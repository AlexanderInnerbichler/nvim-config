# Data Model: GitHub Dashboard

**Branch**: `001-github-dashboard` | **Date**: 2026-04-09

## Cache File

**Path**: `~/.cache/nvim/gh-dashboard.json`

**Schema**:
```json
{
  "fetched_at": 1712649600,
  "profile": { ... },
  "prs": [ ... ],
  "issues": [ ... ],
  "activity": [ ... ],
  "contributions": { ... },
  "repos": [ ... ]
}
```

---

## Entities

### Profile

Source: `gh api user`

```lua
-- Lua table shape after decode
{
  login = "AlexanderInnerbichler",   -- string
  name  = "Alexander Innerbichler",  -- string
  bio   = "...",                     -- string (may be nil/empty)
  followers      = 1,                -- number
  following      = 5,                -- number
  public_repos   = 7,                -- number
  total_contributions = 1092,        -- number (from GraphQL, merged in)
}
```

---

### Pull Request

Source: `gh pr list --author @me --state open --json number,title,headRepository,url,createdAt,isDraft`

```lua
{
  number    = 42,                    -- number
  title     = "Add feature X",       -- string
  repo      = "org/repo-name",       -- string (headRepository.nameWithOwner)
  url       = "https://github.com/...",  -- string
  created_at = "2026-04-01T10:00:00Z",  -- string (ISO 8601)
  is_draft  = false,                 -- boolean
}
```

---

### Issue

Source: `gh issue list --assignee @me --state open --json number,title,repository,url,createdAt`

```lua
{
  number    = 17,                    -- number
  title     = "Bug: crash on startup", -- string
  repo      = "org/repo-name",       -- string (repository.nameWithOwner)
  url       = "https://github.com/...",  -- string
  created_at = "2026-03-28T08:00:00Z",  -- string (ISO 8601)
}
```

---

### Activity Event

Source: `gh api /users/{login}/events` (returns up to 30 events)

```lua
{
  type       = "PushEvent",          -- string (PushEvent|PullRequestEvent|IssuesEvent|etc.)
  repo       = "org/repo-name",      -- string
  created_at = "2026-04-09T08:18:42Z", -- string (ISO 8601)
  summary    = "pushed 3 commits",   -- string (derived from type + payload)
}
```

**Event type → summary mapping**:

| Type | Summary |
|------|---------|
| PushEvent | pushed N commits |
| PullRequestEvent | opened/closed/merged PR |
| IssuesEvent | opened/closed issue |
| IssueCommentEvent | commented on issue |
| CreateEvent | created branch/tag |
| ForkEvent | forked repo |
| WatchEvent | starred repo |

---

### Contribution Day

Source: GraphQL `contributionCalendar.weeks[].contributionDays[]`

```lua
{
  date  = "2026-04-09",   -- string (YYYY-MM-DD)
  count = 2,              -- number
  tier  = 1,              -- number 0–4 (derived: 0=none, 1=low, 2=mid, 3=high, 4=max)
}
```

**Tier thresholds**:

| Tier | Count | Character |
|------|-------|-----------|
| 0    | 0     | ` ` (space) |
| 1    | 1–3   | `░` |
| 2    | 4–9   | `▒` |
| 3    | 10–24 | `▓` |
| 4    | 25+   | `█` |

---

### Repository

Source: `gh repo list --limit 10 --json name,nameWithOwner,url,description,primaryLanguage,stargazerCount,isPrivate,updatedAt`

```lua
{
  name        = "bauwerks-monitoring", -- string
  full_name   = "org/bauwerks-monitoring", -- string (nameWithOwner)
  url         = "https://github.com/...",  -- string
  description = "...",               -- string (may be empty)
  language    = "Python",            -- string (may be nil)
  stars       = 0,                   -- number
  is_private  = true,                -- boolean
  updated_at  = "2026-04-09T08:15:32Z", -- string
}
```

---

## State (in-memory, not cached)

```lua
-- Module-level state in github_dashboard.lua
local state = {
  buf         = nil,   -- buffer handle (number | nil)
  win         = nil,   -- window handle (number | nil)
  data        = nil,   -- decoded cache table | nil
  is_loading  = false, -- boolean: background fetch in progress
  cursor_line = 1,     -- number: current cursor position for <CR> navigation
  items       = {},    -- list of { line=N, url="https://..." } for navigable items
}
```

---

## Helper: Age String

Utility to convert ISO 8601 timestamps to human-readable age strings used in display:

```
"2026-04-07T10:00:00Z"  →  "2d ago"
"2026-04-09T07:00:00Z"  →  "1h ago"
"2026-03-01T00:00:00Z"  →  "39d ago"
```
