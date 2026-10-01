import Foundation

public enum DecodedRecord<T> {
    case current(T)
    /// Migrated from an older schema; the caller persists the migrated value.
    case migrated(T, from: Int)
    /// Written by a newer app version: preserved read-only, never guessed (T30).
    case futureVersion(Int)
    case unreadable(String)
}

/// Version-aware decoding for metadata.json. Unknown future versions are preserved untouched.
public enum MetadataMigration {
    struct VersionProbe: Decodable { var schemaVersion: Int? }

    /// Schema v1 (pre-v2.2 prototypes) had a single `verified` flag. It is mapped explicitly:
    /// it never becomes FULL_CHECKS_PASSED or NO_KNOWN_GAPS (section 7, legacy mapping).
    struct V1: Decodable {
        var id: UUID
        var title: String
        var createdAt: Date
        var duration: Double
        var masterFileName: String?
        var byteCount: Int?
        var verified: Bool?
        var mode: CaptureMode?
    }

    public static func decode(_ data: Data) -> DecodedRecord<RecordingMetadata> {
        let decoder = AtomicJSON.decoder
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            return .unreadable("not a JSON object")
        }
        let version = probe.schemaVersion ?? 1
        if version > RecordingMetadata.currentSchemaVersion { return .futureVersion(version) }
        if version == RecordingMetadata.currentSchemaVersion {
            do { return .current(try decoder.decode(RecordingMetadata.self, from: data)) } catch {
                return .unreadable(String(describing: error))
            }
        }
        do {
            let old = try decoder.decode(V1.self, from: data)
            let contract = CaptureContract.standard(mode: old.mode ?? .screenAndAudio)
            let migrated = RecordingMetadata(
                id: old.id, title: old.title, createdAt: old.createdAt, duration: old.duration,
                masterFileName: old.masterFileName, byteCount: old.byteCount ?? 0, contract: contract,
                outcome: .saved,
                // Legacy "verified" did not record per-source evidence, so completeness is unknown.
                completeness: .unknown,
                validation: (old.verified ?? false) ? .basicChecksPassed : .pending,
                libraryState: .validating, sources: [], anomalies: [])
            return .migrated(migrated, from: version)
        } catch {
            return .unreadable(String(describing: error))
        }
    }
}
