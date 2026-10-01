import SwiftUI
import CallCaptureCore
import CallCaptureMedia

/// Composition root and UI projection of authoritative state. Views read this model;
/// only SessionController decides lifecycle and outcomes.
@MainActor @Observable
final class AppModel {
    let settings: AppSettings
    let layout: FileLayout
    let store: RecordingStore
    let diagnostics: DiagnosticsLog
    let controller: SessionController
    let recovery: RecoveryManager
    let entitlements: EntitlementService
    let liveActivity: LiveActivityController
    let captureAvailable: Bool
    let launchConfiguration: LaunchConfiguration

    private(set) var session: SessionSnapshot
    private(set) var library: [LibraryRow] = []
    private(set) var unreadable: [UnreadableRecord] = []
    private(set) var recoveryCandidates: [RecoveryCandidate] = []
    private(set) var recoveredNotice: [RecordingMetadata] = []
    private(set) var freeBytes: Int64 = 0
    private(set) var isRecovering = false
    var selectedTab: AppTab = .record
    var presentedResultID: UUID?
    var pendingStartAfterReminder = false

    private var validationTask: Task<Void, Never>?

    init(launch: LaunchConfiguration = .current) {
        self.launchConfiguration = launch
        let settings = AppSettings(defaults: launch.defaults)
        if launch.skipOnboarding { settings.hasCompletedOnboarding = true }
        self.settings = settings
        let layout: FileLayout
        do {
            layout = try launch.storageRoot.map(FileLayout.init(root:)) ?? FileLayout.applicationSupport()
        } catch {
            layout = FileLayout(root: FileManager.default.temporaryDirectory.appendingPathComponent("CallCapture"))
        }
        if launch.resetData { try? FileManager.default.removeItem(at: layout.root) }
        self.layout = layout
        // Store creation failing would leave no safe place for media; fail loudly in development.
        let store = try! RecordingStore(layout: layout)
        self.store = store
        let diagnostics = DiagnosticsLog()
        self.diagnostics = diagnostics
        let engine = AppModel.makeEngine(launch: launch)
        self.captureAvailable = engine.isAvailable
        let freeOverride = launch.freeBytesOverride
        let freeBytesProvider: @Sendable () -> Int64 = { freeOverride ?? StorageInfo.freeBytes(at: layout.root) }
        let deps = SessionDependencies(
            engine: engine, makeWriter: { SegmentedTrackWriter() }, assembler: MediaAssembler(), store: store,
            diagnostics: diagnostics, freeBytes: freeBytesProvider)
        self.controller = SessionController(dependencies: deps)
        self.recovery = RecoveryManager(layout: layout, store: store)
        self.entitlements = EntitlementService(defaults: launch.defaults)
        self.liveActivity = LiveActivityController()
        self.session = .idle(now: SystemMonotonicClock().now(), wall: Date())
    }

    private static func makeEngine(launch: LaunchConfiguration) -> any CaptureEngine {
        #if DEBUG
        if let engine = launch.syntheticEngine() { return engine }
        #endif
        #if canImport(ScreenCaptureKit)
        // ScreenCaptureKit is in the iOS 27 device SDK; the simulator SDK may not provide it,
        // in which case Start explains that capture is unavailable (simulator runs use fixtures).
        if #available(iOS 27.0, *) {
            return ScreenCaptureKitEngine()
        }
        #endif
        return UnavailableCaptureEngine()
    }

    // MARK: Launch

    func start() async {
        try? store.reconcileDeletions()
        store.reload()
        #if DEBUG
        await launchConfiguration.seed(into: store, layout: layout)
        store.reload()
        #endif
        refreshLibrary()
        refreshStorage()
        await entitlements.start()
        await runLaunchRecovery()
        Task { await observeSession() }
        scheduleFullValidation()
    }

    private func observeSession() async {
        for await snapshot in await controller.updates() {
            let previous = session
            session = snapshot
            liveActivity.update(with: snapshot)
            if previous.lifecycle != snapshot.lifecycle {
                diagnostics.record(.lifecycle, session: snapshot.sessionID, detail: snapshot.lifecycle.rawValue)
                if snapshot.lifecycle == .finalized || snapshot.lifecycle == .failed {
                    refreshLibrary()
                    refreshStorage()
                    if let id = snapshot.savedRecordingID { presentedResultID = id }
                    scheduleFullValidation()
                }
            }
        }
    }

    // MARK: Recording

    var isSessionActive: Bool { session.lifecycle.isActive }

    func requestStart() {
        guard session.canStart else { return }
        if settings.consentReminder {
            pendingStartAfterReminder = true
        } else {
            beginRecording()
        }
    }

    func beginRecording() {
        pendingStartAfterReminder = false
        let title = Date().formatted(.dateTime.day().month(.abbreviated).hour().minute())
        let contract = settings.contract
        Task { await controller.record(contract: contract, title: String(localized: "Recording \(title)")) }
    }

    func stop() {
        Task { await controller.stop() }
    }

    func acknowledgeResult() {
        Task { await controller.acknowledgeResult() }
    }

    // MARK: Library

    func refreshLibrary() {
        library = store.all().map(LibraryRow.init)
        unreadable = store.unreadable
    }

    func refreshStorage() {
        freeBytes = launchConfiguration.freeBytesOverride ?? StorageInfo.freeBytes(at: layout.root)
    }

    func metadata(_ id: UUID) -> RecordingMetadata? { store.metadata(id) }

    func masterURL(_ id: UUID) -> URL? { store.metadata(id).flatMap(store.masterURL) }

    func rename(_ id: UUID, to title: String) {
        try? store.rename(id, to: title)
        refreshLibrary()
    }

    func delete(_ id: UUID) {
        do {
            try store.delete(id)
            diagnostics.record(.deletion, session: id, detail: "completed")
        } catch {
            diagnostics.record(.deletion, session: id, detail: "pendingRetry")
        }
        refreshLibrary()
        refreshStorage()
    }

    func addBookmark(_ id: UUID, at time: Double, label: String) {
        _ = try? store.addBookmark(id, at: time, label: label)
        refreshLibrary()
    }

    func removeBookmark(_ id: UUID, bookmark: UUID) {
        try? store.removeBookmark(id, bookmark: bookmark)
        refreshLibrary()
    }

    // MARK: Recovery (section 11)

    func runLaunchRecovery() async {
        let candidates = recovery.scan(activeSessionID: session.sessionID)
        recovery.cleanCommitted(candidates)
        isRecovering = true
        var recovered: [RecordingMetadata] = []
        for c in candidates where c.status == .recoverable {
            if let m = try? await recovery.recover(c, assembler: MediaAssembler()) {
                recovered.append(m)
                diagnostics.record(.recovery, session: c.id, detail: m.outcome.rawValue)
            } else {
                diagnostics.record(.recovery, session: c.id, detail: "attemptFailed")
            }
        }
        isRecovering = false
        recoveredNotice = recovered
        recoveryCandidates = recovery.scan(activeSessionID: session.sessionID).filter { $0.status != .alreadyCommitted }
        refreshLibrary()
    }

    /// Explicit retry is separate from the automatic budget (section 15).
    func retryRecovery(_ candidate: RecoveryCandidate) async {
        guard !isSessionActive else { return }   // no conflicting writer/recovery work (section 11)
        _ = try? await recovery.recover(candidate, assembler: MediaAssembler())
        recoveryCandidates = recovery.scan(activeSessionID: session.sessionID).filter { $0.status != .alreadyCommitted }
        refreshLibrary()
    }

    func dismissRecoveredNotice() { recoveredNotice = [] }

    // MARK: Full validation (section 12) — outside active capture, bounded and resumable

    func scheduleFullValidation() {
        validationTask?.cancel()
        validationTask = Task { [weak self] in
            guard let self else { return }
            for row in self.store.all() where row.validation == .basicChecksPassed && row.masterFileName != nil {
                if Task.isCancelled || self.isSessionActive { return }
                await self.validateFully(row.id)
            }
        }
    }

    private func validateFully(_ id: UUID) async {
        guard let m = store.metadata(id), let url = store.masterURL(m) else { return }
        let reportURL = layout.recordingDirectory(id).appendingPathComponent("validation.json")
        guard var report = try? AtomicJSON.read(ValidationReport.self, from: reportURL) else { return }
        // Track order in the master follows source order among the tracks it actually contains.
        let sources = SourceKind.allCases.filter { report.durations[$0.rawValue] != nil }
        while report.coverage != .full {
            if Task.isCancelled || isSessionActive { return }   // capture always wins (rule 10)
            guard let next = try? await RecordingValidator.full(url: url, sources: sources, previous: report) else { return }
            report = next
            try? AtomicJSON.write(report, to: reportURL)
        }
        try? store.update(id) { meta in
            var ledger = AnomalyLedger(anomalies: meta.anomalies)
            ValidationReconciler.reconcile(report: report, expectedDuration: meta.duration, contract: meta.contract, ledger: &ledger)
            meta.anomalies = ledger.anomalies
            meta.validation = report.result
            if report.result == .failed { meta.libraryState = .quarantined }
            let required = Set(meta.contract.requiredSources)
            if ledger.open().contains(where: { required.contains($0.source) }) {
                meta.completeness = .partial
                meta.outcome = meta.outcome.isRecovered ? .recoveredPartial : (meta.outcome == .failed ? .failed : .savedPartial)
            }
        }
        diagnostics.record(.validation, session: id, detail: report.result.rawValue)
        refreshLibrary()
    }

    // MARK: Start availability

    var startDisabledReason: String? {
        if !captureAvailable { return String(localized: "Screen recording isn't available on this device or iOS version.") }
        if !session.canStart && !isSessionActive { return String(localized: "Finishing the previous recording…") }
        let reserve = StorageReserve.forMode(settings.captureMode)
        if !reserve.canStart(freeBytes: freeBytes) { return String(localized: "Free up space to record safely.") }
        return nil
    }

    var storageEstimate: String {
        let range = StorageReserve.forMode(settings.captureMode).estimatedSeconds(freeBytes: freeBytes)
        guard range.upperBound > 60 else { return String(localized: "Not enough space") }
        let hours = range.lowerBound / 3_600
        if hours >= 1 { return String(localized: "About \(Int(hours.rounded(.down)))–\(Int((range.upperBound / 3_600).rounded(.up))) h of recording") }
        return String(localized: "About \(Int(range.lowerBound / 60)) min of recording")
    }
}

enum AppTab: Hashable { case record, recordings, settings }

enum StorageInfo {
    static func freeBytes(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let v = values?.volumeAvailableCapacityForImportantUsage { return v }
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
}

/// Used where no supported capture API exists. Start explains the limitation instead of failing silently.
final class UnavailableCaptureEngine: CaptureEngine, @unchecked Sendable {
    var isAvailable: Bool { false }
    func presentPicker(contract: CaptureContract, generation: Int, sink: @escaping CaptureEventSink) {
        sink(generation, .unsupported("noCaptureAPI"))
    }
    func startCapture(generation: Int) async {}
    func stopCapture(generation: Int) async {}
}
