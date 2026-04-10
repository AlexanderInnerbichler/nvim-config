# Data Model: GitHub Issue & PR Inline Reader

**Branch**: `002-gh-issue-pr-reader` | **Date**: 2026-04-09

---

## Module State (in-memory, `gh_reader.lua`)

```lua
local state = {
  buf      = nil,    -- reader buffer handle (number | nil)
  win      = nil,    -- reader window handle (number | nil)
  item     = nil,    -- current item: { kind, number, repo, url }
  data     = nil,    -- decoded detail table (IssueDetail | PRDetail)
  input_buf = nil,   -- comment/review input buffer (number | nil)
  input_win = nil,   -- comment/review input window (number | nil)
}
```

---

## Item (passed from dashboard)

```lua
-- Shape added to github_dashboard.lua items list
{
  kind   = "issue" | "pr" | "repo",  -- discriminator
  number = 42,                        -- number (nil for repo)
  repo   = "owner/repo-name",         -- string (owner/repo format)
  url    = "https://github.com/...",  -- string (kept for repo xdg-open fallback)
  line   = 12,                        -- number (buffer line, existing field)
}
```

---

## IssueDetail

Source: `gh issue view {n} -R {repo} --json number,title,state,body,labels,author,comments,createdAt,assignees,url`

```lua
{
  kind       = "issue",              -- injected by reader
  number     = 1,                    -- number
  title      = "Bug: ...",           -- string
  state      = "OPEN" | "CLOSED",   -- string
  body       = "Description...",    -- string (markdown)
  labels     = { "bug", "priority" }, -- list[string] (from labels[].name)
  author     = "AlexanderInnerbichler", -- string (from author.login)
  assignees  = { "alex" },          -- list[string] (from assignees[].login)
  created_at = "2026-04-09T...",    -- string (ISO 8601)
  url        = "https://...",       -- string
  comments   = { ... },             -- list[Comment]
}
```

---

## PRDetail

Source: `gh pr view {n} -R {repo} --json number,title,state,body,author,headRefName,baseRefName,reviews,statusCheckRollup,comments,createdAt,isDraft,mergeable,url,assignees`

```lua
{
  kind          = "pr",                     -- injected by reader
  number        = 25,                       -- number
  title         = "feat: ...",              -- string
  state         = "OPEN" | "CLOSED" | "MERGED", -- string
  body          = "## Summary...",          -- string (markdown)
  author        = "AlexanderInnerbichler", -- string
  head_ref      = "feature-branch",        -- string (headRefName)
  base_ref      = "master",               -- string (baseRefName)
  is_draft      = false,                   -- boolean
  mergeable     = "MERGEABLE" | "CONFLICTING" | "UNKNOWN", -- string
  created_at    = "2026-04-09T...",        -- string
  url           = "https://...",           -- string
  labels        = {},                      -- list[string]
  assignees     = {},                      -- list[string]
  reviews       = { ... },                 -- list[Review]
  ci_checks     = { ... },                 -- list[CICheck] (from statusCheckRollup)
  comments      = { ... },                 -- list[Comment]
}
```

---

## Comment

Part of both IssueDetail and PRDetail `comments` list.

```lua
{
  id         = "IC_...",              -- string (comment id, for future edit/delete)
  author     = "AlexanderInnerbichler", -- string (from author.login)
  body       = "Looks good!",        -- string (markdown)
  created_at = "2026-04-09T...",     -- string
}
```

---

## Review

Part of PRDetail `reviews` list.

```lua
{
  author       = "reviewer-login",   -- string
  state        = "APPROVED" | "CHANGES_REQUESTED" | "COMMENTED", -- string
  body         = "LGTM",             -- string (may be empty)
  submitted_at = "2026-04-09T...",   -- string
}
```

---

## CICheck

Part of PRDetail `ci_checks` list (from `statusCheckRollup`).

```lua
{
  name       = "ci / test",           -- string (from name or context field)
  status     = "SUCCESS" | "FAILURE" | "PENDING" | "SKIPPED" | "ERROR", -- string
  conclusion = "success" | "failure" | nil, -- string | nil
}
```

---

## Rendered Buffer Layout

The reader buffer is written as plain text (filetype=markdown) with this structure:

```
Line 0: ""   (padding)
Line 1: "  #42  Issue Title Here                                OPEN"
Line 2: "  author · label1 · label2 · 2d ago"
Line 3: "  ─────────────────────────────────────────────"  (separator)
Line 4: [body markdown lines...]
Line N: "  ─────────────────────────────────────────────"
Line N+1: "  💬 Comments (3)"
Line N+2: ""
Line N+3: "  @author · 1h ago"
Line N+4: [comment body markdown lines...]
...
```

For PR additionally between separator and body:
```
Line 3: "  ⎇ feature-branch → master    draft: No    mergeable: Yes"
Line 4: "  CI: ✓ ci/test  ✗ ci/lint  ⠋ ci/deploy"
Line 5: "  Reviews: ✓ reviewer1  ✗ reviewer2"
Line 6: "  ─────────────────────────────────────────────"
```

---

## Input Buffer Layout

When composing a comment or review (opened in horizontal split):

```
Line 0: "-- Write your comment below. <leader>s to submit, <Esc><Esc> to cancel --"
Line 1: ""
Line 2: [user types here...]
```

Submitted text is extracted as everything from line 1 onward (stripping the header comment).
