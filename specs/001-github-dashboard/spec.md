# Feature Specification: GitHub Dashboard for Neovim

**Feature Branch**: `001-github-dashboard`  
**Created**: 2026-04-09  
**Status**: Draft  
**Input**: User description: "create new feature, i want to have complete overview of my github - similar to the ui steinpete made for apple in my neovim, i want to see my profile with the activity and open PRs issues and so on!"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Quick GitHub Status Check (Priority: P1)

As a developer working in Neovim, I want to open a GitHub dashboard that immediately shows me my open PRs and issues, so I don't need to context-switch to a browser to check what needs attention.

**Why this priority**: This is the core daily-use case — a developer glances at GitHub state without leaving the editor. Everything else builds on this.

**Independent Test**: Can be fully tested by opening the dashboard and verifying that open PRs and issues assigned to the user are displayed with correct titles and repo context.

**Acceptance Scenarios**:

1. **Given** I have open pull requests on GitHub, **When** I open the dashboard, **Then** I see all my open PRs listed with title, repository name, and PR number
2. **Given** I have open issues assigned to me, **When** I open the dashboard, **Then** I see all open issues with title, repository, and issue number
3. **Given** the dashboard is open, **When** I navigate to a PR or issue item, **Then** I can open it in my browser with a single keypress

---

### User Story 2 - Activity & Contribution Overview (Priority: P2)

As a developer, I want to see my recent GitHub activity and contribution graph displayed in the dashboard, so I can track my work output and see what I've been working on recently.

**Why this priority**: Provides self-awareness of work patterns and progress, secondary to the action-oriented PR/issue view.

**Independent Test**: Can be fully tested by verifying that recent commits, PR merges, and the contribution heatmap are visible and accurate for the authenticated user.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** I view the activity section, **Then** I see my recent activity events (commits, PR opens/merges, issue comments) in chronological order
2. **Given** the dashboard is open, **When** I view the contribution section, **Then** I see a visual contribution heatmap covering the last year
3. **Given** I have activity in multiple repositories, **When** I view the activity feed, **Then** each event shows the associated repository name and event type

---

### User Story 3 - Profile Summary (Priority: P3)

As a developer, I want to see my GitHub profile summary (avatar represented as ASCII/block art, username, follower counts, public repo count), so I have a complete at-a-glance overview.

**Why this priority**: Adds completeness and polish to the dashboard but is not critical for daily workflow.

**Independent Test**: Can be tested independently by verifying the profile panel renders the authenticated user's stats correctly.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** I view the profile section, **Then** I see my GitHub username, bio, follower count, following count, and public repo count
2. **Given** the dashboard is open, **When** profile data is loading, **Then** a loading indicator is shown in the profile area

---

### User Story 4 - Repository Overview (Priority: P4)

As a developer, I want to see a list of my most recently active repositories with their status (stars, open issues, language), so I can quickly jump into a repo's context.

**Why this priority**: Useful for context-switching between projects but lower priority than immediate action items.

**Independent Test**: Can be tested by verifying the repository list shows the user's most recently updated repos with accurate metadata.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** I view the repositories section, **Then** I see my most recently active repositories sorted by last updated date
2. **Given** I select a repository in the list, **When** I press the open key, **Then** the repository URL opens in my browser

---

### Edge Cases

- What happens when GitHub API rate limit is reached?
- How does the dashboard behave when the user has no open PRs or issues?
- What happens when network connectivity is unavailable?
- How are repositories with very long names displayed?
- What happens when the user has hundreds of open PRs/issues — is there pagination or truncation?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dashboard MUST display in a Neovim floating window or split layout that can be opened and closed with a single keybinding
- **FR-002**: The dashboard MUST show all open pull requests authored by the authenticated user, including title, repository, PR number, and age
- **FR-003**: The dashboard MUST show all open issues assigned to the authenticated user, including title, repository, issue number, and age
- **FR-004**: The dashboard MUST display a GitHub contribution heatmap for the current year
- **FR-005**: The dashboard MUST show recent activity events (last 20 events) in a scrollable feed
- **FR-006**: The dashboard MUST show user profile stats: username, bio, followers, following, public repos, starred repos
- **FR-007**: Users MUST be able to open any PR, issue, or repository in the browser directly from the dashboard
- **FR-008**: The dashboard MUST refresh data on open and support manual refresh with a keybinding
- **FR-009**: The dashboard layout MUST be clean, minimal, and visually distinct — inspired by polished Apple-aesthetic terminal UIs (clear sections, good use of whitespace, icons/symbols for visual hierarchy)
- **FR-010**: The dashboard MUST authenticate via the user's existing `gh` CLI credentials (no separate auth setup)
- **FR-011**: Data MUST be cached so the dashboard opens instantly after first load; cache should be invalidated after a configurable TTL (default: 5 minutes)
- **FR-012**: The dashboard MUST show a visual indicator when data is stale or being refreshed

### Key Entities

- **Pull Request**: GitHub PR with title, number, repository, author, creation date, labels, review status, CI status
- **Issue**: GitHub issue with title, number, repository, assignees, labels, creation date
- **Activity Event**: A GitHub event (push, PR open/merge, issue comment, fork, star) with timestamp, repo context, and description
- **Contribution Day**: A single day's contribution count, used to render the heatmap
- **User Profile**: GitHub user data — username, avatar (as text art), bio, stats (followers, following, repos)
- **Repository**: GitHub repo with name, description, language, star count, open issue count, last updated

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The dashboard opens and displays cached data in under 200ms from keybinding press
- **SC-002**: Full data refresh (all sections) completes in under 5 seconds on a normal connection
- **SC-003**: All open PRs and issues assigned to the user are visible without scrolling in a typical session (or accessible via keyboard navigation when count exceeds viewport)
- **SC-004**: A developer can check PR/issue status and open one in the browser in under 10 seconds from triggering the dashboard
- **SC-005**: The dashboard renders correctly at terminal widths of 120 characters or wider
- **SC-006**: Zero authentication setup required beyond having `gh` CLI already authenticated

## Assumptions

- The user already has `gh` (GitHub CLI) installed and authenticated — no new auth mechanism needed
- The Neovim config is Lua-based (init.lua), consistent with the existing codebase
- "steinpete's Apple UI" refers to clean, minimal, high-contrast design aesthetic with clear visual hierarchy — not a specific library requirement
- The dashboard will use existing Neovim UI patterns from the codebase (floating windows, similar to the HUD)
- Contribution heatmap will be rendered as block/braille characters in terminal
- Avatar rendering as ASCII/block art is a nice-to-have; a text-based representation is sufficient
- The dashboard covers the authenticated user's own profile (not other users' profiles)
- Notifications are out of scope for v1 (can be added later)
