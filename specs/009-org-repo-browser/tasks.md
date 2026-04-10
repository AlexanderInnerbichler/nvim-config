# Tasks: Org Repo Browser in Dashboard

**Input**: Design documents from `/specs/009-org-repo-browser/`
**Prerequisites**: plan.md ✓, spec.md ✓

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

**Purpose**: No new files or dependencies needed — all changes are additive to one existing file.

- [X] T001 Verify `gh api /user/orgs` returns org list for current user (manual check: `gh api /user/orgs | head`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure shared by both user stories — the `fetch_org_repos` function and `render_org_repos` function must exist before either story can be wired up.

- [X] T002 Add `fetch_org_repos(callback)` to `lua/alex/github_dashboard.lua` after `fetch_repos` (~line 297) — calls `gh api /user/orgs`, fans out per-org to `gh repo list --owner ORG --limit 10 --json name,nameWithOwner,url,primaryLanguage,stargazerCount,isPrivate,pushedAt`, merges and sorts by `pushedAt` desc; org-list failure silently returns `{}`; per-org fetch errors surfaced via `any_err`
- [X] T003 Add `render_org_repos(lines, hl_specs, items, org_repos, err)` to `lua/alex/github_dashboard.lua` after `render_repos` (~line 513) — same structure as `render_repos`; section omitted entirely when no orgs and no error; items get `kind="repo"` + `full_name` + `url`

**Checkpoint**: Both functions defined and syntactically correct — `:luafile %` on the file should produce no errors

---

## Phase 3: User Story 1 — Browse org repos in the dashboard (Priority: P1) 🎯 MVP

**Goal**: "Organization Repositories" section appears in the dashboard, loads asynchronously, shows org repos with correct metadata, `<CR>` opens README.

**Independent Test**: Open dashboard → scroll to bottom → "Organization Repositories" section lists repos. Press `<CR>` on one → README popup opens with breadcrumb `GitHub Dashboard › owner/repo › README`.

- [X] T004 [US1] Wire `render_org_repos` into `apply_render` in `lua/alex/github_dashboard.lua` — add call after `render_repos(...)` line (~line 534): `render_org_repos(lines, hl_specs, items, data.org_repos, data.org_repos_err)`
- [X] T005 [US1] Wire `fetch_org_repos` into `fetch_and_render` in `lua/alex/github_dashboard.lua` — in `start_secondary_fetches`, increment `pending` from `+3` to `+4` and add `fetch_org_repos(function(err, org_repos) if err then state.data.org_repos_err = err else state.data.org_repos = org_repos end; done(err ~= nil) end)`

**Checkpoint**: Open dashboard → "Organization Repositories" section visible. Press `<CR>` → README popup. Press `q` → returns to dashboard.

---

## Phase 4: User Story 2 — Add org repo to watchlist from dashboard (Priority: P2)

**Goal**: `w` keymap on org repo rows toggles watchlist membership identically to personal repos.

**Independent Test**: Move cursor to an org repo row, press `w` → "Added org/repo to watchlist" notification; `gh-watchlist.json` updated. Press `w` again → "Removed…".

- [X] T006 [US2] Verify zero-extra-code: confirm that `toggle_watch_at_cursor` in `lua/alex/github_dashboard.lua` reads `item.full_name` from `state.items` — since T003 already inserts org repo items with `full_name`, the `w` keymap requires no code changes; document outcome as a comment in tasks

**Checkpoint**: `w` on org repo row adds/removes from watchlist. `w` on personal repo row still works. Watchlist manager (`<leader>gw`) reflects the change.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T007 Manual smoke test: open dashboard with no org memberships → "Organization Repositories" section absent (not shown), no errors
- [X] T008 Manual smoke test: simulate network error on org fetch (disconnect, then open dashboard) → section shows error message, rest of dashboard loads normally
- [X] T009 Commit: `feat: org repo browser — Organization Repositories section in dashboard` and push to `009-org-repo-browser`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 (T002 + T003 must exist)
- **US2 (Phase 4)**: Depends on Phase 3 (T004 + T005 must be wired before verifying w keymap)
- **Polish (Phase 5)**: Depends on all stories complete

### Within Each User Story

- T004 and T005 are sequential (T004 wires render, T005 wires fetch — both needed for a working section)
- T006 is a verification-only task; no code changes expected

### Parallel Opportunities

No meaningful parallelism — all changes are in one file and one story depends on the prior.

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Phase 1: Verify `gh api /user/orgs` works
2. Phase 2: Add `fetch_org_repos` + `render_org_repos`
3. Phase 3: Wire both into `apply_render` and `fetch_and_render`
4. **VALIDATE**: Open dashboard → org section visible, `<CR>` → README, `q` → back

### Incremental Delivery

1. Foundation (T002 + T003) → Functions exist, not yet visible in UI
2. US1 wiring (T004 + T005) → Section appears in dashboard → MVP complete
3. US2 verification (T006) → Confirm `w` works for free
4. Polish (T007–T009) → Smoke tests + commit

---

## Notes

- T006 is expected to require zero code changes — the `w` keymap already routes via `item.full_name` which org repo items carry. If it does need a fix, update the item insertion in T003.
- Org list failure is intentionally silent (returns `{}`). Per-org fetch failure shows an error in the section. This is specified in plan.md Phase A.
- `kind="repo"` on org repo items means `<CR>` routing to `gh_reader.open` is already handled — no changes to `gh_reader.lua` needed.
