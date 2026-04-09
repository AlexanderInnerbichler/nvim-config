# Implementation Plan: GitHub Issue & PR Inline Reader

**Branch**: `002-gh-issue-pr-reader` | **Date**: 2026-04-09 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/002-gh-issue-pr-reader/spec.md`

## Summary

Build a Neovim vertical-split reader that opens issues and PRs directly from the existing GitHub dashboard. The reader fetches full detail via `gh` CLI, renders markdown using the already-installed `render-markdown.nvim`, and supports inline actions (comment, approve, merge, close). Minimal changes to the existing `github_dashboard.lua`; all new logic lives in a single new file `lua/alex/gh_reader.lua`.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI v2.45.0 (system), `render-markdown.nvim` (already installed), `vim.ui.select` / `vim.ui.input` (built-in), `vim.system()` (built-in async)  
**Storage**: No cache for reader (always fresh fetch; dashboard cache handles staleness)  
**Testing**: Manual smoke test — open dashboard, `<CR>` on issue, verify full content renders; post comment, verify thread updates  
**Target Platform**: Linux (WSL2), terminal Neovim  
**Project Type**: Neovim plugin module (single new Lua file + small edits to existing file)  
**Performance Goals**: Reader content visible within 3 seconds of `<CR>`  
**Constraints**: No new plugin dependencies; reuse existing `render-markdown.nvim`  
**Scale/Scope**: Single user, issues/PRs from any `gh`-accessible repo

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No unnecessary code | ✅ Pass | Single file, no speculative abstractions |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | `gh` errors shown inline; `pcall` only for JSON decode |
| IV. Logical commits, push after each task | ✅ Pass | Enforced by task workflow |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

**No constitution violations.**

## Project Structure

### Documentation (this feature)

```text
specs/002-gh-issue-pr-reader/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── contracts/
│   └── ui-contract.md   ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code Changes

```text
lua/alex/
├── gh_reader.lua           ← new file (all reader logic)
├── github_dashboard.lua    ← small edits: richer items, dispatch to reader
└── init.lua                ← add require("alex.gh_reader").setup()
```

## Implementation Phases

### Phase A — Dashboard Integration Patch

1. In `github_dashboard.lua`: add `kind`, `number`, `repo` fields to items in `render_prs` and `render_issues`
2. In `github_dashboard.lua`: update `open_url_at_cursor` to dispatch issues/PRs to `require("alex.gh_reader").open(item)`, keep `xdg-open` for repos
3. Create skeleton `lua/alex/gh_reader.lua`: `M.open(item)`, `M.setup()`, `return M`
4. Add `require("alex.gh_reader").setup()` to `lua/alex/init.lua`

**Commit**: `feat: gh-reader — dashboard dispatch patch + module skeleton`

### Phase B — Issue Reader (US1)

5. Implement `fetch_issue(item, callback)`: runs `gh issue view N -R repo --json ...`, maps to IssueDetail shape from data-model.md
6. Implement `open_split()`: creates 80-col right vsplit, `nomodifiable`, `filetype=markdown`, buffer-local keymaps
7. Implement `render_issue(data)`: writes header (title, state badge, meta, separator), body, comments section
8. Implement `setup_highlights()`: all `GhReader*` highlight groups from contracts/
9. Wire `M.open(item)` for `kind="issue"`: fetch → open_split → render

**Commit**: `feat: gh-reader — full issue reader with markdown rendering`

### Phase C — PR Reader (US2)

10. Implement `fetch_pr(item, callback)`: runs `gh pr view N -R repo --json ...`, maps to PRDetail shape
11. Extend `render_pr(data)`: adds PR-specific header rows (branch, CI checks, reviews) before body
12. Wire `M.open(item)` for `kind="pr"`

**Commit**: `feat: gh-reader — PR reader with CI status and review state`

### Phase D — Comment Posting (US3)

13. Implement `open_input(hint, on_submit)`: opens 10-line horizontal split with markdown filetype, hint on line 1
14. In input buffer: `<leader>s` calls `on_submit(body)`, `<Esc><Esc>` cancels
15. Implement `post_comment(item, body, callback)`: runs `gh issue/pr comment N -R repo --body "..."` async
16. Wire `c` keybinding in reader: calls `open_input` → `post_comment` → refresh reader

**Commit**: `feat: gh-reader — inline comment posting`

### Phase E — PR Review / Approve (US4)

17. Implement `submit_review(item, kind, body, callback)`:
    - `kind = "approve"` → `gh pr review N -R repo --approve --body "..."`
    - `kind = "request_changes"` → `gh pr review N -R repo --request-changes --body "..."`
    - `kind = "comment"` → `gh pr review N -R repo --comment --body "..."`
18. Wire `a` keybinding: `vim.ui.select` for review type → `open_input` for body → `submit_review` → refresh

**Commit**: `feat: gh-reader — PR review and approve`

### Phase F — Merge & Close (US5)

19. Implement `merge_pr(item, method, callback)`: runs `gh pr merge N -R repo --{method}` async
20. Wire `m` keybinding: check `data.mergeable == "MERGEABLE"`, show conflict error if not; else `vim.ui.select` for method → `vim.ui.input` confirm → `merge_pr` → refresh
21. Implement `close_issue(item, callback)`: runs `gh issue close N -R repo` async
22. Wire `x` keybinding: `vim.ui.input` confirm → `close_issue` → refresh + notify dashboard to invalidate cache

**Commit**: `feat: gh-reader — merge PR and close issue`

## Complexity Tracking

No constitution violations — table not required.
