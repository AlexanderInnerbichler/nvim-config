# Implementation Plan: Extract gh_dashboard as Standalone Neovim Plugin

**Branch**: `018-extract-dashboard-standalone` | **Date**: 2026-04-11 | **Spec**: `specs/018-extract-dashboard-standalone/spec.md`

## Summary

Move the 7 `lua/gh_dashboard/` modules out of the Neovim config repo into a dedicated `gh_dashboard.nvim` git repository, wire it back into the config via a lazy.nvim `dir =` spec, and add the conventions (entry point, `checkhealth`) that make it installable by anyone from GitHub.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI v2.45.0 (runtime, not a Lua dep), `lazy.nvim` (plugin manager in consumer config)  
**Storage**: `~/.cache/nvim/gh-dashboard.json` (existing dashboard cache), `~/.config/nvim/gh-watchlist.json` and `gh-user-watchlist.json` (watchlist persistence — these stay in the config, not the plugin)  
**Testing**: Manual smoke-test only — no Lua test framework in place  
**Target Platform**: Linux / macOS, Neovim 0.10+  
**Project Type**: Neovim plugin (library)  
**Performance Goals**: N/A — same as today; no new data fetches introduced  
**Constraints**: Must not break the parent config's existing 4 keymaps or 5 rendered panels  
**Scale/Scope**: 7 Lua files, ~900 lines total; single consumer (this nvim config)

## Current Module Inventory

| File | Role |
|------|------|
| `lua/gh_dashboard/init.lua` | Main dashboard window, cache, event rendering |
| `lua/gh_dashboard/heatmap.lua` | Contribution heatmap rendering + highlight specs |
| `lua/gh_dashboard/reader.lua` | Floating popup for issue/PR/README markdown |
| `lua/gh_dashboard/watchlist.lua` | Repo watchlist (org/repo tracking) |
| `lua/gh_dashboard/user_watchlist.lua` | User activity watchlist |
| `lua/gh_dashboard/user_profile.lua` | Watched-user profile popup |
| `lua/gh_dashboard/day_activity.lua` | Day-level contribution drill-down |

**How it's loaded today**: `lua/alex/init.lua` calls `require("gh_dashboard").setup()` etc. directly. No lazy.nvim spec exists — it's just a directory on `runtimepath` via the config root.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. No Unnecessary Code**: No violations anticipated. Extraction copies existing code as-is; no new abstractions introduced. The `plugin/gh_dashboard.lua` entry point is a single-function file — justified by Neovim plugin convention.
- **II. Python Type Annotations**: N/A — Lua project.
- **III. No Silent Exception Swallowing**: Existing `pcall` usage in cache read/write is correct (network/file boundary). No new `pcall` blocks needed; `checkhealth` handler uses Neovim's health API which handles its own error display. No violations anticipated.
- **IV. Logical Commits**: Must commit after each phase. One commit for plugin repo creation, one for parent config update, one for polish. Push immediately each time.
- **V. Backend–Frontend Separation**: N/A — Lua plugin.
- **VI. Branch Lifecycle**: Merge `018-extract-dashboard-standalone` into `master` and delete both local and remote immediately upon completion.

## Project Structure

### Documentation (this feature)

```text
specs/018-extract-dashboard-standalone/
├── spec.md
├── plan.md              ← this file
└── tasks.md             ← created by /speckit.tasks
```

### Source Code

**New plugin repo** (created at `~/code/gh_dashboard.nvim/`):

```text
gh_dashboard.nvim/
├── lua/
│   └── gh_dashboard/
│       ├── init.lua
│       ├── heatmap.lua
│       ├── reader.lua
│       ├── watchlist.lua
│       ├── user_watchlist.lua
│       ├── user_profile.lua
│       └── day_activity.lua
├── plugin/
│   └── gh_dashboard.lua     ← autoload entry point (calls setup() if configured)
└── README.md
```

**Parent Neovim config** (changes only):

```text
~/.config/nvim/
├── lua/
│   ├── alex/
│   │   └── init.lua          ← remove 4 require("gh_dashboard*") setup calls
│   └── plugins/
│       └── gh_dashboard.lua  ← new: { dir = "~/code/gh_dashboard.nvim", ... }
│       (lua/gh_dashboard/ deleted entirely)
└── after/
    └── plugin/
        └── gh_dashboard.lua  ← optional: keymaps moved here from alex/init.lua
```

**Structure Decision**: Single-project layout. The plugin is a pure Lua library with no build step, no frontend, no backend — standard `lua/` + `plugin/` Neovim plugin layout.

## Phase Plan

### Phase 0 — Create Plugin Repo

**Goal**: `~/code/gh_dashboard.nvim` exists as a git repo with all 7 modules, entry point, and README. Parent config unchanged.

- Create `~/code/gh_dashboard.nvim/` and `git init`
- Copy all 7 files from `~/.config/nvim/lua/gh_dashboard/` preserving structure
- Write `plugin/gh_dashboard.lua`: single autoload file, no-op unless user called `require("gh_dashboard").setup()`
- Write minimal `README.md` with install snippet and `setup()` reference
- `git add -A && git commit -m "feat: initial gh_dashboard.nvim plugin"`

### Phase 1 — Wire Into Parent Config

**Goal**: Parent config loads the plugin via `dir =` spec; `lua/gh_dashboard/` deleted.

- Add `lua/plugins/gh_dashboard.lua`: `{ dir = "~/code/gh_dashboard.nvim", lazy = false }`
- Remove the 4 `require("gh_dashboard*").setup()` calls from `lua/alex/init.lua` — the `plugin/` entry point handles this
- Delete `~/.config/nvim/lua/gh_dashboard/` entirely
- Restart Neovim, verify all 4 keymaps and 5 panels work
- `git commit -m "feat: load gh_dashboard via plugin dir spec, remove inline modules"`

### Phase 2 — checkhealth Handler

**Goal**: `:checkhealth gh_dashboard` reports `gh` CLI status and token scopes.

- Add `lua/gh_dashboard/health.lua` (or inline in `init.lua`) implementing `vim.health.start`, `vim.health.ok/warn/error`
- Check: `gh` binary on PATH, `gh auth status` exit code, `gh auth status --show-token` scope includes `read:user`
- Wire handler via `plugin/gh_dashboard.lua` or a `health/` directory per Neovim convention
- Verify `:checkhealth gh_dashboard` outputs green on a working system

### Phase 3 — Polish & Merge

- Final smoke-test: 3 cold Neovim starts, all panels render, no errors
- Merge `018-extract-dashboard-standalone` → `master`, delete branch

## Complexity Tracking

> No constitution violations identified — table omitted.
