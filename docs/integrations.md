# Status bar and shell integrations

Flightdeck keeps a small JSON status file current and ships a `flightdeck` command that reads it. Status bars, tmux and
launchers can show your agents from it without running any AI or calling any API.

## Install the command

Settings › General › Command line › **Install command-line tool** links `Flightdeck.app/Contents/Helpers/flightdeck` into
`~/.local/bin`, or `/usr/local/bin` when only that one is on your PATH and writable. When the folder isn't on your PATH
yet, Settings shows the line to add to your shell profile:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

## The command

```sh
flightdeck status                              # 2 working · 1 needs you · 3 servers
flightdeck status --json                       # the whole status file
flightdeck status --format '{needsYou}/{working}'   # 1/2
```

Placeholders: `{working}`, `{needsYou}`, `{idle}`, `{agents}`, `{servers}`, `{cpu}`, `{memory}`, `{summary}`.
Unknown placeholders are left as they are.

Exit codes: `0` ok, `1` Flightdeck isn't running (no status file, or not refreshed for 30 seconds), `64` bad arguments.
The reason goes to stderr, so `$(flightdeck status)` is empty when the app is not running.

## The status file

`~/Library/Application Support/Flightdeck/status.json`, rewritten atomically after each agents and ports poll (every 5
seconds) when something in it changed, and at least once a minute so `system` and `lastActivity` stay roughly current;
changes to those two alone don't count. Otherwise only its modification time is refreshed, which is what the
30-second staleness check reads. Set `FLIGHTDECK_STATUS_FILE` to point the command at another file.

```json
{
  "version": 1,
  "appVersion": "1.5.0",
  "updatedAt": "2026-11-09T10:00:00Z",
  "counts": { "working": 2, "needsYou": 1, "idle": 0, "servers": 1 },
  "agents": [
    {
      "tool": "claude",
      "folder": "/Users/me/code/app",
      "project": "app",
      "branch": "main",
      "state": "yourTurn",
      "waitingSince": "2026-11-09T09:59:00Z",
      "lastActivity": "2026-11-09T09:59:00Z",
      "lastAction": "Running swift test"
    }
  ],
  "servers": [{ "port": 5173, "project": "site", "framework": "Vite" }],
  "system": { "cpuPercent": 34, "memoryPercent": 61 },
  "limits": [{ "tool": "claude", "window": "5h", "usedPercent": 42, "resetsAt": "2026-11-09T12:00:00Z" }]
}
```

- `version` is the schema version; it goes up only when fields change meaning or disappear.
- `updatedAt` is when the file was last rewritten.
- `state` is one of `working`, `needsApproval`, `yourTurn`, `possiblyStuck`, `idle`. `needsYou` counts
  `needsApproval`, `yourTurn` and `possiblyStuck`, and only those agents have `waitingSince`.
- `servers` lists dev servers only, not system ports. `project`, `framework`, `branch`, `lastAction`, `lastActivity`,
  `resetsAt` and `system` are left out when unknown.
- `limits` is empty until the AI usage poll has run; Claude limits need the opt-in in Settings › AI.

## SketchyBar

Turn on Settings › General › **Notify SketchyBar when the status changes**. Flightdeck then runs
`sketchybar --trigger flightdeck_update` whenever the status file is rewritten.

In `sketchybarrc`:

```sh
sketchybar --add event flightdeck_update \
           --add item flightdeck right \
           --set flightdeck update_freq=30 script="$PLUGIN_DIR/flightdeck.sh" \
           --subscribe flightdeck flightdeck_update
```

`plugins/flightdeck.sh` (SketchyBar runs plugins with a short PATH, so use the full path):

```sh
#!/bin/sh
FLIGHTDECK="$HOME/.local/bin/flightdeck"

if ! STATUS=$("$FLIGHTDECK" status --format '{needsYou} {working}' 2>/dev/null); then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

NEEDS_YOU=${STATUS% *}
WORKING=${STATUS#* }
if [ "$NEEDS_YOU" -gt 0 ]; then COLOR=0xffff9f0a; else COLOR=0xffffffff; fi
sketchybar --set "$NAME" drawing=on icon=✈ label="$WORKING ▶ $NEEDS_YOU !" label.color="$COLOR"
```

## tmux

```tmux
set -g status-interval 5
set -g status-right '#(flightdeck status --format "▶ {working}  ! {needsYou}") | %H:%M'
```

When Flightdeck isn't running the command prints nothing, so the segment disappears.

## Raycast

A script command, e.g. `~/raycast/flightdeck.sh`, shown inline in the root search:

```sh
#!/bin/sh
# @raycast.schemaVersion 1
# @raycast.title Flightdeck
# @raycast.mode inline
# @raycast.refreshTime 10s
"$HOME/.local/bin/flightdeck" status 2>&1
```

## jq

```sh
flightdeck status --json | jq -r '.agents[] | select(.waitingSince) | "\(.project) (\(.branch // "-")): \(.state)"'
```
