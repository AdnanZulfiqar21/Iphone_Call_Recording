import Foundation

public struct PendingDeletions: Codable, Sendable, Hashable {
    public var schemaVersion = 1
    public var ids: [UUID] = []
    public init() {}
}

public enum StoreError: Error, Equatable, Sendable {
    case notFound
    case futureVersion(Int)
    case writerActive
    case protectedDataUnavailable
}

/// A record the store could not load, kept visible rather than hidden or deleted.
public struct UnreadableRecord: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var reason: String
    public var isFutureVersion: Bool
}

/// RecordingStore (section 5): master/derived ownership, metadata transactions and deletion.
public final class RecordingStore: @unchecked Sendable {
    public let layout: FileLayout
    private let fm = FileManager.default
    private let lock = NSLock()
    private let protection: FileProtectionPolicy
    private var cache: [UUID: RecordingMetadata] = [:]
    public private(set) var unreadable: [UnreadableRecord] = []

    /// Test hook: simulate termination at a deletion step (T29).
    public var deletionFaultAfterStep: Int?

    public init(layout: FileLayout, protection: FileProtectionPolicy = .completeUntilFirstUserAuthentication) throws {
        self.layout = layout
        self.protection = protection
        try layout.createDirectories()
    }

    // MARK: Loading

    /// Loads every record, migrating older schemas and preserving unknown future versions.
    @discardableResult
    public func reload() -> [RecordingMetadata] {
        lock.lock(); defer { lock.unlock() }
        cache.removeAll()
        unreadable.removeAll()
        let pending = Set(loadPendingDeletions().ids)
        let dirs = (try? fm.contentsOfDirectory(at: layout.recordings, includingPropertiesForKeys: nil)) ?? []
        for dir in dirs {
            guard let id = UUID(uuidString: dir.lastPathComponent) else { continue }
            let url = dir.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: url) else {
                if fm.fileExists(atPath: url.path) {
                    // Exists but unreadable: likely protected data while locked. Not corrupt (T27).
                    unreadable.append(UnreadableRecord(id: id, reason: "protectedDataUnavailable", isFutureVersion: false))
                }
                continue
            }
            switch MetadataMigration.decode(data) {
            case .current(var m):
                if pending.contains(id) { m.libraryState = .deletePending }
                cache[id] = m
            case .migrated(var m, _):
                try? AtomicJSON.write(m, to: url, protection: protection)
                if pending.contains(id) { m.libraryState = .deletePending }
                cache[id] = m
            case .futureVersion(let v):
                unreadable.append(UnreadableRecord(id: id, reason: "schemaVersion \(v) is newer than this app", isFutureVersion: true))
            case .unreadable(let reason):
                unreadable.append(UnreadableRecord(id: id, reason: reason, isFutureVersion: false))
            }
        }
        return Array(cache.values)
    }

    /// Visible library items: deletion-pending items are hidden (deletion step 2).
    public func all() -> [RecordingMetadata] {
        lock.lock(); defer { lock.unlock() }
        return cache.values.filter { $0.libraryState != .deletePending }
    }

    public func metadata(_ id: UUID) -> RecordingMetadata? {
        lock.lock(); defer { lock.unlock() }
        return cache[id]
    }

    public func masterURL(_ m: RecordingMetadata) -> URL? {
        m.masterFileName.map { layout.recordingDirectory(m.id).appendingPathComponent($0) }
    }

    // MARK: Writing

    public func save(_ metadata: RecordingMetadata) throws {
        let url = layout.recordingDirectory(metadata.id).appendingPathComponent("metadata.json")
        try AtomicJSON.write(metadata, to: url, protection: protection)
        lock.lock(); cache[metadata.id] = metadata; lock.unlock()
    }

    /// Updates mutable metadata (title, bookmarks). The master file is never touched.
    @discardableResult
    public func update(_ id: UUID, _ change: (inout RecordingMetadata) -> Void) throws -> RecordingMetadata {
        guard var m = metadata(id) else { throw StoreError.notFound }
        change(&m)
        try save(m)
        return m
    }

    public func rename(_ id: UUID, to title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try update(id) { $0.title = String(trimmed.prefix(200)) }
    }

    public func addBookmark(_ id: UUID, at time: Double, label: String) throws -> Bookmark {
        let b = Bookmark(time: max(0, time), label: label)
        try update(id) { m in
            m.bookmarks.append(b)
            m.bookmarks.sort { $0.time < $1.time }
        }
        return b
    }

    public func removeBookmark(_ id: UUID, bookmark: UUID) throws {
        try update(id) { $0.bookmarks.removeAll { $0.id == bookmark } }
    }

    // MARK: Deletion transaction (section 11)

    public func loadPendingDeletions() -> PendingDeletions {
        (try? AtomicJSON.read(PendingDeletions.self, from: layout.pendingDeletions)) ?? PendingDeletions()
    }

    private func savePendingDeletions(_ p: PendingDeletions) throws {
        try AtomicJSON.write(p, to: layout.pendingDeletions)
    }

    /// 1. durable intent, 2. hide, 3. delete owned files, 4/5. retire intent once nothing can resurrect.
    public func delete(_ id: UUID) throws {
        var pending = loadPendingDeletions()
        if !pending.ids.contains(id) { pending.ids.append(id) }
        try savePendingDeletions(pending)                                   // step 1
        if deletionFaultAfterStep == 1 { return }
        lock.lock()
        cache[id]?.libraryState = .deletePending                            // step 2
        lock.unlock()
        if deletionFaultAfterStep == 2 { return }
        try removeOwnedFiles(id)                                            // step 3
        if deletionFaultAfterStep == 3 { return }
        try retireDeletion(id)                                              // step 5
    }

    private func removeOwnedFiles(_ id: UUID) throws {
        for dir in [layout.recordingDirectory(id), layout.recoveryDirectory(id), layout.quarantineDirectory(id)]
        where fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
        let cache = layout.waveformCache(id)
        if fm.fileExists(atPath: cache.path) { try fm.removeItem(at: cache) }
        let exports = layout.exports.appendingPathComponent(id.uuidString, isDirectory: true)
        if fm.fileExists(atPath: exports.path) { try fm.removeItem(at: exports) }
    }

    private func retireDeletion(_ id: UUID) throws {
        let stillOwned = [layout.recordingDirectory(id), layout.recoveryDirectory(id), layout.quarantineDirectory(id)]
            .contains { fm.fileExists(atPath: $0.path) }
        guard !stillOwned else { return }
        var pending = loadPendingDeletions()
        pending.ids.removeAll { $0 == id }
        try savePendingDeletions(pending)
        lock.lock(); cache[id] = nil; lock.unlock()
    }

    /// Completes interrupted deletions at launch. Idempotent (T29).
    public func reconcileDeletions() throws {
        for id in loadPendingDeletions().ids {
            try removeOwnedFiles(id)
            try retireDeletion(id)
        }
    }

    public func isDeletionPending(_ id: UUID) -> Bool {
        loadPendingDeletions().ids.contains(id)
    }

    // MARK: Storage accounting (Settings › Storage)

    public struct Usage: Sendable, Equatable {
        public var recordingsBytes: Int64
        public var recoveryBytes: Int64
        public var cacheBytes: Int64
        public var exportBytes: Int64
    }

    public func usage() -> Usage {
        Usage(recordingsBytes: size(of: layout.recordings), recoveryBytes: size(of: layout.recovery) + size(of: layout.quarantine),
              cacheBytes: size(of: layout.caches), exportBytes: size(of: layout.exports))
    }

    /// Clears regenerable caches only. Recovery material is never treated as cache.
    public func clearCaches() throws {
        for item in (try? fm.contentsOfDirectory(at: layout.caches, includingPropertiesForKeys: nil)) ?? [] {
            try fm.removeItem(at: item)
        }
    }

    private func size(of dir: URL) -> Int64 {
        guard let e = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in e {
            let v = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if v?.isRegularFile == true { total += Int64(v?.fileSize ?? 0) }
        }
        return total
    }
}
