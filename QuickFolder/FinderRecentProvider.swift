import AppKit
import Foundation

struct RecentFolderCandidate: Hashable {
    let url: URL
    let lastSeenAt: Date?
}

final class FinderRecentProvider {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func recentFolders(limit: Int) -> [RecentFolderCandidate] {
        let documentControllerCandidates = NSDocumentController.shared.recentDocumentURLs.compactMap { url -> RecentFolderCandidate? in
            guard let directoryURL = directoryURL(for: url) else { return nil }
            return RecentFolderCandidate(url: directoryURL, lastSeenAt: nil)
        }

        let sharedFileListCandidates = sharedFileListURLs().flatMap { url in
            recentFolders(fromSharedFileListAt: url)
        }

        var seen = Set<String>()
        return (sharedFileListCandidates + documentControllerCandidates).compactMap { candidate in
            guard let directoryURL = directoryURL(for: candidate.url) else { return nil }
            let path = canonicalPath(for: directoryURL)
            guard seen.insert(path).inserted else { return nil }
            return RecentFolderCandidate(
                url: URL(fileURLWithPath: path, isDirectory: true),
                lastSeenAt: candidate.lastSeenAt
            )
        }
        .prefix(limit)
        .map { $0 }
    }

    private func directoryURL(for url: URL) -> URL? {
        var isDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue ? url : url.deletingLastPathComponent()
        }

        let parent = url.deletingLastPathComponent()
        var parentIsDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory),
              parentIsDirectory.boolValue else {
            return nil
        }
        return parent
    }

    private func sharedFileListURLs() -> [URL] {
        let baseURL = fileManager
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.sharedfilelist", isDirectory: true)

        let directListNames = [
            "com.apple.LSSharedFileList.RecentDocuments",
            "com.apple.LSSharedFileList.FavoriteItems",
            "com.apple.LSSharedFileList.ProjectsItems"
        ]

        let directURLs = directListNames.flatMap { name in
            ["sfl4", "sfl3", "sfl2"].map { fileExtension in
                baseURL.appendingPathComponent("\(name).\(fileExtension)", isDirectory: false)
            }
        }

        let finderAppURLs = ["sfl4", "sfl3", "sfl2"].map { fileExtension in
            baseURL
                .appendingPathComponent("com.apple.LSSharedFileList.ApplicationRecentDocuments", isDirectory: true)
                .appendingPathComponent("com.apple.finder.\(fileExtension)", isDirectory: false)
        }

        return (directURLs + finderAppURLs).filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func recentFolders(fromSharedFileListAt url: URL) -> [RecentFolderCandidate] {
        guard let data = try? Data(contentsOf: url),
              let archive = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any],
              let items = archive["items"] as? [[String: Any]] else {
            return []
        }

        let baseDate = ((try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date) ?? Date()

        return items.enumerated().compactMap { index, item in
            guard let bookmarkData = item["Bookmark"] as? Data,
                  let resolvedURL = resolveBookmark(bookmarkData),
                  let directoryURL = directoryURL(for: resolvedURL) else {
                return nil
            }

            return RecentFolderCandidate(
                url: directoryURL,
                lastSeenAt: baseDate.addingTimeInterval(TimeInterval(-index))
            )
        }
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }

        return try? URL(
            resolvingBookmarkData: data,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private func canonicalPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
