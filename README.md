<div align="center">

<img src="Resources/AppIcon.png" width="128" alt="Flightdeck icon">

# Flightdeck

**Agent and system monitor for developers.**

Flightdeck lives in the macOS menu bar and shows which AI agents are working, which are waiting on you and where, next to your dev servers and system resources.

[![Latest release](https://img.shields.io/github/v/release/MagnusPladsen/flightdeck?style=flat-square&color=ff7a1a&label=release)](https://github.com/MagnusPladsen/flightdeck/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/MagnusPladsen/flightdeck/total?style=flat-square&color=ff7a1a)](https://github.com/MagnusPladsen/flightdeck/releases)
[![Stars](https://img.shields.io/github/stars/MagnusPladsen/flightdeck?style=flat-square&color=ff7a1a)](https://github.com/MagnusPladsen/flightdeck/stargazers)
[![Release workflow](https://img.shields.io/github/actions/workflow/status/MagnusPladsen/flightdeck/release.yml?style=flat-square&label=build)](https://github.com/MagnusPladsen/flightdeck/actions/workflows/release.yml)
<br>
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)
![Apple Silicon and Intel](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-555555?style=flat-square)
[![Homebrew](https://img.shields.io/badge/Homebrew-magnuspladsen%2Ftap%2Fflightdeck-FBB040?style=flat-square&logo=homebrew&logoColor=white)](https://github.com/MagnusPladsen/homebrew-tap)

<br>

[![Download Flightdeck for macOS](https://img.shields.io/badge/Download_for_macOS-Flightdeck.zip-ff7a1a?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/MagnusPladsen/flightdeck/releases/latest/download/Flightdeck.zip)

```bash
brew install --cask magnuspladsen/tap/flightdeck
```

<br>

<img src="docs/screenshots/overview.png" alt="Flightdeck overview: the agent that needs you, resources, and your-turn agents" width="860">

</div>

## Screenshots

| Menu bar panel | AI agents and usage limits |
|---|---|
| <img src="docs/screenshots/menu-bar-panel.png" alt="Menu bar panel" width="300"> | <img src="docs/screenshots/agents.png" alt="AI agents page" width="520"> |

| Rearrange any page | Dev servers by project |
|---|---|
| <img src="docs/screenshots/edit-layout.png" alt="Layout editing with the page unlocked" width="420"> | <img src="docs/screenshots/ports.png" alt="Servers and ports page" width="420"> |

Screenshots use demo data: start the app with `FLIGHTDECK_DEMO=1` to see the same.

## Features

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
brew install --cask magnuspladsen/tap/flightdeck
```

Or download `Flightdeck.zip` from [Releases](https://github.com/MagnusPladsen/flightdeck/releases). The app is not notarized yet; if macOS blocks it, allow it under System Settings › Privacy & Security › Open Anyway.

## Release

Bump `VERSION` on `main`. `.github/workflows/release.yml` tests, builds a universal `Flightdeck.app`, publishes it as a GitHub release and, when the `TAP_TOKEN` secret is set, updates `Casks/flightdeck.rb` in `MagnusPladsen/homebrew-tap` (first release copies `packaging/homebrew/flightdeck.rb` there).

## Requirements

macOS 14+, Swift 6 toolchain (Xcode 16+).

## Run

```bash
swift run Flightdeck
```

## Build the app bundle

```bash
scripts/bundle.sh
open Flightdeck.app
```

Launch at login only works from the bundled app. The app icon is drawn by `scripts/make-icon.swift`; run `swift scripts/make-icon.swift` to regenerate `Resources/AppIcon.icns`.

## Test

```bash
swift test
```

See [docs/architecture.md](docs/architecture.md) for how it fits together.
