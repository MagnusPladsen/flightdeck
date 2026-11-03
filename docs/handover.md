# Handover: System Monitor (paused 2026-11-03)

Worktree: `~/git/system-monitor/.claude/worktrees/system-monitor-app-938093`, branch `claude/system-monitor-app-938093`. Nothing committed yet.

## What the user wants

- A Mac system monitor that lives in the menu bar. Clicking it opens a popover; it can also be opened as a full dashboard window. Meant to stay open all the time.
- Linux support later. Mac comes first.
- Users can add and manage their own things on the dashboard (custom widgets).
- **AI overview**:
  - which folders Claude, Codex and other agents are working in
  - each agent's state
  - subscription usage limits
- **Listening ports**: recognise the git project or worktree behind each port, e.g. "Next.js · shop · worktree checkout · :3000".
- **UI and UX**:
  - follows the system light/dark theme
  - status colours, e.g. a green dot for a running server

## Decisions made

- **Stack**: one Swift package.
  - `MonitorCore`: platform-neutral library (Foundation only). Builds on macOS and Linux.
  - `SystemMonitorApp`: macOS-only SwiftUI shell. It is guarded with `#if os(macOS)` in `Package.swift`.
- **Linux plan**: reuse `MonitorCore` and build a GTK4/libadwaita UI, either in Swift (adwaita-swift) or as a separate shell. Tray icon through StatusNotifierItem/AppIndicator; GNOME needs the AppIndicator extension. Not started.
- **Platform split**: `Platform/PlatformInterfaces.swift` defines three protocols, each with a Darwin and a Linux implementation:
  - `ProcessInspector`: Darwin uses libproc and sysctl; Linux uses `/proc`.
  - `ListeningSocketScanner`: Darwin parses `lsof -F`; Linux parses `ss -ltnp`.
  - `SystemMetricsReader`: Darwin uses mach, sysctl and IOKit; Linux uses `/proc` and `/sys`.
- **Usage limits**:
  - **Codex**: exact. The `rate_limits` field (5h and weekly `used_percent`, `resets_at`) is read from `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`.
  - **Claude tokens**: summed incrementally from `~/.claude/projects/**/*.jsonl`, deduped by message id plus request id.
  - **Claude limit %**: `ClaudeLimitsClient` calls the unofficial `api.anthropic.com/api/oauth/usage` endpoint with Claude Code's OAuth token (keychain item `Claude Code-credentials`, read via `/usr/bin/security`). Off by default; the setting is `claudeLimitsEnabled`.
- **Agent states**:
  - `working`: CPU at or above 5%, the log was written in the last 3s, or the last transcript entry is `user` (waiting on the model).
  - `needsApproval`: the last assistant message has `stop_reason` `tool_use`.
  - `yourTurn`: the agent finished its turn and is waiting for the next prompt.
  - `idle`: no activity for more than 30 min.
- **Agent detection**:
  - Claude Desktop sessions run as `.../claude.app/Contents/MacOS/claude`, so they are detected as Claude.
  - `codex app-server` is ignored.
- **Docker**: ports owned by Docker or OrbStack are mapped to container names via `docker ps`, cached for 15s.

## Done and verified

- `MonitorCore` fully written.
- `swift test`: 20 tests in 5 suites pass. They cover the parsers, project and worktree resolution, framework and agent detection, and agent state.
- `MonitorCore` builds on Linux: `docker run --rm -v "$PWD":/src:ro -w /src swift:6.1 swift build --target MonitorCore --scratch-path /tmp/build`.

## Done but not yet compiled

These app files exist but have not been built:

- `Sources/SystemMonitorApp/Store/MonitorEngine.swift`: wraps the collectors.
- `Sources/SystemMonitorApp/Store/MonitorStore.swift`: `@Observable` store.
  - Polls system every 2s, ports and agents every 5s, usage every 60s, widgets every 5s, project cache every 30s.
  - Actions: stop process, open in browser, reveal in Finder, open in editor (Zed, VS Code, Cursor, Xcode), open in terminal (Ghostty, kitty, iTerm, Terminal).
- `Sources/SystemMonitorApp/Settings/AppSettings.swift`: preferences in UserDefaults.
  - Menu bar metrics.
  - Show system ports, show idle agents.
  - Claude limits opt-in.
  - Custom widgets.
- `Sources/SystemMonitorApp/SystemMonitorApp.swift`: a one-line stub (`import SwiftUI`). It still needs the `@main` App.

## TODO (next session)

1. **`@main` App** in `SystemMonitorApp.swift`:
   - `MenuBarExtra(...).menuBarExtraStyle(.window)`
   - `Window("Dashboard", id: "dashboard")`
   - `Settings`
   - The app runs as an accessory with no Dock icon. Switch to `.regular` while the dashboard window is open and back to `.accessory` when it closes.
2. **Components** (`Views/Components/`):
   - `StatusDot`
   - `Sparkline` (Swift Charts)
   - `MetricTile`
   - `UsageBar`: green below 60%, yellow below 85%, red above
   - `FrameworkBadge`: colour per framework id
   - `PortRow`: green dot, framework, project, branch and worktree badge, `:port` chip, plus open, editor and stop actions
   - `AgentRow`: tool, project, state dot
   - Formatters for bytes, rates, durations and reset countdowns
3. **Menu bar** (`Views/MenuBar/`):
   - **Label**: icon plus the chosen metrics.
   - **Panel, about 380pt wide**: header; 2×2 tiles (CPU, Memory, Network, Disk); dev servers; active agents; Claude and Codex usage bars; footer with Dashboard, Settings and Quit.
4. **Dashboard** (`Views/Dashboard/`): `NavigationSplitView` with Overview, Servers & Ports, AI Agents, Processes and Widgets.
5. **Settings**:
   - General: menu bar metrics, launch at login via `SMAppService` (needs a bundled .app), show system ports.
   - AI: Claude limits opt-in, with a warning that the endpoint is unofficial.
   - Widgets: add, edit and remove. `CustomWidget.examples` provides starter widgets.
6. **`scripts/bundle.sh`**: builds a release and wraps it in `SystemMonitor.app` with an Info.plist (`LSUIElement` = true, bundle id e.g. `com.magnuspladsen.SystemMonitor`).
7. **Verify**: build, run, screenshot the popover and dashboard, and check against the real ports and agents on this Mac.
8. Add `.gitignore` (`.build/`, `*.app`), a README, and `docs/architecture.md` (referenced from the `Package.swift` comment).
9. Commit via `/commit`. The repo is personal; the no-reply email is already set locally.

## Ideas for later (agreed in brainstorm, not built)

- Notification when an agent needs approval.
- Pace projection for usage limits ("at this rate you hit the cap at 16:40").
- Disk hogs: `node_modules`, `target`, DerivedData, Docker images.
- Dirty repos list.
- Ollama and LM Studio loaded models.
- Timeline of spikes.
- Threshold alerts and a global hotkey.
- Remote machines via a headless agent.
- CLI and JSON output.
- GPU and temperatures (needs SMC).

## Gotchas

- In this shell, `ls` and `grep` are aliased with colours. Use `/bin/ls` and `/usr/bin/grep` in scripts.
- Claude logs are large (about 380 MB modified in the last 24h). `ClaudeTokenTracker` reads incrementally, but the first pass is heavy and must stay off the main thread.
- A Codex `session_meta` line can be hundreds of KB, so the cwd is pulled out of the file head with a string search instead of decoding the JSON.
