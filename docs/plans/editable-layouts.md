# Plan: editable layouts

Every dashboard page except Settings can be unlocked. While unlocked, sections can be dragged, resized, hidden, re-added and moved to another page. Locking saves the result as a custom version of the current theme's layout, e.g. "Ignition (custom)".

## Decisions

| Topic | Choice |
|---|---|
| Edit model | Snap grid: 12 columns, widths of 3, 4, 6, 8 or 12 columns |
| Height | Natural height; only width is set |
| Saving | One custom version per layout, with Reset to original |
| Extras | Hide and re-add sections, move sections between pages, split big sections |

## Model

- **`DashboardPage`**: overview, ports, agents, processes, widgets. This is the existing `DashboardSection` enum, renamed so that "section" can mean a block on a page.
- **`SectionKind`**: every movable block, each with a title, a minimum width and a default page:
  - Overview: needs you, resources, your turn, working, idle, projects.
  - Servers & Ports: dev servers, other ports.
  - AI Agents: sessions, usage limits.
  - Processes: process table.
  - Widgets: one kind per custom widget, `widget(UUID)`.
- **`SectionPlacement`**: a kind plus its width in columns. **`PageLayout`**: an ordered list of placements. A kind that is not on any page is hidden.
- **`DashboardLayout.defaultPages`**: the original arrangement for each layout (Ignition today).
- **`AppSettings.customLayouts`**: `[DashboardLayout: [DashboardPage: PageLayout]]`, stored as JSON. When a custom version exists it is used; Reset deletes it.

## Rendering

- **`SectionGrid`**: a SwiftUI `Layout` that packs placements into rows of 12 columns. Each row is as tall as its tallest section. Below about 800pt of window width every section becomes full width.
- **Page shell**: every page becomes a `ScrollView` around a `SectionGrid`, drawn in the theme's style (Ignition: hairlines, no cards).
- **Processes table**: needs a scroll height, so it takes a minimum height of about 480pt and otherwise fills the window.
- **Resources sidebar**: stays a docked column outside the grid. "Send to sidebar" moves the resources section out of the grid and back.

## Edit mode

- **Lock button**: a lock button in each page's toolbar (`lock` / `lock.open`) toggles edit mode for the whole window.
- **Section chrome** while unlocked: a dashed outline, a drag handle, a resize handle on the trailing edge, and a hide button. Live updates keep running.
- **Drag**: `draggable(SectionKind)` and `dropDestination` insert a section before the one it is dropped on.
  - Dropping onto a page in the sidebar list moves the section to the end of that page.
- **Resize**: dragging the trailing edge snaps to the nearest allowed width.
- **"+ Add section" tray**: lists hidden sections from every page. Adding one puts it at the end of the current page.
- **Lock**: saves the custom version. The theme picker then shows "Ignition (custom)", with a "Reset to original" button.

## Build order (one commit each)

1. **Model and persistence**: the model types, default pages for Ignition, saving, and tests for row packing and save/load. The packing logic goes in a target that has tests.
2. **Overview into the grid**:
   - Split the agent board into Your turn, Working and Idle sections.
   - Move the hero, resources and projects into the grid.
   - Remove the old column grid in `AgentBoard`.
3. **Other pages into the grid**: Servers & Ports, AI Agents, Processes and Widgets. Widget tiles become sections, which replaces the Widgets page's own grid.
4. **Edit mode**: the lock button, section chrome, dragging within a page, resizing, hiding and the Add section tray.
5. **Cross-page moves**: drop onto the sidebar list; the tray shows sections from every page.
6. **Settings and checks**: the custom indicator and Reset in Appearance, screenshots of each page locked and unlocked, README and architecture notes.

## Risks

- **Ports and AI Agents pages change look**: they move from a macOS `List` to the theme's grid, so they will look different (closer to the Overview).
- **Drag inside a scroll view**: needs auto-scroll near the top and bottom edges on long pages.
- **Saved layouts with removed sections**: kinds that no longer exist (e.g. a deleted widget) must be dropped quietly when a layout loads.
