# Flightdeck on Linux

Can Flightdeck run on Linux, and what is the shortest useful path there? Status as of November 2026.

**Short answer:** the data side is mostly done. `MonitorCore` already builds on Linux, and its collectors work there once one real bug is fixed. The work is the UI, the tray and packaging. The recommended path is a headless `flightdeck` binary that serves a web dashboard, then a tray icon, and native packages last.

## What was checked

Everything below ran in Docker (`swift:6.1`, Ubuntu 24.04, aarch64) on a copy of the repo at `db1af8c`.

| Check | Result |
|-------|--------|
| `swift build` | `MonitorCore` builds. `Package.swift` drops `FlightdeckApp` and Sparkle on Linux, as intended. |
| `swift test` | Does not compile: `ParserTests.procArgsSkipsExecPathAndPadding` and `appBundleNameFromExecutablePath` use `DarwinProcessInspector`, which only exists on Darwin. Fenced with `#if canImport(Darwin)`, all 29 tests pass. |
| Smoke run of the collectors | Hangs in `CommandRunner.run`, see below. With that patched, a throwaway executable printed CPU, memory, disk and processes, found a `python3 -m http.server` on 127.0.0.1:5173 with its project, branch and framework, and found a process named `claude` with its working folder and project. |

### The `CommandRunner` hang

`CommandRunner.run` reads the pipe to the end and then calls `Process.waitUntilExit()`, with a timeout scheduled through `DispatchQueue.global().asyncAfter`. On Linux (swift-corelibs-foundation), `waitUntilExit()` never returns. It hung on the first `ss` call and on the second `/bin/echo` call in a standalone repro. Without the scheduled timeout the same code works, so the hang depends on timing.

This blocks every caller on Linux: the port scan (`ss`), the Docker lookup, and custom widgets. It does not happen on macOS.

Fix, verified in the repro: wait on a semaphore that `terminationHandler` signals instead of calling `waitUntilExit()`.

```swift
let exited = DispatchSemaphore(value: 0)
process.terminationHandler = { _ in exited.signal() }
try process.run()
// ... read the pipe, as today ...
exited.wait()
```

## MonitorCore, part by part

The platform split in `Platform/PlatformInterfaces.swift` already does most of the work: `PlatformServices` picks the Darwin or the Linux implementation at compile time.

| Area | macOS source | Linux source | State on Linux |
|------|--------------|--------------|----------------|
| Process list, args, cwd (`ProcessInspector`) | libproc, `sysctl(KERN_PROCARGS2)` | `/proc/<pid>/stat`, `cmdline`, `cwd` | Works. Hardcodes 100 clock ticks per second and 4 KiB pages; read `sysconf(_SC_CLK_TCK)` and `sysconf(_SC_PAGESIZE)` instead, since Asahi and some arm64 kernels use 16 KiB or 64 KiB pages. |
| Listening ports (`ListeningSocketScanner`) | `lsof -F` | `ss -H -ltnp` (iproute2) | Works once `CommandRunner` is fixed. Sockets owned by other users (root's `docker-proxy`, system services) have no `users:` column without root, so the parser drops them. Show them as "unknown owner" instead. |
| CPU, load, uptime (`SystemMetricsReader`) | mach `host_processor_info`, sysctl | `/proc/stat`, `/proc/loadavg`, `/proc/uptime` | Works. |
| Memory | `host_statistics64`, `vm.swapusage`, memory pressure sysctl | `/proc/meminfo` | Works. Wired and compressed are 0. Pressure is guessed from used fraction; `/proc/pressure/memory` (PSI) is the real equivalent. |
| Disks | `statfs` per volume | `statvfs("/")` | Root only. Read `/proc/self/mounts` and skip pseudo file systems to list `/home` and other mounts. |
| Network | `getifaddrs` with `if_data` | `/proc/net/dev` | Works. |
| Battery | IOKit power sources | `/sys/class/power_supply/BAT0` | Works for `BAT0` only; scan `power_supply/*` with `type == Battery`. No time remaining. |
| Docker container names | `docker ps` | same | Works once `CommandRunner` is fixed. On Linux Docker publishes ports from `docker-proxy` (root) or iptables with no listening process at all, so many container ports are invisible without root. Rootless Podman uses `rootlessport`, which `isDockerProcess` does not match. |
| Projects (`ProjectResolver`) | reads `.git` | same | Works. Skips `~/Library`; on Linux it should also skip `~/.cache`, `~/.local` and `~/.config`. |
| Claude limits (`ClaudeLimitsClient`) | keychain via `security`, then file | `~/.claude/.credentials.json` | Already handled; `FoundationNetworking` is imported on Linux. |
| `CommandRunner` search path | Homebrew paths | same list | Add `/home/linuxbrew/.linuxbrew/bin` and `~/.local/bin` for widgets. |

## Agent detection

Agent detection is already Linux-ready, because it only needs process arguments, the working folder and log files.

- **Finding agents.** `AgentDetector` reads argv. On Linux that comes from `/proc/<pid>/cmdline`, which matches the macOS output: the native `claude` binary, the Rust `codex` binary and `node …/@anthropic-ai/claude-code/cli.js` all match. The smoke run found a process named `claude`.
- **Where it works.** `/proc/<pid>/cwd` replaces libproc's vnode path. It only resolves for your own processes, which covers agents you started.
- **Is it running a command.** `hasShellDescendant` uses parent PIDs from `/proc/<pid>/stat`. The `comm` name is cut to 15 characters on Linux, which does not affect `zsh`, `bash` and the other shell names.
- **State from logs.** `ClaudeSessionLogs` and `CodexSessionLogs` read `~/.claude/projects` and `~/.codex/sessions`, the same paths on Linux. Neither honours `CLAUDE_CONFIG_DIR` or `CODEX_HOME` yet, which matters on both platforms.
- **Dev servers and ports.** `FrameworkDetector` works from the command line and `package.json` only, so it needs no change.
- **What does not carry over.** The "open in editor" action and the app-bundle names from `DarwinProcessInspector.appBundleName` are macOS-only. On Linux, use `.desktop` files and `xdg-open` or the editor's CLI.
- **Remote hosts.** Many Linux agent sessions run on devboxes over SSH, where there is no desktop at all. That is the main reason to choose a UI that also works without one.

## UI options

The SwiftUI shell (`FlightdeckApp`, about 3,900 lines) cannot be reused on Linux. Every option means a new front end; they differ in how much code is shared and what users get.

Two facts constrain every desktop option:

- **There is no menu bar popover on Linux.** The nearest thing is a StatusNotifierItem tray icon: an icon, a tooltip, a text label on some desktops, and a D-Bus menu (`com.canonical.dbusmenu`). It cannot host the 380pt panel; clicking it opens a menu or a window.
- **GNOME has no tray by default.** It needs the AppIndicator extension, which Ubuntu ships enabled and Fedora does not. KDE, XFCE, Cinnamon and Waybar support it natively.

### (a) Native GTK or Qt front end

- **adwaita-swift.** Declarative Swift over libadwaita, the closest in style to SwiftUI. It is young with a small community, and GTK4 has no tray API, so the tray has to be a separate piece.
- **SwiftCrossUI.** A SwiftUI-like API with GTK, AppKit and WinUI back ends. It is not a drop-in for SwiftUI, so views are rewritten either way. The widget set is still thin, especially for custom drawing such as sparklines and the section grid.
- **Qt.** There is no maintained Swift binding. It would be a C++/QML app talking to the core over IPC, so it is really option (d) with Qt instead of a web view.
- **Trade-off.** Native look and one language, but views are rewritten against a younger toolkit, and it still needs a separate tray and a running desktop.

### (b) Tray icon via StatusNotifierItem

- **Not a full UI on its own.** It fits alongside any of the others.
- **Implementation.** libayatana-appindicator is GTK3-based and clashes with GTK4 in the same process. Speaking SNI and dbusmenu directly over D-Bus (GLib's GDBus, or sd-bus) avoids GTK entirely and fits a headless daemon.
- **Desktop notifications.** `org.freedesktop.Notifications` on the same bus covers "Claude needs approval".
- **What it shows.** An icon tinted by the worst agent state, a label such as `2 ⚑ 41%` where supported, and a menu with agents that need you, busy ports, and "Open dashboard".

### (c) TUI or web dashboard served by the core

- **Web.** A `flightdeck serve` command runs the collectors on the same cadence as `MonitorStore` and exposes JSON and Server-Sent Events, plus a static HTML dashboard. `PageLayouts` and `GridPacking` are already in the core, so the 12-column layout can be sent to the browser as JSON.
  - Works on any desktop, over SSH port forwarding, and on headless devboxes.
  - One binary, no GUI libraries to link, so it is the easiest to package.
  - Doesn't feel native, and it needs a browser tab or a pinned web app.
- **TUI.** A `flightdeck top` view in the terminal. Cheap to build for agents and ports, and good over SSH, but a poor fit for the dashboard's grid and widgets. It is a nice extra, not the main UI.

### (d) Tauri or Electron around a core daemon

- **How it fits together.** The Swift core runs as a sidecar daemon (the same `serve` as option c), and Tauri wraps the web dashboard in a window with tray, notifications, auto-update and `.deb`, `.rpm` and AppImage bundling built in.
- **Trade-off.** It adds Rust and a JavaScript build to the repo, and the sidecar has to be bundled and supervised. Tauri uses WebKitGTK, which is lighter than Electron. Electron gives the same result at about 150 MB, which is hard to justify for a monitor.
- **Ordering.** This is option (c) plus a shell, so it can come later without throwing anything away.

## Packaging

The core links only Foundation, so `swift build -c release --static-swift-stdlib` gives a single binary that needs only glibc (plus libcurl for `FoundationNetworking`). The Swift Static Linux SDK (musl) can go further and cross-compile fully static x86_64 and aarch64 binaries from macOS; `LinuxSystemMetricsReader` already has a `Musl` branch. Check before relying on it that `FoundationNetworking` works in the static SDK.

| Format | Fit | Notes |
|--------|-----|-------|
| Tarball on GitHub Releases | Good, first | One static binary, plus a systemd user unit and a `.desktop` file. |
| `.deb` / `.rpm` | Good | Built with `nfpm` from the same binary; depend on `iproute2`. No update channel unless you host an apt repo, so start with GitHub Releases downloads. |
| Homebrew on Linux | Good | Needs a formula, not a cask, since casks are macOS-only. Add `Formula/flightdeck.rb` to `MagnusPladsen/homebrew-tap` with Linux bottles or prebuilt tarball URLs per architecture. Developers who use Homebrew on Linux are likely users. |
| AppImage | OK once there is a GUI | Little value for a headless binary. |
| Flatpak | Poor | The sandbox has its own PID namespace, so it cannot see host processes in `/proc` or their sockets. Monitors such as Mission Center work around this with `flatpak-spawn --host` helpers. Not worth it early. |
| Snap | Poor | Strict confinement has the same visibility problem; classic confinement needs Store approval. |

**Updates.** Sparkle is macOS-only. On Linux, package managers handle updates for `.deb` and Homebrew; the daemon can check the GitHub releases API and show "update available" in the dashboard.

**How `release.yml` grows:**

1. Add a `linux` job on `ubuntu-24.04` and `ubuntu-24.04-arm` that runs `swift test` and builds the release binary. Run it on pull requests too, so the core can't silently break on Linux. Today nothing builds Linux in CI.
2. Package each architecture as a tarball and `.deb` with `nfpm`, and upload them to the same `v$VERSION` release the macOS job creates. Either make `release` depend on `linux`, or create the release once and have both jobs upload to it.
3. Extend the Homebrew step to update the formula's version and per-architecture SHA-256 values next to the cask.
4. Drop `sed -i ''`, which is BSD-only, in any step that moves to a Linux runner.

## Recommended path

Build a headless `flightdeck` binary with a web dashboard first, then a tray, then decide about a native window.

1. It reuses the most code: everything up to the HTTP layer is the existing core.
2. It works for the Linux setups this app's users most likely have, including SSH devboxes, which no native GUI covers.
3. It avoids choosing between young Swift GUI toolkits now. Tauri (d) or adwaita-swift (a) can be added later on top of the same daemon.

| Step | What | Rough effort |
|------|------|--------------|
| 1 | **Linux-correct core.** Fix the `CommandRunner` hang, fence the two Darwin tests, use `sysconf` for page size and clock ticks, keep `ss` rows without an owner, and add a Linux CI job. | 1–2 days |
| 2 | **Move the polling loop into the core.** Pull `MonitorEngine` and the cadence logic from `MonitorStore` into a `MonitorService` in `MonitorCore`, so the macOS app and Linux share it. | 1–2 days |
| 3 | **`flightdeck` CLI target.** `flightdeck snapshot --json`, `flightdeck agents`, `flightdeck ports`. Useful on its own, and on macOS too. | 1–2 days |
| 4 | **`flightdeck serve`.** JSON and SSE over HTTP (Hummingbird, or a small SwiftNIO handler), bound to 127.0.0.1 by default, plus a systemd user unit. | 2–4 days |
| 5 | **Web dashboard.** Overview, Agents, Servers & Ports and Processes pages, rendered from `PageLayouts` JSON with no editing at first. | 1–2 weeks |
| 6 | **Tray and notifications.** SNI and dbusmenu over D-Bus with an "agent needs you" notification. Check on GNOME + AppIndicator, KDE and Waybar. | ~1 week |
| 7 | **Packaging.** Static binaries, tarball, `.deb`, Homebrew formula and the `release.yml` changes above. | 2–3 days |
| 8 | **Optional native window.** Tauri around the dashboard or an adwaita-swift app, decided by how step 5 feels in daily use. | 2–4 weeks |

Steps 1–4 give a usable `flightdeck` on Linux in about two weeks of focused work. Steps 1 and 2 also help the macOS app.

## First step to build next

**Make the core Linux-correct and keep it that way (step 1).** It is small, needs no UI decisions, and every other step depends on it.

- `Support/CommandRunner.swift`: wait on `terminationHandler` with a semaphore instead of `waitUntilExit()`.
- `Tests/MonitorCoreTests/ParserTests.swift`: wrap the two `DarwinProcessInspector` tests in `#if canImport(Darwin)`.
- `Platform/Linux/LinuxProcessInspector.swift`: use `sysconf(_SC_CLK_TCK)` and `sysconf(_SC_PAGESIZE)` instead of the constants.
- `.github/workflows/`: a job on `ubuntu-24.04` that runs `swift build` and `swift test` on every push and pull request.
- Done when CI is green on Linux and a test runs `CommandRunner.run("/bin/echo", …)` several times in a row.
