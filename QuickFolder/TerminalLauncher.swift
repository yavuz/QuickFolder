import AppKit
import Foundation

enum TerminalApp: String, CaseIterable, Identifiable {
    case terminal
    case ghostty
    case iterm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: return "macOS Terminal"
        case .ghostty: return "Ghostty"
        case .iterm: return "iTerm"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .ghostty: return "com.mitchellh.ghostty"
        case .iterm: return "com.googlecode.iterm2"
        }
    }

    static var selected: TerminalApp {
        let value = UserDefaults.standard.string(forKey: PreferenceKeys.selectedTerminal)
        return TerminalApp(rawValue: value ?? "") ?? .terminal
    }
}

enum TerminalLaunchError: LocalizedError {
    case appNotFound(String)
    case scriptFailed(String)
    case automationDenied(String)

    var errorDescription: String? {
        switch self {
        case let .appNotFound(name):
            return "\(name) could not be found."
        case let .scriptFailed(message):
            return message
        case let .automationDenied(name):
            return "QuickFolder needs Automation permission to control \(name). Allow it in System Settings > Privacy & Security > Automation."
        }
    }
}

enum TerminalLauncher {
    @MainActor
    static func open(folderURL: URL, terminal: TerminalApp) throws {
        switch terminal {
        case .terminal:
            try openFolderDocument(folderURL, with: .terminal)
        case .iterm:
            try runAppleScript(iTermScript(for: folderURL), appName: TerminalApp.iterm.displayName)
        case .ghostty:
            try openGhostty(at: folderURL)
        }
    }

    private static func iTermScript(for folderURL: URL) -> String {
        """
        set targetPath to "\(folderURL.path.appleScriptEscaped)"
        tell application "iTerm"
            activate
            if (count of windows) = 0 then
                create window with default profile
            end if
            tell current session of current window
                write text "cd " & quoted form of targetPath
            end tell
        end tell
        """
    }

    private static func openFolderDocument(_ folderURL: URL, with terminal: TerminalApp) throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) else {
            throw TerminalLaunchError.appNotFound(terminal.displayName)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error {
                NSLog("QuickFolder could not open folder in \(terminal.displayName): \(error.localizedDescription)")
            }
        }
    }

    private static func runAppleScript(_ source: String, appName: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw TerminalLaunchError.scriptFailed("Could not create terminal script.")
        }

        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
                throw TerminalLaunchError.automationDenied(appName)
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Could not open folder in terminal."
            throw TerminalLaunchError.scriptFailed(message)
        }
    }

    @MainActor
    private static func openGhostty(at folderURL: URL) throws {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: TerminalApp.ghostty.bundleIdentifier) else {
            throw TerminalLaunchError.appNotFound(TerminalApp.ghostty.displayName)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.arguments = ["--working-directory=\(folderURL.path)"]
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
