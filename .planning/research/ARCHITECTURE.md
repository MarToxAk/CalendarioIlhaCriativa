# Architecture Research — ActionCable Integration

**Project:** Calendário Livia v1.5 Real-time & Notifications
**Researched:** 2026-06-05
**Based on:** Full codebase audit (Rails 8.1.3, existing channels, models, views, controllers)

---

## Integration Points (new vs modified)

### New Files

| File | Type | Purpose |
|------|------|---------|
| `app/channels/admin_notifications_channel.rb` | New | Broadcasts badge count + toast to admin |
| `app/channels/client_calendar_channel.rb` | New | Broadcasts calendar updates to specific client |
| `app/views/admin/shared/_pending_badge.html.erb` | New | Badge span rendered inside sidebar link |
| `app/views/admin/shared/_toast.html.erb` | New | Auto-dismissing toast container in admin layout |
| `app/views/client/shared/_toast.html.erb` | New | Auto-dismissing toast container in client layout |
| `app/javascript/controllers/toast_controller.js` | New | Stimulus: auto-dismiss + animate-out after N seconds |
| `app/views/admin/calendar/_arte_chip.html.erb` | New | Extracted partial for single chip (currently inline) |
| `app/views/admin/dashboard/_arte_row.html.erb` | New | Turbo-streamable row partial for dashboard table |
| `app/views/client/home/_calendar_day_cell.html.erb` | New | Extracted partial for single day cell (currently inline) |
| `app/views/client/home/_status_summary.html.erb` | New | Extracted partial for status bar (currently inline) |

### Modified Files

| File | Change |
|------|--------|
| `app/channels/application_cable/connection.rb` | Support dual identity: current_user (admin) + current_client (client, via channel params) |
| `app/models/approval_response.rb` | Add `after_create_commit` broadcast to admin |
| `app/models/arte.rb` | Add `after_update_commit` broadcast on status change |
| `app/views/admin/shared/_sidebar.html.erb` | Add `id="sidebar-badge"` wrapper around Aprovações label |
| `app/views/layouts/admin.html.erb` | Add `turbo_stream_from "admin_notifications"` + `id="admin-toast-region"` div |
| `app/views/layouts/client.html.erb` | Add channel subscription tag + `id="client-toast-region"` div |
| `app/views/client/home/_month_calendar.html.erb` | Add `id="day-#{date.iso8601}"` to each cell div |
| `app/views/admin/calendar/_calendar_grid.html.erb` | Add `id="arte-chip-#{arte.id}"` to each chip span |
| `app/views/admin/dashboard/index.html.erb` | Add `id="dashboard-arte-#{arte.id}"` to each row (after extracting partial) |

---

## Channel Structure

### AdminNotificationsChannel

Subscribes to a single global stream. All admin sessions share it — there is only one admin user in this system (single agency, 10–30 clients).

```ruby
# app/channels/admin_notifications_channel.rb
class AdminNotificationsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user.present?
    stream_from "admin_notifications"
  end
end
```

`current_user` is already set by the existing `Connection#connect` via `cookies.signed[:session_id]`. No changes needed to authentication for admin.

Receives:
- `replace` → `"sidebar-badge"` (badge counter)
- `prepend` → `"approvals-content"` tbody (new approval row)
- `prepend` → `"dashboard-content"` (new arte row)
- `append` → `"admin-toast-region"` (toast notification)

### ClientCalendarChannel

Subscribes to a per-client stream keyed by `access_token`. Client identity comes from a token passed in subscription params (not from Connection).

```ruby
# app/channels/client_calendar_channel.rb
class ClientCalendarChannel < ApplicationCable::Channel
  def subscribed
    client = Client.find_by(access_token: params[:token])
    reject and return unless client&.active?
    stream_from "client_calendar_#{client.access_token}"
  end
end
```

Receives:
- `replace` → `"day-#{date.iso8601}"` (calendar cell)
- `replace` → `"status-summary"` (summary bar chips)
- `append` → `"client-toast-region"` (toast when art revised)

---

## Model Callbacks

### ApprovalResponse — after_create_commit

`approval_response.rb` already has `after_create :sync_arte_status` which transitions arte status synchronously. The broadcast must be `after_create_commit` (not `after_create`) so it fires after the transaction commits and the badge count query sees the updated arte status.

```ruby
# Additions to app/models/approval_response.rb
after_create_commit :broadcast_to_admin

private

def broadcast_to_admin
  pending_count = Arte.change_requested.count

  Turbo::StreamsChannel.broadcast_replace_to(
    "admin_notifications",
    target: "sidebar-badge",
    partial: "admin/shared/pending_badge",
    locals: { count: pending_count }
  )

  Turbo::StreamsChannel.broadcast_prepend_to(
    "admin_notifications",
    target: "approvals-content",
    partial: "admin/approvals/approval_row",
    locals: { approval_response: self }
  )

  Turbo::StreamsChannel.broadcast_prepend_to(
    "admin_notifications",
    target: "dashboard-content",
    partial: "admin/dashboard/arte_row",
    locals: { arte: arte }
  )

  Turbo::StreamsChannel.broadcast_append_to(
    "admin_notifications",
    target: "admin-toast-region",
    partial: "admin/shared/toast",
    locals: { message: "#{arte.client.name} respondeu à arte #{arte.title.presence || arte.scheduled_on.strftime('%d/%m')}" }
  )
end
```

**Ordering guarantee:** `after_create` runs inside the transaction; `after_create_commit` runs after it. Both callbacks co-exist without conflict. The Arte status is committed to DB before the broadcast fires, so `Arte.change_requested.count` returns the correct value.

### Arte — after_update_commit

Scoped to status changes only using `saved_change_to_status?` (available after commit, unlike `status_changed?` which is only valid before commit).

```ruby
# Additions to app/models/arte.rb
after_update_commit :broadcast_status_change, if: :saved_change_to_status?

private

def broadcast_status_change
  # Notify the specific client
  Turbo::StreamsChannel.broadcast_replace_to(
    "client_calendar_#{client.access_token}",
    target: "day-#{scheduled_on.iso8601}",
    partial: "client/home/calendar_day_cell",
    locals: {
      date: scheduled_on,
      artes_do_dia: client.artes.where(scheduled_on: scheduled_on).to_a,
      client: client,
      current_month: scheduled_on.beginning_of_month
    }
  )

  Turbo::StreamsChannel.broadcast_replace_to(
    "client_calendar_#{client.access_token}",
    target: "status-summary",
    partial: "client/home/status_summary",
    locals: { client: client, current_month: scheduled_on.beginning_of_month }
  )

  if revised?
    Turbo::StreamsChannel.broadcast_append_to(
      "client_calendar_#{client.access_token}",
      target: "client-toast-region",
      partial: "client/shared/toast",
      locals: { message: "Arte revisada: #{title.presence || scheduled_on.strftime('%d/%m')}" }
    )
  end

  # Update admin calendar chip
  Turbo::StreamsChannel.broadcast_replace_to(
    "admin_notifications",
    target: "arte-chip-#{id}",
    partial: "admin/calendar/arte_chip",
    locals: { arte: self }
  )

  # Badge may decrease (change_requested → revised means one fewer pending)
  Turbo::StreamsChannel.broadcast_replace_to(
    "admin_notifications",
    target: "sidebar-badge",
    partial: "admin/shared/pending_badge",
    locals: { count: Arte.change_requested.count }
  )
end
```

---

## Broadcast Targets (DOM IDs)

All targets must exist in the DOM when the broadcast arrives. Turbo silently discards streams targeting non-existent IDs — this is safe and expected (admin on Dashboard won't have Approvals table in DOM).

| Target ID | In File | Wrapped Element | Stream Action |
|-----------|---------|-----------------|---------------|
| `sidebar-badge` | `_sidebar.html.erb` | `<span id="sidebar-badge">` around badge pill | `replace` |
| `admin-toast-region` | `layouts/admin.html.erb` | `<div id="admin-toast-region">` (empty, toasts appended) | `append` |
| `approvals-content` | `approvals/index.html.erb` | Already exists as `<turbo-frame id="approvals-content">` | `prepend` into tbody |
| `dashboard-content` | `dashboard/index.html.erb` | Already exists as `<turbo-frame id="dashboard-content">` | `prepend` |
| `arte-chip-#{arte.id}` | `calendar/_calendar_grid.html.erb` | `<span id="arte-chip-42">` wrapping the link chip | `replace` |
| `day-#{date.iso8601}` | `client/home/_month_calendar.html.erb` | `<div id="day-2026-06-15">` each cell div | `replace` |
| `status-summary` | `client/home/index.html.erb` | `<div id="status-summary">` around summary bar | `replace` |
| `client-toast-region` | `layouts/client.html.erb` | `<div id="client-toast-region">` (empty, toasts appended) | `append` |

**Naming rule for dates:** Use `date.iso8601` (e.g., `2026-06-15`), not `strftime` with slashes. Slashes break CSS selectors used internally by Turbo when it resolves the target ID.

**Turbo Frame coexistence:** `approvals-content` and `dashboard-content` are existing turbo-frames used for filter navigation. ActionCable `broadcast_prepend_to` targeting these IDs works correctly — Turbo Stream actions operate on the full document DOM, not scoped inside frames. The existing filter mechanism (which replaces the whole frame content) and the live-prepend (which inserts a row) do not conflict.

---

## Authentication in Channels

### Admin channels (no change needed)

`Connection` already sets `current_user` via `cookies.signed[:session_id]` → `Session.find_by`. `AdminNotificationsChannel#subscribed` simply checks `current_user.present?`. This works today without modification.

### Client channels (token-in-params pattern)

The client auth model in `ClientController` uses `session[:client_id]` + `session[:client_token_version]`. ActionCable connections receive cookies, but decrypting the Rails session cookie from inside `Connection` is fragile (depends on session serializer, may change across Rails versions).

**Use token-in-params instead.** The `access_token` is already public (it is the URL slug every client uses to access their calendar). Pass it when creating the subscription:

In `layouts/client.html.erb` (or a client-specific JS file):
```javascript
// Rendered by Rails — @client is always set in client layout
import consumer from "channels/consumer"
consumer.subscriptions.create(
  { channel: "ClientCalendarChannel", token: "<%= @client.access_token %>" },
  { received(data) { /* Turbo handles stream elements automatically */ } }
)
```

`ClientCalendarChannel#subscribed` receives `params[:token]`, validates it, and streams. This is consistent with how the entire client portal works (token in URL = identity).

**Connection adjustment:** The existing `Connection#connect` calls `set_current_user || reject_unauthorized_connection`. Clients connecting to `ClientCalendarChannel` will have `current_user = nil` — the connection would be rejected before the channel can validate the token. Fix: allow the connection through when no admin session is present, and push the auth decision down to the channel level.

```ruby
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # Allow connection for both admin (session cookie) and unauthenticated clients
      # Channels handle their own authorization via params
      set_current_user
      # Do NOT reject here — ClientCalendarChannel authenticates via params[:token]
    end

    private

    def set_current_user
      if (session_record = Session.find_by(id: cookies.signed[:session_id]))
        self.current_user = session_record.user
      end
    end
  end
end
```

This means the WebSocket connection itself is always accepted; channel-level `reject` handles unauthorized subscriptions. This is the standard Rails pattern when mixing authenticated and token-based channels on the same cable server.

**Security posture:** An attacker who knows a client's `access_token` can subscribe to that client's stream. This is the same threat model as the existing HTTP portal — knowing the token is equivalent to having access. No regression.

---

## Suggested Build Order

Dependencies: each step produces DOM IDs and partials that later steps broadcast into.

### Step 1 — Foundation: Cable connectivity

- Verify `ActionCable` is mounted (it is — Rails 8 default in `routes.rb`)
- Verify `turbo.min.js` importmap pin includes the cable consumer (it does)
- Modify `Connection#connect` to remove the hard reject for non-admin connections
- Smoke test: open browser console, confirm WebSocket connects to `/cable` without error

Nothing visible to the user. De-risks the entire feature.

### Step 2 — AdminNotificationsChannel + sidebar badge

- Create `AdminNotificationsChannel`
- Create `_pending_badge.html.erb` partial (a colored pill with count)
- Add `id="sidebar-badge"` wrapper to "Aprovações" nav item in `_sidebar.html.erb`
- Add `<%= turbo_stream_from "admin_notifications" %>` to `layouts/admin.html.erb`
- Add `<div id="admin-toast-region"></div>` to admin layout
- Create `_toast.html.erb` + `toast_controller.js`
- Verify via console: `ActionCable.server.broadcast("admin_notifications", ...)` updates badge live

### Step 3 — ApprovalResponse broadcast (badge + toast)

- Add `after_create_commit :broadcast_to_admin` to `ApprovalResponse`
- Test end-to-end: client submits approval in one tab → admin sidebar badge updates in another tab without reload

### Step 4 — Live rows in Dashboard and Approvals

- Extract `_arte_row.html.erb` partial from `dashboard/index.html.erb` (rows currently inline)
- Add `id="dashboard-arte-#{arte.id}"` to each row TR
- Extend `broadcast_to_admin` to prepend approval row and dashboard arte row
- Test: client submits response → row appears at top of both admin pages in real time

### Step 5 — ClientCalendarChannel + Arte status broadcast

- Create `ClientCalendarChannel`
- Extract `_calendar_day_cell.html.erb` from `_month_calendar.html.erb`
- Extract `_status_summary.html.erb` from `client/home/index.html.erb`
- Add `id="day-#{date.iso8601}"` to each cell div in `_month_calendar.html.erb`
- Add `id="status-summary"` to summary bar wrapper in `index.html.erb`
- Add channel subscription tag + `id="client-toast-region"` to `layouts/client.html.erb`
- Create `_toast.html.erb` for client (can reuse same partial with different path)
- Add `after_update_commit :broadcast_status_change, if: :saved_change_to_status?` to `Arte`
- Test: admin marks arte revised → client calendar cell updates without reload

### Step 6 — Admin calendar chip live updates

- Extract `_arte_chip.html.erb` from `_calendar_grid.html.erb` (currently inline link)
- Add `id="arte-chip-#{arte.id}"` wrapper to each chip in grid
- Extend `Arte#broadcast_status_change` to replace the admin chip
- Test: approval arrives → admin calendar chip reflects new status color/label

---

## Data Flow Diagram (text)

### Flow A — Client submits approval or change request

```
Client browser (POST /client/:token/artes/:id/responses)
  └─ Client::ResponsesController#create
        └─ ApprovalResponse.save (inside transaction)
              ├─ after_create: sync_arte_status
              │     └─ arte.approved! OR arte.change_requested!
              └─ [commit]
                    └─ after_create_commit: broadcast_to_admin
                          ├─ broadcast_replace_to "admin_notifications"
                          │     → target: "sidebar-badge"  (Arte.change_requested.count)
                          ├─ broadcast_prepend_to "admin_notifications"
                          │     → target: "approvals-content"  (_approval_row)
                          ├─ broadcast_prepend_to "admin_notifications"
                          │     → target: "dashboard-content"  (_arte_row)
                          └─ broadcast_append_to "admin_notifications"
                                → target: "admin-toast-region"  (_toast)

ActionCable server → admin WebSocket connection
  Admin browser (any admin page):
    - sidebar badge count updates
    - toast appears and auto-dismisses
    - if on /admin: arte row prepends at top of dashboard table
    - if on /admin/approvals: approval row prepends at top of table
```

### Flow B — Admin marks arte as revised

```
Admin browser (PATCH /admin/artes/:id/mark_revised)
  └─ Admin::ArtesController#mark_revised
        └─ arte.revised!
              └─ [commit]
                    └─ after_update_commit: broadcast_status_change
                          ├─ broadcast_replace_to "client_calendar_#{token}"
                          │     → target: "day-2026-06-15"  (_calendar_day_cell)
                          ├─ broadcast_replace_to "client_calendar_#{token}"
                          │     → target: "status-summary"  (_status_summary)
                          ├─ broadcast_append_to "client_calendar_#{token}"
                          │     → target: "client-toast-region"  (_toast)
                          ├─ broadcast_replace_to "admin_notifications"
                          │     → target: "arte-chip-42"  (_arte_chip)
                          └─ broadcast_replace_to "admin_notifications"
                                → target: "sidebar-badge"  (count decrements)

ActionCable server → two streams
  Client browser (if on /client/:token/home):
    - calendar day cell re-renders (badge color changes)
    - status summary bar recalculates
    - toast: "Arte revisada: [title]"
  Admin browser (if on /admin/calendar):
    - arte chip re-renders with new status
    - sidebar badge decrements
```

---

## Critical Constraints

**Partial extraction is prerequisite to broadcasting.** Turbo Stream broadcasts render partials server-side. Any view that currently renders a repeating unit inline cannot be targeted by a broadcast until that unit is extracted to a named partial. Three extractions are mandatory before any broadcast targeting those elements will work:

1. Dashboard arte rows → `admin/dashboard/_arte_row.html.erb`
2. Client calendar day cell → `client/home/_calendar_day_cell.html.erb`
3. Admin calendar arte chip → `admin/calendar/_arte_chip.html.erb`
4. Client status summary → `client/home/_status_summary.html.erb`

**`after_create_commit` vs `after_create`.** The existing `after_create :sync_arte_status` callback runs inside the open transaction. If the broadcast also ran inside the transaction (via `after_create`), the badge count query would see the pre-commit state. Use `after_create_commit` for all broadcasts.

**`saved_change_to_status?` not `status_changed?`.** `status_changed?` is dirty tracking, only valid before/during the transaction. `saved_change_to_status?` reads `saved_changes` and is correct in `after_update_commit`.

**Broadcast fires in request thread by default.** `Turbo::StreamsChannel.broadcast_*` is synchronous. At 10–30 clients this is fine. If latency is observed, wrap in `after_create_commit { BroadcastApprovalJob.perform_later(id) }`.

**Client session page has no authenticated `@client`.** The subscription JS tag in `layouts/client.html.erb` must only emit when the client is authenticated (`session[:client_id].present?`). Wrap in a conditional or render it only from the home/artes templates via `content_for(:head)`.
