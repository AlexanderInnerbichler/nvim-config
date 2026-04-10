# Feature Specification: User Watch Activity Feed

**Feature Branch**: `011-user-watch-activity`
**Created**: 2026-04-10
**Status**: Draft
**Input**: "i want to make something like the watch function for specified github users, add a similar overview field with the activity card like the one for the user"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View watched users' activity in the dashboard (Priority: P1)

When the user opens the GitHub Dashboard, a "Watched Users" section appears listing recent events from a manually curated list of GitHub users they have chosen to follow. Each row shows who did what, in which repo, and how long ago — identical in layout to the personal "Recent Activity" card. The section loads asynchronously and does not block other sections.

**Why this priority**: The core value of the feature — a single-pane view of what specific people on GitHub are doing. Without this display, the watched-user list has no visible effect.

**Independent Test**: Add at least one username to the watch list file → open dashboard → "Watched Users" section appears with that user's recent events, each row showing actor, event type, repo, and age.

**Acceptance Scenarios**:

1. **Given** at least one username is in the watch list, **When** the dashboard opens, **Then** a "Watched Users" section appears listing recent events (up to 10 total) from all watched users, each row showing: actor username, event type icon/label, repo name, and relative age
2. **Given** the watch list is empty, **When** the dashboard opens, **Then** the "Watched Users" section is silently absent — no header, no empty state, no error
3. **Given** the section is loading, **When** other sections have rendered from cache, **Then** "Watched Users" shows nothing until its fetch completes (non-blocking)
4. **Given** a fetch for one watched user fails, **When** the dashboard renders, **Then** events from successfully fetched users are still shown; the failed user is silently skipped
5. **Given** all watched users' fetches fail, **When** the dashboard renders, **Then** the section shows a brief error message

---

### User Story 2 - Manage the watched users list (Priority: P2)

The user can add or remove GitHub usernames from their watch list using an in-editor interface — the same popup-based flow used by the existing repo watchlist. A keymap opens a menu to add a new username or remove an existing one. The list persists across Neovim restarts.

**Why this priority**: Without a management UI, the user can only edit the storage file directly. The management popup makes the feature self-contained and consistent with the existing watchlist UX.

**Independent Test**: Press the add-user keymap → input popup appears → type a GitHub username and submit → re-open dashboard → that user's activity appears. Press the manage keymap → select the user → remove → dashboard no longer shows that user's events.

**Acceptance Scenarios**:

1. **Given** the user presses the add-user keymap, **When** the input popup appears and a valid GitHub username is submitted, **Then** that username is added to the persistent watch list and the dashboard reflects it on next open
2. **Given** the user opens the manage popup with existing watched users, **When** a username is selected and removed, **Then** that username is removed from the watch list and no longer appears in the dashboard
3. **Given** the user submits an empty string in the add popup, **When** the popup closes, **Then** the watch list is unchanged
4. **Given** a username is already in the watch list, **When** the user tries to add the same username again, **Then** the list remains unchanged (no duplicates)

---

### User Story 3 - Open a watched user's event in the reader (Priority: P3)

Pressing `<CR>` on a PR or issue event row in "Watched Users" opens that item in the existing inline reader popup — the same experience as for personal PR/issue rows and team activity rows. For non-reader events (push, fork, star), `<CR>` opens the repo URL in the browser.

**Why this priority**: Browse-only is useful; deep-linking into PR/issue review closes the loop. Follows the same pattern already established by Team Activity (feature 010).

**Independent Test**: Add a user who has recent PR activity → open dashboard → move cursor to a PullRequestEvent row under "Watched Users" → press `<CR>` → PR reader opens with correct PR. Press `q` → return to dashboard.

**Acceptance Scenarios**:

1. **Given** cursor is on a PullRequestEvent or IssuesEvent row in "Watched Users", **When** `<CR>` is pressed, **Then** the PR or issue opens in the inline reader with the correct breadcrumb
2. **Given** cursor is on a PushEvent, ForkEvent, or WatchEvent row, **When** `<CR>` is pressed, **Then** the repo URL opens in the browser

---

### Edge Cases

- Watch list contains a username that does not exist on GitHub — that user's fetch fails; silently skipped; other users' events still shown
- Watch list contains 10+ users — all are fetched; only the 10 most-recent events across all users are displayed
- Watched user has no public events — their fetch returns an empty list; they contribute nothing to the section
- Same user added twice — deduplicated on add; no duplicate entries
- Watch list file is missing or corrupt — treated as empty; section silently absent; no crash
- Watched user's username changes on GitHub — old username returns 404; silently skipped until the user removes/re-adds

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dashboard MUST display a "Watched Users" section listing recent events from all usernames in the watch list
- **FR-002**: The watch list MUST persist across Neovim restarts (stored in a local file)
- **FR-003**: Each event row MUST show: actor username, event type icon/label, repository name, and relative age
- **FR-004**: The section MUST load asynchronously and MUST NOT block the rest of the dashboard from rendering
- **FR-005**: The section MUST be silently absent when the watch list is empty
- **FR-006**: The section MUST show at most 10 events total across all watched users, ordered by most-recently-created first
- **FR-007**: A keymap MUST allow the user to add a GitHub username to the watch list via an inline input popup
- **FR-008**: A keymap MUST allow the user to remove a username from the watch list via a selection popup
- **FR-009**: Pressing `<CR>` on a PR or issue event row MUST open that item in the existing inline reader popup
- **FR-010**: Pressing `<CR>` on non-reader event rows (push, fork, star) MUST open the repo URL in the browser
- **FR-011**: Duplicate usernames MUST NOT be added to the watch list
- **FR-012**: If all watched-user fetches fail, the section MUST show a brief error message rather than being silently absent

### Key Entities

- **Watched user**: A GitHub username stored in the persistent watch list — carries only the username string; no metadata
- **User event**: A recent public GitHub event from a watched user — carries actor username, event type, repo full name, creation timestamp, and optional payload (PR number or issue number) for deep-linking

## Assumptions

- Only public events are shown — no private activity, regardless of token scopes
- The same public events endpoint used for personal activity is reused per watched user
- The watch list is stored in a separate file from the repo watchlist
- No real-time polling or notifications — events appear only on dashboard open/refresh
- The add/remove keymap is separate from the existing repo watchlist keymap
- At most 10 events across all watched users are shown (not 10 per user)
- The section does not show an empty-state message — if there are no users, the section is simply absent

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Watched users' activity appears in the dashboard within the same loading cycle as other async sections — no additional wait
- **SC-002**: 100% of existing dashboard behavior (all sections, keymaps, reader navigation) is preserved unchanged
- **SC-003**: Adding a username via the popup takes under 5 seconds from keypress to the watch list being updated on disk
- **SC-004**: The section is absent (zero rows, no header, no error) when the watch list contains zero usernames
- **SC-005**: `<CR>` on a PR or issue watched-user event opens the reader with correct content in under 2 seconds
