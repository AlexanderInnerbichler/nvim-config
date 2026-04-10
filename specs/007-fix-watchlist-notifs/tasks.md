# Tasks: Fix Watchlist Notifications

**Input**: Design documents from `/specs/007-fix-watchlist-notifs/`
**Prerequisites**: plan.md ✓, spec.md ✓

**New files**: none  
**Modified files**: `lua/alex/github_dashboard.lua`, `lua/alex/gh_watchlist.lua`

---

## Phase 2: User Story 1 — Fix timestamp display (Priority: P1) 🎯 MVP

**Goal**: All age labels show the correct elapsed time regardless of the user's local timezone.

**Independent Test**: Trigger a real GitHub event. Within one poll cycle, the notification label and dashboard activity feed show "0m ago" or "1m ago" — not "2h ago".

- [X] T001 [US1] Fix `age_string` in `lua/alex/github_dashboard.lua` — change `local diff = os.time() - t` (line ~65) to `local diff = os.time(os.date("!*t")) - t`; `os.date("!*t")` returns UTC components of now, `os.time()` re-encodes them as local — same offset as `t` — so the UTC drift cancels

**Checkpoint**: Dashboard PR/issue/activity ages and notification HUD ages are now correct.

---

## Phase 3: User Story 2 — Jump to recent event after auto-dismiss (Priority: P2)

**Goal**: `<leader>gn` opens the most recent event even after its popup auto-dismissed.

**Independent Test**: Trigger a real event, wait for the notification popup to disappear (5s), then press `<leader>gn` — the history popup opens or the event opens directly. "No recent notifications" no longer appears for events that already showed.

- [X] T002 [US2] Add `MAX_HISTORY = 20` constant and `history = {}` field to `state` table in `lua/alex/gh_watchlist.lua` — place `MAX_HISTORY` with the other constants at the top; add `history = {}` to `state` alongside `notifs`
- [X] T003 [US2] Insert into history inside `show_notification(repo, ev)` in `lua/alex/gh_watchlist.lua` — after `table.insert(state.notifs, ...)`, add: `table.insert(state.history, 1, { _repo = repo, _ev = ev })` then `if #state.history > MAX_HISTORY then table.remove(state.history) end`
- [X] T004 [US2] Rewrite `M.open_latest` in `lua/alex/gh_watchlist.lua` to fall back to history: if `state.notifs` is non-empty → existing dismiss+open behavior; else if `state.history` is empty → `vim.notify("No recent notifications")`; else → call `open_history_popup()`

**Checkpoint**: After a popup auto-dismisses, `<leader>gn` opens the history popup (or the event directly).

---

## Phase 4: User Story 3 — History popup (Priority: P3)

**Goal**: A browseable floating popup lists recent events; `<CR>` opens the selected event.

**Independent Test**: After all popups have dismissed, press `<leader>gn` — a "Recent Notifications" popup appears listing repo · event-type rows. Press `<CR>` on a row → GH reader opens. Press `q` → popup closes.

- [X] T005 [US3] Implement `open_history_popup()` local function in `lua/alex/gh_watchlist.lua` (place before `M.open_latest`):
  - Create `nofile` buf (`bufhidden=wipe`, `filetype=text`)
  - Render rows: leading `""`, then for each `state.history` entry one line `"   owner/repo  ·  label"` with `GhWatchRepo` on the repo portion and `GhWatchMeta` on the rest, trailing `""`; use `write_buf`
  - `nvim_open_win` 70%×50% centered, `border="rounded"`, `title=" Recent Notifications "`, `footer=" <CR> open  ·  q close "`, `cursorline=true`
  - `<CR>` keymap: compute `idx = cursor_line - 1` (offset for leading blank), guard bounds, close win, call `open_event(state.history[idx]._repo, state.history[idx]._ev)`
  - `q` / `<Esc>` keymap: close win

**Checkpoint**: Full flow works: event → auto-dismiss → `<leader>gn` → history popup → `<CR>` → reader/browser.

---

## Dependencies & Execution Order

- **T001** (US1) is independent — different file from T002–T005, can be done in parallel
- **T002** must precede T003 and T004 (establishes the `history` field)
- **T003** must precede T004 (history must be populated before `open_latest` uses it)
- **T004** must precede T005 (calls `open_history_popup` which doesn't exist yet)
- **T005** completes the chain

### Parallel Opportunities

- T001 and T002 can start simultaneously (different files)
- T003, T004, T005 are sequential (same file, each depends on the prior)

---

## Implementation Strategy

### MVP (T001 + T002 + T003 + T004)

Fixes both reported bugs — timestamps correct, `<leader>gn` works after dismiss. T005 (history popup) is the nice-to-have P3 and can be skipped for a quick MVP.

---

## Notes

- `os.date("!*t")` — the `!` prefix means "return UTC components"; no second arg = use current time
- The history list is newest-first (`table.insert(state.history, 1, entry)`) so `state.history[1]` is always the most recent event
- `open_history_popup` uses the same `write_buf` and `GhWatch*` highlights already in scope
- **Commit after each phase** (Constitution IV)
