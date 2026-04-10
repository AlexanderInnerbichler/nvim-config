# UI Contract: GitHub Issue & PR Inline Reader

**Branch**: `002-gh-issue-pr-reader` | **Date**: 2026-04-09

---

## Module Interface (`alex.gh_reader`)

```lua
local M = require("alex.gh_reader")

M.open(item)    -- Open reader for an issue or PR item from the dashboard
M.setup()       -- Register highlights (called once from init.lua)
```

`item` shape: `{ kind = "issue"|"pr", number = N, repo = "owner/repo", url = "..." }`

---

## Dashboard Integration (`alex.github_dashboard`)

Changes to `github_dashboard.lua`:

1. Items for issues/PRs gain 3 new fields:
   ```lua
   { line = N, url = "...", kind = "issue"|"pr", number = 42, repo = "owner/repo" }
   ```
2. `open_url_at_cursor()` dispatches based on `item.kind`:
   ```lua
   if item.kind == "issue" or item.kind == "pr" then
     require("alex.gh_reader").open(item)
   else
     vim.system({ "xdg-open", item.url })
   end
   ```

---

## Reader Window

- **Layout**: Vertical split on the right, 80 columns wide
- **Buffer**: `nomodifiable`, `filetype = "markdown"`, `buftype = "nofile"`, `bufhidden = "wipe"`
- **Window options**: `number = false`, `signcolumn = "no"`, `wrap = true`, `linebreak = true`, `cursorline = false`

---

## Reader Keybindings (buffer-local)

| Key | Action | Availability |
|-----|--------|-------------|
| `q` / `<Esc>` | Close reader | Always |
| `r` | Reload (re-fetch from GitHub) | Always |
| `c` | Open comment input buffer | When state is OPEN |
| `a` | Open review/approve prompt | PR only, OPEN state |
| `m` | Open merge confirmation prompt | PR only, OPEN + MERGEABLE |
| `x` | Close issue confirmation | Issue only, OPEN state |

---

## Comment Input Flow

1. `c` pressed in reader → horizontal split opens at bottom (10 lines high)
2. Buffer has `filetype = "markdown"`, first line is a read-only hint comment
3. `<leader>s` → submit: reads lines 2+, calls `gh issue/pr comment`, closes input, refreshes reader
4. `<Esc><Esc>` (two quick Escapes) or `:q!` → cancel: closes input buffer, no action

---

## Review Input Flow (PR only)

1. `a` pressed → `vim.ui.select` prompt: `{ "Approve", "Request Changes", "Comment Only" }`
2. After selection → same comment input buffer opens (pre-labeled with review type)
3. `<leader>s` → submits `gh pr review --approve/--request-changes/--comment`
4. On success: reader refreshes showing new review state

---

## Merge Confirmation Flow (PR only)

1. `m` pressed → `vim.ui.select` prompt: `{ "Merge commit", "Squash and merge", "Rebase and merge", "Cancel" }`
2. If conflicting: instead shows error inline, no prompt
3. After method selection → `vim.ui.input` confirms: `"Merge #N into master? (yes/no)"`
4. On confirm: runs `gh pr merge N -R repo --merge/--squash/--rebase` async
5. On success: reader updates to show `MERGED` state

---

## Close Issue Confirmation Flow

1. `x` pressed → `vim.ui.input`: `"Close issue #N? (yes/no)"`
2. On "yes": runs `gh issue close N -R repo` async
3. On success: reader updates to show `CLOSED` state

---

## Error Display

Errors shown as a single-line notification at the bottom of the reader buffer, not as popups:

```
  ✗ Error: merge conflict — resolve conflicts before merging
```

For network/permission errors: `vim.notify(msg, vim.log.levels.ERROR)`

---

## Highlight Groups

| Group | Color | Usage |
|-------|-------|-------|
| `GhReaderTitle` | `#7fc8f8` bold | Issue/PR title |
| `GhReaderMeta` | `#4b5263` | Author, date, labels |
| `GhReaderState` | `#a3be8c` (open) / `#e06c75` (closed) / `#b48ead` (merged) | State badge |
| `GhReaderSection` | `#88c0d0` bold | Section headers (Comments, Reviews) |
| `GhReaderSep` | `#3b4048` | Separator lines |
| `GhCiPass` | `#a3be8c` | ✓ CI check |
| `GhCiFail` | `#e06c75` | ✗ CI check |
| `GhCiPending` | `#e5c07b` | ⠋ CI check |
| `GhReviewApproved` | `#a3be8c` | ✓ reviewer |
| `GhReviewChanges` | `#e06c75` | ✗ reviewer |
