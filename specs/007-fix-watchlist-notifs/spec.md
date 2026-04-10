# Feature Specification: Fix Watchlist Notifications

**Feature Branch**: `007-fix-watchlist-notifs`
**Created**: 2026-04-10
**Status**: Draft
**Input**: User description: "refine the watchlist/notifications to be more usefull. also the time is off, it always says 2h ago if its just now, and it never finds any recent notifcations eventhough i saw the popup"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fix timestamp display (Priority: P1)

All "age" labels in the dashboard and notification HUD are off by a fixed offset (reported as 2h). An event that just happened shows as "2h ago". This makes it impossible to gauge how recent activity is.

**Why this priority**: Incorrect timestamps are a correctness bug that undermines trust in the entire dashboard. Every time-labelled item is wrong.

**Independent Test**: Trigger a real GitHub event (e.g., push a commit). Within one poll cycle the notification appears. The age shown on the notification and in the dashboard activity feed should read "0m ago" or "1m ago", not "2h ago".

**Acceptance Scenarios**:

1. **Given** an event happened 3 minutes ago, **When** it is displayed in the dashboard activity feed or notification HUD, **Then** it shows "3m ago" (± 1 minute)
2. **Given** an event happened 1 day ago, **When** displayed, **Then** it shows "1d ago"
3. **Given** the user is in a non-UTC timezone (e.g. UTC+2), **When** timestamps are displayed, **Then** they are still correct relative to the current local time

---

### User Story 2 - Jump to recent event after notification auto-dismisses (Priority: P2)

The notification popup auto-dismisses after 5 seconds. After that, pressing `<leader>gn` says "No recent notifications" even though an event was just displayed. The user saw the popup but didn't have time to act on it.

**Why this priority**: This makes `<leader>gn` essentially useless unless the user acts within 5 seconds. The feature is broken for its intended purpose.

**Independent Test**: Trigger a real event. Wait for the notification popup to appear and auto-dismiss. Then press `<leader>gn` — the GH reader (or browser) opens for that event. The system should remember at least the last 20 events regardless of whether their popups are still visible.

**Acceptance Scenarios**:

1. **Given** a notification popup appeared and auto-dismissed, **When** the user presses `<leader>gn`, **Then** the most recent event opens in the reader or browser (same as if the popup had still been visible)
2. **Given** multiple events occurred across multiple poll cycles, **When** the user presses `<leader>gn`, **Then** the most recent event is opened
3. **Given** no events have been received since Neovim started, **When** the user presses `<leader>gn`, **Then** "No recent notifications" is shown (existing behavior, still correct)

---

### User Story 3 - View notification history (Priority: P3)

The user wants to see a list of recent events across all watched repos, not just act on the latest one. Currently there is no way to browse what happened recently without opening GitHub in a browser.

**Why this priority**: Nice-to-have quality-of-life improvement. Builds on the history introduced in US2.

**Independent Test**: Press `<leader>gn` when there are no live notification popups — instead of "No recent notifications", a history popup opens listing recent events with repo name, event type, and age. Pressing `<CR>` on a row opens the event in the reader or browser.

**Acceptance Scenarios**:

1. **Given** recent events exist in history but no live popups are visible, **When** the user presses `<leader>gn`, **Then** a popup listing the last N events opens (repo · event type · age)
2. **Given** the history popup is open, **When** the user presses `<CR>` on a row, **Then** the event opens in the GH reader (for PRs/issues) or browser (for pushes)
3. **Given** the history popup is open, **When** the user presses `q` or `<Esc>`, **Then** the popup closes
4. **Given** a live notification popup exists, **When** the user presses `<leader>gn`, **Then** the existing behavior is preserved (dismiss popup + open event directly)

---

### Edge Cases

- Neovim just started and no events have been polled yet — `<leader>gn` shows "No recent notifications"
- History is cleared on Neovim restart (in-memory only, not persisted to disk)
- An event in history whose PR/issue was deleted — opening it may show a 404 in the reader; this is acceptable
- Multiple events from the same repo in quick succession — all are stored individually in history

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: All age labels (in dashboard activity feed, dashboard repo list, PR/issue lists, and notification HUD) MUST reflect the correct elapsed time relative to the current moment, regardless of the user's local timezone
- **FR-002**: The system MUST maintain an in-memory history of the last 20 received events across all watched repos, independent of whether their notification popups are still visible
- **FR-003**: `<leader>gn` MUST open the most recent event from history even if its notification popup has already auto-dismissed
- **FR-004**: When no live popups are visible but history exists, `<leader>gn` MUST open a history popup listing recent events
- **FR-005**: The history popup MUST show repo name, event type, and age for each entry
- **FR-006**: Pressing `<CR>` in the history popup MUST open that event in the GH reader (PR/issue) or browser (push/other)
- **FR-007**: History MUST NOT be persisted to disk — it is ephemeral and resets on Neovim restart

### Key Entities

- **Event history entry**: A record of a received event — repo name, event type, payload reference, and received timestamp; stored in memory only
- **Notification history popup**: A floating window listing recent event history entries, interactive with `<CR>` to open

## Assumptions

- The timezone offset bug affects both the dashboard (`age_string` function) and the watchlist module's `event_label`; both should be fixed together
- History capacity of 20 entries is sufficient — older entries are silently evicted
- The history popup reuses the same visual style as the watchlist manager popup (rounded border, `GhWatch*` highlights)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Age labels are accurate within ±1 minute for events that occurred in the last hour, regardless of timezone
- **SC-002**: `<leader>gn` successfully opens an event at least 30 seconds after its notification popup auto-dismissed
- **SC-003**: History popup lists at least the last 5 events when accessed after all popups have dismissed
- **SC-004**: All three bugs reported by the user ("2h ago", "no recent notifications") produce correct output after the fix
