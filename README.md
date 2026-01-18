# AgentUI

A native macOS menu bar app for managing Claude Code and OpenAI Codex CLI sessions. Quickly browse, resume, and start new coding sessions without leaving your workflow.

## Features

- **Dual Agent Support**: Switch between Claude Code and OpenAI Codex sessions
- **Project Organization**: Sessions grouped by project directory, sorted by recent activity
- **Menu Bar Access**: Quick access from the menu bar with a rich, colorful UI
- **Session Management**:
  - Resume any previous session
  - Continue the latest session in a project
  - Start new sessions
  - Fork sessions (Claude Code only)
  - Bypass permissions mode (Claude Code only)
- **Session Preview**: Click the eye icon to preview recent messages from any session
- **Token Statistics**: View token usage and estimated costs per session and project
- **Finder Integration**: Open project directories directly in Finder

## Screenshots

The app provides both a full window view and a compact menu bar popover for quick access.

## Requirements

- macOS 14.0 or later
- iTerm2 (for launching terminal sessions)
- Claude Code CLI (`claude`) and/or OpenAI Codex CLI (`codex`) installed

## Installation

### Building from Source

1. Clone the repository
2. Run the build script:
   ```bash
   ./Scripts/build.sh
   ```
3. The app bundle will be created at `AgentUI.app`
4. Move it to your Applications folder or run directly:
   ```bash
   open AgentUI.app
   ```

### Running in Development

```bash
./Scripts/run.sh
```

## Usage

### Main Window

1. Select an agent (Claude Code or Codex) using the toggle at the top
2. Click on a project in the sidebar to see its sessions
3. Use the action buttons to:
   - **Continue**: Resume the most recent session
   - **New Session**: Start a fresh session
   - **Bypass**: Start with `--dangerously-skip-permissions` (Claude Code only)

### Menu Bar

1. Click the terminal icon in the menu bar
2. Toggle between Claude Code and Codex
3. Click on a project card to expand it
4. Use quick actions: Continue, New, or Finder
5. Click on individual sessions to resume them

### Session Preview

Hover over any session card and click the eye icon to see a preview of recent messages from that conversation.

## Project Structure

```
AgentUI/
├── Package.swift           # Swift Package Manager manifest
├── Sources/
│   └── AgentUI/
│       ├── AgentUIApp.swift      # App entry point and main window
│       ├── ContentView.swift     # Main UI components
│       ├── MenuBarView.swift     # Menu bar popover UI
│       ├── Models.swift          # Data models (Project, Session, etc.)
│       ├── ClaudeCodeService.swift  # Claude Code session management
│       ├── CodexService.swift       # Codex session management
│       └── Theme.swift           # Colors, typography, and theming
├── Resources/
│   └── AppIcon.icns        # Application icon
└── Scripts/
    ├── build.sh            # Production build script
    └── run.sh              # Development run script

## Skills

This repo includes a minimal set of SwiftUI-focused agent skills under `skills/public` to help when working on the UI:
- `swiftui-view-refactor` — consistent SwiftUI view structure and Observation usage
- `swiftui-ui-patterns` — composable SwiftUI patterns and examples
- `swiftui-performance-audit` — guidance to diagnose and improve SwiftUI performance

Use with Codex CLI by symlinking or copying these folders under `$CODEX_HOME/skills/public` (see `skills/README.md`).
```

## Data Sources

- **Claude Code**: Reads from `~/.claude/projects/` directory
- **Codex**: Reads from `~/.codex/sessions/` directory

Sessions are stored as JSONL files containing conversation history, token usage, and metadata.

## Token Pricing

Estimated costs are calculated using the following rates (per million tokens):

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| Opus | $15.00 | $75.00 | $18.75 | $1.50 |
| Sonnet | $3.00 | $15.00 | $3.75 | $0.30 |
| Haiku | $0.80 | $4.00 | $1.00 | $0.08 |

## License

MIT
