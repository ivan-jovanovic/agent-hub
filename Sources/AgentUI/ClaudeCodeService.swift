import Foundation
import AppKit

@MainActor
class ClaudeCodeService: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: String?

    private let claudeDir: URL
    private let projectsDir: URL

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        self.claudeDir = homeDir.appendingPathComponent(".claude")
        self.projectsDir = claudeDir.appendingPathComponent("projects")
    }

    func loadProjects() {
        isLoading = true
        error = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let projectDirs = try FileManager.default.contentsOfDirectory(
                    at: self.projectsDir,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                var loadedProjects: [Project] = []

                for projectDir in projectDirs {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        var project = Project(encodedPath: projectDir.lastPathComponent)
                        project.sessions = self.loadSessions(for: projectDir)
                        loadedProjects.append(project)
                    }
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
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    nonisolated private func loadSessions(for projectDir: URL) -> [Session] {
        var sessions: [Session] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            for file in files where file.pathExtension == "jsonl" {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                let modifiedDate = attributes[.modificationDate] as? Date ?? Date.distantPast
                let fileSize = attributes[.size] as? Int64 ?? 0

                let fileName = file.deletingPathExtension().lastPathComponent
                let isAgent = fileName.hasPrefix("agent-")

                var session = Session(
                    id: fileName,
                    filePath: file.path,
                    modifiedDate: modifiedDate,
                    fileSize: fileSize,
                    isAgent: isAgent
                )

                // Try to extract metadata and token stats from the JSONL file
                if let metadata = extractSessionMetadata(from: file) {
                    session.summary = metadata.summary
                    session.gitBranch = metadata.gitBranch
                    session.slug = metadata.slug
                    session.inputTokens = metadata.tokens.inputTokens
                    session.outputTokens = metadata.tokens.outputTokens
                    session.cacheCreationTokens = metadata.tokens.cacheCreationTokens
                    session.cacheReadTokens = metadata.tokens.cacheReadTokens
                    session.model = metadata.tokens.model
                }

                sessions.append(session)
            }
        } catch {
            print("Error loading sessions: \(error)")
        }

        // Sort by modification date (newest first)
        sessions.sort { $0.modifiedDate > $1.modifiedDate }

        return sessions
    }

    nonisolated private func extractSessionMetadata(from file: URL) -> (summary: String?, gitBranch: String?, slug: String?, tokens: TokenStats)? {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { return nil }

        var summary: String?
        var gitBranch: String?
        var slug: String?
        var tokens = TokenStats()

        let lines = content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() where !line.isEmpty {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            // Check for summary type (usually in first few lines)
            if index < 10 {
                if json["type"] as? String == "summary",
                   let summaryText = json["summary"] as? String {
                    summary = summaryText
                }

                if let branch = json["gitBranch"] as? String {
                    gitBranch = branch
                }
                if let s = json["slug"] as? String {
                    slug = s
                }
            }

            // Extract token usage from assistant messages
            if let message = json["message"] as? [String: Any],
               let usage = message["usage"] as? [String: Any] {

                if let inputTokens = usage["input_tokens"] as? Int {
                    tokens.inputTokens += inputTokens
                }
                if let outputTokens = usage["output_tokens"] as? Int {
                    tokens.outputTokens += outputTokens
                }
                if let cacheCreation = usage["cache_creation_input_tokens"] as? Int {
                    tokens.cacheCreationTokens += cacheCreation
                }
                if let cacheRead = usage["cache_read_input_tokens"] as? Int {
                    tokens.cacheReadTokens += cacheRead
                }

                // Get model from message
                if tokens.model == nil, let model = message["model"] as? String {
                    tokens.model = model
                }
            }
        }

        return (summary, gitBranch, slug, tokens)
    }

    struct TokenStats {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheCreationTokens: Int = 0
        var cacheReadTokens: Int = 0
        var model: String?
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

            // Extract user messages
            if type == "user",
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {
                messages.append(SessionMessage(role: .user, content: content))
            }

            // Extract assistant messages
            if type == "assistant",
               let message = json["message"] as? [String: Any],
               let contentArray = message["content"] as? [[String: Any]] {
                for item in contentArray {
                    if item["type"] as? String == "text",
                       let text = item["text"] as? String {
                        messages.append(SessionMessage(role: .assistant, content: text))
                        break // Only take first text block
                    }
                }
            }
        }

        // Return last N messages
        return Array(messages.suffix(maxMessages))
    }

    // MARK: - Actions

    func openNewSession(in project: Project) {
        let command = "cd '\(project.decodedPath)' && claude"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }

    func openNewSessionWithBypass(in project: Project) {
        let command = "cd '\(project.decodedPath)' && claude --dangerously-skip-permissions"
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
            let command = "cd '\(url.path)' && claude"
            _ = TerminalLauncher.runInITermOnly(command: command)

            // Reload projects after a short delay to pick up the new session
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.loadProjects()
            }
        }
    }

    func resumeSession(_ session: Session, in project: Project) {
        let command = "cd '\(project.decodedPath)' && claude --resume '\(session.id)'"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }

    func continueLatestSession(in project: Project) {
        let command = "cd '\(project.decodedPath)' && claude --continue"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }

    func forkSession(_ session: Session, in project: Project) {
        let command = "cd '\(project.decodedPath)' && claude --resume '\(session.id)' --fork-session"
        _ = TerminalLauncher.runInITermOnly(command: command)
    }
}
