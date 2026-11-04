# Architecture

One Swift package with two targets.

| Target | Platforms | Role |
|--------|-----------|------|
| `MonitorCore` | macOS, Linux | Collectors, models, parsers. Foundation only. |
| `SystemMonitorApp` | macOS | SwiftUI menu bar app and dashboard. Guarded by `#if os(macOS)` in `Package.swift`. |

## MonitorCore

- **Platform/** — three protocols in `PlatformInterfaces.swift`, each with a Darwin and a Linux implementation:
  - `ProcessInspector`: libproc + sysctl on Darwin, `/proc` on Linux.
  - `ListeningSocketScanner`: `lsof -F` on Darwin, `ss -ltnp` on Linux.
  - `SystemMetricsReader`: mach, sysctl and IOKit on Darwin, `/proc` and `/sys` on Linux.
- **Collectors/** — `SystemCollector` (CPU, memory, disks, network, battery, processes) and `PortCollector` (listening ports enriched with project, framework and Docker container).
- **Projects/** — `ProjectResolver` maps a working directory to its git repo, branch and worktree; `FrameworkDetector` recognises dev servers from the command line and `package.json`.
- **AI/** — `AgentCollector` finds Claude, Codex and other agent processes and derives their state from CPU and session logs. `ClaudeTokenTracker` and `CodexUsageReader` read local logs; `ClaudeLimitsClient` optionally calls Anthropic's unofficial usage endpoint.

## SystemMonitorApp

- **Store/** — `MonitorEngine` owns the collectors and blocks; `MonitorStore` (`@Observable`, main actor) polls it off the main thread: system every 2s, ports and agents every 5s, usage every 60s, widgets every 5s, project cache every 30s.
- **Settings/** — `AppSettings`, persisted to UserDefaults.
- **Views/** — `MenuBar/` (label and the 380pt popover), `Dashboard/` (`NavigationSplitView` with Overview, Servers & Ports, AI Agents, Processes, Widgets), `Settings/`, and shared `Components/`.

The app runs as an accessory (no Dock icon). `DockPresence` switches to a regular app while the dashboard window is open.

## Linux plan

Reuse `MonitorCore` behind a GTK4/libadwaita shell, with a tray icon via StatusNotifierItem/AppIndicator. Not started.
