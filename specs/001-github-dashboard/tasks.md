# Tasks: GitHub Dashboard for Neovim

**Input**: Design documents from `/specs/001-github-dashboard/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ui-contract.md ✅

**Tests**: Not requested — no test tasks generated.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the module skeleton and wire it into the existing config so the file exists and is loadable.

- [x] T001 Create `lua/alex/github_dashboard.lua` with module skeleton: `local M = {}`, `M.toggle = function() end`, `M.setup = function() end`, `return M`
- [x] T002 Add `require("alex.github_dashboard").setup()` to `lua/alex/init.lua` (after existing requires)
- [x] T003 Add `<leader>gh` keybinding to `lua/alex/remap.lua` — `vim.keymap.set("n", "<leader>gh", function() require("alex.github_dashboard").toggle() end, { desc = "Toggle GitHub Dashboard" })`
- [x] T004 Create cache directory: ensure `~/.cache/nvim/` exists at startup (one-time `vim.fn.mkdir` call inside `M.setup`)

**Checkpoint**: Neovim starts without errors, `<leader>gh` is registered (does nothing yet). ✅

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure needed by all user stories — cache read/write, async gh runner, age string helper.

- [x] T005 Implement cache helpers in `lua/alex/github_dashboard.lua`:
  - `cache_path`: `vim.fn.expand("~/.cache/nvim/gh-dashboard.json")`
  - `read_cache()`: reads + JSON-decodes cache file; returns `nil` on missing/corrupt
  - `write_cache(data)`: JSON-encodes + writes atomically (`.tmp` rename pattern from `hud.lua`)
  - `cache_age_seconds()`: returns seconds since cache mtime, or `math.huge` if absent
- [x] T006 Implement `run_gh(args, callback)` in `lua/alex/github_dashboard.lua`:
  - Runs `vim.system(args, { text = true }, ...)` async
  - On success: calls `callback(nil, decoded_table)` via `vim.schedule`
  - On error: calls `callback(err_string, nil)`
  - JSON decodes with `pcall(vim.fn.json_decode, stdout)`
- [x] T007 Implement `age_string(iso8601)` helper in `lua/alex/github_dashboard.lua`:
  - Parses ISO 8601 string to seconds via `os.time` arithmetic
  - Returns `"Xm ago"` / `"Xh ago"` / `"Xd ago"` / `"Xw ago"`

**Checkpoint**: Functions are present and syntactically valid. ✅

---

## Phase 3: User Story 1 — Quick GitHub Status Check (Priority: P1) 🎯 MVP

**Goal**: Open dashboard shows open PRs and assigned issues; user can press `<CR>` to open one in the browser.

**Independent Test**: Press `<leader>gh`, verify PR and issue sections render (empty state or data), navigate to an item, press `<CR>`, confirm browser opens the URL.

### Implementation

- [x] T008 [P] [US1] Implement `fetch_prs(callback)` in `lua/alex/github_dashboard.lua`
- [x] T009 [P] [US1] Implement `fetch_issues(callback)` in `lua/alex/github_dashboard.lua`
- [x] T010 [US1] Implement `render_prs(lines, hl_specs, items, prs, err)` in `lua/alex/github_dashboard.lua`
- [x] T011 [US1] Implement `render_issues(lines, hl_specs, items, issues, err)` in `lua/alex/github_dashboard.lua`
- [x] T012 [US1] Implement `open_win()` in `lua/alex/github_dashboard.lua`
- [x] T013 [US1] Implement `open_url_at_cursor()` in `lua/alex/github_dashboard.lua`
- [x] T014 [US1] Implement `fetch_and_render()` in `lua/alex/github_dashboard.lua`
- [x] T015 [US1] Implement `M.toggle()` in `lua/alex/github_dashboard.lua`

**Checkpoint**: `<leader>gh` opens dashboard window showing PR/issue sections. ✅

---

## Phase 4: User Story 2 — Activity & Contribution Overview (Priority: P2)

**Goal**: Dashboard shows recent activity feed and contribution heatmap.

**Independent Test**: Open dashboard, verify heatmap renders 26 rows of 7 block chars, verify activity feed shows at least the last 5 events with repo names.

### Implementation

- [x] T016 [P] [US2] Implement `fetch_activity(login, callback)` in `lua/alex/github_dashboard.lua`
- [x] T017 [P] [US2] Implement `fetch_contributions(callback)` in `lua/alex/github_dashboard.lua`
- [x] T018 [US2] Implement `render_heatmap(lines, hl_specs, contrib)` in `lua/alex/github_dashboard.lua`
- [x] T019 [US2] Implement `render_activity(lines, hl_specs, activity, err)` in `lua/alex/github_dashboard.lua`
- [x] T020 [US2] Add heatmap highlight groups in `setup_highlights()` in `lua/alex/github_dashboard.lua`
- [x] T021 [US2] Extend `fetch_and_render()` to also fetch activity + contributions in parallel with PRs/issues

**Checkpoint**: Dashboard heatmap and activity sections visible. ✅

---

## Phase 5: User Story 3 — Profile Summary (Priority: P3)

**Goal**: Dashboard shows a profile header with username, bio, and stats.

**Independent Test**: Open dashboard, verify top section shows `AlexanderInnerbichler` with at least 3 stats visible.

### Implementation

- [x] T022 [US3] Implement `fetch_profile(callback)` in `lua/alex/github_dashboard.lua`
- [x] T023 [US3] Implement `render_profile(lines, hl_specs, profile, total_contrib, win_width)` in `lua/alex/github_dashboard.lua`
- [x] T024 [US3] Add profile highlight groups to `setup_highlights()` in `lua/alex/github_dashboard.lua`
- [x] T025 [US3] Extend `fetch_and_render()` to fetch profile first, then fire parallel secondary fetches

**Checkpoint**: Dashboard opens with profile header. ✅

---

## Phase 6: User Story 4 — Repository Overview (Priority: P4)

**Goal**: Dashboard shows most recently active repos with name, language, stars, and visibility.

**Independent Test**: Open dashboard, verify repos section lists repos sorted by recency.

### Implementation

- [x] T026 [US4] Implement `fetch_repos(callback)` in `lua/alex/github_dashboard.lua`
- [x] T027 [US4] Implement `render_repos(lines, hl_specs, items, repos, err)` in `lua/alex/github_dashboard.lua`
- [x] T028 [US4] Extend `fetch_and_render()` to include repos fetch in the parallel batch

**Checkpoint**: Repos section visible with lock icon for private repos. ✅

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Loading states, stale indicators, error handling, and keybinding registration cleanup.

- [x] T029 [P] Loading indicator in title bar (`[loading…]`) shown while fetch is in progress
- [x] T030 [P] Stale indicator: if `cache_age_seconds() >= 300`, set `state.is_stale = true`; title shows `[stale]` in `GhStale` color
- [x] T031 Auto-refresh on open: in `M.toggle()`, stale cache triggers immediate background refresh
- [x] T032 `j` / `k` cursor movement handled natively by Neovim (cursorline enabled); no explicit remapping needed
- [x] T033 Highlights applied after each render: section headers, separators, heatmap tiers, item/meta text
- [ ] T034 Smoke test full flow: open fresh (no cache), wait for load, verify all 5 sections render, navigate with `j/k`, press `<CR>` on activity item, press `r` to force refresh, press `q` to close

**Checkpoint**: Dashboard is fully functional, looks polished, handles all edge cases.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1
- **Phase 3 (US1 — PRs & Issues)**: Depends on Phase 2 — this is the MVP
- **Phase 4 (US2 — Activity + Heatmap)**: Depends on Phase 2; can parallelize with Phase 3
- **Phase 5 (US3 — Profile)**: Depends on Phase 2; can parallelize with Phases 3–4
- **Phase 6 (US4 — Repos)**: Depends on Phase 2; can parallelize with Phases 3–5
- **Phase 7 (Polish)**: Depends on all story phases

### Within Each Story

- Fetch function before render function
- Render function before window integration
- Window integration before `M.toggle()` wiring

### Parallel Opportunities

Within Phase 3:
```
T008 fetch_prs      ─┐
T009 fetch_issues   ─┼─ independent, different functions
T012 open_win       ─┘
```

Within Phase 4:
```
T016 fetch_activity     ─┐
T017 fetch_contributions─┼─ independent
T020 highlight groups   ─┘
```

All phases 3–6 can proceed in parallel after Phase 2 completes.

---

## Implementation Strategy

### MVP (User Story 1 only — Phases 1–3)

1. Complete Phase 1: Setup ✅
2. Complete Phase 2: Foundational ✅
3. Complete Phase 3: PRs & Issues + window + browser open ✅
4. **VALIDATE**: `<leader>gh` opens dashboard, PR/issue sections render, `<CR>` opens browser, `q` closes

### Incremental Delivery

1. Phases 1–3 → MVP: PR/issue dashboard ✓
2. + Phase 4 → adds activity feed + heatmap ✓
3. + Phase 5 → adds profile header ✓
4. + Phase 6 → adds repo list ✓
5. + Phase 7 → polished, production-ready ✓

---

## Notes

- All code lives in one file: `lua/alex/github_dashboard.lua`
- Only `lua/alex/init.lua` and `lua/alex/remap.lua` needed minor edits (T002, T003)
- No new plugin dependencies — uses only built-in Neovim APIs and `gh` CLI
- **Commit and push after each completed phase** (Constitution IV)
- Each `[P]` task touches a different function — safe to implement in any order within the phase
