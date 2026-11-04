# System Monitor

A macOS menu bar system monitor for developers. Click the menu bar item for a quick panel, or open the full dashboard.

- **System**: CPU, memory, network and disk, with live sparklines.
- **Dev servers**: every listening port mapped to its git project, branch and worktree, with the framework detected (e.g. "Next.js · shop · worktree checkout · :3000"). Open in browser, editor or terminal, or stop the process.
- **AI agents**: which folders Claude Code, Codex and other agents are working in, and whether each is working, waiting for approval or waiting for you.
- **Usage limits**: Codex 5h and weekly limits from local logs; Claude token counts from local logs, and optionally Claude limit percentages.
- **Custom widgets**: shell commands shown as dashboard tiles.

Ships 12 themes (Clean Dark by default, Clean Light, a "match system" option, plus Tokyo Night, Catppuccin, Dracula and other popular coding palettes). Linux support is planned; the core library already builds there.

## Requirements

macOS 14+, Swift 6 toolchain (Xcode 16+).

## Run

```bash
swift run SystemMonitor
```

## Build the app bundle

```bash
scripts/bundle.sh
open SystemMonitor.app
```

Launch at login only works from the bundled app.

## Test

```bash
swift test
```

See [docs/architecture.md](docs/architecture.md) for how it fits together.
