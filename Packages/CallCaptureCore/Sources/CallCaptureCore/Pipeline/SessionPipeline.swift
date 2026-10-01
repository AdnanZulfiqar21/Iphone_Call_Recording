import Foundation

/// The capture-critical data path. Callbacks validate identity, record minimal evidence and
/// enqueue within limits; a single serial worker feeds the writer (section 9, rule 9).
public final class SessionPipeline: @unchecked Sendable {
    public let identity: SessionIdentity
    private let lock = NSLock()
    private var health: HealthVerifier
    private let ingress: BoundedIngress
    private let writer: any MediaWriter
    private let clock: any MonotonicClock
    private let diagnostics: DiagnosticsLog?
    private let worker = DispatchQueue(label: "callcapture.writer", qos: .userInitiated)
    private var drainScheduled = false
    private var closed = false
    private var acceptedCutoff: MediaTime?
    private var lastAcceptedSessionEnd: MediaTime = .zero
    private var firstAcceptedSignalled = false
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    public private(set) var lateSamplesRejected = 0

    /// Called once when the first valid media is accepted.
    public var onFirstMediaAccepted: (@Sendable () -> Void)?

    public init(identity: SessionIdentity, contract: CaptureContract, profile: AcceptanceProfile,
                writer: any MediaWriter, clock: any MonotonicClock, diagnostics: DiagnosticsLog? = nil) {
        self.identity = identity
        self.health = HealthVerifier(contract: contract, profile: profile)
        self.ingress = BoundedIngress(profile: profile)
        self.writer = writer
        self.clock = clock
        self.diagnostics = diagnostics
    }

    public func captureStarted() {
        lock.lock(); defer { lock.unlock() }
        health.captureStarted(at: clock.now())
    }

    /// Entry point from capture callbacks. Never blocks on the writer.
    public func ingest(_ sample: CapturedSample) {
        var signalFirst = false
        lock.lock()
        if closed {
            lateSamplesRejected += 1
            lock.unlock()
            return
        }
        let verdict = health.observe(sample.observation, at: clock.now())
        switch verdict {
        case .reject(let reason):
            lock.unlock()
            diagnostics?.record(.sampleRejected, session: identity.sessionID, reason: reason, source: sample.observation.source)
            return
        case .accept:
            break
        }
        switch ingress.enqueue(sample) {
        case .enqueued:
            break
        case .dropped(let ranges):
            for d in ranges { health.ingressDropped(d.source, range: d.range) }
            diagnostics?.record(.queueOverflow, session: identity.sessionID, reason: .queueOverflow, source: sample.observation.source)
        }
        if !firstAcceptedSignalled {
            firstAcceptedSignalled = true
            signalFirst = true
        }
        let needsSchedule = !drainScheduled
        drainScheduled = true
        lock.unlock()
        if signalFirst { onFirstMediaAccepted?() }
        if needsSchedule { worker.async { [weak self] in self?.drainLoop() } }
    }

    private func drainLoop() {
        while let sample = ingress.dequeue() {
            let range: MediaRange
            lock.lock()
            range = health.sessionRange(sample.observation.range)
            lock.unlock()
            switch writer.append(sample, sessionTime: range) {
            case .accepted:
                lock.lock()
                health.writerAccepted(sample.observation.source, range: sample.observation.range)
                lastAcceptedSessionEnd = max(lastAcceptedSessionEnd, range.end)
                lock.unlock()
            case .rejected(let reason):
                lock.lock()
                health.writerRejected(sample.observation.source, range: sample.observation.range, reason: reason)
                lock.unlock()
                diagnostics?.record(.writerRejected, session: identity.sessionID, reason: reason, source: sample.observation.source)
            case .notReady:
                ingress.requeueFront(sample)
                worker.asyncAfter(deadline: .now() + .milliseconds(5)) { [weak self] in self?.drainLoop() }
                return
            }
        }
        lock.lock()
        drainScheduled = false
        let waiters = ingress.count == 0 && closed ? drainWaiters : []
        if !waiters.isEmpty { drainWaiters.removeAll() }
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    /// Stop ingesting: freeze the accepted cutoff (section 8, User Stop).
    public func freezeCutoff() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        acceptedCutoff = health.timelineOrigin == nil ? .zero : lastReceivedSessionEnd()
    }

    private func lastReceivedSessionEnd() -> MediaTime {
        health.contract.sources.compactMap { health.coverage($0.kind, stage: .received).last }.max() ?? .zero
    }

    /// Waits until queued work reaches the writer or the caller's deadline fires.
    public func waitForDrain() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            lock.lock()
            if ingress.count == 0 && !drainScheduled {
                lock.unlock()
                c.resume()
                return
            }
            drainWaiters.append(c)
            let needsSchedule = !drainScheduled
            drainScheduled = true
            lock.unlock()
            if needsSchedule { worker.async { [weak self] in self?.drainLoop() } }
        }
    }

    /// After a drain deadline: anything still queued becomes an explicit loss (T20).
    public func abandonUndrained() {
        let rest = ingress.drainRemaining()
        lock.lock()
        for s in rest {
            health.writerRejected(s.observation.source, range: s.observation.range, reason: .drainTimeout)
        }
        let waiters = drainWaiters
        drainWaiters.removeAll()
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    public func checkpointCommitted(_ report: CheckpointReport) {
        lock.lock(); defer { lock.unlock() }
        for s in report.sources { health.checkpointCommitted(s, sessionRange: report.sessionRange) }
    }

    public func formatChanged(_ source: SourceKind) {
        lock.lock(); defer { lock.unlock() }
        health.formatChanged(source)
    }

    public func currentEpoch(_ source: SourceKind) -> Int {
        lock.lock(); defer { lock.unlock() }
        return health.currentEpoch(source)
    }

    public func status() -> [SourceStatus] {
        lock.lock(); defer { lock.unlock() }
        return health.status(at: clock.now())
    }

    public var anomalies: AnomalyLedger {
        lock.lock(); defer { lock.unlock() }
        return health.ledger
    }

    public var capturedDuration: Double {
        lock.lock(); defer { lock.unlock() }
        return (acceptedCutoff ?? lastReceivedSessionEnd()).seconds
    }

    /// Closes evidence at the cutoff and returns cumulative completeness.
    public func finishEvidence() -> CaptureCompleteness {
        lock.lock(); defer { lock.unlock() }
        let end = acceptedCutoff ?? lastReceivedSessionEnd()
        return health.finish(captureEnd: end)
    }

    public func coverage(_ source: SourceKind, stage: PipelineStage) -> CoverageSet {
        lock.lock(); defer { lock.unlock() }
        return health.coverage(source, stage: stage)
    }
}
