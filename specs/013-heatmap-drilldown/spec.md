# Feature Specification: Heatmap Day Drill-Down

**Feature Branch**: `013-heatmap-drilldown`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: GitHub Issue #4 — "Heatmap drill-down — `<CR>` on a cell shows that day's activity"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Drill into a day's activity from own heatmap (Priority: P1)

While viewing the GitHub dashboard, the user moves the cursor to any cell in the contribution heatmap (the 7-row grid of their own activity). They press `<CR>`. A popup opens showing what happened on that specific day: commits pushed, pull requests opened or merged, and issues opened or closed. The activity is sourced from their GitHub event history filtered to that date.

**Why this priority**: This is the entire feature. The heatmap is the user's own contribution calendar displayed at the top of the dashboard — drilling into a cell is the primary interaction.

**Independent Test**: Navigate the cursor onto any heatmap row in the dashboard, press `<CR>` → a popup opens listing that day's activity. A cell with no contributions shows "No activity on this day". `q` closes the popup.

**Acceptance Scenarios**:

1. **Given** the dashboard is open and the cursor is on a heatmap cell with contributions, **When** `<CR>` is pressed, **Then** a popup opens showing the activity (commits, PR events, issue events) that occurred on that date
2. **Given** the dashboard is open and the cursor is on a heatmap cell with zero contributions, **When** `<CR>` is pressed, **Then** a popup opens displaying "No activity on this day"
3. **Given** the popup is open, **When** the user presses `q` or `<Esc>`, **Then** the popup closes and focus returns to the dashboard
4. **Given** the cursor is on a non-heatmap row (PR list, issue list, repos, separators), **When** `<CR>` is pressed, **Then** existing behaviour is preserved — the current item is opened, not the day drill-down

---

### User Story 2 — Drill into a day's activity from a watched user's heatmap (Priority: P2)

While the watched user profile popup is open (feature 012), the user can navigate to heatmap cells in that popup and press `<CR>`. A drill-down popup opens showing that watched user's public events on the selected date.

**Why this priority**: Extends the same interaction to the watched user heatmap introduced in 012, giving full symmetry. Lower priority since the own-heatmap drill-down is the primary use case.

**Independent Test**: Open watched user profile popup (`<CR>` on `@username` in dashboard) → move cursor to a heatmap cell → `<CR>` → day activity popup for that user opens.

**Acceptance Scenarios**:

1. **Given** a watched user's profile popup is open with the cursor on a heatmap cell, **When** `<CR>` is pressed, **Then** a popup opens showing that user's public events for that date
2. **Given** the drill-down popup was opened from a watched user popup, **When** closed, **Then** focus returns to the watched user popup

---

### Edge Cases

- What happens when event history for that date is unavailable or the API errors? → The popup opens and shows a brief error message; it does not crash or hang
- What happens when the selected date is today and events are still accumulating? → Shows whatever events have been recorded so far, no special handling needed
- What happens when `<CR>` is pressed on a day-label column (Mo/We/Fr) rather than a cell? → No popup opens — only cells with a date trigger the drill-down
- What happens when the event history doesn't go back far enough to cover the selected date? → Shows "No activity recorded for this day" (API returned empty)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Pressing `<CR>` on a heatmap contribution cell in the dashboard MUST open a drill-down popup for the date that cell represents
- **FR-002**: The popup MUST display each event that occurred on that date, grouped or listed by event type (push, pull request, issue)
- **FR-003**: Each event row in the popup MUST show the event type, the repository name, and a brief description of the action (e.g. "pushed 3 commits", "opened PR #42")
- **FR-004**: If no events occurred on the selected date, the popup MUST display a "No activity on this day" message
- **FR-005**: Pressing `q` or `<Esc>` MUST close the popup
- **FR-006**: `<CR>` on non-heatmap rows in the dashboard MUST continue to behave as before (open PR/issue/browser/profile)
- **FR-007**: Pressing `<CR>` on a heatmap cell in a watched user's profile popup MUST open the same drill-down popup showing that user's public events for that date
- **FR-008**: The popup MUST open immediately with a loading indicator; events are fetched asynchronously after the window appears

### Key Entities

- **HeatmapCell**: A rendered cell in the contribution heatmap with an associated ISO date (`YYYY-MM-DD`) and contribution count; added to `state.items` with `kind="day"` and a `date` field
- **DayActivity**: The list of public events for a specific user on a specific date, sourced from their event history; each entry has an event type, repository name, and action description

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The drill-down popup opens (with loading state) immediately on `<CR>`; activity content renders within 3 seconds on a normal connection
- **SC-002**: All heatmap cells in both the dashboard and watched user profile popup respond to `<CR>` — 100% of cells are interactive
- **SC-003**: Zero regressions on existing `<CR>` behaviour for non-heatmap rows (PRs, issues, repos, watched user headers all still open correctly)
- **SC-004**: The popup closes cleanly on `q` or `<Esc>` with no UI artifacts or focus issues

## Assumptions

- Event history is fetched from the public events endpoint filtered to the selected date; the API may not return events older than 90 days (GitHub API limitation) — in that case the "No activity recorded" message covers it
- The drill-down is read-only — no actions can be taken on events from within the popup
- The watched user drill-down (US2) uses the same popup component as the own-heatmap drill-down (US1), parameterised by username
- Day-label cells ("Mo", "We", "Fr") have no date and do not trigger any action
