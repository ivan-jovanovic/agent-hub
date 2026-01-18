import Foundation

enum AgentType: String, CaseIterable {
    case claudeCode = "Claude Code"
    case codex = "Codex"
}

// MARK: - Session Messages for Preview

enum MessageRole {
    case user
    case assistant
}

struct SessionMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String

    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 200 {
            return String(trimmed.prefix(200)) + "..."
        }
        return trimmed
    }
}

struct Project: Identifiable, Hashable {
    let id: String
    let encodedPath: String
    let decodedPath: String
    let displayName: String
    var sessions: [Session]

    // Initialize from Claude Code's encoded path
    init(encodedPath: String) {
        self.encodedPath = encodedPath
        self.decodedPath = Project.decodePath(encodedPath)
        self.displayName = Project.extractDisplayName(from: decodedPath)
        self.id = encodedPath
        self.sessions = []
    }

    // Initialize from Codex's decoded path (cwd)
    init(decodedPath: String) {
        self.encodedPath = decodedPath
        self.decodedPath = decodedPath
        self.displayName = Project.extractDisplayName(from: decodedPath)
        self.id = decodedPath
        self.sessions = []
    }

    static func decodePath(_ encoded: String) -> String {
        // Claude Code encodes paths by replacing "/" and "." with "-"
        // We need to find the actual path by testing filesystem existence

        // Split by "-" and filter out empty strings from leading "-"
        let components = encoded.split(separator: "-").map(String.init)

        // Try to reconstruct the path by testing filesystem existence
        // Use backtracking to find a path that fully exists
        if let resolved = resolvePathComponents(components, currentPath: "", mustExist: true) {
            return resolved
        }

        // Fallback: try without requiring final path to exist
        if let resolved = resolvePathComponents(components, currentPath: "", mustExist: false) {
            return resolved
        }

        // Final fallback: simple replacement
        return "/" + encoded.dropFirst().replacingOccurrences(of: "-", with: "/")
    }

    private static func resolvePathComponents(_ components: [String], currentPath: String, mustExist: Bool) -> String? {
        guard !components.isEmpty else {
            return currentPath.isEmpty ? nil : currentPath
        }

        let remaining = components

        // Try longer joins first (greedy for longest valid segment)
        // This helps match "bedtime-story-studio-gadk" before "bedtime-story-studio"
        for joinCount in (1...remaining.count).reversed() {
            let joined = remaining.prefix(joinCount).joined(separator: "-")
            let joinedWithDot = remaining.prefix(joinCount).joined(separator: ".")

            let testPaths = [
                "\(currentPath)/\(joined)",
                "\(currentPath)/\(joinedWithDot)"
            ]

            for testPath in testPaths {
                if FileManager.default.fileExists(atPath: testPath) {
                    let newRemaining = Array(remaining.dropFirst(joinCount))
                    if newRemaining.isEmpty {
                        return testPath
                    }
                    if let resolved = resolvePathComponents(newRemaining, currentPath: testPath, mustExist: mustExist) {
                        // If mustExist, verify the final path exists
                        if mustExist && !FileManager.default.fileExists(atPath: resolved) {
                            continue // Try shorter match
                        }
                        return resolved
                    }
                }
            }
        }

        // Nothing found
        if mustExist {
            return nil
        }

        // Fallback: just use hyphen joining for remaining
        let fallback = remaining.joined(separator: "-")
        return currentPath.isEmpty ? "/\(fallback)" : "\(currentPath)/\(fallback)"
    }

    static func extractDisplayName(from path: String) -> String {
        // Get the last component of the path
        let lastComponent = (path as NSString).lastPathComponent

        // Replace '-' and '.' with spaces, then capitalize each word
        let formatted = lastComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")

        return formatted
    }

    // MARK: - Project Statistics

    var totalTokens: Int {
        sessions.reduce(0) { $0 + $1.totalTokens }
    }

    var totalInputTokens: Int {
        sessions.reduce(0) { $0 + $1.inputTokens }
    }

    var totalOutputTokens: Int {
        sessions.reduce(0) { $0 + $1.outputTokens }
    }

    var totalCost: Double {
        sessions.reduce(0) { $0 + $1.estimatedCost }
    }

    var formattedTotalTokens: String {
        if totalTokens == 0 {
            return "—"
        }
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    var formattedTotalCost: String {
        if totalCost < 0.01 {
            return String(format: "$%.4f", totalCost)
        } else if totalCost < 1.0 {
            return String(format: "$%.2f", totalCost)
        } else {
            return String(format: "$%.2f", totalCost)
        }
    }
}

struct Session: Identifiable, Hashable {
    let id: String
    let filePath: String
    let modifiedDate: Date
    let fileSize: Int64
    var summary: String?
    var gitBranch: String?
    var slug: String?
    let isAgent: Bool

    // Token statistics
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0
    var model: String?

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens
    }

    var displayName: String {
        if let summary = summary, !summary.isEmpty {
            return summary
        }
        if let slug = slug {
            return slug
        }
        return String(id.prefix(8)) + "..."
    }

    var formattedDate: String {
        Session.relativeDateFormatter.localizedString(for: modifiedDate, relativeTo: Date())
    }

    var formattedSize: String {
        Session.byteCountFormatter.string(fromByteCount: fileSize)
    }

    var formattedTokens: String {
        if totalTokens == 0 {
            return "—"
        }
        if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }

    var estimatedCost: Double {
        // Pricing per million tokens (as of late 2024)
        // Default to Sonnet pricing if model unknown
        let (inputPrice, outputPrice, cacheWritePrice, cacheReadPrice) = modelPricing

        let inputCost = Double(inputTokens) / 1_000_000 * inputPrice
        let outputCost = Double(outputTokens) / 1_000_000 * outputPrice
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * cacheWritePrice
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * cacheReadPrice

        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }

    private var modelPricing: (input: Double, output: Double, cacheWrite: Double, cacheRead: Double) {
        guard let model = model?.lowercased() else {
            return (3.0, 15.0, 3.75, 0.30) // Default Sonnet pricing
        }

        if model.contains("opus") {
            return (15.0, 75.0, 18.75, 1.50)
        } else if model.contains("haiku") {
            return (0.80, 4.0, 1.0, 0.08)
        } else {
            // Sonnet
            return (3.0, 15.0, 3.75, 0.30)
        }
    }

    var formattedCost: String {
        let cost = estimatedCost
        if cost < 0.01 {
            return String(format: "$%.4f", cost)
        } else if cost < 1.0 {
            return String(format: "$%.2f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }
}

extension Session {
    fileprivate static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    fileprivate static let byteCountFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}
