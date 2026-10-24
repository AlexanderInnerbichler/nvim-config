# Feature Specification: PR Review Comments + Keybind Hints

**Feature Branch**: `016-pr-review-comments-hud`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "make it so the review comments also show up in the PR overview, make the comment/review and add the d instruction to the hotbar when hovering over the PR so i dont forget"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inline Review Comments in PR Overview (Priority: P1)

When the user opens a PR (pressing Enter on a PR row), the reader popup shows the full PR detail including all inline review comments posted on the diff, so the user can read code feedback without leaving Neovim.

**Why this priority**: The core value of the feature — review comments are the most important missing information from the current PR overview. Users post comments via the diff popup and naturally want to see them reflected when reading the PR.

**Independent Test**: Open any PR that has inline review comments → all review comments are visible in the PR overview with commenter, path, line reference, and comment body.

**Acceptance Scenarios**:

1. **Given** a PR with inline review comments, **When** the user presses Enter on that PR row in the dashboard, **Then** the PR overview shows a "Review Comments" section listing each comment with: the file path, line number, commenter username, and comment body.
2. **Given** a PR with no inline review comments, **When** the user opens the PR overview, **Then** no review comments section appears.
3. **Given** a PR with multiple review comments on different files, **When** the user opens the PR overview, **Then** all comments are shown in a clear list.

---

### User Story 2 - `d` Keybind Hint in Dashboard Footer on PR Row (Priority: P2)

When the cursor is on a PR row in the dashboard, the footer hotbar updates to show `d` as a shortcut for opening the diff, so the user doesn't have to remember the keybind.

**Why this priority**: Discoverability fix — the diff viewer is already implemented but invisible to users who forget the `d` shortcut.

**Independent Test**: Move cursor to a PR row → footer shows `d diff` hint. Move cursor to a non-PR row → hint disappears.

**Acceptance Scenarios**:

1. **Given** the dashboard is open and cursor is on a PR row, **When** the user looks at the footer, **Then** the footer displays `d diff` as an available action alongside existing hints.
2. **Given** the cursor is on a non-PR row (issue, repo, activity), **When** the user looks at the footer, **Then** the `d diff` hint is not shown.
3. **Given** the cursor moves from a PR row to a non-PR row, **When** the cursor moves, **Then** the footer updates immediately.

---

### User Story 3 - Keybind Hints in PR Reader Footer (Priority: P3)

When the PR reader popup is open, the footer shows all available keybinds so the user knows what actions are available.

**Why this priority**: Quality-of-life — the PR reader supports `c` (comment) and `d` (diff) actions but the footer only shows `q close`. Surfacing these hints reduces friction.

**Independent Test**: Open a PR overview → footer shows comment and diff keybinds alongside close.

**Acceptance Scenarios**:

1. **Given** the PR reader popup is open, **When** the user looks at the footer, **Then** it shows hints for all available actions: comment, diff, and close.

---

### Edge Cases

- What if fetching review comments fails (network error)? The PR overview should still load; the review comments section shows an error state rather than blocking the entire view.
- What if a PR has a very large number of review comments (50+)? All comments should be listed without crashing or truncating.
- What if the cursor is on a PR row in the activity/event feed (not the main PR list)? The `d` hint should appear there too if `d` is supported on those rows.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The PR overview MUST display all inline review comments for the PR, each showing: file path, line number, commenter username, and comment body.
- **FR-002**: Review comments MUST be fetched when the PR overview is opened (same lifecycle as the rest of PR data).
- **FR-003**: If a PR has no inline review comments, the PR overview MUST NOT show an empty review comments section.
- **FR-004**: The dashboard footer MUST display a `d diff` keybind hint when the cursor is on a PR row.
- **FR-005**: The dashboard footer MUST NOT show the `d diff` hint when the cursor is on a non-PR row.
- **FR-006**: The PR reader popup footer MUST show keybind hints for comment and diff actions alongside the existing close hint.

### Key Entities

- **ReviewComment**: An inline comment attached to a specific file and line of a PR diff. Attributes: commenter username, file path, line number, and body text.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A PR with inline review comments shows all comments within the same load time as the existing PR description (under 3 seconds total).
- **SC-002**: The dashboard footer updates to show or hide the `d diff` hint within one cursor move, with no perceptible delay.
- **SC-003**: 100% of available keybinds for the PR reader popup are visible in its footer.
- **SC-004**: No regression — existing PR overview content (description, CI status, review approvals) continues to display correctly.

## Assumptions

- "Review comments" means inline diff comments; general PR comments (top-level) are already shown and are out of scope.
- The `d` keybind in the dashboard already works on PR rows (feature 014); this feature only adds the visual hint.
- The PR reader already supports `c` to post a comment (feature 015); this feature only adds the footer hint for it.
- The dynamic footer hint for `d` requires tracking cursor position in the dashboard (a CursorMoved autocmd or equivalent).
