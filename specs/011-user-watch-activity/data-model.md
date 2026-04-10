# Data Model: User Watch Activity Feed

## Watched User (persistent)

Stored in `~/.config/nvim/gh-user-watchlist.json`:

```json
{ "users": ["torvalds", "antirez", "tjdevries"] }
```

| Field      | Type   | Notes                              |
|------------|--------|------------------------------------|
| `username` | string | GitHub login, stored as plain string in array |

## User Event (in-memory, never persisted)

Same shape as team activity events (same JQ filter, same endpoint family):

| Field          | Type   | Source                                          | Notes                                      |
|----------------|--------|-------------------------------------------------|--------------------------------------------|
| `actor`        | string | `.actor.login`                                  | Always equals the watched username         |
| `type`         | string | `.type`                                         | e.g. "PushEvent", "PullRequestEvent"       |
| `repo`         | string | `.repo.name`                                    | `owner/repo` format                        |
| `created_at`   | string | `.created_at`                                   | ISO 8601                                   |
| `pr_number`    | int    | `.payload.pull_request.number`                  | nil/NIL for non-PR events                  |
| `issue_number` | int    | `.payload.issue.number`                         | nil/NIL for non-issue events               |

## Dashboard Item (cursor routing)

Same as team activity items:

| Field    | Type   | PR events      | Issue events      | Other events                            |
|----------|--------|----------------|-------------------|-----------------------------------------|
| `line`   | int    | 0-indexed line | same              | same                                    |
| `kind`   | string | `"pr"`         | `"issue"`         | `"push"` (any non-reader kind)          |
| `number` | int    | `pr_number`    | `issue_number`    | nil                                     |
| `repo`   | string | `"owner/repo"` | `"owner/repo"`    | nil                                     |
| `url`    | string | nil            | nil               | `"https://github.com/" .. repo`         |

## `state.data` Fields Added to Dashboard

| Field                  | Type       | Set by                        |
|------------------------|------------|-------------------------------|
| `watched_events`       | list/nil   | `fetch_watched_users_activity` |
| `watched_events_err`   | string/nil | `fetch_watched_users_activity` |
