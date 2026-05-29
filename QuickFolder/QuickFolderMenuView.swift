import AppKit
import SwiftUI

struct QuickFolderMenuView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: FolderStore
    @AppStorage(PreferenceKeys.launcherMode) private var launcherMode = LauncherMode.full.rawValue
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
        .onReceive(NotificationCenter.default.publisher(for: .quickFolderLauncherDidShow)) { _ in
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

            Button {
                launcherMode = LauncherMode.compact.rawValue
            } label: {
                Label("Compact", systemImage: "text.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Switch to compact launcher")

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

struct LauncherRootView: View {
    var presentationOverride: LauncherMode?
    @AppStorage(PreferenceKeys.launcherMode) private var launcherMode = LauncherMode.full.rawValue

    private var activeMode: LauncherMode {
        presentationOverride ?? LauncherMode(rawValue: launcherMode) ?? .full
    }

    var body: some View {
        Group {
            switch activeMode {
            case .full:
                QuickFolderMenuView()
            case .compact:
                CompactLauncherView()
            }
        }
        .onChange(of: launcherMode) { _, _ in
            NotificationCenter.default.post(name: .launcherModeDidChange, object: nil)
        }
    }
}

@MainActor
private final class CompactLauncherKeyboardMonitor {
    private var monitor: Any?
    weak var viewModel: CompactLauncherViewModel?

    func start() {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let viewModel = self?.viewModel else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            switch event.keyCode {
            case 36, 76:
                if flags.contains(.command) {
                    viewModel.performCommandReturnAction()
                } else {
                    viewModel.performReturnAction()
                }
                return nil
            case 126:
                viewModel.moveSelection(by: -1)
                return nil
            case 125:
                viewModel.moveSelection(by: 1)
                return nil
            case 53:
                viewModel.closePopover()
                return nil
            default:
                return event
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

@MainActor
final class CompactLauncherViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedIndex = 0

    private let keyboardMonitor = CompactLauncherKeyboardMonitor()
    private weak var store: FolderStore?

    func bind(store: FolderStore) {
        self.store = store
        keyboardMonitor.viewModel = self
    }

    var rankedResults: [FolderItem] {
        guard let store else { return [] }
        return FolderSearchRanker.rankedItems(from: store.allVisibleItems, query: query)
    }

    var selectedItem: FolderItem? {
        guard rankedResults.indices.contains(selectedIndex) else { return nil }
        return rankedResults[selectedIndex]
    }

    func refreshRecents() {
        store?.refreshFinderRecents()
    }

    func resetSelection() {
        selectedIndex = 0
    }

    func clampSelection() {
        guard !rankedResults.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(selectedIndex, rankedResults.count - 1)
    }

    func moveSelection(by offset: Int) {
        guard !rankedResults.isEmpty else { return }
        selectedIndex = (selectedIndex + offset + rankedResults.count) % rankedResults.count
    }

    func performReturnAction() {
        guard let item = selectedItem, let store else { return }
        store.openFolder(item)
        closePopover()
    }

    func performCommandReturnAction() {
        guard let item = selectedItem, let store else { return }
        if store.openInTerminal(item) {
            closePopover()
        }
    }

    func closePopover() {
        NotificationCenter.default.post(name: .closeQuickFolderPopover, object: nil)
    }

    func startKeyboardMonitor() {
        keyboardMonitor.viewModel = self
        keyboardMonitor.start()
    }

    func stopKeyboardMonitor() {
        keyboardMonitor.stop()
    }
}

struct CompactLauncherView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var store: FolderStore
    @AppStorage(PreferenceKeys.launcherMode) private var launcherMode = LauncherMode.compact.rawValue
    @StateObject private var viewModel = CompactLauncherViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
            Divider()
            footer
        }
        .frame(width: 420, height: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            viewModel.bind(store: store)
            viewModel.refreshRecents()
            viewModel.resetSelection()
            focusSearch()
            viewModel.startKeyboardMonitor()
        }
        .onDisappear {
            viewModel.stopKeyboardMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPopover.didShowNotification)) { _ in
            viewModel.bind(store: store)
            viewModel.resetSelection()
            focusSearch()
            viewModel.startKeyboardMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickFolderLauncherDidShow)) { _ in
            viewModel.bind(store: store)
            viewModel.resetSelection()
            focusSearch()
            viewModel.startKeyboardMonitor()
        }
        .onChange(of: viewModel.query) { _, _ in
            viewModel.resetSelection()
        }
        .onChange(of: store.allVisibleItems.count) { _, _ in
            viewModel.clampSelection()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search folders…", text: $viewModel.query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    viewModel.performReturnAction()
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if let errorMessage = store.errorMessage {
                        compactErrorBanner(errorMessage)
                    }

                    if viewModel.rankedResults.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.rankedResults.enumerated()), id: \.element.id) { index, item in
                            CompactFolderRowView(
                                item: item,
                                isSelected: index == viewModel.selectedIndex
                            ) {
                                store.openFolder(item)
                                viewModel.closePopover()
                            }
                            .id(item.id)
                            .onTapGesture {
                                viewModel.selectedIndex = index
                                store.openFolder(item)
                                viewModel.closePopover()
                            }
                            .contextMenu {
                                Button("Open in Finder") {
                                    viewModel.selectedIndex = index
                                    viewModel.performReturnAction()
                                }
                                Button("Open in Terminal") {
                                    viewModel.selectedIndex = index
                                    viewModel.performCommandReturnAction()
                                }
                                .disabled(!item.exists)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .onChange(of: viewModel.selectedIndex) { _, newValue in
                let results = viewModel.rankedResults
                guard results.indices.contains(newValue) else { return }
                proxy.scrollTo(results[newValue].id, anchor: .center)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(emptyStateTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptyStateTitle: String {
        let trimmedQuery = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return "No folders match \"\(trimmedQuery)\""
        }
        return "Pin folders or open one to build your launcher list."
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                store.chooseAndPinFolder()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Pin folder")

            Button {
                launcherMode = LauncherMode.full.rawValue
            } label: {
                Label("Full panel", systemImage: "rectangle.split.2x1")
            }
            .buttonStyle(.borderless)
            .help("Switch to full panel")

            Spacer()

            Text("↵ open  ⌘↵ terminal")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func compactErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button {
                store.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func focusSearch() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            isSearchFocused = true
        }
    }
}

private struct CompactFolderRowView: View {
    let item: FolderItem
    let isSelected: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: item.exists ? "folder.fill" : "exclamationmark.folder.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.exists ? .blue : .orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(item.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(item.exists ? .primary : .secondary)
                            .lineLimit(1)

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                    }

                    Text(item.exists ? item.parentPath : "Unavailable · \(item.parentPath)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.exists)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.22))
        }
        return AnyShapeStyle(.quaternary.opacity(0.45))
    }
}
