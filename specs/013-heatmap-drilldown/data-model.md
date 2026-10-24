# Data Model: Heatmap Day Drill-Down

## Entities

### HeatmapCellItem
Added to `state.items` (dashboard) or `popup_items` (profile popup) by `render_heatmap` when called with the optional `items` + `username` parameters. One item per heatmap row (7 total per heatmap), mapped to the most recent date in that row.

| Field    | Type   | Notes                                          |
|----------|--------|------------------------------------------------|
| line     | number | 0-indexed buffer line (the heatmap row)        |
| kind     | string | `"day"`                                        |
| date     | string | ISO date `YYYY-MM-DD` — most recent date in the row |
| username | string | GitHub login of the user the heatmap belongs to |

---

### DayEvent
A single GitHub event for a specific user on a specific calendar date. Returned by the events API filtered to that date. Not persisted — fetched on-demand.

| Field      | Type   | Notes                                        |
|------------|--------|----------------------------------------------|
| type       | string | GitHub event type (e.g. `PushEvent`)         |
| repo       | string | `owner/repo` name                            |
| created_at | string | ISO 8601 timestamp                           |
| summary    | string | Human-readable action (e.g. "pushed 3 commits") |

---

## Item routing table (updated)

The `open_url_at_cursor` dispatcher in `github_dashboard.lua` and the `<CR>` handler in `gh_user_profile.lua` route items by `kind`:

| kind    | Action                                      |
|---------|---------------------------------------------|
| `pr`    | `gh_reader.open(item)` — inline PR reader   |
| `issue` | `gh_reader.open(item)` — inline issue reader|
| `repo`  | `gh_reader.open(item)` — inline README view |
| `push`  | `xdg-open(item.url)` — browser             |
| `user`  | `gh_user_profile.open(item.username)`       |
| `day`   | `gh_day_activity.open(item.username, item.date)` ← **NEW** |
