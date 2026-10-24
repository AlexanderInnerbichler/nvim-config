# Implementation Plan: Org Repo Browser in Dashboard

**Branch**: `009-org-repo-browser` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-org-repo-browser/spec.md`

## Summary

Add an "Organization Repositories" section to the GitHub Dashboard. Auto-detect orgs via `gh api /user/orgs`, then fetch the top-10 most-recently-pushed repos per org via `gh repo list --owner ORG`. Render as a new section after personal repos using the existing `render_repos` pattern. No changes to `gh_reader.lua` or `gh_watchlist.lua` — `kind="repo"` + `full_name` already handles README open and `w` watchlist toggle.

## Technical Context

**Language/Version**: Lua (LuaJIT 2.1), Neovim 0.12.0-dev  
**Primary Dependencies**: `gh` CLI (existing), `github_dashboard.lua` (all changes here)  
**Storage**: Org repos not cached separately — fetched as part of normal dashboard refresh  
**Testing**: Manual — open dashboard, verify "Organization Repositories" section  
**Target Platform**: Linux (WSL2), terminal Neovim  
**New files**: none  
**Modified files**: `lua/alex/github_dashboard.lua`

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. No Unnecessary Code | ✅ Pass | No new files; reuses existing render pattern |
| II. Python type annotations | N/A | Lua project |
| III. No silent exception swallowing | ✅ Pass | Org fetch errors shown in section; org list failure silently omits section |
| IV. Logical commits, push after each task | ✅ Pass | One commit per phase |
| V. Backend/frontend separation | N/A | Single-layer Neovim module |
| VI. Branch lifecycle management | ✅ Pass | Merge + delete after completion |

## Project Structure

```text
lua/alex/github_dashboard.lua   ← fetch_org_repos, render_org_repos, integrate into fetch_and_render
```

---

## Phase A — `fetch_org_repos(callback)`

**Location**: `lua/alex/github_dashboard.lua`, after `fetch_repos` (~line 297).

Two-step async fetch: first list the user's orgs, then fan out to fetch repos per org, merge and sort by `pushedAt` descending.

```lua
local function fetch_org_repos(callback)
  run_gh(
    { "gh", "api", "/user/orgs", "--paginate" },
    function(err, orgs)
      if err or not orgs or #orgs == 0 then
        callback(nil, {})  -- silently omit section when org list fails
        return
      end

      local pending = #orgs
      local all_repos = {}
      local any_err

      for _, org in ipairs(orgs) do
        run_gh(
          { "gh", "repo", "list", "--owner", org.login, "--limit", "10",
            "--json", "name,nameWithOwner,url,primaryLanguage,stargazerCount,isPrivate,pushedAt" },
          function(ferr, repos)
            if ferr then
              any_err = ferr
            else
              for _, r in ipairs(repos or {}) do
                table.insert(all_repos, {
                  name       = r.name,
                  full_name  = r.nameWithOwner,
                  url        = r.url,
                  language   = type(r.primaryLanguage) == "table" and r.primaryLanguage.name or "",
                  stars      = r.stargazerCount or 0,
                  is_private = r.isPrivate,
                  updated_at = r.pushedAt,
                })
              end
            end
            pending = pending - 1
            if pending == 0 then
              table.sort(all_repos, function(a, b)
                return (a.updated_at or "") > (b.updated_at or "")
              end)
              callback(any_err, all_repos)
            end
          end
        )
      end
    end
  )
end
```

> **Note on error handling**: The org list call failing means the user has no orgs or the network is down — silently return `{}` so the section is omitted. Individual org repo fetch failures are surfaced via `any_err` which shows the error message in the section.

---

## Phase B — `render_org_repos(lines, hl_specs, items, org_repos, err)`

**Location**: `lua/alex/github_dashboard.lua`, after `render_repos` (~line 513).

Identical structure to `render_repos`, just a different section header and message:

```lua
local function render_org_repos(lines, hl_specs, items, org_repos, err)
  if not err and (not org_repos or #org_repos == 0) then return end

  local header = "  Organization Repositories"
  table.insert(lines, header)
  table.insert(hl_specs, { hl = "GhSection", line = #lines - 1, col_s = 0, col_e = #header })

  if err then
    local msg = "  ✗ " .. sl(err)
    table.insert(lines, msg)
    table.insert(hl_specs, { hl = "GhError", line = #lines - 1, col_s = 0, col_e = #msg })
  else
    for _, repo in ipairs(org_repos) do
      local lock = repo.is_private and "🔒" or " ⊙"
      local lang = sl(repo.language) ~= "" and sl(repo.language) or "—"
      local age  = age_string(repo.updated_at)
      local line = string.format("   %s  %-30s  %-10s  ★%-3d  %s",
        lock, sl(repo.name):sub(1, 30), lang:sub(1, 10), repo.stars, age)
      table.insert(items, { line = #lines, url = repo.url, full_name = repo.full_name, kind = "repo" })
      table.insert(lines, line)
      table.insert(hl_specs, { hl = "GhItem", line = #lines - 1, col_s = 0, col_e = 35 })
      table.insert(hl_specs, { hl = "GhMeta", line = #lines - 1, col_s = 45, col_e = -1 })
    end
  end
end
```

> **Visibility rule**: Section is omitted entirely when no org repos exist and there's no error (`#org_repos == 0 and not err`). This satisfies FR-006 (graceful no-orgs state) without a distracting empty section.

---

## Phase C — Wire into `apply_render` and `fetch_and_render`

### C1: `apply_render` (~line 534)

Add `render_org_repos` call after `render_repos`:

```lua
render_repos(lines, hl_specs, items, data.repos, data.repos_err)
render_org_repos(lines, hl_specs, items, data.org_repos, data.org_repos_err)
```

### C2: `fetch_and_render` — `start_secondary_fetches` (~line 570)

Increment `pending` by 1 more and add `fetch_org_repos` call:

```lua
-- change: pending = pending + 3  →  pending = pending + 4
pending = pending + 4
fetch_prs(...)
fetch_issues(...)
fetch_repos(...)
fetch_org_repos(function(err, org_repos)
  if err then state.data.org_repos_err = err else state.data.org_repos = org_repos end
  done(err ~= nil)
end)
```

> **FR-007 compliance**: `fetch_org_repos` is one more parallel fetch in the existing fan-out pattern. The dashboard renders from cache immediately; the org section populates when the fetch completes — no blocking.

**Commit**: `feat: org repo browser — new Organization Repositories section in dashboard`

---

## Verification

1. Open dashboard → "Organization Repositories" section appears after "Repositories"
2. Each row shows: lock icon, repo name, language, stars, age
3. Press `<CR>` on an org repo → README popup opens, breadcrumb = `GitHub Dashboard › org/repo › README`
4. Press `w` on an org repo → "Added org/repo to watchlist" notification; `gh-watchlist.json` updated
5. No org memberships → section is absent (not shown at all)
6. Network error on org repo fetch → section shows error message, dashboard does not crash
7. Press `<CR>` on PR/issue/personal repo rows → existing behavior unchanged
