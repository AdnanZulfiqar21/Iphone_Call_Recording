import Foundation

/// Section 11 layout under a non-purgeable root (Application Support/CallCapture on device).
public struct FileLayout: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public static func applicationSupport(fileManager: FileManager = .default) throws -> FileLayout {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return FileLayout(root: base.appendingPathComponent("CallCapture", isDirectory: true))
    }

    public var recordings: URL { root.appendingPathComponent("Recordings", isDirectory: true) }
    public var recovery: URL { root.appendingPathComponent("Recovery", isDirectory: true) }
    public var deletions: URL { root.appendingPathComponent("Deletions", isDirectory: true) }
    public var quarantine: URL { root.appendingPathComponent("Quarantine", isDirectory: true) }
    /// Regenerable caches (waveforms) are kept separately and may be cleared.
    public var caches: URL { root.appendingPathComponent("Caches", isDirectory: true) }
    public var exports: URL { root.appendingPathComponent("Exports", isDirectory: true) }
    public var diagnostics: URL { root.appendingPathComponent("Diagnostics", isDirectory: true) }

    public func recordingDirectory(_ id: UUID) -> URL { recordings.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func recoveryDirectory(_ id: UUID) -> URL { recovery.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func quarantineDirectory(_ id: UUID) -> URL { quarantine.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func waveformCache(_ id: UUID) -> URL { caches.appendingPathComponent("waveform-\(id.uuidString).json") }
    public var pendingDeletions: URL { deletions.appendingPathComponent("pending-deletions.json") }

    public func createDirectories(fileManager: FileManager = .default) throws {
        for dir in [recordings, recovery, deletions, quarantine, caches, exports, diagnostics] {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

/// Atomic JSON persistence. `Data.write(.atomic)` writes a temporary file and renames it,
/// so readers see the old or the new version, never a torn write.
public enum AtomicJSON {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public static func write<T: Encodable>(_ value: T, to url: URL, protection: FileProtectionPolicy? = nil) throws {
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: protection?.writingOptions ?? [.atomic])
        // Re-apply protection after replacement (section 13).
        protection?.apply(to: url)
    }

    public static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        try decoder.decode(type, from: Data(contentsOf: url))
    }
}

/// File protection decision (P02). Recordings use "complete until first user authentication"
/// so capture can keep writing new segments while the device locks during a call; the
/// stricter class would make new-segment creation fail while locked (section 13, T27).
public enum FileProtectionPolicy: String, Codable, Sendable {
    case completeUntilFirstUserAuthentication
    case complete

    var writingOptions: Data.WritingOptions {
        #if os(iOS)
        switch self {
        case .completeUntilFirstUserAuthentication: return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        case .complete: return [.atomic, .completeFileProtection]
        }
        #else
        return [.atomic]
        #endif
    }

    public func apply(to url: URL) {
        #if os(iOS)
        let value: FileProtectionType = self == .complete ? .complete : .completeUntilFirstUserAuthentication
        try? FileManager.default.setAttributes([.protectionKey: value], ofItemAtPath: url.path)
        #endif
    }
}
