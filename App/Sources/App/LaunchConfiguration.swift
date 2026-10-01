import Foundation
import CallCaptureCore
#if DEBUG
import CallCaptureMedia
#endif

/// Launch-time configuration. In shipping builds this is always `.production`; the DEBUG-only
/// fixture switches below cannot be selected in Release (P03, section 18).
struct LaunchConfiguration {
    var defaults: UserDefaults = .standard
    var storageRoot: URL?
    var resetData = false
    var skipOnboarding = false
    var freeBytesOverride: Int64?
    var thermalOverride: ThermalLevel?
    #if DEBUG
    var scenario: String?
    var picker: String?
    var seedLibraryCount = 0
    var seedMediaRecording = false
    #endif

    static var production: LaunchConfiguration { LaunchConfiguration() }

    static var current: LaunchConfiguration {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        guard args.contains("-UITestMode") else { return .production }
        var c = LaunchConfiguration()
        let suite = "CallCaptureUITests"
        UserDefaults().removePersistentDomain(forName: suite)
        c.defaults = UserDefaults(suiteName: suite) ?? .standard
        c.storageRoot = FileManager.default.temporaryDirectory.appendingPathComponent("CallCaptureUITest", isDirectory: true)
        c.resetData = true
        c.skipOnboarding = !args.contains("-UITestShowOnboarding")
        c.scenario = value("-UITestScenario")
        c.picker = value("-UITestPicker")
        c.seedLibraryCount = Int(value("-UITestSeedLibrary") ?? "") ?? 0
        c.seedMediaRecording = args.contains("-UITestSeedMedia")
        if let free = value("-UITestFreeBytes").flatMap(Int64.init) { c.freeBytesOverride = free }
        if let thermal = value("-UITestThermal").flatMap(ThermalLevel.init(rawValue:)) { c.thermalOverride = thermal }
        if let appearance = value("-UITestAppearance") { c.defaults.set(appearance, forKey: "appearance") }
        if args.contains("-UITestNoConsentReminder") { c.defaults.set(false, forKey: "consentReminder") }
        return c
        #else
        return .production
        #endif
    }

    #if DEBUG
    /// Synthetic capture for simulator UI tests: real writer and assembler, synthetic input.
    func syntheticEngine() -> (any CaptureEngine)? {
        guard scenario != nil || picker != nil else { return nil }
        let response: SyntheticCaptureEngine.PickerResponse = switch picker {
        case "cancel": .cancel
        case "deny": .deny
        case "unsupported": .unsupported
        case "nomic": .accept(microphone: false)
        default: .accept(microphone: true)
        }
        let engine = SyntheticCaptureEngine(pickerResponse: response, scenario: SyntheticScenario.named(scenario ?? "normal"))
        engine.payloadFactory = SyntheticMediaFactory.payload(for:)
        return engine
    }

    /// Seeds metadata-only rows (UX12) and/or one real media recording with a known gap (UX13).
    @MainActor
    func seed(into store: RecordingStore, layout: FileLayout) async {
        if seedLibraryCount > 0 {
            let contract = CaptureContract.standard(mode: .screenAndAudio)
            let titles = ["Supplier call — pricing", "Interview with Sana", "دادی جان سے بات چیت — family call",
                          "Landlord — deposit return discussion and agreed dates for the final inspection", "Weekly planning", "Café meeting"]
            for i in 0..<seedLibraryCount {
                let outcome: FinalOutcome = i % 7 == 0 ? .savedPartial : (i % 11 == 0 ? .recovered : .saved)
                var m = RecordingMetadata(id: UUID(), title: "\(titles[i % titles.count]) \(i + 1)",
                                          createdAt: Date().addingTimeInterval(Double(-i) * 3_700), duration: Double(60 + (i * 37) % 3_000),
                                          masterFileName: nil, byteCount: 1_000_000 + i * 1_000, contract: contract, outcome: outcome,
                                          completeness: outcome == .saved ? .noKnownGaps : .partial, validation: .basicChecksPassed,
                                          libraryState: .available, sources: [], anomalies: [])
                if i % 9 == 0 { m.bookmarks = [Bookmark(time: 30, label: "Important")] }
                try? store.save(m)
            }
        }
        if seedMediaRecording {
            await FixtureRecordingBuilder.build(store: store, layout: layout)
        }
    }
    #endif
}

#if DEBUG
/// Builds a real 20-second recording with a microphone gap at 00:06–00:09 via the production writer.
enum FixtureRecordingBuilder {
    static func build(store: RecordingStore, layout: FileLayout) async {
        let id = UUID()
        let contract = CaptureContract.standard(mode: .screenAndAudio)
        let identity = SessionIdentity(sessionID: id, generation: 1, contractVersion: 1)
        let recovery = layout.recoveryDirectory(id)
        let writer = SegmentedTrackWriter()
        guard (try? writer.open(identity: identity, contract: contract, recoveryDirectory: recovery, onCheckpoint: { _ in })) != nil else { return }
        var t = 0.0, frame = 0.0
        while t < 20 {
            while frame <= t {
                let o = SampleObservation(source: .screen, range: MediaRange(startSeconds: 500 + frame, endSeconds: 500 + frame + 1.0 / 30), frame: .complete)
                await append(writer, o, t: frame)
                frame += 1.0 / 30
            }
            if !(6..<9).contains(t) {
                let o = SampleObservation(source: .microphone, range: MediaRange(startSeconds: 500 + t, endSeconds: 500 + t + 0.02), audio: .speech())
                await append(writer, o, t: t)
            }
            t += 0.02
        }
        _ = await writer.finish()
        guard let manifest = try? RecoveryFiles(directory: recovery).readManifest() else { return }
        let dir = layout.recordingDirectory(id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let media = try? await MediaAssembler().assemble(recoveryDirectory: recovery, manifest: manifest, into: dir) else { return }
        var ledger = AnomalyLedger()
        ledger.record(Anomaly(source: .microphone, range: MediaRange(startSeconds: 6, endSeconds: 9), kind: .missing, reason: .ptsDiscontinuity))
        let m = RecordingMetadata(id: id, title: "Supplier call — pricing", createdAt: Date(), duration: media.duration,
                                  masterFileName: media.masterFileName, byteCount: media.byteCount, contract: contract,
                                  outcome: .savedPartial, completeness: .partial, validation: media.validation.result,
                                  libraryState: .available,
                                  sources: [SourceSummary(source: .screen, requirement: .required, receivedSeconds: 20, everReceived: true, openAnomalySeconds: 0),
                                            SourceSummary(source: .microphone, requirement: .required, receivedSeconds: 17, everReceived: true, openAnomalySeconds: 3),
                                            SourceSummary(source: .appAudio, requirement: .optional, receivedSeconds: 0, everReceived: false, openAnomalySeconds: 20)],
                                  anomalies: ledger.anomalies, bookmarks: [Bookmark(time: 14, label: "Price agreed")])
        try? AtomicJSON.write(media.validation, to: dir.appendingPathComponent("validation.json"))
        try? store.save(m)
        try? FileManager.default.removeItem(at: recovery)
    }

    private static func append(_ writer: SegmentedTrackWriter, _ o: SampleObservation, t: Double) async {
        let sample = CapturedSample(observation: o, payload: SyntheticMediaFactory.payload(for: o))
        let range = MediaRange(startSeconds: t, endSeconds: t + o.range.duration)
        var tries = 0
        while writer.append(sample, sessionTime: range) == .notReady && tries < 300 {
            tries += 1
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}
#endif
