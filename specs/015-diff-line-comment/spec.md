# Feature Specification: PR Diff Inline Line Comments

**Feature Branch**: `015-diff-line-comment`
**Created**: 2026-04-10
**Status**: Draft
**Input**: GitHub Issue #6 comment — "make it possible in Visual mode to highlight and then press c to create a comment for it"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Post an inline review comment on selected diff lines (Priority: P1)

While viewing a PR diff in the diff popup (opened via `d` from the dashboard), the user enters Visual mode and selects one or more lines they want to comment on. They press `c`. A text input appears where they type their comment. On submit, the comment is posted to the PR as an inline review comment attached to the selected line(s). The input closes and the user returns to the diff view.

**Why this priority**: This is the entire feature — commenting on specific diff lines without leaving Neovim is the core value. It turns the diff viewer from read-only into a lightweight code review tool.

**Independent Test**: Open the diff popup for any PR → enter Visual mode → select a `+` or `-` line → press `c` → input appears → type a message → submit → comment appears in the PR on GitHub attached to that line.

**Acceptance Scenarios**:

1. **Given** the diff popup is open and the user has selected one or more lines in Visual mode, **When** `c` is pressed, **Then** a text input prompt appears for the comment body
2. **Given** the comment input is open and the user submits a non-empty message, **Then** the comment is posted to GitHub as a review comment on the selected line(s) and the input closes
3. **Given** the comment input is open and the user cancels (presses `<Esc>`), **Then** the input closes without posting anything and focus returns to the diff
4. **Given** the user selects a non-diff line (file header, blank line), **When** `c` is pressed, **Then** a clear message is shown explaining that the selected line cannot be commented on
5. **Given** the comment submission fails (network error, permissions), **Then** an error message is shown without crashing

---

### Edge Cases

- What happens when the user selects a mix of commentable and non-commentable lines? → The comment is anchored to the last commentable line in the selection
- What happens when the user presses `c` in Normal mode (no selection)? → Nothing happens, or treats the cursor line as a single-line selection
- What happens when the diff is for a PR the user doesn't have write access to? → Submission fails and an error message is shown
- What happens if the user submits an empty comment? → Submission is blocked and a hint is shown asking for content

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the diff popup, pressing `c` after a Visual mode selection MUST open a text input for the comment body
- **FR-002**: Submitting a non-empty comment MUST post it to GitHub as an inline review comment attached to the selected diff line(s)
- **FR-003**: Pressing `<Esc>` in the comment input MUST cancel and return focus to the diff without posting anything
- **FR-004**: Attempting to comment on a non-diff line (file header, hunk header `@@`, blank lines) MUST show a message explaining the line is not commentable
- **FR-005**: Submitting an empty comment MUST be blocked — the input must not close until a non-empty message is provided or the user cancels
- **FR-006**: If the comment post fails, an error message MUST be displayed in the diff popup without crashing
- **FR-007**: After a successful submission, focus MUST return to the diff popup

### Key Entities

- **DiffLineComment**: An inline comment attached to a specific line of a PR diff; has a comment body and is anchored to one or more selected lines in the patch

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From Visual selection to posted comment takes under 5 seconds of user interaction (input appears immediately on `c`; comment posts within 3 seconds of submission on a normal connection)
- **SC-002**: 100% of submitted comments appear on GitHub attached to the correct diff line
- **SC-003**: Zero regressions — `d`, `<CR>`, `q`, and all other diff and dashboard keymaps continue to work correctly
- **SC-004**: Cancelling with `<Esc>` leaves the diff popup state unchanged in 100% of cases

## Assumptions

- Comments are posted as single-comment PR reviews (not as part of a multi-comment review batch)
- The feature applies only inside the diff popup opened via `d`; commenting from the PR description view is out of scope
- Multi-line selections anchor the comment to the last selected line (GitHub's inline comment model attaches to a single line even when a range is highlighted)
- The existing comment input UI from `gh_reader.lua` (`M.open_input`) is reused for the text entry
