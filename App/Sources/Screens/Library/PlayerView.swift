import SwiftUI
import AVFoundation
import AVKit
import CallCaptureCore

/// Player and details (section 14.6): large transport, elapsed/remaining, accessible seeking,
/// bookmarks and a labelled gap timeline from real saved-media data.
struct PlayerView: View {
    @Environment(AppModel.self) private var model
    @Environment(EntitlementService.self) private var entitlements
    let recordingID: UUID

    @State private var player = PlayerController()
    @State private var waveform: [Float]?
    @State private var waveformUnavailable = false
    @State private var showVideo = false
    @State private var showExport = false
    @State private var showBookmarkPrompt = false
    @State private var bookmarkLabel = ""
    @State private var renaming = false
    @State private var renameText = ""
    @State private var confirmDelete = false
    @State private var showReport = false
    @State private var showPro = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let m = model.metadata(recordingID) {
            content(m)
        } else {
            EmptyState(systemImage: "questionmark.folder", title: String(localized: "Recording unavailable"),
                       message: String(localized: "This recording was deleted or can't be opened."))
        }
    }

    private func content(_ m: RecordingMetadata) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Text(m.title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    HStack(spacing: DS.Space.s) {
                        Text(m.createdAt.formatted(date: .abbreviated, time: .shortened))
                        StatusPill(text: StatusCopy.outcome(m.outcome), tone: StatusCopy.outcomeTone(m.outcome))
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: DS.Space.xs, bottom: 0, trailing: DS.Space.xs))
            }

            Section {
                if m.masterFileName != nil, model.masterURL(m.id).map({ FileManager.default.fileExists(atPath: $0.path) }) == true {
                    if showVideo && m.contract.mode != .audioOnly {
                        VideoPlayer(player: player.player)
                            .frame(height: 360)
                            .listRowInsets(EdgeInsets())
                    }
                    GapTimeline(duration: max(m.duration, 0.1), anomalies: m.openAnomalies, bookmarks: m.bookmarks,
                                waveform: waveform, position: player.currentTime) { player.seek(to: $0) }
                        .frame(height: 64)
                        // "waveformReady" marks a preview built from the saved media (UX13 test hook).
                        .accessibilityIdentifier(waveform == nil ? "gapTimeline" : "waveformReady")
                    if waveformUnavailable {
                        Text("Waveform preview unavailable. Playback still works.").font(.footnote).foregroundStyle(.secondary)
                    } else if waveform == nil {
                        Text("Loading preview…").font(.footnote).foregroundStyle(.secondary)
                    }
                    TransportControls(player: player, duration: m.duration)
                } else {
                    InlineNotice(text: String(localized: "The media file for this recording isn't available on this iPhone. Its report is still shown below."))
                }
            }

            if !m.openAnomalies.isEmpty || !m.bookmarks.isEmpty {
                Section(String(localized: "Markers")) {
                    ForEach(m.openAnomalies) { a in
                        Button { player.seek(to: a.range.start.seconds) } label: {
                            TimelineMarker(kind: .gap, title: gapTitle(a), time: a.range.description)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(m.bookmarks) { b in
                        Button { player.seek(to: b.time) } label: {
                            TimelineMarker(kind: .bookmark, title: b.label, time: TimeFormatting.clock(b.time))
                        }
                        .buttonStyle(.plain)
                        .swipeActions { Button(role: .destructive) { model.removeBookmark(m.id, bookmark: b.id) } label: { Label("Remove", systemImage: "trash") } }
                    }
                }
            }

            Section(String(localized: "What was captured")) {
                ForEach(m.sources, id: \.source) { s in
                    LabeledContent(s.source.displayName) {
                        Text(s.everReceived ? (s.openAnomalySeconds > 0.05 ? String(localized: "Partial") : String(localized: "No known gaps"))
                                            : String(localized: "Not received"))
                    }
                }
                LabeledContent(String(localized: "File checks"), value: StatusCopy.validation(m.validation))
                LabeledContent(String(localized: "Size"), value: StatusCopy.bytes(Int64(m.byteCount)))
                Button {
                    if entitlements.isAvailable(.detailedHistory) { showReport = true } else { showPro = true }
                } label: {
                    Label(entitlements.isPro ? String(localized: "Detailed technical report") : String(localized: "Detailed technical report (Pro)"),
                          systemImage: entitlements.isPro ? "doc.text.magnifyingglass" : "lock")
                }
                .frame(minHeight: DS.Size.minimumTarget)
                Text("A playable file doesn't prove everyone in a call was recorded.").font(.footnote).foregroundStyle(.secondary)
            }

            Section {
                Button { bookmarkLabel = ""; showBookmarkPrompt = true } label: { Label("Add bookmark here", systemImage: "bookmark") }
                    .frame(minHeight: DS.Size.minimumTarget)
                Button { showExport = true } label: { Label("Export or share", systemImage: "square.and.arrow.up") }
                    .frame(minHeight: DS.Size.minimumTarget)
                    .disabled(model.masterURL(m.id) == nil)
                    .accessibilityIdentifier("exportButton")
                Button { renameText = m.title; renaming = true } label: { Label("Rename", systemImage: "pencil") }
                    .frame(minHeight: DS.Size.minimumTarget)
                Button(role: .destructive) { confirmDelete = true } label: { Label("Delete recording", systemImage: "trash") }
                    .frame(minHeight: DS.Size.minimumTarget)
            }
        }
        .navigationTitle(String(localized: "Recording"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if m.contract.mode != .audioOnly {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showVideo ? String(localized: "Hide video") : String(localized: "Show video")) { showVideo.toggle() }
                }
            }
        }
        .task(id: m.id) {
            if let url = model.masterURL(m.id) { player.load(url: url) }
            await loadWaveform(m)
        }
        .onDisappear { player.pause() }
        .onChange(of: model.isSessionActive) { _, active in if active { player.pause() } }   // section 14.6
        .sheet(isPresented: $showExport) { ExportSheet(metadata: m) }
        .sheet(isPresented: $showReport) { NavigationStack { TechnicalReportView(metadata: m) } }
        .sheet(isPresented: $showPro) { NavigationStack { ProView() } }
        .alert(String(localized: "Bookmark at \(TimeFormatting.clock(player.currentTime))"), isPresented: $showBookmarkPrompt) {
            TextField("Label", text: $bookmarkLabel)
            Button("Add") {
                model.addBookmark(m.id, at: player.currentTime, label: bookmarkLabel.isEmpty ? String(localized: "Bookmark") : bookmarkLabel)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(String(localized: "Rename recording"), isPresented: $renaming) {
            TextField("Title", text: $renameText)
            Button("Save") { model.rename(m.id, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(String(localized: "Delete “\(m.title)”?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Recording", role: .destructive) {
                player.pause()
                model.delete(m.id)
                dismiss()
            }
        } message: {
            Text("This removes the recording from this iPhone. Copies you've shared aren't affected. This can't be undone.")
        }
    }

    private func gapTitle(_ a: Anomaly) -> String {
        switch a.kind {
        case .missing: return String(localized: "\(a.source.displayName) missing")
        case .inconclusive: return String(localized: "\(a.source.displayName) unconfirmed")
        case .damaged: return String(localized: "\(a.source.displayName) damaged")
        }
    }

    private func loadWaveform(_ m: RecordingMetadata) async {
        guard !model.isSessionActive, let url = model.masterURL(m.id) else {
            waveformUnavailable = model.masterURL(m.id) != nil
            return
        }
        if let peaks = await WaveformService.peaks(for: url, cache: model.layout.waveformCache(m.id)) {
            waveform = peaks
        } else {
            waveformUnavailable = true
        }
    }
}

/// Owns the AVPlayer and publishes time at a modest rate.
@MainActor @Observable
final class PlayerController {
    let player = AVPlayer()
    private(set) var currentTime: Double = 0
    private(set) var isPlaying = false
    private var observer: Any?

    func load(url: URL) {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        if observer == nil {
            observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] t in
                MainActor.assumeIsolated {
                    self?.currentTime = t.seconds.isFinite ? t.seconds : 0
                    self?.isPlaying = self?.player.timeControlStatus == .playing
                }
            }
        }
    }

    func toggle() {
        if player.timeControlStatus == .playing { player.pause() } else { player.play() }
        isPlaying = player.timeControlStatus != .paused
    }

    func pause() { player.pause(); isPlaying = false }

    func seek(to seconds: Double) {
        currentTime = max(0, seconds)
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func skip(_ delta: Double) { seek(to: currentTime + delta) }
}

struct TransportControls: View {
    let player: PlayerController
    let duration: Double

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Slider(value: Binding(get: { min(player.currentTime, duration) }, set: { player.seek(to: $0) }), in: 0...max(duration, 0.1))
                .accessibilityLabel(Text("Playback position"))
                .accessibilityValue(Text("\(TimeFormatting.clock(player.currentTime)) of \(TimeFormatting.clock(duration))"))
            HStack {
                Text(TimeFormatting.clock(player.currentTime)).monospacedDigit()
                Spacer()
                Text("−\(TimeFormatting.clock(max(0, duration - player.currentTime)))").monospacedDigit()
            }
            .font(.footnote).foregroundStyle(.secondary)
            .accessibilityHidden(true)
            HStack(spacing: DS.Space.xxl) {
                Button { player.skip(-15) } label: { Image(systemName: "gobackward.15").font(.title2) }
                    .frame(minWidth: DS.Size.minimumTarget, minHeight: DS.Size.minimumTarget)
                    .accessibilityLabel(Text("Back 15 seconds"))
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(DS.Palette.accentButton, in: Circle())
                }
                .accessibilityLabel(player.isPlaying ? Text("Pause") : Text("Play"))
                .accessibilityIdentifier("playPauseButton")
                Button { player.skip(15) } label: { Image(systemName: "goforward.15").font(.title2) }
                    .frame(minWidth: DS.Size.minimumTarget, minHeight: DS.Size.minimumTarget)
                    .accessibilityLabel(Text("Forward 15 seconds"))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, DS.Space.s)
    }
}

/// Timeline from real saved data. Gaps are drawn as gaps; no waveform is invented across them.
struct GapTimeline: View {
    let duration: Double
    let anomalies: [Anomaly]
    let bookmarks: [Bookmark]
    let waveform: [Float]?
    let position: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(DS.Palette.accentFill)
                if let waveform, !waveform.isEmpty {
                    HStack(alignment: .center, spacing: 1) {
                        ForEach(waveform.indices, id: \.self) { i in
                            let t = Double(i) / Double(waveform.count) * duration
                            let inGap = anomalies.contains { t >= $0.range.start.seconds && t < $0.range.end.seconds && $0.source.isAudio }
                            Capsule().fill(DS.Palette.accent.opacity(inGap ? 0 : 0.55))
                                .frame(height: max(2, CGFloat(waveform[i]) * (geo.size.height - 12)))
                        }
                    }
                    .padding(.horizontal, 2)
                }
                ForEach(anomalies) { a in
                    let x = w * a.range.start.seconds / duration
                    let gw = max(3, w * a.range.duration / duration)
                    Rectangle()
                        .fill(DS.Palette.warningFill)
                        .overlay(Rectangle().strokeBorder(DS.Palette.warning, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        .frame(width: gw)
                        .offset(x: x)
                }
                ForEach(bookmarks) { b in
                    Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(DS.Palette.accent)
                        .offset(x: w * b.time / duration - 4, y: -geo.size.height / 2 + 6)
                }
                Rectangle().fill(DS.Palette.accent).frame(width: 2).offset(x: w * min(position, duration) / duration)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in onSeek(max(0, min(duration, v.location.x / w * duration))) })
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Timeline"))
        .accessibilityValue(Text(anomalies.isEmpty ? String(localized: "No known gaps")
                                 : String(localized: "\(anomalies.count) missing section(s). See Markers.")))
    }
}
