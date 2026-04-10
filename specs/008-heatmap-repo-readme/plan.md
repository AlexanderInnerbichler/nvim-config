# Implementation Plan: Heatmap Colors and Repo README Viewer

**Branch**: `008-heatmap-repo-readme` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-heatmap-repo-readme/spec.md`

## Summary

Two independent changes:
1. **Heatmap palette** — replace the 5 `GhHeat*` hex values in `github_dashboard.lua` with a cooler teal-shifted green gradient
2. **README viewer** — `<CR>` on a repo row fetches the raw README via GitHub API and renders it in the existing `gh_reader` popup (same `process_body` renderer, same breadcrumb/footer/back-nav)

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI (existing), `gh_reader.lua` (reuse `process_body`, `open_popup`, `write_buf`)  
**Storage**: README not cached — fetched fresh each time  
**Testing**: Manual — verify heatmap visually; press `<CR>` on a repo, verify README renders  
**Target Platform**: Linux (WSL2), terminal Neovim  
**New files**: none  
**Modified files**: `lua/alex/github_dashboard.lua`, `lua/alex/gh_reader.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | ✅ Pass | No new files; reuses existing renderer |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | Error shown in reader buffer on fetch failure |
| IV. Logical commits, push after each task | ✅ Pass | One commit per phase |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Project Structure

```text
lua/alex/github_dashboard.lua   ← heatmap palette; add kind="repo" to items; route to reader
lua/alex/gh_reader.lua          ← fetch_readme, render_readme; handle kind="repo" in M.open
```

---

## Phase A — Heatmap Color Palette

**Location**: `lua/alex/github_dashboard.lua` — `setup_highlights()` lines ~131–135.

Replace the current GitHub-replica greens with a teal-shifted palette that pops on dark terminals:

```lua
-- Before (muted GitHub greens):
vim.api.nvim_set_hl(0, "GhHeat0", { fg = "#2d333b" })  -- dark gray
vim.api.nvim_set_hl(0, "GhHeat1", { fg = "#0e4429" })  -- very dark green
vim.api.nvim_set_hl(0, "GhHeat2", { fg = "#006d32" })  -- dark green
vim.api.nvim_set_hl(0, "GhHeat3", { fg = "#26a641" })  -- medium green
vim.api.nvim_set_hl(0, "GhHeat4", { fg = "#39d353" })  -- bright green

-- After (teal-shifted vibrant greens):
vim.api.nvim_set_hl(0, "GhHeat0", { fg = "#1b1f2b" })  -- near-invisible dark navy (empty)
vim.api.nvim_set_hl(0, "GhHeat1", { fg = "#0d4a3a" })  -- deep forest teal
vim.api.nvim_set_hl(0, "GhHeat2", { fg = "#0a7a5c" })  -- emerald
vim.api.nvim_set_hl(0, "GhHeat3", { fg = "#10c87e" })  -- bright teal-green
vim.api.nvim_set_hl(0, "GhHeat4", { fg = "#00ff99" })  -- neon mint
```

**Commit**: `feat: cooler heatmap palette — teal-shifted greens`

---

## Phase B — Repo README Viewer

### B1: Dashboard — add `kind="repo"` and route to reader

**`render_repos`** (~line 507, `lua/alex/github_dashboard.lua`):
```lua
-- change:
table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name })
-- to:
table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name, kind = "repo" })
```

**`open_url_at_cursor`** (~line 612, `lua/alex/github_dashboard.lua`) — add `elseif item.kind == "repo"` to route to reader instead of browser:
```lua
if item.kind == "issue" or item.kind == "pr" then
  require("alex.gh_reader").open(item)
elseif item.kind == "repo" then
  require("alex.gh_reader").open(item)
else
  vim.system({ "xdg-open", item.url })
end
```

### B2: Reader — `fetch_readme(item, callback)`

Add to `lua/alex/gh_reader.lua`. Uses `Accept: application/vnd.github.raw` to get plain text directly (avoids base64 decoding):

```lua
local function fetch_readme(item, callback)
  vim.system(
    { "gh", "api", "repos/" .. item.full_name .. "/readme",
      "-H", "Accept: application/vnd.github.raw" },
    { text = true },
    function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          callback("No README found", nil)
          return
        end
        callback(nil, result.stdout)
      end)
    end
  )
end
```

### B3: Reader — `render_readme(data)`

Add to `lua/alex/gh_reader.lua`. Uses existing `process_body`, `open_popup`, `write_buf`:

```lua
local function render_readme(data)
  local lines, hl_specs = {}, {}
  local crumb_prefix = "  GitHub Dashboard  ›  "
  local crumb = crumb_prefix .. data.full_name .. "  ›  README"
  table.insert(lines, crumb)
  table.insert(hl_specs, { hl = "GhReaderBreadcrumb", line = 0, col_s = 0, col_e = #crumb_prefix })
  table.insert(hl_specs, { hl = "GhReaderTitle", line = 0, col_s = #crumb_prefix, col_e = -1 })
  table.insert(lines, "")
  table.insert(lines, separator())
  table.insert(hl_specs, { hl = "GhReaderSep", line = #lines - 1, col_s = 0, col_e = -1 })
  table.insert(lines, "")
  process_body(data.body, lines, hl_specs)
  open_popup(data.full_name .. "  README", "q back")
  write_buf(lines, hl_specs)
end
```

### B4: Reader — `M.open` repo branch

In `M.open(item)` (~line 767, `lua/alex/gh_reader.lua`), update the initial loading state to handle repos (no `item.number`), then add the `kind="repo"` fetch branch:

```lua
-- loading state (replace item.number reference):
local label = item.number and ("#" .. tostring(item.number)) or (item.full_name or item.repo or "…")
vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {
  crumb_prefix .. label, "", "  ⠋ loading " .. label .. "…",
})

-- fetch branch:
elseif item.kind == "repo" then
  fetch_readme(item, function(err, body)
    if err then
      vim.bo[state.buf].modifiable = true
      vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "", "  ✗ " .. err })
      vim.bo[state.buf].modifiable = false
      return
    end
    render_readme({ full_name = item.full_name, body = body })
  end)
```

**Commit**: `feat: repo README viewer — <CR> on repo row opens README in reader popup`

---

## Verification

1. Open dashboard → heatmap shows 5 clearly distinct teal-green tones
2. Move cursor to a repo row → press `<CR>` → README popup opens, breadcrumb = `GitHub Dashboard › owner/repo › README`
3. Scrollable; headings, code blocks, bullets render correctly via `process_body`
4. Press `q` → focus returns to dashboard
5. Repo with no README → error message "No README found" shown in popup
6. Press `<CR>` on a PR row → existing PR reader unaffected
