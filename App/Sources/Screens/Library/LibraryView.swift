import SwiftUI
import CallCaptureCore

/// Recordings library (section 14.6): text-first rows, local title search, sort and outcome
/// filters. Separate first-use empty, no-results and needs-attention states. Rows never decode media.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(EntitlementService.self) private var entitlements
    @State private var showPro = false
    @State private var query = LibraryQuery()
    @State private var renaming: LibraryRow?
    @State private var renameText = ""
    @State private var deleting: LibraryRow?

    var body: some View {
        NavigationStack {
            let rows = query.apply(to: model.library)
            List {
                if !model.recoveredNotice.isEmpty || !model.recoveryCandidates.isEmpty || !model.unreadable.isEmpty {
                    Section { RecoveryBanner() }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    FilterChips(selection: $query.filter)
                        .listRowInsets(EdgeInsets(top: DS.Space.xs, leading: 0, bottom: DS.Space.xs, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(rows) { row in
                        NavigationLink(value: row.id) { RecordingRow(row: row) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { deleting = row } label: { Label("Delete", systemImage: "trash") }
                            }
                            .contextMenu { rowMenu(row) }
                            .accessibilityActions { rowMenu(row) }
                            .accessibilityIdentifier("libraryRow")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay { emptyState(rows: rows) }
            .navigationTitle(String(localized: "Recordings"))
            .searchable(text: $query.text, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search titles"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $query.sort) {
                            Text("Newest first").tag(LibrarySort.newest)
                            Text("Oldest first").tag(LibrarySort.oldest)
                        }
                        Section(entitlements.isPro ? String(localized: "More sorting") : String(localized: "More sorting with Pro")) {
                            ForEach([LibrarySort.longest, .shortest, .title], id: \.self) { option in
                                Button {
                                    if entitlements.isAvailable(.advancedOrganization) { query.sort = option } else { showPro = true }
                                } label: {
                                    if entitlements.isPro {
                                        Label(sortTitle(option), systemImage: query.sort == option ? "checkmark" : "arrow.up.arrow.down")
                                    } else {
                                        Label(sortTitle(option), systemImage: "lock")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityIdentifier("sortMenu")
                }
            }
            .navigationDestination(for: UUID.self) { id in PlayerView(recordingID: id) }
            .sheet(isPresented: $showPro) { NavigationStack { ProView() } }
            .alert(String(localized: "Rename recording"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    if let r = renaming { model.rename(r.id, to: renameText) }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .confirmationDialog(deleteTitle, isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Delete Recording", role: .destructive) {
                    if let d = deleting { model.delete(d.id) }
                    deleting = nil
                }
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: {
                Text("This removes the recording and its saved data from this iPhone. Copies you've already shared or exported aren't affected. This can't be undone.")
            }
            .refreshable { model.refreshLibrary() }
        }
    }

    private func sortTitle(_ s: LibrarySort) -> String {
        switch s {
        case .newest: return String(localized: "Newest first")
        case .oldest: return String(localized: "Oldest first")
        case .longest: return String(localized: "Longest first")
        case .shortest: return String(localized: "Shortest first")
        case .title: return String(localized: "Title A–Z")
        }
    }

    private var deleteTitle: String {
        String(localized: "Delete “\(deleting?.title ?? "")”?")
    }

    @ViewBuilder private func rowMenu(_ row: LibraryRow) -> some View {
        Button { renameText = row.title; renaming = row } label: { Label("Rename", systemImage: "pencil") }
        if let url = model.masterURL(row.id) {
            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
        }
        Button(role: .destructive) { deleting = row } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder private func emptyState(rows: [LibraryRow]) -> some View {
        if model.library.isEmpty && model.recoveryCandidates.isEmpty {
            EmptyState(systemImage: "waveform", title: String(localized: "No recordings yet"),
                       message: String(localized: "Recordings you make appear here, with what was captured and anything missing."),
                       actionTitle: String(localized: "Start a recording")) { model.selectedTab = .record }
        } else if rows.isEmpty {
            ContentUnavailableView.search(text: query.text)
        }
    }
}

struct FilterChips: View {
    @Binding var selection: LibraryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.s) {
                ForEach(LibraryFilter.allCases, id: \.self) { f in
                    Button {
                        selection = f
                    } label: {
                        Text(title(f))
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, DS.Space.m)
                            .frame(minHeight: 36)
                            .foregroundStyle(selection == f ? Color.white : Color.primary)
                            .background(selection == f ? DS.Palette.accentButton : DS.Palette.card, in: Capsule())
                            .overlay(Capsule().strokeBorder(DS.Palette.separator.opacity(selection == f ? 0 : 1)))
                            .frame(minHeight: DS.Size.minimumTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == f ? .isSelected : [])
                    .accessibilityIdentifier("filter-\(f.rawValue)")
                }
            }
            .padding(.horizontal, DS.Space.l)
        }
    }

    private func title(_ f: LibraryFilter) -> String {
        switch f {
        case .all: return String(localized: "All")
        case .partial: return String(localized: "Partial")
        case .recovered: return String(localized: "Recovered")
        case .bookmarked: return String(localized: "Bookmarked")
        case .needsAttention: return String(localized: "Needs attention")
        }
    }
}

/// Recovery results and items needing attention (section 11, UX11). Never implies capture continued.
struct RecoveryBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            if !model.recoveredNotice.isEmpty {
                HStack(alignment: .top, spacing: DS.Space.m) {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(DS.Palette.accent).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text("^[\(model.recoveredNotice.count) recording](inflect: true) recovered after CallCapture closed unexpectedly")
                            .font(.callout.weight(.semibold))
                        Text("Recording didn't continue after the app closed. The end of each recovered recording may be missing.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("OK") { model.dismissRecoveredNotice() }.frame(minHeight: DS.Size.minimumTarget)
                    }
                }
            }
            ForEach(model.recoveryCandidates) { c in
                HStack(alignment: .top, spacing: DS.Space.m) {
                    Image(systemName: c.status == .waitingForUnlock ? "lock" : "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Palette.warning).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(c.title).font(.callout.weight(.semibold))
                        Text(c.reason ?? String(localized: "Kept safely. Not shown in your library until it can be opened."))
                            .font(.footnote).foregroundStyle(.secondary)
                        if c.status == .recoverable || (c.status == .quarantined && !c.validSegments.isEmpty) {
                            Button("Try again") { Task { await model.retryRecovery(c) } }
                                .disabled(model.isSessionActive || model.isRecovering)
                                .frame(minHeight: DS.Size.minimumTarget)
                        }
                    }
                }
            }
            ForEach(model.unreadable) { u in
                Label(u.isFutureVersion ? String(localized: "A recording made by a newer CallCapture is kept unchanged.")
                                        : String(localized: "A recording's details couldn't be read. It's kept unchanged."),
                      systemImage: "doc.badge.ellipsis")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityIdentifier("recoveryBanner")
    }
}
