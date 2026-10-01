import Foundation

/// Section 12. Records exactly what was checked; basic coverage never implies full integrity.
public struct ValidationReport: Codable, Sendable, Hashable {
    public static let validatorVersion = 1

    public var validatorVersion: Int
    public var fileName: String
    public var byteCount: Int
    public var sha256: String?
    public var coverage: ValidationCoverage
    public var result: FileValidation
    public var durations: [String: Double]
    /// Ranges whose decode failed or that are missing in the file.
    public var detectedRanges: [MediaRange]
    /// For FULL checks: seconds decoded so far, so the work is resumable.
    public var decodedThrough: Double
    public var notes: [String]

    public init(fileName: String, byteCount: Int, sha256: String?, coverage: ValidationCoverage, result: FileValidation,
                durations: [String: Double] = [:], detectedRanges: [MediaRange] = [], decodedThrough: Double = 0, notes: [String] = []) {
        self.validatorVersion = Self.validatorVersion
        self.fileName = fileName
        self.byteCount = byteCount
        self.sha256 = sha256
        self.coverage = coverage
        self.result = result
        self.durations = durations
        self.detectedRanges = detectedRanges
        self.decodedThrough = decodedThrough
        self.notes = notes
    }
}

/// Reconciles what the validator found in the file with capture/writer evidence.
/// A file missing required audio stays PARTIAL even if what remains decodes perfectly (section 12).
public enum ValidationReconciler {
    public static func reconcile(report: ValidationReport, expectedDuration: Double, contract: CaptureContract,
                                 ledger: inout AnomalyLedger, tolerance: Double = 0.25) {
        for source in contract.requiredSources where source.isAudio {
            let key = source.rawValue
            guard let actual = report.durations[key] else { continue }
            if expectedDuration - actual > tolerance {
                // A long video track must not hide a shorter audio track (section 6.3).
                ledger.record(Anomaly(source: source, range: MediaRange(startSeconds: actual, endSeconds: expectedDuration),
                                      kind: .missing, reason: .tailTruncation))
            }
        }
        for r in report.detectedRanges {
            for s in contract.requiredSources {
                ledger.record(Anomaly(source: s, range: r, kind: .damaged, reason: .segmentCorrupt))
            }
        }
    }
}
