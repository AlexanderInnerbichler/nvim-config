# Feature Specification: GH Reader — Readable Content Display

**Feature Branch**: `003-reader-rendering`
**Created**: 2026-04-10
**Status**: Draft
**Input**: User description: "ok now i dont like how the Markdown is rendered in the nvim buffer, it is extremely hard to read! this nvim plugin we're writting should make my life easier not be useless"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Readable Issue/PR Body (Priority: P1)

As a developer, when I open an issue or PR from the dashboard, I want the body content to be immediately readable — headers stand out, code blocks are visually distinct, bold/italic text is actually emphasized — without raw markdown syntax cluttering the text.

**Why this priority**: The body is the primary reason for opening the reader. If it is unreadable the entire feature is useless.

**Independent Test**: Open an issue that contains headers, a code block, and bold text. Verify the content reads naturally without raw syntax characters.

**Acceptance Scenarios**:

1. **Given** an issue with `## Background` and `**important term**` in the body, **When** the reader opens it, **Then** headers appear visually larger/distinct and bold text is emphasized — no raw `**` or `##` visible
2. **Given** an issue with a fenced code block, **When** the reader opens it, **Then** the code block is clearly separated from prose with a distinct visual treatment
3. **Given** a PR with a long description, **When** I read it, **Then** the visual hierarchy guides the eye naturally from title → metadata → body → comments

---

### User Story 2 — Scannable Comment Thread (Priority: P2)

When reading comments and review threads, each comment's author and timestamp should be clearly separated from the comment body, and comments should be visually separated from each other so the thread can be scanned quickly.

**Why this priority**: After the body, the comment thread is where context and decisions live. Poor comment formatting turns a quick scan into a wall of text.

**Independent Test**: Open an issue with 3+ comments and verify each comment is clearly attributed and the thread boundary is obvious without reading every word.

**Acceptance Scenarios**:

1. **Given** an issue with multiple comments, **When** reading the thread, **Then** each comment's author is visually prominent and the comment boundary is unmistakable
2. **Given** a comment containing a code snippet, **When** reading it, **Then** the code is visually distinct within the comment body

---

### User Story 3 — Glanceable Metadata Header (Priority: P3)

The title, state badge (open/closed/merged), author, labels, and branch info should all be readable at a glance — like an information card — before the body content begins.

**Why this priority**: Without clear metadata I must hunt for basic context before I can start reading the body.

**Independent Test**: Open a PR and within 3 seconds identify its state, author, source branch, and merge readiness without reading any body text.

**Acceptance Scenarios**:

1. **Given** a merged PR, **When** the reader opens, **Then** the MERGED badge is immediately visually distinct from OPEN or CLOSED
2. **Given** a PR with conflict, **When** reading the header, **Then** the merge conflict status is visible without having to scroll

---

### Edge Cases

- What happens when the issue body is empty?
- What if a comment contains only a code block with no prose?
- What if the title is very long (80+ characters)?
- What if there are 20+ comments — does the thread remain scannable?
- What if a body contains a mix of all markdown elements (table, list, code, headers)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Markdown formatting in issue/PR bodies MUST be visually rendered — headers, bold, italic, and code blocks presented as formatted output, not raw syntax characters
- **FR-002**: Code blocks MUST be visually separated from surrounding prose with a clear visual boundary (distinct background or framing)
- **FR-003**: The metadata header (state, author, age, labels, branch) MUST be scannable in a single glance
- **FR-004**: Each comment MUST be visually separated from adjacent comments — author + timestamp on one line, body indented or grouped below
- **FR-005**: The state badge (OPEN / CLOSED / MERGED) MUST be color-coded for instant recognition
- **FR-006**: Empty body and empty comment list MUST display a clear placeholder rather than blank space
- **FR-007**: The content layout MUST use clear visual grouping so a reader can scan top-to-bottom without confusion
- **FR-008**: Lists (bulleted and numbered) in body and comments MUST render with visible list markers, not raw `- ` or `1.` syntax

### Key Entities

- **Issue/PR Body**: Multi-section markdown document — prose, headers, lists, code blocks, blockquotes
- **Comment**: Author + timestamp header line + markdown body; repeated for each comment
- **Metadata Header**: State badge, author, age, labels (issues) or branch + CI + mergeability (PRs)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can identify the state, author, and key metadata of an issue or PR within 3 seconds of opening the reader
- **SC-002**: A developer can fully read a 300-word issue body containing code examples without needing to open the browser
- **SC-003**: In a thread with 5 comments, the developer can locate a specific comment by author in under 10 seconds by scanning
- **SC-004**: Zero raw markdown syntax characters (`**`, `##`, ` ``` `, `- `) are visible in rendered prose and list sections

## Assumptions

- The reader panel is a fixed-width vertical split (~85 columns); layout is optimized for that width
- The goal is readability of content, not pixel-perfect GitHub styling
- This spec covers only the visual reading experience — actions (comment, approve, merge) remain unchanged
- Both issue bodies and PR descriptions require the same rendering treatment
