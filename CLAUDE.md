# nvim Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-04-09

## Active Technologies
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (system), `render-markdown.nvim` (already installed), `vim.ui.select` / `vim.ui.input` (built-in), `vim.system()` (built-in async) (002-gh-issue-pr-reader)
- No cache for reader (always fresh fetch; dashboard cache handles staleness) (002-gh-issue-pr-reader)
- Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `render-markdown.nvim` (already installed + configured in `after/plugin/render-markdown.lua`), custom highlights in `GhReader*` namespace (003-reader-rendering)
- No changes to data model or cache (003-reader-rendering)

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
- 003-reader-rendering: Added Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `render-markdown.nvim` (already installed + configured in `after/plugin/render-markdown.lua`), custom highlights in `GhReader*` namespace
- 002-gh-issue-pr-reader: Added Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (system), `render-markdown.nvim` (already installed), `vim.ui.select` / `vim.ui.input` (built-in), `vim.system()` (built-in async)

- 001-github-dashboard: Added Lua (LuaJIT 2.1), Neovim 0.12.0-dev + `gh` CLI v2.45.0 (system), `vim.system()` (built-in async), `xdg-open` (browser)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
