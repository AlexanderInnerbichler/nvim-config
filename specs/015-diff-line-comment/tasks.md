# Tasks: PR Diff Inline Line Comments

**Input**: Design documents from `specs/015-diff-line-comment/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Single user story (P1) — Visual mode `c` in the diff popup posts an inline review comment on the selected line.

**Only one file changes**: `lua/alex/gh_reader.lua`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 for all implementation tasks
- Exact file paths included in all descriptions

---

## Phase 1: Setup

*No project-level setup needed — existing Lua/Neovim plugin project.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the three new `diff_*` fields to `state` in `gh_reader.lua`. All other tasks depend on this structure existing.

- [X] T001 Add `diff_item = nil`, `diff_line_map = {}`, and `diff_head_sha = nil` fields to the `state` table at the top of `lua/alex/gh_reader.lua` (alongside existing `buf`, `win`, `item`, `data`, `input_buf`, `input_win` fields)

**Checkpoint**: `state` structure updated — implementation tasks can begin.

---

## Phase 3: User Story 1 — Inline review comment from diff (Priority: P1) 🎯 MVP

**Goal**: In the diff popup, enter Visual mode, select a diff line, press `c`, type a comment, submit → comment appears on GitHub attached to that line.

**Independent Test**: Open diff popup (`d` on PR row) → Visual select a `+` line → `c` → input opens → submit → verify comment appears in the PR on GitHub.

- [X] T002 [US1] Add `local function fetch_head_sha(number, repo, callback)` to `lua/alex/gh_reader.lua` — calls `vim.system({ "gh", "pr", "view", tostring(number), "--repo", repo, "--json", "headRefOid", "--jq", ".headRefOid" }, { text = true }, ...)`, schedules `callback(nil, vim.trim(stdout))` on success or `callback(stderr, nil)` on failure

- [X] T003 [US1] Add `local function post_review_comment(number, repo, sha, path, line, side, body, callback)` to `lua/alex/gh_reader.lua` — calls `vim.system({ "gh", "api", "repos/" .. repo .. "/pulls/" .. tostring(number) .. "/comments", "-f", "body=" .. body, "-f", "commit_id=" .. sha, "-f", "path=" .. path, "-F", "line=" .. tostring(line), "-f", "side=" .. side }, { text = true }, ...)`, schedules `callback(nil)` on success or `callback(stderr)` on failure

- [X] T004 [US1] Extend `render_diff_content` in `lua/alex/gh_reader.lua` to accept an optional 7th param `line_map`; inside the diff line loop track `cur_path` (from `diff --git b/FILE`), `new_line_n`, and `old_line_n` (reset on each `@@` hunk header from `+START` value minus 1); for `+` lines (not `+++`) increment `new_line_n` and insert `line_map[buf_ln] = { path=cur_path, line=new_line_n, side="RIGHT" }`; for `-` lines (not `---`) increment `old_line_n` and insert `line_map[buf_ln] = { path=cur_path, line=old_line_n, side="LEFT" }`; for space-prefix context lines increment both counters and insert with `side="RIGHT"` and new file line; when `line_map` is nil the function is unchanged

- [X] T005 [US1] Rewrite `M.open_diff` in `lua/alex/gh_reader.lua` to: (a) reset `state.diff_item = item`, `state.diff_line_map = {}`, `state.diff_head_sha = nil`; (b) update footer to `" c comment · q close "`; (c) register `vim.keymap.set("v", "c", ..., { buffer = state.buf, nowait = true, silent = true })` that reads `vim.fn.getpos("'>")[2] - 1` as 0-indexed buffer line, looks up `state.diff_line_map[end_ln]`, shows `vim.notify("Cannot comment on this line")` if not found, shows `vim.notify("Still loading, please try again")` if `state.diff_head_sha` is empty, otherwise calls `vim.cmd("normal! \27")` then `M.open_input(...)` with a callback that calls `post_review_comment` and notifies on success/error; (d) use a `pending=2` fan-out to run `fetch_diff` and `fetch_head_sha` in parallel, storing `state.diff_head_sha` when SHA arrives, and calling `render_diff_content(..., state.diff_line_map)` + `write_buf` once both complete

- [X] T006 Smoke-test all seven verification scenarios from plan.md and commit all changes on branch `015-diff-line-comment`

---

## Dependencies & Execution Order

- **T001** (state fields): no dependencies — start immediately
- **T002** (fetch_head_sha): depends on T001
- **T003** (post_review_comment): depends on T001; can run parallel with T002 (same file, different functions)
- **T004** (render_diff_content extension): depends on T001; can run parallel with T002/T003
- **T005** (M.open_diff rewrite): depends on T002 + T003 + T004
- **T006** (smoke test + commit): depends on T005

### Parallel Opportunities

- T002, T003, T004 all add independent private functions to `gh_reader.lua` — logically parallel but in the same file; write sequentially for clarity

---

## Implementation Strategy

1. T001 — extend state
2. T002 → T003 → T004 — add private functions (sequential for single-file clarity)
3. T005 — rewrite M.open_diff wiring everything together
4. T006 — smoke test + commit

---

## Notes

- No test files — manual smoke test per plan.md Verification section
- `c` is Visual-mode-only (`vim.keymap.set("v", ...)`) — does not shadow Normal mode `c`
- The keymap is set once in `M.open_diff` on `state.buf`; if `M.open_diff` is called again the keymap is overwritten (same buffer), which is correct
- `@@` lines and file header lines (`diff --git`, `index`, `---`, `+++`) are NOT inserted into `line_map` — they produce the "Cannot comment" message
- `state.diff_head_sha` may be `""` if the SHA fetch fails; the keymap handler checks for this and shows "Still loading"
