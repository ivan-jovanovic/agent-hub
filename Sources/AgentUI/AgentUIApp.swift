import SwiftUI

@main
struct AgentUIApp: App {
    @StateObject private var claudeService = ClaudeCodeService()
    @StateObject private var codexService = CodexService()

    var body: some Scene {
        WindowGroup {
            MainContentView(claudeService: claudeService, codexService: codexService)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 900, height: 600)

        MenuBarExtra("Agent Hub", systemImage: "terminal.fill") {
            MenuBarView(claudeService: claudeService, codexService: codexService)
        }
        .menuBarExtraStyle(.window)

        // Custom status item with RepoBar-like chips + SwiftUI popover
    }
}

// Wrapper to pass services to ContentView
struct MainContentView: View {
    @ObservedObject var claudeService: ClaudeCodeService
    @ObservedObject var codexService: CodexService
    @StateObject private var usageService = UsageService()
    @StateObject private var codexUsageService = CodexUsageService()
    @State private var selectedProject: Project?
    @State private var selectedAgent: AgentType = .claudeCode
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    private var currentProjects: [Project] {
        switch selectedAgent {
        case .claudeCode:
            return claudeService.projects
        case .codex:
            return codexService.projects
        }
    }

    private var isLoading: Bool {
        switch selectedAgent {
        case .claudeCode:
            return claudeService.isLoading
        case .codex:
            return codexService.isLoading
        }
    }

    private func loadProjects() {
        switch selectedAgent {
        case .claudeCode:
            claudeService.loadProjects()
        case .codex:
            codexService.loadProjects()
        }
    }

    private func openNewSession(in project: Project) {
        switch selectedAgent {
        case .claudeCode:
            claudeService.openNewSession(in: project)
        case .codex:
            codexService.openNewSession(in: project)
        }
    }

    private func resumeSession(_ session: Session, in project: Project) {
        switch selectedAgent {
        case .claudeCode:
            claudeService.resumeSession(session, in: project)
        case .codex:
            codexService.resumeSession(session, in: project)
        }
    }

    private func continueLatestSession(in project: Project) {
        switch selectedAgent {
        case .claudeCode:
            claudeService.continueLatestSession(in: project)
        case .codex:
            codexService.continueLatestSession(in: project)
        }
    }

    private func forkSession(_ session: Session, in project: Project) {
        switch selectedAgent {
        case .claudeCode:
            claudeService.forkSession(session, in: project)
        case .codex:
            codexService.forkSession(session, in: project)
        }
    }

    private func openNewSessionWithBypass(in project: Project) {
        claudeService.openNewSessionWithBypass(in: project)
    }

    private func openNewProjectSession() {
        switch selectedAgent {
        case .claudeCode:
            claudeService.openNewProjectSession()
        case .codex:
            codexService.openNewProjectSession()
        }
    }

    private func getSessionPreview(for session: Session) -> [SessionMessage] {
        switch selectedAgent {
        case .claudeCode:
            return claudeService.getSessionPreview(for: session)
        case .codex:
            return codexService.getSessionPreview(for: session)
        }
    }

    var body: some View {
        ZStack {
            CanvasBackground(theme: AppTheme.forAgent(selectedAgent))

            NavigationSplitView {
                ProjectListView(
                    projects: currentProjects,
                    selectedProject: $selectedProject,
                    selectedAgent: $selectedAgent,
                    theme: AppTheme.forAgent(selectedAgent),
                    usageService: usageService,
                    codexUsageService: codexUsageService,
                    onRefresh: { loadProjects() },
                    onNewSession: { project in openNewSession(in: project) },
                    onContinue: { project in continueLatestSession(in: project) },
                    onNewSessionWithBypass: { project in openNewSessionWithBypass(in: project) },
                    onNewProject: { openNewProjectSession() },
                    onAgentChanged: {
                        selectedProject = nil
                        loadProjects()
                        if selectedAgent == .claudeCode, usageService.usage == nil, !usageService.isLoading {
                            usageService.refresh()
                        }
                        if selectedAgent == .codex, codexUsageService.usage == nil, !codexUsageService.isLoading {
                            codexUsageService.refresh()
                        }
                    }
                )
                .frame(minWidth: 320)
            } detail: {
                if let project = selectedProject {
                    SessionListView(
                        project: project,
                        agentType: selectedAgent,
                        theme: AppTheme.forAgent(selectedAgent),
                        onResume: { session in resumeSession(session, in: project) },
                        onFork: { session in forkSession(session, in: project) },
                        onNewSession: { openNewSession(in: project) },
                        onNewSessionWithBypass: { openNewSessionWithBypass(in: project) },
                        onContinue: { continueLatestSession(in: project) },
                        getPreview: getSessionPreview
                    )
                } else {
                    EmptyStateView(theme: AppTheme.forAgent(selectedAgent))
                }
            }
        }
        .onAppear {
            loadProjects()
            // Only refresh Claude usage by default to avoid spawning Codex PTY unnecessarily
            usageService.refresh()

            // Show onboarding on first launch or if iTerm2 is missing
            if !hasCompletedOnboarding || !FileManager.default.fileExists(atPath: "/Applications/iTerm.app") {
                showOnboarding = true
            }
        }
        .onChange(of: showOnboarding) { _, newValue in
            if !newValue {
                hasCompletedOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .overlay {
            if isLoading && currentProjects.isEmpty {
                LoadingOverlay(theme: AppTheme.forAgent(selectedAgent))
            }
        }
    }
}

// MARK: - Usage Chips (Main Window)

struct UsageChipsView: View {
    @ObservedObject var usageService: UsageService

    var body: some View {
        HStack(spacing: 10) {
            if usageService.isLoading {
                ProgressView().scaleEffect(0.9)
                Text("Fetching Claude usage…")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            } else if let snap = usageService.usage {
                chip(title: "Session", valueText: "\(Int(snap.primary.remainingPercent))% left", color: .orange)
                if let weekly = snap.weekly {
                    chip(title: "Week", valueText: "\(Int(weekly.remainingPercent))% left", color: .blue)
                } else {
                    chip(title: "Week", valueText: "—", color: .blue)
                }
                if let cost = snap.providerCost {
                    chip(title: "Extra", valueText: formattedCost(cost.used, cost.currency) + "/" + formattedCost(cost.limit, cost.currency), color: Color.brandSecondary)
                }
                Spacer()
                Button {
                    usageService.refresh()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                .help("Refresh usage")
            } else if let err = usageService.error {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                Text(err)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Button {
                    usageService.refresh()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chip(title: String, valueText: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(AppTypography.micro)
            Text(valueText).font(AppTypography.micro)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .foregroundColor(color)
    }

    private func formattedCost(_ amount: Double, _ currencyCode: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}

struct CodexUsageChipsView: View {
    @ObservedObject var service: CodexUsageService

    var body: some View {
        HStack(spacing: 10) {
            if service.isLoading {
                ProgressView().scaleEffect(0.9)
                Text("Fetching Codex usage…")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            } else if let snap = service.usage {
                chip(title: "Session", valueText: "\(snap.sessionLeftPercent)% left", color: .green)
                if let wl = snap.weeklyLeftPercent {
                    chip(title: "Week", valueText: "\(wl)% left", color: .blue)
                } else {
                    chip(title: "Week", valueText: "—", color: .blue)
                }
                Spacer()
                Button { service.refresh() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
                .help("Refresh usage")
            } else if let err = service.error {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                Text(err)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Button { service.refresh() } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.plain)
            } else {
                // No data fetched yet; prompt to fetch
                Text("Codex usage not fetched")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    service.refresh()
                } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.plain)
                    .help("Fetch Codex usage")
            }
        }
    }

    private func chip(title: String, valueText: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title).font(AppTypography.micro)
            Text(valueText).font(AppTypography.micro)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .foregroundColor(color)
    }
}
