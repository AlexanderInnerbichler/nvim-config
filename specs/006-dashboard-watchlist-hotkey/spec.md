# Feature Specification: Dashboard Watchlist Hotkey

**Feature Branch**: `006-dashboard-watchlist-hotkey`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "i want to bring the watchlist manager also into the github dashboard, i want to press w ontop of one of my repos and add it to the watchlist"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add repo to watchlist from dashboard (Priority: P1)

While browsing the GitHub Dashboard popup, the user positions the cursor on any repo row in the "Your Repositories" section and presses `w`. The repo is immediately added to the watchlist. A brief confirmation appears so the user knows it worked. If the repo is already watched, pressing `w` removes it instead (toggle behavior).

**Why this priority**: This is the entire feature — the ability to add a watched repo without leaving the dashboard or manually typing `owner/repo` into the watchlist manager popup. It eliminates the friction of switching between two popups.

**Independent Test**: Open dashboard (`<leader>gh`), move cursor to a repo row, press `w` → repo appears in the watchlist manager (`<leader>gw`). Verify `~/.config/nvim/gh-watchlist.json` is updated. Press `w` again on the same repo → it is removed.

**Acceptance Scenarios**:

1. **Given** the dashboard is open and cursor is on a repo row, **When** the user presses `w`, **Then** the repo is added to the watchlist and a notification confirms "Added owner/repo to watchlist"
2. **Given** the repo under the cursor is already in the watchlist, **When** the user presses `w`, **Then** the repo is removed and a notification confirms "Removed owner/repo from watchlist"
3. **Given** the cursor is on a PR row or issue row (not a repo), **When** the user presses `w`, **Then** nothing happens (no error, no side effect)

---

### Edge Cases

- Cursor is on a blank line or section header — `w` does nothing
- Watchlist file cannot be written (disk full) — silent failure, no crash
- Same repo added twice via different paths (dashboard + manual input) — duplicate is prevented, treated as already-watched

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to press `w` on a repo row in the GitHub Dashboard to add that repo to the watchlist
- **FR-002**: If the repo is already in the watchlist, pressing `w` MUST remove it (toggle)
- **FR-003**: A brief inline notification MUST confirm the action (added or removed) with the repo name
- **FR-004**: The `w` keymap MUST be a no-op when the cursor is not on a repo row (PR, issue, header, or blank line)
- **FR-005**: The watchlist MUST be persisted immediately after the add/remove action

### Key Entities

- **Repo row**: A line in the dashboard "Your Repositories" section that carries an `owner/repo` identifier
- **Watchlist entry**: `{ owner, repo, last_seen_id }` — same schema as defined in the watchlist module

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can add a repo to the watchlist in one keypress without leaving the dashboard
- **SC-002**: Toggle behavior is consistent — pressing `w` twice leaves the watchlist unchanged
- **SC-003**: The `w` key produces no visible effect when pressed on non-repo rows
- **SC-004**: Confirmation feedback appears within the same interaction cycle as the keypress
