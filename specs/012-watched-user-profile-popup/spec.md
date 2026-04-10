# Feature Specification: Watched User Profile Popup

**Feature Branch**: `012-watched-user-profile-popup`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "when i press on a watched user i want to open a new popup -> add a similar overview field with the activity heatmap for the user"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View watched user's profile and heatmap from dashboard (Priority: P1)

When browsing the "Watched Users" section in the GitHub dashboard, the user presses `<CR>` on any username row. A floating popup opens showing that user's public GitHub profile (name, bio, public repos, followers, following) along with their 26-week contribution heatmap — the same visual layout used for the logged-in user's own profile at the top of the dashboard.

**Why this priority**: This is the entire feature. The popup is the complete deliverable.

**Independent Test**: With at least one username in the watched users list, open the dashboard, navigate to the "Watched Users" section, press `<CR>` on a username row → popup opens showing that user's profile stats and heatmap. Press `q` → popup closes.

**Acceptance Scenarios**:

1. **Given** the dashboard is open with "Watched Users" showing a username row, **When** the cursor is on that row and `<CR>` is pressed, **Then** a floating popup opens displaying the username, bio, public repo count, follower/following counts, and a 26-week contribution heatmap grid
2. **Given** the popup is open, **When** the user presses `q` or `<Esc>`, **Then** the popup closes and focus returns to the dashboard
3. **Given** `<CR>` is pressed on a non-username row (separator, header, empty state), **When** pressed, **Then** nothing happens — no popup, no error
4. **Given** the watched user has no public contribution data, **When** the popup opens, **Then** the heatmap renders as all-empty and no error is surfaced

---

### User Story 2 - Open profile popup from the manager (Priority: P2)

When the watched users manager popup (`<leader>gu`) is open, the user presses `<CR>` on a username line. The same profile popup opens for that user.

**Why this priority**: Convenience — the manager is where users browse their watch list, so opening a profile from there avoids switching to the dashboard first.

**Independent Test**: Open manager with `<leader>gu`, press `<CR>` on a username → profile popup opens. Press `q` → closes, focus returns to manager.

**Acceptance Scenarios**:

1. **Given** the manager popup is open showing watched usernames, **When** `<CR>` is pressed on a username line, **Then** the profile popup opens for that user
2. **Given** the profile popup was opened from the manager, **When** the popup is closed, **Then** focus returns to the manager popup

---

### Edge Cases

- What happens when the GitHub API is unavailable or the username no longer exists? → The popup opens, shows an inline error message ("Could not load profile for USERNAME"), heatmap section absent
- What happens when contribution data cannot be fetched (GraphQL error)? → Profile stats still render; heatmap section shows a brief error row
- What happens when `<CR>` is pressed on a header, separator, or empty-state row in "Watched Users"? → No popup, no error — keymap only fires on actual username rows

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Pressing `<CR>` on a watched username row in the dashboard "Watched Users" section MUST open a profile popup for that user
- **FR-002**: The popup MUST display the user's login, display name (if set), bio (if set), public repository count, follower count, and following count
- **FR-003**: The popup MUST display a 26-week contribution heatmap grid using the same visual style as the dashboard's own profile section
- **FR-004**: The popup MUST have a title showing the username and a footer hint showing available keymaps
- **FR-005**: Pressing `q` or `<Esc>` MUST close the popup
- **FR-006**: Pressing `<CR>` on a non-username row (header, separator, empty state) MUST be a no-op
- **FR-007**: Pressing `<CR>` on a username in the watched users manager popup MUST also open the profile popup
- **FR-008**: Profile and contribution data MUST be fetched on-demand when the popup opens (no persistent caching)
- **FR-009**: While data is loading, the popup MUST show a loading indicator rather than blocking the UI
- **FR-010**: If the profile fetch fails, the popup MUST show an inline error message; the window MUST still open

### Key Entities

- **UserProfile**: login, name, bio, public_repos, followers, following — sourced from the public user profile endpoint
- **ContributionCalendar**: 26-week × 7-day grid of contribution counts and color tiers — sourced from the GitHub GraphQL API using a per-user query

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The popup opens (with at minimum a loading state) immediately on `<CR>`; full data renders within 3 seconds on a normal connection
- **SC-002**: The popup renders profile stats and a 26-week heatmap that visually matches the dashboard's own profile section layout
- **SC-003**: `<CR>` on non-username rows produces no visible effect — no error message, no popup
- **SC-004**: The popup can be dismissed with a single keypress (`q` or `<Esc>`) from any cursor position
- **SC-005**: Opening and closing the popup multiple times in sequence produces no errors or UI artifacts

## Assumptions

- The `gh` CLI token has sufficient scope to read public user profiles and contribution data for any GitHub username
- The GraphQL contribution query for another user uses `user(login: "USERNAME") { contributionsCollection { contributionCalendar { ... } } }` — same shape as the existing `viewer` query
- No persistent caching is needed — data is fetched fresh each time the popup opens
