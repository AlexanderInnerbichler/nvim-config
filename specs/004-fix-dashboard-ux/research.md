# Research: GitHub Dashboard UX Refinements

## Decision 1: How to match reader window size to dashboard

**Decision**: Change reader popup dimensions from 80%×85% to 90%×90% (same formula as dashboard) and keep the same centering calculation.

**Rationale**: The dashboard (`github_dashboard.lua:open_win`) uses `ui.width * 0.90` / `ui.height * 0.90`. The reader (`gh_reader.lua:open_popup`) uses `ui.width * 0.80` / `ui.height * 0.85`. Making both use 0.90×0.90 with the same `math.floor((ui.height - height) / 2)` centering formula produces identical window footprints with zero coupling between the two modules.

**Alternatives considered**:
- Pass dashboard window handle to `M.open(item)` and read its config via `nvim_win_get_config` — works but couples the two modules unnecessarily
- Reuse the dashboard's window/buffer directly — requires reader to hijack dashboard state, makes back-navigation (`q`) much harder
- Share a common `open_popup` utility — over-engineering for two callers

---

## Decision 2: Replace horizontal split input with floating popup

**Decision**: Replace `vim.cmd("belowright 10split")` in `M.open_input` with `nvim_open_win` using a centered floating popup (60% width × 12 lines, rounded border).

**Rationale**: The current `belowright 10split` creates a new editor split that disrupts the layout and requires `close_input()` to close it cleanly. A floating popup over the reader is visually consistent with the rest of the UI (dashboard and reader both use floating windows) and leaves zero layout side-effects on open/close.

**Size**: 60% of terminal width, 12 lines tall, centered on screen. The first line shows the hint text (non-editable), remaining lines are for the message body. This is sufficient for a comment or review body without being overwhelming.

**Hint line**: Displayed as the first line of the buffer with a comment prefix `-- hint --`. The window border `title` shows the action name (e.g., `Write comment`). The border `footer` shows `<leader>s submit  ·  <Esc><Esc> cancel`.

**Implementation**: `nvim_open_win` with `relative="editor"`, `style="minimal"`, `border="rounded"`. After creating the window, `vim.cmd("startinsert")` places user in insert mode on line 2. `BufWipeout` autocmd cleans up state. The `do_submit` and `do_cancel` functions close the window with `nvim_win_close` instead of needing a separate `close_input()` that references the split.

**Alternatives considered**:
- `vim.ui.input` (built-in) — single-line only, can't write multi-line comments
- `vim.fn.input()` — blocks the event loop, no async
- Keep the split but make it smarter — still disrupts layout, violates SC-002

---

## Decision 3: No data model needed

**Decision**: Skip `data-model.md` — this feature has no new entities or storage changes.

**Rationale**: Both bugs are purely UI/window-management fixes. No new data, no new state fields, no persistence changes.

---

## Decision 4: No contracts/ needed

**Decision**: Skip `contracts/` — the plugin has no external API surface.

**Rationale**: `gh_reader.lua` is a purely internal Neovim plugin module. Its public API (`M.open`, `M.open_input`, etc.) is called only from within this codebase. No contract documentation is needed.
