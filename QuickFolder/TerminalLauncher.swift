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

    /// Application name passed to `/usr/bin/open -a`.
    var openCLIApplicationName: String {
        switch self {
        case .terminal: return "Terminal"
        case .iterm: return "iTerm"
        case .ghostty: return "Ghostty"
        }
    }

    static var selected: TerminalApp {
        let value = UserDefaults.standard.string(forKey: PreferenceKeys.selectedTerminal)
        return TerminalApp(rawValue: value ?? "") ?? .terminal
    }
}

enum TerminalLaunchError: LocalizedError {
    case appNotFound(String)
    case launchFailed(String)
    case automationDenied(String)

    var errorDescription: String? {
        switch self {
        case let .appNotFound(name):
            return "\(name) could not be found."
        case let .launchFailed(message):
            return message
        case let .automationDenied(name):
            return "QuickFolder needs permission to control \(name). Open System Settings → Privacy & Security → Automation and allow QuickFolder for \(name)."
        }
    }
}

enum TerminalLauncher {
    @MainActor
    static func open(folderURL: URL, terminal: TerminalApp) throws {
        switch terminal {
        case .terminal, .iterm:
            try openWithOpenCLI(terminal: terminal, folderURL: folderURL)
        case .ghostty:
            try openGhostty(at: folderURL)
        }
    }

    /// Opens a folder in Terminal/iTerm via `open -a` (no Automation permission required).
    private static func openWithOpenCLI(terminal: TerminalApp, folderURL: URL) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) != nil else {
            throw TerminalLaunchError.appNotFound(terminal.displayName)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", terminal.openCLIApplicationName, folderURL.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TerminalLaunchError.launchFailed("Could not open folder in \(terminal.displayName).")
        }
    }

    /// Ghostty 1.3+ exposes AppleScript for new windows with a working directory.
    private static func openGhostty(at folderURL: URL) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: TerminalApp.ghostty.bundleIdentifier) != nil else {
            throw TerminalLaunchError.appNotFound(TerminalApp.ghostty.displayName)
        }

        let path = folderURL.standardizedFileURL.path
        let script = """
        tell application "Ghostty"
            activate
            set cfg to new surface configuration
            set initial working directory of cfg to "\(path.appleScriptEscaped)"
            new window with configuration cfg
        end tell
        """

        do {
            try runAppleScript(script, appName: TerminalApp.ghostty.displayName)
        } catch let error as TerminalLaunchError {
            if case .automationDenied = error {
                throw error
            }
            throw error
        } catch {
            throw TerminalLaunchError.launchFailed("Could not open folder in Ghostty.")
        }
    }

    private static func runAppleScript(_ source: String, appName: String) throws {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw TerminalLaunchError.launchFailed("Could not create terminal script.")
        }

        script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
                throw TerminalLaunchError.automationDenied(appName)
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? "Could not open folder in terminal."
            throw TerminalLaunchError.launchFailed(message)
        }
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
