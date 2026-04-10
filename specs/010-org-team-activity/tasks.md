# Tasks: Org Team Activity Feed

**Input**: Design documents from `specs/010-org-team-activity/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

**Organization**: All changes are in `lua/alex/github_dashboard.lua`. Tasks are grouped by user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

*No project initialization needed — extending an existing Lua module with no new files or dependencies.*

- [X] T001 Read `lua/alex/github_dashboard.lua` lines 299–583 to confirm exact signatures of `fetch_org_repos`, `render_org_repos`, `start_secondary_fetches`, and `apply_render` before writing any code

---

## Phase 2: Foundational

*No blocking prerequisites — all infrastructure (run_gh, age_string, EVENT_ICONS, event_summary, state.data) already exists.*

**Checkpoint**: Foundation confirmed — user story implementation can begin.

---

## Phase 3: User Story 1 — Browse team activity in the dashboard (Priority: P1) 🎯 MVP

**Goal**: A "Team Activity" section appears in the dashboard listing recent events from org members, loading asynchronously without blocking the rest of the dashboard.

**Independent Test**: Open dashboard → scroll to bottom → "Team Activity" section lists events with actor username, event type icon, repo, and age. Section absent when user has no org memberships.

### Implementation for User Story 1

- [X] T002 [US1] Add `fetch_team_activity(callback)` function to `lua/alex/github_dashboard.lua` after `fetch_org_repos` (line ~342): call `gh api /user/orgs --paginate`; if no orgs call `callback(nil, {})` and return; for each org call `gh api /orgs/{login}/events --jq '[.[] | {type, actor: .actor.login, repo: .repo.name, created_at, pr_number: .payload.pull_request.number, issue_number: .payload.issue.number}]'`; collect events ignoring per-org errors; when all done sort by `created_at` desc and call `callback(any_err, {unpack(all_events, 1, 10)})`

- [X] T003 [US1] Add `render_team_activity(lines, hl_specs, items, team_events, err)` function to `lua/alex/github_dashboard.lua` after `render_org_repos` (line ~584): return silently if no error AND no events; add header `"  Team Activity"` with `GhSection` highlight; on error add `"  ✗ ..."` with `GhError`; for each event add row `string.format("   %-18s  %s  %-30s  %s", actor:sub(1,18), EVENT_ICONS[type] or "·", repo:sub(1,30), age_string(created_at))` with `GhStats` highlight on icon column and `GhMeta` on age

- [X] T004 [US1] Wire `render_team_activity` into `apply_render` in `lua/alex/github_dashboard.lua`: add call `render_team_activity(lines, hl_specs, items, data.team_events, data.team_events_err)` immediately after the `render_org_repos(...)` call (line ~606)

- [X] T005 [US1] Wire `fetch_team_activity` into `start_secondary_fetches` in `lua/alex/github_dashboard.lua`: change `pending = pending + 4` to `pending = pending + 5`; add fetch call after `fetch_org_repos` block: `fetch_team_activity(function(err, events) if err then state.data.team_events_err = err else state.data.team_events = events end; done(err ~= nil) end)`

**Checkpoint**: Open dashboard — "Team Activity" section visible with event rows showing actor, icon, repo, age. If no org memberships, section absent.

---

## Phase 4: User Story 2 — Open a team event in the reader (Priority: P2)

**Goal**: `<CR>` on a PR/issue team event opens it in the inline reader popup; `<CR>` on push/fork/star opens the repo URL in the browser.

**Independent Test**: Move cursor to a PullRequestEvent row in Team Activity → press `<CR>` → PR reader popup opens with correct PR. Move cursor to a PushEvent row → press `<CR>` → browser opens repo URL.

### Implementation for User Story 2

- [X] T006 [US2] Extend `render_team_activity` in `lua/alex/github_dashboard.lua` to insert items into the `items` table for each event row: for `PullRequestEvent` insert `{ line=#lines, kind="pr", number=event.pr_number, repo=event.repo }`; for `IssuesEvent` insert `{ line=#lines, kind="issue", number=event.issue_number, repo=event.repo }`; for all other types insert `{ line=#lines, kind="push", url="https://github.com/"..event.repo }` — insert BEFORE `table.insert(lines, line)` so line index is correct (0-indexed: `#lines` is the upcoming line index)

**Checkpoint**: `<CR>` on PR/issue team events opens reader with correct content. `<CR>` on push/fork/star opens browser to repo URL. Back navigation with `q` returns to dashboard.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [ ] T007 Smoke test the full dashboard: verify Team Activity section loads asynchronously (other sections appear from cache first), verify event rows display correctly, verify `<CR>` routing for all event types, verify section absent for no-org account, commit and push `feat: add Team Activity section — org member events in dashboard`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Trivial — no blocking work
- **User Story 1 (Phase 3)**: T002 → T003 → T004 → T005 (sequential, same file)
- **User Story 2 (Phase 4)**: T006 depends on T003 (extends render_team_activity written in T003)
- **Polish (Phase 5)**: Depends on all story phases complete

### Within Each User Story

- T002 before T003 (render needs fetch's data shape defined)
- T003 before T004 and T006
- T004 and T005 can be done in either order (independent wiring points)

### Parallel Opportunities

No tasks are parallelizable — all changes are in the same file and must be written in logical order to avoid conflicts.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001: Read existing patterns
2. T002–T005: Implement fetch, render, and wire-up (US1)
3. **VALIDATE**: Open dashboard, confirm Team Activity section
4. Add US2 (T006) — cursor routing

### Incremental Delivery

1. After T005: Display-only Team Activity section — valuable on its own
2. After T006: Full interaction — reader integration completes the feature

---

## Notes

- All changes in one file: `lua/alex/github_dashboard.lua`
- No `[P]` tasks — single file, sequential writes
- The `open_url_at_cursor` function (line ~688) requires no changes — it already routes non-reader kinds to browser via `vim.system({ "xdg-open", item.url })`
- Item line index: use `#lines` (current length = next line's 0-indexed position) before inserting the row
- Commit and push after T005 (US1 complete) and again after T007 (full feature complete)
