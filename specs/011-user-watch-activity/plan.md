# Implementation Plan: User Watch Activity Feed

**Branch**: `011-user-watch-activity` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/011-user-watch-activity/spec.md`

## Summary

Add a "Watched Users" section to the GitHub Dashboard showing recent events from a manually curated list of GitHub usernames. A new standalone module (`gh_user_watchlist.lua`) handles persistence and the manager popup. The dashboard gains `fetch_watched_users_activity` + `render_watched_users` wired into the existing async fetch pipeline. A new `<leader>gu` keymap opens the manager.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI v2.45.0, `gh_reader.lua` (existing), `vim.system()` (built-in async), `vim.uv.fs_rename` (built-in atomic writes)  
**Storage**: `~/.config/nvim/gh-user-watchlist.json` — atomic JSON read/write (same pattern as `gh-watchlist.json`)  
**Testing**: Manual smoke test  
**Target Platform**: Linux (WSL2), Neovim terminal  
**Project Type**: Neovim plugin (Lua modules)  
**Performance Goals**: Section appears within the same async cycle as other secondary sections  
**Constraints**: Max 10 events total across all watched users; section absent when list is empty  
**Scale/Scope**: Typically 1–10 watched users

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| No unnecessary code | ✅ Pass | New module mirrors existing `gh_watchlist.lua` pattern; no speculative abstractions |
| Functions ≤ 80 lines | ✅ Pass | Each function is self-contained and short |
| Max 4 levels indentation | ✅ Pass | Fan-out pattern matches existing code |
| No speculative abstractions | ✅ Pass | `fetch_watched_users_activity` is separate from `fetch_team_activity` (different endpoints, different data source — only 2 similar callers, below threshold) |
| Logical commits + push | ✅ Required | One commit per completed task |

## Project Structure

### Documentation (this feature)

```text
specs/011-user-watch-activity/
├── plan.md          ← this file
├── research.md      ← Phase 0 output
├── data-model.md    ← Phase 1 output
└── tasks.md         ← Phase 2 output (from /speckit.tasks)
```

### Source Code

```text
lua/alex/gh_user_watchlist.lua   ← NEW: persistence + manager popup module
lua/alex/github_dashboard.lua    ← MODIFY: add fetch + render + wire-up
lua/alex/init.lua                ← MODIFY: call gh_user_watchlist.setup()
lua/alex/remap.lua               ← MODIFY: add <leader>gu keymap
gh-user-watchlist.json           ← created at runtime in ~/.config/nvim/
```

## Implementation Details

### 1. `lua/alex/gh_user_watchlist.lua` (new file)

```lua
local WATCHLIST_PATH = vim.fn.expand("~/.config/nvim/gh-user-watchlist.json")
local state = { users = {}, manager_buf = nil, manager_win = nil }

-- load/save: same atomic JSON pattern as gh_watchlist.lua
-- storage format: { "users": ["username1", "username2"] }

-- render_manager(): renders list in manager window
-- open_add_input(): input popup, validates non-empty + no "/" (bare username)
-- remove_at_cursor(): deletes selected username from state.users
-- open_manager() / close_manager(): centered floating window
--   title = " Watched Users "
--   footer = " a add  ·  d remove  ·  q close "
--   keymaps: a=add, d/x=remove, q/<Esc>=close

M.get_users = function() return state.users end
M.toggle = function() ... end  -- open/close manager
M.setup = function() ... end   -- load from disk, setup highlights
```

### 2. `lua/alex/github_dashboard.lua` additions

**`fetch_watched_users_activity(callback)`** — added after `fetch_team_activity`:
```
1. local users = require("alex.gh_user_watchlist").get_users()
2. if empty → callback(nil, nil) [silently absent]
3. fan out: gh api /users/{username}/events --jq "[...] | .[0:20]" per user
4. collect events; track last_err for any per-user failure
5. sort by created_at desc, take top 10
6. if #top == 0 and last_err → callback(last_err, nil) [shows error]
7. else → callback(nil, top)
```

**`render_watched_users(lines, hl_specs, items, events, err)`** — after `render_team_activity`:
- Guard: `if not err and events == nil then return end` (nil = empty list → absent)
- Header: `"  Watched Users"` with `GhSection` highlight
- Error row: `"  ✗ ..."` with `GhError`
- Empty row (events == `{}`): `"   No recent activity from watched users"` with `GhEmpty`
- Event rows: same format as `render_team_activity` — actor, icon, repo, age
- Item routing: same as `render_team_activity` (PR → reader, issue → reader, other → browser)

**`apply_render`**: add `render_watched_users(lines, hl_specs, items, data.watched_events, data.watched_events_err)` after `render_team_activity`

**`start_secondary_fetches`**: bump pending by 1 more, add `fetch_watched_users_activity` call

### 3. `lua/alex/init.lua`

Add `require("alex.gh_user_watchlist").setup()` alongside the existing `require("alex.gh_watchlist").setup()`.

### 4. `lua/alex/remap.lua`

Add:
```lua
vim.keymap.set("n", "<leader>gu", function() require("alex.gh_user_watchlist").toggle() end, { desc = "Toggle GitHub User Watchlist" })
```

## Complexity Tracking

No constitution violations.
