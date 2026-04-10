# Feature Specification: Org Team Activity Feed

**Feature Branch**: `010-org-team-activity`
**Created**: 2026-04-10
**Status**: Draft
**Input**: Issue #5 — "Org member activity feed — Team section in dashboard"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse team activity in the dashboard (Priority: P1)

When the user opens the GitHub Dashboard, a new "Team Activity" section appears below "Organization Repositories". It lists recent events from all members of the user's GitHub organizations — pushes, PRs, issues, comments — showing who did what, in which repo, and how long ago. The section loads asynchronously and does not block the rest of the dashboard.

**Why this priority**: The user works in one or more GitHub orgs and wants a single-pane view of what the team is doing without opening a browser or switching context. This is the core value of the feature.

**Independent Test**: Open dashboard → scroll to bottom → "Team Activity" section lists recent events from org members with actor name, event type, repo, and age. Section appears after other sections finish loading.

**Acceptance Scenarios**:

1. **Given** the user belongs to one or more GitHub orgs, **When** the dashboard opens, **Then** a "Team Activity" section appears listing recent events from org members (up to 10 total across all orgs), each showing: actor username, event type, repo name, and age
2. **Given** the section is loading, **When** other sections have already rendered from cache, **Then** the "Team Activity" section shows nothing until its fetch completes (async, non-blocking)
3. **Given** the user belongs to no orgs, **When** the dashboard opens, **Then** the "Team Activity" section is silently absent — not shown, no error message
4. **Given** the org events fetch fails, **When** the dashboard renders, **Then** the "Team Activity" section shows a brief error message; the rest of the dashboard is unaffected
5. **Given** the section is visible with multiple event types, **Then** each row shows a distinct icon or label for the event type (push, PR, issue, comment, star, fork)

---

### User Story 2 - Open a team event in the reader (Priority: P2)

Pressing `<CR>` on a team activity row that corresponds to a PR or issue event opens it directly in the existing inline reader popup — the same experience as pressing `<CR>` on a personal PR or issue row. For events with no associated PR/issue (push, star, fork), `<CR>` opens the repo URL in the browser.

**Why this priority**: Browse-only is useful but the ability to jump straight into a PR or issue for review closes the loop. Without this the user still has to open a browser for any actionable event.

**Independent Test**: Move cursor to a PR-event row in Team Activity → press `<CR>` → PR reader popup opens with correct PR details and breadcrumb `GitHub Dashboard › owner/repo › #N`. Press `q` → returns to dashboard.

**Acceptance Scenarios**:

1. **Given** cursor is on a PullRequestEvent or IssuesEvent row, **When** user presses `<CR>`, **Then** the PR or issue opens in the inline reader with correct breadcrumb
2. **Given** cursor is on a PushEvent, ForkEvent, or WatchEvent row, **When** user presses `<CR>`, **Then** the repo URL opens in the browser
3. **Given** the reader is already open for another item, **When** the user navigates back and opens a team event, **Then** the reader shows the correct team event content with no stale data

---

### Edge Cases

- Org has many active members with many recent events — capped at 10 most-recent events total across all orgs, ordered by `created_at` descending
- An event belongs to the user themselves — shown in the feed (no self-filtering); the actor name makes ownership clear
- Org events fetch partially fails (one org errors, others succeed) — successful orgs' events are shown; per-org errors are silently ignored
- Event type not in the known label map (e.g., a new GitHub event type) — rendered as generic "activity" with repo name; does not error

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dashboard MUST display a "Team Activity" section listing recent events from all GitHub organizations the user belongs to
- **FR-002**: The org list MUST be auto-detected from the user's GitHub account — no manual configuration required
- **FR-003**: Each team activity row MUST show: actor username, event type label, repository name, and relative age
- **FR-004**: The "Team Activity" section MUST load asynchronously and MUST NOT block the rest of the dashboard from rendering from cache
- **FR-005**: The section MUST be silently absent when the user has no org memberships
- **FR-006**: Pressing `<CR>` on a PR or issue event row MUST open that item in the existing inline reader popup
- **FR-007**: Pressing `<CR>` on non-reader event rows (push, fork, star) MUST open the repo URL in the browser
- **FR-008**: The section MUST show at most 10 events total across all orgs, ordered by most-recently-created first
- **FR-009**: If org events fetch fails, the section MUST show a brief error message rather than crashing or silently showing nothing

### Key Entities

- **Team event**: A GitHub event from an org member — carries actor username, event type, repo full name, creation timestamp, and optional payload (PR number or issue number) for deep-linking into the reader

## Assumptions

- Events are fetched from the org events endpoint, which returns events visible to the authenticated user
- The same org list auto-detected by the org repo browser (feature 009) is reused — no separate org-detection call needed
- Team events are not cached separately — fetched as part of the normal dashboard refresh cycle
- No per-org breakdown in the UI — all org events appear under one "Team Activity" section sorted by time
- The event actor may be the user themselves; no self-filtering is applied

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Team activity events appear in the dashboard within the same loading cycle as other async sections (no additional wait after org repos load)
- **SC-002**: 100% of existing dashboard behavior (PR rows, issue rows, personal repo rows, org repo rows, all keymaps) is preserved unchanged
- **SC-003**: `<CR>` on a PR or issue team event opens the reader with correct content in under 2 seconds
- **SC-004**: The section is absent (zero rows, no error shown) when the user has no org memberships
