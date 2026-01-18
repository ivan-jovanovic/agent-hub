# AGENTS.md

Instructions for AI coding agents working on Agent Hub.

## Project Overview

Agent Hub is a native macOS SwiftUI app for managing Claude Code and OpenAI Codex CLI sessions. It has two interfaces: a full window app and a menu bar popover.

**Tech stack**: Swift, SwiftUI, Swift Package Manager

**Key directories**:
- `Sources/AgentUI/` - All Swift source files
- `Scripts/` - Build and setup scripts
- `Resources/` - App icon, Info.plist, entitlements

## Build and Test

```bash
# Setup (checks dependencies + builds)
./Scripts/setup.sh

# Build only
./Scripts/build.sh

# Run
open "Agent Hub.app"
```

There are no automated tests yet. Verify changes by building and running the app.

## Code Style

- **SwiftUI**: Use `@StateObject` for owned state, `@ObservedObject` for passed state
- **Naming**: Services end with `Service`, views end with `View`
- **File organization**: One major view/service per file
- **No comments**: Code should be self-explanatory; avoid unnecessary comments
- **Keep it simple**: No over-engineering, no premature abstractions

## Architecture Rules

- Services handle data loading and CLI interaction
- Views are purely presentational with minimal logic
- Theme colors come from `Theme.swift` via `AppTheme.forAgent()`
- Terminal launches go through `Terminal.swift` AppleScript helpers
- Both agents (Claude Code, Codex) follow the same service interface pattern

## Adding Features

1. **New UI element**: Add to appropriate view in `ContentView.swift` or `MenuBarView.swift`
2. **New data field**: Update model in `Models.swift`, add parsing in service
3. **New agent type**: Add enum case, create service, update all switch statements

## Files to Know

| File | What it does |
|------|--------------|
| `AgentUIApp.swift` | App entry point, window and menu bar setup |
| `ContentView.swift` | Main window with sidebar and detail views |
| `MenuBarView.swift` | Menu bar popover UI |
| `ClaudeCodeService.swift` | Claude session loading and launching |
| `CodexService.swift` | Codex session loading and launching |
| `Models.swift` | Core data types: Project, Session, AgentType |
| `Theme.swift` | Colors, gradients, typography |

## Common Pitfalls

- **Use Homebrew Swift for builds**: The build script prefers `/opt/homebrew/opt/swift/bin/swift` if available
- **App bundle name has a space**: It's `Agent Hub.app`, not `AgentHub.app`
- **Path encoding**: Claude Code encodes `/` as `-` in directory names
- **iTerm2 required**: Terminal integration only works with iTerm2, not Terminal.app

## Commit Messages

Use conventional style:
- `Add <feature>` for new features
- `Fix <issue>` for bug fixes
- `Update <thing>` for changes to existing code
- Keep messages concise (one line preferred)

## Security

- Never commit API keys or tokens
- Session files may contain sensitive conversation data - don't log contents
- AppleScript automation requires user permission - don't try to bypass
