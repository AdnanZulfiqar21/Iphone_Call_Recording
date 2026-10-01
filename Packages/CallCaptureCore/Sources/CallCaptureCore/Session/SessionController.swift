import Foundation

/// Everything the UI needs, derived from authoritative state. Views never infer health.
public struct SessionSnapshot: Sendable, Equatable {
    public var lifecycle: Lifecycle
    public var sessionID: UUID?
    public var generation: Int
    public var contract: CaptureContract?
    /// Seconds since the first captured media (never includes picker wait).
    public var elapsed: Double
    public var sources: [SourceStatus]
    public var anomalies: AnomalyLedger
    public var nonCaptureOutcome: NonCaptureOutcome?
    public var finalOutcome: FinalOutcome?
    public var endReason: ReasonCode?
    public var savedRecordingID: UUID?
    public var resourceState: ResourceState
    public var stopRequested: Bool
    public var canStart: Bool
    public var updatedAt: MonotonicInstant
    public var wallUpdatedAt: Date

    public static func idle(now: MonotonicInstant, wall: Date) -> SessionSnapshot {
        SessionSnapshot(lifecycle: .idle, sessionID: nil, generation: 0, contract: nil, elapsed: 0, sources: [],
                        anomalies: AnomalyLedger(), nonCaptureOutcome: nil, finalOutcome: nil, endReason: nil,
                        savedRecordingID: nil, resourceState: .normal, stopRequested: false, canStart: true,
                        updatedAt: now, wallUpdatedAt: wall)
    }

    public var headline: StatusLine {
        StatusPresenter.headline(lifecycle: lifecycle, nonCapture: nonCaptureOutcome, outcome: finalOutcome, endReason: endReason)
    }
}

public struct SessionDependencies: Sendable {
    public var engine: any CaptureEngine
    public var makeWriter: @Sendable () -> any MediaWriter
    public var assembler: any RecordingAssembler
    public var store: RecordingStore
    public var clock: any MonotonicClock
    public var wallClock: any WallClock
    public var scheduler: any SessionScheduler
    public var diagnostics: DiagnosticsLog
    public var profile: AcceptanceProfile
    public var freeBytes: @Sendable () -> Int64

    public init(engine: any CaptureEngine, makeWriter: @escaping @Sendable () -> any MediaWriter, assembler: any RecordingAssembler,
                store: RecordingStore, clock: any MonotonicClock = SystemMonotonicClock(), wallClock: any WallClock = SystemWallClock(),
                scheduler: any SessionScheduler = TaskScheduler(), diagnostics: DiagnosticsLog = DiagnosticsLog(),
                profile: AcceptanceProfile = .v1, freeBytes: @escaping @Sendable () -> Int64) {
        self.engine = engine
        self.makeWriter = makeWriter
        self.assembler = assembler
        self.store = store
        self.clock = clock
        self.wallClock = wallClock
        self.scheduler = scheduler
        self.diagnostics = diagnostics
        self.profile = profile
        self.freeBytes = freeBytes
    }
}

/// Holds the active pipeline for the capture callback path without hopping onto the actor.
final class PipelineBox: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = -1
    private var pipeline: SessionPipeline?

    func set(_ p: SessionPipeline?, generation g: Int) { lock.lock(); pipeline = p; generation = g; lock.unlock() }
    func get(_ g: Int) -> SessionPipeline? { lock.lock(); defer { lock.unlock() }; return g == generation ? pipeline : nil }
}

/// SessionController (section 5): the single authority for lifecycle, generation, contract,
/// deadlines and event coordination. No other component decides start/stop/completion.
public actor SessionController {
    private let deps: SessionDependencies
    private var machine: SessionStateMachine
    private var deadlines: [SessionDeadline: any ScheduledWork] = [:]
    private let box = PipelineBox()
    private var pipeline: SessionPipeline?
    private var writer: (any MediaWriter)?
    private var recoveryFiles: RecoveryFiles?
    private var journal: RecoveryJournal?
    private var firstMediaAt: MonotonicInstant?
    private var stoppedElapsed: Double?
    private var savedRecordingID: UUID?
    private var title = ""
    private var governor: ResourceGovernor
    private var ticker: (any ScheduledWork)?
    private var continuations: [UUID: AsyncStream<SessionSnapshot>.Continuation] = [:]
    private var lastSnapshot: SessionSnapshot

    public init(dependencies: SessionDependencies) {
        self.deps = dependencies
        self.machine = SessionStateMachine(profile: dependencies.profile)
        self.governor = ResourceGovernor(reserve: StorageReserve.forMode(.screenAndAudio))
        self.lastSnapshot = .idle(now: dependencies.clock.now(), wall: dependencies.wallClock.now())
    }

    // MARK: Public API

    public func snapshot() -> SessionSnapshot { makeSnapshot() }

    public func updates() -> AsyncStream<SessionSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<SessionSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.yield(makeSnapshot())
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) { continuations[id] = nil }

    /// Explicit user Record action (rule 4). A second request while active is ignored.
    public func record(contract: CaptureContract, title: String) {
        guard machine.canStartNewSession else { return }
        self.title = title
        firstMediaAt = nil
        stoppedElapsed = nil
        savedRecordingID = nil
        governor = ResourceGovernor(reserve: StorageReserve.forMode(contract.mode))
        apply(.recordRequested(contract))
    }

    /// User Stop: acknowledged immediately, idempotent (UX07, T01).
    public func stop() {
        apply(.stopRequested, generation: machine.generation)
    }

    /// Returns to idle after the result is shown. Never restarts capture.
    public func acknowledgeResult() {
        apply(.reset, generation: machine.generation)
    }

    // MARK: Event handling

    private func apply(_ event: SessionEvent, generation: Int? = nil) {
        let before = machine.lifecycle
        let effects = machine.handle(event, generation: generation)
        if before != machine.lifecycle {
            deps.diagnostics.record(.lifecycle, session: machine.sessionID, detail: "\(before.rawValue)->\(machine.lifecycle.rawValue)")
        }
        for effect in effects { perform(effect) }
        publish()
    }

    private func perform(_ effect: SessionEffect) {
        let generation = machine.generation
        switch effect {
        case .checkResources:
            let free = deps.freeBytes()
            let state = governor.evaluate(ResourceInputs(freeBytes: free))
            if governor.reserve.canStart(freeBytes: free) && state != .protectedStop {
                apply(.resourcesReady, generation: generation)
            } else {
                apply(.resourcesInsufficient, generation: generation)
            }
        case .presentPicker:
            guard let contract = machine.contract else { return }
            deps.engine.presentPicker(contract: contract, generation: generation, sink: makeSink())
        case .startCapture:
            startCapture(generation: generation)
        case .stopCapture:
            let engine = deps.engine
            stoppedElapsed = currentElapsed()
            Task { await engine.stopCapture(generation: generation) }
        case .freezeCutoff:
            stoppedElapsed = stoppedElapsed ?? currentElapsed()
            pipeline?.freezeCutoff()
        case .beginDrain:
            guard let p = pipeline else {
                apply(.drainCompleted, generation: generation)
                return
            }
            Task { [weak self] in
                await p.waitForDrain()
                await self?.handleDrained(generation)
            }
        case .finalizeWriter:
            finalize(generation: generation)
        case .cancelWriter:
            let w = writer
            Task { [weak self] in
                await w?.cancel()
                await self?.writerDidClose(generation)
            }
        case .preserveRecovery:
            updateJournal { $0.state = .needsRecovery }
        case .releaseResources:
            ticker?.cancel()
            ticker = nil
            box.set(nil, generation: -1)
        case .schedule(let d, let seconds):
            deadlines[d]?.cancel()
            deadlines[d] = deps.scheduler.schedule(after: seconds) { [weak self] in
                await self?.deadlineFired(d, generation: generation)
            }
        case .cancel(let d):
            deadlines[d]?.cancel()
            deadlines[d] = nil
        }
    }

    private func deadlineFired(_ d: SessionDeadline, generation: Int) {
        guard generation == machine.generation else { return }
        deps.diagnostics.record(.deadline, session: machine.sessionID, detail: d.rawValue)
        if d == .drain { pipeline?.abandonUndrained() }
        if d == .startup, machine.lifecycle == .capturing, let contract = machine.contract,
           contract.unmetRequirementPolicy == .protectedStop {
            let unmet = (pipeline?.status() ?? []).filter {
                $0.requirement == .required && $0.health != .checksPassing && $0.health != .limited
            }
            if !unmet.isEmpty {
                deps.diagnostics.record(.deadline, session: machine.sessionID, reason: .sourceNeverArrived, detail: "protectedStop")
                apply(.protectedStop(.sourceNeverArrived), generation: generation)
                return
            }
        }
        apply(.deadlineExpired(d), generation: generation)
    }

    private func handleDrained(_ generation: Int) {
        guard machine.lifecycle == .stopping else { return }
        apply(.drainCompleted, generation: generation)
    }

    private func writerDidClose(_ generation: Int) {
        apply(.writerClosed, generation: generation)
    }

    private nonisolated func makeSink() -> CaptureEventSink {
        let box = self.box
        return { [weak self] generation, event in
            if case .sample(let sample) = event {
                // Hot path: straight into the bounded pipeline, no task per sample (rule 9).
                box.get(generation)?.ingest(sample)
                return
            }
            Task { await self?.engineEvent(generation, event) }
        }
    }

    private func engineEvent(_ generation: Int, _ event: CaptureEngineEvent) {
        guard generation == machine.generation else { return }   // stale callback (T04)
        switch event {
        case .selectionAccepted(let mic):
            if !mic, let contract = machine.contract, contract.policy(for: .microphone)?.requirement == .required {
                // The person turned the microphone off in the system picker: a deliberate new contract
                // segment in which the microphone is optional (section 6.1).
                machine.adoptContract(contract.limited(droppingRequirementFor: .microphone))
            }
            apply(.selectionAccepted(microphoneEnabled: mic), generation: generation)
        case .selectionCancelled: apply(.selectionCancelled, generation: generation)
        case .permissionDenied: apply(.permissionDenied, generation: generation)
        case .unsupported(let why):
            deps.diagnostics.record(.error, session: machine.sessionID, detail: "unsupported")
            _ = why
            apply(.unsupported, generation: generation)
        case .sample: break
        case .formatChanged(let source):
            pipeline?.formatChanged(source)
            deps.diagnostics.record(.lifecycle, session: machine.sessionID, reason: .formatChanged, source: source)
            publish()
        case .stopped(let reason):
            apply(.captureEnded(reason: reason), generation: generation)
        case .mediaServicesReset:
            apply(.mediaServicesReset, generation: generation)
        }
    }

    // MARK: Capture start

    private func startCapture(generation: Int) {
        guard let identity = machine.identity, let contract = machine.contract else { return }
        let files = RecoveryFiles(directory: deps.store.layout.recoveryDirectory(identity.sessionID))
        let writer = deps.makeWriter()
        do {
            try files.prepare()
            var j = RecoveryJournal(identity: identity, contract: contract, createdAt: deps.wallClock.now(), title: title)
            j.state = .active
            try files.writeJournal(j)
            journal = j
            recoveryFiles = files
            try writer.open(identity: identity, contract: contract, recoveryDirectory: files.directory) { [weak self] report in
                Task { await self?.checkpoint(report, generation: generation) }
            }
        } catch {
            deps.diagnostics.record(.error, session: identity.sessionID, detail: "writerOpenFailed")
            apply(.unsupported, generation: generation)
            return
        }
        self.writer = writer
        let p = SessionPipeline(identity: identity, contract: contract, profile: deps.profile, writer: writer,
                                clock: deps.clock, diagnostics: deps.diagnostics)
        p.onFirstMediaAccepted = { [weak self] in
            Task { await self?.firstMedia(generation) }
        }
        p.captureStarted()
        pipeline = p
        box.set(p, generation: generation)
        let engine = deps.engine
        Task { await engine.startCapture(generation: generation) }
        startTicker(generation: generation)
    }

    private func firstMedia(_ generation: Int) {
        guard generation == machine.generation else { return }
        if firstMediaAt == nil { firstMediaAt = deps.clock.now() }
        apply(.firstMediaAccepted, generation: generation)
    }

    private func checkpoint(_ report: CheckpointReport, generation: Int) {
        guard generation == machine.generation else { return }
        pipeline?.checkpointCommitted(report)
        let anomalies = pipeline?.anomalies.anomalies ?? []
        updateJournal { j in
            j.lastKnownCaptureEnd = max(j.lastKnownCaptureEnd, report.sessionRange.end.seconds)
            j.anomalies = anomalies
        }
    }

    private func updateJournal(_ change: (inout RecoveryJournal) -> Void) {
        guard var j = journal, let files = recoveryFiles else { return }
        change(&j)
        journal = j
        try? files.writeJournal(j)
    }

    /// 1 Hz status refresh while capturing (section 14.7); significant changes publish immediately.
    private func startTicker(generation: Int) {
        ticker?.cancel()
        ticker = deps.scheduler.schedule(after: 1) { [weak self] in
            await self?.tick(generation)
        }
    }

    private func tick(_ generation: Int) {
        guard generation == machine.generation, machine.lifecycle.isActive else { return }
        publish()
        startTicker(generation: generation)
    }

    // MARK: Finalization

    private func finalize(generation: Int) {
        guard let identity = machine.identity, let contract = machine.contract, let files = recoveryFiles else {
            apply(.finalizeFailed, generation: generation)
            return
        }
        let writer = self.writer
        let pipeline = self.pipeline
        updateJournal { $0.state = .finalizing }
        Task { [weak self] in
            let report = await writer?.finish()
            await self?.completeFinalization(generation: generation, identity: identity, contract: contract,
                                             files: files, pipeline: pipeline, report: report)
        }
    }

    private func completeFinalization(generation: Int, identity: SessionIdentity, contract: CaptureContract,
                                      files: RecoveryFiles, pipeline: SessionPipeline?, report: WriterFinishReport?) async {
        guard generation == machine.generation else { return }
        let completeness = pipeline?.finishEvidence() ?? .unknown
        var ledger = pipeline?.anomalies ?? AnomalyLedger()
        let capturedSeconds = pipeline?.capturedDuration ?? 0
        updateJournal { j in
            j.anomalies = ledger.anomalies
            j.lastKnownCaptureEnd = max(j.lastKnownCaptureEnd, capturedSeconds)
        }
        guard let manifest = try? files.readManifest(), !manifest.segments.isEmpty else {
            // Nothing was committed: there is no media to preserve. Report a failed start honestly.
            try? FileManager.default.removeItem(at: files.directory)
            journal = nil
            apply(.finalizeCompleted(.failed), generation: generation)
            return
        }
        let recordingDir = deps.store.layout.recordingDirectory(identity.sessionID)
        do {
            try FileManager.default.createDirectory(at: recordingDir, withIntermediateDirectories: true)
            let media = try await deps.assembler.assemble(recoveryDirectory: files.directory, manifest: manifest, into: recordingDir)
            ValidationReconciler.reconcile(report: media.validation, expectedDuration: capturedSeconds, contract: contract, ledger: &ledger)
            let required = Set(contract.requiredSources)
            let finalCompleteness: CaptureCompleteness =
                ledger.open().contains { required.contains($0.source) } ? .partial : completeness
            let playable = media.validation.result != .failed
            let outcome = FinalOutcome.make(recovered: false, completeness: finalCompleteness, playable: playable)
            let statuses = pipeline?.status() ?? []
            let metadata = RecordingMetadata(
                id: identity.sessionID, title: title, createdAt: journal?.createdAt ?? deps.wallClock.now(),
                duration: media.duration, masterFileName: media.masterFileName, byteCount: media.byteCount,
                contract: contract, outcome: outcome, completeness: finalCompleteness, validation: media.validation.result,
                libraryState: playable ? .available : .quarantined,
                sources: contract.sources.map { p in
                    let s = statuses.first { $0.source == p.kind }
                    return SourceSummary(source: p.kind, requirement: p.requirement, receivedSeconds: s?.receivedSeconds ?? 0,
                                         everReceived: s?.hasEverReceived ?? false, openAnomalySeconds: ledger.affectedSeconds(for: p.kind))
                },
                anomalies: ledger.anomalies, endReason: machine.captureEndReason,
                unmetRequirements: contract.isImportantMode ? Array(Set(ledger.open().map(\.source)).intersection(required)).sorted() : [])
            try AtomicJSON.write(media.validation, to: recordingDir.appendingPathComponent("validation.json"))
            try AtomicJSON.write(ledger, to: recordingDir.appendingPathComponent("health.json"))
            try deps.store.save(metadata)
            guard playable else { throw FinalizeError.validationFailed }
            // Recovery material is removed only after the master is validated and committed (rule 20).
            updateJournal { $0.state = .committed }
            try? FileManager.default.removeItem(at: files.directory)
            savedRecordingID = identity.sessionID
            journal = nil
            deps.diagnostics.record(.validation, session: identity.sessionID, detail: media.validation.result.rawValue)
            apply(.finalizeCompleted(outcome), generation: generation)
            apply(.writerClosed, generation: generation)
        } catch {
            deps.diagnostics.record(.error, session: identity.sessionID, detail: "finalizeFailed")
            apply(.finalizeFailed, generation: generation)
            apply(.writerClosed, generation: generation)
        }
    }

    enum FinalizeError: Error { case validationFailed }

    // MARK: Snapshot

    private func currentElapsed() -> Double {
        guard let start = firstMediaAt else { return 0 }
        return deps.clock.now().seconds(since: start)
    }

    private func makeSnapshot() -> SessionSnapshot {
        let now = deps.clock.now()
        let lifecycle = machine.lifecycle
        let elapsed = lifecycle == .capturing ? currentElapsed() : (stoppedElapsed ?? currentElapsed())
        return SessionSnapshot(
            lifecycle: lifecycle, sessionID: machine.sessionID, generation: machine.generation, contract: machine.contract,
            elapsed: elapsed, sources: pipeline?.status() ?? [], anomalies: pipeline?.anomalies ?? AnomalyLedger(),
            nonCaptureOutcome: machine.nonCaptureOutcome, finalOutcome: machine.finalOutcome, endReason: machine.captureEndReason,
            savedRecordingID: savedRecordingID, resourceState: governor.state, stopRequested: machine.stopRequested,
            canStart: machine.canStartNewSession, updatedAt: now, wallUpdatedAt: deps.wallClock.now())
    }

    private func publish() {
        let s = makeSnapshot()
        lastSnapshot = s
        for c in continuations.values { c.yield(s) }
    }
}
