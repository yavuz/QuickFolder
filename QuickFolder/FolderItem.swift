import Foundation

enum FolderSource: String, Codable, CaseIterable {
    case app
    case finder
    case manual
}

struct FolderItem: Identifiable, Codable, Equatable {
    var id: UUID
    var displayName: String
    var path: String
    var bookmarkData: Data?
    var isPinned: Bool
    var lastOpenedAt: Date?
    var openCount: Int
    var source: FolderSource

    init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        bookmarkData: Data?,
        isPinned: Bool,
        lastOpenedAt: Date?,
        openCount: Int,
        source: FolderSource
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.bookmarkData = bookmarkData
        self.isPinned = isPinned
        self.lastOpenedAt = lastOpenedAt
        self.openCount = openCount
        self.source = source
    }

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    var exists: Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    var parentPath: String {
        url.deletingLastPathComponent().path
    }
}
