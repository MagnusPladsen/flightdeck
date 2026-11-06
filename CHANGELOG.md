# Changelog

Each release is a `## <version> — <date>` heading followed by `- ` bullets. The app shows the new entries
once after it updates, the site lists them, and the release workflow uses the entry as the release notes.

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
