import Foundation

/// What launch-time reconciliation found for one recovery directory.
public struct RecoveryCandidate: Sendable, Hashable, Identifiable {
    public enum Status: String, Sendable, Hashable {
        /// Usable segments exist and can be assembled.
        case recoverable
        /// Files exist but protected data is unavailable (device locked). Not corrupt (T27).
        case waitingForUnlock
        /// Preserved untouched after repeated failure or unreadable/future-format data (T25, T28).
        case quarantined
        /// Leftover from a session whose master was committed; safe to clean.
        case alreadyCommitted
    }

    public var id: UUID
    public var status: Status
    public var title: String
    public var createdAt: Date?
    public var recoverableSeconds: Double
    public var lastKnownCaptureEnd: Double
    public var validSegments: [RecoveryManifest.Segment]
    public var damagedSegments: [RecoveryManifest.Segment]
    public var reason: String?
    public var attempts: Int
}

/// RecoveryManager (section 5). Reconciles journals and media before any repair, uses bounded
/// retries, quarantines instead of deleting, and never restarts capture.
public final class RecoveryManager: @unchecked Sendable {
    private let layout: FileLayout
    private let store: RecordingStore
    private let profile: AcceptanceProfile
    private let launchID: UUID
    private let fm = FileManager.default

    public init(layout: FileLayout, store: RecordingStore, profile: AcceptanceProfile = .v1, launchID: UUID = UUID()) {
        self.layout = layout
        self.store = store
        self.profile = profile
        self.launchID = launchID
    }

    /// Scans recovery material. Does not modify media.
    public func scan(activeSessionID: UUID? = nil) -> [RecoveryCandidate] {
        let dirs = (try? fm.contentsOfDirectory(at: layout.recovery, includingPropertiesForKeys: nil)) ?? []
        var result: [RecoveryCandidate] = []
        for dir in dirs {
            guard let id = UUID(uuidString: dir.lastPathComponent), id != activeSessionID else { continue }
            // A deleted item must never be resurrected by recovery (rule 21).
            if store.isDeletionPending(id) { continue }
            result.append(inspect(id: id, directory: dir))
        }
        let quarantined = (try? fm.contentsOfDirectory(at: layout.quarantine, includingPropertiesForKeys: nil)) ?? []
        for dir in quarantined {
            guard let id = UUID(uuidString: dir.lastPathComponent), !store.isDeletionPending(id) else { continue }
            let journal = try? RecoveryFiles(directory: dir).readJournal()
            result.append(RecoveryCandidate(id: id, status: .quarantined, title: journal?.title ?? "Recording",
                                            createdAt: journal?.createdAt, recoverableSeconds: 0,
                                            lastKnownCaptureEnd: journal?.lastKnownCaptureEnd ?? 0, validSegments: [],
                                            damagedSegments: [], reason: "Kept safely for later review", attempts: journal?.recoveryAttempts ?? 0))
        }
        return result.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func inspect(id: UUID, directory: URL) -> RecoveryCandidate {
        let files = RecoveryFiles(directory: directory)
        var candidate = RecoveryCandidate(id: id, status: .quarantined, title: "Recording", createdAt: nil, recoverableSeconds: 0,
                                          lastKnownCaptureEnd: 0, validSegments: [], damagedSegments: [], reason: nil, attempts: 0)
        let journal: RecoveryJournal
        do {
            journal = try files.readJournal()
        } catch {
            if isProtectedDataError(error, url: files.journalURL) {
                candidate.status = .waitingForUnlock
                candidate.reason = "Unlock your iPhone to check this recording"
            } else {
                candidate.reason = "Recording details could not be read"
            }
            return candidate
        }
        candidate.title = journal.title
        candidate.createdAt = journal.createdAt
        candidate.lastKnownCaptureEnd = journal.lastKnownCaptureEnd
        candidate.attempts = journal.recoveryAttempts
        if journal.schemaVersion > RecoveryJournal.currentSchemaVersion {
            candidate.reason = "Made by a newer version of CallCapture"
            return candidate
        }
        if journal.state == .committed {
            candidate.status = .alreadyCommitted
            return candidate
        }
        guard let manifest = try? files.readManifest() else {
            candidate.reason = "No saved media was committed before the app closed"
            candidate.status = journal.recoveryAttempts >= profile.recoveryRetriesPerLaunch ? .quarantined : .recoverable
            return candidate
        }
        guard let initName = manifest.initializationFileName,
              let initData = try? Data(contentsOf: files.initializationDirectory.appendingPathComponent(initName)),
              manifest.initializationSHA256 == nil || SHA256Hasher.hex(of: initData) == manifest.initializationSHA256 else {
            // Fragments are not playable without initialization data; never guess (T25).
            candidate.reason = "Required setup data for this recording is missing"
            return candidate
        }
        for segment in manifest.segments.sorted(by: { $0.sequence < $1.sequence }) {
            let url = files.segmentsDirectory.appendingPathComponent(segment.fileName)
            if let data = try? Data(contentsOf: url), data.count == segment.byteCount, SHA256Hasher.hex(of: data) == segment.sha256 {
                candidate.validSegments.append(segment)
            } else {
                candidate.damagedSegments.append(segment)
            }
        }
        candidate.recoverableSeconds = candidate.validSegments.reduce(0) { $0 + $1.sessionRange.duration }
        if journal.recoveryAttempts >= profile.recoveryRetriesPerLaunch && journal.lastAttemptLaunchID == launchID {
            candidate.reason = "Automatic repair stopped after \(profile.recoveryRetriesPerLaunch) attempts"
            return candidate
        }
        candidate.status = candidate.validSegments.isEmpty ? .quarantined : .recoverable
        if candidate.validSegments.isEmpty { candidate.reason = "No complete media segments were saved" }
        return candidate
    }

    private func isProtectedDataError(_ error: Error, url: URL) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && (ns.code == NSFileReadNoPermissionError || ns.code == 257) { return fm.fileExists(atPath: url.path) }
        if ns.domain == NSPOSIXErrorDomain && (ns.code == Int(EPERM) || ns.code == Int(EACCES)) { return true }
        return false
    }

    /// Assembles valid segments into a recording. The recovery copy is removed only after the
    /// replacement is validated and committed (rule 20). Interrupted recovery is idempotent.
    public func recover(_ candidate: RecoveryCandidate, assembler: any RecordingAssembler) async throws -> RecordingMetadata {
        let dir = layout.recoveryDirectory(candidate.id)
        let files = RecoveryFiles(directory: dir)
        var journal = try files.readJournal()
        var manifest = try files.readManifest()
        // The retry budget is per item per app launch (section 15).
        if journal.lastAttemptLaunchID != launchID { journal.recoveryAttempts = 0 }
        guard journal.recoveryAttempts < profile.recoveryRetriesPerLaunch else {
            try quarantine(candidate.id)
            throw StoreError.notFound
        }
        journal.recoveryAttempts += 1
        journal.lastAttemptLaunchID = launchID
        try files.writeJournal(journal)

        manifest.segments = candidate.validSegments
        let recordingDir = layout.recordingDirectory(candidate.id)
        try fm.createDirectory(at: recordingDir, withIntermediateDirectories: true)
        let media: FinalizedMedia
        do {
            media = try await assembler.assemble(recoveryDirectory: dir, manifest: manifest, into: recordingDir)
        } catch {
            if journal.recoveryAttempts >= profile.recoveryRetriesPerLaunch { try quarantine(candidate.id) }
            throw error
        }

        var ledger = AnomalyLedger(anomalies: journal.anomalies)
        let ordered = candidate.validSegments.sorted { $0.sequence < $1.sequence }
        let sources = journal.contract.requiredSources
        // Holes between preserved segments, damaged segments and the lost tail are explicit.
        var cursor = 0.0
        for seg in ordered {
            if seg.sessionRange.start.seconds - cursor > profile.gapTolerance {
                for s in sources {
                    ledger.record(Anomaly(source: s, range: MediaRange(startSeconds: cursor, endSeconds: seg.sessionRange.start.seconds),
                                          kind: .missing, reason: .segmentCorrupt))
                }
            }
            cursor = max(cursor, seg.sessionRange.end.seconds)
        }
        let knownEnd = max(journal.lastKnownCaptureEnd, candidate.damagedSegments.map(\.sessionRange.end.seconds).max() ?? 0)
        if knownEnd - cursor > profile.gapTolerance {
            for s in sources {
                ledger.record(Anomaly(source: s, range: MediaRange(startSeconds: cursor, endSeconds: knownEnd), kind: .missing, reason: .processTerminated))
            }
        }
        ValidationReconciler.reconcile(report: media.validation, expectedDuration: cursor, contract: journal.contract, ledger: &ledger)

        let required = Set(sources)
        let completeness: CaptureCompleteness = ledger.open().contains { required.contains($0.source) } ? .partial : .unknown
        let playable = media.validation.result != .failed
        let metadata = RecordingMetadata(
            id: candidate.id, title: journal.title, createdAt: journal.createdAt, duration: media.duration,
            masterFileName: media.masterFileName, byteCount: media.byteCount, contract: journal.contract,
            // Recovered media after termination can never claim NO_KNOWN_GAPS: the end is unobserved.
            outcome: FinalOutcome.make(recovered: true, completeness: completeness, playable: playable),
            completeness: completeness, validation: media.validation.result,
            libraryState: playable ? .available : .quarantined,
            sources: journal.contract.sources.map { p in
                SourceSummary(source: p.kind, requirement: p.requirement, receivedSeconds: cursor, everReceived: cursor > 0,
                              openAnomalySeconds: ledger.affectedSeconds(for: p.kind))
            },
            anomalies: ledger.anomalies, endReason: .processTerminated)
        try AtomicJSON.write(media.validation, to: recordingDir.appendingPathComponent("validation.json"))
        try store.save(metadata)
        if playable {
            journal.state = .committed
            try files.writeJournal(journal)
            try fm.removeItem(at: dir)
        } else {
            try quarantine(candidate.id)
        }
        return metadata
    }

    /// Moves material to quarantine. Nothing is deleted.
    public func quarantine(_ id: UUID) throws {
        let source = layout.recoveryDirectory(id)
        guard fm.fileExists(atPath: source.path) else { return }
        let target = layout.quarantineDirectory(id)
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.moveItem(at: source, to: target)
    }

    /// Removes leftovers whose master was already committed.
    public func cleanCommitted(_ candidates: [RecoveryCandidate]) {
        for c in candidates where c.status == .alreadyCommitted {
            guard let m = store.metadata(c.id), m.libraryState == .available else { continue }
            try? fm.removeItem(at: layout.recoveryDirectory(c.id))
        }
    }
}
