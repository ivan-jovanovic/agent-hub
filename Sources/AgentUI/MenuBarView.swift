import SwiftUI

struct MenuBarView: View {
    @ObservedObject var claudeService: ClaudeCodeService
    @ObservedObject var codexService: CodexService
    @StateObject private var usageService = UsageService()
    @StateObject private var codexUsageService = CodexUsageService()
    @AppStorage("menuBarAgent") private var selectedAgent: String = AgentType.claudeCode.rawValue
    @State private var expandedProjectId: String?
    @State private var showUsageSettings = false

    private var currentAgent: AgentType {
        AgentType(rawValue: selectedAgent) ?? .claudeCode
    }

    private var theme: AppTheme {
        AppTheme.forAgent(currentAgent)
    }

    private var currentProjects: [Project] {
        switch currentAgent {
        case .claudeCode:
            return claudeService.projects
        case .codex:
            return codexService.projects
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(0.3)

            // Projects list
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(currentProjects.prefix(12)) { project in
                        ProjectCard(
                            project: project,
                            isExpanded: expandedProjectId == project.id,
                            theme: theme,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedProjectId = expandedProjectId == project.id ? nil : project.id
                                }
                            },
                            onContinue: { continueLatestSession(in: project) },
                            onNewSession: { openNewSession(in: project) },
                            onResumeSession: { session in resumeSession(session, in: project) },
                            onShowInFinder: {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.decodedPath)
                            }
                        )
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: 400)

            Divider().opacity(0.3)

            // Footer
            footerView
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .onAppear {
            loadProjects()
            usageService.refresh() // default to Claude
        }
        // Present settings inline to avoid closing the menu popover
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 10) {
            // Title and refresh
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accentGradient)
                    Text("Agent Hub")
                        .font(AppTypography.titleSmall)
                }

                Spacer()

                Button {
                    loadProjects()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")

                Button {
                    showUsageSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Usage Settings")
            }

            // Agent toggle
            HStack(spacing: 4) {
                AgentToggleButton(
                    title: "Claude Code",
                    icon: "terminal.fill",
                    isSelected: currentAgent == .claudeCode,
                    color: .orange
                ) {
                    withAnimation { selectedAgent = AgentType.claudeCode.rawValue }
                    loadProjects()
                    usageService.refresh()
                }

                AgentToggleButton(
                    title: "Codex",
                    icon: "cpu.fill",
                    isSelected: currentAgent == .codex,
                    color: .green
                ) {
                    withAnimation { selectedAgent = AgentType.codex.rawValue }
                    loadProjects()
                    codexUsageService.refresh()
                }
            }
            // Show usage/settings inline so the popover stays open
            if currentAgent == .claudeCode {
                if showUsageSettings {
                    UsageSettingsInline(
                        usageService: usageService,
                        onClose: { withAnimation { showUsageSettings = false } })
                        .transition(.opacity)
                } else {
                    usageMini
                }
            } else {
                codexUsageMini
            }
        }
        .padding(12)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 12) {
            Button {
                openNewProjectSession()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("New Project")
                        .font(AppTypography.caption)
                }
                .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                openMainWindow()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Open App")
                        .font(AppTypography.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(12)
    }

    // MARK: - Actions

    private func loadProjects() {
        claudeService.loadProjects()
        codexService.loadProjects()
    }

    private func openNewSession(in project: Project) {
        switch currentAgent {
        case .claudeCode:
            claudeService.openNewSession(in: project)
        case .codex:
            codexService.openNewSession(in: project)
        }
    }

    private func resumeSession(_ session: Session, in project: Project) {
        switch currentAgent {
        case .claudeCode:
            claudeService.resumeSession(session, in: project)
        case .codex:
            codexService.resumeSession(session, in: project)
        }
    }

    private func continueLatestSession(in project: Project) {
        switch currentAgent {
        case .claudeCode:
            claudeService.continueLatestSession(in: project)
        case .codex:
            codexService.continueLatestSession(in: project)
        }
    }

    private func openNewProjectSession() {
        switch currentAgent {
        case .claudeCode:
            claudeService.openNewProjectSession()
        case .codex:
            codexService.openNewProjectSession()
        }
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows {
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
    }
}

// MARK: - Agent Toggle Button

struct AgentToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(AppTypography.captionMedium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.strokeSoft, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Project Card

// MARK: - Usage Mini + Settings

extension MenuBarView {
    private var usageMini: some View {
        Group {
            if usageService.isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Fetching Claude usage…")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let snap = usageService.usage {
                HStack(spacing: 8) {
                    usageChip(title: "Session", value: Int(snap.primary.remainingPercent), color: .orange)
                    if let weekly = snap.weekly {
                        usageChip(title: "Week", value: Int(weekly.remainingPercent), color: .blue)
                    } else {
                        usageChipText(title: "Week", text: "—", color: .blue)
                    }
                    if let cost = snap.providerCost {
                        costChip(used: cost.used, limit: cost.limit, currency: cost.currency)
                    }
                    Spacer()
                    Button { usageService.refresh() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            } else if let err = usageService.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(err)
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func usageChip(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title).font(AppTypography.micro)
            Text("\(value)% left").font(AppTypography.micro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .foregroundColor(color)
    }

    private func usageChipText(title: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title).font(AppTypography.micro)
            Text(text).font(AppTypography.micro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .foregroundColor(color)
    }

    private func costChip(used: Double, limit: Double, currency: String) -> some View {
        let fmt: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = currency
            return f
        }()
        let usedStr = fmt.string(from: NSNumber(value: used)) ?? String(format: "%.2f", used)
        let limitStr = fmt.string(from: NSNumber(value: limit)) ?? String(format: "%.2f", limit)
        return HStack(spacing: 4) {
            Text("Extra")
                .font(AppTypography.micro)
            Text("\(usedStr)/\(limitStr)")
                .font(AppTypography.micro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.15))
        .clipShape(Capsule())
        .foregroundColor(.purple)
    }

    private var codexUsageMini: some View {
        Group {
            if codexUsageService.isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Fetching Codex usage…")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let snap = codexUsageService.usage {
                HStack(spacing: 8) {
                    usageChip(title: "Session", value: snap.sessionLeftPercent, color: .green)
                    if let wl = snap.weeklyLeftPercent {
                        usageChip(title: "Week", value: wl, color: .blue)
                    } else {
                        usageChipText(title: "Week", text: "—", color: .blue)
                    }
                    Spacer()
                    Button { codexUsageService.refresh() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            } else if let err = codexUsageService.error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text(err)
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Text("Codex usage not fetched")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        codexUsageService.refresh()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Fetch Codex usage")
                }
                .padding(.top, 2)
            }
        }
    }
}

struct UsageSettingsInline: View {
    @ObservedObject var usageService: UsageService
    var onClose: () -> Void

    @State private var tempSource: ClaudeUsageSource = .auto
    @State private var tempSessionKey: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
            Text("Claude Usage Settings")
                    .font(AppTypography.captionMedium)
                Spacer()
                Button {
                    withAnimation { onClose() }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Picker("Source", selection: $tempSource) {
                ForEach(ClaudeUsageSource.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            if tempSource == .web || tempSource == .auto {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Paste your claude.ai sessionKey (sk-ant-…)")
                        .font(AppTypography.micro)
                        .foregroundColor(.secondary)
                    TextField("sk-ant-…", text: $tempSessionKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Load Organizations") {
                            usageService.sessionKey = tempSessionKey
                            usageService.loadOrganizations()
                        }
                        .buttonStyle(.bordered)
                        if !usageService.organizations.isEmpty {
                            Menu {
                                ForEach(usageService.organizations, id: \.id) { org in
                                    Button(org.name ?? org.id) {
                                        usageService.orgId = org.id
                                    }
                                }
                            } label: {
                                Label(usageService.organizations.first(where: { $0.id == usageService.orgId })?.name ?? "Select Org", systemImage: "building.2")
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Save & Refresh") {
                    usageService.sourceString = tempSource.rawValue
                    usageService.sessionKey = tempSessionKey
                    usageService.refresh()
                    withAnimation { onClose() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.strokeSoft, lineWidth: 1)
                )
        )
        .onAppear {
            tempSource = ClaudeUsageSource(rawValue: usageService.sourceString) ?? .auto
            tempSessionKey = usageService.sessionKey
        }
    }
}

struct ProjectCard: View {
    let project: Project
    let isExpanded: Bool
    let theme: AppTheme
    let onTap: () -> Void
    let onContinue: () -> Void
    let onNewSession: () -> Void
    let onResumeSession: (Session) -> Void
    let onShowInFinder: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.accentGradient.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.accentGradient)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.displayName)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let lastSession = project.sessions.first {
                        Text(lastSession.formattedDate)
                            .font(AppTypography.micro)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Session count badge
                Text("\(project.sessions.count)")
                    .font(AppTypography.micro)
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())

                // Expand arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider().opacity(0.3).padding(.horizontal, 10)

                    // Action buttons
                    HStack(spacing: 8) {
                        ActionButton(
                            title: "Continue",
                            icon: "play.fill",
                            color: .green,
                            action: onContinue
                        )

                        ActionButton(
                            title: "New",
                            icon: "plus",
                            color: theme.accent,
                            action: onNewSession
                        )

                        ActionButton(
                            title: "Finder",
                            icon: "folder",
                            color: .blue,
                            action: onShowInFinder
                        )
                    }
                    .padding(10)

                    // Recent sessions
                    if !project.sessions.isEmpty {
                        Divider().opacity(0.3).padding(.horizontal, 10)

                        VStack(spacing: 4) {
                            ForEach(project.sessions.prefix(3)) { session in
                                SessionRow(
                                    session: session,
                                    theme: theme,
                                    onResume: { onResumeSession(session) }
                                )
                            }
                        }
                        .padding(10)
                    }
                }
                .background(Color.surfaceElevated)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering || isExpanded ? Color.surfaceHover : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isExpanded ? theme.accent.opacity(0.3) : Color.strokeSoft, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(AppTypography.micro)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(isHovering ? color.opacity(0.2) : color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 5))
        .onHover { isHovering = $0 }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session
    let theme: AppTheme
    let onResume: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: session.isAgent ? "cpu" : "bubble.left.fill")
                    .font(.system(size: 10))
                    .foregroundColor(session.isAgent ? .orange : theme.accent)
                    .frame(width: 16)

                // Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.displayName)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(session.formattedDate)
                        Text("·")
                        Text(session.formattedSize)
                        if session.totalTokens > 0 {
                            Text("·")
                            Text(session.formattedTokens)
                        }
                    }
                    .font(AppTypography.micro)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Play icon on hover
                if isHovering {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovering ? Color.green.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
