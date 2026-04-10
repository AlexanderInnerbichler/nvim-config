# Feature Specification: Migrate Neovim Config from Packer to LazyVim

**Feature Branch**: `017-moving-neovim-config`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "moving my neovim config from packer to the new lazyvim"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Editor Opens and Core Editing Works (Priority: P1)

After the migration, Neovim opens without errors and all fundamental editing capabilities work: LSP, syntax highlighting, file navigation, keymaps, and the status line. The editor is usable as a daily driver from day one.

**Why this priority**: This is the baseline. Everything else is irrelevant if the editor is broken or spams startup errors. Must be independently verifiable before touching any cosmetic or optional plugins.

**Independent Test**: Open Neovim cold, open a Lua file from this config, confirm LSP attaches (hover works), no error notifications appear on startup, and all existing keymaps function.

**Acceptance Scenarios**:

1. **Given** the migration is applied, **When** Neovim is launched, **Then** it opens without any error notifications or missing module warnings
2. **Given** a source file is open, **When** the LSP hover keymap is triggered, **Then** the LSP hover popup appears correctly
3. **Given** Neovim is open, **When** existing custom keymaps are used (leader key, window navigation, etc.), **Then** they behave identically to the pre-migration setup

---

### User Story 2 - All Existing Plugins Available and Configured (Priority: P2)

Every plugin that was managed by Packer is present and correctly configured under LazyVim. No plugin is silently missing; any plugin that LazyVim already bundles is deduplicated rather than double-installed.

**Why this priority**: Custom plugins (gh dashboard, plan viewer, treesitter config, render-markdown, etc.) are core to the daily workflow. Once the editor boots, all tools must be present.

**Independent Test**: Open the lazy.nvim UI (`<leader>l` or `:Lazy`), verify all expected plugins appear and show no errors. Open the GitHub dashboard, trigger a PR review popup — both should work exactly as before.

**Acceptance Scenarios**:

1. **Given** the migration is applied, **When** the plugin manager UI is opened, **Then** all previously-configured plugins are listed with no install or load errors
2. **Given** a plugin that LazyVim bundles by default (e.g., treesitter, telescope), **When** its config is checked, **Then** custom overrides from the old config are applied rather than LazyVim defaults being silently ignored
3. **Given** a custom module (e.g., `lua/alex/github_dashboard.lua`), **When** its keybind is triggered, **Then** it works identically to the pre-migration behavior

---

### User Story 3 - Config Uses LazyVim Idioms Properly (Priority: P3)

The migrated config is structured in LazyVim's native style — plugin specs in `lua/plugins/`, overrides via `opts`, lazy-loading declared correctly — rather than being a verbatim port of packer syntax. Future plugin additions follow the new pattern naturally.

**Why this priority**: A working-but-structurally-wrong migration creates tech debt immediately. This story ensures the migration is done right, not just done.

**Independent Test**: Add a new test plugin following LazyVim conventions (no packer-style `use()`), confirm it loads. Review `lua/plugins/` — no `require('packer')` calls anywhere in the config.

**Acceptance Scenarios**:

1. **Given** the migration is complete, **When** the config is grepped for packer-specific patterns (`use(`, `packer_bootstrap`, `PackerSync`), **Then** no matches are found
2. **Given** a LazyVim-style plugin spec is added to `lua/plugins/`, **When** Neovim is restarted, **Then** the plugin installs and loads without any additional wiring
3. **Given** a plugin that needs custom configuration, **When** its spec uses the `opts` or `config` key, **Then** the configuration is applied correctly at load time

---

### Edge Cases

- What happens to plugins that are Packer-only or incompatible with lazy.nvim's loading model (e.g., plugins using `setup()` in a Packer `config` callback)?
- What happens if LazyVim ships a newer version of a plugin that breaks existing custom config (e.g., treesitter API changes)?
- What happens to `after/plugin/` files that rely on plugins being loaded synchronously at startup — does lazy loading break them?
- What happens to the compiled Packer loader (`plugin/packer_compiled.lua`) if it is not removed before switching — does it conflict?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The editor MUST start without any error or warning notifications after migration
- **FR-002**: All plugins previously managed by Packer MUST be available under the new plugin manager
- **FR-003**: Users MUST be able to trigger all existing custom keymaps with identical behavior
- **FR-004**: LazyVim-bundled plugins that overlap with existing plugins MUST use the existing custom configuration, not LazyVim defaults
- **FR-005**: The `after/plugin/` configuration files MUST continue to apply correctly after migration
- **FR-006**: The Packer compiled loader (`plugin/packer_compiled.lua`) MUST be removed to avoid conflicts
- **FR-007**: All custom modules in `lua/alex/` MUST load and function without modification [NEEDS CLARIFICATION: are any of these modules using packer-specific APIs directly?]
- **FR-008**: Plugin lazy-loading MUST be declared explicitly for any plugin that should not load at startup

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Neovim startup produces zero error notifications across 5 consecutive cold starts
- **SC-002**: All keymaps that existed before migration continue to work after migration (verified by manually triggering each one)
- **SC-003**: The plugin manager UI shows all expected plugins as installed with no load errors
- **SC-004**: No packer-specific code (`use(`, `PackerSync`, `packer_bootstrap`) remains anywhere in the config
- **SC-005**: A new plugin can be added using LazyVim conventions and loads correctly without additional wiring
