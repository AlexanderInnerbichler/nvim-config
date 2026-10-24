# Data Model: PR Diff Viewer

## Entities

### PRDiff
The raw unified diff output for a pull request. Fetched on-demand; not persisted.

| Field    | Type   | Notes                                              |
|----------|--------|----------------------------------------------------|
| number   | number | PR number (from dashboard item)                    |
| repo     | string | `owner/repo` (from dashboard item)                 |
| text     | string | Raw unified diff output from `gh pr diff`          |

---

## Item routing table (updated)

The `d` keymap in `github_dashboard.lua` routes by `item.kind`:

| kind  | `<CR>` / `o` action          | `d` action                             |
|-------|------------------------------|----------------------------------------|
| `pr`  | `gh_reader.open(item)`       | `gh_reader.open_diff(item)` ← **NEW** |
| `issue` | `gh_reader.open(item)`     | (no-op)                                |
| `repo`  | `gh_reader.open(item)`     | (no-op)                                |
| `push`  | `xdg-open(item.url)`       | (no-op)                                |
| `user`  | `gh_user_profile.open()`   | (no-op)                                |
| `day`   | `gh_day_activity.open()`   | (no-op)                                |
