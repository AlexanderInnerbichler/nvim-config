# Tasks: User Watch Activity Feed

**Input**: Design documents from `specs/011-user-watch-activity/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

**Organization**: Tasks span 4 files. Grouped by user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

- [X] T001 Read `lua/alex/gh_watchlist.lua` (lines 1–120, 280–411) to confirm exact signatures for `load_watchlist`, `save_watchlist`, `open_manager`, `open_add_input`, `remove_at_cursor` and the atomic write pattern before writing any new code

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T002 Create `lua/alex/gh_user_watchlist.lua` with module scaffold: `local M = {}`, `WATCHLIST_PATH = vim.fn.expand("~/.config/nvim/gh-user-watchlist.json")`, `state = { users = {}, manager_buf = nil, manager_win = nil }`, highlight setup (`GhUserWatch*` namespace), `load_watchlist` (reads `{ "users": [...] }`, populates `state.users`), `save_watchlist` (atomic write: `{ "users": state.users }`), and `M.get_users = function() return state.users end`

- [X] T003 Add `require("alex.gh_user_watchlist").setup()` to `lua/alex/init.lua` on a new line after `require("alex.gh_watchlist").setup()` (line 8)

**Checkpoint**: Module loads without error — `require("alex.gh_user_watchlist").get_users()` returns `{}`.

---

## Phase 3: User Story 1 — View watched users' activity in the dashboard (Priority: P1) 🎯 MVP

**Goal**: "Watched Users" section appears in the dashboard showing recent events from all usernames in the watch list.

**Independent Test**: Edit `~/.config/nvim/gh-user-watchlist.json` to `{"users":["torvalds"]}` → open dashboard → "Watched Users" section shows recent events from that user with actor, icon, repo, and age.

### Implementation for User Story 1

- [X] T004 [US1] Add `fetch_watched_users_activity(callback)` to `lua/alex/github_dashboard.lua` after `fetch_team_activity` (line ~378): call `require("alex.gh_user_watchlist").get_users()`; if empty → `callback(nil, nil)` and return; for each username call `gh api /users/{username}/events --jq "[.[] | {type, actor: .actor.login, repo: .repo.name, created_at, pr_number: .payload.pull_request.number, issue_number: .payload.issue.number}] | .[0:20]"`; collect events, track `last_err`; when all done sort by `created_at` desc, take top 10; if `#top == 0 and last_err` then `callback(last_err, nil)` else `callback(nil, top)`

- [X] T005 [US1] Add `render_watched_users(lines, hl_specs, items, events, err)` to `lua/alex/github_dashboard.lua` after `render_team_activity` (line ~661): guard `if not err and events == nil then return end`; header `"  Watched Users"` with `GhSection`; on error show `"  ✗ ..."` with `GhError`; if `#events == 0` show `"   No recent activity from watched users"` with `GhEmpty`; else render event rows with same format as `render_team_activity`: `string.format("   %-18s  %s  %-30s  %s", actor:sub(1,18), icon, repo:sub(1,30), age)` with icon and meta highlights; insert items (PR→kind="pr", issue→kind="issue", other→kind="push"+url); add separator at end

- [X] T006 [US1] Wire `render_watched_users` into `apply_render` in `lua/alex/github_dashboard.lua`: add `render_watched_users(lines, hl_specs, items, data.watched_events, data.watched_events_err)` after the `render_team_activity(...)` call (line ~684)

- [X] T007 [US1] Wire `fetch_watched_users_activity` into `start_secondary_fetches` in `lua/alex/github_dashboard.lua`: bump `pending = pending + 6` (was 5); add after `fetch_team_activity` block: `fetch_watched_users_activity(function(err, events) if err then state.data.watched_events_err = err else state.data.watched_events = events end; done(err ~= nil) end)`

**Checkpoint**: Edit watch list file with a known username → open dashboard → "Watched Users" section shows that user's recent events. Empty list → section absent.

---

## Phase 4: User Story 2 — Manage the watched users list (Priority: P2)

**Goal**: `<leader>gu` opens a manager popup to add/remove GitHub usernames. Changes persist across restarts.

**Independent Test**: Press `<leader>gu` → manager popup opens with "Watched Users" title → press `a` → input popup → type `torvalds` → `<C-s>` → username appears in manager → press `q` → re-open dashboard → "Watched Users" shows torvalds's events → re-open manager → `d` on torvalds → removed from list.

### Implementation for User Story 2

- [X] T008 [US2] Add `render_manager()`, `close_manager()`, `open_add_input()`, `remove_at_cursor()`, and `open_manager()` to `lua/alex/gh_user_watchlist.lua`, modeled exactly on `gh_watchlist.lua`'s equivalents (lines 341–411): `render_manager` renders `state.users` (one username per line, GhSection header); `open_add_input` opens a floating input with title `" Add GitHub username "`, validates non-empty and no `/` character, deduplicates, inserts into `state.users`, calls `save_watchlist` and `render_manager`; `remove_at_cursor` removes the username at cursor position and calls `save_watchlist`; `open_manager` opens a centered floating window (70% width, 50% height) with title `" Watched Users "`, footer `" a add  ·  d remove  ·  q close "`, keymaps `a`=add, `d`/`x`=remove, `q`/`<Esc>`=close; add `M.toggle` and complete `M.setup` (calls `setup_highlights`, mkdir, `load_watchlist`)

- [X] T009 [P] [US2] Add `<leader>gu` keymap to `lua/alex/remap.lua` after the `<leader>gn` line (line 60): `vim.keymap.set("n", "<leader>gu", function() require("alex.gh_user_watchlist").toggle() end, { desc = "Toggle GitHub User Watchlist" })`

**Checkpoint**: `<leader>gu` opens manager. `a` adds a username. `d` removes it. File `~/.config/nvim/gh-user-watchlist.json` reflects changes after each action. Dashboard updates on next open.

---

## Phase 5: User Story 3 — Open a watched user's event in the reader (Priority: P3)

**Goal**: `<CR>` on a PR/issue row opens the inline reader; `<CR>` on push/fork/star opens the browser.

**Independent Test**: Cursor on PullRequestEvent row in "Watched Users" → `<CR>` → reader opens with correct PR content and breadcrumb. Cursor on PushEvent row → `<CR>` → browser opens to repo URL.

### Implementation for User Story 3

*US3 is already implemented as part of T005 — `render_watched_users` inserts items with correct `kind` routing (PR→"pr", issue→"issue", other→"push"+url), and `open_url_at_cursor` in the dashboard handles routing without any changes. No additional tasks needed.*

**Checkpoint**: `<CR>` routing verified during smoke test in T010.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T010 Smoke test: verify "Watched Users" section appears with a real username, `<CR>` on PR/issue opens reader, `<CR>` on push opens browser, empty list → section absent, manager popup add/remove works, file persists across restart; commit and push `feat: add Watched Users activity feed with manager popup`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 read; T002 and T003 are sequential (T002 creates the module, T003 registers it)
- **US1 (Phase 3)**: Depends on T002 (T004 calls `get_users()`); T004 → T005 → T006 → T007 sequential (same file)
- **US2 (Phase 4)**: T008 depends on T002 scaffold; T009 [P] can run in parallel with T008 (different file)
- **US3 (Phase 5)**: No additional work — implemented in T005
- **Polish (Phase 6)**: Depends on all prior phases

### Within Each User Story

- T004 before T005 (render needs fetch's data shape)
- T005 before T006, T007 (wire-up needs function to exist)
- T008 and T009 can run in parallel (different files)

### Parallel Opportunities

- **T009 [P]**: `remap.lua` change is independent of `gh_user_watchlist.lua` work in T008 — can be done simultaneously

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001: Read existing patterns
2. T002–T003: Create module scaffold + register in init.lua
3. T004–T007: Fetch + render + wire-up in dashboard
4. **VALIDATE**: Edit JSON file manually, open dashboard, confirm section
5. Add US2 (T008–T009) for management UI

### Incremental Delivery

1. T001–T003 → Foundation: module exists, loads cleanly
2. T004–T007 → US1 complete: section visible in dashboard (manual JSON editing)
3. T008–T009 → US2 complete: full management UI via `<leader>gu`
4. T010 → Smoke test + commit

---

## Notes

- T009 is the only [P] task — `remap.lua` is independent of `gh_user_watchlist.lua`
- US3 requires zero additional code — item routing is implemented inside `render_watched_users` (T005)
- `pending` counter: was 5, becomes 6 after T007 (one more async fetch added)
- `open_url_at_cursor` in `github_dashboard.lua` requires no changes — already handles all item kinds
- Commit and push after T007 (US1 done) and again after T010 (full feature)
