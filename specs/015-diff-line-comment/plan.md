# Implementation Plan: PR Diff Inline Line Comments

**Branch**: `015-diff-line-comment` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/015-diff-line-comment/spec.md` (Issue #6 comment)

## Summary

Extend the diff popup (014) so that selecting lines in Visual mode and pressing `c` opens the existing `M.open_input` prompt and posts the comment to GitHub as an inline PR review comment via `gh api`. The diff render loop is extended to build a `line_map` (buffer_line → `{path, line, side}`) so the keymap handler knows which file and line number the cursor is on.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev
**Primary Dependencies**: `gh` CLI v2.45.0, `gh api` (REST), `gh_reader.lua` (existing `open_popup`, `write_buf`, `M.open_input`)
**Storage**: N/A — comment posted immediately, not cached
**Testing**: Manual smoke test
**Target Platform**: Neovim on Linux (WSL2)
**Performance Goals**: `c` keymap opens input immediately; comment posts within 3 seconds
**Constraints**: Depends on 014 (diff viewer) being merged; no new popup infrastructure; reuse `M.open_input`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | PASS | line_map built in existing render loop, no new abstractions |
| II. Python Type Annotations | N/A | Lua project |
| III. No Silent Exception Swallowing | PASS | All API errors surface via notify |
| IV. Logical Commits | PASS | Commit after each phase |
| V. Backend–Frontend Separation | N/A | Lua project |
| VI. Branch Lifecycle | PASS | Merge + delete immediately after smoke test |

## Project Structure

### Source Code Changes

```text
lua/alex/
└── gh_reader.lua  ← MODIFY only: add fetch_head_sha, post_review_comment,
                      extend render_diff_content with line_map output,
                      extend M.open_diff with parallel fetches + visual keymap
```

## Key Research Findings

**GitHub API for inline review comments** — no `gh` CLI subcommand; must use REST directly:
```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  -f body='...' \
  -f commit_id='HEAD_SHA' \
  -f path='src/file.lua' \
  -F line=42 \
  -f side='RIGHT'   # RIGHT = new file (+/context), LEFT = old file (-)
```
`commit_id` is the PR's head SHA — must be fetched via `gh pr view {n} --repo {r} --json headRefOid --jq '.headRefOid'`.

**Visual selection**: `vim.fn.getpos("'<")[2]` / `vim.fn.getpos("'>")[2]` — 1-indexed, reliable in keymap handlers.

**line_map key**: 0-indexed buffer line (subtract 1 from getpos result).

## Implementation Design

### 1. `fetch_head_sha(number, repo, callback)` — new private function

```lua
local function fetch_head_sha(number, repo, callback)
  vim.system(
    { "gh", "pr", "view", tostring(number), "--repo", repo,
      "--json", "headRefOid", "--jq", ".headRefOid" },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then callback(result.stderr or "gh error", nil)
        else callback(nil, vim.trim(result.stdout or "")) end
      end)
    end
  )
end
```

### 2. `post_review_comment(number, repo, sha, path, line, side, body, callback)` — new private function

```lua
local function post_review_comment(number, repo, sha, path, line, side, body, callback)
  vim.system(
    { "gh", "api", "repos/" .. repo .. "/pulls/" .. tostring(number) .. "/comments",
      "-f", "body=" .. body,
      "-f", "commit_id=" .. sha,
      "-f", "path=" .. path,
      "-F", "line=" .. tostring(line),
      "-f", "side=" .. side },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then callback(result.stderr or "api error")
        else callback(nil) end
      end)
    end
  )
end
```

### 3. Extend `render_diff_content` — add optional `line_map` output param

Signature change: `render_diff_content(lines, hl_specs, number, repo, diff_text, err, line_map)`

Inside the diff line iteration loop, track the current file path, new-file line counter, and old-file line counter. When `line_map` is non-nil, record commentable lines:

```lua
-- state tracked across the loop:
local cur_path    = nil
local new_line_n  = 0
local old_line_n  = 0

-- for each diff line after header/err checks:
for raw_line in diff_text:gmatch("[^\n]+") do
  table.insert(lines, raw_line)
  local buf_ln = #lines - 1

  if raw_line:match("^diff %-%-git") then
    cur_path   = raw_line:match(" b/(.+)$")
    new_line_n = 0; old_line_n = 0
    -- apply no highlight (plain file header)
  elseif raw_line:match("^@@") then
    local ns, nn = raw_line:match("@@ %-(%d+),?%d* %+(%d+),?%d* @@")
    old_line_n = tonumber(ns or 0) - 1
    new_line_n = tonumber(nn or 0) - 1
    table.insert(hl_specs, { hl = "GhDiffHunk", line = buf_ln, col_s = 0, col_e = -1 })
  elseif raw_line:sub(1,1) == "+" and not raw_line:match("^%+%+%+") then
    new_line_n = new_line_n + 1
    table.insert(hl_specs, { hl = "GhDiffAdd", line = buf_ln, col_s = 0, col_e = -1 })
    if line_map and cur_path then
      line_map[buf_ln] = { path = cur_path, line = new_line_n, side = "RIGHT" }
    end
  elseif raw_line:sub(1,1) == "-" and not raw_line:match("^%-%-%-") then
    old_line_n = old_line_n + 1
    table.insert(hl_specs, { hl = "GhDiffDel", line = buf_ln, col_s = 0, col_e = -1 })
    if line_map and cur_path then
      line_map[buf_ln] = { path = cur_path, line = old_line_n, side = "LEFT" }
    end
  elseif raw_line:sub(1,1) == " " then
    new_line_n = new_line_n + 1; old_line_n = old_line_n + 1
    if line_map and cur_path then
      line_map[buf_ln] = { path = cur_path, line = new_line_n, side = "RIGHT" }
    end
  end
end
```

### 4. Extend `M.open_diff` — parallel fetches + state + visual keymap

```lua
M.open_diff = function(item)
  open_popup(string.format(" PR #%d diff ", item.number), " c comment · q close ")
  vim.wo[state.win].wrap = false

  -- reset diff-specific state
  state.diff_item    = item
  state.diff_line_map = {}
  state.diff_head_sha = nil

  write_buf({ "", "  Loading diff…" }, {})

  -- visual keymap: c to comment on selected line
  vim.keymap.set("v", "c", function()
    local end_ln = vim.fn.getpos("'>")[2] - 1  -- 0-indexed
    local info   = state.diff_line_map[end_ln]
    if not info then
      vim.cmd("normal! \27")
      vim.notify("Cannot comment on this line", vim.log.levels.INFO)
      return
    end
    if not state.diff_head_sha or state.diff_head_sha == "" then
      vim.cmd("normal! \27")
      vim.notify("Still loading, please try again", vim.log.levels.INFO)
      return
    end
    vim.cmd("normal! \27")  -- exit visual mode before opening input
    M.open_input("Review comment  |  <C-s> submit  ·  <Esc><Esc> cancel", function(body)
      post_review_comment(
        state.diff_item.number, state.diff_item.repo,
        state.diff_head_sha, info.path, info.line, info.side,
        body, function(err)
          if err then
            vim.notify("Failed: " .. err:gsub("[\n\r]", " "), vim.log.levels.ERROR)
          else
            vim.notify("Review comment posted", vim.log.levels.INFO)
          end
        end
      )
    end)
  end, { buffer = state.buf, nowait = true, silent = true })

  -- parallel: fetch SHA + fetch diff; render after both complete
  local pending   = 2
  local diff_text, diff_err, head_sha

  local function on_both()
    pending = pending - 1
    if pending > 0 then return end
    state.diff_head_sha = head_sha or ""
    local lines, hl_specs = {}, {}
    table.insert(lines, "")
    render_diff_content(lines, hl_specs, item.number, item.repo,
                        diff_text or "", diff_err, state.diff_line_map)
    table.insert(lines, "")
    write_buf(lines, hl_specs)
  end

  fetch_diff(item.number, item.repo, function(err, text)
    diff_err, diff_text = err, text; on_both()
  end)
  fetch_head_sha(item.number, item.repo, function(_, sha)
    head_sha = sha; on_both()
  end)
end
```

### 5. Add `diff_item`, `diff_line_map`, `diff_head_sha` to `state`

```lua
local state = {
  buf            = nil,
  win            = nil,
  item           = nil,
  data           = nil,
  input_buf      = nil,
  input_win      = nil,
  diff_item      = nil,   -- ← NEW
  diff_line_map  = {},    -- ← NEW
  diff_head_sha  = nil,   -- ← NEW
}
```

### Footer update

Change footer from `" q close "` to `" c comment · q close "` so the user knows the keymap exists.

## Verification

1. Open diff popup → Visual select a `+` line → `c` → input opens → submit → comment appears on GitHub attached to correct line
2. Visual select a `-` line → comment posts with `side=LEFT` on old file line
3. Visual select a `@@` hunk header or file header → message "Cannot comment on this line"
4. `<Esc><Esc>` in input → closes without posting
5. Network error during post → error notification, popup stays open
6. `q` from diff still closes popup (no regression)
7. `<CR>` on PR row in dashboard still opens PR description (no regression)
