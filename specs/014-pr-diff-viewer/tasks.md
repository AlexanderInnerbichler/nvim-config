# Tasks: PR Diff Viewer

**Input**: Design documents from `specs/014-pr-diff-viewer/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Single user story (P1) — `d` keymap on PR rows opens unified diff in the reader popup.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1)
- Exact file paths included in all descriptions

---

## Phase 1: Setup

*No project-level setup needed — existing Lua/Neovim plugin project.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the three diff highlight groups to `gh_reader.lua`. Every other task depends on these existing.

- [X] T001 Add `GhDiffAdd` (fg `#98c379`), `GhDiffDel` (fg `#e06c75`), and `GhDiffHunk` (fg `#61afef`) highlight groups in the highlights block at the top of `lua/alex/gh_reader.lua` (alongside existing `GhReader*` groups)

**Checkpoint**: Highlight groups defined — implementation tasks can now begin.

---

## Phase 3: User Story 1 — PR diff viewer (Priority: P1) 🎯 MVP

**Goal**: Pressing `d` on a PR row in the dashboard opens the full unified diff in the reader popup with green/red/blue line highlighting.

**Independent Test**: Move cursor to a PR row in the dashboard → press `d` → popup opens with loading state then renders diff; `+` lines are green, `-` lines are red, `@@` hunk headers are blue. Press `q` → popup closes.

- [X] T002 [US1] Add `local function fetch_diff(number, repo, callback)` to `lua/alex/gh_reader.lua` — calls `vim.system({ "gh", "pr", "diff", tostring(number), "--repo", repo }, { text = true }, ...)` and schedules callback with `(err, stdout)` on completion

- [X] T003 [US1] Add `local function render_diff_content(lines, hl_specs, number, repo, diff_text, err)` to `lua/alex/gh_reader.lua` — renders breadcrumb (`  GitHub Dashboard  ›  {repo}  ›  PR #{number} diff` with `GhReaderBreadcrumb` + `GhReaderTitle` highlights), blank line, then iterates diff lines applying `GhDiffHunk` to `@@` lines, `GhDiffAdd` to `+` lines (excluding `+++`), `GhDiffDel` to `-` lines (excluding `---`); renders `GhReaderError` on err, `GhReaderEmpty` `"  (no diff)"` on empty text

- [X] T004 [US1] Add `M.open_diff = function(item)` to `lua/alex/gh_reader.lua` — calls `open_popup(" PR #N diff ", " q close ")`, sets `vim.wo[state.win].wrap = false`, calls `write_buf({"  Loading diff…"}, {})`, then calls `fetch_diff(item.number, item.repo, callback)` where callback builds lines+hl_specs via `render_diff_content` and calls `write_buf`

- [X] T005 [P] [US1] Add `title = pr.title` to the PR item table in `render_prs` in `lua/alex/github_dashboard.lua` (future-proofs breadcrumb; the item already has `number`, `repo`, `url`, `kind`)

- [X] T006 [US1] Add `local function open_diff_at_cursor()` to `lua/alex/github_dashboard.lua` — reads cursor line, iterates `state.items`, calls `require("alex.gh_reader").open_diff(item)` when `item.kind == "pr"` matches, returns silently if no match

- [X] T007 [US1] Add `buf_map("d", open_diff_at_cursor)` keymap in `lua/alex/github_dashboard.lua` alongside the existing `buf_map("<CR>", open_url_at_cursor)` call

**Checkpoint**: US1 fully functional — `d` on PR rows opens the diff popup; all other keymaps unchanged.

---

## Phase 4: Polish & Cross-Cutting Concerns

- [X] T008 Smoke-test all six verification scenarios from plan.md (PR diff renders; non-PR row `d` is no-op; `q` closes; empty diff; error state; `<CR>` regression) and commit all changes on branch `014-pr-diff-viewer`

---

## Dependencies & Execution Order

- **T001** (highlights): no dependencies — start immediately
- **T002** (fetch_diff): depends on T001
- **T003** (render_diff_content): depends on T001; can run parallel with T002 (same file, but logically independent — sequence for clarity)
- **T004** (M.open_diff): depends on T002 + T003
- **T005** (title in items): independent — different function in same file; run parallel with T002–T004
- **T006** (open_diff_at_cursor): depends on T004 (open_diff must exist before wiring)
- **T007** (buf_map): depends on T006
- **T008** (smoke test + commit): depends on all above

### Parallel Opportunities

- T005 (`render_prs` title change) can be done any time after T001 — it touches a different function
- T002 and T003 are in the same file but different functions — can be written in parallel if splitting work

---

## Implementation Strategy

### MVP (Single Story)

1. T001 — add highlights
2. T002 + T003 — fetch + render (can overlap)
3. T004 — wire `M.open_diff`
4. T005 + T006 + T007 — dashboard wiring
5. T008 — smoke test + commit

---

## Notes

- No test files — manual smoke test per plan.md Verification section
- `open_popup` already sets up `q`/`<Esc>` keymaps; `M.open_diff` gets these for free
- `wrap = false` must be set after `open_popup` since `open_popup` applies its own window options
- The `---` / `+++` file header lines in unified diff must be excluded from `GhDiffDel`/`GhDiffAdd` highlighting — handled by the `not line:match("^%-%-%-")` / `not line:match("^%+%+%+")` guards in T003
