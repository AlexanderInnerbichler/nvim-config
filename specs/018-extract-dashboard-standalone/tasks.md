# Tasks: Extract gh_dashboard as Standalone Neovim Plugin

**Input**: `spec.md`, `plan.md`  
**Prerequisites**: `plan.md` (required), `spec.md` (required)

**Organization**: Tasks are grouped by user story to enable independent validation of each slice.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: Create the standalone plugin repo and establish its structure.

- [x] T001 Create `~/code/gh_dashboard.nvim/` directory and run `git init` inside it
- [x] T002 [P] Create `~/code/gh_dashboard.nvim/lua/gh_dashboard/` and `~/code/gh_dashboard.nvim/plugin/` directories

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Copy the 7 existing modules into the new repo — nothing else can be tested until the plugin can load.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T003 Copy all 7 modules from `~/.config/nvim/lua/gh_dashboard/` into `~/code/gh_dashboard.nvim/lua/gh_dashboard/` verbatim — no code changes yet: `cp ~/.config/nvim/lua/gh_dashboard/*.lua ~/code/gh_dashboard.nvim/lua/gh_dashboard/`
- [x] T004 Write `~/code/gh_dashboard.nvim/plugin/gh_dashboard.lua` — the autoload entry point. It must check for a module-level `_setup_called` guard so `setup()` is not double-invoked if a user also calls it manually:
  ```lua
  if vim.g.gh_dashboard_loaded then return end
  vim.g.gh_dashboard_loaded = true
  -- keymaps and setup() are registered lazily via require("gh_dashboard").setup()
  -- The plugin entry point is intentionally minimal; consumers call setup() themselves.
  ```
- [x] T005 `git add -A && git commit -m "feat: initial gh_dashboard.nvim plugin with 7 modules and entry point"` inside `~/code/gh_dashboard.nvim/`

**Checkpoint**: Foundation ready — `require("gh_dashboard")` resolves from the new repo when it is on `runtimepath`. User story work can begin.

---

## Phase 3: User Story 1 — Plugin Runs from Its Own Repository (Priority: P1) 🎯 MVP

**Goal**: A minimal Neovim config that installs only `gh_dashboard.nvim` can open the dashboard without errors.

**Independent Test**: Create `~/.config/nvim-test/init.lua` containing only the lazy.nvim bootstrap and `{ dir = "~/code/gh_dashboard.nvim", lazy = false }`. Launch `NVIM_APPNAME=nvim-test nvim`, call `require("gh_dashboard").setup()` in the cmdline, open the dashboard with `<leader>gh` — all panels render, no Lua errors.

### Implementation for User Story 1

- [x] T006 [US1] Verify the plugin loads cleanly from the new dir by temporarily adding `{ dir = "~/code/gh_dashboard.nvim", lazy = false }` to `~/.config/nvim/lua/plugins/` **in addition** to the existing `lua/gh_dashboard/` directory on runtimepath — both must coexist without `require()` conflicts (same namespace, later path wins)
- [x] T007 [US1] Write `~/code/gh_dashboard.nvim/README.md` with: install snippet (lazy.nvim `dir =` and GitHub URL variants), minimal `setup({})` call, list of keymaps, and `gh` CLI prerequisite
- [x] T008 [US1] `git add -A && git commit -m "docs: add README with install and setup instructions"` inside `~/code/gh_dashboard.nvim/`

**Checkpoint**: User Story 1 complete — plugin loads and renders from its own repo directory.

---

## Phase 4: User Story 2 — Parent Config Uses Plugin Dir, Inline Modules Deleted (Priority: P2)

**Goal**: `~/.config/nvim/lua/gh_dashboard/` is fully deleted and replaced by the `dir =` spec — zero behavior change.

**Independent Test**: Delete `lua/gh_dashboard/` from the nvim config, restart Neovim — all 4 keymaps (`<leader>gh`, `<leader>gw`, `<leader>gn`, `<leader>gu`) and all 5 panels (heatmap, contributions total, PR list, watchlist, user profile) work identically. Zero error notifications on cold start.

### Implementation for User Story 2

- [x] T009 [US2] Add `~/.config/nvim/lua/plugins/gh_dashboard.lua`:
  ```lua
  return {
    { dir = vim.fn.expand("~/code/gh_dashboard.nvim"), lazy = false },
  }
  ```
- [x] T010 [US2] Remove the 4 `require("gh_dashboard*").setup()` calls from `~/.config/nvim/lua/alex/init.lua` — move `setup()` calls into `~/.config/nvim/after/plugin/gh_dashboard.lua` (new file) so they fire after the plugin loads:
  ```lua
  require("gh_dashboard").setup()
  require("gh_dashboard.reader").setup()
  require("gh_dashboard.watchlist").setup()
  require("gh_dashboard.user_watchlist").setup()
  ```
- [x] T011 [US2] Delete `~/.config/nvim/lua/gh_dashboard/` entirely: `rm -rf ~/.config/nvim/lua/gh_dashboard/`
- [x] T012 [US2] Restart Neovim and verify: 3 cold starts, zero error notifications, all 4 keymaps respond, heatmap and PR panels render correctly
- [ ] T013 [US2] `git add -A && git commit -m "feat: load gh_dashboard via plugin dir spec, remove inline modules"` in the nvim config repo

**Checkpoint**: User Story 2 complete — `lua/gh_dashboard/` is gone from the config, dashboard works via plugin path.

---

## Phase 5: User Story 3 — checkhealth Handler + Public Entry Point (Priority: P3)

**Goal**: `:checkhealth gh_dashboard` reports actionable status; a stranger can install from the README.

**Independent Test**: Run `:checkhealth gh_dashboard` on a correctly configured system — see green OK lines for `gh` CLI presence, auth status, and `read:user` scope. Remove `gh` from PATH temporarily — see a clear ERROR with fix instructions.

### Implementation for User Story 3

- [ ] T014 [P] [US3] Create `~/code/gh_dashboard.nvim/lua/gh_dashboard/health.lua`:
  ```lua
  local M = {}
  M.check = function()
    vim.health.start("gh_dashboard")
    -- check 1: gh binary
    if vim.fn.executable("gh") == 1 then
      vim.health.ok("gh CLI found: " .. vim.fn.system("gh --version"):match("[^\n]+"))
    else
      vim.health.error("gh CLI not found", { "Install gh: https://cli.github.com" })
    end
    -- check 2: auth status
    local auth = vim.fn.system("gh auth status 2>&1")
    if vim.v.shell_error == 0 then
      vim.health.ok("gh authenticated")
    else
      vim.health.error("gh not authenticated", { "Run: gh auth login" })
    end
    -- check 3: read:user scope
    if auth:find("read:user") or auth:find("read_user") then
      vim.health.ok("read:user scope present")
    else
      vim.health.warn("read:user scope not confirmed", { "Run: gh auth refresh -s read:user" })
    end
  end
  return M
  ```
- [ ] T015 [P] [US3] Register the health module by adding to `~/code/gh_dashboard.nvim/plugin/gh_dashboard.lua`:
  ```lua
  -- register :checkhealth handler
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "health",
    once = true,
    callback = function() require("gh_dashboard.health") end,
  })
  ```
  Actually, Neovim discovers health modules automatically at `lua/PLUGIN/health.lua` when the module name matches — no manual registration needed. Remove the autocmd; the file location is sufficient.
- [ ] T016 [US3] Verify `:checkhealth gh_dashboard` runs and produces output (green on working system, red/yellow if `gh` is misconfigured)
- [ ] T017 [US3] `git add -A && git commit -m "feat: add checkhealth handler for gh CLI, auth, and scope validation"` inside `~/code/gh_dashboard.nvim/`

**Checkpoint**: User Story 3 complete — `:checkhealth gh_dashboard` works, README sufficient for a stranger to install.

---

## Phase 6: Polish

**Purpose**: Final verification, branch cleanup.

- [ ] T018 [P] Run SC-001 verification: minimal `NVIM_APPNAME=nvim-test nvim` config with only `gh_dashboard.nvim` installed — dashboard opens cold, zero errors
- [ ] T019 [P] Run SC-002 verification: confirm `~/.config/nvim/lua/gh_dashboard/` directory does not exist (`ls ~/.config/nvim/lua/` must not show `gh_dashboard`)
- [ ] T020 [P] Run SC-005 regression check: all 4 keymaps (`<leader>gh`, `<leader>gw`, `<leader>gn`, `<leader>gu`) produce correct output; heatmap Sunday-first row order preserved
- [ ] T021 Merge and delete branch: `git checkout master && git merge --no-ff 018-extract-dashboard-standalone && git branch -d 018-extract-dashboard-standalone && git push && git push origin --delete 018-extract-dashboard-standalone`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — blocks all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — verify plugin loads before touching config
- **US2 (Phase 4)**: Depends on Phase 3 — must confirm standalone load before deleting inline modules
- **US3 (Phase 5)**: Depends on Phase 2 only — `health.lua` is additive, safe to do in parallel with US2 if desired
- **Polish (Phase 6)**: Depends on all user stories

### Within Each Phase

- T003 and T004 (copy modules + write entry point) can run in parallel — different files
- T009 and T010 (add plugin spec + move setup calls) can run in parallel — different files
- T014 and T015 (`health.lua` + entry point update) are noted as [P] but T015 is actually a no-op (Neovim auto-discovers) — both touch the same repo, sequence them
- T018, T019, T020 (polish verifications) can all run in parallel — read-only

### Parallel Opportunities

US3 (health handler) is the largest independent slice — it touches only `health.lua` in the plugin repo and has no dependency on the parent config changes in US2.

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. Phase 1 + 2: Create repo and copy modules
2. Phase 3: Verify plugin loads standalone
3. Phase 4: **CRITICAL** — delete inline modules from config
4. **STOP and VALIDATE**: Is daily driving still intact? All keymaps and panels work?
5. If yes → Phase 5 (health). If no → debug before continuing.

### Incremental Delivery

1. Phase 1–2 → Plugin repo exists and loads
2. Phase 3 → Confirmed standalone (MVP — plugin is portable)
3. Phase 4 → Config cleaned up (parent config no longer ships the source)
4. Phase 5 → Public-quality polish (health + README)
5. Phase 6 → Verified, merged, branch deleted

### Risk Notes

- **Point of no return**: T011 (`rm -rf lua/gh_dashboard/`) — after this, `lua/gh_dashboard/` is gone from the config. T012 (verify 3 cold starts) MUST precede it or immediately follow before committing.
- **Namespace collision**: While both `lua/gh_dashboard/` and the `dir =` spec coexist (T006), Neovim will use whichever appears first on runtimepath. Test with only the plugin dir, not both simultaneously.
- **after/plugin/ timing** (T010): Moving `setup()` calls to `after/plugin/gh_dashboard.lua` is the correct LazyVim pattern — this file runs after all plugins load, so the `lazy = false` spec guarantees the plugin is present.
