# Tasks: GitHub Issue & PR Inline Reader

**Input**: Design documents from `/specs/002-gh-issue-pr-reader/`  
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ui-contract.md ✅

**Tests**: Not requested — no test tasks generated.

**Organization**: Tasks grouped by user story to enable independent, incremental delivery.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the module skeleton and wire it into the existing config.

- [x] T001 Create `lua/alex/gh_reader.lua` with module skeleton: `local M = {}`, `M.open = function(item) end`, `M.setup = function() end`, `return M`
- [x] T002 Add `require("alex.gh_reader").setup()` to `lua/alex/init.lua` (after `github_dashboard` require)
- [x] T003 In `lua/alex/github_dashboard.lua` `render_prs`: add `kind = "pr"`, `number = pr.number`, `repo = pr.repo` fields to each item inserted into `items`
- [x] T004 In `lua/alex/github_dashboard.lua` `render_issues`: add `kind = "issue"`, `number = iss.number`, `repo = iss.repo` fields to each item inserted into `items`
- [x] T005 In `lua/alex/github_dashboard.lua` `open_url_at_cursor`: replace the `vim.system({"xdg-open", item.url})` call with a dispatch: if `item.kind == "issue" or item.kind == "pr"` call `require("alex.gh_reader").open(item)`, else keep `xdg-open`

**Checkpoint**: Neovim starts without errors. `<CR>` on a dashboard issue/PR calls `gh_reader.open()` (no-op yet). `<CR>` on repos still opens browser.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared window, highlight, and async-fetch infrastructure used by all user stories.

- [x] T006 Implement `setup_highlights()` in `lua/alex/gh_reader.lua` — define all highlight groups from contracts/ui-contract.md: `GhReaderTitle`, `GhReaderMeta`, `GhReaderState` (open/closed/merged variants), `GhReaderSection`, `GhReaderSep`, `GhCiPass`, `GhCiFail`, `GhCiPending`, `GhReviewApproved`, `GhReviewChanges`. Call inside `M.setup()` and re-register on `ColorScheme` autocmd.
- [x] T007 Implement `open_split()` in `lua/alex/gh_reader.lua`: create a 80-col right `vsplit`, set buffer options (`nomodifiable`, `filetype=markdown`, `buftype=nofile`, `bufhidden=wipe`, `number=false`, `signcolumn=no`, `wrap=true`, `linebreak=true`). Store `state.buf` and `state.win`. Return early if split already open and valid.
- [x] T008 Implement `close_split()` in `lua/alex/gh_reader.lua`: close `state.win` if valid, set `state.win = nil`.
- [x] T009 Implement `write_buf(lines, hl_specs)` in `lua/alex/gh_reader.lua`: set `modifiable=true`, call `nvim_buf_set_lines`, set `modifiable=false`, clear namespace, apply all highlight specs via `nvim_buf_add_highlight`.
- [x] T010 Implement `run_gh(args, callback)` in `lua/alex/gh_reader.lua` — identical pattern to `github_dashboard.lua`: `vim.system(args, {text=true}, ...)`, `vim.schedule`, `pcall(vim.fn.json_decode, stdout)`, call `callback(err, data)`.
- [x] T011 Implement `separator()` helper and `age_string(iso8601)` helper in `lua/alex/gh_reader.lua` — copy the identical implementations from `github_dashboard.lua` (same logic, local to this module).

**Checkpoint**: Module loads without error (`nvim --headless -c "lua require('alex.gh_reader')" -c "q"` exits 0).

---

## Phase 3: User Story 1 — Read a Full Issue (Priority: P1) 🎯 MVP

**Goal**: `<CR>` on a dashboard issue opens a right-split reader showing the full issue body and comment thread.

**Independent Test**: Open dashboard, press `<CR>` on an issue, verify: title + state badge + labels + body + all comments render in the right split. Press `q` to close.

### Implementation

- [x] T012 [P] [US1] Implement `fetch_issue(item, callback)` in `lua/alex/gh_reader.lua`: run `gh issue view {item.number} -R {item.repo} --json number,title,state,body,labels,author,comments,createdAt,assignees,url`; map response to IssueDetail shape from data-model.md (labels: `[.labels[].name]`, author: `author.login`, comments: map each to `{id, author=.author.login, body, created_at=.createdAt}`)
- [x] T013 [US1] Implement `render_header_issue(lines, hl_specs, data)` in `lua/alex/gh_reader.lua`:
  - Line 1: `"  #N  Title"` — highlight title with `GhReaderTitle`
  - Line 2: state badge (`OPEN`=green/`GhReaderState`, `CLOSED`=red), then `"  @author · label1 · label2 · Xd ago"` in `GhReaderMeta`
  - Line 3: separator — `GhReaderSep`
- [x] T014 [US1] Implement `render_comments(lines, hl_specs, comments)` in `lua/alex/gh_reader.lua`:
  - Section header `"  💬 Comments (N)"` — `GhReaderSection`
  - Separator
  - For each comment: `"  @author · Xh ago"` in `GhReaderMeta`, then body lines (passed through as-is for markdown rendering)
  - Empty state: `"   No comments yet"` in dimmed style
- [x] T015 [US1] Implement `render_issue(data)` in `lua/alex/gh_reader.lua`: builds `lines` + `hl_specs` by calling `render_header_issue` then body lines then separator then `render_comments`; calls `write_buf`
- [x] T016 [US1] Wire `M.open(item)` for `kind="issue"` in `lua/alex/gh_reader.lua`: call `open_split()`, show `"  ⠋ loading #N…"` placeholder, then `fetch_issue(item, function(err, data) ... render_issue(data) end)`
- [x] T017 [US1] Register buffer-local keymaps in `open_split()`: `q` and `<Esc>` → `close_split()`, `r` → re-fetch and re-render current `state.item`

**Checkpoint**: `<CR>` on any dashboard issue opens right split showing full content. `q` closes. `r` reloads.

---

## Phase 4: User Story 2 — Read a Full PR (Priority: P1)

**Goal**: `<CR>` on a dashboard PR opens the reader showing body, CI status, reviewer states, and review comments.

**Independent Test**: Open dashboard, press `<CR>` on a PR, verify: branch info, CI check statuses (✓/✗/⠋), reviewer states, body, and review comments render correctly. Press `q` to close.

### Implementation

- [x] T018 [P] [US2] Implement `fetch_pr(item, callback)` in `lua/alex/gh_reader.lua`: run `gh pr view {item.number} -R {item.repo} --json number,title,state,body,author,headRefName,baseRefName,reviews,statusCheckRollup,comments,createdAt,isDraft,mergeable,url,assignees`; map to PRDetail shape: `head_ref=headRefName`, `base_ref=baseRefName`, `is_draft=isDraft`, `ci_checks=statusCheckRollup` (map each to `{name, status=.status, conclusion=.conclusion}`), `reviews` (map each to `{author=.author.login, state, body, submitted_at=.submittedAt}`)
- [x] T019 [US2] Implement `render_header_pr(lines, hl_specs, data)` in `lua/alex/gh_reader.lua`:
  - Same title line as issue but with draft indicator if `is_draft`
  - State badge: `OPEN`=green, `MERGED`=purple/`GhReaderState`, `CLOSED`=red
  - Branch line: `"  ⎇  head_ref → base_ref   draft: No/Yes   mergeable: Yes/No/Unknown"`
  - CI line: `"  CI: "` then for each check: `"✓ name"` (`GhCiPass`) / `"✗ name"` (`GhCiFail`) / `"⠋ name"` (`GhCiPending`); show `"  CI: no checks"` if empty
  - Reviews line: `"  Reviews: "` then for each review: `"✓ login"` (`GhReviewApproved`) / `"✗ login"` (`GhReviewChanges`) / `"· login"` (comment); show `"  Reviews: none"` if empty
  - Separator
- [x] T020 [US2] Implement `render_reviews(lines, hl_specs, reviews)` in `lua/alex/gh_reader.lua`: section header `"  🔍 Reviews (N)"`, then for each review with a body: `"  @author · state · Xd ago"` + body lines; skip reviews with empty bodies
- [x] T021 [US2] Implement `render_pr(data)` in `lua/alex/gh_reader.lua`: `render_header_pr` → body lines → separator → `render_reviews` → separator → `render_comments`; calls `write_buf`
- [x] T022 [US2] Wire `M.open(item)` for `kind="pr"` in `lua/alex/gh_reader.lua`: same pattern as issue — `open_split()`, loading placeholder, `fetch_pr`, `render_pr`

**Checkpoint**: `<CR>` on any dashboard PR opens right split. CI status and reviewer states visible with color coding.

---

## Phase 5: User Story 3 — Post a Comment (Priority: P2)

**Goal**: Press `c` in the reader to compose and post a comment on the open issue or PR.

**Independent Test**: Open any issue reader, press `c`, type a comment, press `<leader>s`, verify comment appears in the refreshed reader thread.

### Implementation

- [x] T023 [US3] Implement `open_input(hint, on_submit)` in `lua/alex/gh_reader.lua`:
  - Open a horizontal split (`split`) at the bottom, 10 lines tall
  - Create scratch buffer with `filetype=markdown`, first line = `"-- " .. hint .. " | <leader>s submit · <Esc><Esc> cancel --"`
  - Set `modifiable=true`; cursor starts at line 2
  - Store in `state.input_buf` / `state.input_win`
  - `<leader>s`: collect lines 2+ from buffer, join with `\n`, call `on_submit(body)`, close input window
  - `<Esc><Esc>` (mapped with `noremap`): close input window with no action
- [x] T024 [US3] Implement `post_comment(item, body, callback)` in `lua/alex/gh_reader.lua`:
  - If `item.kind == "issue"`: run `gh issue comment {n} -R {repo} --body {body}`
  - If `item.kind == "pr"`: run `gh pr comment {n} -R {repo} --body {body}`
  - On success: `callback(nil)` via `vim.schedule`; on error: `callback(err)`
- [x] T025 [US3] Wire `c` keybinding in `open_split()` (buffer-local): calls `open_input("Write comment", function(body) post_comment(state.item, body, function(err) ... end) end)`; on success shows `vim.notify("Comment posted")` and re-fetches + re-renders; on error shows `vim.notify(err, ERROR)`

**Checkpoint**: Open reader, press `c`, type text, `<leader>s` posts it. Reader refreshes showing new comment.

---

## Phase 6: User Story 4 — Approve / Review a PR (Priority: P2)

**Goal**: Press `a` in a PR reader to submit an approval, request-changes, or comment-only review.

**Independent Test**: Open a PR reader, press `a`, select "Approve", add optional body, submit — verify PR reader shows approved review state.

### Implementation

- [x] T026 [US4] Implement `submit_review(item, kind, body, callback)` in `lua/alex/gh_reader.lua`:
  - `kind = "approve"` → `gh pr review {n} -R {repo} --approve --body {body}`
  - `kind = "request_changes"` → `gh pr review {n} -R {repo} --request-changes --body {body}`
  - `kind = "comment"` → `gh pr review {n} -R {repo} --comment --body {body}`
  - On success/error: `callback(err)` via `vim.schedule`
- [x] T027 [US4] Wire `a` keybinding in `open_split()` (only active when `state.item.kind == "pr"`):
  - `vim.ui.select({"Approve", "Request Changes", "Comment Only", "Cancel"}, ...)` 
  - On non-cancel: `open_input("Review (" .. selection .. ")", function(body) submit_review(state.item, kind, body, ...) end)`
  - On success: `vim.notify("Review submitted")` + re-fetch + re-render
  - On error: `vim.notify(err, ERROR)`
  - On `kind="repo"` or issue: `a` does nothing (no keybinding registered)

**Checkpoint**: Open a PR reader, `a` → select type → write body → submit → review appears in reader header and reviews section.

---

## Phase 7: User Story 5 — Merge PR & Close Issue (Priority: P3)

**Goal**: Press `m` in a PR reader to merge, or `x` in an issue reader to close.

**Independent Test (merge)**: Open an open PR reader, press `m`, select "Squash and merge", confirm — PR state changes to MERGED in the reader. **Independent Test (close)**: Open an open issue reader, press `x`, confirm — issue state changes to CLOSED.

### Implementation

- [x] T028 [US5] Implement `merge_pr(item, method, callback)` in `lua/alex/gh_reader.lua`:
  - `method = "merge"` → `gh pr merge {n} -R {repo} --merge`
  - `method = "squash"` → `gh pr merge {n} -R {repo} --squash`
  - `method = "rebase"` → `gh pr merge {n} -R {repo} --rebase`
  - On success/error: `callback(err)` via `vim.schedule`
- [x] T029 [US5] Wire `m` keybinding in `open_split()` (only for `kind="pr"`):
  - If `state.data.mergeable ~= "MERGEABLE"`: show `vim.notify("Cannot merge: " .. state.data.mergeable, WARN)` and return
  - Else: `vim.ui.select({"Merge commit", "Squash and merge", "Rebase and merge", "Cancel"}, ...)`
  - On non-cancel: `vim.ui.input({prompt = "Merge #N into " .. base_ref .. "? (yes/no): "}, function(ans) if ans == "yes" then merge_pr(...) end end)`
  - On success: `vim.notify("PR #N merged")` + re-fetch + re-render
- [x] T030 [US5] Implement `close_issue(item, callback)` in `lua/alex/gh_reader.lua`: run `gh issue close {n} -R {repo}`; on success/error: `callback(err)`
- [x] T031 [US5] Wire `x` keybinding in `open_split()` (only for `kind="issue"`):
  - `vim.ui.input({prompt = "Close issue #N? (yes/no): "}, function(ans) if ans == "yes" then close_issue(state.item, ...) end end)`
  - On success: `vim.notify("Issue #N closed")` + re-fetch + re-render + invalidate dashboard cache (`vim.uv.fs_unlink(dashboard_cache_path)`)

**Checkpoint**: `m` merges a mergeable PR (state → MERGED). `x` closes an open issue (state → CLOSED). Dashboard cache invalidated after both actions so next `<leader>gh` shows updated state.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [x] T032 [P] Handle `vim.NIL` guards throughout `lua/alex/gh_reader.lua`: wherever a fetched field (body, bio, labels, reviews, ci_checks) is accessed, use `type(x) == "table"` or `x and x ~= vim.NIL` guards — same pattern as the `primaryLanguage` fix in `github_dashboard.lua`
- [x] T033 [P] Add inline error display in `render_issue` and `render_pr`: if fetch callback returns `err`, write a single error line `"  ✗ " .. err` to the buffer instead of crashing
- [x] T034 Add `r` reload keybinding behavior: store `state.item` on open; `r` calls the appropriate `fetch_issue`/`fetch_pr` based on `state.item.kind`, then re-renders
- [x] T035 Smoke test the full flow: dashboard → `<CR>` issue → read → `c` comment → `q`; dashboard → `<CR>` PR → read → `a` approve → `m` merge attempt on conflicting PR (expect error) → `q`

**Checkpoint**: All user stories work end-to-end, errors display cleanly, no crashes on nil/vim.NIL fields.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational)**: Depends on Phase 1
- **Phase 3 (US1 — Issue Reader)**: Depends on Phase 2 — this is the MVP
- **Phase 4 (US2 — PR Reader)**: Depends on Phase 2; can parallelize with Phase 3 (different render functions)
- **Phase 5 (US3 — Comment)**: Depends on Phases 3+4 (needs open reader); `open_input` is shared
- **Phase 6 (US4 — Review)**: Depends on Phase 4 (PR-only); can parallelize with Phase 5
- **Phase 7 (US5 — Merge/Close)**: Depends on Phases 3+4; can parallelize with Phases 5+6
- **Phase 8 (Polish)**: Depends on all story phases

### Within Each Story

- Fetch function before render function
- Render function before `M.open` wiring
- Keybinding registration in `open_split` — happens once for all stories

### Parallel Opportunities

Within Phase 3+4 (both P1):
```
T012 fetch_issue     ─┐
T018 fetch_pr        ─┼─ independent functions, different data shapes
T013 render_header   ─┘
```

Within Phase 5+6+7 (all action phases):
```
T023 open_input      (shared, implement once)
T026 submit_review   ─┐
T028 merge_pr        ─┼─ independent action functions
T030 close_issue     ─┘
```

---

## Implementation Strategy

### MVP (Phases 1–3, US1 only — 17 tasks)

1. Phase 1: Setup + dashboard patch
2. Phase 2: Foundational helpers
3. Phase 3: Issue reader
4. **VALIDATE**: `<leader>gh` → `<CR>` on issue → full content visible → `q` closes

### Incremental Delivery

1. Phases 1–3 → Read issues ✓
2. + Phase 4 → Read PRs ✓
3. + Phase 5 → Post comments ✓
4. + Phase 6 → Approve/review PRs ✓
5. + Phase 7 → Merge + close ✓ (100% browser-free)
6. + Phase 8 → Polish ✓

---

## Notes

- New file: `lua/alex/gh_reader.lua`
- Modified files: `lua/alex/github_dashboard.lua` (T003–T005), `lua/alex/init.lua` (T002)
- No new plugin dependencies — `render-markdown.nvim` activates automatically on `filetype=markdown`
- **Commit and push after each completed phase** (Constitution IV)
- `vim.NIL` guards are critical — `gh` returns JSON `null` for many optional fields (same bug as `primaryLanguage` in 001)
