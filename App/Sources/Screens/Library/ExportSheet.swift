import SwiftUI
import AVFoundation
import Photos
import UniformTypeIdentifiers
import CallCaptureCore

/// Export (section 14.3): native share/Files flows, derived copies only, master preserved (rule 19).
/// Shows completion only when known; never claims a third-party destination finished its work.
struct ExportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let metadata: RecordingMetadata

    enum Status: Equatable {
        case idle
        case preparing(String)
        case done(String)
        case failed(String)
    }

    @State private var status: Status = .idle
    @State private var exportTask: Task<Void, Never>?
    @State private var exportingFile = false
    @State private var audioURL: URL?

    var body: some View {
        NavigationStack {
            List {
                if model.isSessionActive {
                    Section {
                        InlineNotice(text: String(localized: "Exports that create new files wait until the current recording is saved, so they can't interfere with it."),
                                     tone: .accent)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section {
                    if let url = model.masterURL(metadata.id) {
                        ShareLink(item: url, subject: Text(metadata.title)) {
                            SettingsRow(title: String(localized: "Share recording"), systemImage: "square.and.arrow.up",
                                        detail: String(localized: "Video with all audio tracks · \(StatusCopy.bytes(Int64(metadata.byteCount)))"))
                        }
                        Button { exportingFile = true } label: {
                            SettingsRow(title: String(localized: "Save to Files"), systemImage: "folder",
                                        detail: String(localized: "Choose a folder on this iPhone or in iCloud Drive"))
                        }
                        .fileExporter(isPresented: $exportingFile, item: MovieFile(url: url), contentTypes: [.quickTimeMovie],
                                      defaultFilename: metadata.title) { result in
                            if case .success(let saved) = result { status = .done(String(localized: "Saved to \(saved.lastPathComponent)")) }
                        }
                    }
                } footer: {
                    Text("The original stays in CallCapture. Deleting it later doesn't delete copies you've shared.")
                }
                Section {
                    Button { exportAudioOnly() } label: {
                        SettingsRow(title: String(localized: "Create audio-only copy"), systemImage: "waveform",
                                    detail: String(localized: "A separate M4A file; the original is unchanged"))
                    }
                    .disabled(isBusy || model.isSessionActive)
                    if let audioURL {
                        ShareLink(item: audioURL) {
                            SettingsRow(title: String(localized: "Share audio-only copy"), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button { addToPhotos() } label: {
                        SettingsRow(title: String(localized: "Add to Photos"), systemImage: "photo.on.rectangle",
                                    detail: String(localized: "Add-only: CallCapture can't see your library"))
                    }
                    .disabled(isBusy || model.isSessionActive || metadata.contract.mode == .audioOnly)
                }
                Section { statusView }
            }
            .navigationTitle(String(localized: "Export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isBusy ? String(localized: "Cancel export") : String(localized: "Done")) {
                        if isBusy {
                            exportTask?.cancel()
                            status = .failed(String(localized: "Export cancelled. The original is unchanged."))
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var isBusy: Bool { if case .preparing = status { return true }; return false }

    @ViewBuilder private var statusView: some View {
        switch status {
        case .idle: EmptyView()
        case .preparing(let text):
            HStack { ProgressView(); Text(text) }
        case .done(let text):
            Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(DS.Palette.pass)
        case .failed(let text):
            Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(DS.Palette.warning)
        }
    }

    private func exportAudioOnly() {
        guard let source = model.masterURL(metadata.id) else { return }
        let dir = model.layout.exports.appendingPathComponent(metadata.id.uuidString, isDirectory: true)
        let target = dir.appendingPathComponent("audio.m4a")
        status = .preparing(String(localized: "Creating audio-only copy…"))
        exportTask = Task {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                let asset = AVURLAsset(url: source)
                guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                    throw CocoaError(.featureUnsupported)
                }
                try await session.export(to: target, as: .m4a)
                try Task.checkCancellation()
                try? model.store.update(metadata.id) { m in
                    m.derived.removeAll { $0.kind == .audioOnly }
                    m.derived.append(DerivedArtifact(kind: .audioOnly, fileName: "audio.m4a", createdAt: Date()))
                }
                audioURL = target
                status = .done(String(localized: "Audio-only copy ready"))
            } catch is CancellationError {
                try? FileManager.default.removeItem(at: target)
            } catch {
                try? FileManager.default.removeItem(at: target)
                status = .failed(String(localized: "Couldn't create the audio copy. The original is unchanged."))
            }
        }
    }

    private func addToPhotos() {
        guard let source = model.masterURL(metadata.id) else { return }
        status = .preparing(String(localized: "Adding to Photos…"))
        exportTask = Task {
            let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard auth == .authorized || auth == .limited else {
                status = .failed(String(localized: "Photos access wasn't allowed. You can change this in Settings."))
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = false   // copy: the master stays in CallCapture
                    request.addResource(with: .video, fileURL: source, options: options)
                }
                status = .done(String(localized: "Added to Photos"))
            } catch {
                status = .failed(String(localized: "Couldn't add to Photos. The original is unchanged."))
            }
        }
    }
}

/// Transferable wrapper so the Files exporter copies the master (never moves it).
struct MovieFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .quickTimeMovie) { file in SentTransferredFile(file.url, allowAccessingOriginalFile: false) }
    }
}
