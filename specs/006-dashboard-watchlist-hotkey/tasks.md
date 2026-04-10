# Tasks: Dashboard Watchlist Hotkey

**Input**: Design documents from `/specs/006-dashboard-watchlist-hotkey/`
**Prerequisites**: plan.md ✓, spec.md ✓

**New files**: none  
**Modified files**: `lua/alex/gh_watchlist.lua`, `lua/alex/github_dashboard.lua`

---

## Phase 1: User Story 1 — Add/Remove Repo from Dashboard (Priority: P1) 🎯 MVP

**Goal**: Press `w` on a repo row in the GitHub Dashboard to toggle that repo's watchlist membership.

**Independent Test**: Open dashboard (`<leader>gh`), move cursor to a repo row, press `w` → notification "Added owner/repo to watchlist" appears and `~/.config/nvim/gh-watchlist.json` is updated. Press `w` again → notification "Removed owner/repo from watchlist".

- [X] T001 [US1] Add `M.toggle_repo(full_name)` to `lua/alex/gh_watchlist.lua` — splits `full_name` on `/`, checks `state.repos` for existing entry: if found removes it + `save_watchlist()` + `vim.notify("Removed … from watchlist")`, else inserts `{ owner, repo, last_seen_id="" }` + `save_watchlist()` + `vim.notify("Added … to watchlist")`; place after `M.open_latest` before `return M`
- [X] T002 [US1] Update `render_repos` in `lua/alex/github_dashboard.lua` — change `table.insert(items, { line = #lines, url = repo.url })` to `table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name })` so the `w` handler can read it
- [X] T003 [US1] Add `toggle_watch_at_cursor` helper and `w` keymap in `open_win()` in `lua/alex/github_dashboard.lua` — helper iterates `state.items`, finds item where `item.line == cur_line` and `item.full_name` is set, calls `require("alex.gh_watchlist").toggle_repo(item.full_name)`; register with `buf_map("w", toggle_watch_at_cursor)`

**Checkpoint**: Full add/remove cycle works from dashboard. `gh-watchlist.json` updated on each toggle. `w` on non-repo rows is a no-op.

---

## Dependencies & Execution Order

- **T001** (watchlist public API) can be done independently of T002/T003
- **T002** must precede T003 (T003 relies on `full_name` being in items)
- **T001 and T002** can run in parallel (different files)

### Parallel Opportunities

- T001 and T002 can start simultaneously (different files, no deps between them)
- T003 starts after T002

---

## Implementation Strategy

This is a minimal two-file change. Complete T001 + T002 in parallel, then T003. Smoke test, commit, push, merge.

---

## Notes

- `repo.full_name` is already populated in `fetch_repos` via `r.nameWithOwner` — no extra fetch needed
- `toggle_watch_at_cursor` must be defined as a local inside `open_win` (or before it) so it closes over `state`; it can also be a module-level local since `state` is already module-level
- **Commit and push after all tasks complete** (Constitution IV)
