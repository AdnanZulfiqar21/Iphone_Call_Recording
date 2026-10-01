#if os(iOS) && canImport(ScreenCaptureKit)
import AVFoundation
import CoreMedia
import ScreenCaptureKit
import CallCaptureCore

/// Production capture adapter (P03), path A: ScreenCaptureKit on iOS 27.
///
/// Uses only the genuine system content-sharing picker; never imitates it (section 14.4).
/// Callbacks do minimal work: identity check, small observation, bounded hand-off (section 9).
/// Whether remote call audio is supplied is UNTESTED until physical validation (P14).
@available(iOS 27.0, *)
public final class ScreenCaptureKitEngine: NSObject, CaptureEngine, SCContentSharingPickerObserver, SCStreamDelegate,
    SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var sink: CaptureEventSink?
    private var generation = -1
    private var contract: CaptureContract?
    private var filter: SCContentFilter?
    private var stream: SCStream?
    private var formatKeys: [SourceKind: String] = [:]
    private var epochs: [SourceKind: Int] = [:]
    private var stopRequested = false
    private var observing = false
    private let videoQueue = DispatchQueue(label: "callcapture.capture.video", qos: .userInitiated)
    private let audioQueue = DispatchQueue(label: "callcapture.capture.audio", qos: .userInitiated)
    private var notificationTokens: [NSObjectProtocol] = []

    public override init() {
        super.init()
    }

    public var isAvailable: Bool { SCContentSharingPicker.shared.isAvailable }

    // MARK: Picker

    public func presentPicker(contract: CaptureContract, generation: Int, sink: @escaping CaptureEventSink) {
        lock.withLock {
            self.sink = sink
            self.generation = generation
            self.contract = contract
            self.filter = nil
            self.stopRequested = false
            self.formatKeys = [:]
            self.epochs = [:]
        }
        DispatchQueue.main.async { [self] in
            let picker = SCContentSharingPicker.shared
            var configuration = SCContentSharingPickerConfiguration()
            configuration.showsMicrophoneControl = contract.policy(for: .microphone) != nil
            picker.defaultConfiguration = configuration
            if !lock.withLock({ observing }) {
                picker.add(self)
                lock.withLock { observing = true }
            }
            picker.isActive = true
            picker.present()
        }
    }

    public func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        let (s, g) = lock.withLock { (sink, generation) }
        s?(g, .selectionCancelled)
    }

    public func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        let (s, g, alreadyRunning) = lock.withLock { () -> (CaptureEventSink?, Int, Bool) in
            let running = self.stream != nil
            if !running { self.filter = filter }
            return (sink, generation, running)
        }
        // A selection change while capturing would redefine scope: treat as a new epoch (T05).
        if alreadyRunning {
            for source in SourceKind.allCases { s?(g, .formatChanged(source)) }
            return
        }
        s?(g, .selectionAccepted(microphoneEnabled: filter.isMicrophoneEnabled))
    }

    public func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        let (s, g) = lock.withLock { (sink, generation) }
        s?(g, Self.isUserDeclined(error) ? .permissionDenied : .unsupported("pickerStartFailed"))
    }

    // MARK: Stream

    public func startCapture(generation g: Int) async {
        let (filter, contract, s) = lock.withLock { (self.filter, self.contract, self.sink) }
        guard let filter, let contract, g == lock.withLock({ generation }) else { return }

        let wantsAppAudio = contract.policy(for: .appAudio) != nil
        let wantsMic = filter.isMicrophoneEnabled
        if wantsMic || wantsAppAudio { activateAudioSession() }

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = wantsAppAudio
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true
        configuration.captureDynamicRange = .SDR

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            if contract.policy(for: .screen) != nil {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
            }
            if wantsAppAudio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue) }
            if wantsMic { try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: audioQueue) }
            lock.withLock { self.stream = stream }
            observeAudioSessionNotifications()
            try await stream.startCapture()
        } catch {
            lock.withLock { self.stream = nil }
            s?(g, Self.isUserDeclined(error) ? .permissionDenied : .stopped(Self.reason(for: error)))
        }
    }

    public func stopCapture(generation g: Int) async {
        let (stream, s, current) = lock.withLock { () -> (SCStream?, CaptureEventSink?, Int) in
            stopRequested = true
            let st = self.stream
            self.stream = nil
            return (st, sink, generation)
        }
        guard g == current else { return }
        if let stream {
            try? await stream.stopCapture()
            s?(g, .stopped(nil))
        }
        await MainActor.run {
            SCContentSharingPicker.shared.isActive = false
        }
        removeAudioSessionNotifications()
        deactivateAudioSession()
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        let source: SourceKind
        switch type {
        case .screen: source = .screen
        case .audio: source = .appAudio
        case .microphone: source = .microphone
        @unknown default: return
        }
        let (s, g) = lock.withLock { (sink, generation) }
        guard let s else { return }

        var frame: FrameStatus?
        var payload: (any SamplePayload)? = SampleBufferPayload(sampleBuffer)
        if source == .screen {
            frame = Self.frameStatus(of: sampleBuffer)
            if frame != .complete { payload = nil }   // idle/blank frames carry no new image
        }

        // Detect format/route epochs from the actual buffers (T16).
        let key = SampleBufferInspector.formatKey(of: sampleBuffer)
        let (changed, epoch) = lock.withLock { () -> (Bool, Int) in
            if let previous = formatKeys[source], previous != key, payload != nil {
                epochs[source, default: 0] += 1
                formatKeys[source] = key
                return (true, epochs[source] ?? 0)
            }
            if payload != nil { formatKeys[source] = key }
            return (false, epochs[source] ?? 0)
        }
        if changed { s(g, .formatChanged(source)) }

        let observation = SampleObservation(
            source: source,
            range: SampleBufferInspector.range(of: sampleBuffer),
            formatEpoch: epoch,
            audio: source.isAudio ? AudioAnalyzer.summarize(sampleBuffer) : nil,
            frame: frame,
            byteCount: SampleBufferInspector.byteCount(of: sampleBuffer))
        s(g, .sample(CapturedSample(observation: observation, payload: payload)))
    }

    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        let (s, g, requested) = lock.withLock { () -> (CaptureEventSink?, Int, Bool) in
            self.stream = nil
            return (sink, generation, stopRequested)
        }
        guard !requested else { return }
        // System or user stop from outside the app is authoritative (rule 5).
        s?(g, .stopped(Self.reason(for: error)))
        removeAudioSessionNotifications()
        deactivateAudioSession()
    }

    // MARK: Helpers

    static func frameStatus(of buffer: CMSampleBuffer) -> FrameStatus {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw) else {
            return CMSampleBufferGetImageBuffer(buffer) != nil ? .complete : .idle
        }
        switch status {
        case .complete: return .complete
        case .idle: return .idle
        case .blank: return .blank
        case .suspended: return .suspended
        case .started: return .started
        case .stopped: return .stopped
        @unknown default: return .idle
        }
    }

    static func isUserDeclined(_ error: any Error) -> Bool {
        let ns = error as NSError
        return ns.domain == SCStreamErrorDomain && ns.code == SCStreamError.Code.userDeclined.rawValue
    }

    static func reason(for error: any Error) -> ReasonCode? {
        let ns = error as NSError
        guard ns.domain == SCStreamErrorDomain, let code = SCStreamError.Code(rawValue: ns.code) else { return .streamStoppedBySystem }
        switch code {
        case .userStopped: return nil   // the person stopped from the system UI: an ordinary Stop
        case .insufficientStorage: return .diskFull
        default: return .streamStoppedBySystem
        }
    }

    /// Needed for background microphone delivery (Apple iOS 27 sample). No route-changing options
    /// (e.g. defaultToSpeaker) are used. `mixWithOthers` avoids
    /// interrupting another app's audio; the effect on a live call is assessed in P14 (section 9).
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetoothHFP])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func observeAudioSessionNotifications() {
        let center = NotificationCenter.default
        let reset = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            let (s, g) = self.lock.withLock { (self.sink, self.generation) }
            s?(g, .mediaServicesReset)
        }
        let route = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            let (s, g) = self.lock.withLock { (self.sink, self.generation) }
            // Route changes can alter sample rate/channels; old proof expires until new audio arrives (T16).
            s?(g, .formatChanged(.microphone))
        }
        lock.withLock { notificationTokens = [reset, route] }
    }

    private func removeAudioSessionNotifications() {
        let tokens = lock.withLock { () -> [NSObjectProtocol] in
            let t = notificationTokens
            notificationTokens = []
            return t
        }
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
#endif

#if os(iOS) && canImport(ReplayKit)
import ReplayKit

/// Candidate B (ReplayKit Broadcast Upload Extension) was evaluated in P01 and not selected for
/// V1 (docs/platform/capture-path-decision.md). This reference keeps its public symbols compiled
/// against the current SDK so the fallback stays SDK_COMPILED; it is not used at runtime.
enum ReplayKitCandidateReference {
    static let compiledSymbols: [Any.Type] = [RPBroadcastSampleHandler.self, RPSystemBroadcastPickerView.self]
}
#endif
