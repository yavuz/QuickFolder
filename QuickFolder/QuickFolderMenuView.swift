import AppKit
import SwiftUI

struct QuickFolderMenuView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: FolderStore
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    @AppStorage(PreferenceKeys.pinnedSectionExpanded) private var pinnedSectionExpanded = true
    @AppStorage(PreferenceKeys.recentSectionExpanded) private var recentSectionExpanded = true

    private var filteredPinned: [FolderItem] {
        filter(store.pinnedItems)
    }

    private var filteredRecent: [FolderItem] {
        filter(store.recentItems)
    }

    private var firstResult: FolderItem? {
        filteredPinned.first ?? filteredRecent.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 396, height: 540)
        .background(.regularMaterial)
        .onAppear {
            store.refreshFinderRecents()
            focusSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didShowNotification)) { _ in
            focusSearch()
        }
        .onSubmit {
            if let firstResult {
                store.openFolder(firstResult)
            }
        }
        .onExitCommand {
            NSApp.keyWindow?.close()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text("QuickFolder")
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(store.pinnedItems.count) pinned · \(store.recentItems.count) recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.chooseAndPinFolder()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Pin folder")

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search folders", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(16)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let errorMessage = store.errorMessage {
                    errorBanner(errorMessage)
                }

                section(
                    title: "Pinned",
                    items: filteredPinned,
                    isExpanded: $pinnedSectionExpanded,
                    emptySystemImage: "pin",
                    emptyTitle: "No pinned folders"
                )
                section(
                    title: "Recent",
                    items: filteredRecent,
                    isExpanded: $recentSectionExpanded,
                    emptySystemImage: "clock",
                    emptyTitle: "No recent folders"
                )
            }
            .padding(16)
        }
        .scrollIndicators(.automatic)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                store.chooseAndPinFolder()
            } label: {
                Label("Pin Folder", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit QuickFolder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func section(
        title: String,
        items: [FolderItem],
        isExpanded: Binding<Bool>,
        emptySystemImage: String,
        emptyTitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\(items.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                if items.isEmpty {
                    EmptySectionView(systemImage: emptySystemImage, title: emptyTitle)
                } else {
                    VStack(spacing: 6) {
                        ForEach(items) { item in
                            FolderRowView(item: item)
                                .environmentObject(store)
                        }
                    }
                }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func filter(_ items: [FolderItem]) -> [FolderItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }

        return items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                || item.path.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func focusSearch() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            isSearchFocused = true
        }
    }
}

private struct EmptySectionView: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
