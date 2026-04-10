# Tasks: Heatmap Colors and Repo README Viewer

**Input**: Design documents from `/specs/008-heatmap-repo-readme/`
**Prerequisites**: plan.md ✓, spec.md ✓

**New files**: none  
**Modified files**: `lua/alex/github_dashboard.lua`, `lua/alex/gh_reader.lua`

---

## Phase 2: User Story 1 — Cooler heatmap palette (Priority: P1) 🎯

**Goal**: Replace the 5 `GhHeat*` highlight colors with a teal-shifted vibrant green gradient.

**Independent Test**: Open dashboard (`<leader>gh`). Contribution heatmap shows five clearly distinct shades of cool green — near-invisible navy, deep forest teal, emerald, bright teal-green, neon mint — with strong contrast between levels.

- [X] T001 [P] [US1] Replace the 5 `GhHeat*` colors in `setup_highlights()` in `lua/alex/github_dashboard.lua` (lines ~131–135): `GhHeat0 = #1b1f2b` (dark navy), `GhHeat1 = #0d4a3a` (deep teal), `GhHeat2 = #0a7a5c` (emerald), `GhHeat3 = #10c87e` (bright teal-green), `GhHeat4 = #00ff99` (neon mint); keep `bg = "NONE"` on all

**Checkpoint**: Dashboard heatmap shows the new vibrant teal-green gradient.

---

## Phase 3: User Story 2 — Repo README viewer (Priority: P1)

**Goal**: `<CR>` on a repo row opens the README in the inline reader popup instead of a browser.

**Independent Test**: Open dashboard, press `<CR>` on a repo row → README popup opens with breadcrumb `GitHub Dashboard › owner/repo › README`. Headings, code blocks, bullets render. Press `q` → focus returns to dashboard. Repo with no README shows error message.

- [X] T002 [P] [US2] Add `kind = "repo"` to the items table insertion in `render_repos` in `lua/alex/github_dashboard.lua` (~line 507): change `table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name })` to `table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name, kind = "repo" })`
- [X] T003 [US2] Update `open_url_at_cursor` in `lua/alex/github_dashboard.lua` (~line 612): add `elseif item.kind == "repo" then require("alex.gh_reader").open(item)` between the existing `pr/issue` branch and the `else` (xdg-open) branch, so repo rows route to the reader
- [X] T004 [US2] Add `fetch_readme(item, callback)` local function in `lua/alex/gh_reader.lua` (place near other fetch functions ~line 294): uses `vim.system({ "gh", "api", "repos/" .. item.full_name .. "/readme", "-H", "Accept: application/vnd.github.raw" }, { text = true }, ...)` — on success calls `callback(nil, result.stdout)`; on failure (`result.code ~= 0`) calls `callback("No README found", nil)`; wraps result in `vim.schedule`
- [X] T005 [US2] Add `render_readme(data)` local function in `lua/alex/gh_reader.lua` (place after `render_pr` ~line 637): builds breadcrumb line `"  GitHub Dashboard  ›  " .. data.full_name .. "  ›  README"` with `GhReaderBreadcrumb` / `GhReaderTitle` highlights; adds separator; calls `process_body(data.body, lines, hl_specs)`; calls `open_popup(data.full_name .. "  README", "q back")`; calls `write_buf(lines, hl_specs)`
- [X] T006 [US2] Add `kind = "repo"` branch in `M.open(item)` in `lua/alex/gh_reader.lua` (~line 767): update the loading-state label to use `item.full_name or ("#" .. tostring(item.number or "…"))` so repos show the repo name; add `elseif item.kind == "repo" then` block that calls `fetch_readme(item, callback)` and on success calls `render_readme({ full_name = item.full_name, body = body })`, on error writes the error to the buffer

**Checkpoint**: Full README flow works end-to-end: `<CR>` on repo → README renders → `q` returns to dashboard.

---

## Dependencies & Execution Order

- **T001** (US1, dashboard.lua) and **T002** (US2, dashboard.lua) are in different files — can start in parallel
- **T001** is fully independent of all US2 tasks
- **T002** must precede T003 (T003 relies on `kind="repo"` being in items)
- **T003** can be done immediately after T002 (same file, sequential)
- **T004** and **T005** can start as soon as T002 is done — different functions in gh_reader.lua, no deps between them
- **T006** must come after T004 and T005 (calls both)

### Parallel Opportunities

- T001 + T002 can start simultaneously (different files)
- T004 + T005 can run in parallel (different functions, same file but no conflict)
- T003 and T004+T005 can run simultaneously after T002 completes

---

## Implementation Strategy

Both stories are P1 with no foundational blockers. Implement T001 and T002 in parallel, then complete T003–T006 sequentially. Smoke test, commit each phase, push.

---

## Notes

- `Accept: application/vnd.github.raw` returns plain-text README directly — no base64 decoding needed
- `process_body` is already a local function in `gh_reader.lua` — accessible from `render_readme`
- `separator()`, `open_popup()`, `write_buf()` are all local to `gh_reader.lua` — accessible from `render_readme`
- `state.item` is set at the top of `M.open` — `register_keymaps`'s `back()` function (q/Esc) calls `require("alex.github_dashboard").focus_win()` which already handles the back-nav correctly
- **Commit after each phase** (Constitution IV)
