# Research: GH Reader Rendering

## Decision 1: Use render-markdown.nvim (already installed)

**Decision**: Activate render-markdown.nvim properly on the reader buffer rather than building a custom renderer.

**Rationale**: render-markdown.nvim is already installed (`MeanderingProgrammer/render-markdown.nvim`) and configured (`after/plugin/render-markdown.lua`). It explicitly supports `buftype=nofile` with first-class rendering. The reader already sets `filetype=markdown` on its buffer, which is the trigger. No new dependency needed.

**Alternatives considered**:
- Custom inline highlight passes (manual bold/italic detection) — high complexity, brittle
- Rendering to plain text (stripping markdown) — loses all formatting signal

---

## Decision 2: The 2-space prefix is the root cause

**Decision**: Remove the `"  "` prefix that `render_body_lines` prepends to every body line.

**Rationale**: Standard CommonMark requires headings (`##`), fences (` ``` `), and list markers (`-`, `*`) to start at column 0 (or column 1 for tight lists). With `"  " .. raw_line`, every element gets a 2-character indent, which:
- Breaks heading detection (`  ## foo` is a paragraph, not an H2)
- Breaks fenced code blocks (`  ` ``` `` ` is not a fence)
- Breaks list items only if indented past 3 spaces (which it isn't for single indent, but stacked prefixes in nested lists break)

render-markdown.nvim IS active on the buffer (filetype=markdown, buftype=nofile both confirmed), but the content it receives has broken structure.

**Fix**: Write body lines without a leading prefix. render-markdown.nvim itself adds visual padding via its `padding` config.

---

## Decision 3: Trigger re-render after write_buf

**Decision**: After `write_buf` updates the buffer content, fire `ModeChanged` or call render-markdown's update API to force a re-parse.

**Rationale**: render-markdown.nvim attaches autocmds on `FileType markdown`. If the filetype is set before content is written (as in `open_split`), the plugin is attached. But a programmatic `nvim_buf_set_lines` does not fire a `BufWritePost` or `TextChanged` autocmd in the same tick. The safe way to force a re-render: `vim.cmd("redraw")` or trigger `ModeChanged` so the plugin's debounce fires. Alternatively, call `require("render-markdown").enable()` after setting content.

**Alternatives considered**:
- Relying on `CursorMoved` to trigger render — works but adds a visible flash on first open
- Using `vim.schedule` to let autocmds settle — fragile

---

## Decision 4: Comment boundaries use markdown `---`

**Decision**: Separate each comment with a `---` horizontal rule (markdown thematic break) rather than the current custom `─────` separator string.

**Rationale**: render-markdown.nvim renders `---` as a styled horizontal rule with its `RenderMarkdownDash` highlight. This gives a clean visual separator with no extra code. The current `─` separator is a custom string that render-markdown ignores.

---

## Decision 5: Comment author line as a bold header

**Decision**: Render each comment's author/timestamp as a markdown H4 (`#### @author · 2h ago`) instead of a custom-colored plain text line.

**Rationale**: render-markdown.nvim renders H4 with a soft background (`RenderMarkdownH4Bg`) which naturally groups author + body into a visually distinct comment card. Eliminates the custom highlight for comment attribution.

---

## Decision 6: Title as markdown H1

**Decision**: Render the issue/PR title as a markdown H1 (`# #42 Fix the bug`) instead of a custom plain text line.

**Rationale**: render-markdown.nvim renders H1 with full-width background highlight (`RenderMarkdownH1Bg`, already customised in the config). This gives the title the most visual weight without any extra code. The `GhReaderTitle` custom highlight is replaced by render-markdown's H1 rendering.

**Constraint**: The state badge (OPEN/CLOSED/MERGED) and meta line must remain as custom lines directly below the H1 since render-markdown doesn't understand GitHub state semantics.
