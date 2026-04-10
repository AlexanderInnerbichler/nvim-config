# Tasks: PR Review Comments + Keybind Hints

**Input**: Design documents from `specs/016-pr-review-comments-hud/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Three user stories — US1 (P1) is independent MVP; US2 and US3 touch different files (parallel with each other after US1).

**Files changed**: `lua/alex/gh_reader.lua` (US1 + US3), `lua/alex/github_dashboard.lua` (US2)

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1/US2/US3 for implementation tasks

---

## Phase 1: Setup

*No project-level setup needed — existing Lua/Neovim plugin project.*

---

## Phase 2: Foundational

*No shared prerequisites — all three user stories can begin immediately.*

---

## Phase 3: User Story 1 — Review Comments in PR Overview (Priority: P1) 🎯 MVP

**Goal**: Opening a PR shows all inline review comments below the general comments section.

**Independent Test**: Open a PR that has inline review comments → a "Review Comments" section appears at the bottom of the PR overview listing each comment's author, file path, line number, and body.

- [X] T001 [US1] Add `local function fetch_review_comments(number, repo, callback)` to `lua/alex/gh_reader.lua` — calls `vim.system({ "gh", "api", "repos/" .. repo .. "/pulls/" .. tostring(number) .. "/comments", "--jq", "[.[] | {login: .user.login, path: .path, line: (.line // .original_line), body: .body}]" }, { text = true }, ...)`, on success decodes JSON and calls `callback(data)`, on any failure calls `callback({})` (errors are silent — review comments must not block the PR view)

- [X] T002 [US1] Add `local function render_review_comments_section(lines, hl_specs, review_comments)` to `lua/alex/gh_reader.lua` after `render_comments_section` — if `#review_comments == 0` returns immediately (no section); otherwise inserts a separator, a `"  🔎 Review Comments (N)"` header with `GhReaderSection` highlight, then for each comment: blank line, meta line `"  @login  ·  path:line"` with `GhReaderMeta` highlight, a `╌` divider with `GhReaderSep`, and `process_body(rc.body, lines, hl_specs)`

- [X] T003 [US1] Change `render_pr(data)` in `lua/alex/gh_reader.lua` to `render_pr(data, review_comments)` and add `render_review_comments_section(lines, hl_specs, review_comments or {})` immediately after the existing `render_comments_section(lines, hl_specs, data.comments)` call on line ~656

- [X] T004 [US1] Rewrite the `elseif item.kind == "pr" then` branch in `M.open` in `lua/alex/gh_reader.lua` to use a `pending=2` fan-out: declare local `pr_data, rc_data, pending = 2`; define `local function on_both()` that decrements pending and returns if > 0, otherwise sets `state.data = pr_data` and calls `render_pr(pr_data, rc_data or {})`; call `fetch_pr(item, ...)` storing result in `pr_data` and calling `on_both()` (bail out on error as before); call `fetch_review_comments(item.number, item.repo, ...)` storing result in `rc_data` and calling `on_both()`

---

## Phase 4: User Story 2 — `d` Diff Hint in Dashboard Footer on PR Rows (Priority: P2)

**Goal**: Dashboard footer shows `d diff` hint when cursor is on a PR row; reverts to default footer otherwise.

**Independent Test**: Open dashboard → move cursor to a PR row → footer updates to show `d diff`; move cursor to an issue or activity row → `d diff` disappears from footer.

- [X] T005 [P] [US2] Add a `CursorMoved` autocmd in `open_win()` in `lua/alex/github_dashboard.lua` after all `buf_map` calls — define two footer strings as locals before `nvim_open_win`: `footer_default = " <CR> open  ·  w watch  ·  r refresh  ·  <leader>gw watchlist  ·  <leader>gn notifs  ·  q close "` and `footer_pr = " <CR> open  ·  d diff  ·  w watch  ·  r refresh  ·  q close "`; use `footer_default` as the initial footer in `nvim_open_win`; register `vim.api.nvim_create_autocmd("CursorMoved", { buffer = state.buf, callback = function() ... end })` that reads cursor line (0-indexed), iterates `state.items` to check if `item.kind == "pr"`, and calls `vim.api.nvim_win_set_config(state.win, { footer = on_pr and footer_pr or footer_default, footer_pos = "center" })` — guard with `if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end`

---

## Phase 5: User Story 3 — Keybind Hints in PR Reader Footer (Priority: P3)

**Goal**: PR reader footer shows `d diff` and pressing `d` opens the diff popup.

**Independent Test**: Open a PR reader → footer shows `d diff`; press `d` → diff popup opens for that PR.

- [X] T006 [P] [US3] Add `bmap("d", function() if state.item and state.item.kind == "pr" then M.open_diff(state.item) end end)` to `register_keymaps()` in `lua/alex/gh_reader.lua` after the existing `bmap("m", ...)` block

- [X] T007 [P] [US3] Update `pr_footer` string in `render_pr` in `lua/alex/gh_reader.lua` from `"q back  ·  r refresh  ·  c comment  ·  a review  ·  m merge"` to `"q back  ·  r refresh  ·  c comment  ·  a review  ·  d diff  ·  m merge"`

---

## Phase 6: Polish

- [ ] T008 Smoke-test all eight verification scenarios from plan.md and commit all changes on branch `016-pr-review-comments-hud`

---

## Dependencies & Execution Order

- **T001** (fetch_review_comments): no dependencies
- **T002** (render_review_comments_section): no dependencies; can run parallel with T001
- **T003** (render_pr +param): depends on T002
- **T004** (M.open fan-out): depends on T001 + T003
- **T005** (dashboard CursorMoved): no dependencies on US1; can run after T001-T004 or in parallel
- **T006** (register_keymaps d): no dependencies; can run in parallel with T005
- **T007** (pr_footer update): no dependencies; can run in parallel with T005/T006
- **T008** (smoke test + commit): depends on T004 + T005 + T006 + T007

### Parallel Opportunities

- T001 and T002 — no dependencies between them (same file, different functions)
- T005, T006, T007 — all independent (T005 in different file; T006/T007 in same file but no deps)

---

## Implementation Strategy

1. T001 → T002 → T003 → T004 — US1 in sequence (single-file clarity)
2. T005 — US2 (dashboard file, fully independent)
3. T006 → T007 — US3 in sequence (same file)
4. T008 — smoke test + commit
