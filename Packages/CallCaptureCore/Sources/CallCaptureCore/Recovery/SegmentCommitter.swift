import Foundation

/// The section 10.3 checkpoint transaction for segmented output:
/// 1. write media to staging, 2. finish the segment, 3. check range/metadata,
/// 4. commit the manifest atomically, 5. advance only the evidence actually established.
public final class SegmentCommitter: @unchecked Sendable {
    public enum Fault: Sendable { case none, failBeforeRename, failBeforeManifest }

    private let files: RecoveryFiles
    private let lock = NSLock()
    private var manifest: RecoveryManifest
    private let fm = FileManager.default
    /// Test hook for T24 (crash between transaction steps).
    public var fault: Fault = .none

    public init(files: RecoveryFiles, sessionID: UUID) throws {
        self.files = files
        try files.prepare()
        self.manifest = (try? files.readManifest()) ?? RecoveryManifest(sessionID: sessionID)
        try files.writeManifest(manifest)
    }

    public var currentManifest: RecoveryManifest { lock.lock(); defer { lock.unlock() }; return manifest }

    public func commitInitialization(_ data: Data) throws {
        lock.lock(); defer { lock.unlock() }
        let name = "init.mp4"
        let url = files.initializationDirectory.appendingPathComponent(name)
        try data.write(to: url, options: protectedAtomic)
        manifest.initializationFileName = name
        manifest.initializationSHA256 = SHA256Hasher.hex(of: data)
        try files.writeManifest(manifest)
    }

    /// Commits one media segment and returns the checkpoint receipt.
    public func commitSegment(_ data: Data, sessionRange: MediaRange, sources: [SourceKind]) throws -> CheckpointReport {
        lock.lock(); defer { lock.unlock() }
        guard manifest.initializationFileName != nil else { throw CommitError.missingInitialization }
        guard !data.isEmpty, !sessionRange.isEmpty else { throw CommitError.emptySegment }
        if let last = manifest.segments.last, sessionRange.start.seconds < last.sessionRange.start.seconds {
            throw CommitError.outOfOrder
        }
        let sequence = (manifest.segments.last?.sequence ?? -1) + 1
        let name = String(format: "seg-%06d.m4s", sequence)
        let staging = files.segmentsDirectory.appendingPathComponent(name + ".staging")
        let final = files.segmentsDirectory.appendingPathComponent(name)
        try data.write(to: staging, options: protectedAtomic)                                   // 1–2
        let hash = SHA256Hasher.hex(of: data)                                                    // 3
        if fault == .failBeforeRename { throw CommitError.injectedFault }
        if fm.fileExists(atPath: final.path) { try fm.removeItem(at: final) }
        try fm.moveItem(at: staging, to: final)
        if fault == .failBeforeManifest { throw CommitError.injectedFault }
        let segment = RecoveryManifest.Segment(sequence: sequence, fileName: name, sessionRange: sessionRange,
                                               sources: sources, byteCount: data.count, sha256: hash)
        manifest.segments.append(segment)
        try files.writeManifest(manifest)                                                         // 4
        return CheckpointReport(sequence: sequence, sessionRange: sessionRange, sources: sources,
                                fileName: name, byteCount: data.count, sha256: hash)             // 5
    }

    public enum CommitError: Error, Sendable { case missingInitialization, emptySegment, outOfOrder, injectedFault }

    private var protectedAtomic: Data.WritingOptions {
        #if os(iOS)
        return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        return [.atomic]
        #endif
    }
}
