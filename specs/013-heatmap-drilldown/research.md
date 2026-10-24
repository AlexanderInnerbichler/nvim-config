# Research: Heatmap Day Drill-Down

## Decision: Per-row items vs per-cell items

**Decision**: One item per heatmap row (day-of-week line), mapped to the most recent date in that row  
**Rationale**: `open_url_at_cursor` in `github_dashboard.lua` routes by line number only — there is no column-based dispatch. Each of the 7 heatmap rows is one buffer line. Inserting one item per row with the most recent date in that row is the simplest approach that works with the existing routing infrastructure and delivers the most useful result (users typically want recent activity, not ancient dates).  
**Alternatives considered**: Column-based hit detection — requires overriding `<CR>` with custom cursor-column math; substantially more complex and departs from the established items pattern. Per-cell items for all 52×7 cells — floods `state.items` with 364 entries and still requires column detection to distinguish them.

---

## Decision: `render_heatmap` signature extension

**Decision**: Add two optional parameters `items` and `username` to `M.render_heatmap` in `gh_heatmap.lua`  
**Rationale**: When `items` is `nil` (existing callers that don't need drill-down), the function behaves identically to today — no breaking change. When `items` is a table, the function records the most recent date per row and inserts `kind="day"` items. The `username` field is stored on the item so the routing layer knows which user to fetch events for.  
**Alternatives considered**: Separate `render_heatmap_interactive` function — unnecessary duplication of the 50-line render body for one extra feature flag.

---

## Decision: New `gh_day_activity.lua` module vs embedding in existing modules

**Decision**: New `lua/alex/gh_day_activity.lua` standalone module with `M.open(username, date)`  
**Rationale**: The day popup has its own fetch logic, render logic, and window lifecycle — a distinct concern from profile display (`gh_user_profile`) or heatmap rendering (`gh_heatmap`). A small standalone module keeps each file focused.  
**Alternatives considered**: Adding to `gh_user_profile.lua` — that module is already doing profile+heatmap, adding a third responsibility would bloat it.

---

## Decision: Event filtering by date

**Decision**: Use `gh api /users/{username}/events --jq "[.[] | select(.created_at | startswith(\"YYYY-MM-DD\"))]"` — filter by ISO date prefix  
**Rationale**: The events API returns events with `created_at` in ISO 8601 format (`2026-04-10T14:32:00Z`). A `startswith` filter on the date prefix is the most reliable way to get all events for a calendar day. No server-side date filtering is needed.  
**Alternatives considered**: Fetching all events and filtering client-side — wastes bandwidth; the `--jq` approach filters on the server and returns only the relevant events. Using a separate search API — not available for event types.

---

## Decision: `gh_user_profile.lua` items management for the profile popup

**Decision**: Add a `popup_items = {}` upvalue inside `M.open`, populate it in `render_and_apply` after calling `render_content`, and add a `<CR>` keymap that routes `kind="day"` items via `gh_day_activity.open`  
**Rationale**: The profile popup has its own buffer with its own keymaps. It can't use `state.items` from the dashboard. A closure-captured local table (`popup_items`) follows the same pattern as `state.items` in the dashboard.  
**Alternatives considered**: Having the profile popup re-use the dashboard's routing — not viable since the profile popup has no access to dashboard state.
