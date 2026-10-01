import Foundation

/// Opaque media payload (a CMSampleBuffer in the media layer). Core never inspects it.
public protocol SamplePayload: Sendable {}

public struct CapturedSample: Sendable {
    public var observation: SampleObservation
    public var payload: (any SamplePayload)?

    public init(observation: SampleObservation, payload: (any SamplePayload)? = nil) {
        self.observation = observation
        self.payload = payload
    }
}

public enum IngressResult: Equatable, Sendable {
    case enqueued
    /// The sample (and possibly older queued samples) were dropped; the ranges are reported, never silent.
    case dropped([DroppedRange])
}

public struct DroppedRange: Equatable, Sendable {
    public var source: SourceKind
    public var range: MediaRange
}

/// Section 15 queue bounds, enforced at ingress and counting everything retained (T17, T18).
/// Video: at most `videoQueueBytes`. Audio: at most `audioQueueSeconds` and `audioQueueBytes`
/// per source, whichever arrives first. Total items are capped by `maxPendingTasks`.
public final class BoundedIngress: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [CapturedSample] = []
    private var head = 0
    private var videoBytes = 0
    private var audioBytes: [SourceKind: Int] = [:]
    private var audioSeconds: [SourceKind: Double] = [:]
    private let profile: AcceptanceProfile
    public private(set) var droppedCount = 0
    public private(set) var highWaterItems = 0

    public init(profile: AcceptanceProfile) { self.profile = profile }

    public var count: Int { lock.lock(); defer { lock.unlock() }; return items.count - head }

    public func enqueue(_ sample: CapturedSample) -> IngressResult {
        lock.lock(); defer { lock.unlock() }
        let o = sample.observation
        var dropped: [DroppedRange] = []
        if o.source.isAudio {
            let wouldBytes = (audioBytes[o.source] ?? 0) + o.byteCount
            let wouldSeconds = (audioSeconds[o.source] ?? 0) + o.range.duration
            if wouldBytes > profile.audioQueueBytes || wouldSeconds > profile.audioQueueSeconds || pending >= profile.maxPendingTasks {
                droppedCount += 1
                return .dropped([DroppedRange(source: o.source, range: o.range)])
            }
        } else {
            // Video under pressure: drop the oldest queued video frames before refusing the newest,
            // so the queue stays current. Each dropped frame is still reported.
            while videoBytes + o.byteCount > profile.videoQueueBytes || pending >= profile.maxPendingTasks {
                guard let index = items[head...].firstIndex(where: { !$0.observation.source.isAudio }) else { break }
                let old = items.remove(at: index)
                videoBytes -= old.observation.byteCount
                dropped.append(DroppedRange(source: old.observation.source, range: old.observation.range))
                droppedCount += 1
            }
            if videoBytes + o.byteCount > profile.videoQueueBytes || pending >= profile.maxPendingTasks {
                droppedCount += 1
                dropped.append(DroppedRange(source: o.source, range: o.range))
                return .dropped(dropped)
            }
        }
        items.append(sample)
        account(o, sign: 1)
        highWaterItems = max(highWaterItems, pending)
        return dropped.isEmpty ? .enqueued : .dropped(dropped)
    }

    /// Removes and returns the oldest sample.
    public func dequeue() -> CapturedSample? {
        lock.lock(); defer { lock.unlock() }
        guard head < items.count else { return nil }
        let s = items[head]
        head += 1
        account(s.observation, sign: -1)
        if head > 64 && head * 2 > items.count {
            items.removeFirst(head)
            head = 0
        }
        return s
    }

    /// Returns the oldest sample to the front after the writer reported it was not ready.
    public func requeueFront(_ sample: CapturedSample) {
        lock.lock(); defer { lock.unlock() }
        if head > 0 {
            head -= 1
            items[head] = sample
        } else {
            items.insert(sample, at: 0)
        }
        account(sample.observation, sign: 1)
    }

    /// Empties the queue, returning what was still pending so it can be reported as loss.
    public func drainRemaining() -> [CapturedSample] {
        lock.lock(); defer { lock.unlock() }
        let rest = Array(items[head...])
        items.removeAll()
        head = 0
        videoBytes = 0
        audioBytes.removeAll()
        audioSeconds.removeAll()
        return rest
    }

    private var pending: Int { items.count - head }

    private func account(_ o: SampleObservation, sign: Int) {
        if o.source.isAudio {
            audioBytes[o.source, default: 0] += sign * o.byteCount
            audioSeconds[o.source, default: 0] += Double(sign) * o.range.duration
        } else {
            videoBytes += sign * o.byteCount
        }
    }
}
