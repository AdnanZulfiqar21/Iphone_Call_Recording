import Foundation
@testable import CallCaptureCore

/// Deterministic scheduler: deadlines fire only when a test says so.
final class ManualScheduler: SessionScheduler, @unchecked Sendable {
    final class Work: ScheduledWork, @unchecked Sendable {
        let seconds: Double
        let action: @Sendable () async -> Void
        private(set) var cancelled = false
        init(seconds: Double, action: @escaping @Sendable () async -> Void) { self.seconds = seconds; self.action = action }
        func cancel() { cancelled = true }
    }

    private let lock = NSLock()
    private var items: [Work] = []

    func schedule(after seconds: Double, _ action: @escaping @Sendable () async -> Void) -> any ScheduledWork {
        let w = Work(seconds: seconds, action: action)
        lock.withLock { items.append(w) }
        return w
    }

    /// Fires pending (non-cancelled) work whose delay equals `seconds`.
    func fire(after seconds: Double) async {
        let due: [Work] = lock.withLock {
            let d = items.filter { !$0.cancelled && $0.seconds == seconds }
            items.removeAll { w in d.contains { $0 === w } }
            return d
        }
        for w in due { await w.action() }
    }

    var pendingDelays: [Double] { lock.withLock { items.filter { !$0.cancelled }.map(\.seconds) } }
}

func temporaryRoot() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cc-tests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Polls an async condition with a real-time timeout (for actor/task hand-offs only).
func eventually(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return await condition()
}

extension SampleObservation {
    static func audio(_ source: SourceKind = .microphone, _ start: Double, _ duration: Double = 0.1,
                      _ content: AudioContentSummary = .speech()) -> SampleObservation {
        SampleObservation(source: source, range: MediaRange(startSeconds: start, endSeconds: start + duration), audio: content, byteCount: 1_000)
    }

    static func frame(_ start: Double, _ status: FrameStatus = .complete) -> SampleObservation {
        SampleObservation(source: .screen, range: MediaRange(startSeconds: start, endSeconds: start + 1.0 / 30), frame: status, byteCount: 50_000)
    }
}

let screenMicContract = CaptureContract.standard(mode: .screenAndAudio)
