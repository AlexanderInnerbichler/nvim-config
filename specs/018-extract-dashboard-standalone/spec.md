# Feature Specification: Extract gh_dashboard as Standalone Neovim Plugin

**Feature Branch**: `018-extract-dashboard-standalone`  
**Created**: 2026-04-11  
**Status**: Draft  
**Input**: User description: "extract gh_dashboard as standalone neovim plugin"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plugin Runs from Its Own Repository (Priority: P1)

A developer clones `gh_dashboard.nvim` as a fresh repo, adds it to their plugin manager, restarts their editor, and the GitHub dashboard works identically to today — no dependency on the parent Neovim config.

**Why this priority**: This is the core goal. If the plugin can be installed standalone, everything else (versioning, public distribution) becomes possible. Without this, the remaining stories have no foundation.

**Independent Test**: Create a minimal Neovim config that only installs `gh_dashboard.nvim` (no other custom config), opens the editor, runs the dashboard keybind, and sees the contribution heatmap and PR list render correctly.

**Acceptance Scenarios**:

1. **Given** a fresh repo at `~/code/gh_dashboard.nvim` with only the 7 current modules, **When** installed via `{ dir = "~/code/gh_dashboard.nvim" }` in a minimal config, **Then** the dashboard opens without errors and all panels render.
2. **Given** the plugin is installed, **When** no `setup()` call is made, **Then** the plugin provides a safe no-op default (no crash, no keymaps registered).
3. **Given** the plugin is installed, **When** `require("gh_dashboard").setup({ username = "alice" })` is called, **Then** the dashboard fetches Alice's contributions and renders them correctly.

---

### User Story 2 - Parent Config Installs the Plugin Like Any Other (Priority: P2)

The existing Neovim config removes its `lua/gh_dashboard/` directory and instead loads the plugin from its new standalone repo path, with zero change in end-user behavior.

**Why this priority**: The parent config is the primary consumer. If the migration breaks the current workflow, the extraction has failed. This story validates the seam.

**Independent Test**: Delete `lua/gh_dashboard/` from the nvim config, add `{ dir = "~/code/gh_dashboard.nvim" }` to `lua/plugins/`, restart Neovim — dashboard must work identically to before.

**Acceptance Scenarios**:

1. **Given** `lua/gh_dashboard/` is removed from the config, **When** the plugin is loaded via `dir =` path, **Then** all 4 keymaps (`<leader>gh`, `<leader>gw`, `<leader>gn`, `<leader>gu`) work as before.
2. **Given** the plugin is loaded, **When** the user opens the dashboard, **Then** heatmap, PR list, watchlist, and user profile panels all render correctly.
3. **Given** the plugin spec exists in `lua/plugins/`, **When** a future version bump is made, **Then** only the plugin directory (not the nvim config) needs to change.

---

### User Story 3 - Plugin Has a Public Entry Point and Minimal Docs (Priority: P3)

The extracted plugin has a `plugin/gh_dashboard.lua` autoload entry point (Neovim convention) and a README covering installation and configuration, so a stranger could install it from GitHub with no prior knowledge of the internal structure.

**Why this priority**: Makes the plugin actually distributable. Not needed for personal use (US1 + US2 suffice) but required before publishing.

**Independent Test**: Add the GitHub URL to a fresh config's plugin manager, run `:checkhealth gh_dashboard`, see no errors; read the README and follow the install steps without any other guidance.

**Acceptance Scenarios**:

1. **Given** the plugin is installed from its GitHub URL, **When** Neovim starts, **Then** no manual `require(...)` call is needed — the entry point auto-loads the module.
2. **Given** `:checkhealth gh_dashboard` is run, **Then** it reports `gh` CLI present/missing and whether a GitHub token is configured.
3. **Given** the README install section, **When** followed by a new user, **Then** the plugin is functional with only a `setup({ username = "..." })` call.

---

### Edge Cases

- What happens when `gh` CLI is not installed or not authenticated — the plugin must surface a human-readable error rather than a Lua stack trace.
- What happens when `setup()` is called more than once — second call should be a no-op or safely reconfigure without registering duplicate keymaps.
- What happens when the plugin directory is missing from `runtimepath` — `require("gh_dashboard")` must fail with a clear message, not a cryptic nil index.
- What happens when the user's GitHub token has no `read:user` scope — the contribution fetch will return partial data; the plugin should render what it has and note the missing data.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plugin MUST live in its own git repository, separate from any Neovim config repo, with no runtime dependency on the parent config.
- **FR-002**: The plugin MUST expose a `setup(opts)` function as its sole public configuration surface; all keymaps, autocommands, and state are registered inside `setup()`.
- **FR-003**: Users MUST be able to install the plugin by pointing their plugin manager at either a local directory path or a GitHub remote URL.
- **FR-004**: The plugin MUST work with zero configuration when `gh` CLI is already authenticated (derives username from `gh api user`).
- **FR-005**: The plugin MUST provide a `:checkhealth gh_dashboard` handler that validates `gh` CLI presence, authentication, and token scopes.
- **FR-006**: The parent Neovim config MUST be updated to remove `lua/gh_dashboard/` and load the plugin via a lazy.nvim spec instead.
- **FR-007**: All 7 existing modules (`init`, `heatmap`, `reader`, `watchlist`, `user_watchlist`, `user_profile`, `day_activity`) MUST be preserved with no behavior change during extraction.
- **FR-008**: The plugin MUST NOT require any Neovim distro (LazyVim, AstroNvim, etc.) — it must work in plain Neovim with only lazy.nvim as plugin manager.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A minimal Neovim config containing only `gh_dashboard.nvim` (no other custom modules) opens the dashboard without errors after a cold start.
- **SC-002**: The parent config's `lua/gh_dashboard/` directory is fully deleted — zero files remain — and the dashboard continues to work identically via the plugin path.
- **SC-003**: `:checkhealth gh_dashboard` passes green on a correctly configured system and reports actionable errors on a misconfigured one.
- **SC-004**: The plugin repo contains a README sufficient for a stranger to install and configure the plugin without reading source code.
- **SC-005**: Zero behavior regressions: all 4 keymaps, all 5 panels (heatmap, contributions total, PR list, watchlist, user profile), and the day-activity drill-down work identically before and after extraction.
