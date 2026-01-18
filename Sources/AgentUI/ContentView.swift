import SwiftUI

// MARK: - Canvas Background

struct CanvasBackground: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.backgroundPrimary, Color.backgroundSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [theme.accent.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color.brandPrimary.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let theme: AppTheme
    @State private var didAppear = false

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(theme.accentGradient.opacity(0.18))
                        .frame(width: 110, height: 110)

                    Circle()
                        .strokeBorder(theme.accent.opacity(0.2), lineWidth: 1)
                        .frame(width: 110, height: 110)

                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(theme.accentGradient)
                }

                VStack(spacing: 6) {
                    Text("Choose a Project")
                        .font(AppTypography.titleLarge)
                        .foregroundColor(.textPrimary)

                    Text("Pick a project in the sidebar to explore sessions.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(.textSecondary)
                }

                HStack(spacing: 10) {
                    HintPill(icon: "play.fill", text: "Continue latest", color: theme.accent)
                    HintPill(icon: "plus", text: "New session", color: Color.brandPrimary)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.strokeSoft, lineWidth: 1)
                    )
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 12)
        .animation(.easeOut(duration: 0.4), value: didAppear)
        .onAppear { didAppear = true }
    }
}

struct HintPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(AppTypography.micro)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(theme.accent)

            Text("Loading projects...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(.textSecondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.strokeSoft, lineWidth: 1)
        )
    }
}

// MARK: - Project List View

struct ProjectListView: View {
    let projects: [Project]
    @Binding var selectedProject: Project?
    @Binding var selectedAgent: AgentType
    let theme: AppTheme
    var usageService: UsageService? = nil
    var codexUsageService: CodexUsageService? = nil
    let onRefresh: () -> Void
    let onNewSession: (Project) -> Void
    let onContinue: (Project) -> Void
    let onNewSessionWithBypass: (Project) -> Void
    let onNewProject: () -> Void
    let onAgentChanged: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Agent Hub")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(.textPrimary)

                        Text("Projects and sessions")
                            .font(AppTypography.caption)
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Refresh projects")

                    Button(action: onNewProject) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("New Project")
                }

                HStack(spacing: 8) {
                    ForEach(AgentType.allCases, id: \.self) { agent in
                        AgentPickerButton(
                            agent: agent,
                            isSelected: selectedAgent == agent,
                            theme: AppTheme.forAgent(agent)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedAgent = agent
                                onAgentChanged()
                            }
                        }
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if selectedAgent == .claudeCode, let usageService {
                    usageBlock(title: "Claude Usage") {
                        UsageChipsView(usageService: usageService)
                    }
                } else if selectedAgent == .codex, let codexUsageService {
                    usageBlock(title: "Codex Usage") {
                        CodexUsageChipsView(service: codexUsageService)
                    }
                }
            }
            .padding(16)

            Divider().opacity(0.5)

            HStack {
                Text("Projects")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer()

                Text("\(projects.count)")
                    .font(AppTypography.micro)
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.35)

            if projects.isEmpty {
                emptyProjectsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(projects) { project in
                            ProjectRowView(
                                project: project,
                                isSelected: selectedProject == project,
                                agentType: selectedAgent,
                                theme: theme,
                                onNewSession: { onNewSession(project) },
                                onContinue: { onContinue(project) },
                                onNewSessionWithBypass: { onNewSessionWithBypass(project) }
                            )
                            .onTapGesture {
                                selectedProject = project
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color.backgroundSecondary)
    }

    private func usageBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.micro)
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.strokeSoft, lineWidth: 1)
                )
        )
    }

    private var emptyProjectsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 34))
                .foregroundStyle(theme.accentGradient)

            Text("No Projects Yet")
                .font(AppTypography.titleSmall)
                .foregroundColor(.textPrimary)

            Text("Start a session to create your first project.")
                .font(AppTypography.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .padding(12)
    }
}

struct AgentPickerButton: View {
    let agent: AgentType
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: agent == .claudeCode ? "terminal" : "cpu")
                    .font(.system(size: 12, weight: .semibold))
                Text(agent.rawValue)
                    .font(AppTypography.captionMedium)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? theme.accentGradient : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing))
            .foregroundColor(isSelected ? .white : .textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.clear : Color.strokeSoft, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool
    let agentType: AgentType
    let theme: AppTheme
    let onNewSession: () -> Void
    let onContinue: () -> Void
    let onNewSessionWithBypass: () -> Void

    @State private var isHovering = false

    private var shortPath: String {
        let path = project.decodedPath
        let components = path.components(separatedBy: "/")

        if let docsIndex = components.firstIndex(of: "Documents") {
            let startIndex = docsIndex + 1
            if startIndex < components.count {
                let endComponents = Array(components[startIndex...])
                return endComponents.joined(separator: "/")
            }
        }

        let lastComponents = components.suffix(3)
        return lastComponents.joined(separator: "/")
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.accentGradient)
                .frame(width: 6, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.displayName)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(shortPath)
                    .font(AppTypography.mono)
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    QuickActionButton(
                        title: "Continue",
                        icon: "play.fill",
                        color: theme.accent,
                        action: onContinue
                    )

                    QuickActionButton(
                        title: "New",
                        icon: "plus",
                        color: Color.brandPrimary,
                        action: onNewSession
                    )

                    if agentType == .claudeCode {
                        QuickActionButton(
                            title: "Bypass",
                            icon: "bolt.fill",
                            color: Color.statusWarning,
                            action: onNewSessionWithBypass
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Text("\(project.sessions.count)")
                .font(AppTypography.micro)
                .foregroundColor(theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accent.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? theme.accent.opacity(0.12) : (isHovering ? Color.surfaceHover : Color.surfaceElevated))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? theme.accent.opacity(0.35) : Color.strokeSoft, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button { onNewSession() } label: {
                Label("New Session", systemImage: "plus")
            }
            Button { onContinue() } label: {
                Label("Continue Latest", systemImage: "play.fill")
            }
            if agentType == .claudeCode {
                Button { onNewSessionWithBypass() } label: {
                    Label("Bypass Permissions", systemImage: "bolt.fill")
                }
            }
            Divider()
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.decodedPath)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
            .background(isHovering ? color.opacity(0.2) : color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
}

// MARK: - Session List View

struct SessionListView: View {
    let project: Project
    let agentType: AgentType
    let theme: AppTheme
    let onResume: (Session) -> Void
    let onFork: (Session) -> Void
    let onNewSession: () -> Void
    let onNewSessionWithBypass: () -> Void
    let onContinue: () -> Void
    var getPreview: ((Session) -> [SessionMessage])?

    var mainSessions: [Session] {
        project.sessions.filter { !$0.isAgent }
    }

    var agentSessions: [Session] {
        project.sessions.filter { $0.isAgent }
    }

    var body: some View {
        VStack(spacing: 0) {
            SessionHeaderView(
                project: project,
                agentType: agentType,
                theme: theme,
                onContinue: onContinue,
                onNewSession: onNewSession,
                onNewSessionWithBypass: onNewSessionWithBypass
            )

            Divider().opacity(0.4)

            ScrollView {
                LazyVStack(spacing: 18, pinnedViews: [.sectionHeaders]) {
                    if !mainSessions.isEmpty {
                        Section {
                            ForEach(mainSessions) { session in
                                SessionCardView(
                                    session: session,
                                    showFork: agentType == .claudeCode,
                                    theme: theme,
                                    onResume: { onResume(session) },
                                    onFork: { onFork(session) },
                                    getPreview: getPreview
                                )
                            }
                        } header: {
                            SectionHeaderView(title: "Sessions", count: mainSessions.count, theme: theme)
                        }
                    }

                    if !agentSessions.isEmpty {
                        Section {
                            ForEach(agentSessions) { session in
                                SessionCardView(
                                    session: session,
                                    showFork: agentType == .claudeCode,
                                    theme: theme,
                                    onResume: { onResume(session) },
                                    onFork: { onFork(session) },
                                    getPreview: getPreview
                                )
                            }
                        } header: {
                            SectionHeaderView(title: "Sub-Agents", count: agentSessions.count, theme: theme)
                        }
                    }

                    if project.sessions.isEmpty {
                        EmptySessionsView(theme: theme)
                    }
                }
                .padding(20)
            }
            .background(Color.backgroundPrimary)
        }
    }
}

struct SessionHeaderView: View {
    let project: Project
    let agentType: AgentType
    let theme: AppTheme
    let onContinue: () -> Void
    let onNewSession: () -> Void
    let onNewSessionWithBypass: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.displayName)
                        .font(AppTypography.titleLarge)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text(project.decodedPath)
                            .font(AppTypography.mono)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundColor(.textSecondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onContinue) {
                        Label("Continue", systemImage: "play.fill")
                    }
                    .buttonStyle(GradientButtonStyle(gradient: theme.accentGradient))

                    Button(action: onNewSession) {
                        Label("New Session", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if agentType == .claudeCode {
                        Button(action: onNewSessionWithBypass) {
                            Label("Bypass", systemImage: "bolt.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .help("New session with --dangerously-skip-permissions")
                    }
                }
            }

            if project.totalTokens > 0 {
                HStack(spacing: 12) {
                    StatBadge(
                        icon: "bubble.left.and.bubble.right",
                        label: "Sessions",
                        value: "\(project.sessions.count)",
                        theme: theme
                    )
                    StatBadge(
                        icon: "number",
                        label: "Tokens",
                        value: project.formattedTotalTokens,
                        theme: theme
                    )
                    StatBadge(
                        icon: "dollarsign.circle",
                        label: "Cost",
                        value: project.formattedTotalCost,
                        theme: theme
                    )
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.strokeSoft, lineWidth: 1)
                )
                .overlay(
                    LinearGradient(
                        colors: [theme.accent.opacity(0.18), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                )
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.textPrimary)
                Text(label)
                    .font(AppTypography.micro)
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SectionHeaderView: View {
    let title: String
    let count: Int
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Text("\(count)")
                .font(AppTypography.micro)
                .foregroundColor(theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.accent.opacity(0.15))
                .clipShape(Capsule())

            Rectangle()
                .fill(Color.strokeSoft)
                .frame(height: 1)
        }
        .padding(.vertical, 8)
        .background(Color.backgroundPrimary)
    }
}

struct SessionCardView: View {
    let session: Session
    let showFork: Bool
    let theme: AppTheme
    let onResume: () -> Void
    let onFork: () -> Void
    var getPreview: ((Session) -> [SessionMessage])?

    @State private var isHovering = false
    @State private var showPreview = false
    @State private var previewMessages: [SessionMessage] = []
    @State private var hoverTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(session.isAgent ? Color.statusWarning.opacity(0.18) : theme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: session.isAgent ? "cpu" : "bubble.left.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(session.isAgent ? .statusWarning : theme.accent)
            }
            .popover(isPresented: $showPreview, arrowEdge: .leading) {
                SessionPreviewView(messages: previewMessages, theme: theme)
                    .onHover { hovering in
                        if hovering {
                            dismissTask?.cancel()
                            dismissTask = nil
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(session.displayName)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    SessionMetaTag(icon: "clock", text: session.formattedDate, tint: .textTertiary)
                    SessionMetaTag(icon: "doc", text: session.formattedSize, tint: .textTertiary)
                    if session.totalTokens > 0 {
                        SessionMetaTag(icon: "number", text: session.formattedTokens, tint: theme.accent)
                        SessionMetaTag(icon: "dollarsign.circle", text: session.formattedCost, tint: theme.accent)
                    }
                    if let branch = session.gitBranch {
                        SessionMetaTag(icon: "arrow.triangle.branch", text: branch, tint: .textTertiary)
                    }
                }
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button("Resume", action: onResume)
                        .buttonStyle(GradientButtonStyle(gradient: theme.accentGradient))
                        .controlSize(.small)

                    if showFork {
                        Button("Fork", action: onFork)
                            .buttonStyle(SecondaryButtonStyle())
                            .controlSize(.small)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovering ? Color.surfaceHover : Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isHovering ? theme.accent.opacity(0.2) : Color.strokeSoft, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }

            if hovering {
                dismissTask?.cancel()
                dismissTask = nil

                hoverTask?.cancel()
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            if let getPreview = getPreview {
                                previewMessages = getPreview(session)
                            }
                            showPreview = true
                        }
                    }
                }
            } else {
                hoverTask?.cancel()
                hoverTask = nil

                dismissTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled {
                        await MainActor.run {
                            showPreview = false
                        }
                    }
                }
            }
        }
        .contextMenu {
            Button { onResume() } label: {
                Label("Resume Session", systemImage: "play.fill")
            }
            if showFork {
                Button { onFork() } label: {
                    Label("Fork Session", systemImage: "arrow.triangle.branch")
                }
            }
            Divider()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id, forType: .string)
            } label: {
                Label("Copy Session ID", systemImage: "doc.on.doc")
            }
        }
    }
}

struct SessionMetaTag: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(AppTypography.micro)
        }
        .foregroundColor(tint)
    }
}

// MARK: - Session Preview View

struct SessionPreviewView: View {
    let messages: [SessionMessage]
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(theme.accentGradient)
                Text("Conversation Preview")
                    .font(AppTypography.captionMedium)
                Spacer()
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))

            Divider().opacity(0.3)

            if messages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No messages to preview")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, theme: theme)
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MessageBubble: View {
    let message: SessionMessage
    let theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(message.role == .user ? Color.brandPrimary.opacity(0.15) : theme.accent.opacity(0.15))
                    .frame(width: 26, height: 26)

                Image(systemName: message.role == .user ? "person.fill" : "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(message.role == .user ? Color.brandPrimary : theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "Claude")
                    .font(AppTypography.micro)
                    .foregroundColor(message.role == .user ? Color.brandPrimary : theme.accent)

                Text(message.preview)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(.textPrimary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(message.role == .user ? Color.brandPrimary.opacity(0.05) : theme.accent.opacity(0.06))
        )
    }
}

struct EmptySessionsView: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(theme.accentGradient.opacity(0.12))
                    .frame(width: 90, height: 90)

                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.accentGradient)
            }

            VStack(spacing: 6) {
                Text("No Sessions Yet")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(.textPrimary)

                Text("Start a new session to begin working on this project.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}
