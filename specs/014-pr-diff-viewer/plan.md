# Implementation Plan: PR Diff Viewer

**Branch**: `014-pr-diff-viewer` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/014-pr-diff-viewer/spec.md` (GitHub Issue #6)

## Summary

Add a `d` keymap to the dashboard that opens the full unified diff of the PR under the cursor in the existing reader popup. Lines prefixed with `+` are highlighted green, `-` red, `@@` blue. Reuses `open_popup` and `write_buf` from `gh_reader.lua`; adds three new diff highlight groups and a `M.open_diff(item)` entry point.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev
**Primary Dependencies**: `gh` CLI v2.45.0, `vim.system()` async, `gh_reader.lua` (existing `open_popup`, `write_buf`)
**Storage**: N/A — diff fetched fresh on each open
**Testing**: Manual smoke test
**Target Platform**: Neovim on Linux (WSL2)
**Performance Goals**: Loading state visible immediately; diff renders within 3 seconds
**Constraints**: Reuse reader popup infrastructure (no new window management); `gh pr diff` outputs unified patch to stdout

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | PASS | No new popup infrastructure; diff parsing is a tight loop with no abstractions |
| II. Python Type Annotations | N/A | Lua project |
| III. No Silent Exception Swallowing | PASS | Fetch errors surfaced in popup window |
| IV. Logical Commits | PASS | Commit after each phase |
| V. Backend–Frontend Separation | N/A | Lua project |
| VI. Branch Lifecycle | PASS | Merge + delete immediately after smoke test |

## Project Structure

### Source Code Changes

```text
lua/alex/
├── gh_reader.lua       ← MODIFY: add GhDiff* highlights, fetch_diff, render_diff_content, M.open_diff
└── github_dashboard.lua ← MODIFY: add `d` keymap + open_diff_at_cursor(), add title to PR items
```

## Implementation Design

### Changes to `lua/alex/gh_reader.lua`

**New highlight groups** (alongside existing `GhReader*` groups at top of file):
```lua
vim.api.nvim_set_hl(0, "GhDiffAdd",  { fg = "#98c379", bold = false })  -- green
vim.api.nvim_set_hl(0, "GhDiffDel",  { fg = "#e06c75", bold = false })  -- red
vim.api.nvim_set_hl(0, "GhDiffHunk", { fg = "#61afef", bold = false })  -- blue
```

**New private function `fetch_diff(number, repo, callback)`**:
```lua
local function fetch_diff(number, repo, callback)
  vim.system(
    { "gh", "pr", "diff", tostring(number), "--repo", repo },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          callback(result.stderr or "gh error", nil)
        else
          callback(nil, result.stdout or "")
        end
      end)
    end
  )
end
```

**New private function `render_diff_content(lines, hl_specs, number, repo, diff_text, err)`**:
```lua
local function render_diff_content(lines, hl_specs, number, repo, diff_text, err)
  -- breadcrumb
  local crumb_prefix = "  GitHub Dashboard  ›  "
  local crumb        = crumb_prefix .. repo .. "  ›  PR #" .. number .. " diff"
  table.insert(lines, crumb)
  table.insert(hl_specs, { hl = "GhReaderBreadcrumb", line = #lines-1, col_s = 0, col_e = #crumb_prefix })
  table.insert(hl_specs, { hl = "GhReaderTitle",      line = #lines-1, col_s = #crumb_prefix, col_e = -1 })
  table.insert(lines, "")

  if err then
    local msg = "  ✗ " .. err:gsub("[\n\r]", " ")
    table.insert(lines, msg)
    table.insert(hl_specs, { hl = "GhReaderError", line = #lines-1, col_s = 0, col_e = #msg })
    return
  end
  if diff_text == "" then
    local msg = "  (no diff)"
    table.insert(lines, msg)
    table.insert(hl_specs, { hl = "GhReaderEmpty", line = #lines-1, col_s = 0, col_e = #msg })
    return
  end

  for line in diff_text:gmatch("[^\n]+") do
    table.insert(lines, line)
    local ln = #lines - 1
    if line:match("^@@") then
      table.insert(hl_specs, { hl = "GhDiffHunk", line = ln, col_s = 0, col_e = -1 })
    elseif line:sub(1,1) == "+" and not line:match("^%+%+%+") then
      table.insert(hl_specs, { hl = "GhDiffAdd",  line = ln, col_s = 0, col_e = -1 })
    elseif line:sub(1,1) == "-" and not line:match("^%-%-%-") then
      table.insert(hl_specs, { hl = "GhDiffDel",  line = ln, col_s = 0, col_e = -1 })
    end
  end
end
```

**New public entry point `M.open_diff(item)`**:
```lua
M.open_diff = function(item)
  local title  = string.format(" PR #%d diff ", item.number)
  local footer = " q close "
  open_popup(title, footer)
  vim.wo[state.win].wrap = false  -- diffs read better without wrapping

  -- loading state
  local loading = { "  Loading diff…" }
  write_buf(loading, {})

  fetch_diff(item.number, item.repo, function(err, diff_text)
    local lines, hl_specs = {}, {}
    table.insert(lines, "")
    render_diff_content(lines, hl_specs, item.number, item.repo, diff_text or "", err)
    table.insert(lines, "")
    write_buf(lines, hl_specs)
  end)
end
```

### Changes to `lua/alex/github_dashboard.lua`

**`render_prs` — add `title` to items** (so breadcrumb can use it if needed in future; harmless now):
```lua
table.insert(items, { line = #lines, url = pr.url, kind = "pr",
                      number = pr.number, repo = pr.repo, title = pr.title })
```

**New function `open_diff_at_cursor()`**:
```lua
local function open_diff_at_cursor()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
  local cur_line = vim.api.nvim_win_get_cursor(state.win)[1] - 1
  for _, item in ipairs(state.items) do
    if item.line == cur_line and item.kind == "pr" then
      require("alex.gh_reader").open_diff(item)
      return
    end
  end
end
```

**Add keymap** (alongside existing `buf_map("<CR>", ...)` calls):
```lua
buf_map("d", open_diff_at_cursor)
```

## Verification

1. Dashboard open → cursor on a PR row → `d` → loading state appears → diff renders with green/red/blue lines
2. Non-PR row → `d` → nothing happens
3. Diff popup → `q` → returns to dashboard cleanly
4. Empty diff (PR with no changes) → popup shows "(no diff)"
5. `gh` error (bad network) → popup shows error message, no crash
6. `<CR>` on PR row → still opens PR description (no regression)
