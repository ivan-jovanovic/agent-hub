import AppKit
import Foundation

@MainActor
enum TerminalLauncher {
    // Known iTerm bundle identifiers (stable, beta, Setapp)
    private static let iTermBundleIds = [
        "com.googlecode.iterm2",
        "com.googlecode.iterm2.beta",
        "com.iterm2.Setapp"
    ]

    private static func installedITermBundleId() -> String? {
        for id in iTermBundleIds {
            if isAppInstalled(bundleId: id) { return id }
        }
        return nil
    }
    /// Launch the command in iTerm if available; otherwise fall back to Terminal.app.
    /// Returns true when the script was dispatched to a terminal successfully.
    @discardableResult
    static func run(command: String) -> Bool {
        if let bundleId = installedITermBundleId() {
            let ok = runAppleScript(iTermAppleScript(for: command, bundleId: bundleId))
            if ok { return true }
        }
        // Fallback to Terminal.app
        return runAppleScript(terminalAppleScript(for: command))
    }

    /// Launch the command in iTerm only (no fallback). Returns true on success.
    @discardableResult
    static func runInITermOnly(command: String) -> Bool {
        guard let bundleId = installedITermBundleId() else { return false }
        return runAppleScript(iTermAppleScript(for: command, bundleId: bundleId))
    }

    private static func iTermAppleScript(for command: String, bundleId: String) -> String {
        let escaped = escapeForAppleScript(command)
        return """
        tell application id "\(bundleId)"
            activate
            if (count of windows) > 0 then
                tell current window
                    set newTab to (create tab with default profile)
                    tell current session of newTab
                        write text "\(escaped)"
                    end tell
                end tell
            else
                set newWindow to (create window with default profile)
                tell current session of newWindow
                    write text "\(escaped)"
                end tell
            end if
        end tell
        """
    }

    private static func terminalAppleScript(for command: String) -> String {
        let escaped = escapeForAppleScript(command)
        return """
        tell application "Terminal"
            activate
            if (count of windows) is 0 then
                do script "\(escaped)"
            else
                do script "\(escaped)" in front window
            end if
        end tell
        """
    }

    /// Escape a shell command so it can be embedded in an AppleScript string literal safely.
    private static func escapeForAppleScript(_ value: String) -> String {
        var s = value
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\"", with: "\\\"")
        s = s.replacingOccurrences(of: "\n", with: " ")
        return s
    }

    @discardableResult
    private static func runAppleScript(_ script: String) -> Bool {
        var errorInfo: NSDictionary?
        guard let object = NSAppleScript(source: script) else { return false }
        object.executeAndReturnError(&errorInfo)
        if let errorInfo = errorInfo {
            print("AppleScript error: \(errorInfo)")
            return false
        }
        return true
    }

    private static func isAppInstalled(bundleId: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
}
