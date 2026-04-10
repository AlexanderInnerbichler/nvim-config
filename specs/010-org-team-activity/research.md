# Research: Org Team Activity Feed

## GitHub Events API

**Decision**: Use `GET /orgs/{org}/events` endpoint via `gh api`  
**Rationale**: Returns the org's public event timeline (visible to the authenticated user), which is exactly what the spec describes. The `/user/events/orgs/{org}` endpoint returns events the user *received*, not org-wide events — wrong semantics.  
**Alternatives considered**: `/user/received_events` — too personal, mixes unrelated repos. `/search/events` — not available via REST.

## Org List Discovery

**Decision**: Re-fetch `GET /user/orgs` inside `fetch_team_activity` (same call as `fetch_org_repos`)  
**Rationale**: There is no shared org list state between fetch functions in the current architecture — each fetch is fire-and-forget with a callback. The spec says "no separate org-detection call needed" meaning no *new* API endpoint is introduced; `GET /user/orgs` is already used for org repos and is the canonical source. Two calls to the same cached-by-gh endpoint is acceptable.  
**Alternatives considered**: Refactoring to share state — over-engineering; caching org list in module state — adds complexity not justified by one extra cheap call.

## Event Payload: PR/Issue Number Extraction

**Decision**: JQ filter extracts `pr_number` and `issue_number` directly from payload  
**Rationale**: The reader's `M.open(item)` requires `number` + `repo` + `kind`. Extracting at fetch time (in JQ) avoids Lua-side payload parsing and keeps the data model flat.

JQ filter per org:
```
[.[] | {type, actor: .actor.login, repo: .repo.name, created_at,
        pr_number: .payload.pull_request.number,
        issue_number: .payload.issue.number}]
```

**Alternatives considered**: Fetching full payload and parsing in Lua — unnecessary complexity; payload shapes differ per event type and JQ handles this cleanly with null-safe `//`.

## Event Merge & Sorting

**Decision**: Collect all org events into one table, sort by `created_at` descending (string compare), take first 10  
**Rationale**: ISO 8601 timestamps sort correctly as strings (lexicographic = chronological). No date parsing needed for sort.  
**Alternatives considered**: `os.time()` parse for sort — correct but unnecessary given ISO 8601 lexicographic property.

## Reader Integration (kind routing)

**Decision**: Team activity items use the same `kind` values as existing dashboard items  
- `PullRequestEvent` → `kind = "pr"`, `number = pr_number`, `repo = repo`  
- `IssuesEvent` → `kind = "issue"`, `number = issue_number`, `repo = repo`  
- All other events → `kind = "push"` (or any non-reader kind) + `url = "https://github.com/" .. repo`

**Rationale**: `open_url_at_cursor` already handles: reader kinds ("pr", "issue", "repo") go to `gh_reader.open(item)`; any other kind opens `item.url` in browser. No code change needed in the router.

## Row Format

**Decision**: Each team activity row: `actor  event_summary  repo  age`  
Matching the existing `render_activity` format (icon + summary + repo + age), but replacing icon with actor username.

Format string:
```lua
string.format("   %-18s  %s  %-30s  %s", actor:sub(1,18), icon, repo:sub(1,30), age)
```

**Rationale**: Actor is the distinguishing field for team events (vs personal activity where actor is always self). Icon still conveys event type visually.

## Error Handling

**Decision**: Per-org fetch errors are silently ignored (successful orgs' events shown); total failure (no orgs or all fail) shows error message in section header  
**Rationale**: Matches spec FR-009 and edge case "partial failure" behavior. Consistent with `fetch_org_repos` pattern.

## `pending` counter in `start_secondary_fetches`

**Decision**: Bump `pending` from 4 → 5 in `start_secondary_fetches`  
**Rationale**: `fetch_team_activity` is one additional async fetch alongside the existing four (prs, issues, repos, org_repos).
