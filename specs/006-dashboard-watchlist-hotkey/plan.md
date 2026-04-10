# Implementation Plan: Dashboard Watchlist Hotkey

**Branch**: `006-dashboard-watchlist-hotkey` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-dashboard-watchlist-hotkey/spec.md`

## Summary

Add `w` keymap to the GitHub Dashboard popup: pressing `w` on a repo row toggles that repo's watchlist membership (add if absent, remove if present) via a call to `gh_watchlist.toggle_repo(full_name)`. Expose a new `M.toggle_repo(full_name)` function in `gh_watchlist.lua`. Update `render_repos` in `github_dashboard.lua` to store `full_name` in the item table so the keymap handler can extract it.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh_watchlist.lua` (existing module, `lua/alex/`), `github_dashboard.lua` (existing module, `lua/alex/`)  
**Storage**: `~/.config/nvim/gh-watchlist.json` — existing atomic JSON persistence (no schema change)  
**Testing**: Manual — open dashboard, press `w` on a repo, verify `gh-watchlist.json`  
**Target Platform**: Linux (WSL2), terminal Neovim  
**New files**: none  
**Modified files**: `lua/alex/gh_watchlist.lua`, `lua/alex/github_dashboard.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | ✅ Pass | Two targeted changes, no new files |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | No new try/except patterns |
| IV. Logical commits, push after each task | ✅ Pass | One commit for the feature |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Project Structure

```text
lua/alex/gh_watchlist.lua       ← expose M.toggle_repo(full_name)
lua/alex/github_dashboard.lua   ← store full_name in repo items; add w keymap
~/.config/nvim/gh-watchlist.json  ← runtime persistence (unchanged schema)
```

---

## Implementation

### Change 1: `lua/alex/gh_watchlist.lua` — expose `M.toggle_repo`

Add a new public function after `M.open_latest`:

```lua
M.toggle_repo = function(full_name)
  local owner, repo = full_name:match("^([^/]+)/([^/]+)$")
  if not owner or not repo then return end
  for i, e in ipairs(state.repos) do
    if e.owner == owner and e.repo == repo then
      table.remove(state.repos, i)
      save_watchlist()
      vim.notify("Removed " .. full_name .. " from watchlist", vim.log.levels.INFO)
      return
    end
  end
  table.insert(state.repos, { owner = owner, repo = repo, last_seen_id = "" })
  save_watchlist()
  vim.notify("Added " .. full_name .. " to watchlist", vim.log.levels.INFO)
end
```

### Change 2: `lua/alex/github_dashboard.lua` — store `full_name` + add `w` keymap

**In `render_repos`**: change item insertion from:
```lua
table.insert(items, { line = #lines, url = repo.url })
```
to:
```lua
table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name })
```

**In `open_win`**: add a new local helper and buffer keymap:
```lua
local function toggle_watch_at_cursor()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
  local cur_line = vim.api.nvim_win_get_cursor(state.win)[1] - 1  -- 0-indexed
  for _, item in ipairs(state.items) do
    if item.line == cur_line and item.full_name then
      require("alex.gh_watchlist").toggle_repo(item.full_name)
      return
    end
  end
end

-- inside open_win(), with the other buf_map calls:
buf_map("w", toggle_watch_at_cursor)
```

---

## Verification

1. `<leader>gh` → open dashboard
2. Move cursor to a repo row, press `w` → notification "Added owner/repo to watchlist"
3. `~/.config/nvim/gh-watchlist.json` updated
4. Press `w` again on same repo → notification "Removed owner/repo from watchlist"
5. `w` on a PR row or issue row → no effect, no error
6. `<leader>gw` → watchlist manager confirms the repo is listed

---

## Complexity Tracking

No violations.
