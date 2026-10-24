# Research: Repo Watchlist with Activity HUD

## Decision 1: Background polling with `vim.uv.new_timer()`

**Decision**: Use `vim.uv.new_timer()` with a 60-second repeat interval and `vim.schedule_wrap()` callback for all poll logic.

**Rationale**: The existing `lua/alex/hud.lua` already demonstrates this exact pattern (`timer:start(3000, 3000, vim.schedule_wrap(refresh))`). It is non-blocking (runs in the libuv event loop), supports clean stop/close lifecycle, and is the canonical Neovim 0.10+ approach. The timer reference is stored in module state and reused — no new timers created on re-setup.

**Alternatives considered**:
- `vim.defer_fn` — one-shot only, requires chaining for repeats; fragile
- `vim.loop` — older alias for `vim.uv`; identical behaviour, prefer `vim.uv`
- Autocmd-based polling (e.g., `CursorHold`) — fires only on user activity, misses notifications when idle

---

## Decision 2: Floating corner notification window

**Decision**: `nvim_open_win` with `relative="editor"`, top-right corner position, `width=52`, `height=3`, `focusable=false`, `zindex=10`. Auto-dismissed by a second `vim.uv.new_timer()` after 5 seconds.

**Rationale**: The `zindex` parameter is confirmed supported (found in `hud.lua:740`). `focusable=false` prevents focus steal during typing. `relative="editor"` positions to the full terminal surface. Top-right corner (`row=1`, `col=ui.width - width - 2`) is the conventional notification position and leaves the bottom-left coding area undisturbed.

**Multiple notifications**: At most 3 stacked notifications at once — each 4 lines apart vertically (3 content + 1 gap). If a 4th fires, the oldest is replaced. The notification buffer is a single-line summary: `⊙ owner/repo  ·  push · 2m ago`.

**Alternatives considered**:
- `vim.notify` (built-in) — cannot be styled to match the plugin's aesthetic; no action key support
- Bottom-right — conventionally reserved for status/progress indicators

---

## Decision 3: Watchlist persistence at `~/.config/nvim/gh-watchlist.json`

**Decision**: Same atomic read/write pattern as `github_dashboard.lua` (`write_cache` using `.tmp` + `fs_rename`). Store at `~/.config/nvim/gh-watchlist.json` (not cache dir) because watchlist is user config, not transient data.

**Schema**:
```json
{
  "repos": [
    { "owner": "alice", "repo": "myproject", "last_seen_id": "37891234567" },
    { "owner": "bob",   "repo": "tool",       "last_seen_id": "" }
  ]
}
```

**Rationale**: `~/.cache/nvim/` is for transient state that can be deleted freely. The watchlist is intentional configuration — it belongs in `~/.config/nvim/`. The existing `vim.fn.json_encode`/`json_decode` + `vim.fn.writefile` + `vim.uv.fs_rename` pattern is already proven in this codebase.

---

## Decision 4: GitHub Events API for per-repo polling

**Decision**: `gh api repos/{owner}/{repo}/events --jq '[.[] | {id,type,created_at,payload}]'` per watched repo. Deduplicate by comparing event `id` against `last_seen_id` stored per repo.

**Rationale**: The `/repos/{owner}/{repo}/events` endpoint returns up to 30 recent events for a specific repo including `id`, `type`, `created_at`, and a `payload` object containing nested data (PR number, issue number, branch name, comment body snippet). The event `id` is a stable string that uniquely identifies each event. Storing the most-recently-seen `id` per repo prevents the same event from re-notifying on the next poll.

**Event types to surface** (maps to user-visible notification text):
| API type | Display text |
|----------|-------------|
| `PushEvent` | `push: N commits to branch` |
| `PullRequestEvent` | `PR #N opened/closed/merged` |
| `IssuesEvent` | `issue #N opened/closed` |
| `IssueCommentEvent` | `comment on #N` |
| `PullRequestReviewEvent` | `review on PR #N` |
| Other | `activity` |

**Rate limits**: 5000 authenticated requests/hour. 20 repos × 1 request × 60 polls/hour = 1200 requests/hour — safely within limits.

---

## Decision 5: New module `lua/alex/gh_watchlist.lua`

**Decision**: Create a new standalone module following the existing `setup()` / `toggle()` / `focus_win()` interface pattern. Register in `lua/alex/init.lua` with `require("alex.gh_watchlist").setup()`. Add keymap `<leader>gw` in `lua/alex/remap.lua`.

**Module responsibilities**:
- `M.setup()` — load watchlist from disk, start poll timer, register highlights
- `M.toggle()` — open/close the watchlist manager popup
- Poll loop — runs every 60s, fetches events, shows notifications for new ones
- Notification windows — ephemeral corner popups, auto-dismissed

**Rationale**: Keeping it in a new file respects the single-responsibility structure of the codebase (each module owns one feature area). The watchlist manager is independent enough from the dashboard that merging them would bloat `github_dashboard.lua`.

---

## Decision 6: Watchlist manager UI

**Decision**: A floating popup (same 90%×90% pattern) listing watched repos. Keymaps: `a` add, `d`/`x` remove selected, `q` close. Adding uses the existing `M.open_input` pattern (floating input popup from `gh_reader.lua`).

**Rationale**: Consistent with the existing dashboard/reader popup style. No new UI patterns needed — list display and input popup are already implemented elsewhere in the codebase.

---

## Decision 7: No `data-model.md` or `contracts/` needed

**Decision**: Skip both. The feature has simple JSON persistence (two fields per repo) and no external API surface — it is a purely internal Neovim plugin.
