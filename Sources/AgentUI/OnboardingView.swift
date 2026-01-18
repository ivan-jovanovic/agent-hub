import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var checks = DependencyChecks()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to Agent Hub")
                    .font(.title.bold())

                Text("Manage your Claude Code and Codex sessions from the menu bar.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)
            .padding(.horizontal, 32)

            Divider()
                .padding(.vertical, 24)

            // Dependency checks
            VStack(alignment: .leading, spacing: 16) {
                Text("Setup Checklist")
                    .font(.headline)

                DependencyRow(
                    name: "iTerm2",
                    description: "Required for launching sessions",
                    isInstalled: checks.hasiTerm2,
                    installURL: "https://iterm2.com"
                )

                DependencyRow(
                    name: "Claude Code",
                    description: "For Claude AI coding sessions",
                    isInstalled: checks.hasClaudeCode,
                    installURL: "https://github.com/anthropics/claude-code",
                    isOptional: true
                )

                DependencyRow(
                    name: "Codex CLI",
                    description: "For OpenAI Codex sessions",
                    isInstalled: checks.hasCodex,
                    installURL: "https://github.com/openai/codex",
                    isOptional: true
                )

                if !checks.hasClaudeCode && !checks.hasCodex {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Install at least one CLI to use Agent Hub")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Permissions note
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.secondary)
                    Text("Automation Permission")
                        .font(.subheadline.bold())
                }

                Text("When you first launch a session, macOS will ask for permission to control iTerm2. Click OK to allow.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 32)

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Recheck") {
                    checks = DependencyChecks()
                }
                .buttonStyle(.bordered)

                Button("Get Started") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(!checks.hasiTerm2)
            }
            .padding(.bottom, 32)
        }
        .frame(width: 420, height: 520)
    }
}

struct DependencyRow: View {
    let name: String
    let description: String
    let isInstalled: Bool
    let installURL: String
    var isOptional: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isInstalled ? .green : (isOptional ? .secondary : .red))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.subheadline.bold())
                    if isOptional {
                        Text("optional")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isInstalled {
                Link(destination: URL(string: installURL)!) {
                    Text("Install")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct DependencyChecks {
    let hasiTerm2: Bool
    let hasClaudeCode: Bool
    let hasCodex: Bool

    init() {
        hasiTerm2 = FileManager.default.fileExists(atPath: "/Applications/iTerm.app")
        hasClaudeCode = Self.commandExists("claude")
        hasCodex = Self.commandExists("codex")
    }

    private static func commandExists(_ command: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-l", "-c", "which \(command)"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
