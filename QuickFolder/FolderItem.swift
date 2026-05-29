import CoreGraphics
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

enum LauncherMode: String, CaseIterable, Identifiable {
    case full
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return "Full panel"
        case .compact: return "Compact launcher"
        }
    }

    var detail: String {
        switch self {
        case .full:
            return "Pinned and Recent sections with full row actions."
        case .compact:
            return "Search-first palette with keyboard navigation."
        }
    }

    static var current: LauncherMode {
        let raw = UserDefaults.standard.string(forKey: PreferenceKeys.launcherMode) ?? LauncherMode.full.rawValue
        return LauncherMode(rawValue: raw) ?? .full
    }

    var contentSize: CGSize {
        switch self {
        case .full:
            return CGSize(width: 396, height: 540)
        case .compact:
            return CGSize(width: 420, height: 360)
        }
    }
}

enum LauncherPosition: String, CaseIterable, Identifiable {
    case menuBar
    case centerScreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .menuBar: return "Menu bar"
        case .centerScreen: return "Center screen"
        }
    }

    var detail: String {
        switch self {
        case .menuBar:
            return "Opens below the menu bar icon, like today."
        case .centerScreen:
            return "Opens in the center of the screen, Spotlight-style (compact launcher only)."
        }
    }

    static var current: LauncherPosition {
        let raw = UserDefaults.standard.string(forKey: PreferenceKeys.launcherPosition)
            ?? LauncherPosition.menuBar.rawValue
        return LauncherPosition(rawValue: raw) ?? .menuBar
    }
}

extension Notification.Name {
    static let launcherModeDidChange = Notification.Name("QuickFolderLauncherModeDidChange")
    static let launcherPositionDidChange = Notification.Name("QuickFolderLauncherPositionDidChange")
    static let quickFolderLauncherDidShow = Notification.Name("QuickFolderLauncherDidShow")
    static let closeQuickFolderPopover = Notification.Name("QuickFolderClosePopover")
}
