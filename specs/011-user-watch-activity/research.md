# Research: User Watch Activity Feed

## Events Endpoint

**Decision**: Use `GET /users/{username}/events` per watched user  
**Rationale**: This is the exact same endpoint already used by `fetch_activity` in `github_dashboard.lua` for the personal activity section. It returns the user's public event timeline. No additional scopes needed beyond the current gh token.  
**Alternatives considered**: `/users/{username}/received_events` — returns events the user *received*, not what they *did*. Wrong semantics.

## Watch List Storage

**Decision**: `~/.config/nvim/gh-user-watchlist.json` — stores `{ "users": ["username1", "username2"] }`  
**Rationale**: Mirrors the repo watchlist pattern (`gh-watchlist.json` stores `{ "repos": [...] }`). Separate file from the repo watchlist to avoid coupling. Atomic write via `.tmp` + `fs_rename` as used everywhere else.  
**Alternatives considered**: Reusing `gh-watchlist.json` with a new top-level key — would require reading/writing the existing watchlist file from a new module, creating coupling. Separate file is cleaner.

## Module Architecture

**Decision**: New standalone module `lua/alex/gh_user_watchlist.lua` for persistence + manager UI; `github_dashboard.lua` calls `require("alex.gh_user_watchlist").get_users()` to get the current list at fetch time.  
**Rationale**: Mirrors how `gh_watchlist.lua` is structured. Dashboard keeps all fetch/render logic; `gh_user_watchlist.lua` owns persistence and UI. `get_users()` is a synchronous call — the module is loaded at startup via `M.setup()` in init.lua before the dashboard is ever opened.  
**Alternatives considered**: Reading the JSON file directly from the dashboard — works but couples the dashboard to the storage format. The module abstraction is minimal overhead and consistent with existing patterns.

## Dashboard Integration

**Decision**: `fetch_watched_users_activity(callback)` + `render_watched_users(...)` added to `github_dashboard.lua`; `pending` bumped by 1 more in `start_secondary_fetches`.  
**Rationale**: Exact same fan-out + merge pattern as `fetch_team_activity`. No refactoring needed — the two functions are similar but differ in data source and endpoint.  
**Alternatives considered**: Extracting a shared `fetch_user_events_for_list` helper — would serve 2 callers (team activity uses org endpoint, not user endpoint), so not identical enough for abstraction. Threshold not met.

## nil vs {} Sentinel (Empty Watch List)

**Decision**: `callback(nil, nil)` when list is empty; `callback(nil, {})` when list is non-empty but all fetches returned nothing; render guard `team_events == nil` → absent, `{}` → "No recent activity from watched users".  
**Rationale**: Same pattern established and proven correct by the Team Activity fix. Distinguishes "no users" (silently absent) from "users but no events" (section visible).

## Manager UI

**Decision**: Single manager popup reusing the exact same `open_manager()` pattern from `gh_watchlist.lua` — centered floating window with `a` to add, `d`/`x` to delete, `q` to close.  
**Rationale**: Consistency with existing UX. The input popup pattern (`<C-s>` confirm, `<Esc><Esc>` cancel) is already familiar to the user.  
**Key difference vs repo watchlist**: Input accepts a bare username string (not `owner/repo` format). Validation: non-empty and no `/` character.

## Keymap

**Decision**: `<leader>gu` — toggle the user watchlist manager  
**Rationale**: `<leader>gw` is taken by repo watchlist. `<leader>gu` = "GitHub Users". Not conflicting with any existing keymap in `remap.lua`.

## JQ Filter for User Events

**Decision**: Same filter as team activity but with `.[0:20]` applied at the source to limit data per user:  
```
[.[] | {type, actor: .actor.login, repo: .repo.name, created_at, pr_number: .payload.pull_request.number, issue_number: .payload.issue.number}] | .[0:20]
```
**Rationale**: Fetching 20 per user is sufficient to fill the 10-event cap across all watched users (unless all 20 from user A are newer than all of user B's events, which is handled correctly by the global sort+cap). Same approach used in the personal activity section.
