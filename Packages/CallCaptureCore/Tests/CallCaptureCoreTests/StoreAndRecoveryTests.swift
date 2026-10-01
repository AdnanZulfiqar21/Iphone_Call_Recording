import Foundation
import Testing
@testable import CallCaptureCore

@Suite("Store, deletion, migration and recovery (section 11, T23–T30)")
struct StoreAndRecoveryTests {
    func makeStore() throws -> (RecordingStore, FileLayout) {
        let layout = FileLayout(root: temporaryRoot())
        return (try RecordingStore(layout: layout), layout)
    }

    func metadata(_ id: UUID = UUID(), title: String = "Call", outcome: FinalOutcome = .saved) -> RecordingMetadata {
        RecordingMetadata(id: id, title: title, createdAt: Date(), duration: 60, masterFileName: "master.mp4", byteCount: 10,
                          contract: screenMicContract, outcome: outcome, completeness: .noKnownGaps, validation: .basicChecksPassed,
                          libraryState: .available, sources: [], anomalies: [])
    }

    /// Creates a recovery directory with init + `count` committed 2 s segments.
    func makeRecovery(_ layout: FileLayout, id: UUID, segments count: Int, lastKnownEnd: Double? = nil) throws -> RecoveryFiles {
        let files = RecoveryFiles(directory: layout.recoveryDirectory(id))
        let committer = try SegmentCommitter(files: files, sessionID: id)
        try committer.commitInitialization(Data("INIT".utf8))
        for i in 0..<count {
            _ = try committer.commitSegment(Data(repeating: UInt8(i), count: 64),
                                            sessionRange: MediaRange(startSeconds: Double(i) * 2, endSeconds: Double(i + 1) * 2),
                                            sources: [.screen, .microphone])
        }
        var j = RecoveryJournal(identity: SessionIdentity(sessionID: id, generation: 1, contractVersion: 1),
                                contract: screenMicContract, createdAt: Date(), title: "Interrupted call")
        j.lastKnownCaptureEnd = lastKnownEnd ?? Double(count * 2)
        try files.writeJournal(j)
        return files
    }

    @Test("Rename and bookmarks change metadata only")
    func renameAndBookmarks() throws {
        let (store, _) = try makeStore()
        let m = metadata()
        try store.save(m)
        try store.rename(m.id, to: "  دادی جان — family call  ")
        _ = try store.addBookmark(m.id, at: 30, label: "Price agreed")
        _ = try store.addBookmark(m.id, at: 10, label: "Intro")
        store.reload()
        let r = try #require(store.metadata(m.id))
        #expect(r.title == "دادی جان — family call")
        #expect(r.bookmarks.map(\.label) == ["Intro", "Price agreed"])
        #expect(r.masterFileName == "master.mp4")
    }

    @Test("T29 deletion interrupted at every step completes on relaunch without resurrection", arguments: [1, 2, 3])
    func interruptedDeletion(step: Int) async throws {
        let (store, layout) = try makeStore()
        let m = metadata()
        try store.save(m)
        _ = try makeRecovery(layout, id: m.id, segments: 2)
        store.deletionFaultAfterStep = step
        try store.delete(m.id)
        // "Relaunch": new store and recovery manager over the same files.
        let relaunched = try RecordingStore(layout: layout)
        let manager = RecoveryManager(layout: layout, store: relaunched)
        #expect(manager.scan().isEmpty)                      // recovery never resurrects it
        relaunched.reload()
        #expect(relaunched.all().allSatisfy { $0.id != m.id })
        try relaunched.reconcileDeletions()
        #expect(!FileManager.default.fileExists(atPath: layout.recordingDirectory(m.id).path))
        #expect(!FileManager.default.fileExists(atPath: layout.recoveryDirectory(m.id).path))
        #expect(relaunched.loadPendingDeletions().ids.isEmpty)
        relaunched.reload()
        #expect(relaunched.metadata(m.id) == nil)
    }

    @Test("T30 v1 metadata migrates explicitly; future versions are preserved read-only")
    func migration() throws {
        let (store, layout) = try makeStore()
        let oldID = UUID(), futureID = UUID(), brokenID = UUID()
        for id in [oldID, futureID, brokenID] {
            try FileManager.default.createDirectory(at: layout.recordingDirectory(id), withIntermediateDirectories: true)
        }
        let v1 = """
        {"id":"\(oldID.uuidString)","title":"Old","createdAt":"2026-01-01T10:00:00Z","duration":12,"verified":true}
        """
        try Data(v1.utf8).write(to: layout.recordingDirectory(oldID).appendingPathComponent("metadata.json"))
        let future = Data(#"{"schemaVersion":99,"anything":"new"}"#.utf8)
        let futureURL = layout.recordingDirectory(futureID).appendingPathComponent("metadata.json")
        try future.write(to: futureURL)
        try Data("{not json".utf8).write(to: layout.recordingDirectory(brokenID).appendingPathComponent("metadata.json"))

        store.reload()
        let migrated = try #require(store.metadata(oldID))
        #expect(migrated.schemaVersion == RecordingMetadata.currentSchemaVersion)
        #expect(migrated.completeness == .unknown)           // legacy "verified" never means complete
        #expect(migrated.validation == .basicChecksPassed)
        #expect(store.unreadable.contains { $0.id == futureID && $0.isFutureVersion })
        #expect(store.unreadable.contains { $0.id == brokenID })
        #expect(try Data(contentsOf: futureURL) == future)   // untouched
    }

    @Test("Clearing caches never removes recovery material")
    func clearCaches() throws {
        let (store, layout) = try makeStore()
        let id = UUID()
        _ = try makeRecovery(layout, id: id, segments: 1)
        try Data("w".utf8).write(to: layout.waveformCache(id))
        try store.clearCaches()
        #expect(!FileManager.default.fileExists(atPath: layout.waveformCache(id).path))
        #expect(FileManager.default.fileExists(atPath: RecoveryFiles(directory: layout.recoveryDirectory(id)).manifestURL.path))
        #expect(store.usage().recoveryBytes > 0)
    }

    @Test("T24 crash after checkpoints: recover what exists, report the lost tail")
    func recoverAfterCrash() async throws {
        let (store, layout) = try makeStore()
        let id = UUID()
        _ = try makeRecovery(layout, id: id, segments: 3, lastKnownEnd: 7.5)
        let manager = RecoveryManager(layout: layout, store: store)
        let candidate = try #require(manager.scan().first)
        #expect(candidate.status == .recoverable)
        #expect(candidate.validSegments.count == 3)
        let m = try await manager.recover(candidate, assembler: FixtureAssembler())
        #expect(m.outcome == .recoveredPartial)
        #expect(m.completeness == .partial)
        #expect(m.anomalies.contains { $0.reason == .processTerminated && abs($0.range.start.seconds - 6) < 0.01 })
        #expect(!FileManager.default.fileExists(atPath: layout.recoveryDirectory(id).path))   // only after commit
        #expect(store.metadata(id)?.libraryState == .available)
    }

    @Test("T24 crash between transaction steps never claims an uncommitted segment")
    func crashBetweenSteps() throws {
        let (_, layout) = try makeStore()
        let id = UUID()
        let files = RecoveryFiles(directory: layout.recoveryDirectory(id))
        let c = try SegmentCommitter(files: files, sessionID: id)
        try c.commitInitialization(Data("INIT".utf8))
        _ = try c.commitSegment(Data(repeating: 1, count: 32), sessionRange: MediaRange(startSeconds: 0, endSeconds: 2), sources: [.microphone])
        c.fault = .failBeforeManifest
        #expect(throws: SegmentCommitter.CommitError.self) {
            _ = try c.commitSegment(Data(repeating: 2, count: 32), sessionRange: MediaRange(startSeconds: 2, endSeconds: 4), sources: [.microphone])
        }
        #expect(try files.readManifest().segments.count == 1)
    }

    @Test("T23 a corrupted middle segment is excluded and its range reported")
    func corruptMiddle() async throws {
        let (store, layout) = try makeStore()
        let id = UUID()
        let files = try makeRecovery(layout, id: id, segments: 3)
        try Data("garbage".utf8).write(to: files.segmentsDirectory.appendingPathComponent("seg-000001.m4s"))
        let manager = RecoveryManager(layout: layout, store: store)
        let candidate = try #require(manager.scan().first)
        #expect(candidate.damagedSegments.map(\.sequence) == [1])
        let m = try await manager.recover(candidate, assembler: FixtureAssembler())
        #expect(m.anomalies.contains { abs($0.range.start.seconds - 2) < 0.01 && abs($0.range.end.seconds - 4) < 0.01 })
        #expect(m.outcome == .recoveredPartial)
    }

    @Test("T25 missing initialization data is quarantined, never guessed")
    func missingInit() throws {
        let (store, layout) = try makeStore()
        let id = UUID()
        let files = try makeRecovery(layout, id: id, segments: 2)
        try FileManager.default.removeItem(at: files.initializationDirectory.appendingPathComponent("init.mp4"))
        let candidate = try #require(RecoveryManager(layout: layout, store: store).scan().first)
        #expect(candidate.status == .quarantined)
        #expect(FileManager.default.fileExists(atPath: files.manifestURL.path))   // preserved
    }

    @Test("T28 repeated bad recovery is bounded, then quarantined; nothing deleted")
    func boundedRetries() async throws {
        let (store, layout) = try makeStore()
        let id = UUID()
        _ = try makeRecovery(layout, id: id, segments: 2)
        let manager = RecoveryManager(layout: layout, store: store)
        for _ in 0..<3 {
            guard let c = manager.scan().first(where: { $0.status == .recoverable }) else { break }
            _ = try? await manager.recover(c, assembler: FixtureAssembler(failing: true))
        }
        #expect(!FileManager.default.fileExists(atPath: layout.recoveryDirectory(id).path))
        #expect(FileManager.default.fileExists(atPath: layout.quarantineDirectory(id).path))
        #expect(manager.scan().first?.status == .quarantined)
    }

    @Test("T26 nothing committed yet: candidate reports no media instead of a false save")
    func crashBeforeFirstCheckpoint() throws {
        let (store, layout) = try makeStore()
        let id = UUID()
        let files = RecoveryFiles(directory: layout.recoveryDirectory(id))
        try files.prepare()
        try files.writeJournal(RecoveryJournal(identity: SessionIdentity(sessionID: id, generation: 1, contractVersion: 1),
                                               contract: screenMicContract, createdAt: Date(), title: "x"))
        let c = try #require(RecoveryManager(layout: layout, store: store).scan().first)
        #expect(c.validSegments.isEmpty)
        #expect(c.recoverableSeconds == 0)
        #expect(c.reason != nil)
    }

    @Test("SHA-256 matches FIPS vectors")
    func sha256() {
        #expect(SHA256Hasher.hex(of: Data()) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(SHA256Hasher.hex(of: Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(SHA256Hasher.hex(of: Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8))
                == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        var h = SHA256Hasher()
        for _ in 0..<1000 { h.update(Data(repeating: 0x61, count: 1000)) }
        #expect(h.finalize() == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }
}
