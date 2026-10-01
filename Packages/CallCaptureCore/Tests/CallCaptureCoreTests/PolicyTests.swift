import Foundation
import Testing
@testable import CallCaptureCore

@Suite("Ingress, resources, library, presentation, diagnostics, entitlement")
struct PolicyTests {
    @Test("T17 audio queue bound: overflow is reported, never silent")
    func audioBound() {
        let q = BoundedIngress(profile: .v1)
        var dropped: [DroppedRange] = []
        for i in 0..<40 {   // 4 s of 100 ms audio, bound is 2 s
            if case .dropped(let d) = q.enqueue(CapturedSample(observation: .audio(.microphone, Double(i) * 0.1))) { dropped += d }
        }
        #expect(q.count == 20)
        #expect(dropped.count == 20)
        #expect(dropped.allSatisfy { $0.source == .microphone })
    }

    @Test("Video overflow drops oldest frames first and reports each")
    func videoBound() {
        let q = BoundedIngress(profile: .v1)
        var reported = 0
        for i in 0..<1_000 {
            if case .dropped(let d) = q.enqueue(CapturedSample(observation: .frame(Double(i) / 30))) { reported += d.count }
        }
        #expect(q.count * 50_000 <= AcceptanceProfile.v1.videoQueueBytes)
        #expect(reported == 1_000 - q.count)
        #expect(q.dequeue()?.observation.range.start.seconds ?? 0 > 0)
    }

    @Test("T18 pending-item limit is enforced at ingress")
    func pendingLimit() {
        var p = AcceptanceProfile.v1
        p.maxPendingTasks = 10
        let q = BoundedIngress(profile: p)
        for i in 0..<50 { _ = q.enqueue(CapturedSample(observation: .audio(.appAudio, Double(i) * 0.001, 0.001))) }
        #expect(q.count == 10)
    }

    @Test("T36 resource governor degrades optional work first and protects storage reserve")
    func governor() {
        var g = ResourceGovernor(reserve: .forMode(.screenAndAudio))
        let plenty: Int64 = 50_000_000_000
        #expect(g.evaluate(ResourceInputs(freeBytes: plenty)) == .normal)
        #expect(g.evaluate(ResourceInputs(freeBytes: plenty, thermal: .fair)) == .conserve)
        #expect(!g.state.allowsOptionalVisuals)
        #expect(g.evaluate(ResourceInputs(freeBytes: plenty, memoryWarning: true)) == .audioPriority)
        #expect(g.evaluate(ResourceInputs(freeBytes: g.reserve.reserveBytes - 1)) == .protectedStop)
        let est = g.reserve.estimatedSeconds(freeBytes: 10_000_000_000)
        #expect(est.lowerBound < est.upperBound)   // a range, never a single promise
    }

    @Test("UX12 search, sort and filter over a 1,000-item library")
    func largeLibrary() {
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        var rows: [LibraryRow] = []
        for i in 0..<1_000 {
            var m = RecordingMetadata(id: UUID(), title: i % 50 == 0 ? "Café meeting \(i)" : "Call \(i)", createdAt: base.addingTimeInterval(Double(i)),
                                      duration: 60, masterFileName: "m", byteCount: 1, contract: screenMicContract,
                                      outcome: i % 10 == 0 ? .savedPartial : (i % 25 == 0 ? .recovered : .saved),
                                      completeness: .noKnownGaps, validation: .basicChecksPassed, libraryState: .available,
                                      sources: [], anomalies: [])
            if i % 100 == 0 { m.bookmarks = [Bookmark(time: 1, label: "b")] }
            rows.append(LibraryRow(m))
        }
        let start = Date()
        let cafe = LibraryQuery(text: "cafe").apply(to: rows)
        #expect(cafe.count == 20)
        #expect(LibraryQuery(filter: .partial).apply(to: rows).count == 100)
        #expect(LibraryQuery(filter: .bookmarked).apply(to: rows).count == 10)
        let oldest = LibraryQuery(sort: .oldest).apply(to: rows)
        #expect(oldest.first?.title == "Café meeting 0")
        #expect(LibraryQuery(text: "zzz").apply(to: rows).isEmpty)
        #expect(Date().timeIntervalSince(start) < 2)
    }

    @Test("UX06 unknown, stale and limited evidence never produce passing copy")
    func truthfulCopy() {
        for health in CurrentSourceHealth.allCases where health != .checksPassing {
            for reason in [nil] + ReasonCode.allCases.map(Optional.some) {
                let s = SourceStatus(source: .microphone, requirement: .required, health: health, reason: reason)
                #expect(StatusPresenter.source(s, lifecycle: .capturing).tone != .pass)
            }
        }
        let passing = SourceStatus(source: .microphone, requirement: .required, health: .checksPassing)
        #expect(StatusPresenter.source(passing, lifecycle: .finalized).tone == .neutral)   // not live any more
        #expect(StatusPresenter.headline(lifecycle: .finalized, nonCapture: nil, outcome: .savedPartial, endReason: nil).tone == .warning)
        #expect(StatusPresenter.headline(lifecycle: .finalized, nonCapture: nil, outcome: .recovered, endReason: nil).tone != .pass)
        #expect(StatusPresenter.headline(lifecycle: .capturing, nonCapture: nil, outcome: nil, endReason: nil).tone == .recording)
        let now = MonotonicInstant(nanoseconds: 100_000_000_000)
        #expect(StatusPresenter.freshness(lastUpdate: MonotonicInstant(nanoseconds: 90_000_000_000), now: now)?.message == .statusNotUpdated)
        #expect(StatusPresenter.freshness(lastUpdate: MonotonicInstant(nanoseconds: 99_000_000_000), now: now) == nil)
    }

    @Test("FinalOutcome never promotes unknown completeness to a full save")
    func outcomes() {
        #expect(FinalOutcome.make(recovered: false, completeness: .unknown, playable: true) == .savedPartial)
        #expect(FinalOutcome.make(recovered: false, completeness: .noKnownGaps, playable: true) == .saved)
        #expect(FinalOutcome.make(recovered: true, completeness: .noKnownGaps, playable: true) == .recovered)
        #expect(FinalOutcome.make(recovered: false, completeness: .noKnownGaps, playable: false) == .failed)
    }

    @Test("T35 diagnostics are bounded and strip free text")
    func diagnostics() throws {
        let log = DiagnosticsLog(capacity: 5)
        for i in 0..<12 { log.record(.lifecycle, detail: "step\(i)") }
        #expect(log.events.count == 5)
        #expect(log.events.first?.sequence == 7)
        log.record(.error, detail: "Call with +44 7700 900123 <John>")
        let detail = try #require(log.events.last?.detail)
        #expect(!detail.contains("<"))
        #expect(!detail.contains("+"))
        let data = try log.exportReport(appVersion: "1.0", osVersion: "27.0", deviceModel: "iPhone", resourceState: "NORMAL", now: Date())
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("No recordings"))
    }

    @Test("T33 / UX15 purchase states never affect core features")
    func entitlement() {
        let core = Feature.allCases.filter { !$0.requiresPro }
        for state in [EntitlementState.unknown, .free, .revoked, .pro] {
            for f in core { #expect(EntitlementPolicy.isAvailable(f, cache: EntitlementCache(state: state))) }
        }
        #expect(!EntitlementPolicy.isAvailable(.exportPresets, cache: EntitlementCache(state: .free)))
        #expect(EntitlementPolicy.isAvailable(.exportPresets, cache: EntitlementCache(state: .unknown, verifiedAt: Date(), productID: "pro")))
        #expect(!EntitlementPolicy.isAvailable(.exportPresets, cache: EntitlementCache(state: .unknown)))
        #expect([Feature.record, .healthWarnings, .playback, .rename, .delete, .standardExport, .recovery].allSatisfy { !$0.requiresPro })
    }

    @Test("Important mode makes app audio required and uses protected stop")
    func importantMode() {
        let c = CaptureContract.standard(mode: .screenAndAudio, importantMode: true)
        #expect(c.requiredSources.contains(.appAudio))
        #expect(c.unmetRequirementPolicy == .protectedStop)
        let limited = c.limited(droppingRequirementFor: .appAudio)
        #expect(!limited.requiredSources.contains(.appAudio))
        #expect(limited.version == c.version + 1)
    }

    @Test("Time formatting for copy")
    func formatting() {
        #expect(TimeFormatting.clock(250) == "04:10")
        #expect(TimeFormatting.clock(3_725) == "1:02:05")
        #expect(MediaRange(startSeconds: 250, endSeconds: 260).description == "04:10–04:20")
    }
}
