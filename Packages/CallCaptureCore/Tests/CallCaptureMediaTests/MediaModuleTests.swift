import Foundation
import Testing
@testable import CallCaptureCore
@testable import CallCaptureMedia

@Test func mediaModuleLoads() {
    #expect(CallCaptureMediaInfo.moduleVersion == 1)
}

#if canImport(AVFoundation)
import AVFoundation

private func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("ccm-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private final class CheckpointCollector: @unchecked Sendable {
    let lock = NSLock()
    var reports: [CheckpointReport] = []
    func add(_ r: CheckpointReport) { lock.withLock { reports.append(r) } }
    var all: [CheckpointReport] { lock.withLock { reports } }
}

private func log(_ s: String) {
    FileHandle.standardError.write(Data(("[media-test] " + s + "\n").utf8))
}

/// Feeds real buffers into the production writer, honouring backpressure like the pipeline does.
/// Returns counts so a stalled writer fails the test instead of hanging it.
@discardableResult
private func write(_ writer: SegmentedTrackWriter, _ observations: [SampleObservation], origin: Double) async -> (accepted: Int, other: Int) {
    var accepted = 0, other = 0
    for (i, o) in observations.enumerated() {
        let sample = CapturedSample(observation: o, payload: SyntheticMediaFactory.payload(for: o))
        let session = MediaRange(startSeconds: o.range.start.seconds - origin, endSeconds: o.range.end.seconds - origin)
        var attempts = 0
        var result = writer.append(sample, sessionTime: session)
        while result == .notReady && attempts < 100 {
            attempts += 1
            try? await Task.sleep(nanoseconds: 2_000_000)
            result = writer.append(sample, sessionTime: session)
        }
        if result == .accepted { accepted += 1 } else {
            other += 1
            if other <= 3 || other % 200 == 0 { log("sample \(i) \(o.source.rawValue) -> \(result) \(writer.diagnosticSummary)") }
            if other > 50 && accepted == 0 { log("writer stalled; aborting feed"); break }
        }
    }
    log("fed \(observations.count): accepted \(accepted), other \(other); \(writer.diagnosticSummary)")
    return (accepted, other)
}

private func observations(seconds: Double, origin: Double = 100, micGap: ClosedRange<Double>? = nil) -> [SampleObservation] {
    var list: [SampleObservation] = []
    var t = 0.0
    var frame = 0.0
    while t < seconds - 1e-9 {
        while frame <= t {
            list.append(SampleObservation(source: .screen, range: MediaRange(startSeconds: origin + frame, endSeconds: origin + frame + 1.0 / 30),
                                          frame: .complete, byteCount: 1))
            frame += 1.0 / 30
        }
        if micGap.map({ !$0.contains(t) }) ?? true {
            list.append(SampleObservation(source: .microphone, range: MediaRange(startSeconds: origin + t, endSeconds: origin + t + 0.02),
                                          audio: .speech(level: 0.3), byteCount: 1))
        }
        t += 0.02
    }
    return list.sorted { $0.range.start < $1.range.start }
}

@Suite("Production media writer, assembler and validator (P04/P05, SYNTHETIC_TESTED)", .timeLimit(.minutes(3)))
struct MediaPipelineTests {
    let contract = CaptureContract.standard(mode: .screenAndAudio)

    @Test("Audio analysis distinguishes tone, all-zero and clipping")
    func audioAnalysis() throws {
        let tone = try #require(SyntheticMediaFactory.audioBuffer(pts: 0, duration: 0.1, frequency: 440, amplitude: 0.5))
        let s = try #require(AudioAnalyzer.summarize(tone))
        #expect(!s.isAllZero)
        #expect(abs(s.peak - 0.5) < 0.05)
        let zero = try #require(SyntheticMediaFactory.audioBuffer(pts: 0, duration: 0.1, frequency: 0, amplitude: 0))
        #expect(AudioAnalyzer.summarize(zero)?.isAllZero == true)
        let loud = try #require(SyntheticMediaFactory.audioBuffer(pts: 0, duration: 0.1, frequency: 440, amplitude: 1.2))
        #expect((AudioAnalyzer.summarize(loud)?.clippedFraction ?? 0) > 0.05)
    }

    @Test("Writer commits per-track segments with explicit checkpoints; master assembles and validates")
    func writeAssembleValidate() async throws {
        let root = tempDir()
        let recovery = root.appendingPathComponent("recovery")
        let collector = CheckpointCollector()
        let writer = SegmentedTrackWriter()
        let identity = SessionIdentity(sessionID: UUID(), generation: 1, contractVersion: 1)
        try writer.open(identity: identity, contract: contract, recoveryDirectory: recovery) { collector.add($0) }
        let fed = await write(writer, observations(seconds: 7), origin: 100)
        #expect(fed.accepted > 500)
        log("finishing writer")
        let report = await writer.finish()
        log("writer finished: \(String(describing: report.error))")
        #expect(report.error == nil)

        let manifest = try RecoveryFiles(directory: recovery).readManifest()
        #expect(Set(manifest.tracks.map(\.source)) == [.screen, .microphone])
        #expect(manifest.segments(for: .screen).count >= 2)
        #expect(manifest.segments(for: .microphone).count >= 2)
        #expect(collector.all.count == manifest.segments.count)
        // Checkpoints cover the timeline contiguously per track (section 10.3).
        for source in [SourceKind.screen, .microphone] {
            let segs = manifest.segments(for: source)
            for (a, b) in zip(segs, segs.dropFirst()) { #expect(abs(b.sessionRange.start.seconds - a.sessionRange.end.seconds) < 0.1) }
        }

        let recordingDir = root.appendingPathComponent("recording")
        try FileManager.default.createDirectory(at: recordingDir, withIntermediateDirectories: true)
        log("assembling \(manifest.segments.count) segments")
        let media = try await MediaAssembler().assemble(recoveryDirectory: recovery, manifest: manifest, into: recordingDir)
        log("assembled: \(media.validation.notes) durations=\(media.validation.durations)")
        #expect(media.validation.result == .basicChecksPassed)
        #expect(abs(media.duration - 7) < 0.6)
        #expect(media.tracks == [.screen, .microphone])
        #expect(media.validation.sha256?.count == 64)

        let url = recordingDir.appendingPathComponent(media.masterFileName)
        var full = media.validation
        for _ in 0..<50 where full.coverage != .full {
            full = try await RecordingValidator.full(url: url, sources: media.tracks, previous: full, chunkSeconds: 3)
        }
        #expect(full.result == .fullChecksPassed)
        #expect(full.detectedRanges.isEmpty)
    }

    @Test("T06 a microphone hole survives writing and is detected by FULL validation")
    func gapDetectedInFile() async throws {
        let root = tempDir()
        let recovery = root.appendingPathComponent("recovery")
        let writer = SegmentedTrackWriter()
        try writer.open(identity: SessionIdentity(sessionID: UUID(), generation: 1, contractVersion: 1), contract: contract,
                        recoveryDirectory: recovery) { _ in }
        await write(writer, observations(seconds: 9, micGap: 3.0...5.99), origin: 100)
        _ = await writer.finish()
        let manifest = try RecoveryFiles(directory: recovery).readManifest()
        let recordingDir = root.appendingPathComponent("recording")
        try FileManager.default.createDirectory(at: recordingDir, withIntermediateDirectories: true)
        let media = try await MediaAssembler().assemble(recoveryDirectory: recovery, manifest: manifest, into: recordingDir)
        var full = media.validation
        for _ in 0..<50 where full.coverage != .full {
            full = try await RecordingValidator.full(url: recordingDir.appendingPathComponent(media.masterFileName),
                                                     sources: media.tracks, previous: full, chunkSeconds: 4)
        }
        let hole = full.detectedRanges.first { $0.start.seconds > 2.5 && $0.end.seconds < 6.6 }
        #expect(hole != nil, "detected: \(full.detectedRanges)")
    }

    @Test("T16 an audio format change starts a new epoch part and still assembles")
    func formatEpoch() async throws {
        let root = tempDir()
        let recovery = root.appendingPathComponent("recovery")
        let writer = SegmentedTrackWriter()
        try writer.open(identity: SessionIdentity(sessionID: UUID(), generation: 1, contractVersion: 1), contract: contract,
                        recoveryDirectory: recovery) { _ in }
        var t = 0.0
        while t < 6 {
            let rate = t < 3 ? 48_000.0 : 44_100.0
            if let b = SyntheticMediaFactory.audioBuffer(pts: 100 + t, duration: 0.02, frequency: 440, amplitude: 0.3, sampleRate: rate) {
                let o = SampleObservation(source: .microphone, range: MediaRange(startSeconds: 100 + t, endSeconds: 100 + t + 0.02),
                                          audio: .speech(), byteCount: 1)
                var tries = 0
                while writer.append(CapturedSample(observation: o, payload: SampleBufferPayload(b)),
                                    sessionTime: MediaRange(startSeconds: t, endSeconds: t + 0.02)) == .notReady && tries < 500 {
                    tries += 1
                    try? await Task.sleep(nanoseconds: 2_000_000)
                }
            }
            t += 0.02
        }
        _ = await writer.finish()
        let manifest = try RecoveryFiles(directory: recovery).readManifest()
        #expect(Set(manifest.tracks.map { $0.epoch ?? 0 }) == [0, 1])
        let recordingDir = root.appendingPathComponent("recording")
        try FileManager.default.createDirectory(at: recordingDir, withIntermediateDirectories: true)
        let media = try await MediaAssembler().assemble(recoveryDirectory: recovery, manifest: manifest, into: recordingDir)
        #expect(media.validation.result == .basicChecksPassed)
        #expect(abs(media.duration - 6) < 0.6)
    }

    @Test("T24 recovery from committed segments after an abandoned writer")
    func recoveryFromSegments() async throws {
        let layout = FileLayout(root: tempDir())
        let store = try RecordingStore(layout: layout)
        let id = UUID()
        let recovery = layout.recoveryDirectory(id)
        let writer = SegmentedTrackWriter()
        let identity = SessionIdentity(sessionID: id, generation: 1, contractVersion: 1)
        try writer.open(identity: identity, contract: contract, recoveryDirectory: recovery) { _ in }
        var journal = RecoveryJournal(identity: identity, contract: contract, createdAt: Date(), title: "Crashed")
        journal.lastKnownCaptureEnd = 8
        try RecoveryFiles(directory: recovery).writeJournal(journal)
        await write(writer, observations(seconds: 8), origin: 100)
        await writer.cancel()   // simulates termination: no finishWriting, only committed segments remain

        let manager = RecoveryManager(layout: layout, store: store)
        let candidate = try #require(manager.scan().first)
        #expect(candidate.status == .recoverable)
        let m = try await manager.recover(candidate, assembler: MediaAssembler())
        #expect(m.outcome == .recoveredPartial || m.outcome == .recovered)
        #expect(m.outcome != .saved)
        #expect(m.duration > 3)
        #expect(m.anomalies.contains { $0.reason == .processTerminated })
    }

    @Test("End-to-end: SessionController + synthetic engine + production writer")
    func controllerEndToEnd() async throws {
        let layout = FileLayout(root: tempDir())
        let store = try RecordingStore(layout: layout)
        let engine = SyntheticCaptureEngine(pickerResponse: .accept(microphone: true))
        engine.payloadFactory = SyntheticMediaFactory.payload(for:)
        var profile = AcceptanceProfile.v1
        profile.audioQueueSeconds = 600
        profile.audioQueueBytes = 1 << 30
        profile.videoQueueBytes = 1 << 30
        profile.maxPendingTasks = 1_000_000
        let deps = SessionDependencies(engine: engine, makeWriter: { SegmentedTrackWriter() }, assembler: MediaAssembler(),
                                       store: store, profile: profile, freeBytes: { 50_000_000_000 })
        let controller = SessionController(dependencies: deps)
        await controller.record(contract: contract, title: "E2E")
        for _ in 0..<200 {
            if await controller.snapshot().lifecycle == .starting { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        for o in observations(seconds: 5, origin: 1_000) {
            engine.deliver(o.source, start: o.range.start.seconds, duration: o.range.duration, audio: o.audio, frame: o.frame)
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        await controller.stop()
        for _ in 0..<1_500 {
            let l = await controller.snapshot().lifecycle
            if l == .finalized || l == .failed { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let s = await controller.snapshot()
        #expect(s.lifecycle == .finalized)
        #expect(s.finalOutcome == .saved || s.finalOutcome == .savedPartial)
        let saved = try #require(s.savedRecordingID)
        let m = try #require(store.metadata(saved))
        #expect(m.validation == .basicChecksPassed)
        #expect(FileManager.default.fileExists(atPath: layout.recordingDirectory(saved).appendingPathComponent("master.mov").path))
    }
}
#endif
