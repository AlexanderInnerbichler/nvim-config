# Research: PR Review Comments + Keybind Hints

## Decision: `gh api REST` for review comments (not `gh pr view --json`)

**Decision**: Fetch inline review comments via `gh api repos/{repo}/pulls/{n}/comments`
**Rationale**: `gh pr view --json` does not expose `reviewComments` as a field. The `comments` field it does expose is general PR comments only. The REST endpoint is the same one used to POST review comments (feature 015) so we already have auth wired up.
**Alternatives considered**: GraphQL `reviewThreads` traversal — more complex and not needed for read-only display.

---

## Decision: Parallel fan-out in M.open for PR kind (pending=2)

**Decision**: Run `fetch_pr` and `fetch_review_comments` in parallel; render only after both complete
**Rationale**: Same pattern already used in `M.open_diff` (features 014/015). Total load time is bounded by the slower of the two calls, not their sum. `fetch_pr` returns quickly; review comments fetch is typically fast too.
**Alternatives considered**: Sequential fetch (fetch PR first, then review comments) — simpler but adds latency.

---

## Decision: `render_pr(data, review_comments)` — add optional 2nd param

**Decision**: Extend `render_pr` signature with an optional `review_comments` table; add `render_review_comments_section` after `render_comments_section`
**Rationale**: Mirrors the existing `render_reviews_section` / `render_comments_section` pattern exactly. When `review_comments` is nil or empty, the section is omitted. No behavior change for existing callers.
**Alternatives considered**: Separate render function called from `M.open` — creates indirection without benefit.

---

## Decision: `d` keymap added to `register_keymaps()` in gh_reader.lua

**Decision**: Add `bmap("d", ...)` in `register_keymaps()` — calls `M.open_diff(state.item)` when `state.item.kind == "pr"`, silent no-op otherwise
**Rationale**: All other reader keymaps (`c`, `a`, `m`, `x`) are registered in `register_keymaps()`. Consistent placement. No new abstraction needed.
**Alternatives considered**: Register `d` only in `render_pr` — would need cleanup when navigating to issues; inconsistent with existing pattern.

---

## Decision: `CursorMoved` autocmd + `nvim_win_set_config` for dynamic dashboard footer

**Decision**: Register a `CursorMoved` autocmd on `state.buf` inside `open_win()`; call `nvim_win_set_config(state.win, { footer = ..., footer_pos = "center" })` to swap footer between PR-row and default variants
**Rationale**: Neovim's floating window footer IS mutable via `nvim_win_set_config`. `CursorMoved` fires on every line change — cheap O(n) scan over `state.items` (typically < 50 items). No additional state needed.
**Alternatives considered**: Always show `d diff` in the static footer — simpler but misleading when cursor is not on a PR; confuses users on non-PR rows.

---

## Review comment REST API schema

The `/repos/{owner}/{repo}/pulls/{n}/comments` response items contain:
- `user.login` — commenter username
- `path` — relative file path
- `line` — current line number (may be null if the line was deleted)
- `original_line` — line number at time of posting (fallback when `line` is null)
- `body` — comment text

jq extraction: `[.[] | {login: .user.login, path: .path, line: (.line // .original_line), body: .body}]`
