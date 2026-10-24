# Implementation Plan: PR Review Comments + Keybind Hints

**Branch**: `016-pr-review-comments-hud` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/016-pr-review-comments-hud/spec.md`

## Summary

Three improvements to the Neovim GitHub dashboard:
1. **US1** — Inline review comments appear in the PR overview (parallel fetch via REST API, new render section)
2. **US2** — Dashboard footer dynamically shows `d diff` hint when cursor is on a PR row (`CursorMoved` autocmd)
3. **US3** — PR reader footer includes `d diff`; `d` keymap registered in `register_keymaps()` to open diff from the reader

## Technical Context

- **Language**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev
- **Primary files**: `lua/alex/gh_reader.lua`, `lua/alex/github_dashboard.lua`
- **Dependencies**: `gh` CLI v2.45.0, existing `fetch_pr`, `render_pr`, `register_keymaps`, `open_win`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | PASS | No new abstractions; reuses existing section-render pattern |
| II. Python Type Annotations | N/A | Lua project |
| III. No Silent Exception Swallowing | PASS | review comment fetch errors notified, don't block PR render |
| IV. Logical Commits | PASS | Commit after each user story |
| V. Backend–Frontend Separation | N/A | Lua project |
| VI. Branch Lifecycle | PASS | Merge + delete immediately after smoke test |

## Project Structure

### Source Code Changes

```text
lua/alex/
├── gh_reader.lua        ← MODIFY: fetch_review_comments, render_review_comments_section,
│                                   render_pr(+param), M.open fan-out, register_keymaps d keymap,
│                                   pr_footer update
└── github_dashboard.lua ← MODIFY: CursorMoved autocmd in open_win, dynamic footer
```

## Implementation Design

### US1 — Review comments in PR overview (`gh_reader.lua`)

**Step A** — Add private `fetch_review_comments(number, repo, callback)`:

```lua
local function fetch_review_comments(number, repo, callback)
  vim.system(
    { "gh", "api", "repos/" .. repo .. "/pulls/" .. tostring(number) .. "/comments",
      "--jq", "[.[] | {login: .user.login, path: .path, line: (.line // .original_line), body: .body}]" },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then callback({}) return end
        local ok, data = pcall(vim.json.decode, result.stdout or "[]")
        callback(ok and type(data) == "table" and data or {})
      end)
    end
  )
end
```

Note: errors fail silently (return `{}`) — review comments are supplementary; they must not block the PR view.

**Step B** — Add `render_review_comments_section(lines, hl_specs, review_comments)` after `render_comments_section` (mirrors its pattern):

```lua
local function render_review_comments_section(lines, hl_specs, review_comments)
  if #review_comments == 0 then return end
  table.insert(lines, "")
  table.insert(lines, separator())
  table.insert(hl_specs, { hl = "GhReaderSep", line = #lines - 1, col_s = 0, col_e = -1 })
  local header = "  🔎 Review Comments (" .. #review_comments .. ")"
  table.insert(lines, header)
  table.insert(hl_specs, { hl = "GhReaderSection", line = #lines - 1, col_s = 0, col_e = #header })
  for _, rc in ipairs(review_comments) do
    table.insert(lines, "")
    local meta = "  @" .. sl(rc.login) .. "  ·  " .. sl(rc.path) .. ":" .. tostring(rc.line or "?")
    table.insert(lines, meta)
    table.insert(hl_specs, { hl = "GhReaderMeta", line = #lines - 1, col_s = 0, col_e = -1 })
    table.insert(lines, "  " .. string.rep("╌", CODE_WIDTH))
    table.insert(hl_specs, { hl = "GhReaderSep", line = #lines - 1, col_s = 0, col_e = -1 })
    process_body(rc.body, lines, hl_specs)
  end
end
```

**Step C** — Change `render_pr(data)` to `render_pr(data, review_comments)`:
- After `render_comments_section(lines, hl_specs, data.comments)` add:
  ```lua
  render_review_comments_section(lines, hl_specs, review_comments or {})
  ```

**Step D** — Change the PR branch in `M.open` to a `pending=2` fan-out:

```lua
elseif item.kind == "pr" then
  local pr_data, rc_data
  local pending = 2
  local function on_both()
    pending = pending - 1
    if pending > 0 then return end
    state.data = pr_data
    render_pr(pr_data, rc_data or {})
  end
  fetch_pr(item, function(err, data)
    if err then
      vim.bo[state.buf].modifiable = true
      vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "", "  ✗ " .. sl(err) })
      vim.bo[state.buf].modifiable = false
      return
    end
    pr_data = data
    on_both()
  end)
  fetch_review_comments(item.number, item.repo, function(data)
    rc_data = data
    on_both()
  end)
```

Note: if `fetch_pr` errors we bail early without waiting for `fetch_review_comments`. That's acceptable — the PR view is meaningless without the PR data.

---

### US2 — Dynamic dashboard footer (`github_dashboard.lua`)

Add a `CursorMoved` autocmd inside `open_win()`, after all `buf_map` calls:

```lua
local footer_default = " <CR> open  ·  w watch  ·  r refresh  ·  <leader>gw watchlist  ·  <leader>gn notifs  ·  q close "
local footer_pr      = " <CR> open  ·  d diff  ·  w watch  ·  r refresh  ·  q close "

vim.api.nvim_create_autocmd("CursorMoved", {
  buffer = state.buf,
  callback = function()
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cur = vim.api.nvim_win_get_cursor(state.win)[1] - 1
    local on_pr = false
    for _, item in ipairs(state.items) do
      if item.line == cur and item.kind == "pr" then on_pr = true; break end
    end
    vim.api.nvim_win_set_config(state.win, {
      footer     = on_pr and footer_pr or footer_default,
      footer_pos = "center",
    })
  end,
})
```

Also update the initial `nvim_open_win` call to use `footer_default` (extract the string to a local so it's defined before `open_win`).

---

### US3 — `d` keymap + footer hint in PR reader (`gh_reader.lua`)

**In `register_keymaps()`**, add after the existing `bmap("m", ...)`:

```lua
bmap("d", function()
  if state.item and state.item.kind == "pr" then
    M.open_diff(state.item)
  end
end)
```

**In `render_pr`**, update the footer string:

```lua
-- before
local pr_footer = "q back  ·  r refresh  ·  c comment  ·  a review  ·  m merge"
-- after
local pr_footer = "q back  ·  r refresh  ·  c comment  ·  a review  ·  d diff  ·  m merge"
```

---

## Verification

1. Open a PR that has inline review comments → review comments section appears after the general comments section, showing `@user · path:line` header and body
2. Open a PR with no review comments → no review comments section shown
3. If review comment fetch fails (network error) → PR still loads, review comments section absent
4. Move cursor to a PR row in dashboard → footer shows `d diff` hint
5. Move cursor to an issue/repo/activity row → footer reverts to default (no `d diff`)
6. Open PR reader → footer shows `d diff` · press `d` → diff popup opens
7. `q back` from PR reader → still returns to dashboard (no regression)
8. `r refresh` from PR reader → re-fetches PR and review comments (both)
