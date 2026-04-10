# Tasks: Migrate Neovim Config from Packer to LazyVim

**Input**: `spec.md`, `plan.md`  
**Prerequisites**: `plan.md` (required), `spec.md` (required)

**Organization**: Tasks are grouped by user story to enable independent validation of each slice.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: Prepare the repository before any plugin manager code changes.

- [ ] T001 Commit current working state as a restore point: `git add -A && git commit -m "chore: snapshot packer config before lazyvim migration"`
- [ ] T002 [P] Delete `plugin/packer_compiled.lua` — conflicts with LazyVim's bootstrap if left in place
- [ ] T003 [P] Create `lua/plugins/` directory: `mkdir -p ~/.config/nvim/lua/plugins`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Replace the plugin manager bootstrap — nothing else works until this is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 Replace `init.lua` with the LazyVim bootstrap: install lazy.nvim via the standard git clone snippet, call `require("lazy").setup({ spec = { { import = "plugins" } }, ... })`; preserve the existing `vim.cmd([[colorscheme vesper]])`, `vim.cmd([[tnoremap <Esc> <C-\><C-n>]])`, and `vim.opt.termguicolors = true` lines after the bootstrap call
- [ ] T005 Remove `require("alex.packer")` from `lua/alex/init.lua` — packer.lua must no longer be loaded at startup
- [ ] T006 Create a minimal `lua/plugins/init.lua` returning `{}` so lazy.nvim has a valid spec dir — restart Neovim and verify `:Lazy` opens without errors even before any plugins are migrated

**Checkpoint**: Foundation ready — Neovim opens, `:Lazy` UI loads, zero crash. User story work can begin.

---

## Phase 3: User Story 1 — Editor Opens and Core Editing Works (Priority: P1) 🎯 MVP

**Goal**: LSP hover works, syntax highlighting works, all existing keymaps function, zero startup errors.

**Independent Test**: Open Neovim cold → open `lua/alex/github_dashboard.lua` → trigger LSP hover (default: `K`) → confirm no error notifications → confirm `<leader>` keymaps work.

### Implementation for User Story 1

- [ ] T007 [US1] Create `lua/plugins/colorschemes.lua`: declare `datsfilipe/vesper.nvim` with `lazy = false, priority = 1000` so it loads before `init.lua`'s `colorscheme vesper` runs; add `mofiqul/vscode.nvim` and `vague2k/vague.nvim` as plain lazy specs
- [ ] T008 [P] [US1] Create `lua/plugins/treesitter.lua`: override LazyVim's bundled treesitter spec — use `{ "nvim-treesitter/nvim-treesitter", opts = {} }` to let `after/plugin/treesitter.lua` handle all configuration (lazy.nvim sources `after/plugin/` after plugins load; no duplication needed)
- [ ] T009 [P] [US1] Create `lua/plugins/lsp.lua` for LazyVim native LSP: declare `{ "neovim/nvim-lspconfig", opts = { servers = { lua_ls = {}, ... } } }` using the same server list that was in `after/plugin/lsp-zero.lua`; add `{ "seblyng/roslyn.nvim" }` as a separate spec in the same file; delete `after/plugin/lsp-zero.lua` — LazyVim's mason + mason-lspconfig bundle handles the rest. The native LSP equivalent of lsp-zero's `default_keymaps` is already provided by LazyVim (`K` for hover, `gd` for definition, etc.)
- [ ] T010 [P] [US1] Create `lua/plugins/telescope.lua`: override LazyVim's bundled telescope spec — `{ "nvim-telescope/telescope.nvim", opts = {} }` is sufficient since `after/plugin/telescope.lua` handles keymaps and picker config; verify `after/plugin/telescope.lua` still loads cleanly
- [ ] T011 [US1] Manually verify User Story 1: 5 cold Neovim starts with zero error notifications; LSP hover works on a Lua file; `<leader>` keymaps function; syntax highlighting active; colorscheme correct

**Checkpoint**: User Story 1 complete — editor is a daily driver with zero startup errors.

---

## Phase 4: User Story 2 — All Existing Plugins Available and Configured (Priority: P2)

**Goal**: Every plugin from packer.lua is present and functional; custom `lua/alex/` modules work identically.

**Independent Test**: Open `:Lazy` — all plugins listed, no errors. Trigger GitHub dashboard keybind, open plan viewer, open a harpoon mark — all work exactly as before.

### Implementation for User Story 2

- [ ] T012 [P] [US2] Create `lua/plugins/harpoon.lua`: `{ "ThePrimeagen/harpoon", branch = "harpoon2", dependencies = { "nvim-lua/plenary.nvim" } }` — `after/plugin/harpoon.lua` handles keymaps and setup
- [ ] T013 [P] [US2] Create `lua/plugins/neotest.lua`: single spec for `nvim-neotest/neotest` with dependencies `nvim-neotest/nvim-nio`, `nvim-lua/plenary.nvim`, `antoinemadec/FixCursorHold.nvim`; add `nvim-neotest/neotest-python` and `fredrikaverpil/neotest-golang` as separate specs; `after/plugin/neotest.lua` handles adapter registration
- [ ] T014 [P] [US2] Create `lua/plugins/conform.lua`: `{ "stevearc/conform.nvim", opts = {} }` — `after/plugin/conform.lua` handles formatter config; the `opts = {}` override prevents LazyVim's default conform config from conflicting
- [ ] T015 [P] [US2] Create `lua/plugins/editor.lua`: plain specs for `tpope/vim-fugitive`, `voldikss/vim-floaterm`, `HakonHarnes/img-clip.nvim`, `stevearc/dressing.nvim`, `{ "chomosuke/term-edit.nvim", tag = "v1.*", lazy = false }` — no setup needed beyond what `after/plugin/` files provide
- [ ] T016 [P] [US2] Create `lua/plugins/ui.lua`: spec for `MeanderingProgrammer/render-markdown.nvim` (`after/plugin/render-markdown.lua` handles setup), `MunifTanjim/nui.nvim`; check whether `after/plugin/feline.lua` is the active statusline — if so, add `{ "nvim-lualine/lualine.nvim", enabled = false }` to disable LazyVim's bundled lualine and add `nvim-lualine/lualine.nvim` → actually add feline: `{ "freddiehaddad/feline.nvim" }` as the explicit spec instead
- [ ] T017 [P] [US2] Create `lua/plugins/avante.lua`: `{ "yetone/avante.nvim", branch = "main", build = "make", dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim", "HakonHarnes/img-clip.nvim" } }` — note `build` replaces packer's `run`; `after/plugin/avante.lua` handles setup
- [ ] T018 [US2] Verify User Story 2: open `:Lazy` and confirm all plugins from the plan.md inventory show as installed with no load errors; trigger GitHub dashboard, plan viewer, harpoon mark navigation, floaterm, telescope — all must work identically to pre-migration

**Checkpoint**: User Story 2 complete — all plugins present and working; all custom modules unaffected.

---

## Phase 5: User Story 3 — Config Uses LazyVim Idioms Properly (Priority: P3)

**Goal**: No packer syntax anywhere; a new plugin can be added in LazyVim style without extra wiring.

**Independent Test**: Grep for packer patterns → zero matches. Add `{ "tpope/vim-commentary" }` to `lua/plugins/editor.lua`, restart Neovim, confirm it installs, remove it.

### Implementation for User Story 3

- [ ] T019 [US3] Delete `lua/alex/packer.lua` — dead code; nothing requires it anymore
- [ ] T020 [US3] Audit all `lua/plugins/*.lua` files: for every LazyVim-bundled plugin check that it uses `opts` or `config` override rather than a full re-declaration; remove any redundant `dependencies` arrays for plugins LazyVim already wires up
- [ ] T021 [P] [US3] Grep entire config for packer patterns: `grep -r "use(" ~/.config/nvim/lua ~/.config/nvim/init.lua` and `grep -r "packer_bootstrap\|PackerSync\|packadd packer" ~/.config/nvim` — must return zero matches
- [ ] T022 [P] [US3] Remove packer's data directory to prevent old installs from shadowing lazy.nvim: `rm -rf ~/.local/share/nvim/site/pack/packer`
- [ ] T023 [US3] Smoke-test LazyVim idiom: add `{ "tpope/vim-commentary" }` to `lua/plugins/editor.lua`, restart Neovim, confirm auto-install and load via `:Lazy`, then remove the entry and confirm clean removal

**Checkpoint**: User Story 3 complete — zero packer remnants, config is idiomatic LazyVim.

---

## Final Phase: Polish

**Purpose**: Cross-cutting verification, documentation, branch cleanup.

- [ ] T024 [P] Run SC-001 verification: 5 consecutive cold Neovim starts, confirm zero error notifications each time
- [ ] T025 [P] Verify all `after/plugin/` files still load correctly: open each configured plugin (harpoon, telescope, conform, neotest, floaterm, avante, render-markdown, roslyn) and exercise its primary function once
- [ ] T026 Commit final state: `git add -A && git commit -m "feat: migrate neovim config from packer to lazyvim"` then push
- [ ] T027 Merge and delete branch per Constitution VI: `git checkout master && git merge --no-ff 017-moving-neovim-config && git branch -d 017-moving-neovim-config && git push origin --delete 017-moving-neovim-config`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — blocks all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — verify editor works before migrating the rest
- **US2 (Phase 4)**: Depends on Phase 3 — plugin migration makes no sense on a broken editor
- **US3 (Phase 5)**: Depends on Phase 4 — can't clean up packer until all plugins are migrated
- **Polish (Final)**: Depends on Phase 5

### Within Each Phase

- T002, T003 (delete compiled + mkdir) can run in parallel — different paths
- T008, T009, T010 (treesitter, LSP, telescope) can run in parallel — different files
- T012–T017 (all plugin group files) can all run in parallel — each writes a different `lua/plugins/*.lua` file
- T021, T022 (grep + rm packer data) can run in parallel — independent operations
- T019 (delete packer.lua) must precede T021 (grep) — otherwise triggers a false positive

### Parallel Opportunities

Phase 4 (T012–T017) is the largest parallelism window: all 6 plugin spec files are independent and can be written simultaneously.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (snapshot + prep)
2. Complete Phase 2: Foundational (bootstrap — **point of no return**)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Is the editor usable as a daily driver? LSP working?
5. If yes → proceed to US2. If no → debug before adding more plugins.

### Incremental Delivery

1. Setup + Foundational → LazyVim boots (verify `:Lazy` opens)
2. US1 → Editor works: LSP, keymaps, colorscheme (MVP — usable immediately)
3. US2 → All plugins back online
4. US3 → Clean config, zero packer remnants
5. Polish → Verified, committed, branch deleted

### Risk Notes

- **Point of no return**: T004 (replacing `init.lua`) — after this, packer no longer works. T001 (git snapshot) must precede it.
- **lualine vs feline** (T016): LazyVim enables lualine by default. Check `after/plugin/feline.lua` — if feline is the active statusline, explicitly disable lualine in `lua/plugins/ui.lua` to avoid two competing statuslines.
- **Commit discipline** (Constitution IV): commit after each phase checkpoint minimum. Do not accumulate all phases into one commit.
