# Tasks: GH Reader — Readable Content Display

**Input**: Design documents from `/specs/003-reader-rendering/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓

**Single file**: All changes are in `lua/alex/gh_reader.lua`

---

## Phase 1: Setup

No new files or dependencies needed — all changes are edits to an existing file.

- [X] T001 Verify `render-markdown.nvim` is active on reader buffer by opening a real issue and confirming `filetype=markdown` is set in `lua/alex/gh_reader.lua:248`

---

## Phase 2: Foundational

No shared infrastructure needed — US1, US2, US3 all touch different functions and can proceed directly.

**Checkpoint**: Research confirmed — render-markdown.nvim IS attached. Root cause is the `"  "` prefix in `render_body_lines`. Proceed to user stories.

---

## Phase 3: User Story 1 — Readable Issue/PR Body (Priority: P1) 🎯 MVP

**Goal**: Raw markdown syntax (`**`, `##`, ` ``` `) disappears; content renders as formatted text

**Independent Test**: Open a GitHub issue containing a heading, a code block, and bold text → verify all render visually with no syntax characters visible

### Implementation

- [X] T002 [US1] Remove `"  "` prefix from `render_body_lines` — change `table.insert(lines, "  " .. raw_line)` to `table.insert(lines, raw_line)` in `lua/alex/gh_reader.lua`
- [X] T003 [US1] Convert issue title to markdown H1 — change `"  #" .. data.number .. "  " .. sl(data.title)` to `"# #" .. data.number .. "  " .. sl(data.title)` in `render_issue` in `lua/alex/gh_reader.lua`
- [X] T004 [US1] Convert PR title to markdown H1 — same change in `render_pr` in `lua/alex/gh_reader.lua`; remove the `GhReaderTitle` highlight for the title line from both functions
- [X] T005 [US1] Force re-render after `write_buf` — after `vim.bo[state.buf].modifiable = false` in `write_buf`, add `vim.schedule(function() vim.cmd("redraw") end)` in `lua/alex/gh_reader.lua`

**Checkpoint**: Open a real issue — heading renders with background, code block gets styled, bold text is bold. Zero raw syntax visible.

---

## Phase 4: User Story 2 — Scannable Comment Thread (Priority: P2)

**Goal**: Each comment clearly bounded with styled separator and visually distinct author header

**Independent Test**: Open an issue with 3+ comments — scan to a specific comment by author without reading every word

### Implementation

- [X] T006 [US2] Replace custom `separator()` call between comments with a `---` markdown thematic break in `render_comments_section` in `lua/alex/gh_reader.lua`; also replace the section header separator before `💬 Comments` with `---`
- [X] T007 [US2] Change comment author line from plain `"  @" .. c.author .. "  ·  " .. age` to markdown H4 `"#### @" .. sl(c.author) .. "  ·  " .. age_string(c.created_at)` in `render_comments_section` in `lua/alex/gh_reader.lua`; remove the manual `GhReaderMeta` highlight for this line

**Checkpoint**: Comment thread renders with styled `---` dividers and H4 author headings (soft background). Each comment is a visually distinct card.

---

## Phase 5: User Story 3 + Polish (Priority: P3)

**Goal**: Remove dead code, verify metadata header remains readable

### Implementation

- [X] T008 [US3] Remove `GhReaderTitle` highlight group from `setup_highlights` in `lua/alex/gh_reader.lua` (replaced by render-markdown H1 styling)
- [X] T009 [US3] Remove `GhReaderSection` highlight application for the comments section header line (it now renders as a markdown heading) in `lua/alex/gh_reader.lua`
- [ ] T010 Smoke test: open a PR with all content types (heading, code block, list, bold, 3+ comments) — verify SC-004 (zero raw syntax) and SC-001 (metadata readable in 3 seconds)

---

## Dependencies & Execution Order

- **T002** (body prefix) must come before T003/T004 (title) — both in the same render path
- **T005** (force redraw) can be done any time — independent of T002–T004
- **T006, T007** (comments) can start after T002 is done (they reuse `render_body_lines`)
- **T008, T009** (cleanup) must come last — only safe to remove highlights after render-markdown replaces them

### Parallel Opportunities

- T003 and T004 are identical changes in two functions — can be done in one edit pass
- T008 and T009 can be done together in one edit

---

## Implementation Strategy

### MVP (T002–T005 only)

Complete Phase 3 and the body renders correctly. Comments are still plain-text but at least body formatting works. Delivers the highest-value fix with 4 tasks.

### Full Delivery

T002 → T003+T004 → T005 → T006+T007 → T008+T009 → T010 smoke test

---

## Notes

- No new highlights or helpers needed — render-markdown.nvim handles all visual styling
- The `sl()` helper in `gh_reader.lua` is already defined; use it on author names
- `GhReaderMeta`, `GhCiPass/Fail/Pending`, `GhReviewApproved/Changes/Comment` highlights remain unchanged — they cover the non-body sections (CI status, branch line, review states) which are NOT markdown
- **Commit and push after each phase** (Constitution IV)
