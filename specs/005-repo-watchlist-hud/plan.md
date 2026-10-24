# Implementation Plan: Repo Watchlist with Activity HUD

**Branch**: `005-repo-watchlist-hud` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-repo-watchlist-hud/spec.md`

## Summary

New module `lua/alex/gh_watchlist.lua`. Polls watched GitHub repos every 60s using `vim.uv.new_timer()`. Shows floating corner notifications for new events. Persists watchlist to `~/.config/nvim/gh-watchlist.json`. Provides a manager popup (add/remove repos) accessible via `<leader>gw`. Jump-to-activity via `<leader>gn`.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev
**Primary Dependencies**: `vim.uv.new_timer` (built-in), `vim.system()` (built-in), `gh` CLI v2.45.0, `nvim_open_win` (built-in)
**Storage**: `~/.config/nvim/gh-watchlist.json` — atomic JSON read/write (same pattern as dashboard cache)
**Testing**: Manual — add a repo, trigger a real GitHub event, verify notification appears within 2 poll cycles
**Target Platform**: Linux (WSL2), terminal Neovim
**New files**: `lua/alex/gh_watchlist.lua`
**Modified files**: `lua/alex/init.lua`, `lua/alex/remap.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | ✅ Pass | New module, reuses existing patterns |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | Poll errors fail silently (no spam), not swallowed silently — just throttled |
| IV. Logical commits, push after each task | ✅ Pass | One commit per phase |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Project Structure

```text
lua/alex/gh_watchlist.lua    ← new module (all feature logic)
lua/alex/init.lua            ← add require("alex.gh_watchlist").setup()
lua/alex/remap.lua           ← add <leader>gw and <leader>gn keymaps
~/.config/nvim/gh-watchlist.json  ← runtime persistence (not committed)
```

---

## Phase A — Core State + Persistence

**Goal**: Skeleton module with load/save. No UI, no polling — just the data layer working end-to-end.

### Storage pattern (identical to dashboard cache):

```lua
local WATCHLIST_PATH = vim.fn.expand("~/.config/nvim/gh-watchlist.json")

local function load_watchlist()
  if vim.fn.filereadable(WATCHLIST_PATH) == 0 then return end
  local lines = vim.fn.readfile(WATCHLIST_PATH)
  if not lines or #lines == 0 then return end
  local ok, data = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if ok and type(data) == "table" and type(data.repos) == "table" then
    state.repos = data.repos
  end
end

local function save_watchlist()
  local tmp = WATCHLIST_PATH .. ".tmp"
  vim.fn.writefile({ vim.fn.json_encode({ repos = state.repos }) }, tmp)
  vim.uv.fs_rename(tmp, WATCHLIST_PATH, function() end)
end
```

**JSON schema** (per repo entry):
```json
{ "owner": "alice", "repo": "myproject", "last_seen_id": "37891234567" }
```

**Commit**: `feat: gh-watchlist — module skeleton, watchlist load/save`

---

## Phase B — Background Polling + Notification HUD

**Goal**: Timer polls watched repos every 60s. New events → floating corner notification (top-right, auto-dismissed after 5s). Up to 3 stacked notifications.

### Poll loop:

- `gh api repos/{owner}/{repo}/events --jq '[.[] | {id,type,created_at,payload}] | .[0:10]'`
- Iterate events newest-first; stop when `ev.id == entry.last_seen_id`
- All new events → `show_notification()`; update `last_seen_id` to `events[1].id`; call `save_watchlist()`

### Notification window spec:

- Size: `width=54`, `height=3`, top-right: `row=1 + slot*4`, `col=ui.width-56`
- `focusable=false`, `zindex=50`, `border="rounded"`
- Line 1: `"  ⊙ owner/repo  ·  push"` (highlighted: repo in `GhWatchRepo`, bullet in `GhWatchNotif`)
- Cap at 3 simultaneous notifications; evict oldest if exceeded
- Auto-dismiss: `vim.uv.new_timer()` fires after 5000ms → `nvim_win_close`
- Each notification buffer stores `_gh_notif_ev` and `_gh_notif_repo` for US3 jump

### Event label map:

| API type | Label |
|----------|-------|
| `PushEvent` | `push` |
| `PullRequestEvent` | `PR #N opened/merged/closed` |
| `IssuesEvent` | `issue #N opened/closed` |
| `IssueCommentEvent` | `comment on #N` |
| `PullRequestReviewEvent` | `review on PR #N` |
| other | `activity` |

### Timer start in `M.setup()`:

```lua
state.poll_timer = vim.uv.new_timer()
state.poll_timer:start(5000, 60000, vim.schedule_wrap(poll))
```

5s initial delay avoids a poll before Neovim finishes loading.

**Commit**: `feat: gh-watchlist — background polling + corner notification HUD`

---

## Phase C — Watchlist Manager UI

**Goal**: `<leader>gw` opens a floating popup listing watched repos. `a` adds, `d` removes, `q` closes.

### Layout:

```
╭─── Watched Repos ─────────────────────────────╮
│                                                │
│   alice/myproject                              │
│   bob/tool                                     │
│                                                │
╰────────────────────────────────────────────────╯
```

- Footer: `a add  ·  d remove  ·  q close`
- Same `lines`/`hl_specs`/`write_buf` pattern used in dashboard and reader
- `a` → inline floating input popup (same `nvim_open_win` pattern as `gh_reader.M.open_input`) asking for `owner/repo`; validates format; appends to `state.repos`; saves; re-renders
- `d` → removes repo at cursor line from `state.repos`; saves; re-renders
- `GhSelected` highlight on cursor line for visual selection
- 70%×50% centered popup, `filetype="text"`, `cursorline=true`

**Commit**: `feat: gh-watchlist — manager popup (add/remove repos)`

---

## Phase D — Jump to Activity + Wire-up

**Goal**: `<leader>gn` opens the most recent notification's item in the GH reader (or browser for pushes). Register module in `init.lua` and keymaps in `remap.lua`.

### `M.open_latest()`:

Since notifications are `focusable=false`, the jump action is a global keymap rather than an in-window keypress:

```lua
M.open_latest = function()
  local last = state.notifs[#state.notifs]
  if not last then vim.notify("No recent notifications", vim.log.levels.INFO) return end
  -- dismiss
  if last.timer then last.timer:stop() last.timer:close() end
  pcall(vim.api.nvim_win_close, last.win, true)
  table.remove(state.notifs)
  -- open
  open_event(last._repo, last._ev)
end
```

`open_event(repo, ev)` extracts item from payload:
- `PullRequestEvent` → `gh_reader.open({ kind="pr", number=N, repo=repo })`
- `IssuesEvent`/`IssueCommentEvent` → `gh_reader.open({ kind="issue", ... })`
- `PushEvent` → `vim.system({ "xdg-open", "https://github.com/" .. repo })`

Store `_repo` and `_ev` directly on the notif table entry (not on buf vars, since buf may be wiped).

### `lua/alex/init.lua` addition:

```lua
require("alex.gh_watchlist").setup()
```

### `lua/alex/remap.lua` additions:

```lua
vim.keymap.set("n", "<leader>gw", function() require("alex.gh_watchlist").toggle() end, { desc = "Toggle GitHub Watchlist" })
vim.keymap.set("n", "<leader>gn", function() require("alex.gh_watchlist").open_latest() end, { desc = "Open latest GitHub notification" })
```

**Commit**: `feat: gh-watchlist — jump-to-activity, wire up init + remap`

---

## Highlights

```lua
GhWatchTitle  = { fg = "#7fc8f8", bold = true }
GhWatchRepo   = { fg = "#abb2bf" }
GhWatchNotif  = { fg = "#e5c07b" }    -- ⊙ bullet
GhWatchEmpty  = { fg = "#4b5263", italic = true }
GhWatchSep    = { fg = "#3b4048" }
```

---

## Verification

1. `<leader>gw` → manager popup opens (empty), footer shows shortcuts
2. Press `a`, type `owner/repo`, confirm → repo in list; `~/.config/nvim/gh-watchlist.json` written
3. Restart Neovim → `<leader>gw` shows same repo (persistence confirmed)
4. Trigger a real event on the watched repo → within 60s notification appears top-right
5. Notification auto-dismisses after ~5s
6. While notification is visible, press `<leader>gn` → GH reader opens for that PR/issue
7. `d` on a repo in manager → removed from list and from file
