# Feature Specification: PR Diff Viewer

**Feature Branch**: `014-pr-diff-viewer`
**Created**: 2026-04-10
**Status**: Draft
**Input**: GitHub Issue #6 — "PR diff viewer — `d` on a PR row opens the full patch in the reader"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — View a PR's full diff from the dashboard (Priority: P1)

While reviewing the dashboard, the user spots a pull request in the PR list. Instead of switching to a browser, they press `d` on the PR row. The full diff opens immediately in the same reader popup used for PR descriptions and README files — all changed files, hunks, additions in green, deletions in red, hunk headers in blue. The user can scroll through the entire patch, then press `q` to return to the dashboard.

**Why this priority**: This is the entire feature. The diff is the primary artifact developers care about when reviewing a PR, and viewing it without leaving Neovim is the core value.

**Independent Test**: Move cursor to any PR row in the dashboard, press `d` → a popup opens showing the diff with coloured additions/deletions. Press `q` → focus returns to the dashboard.

**Acceptance Scenarios**:

1. **Given** the dashboard is open and the cursor is on a PR row, **When** `d` is pressed, **Then** a reader popup opens displaying the full diff of that PR with `+` lines highlighted in green, `-` lines in red, and `@@` hunk headers in blue
2. **Given** the diff popup is open, **When** the user scrolls, **Then** the entire patch is navigable and all changed files are visible
3. **Given** the diff popup is open, **When** `q` or `<Esc>` is pressed, **Then** the popup closes and focus returns to the dashboard
4. **Given** the cursor is on a non-PR row (issues, repos, heatmap, watched users), **When** `d` is pressed, **Then** nothing happens — no popup opens, no error shown

---

### Edge Cases

- What happens if the PR has no diff (empty commit, already merged with no changes)? → The popup opens and shows an empty state message
- What happens if the diff fetch fails (no permissions, deleted PR, network issue)? → The popup opens and shows an error message; it does not crash
- What happens on a very large diff (thousands of lines)? → The popup renders all lines; performance is acceptable for typical open-source PR sizes
- What happens if `d` is pressed while a diff popup is already open? → No second popup is opened

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Pressing `d` on a PR row in the dashboard MUST open a popup displaying the full diff of that PR
- **FR-002**: The diff MUST display addition lines (lines beginning with `+`) with a distinct green colour
- **FR-003**: The diff MUST display deletion lines (lines beginning with `-`) with a distinct red colour
- **FR-004**: The diff MUST display hunk header lines (lines beginning with `@@`) with a distinct blue colour
- **FR-005**: The diff popup MUST reuse the existing reader popup infrastructure — same size, border, breadcrumb style, and close behaviour
- **FR-006**: Pressing `q` or `<Esc>` in the diff popup MUST close it and return focus to the dashboard
- **FR-007**: Pressing `d` on any non-PR row MUST do nothing
- **FR-008**: If the diff cannot be fetched, the popup MUST display an error message without crashing

### Key Entities

- **PRDiff**: The raw patch output for a pull request; contains one or more file sections, each with hunk headers (`@@`) and changed lines prefixed with `+` or `-`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pressing `d` on a PR row shows a loading state immediately; the diff content renders within 3 seconds on a normal connection
- **SC-002**: All three diff line types (`+`, `-`, `@@`) are visually distinct via colour in 100% of diffs rendered
- **SC-003**: Zero regressions — `<CR>`, `o`, and all other existing dashboard keymaps continue to behave correctly
- **SC-004**: The popup closes cleanly on `q`/`<Esc>` with no UI artifacts or focus issues

## Assumptions

- The diff is fetched fresh on each popup open; no caching needed
- The viewer is read-only — no inline editing, staging, or commenting from the diff popup
- Diff output is unified/inline format rendered with line-prefix-based highlighting, not a side-by-side view
- File header lines (`---`, `+++`, `diff --git`) are rendered as plain text without special highlighting (they are context, not changes)
