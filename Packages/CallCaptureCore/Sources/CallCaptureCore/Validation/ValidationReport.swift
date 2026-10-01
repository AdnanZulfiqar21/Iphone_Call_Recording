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
    /// The same ranges attributed to the track they were found in (source raw value → ranges).
    public var sourceRanges: [String: [MediaRange]]?
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
            let tail = MediaRange(startSeconds: actual, endSeconds: expectedDuration)
            if expectedDuration - actual > tolerance && !alreadyKnown(tail, source: source, in: ledger) {
                // A long video track must not hide a shorter audio track (section 6.3).
                ledger.record(Anomaly(source: source, range: tail, kind: .missing, reason: .tailTruncation))
            }
        }
        // File-level holes found by FULL checks, attributed per track. A hole already known from
        // capture evidence is not duplicated; anything new is added and never removes old intervals.
        for (raw, ranges) in report.sourceRanges ?? [:] {
            guard let source = SourceKind(rawValue: raw) else { continue }
            for r in ranges where !alreadyKnown(r, source: source, in: ledger) {
                ledger.record(Anomaly(source: source, range: r, kind: .missing, reason: .fileGap))
            }
        }
        if report.sourceRanges == nil {
            for r in report.detectedRanges {
                for s in contract.requiredSources where !alreadyKnown(r, source: s, in: ledger) {
                    ledger.record(Anomaly(source: s, range: r, kind: .damaged, reason: .segmentCorrupt))
                }
            }
        }
    }

    static func alreadyKnown(_ r: MediaRange, source: SourceKind, in ledger: AnomalyLedger) -> Bool {
        ledger.open(for: source).contains { a in
            let overlap = min(a.range.end.seconds, r.end.seconds) - max(a.range.start.seconds, r.start.seconds)
            return overlap >= 0.8 * r.duration
        }
    }
}
