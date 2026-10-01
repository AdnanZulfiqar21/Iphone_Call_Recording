#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import UniformTypeIdentifiers
import CallCaptureCore

/// Production MediaWriter backend selected in P04 (docs/platform/capture-path-decision.md).
///
/// One backend per session (rule 2). Internally each source × format epoch is encoded by its
/// own AVAssetWriter in delegate segment mode (fragmented MPEG-4, HLS profile), which reports
/// every initialization and media segment explicitly. Each segment is committed through
/// SegmentCommitter before a checkpoint is reported, so CHECKPOINT_COMMITTED is never inferred
/// from a timer or file size (section 10). Separate tracks preserve source provenance.
public final class SegmentedTrackWriter: NSObject, MediaWriter, @unchecked Sendable {
    public struct Settings: Sendable {
        public var segmentInterval: Double = 2
        public var videoBitRate: Int = 6_000_000
        public var maxVideoLongEdge: Int = 1_920
        public var audioBitRate: Int = 128_000
        public init() {}
    }

    private let settings: Settings
    /// Guards track management during append.
    private let lock = NSLock()
    /// Guards commit references; never held while appending, because segment callbacks
    /// may arrive on any thread, including during an append.
    private let refLock = NSLock()
    private var committer: SegmentCommitter?
    private var onCheckpoint: (@Sendable (CheckpointReport) -> Void)?
    private var tracks: [TrackKey: TrackWriter] = [:]
    private var currentEpoch: [SourceKind: Int] = [:]
    private var formatKeys: [SourceKind: String] = [:]
    private var lastAudioEnd: [SourceKind: Double] = [:]
    private let discontinuityTolerance = 0.1
    /// Session origin in source time: PTS that maps to session time zero.
    private var origin: CMTime?
    private var finished = false
    private var lastError: String?
    private var videoCanvas: (width: Int, height: Int)?

    struct TrackKey: Hashable { let source: SourceKind; let epoch: Int }

    public init(settings: Settings = Settings()) {
        self.settings = settings
    }

    public func open(identity: SessionIdentity, contract: CaptureContract, recoveryDirectory: URL,
                     onCheckpoint: @escaping @Sendable (CheckpointReport) -> Void) throws {
        let c = try SegmentCommitter(files: RecoveryFiles(directory: recoveryDirectory), sessionID: identity.sessionID)
        refLock.withLock {
            committer = c
            self.onCheckpoint = onCheckpoint
        }
    }

    public func append(_ sample: CapturedSample, sessionTime: MediaRange) -> WriterAppendResult {
        lock.lock(); defer { lock.unlock() }
        guard !finished else { return .rejected(.writerRejected) }
        // An idle/blank frame without image data is evidence only; there is nothing to encode.
        guard let payload = sample.payload as? SampleBufferPayload else { return .accepted }
        let buffer = payload.buffer
        let source = sample.observation.source
        if source == .screen && CMSampleBufferGetImageBuffer(buffer) == nil { return .accepted }

        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        if refLock.withLock({ origin }) == nil {
            let o = CMTimeSubtract(pts, CMTime(seconds: sessionTime.start.seconds, preferredTimescale: pts.timescale > 0 ? pts.timescale : 1_000_000_000))
            refLock.withLock { origin = o }
        }

        // Audio format change or timestamp discontinuity: close the part and start a new one
        // (section 10.2). Each part is placed at its own session offset during assembly, so a
        // hole stays a hole and later audio keeps its true time instead of being closed up.
        let key = SampleBufferInspector.formatKey(of: buffer)
        let start = CMTimeGetSeconds(pts)
        let discontinuous = source.isAudio && (lastAudioEnd[source].map { start - $0 > discontinuityTolerance } ?? false)
        let end = start + max(0, CMTimeGetSeconds(CMSampleBufferGetDuration(buffer)).isFinite ? CMTimeGetSeconds(CMSampleBufferGetDuration(buffer)) : 0)
        if source.isAudio { lastAudioEnd[source] = max(lastAudioEnd[source] ?? end, end) }
        if source.isAudio, let previous = formatKeys[source], previous != key || discontinuous {
            let oldKey = TrackKey(source: source, epoch: currentEpoch[source] ?? 0)
            tracks[oldKey]?.finishAsync()
            currentEpoch[source] = (currentEpoch[source] ?? 0) + 1
        }
        formatKeys[source] = key
        let trackKey = TrackKey(source: source, epoch: currentEpoch[source] ?? 0)

        let track: TrackWriter
        if let existing = tracks[trackKey] {
            track = existing
        } else {
            do {
                track = try makeTrack(trackKey, first: buffer)
                tracks[trackKey] = track
            } catch {
                refLock.withLock { lastError = String(describing: error) }
                return .rejected(.writerRejected)
            }
        }
        return track.append(buffer)
    }

    private func makeTrack(_ key: TrackKey, first: CMSampleBuffer) throws -> TrackWriter {
        let (committer, origin) = refLock.withLock { (self.committer, self.origin) }
        guard committer != nil, let origin else { throw WriterError.notOpen }
        let outputSettings: [String: Any]
        let mediaType: AVMediaType
        if key.source == .screen {
            mediaType = .video
            let canvas = videoCanvas ?? canvasSize(for: first)
            videoCanvas = canvas
            outputSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: canvas.width,
                AVVideoHeightKey: canvas.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: settings.videoBitRate,
                    AVVideoMaxKeyFrameIntervalDurationKey: 1,
                    AVVideoAllowFrameReorderingKey: false,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                ],
            ]
        } else {
            mediaType = .audio
            let asbd = SampleBufferInspector.audioFormat(of: first)
            let rate = asbd.map { $0.mSampleRate > 0 ? $0.mSampleRate : 48_000 } ?? 48_000
            let channels = min(2, max(1, Int(asbd?.mChannelsPerFrame ?? 1)))
            outputSettings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: min(48_000, rate),
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: settings.audioBitRate * channels / 2 + 32_000,
            ]
        }
        let firstPTS = CMSampleBufferGetPresentationTimeStamp(first)
        let offset = CMTimeSubtract(firstPTS, origin)
        let onSegment: @Sendable (Data, AVAssetSegmentType, CMTime, CMTime) -> Void = { [weak self] data, type, start, duration in
            self?.segmentProduced(key: key, data: data, type: type, sourceStart: start, duration: duration)
        }
        return try TrackWriter(key: key, mediaType: mediaType, outputSettings: outputSettings, startTime: firstPTS,
                               sessionOffset: offset, segmentInterval: settings.segmentInterval, onSegment: onSegment)
    }

    private func canvasSize(for buffer: CMSampleBuffer) -> (width: Int, height: Int) {
        guard let image = CMSampleBufferGetImageBuffer(buffer) else { return (1_080, 1_920) }
        var w = CVPixelBufferGetWidth(image), h = CVPixelBufferGetHeight(image)
        let longEdge = max(w, h)
        if longEdge > settings.maxVideoLongEdge {
            let scale = Double(settings.maxVideoLongEdge) / Double(longEdge)
            w = Int(Double(w) * scale)
            h = Int(Double(h) * scale)
        }
        return (w & ~1, h & ~1)
    }

    /// Commit transaction for each segment produced by a track writer.
    private func segmentProduced(key: TrackKey, data: Data, type: AVAssetSegmentType, sourceStart: CMTime, duration: CMTime) {
        let (committer, origin, callback) = refLock.withLock { (self.committer, self.origin, self.onCheckpoint) }
        guard let committer, let origin else { return }
        do {
            switch type {
            case .initialization:
                try committer.commitInitialization(data, source: key.source, epoch: key.epoch)
            case .separable:
                guard committer.hasInitialization(for: key.source, epoch: key.epoch) else { throw WriterError.missingInitialization }
                let start = CMTimeSubtract(sourceStart, origin).seconds
                let range = MediaRange(startSeconds: max(0, start), endSeconds: max(0, start) + max(0, duration.seconds))
                let report = try committer.commitSegment(data, sessionRange: range, sources: [key.source], epoch: key.epoch)
                callback?(report)
            @unknown default:
                break
            }
        } catch {
            refLock.withLock { lastError = "segmentCommit:\(error)" }
        }
    }

    public func finish() async -> WriterFinishReport {
        let all: [TrackWriter] = lock.withLock {
            finished = true
            return Array(tracks.values)
        }
        for t in all { await t.finish() }
        let manifest = refLock.withLock { committer?.currentManifest }
        let error = refLock.withLock { lastError }
        return WriterFinishReport(lastCheckpointSequence: manifest?.segments.last?.sequence ?? -1,
                                  writtenRange: manifest.flatMap { $0.segments.isEmpty ? nil : MediaRange(startSeconds: 0, endSeconds: $0.committedEnd) },
                                  error: error)
    }

    public func cancel() async {
        let all: [TrackWriter] = lock.withLock {
            finished = true
            return Array(tracks.values)
        }
        for t in all { t.cancel() }
    }

    enum WriterError: Error { case notOpen, missingInitialization, cannotAddInput, startFailed(String) }

    /// Technical summary for diagnostics and tests (no media content).
    public var diagnosticSummary: String {
        let parts = lock.withLock { tracks.map { "\($0.key.source.rawValue).e\($0.key.epoch)=\($0.value.statusDescription)" } }
        let err = refLock.withLock { lastError ?? "none" }
        return "tracks[\(parts.sorted().joined(separator: ","))] lastError=\(err)"
    }
}

/// One AVAssetWriter in delegate segment mode for a single source × epoch.
final class TrackWriter: NSObject, AVAssetWriterDelegate, @unchecked Sendable {
    let key: SegmentedTrackWriter.TrackKey
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let onSegment: @Sendable (Data, AVAssetSegmentType, CMTime, CMTime) -> Void
    private var closed = false
    private let lock = NSLock()

    init(key: SegmentedTrackWriter.TrackKey, mediaType: AVMediaType, outputSettings: [String: Any], startTime: CMTime,
         sessionOffset: CMTime, segmentInterval: Double, onSegment: @escaping @Sendable (Data, AVAssetSegmentType, CMTime, CMTime) -> Void) throws {
        self.key = key
        self.onSegment = onSegment
        writer = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue) ?? .mpeg4Movie)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = CMTime(seconds: segmentInterval, preferredTimescale: 600)
        writer.initialSegmentStartTime = startTime
        input = AVAssetWriterInput(mediaType: mediaType, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true
        super.init()
        writer.delegate = self
        guard writer.canAdd(input) else { throw SegmentedTrackWriter.WriterError.cannotAddInput }
        writer.add(input)
        guard writer.startWriting() else {
            throw SegmentedTrackWriter.WriterError.startFailed(writer.error.map { String(describing: $0) } ?? "unknown")
        }
        writer.startSession(atSourceTime: startTime)
        _ = sessionOffset
    }

    var statusDescription: String {
        lock.withLock {
            "status:\(writer.status.rawValue) ready:\(input.isReadyForMoreMediaData) err:\(writer.error.map { ($0 as NSError).code } ?? 0)"
        }
    }

    func append(_ buffer: CMSampleBuffer) -> WriterAppendResult {
        lock.lock(); defer { lock.unlock() }
        guard !closed, writer.status == .writing else { return .rejected(.writerRejected) }
        guard input.isReadyForMoreMediaData else { return .notReady }
        return input.append(buffer) ? .accepted : .rejected(.writerRejected)
    }

    /// Every caller awaits the same in-flight finish, so a part closed early (format change) is
    /// fully committed before the session's finish() returns.
    private var finishing: Task<Void, Never>?

    func finish() async {
        let task: Task<Void, Never> = lock.withLock {
            if let finishing { return finishing }
            let shouldFinish = !closed && writer.status == .writing
            closed = true
            let t = Task { [writer, input] in
                guard shouldFinish else { return }
                input.markAsFinished()
                await writer.finishWriting()
            }
            finishing = t
            return t
        }
        await task.value
    }

    func finishAsync() {
        Task { await finish() }
    }

    func cancel() {
        lock.withLock {
            guard !closed else { return }
            closed = true
            if writer.status == .writing { writer.cancelWriting() }
        }
    }

    func assetWriter(_ writer: AVAssetWriter, didOutputSegmentData segmentData: Data, segmentType: AVAssetSegmentType,
                     segmentReport: AVAssetSegmentReport?) {
        var start = CMTime.invalid
        var duration = CMTime.zero
        if let report = segmentReport?.trackReports.first {
            start = report.earliestPresentationTimeStamp
            duration = report.duration
        }
        onSegment(segmentData, segmentType, start, duration)
    }
}
#endif
