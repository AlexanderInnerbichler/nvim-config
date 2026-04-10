# Implementation Plan: Migrate Neovim Config from Packer to LazyVim

**Branch**: `017-moving-neovim-config` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)

## Summary

Replace the Packer plugin manager with LazyVim (a full Neovim distribution built on lazy.nvim), migrating all 30+ existing plugin declarations to lazy.nvim spec files while preserving every custom module in `lua/alex/` and every `after/plugin/` configuration unchanged. The migration proceeds in three independent slices: (1) bootstrap LazyVim and verify the editor opens, (2) migrate all plugins with their existing configs, (3) clean up all Packer remnants and enforce LazyVim idioms.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Plugin manager (current)**: wbthomason/packer.nvim (loaded via `plugin/packer_compiled.lua`)  
**Plugin manager (target)**: LazyVim distribution → lazy.nvim v11+  
**Storage**: N/A  
**Testing**: Manual — open Neovim cold, verify LSP, keymaps, plugins, no startup errors  
**Target Platform**: Linux, single-user Neovim config  
**Project Type**: Neovim configuration repository  
**Performance Goals**: Startup time ≤ current baseline (lazy-loading must not regress startup)  
**Constraints**: All custom modules in `lua/alex/` must work unmodified; `after/plugin/` files must remain loadable  
**Scale/Scope**: ~30 plugins, 14 after/plugin configs, 11 custom lua/alex modules

**Plugins currently managed by Packer** (full inventory from `lua/alex/packer.lua`):

| Plugin | Migration Action |
|--------|-----------------|
| wbthomason/packer.nvim | REMOVE — replaced by lazy.nvim |
| nvim-treesitter/nvim-treesitter | LazyVim bundles — override with existing after/plugin/treesitter.lua config |
| seblyng/roslyn.nvim | Migrate to lua/plugins/lsp.lua |
| mofiqul/vscode.nvim | Migrate to lua/plugins/colorschemes.lua |
| datsfilipe/vesper.nvim | Active colorscheme (set in init.lua) — migrate |
| tpope/vim-fugitive | Migrate to lua/plugins/editor.lua |
| vague2k/vague.nvim | Migrate to lua/plugins/colorschemes.lua |
| stevearc/conform.nvim | LazyVim bundles — override via lua/plugins/conform.lua |
| ThePrimeagen/harpoon (harpoon2 branch) | Migrate to lua/plugins/harpoon.lua with branch pin |
| nvim-telescope/telescope.nvim | LazyVim bundles — override via lua/plugins/telescope.lua |
| VonHeikemen/lsp-zero.nvim v3.x | REMOVE — dropping in favour of LazyVim native LSP |
| williamboman/mason.nvim | LazyVim bundles — no separate spec needed |
| williamboman/mason-lspconfig.nvim | LazyVim bundles — no separate spec needed |
| neovim/nvim-lspconfig | LazyVim bundles — no separate spec needed |
| hrsh7th/nvim-cmp | LazyVim bundles — no separate spec needed |
| hrsh7th/cmp-nvim-lsp | LazyVim bundles — no separate spec needed |
| L3MON4D3/LuaSnip | LazyVim bundles — no separate spec needed |
| nvim-tree/nvim-web-devicons | LazyVim bundles — no separate spec needed |
| nvim-neotest/neotest + adapters | Migrate to lua/plugins/neotest.lua |
| chomosuke/term-edit.nvim | Migrate with tag = "v1.*" |
| voldikss/vim-floaterm | Migrate to lua/plugins/editor.lua |
| nvim-lualine/lualine.nvim | LazyVim bundles lualine — verify no conflict with after/plugin/feline.lua |
| stevearc/dressing.nvim | Migrate to lua/plugins/ui.lua |
| MunifTanjim/nui.nvim | Migrate to lua/plugins/ui.lua |
| MeanderingProgrammer/render-markdown.nvim | Migrate; existing after/plugin/render-markdown.lua handles config |
| HakonHarnes/img-clip.nvim | Migrate to lua/plugins/editor.lua |
| folke/snacks.nvim | LazyVim bundles — no separate spec needed |
| yetone/avante.nvim | Migrate to lua/plugins/avante.lua with `build = "make"` |

**FR-007 resolved**: No module in `lua/alex/` uses any Packer API. All modules use `vim.*` APIs and `gh` CLI exclusively — they require no modification.

**LSP decision**: Drop lsp-zero entirely. Delete `after/plugin/lsp-zero.lua` and migrate its config to LazyVim's native LSP setup (mason + mason-lspconfig + nvim-lspconfig, all bundled by LazyVim). No separate `lua/plugins/lsp.lua` spec needed — LazyVim's defaults handle mason and lspconfig; only server-specific config goes into `lua/plugins/lsp.lua` via `opts`.

## Constitution Check

*GATE: Must pass before implementation. Re-check after Phase 1.*

| Principle | Assessment |
|-----------|------------|
| **I. No Unnecessary Code** | ⚠️ **Watch**: For every LazyVim-bundled plugin, use `opts = {}` override pattern rather than re-declaring a full spec. Delete `lua/alex/packer.lua` entirely once migration is complete — no dead code. |
| **II. Python Type Annotations** | ✅ N/A — Lua project |
| **III. No Silent Exception Swallowing** | ✅ N/A — Lua project |
| **IV. Logical Commits** | ⚠️ **Watch**: High risk of accumulating changes. Commit after each phase checkpoint. At minimum: one commit for bootstrap, one per plugin group, one for cleanup. Push after each. |
| **V. Backend–Frontend Separation** | ✅ N/A — Neovim config project |
| **VI. Branch Lifecycle** | ✅ Standard — delete `017-moving-neovim-config` locally and remotely after merge |

## Project Structure

### Documentation (this feature)

```text
specs/017-moving-neovim-config/
├── spec.md              # Feature specification
├── plan.md              # This file
└── tasks.md             # Phase-structured task list (created by /speckit.tasks)
```

### Source Code (config root)

```text
~/.config/nvim/
├── init.lua                          # MODIFY: replace packer bootstrap with LazyVim bootstrap
├── lua/
│   ├── alex/
│   │   ├── init.lua                  # MODIFY: remove require("alex.packer")
│   │   ├── packer.lua                # DELETE after migration complete
│   │   └── [all other modules]       # UNCHANGED
│   └── plugins/                      # NEW: lazy.nvim plugin specs
│       ├── colorschemes.lua          # vesper, vscode, vague
│       ├── editor.lua                # fugitive, floaterm, img-clip, dressing
│       ├── lsp.lua                   # LazyVim native LSP overrides (servers via opts)
│       ├── treesitter.lua            # treesitter override
│       ├── telescope.lua             # telescope override
│       ├── harpoon.lua               # harpoon2 with branch pin
│       ├── conform.lua               # conform override
│       ├── neotest.lua               # neotest + python + golang adapters
│       ├── ui.lua                    # render-markdown, nui, lualine/feline reconcile
│       └── avante.lua                # avante with build = "make"
├── after/plugin/                     # UNCHANGED (all 14 files stay as-is)
└── plugin/
    └── packer_compiled.lua           # DELETE before LazyVim bootstrap
```

**Structure Decision**: Single-config layout. LazyVim expects plugin specs in `lua/plugins/` (one file per concern). All existing `lua/alex/` modules and `after/plugin/` files are preserved; only the bootstrap layer and plugin declaration layer change.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Some LazyVim-bundled plugins may need full `config` blocks rather than `opts` | conform and telescope have complex setups in after/plugin/ that reference plugin internals | `opts` alone cannot call arbitrary setup functions with closures; `config = function() end` is the LazyVim-sanctioned escape hatch |
