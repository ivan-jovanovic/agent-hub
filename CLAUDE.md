# CLAUDE.md - Agent Instructions for AgentUI

## Project Overview

AgentUI is a native macOS SwiftUI application that provides a GUI for managing Claude Code and OpenAI Codex CLI sessions. It reads session data from the filesystem and launches terminal sessions via AppleScript (iTerm2).

## Building and Running

### Build for Production
```bash
./Scripts/build.sh
```
This creates `AgentUI.app` in the project root.

### Run the App
```bash
open AgentUI.app
# or
./Scripts/run.sh
```

### Development Notes
- This is a Swift Package Manager project, NOT an Xcode project
- Build output goes to `.build/` directory
- The build script copies the binary to an app bundle structure

## Architecture

### Entry Point
- `AgentUIApp.swift` - Main app with WindowGroup and MenuBarExtra scenes

### Services (Data Layer)
- `ClaudeCodeService.swift` - Loads sessions from `~/.claude/projects/`
- `CodexService.swift` - Loads sessions from `~/.codex/sessions/`

Both services:
- Parse JSONL session files
- Extract metadata (summary, git branch, tokens, model)
- Provide session preview (recent messages)
- Launch iTerm2 sessions via AppleScript

### Models
- `Models.swift` contains:
  - `AgentType` enum (claudeCode, codex)
  - `Project` - Groups sessions by directory path
  - `Session` - Individual conversation with metadata
  - `SessionMessage` - For preview display

### Views
- `ContentView.swift` - Main window UI:
  - `ProjectListView` - Sidebar with project list
  - `SessionListView` - Detail view with session cards
  - `SessionCardView` - Individual session with actions
  - `SessionPreviewView` - Popover showing recent messages

- `MenuBarView.swift` - Menu bar popover:
  - Compact project cards
  - Quick actions (Continue, New, Finder)
  - Agent toggle

### Theming
- `Theme.swift` - Centralized theming:
  - `AppTheme` - Agent-specific colors and gradients
  - `AppTypography` - Font styles
  - Color extensions for semantic colors

## Key Implementation Details

### Session File Parsing
Claude Code JSONL format:
```json
{"type": "user", "message": {"content": "..."}}
{"type": "assistant", "message": {"content": [...], "usage": {...}}}
{"type": "summary", "summary": "..."}
```

Codex JSONL format:
```json
{"type": "session_meta", "payload": {"cwd": "...", "id": "..."}}
{"type": "response_item", "payload": {"role": "...", "content": [...]}}
{"type": "event_msg", "payload": {"type": "token_count", "info": {...}}}
```

### Terminal Integration
Sessions are launched via AppleScript to iTerm2:
- Creates new tab in existing window (or new window)
- Changes to project directory
- Runs appropriate CLI command (claude/codex with flags)

### Path Decoding (Claude Code)
Claude Code encodes paths by replacing `/` with `-`. The `Project.decodePath()` method reconstructs the original path by testing filesystem existence.

## Common Tasks

### Adding a New Feature to Session Cards
1. Add state/properties to `SessionCardView` in `ContentView.swift`
2. If data needed, add parsing in the appropriate service
3. Update the model if new data fields required

### Modifying the Menu Bar
Edit `MenuBarView.swift` - it uses `.window` style MenuBarExtra for rich UI.

### Changing Colors/Theme
Edit `Theme.swift`:
- `AppTheme.forAgent()` returns agent-specific theme
- Modify gradients, accent colors there

### Adding a New Agent Type
1. Add case to `AgentType` enum in `Models.swift`
2. Create new service class following `ClaudeCodeService` pattern
3. Add to `AgentUIApp.swift` as `@StateObject`
4. Update all switch statements in views

## Troubleshooting

### App Won't Build
- Ensure you have Command Line Tools: `xcode-select --install`
- The project uses SPM, not Xcode projects

### Sessions Not Loading
- Check that `~/.claude/projects/` or `~/.codex/sessions/` exist
- Verify JSONL files are readable
- Check Console.app for errors

### Terminal Not Opening
- Ensure iTerm2 is installed
- Grant automation permissions in System Preferences > Privacy > Automation

## File Locations
- Session data: `~/.claude/projects/` and `~/.codex/sessions/`
- App bundle: `./AgentUI.app`
- Build artifacts: `./.build/`
