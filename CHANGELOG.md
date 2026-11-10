# Changelog

Each release is a `## <version> — <date>` heading followed by `- ` bullets. The app shows the new entries
once after it updates, the site lists them, and the release workflow uses the entry as the release notes.

## 1.9.1 — 2026-11-10

- Hovering CPU, memory, disk or a limit opens a card right away, instead of a tooltip that rarely appeared.
- The music backgrounds are easier to see, and every style now follows the audio level as well as the beat, so Glow and the others move with live audio.

## 1.9.0 — 2026-11-10

- Hover CPU or memory to see which apps use the most, with helper processes counted under their app. Hover disk for each volume's free space.
- Hover a 5h or weekly limit to see when you'll hit it at the current pace, or that it lasts until reset.
- The Processes page opens with a collapsible "What's using what" breakdown; click an app to filter the list. The process list is restyled to match the rest of the app.
- An optional background that pulses to the music in your visualiser colours, with ten styles. Turn it on in Settings › Now playing or the adjust menu on Now playing.
- Five more visualiser styles: Mirror, Dot matrix, Line, Sunburst and Ribbons.

## 1.8.0 — 2026-11-10

- Agent cards show which step of its task list Claude is on ("Step 3 of 5"), with a bar per step and the full list on hover.
- The overview lists your dev servers between the agents and the projects.
- Context meter: each Claude session on the AI Agents page shows how full its context is, and turns orange when it will compact soon.
- Agents working in the same checkout get a warning on the AI Agents page, naming the files they both changed, with a shortcut to start the next agent in its own worktree.
- Worktrees show how much disk their build caches take (node_modules, .build, .venv, target and the like), and Clean up says how much it frees.

## 1.7.0 — 2026-11-09

- Office party: while music plays the office dims and turns into a rave in your visualiser colours, with a flashing dance floor, spotlights, lasers, a disco ball and a strobe on big beats. With "Visualiser follows the actual audio" on it follows the kick drum. Turn it off in Settings › Now playing; Reduce Motion turns off the strobe.
- Big speaker stacks stand either side of the jukebox, pumping on the beat, with a scrolling sign showing the track.
- Every agent in the office nods its head to the beat.
- Music controls live in the office: click the glowing pads in front of the jukebox to skip or pause, or stand by it and press Space, Q or E. The sign over the speakers shows the track and how far in it is.

## 1.6.0 — 2026-11-09

- Agent cards show what the agent changed since it started (files and lines added and removed), with a Diff button that opens the full diff.
- Agents that need you show their last message or the question they're asking, so you know what they want without switching.
- New agent: start Claude Code or Codex in a new or existing worktree, in Ghostty, iTerm2, Terminal or a tmux window.
- Worktrees show CI and review status for open pull requests, and you get an alert when CI fails on a branch an agent is working in. Pull requests from forks are left out.
- Limit forecast: see when a 5h or weekly limit runs out at the current pace, or that it lasts until reset.
- Keep awake: keep the Mac from sleeping while agents work, with a toggle on the overview and the AI Agents page. Off by default.
- Alerts can follow macOS Focus as well as your quiet hours.
- Servers: stopped dev servers stay listed for 10 minutes with Run again, port conflicts are flagged, and Restart reruns a server in a terminal tab and keeps its log. Stop alerts are opt-in.
- Today: a recap of agent time, time spent waiting on you and turns per project, with yesterday for comparison. An optional notification sums up the day before.
- A `flightdeck status` command and a status file for SketchyBar, tmux and Raycast. Install the command from Settings › General.
- The overview shows two Working and Idle cards and four projects, with See all for the rest.
- Background git checks no longer lock your repository while you or an agent commit.

## 1.5.0 — 2026-11-09

- Now playing: play, pause, skip and change the volume for Spotify and Music from the dashboard. Pick Minimal or Expanded, five visualiser styles and six palettes from its adjust menu. A badge shows whether the visualiser is animated or follows live audio.
- The System and Now playing sections can be collapsed.
- Office: agents that need you show as avatars that bounce until you look, and a jukebox shows what's playing.
- Sidebar icons line up in a fixed-width column.
- The README and site cover the new Now playing and Office, with fresh screenshots.

## 1.4.0 — 2026-11-06

- Office: a walkable pixel-art office where each project is a room and you can see what every agent is up to. Walk over to an agent to go to its terminal or stop it. Open it from Office in the sidebar or the Visualize button.
- Now playing: the dashboard shows what's playing and a visualiser in your theme's colours, in every layout. Turn it off in Settings, or opt in to real audio levels.
- The README and site describe everything new, with fresh screenshots.

## 1.3.0 — 2026-11-06

- Go to terminal and Stop on agent cards. Go to terminal focuses the agent's own Ghostty, iTerm2, Terminal or tmux tab.
- Press ⌃⌥N anywhere to jump to the next agent that needs you. Change the shortcut in Settings › General.
- Agents that look stuck get a badge with the reason and count as needing you.
- Agent cards can show CPU and memory for the agent and everything it started.
- A Worktrees page lists your worktrees with changes, ahead/behind, PR and agent, and cleans up stale ones.
- Quiet hours, and pausing alerts from the menu bar bell. Alerts held back arrive as one summary afterwards.
- Optional token and spend tracking per project and model, with a daily budget alert. Turn it on in Settings › AI.

## 1.2.0 — 2026-11-06

- Settings is now a page in the dashboard instead of a separate window.
- Built-in themes can't be edited anymore. Copy one to make your own theme, which you can rename, duplicate and delete. Colours you changed in 1.1 become a custom theme.
- Colour swatches in the theme editor line up in a column.
- Agents no longer show as needing you while Claude is still thinking after a long prompt.

## 1.1.1 — 2026-11-05

- Ring labels have more room, so reset times are no longer cut off.

## 1.1.0 — 2026-11-05

- 13 dashboard layouts, each with its own look and default theme. Any of the 22 themes works on any layout, and you can set your own colours.
- The default layout shows CPU, memory and your agent's 5h and week limits as rings that resize to fit.
- Limits follow your default agent and fall back to Claude Code, then Codex. Add Claude Code and Codex limits side by side from Customize.
- Notifications when an agent needs you, with a bell in the menu bar panel to turn them off and settings for what alerts you.
- The AI Agents page groups agents into Needs you, Working and Idle, and the overview keeps Needs you to one row.
- Claude limits stay on screen when Anthropic rate-limits the request, and are checked every 5 minutes instead of every minute.
- The menu bar hides counts that are zero.
- See what's new after each update.

## 1.0.8 — 2026-11-04

- "Your turn" is now called "Needs you" everywhere.
- Claude no longer shows as needing you while it writes text before running a tool.

## 1.0.7 — 2026-11-04

- The menu bar panel lists each agent once.

## 1.0.6 — 2026-11-04

- Searching on the overview makes it clear the dashboard is filtered.

## 1.0.5 — 2026-11-04

- The menu bar, panel and overview count agents that need you the same way.

## 1.0.4 — 2026-11-04

- The overview headline says how many other agents need you.
- Open the Ask Claude palette from anywhere with ⌘K.
- Tidier buttons on the Needs you cards.

## 1.0.3 — 2026-11-04

- Ask Claude about your dashboard from the search bar; answers open in a command palette.
- The sidebar logo is now the jet formation.

## 1.0.2 — 2026-11-04

- In-app updates.
- A compact bars style for the menu bar label.

## 1.0.1 — 2026-11-04

- A new three-jet formation app icon.
- The menu bar shows working agents and a dot when an agent needs you.
- The menu bar panel leads with CPU, memory and who needs you.
- A big clock section on the overview.
- The dashboard opens on launch and when you reopen the app.

## 1.0.0 — 2026-11-04

- First release: AI agents, dev servers, processes and system resources in the menu bar and a dashboard.
- Editable dashboard pages: move, resize and hide sections, and move them between pages.
