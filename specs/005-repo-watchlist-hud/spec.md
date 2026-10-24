# Feature Specification: Repo Watchlist with Activity HUD

**Feature Branch**: `005-repo-watchlist-hud`
**Created**: 2026-04-10
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Manage the Watchlist (Priority: P1)

The user wants to keep an eye on a handful of GitHub repositories across different organizations. From within Neovim, they need a way to add repos to a personal watchlist and remove them when they're no longer relevant — without leaving the editor.

**Why this priority**: Without a managed watchlist there is nothing to watch. This is the enabling foundation for the entire feature.

**Independent Test**: Add a repo to the watchlist, verify it appears in the list, remove it, verify it is gone. No notifications needed to validate this story.

**Acceptance Scenarios**:

1. **Given** no watchlist exists, **When** the user opens the watchlist manager, **Then** they see an empty list with a prompt to add repos
2. **Given** the watchlist is open, **When** the user types a repo name (e.g. `owner/repo`) and confirms, **Then** the repo is saved to the watchlist and appears in the list immediately
3. **Given** a repo is on the watchlist, **When** the user selects it and removes it, **Then** it disappears from the list and is no longer polled
4. **Given** repos are on the watchlist, **When** Neovim is restarted, **Then** the watchlist is restored exactly as left — no entries lost

---

### User Story 2 — Activity HUD Notifications (Priority: P2)

While the user is coding, the system polls the watched repos in the background. When new activity occurs (push, comment, PR opened/merged, issue opened/closed), a small floating notification appears in the corner of the screen — a "visual ping" — without interrupting the editing workflow.

The notification shows what happened, on which repo, and disappears automatically after a few seconds.

**Why this priority**: This is the core value of the feature — awareness of repo activity without switching context.

**Independent Test**: With at least one repo on the watchlist, trigger a real event on that repo (e.g. push a commit or open an issue from a browser). Within the polling interval the notification must appear in Neovim.

**Acceptance Scenarios**:

1. **Given** a repo is on the watchlist, **When** a new commit is pushed to it, **Then** a floating notification appears showing the repo name and "new push"
2. **Given** a repo is on the watchlist, **When** a new issue is opened, **Then** a notification appears showing the repo name and "new issue"
3. **Given** a repo is on the watchlist, **When** a PR is merged, **Then** a notification appears showing "PR merged"
4. **Given** a repo is on the watchlist, **When** a comment is added to a PR or issue, **Then** a notification appears showing "new comment"
5. **Given** a notification appears, **When** no user action is taken, **Then** it auto-dismisses after ~5 seconds
6. **Given** multiple events fire within seconds of each other, **When** notifications appear, **Then** they stack or queue — none are silently dropped
7. **Given** no new activity since last poll, **When** the poll fires, **Then** no notification appears

---

### User Story 3 — Jump to Activity from Notification (Priority: P3)

When a notification appears, the user can press a key to immediately open the relevant issue, PR, or repo in the GitHub reader — without having to navigate back through the dashboard manually.

**Why this priority**: Closes the loop — the notification is actionable, not just informational.

**Independent Test**: Trigger an event on a watched repo. When the notification appears, press the action key. The GH reader must open showing the relevant item.

**Acceptance Scenarios**:

1. **Given** a notification is visible for a PR event, **When** the user presses the action key (e.g. `<CR>`), **Then** the PR reader opens showing that PR
2. **Given** a notification is visible for an issue event, **When** the user presses the action key, **Then** the issue reader opens
3. **Given** a notification is visible for a push event (no specific issue/PR), **When** the user presses the action key, **Then** the repo is opened in the browser
4. **Given** a notification has auto-dismissed, **When** the user opens the dashboard, **Then** the most recent unread events are visible in a "recent activity" section for that repo

---

### Edge Cases

- What if a watched repo is deleted or made private? It should be silently skipped during polling and a one-time warning shown.
- What if the user is offline or GitHub is unreachable? Polling fails gracefully — no error spam, just silent retry on the next interval.
- What if 10+ events fire simultaneously? Notifications are capped (show at most 3 at once), with a summary ("+ 7 more") if overflowing.
- What if the same event fires on two consecutive polls? Deduplication must prevent the same event from notifying twice.
- What if Neovim is in insert mode when a notification fires? The notification appears but does not disrupt typing — no keymap hijacking.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to add a GitHub repo (by `owner/repo` name) to the watchlist from within Neovim
- **FR-002**: Users MUST be able to remove a repo from the watchlist
- **FR-003**: The watchlist MUST persist across Neovim sessions (survive restarts)
- **FR-004**: The system MUST poll watched repos for new activity at a configurable interval (default: 60 seconds)
- **FR-005**: New activity MUST trigger a floating notification in the editor showing: repo name, event type, and brief description
- **FR-006**: Notifications MUST auto-dismiss after ~5 seconds without user interaction
- **FR-007**: The notification MUST be non-blocking — it must not interrupt typing, commands, or any active mode
- **FR-008**: The system MUST deduplicate events so the same activity never triggers two notifications
- **FR-009**: Users MUST be able to press a key on an active notification to open the related item (PR, issue, or browser for pushes)
- **FR-010**: Polling MUST fail silently on network errors — no repeated error notifications
- **FR-011**: The watchlist manager MUST be accessible via a keyboard shortcut from anywhere in Neovim

### Key Entities

- **Watched Repo**: A GitHub repo on the watchlist — identified by `owner/repo`, with a "last seen event" timestamp used for deduplication
- **Activity Event**: A single GitHub event (push, PR open/merge, issue open/close, comment) on a watched repo — has a type, timestamp, URL, and brief description
- **Notification**: A transient floating display of one Activity Event — appears for ~5 seconds, has an action key to jump to the item

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can add a repo to the watchlist and receive their first notification within 2 polling cycles of a real event occurring
- **SC-002**: Notifications appear without any disruption to active editing — zero keystrokes lost or modes changed due to a notification appearing
- **SC-003**: The watchlist survives a Neovim restart with 100% of entries intact
- **SC-004**: The same GitHub event never generates more than one notification, regardless of how many polls occur after it
- **SC-005**: The user can navigate from a notification to the relevant PR/issue in under 2 keypresses

## Assumptions

- The user is authenticated with the GitHub CLI (`gh auth status` passes) — no separate auth is needed for this feature
- Polling interval is fixed at 60 seconds by default; making it configurable per-repo is out of scope
- The watchlist holds at most ~20 repos — no pagination or search within the watchlist is needed
- Push events show the branch and commit count but do not deep-link to individual commits
- The notification HUD is a new small floating window separate from the dashboard and reader popups — it appears in a corner (top-right) and does not affect existing window layout
