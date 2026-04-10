# Implementation Plan: Fix Watchlist Notifications

**Branch**: `007-fix-watchlist-notifs` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-fix-watchlist-notifs/spec.md`

## Summary

Three focused fixes to `lua/alex/gh_watchlist.lua` and `lua/alex/github_dashboard.lua`:
1. **Timezone bug** — `age_string` treats UTC timestamps as local time; fix with a UTC-offset correction
2. **Notification history** — add `state.history` so `<leader>gn` works after popups auto-dismiss
3. **History popup** — when no live popups exist but history does, show a browseable list

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `vim.uv.new_timer` (built-in), `nvim_open_win` (built-in)  
**Storage**: `state.history` — in-memory only, never persisted  
**Testing**: Manual — trigger real GitHub events, verify age labels and `<leader>gn` behavior  
**Target Platform**: Linux (WSL2), terminal Neovim  
**New files**: none  
**Modified files**: `lua/alex/github_dashboard.lua`, `lua/alex/gh_watchlist.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | ✅ Pass | No new files, targeted additions |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | No new try/catch patterns |
| IV. Logical commits, push after each task | ✅ Pass | One commit per phase |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Project Structure

```text
lua/alex/github_dashboard.lua   ← fix age_string UTC offset (one line)
lua/alex/gh_watchlist.lua       ← add state.history, fix open_latest, add history popup
```

---

## Phase A — Fix UTC Timestamp Bug

**Root cause**: `os.time({ year, month, day, hour, min, sec })` in Lua interprets fields as **local time**, returning the UTC epoch for that local moment. But GitHub's ISO 8601 timestamps are UTC. In UTC+2, a "just now" event (14:30 UTC) gets parsed as "14:30 local = 12:30 UTC epoch", while `os.time()` = 14:30 UTC — producing a `diff` of 2 hours.

**Fix**: Replace `os.time()` in the diff with `os.time(os.date("!*t"))`. Both sides now apply the same local-time mis-encoding to UTC, so the offset cancels perfectly:

```lua
-- Before (line ~65 in github_dashboard.lua):
local diff = os.time() - t

-- After:
local diff = os.time(os.date("!*t")) - t
```

`os.date("!*t")` returns the UTC components of the current moment. `os.time()` re-encodes them as local time — the same systematic offset applied to `t` — so `diff` is now the true elapsed seconds.

**Location**: `lua/alex/github_dashboard.lua` — `age_string()` line ~65. Single line change.

**Commit**: `fix: correct UTC timestamp parsing in age_string`

---

## Phase B — Notification History + Fix `open_latest`

**Root cause**: `show_notification` appends to `state.notifs`. The auto-dismiss timer removes the entry after 5s. `M.open_latest` reads `state.notifs[#state.notifs]` — empty after dismissal → "No recent notifications".

**Fix**: Add `state.history` — a capped list (newest-first, max 20 entries) that accumulates every received event and is never pruned by timers.

### State change (`lua/alex/gh_watchlist.lua`):

```lua
local MAX_HISTORY = 20

local state = {
  repos        = {},
  poll_timer   = nil,
  notifs       = {},
  history      = {},   -- NEW: { _repo, _ev } newest-first, max MAX_HISTORY
  manager_buf  = nil,
  manager_win  = nil,
}
```

### In `show_notification` — append to history after creating the notif entry:

```lua
table.insert(state.history, 1, { _repo = repo, _ev = ev })
if #state.history > MAX_HISTORY then table.remove(state.history) end
```

### Fix `M.open_latest` — fall back to history popup when no live popups:

```lua
M.open_latest = function()
  local last = state.notifs[#state.notifs]
  if last then
    if last.timer then last.timer:stop() last.timer:close() end
    if last.win and vim.api.nvim_win_is_valid(last.win) then
      pcall(vim.api.nvim_win_close, last.win, true)
    end
    table.remove(state.notifs)
    open_event(last._repo, last._ev)
    return
  end
  if #state.history == 0 then
    vim.notify("No recent notifications", vim.log.levels.INFO)
    return
  end
  open_history_popup()
end
```

**Commit**: `fix: add notification history — open_latest works after popup auto-dismisses`

---

## Phase C — History Popup (US3)

A manager-style floating popup listing `state.history` entries. Same visual pattern as `open_manager()` — `write_buf`, `GhWatch*` highlights, `cursorline`, footer with shortcuts.

### `open_history_popup()` — new local function in `lua/alex/gh_watchlist.lua`:

- Creates `nofile` buf, renders one row per history entry: `"   owner/repo  ·  event label"`
- `GhWatchRepo` on the repo portion, `GhWatchMeta` on the rest
- `nvim_open_win` — 70%×50% centered, `title = " Recent Notifications "`, `footer = " <CR> open  ·  q close "`
- `<CR>` keymap: close popup, call `open_event(entry._repo, entry._ev)` for the row at cursor
- `q` / `<Esc>`: close popup

**Commit**: `feat: notification history popup — browse recent events via <leader>gn`

---

## Verification

1. Trigger a real push/PR → notification appears; age shows correctly (not "2h ago")
2. Wait 5s for popup to auto-dismiss
3. Press `<leader>gn` → history popup opens listing the event
4. Press `<CR>` → GH reader opens (or browser for push)
5. Live popup visible → `<leader>gn` still does dismiss + open directly (unchanged path)
6. Restart Neovim → `<leader>gn` shows "No recent notifications" (history is ephemeral)
