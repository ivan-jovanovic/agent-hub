import Foundation

struct CodexUsageSnapshot {
    let sessionUsedPercent: Int
    let sessionResetText: String?
    let weeklyUsedPercent: Int?
    let weeklyResetText: String?

    var sessionLeftPercent: Int { max(0, 100 - sessionUsedPercent) }
    var weeklyLeftPercent: Int? { weeklyUsedPercent.map { max(0, 100 - $0) } }
}

enum CodexStatusProbe {
    static func fetch(timeoutSeconds: TimeInterval = 8) async throws -> CodexUsageSnapshot {
        // Skip RPC - use PTY directly like CodexBar does
        // Use PTY runner (no external Terminal window) - like CodexBar
        do {
            let runner = TTYCommandRunner()
            let result = try runner.runCodexStatus(timeout: max(timeoutSeconds, 18))
            let clean = stripANSIEscape(result.text)
            debugDump(clean)  // Always dump for debugging
            if let snap = parseStatus(clean) {
                return snap
            }
            throw NSError(domain: "CodexStatus", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not parse Codex /status output."])
        } catch {
            if case PTYError.timedOut = error {
                debugDump("pty-timeout")
            }
            throw NSError(domain: "CodexStatus", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not parse Codex /status output."])
        }
    }

    // MARK: - Helpers

    private static func stripANSIEscape(_ s: String) -> String {
        // Remove ANSI CSI escape sequences and control characters commonly used in TUIs
        // Use explicit ESC character to avoid Swift unicode escape pitfalls
        let pattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        var out = regex?.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "") ?? s
        // Strip OSC sequences (title/color updates).
        let oscPattern = "\u{001B}\\][^\u{0007}\u{001B}]*(\u{0007}|\u{001B}\\\\)"
        out = out.replacingOccurrences(of: oscPattern, with: "", options: .regularExpression)
        // Strip single-character ESC sequences (e.g. RI).
        out = out.replacingOccurrences(of: "\u{001B}[A-Za-z]", with: "", options: .regularExpression)
        let extraCtrlPattern = "\u{001B}(=|>|>|7|8)"
        out = out.replacingOccurrences(of: extraCtrlPattern, with: "", options: NSString.CompareOptions.regularExpression)
        // Normalize carriage returns that some TUI apps emit
        out = out.replacingOccurrences(of: "\r", with: "")
        return out
    }

    private static func debugDump(_ text: String) {
        do {
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/AgentHub")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("codex-status.txt")
            try text.data(using: .utf8)?.write(to: url)
        } catch {
            // ignore
        }
    }

    private static func parseStatus(_ text: String) -> CodexUsageSnapshot? {
        // Check for known error conditions
        let lower = text.lowercased()
        if lower.contains("data not available yet") {
            return nil
        }
        if lower.contains("update available") && lower.contains("codex") {
            return nil
        }

        // Look for lines like:
        //  "5h limit:       [████░░░░░░] 40% left (resets 04:49)"
        //  "Weekly limit:   [██████████] 68% left (resets 16:32)"
        // Or older format:
        //  "5h limit:       [....] 5% used (resets 04:49)"
        var sessionLeft: Int?
        var sessionReset: String?
        var weeklyLeft: Int?
        var weeklyReset: String?

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let lowerLine = line.lowercased()
            if lowerLine.contains("run /status") || lowerLine.contains("heads up") {
                continue
            }
            guard line.contains("%") else { continue }
            let isRelevant = lowerLine.contains("limit") ||
                lowerLine.contains("session") ||
                lowerLine.contains("week") ||
                lowerLine.contains("window") ||
                lowerLine.contains("usage") ||
                lowerLine.contains("5h") ||
                lowerLine.contains("5-hour")
            guard isRelevant else { continue }
            let (pct, rst) = extractPercentLeft(line)
            guard let pct else { continue }
            if lowerLine.contains("weekly") || lowerLine.contains("week") {
                weeklyLeft = pct
                weeklyReset = rst
                continue
            }
            if lowerLine.contains("session") || lowerLine.contains("5h") || lowerLine.contains("5-hour") || lowerLine.contains("current") {
                sessionLeft = pct
                sessionReset = rst
                continue
            }
            if lowerLine.contains("limit") || lowerLine.contains("usage") || lowerLine.contains("window") {
                if sessionLeft == nil {
                    sessionLeft = pct
                    sessionReset = rst
                } else if weeklyLeft == nil {
                    weeklyLeft = pct
                    weeklyReset = rst
                }
            }
        }

        guard let sl = sessionLeft else { return nil }
        // Convert "% left" to "% used" for the snapshot
        return CodexUsageSnapshot(
            sessionUsedPercent: max(0, 100 - sl),
            sessionResetText: sessionReset,
            weeklyUsedPercent: weeklyLeft.map { max(0, 100 - $0) },
            weeklyResetText: weeklyReset)
    }

    private static func extractPercentLeft(_ line: String) -> (Int?, String?) {
        // Try "% left" format first (newer Codex output)
        let leftPattern = "([0-9]{1,3})%\\s+(left|remaining)"
        if let regex = try? NSRegularExpression(pattern: leftPattern, options: .caseInsensitive) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let m = regex.firstMatch(in: line, options: [], range: range),
               let r = Range(m.range(at: 1), in: line),
               let pct = Int(line[r]) {
                let reset = extractResetString(line)
                return (pct, reset)
            }
        }

        // Fallback to "% used" format (older Codex output)
        let usedPattern = "([0-9]{1,3})%\\s+used"
        if let regex = try? NSRegularExpression(pattern: usedPattern, options: .caseInsensitive) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let m = regex.firstMatch(in: line, options: [], range: range),
               let r = Range(m.range(at: 1), in: line),
               let pct = Int(line[r]) {
                let reset = extractResetString(line)
                // Convert used to left
                return (max(0, 100 - pct), reset)
            }
        }

        return (nil, nil)
    }

    private static func extractResetString(_ line: String) -> String? {
        // Match "resets HH:MM" or "(resets HH:MM)"
        let pattern = "resets?\\s+([^\\)\\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let m = regex.firstMatch(in: line, options: [], range: range),
           m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: line) {
            return String(line[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
