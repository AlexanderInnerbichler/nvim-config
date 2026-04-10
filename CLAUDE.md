# nvim Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-09

## Active Technologies
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (system), `render-markdown.nvim` (already installed), `vim.ui.select` / `vim.ui.input` (built-in), `vim.system()` (built-in async) (002-gh-issue-pr-reader)
- No cache for reader (always fresh fetch; dashboard cache handles staleness) (002-gh-issue-pr-reader)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `render-markdown.nvim` (already installed + configured in `after/plugin/render-markdown.lua`), custom highlights in `GhReader*` namespace (003-reader-rendering)
- No changes to data model or cache (003-reader-rendering)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `vim.api.nvim_open_win` (built-in), `vim.api.nvim_win_close` (built-in) (004-fix-dashboard-ux)
- N/A — no data model changes (004-fix-dashboard-ux)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `vim.uv.new_timer` (built-in), `vim.system()` (built-in), `gh` CLI v2.45.0, `nvim_open_win` (built-in) (005-repo-watchlist-hud)
- `~/.config/nvim/gh-watchlist.json` — atomic JSON read/write (same pattern as dashboard cache) (005-repo-watchlist-hud)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh_watchlist.lua` (existing module, `lua/alex/`), `github_dashboard.lua` (existing module, `lua/alex/`) (006-dashboard-watchlist-hotkey)
- `~/.config/nvim/gh-watchlist.json` — existing atomic JSON persistence (no schema change) (006-dashboard-watchlist-hotkey)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `vim.uv.new_timer` (built-in), `nvim_open_win` (built-in) (007-fix-watchlist-notifs)
- `state.history` — in-memory only, never persisted (007-fix-watchlist-notifs)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI (existing), `gh_reader.lua` (reuse `process_body`, `open_popup`, `write_buf`) (008-heatmap-repo-readme)
- README not cached — fetched fresh each time (008-heatmap-repo-readme)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0, `gh_reader.lua` (existing), `vim.system()` (built-in async) (010-org-team-activity)
- N/A — team events are not cached; fetched each dashboard refresh cycle (010-org-team-activity)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0, `gh_reader.lua` (existing), `vim.system()` (built-in async), `vim.uv.fs_rename` (built-in atomic writes) (011-user-watch-activity)
- `~/.config/nvim/gh-user-watchlist.json` — atomic JSON read/write (same pattern as `gh-watchlist.json`) (011-user-watch-activity)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (REST + GraphQL), `vim.system()` (async), `nvim_open_win` (floating windows) (012-watched-user-profile-popup)
- N/A — no persistence; data fetched fresh on each popup open (012-watched-user-profile-popup)

- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (system), `vim.system()` (built-in async), `xdg-open` (browser) (001-github-dashboard)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Lua (LuaJIT 2.1), Neovim 0.12.0-dev

## Code Style

Lua (LuaJIT 2.1), Neovim 0.12.0-dev: Follow standard conventions

## Recent Changes
- 012-watched-user-profile-popup: Added Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (REST + GraphQL), `vim.system()` (async), `nvim_open_win` (floating windows)
- 011-user-watch-activity: Added Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0, `gh_reader.lua` (existing), `vim.system()` (built-in async), `vim.uv.fs_rename` (built-in atomic writes)
- 010-org-team-activity: Added Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0, `gh_reader.lua` (existing), `vim.system()` (built-in async)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
