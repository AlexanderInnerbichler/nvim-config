# Implementation Plan: GitHub Dashboard for Neovim

**Branch**: `001-github-dashboard` | **Date**: 2026-04-09 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/001-github-dashboard/spec.md`

## Summary

Build a Neovim floating-window GitHub dashboard that shows the authenticated user's open PRs, assigned issues, recent activity, contribution heatmap, and profile stats. All data is fetched via the `gh` CLI (already authenticated), cached to JSON for instant re-opens, and displayed using raw Neovim API consistent with the existing HUD and plan_viewer modules.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI v2.45.0 (system), `vim.system()` (built-in async), `xdg-open` (browser)  
**Storage**: JSON cache at `~/.cache/nvim/gh-dashboard.json`, 5-minute TTL  
**Testing**: Manual smoke test — open dashboard, verify sections render, verify `<CR>` opens URL  
**Target Platform**: Linux (WSL2), terminal Neovim  
**Project Type**: Neovim plugin module (single Lua file)  
**Performance Goals**: Open with cached data in <200ms; full refresh in <5s  
**Constraints**: Min terminal width 120 chars; no new plugin dependencies  
**Scale/Scope**: Single user, ~30 PRs/issues/events max per session

## Constitution Check

*Adapted from project constitution for Lua/Neovim context (Python-specific principles I–III do not apply):*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No unnecessary code | ✅ Pass | Single file, no speculative abstractions |
| II. Python type annotations | N/A | Lua project — principle does not apply |
| III. No silent exception swallowing | ✅ Pass | `gh` errors shown inline; `pcall` only for JSON decode |
| IV. Logical commits, push after each task | ✅ Pass | Enforced by task workflow |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete immediately after completion |

**No constitution violations requiring justification.**

## Project Structure

### Documentation (this feature)

```text
specs/001-github-dashboard/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
├── contracts/
│   └── ui-contract.md   ← Phase 1 output
└── tasks.md             ← Phase 2 output (/speckit.tasks)
```

### Source Code

```text
lua/alex/
└── github_dashboard.lua   ← new file (single module)

lua/alex/
├── init.lua               ← add require("alex.github_dashboard").setup()
└── remap.lua              ← add <leader>gh keybinding
```

## Implementation Phases

### Phase A — Data Layer (gh CLI fetching + cache)

1. Create `lua/alex/github_dashboard.lua` with module skeleton (`M.toggle`, `M.setup`)
2. Implement `fetch_all()`: runs 4 `gh` commands in parallel via `vim.system()`
   - `gh api user` → profile
   - `gh pr list --author @me --state open --json number,title,headRepository,url,createdAt,isDraft`
   - `gh issue list --assignee @me --state open --json number,title,url,createdAt`  
     (Note: `--json repository` field not available; use `--json repositoryUrl` or parse from url)
   - `gh api graphql` → contributions calendar
   - `gh api /users/{login}/events` → activity (after profile fetch gives login)
3. Implement cache read/write to `~/.cache/nvim/gh-dashboard.json`
4. Implement age-string helper (`"2d ago"`, `"3h ago"`)

**Commit**: `feat: github dashboard — data layer with gh CLI fetching and JSON cache`

### Phase B — Rendering Layer (buffer + highlights)

5. Implement `render(data)`: builds list of lines and highlight specs from cached data
   - Profile bar with total contributions
   - Heatmap: 26 weeks × 7 rows of tier characters
   - PR list (or empty state message)
   - Issue list (or empty state message)
   - Activity feed (10 events, summarized)
   - Collect navigable items into `state.items`
6. Implement highlight groups (profile=blue, heatmap tiers 0–4, PR/issue bullets, separators=dim)
7. Apply highlights via `nvim_buf_add_highlight`

**Commit**: `feat: github dashboard — rendering layer with heatmap and section highlights`

### Phase C — Window + Keybindings

8. Implement `open_win()`: centered floating window, 90% dimensions, `nomodifiable`, hide cursor line number, no sign column
9. Set buffer-local keymaps: `q`/`<Esc>` close, `r` refresh, `<CR>`/`o` open URL
10. Implement `open_url(url)`: calls `vim.system({"xdg-open", url})`
11. Implement stale/loading indicator in title line
12. Wire `M.toggle()` and `M.setup()`

**Commit**: `feat: github dashboard — floating window, keybindings, browser open`

### Phase D — Integration + Polish

13. Add `require("alex.github_dashboard").setup()` to `lua/alex/init.lua`
14. Add `<leader>gh` keybinding to `lua/alex/remap.lua`
15. Manual smoke test: open dashboard, navigate items, force refresh, close
16. Fix any rendering issues (alignment, wrapping, heatmap sizing)

**Commit**: `feat: github dashboard — wire into init.lua and remap.lua`

## Complexity Tracking

No constitution violations — table not required.
