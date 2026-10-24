# Research: PR Diff Viewer

## Decision: Reuse `gh_reader.lua` popup vs new module

**Decision**: Add `M.open_diff` to the existing `gh_reader.lua` and reuse `open_popup` + `write_buf`
**Rationale**: The reader already owns all popup window lifecycle, highlight application, and keymaps (`q`/`<Esc>` close). Creating a new module would duplicate ~100 lines of window management for no benefit. The diff is just another content type for the same popup.
**Alternatives considered**: New `gh_pr_diff.lua` standalone module — rejected; unnecessary duplication of `open_popup`/`write_buf`.

---

## Decision: `d` keymap scope — PR rows only

**Decision**: `d` activates only when the cursor is on a `kind="pr"` item; no-op on all other rows
**Rationale**: `open_diff_at_cursor()` iterates `state.items` and only matches `kind == "pr"`. On other rows it finds no match and returns silently. No notification is shown — consistent with how `<CR>` on separator lines silently does nothing.
**Alternatives considered**: Show a notification "no PR under cursor" — rejected; noisy, especially since `d` is a common navigation key in some Neovim workflows.

---

## Decision: Line-prefix highlighting (not TreeSitter/filetype)

**Decision**: Apply highlights in the Lua render loop by inspecting the first character of each line
**Rationale**: Unified diff format is simple — `+`/`-`/`@@` prefixes are unambiguous. Setting filetype to `diff` would pull in Neovim's built-in diff syntax which conflicts with our `GhReader*` colour scheme and can't be controlled. The per-line loop is 5 lines of code.
**Alternatives considered**: `vim.bo[buf].filetype = "diff"` — rejected; can't control which highlight groups are used, conflicts with our theme.

---

## Decision: `wrap = false` for diff view

**Decision**: Disable line wrapping in the diff popup window
**Rationale**: Long diff lines (e.g., minified JS changes) wrap confusingly and destroy the visual structure of the patch. The reader uses `wrap = true` for prose (PR descriptions, READMEs) but diff is code — it reads better unwrapped with horizontal scrolling.
**Alternatives considered**: Keep `wrap = true` like other reader views — rejected; diffs are not prose and wrapping breaks the visual alignment.

---

## Decision: `gh pr diff {number} --repo {owner/repo}` command

**Decision**: Use `gh pr diff <number> --repo <owner/repo>` to fetch the unified diff
**Rationale**: This is the standard `gh` CLI command for PR diffs, outputs unified patch to stdout. The `--repo` flag is required when running outside the repo directory (which is always the case here since cwd is `~/.config/nvim`). `item.number` and `item.repo` are already stored in the dashboard PR items.
**Alternatives considered**: GitHub REST API `GET /repos/{owner}/{repo}/pulls/{number}/files` — returns JSON with per-file patches, more complex to reassemble into a unified diff; not worth the extra parsing.
