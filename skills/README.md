This project includes a minimal set of SwiftUI-focused skills intended for use with OpenAI Codex CLI (or similar agent tooling) when working on this repository.

Included skills (skills/public):
- swiftui-view-refactor — Consistent structure, dependency injection, and Observation usage for SwiftUI views.
- swiftui-ui-patterns — Best practices and examples for composing SwiftUI UI.
- swiftui-performance-audit — Guidance to audit and improve SwiftUI performance.

Why these:
- AgentUI is a macOS SwiftUI app; these skills directly support UI structure, patterns, and performance in this codebase.
- iOS‑specific or release‑process skills from the source collection were intentionally omitted to keep things lean.

How to use with Codex CLI:
1) Either symlink this folder into your Codex skills path:
   ln -s "$(pwd)/skills/public" "$CODEX_HOME/skills/public/agentui"
2) Or copy the individual skill folders under $CODEX_HOME/skills/public

These files are documentation for the agent; no runtime integration is needed by the app.

