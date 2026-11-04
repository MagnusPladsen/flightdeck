# System Monitor

A macOS menu bar system monitor for developers. Click the menu bar item for a quick panel, or open the full dashboard.

- **System**: CPU, memory, network and disk, with live sparklines.
- **Dev servers**: every listening port mapped to its git project, branch and worktree, with the framework detected (e.g. "Next.js · shop · worktree checkout · :3000"). Open in browser, editor or terminal, or stop the process.
- **AI agents**: which folders Claude Code, Codex and other agents are working in, and whether each is working, waiting for approval or waiting for you.
- **Usage limits**: Codex 5h and weekly limits from local logs; Claude token counts from local logs, and optionally Claude limit percentages.
- **Custom widgets**: shell commands shown as dashboard tiles.

Ships 13 themes. A theme sets the dashboard layout as well as its colours: Ignition is the default (a near-black agent board that leads with whichever agent needs you), plus Clean Dark, Clean Light, a "match system" option, Tokyo Night, Catppuccin, Dracula and other popular coding palettes. More layouts are planned.

Every dashboard page can be rearranged: click the lock button in the toolbar, then drag sections to move them (also onto another page in the sidebar), drag their right edge to resize on a 12-column grid, or hide them and add them back from the tray. Locking saves a custom version of the theme's layout, e.g. "Ignition (custom)"; Settings › Appearance resets it.

Linux support is planned; the core library already builds there.

## Install

```bash
brew install --cask magnuspladsen/tap/system-monitor
```

Or download `SystemMonitor.zip` from [Releases](https://github.com/MagnusPladsen/system-monitor/releases). The app is not notarized yet; if macOS blocks it, allow it under System Settings › Privacy & Security › Open Anyway.

## Release

Bump `VERSION` on `main`. `.github/workflows/release.yml` tests, builds a universal `SystemMonitor.app`, publishes it as a GitHub release and, when the `TAP_TOKEN` secret is set, updates `Casks/system-monitor.rb` in `MagnusPladsen/homebrew-tap` (first release copies `packaging/homebrew/system-monitor.rb` there).

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

Launch at login only works from the bundled app. The app icon is drawn by `scripts/make-icon.swift`; run `swift scripts/make-icon.swift` to regenerate `Resources/AppIcon.icns`.

## Test

```bash
swift test
```

See [docs/architecture.md](docs/architecture.md) for how it fits together.
