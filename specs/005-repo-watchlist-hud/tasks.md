# Tasks: Repo Watchlist with Activity HUD

**Input**: Design documents from `/specs/005-repo-watchlist-hud/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓

**New file**: `lua/alex/gh_watchlist.lua`
**Modified files**: `lua/alex/init.lua`, `lua/alex/remap.lua`

---

## Phase 1: Setup

- [X] T001 Create empty `lua/alex/gh_watchlist.lua` with `local M = {}` skeleton, `state` table (`repos`, `poll_timer`, `notifs`), `M.setup`, `M.toggle`, `M.open_latest`, `return M`

---

## Phase 2: Foundational — Storage + Highlights

These are shared by all user stories and must be complete before any phase can be tested.

- [X] T002 Implement `load_watchlist()` in `lua/alex/gh_watchlist.lua` — reads `~/.config/nvim/gh-watchlist.json` using `vim.fn.readfile` + `vim.fn.json_decode`, populates `state.repos`; no-op if file missing
- [X] T003 Implement `save_watchlist()` in `lua/alex/gh_watchlist.lua` — atomic write via `.tmp` + `vim.uv.fs_rename` (same pattern as `github_dashboard.lua:write_cache`)
- [X] T004 Add `setup_highlights()` in `lua/alex/gh_watchlist.lua` with groups: `GhWatchTitle` (fg=#7fc8f8 bold), `GhWatchRepo` (fg=#abb2bf), `GhWatchNotif` (fg=#e5c07b), `GhWatchEmpty` (fg=#4b5263 italic), `GhWatchSep` (fg=#3b4048)
- [X] T005 Implement `M.setup()` in `lua/alex/gh_watchlist.lua`: call `setup_highlights()`, `vim.fn.mkdir` for config dir, `load_watchlist()`, register `ColorScheme` autocmd; leave timer start as a stub `-- TODO: Phase B`

**Checkpoint**: `:lua require("alex.gh_watchlist").setup()` runs without error; `state.repos` reflects file contents if present.

---

## Phase 3: User Story 1 — Manage the Watchlist (Priority: P1) 🎯 MVP

**Goal**: User can open a manager popup, add a repo by `owner/repo`, remove one, and have the list survive a Neovim restart.

**Independent Test**: `:lua require("alex.gh_watchlist").toggle()` → popup opens; press `a`, enter `owner/repo` → appears in list; restart Neovim → still there; press `d` → gone.

### Implementation

- [X] T006 [US1] Implement `write_buf(lines, hl_specs)` local helper in `lua/alex/gh_watchlist.lua` (same pattern as `gh_reader.lua:write_buf` — set modifiable, buf_set_lines, clear_namespace, add_highlight, unset modifiable)
- [X] T007 [US1] Implement `render_manager()` in `lua/alex/gh_watchlist.lua` — builds `lines`/`hl_specs` from `state.repos`; shows "No repos watched" (`GhWatchEmpty`) when empty; each repo on its own line with `GhWatchRepo` highlight; calls `write_buf`
- [X] T008 [US1] Implement `open_manager()` in `lua/alex/gh_watchlist.lua` — creates buf (`buftype=nofile`, `bufhidden=wipe`, `filetype=text`), calls `nvim_open_win` (70% width × 50% height, centered, `border="rounded"`, title `" Watched Repos "`, footer `" a add  ·  d remove  ·  q close "`, `cursorline=true`); calls `render_manager()`
- [X] T009 [US1] Implement `close_manager()` in `lua/alex/gh_watchlist.lua` — closes `state.manager_win` if valid
- [X] T010 [US1] Implement `open_add_input()` in `lua/alex/gh_watchlist.lua` — floating input popup (same `nvim_open_win` pattern as `gh_reader.lua:M.open_input`: 60% width × 8 lines, title `" Add repo (owner/repo) "`, footer `" <leader>s confirm  ·  <Esc><Esc> cancel "`); on submit validates format `owner/repo`, inserts into `state.repos` with `last_seen_id=""`, calls `save_watchlist()` + `render_manager()`
- [X] T011 [US1] Register keymaps in `open_manager()` in `lua/alex/gh_watchlist.lua`: `a` → `open_add_input()`, `d`/`x` → remove repo at cursor (calculate index from cursor line), `q`/`<Esc>` → `close_manager()`
- [X] T012 [US1] Implement `M.toggle()` in `lua/alex/gh_watchlist.lua` — if manager win valid: close; else: `open_manager()`

**Checkpoint**: Full add/remove/persist cycle works. `~/.config/nvim/gh-watchlist.json` written on every change.

---

## Phase 4: User Story 2 — Activity HUD Notifications (Priority: P2)

**Goal**: Background timer polls watched repos; new events produce a floating top-right notification that auto-dismisses after 5s. Up to 3 stacked.

**Independent Test**: Add a real repo, trigger a push/PR/issue from a browser — within 60s a notification appears top-right without disrupting editing.

### Implementation

- [X] T013 [US2] Implement `run_gh(args, callback)` in `lua/alex/gh_watchlist.lua` — same async pattern as `gh_reader.lua:run_gh` (vim.system → vim.schedule → json_decode → callback)
- [X] T014 [US2] Implement `event_label(ev)` in `lua/alex/gh_watchlist.lua` — returns human-readable string per event type: PushEvent→"push", PullRequestEvent→"PR #N opened/merged/closed", IssuesEvent→"issue #N opened/closed", IssueCommentEvent→"comment on #N", PullRequestReviewEvent→"review on PR #N", fallback→"activity"; extract numbers from `ev.payload` where available
- [X] T015 [US2] Implement `show_notification(repo, ev)` in `lua/alex/gh_watchlist.lua` — creates top-right floating window (`width=54`, `height=3`, `row=1+slot*4`, `col=ui.width-56`, `focusable=false`, `zindex=50`, `border="rounded"`); line 1 = `"  ⊙ " .. repo .. "  ·  " .. label`; applies `GhWatchNotif` highlight to ⊙; stores `{ win, buf, timer, _repo=repo, _ev=ev }` in `state.notifs`; evicts oldest if `#state.notifs >= 3`; starts 5000ms auto-dismiss timer per notification
- [X] T016 [US2] Implement `poll_repo(entry)` in `lua/alex/gh_watchlist.lua` — calls `gh api repos/{owner}/{repo}/events --jq '[.[] | {id,type,created_at,payload}] | .[0:10]'`; iterates newest-first, stops at `entry.last_seen_id`; calls `show_notification` for each new event; updates `entry.last_seen_id` to `events[1].id`; calls `save_watchlist()`
- [X] T017 [US2] Implement `poll()` in `lua/alex/gh_watchlist.lua` — iterates `state.repos`, calls `poll_repo(entry)` for each; no-op if `state.repos` is empty
- [X] T018 [US2] Start poll timer in `M.setup()` in `lua/alex/gh_watchlist.lua` — replace the `-- TODO: Phase B` stub with `state.poll_timer = vim.uv.new_timer(); state.poll_timer:start(5000, 60000, vim.schedule_wrap(poll))`

**Checkpoint**: With a watched repo, trigger a real GitHub event → notification appears within 60s; auto-dismisses after 5s; same event does not re-notify on next poll.

---

## Phase 5: User Story 3 — Jump to Activity (Priority: P3)

**Goal**: `<leader>gn` opens the most recent notification's PR/issue in the GH reader (or browser for pushes).

**Independent Test**: Trigger an event, wait for notification, press `<leader>gn` → GH reader opens for that item (or browser for push).

### Implementation

- [X] T019 [US3] Implement `open_event(repo, ev)` in `lua/alex/gh_watchlist.lua` — extracts owner/repo from `repo` string; for `PullRequestEvent`: calls `require("alex.gh_reader").open({ kind="pr", number=ev.payload.pull_request.number, repo=repo })`; for `IssuesEvent`/`IssueCommentEvent`: calls `open({ kind="issue", number=..., repo=repo })`; for others (PushEvent): calls `vim.system({ "xdg-open", "https://github.com/" .. repo })`
- [X] T020 [US3] Implement `M.open_latest()` in `lua/alex/gh_watchlist.lua` — grabs `state.notifs[#state.notifs]`; if nil: `vim.notify("No recent notifications")`; else: stops+closes its timer and window, removes from `state.notifs`, calls `open_event(last._repo, last._ev)`

**Checkpoint**: `<leader>gn` while notification is visible → GH reader opens for that PR/issue.

---

## Phase 6: Wire-up + Polish

- [X] T021 Add `require("alex.gh_watchlist").setup()` to `lua/alex/init.lua` after the existing `gh_reader` setup line
- [X] T022 Add keymaps to `lua/alex/remap.lua`: `<leader>gw` → `require("alex.gh_watchlist").toggle()` and `<leader>gn` → `require("alex.gh_watchlist").open_latest()`
- [X] T023 Smoke test: `<leader>gw` → add `owner/repo` → restart Neovim → repo still listed → trigger event → notification appears → `<leader>gn` → reader opens

---

## Dependencies & Execution Order

- **T002–T005** (Foundational) must complete before any US1/US2/US3 tasks
- **T006–T012** (US1) are sequential within the phase — each builds on prior
- **T013–T018** (US2) can begin after T002–T005; T016 depends on T013+T014+T015; T017 depends on T016; T018 depends on T017
- **T019–T020** (US3) can begin after T002–T005 and T015 (notification structure)
- **T021–T022** (wire-up) must come last

### Parallel Opportunities

- T006+T013 can start in parallel (different function groups in same file, no shared deps)
- T014 and T015 can start in parallel (neither depends on the other)
- T019 can start as soon as T015 is done (uses notification structure)

---

## Implementation Strategy

### MVP (T001–T012 only)

Watchlist persistence + manager UI with add/remove. No polling yet — delivers full US1 value: you can curate a watchlist that survives restarts.

### Full Delivery

T001–T005 → T006–T012 (US1) → T013–T018 (US2) → T019–T020 (US3) → T021–T023 (wire-up)

---

## Notes

- `state.notifs` entries store `_repo` and `_ev` directly (not on buf vars) — buf may be wiped before `open_latest()` is called
- `last_seen_id = ""` for newly added repos — first poll will silently update the watermark to the latest event without notifying (avoids flooding on first add)
- No error notifications for failed polls — `run_gh` callback returns `nil`, `poll_repo` simply returns early
- **Commit and push after each phase** (Constitution IV)
