import SwiftUI
import CallCaptureCore

/// Pro: the detailed technical report (section 21 "detailed diagnostic/history views").
/// Everything needed to understand an incomplete recording is already free in the player;
/// this adds reason codes, validation coverage and file identity.
struct TechnicalReportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let metadata: RecordingMetadata

    var body: some View {
        let report = try? AtomicJSON.read(ValidationReport.self,
                                          from: model.layout.recordingDirectory(metadata.id).appendingPathComponent("validation.json"))
        List {
            Section(String(localized: "Outcome")) {
                LabeledContent(String(localized: "Result"), value: metadata.outcome.rawValue)
                LabeledContent(String(localized: "Completeness"), value: metadata.completeness.rawValue)
                LabeledContent(String(localized: "File checks"), value: metadata.validation.rawValue)
                if let reason = metadata.endReason { LabeledContent(String(localized: "End reason"), value: reason.rawValue) }
                LabeledContent(String(localized: "Contract"),
                               value: "v\(metadata.contract.version) · \(metadata.contract.mode.rawValue)\(metadata.contract.isImportantMode ? " · important" : "")")
            }
            Section(String(localized: "Sources")) {
                ForEach(metadata.contract.sources, id: \.kind) { p in
                    let s = metadata.sources.first { $0.source == p.kind }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(p.kind.displayName) · \(p.requirement.rawValue)").font(.body.weight(.medium))
                        Text("received \(String(format: "%.1f", s?.receivedSeconds ?? 0)) s · open gaps \(String(format: "%.1f", s?.openAnomalySeconds ?? 0)) s")
                            .font(.footnote.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Section(String(localized: "Intervals")) {
                if metadata.anomalies.isEmpty { Text("None recorded").foregroundStyle(.secondary) }
                ForEach(metadata.anomalies) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(a.source.displayName) · \(a.kind.rawValue) · \(a.range.description)").font(.body.weight(.medium))
                        Text("\(a.reason.rawValue)\(a.isOpen ? "" : " · resolved")").font(.footnote.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            if let report {
                Section(String(localized: "File validation")) {
                    LabeledContent(String(localized: "Coverage"), value: report.coverage.rawValue)
                    LabeledContent(String(localized: "Validator"), value: "v\(report.validatorVersion)")
                    ForEach(report.durations.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                        LabeledContent(item.key, value: String(format: "%.2f s", item.value))
                    }
                    if let hash = report.sha256 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SHA-256").font(.footnote)
                            Text(hash).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                    ForEach(report.notes, id: \.self) { Text($0).font(.footnote.monospaced()) }
                }
            }
            Section {
                Text("A matching checksum shows the file hasn't changed since it was checked. It doesn't certify what was said or who took part.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "Technical report"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
