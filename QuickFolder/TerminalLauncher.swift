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

    var errorDescription: String? {
        switch self {
        case let .appNotFound(name):
            return "\(name) could not be found."
        case let .scriptFailed(message):
            return message
        }
    }
}

enum TerminalLauncher {
    @MainActor
    static func open(folderURL: URL, terminal: TerminalApp) throws {
        switch terminal {
        case .terminal:
            try runAppleScript(terminalScript(for: folderURL))
        case .iterm:
            try runAppleScript(iTermScript(for: folderURL))
        case .ghostty:
            try openGhostty(at: folderURL)
        }
    }

    private static func terminalScript(for folderURL: URL) -> String {
        """
        set targetPath to "\(folderURL.path.appleScriptEscaped)"
        tell application "Terminal"
            activate
            do script "cd " & quoted form of targetPath
        end tell
        """
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

    private static func runAppleScript(_ source: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw TerminalLaunchError.scriptFailed("Could not create terminal script.")
        }

        script.executeAndReturnError(&error)
        if let error {
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
