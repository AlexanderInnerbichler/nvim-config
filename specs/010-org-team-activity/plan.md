# Implementation Plan: Org Team Activity Feed

**Branch**: `010-org-team-activity` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/010-org-team-activity/spec.md`

## Summary

Add a "Team Activity" section to the GitHub Dashboard showing recent events from members of the user's GitHub organizations. The section loads asynchronously alongside other secondary fetches. Pressing `<CR>` on PR/issue events opens them in the existing inline reader; push/fork/star events open the repo URL in the browser.

All changes are confined to a single file: `lua/alex/github_dashboard.lua`.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI v2.45.0, `gh_reader.lua` (existing), `vim.system()` (built-in async)  
**Storage**: N/A — team events are not cached; fetched each dashboard refresh cycle  
**Testing**: Manual smoke test (open dashboard, verify Team Activity section)  
**Target Platform**: Linux (WSL2), Neovim terminal  
**Project Type**: Neovim plugin (single-file Lua module)  
**Performance Goals**: Section appears within the same async window as other secondary sections; no additional wait  
**Constraints**: Max 10 events total across all orgs; section absent when no orgs  
**Scale/Scope**: Typically 1-3 orgs; events cap hard at 10

## Constitution Check

*Applies Neovim Lua conventions (no Python-specific rules); general principles apply.*

| Principle | Status | Notes |
|-----------|--------|-------|
| No unnecessary code | ✅ Pass | Single new fetch + render function pair; no abstractions added |
| Functions ≤ 80 lines | ✅ Pass | `fetch_team_activity` ~35 lines, `render_team_activity` ~35 lines |
| Max 4 levels indentation | ✅ Pass | Fan-out pattern matches existing `fetch_org_repos` |
| No speculative abstractions | ✅ Pass | No shared org-fetch helper (would serve 2 callers, below threshold) |
| No error handling for impossible scenarios | ✅ Pass | Only handles expected: no orgs, partial failures, total failure |
| Logical commits + push after each task | ✅ Required | One commit per completed task |

## Project Structure

### Documentation (this feature)

```text
specs/010-org-team-activity/
├── plan.md              ← this file
├── research.md          ← Phase 0 output
├── data-model.md        ← Phase 1 output
└── tasks.md             ← Phase 2 output (from /speckit.tasks)
```

### Source Code

All changes in one file:

```text
lua/alex/github_dashboard.lua   ← add fetch_team_activity, render_team_activity,
                                    wire into apply_render + start_secondary_fetches
```

No new files. No contracts (internal module, no external interface changes).

## Implementation Details

### 1. `fetch_team_activity(callback)`

Pattern mirrors `fetch_org_repos`:
1. Call `gh api /user/orgs --paginate` → list of orgs
2. If no orgs → `callback(nil, {})` (silently absent per FR-005)
3. For each org, call `gh api /orgs/{login}/events` with JQ filter extracting: `type`, `actor.login`, `repo.name`, `created_at`, `payload.pull_request.number`, `payload.issue.number`
4. Collect all events; per-org errors silently ignored (only `any_err` tracks total failure)
5. When all org fetches complete: sort by `created_at` desc (string compare), take `[1..10]`, `callback(any_err, events)`

### 2. `render_team_activity(lines, hl_specs, items, team_events, err)`

Pattern mirrors `render_org_repos`:
- If no error AND no events → `return` (section absent, per FR-005 / SC-004)
- Header: `"  Team Activity"` with `GhSection` highlight
- On error: show `"  ✗ ..."` with `GhError`
- Per event row: `"   actor  icon  repo  age"` using `EVENT_ICONS[type] or "·"`
- Insert into `items`:
  - PullRequestEvent: `{ line, kind="pr", number=pr_number, repo=repo }`
  - IssuesEvent: `{ line, kind="issue", number=issue_number, repo=repo }`
  - Other: `{ line, kind="push", url="https://github.com/"..repo }`

### 3. Wire-up in `apply_render`

```lua
render_team_activity(lines, hl_specs, items, data.team_events, data.team_events_err)
```
Added after `render_org_repos` call.

### 4. Wire-up in `start_secondary_fetches`

Bump `pending = pending + 5` (was 4), add:
```lua
fetch_team_activity(function(err, events)
  if err then state.data.team_events_err = err else state.data.team_events = events end
  done(err ~= nil)
end)
```

## Complexity Tracking

No constitution violations.
