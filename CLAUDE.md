# CLAUDE.md - Agent Instructions for Agent Hub

## Project Overview

Agent Hub is a native macOS SwiftUI application for managing Claude Code and OpenAI Codex CLI sessions. It provides both a full window interface and menu bar quick access. The app reads session data from the filesystem and launches terminal sessions via iTerm2.

## Building and Running

### Quick Setup
```bash
./Scripts/setup.sh
```
This checks prerequisites, installs missing dependencies, and builds the app.

### Manual Build
```bash
./Scripts/build.sh
```
Creates `Agent Hub.app` in the project root.

### Run the App
```bash
open "Agent Hub.app"
```

### Development Notes
- Swift Package Manager project (not Xcode)
- Build output: `.build/`
- App bundle: `Agent Hub.app`

## Architecture

### Entry Point
- `AgentUIApp.swift` - Main app with WindowGroup and MenuBarExtra scenes, contains `MainContentView` wrapper

### Views
| File | Purpose |
|------|---------|
| `ContentView.swift` | Main window: `ProjectListView`, `SessionListView`, `SessionCardView`, `SessionPreviewView` |
| `MenuBarView.swift` | Menu bar popover with compact project cards and quick actions |
| `OnboardingView.swift` | First-run setup wizard with dependency checks |
| `Theme.swift` | `AppTheme`, `AppTypography`, agent-specific colors and gradients |

### Services
| File | Purpose |
|------|---------|
| `ClaudeCodeService.swift` | Loads sessions from `~/.claude/projects/` |
| `CodexService.swift` | Loads sessions from `~/.codex/sessions/` |
| `UsageService.swift` | Fetches Claude Code usage/quota via CLI |
| `CodexUsageService.swift` | Fetches Codex usage via RPC |
| `Terminal.swift` | AppleScript integration for iTerm2 |

### Models & Utilities
| File | Purpose |
|------|---------|
| `Models.swift` | `AgentType`, `Project`, `Session`, `SessionMessage` |
| `ClaudeUsage.swift` | Claude usage data structures |
| `CodexUsage.swift` | Codex usage data structures |
| `CodexRPC.swift` | JSON-RPC communication with Codex CLI |
| `TTYCommandRunner.swift` | PTY-based command execution |

## Key Patterns

### Session File Parsing
Claude Code JSONL:
```json
{"type": "user", "message": {"content": "..."}}
{"type": "assistant", "message": {"content": [...], "usage": {...}}}
{"type": "summary", "summary": "..."}
```

Codex JSONL:
```json
{"type": "session_meta", "payload": {"cwd": "...", "id": "..."}}
{"type": "response_item", "payload": {"role": "...", "content": [...]}}
```

### Terminal Integration
Sessions launch via AppleScript to iTerm2:
- Creates new tab (or window)
- Changes to project directory
- Runs CLI command with appropriate flags

### Path Decoding
Claude Code encodes paths by replacing `/` with `-`. `Project.decodePath()` reconstructs the original path by testing filesystem existence.

## Common Tasks

### Adding a Feature to Session Cards
1. Add state/properties to `SessionCardView` in `ContentView.swift`
2. Add parsing in the appropriate service if needed
3. Update models if new data fields required

### Modifying the Menu Bar
Edit `MenuBarView.swift` - uses `.window` style MenuBarExtra.

### Changing Theme/Colors
Edit `Theme.swift` - `AppTheme.forAgent()` returns agent-specific theme.

### Adding a New Agent Type
1. Add case to `AgentType` enum in `Models.swift`
2. Create service class following `ClaudeCodeService` pattern
3. Add to `AgentUIApp.swift` as `@StateObject`
4. Update switch statements in views

## File Locations
- Claude sessions: `~/.claude/projects/`
- Codex sessions: `~/.codex/sessions/`
- App bundle: `./Agent Hub.app`
- Build artifacts: `./.build/`

## Troubleshooting

**App won't build**: Run `xcode-select --install` for Command Line Tools

**Sessions not loading**: Check that session directories exist and JSONL files are readable

**Terminal not opening**: Ensure iTerm2 is installed and grant automation permissions in System Preferences > Privacy > Automation
