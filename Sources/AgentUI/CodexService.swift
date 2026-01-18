import Foundation
import AppKit

@MainActor
class CodexService: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: String?

    private let codexDir: URL
    private let sessionsDir: URL

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.codexDir = homeDir.appendingPathComponent(".codex")
        self.sessionsDir = codexDir.appendingPathComponent("sessions")
    }

    func loadProjects() {
        isLoading = true
        error = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Find all .jsonl files recursively in sessions directory
            let sessionFiles = self.findSessionFiles(in: self.sessionsDir)

            // Group sessions by project (cwd)
            var projectMap: [String: [Session]] = [:]

            for file in sessionFiles {
                if let sessionInfo = self.parseSessionFile(file) {
                    let projectPath = sessionInfo.cwd
                    if projectMap[projectPath] == nil {
                        projectMap[projectPath] = []
                    }
                    projectMap[projectPath]?.append(sessionInfo.session)
                }
            }

            // Convert to Project objects
            var loadedProjects: [Project] = []
            for (path, sessions) in projectMap {
                var project = Project(decodedPath: path)
                project.sessions = sessions.sorted { $0.modifiedDate > $1.modifiedDate }
                loadedProjects.append(project)
            }

            // Sort by most recent session
            loadedProjects.sort { p1, p2 in
                let date1 = p1.sessions.first?.modifiedDate ?? .distantPast
                let date2 = p2.sessions.first?.modifiedDate ?? .distantPast
                return date1 > date2
            }

            DispatchQueue.main.async {
                self.projects = loadedProjects
                self.isLoading = false
            }
        }
    }

    nonisolated private func findSessionFiles(in directory: URL) -> [URL] {
        var files: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "jsonl" {
                files.append(fileURL)
            }
        }

        return files
    }

    nonisolated private func parseSessionFile(_ file: URL) -> (cwd: String, session: Session)? {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return nil }

        var cwd: String?
        var sessionId: String?
        var timestamp: Date?
        var model: String?
        var tokens = TokenStats()

        let lines = content.components(separatedBy: .newlines)
        for line in lines where !line.isEmpty {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // Look for session_meta type
            if json["type"] as? String == "session_meta",
               let payload = json["payload"] as? [String: Any] {
                cwd = payload["cwd"] as? String
                sessionId = payload["id"] as? String

                if let ts = payload["timestamp"] as? String {
                    timestamp = codexISO8601Formatter.date(from: ts)
                }
            }

            // Look for turn_context to get model
            if json["type"] as? String == "turn_context",
               let payload = json["payload"] as? [String: Any],
               let m = payload["model"] as? String {
                model = m
            }

            // Look for token_count events
            if json["type"] as? String == "event_msg",
               let payload = json["payload"] as? [String: Any],
               payload["type"] as? String == "token_count",
               let info = payload["info"] as? [String: Any],
               let lastUsage = info["last_token_usage"] as? [String: Any] {

                if let inputTokens = lastUsage["input_tokens"] as? Int {
                    tokens.inputTokens += inputTokens
                }
                if let outputTokens = lastUsage["output_tokens"] as? Int {
                    tokens.outputTokens += outputTokens
                }
                if let cachedInput = lastUsage["cached_input_tokens"] as? Int {
                    tokens.cacheReadTokens += cachedInput
                }
            }
        }

        guard let cwd = cwd, let sessionId = sessionId else {
            return nil
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
        let modifiedDate = attributes?[.modificationDate] as? Date ?? Date.distantPast
        let fileSize = attributes?[.size] as? Int64 ?? 0

        var session = Session(
            id: sessionId,
            filePath: file.path,
            modifiedDate: timestamp ?? modifiedDate,
            fileSize: fileSize,
            summary: nil,
            gitBranch: nil,
            slug: nil,
            isAgent: false
        )

        session.inputTokens = tokens.inputTokens
        session.outputTokens = tokens.outputTokens
        session.cacheReadTokens = tokens.cacheReadTokens
        session.model = model

        return (cwd, session)
    }

    struct TokenStats {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheReadTokens: Int = 0
    }

    // MARK: - Session Preview

    nonisolated func getSessionPreview(for session: Session, maxMessages: Int = 4) -> [SessionMessage] {
        guard let content = try? String(contentsOfFile: session.filePath, encoding: .utf8) else {
            return []
        }

        var messages: [SessionMessage] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines where !line.isEmpty {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = json["type"] as? String else {
                continue
            }

            // Codex uses response_item for messages
            if type == "response_item",
               let payload = json["payload"] as? [String: Any],
               let role = payload["role"] as? String,
               let contentArray = payload["content"] as? [[String: Any]] {

                for item in contentArray {
                    if item["type"] as? String == "input_text",
                       let text = item["text"] as? String {
                        messages.append(SessionMessage(role: role == "user" ? .user : .assistant, content: text))
                        break
                    }
                    if item["type"] as? String == "output_text",
                       let text = item["text"] as? String {
                        messages.append(SessionMessage(role: .assistant, content: text))
                        break
                    }
                }
            }

            // Also check event_msg for user messages
            if type == "event_msg",
               let payload = json["payload"] as? [String: Any],
               payload["type"] as? String == "user_message",
               let message = payload["message"] as? String {
                messages.append(SessionMessage(role: .user, content: message))
            }
        }

        // Return last N messages
        return Array(messages.suffix(maxMessages))
    }

    // MARK: - Actions

    func openNewSession(in project: Project) {
        let command = "cd '\(project.decodedPath)' && codex"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }

    func openNewProjectSession() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select or create a directory for your new project"
        panel.prompt = "Start Session"

        if panel.runModal() == .OK, let url = panel.url {
            let command = "cd '\(url.path)' && codex"
            _ = TerminalLauncher.runInITermOnly(command: command)

            // Reload projects after a short delay to pick up the new session
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.loadProjects()
            }
        }
    }

    func resumeSession(_ session: Session, in project: Project) {
        let command = "cd '\(project.decodedPath)' && codex resume '\(session.id)'"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }

    func continueLatestSession(in project: Project) {
        let command = "cd '\(project.decodedPath)' && codex resume --last"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }

    func forkSession(_ session: Session, in project: Project) {
        // Codex doesn't have fork, just resume
        resumeSession(session, in: project)
    }

}

// Nonisolated reusable date formatter for Codex timestamps
fileprivate let codexISO8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
