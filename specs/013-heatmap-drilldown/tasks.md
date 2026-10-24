# Tasks: Heatmap Day Drill-Down

**Input**: Design documents from `specs/013-heatmap-drilldown/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Tasks grouped by user story — US1 = own heatmap drill-down (P1), US2 = watched user profile heatmap drill-down (P2).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Exact file paths included in all descriptions

---

## Phase 1: Setup

*No project-level setup needed — existing Lua/Neovim plugin project.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend `render_heatmap` to optionally emit `kind="day"` items. Both US1 and US2 depend on this.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T001 Extend `M.render_heatmap` in `lua/alex/gh_heatmap.lua` to accept two optional trailing params `items` and `username`; inside the row loop track `day_last_dates[day_idx]` (most recent `day.date` seen in that row); after flushing heatmap rows into `lines`, when `items` and `username` are non-nil insert `{ line = base_line + i - 1, kind = "day", date = day_last_dates[i], username = username }` for each row that has a date; callers that omit `items`/`username` are unaffected

**Checkpoint**: `render_heatmap` now populates `items` with `kind="day"` entries when called with optional params. Existing callers still work.

---

## Phase 3: User Story 1 — Own-heatmap drill-down (Priority: P1) 🎯 MVP

**Goal**: Pressing `<CR>` on any heatmap row in the dashboard opens a day-activity popup for the most recent date in that row.

**Independent Test**: Open dashboard → move cursor to any heatmap row → press `<CR>` → popup opens showing loading state then activity (or "No activity on this day"). Press `q` → popup closes.

- [X] T002 [US1] Create `lua/alex/gh_day_activity.lua` with: `fetch_day_events(username, date, callback)` using `gh api /users/{username}/events --jq "[.[] | select(.created_at | startswith(\"DATE\"))]"`; `event_summary(ev)` returning human-readable strings ("pushed N commits", "opened PR #N", "merged PR #N", "opened issue #N", "closed issue #N"); `render_events(lines, hl_specs, username, date, events, err)` writing a header line and one line per event (or "No activity on this day" if empty); `M.open(username, date)` creating buf+win immediately with "Loading…" state (75 % width × 60 % height, title ` YYYY-MM-DD `, footer ` q close `), then calling `fetch_day_events` async and writing rendered output on callback; `q`/`<Esc>` keymaps close the window

- [X] T003 [US1] Update `lua/alex/github_dashboard.lua`: in `apply_render` capture `local login = data.profile and data.profile.login` and pass `items, login` as 4th/5th args to `heatmap.render_heatmap`; in `open_url_at_cursor` add `elseif item.kind == "day" then require("alex.gh_day_activity").open(item.username, item.date)` branch

**Checkpoint**: US1 fully functional — dashboard heatmap rows respond to `<CR>` with the day popup.

---

## Phase 4: User Story 2 — Watched-user profile popup drill-down (Priority: P2)

**Goal**: Pressing `<CR>` on any heatmap row in the watched user profile popup opens a day-activity popup for that user on the most recent date in that row.

**Independent Test**: Open watched user profile popup (`<CR>` on a `@username` row in the dashboard) → move cursor to a heatmap row → press `<CR>` → day popup for that user opens. Close popup → focus returns to profile popup.

- [X] T004 [US2] Update `lua/alex/gh_user_profile.lua`: add `items` as third param to `render_content(lines, hl_specs, items, username, ...)` and forward it plus `username` to `heatmap.render_heatmap(lines, hl_specs, contrib, items, username)`; in `M.open` declare `local popup_items = {}`; in `render_and_apply` pass a fresh `{}` table as `items` to `render_content` and assign result to `popup_items`; add `<CR>` bmap that reads `vim.api.nvim_win_get_cursor(win)[1] - 1`, iterates `popup_items` for a matching `kind=="day"` item, and calls `require("alex.gh_day_activity").open(item.username, item.date)`

**Checkpoint**: US2 fully functional — watched user profile popup heatmap rows respond to `<CR>` with the day popup for that user.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T005 Smoke-test all five verification scenarios from plan.md (dashboard heatmap `<CR>`, zero-contribution row, non-heatmap rows unchanged, watched user profile heatmap `<CR>`, popup `q`/`<Esc>` closes cleanly) and commit all changes on branch `013-heatmap-drilldown`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: Start immediately — no dependencies
- **US1 (Phase 3)**: Depends on T001 (Phase 2)
- **US2 (Phase 4)**: Depends on T001 (Phase 2) and T002 (gh_day_activity module must exist)
- **Polish (Phase 5)**: Depends on T002, T003, T004

### Within Each User Story

- **US1**: T002 before T003 (dashboard requires the module to exist when requiring it at runtime; creating it first keeps the diff reviewable)
- **US2**: T004 is a single self-contained task; depends on T001 and T002

### Parallel Opportunities

- T002 and T003 touch different files (`gh_day_activity.lua` vs `github_dashboard.lua`) — can be worked in parallel once T001 is done, but T003 calls `require("alex.gh_day_activity")` so T002 should land first
- T004 is independent of T002/T003 at the file level but depends on T002 at runtime

---

## Parallel Example: Phase 3 + 4 (after T001 complete)

```bash
# Once T001 is merged:
Task A: T002 — create gh_day_activity.lua
Task B: T004 — update gh_user_profile.lua (adds popup_items/<CR>, wires render_content)

# After T002:
Task C: T003 — update github_dashboard.lua (wires open_url_at_cursor)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T001: extend `render_heatmap`
2. Complete T002: create `gh_day_activity.lua`
3. Complete T003: wire dashboard
4. **STOP and VALIDATE**: test own-heatmap drill-down
5. Proceed to US2 if validation passes

### Incremental Delivery

1. T001 → foundational ready
2. T002 + T003 → US1 complete and testable (MVP)
3. T004 → US2 complete and testable
4. T005 → smoke test + commit

---

## Notes

- No new test files — manual smoke test per plan.md Verification section
- `render_heatmap` backward-compatibility is critical — nil `items` must produce identical output to today
- `gh_day_activity.lua` needs no `setup()` call — highlights (`GhHeat*`, etc.) already defined by dashboard on startup
- The `day_last_dates` tracking in T001 must handle rows where all cells have `nil` dates (sparse weeks at the start of the year) — those rows produce no item
