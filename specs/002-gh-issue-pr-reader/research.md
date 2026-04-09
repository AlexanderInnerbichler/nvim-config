# Research: GitHub Issue & PR Inline Reader

**Branch**: `002-gh-issue-pr-reader` | **Date**: 2026-04-09

---

## Decision 1: Data Source for Issue/PR Detail

**Decision**: Use `gh issue view` and `gh pr view` with `--json` flag.

**Rationale**: These are the highest-level `gh` commands that return structured, complete data in one call — including nested comments, reviews, and CI checks. Tested and confirmed working:

```bash
gh issue view 1 -R owner/repo --json number,title,state,body,labels,author,comments,createdAt
gh pr view 25 -R owner/repo --json number,title,state,body,author,headRefName,baseRefName,reviews,statusCheckRollup,comments,createdAt,isDraft,mergeable
```

Confirmed fields available on `gh pr view`:
- `reviews` — array of `{author, state, body, submittedAt}`
- `statusCheckRollup` — array of CI checks (empty if none)
- `comments` — inline/review comments (distinct from review thread)
- `mergeable` — `"MERGEABLE"` / `"CONFLICTING"` / `"UNKNOWN"`

**Alternatives considered**:
- `gh api repos/{owner}/{repo}/issues/{n}` — lower-level, requires separate calls for comments, less ergonomic
- Direct GitHub REST API — requires managing tokens manually

---

## Decision 2: Action Commands

**Decision**: Use native `gh` CLI action commands — no REST API calls for mutations.

**Commands confirmed available**:

| Action | Command |
|--------|---------|
| Post issue comment | `gh issue comment {n} -R {repo} --body "{text}"` |
| Post PR comment | `gh pr comment {n} -R {repo} --body "{text}"` |
| Approve PR | `gh pr review {n} -R {repo} --approve --body "{text}"` |
| Request changes | `gh pr review {n} -R {repo} --request-changes --body "{text}"` |
| Merge PR | `gh pr merge {n} -R {repo} --merge/--squash/--rebase` |
| Close issue | `gh issue close {n} -R {repo}` |
| Reopen issue | `gh issue reopen {n} -R {repo}` |

For all write operations, input text is passed via `--body` flag (safe via `vim.system` array — no shell escaping needed).

**Alternatives considered**:
- Piping from stdin with `-F -` — works but adds complexity vs `--body`
- Opening a temp file — unnecessary when `vim.system` handles multi-line strings in args

---

## Decision 3: Markdown Rendering

**Decision**: Set reader buffer `filetype = "markdown"` and rely on the already-installed `render-markdown.nvim` plugin.

**Rationale**: `render-markdown.nvim` is already in `packer.lua`. It activates automatically on `filetype=markdown` buffers, rendering code blocks, headers, bold/italic, and lists. Zero extra configuration needed.

**Image handling**: Images in markdown (`![alt](url)`) will appear as raw text since render-markdown.nvim doesn't fetch images — this satisfies FR-013 (show as-is / placeholder).

**Alternatives considered**:
- Manual ANSI-style formatting — fragile, unmaintainable
- `glow` CLI piped to buffer — external dependency, not installed

---

## Decision 4: Reader UI Layout

**Decision**: Vertical split (right side, 80 columns) rather than a floating window.

**Rationale**: Issues and PRs have long content — a full-height split is better for scrolling than a floating window. The dashboard is already a floating window; adding a nested float would be confusing. The split can be closed with `q` without disturbing the dashboard.

**Layout**:
```
┌──────────────────┬────────────────────────────┐
│  Editor / other  │  GH Reader (80 cols)        │
│                  │  Title, metadata header     │
│                  │  ─────────────────────────  │
│                  │  Body (markdown rendered)   │
│                  │  ─────────────────────────  │
│                  │  Comments / Reviews         │
└──────────────────┴────────────────────────────┘
```

**Alternatives considered**:
- Floating window — better for quick views but poor for long content
- Full-screen takeover — too disruptive, lose editor context

---

## Decision 5: Comment / Review Input Flow

**Decision**: Open a scratch buffer in a horizontal split for composing text, then submit on `:wq` / `<leader>s`.

**Flow**:
1. User presses `c` (comment) or `a` (review) in the reader
2. A small horizontal split (8 lines) opens at the bottom with `filetype=markdown`
3. User types their comment/review body
4. `<leader>s` or `:wq` submits → runs `gh` command async → closes input buffer → refreshes reader
5. `<Esc><Esc>` or `:q!` cancels → closes input buffer, no post

**Rationale**: Familiar Vim editing workflow. Markdown filetype gives syntax highlighting while typing. No popup/prompt needed.

**Alternatives considered**:
- `vim.ui.input` — limited to single-line input, unsuitable for multi-line comments
- External `$EDITOR` — process management complexity

---

## Decision 6: Integration with Existing Dashboard

**Decision**: Extend the `items` table in `github_dashboard.lua` to carry `kind`, `number`, and `repo` fields alongside the existing `url`. Change `open_url_at_cursor` to dispatch to the reader module for `issue` and `pr` kinds, and keep `xdg-open` for `repo` kind.

**Changes to `github_dashboard.lua`**:
- `render_prs`: add `kind="pr"`, `number=pr.number`, `repo=pr.repo` to each item
- `render_issues`: add `kind="issue"`, `number=iss.number`, `repo=iss.repo` to each item
- `render_repos`: add `kind="repo"` (no number)
- `open_url_at_cursor`: if `item.kind == "issue" or item.kind == "pr"` → call reader; else `xdg-open`

**Rationale**: Minimal change to the existing module — just richer metadata on already-existing items.

---

## Decision 7: Module Structure

**Decision**: Single new file `lua/alex/gh_reader.lua` with `M.open(item)` public interface.

**Pattern**: Same as `plan_viewer.lua` and `github_dashboard.lua` — module table, single file, no subdirectory.

**`item` shape passed from dashboard**:
```lua
{ kind = "issue"|"pr", number = 42, repo = "owner/repo", url = "..." }
```

---

## APIs Verified

| Data | Command | Tested |
|------|---------|--------|
| Issue full detail + comments | `gh issue view N -R repo --json ...` | ✅ |
| PR full detail + reviews + CI | `gh pr view N -R repo --json ...` | ✅ |
| Post issue comment | `gh issue comment N -R repo --body "..."` | ✅ (help confirmed) |
| Post PR comment | `gh pr comment N -R repo --body "..."` | ✅ (help confirmed) |
| PR review (approve/reject) | `gh pr review N -R repo --approve --body "..."` | ✅ (help confirmed) |
| Merge PR | `gh pr merge N -R repo --squash/--merge/--rebase` | ✅ (help confirmed) |
| Close issue | `gh issue close N -R repo` | ✅ (help confirmed) |
