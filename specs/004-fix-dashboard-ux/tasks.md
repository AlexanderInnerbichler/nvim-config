# Tasks: GitHub Dashboard UX Refinements

**Input**: Design documents from `/specs/004-fix-dashboard-ux/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓

**Single file**: All changes are in `lua/alex/gh_reader.lua`

---

## Phase 1: Setup

No new files, dependencies, or infrastructure needed — both fixes are edits to a single existing function and one existing function body.

- [X] T001 Verify current reader popup dimensions in `lua/alex/gh_reader.lua:258–263` (`open_popup`, `width = ui.width * 0.80`, `height = ui.height * 0.85`)

---

## Phase 2: Foundational

No shared infrastructure needed — US1 and US2 touch different functions and can proceed directly.

---

## Phase 3: User Story 1 — Consistent Reader Window Size (Priority: P1) 🎯 MVP

**Goal**: Reader popup opens at the same 90%×90% footprint as the dashboard — zero visual shift when navigating from dashboard to issue/PR

**Independent Test**: Open dashboard (`<leader>gh`), press `<CR>` on any issue → reader window must have identical outer dimensions and position as the dashboard — no shrink, no offset

### Implementation

- [X] T002 [US1] Change reader popup width from `ui.width * 0.80` to `ui.width * 0.90` in `open_popup` in `lua/alex/gh_reader.lua:260`
- [X] T003 [US1] Change reader popup height from `ui.height * 0.85` to `ui.height * 0.90` in `open_popup` in `lua/alex/gh_reader.lua:261`

**Checkpoint**: Open the dashboard and press `<CR>` on an issue — the reader window must sit at the exact same position and size as the dashboard, with no visual shift.

---

## Phase 4: User Story 2 — Floating Input Popup (Priority: P2)

**Goal**: Comment (`c`) and review (`a`) input open as a centered floating popup, not a horizontal split — editor layout is unchanged before and after

**Independent Test**: Open any issue, press `c` → a floating popup appears over the reader; press `<Esc><Esc>` → popup closes, no new splits exist

### Implementation

- [X] T004 [US2] Rewrite `M.open_input` in `lua/alex/gh_reader.lua` to replace `vim.cmd("belowright 10split")` with `vim.api.nvim_open_win` (centered, 60% width × 12 lines, rounded border, title = hint, footer = shortcut hints)
- [X] T005 [US2] Remove `prev_win` tracking from `M.open_input` in `lua/alex/gh_reader.lua` — no longer needed since popup close leaves reader focused automatically
- [X] T006 [US2] Verify `close_input` in `lua/alex/gh_reader.lua` correctly closes the floating window via `nvim_win_close` (already does — confirm no split-specific logic remains)

**Checkpoint**: Open a PR, press `c` → floating popup appears (no splits). Type text, press `<leader>s` → popup closes, reader refreshes. Press `c` again, press `<Esc><Esc>` → popup closes, layout unchanged.

---

## Phase 5: Polish

- [X] T007 Smoke test full workflow: `<leader>gh` → issue → reader same size as dashboard → `c` → floating popup → submit → reader refreshes → `q` → back to dashboard
- [X] T008 Smoke test PR workflow: `<leader>gh` → PR → `a` → select review type → floating popup → `<Esc><Esc>` → cancel with no layout change

---

## Dependencies & Execution Order

- **T002 and T003** are independent of T004–T006 (different functions) — can run in parallel
- **T004** is the core of US2; T005 is a cleanup follow-up; T006 is a verification step
- **T007 and T008** (smoke tests) must come last

### Parallel Opportunities

- T002 + T003 can be done in a single edit (same function, consecutive lines)
- T004 + T005 can be done together in one rewrite pass of `M.open_input`

---

## Implementation Strategy

### MVP (T002–T003 only)

Two-line change fixes the most visible bug (window size/position). Delivers US1 with zero risk.

### Full Delivery

T002+T003 → commit → T004+T005+T006 → commit → T007+T008 smoke test → commit → merge

---

## Notes

- No new highlight groups or helpers needed
- `close_input()` already uses `nvim_win_close` — no split-specific teardown to remove
- The `BufWipeout` autocmd in `M.open_input` handles state cleanup — keep it
- **Commit and push after each phase** (Constitution IV)
