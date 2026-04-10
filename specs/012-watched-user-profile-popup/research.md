# Research: Watched User Profile Popup

## Decision: New standalone module vs extending existing modules

**Decision**: New `lua/alex/gh_user_profile.lua` module  
**Rationale**: The popup is an independent UI component with its own async lifecycle and window. Keeping it in a standalone module avoids coupling dashboard internals to the popup, and keeps `gh_user_watchlist.lua` focused on list management.  
**Alternatives considered**: Adding to `gh_user_watchlist.lua` (mixes concerns — list mgmt vs profile display); adding to `github_dashboard.lua` (bloats an already large file; popup has no need for dashboard state)

---

## Decision: Reuse render_heatmap / render_profile from dashboard vs duplicate

**Decision**: Duplicate (with adaptations) into `gh_user_profile.lua`  
**Rationale**: `render_profile` references `state.is_loading` and `state.is_stale` from dashboard module state — it cannot be called from outside without modification. The shared constants (TIER_CHARS, HEAT_HLS, 4 lines of `contribution_tier`) are small enough that duplication is cheaper than extracting a shared utility. Two callers is below the three-pattern threshold per constitution.  
**Alternatives considered**: Exporting from `github_dashboard.lua` as `M.render_heatmap` — creates undesirable coupling between modules; extracting a `gh_render_utils.lua` — premature abstraction for 2 callers

---

## Decision: Dashboard "Watched Users" layout — grouped by user vs flat

**Decision**: Group events by actor with per-user header rows  
**Rationale**: The spec requires "username rows" that `<CR>` can act on. Grouping by actor also improves readability (easy to scan per-user activity). A `kind="user"` item is inserted for each actor header row, routed to `open_url_at_cursor` → `gh_user_profile.open(username)`.  
**Alternatives considered**: Flat list with a new `u` keymap for "open actor's profile" — simpler but spec explicitly describes username rows; changing `<CR>` on all event rows to open profile (loses PR/issue navigation)

---

## Decision: GraphQL query parameterization for contributions

**Decision**: Use `user(login: "USERNAME") { contributionsCollection { ... } }` (not `viewer`)  
**Rationale**: The `viewer` field returns the authenticated user's data. To fetch another user's data, the GraphQL `user(login:)` field is used. The response shape is identical — `data.user.contributionsCollection.contributionCalendar` vs `data.viewer.contributionsCollection.contributionCalendar`.  
**Alternatives considered**: REST `/users/{username}/events` — does not provide contribution calendar; only GraphQL has that

---

## Decision: Loading state — open window immediately vs wait for data

**Decision**: Open window immediately with "Loading..." then replace content when data arrives  
**Rationale**: Both profile and contribution fetches are network calls (~200–500ms). Showing a loading state immediately gives feedback. The fan-out pattern (pending=2, callback fires render when both complete) is already established in the dashboard.  
**Alternatives considered**: Block until data ready (no feedback); open on first partial result (complicates render logic)
