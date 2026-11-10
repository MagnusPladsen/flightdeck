<div align="center">

<img src="Resources/AppIcon.png" width="128" alt="Flightdeck icon">

# Flightdeck

**Agent and system monitor for developers.**

Flightdeck lives in the macOS menu bar and shows which AI agents are working, which are waiting on you and where, next to your dev servers and system resources.

**[flightdeck.pladsen.dev](https://flightdeck.pladsen.dev)**

[![Latest release](https://img.shields.io/github/v/release/MagnusPladsen/flightdeck?style=flat-square&color=ff7a1a&label=release)](https://github.com/MagnusPladsen/flightdeck/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/MagnusPladsen/flightdeck/total?style=flat-square&color=ff7a1a)](https://github.com/MagnusPladsen/flightdeck/releases)
[![Stars](https://img.shields.io/github/stars/MagnusPladsen/flightdeck?style=flat-square&color=ff7a1a)](https://github.com/MagnusPladsen/flightdeck/stargazers)
[![Build](https://img.shields.io/github/actions/workflow/status/MagnusPladsen/flightdeck/ci.yml?style=flat-square&label=build)](https://github.com/MagnusPladsen/flightdeck/actions/workflows/ci.yml)
<br>
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)
![Apple Silicon and Intel](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-555555?style=flat-square)
[![Homebrew](https://img.shields.io/badge/Homebrew-magnuspladsen%2Ftap%2Fflightdeck-FBB040?style=flat-square&logo=homebrew&logoColor=white)](https://github.com/MagnusPladsen/homebrew-tap)

<br>

[![Download Flightdeck for macOS](https://img.shields.io/badge/Download_for_macOS-Flightdeck.zip-ff7a1a?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/MagnusPladsen/flightdeck/releases/latest/download/Flightdeck.zip)

```bash
brew trust magnuspladsen/tap
brew install --cask magnuspladsen/tap/flightdeck
```

<br>

<img src="docs/screenshots/overview.png" alt="Flightdeck overview: the agent that needs you, resources, and the Needs you list" width="860">

</div>

## Screenshots

| Menu bar panel | AI agents and usage limits |
|---|---|
| <img src="docs/screenshots/menu-bar-panel.png" alt="Menu bar panel" width="300"> | <img src="docs/screenshots/agents.png" alt="AI agents page" width="520"> |

| Rearrange any page | Dev servers by project |
|---|---|
| <img src="docs/screenshots/edit-layout.png" alt="Layout editing with the page unlocked" width="420"> | <img src="docs/screenshots/ports.png" alt="Servers and ports page" width="420"> |

| Worktrees and stale clean-up | Settings in the dashboard |
|---|---|
| <img src="docs/screenshots/worktrees.png" alt="Worktrees page with stale worktrees and Clean up" width="420"> | <img src="docs/screenshots/settings.png" alt="Settings page in the dashboard" width="420"> |

| The Office | Now playing |
|---|---|
| <img src="docs/screenshots/office.png" alt="Office party: dimmed rooms, dance floor, lasers, speaker stacks and the jukebox pads" width="420"> | <img src="docs/screenshots/now-playing.png" alt="Now playing with player controls and the adjust menu" width="420"> |

Screenshots use demo data: start the app with `FLIGHTDECK_DEMO=1` to see the same.

## Features

- **System**: CPU, memory, network and disk, with live sparklines. An optional Network by app section (add it from the hidden sections on the Processes page) shows each app's download and upload. Hover CPU or memory to see which apps use the most (helpers counted under their app), and hover a 5h or weekly limit to see when you'll hit it at the current pace. The Processes page opens with a collapsible "What's using what" breakdown above a sortable process list. Collapse the section when you don't need it.
- **Dev servers**: every listening port mapped to its git project, branch and worktree, with the framework detected (e.g. "Next.js · shop · worktree checkout · :3000"). Open in browser, editor or terminal, or stop the process. Stopped servers stay listed for 10 minutes with Run again, port conflicts are flagged, and Restart reruns a server in a terminal tab and keeps its log.
- **AI agents**: which folders Claude Code, Codex and other agents are working in, and whether each is working, waiting for approval or waiting for you. Agents that look stuck (e.g. the same tool call over and over) get a badge with the reason and count as needing you. Cards can show CPU and memory for the agent and everything it started. Each card shows what the agent changed since it started, with a Diff button, and agents that need you show their last message or question. When Claude keeps a task list, cards show which step it is on ("Step 3 of 5") with a bar per step. On the Agents page each Claude session has a context meter that turns orange as it nears auto-compaction, and agents sharing one checkout get a warning naming the files they both changed, with a shortcut to start the next one in a worktree. The overview also lists your dev servers between the agents and projects.
- **Agent controls**: Go to terminal focuses the agent's own Ghostty, iTerm2, Terminal or tmux tab; Stop interrupts it. Press ⌃⌥N anywhere to jump to the next agent that needs you (change the shortcut in Settings › General). New agent starts Claude Code or Codex in a new or existing worktree, in your terminal or a tmux window.
- **Keep awake**: optional, off by default. Keeps the Mac from sleeping while agents work; toggle it on the overview or the AI Agents page.
- **Worktrees**: every git worktree with its changes, ahead/behind, PR and the agent in it. Clean worktrees with no agent, no open PR and no commits for 14 days (adjustable) are marked stale, and Clean up removes them. Each row shows the size of its build caches (`node_modules`, `.build`, `.venv`, `target` and the like), and Clean up says how much it frees. Open pull requests show CI and review status, with an alert when CI fails on a branch an agent works in.
- **Alerts**: a notification when an agent needs you. Set quiet hours, or pause alerts from the bell in the menu bar panel; alerts held back arrive as one summary afterwards. Alerts can also stay quiet while a macOS Focus is on.
- **Usage limits**: Codex 5h and weekly limits from local logs; Claude token counts from local logs, and optionally Claude limit percentages. A forecast says when a limit runs out at the current pace.
- **Today**: agent time, time spent waiting on you and turns per project, compared with yesterday.
- **Token spend**: optional, off by default. Estimated cost per project and model from Claude Code and Codex logs, with a daily budget alert. Turn it on in Settings › AI.
- **Command palette**: press ⌘K in the dashboard to jump to any page, agent, dev server or worktree, start a new agent, pause alerts or skip a track. Type something that isn't a command and the last row asks Claude about it.
- **Ask Claude**: type a question in the overview's search bar and press Return, ask from the command palette, or press ⇧⌘K anywhere in the dashboard. The answer opens in a palette with follow-ups, and agents it names open their terminal in one click. It runs your installed `claude` CLI with read-only tools and a snapshot of what the dashboard shows.
- **Office**: a walkable pixel-art office with a room per repo, where each agent is posed by what it's doing. Agents that need you show as bouncing avatars along the top, and a jukebox plays what's on. While music plays the office turns into a party in your visualiser colours: the dance floor flashes, spotlights and lasers sweep, the speakers pump and every agent nods to the beat. Click the pads in front of the jukebox to skip or pause, or stand by it and press Space, Q or E. Walk up to an agent to go to its terminal or stop it. Windows along the outer walls follow the time of day, from daylight through sunset to a starry night with desk lamps on; type a city in Settings to see its rain, snow or clouds in them (looked up on Open-Meteo, off by default). Open it from Office in the sidebar or the Visualize button.
- **Achievements**: 59 to unlock for agent hours, agents working at once, turns, streaks, night-owl sessions, cleaned-up worktrees, tracks heard, office raves and more. The Achievements page lists every one, with progress on the locked ones, and a card and a notification announce each unlock.
- **Now playing**: what's playing in any player, with a visualiser in your theme's colours. Previous, play/pause and next, plus a volume slider for Spotify and Music. The adjust menu switches between Minimal and Expanded, ten visualiser styles and six palettes, and can turn on a dashboard background that pulses to the music in the same colours (ten styles, off by default). Live audio levels are opt-in; otherwise the bars follow play and pause. Optionally take the colours from the cover art (skipped for music in a browser, whose artwork is the site's icon) and flash status dots and the selected page on the beat; both are off by default. The menu bar panel shows a mini player, and the menu bar itself can show a few live music bars. The section collapses like System.
- **Custom widgets**: shell commands shown as dashboard tiles.
- **Status command**: `flightdeck status` and a status file for SketchyBar, tmux and Raycast. See [docs/integrations.md](docs/integrations.md).

Ships 13 layouts and 22 themes, and any theme works on any layout. Ignition is the default layout (a near-black agent board that leads with whichever agent needs you); the others are macOS, Terminal, Glass, Bento, Cockpit, Editorial, Neon, Agent focus, Projects, Zen, Mission control and Timeline. Each layout switches to the theme it was designed in, and Settings › Appearance lets you pick another theme (Clean Dark, Clean Light, "match system", Tokyo Night, Catppuccin, Dracula and other coding palettes). Built-in themes are read-only: copy one to make your own theme, which you can recolour, rename, duplicate and delete.

Settings is a dashboard page at the bottom of the sidebar, not a separate window.

A big clock sits beside the "needs you" headline on the overview; like every section it can be moved, resized or hidden. Hover a "Needs you" card and click its X to clear it until that agent does something new.

Every dashboard page can be rearranged: click the lock button in the toolbar, then drag sections to move them (also onto another page in the sidebar), drag their right edge to resize on a 12-column grid, or hide them and add them back from the tray. Locking saves a custom version of the layout, e.g. "Ignition (custom)"; Settings › Appearance resets it.

Flightdeck is macOS only for now. The core library already builds on Linux, but there is no Linux app yet.

## Install

```bash
brew trust magnuspladsen/tap
brew install --cask magnuspladsen/tap/flightdeck
```

Newer Homebrew versions only load casks from taps you trust, hence the first line.

Or download `Flightdeck.zip` from [Releases](https://github.com/MagnusPladsen/flightdeck/releases). The app is not notarized yet; if macOS blocks it, allow it under System Settings › Privacy & Security › Open Anyway.

Flightdeck updates itself with [Sparkle](https://sparkle-project.org): it checks daily once you allow it, and "Check for Updates…" sits in the menu bar panel footer and in Settings › General.

## Release

Add a `## <version> — <date>` entry to `CHANGELOG.md` and bump `VERSION` on `main`. The entry becomes the release notes, the site's Flight log and the What's new card the app shows once after it updates. `.github/workflows/release.yml` tests, builds a universal `Flightdeck.app`, signs the zip and writes `appcast.xml` with Sparkle's `generate_appcast`, publishes both as a GitHub release, uploads the appcast to the fixed `update-feed` release the app reads (`SUFeedURL`) and, when the `TAP_TOKEN` secret is set, updates `Casks/flightdeck.rb` in `MagnusPladsen/homebrew-tap` (first release copies `packaging/homebrew/flightdeck.rb` there).

The release needs the `SPARKLE_PRIVATE_KEY` secret: the EdDSA private key whose public half is `SUPublicEDKey` in `scripts/bundle.sh`. It lives in the login keychain under the `flightdeck` account of Sparkle's `generate_keys`.

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

Launch at login and update checks only work from the bundled app, which embeds `Sparkle.framework`. The app icon is drawn by `scripts/make-icon.swift`; run `swift scripts/make-icon.swift` to regenerate `Resources/AppIcon.icns`.

## Test

```bash
swift test
```

See [docs/architecture.md](docs/architecture.md) for how it fits together.

## License

[MIT](LICENSE)
