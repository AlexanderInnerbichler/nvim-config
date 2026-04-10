# Implementation Plan: GH Reader — Readable Content Display

**Branch**: `003-reader-rendering` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-reader-rendering/spec.md`

## Summary

Fix the GH reader so issue/PR content is actually readable. `render-markdown.nvim` is already installed and IS active on the reader buffer (filetype=markdown, buftype=nofile both confirmed). The problem is purely structural: `render_body_lines` prefixes every line with `"  "`, which breaks CommonMark heading/fence/list parsing. Additionally, title/comment structure can be improved to leverage render-markdown's own visual styling.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev
**Primary Dependencies**: `render-markdown.nvim` (already installed + configured in `after/plugin/render-markdown.lua`), custom highlights in `GhReader*` namespace
**Storage**: No changes to data model or cache
**Testing**: Manual — open a real issue/PR with headers, code blocks, lists, and comments
**Target Platform**: Linux (WSL2), terminal Neovim
**Single file changed**: `lua/alex/gh_reader.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No unnecessary code | ✅ Pass | Removing code (the 2-space prefix), not adding |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | No new try/catch |
| IV. Logical commits, push after each task | ✅ Pass | One commit per phase |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Root Cause (from research.md)

`render_body_lines` does `table.insert(lines, "  " .. raw_line)`. This 2-space prefix causes:
- `  ## Heading` → not a heading (CommonMark: headings must start at col 0)
- `  ` ``` `` ` → not a code fence (fences must start at col 0–3)
- All markdown structure silently degraded to plain text

render-markdown.nvim is attached and parsing, but finds no valid markdown elements.

## Implementation Phases

### Phase A — Fix body rendering (US1 core)

**Changes to `lua/alex/gh_reader.lua`**:

1. **`render_body_lines`**: Remove the `"  "` prefix — write lines as clean markdown with no leading indent. Add a single blank line before and after the body block for visual breathing room.

   ```lua
   -- before
   table.insert(lines, "  " .. raw_line)
   -- after
   table.insert(lines, raw_line)
   ```

2. **Title line (`render_issue` + `render_pr`)**: Convert from custom plain text to markdown H1 so render-markdown.nvim renders it with full-width background.

   ```lua
   -- before: "  #42  Fix the bug"
   -- after:  "# #42  Fix the bug"
   ```
   Remove the `GhReaderTitle` highlight for this line — render-markdown's H1 styling replaces it.

3. **Force re-render after `write_buf`**: After `vim.bo[state.buf].modifiable = false`, call `vim.schedule(function() vim.cmd("redraw") end)` to ensure render-markdown picks up the new content.

**Commit**: `feat: fix gh-reader body rendering — remove 2-space prefix, markdown H1 title`

---

### Phase B — Improve comment thread (US2)

4. **Comment separator**: Replace the custom `separator()` string between comments with `---` (markdown thematic break) so render-markdown renders a styled horizontal rule.

   Each comment block becomes:
   ```
   ---
   #### @author  ·  2h ago
   
   Comment body here (clean markdown)
   ```

5. **Comment author line**: Change from custom `GhReaderMeta` plain text to markdown H4 (`#### @author · age`). render-markdown renders H4 with a soft background (`RenderMarkdownH4Bg`) that groups author + body into a visually distinct card. Remove the custom `GhReaderMeta` highlight for comment attribution.

**Commit**: `feat: gh-reader comments — markdown separators and h4 author lines`

---

### Phase C — Polish (US3 metadata header)

6. **Remove now-redundant highlights**: `GhReaderTitle` is no longer needed (H1 replaces it). Clean up `setup_highlights()` accordingly.

7. **Smoke test**: Open a real issue with headers, code block, bullet list, and 3+ comments. Verify zero raw syntax visible.

**Commit**: `chore: gh-reader — remove redundant title highlight, smoke test pass`

## Key Files

| File | Change |
|------|--------|
| `lua/alex/gh_reader.lua` | `render_body_lines`, `render_issue`, `render_pr`, `render_comments_section`, `setup_highlights` |
| `after/plugin/render-markdown.lua` | No change needed — already configured |

## Verification

1. Open a GH issue containing `## Background`, `**bold**`, ` ```python\ncode\n``` `, and a bullet list → all render without raw syntax
2. Open a PR → title renders with H1 background stripe, body renders with formatted markdown
3. Scroll through a 5-comment thread → each comment clearly bounded by styled `---` rule with H4 author heading
4. Open an issue with empty body → `(no description)` placeholder still visible
