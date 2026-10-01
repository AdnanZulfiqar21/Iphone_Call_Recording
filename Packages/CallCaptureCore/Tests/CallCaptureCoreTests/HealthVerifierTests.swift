import Foundation
import Testing
@testable import CallCaptureCore

@Suite("HealthVerifier and anomaly ledger (sections 6, 9, T05–T16)")
struct HealthVerifierTests {
    let clock = ManualClock()

    func verifier(_ contract: CaptureContract = screenMicContract) -> HealthVerifier {
        var v = HealthVerifier(contract: contract)
        v.captureStarted(at: clock.now())
        return v
    }

    /// Delivers continuous mic audio from `from` to `to` in 100 ms buffers.
    func feed(_ v: inout HealthVerifier, _ from: Double, _ to: Double, _ content: AudioContentSummary = .speech(), source: SourceKind = .microphone) {
        var t = from
        while t < to - 1e-9 {
            _ = v.observe(.audio(source, t, 0.1, content), at: clock.now())
            clock.advance(seconds: 0.1)
            t += 0.1
        }
    }

    @Test("T06 200 ms, 3 s and 10 s losses are each retained", arguments: [0.2, 3.0, 10.0])
    func gapsRetained(gap: Double) {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 5)
        feed(&v, 5 + gap, 8 + gap)
        let open = v.ledger.open(for: .microphone)
        #expect(open.count == 1)
        #expect(abs(open[0].range.duration - gap) < 0.02)
        #expect(open[0].reason == .ptsDiscontinuity)
        #expect(v.completeness == .partial)
    }

    @Test("T07 audio resumes: current health recovers, completeness stays partial")
    func resumeKeepsGap() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 2)
        clock.advance(seconds: 3)
        let during = v.status(at: clock.now()).first { $0.source == .microphone }!
        #expect(during.health == .limited)
        #expect(during.reason == .sourceStale)
        feed(&v, 5, 7)
        let after = v.status(at: clock.now()).first { $0.source == .microphone }!
        #expect(after.health == .checksPassing)
        #expect(v.completeness == .partial)
        #expect(StatusPresenter.persistentNotices(v.ledger).count == 1)
    }

    @Test("T09 all-zero buffers during expected speech are inconclusive, never proof")
    func allZeroAudio() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 1)
        feed(&v, 1, 6, .allZero)
        let s = v.status(at: clock.now()).first { $0.source == .microphone }!
        #expect(s.health == .limited)
        #expect(s.reason == .allZeroAudio)
        _ = v.finish(captureEnd: MediaTime(seconds: 6))
        #expect(v.ledger.open(for: .microphone).contains { $0.reason == .allZeroAudio && $0.kind == .inconclusive })
        #expect(v.completeness == .partial)
    }

    @Test("T10 genuine silence (noise floor) is not a failure")
    func silenceIsNotFailure() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 6, .silentNoiseFloor)
        let s = v.status(at: clock.now()).first { $0.source == .microphone }!
        #expect(s.health == .checksPassing)
        #expect(v.ledger.open().isEmpty)
    }

    @Test("T11 static display with idle frames is not frozen video")
    func idleFrames() {
        var v = verifier(CaptureContract.standard(mode: .screenOnly))
        _ = v.observe(.frame(0, .complete), at: clock.now())
        for i in 1...20 {
            clock.advance(seconds: 1)
            _ = v.observe(.frame(Double(i), .idle), at: clock.now())
        }
        #expect(v.status(at: clock.now())[0].health == .checksPassing)
        // No unchanged-frame timeout for video (section 15).
        clock.advance(seconds: 30)
        #expect(v.status(at: clock.now())[0].health == .checksPassing)
    }

    @Test("T12 blank, suspended and stopped frames have distinct reasons", arguments: [
        (FrameStatus.blank, CurrentSourceHealth.limited, ReasonCode.blankFrames),
        (FrameStatus.suspended, CurrentSourceHealth.limited, ReasonCode.suspendedFrames),
        (FrameStatus.stopped, CurrentSourceHealth.unavailable, ReasonCode.stoppedFrames),
    ])
    func frameStatuses(status: FrameStatus, health: CurrentSourceHealth, reason: ReasonCode) {
        var v = verifier(CaptureContract.standard(mode: .screenOnly))
        _ = v.observe(.frame(0, status), at: clock.now())
        let s = v.status(at: clock.now())[0]
        #expect(s.health == health)
        #expect(s.reason == reason)
    }

    @Test("T03 a required source that never arrives becomes unavailable and missing")
    func neverArrives() {
        var v = verifier()
        for i in 0..<16 {
            _ = v.observe(.frame(Double(i)), at: clock.now())
            clock.advance(seconds: 1)
        }
        let mic = v.status(at: clock.now()).first { $0.source == .microphone }!
        #expect(mic.health == .unavailable)
        #expect(mic.reason == .sourceNeverArrived)
        _ = v.finish(captureEnd: MediaTime(seconds: 16))
        #expect(v.ledger.open(for: .microphone).first?.reason == .sourceNeverArrived)
        #expect(v.completeness == .partial)
    }

    @Test("Optional app audio that never arrives does not make the result partial")
    func optionalSourceMissing() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 16)
        let app = v.status(at: clock.now()).first { $0.source == .appAudio }!
        #expect(app.health == .unavailable)
        #expect(StatusPresenter.source(app, lifecycle: .capturing).message == .sourceUnconfirmed(.appAudio))
        #expect(StatusPresenter.source(app, lifecycle: .capturing).tone == .neutral)
        _ = v.finish(captureEnd: MediaTime(seconds: 16))
        #expect(v.completeness == .noKnownGaps)
        #expect(!v.ledger.open(for: .appAudio).isEmpty)   // still reported
    }

    @Test("T15 invalid, duplicated and backward timestamps are rejected safely")
    func timestampFaults() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        #expect(v.observe(.audio(.microphone, 0, 0.1), at: clock.now()) == .accept)
        #expect(v.observe(.audio(.microphone, 0.1, 0.1), at: clock.now()) == .accept)
        #expect(v.observe(.audio(.microphone, 0.1, 0.1), at: clock.now()) == .reject(.ptsDuplicate))
        #expect(v.observe(.audio(.microphone, -5, 0.1), at: clock.now()) == .reject(.ptsBackward))
        let bad = SampleObservation(source: .microphone, range: MediaRange(start: MediaTime(seconds: .infinity), end: MediaTime(seconds: .infinity)))
        #expect(v.observe(bad, at: clock.now()) == .reject(.ptsInvalid))
        #expect(v.ledger.open().isEmpty)
    }

    @Test("T05/T16 a format epoch change expires old proof until new media arrives")
    func formatChange() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 1)
        v.formatChanged(.microphone)
        let s = v.status(at: clock.now()).first { $0.source == .microphone }!
        #expect(s.health == .checking)
        #expect(s.reason == .formatChanged)
        var o = SampleObservation.audio(.microphone, 1.0)
        o.formatEpoch = 1
        _ = v.observe(o, at: clock.now())
        #expect(v.status(at: clock.now()).first { $0.source == .microphone }!.health == .checksPassing)
    }

    @Test("T19 startup and tail truncation near boundaries are reported")
    func boundaries() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 1.0, 5.0)
        _ = v.finish(captureEnd: MediaTime(seconds: 7))
        let reasons = Set(v.ledger.open(for: .microphone).map(\.reason))
        #expect(reasons.contains(.startupTruncation))
        #expect(reasons.contains(.tailTruncation))
    }

    @Test("T08 writer rejection after successful capture is a visible mismatch")
    func writerRejected() {
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 2)
        v.writerRejected(.microphone, range: MediaRange(startSeconds: 0.5, endSeconds: 0.7))
        #expect(v.ledger.open(for: .microphone).first?.reason == .writerRejected)
        #expect(v.completeness == .partial)
    }

    @Test("T31 wall-clock jumps do not affect monotonic watchdogs")
    func wallClockJump() {
        let wall = FixedWallClock(Date())
        var v = verifier()
        _ = v.observe(.frame(0), at: clock.now())
        feed(&v, 0, 1)
        wall.set(Date().addingTimeInterval(-86_400))   // user changes the date
        #expect(v.status(at: clock.now()).first { $0.source == .microphone }!.health == .checksPassing)
    }

    @Test("Ledger: coalescing preserves meaning; only checkpoint evidence resolves")
    func ledgerSemantics() {
        var l = AnomalyLedger()
        l.record(Anomaly(source: .microphone, range: MediaRange(startSeconds: 1, endSeconds: 2), kind: .missing, reason: .ptsDiscontinuity))
        l.record(Anomaly(source: .microphone, range: MediaRange(startSeconds: 2, endSeconds: 3), kind: .missing, reason: .ptsDiscontinuity))
        l.record(Anomaly(source: .microphone, range: MediaRange(startSeconds: 2.5, endSeconds: 4), kind: .inconclusive, reason: .allZeroAudio))
        #expect(l.open().count == 2)
        #expect(abs(l.affectedSeconds(for: .microphone) - 3) < 1e-6)
        let id = l.open()[0].id
        let resolvedByHealth = l.resolve(id: id, because: "healthy again", evidence: .received)
        #expect(!resolvedByHealth)
        #expect(l.open().count == 2)
        let resolvedByEvidence = l.resolve(id: id, because: "recovered segment", evidence: .checkpointed)
        #expect(resolvedByEvidence)
        #expect(l.open().count == 1)
    }

    @Test("Coverage set reports internal holes")
    func coverageGaps() {
        var c = CoverageSet()
        c.insert(MediaRange(startSeconds: 0, endSeconds: 2))
        c.insert(MediaRange(startSeconds: 3, endSeconds: 5))
        c.insert(MediaRange(startSeconds: 1, endSeconds: 2.5))
        let gaps = c.gaps(within: MediaRange(startSeconds: 0, endSeconds: 6))
        #expect(gaps.count == 2)
        #expect(abs(gaps[0].duration - 0.5) < 1e-6)
        #expect(abs(gaps[1].duration - 1) < 1e-6)
    }
}
