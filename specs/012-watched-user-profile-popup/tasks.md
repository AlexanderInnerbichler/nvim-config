# Tasks: Watched User Profile Popup

**Input**: Design documents from `specs/012-watched-user-profile-popup/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

**Organization**: Tasks span 3 files. Grouped by user story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

- [X] T001 Read `lua/alex/github_dashboard.lua` lines 1–160 (constants, TIER_CHARS, HEAT_HLS, HEATMAP_WEEKS, TIER_THRESHOLDS, contribution_tier, run_gh), lines 241–273 (fetch_contributions / CONTRIB_QUERY), lines 433–515 (render_profile, render_heatmap), lines 712–755 (render_watched_users), and lines 869–883 (open_url_at_cursor) before writing any new code — confirms exact signatures and constants to duplicate

---

## Phase 2: Foundational (Blocking Prerequisites)

- [X] T002 Create `lua/alex/gh_user_profile.lua` with: module scaffold `local M = {}`; duplicate constants `HEATMAP_WEEKS=26`, `TIER_CHARS`, `TIER_THRESHOLDS`, `HEAT_HLS`; `local ns = vim.api.nvim_create_namespace("GhUserProfile")`; `contribution_tier(count)` (5-line copy from dashboard); `run_gh(args, callback)` (14-line copy from dashboard); `fetch_user_profile(username, callback)` calling `gh api /users/{username} --jq '{login,name,bio,followers,following,public_repos}'`; `fetch_user_contributions(username, callback)` using GraphQL `user(login: "USERNAME") { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { contributionCount date } } } } }` with JSON path `decoded.data.user.contributionsCollection.contributionCalendar`; empty `M.open` stub `function(username) end`; `return M`

**Checkpoint**: `require("alex.gh_user_profile")` loads without error; `M.open` exists as a no-op.

---

## Phase 3: User Story 1 — View profile from dashboard (Priority: P1) 🎯 MVP

**Goal**: `<CR>` on a `@username` header row in "Watched Users" opens a popup with that user's profile stats and 26-week contribution heatmap.

**Independent Test**: With at least one username in `~/.config/nvim/gh-user-watchlist.json`, open dashboard → "Watched Users" section shows `@username` header rows grouped by actor → `<CR>` on a header row opens popup with profile stats + heatmap → `q` closes.

### Implementation for User Story 1

- [X] T003 [US1] Rewrite `render_watched_users` in `lua/alex/github_dashboard.lua` (lines ~712–755) to group events by actor: (1) build ordered actor list preserving first-appearance order from the sorted events list; (2) for each actor insert header line `"   @" .. actor` with `GhSection`+`GhUsername` highlights and item `{ line=#lines, kind="user", username=actor }`; (3) render each actor's events indented: `string.format("      %s  %-32s  %s", icon, repo:sub(1,32), age)` (drop actor column since it's now in header); keep same PR/issue/push item routing per event; separator at end as before

- [X] T004 [US1] Extend `open_url_at_cursor` in `lua/alex/github_dashboard.lua` (line ~874) to handle `kind == "user"`: add `elseif item.kind == "user" then require("alex.gh_user_profile").open(item.username)` between the `gh_reader` branch and the `xdg-open` fallback

- [X] T005 [US1] Implement `render_content(lines, hl_specs, win_width, username, profile, contrib, profile_err, contrib_err)` in `lua/alex/gh_user_profile.lua`: header `"  @" .. username` with `GhSection` hl; if `profile_err` → `"  ✗ " .. err` with `GhError`; else stats line `string.format("  👥 %d followers · %d following · %d repos · %d contributions", ...)` with `GhStats`; if `profile.bio` non-empty/non-nil → `"  " .. profile.bio` with `GhStats`; separator line (80 `─` chars) with `GhSeparator`; if `contrib_err` → `"  ✗ contributions unavailable"` with `GhError`; else render 7-row heatmap grid using exact same loop as dashboard `render_heatmap` (day_labels, TIER_CHARS, HEAT_HLS, col_positions); finally `"     " .. (contrib and contrib.total or 0) .. " contributions this year"` with `GhStats`

- [X] T006 [US1] Implement `M.open(username)` in `lua/alex/gh_user_profile.lua`: (1) create buf (nofile/wipe/nomodifiable); (2) open centered float 80%w × 70%h, title `" @{username} "`, footer `" q close "`, border=rounded; (3) write `{ "", "  Loading @" .. username .. "…", "" }` into buf immediately; (4) fan out `fetch_user_profile` + `fetch_user_contributions` with `pending=2`, each callback stores result and calls `done()`; (5) `done()` decrements pending, when 0 calls `render_and_apply()`; (6) `render_and_apply()` calls `render_content` to build lines+hl_specs, sets buf modifiable, writes lines, clears ns, applies highlights, sets modifiable=false; (7) keymaps `q`+`<Esc>` close the win

**Checkpoint**: Edit watch list JSON to add a known user → open dashboard → "Watched Users" groups events under `@username` header → `<CR>` on header opens popup showing profile stats + heatmap → `q` closes.

---

## Phase 4: User Story 2 — Open profile from manager popup (Priority: P2)

**Goal**: `<CR>` on a username line in the manager (`<leader>gu`) opens the same profile popup.

**Independent Test**: `<leader>gu` → manager popup → `<CR>` on a username line → profile popup opens → `q` → focus returns to manager.

### Implementation for User Story 2

- [X] T007 [P] [US2] Add `<CR>` keymap to `open_manager` in `lua/alex/gh_user_watchlist.lua` (after the `bmap("<Esc>", close_manager)` line ~207): `bmap("<CR>", function() local cur = vim.api.nvim_win_get_cursor(state.manager_win)[1]; local idx = cur - 1; if idx >= 1 and idx <= #state.users then require("alex.gh_user_profile").open(state.users[idx]) end end)`

- [X] T008 [P] [US2] Update the manager footer string in `lua/alex/gh_user_watchlist.lua` (line ~191) from `" a add  ·  d remove  ·  q close "` to `" a add  ·  d remove  ·  <CR> profile  ·  q close "`

**Checkpoint**: `<leader>gu` → `<CR>` on username → profile popup opens. `q` → manager still open. Footer shows updated hint.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T009 Smoke test end-to-end: (a) dashboard "Watched Users" shows grouped actor headers; (b) `<CR>` on `@username` row opens profile popup with stats+heatmap; (c) `<CR>` on event row still opens PR/issue/browser; (d) `<leader>gu` → `<CR>` → profile popup; (e) empty watched list → "Watched Users" section absent; (f) invalid username → popup opens with error row; commit `feat: add watched user profile popup with heatmap`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — read files first
- **Foundational (Phase 2)**: Depends on Phase 1; T002 creates the module used by US1 tasks
- **US1 (Phase 3)**: T003 and T004 modify `github_dashboard.lua` (sequential — same file); T005 and T006 are in `gh_user_profile.lua` (sequential — T005 before T006); T003+T004 can run in parallel with T005 (different files)
- **US2 (Phase 4)**: T007 and T008 [P] depend only on T002 scaffold (different lines in same file — sequential to be safe)
- **Polish (Phase 5)**: Depends on all prior phases

### Within Each User Story

- T003 before T004 (both in dashboard.lua — sequential)
- T005 before T006 (render_content must exist before open uses it)
- T003+T004 can start in parallel with T005+T006 (different files)
- T007 and T008 are in the same file — sequential; but can start after T002

### Parallel Opportunities

- **T003+T004 [dashboard.lua] vs T005+T006 [gh_user_profile.lua]**: these two pairs are in different files and can run simultaneously
- **T007 and T008**: both in `gh_user_watchlist.lua` — same file, run sequentially; but independent of US1 tasks

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001: Read existing code patterns
2. T002: Create module scaffold
3. T003–T006: Dashboard grouping + popup rendering
4. **VALIDATE**: Grouped Watched Users + working profile popup
5. Add US2 (T007–T008) for manager CR support

### Incremental Delivery

1. T001–T002 → Foundation: module exists, loads cleanly
2. T003–T004 → Dashboard "Watched Users" grouped by actor (verify layout)
3. T005–T006 → Profile popup functional (verify profile + heatmap render)
4. T007–T008 → Manager CR support
5. T009 → Full smoke test + commit

---

## Notes

- `render_content` does NOT use `state.is_loading` or `state.is_stale` — those are dashboard-specific; the popup always shows fresh data
- The `separator()` helper is local to `github_dashboard.lua` — `gh_user_profile.lua` should inline a fixed-width separator: `string.rep("─", 80)`
- All `GhHeat*`, `GhSection`, `GhUsername`, `GhStats`, `GhError`, `GhSeparator` highlights are already defined by `github_dashboard.lua` setup — no new highlights needed
- `pending` counter starts at 2 (profile + contributions); `render_and_apply` fires only when both return
- If `kind == "user"` item is clicked, `open_url_at_cursor` no longer falls through to `xdg-open` or `gh_reader`
