# UI Contract: GitHub Dashboard

**Branch**: `001-github-dashboard` | **Date**: 2026-04-09

This document defines the public interface for the `alex.github_dashboard` Neovim module.

---

## Module Interface

```lua
local M = require("alex.github_dashboard")

M.toggle()   -- Open if closed, close if open
M.setup()    -- Register keybindings and autocommands (called once from init.lua)
```

No other functions are part of the public interface.

---

## Keybindings (global, set by M.setup)

| Binding | Action |
|---------|--------|
| `<leader>gh` | Toggle dashboard open/closed |

---

## Keybindings (inside dashboard window)

| Binding | Action |
|---------|--------|
| `q` | Close dashboard |
| `<Esc>` | Close dashboard |
| `r` | Force refresh (invalidate cache, re-fetch all) |
| `<CR>` | Open item under cursor in browser |
| `o` | Open item under cursor in browser (alternate) |
| `j` / `k` | Move cursor down/up |

---

## Visual Layout Contract

The dashboard window MUST:
- Be a centered floating window covering ~90% of the editor width and height
- Have no line numbers, no sign column, no status line
- Show a title bar: `  GitHub Dashboard  ` with username appended
- Use visual separator lines (`────────...`) between sections
- Show a `[loading...]` indicator next to the title when fetching
- Show a `[stale]` indicator when displaying data older than 5 minutes

**Section order (fixed)**:

1. Profile bar (username, total contributions, stats)
2. Contribution heatmap (26 weeks, 7 rows, characters per tier)
3. Separator
4. Open Pull Requests (or `  No open pull requests`)
5. Separator
6. Assigned Issues (or `  No assigned issues`)
7. Separator
8. Recent Activity (last 10 events)

---

## Navigable Items

Items that can be opened with `<CR>` must be visually marked. Convention: items start with a bullet (`  ` or ` `) and the line is registered in `state.items` with a URL.

Cursor highlight on navigable items uses the existing `Visual` highlight group.

---

## Cache Contract

- Cache file: `~/.cache/nvim/gh-dashboard.json`
- Written atomically (write to `.tmp`, then rename)
- On decode error: log warning, treat as cache miss
- On fetch error: preserve existing cache, show error note in dashboard

---

## Error Display

Errors are shown inline within each section, not as popups:

```
  Pull Requests
  ✗ Failed to fetch (rate limited — retry in 32s)
```
