# Data Model: PR Review Comments + Keybind Hints

## Entities

### ReviewComment
Fetched from GitHub REST API; not persisted locally.

| Field  | Type   | Notes                                                    |
|--------|--------|----------------------------------------------------------|
| login  | string | Commenter username (`user.login` from API)               |
| path   | string | Relative file path the comment is attached to            |
| line   | number | Line number in the file (`line // original_line` from API) |
| body   | string | Comment text                                             |

---

## State additions

None. Review comments are fetched fresh on each `M.open(item)` call and passed directly to `render_pr`. They are not stored in `state`.

---

## No new persistent state

- `state.items` in the dashboard already contains `{line, kind, ...}` per buffer row — used as-is by the `CursorMoved` handler to determine if cursor is on a PR row.
- Dashboard footer string is managed by `nvim_win_set_config` at runtime; no new state field needed.
