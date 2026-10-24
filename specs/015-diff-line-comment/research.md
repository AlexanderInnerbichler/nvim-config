# Research: PR Diff Inline Line Comments

## Decision: `gh api` REST directly (not `gh pr review` or `gh pr comment`)

**Decision**: Use `gh api repos/{owner}/{repo}/pulls/{number}/comments` with `-f` flags
**Rationale**: No `gh` CLI subcommand wraps inline review comments. `gh pr comment` posts general (non-code) comments. `gh pr review` posts a review with a body but no per-line anchoring. The REST endpoint `pulls/{n}/comments` is the only path for line-specific review comments.
**Alternatives considered**: `gh pr review --body` — only posts a general review text, not anchored to a line.

---

## Decision: `line` + `side` API params (not deprecated `position`)

**Decision**: Use `line` (new-file line number for RIGHT, old-file line number for LEFT) and `side` ("RIGHT" or "LEFT")
**Rationale**: GitHub's `position` param (counting from `@@` header) is deprecated. The `line`+`side` approach is the modern API, more intuitive to compute from the diff, and does not require counting `@@` header lines.
**Alternatives considered**: `position` (deprecated diff-position counting from `@@`) — rejected.

---

## Decision: Fetch head SHA in parallel with diff (not from `state.data`)

**Decision**: `fetch_head_sha` runs in parallel with `fetch_diff` inside `M.open_diff`; result stored in `state.diff_head_sha`
**Rationale**: `M.open_diff` can be called directly from the dashboard without the PR description having been opened first. `state.data` (populated by `M.open(item)`) may be nil or stale. Fetching the SHA independently inside `M.open_diff` guarantees correctness regardless of call path.
**Alternatives considered**: Add `headRefOid` to `fetch_pr` GraphQL query and use `state.data.head_ref_oid` — viable when PR description is open, but unreliable when diff is opened directly from dashboard.

---

## Decision: Anchor comment to end line of visual selection

**Decision**: Use `vim.fn.getpos("'>")[2]` (end of visual selection, 1-indexed) as the anchor line
**Rationale**: GitHub's inline review comment model attaches to a single line even for multi-line selections. Using the end line matches what IDEs (VS Code, IntelliJ) do with multi-line selections. `vim.fn.getpos("'>")` is reliable and 1-indexed.
**Alternatives considered**: Use start line `'<` — less intuitive; the "highlighted context" ends at the last line.

---

## Decision: line_map built inside `render_diff_content` via optional output param

**Decision**: Add optional 7th param `line_map` to `render_diff_content`; populate it as the render loop processes lines
**Rationale**: The render loop already iterates every diff line tracking highlights. Adding line_map population there costs ~4 extra lines and avoids a second pass over the diff text. When `line_map` is nil (future callers that don't need it), behaviour is identical.
**Alternatives considered**: Parse diff text separately in `M.open_diff` — duplicates the diff-line iteration logic.

---

## Decision: `c` keymap in Visual mode only on diff buffer

**Decision**: `vim.keymap.set("v", "c", ..., { buffer = state.buf })` — scoped to the reader buffer, Visual mode only
**Rationale**: `c` in Normal mode has standard Neovim meaning (change); we must not shadow it. In Visual mode inside this floating buffer, `c` is unused and a natural fit for "comment". The buffer-local scope prevents leaking outside the diff popup.
**Alternatives considered**: `<leader>c` — less ergonomic; requires two keys. `C` (shift) — unusual for a confirm-style action.
