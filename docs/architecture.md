# Architecture

One Swift package with three targets.

| Target | Platforms | Role |
|--------|-----------|------|
| `MonitorCore` | macOS, Linux | Collectors, models, parsers. Foundation only. |
| `FlightdeckApp` | macOS | SwiftUI menu bar app and dashboard. Guarded by `#if os(macOS)` in `Package.swift`. |
| `FlightdeckCLI` | macOS, Linux | The `flightdeck` command (product `flightdeck-cli`, so it can't clash with `Flightdeck` on a case-insensitive disk). Reads `status.json`; bundled as `Contents/Helpers/flightdeck`. See [integrations.md](integrations.md). |

## MonitorCore

- **Platform/** — three protocols in `PlatformInterfaces.swift`, each with a Darwin and a Linux implementation:
  - `ProcessInspector`: libproc + sysctl on Darwin, `/proc` on Linux.
  - `ListeningSocketScanner`: `lsof -F` on Darwin, `ss -ltnp` on Linux.
  - `SystemMetricsReader`: mach, sysctl and IOKit on Darwin, `/proc` and `/sys` on Linux.
- **Collectors/** — `SystemCollector` (CPU, memory, disks, network, battery, processes) and `PortCollector` (listening ports enriched with project, framework and Docker container).
- **Projects/** — `ProjectResolver` maps a working directory to its git repo, branch and worktree; `FrameworkDetector` recognises dev servers from the command line and `package.json`.
- **Layout/** — `PageLayouts` (which sections sit on which dashboard page, their column spans and the hidden ones), `SectionKind` and `GridPacking` (12-column row packing with spans of 3, 4, 6, 8 or 12).
- **AI/** — `AgentCollector` finds Claude, Codex and other agent processes and derives their state from CPU and session logs. `ClaudeTokenTracker` and `CodexUsageReader` read local logs; `ClaudeLimitsClient` optionally calls Anthropic's unofficial usage endpoint. `UsageHistory` keeps the last 45 minutes of limit readings and `LimitForecast` projects from them when a limit runs out.
- **Recap/** — `RecapLedger` adds up agent time per project and day from the 5s agent polls (working, waiting on you, longest wait, finished turns, sessions); gaps over 30s are left out. `DailyRecapTracker` in the app saves it to `~/Library/Application Support/Flightdeck/recap.json` about once a minute and keeps 14 days.

## FlightdeckApp

- **Store/** — `MonitorEngine` owns the collectors and blocks; `MonitorStore` (`@Observable`, main actor) polls it off the main thread: system every 2s, ports and agents every 5s, usage every 60s, widgets every 5s, project cache every 30s.
- **Settings/** — `AppSettings`, persisted to UserDefaults.
- **Ask/** — `ClaudeAsker` answers the dashboard's questions: `AskContext` writes a `CLAUDE.md` guide and a live `state.md` to `~/Library/Application Support/Flightdeck/Ask/`, then it runs `claude -p` there with only Read, Grep and Glob allowed (`--continue` for follow-ups). `AskPalette` shows the answer over the dashboard window; Return in the overview search bar or Edit › Ask Claude… (⌘K) opens it.
- **Integrations/** — `StatusPublisher` writes `StatusReport` (MonitorCore **Status/**) to `status.json` after each agents and ports poll, only when it changed, otherwise touching it so readers can spot a stopped app; it also fires the optional SketchyBar event. `CommandLineTool` links the bundled command into the user's PATH.
- **Updates/** — `AppUpdater` wraps Sparkle's `SPUStandardUpdaterController` and publishes whether a check can start. It only starts inside the bundled app, which carries `SUFeedURL` and `SUPublicEDKey`; Sparkle keeps the automatic-check setting in its own user defaults. The release workflow publishes the signed appcast to the `update-feed` release.
- **Views/** — `MenuBar/` (label and the 380pt popover), `Dashboard/` (`NavigationSplitView` with Overview, Servers & Ports, AI Agents, Processes, Widgets; every page is a `PageCanvas` of sections on a `SectionGrid`, arranged by the current theme's `DashboardLayout` or the user's custom version of it; the sidebar and menu bar panel are styled by that layout too), `Settings/`, and shared `Components/`.
- **Editing layouts** — `LayoutEditor` holds a draft while the window is unlocked; `EditableSection` adds the drag handle, resize edge, hide and move-to-page controls; locking saves the draft to `AppSettings.customLayouts` keyed by layout. Saved layouts are sanitised on load, so deleted widgets drop out and new ones land on their home page.

The app runs as an accessory (no Dock icon). `DockPresence` switches to a regular app while the dashboard window is open.

## Linux plan

Not started. See [linux.md](linux.md) for what already works, the options and the recommended path (a headless `flightdeck` binary with a web dashboard, then a tray icon).
