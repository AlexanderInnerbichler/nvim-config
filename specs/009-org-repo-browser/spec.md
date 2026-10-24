# Feature Specification: Org Repo Browser in Dashboard

**Feature Branch**: `009-org-repo-browser`
**Created**: 2026-04-10
**Status**: Draft
**Input**: User description: "browse and watch repos from GitHub organizations the user belongs to, shown as a new section in the dashboard"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse org repos in the dashboard (Priority: P1)

When the user opens the GitHub Dashboard popup, a new "Organization Repositories" section appears after the personal repos section. It lists repos from all GitHub organizations the user belongs to, auto-detected via the `gh` CLI. The user can press `<CR>` on any org repo to open its README in the reader popup, exactly like personal repos.

**Why this priority**: The user is a member of one or more GitHub orgs and wants to keep track of those repos without switching to a browser. This is the foundational capability the rest of the story depends on.

**Independent Test**: Open dashboard → scroll to the bottom → "Organization Repositories" section lists repos from the user's orgs. Press `<CR>` on one → README popup opens.

**Acceptance Scenarios**:

1. **Given** the user belongs to one or more GitHub orgs, **When** the dashboard opens, **Then** a new "Organization Repositories" section appears listing repos from those orgs, each with name, language, stars, and age
2. **Given** an org repo is listed, **When** the user presses `<CR>` on it, **Then** the README opens in the reader popup with the breadcrumb `GitHub Dashboard › owner/repo › README`
3. **Given** the user has no org memberships, **When** the dashboard opens, **Then** the "Organization Repositories" section shows "No org repos found" and does not error
4. **Given** the org repos are loading, **When** other dashboard sections have already rendered from cache, **Then** a loading indicator appears in the org section until the fetch completes
5. **Given** the org repos section is visible, **When** the user presses `w` on an org repo row, **Then** it is added to the watchlist (same behavior as personal repos)

---

### User Story 2 - Add org repo to watchlist from dashboard (Priority: P2)

The existing `w` keymap in the dashboard already toggles a personal repo on/off the watchlist. This story ensures the same behavior works identically on org repo rows.

**Why this priority**: Without this, the org browser would be browse-only. Adding to the watchlist is the main action the user wants to take after discovering an interesting org repo. Because the `w` keymap already routes through `item.full_name`, this is likely a zero-extra-code story once US1 is done correctly.

**Independent Test**: Open dashboard, move cursor to an org repo row, press `w` → notification "Added org/repo to watchlist" appears and `gh-watchlist.json` is updated. Press `w` again → "Removed…". Verify the watchlist manager (`<leader>gw`) reflects the change.

**Acceptance Scenarios**:

1. **Given** cursor is on an org repo row, **When** user presses `w`, **Then** the repo is added/removed from the watchlist (toggle) and a confirmation notification appears
2. **Given** the same repo is already in the watchlist via another path (e.g., manually added), **When** the user presses `w` on it in the org section, **Then** it is removed (deduplication consistent with existing behavior)

---

### Edge Cases

- User belongs to many orgs with many repos — the section shows the top 10 repos per org (or a configurable limit), ordered by most recently pushed
- Org repo fetch fails (network error) — the section shows a brief error message and does not crash the dashboard
- The org list itself fails — the section is silently omitted (no error shown for a section the user may not know exists yet)
- An org repo appears in both org section and personal repos section (forked into org) — shown in both, no deduplication required

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dashboard MUST display a new "Organization Repositories" section that lists repos from all GitHub organizations the user belongs to
- **FR-002**: The org list MUST be auto-detected from the user's GitHub account — no manual configuration required
- **FR-003**: Each org repo row MUST show the same information as personal repos: name, language, star count, and last-pushed age
- **FR-004**: Pressing `<CR>` on an org repo row MUST open the repo's README in the inline reader popup, with correct breadcrumb
- **FR-005**: Pressing `w` on an org repo row MUST toggle that repo's watchlist membership (add/remove), identical to personal repos
- **FR-006**: If the user has no org memberships, the section MUST show a graceful "No org repos" message rather than error or be absent
- **FR-007**: The org section MUST load asynchronously — it MUST NOT block the rest of the dashboard from rendering from cache

### Key Entities

- **Org repo**: A repository belonging to a GitHub organization the user is a member of — carries `full_name` (owner/repo), language, stars, last-pushed date

## Assumptions

- The top 10 most recently pushed repos per org are shown (same limit as personal repos section)
- Org data is not cached separately — fetched as part of the normal dashboard refresh cycle
- No org-specific section header per org — all org repos appear under one "Organization Repositories" section, ordered by most-recently-pushed across all orgs

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Org repos appear in the dashboard within the same loading cycle as other sections (no additional wait after the dashboard fully loads)
- **SC-002**: 100% of existing dashboard behavior (PR rows, issue rows, personal repo rows, all keymaps) is preserved unchanged
- **SC-003**: `<CR>` on an org repo opens its README with the correct breadcrumb in under 2 seconds
- **SC-004**: `w` toggle on an org repo updates `gh-watchlist.json` immediately, same as personal repos
