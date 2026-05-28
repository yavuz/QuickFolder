import AppKit
import Foundation

@MainActor
final class FolderStore: ObservableObject {
    @Published private(set) var items: [FolderItem] = []
    @Published var errorMessage: String?

    private let fileManager: FileManager
    private let finderRecentProvider: FinderRecentProvider

    init(
        fileManager: FileManager = .default,
        finderRecentProvider: FinderRecentProvider = FinderRecentProvider()
    ) {
        self.fileManager = fileManager
        self.finderRecentProvider = finderRecentProvider
        load()
        refreshFinderRecents()
    }

    var pinnedItems: [FolderItem] {
        items
            .filter(\.isPinned)
            .sorted { left, right in
                left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
            }
    }

    var recentItems: [FolderItem] {
        let pinnedIDs = Set(pinnedItems.map(\.id))
        return items
            .filter { !pinnedIDs.contains($0.id) && $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(recentLimit)
            .map { $0 }
    }

    var allVisibleItems: [FolderItem] {
        pinnedItems + recentItems
    }

    func chooseAndPinFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Pin"
        panel.message = "Choose folders to keep in QuickFolder."

        guard panel.runModal() == .OK else { return }

        panel.urls.forEach { url in
            upsertFolder(url: url, isPinned: true, source: .manual, openedAt: nil)
        }
        save()
    }

    func openFolder(_ item: FolderItem) {
        guard let index = index(for: item) else { return }
        guard let resolvedURL = resolvedURL(for: items[index]) else {
            errorMessage = "Folder is no longer available."
            return
        }

        var accessWasStarted = false
        if items[index].bookmarkData != nil {
            accessWasStarted = resolvedURL.startAccessingSecurityScopedResource()
        }
        defer {
            if accessWasStarted {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }

        guard itemExists(at: resolvedURL) else {
            errorMessage = "Folder is no longer available."
            items[index].path = canonicalPath(for: resolvedURL)
            save()
            return
        }

        NSWorkspace.shared.open(resolvedURL)
        items[index].path = canonicalPath(for: resolvedURL)
        items[index].displayName = displayName(for: resolvedURL)
        items[index].bookmarkData = bookmarkData(for: resolvedURL) ?? items[index].bookmarkData
        items[index].lastOpenedAt = Date()
        items[index].openCount += 1
        if items[index].source == .finder {
            items[index].source = .app
        }
        save()
    }

    func pin(_ item: FolderItem) {
        guard let index = index(for: item) else { return }
        items[index].isPinned = true
        if items[index].source == .finder {
            items[index].source = .manual
        }
        save()
    }

    func unpin(_ item: FolderItem) {
        guard let index = index(for: item) else { return }
        items[index].isPinned = false
        save()
    }

    func removeFromRecents(_ item: FolderItem) {
        guard let index = index(for: item) else { return }
        if items[index].isPinned {
            items[index].lastOpenedAt = nil
            items[index].openCount = 0
        } else {
            items.remove(at: index)
        }
        save()
    }

    func forget(_ item: FolderItem) {
        guard let index = index(for: item) else { return }
        items.remove(at: index)
        save()
    }

    func revealInFinder(_ item: FolderItem) {
        guard let resolvedURL = resolvedURL(for: item) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([resolvedURL])
    }

    func openInTerminal(_ item: FolderItem) {
        guard let resolvedURL = resolvedURL(for: item) else {
            errorMessage = "Folder is no longer available."
            return
        }

        guard itemExists(at: resolvedURL) else {
            errorMessage = "Folder is no longer available."
            return
        }

        do {
            try TerminalLauncher.open(folderURL: resolvedURL, terminal: TerminalApp.selected)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearRecents() {
        items.removeAll { !$0.isPinned }
        for index in items.indices {
            items[index].lastOpenedAt = nil
            items[index].openCount = 0
        }
        save()
    }

    func refreshFinderRecents() {
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.finderHistoryEnabled) else { return }

        let candidates = finderRecentProvider.recentFolders(limit: recentLimit)
        guard !candidates.isEmpty else { return }

        candidates.forEach { candidate in
            upsertFolder(
                url: candidate.url,
                isPinned: false,
                source: .finder,
                openedAt: candidate.lastSeenAt ?? .distantPast
            )
        }
        save()
    }

    private var recentLimit: Int {
        let value = UserDefaults.standard.integer(forKey: PreferenceKeys.recentLimit)
        return [10, 25, 50].contains(value) ? value : 25
    }

    private var storeURL: URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("QuickFolder", isDirectory: true)
            .appendingPathComponent("folders.json", isDirectory: false)
    }

    private func load() {
        do {
            let directory = storeURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            guard fileManager.fileExists(atPath: storeURL.path) else {
                items = []
                return
            }
            let data = try Data(contentsOf: storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([FolderItem].self, from: data)
        } catch {
            errorMessage = "Could not load QuickFolder data."
            items = []
        }
    }

    private func save() {
        do {
            let directory = storeURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: storeURL, options: [.atomic])
        } catch {
            errorMessage = "Could not save QuickFolder data."
        }
    }

    private func upsertFolder(url: URL, isPinned: Bool, source: FolderSource, openedAt: Date?) {
        let path = canonicalPath(for: url)
        if let index = items.firstIndex(where: { canonicalPath(for: $0.url) == path }) {
            items[index].displayName = displayName(for: url)
            items[index].path = path
            items[index].bookmarkData = bookmarkData(for: url) ?? items[index].bookmarkData
            items[index].isPinned = items[index].isPinned || isPinned
            items[index].lastOpenedAt = maxDate(items[index].lastOpenedAt, openedAt)
            if items[index].source == .finder && source != .finder {
                items[index].source = source
            }
            return
        }

        items.append(
            FolderItem(
                displayName: displayName(for: url),
                path: path,
                bookmarkData: bookmarkData(for: url),
                isPinned: isPinned,
                lastOpenedAt: openedAt,
                openCount: 0,
                source: source
            )
        )
    }

    private func resolvedURL(for item: FolderItem) -> URL? {
        guard let bookmarkData = item.bookmarkData else {
            return item.url
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            return item.url
        }
    }

    private func index(for item: FolderItem) -> Int? {
        items.firstIndex(where: { $0.id == item.id })
    }

    private func displayName(for url: URL) -> String {
        let lastPathComponent = url.lastPathComponent
        return lastPathComponent.isEmpty ? url.path : lastPathComponent
    }

    private func bookmarkData(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
    }

    private func itemExists(at url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func canonicalPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func maxDate(_ left: Date?, _ right: Date?) -> Date? {
        switch (left, right) {
        case let (left?, right?):
            return max(left, right)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }
}
