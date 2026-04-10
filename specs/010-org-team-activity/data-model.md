# Data Model: Org Team Activity Feed

## Team Event (in-memory only, never persisted)

| Field          | Type   | Source                          | Notes                                      |
|----------------|--------|---------------------------------|--------------------------------------------|
| `actor`        | string | `event.actor.login`             | GitHub username of the person who acted    |
| `type`         | string | `event.type`                    | e.g. "PushEvent", "PullRequestEvent"       |
| `repo`         | string | `event.repo.name`               | `owner/repo` format                        |
| `created_at`   | string | `event.created_at`              | ISO 8601, e.g. "2026-04-10T12:34:56Z"      |
| `pr_number`    | int    | `event.payload.pull_request.number` | nil for non-PR events                  |
| `issue_number` | int    | `event.payload.issue.number`    | nil for non-issue events                   |

## Dashboard Item (for cursor routing)

Inserted into `state.items` by `render_team_activity`. Fields used by `open_url_at_cursor`:

| Field    | Type   | Value for PR events                 | Value for issue events               | Value for other events               |
|----------|--------|-------------------------------------|--------------------------------------|--------------------------------------|
| `line`   | int    | 0-indexed buffer line number        | same                                 | same                                 |
| `kind`   | string | `"pr"`                              | `"issue"`                            | `"push"` (any non-reader kind)       |
| `number` | int    | `pr_number`                         | `issue_number`                       | nil                                  |
| `repo`   | string | `"owner/repo"`                      | `"owner/repo"`                       | nil                                  |
| `url`    | string | nil (reader fetches fresh)          | nil (reader fetches fresh)           | `"https://github.com/" .. repo`      |

## State Fields Added to `state.data`

| Field              | Type          | Set by                  |
|--------------------|---------------|-------------------------|
| `team_events`      | list of event | `fetch_team_activity`   |
| `team_events_err`  | string        | `fetch_team_activity`   |
