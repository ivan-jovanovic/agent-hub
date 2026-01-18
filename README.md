# Agent Hub

A native macOS menu bar app for managing Claude Code and OpenAI Codex CLI sessions.

![Agent Hub Screenshot](image_full3.png)

## Features

- **Menu bar access** — browse and resume sessions without leaving your workflow
- **Dual agent support** — switch between Claude Code and Codex
- **Session preview** — peek at recent messages before resuming
- **Token stats** — track usage and estimated costs
- **One-click actions** — continue, fork, or start new sessions

## Installation

```bash
git clone https://github.com/ivan-jovanovic/agent-hub.git
cd agent-hub
./Scripts/build.sh
open AgentUI.app
```

Move `AgentUI.app` to your Applications folder to keep it.

## Requirements

- macOS 14.0+
- [iTerm2](https://iterm2.com/)
- [Claude Code](https://github.com/anthropics/claude-code) and/or [Codex CLI](https://github.com/openai/codex)

## Contributing

Contributions welcome! See [CLAUDE.md](CLAUDE.md) for architecture details and development notes.

## License

MIT
