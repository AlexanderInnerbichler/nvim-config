# Data Model: Watched User Profile Popup

## Entities

### UserProfile
Fetched from `gh api /users/{username}` on popup open. Not persisted.

| Field        | Type   | Source              | Notes                         |
|--------------|--------|---------------------|-------------------------------|
| login        | string | `.login`            | GitHub username               |
| name         | string | `.name`             | Display name; may be null     |
| bio          | string | `.bio`              | Profile bio; may be null      |
| public_repos | number | `.public_repos`     | Count of public repositories  |
| followers    | number | `.followers`        | Follower count                |
| following    | number | `.following`        | Following count               |

### ContributionCalendar
Fetched via GraphQL `user(login: "USERNAME") { contributionsCollection { contributionCalendar { ... } } }`. Not persisted.

| Field   | Type               | Notes                                          |
|---------|--------------------|------------------------------------------------|
| total   | number             | Total contributions this year                  |
| weeks   | Week[]             | Last 26 weeks of contribution data             |

### Week (nested in ContributionCalendar)

| Field | Type  | Notes                            |
|-------|-------|----------------------------------|
| days  | Day[] | 7 days (some weeks have <7 days) |

### Day (nested in Week)

| Field | Type   | Notes                                        |
|-------|--------|----------------------------------------------|
| date  | string | ISO date string `YYYY-MM-DD`                 |
| count | number | Number of contributions on that day          |
| tier  | number | 1–5 render tier (1=none, 5=max)              |

---

## Popup Window Item

Items inserted into `state.items` in `github_dashboard.lua` for the `kind="user"` actor header rows in "Watched Users":

| Field    | Type   | Notes                       |
|----------|--------|-----------------------------|
| line     | number | 0-indexed buffer line        |
| kind     | string | `"user"`                    |
| username | string | The GitHub login to open    |
