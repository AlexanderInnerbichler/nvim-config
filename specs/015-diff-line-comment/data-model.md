# Data Model: PR Diff Inline Line Comments

## Entities

### DiffLineInfo
Computed at render time for each commentable diff line; stored in `state.diff_line_map[buf_line]`.

| Field  | Type   | Notes                                                      |
|--------|--------|------------------------------------------------------------|
| path   | string | Relative file path (from `diff --git b/FILE` header)       |
| line   | number | Line number in new file (RIGHT) or old file (LEFT)         |
| side   | string | `"RIGHT"` for `+`/context lines; `"LEFT"` for `-` lines   |

---

### DiffReviewComment
Posted to GitHub via the REST API. Not persisted locally.

| Field     | Type   | Notes                                                    |
|-----------|--------|----------------------------------------------------------|
| body      | string | Comment text entered by user                             |
| commit_id | string | PR head SHA (`state.diff_head_sha`)                      |
| path      | string | From `DiffLineInfo.path`                                 |
| line      | number | From `DiffLineInfo.line`                                 |
| side      | string | From `DiffLineInfo.side`                                 |

---

## State additions to `gh_reader.lua`

| Field            | Type   | Notes                                               |
|------------------|--------|-----------------------------------------------------|
| `diff_item`      | table  | `{number, repo}` of the currently displayed diff    |
| `diff_line_map`  | table  | `{[buf_line_0idx] = DiffLineInfo, ...}`             |
| `diff_head_sha`  | string | PR head commit SHA; `nil` until fetched             |

---

## Non-commentable lines (no entry in `diff_line_map`)

- `diff --git a/... b/...` file headers
- `index ...` lines
- `--- a/...` / `+++ b/...` file path lines
- `@@` hunk headers
- Empty lines (breadcrumb spacers)
