# Feature Specification: GitHub Dashboard UX Refinements

**Feature Branch**: `004-fix-dashboard-ux`
**Created**: 2026-04-10
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Consistent Reader Window Size & Position (Priority: P1)

When a user opens an issue or PR from the dashboard, the reader window opens as a noticeably smaller popup in a different position than the dashboard. This breaks the illusion of seamless navigation — it looks like a dialog on top of a dialog rather than a full content view.

The reader should occupy the same footprint as the dashboard (same width, height, and center position) so the user feels they have "navigated into" the item rather than opened a tooltip.

**Why this priority**: This is a visible layout defect that degrades the experience on every single issue/PR open action.

**Independent Test**: Open the dashboard with `<leader>gh`, press `<CR>` on any issue. The reader window must have the same outer dimensions and position as the dashboard — no shift, no shrink.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** the user presses `<CR>` on an issue, **Then** the reader popup occupies the exact same screen area as the dashboard
2. **Given** the reader is open, **When** the user presses `q`, **Then** focus returns to the dashboard and the dashboard popup is in its original position and size
3. **Given** the reader is open, **When** the user refreshes (`r`) to open a different item, **Then** the window does not jump or resize

---

### User Story 2 — Comment / Review Input as Floating Popup (Priority: P2)

When a user presses `c` (comment) or `a` (review), an input area opens as a horizontal split at the bottom of the terminal. This is jarring: it disrupts the editor layout and doesn't close cleanly when cancelled.

The input area should open as a small centered floating popup over the reader, leaving the editor layout untouched.

**Why this priority**: The comment/review workflow is a core action. An input method that breaks the visual layout makes the feature feel broken.

**Independent Test**: Open a PR, press `c`. A floating input box must appear — no new splits, no changes to the window layout. After submitting or cancelling, the layout is identical to before.

**Acceptance Scenarios**:

1. **Given** the reader is showing an issue, **When** the user presses `c`, **Then** a floating input popup appears for typing the comment — no horizontal splits are created
2. **Given** the comment input popup is open, **When** the user submits (`<leader>s`), **Then** the popup closes and the reader refreshes in place
3. **Given** the comment input popup is open, **When** the user cancels (`<Esc><Esc>`), **Then** the popup closes and the reader and editor layout are unchanged
4. **Given** the reader is showing a PR, **When** the user presses `a` and selects a review type, **Then** a floating input popup opens for the review body (same pattern as comment)
5. **Given** the input popup is open, **When** any submit/cancel action completes, **Then** the total window count in the editor is the same as before the popup was opened

---

### Edge Cases

- What if the user presses `c` while an input popup is already open? The existing popup should be re-focused rather than a second one opening.
- What if submission fails (network error)? The input popup closes, an error notification appears, and the reader content is unchanged.
- What if the terminal is resized while the reader or input popup is open? Both windows should remain usable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The reader popup MUST open with the same width, height, and screen position as the dashboard popup
- **FR-002**: When returning from the reader to the dashboard via `q`, the dashboard popup MUST remain in its original position and size
- **FR-003**: The comment input area MUST open as a floating popup, not as a horizontal split
- **FR-004**: The review input area (approve, request changes, comment-only) MUST open as a floating popup, not as a horizontal split
- **FR-005**: Closing the input popup (submit or cancel) MUST leave all editor windows and splits unchanged
- **FR-006**: The input popup MUST display the available actions (submit / cancel shortcuts) visible within the popup itself
- **FR-007**: While an input popup is open, the user MUST be placed in insert mode automatically

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Opening an issue/PR from the dashboard produces zero visible layout shift — the reader occupies the same screen area as the dashboard
- **SC-002**: Pressing `c` or `a` never creates a new editor split — verified by checking window count before and after
- **SC-003**: The complete comment/review workflow (open popup → type → submit) can be completed without the user needing to manage window layout at any step
- **SC-004**: Cancelling an input popup returns the user to exactly the same state as before opening it (same focused window, same cursor position in the reader)

## Assumptions

- The dashboard and reader share the same popup slot — the reader replaces the dashboard visually while the dashboard buffer remains open in the background
- Input popups are short-lived and do not need to persist across Neovim sessions
- Input popup size can be fixed (e.g., centered, ~60% width × 12 lines) without needing to be user-resizable
