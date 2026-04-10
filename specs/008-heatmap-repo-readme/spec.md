# Feature Specification: Heatmap Colors and Repo README Viewer

**Feature Branch**: `008-heatmap-repo-readme`
**Created**: 2026-04-10
**Status**: Draft
**Input**: User description: "cooler heatmap colors (still green), and repo README viewer in dashboard popup similar to PR/issue reader"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cooler contribution heatmap colors (Priority: P1)

The contribution heatmap in the GitHub Dashboard uses the standard GitHub green palette, but the user wants more visually distinct, vibrant green tones that look better in a dark terminal theme while staying recognisably green.

**Why this priority**: Visual quality improvement with zero functional risk — a pure colour palette swap. Quick win.

**Independent Test**: Open the dashboard (`<leader>gh`) and look at the contribution heatmap. The five heat tiers (empty → light → medium → high → intense) should show a clear, attractive gradient of greens that looks distinct from the default. No tiles should be invisible against the background.

**Acceptance Scenarios**:

1. **Given** the dashboard is open, **When** the heatmap is rendered, **Then** each of the five contribution tiers shows a visually distinct shade of green, with the highest tier being the most vibrant
2. **Given** the user changes their colorscheme, **When** the `ColorScheme` autocmd fires, **Then** the new heatmap colors are re-applied

---

### User Story 2 - Repo README viewer in dashboard popup (Priority: P1)

Currently pressing `<CR>` on a repo row in the GitHub Dashboard opens the repo in a browser. The user wants to press `<CR>` on a repo row and see the repo's README rendered inside the Neovim popup — the same experience as reading a PR or issue — without leaving the editor.

**Why this priority**: Core quality-of-life feature. The dashboard already shows PRs and issues in an inline reader; repos should have the same treatment.

**Independent Test**: Open the dashboard, move cursor to a repo row, press `<CR>` → a popup opens showing the repo's README content rendered as markdown (headings, code blocks, bullets). Press `q` → returns focus to the dashboard (same back-navigation as the PR reader).

**Acceptance Scenarios**:

1. **Given** the cursor is on a repo row, **When** the user presses `<CR>`, **Then** the repo's README opens in the same inline reader popup used for PRs and issues
2. **Given** the README popup is open, **When** the user presses `q`, **Then** focus returns to the dashboard (same back-navigation as PR/issue reader)
3. **Given** the repo has no README, **When** the user presses `<CR>`, **Then** a message "No README found" is shown and the reader closes (or does not open)
4. **Given** a repo row is selected in the dashboard, **When** the README is loading, **Then** a loading indicator is shown so the user knows something is happening
5. **Given** the reader is already open for a PR/issue, **When** the user navigates back and then opens a repo README, **Then** the reader shows the README correctly (no stale content)

---

### Edge Cases

- Repo is private and the user does not have access via `gh` — the fetch fails silently and a "Could not load README" message is shown
- README is very long (>500 lines) — the popup renders it fully and is scrollable
- README contains only a title and no body — renders the title; does not error
- `<CR>` pressed on a PR row or issue row — existing behavior unchanged (opens in PR/issue reader)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The five heatmap tiers MUST render with a visually distinct, vibrant green gradient that improves on the current muted palette
- **FR-002**: The heatmap colors MUST re-apply automatically when the user's colorscheme changes
- **FR-003**: Pressing `<CR>` on a repo row in the dashboard MUST open the repo's README in the existing inline reader popup
- **FR-004**: The README MUST be rendered using the same markdown formatting already used for PR/issue bodies (headings, code blocks, bullets, etc.)
- **FR-005**: The breadcrumb line at the top of the reader MUST show the repo name (e.g., `GitHub Dashboard › owner/repo › README`)
- **FR-006**: Pressing `q` in the README reader MUST return focus to the dashboard (same back-navigation as PR/issue)
- **FR-007**: If no README exists or the fetch fails, the reader MUST show a descriptive message rather than an empty or broken popup
- **FR-008**: Pressing `<CR>` on non-repo rows (PR, issue, blank) MUST retain existing behavior

### Key Entities

- **README content**: The markdown text of a repo's README file, fetched on demand and displayed as a read-only document in the reader popup

## Assumptions

- The `gh` CLI already has the necessary permissions to fetch README content for repos listed in the dashboard
- The README reader is read-only — no commenting or editing
- The existing reader's `process_body` markdown renderer is used as-is for README content; no new rendering is needed
- README content is not cached — always fetched fresh on `<CR>` (same as PR/issue bodies)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All five heatmap tiers are visually distinguishable from each other and from the background at a glance
- **SC-002**: README opens within 2 seconds for repos accessible via the `gh` CLI
- **SC-003**: 100% of existing `<CR>` behavior on PR/issue rows is preserved unchanged
- **SC-004**: Back-navigation (`q`) from README returns to the dashboard in the same way as from a PR/issue
