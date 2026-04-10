# Research: GitHub Dashboard for Neovim

**Branch**: `001-github-dashboard` | **Date**: 2026-04-09

## Decision 1: Data Source

**Decision**: Use `gh` CLI (GitHub CLI) as the exclusive data source for all GitHub API calls.

**Rationale**: Already installed and authenticated (`gh version 2.45.0`). Handles OAuth token refresh, rate limiting headers, and all authentication. Zero additional setup for the user. All required data is reachable via `gh api` and `gh pr list` / `gh issue list`.

**Alternatives considered**:
- Direct GitHub REST API via `curl` — requires managing tokens, no advantage over `gh`
- `octo.nvim` plugin — heavy dependency, would own the UI layer we want to design ourselves
- Lua HTTP library — adds a dependency, worse auth story

**Commands confirmed working**:
```
gh api user                                       # profile
gh pr list --author @me --state open              # open PRs
gh issue list --assignee @me --state open         # open issues assigned to me
gh api /users/{login}/events                      # recent activity (30 events)
gh api graphql -f query='...'                     # contributions calendar (GraphQL)
gh repo list --limit 10 --json name,url,...       # recent repos
```

---

## Decision 2: Async Execution

**Decision**: Use `vim.system()` (Neovim 0.10+) for all async shell calls.

**Rationale**: Neovim 0.12.0 is running, so `vim.system()` is available and stable. It is the idiomatic modern Neovim approach — no extra dependencies. It supports callbacks and `vim.schedule()` for safe UI updates from callbacks.

**Alternatives considered**:
- `plenary.job` — also available (plenary.nvim is installed), but `vim.system()` is built-in and preferred for new code
- Synchronous `vim.fn.system()` — blocks the UI, unacceptable for network calls

**Pattern**:
```lua
vim.system({ "gh", "api", "user" }, { text = true }, function(result)
  vim.schedule(function()
    -- safe to update UI here
    local data = vim.fn.json_decode(result.stdout)
  end)
end)
```

---

## Decision 3: UI Framework

**Decision**: Raw Neovim API (`vim.api`) — no nui.nvim.

**Rationale**: The existing HUD (`lua/alex/hud.lua`) and plan_viewer (`lua/alex/plan_viewer.lua`) both use raw `vim.api` directly. Consistent with codebase patterns. `nui.nvim` is installed but never used in custom code. Introducing it for this feature would be a new pattern without justification.

**Layout approach**: Single full-screen floating window split into visual sections using separator lines. Buffer is `nomodifiable` with syntax highlights applied via `nvim_buf_add_highlight`.

**Alternatives considered**:
- `nui.nvim` Layout + Popup — more structured API but adds conceptual weight
- Telescope picker — wrong paradigm for a dashboard (search, not browse)
- Split windows — less focused, harder to dismiss cleanly

---

## Decision 4: Caching Strategy

**Decision**: Write JSON cache to `~/.cache/nvim/gh-dashboard.json` with a 5-minute TTL. Dashboard shows cached data instantly on open; refreshes async in background.

**Rationale**: The HUD uses the same pattern (reads from `~/.claude/hud.json` on a timer). Familiar, simple, no new infra. 5 minutes matches spec SC-002.

**On-open behavior**:
1. If cache exists and age < 5 min: show immediately, no fetch
2. If cache exists and age >= 5 min: show stale data with indicator, trigger background refresh
3. If no cache: show loading skeleton, fetch all sections in parallel

---

## Decision 5: Contribution Heatmap Rendering

**Decision**: Use block shading characters (` `, `░`, `▒`, `▓`, `█`) mapped to 5 contribution tiers for the heatmap. Display last 26 weeks (half-year) to fit in ~80 columns.

**Rationale**: Confirmed the GraphQL endpoint returns contribution data by day/week. Block chars render in all terminals. 26 weeks × 7 rows = one column per week, fits in 80-char terminals comfortably.

**Tiers** (calibrated to actual data — max seen ~83 contributions/day):
- 0 contributions: ` ` (space, dim)
- 1–3: `░`
- 4–9: `▒`
- 10–24: `▓`
- 25+: `█`

**Alternatives considered**:
- Braille characters — more granular, but harder to read in most fonts
- Full-year heatmap — 52 weeks, requires ~110 columns, exceeds SC-005 target

---

## Decision 6: Module Structure

**Decision**: Single file `lua/alex/github_dashboard.lua` with `M.toggle()` and `M.setup()` public interface — same pattern as `plan_viewer.lua`.

**Rationale**: Matches existing module pattern exactly. One file, one concern. No subdirectory needed for this scope.

**Keybinding**: `<leader>gh` — fits the `<leader>g` git-adjacent prefix already established in `remap.lua`, no conflict with existing bindings (`gs`, `gc`, `gd`, `gl`).

---

## Decision 7: Layout Design

**Decision**: Full-screen centered floating window (90% width, 90% height) with labeled sections separated by divider lines. Inspired by clean Apple-style TUI aesthetics — minimal, high-contrast, well-padded.

**Section order** (top to bottom):
```
┌─ GitHub Dashboard ──────────────────────────┐
│  Profile: AlexanderInnerbichler  ●  1092 contributions  │
│  Heatmap (26 weeks)                         │
│  ───────────────────────────────────────── │
│  Open PRs (N)                               │
│  ───────────────────────────────────────── │
│  Assigned Issues (N)                        │
│  ───────────────────────────────────────── │
│  Recent Activity                            │
└─────────────────────────────────────────────┘
```

**Keybindings inside dashboard**:
- `q` / `<Esc>` — close
- `r` — force refresh
- `<CR>` / `o` — open selected item in browser (`xdg-open`)

---

## APIs Verified

| Data | Command | Status |
|------|---------|--------|
| Profile | `gh api user` | ✅ Returns login, name, bio, followers, following, public_repos |
| Open PRs | `gh pr list --author @me --state open` | ✅ (empty now, correct) |
| Issues | `gh issue list --assignee @me` | ✅ (empty now, correct) |
| Activity | `gh api /users/{login}/events` | ✅ Returns 30 events with type, repo, date |
| Contributions | `gh api graphql -f query='...'` | ✅ Returns 52 weeks × 7 days |
| Repos | `gh repo list --limit 10` | Not tested, assumed working |
