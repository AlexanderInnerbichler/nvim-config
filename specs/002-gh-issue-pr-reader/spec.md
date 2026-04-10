# Feature Specification: GitHub Issue & PR Inline Reader

**Feature Branch**: `002-gh-issue-pr-reader`  
**Created**: 2026-04-09  
**Status**: Draft  
**Input**: User description: "build on top of the github dashboard — endgoal is i dont want to read issues or MergeRequests in the UI again"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Read a Full Issue Without Leaving Neovim (Priority: P1)

As a developer working in Neovim, I want to open any issue from the dashboard and read its full body, description, labels, and comment thread inline, so I never need to switch to a browser just to understand what an issue is asking for.

**Why this priority**: Reading is the most fundamental action. Without it, nothing else is possible. This is the MVP that unlocks all other stories.

**Independent Test**: Navigate to an issue in the dashboard, press `<CR>`, and verify the full issue body and all comments render in a Neovim buffer with correct formatting.

**Acceptance Scenarios**:

1. **Given** the dashboard shows an assigned issue, **When** I press `<CR>` on it, **Then** a reader pane opens showing: issue title, author, labels, state (open/closed), body (markdown rendered), and all comments in chronological order
2. **Given** the reader is open, **When** the issue body contains markdown (code blocks, lists, headers), **Then** it renders with appropriate visual formatting
3. **Given** the reader is open, **When** I press `q` or `<Esc>`, **Then** the pane closes and focus returns to the dashboard

---

### User Story 2 — Read a Full Pull Request Without Leaving Neovim (Priority: P1)

As a developer, I want to open any pull request from the dashboard and read its description, review comments, and CI status inline, so I understand the full context of a PR without opening GitHub in a browser.

**Why this priority**: Co-equal with issue reading — PRs are arguably more urgent daily items than issues.

**Independent Test**: Navigate to a PR in the dashboard, press `<CR>`, and verify the PR body, metadata (branch, reviewer, CI status), and review comment thread render correctly.

**Acceptance Scenarios**:

1. **Given** the dashboard shows an open PR, **When** I press `<CR>` on it, **Then** a reader pane opens showing: PR title, author, source/target branch, reviewers, CI check status (pass/fail/pending), body, and review comments
2. **Given** a PR has failing CI checks, **When** I view it in the reader, **Then** the failed check names are visible with their status
3. **Given** the PR reader is open, **When** I press `q`, **Then** the pane closes

---

### User Story 3 — Post a Comment on an Issue or PR (Priority: P2)

As a developer, I want to write and submit a comment on any issue or PR directly from the reader, so I can participate in discussions without ever touching a browser.

**Why this priority**: Reading without commenting means I still need to go to the browser for any interaction. This closes that gap.

**Independent Test**: Open an issue reader, trigger the comment flow, type a comment, submit it, and verify the comment thread updates with the new comment.

**Acceptance Scenarios**:

1. **Given** the issue reader is open, **When** I press `c`, **Then** an edit buffer opens where I can write a comment in markdown
2. **Given** I have written a comment, **When** I save and confirm, **Then** the comment is posted to GitHub and the reader refreshes to show it
3. **Given** I am writing a comment, **When** I press `<Esc>` or discard, **Then** no comment is posted and the reader remains open
4. **Given** I submit a comment, **When** the post succeeds, **Then** a brief success notification appears

---

### User Story 4 — Approve or Request Changes on a PR (Priority: P2)

As a developer, I want to submit a review decision (approve, request changes, or comment) on a PR directly from the reader, so I can complete a code review without switching to the browser.

**Why this priority**: Approval is the natural endpoint of a code review — if I can read but not act, the flow is incomplete.

**Independent Test**: Open a PR reader, trigger the review flow, select "Approve", add an optional comment, submit, and verify the PR reflects the approval.

**Acceptance Scenarios**:

1. **Given** the PR reader is open, **When** I press `a`, **Then** I am prompted to choose a review type: Approve / Request Changes / Comment
2. **Given** I select "Approve", **When** I confirm, **Then** my approval is submitted to GitHub and the PR reader shows my review
3. **Given** I select "Request Changes", **When** I type a reason and confirm, **Then** the review with changes requested is submitted
4. **Given** I am not a reviewer on the PR, **When** I submit a comment-only review, **Then** it is posted as a general review comment

---

### User Story 5 — Manage Issue/PR State (Priority: P3)

As a developer, I want to close issues, merge PRs, and change labels directly from the reader, so I can fully action items without the browser.

**Why this priority**: Closing issues and merging PRs are high-frequency final actions. Without them the workflow always ends with a browser trip.

**Independent Test**: Open a PR reader, trigger merge, confirm, verify the PR state changes to "merged" and the dashboard reflects this on next refresh.

**Acceptance Scenarios**:

1. **Given** the PR reader is open and the PR is mergeable, **When** I press `m`, **Then** I am shown a confirmation prompt with the merge method options (merge commit / squash / rebase)
2. **Given** I confirm a merge, **When** the merge succeeds, **Then** the PR reader updates to show "Merged" and a notification appears
3. **Given** the issue reader is open, **When** I press `x`, **Then** I am asked to confirm closing the issue
4. **Given** I confirm close, **When** the close succeeds, **Then** the reader shows the issue as "Closed" and the dashboard removes it from the active list on next refresh

---

### Edge Cases

- What happens when a PR has merge conflicts (cannot auto-merge)?
- How are very long issue bodies handled — is there scrolling?
- What if a comment post fails due to network error?
- What if the user lacks permission to merge or close?
- How are issues/PRs with 100+ comments displayed?
- What happens when markdown contains embedded images (which can't render in terminal)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The reader MUST open inline (within Neovim, no browser) when activating an issue or PR from the dashboard
- **FR-002**: The reader MUST display: title, author, state, labels, creation date, body (markdown formatted), and all comments with author and timestamp
- **FR-003**: PR reader MUST additionally display: source branch → target branch, list of reviewers and their review states, CI check names and statuses (pass/fail/pending)
- **FR-004**: The reader MUST be scrollable for long content
- **FR-005**: Users MUST be able to post a new comment on any open issue or PR from within the reader
- **FR-006**: Users MUST be able to submit a PR review (approve, request changes, or comment) from within the reader
- **FR-007**: Users MUST be able to close an issue or merge a PR from within the reader
- **FR-008**: The reader MUST support merge method selection (merge commit, squash, rebase) before merging a PR
- **FR-009**: All destructive actions (merge, close) MUST require explicit confirmation before executing
- **FR-010**: The reader MUST refresh its content after a user-triggered action (post comment, approve, merge, close)
- **FR-011**: Markdown in issue/PR bodies and comments MUST render with visual formatting (bold, code blocks, lists, headers)
- **FR-012**: The reader MUST show a clear error message inline when an action fails (e.g., network error, permission denied, merge conflict)
- **FR-013**: Images in markdown MUST be replaced with a `[image]` placeholder — no attempt to render them
- **FR-014**: The reader MUST be accessible from the dashboard (`<CR>` on any issue or PR item)

### Key Entities

- **Issue Detail**: Full issue data — id, title, body, state, labels, author, assignees, comments list, creation date
- **PR Detail**: Full PR data — all Issue Detail fields plus: source branch, target branch, reviewers with review states, CI checks list, merge status, is_draft
- **Comment**: Author login, body (markdown), created_at, comment id
- **Review**: Reviewer login, state (APPROVED / CHANGES_REQUESTED / COMMENTED), body, submitted_at
- **CI Check**: Name, status (success / failure / pending / skipped), conclusion

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can read the complete content of any issue or PR (body + all comments) within 3 seconds of selecting it from the dashboard
- **SC-002**: A developer can post a comment, approve a PR, or close an issue entirely within Neovim in under 30 seconds from opening the reader
- **SC-003**: 100% of daily issue/PR management tasks (read, comment, approve, merge, close) can be completed without opening a browser
- **SC-004**: The reader renders markdown formatting correctly — code blocks, bold, lists, and headers are visually distinct
- **SC-005**: All actions show clear success or failure feedback within 2 seconds of completion

## Assumptions

- Built on top of the existing `github_dashboard.lua` module — the reader will be a separate module triggered from the dashboard
- All data sourced via `gh` CLI — no direct GitHub API tokens needed
- The feature covers GitHub only (not GitLab/Bitbucket)
- Comment editing and deletion are out of scope for this version
- Line-level PR code review comments (on specific diff lines) are out of scope — only top-level PR review comments
- The user is already authenticated via `gh auth login` — no new auth setup
- "Roadmap" in the user description means a full spec covering all phases from read-only to full interaction, delivered incrementally
