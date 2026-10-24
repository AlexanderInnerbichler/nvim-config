# Implementation Plan: GitHub Dashboard UX Refinements

**Branch**: `004-fix-dashboard-ux` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-fix-dashboard-ux/spec.md`

## Summary

Fix two UX bugs in the GH reader:
1. Reader popup is smaller and offset vs the dashboard — fix by matching dashboard's 90%×90% dimensions
2. Comment/review input opens as a bottom split — replace with a centered floating popup

Single file changed: `lua/alex/gh_reader.lua`.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev
**Primary Dependencies**: `vim.api.nvim_open_win` (built-in), `vim.api.nvim_win_close` (built-in)
**Storage**: N/A — no data model changes
**Testing**: Manual — open real issues/PRs from dashboard, use comment/review flow
**Target Platform**: Linux (WSL2), terminal Neovim
**Single file changed**: `lua/alex/gh_reader.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | ✅ Pass | Removing split logic, not adding layers |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | No new try/catch |
| IV. Logical commits, push after each task | ✅ Pass | One commit per fix |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Project Structure

```text
lua/alex/gh_reader.lua    ← only file changed
```

---

## Phase A — Fix reader window size (US1)

**Root cause**: `open_popup` uses `ui.width * 0.80` / `ui.height * 0.85`, while the dashboard uses `0.90` / `0.90`.

**Change in `open_popup`** (`gh_reader.lua:258–263`):

```lua
-- before
local width  = math.floor(ui.width  * 0.80)
local height = math.floor(ui.height * 0.85)

-- after
local width  = math.floor(ui.width  * 0.90)
local height = math.floor(ui.height * 0.90)
```

That's the entire fix for US1. Row/col centering formula is identical to the dashboard so position auto-matches.

**Commit**: `fix: gh-reader popup — match dashboard window size (90x90)`

---

## Phase B — Replace input split with floating popup (US2)

**Root cause**: `M.open_input` calls `vim.cmd("belowright 10split")` which creates a horizontal editor split.

**New approach**: Replace the split with `nvim_open_win`. The input popup:
- 60% terminal width × 12 lines, centered
- `border = "rounded"`, `title = " " .. hint_title .. " "`, `footer = " <leader>s submit  ·  <Esc><Esc> cancel "`
- `filetype = "markdown"` (unchanged)
- Buffer lines: line 1 = hint comment `"-- " .. hint .. " --"`, line 2 = `""`
- Cursor placed at line 2 col 0, then `startinsert`

**Rewrite `M.open_input`**:

```lua
function M.open_input(hint, on_submit)
  close_input()  -- close any existing input popup

  state.input_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.input_buf].buftype   = "nofile"
  vim.bo[state.input_buf].bufhidden = "wipe"
  vim.bo[state.input_buf].filetype  = "markdown"

  vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "", "" })

  local ui     = vim.api.nvim_list_uis()[1] or { width = 180, height = 50 }
  local width  = math.floor(ui.width  * 0.60)
  local height = 12
  local row    = math.floor((ui.height - height) / 2)
  local col    = math.floor((ui.width  - width)  / 2)

  state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
    relative   = "editor",
    width      = width,
    height     = height,
    row        = row,
    col        = col,
    style      = "minimal",
    border     = "rounded",
    title      = " " .. hint .. " ",
    title_pos  = "center",
    footer     = " <leader>s submit  ·  <Esc><Esc> cancel ",
    footer_pos = "center",
  })
  vim.wo[state.input_win].number         = false
  vim.wo[state.input_win].relativenumber = false
  vim.wo[state.input_win].signcolumn     = "no"
  vim.wo[state.input_win].wrap           = true
  vim.wo[state.input_win].linebreak      = true

  vim.api.nvim_win_set_cursor(state.input_win, { 1, 0 })
  vim.cmd("startinsert")

  local function do_cancel()
    close_input()
  end

  local function do_submit()
    local all_lines = vim.api.nvim_buf_get_lines(state.input_buf, 0, -1, false)
    local body = table.concat(all_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    close_input()
    on_submit(body)
  end

  local function imap(mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = state.input_buf, nowait = true, silent = true })
  end

  imap("n", "<leader>s", do_submit)
  imap("i", "<leader>s", function() vim.cmd("stopinsert") do_submit() end)
  imap("n", "<Esc><Esc>", do_cancel)

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer   = state.input_buf,
    once     = true,
    callback = function()
      state.input_buf = nil
      state.input_win = nil
    end,
  })
end
```

Note: removed `prev_win` tracking (restoring focus to reader) — `close_input()` already just closes the window and the reader remains the last active popup.

**Commit**: `fix: gh-reader input — replace bottom split with centered floating popup`

---

## Verification

1. `<leader>gh` → dashboard opens 90%×90%
2. `<CR>` on issue → reader opens at exact same size/position (no shrink, no shift)
3. `q` → back to dashboard, layout unchanged
4. `<CR>` on PR → `c` → floating input popup appears centered (no bottom split)
5. Type a comment → `<leader>s` → popup closes, reader refreshes with new comment
6. Open PR → `c` → `<Esc><Esc>` → popup closes, reader unchanged
7. Open PR → `a` → select "Approve" → same floating popup for review body
