import Foundation
import Testing
@testable import CallCaptureCore

@Suite("SessionController end-to-end with synthetic capture (P02–P06)")
struct SessionControllerTests {
    struct Harness {
        let controller: SessionController
        let engine: SyntheticCaptureEngine
        let writer: FixtureMediaWriter
        let scheduler: ManualScheduler
        let store: RecordingStore
        let layout: FileLayout
    }

    final class Free: @unchecked Sendable { var bytes: Int64; init(_ b: Int64) { bytes = b } }

    func harness(picker: SyntheticCaptureEngine.PickerResponse = .accept(microphone: true),
                 writer: FixtureMediaWriter = FixtureMediaWriter(), assembler: FixtureAssembler = FixtureAssembler(),
                 freeBytes: Int64 = 50_000_000_000, free: Free? = nil) throws -> Harness {
        let layout = FileLayout(root: temporaryRoot())
        let store = try RecordingStore(layout: layout)
        let engine = SyntheticCaptureEngine(pickerResponse: picker)
        let scheduler = ManualScheduler()
        // Tests deliver media faster than real time, so the queue bounds are widened here;
        // the bounds themselves are covered by PolicyTests (T17, T18).
        var profile = AcceptanceProfile.v1
        profile.audioQueueSeconds = 600
        profile.audioQueueBytes = 1 << 30
        profile.videoQueueBytes = 1 << 30
        profile.maxPendingTasks = 1_000_000
        let deps = SessionDependencies(engine: engine, makeWriter: { writer }, assembler: assembler, store: store,
                                       scheduler: scheduler, profile: profile, freeBytes: { free?.bytes ?? freeBytes })
        return Harness(controller: SessionController(dependencies: deps), engine: engine, writer: writer,
                       scheduler: scheduler, store: store, layout: layout)
    }

    func lifecycle(_ h: Harness) async -> Lifecycle { await h.controller.snapshot().lifecycle }

    func feed(_ h: Harness, from: Double, to: Double, mic: Bool = true) {
        var t = from
        var nextFrame = from
        while t < to - 1e-9 {
            if t >= nextFrame { h.engine.deliver(.screen, start: 1_000 + t, duration: 1.0 / 30, frame: .complete, bytes: 20_000); nextFrame += 0.5 }
            if mic { h.engine.deliver(.microphone, start: 1_000 + t, duration: 0.1, audio: .speech(), bytes: 1_000) }
            t += 0.1
        }
    }

    @Test("Normal record → stop → saved with no known gaps")
    func happyPath() async throws {
        let h = try harness()
        await h.controller.record(contract: screenMicContract, title: "Team call")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 6)
        #expect(await eventually { await lifecycle(h) == .capturing })
        await h.controller.stop()
        let afterStop = await lifecycle(h)
        #expect([.stopping, .finalizing, .finalized].contains(afterStop))
        #expect(await eventually { await lifecycle(h) == .finalized })
        let s = await h.controller.snapshot()
        #expect(s.finalOutcome == .saved)
        let id = try #require(s.savedRecordingID)
        let m = try #require(h.store.metadata(id))
        #expect(m.title == "Team call")
        #expect(m.completeness == .noKnownGaps)
        #expect(m.validation == .basicChecksPassed)
        #expect(!FileManager.default.fileExists(atPath: h.layout.recoveryDirectory(id).path))
        #expect(h.engine.stopCount == 1)
        await h.controller.acknowledgeResult()
        #expect(await lifecycle(h) == .idle)
    }

    @Test("T06/T07 a mid-session microphone gap yields 'saved with missing sections'")
    func gapIsPartial() async throws {
        let h = try harness()
        await h.controller.record(contract: screenMicContract, title: "Gap")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 4)
        feed(h, from: 4, to: 7, mic: false)
        feed(h, from: 7, to: 10)
        #expect(await eventually { !(await h.controller.snapshot().anomalies.open().isEmpty) })
        let live = await h.controller.snapshot()
        #expect(live.sources.first { $0.source == .microphone }?.health == .checksPassing)   // current health recovered
        await h.controller.stop()
        #expect(await eventually { await lifecycle(h) == .finalized })
        let s = await h.controller.snapshot()
        #expect(s.finalOutcome == .savedPartial)
        let savedID = try #require(s.savedRecordingID)
        let m = try #require(h.store.metadata(savedID))
        let gap = try #require(m.openAnomalies.first { $0.source == .microphone })
        #expect(abs(gap.range.start.seconds - 4) < 0.15)
        #expect(abs(gap.range.end.seconds - 7) < 0.15)
    }

    @Test("T08 capture succeeds but the writer rejects microphone input")
    func writerRejects() async throws {
        let h = try harness(writer: FixtureMediaWriter(behaviour: .rejectSource(.microphone)))
        await h.controller.record(contract: screenMicContract, title: "Rejected")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 5)
        await h.controller.stop()
        #expect(await eventually { await lifecycle(h) == .finalized })
        #expect(await h.controller.snapshot().finalOutcome == .savedPartial)
    }

    @Test("T02 cancellation creates no recording and no success state")
    func cancelled() async throws {
        let h = try harness(picker: .cancel)
        await h.controller.record(contract: screenMicContract, title: "x")
        #expect(await eventually { await lifecycle(h) == .cancelled })
        let s = await h.controller.snapshot()
        #expect(s.nonCaptureOutcome == .userCancelled)
        #expect(s.headline.tone != .pass)
        #expect(h.store.all().isEmpty)
        #expect(s.canStart)
    }

    @Test("Insufficient storage blocks start with a reason")
    func noStorage() async throws {
        let h = try harness(freeBytes: 10_000_000)
        await h.controller.record(contract: screenMicContract, title: "x")
        #expect(await eventually { await lifecycle(h) == .failed })
        #expect(await h.controller.snapshot().nonCaptureOutcome == .insufficientStorage)
        #expect(h.engine.startCount == 0)
    }

    @Test("T21 finalization never completes: recovery preserved, app stays usable, no second writer")
    func finalizeHangs() async throws {
        let h = try harness(writer: FixtureMediaWriter(behaviour: .hangOnFinish))
        await h.controller.record(contract: screenMicContract, title: "Hang")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 5)
        await h.controller.stop()
        #expect(await eventually { await lifecycle(h) == .finalizing })
        await h.scheduler.fire(after: 30)
        #expect(await lifecycle(h) == .failed)
        let s = await h.controller.snapshot()
        #expect(!s.canStart)   // writer lease still held until it confirms closure
        let id = try #require(s.sessionID)
        let journal = try RecoveryFiles(directory: h.layout.recoveryDirectory(id)).readJournal()
        #expect(journal.state == .needsRecovery)
        #expect(await eventually { await h.controller.snapshot().canStart })   // cancel completed → lease released
        await h.controller.record(contract: screenMicContract, title: "Next")
        #expect(await eventually { await h.controller.snapshot().generation == 2 })
    }

    @Test("T20 stop while accepted work remains: drain deadline turns leftovers into explicit loss")
    func drainDeadline() async throws {
        let h = try harness(writer: FixtureMediaWriter(behaviour: .notReadyTimes(1_000_000)))
        await h.controller.record(contract: screenMicContract, title: "Drain")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 1)
        await h.controller.stop()
        await h.scheduler.fire(after: 5)
        #expect(await eventually { await lifecycle(h) != .stopping })
        let s = await h.controller.snapshot()
        #expect(s.anomalies.open().contains { $0.reason == .drainTimeout } || s.lifecycle == .finalized || s.lifecycle == .failed)
    }

    @Test("T04 late callbacks from a previous session are ignored")
    func lateCallbacks() async throws {
        let h = try harness()
        await h.controller.record(contract: screenMicContract, title: "One")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 3)
        await h.controller.stop()
        #expect(await eventually { await lifecycle(h) == .finalized })
        await h.controller.acknowledgeResult()
        await h.controller.record(contract: screenMicContract, title: "Two")
        #expect(await eventually { await lifecycle(h) == .starting })
        h.engine.emit(.stopped(.streamStoppedBySystem), generation: 1)
        h.engine.deliver(.microphone, start: 5_000, duration: 0.1, audio: .speech(), generation: 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await lifecycle(h) == .starting)
    }

    @Test("Important mode: unconfirmed required app audio at the startup deadline stops safely and keeps media")
    func importantModeProtectedStop() async throws {
        let h = try harness()
        let contract = CaptureContract.standard(mode: .screenAndAudio, importantMode: true)
        await h.controller.record(contract: contract, title: "Important")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 16)   // screen + mic only; app audio never arrives
        #expect(await eventually { await lifecycle(h) == .capturing })
        // Startup deadline evaluation uses the monotonic clock; advance past it via the real clock wait.
        try await Task.sleep(nanoseconds: 50_000_000)
        await h.scheduler.fire(after: 15)
        #expect(await eventually { await lifecycle(h) == .finalized })
        let s = await h.controller.snapshot()
        #expect(s.endReason == .sourceNeverArrived)
        #expect(s.finalOutcome == .savedPartial)
        let id = try #require(s.savedRecordingID)
        let m = try #require(h.store.metadata(id))
        #expect(m.unmetRequirements == [.appAudio])
    }

    @Test("T26/T36 storage reaching the reserve during capture stops safely and keeps media")
    func lowStorageProtectedStop() async throws {
        let free = Free(50_000_000_000)
        let h = try harness(free: free)
        await h.controller.record(contract: screenMicContract, title: "Low space")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 4)
        #expect(await eventually { await lifecycle(h) == .capturing })
        free.bytes = 100_000_000   // below the reserve
        await h.scheduler.fire(after: 1)   // resource evaluation tick
        #expect(await eventually { await lifecycle(h) == .finalized })
        let s = await h.controller.snapshot()
        #expect(s.endReason == .diskFull)
        #expect(s.savedRecordingID != nil)
        #expect(s.headline.message == .savedNoKnownGaps || s.headline.message == .savedWithMissingSections)
    }

    @Test("Microphone turned off in the system picker makes it optional, not missing")
    func micOffInPicker() async throws {
        let h = try harness(picker: .accept(microphone: false))
        await h.controller.record(contract: screenMicContract, title: "No mic")
        #expect(await eventually { await lifecycle(h) == .starting })
        feed(h, from: 0, to: 4, mic: false)
        await h.controller.stop()
        #expect(await eventually { await lifecycle(h) == .finalized })
        #expect(await h.controller.snapshot().finalOutcome == .saved)
    }
}
