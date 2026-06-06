# Features Research — Real-time UX Patterns

**Project:** Calendário Livia — v1.5 Real-time & Notifications
**Researched:** 2026-06-05
**Stack context:** Rails 8.1.3, Turbo (turbo-rails), Stimulus, ActionCable, Tailwind v4, PostgreSQL

---

## Table Stakes (must have)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Turbo Stream subscription tag in each view | Without `turbo_stream_from`, no cable updates reach that page | Low | One line per view that needs live updates |
| Broadcast from model callback (`after_create_commit`) | Standard Rails pattern — controller should not manually broadcast in most cases | Low | Use `_later` variants to offload to ActiveJob |
| Scoped streams (admin vs client) | Admin sees all; client sees only their own — must be enforced server-side | Medium | Two separate stream names per broadcast |
| Toast that auto-dismisses | Users expect transient feedback, not a permanent banner | Low-Med | CSS transition + Stimulus timeout |
| Badge counter on sidebar | Admin needs to know pending items without opening Aprovações | Low | Turbo Stream `replace` on a dedicated DOM element |
| Calendar cell partial replace | Chips must update without morphing the entire grid | Medium | Requires stable DOM IDs per day cell |

---

## Implementation Patterns

### Turbo Streams over Cable

**How it works (HIGH confidence — verified via Context7/turbo-rails official docs):**

1. The view subscribes with the `turbo_stream_from` helper, which renders a `<turbo-cable-stream-source>` custom element. The stream name is signed (HMAC) by the Rails helper — clients cannot forge subscriptions.
2. The server broadcasts using `Turbo::StreamsChannel.broadcast_*_to(streamable, ...)` or model-level `broadcasts_to`.
3. The browser receives a `<turbo-stream action="..." target="...">` fragment over the cable socket and applies it to the DOM immediately.

**The eight available actions:** `append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`, `refresh`.

**From model (recommended for this project):**

```ruby
# app/models/approval_response.rb
after_create_commit :broadcast_to_admin

private

def broadcast_to_admin
  # Broadcasts to ALL admins watching "admin_approvals" stream
  broadcast_append_later_to "admin_approvals",
    target: "approvals_list",
    partial: "admin/approvals/approval_row",
    locals: { approval: self }

  # Also update badge counter on same stream
  broadcast_replace_later_to "admin_approvals",
    target: "pending_badge",
    partial: "admin/shared/pending_badge"
end
```

**From controller (for one-off cases like "marcar revisada"):**

```ruby
# app/controllers/admin/artes_controller.rb
def mark_revised
  @arte.update!(status: :revised)

  # Notify the specific client watching their calendar
  Turbo::StreamsChannel.broadcast_replace_to(
    "client_#{@arte.client.token}",
    target: "day_cell_#{@arte.scheduled_on.strftime('%Y-%m-%d')}",
    partial: "client/calendar/day_cell",
    locals: { date: @arte.scheduled_on, artes: @arte.client.artes.on_date(@arte.scheduled_on) }
  )

  # Notify all admins watching the admin calendar
  Turbo::StreamsChannel.broadcast_replace_to(
    "admin_calendar",
    target: "day_cell_#{@arte.scheduled_on.strftime('%Y-%m-%d')}",
    partial: "admin/calendar/day_cell",
    locals: { date: @arte.scheduled_on, artes: Arte.on_date(@arte.scheduled_on) }
  )
end
```

**View subscription (one tag per stream the view needs):**

```erb
<%# Admin layout — outside any Turbo Frame %>
<%= turbo_stream_from "admin_approvals" %>
<%= turbo_stream_from "admin_calendar" %>

<%# Client calendar view %>
<%= turbo_stream_from "client_#{@client.token}" %>
```

**CRITICAL: use `_later_` variants in model callbacks.** Synchronous `broadcast_*_to` inside a DB transaction can deadlock — the cable push happens before the commit is flushed. Use `broadcast_append_later_to` / `broadcast_replace_later_to` — these enqueue an ActiveJob that runs after commit. When broadcasting from a controller action (outside a transaction), synchronous variants are fine.

---

### Toast System

**Recommended pattern: Turbo Stream `append` to a dedicated container + Stimulus auto-dismiss controller.**

The server broadcasts a toast fragment onto the same stream already open for other updates — no extra WebSocket subscription needed.

```erb
<%# app/views/layouts/admin.html.erb — in <body>, outside Turbo Frames %>
<div id="toast_container"
     class="fixed top-4 right-4 z-50 flex flex-col gap-2 pointer-events-none">
</div>
```

```ruby
# Alongside every approval broadcast, append a toast on the same stream
Turbo::StreamsChannel.broadcast_append_to(
  "admin_approvals",
  target: "toast_container",
  partial: "admin/shared/toast",
  locals: { message: "#{response.client.name} respondeu a uma arte", type: :info }
)
```

```erb
<%# app/views/admin/shared/_toast.html.erb %>
<div id="toast_<%= SecureRandom.hex(4) %>"
     data-controller="toast"
     data-toast-duration-value="4000"
     class="pointer-events-auto bg-white border border-gray-200 shadow-lg rounded-lg
            px-4 py-3 flex items-center gap-3 transition-all duration-300">
  <%= message %>
  <% if defined?(link_path) && link_path %>
    <%= link_to "Ver arte", link_path, class: "text-green-600 font-medium text-sm" %>
  <% end %>
</div>
```

```javascript
// app/javascript/controllers/toast_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  connect() {
    setTimeout(() => this.dismiss(), this.durationValue)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "translate-x-full")
    setTimeout(() => this.element.remove(), 300) // wait for CSS transition
  }
}
```

**Why not a Stimulus controller that listens to cable events:** ActionCable does not emit DOM events that Stimulus can intercept natively. You would need to create a custom channel JS class and wire up event listeners — more complexity for zero gain. Turbo Stream append to a container is idiomatic and needs only the auto-dismiss controller shown above.

---

### Badge Counter

**Pattern: dedicated partial with a stable DOM ID, replaced by broadcast.**

```erb
<%# app/views/admin/shared/_pending_badge.html.erb %>
<% count = Art.where(status: :requested_change).count %>
<span id="pending_badge"
      class="<%= count > 0 ? 'inline-flex bg-red-500 text-white' : 'hidden' %>
             items-center justify-center w-5 h-5 text-xs font-bold rounded-full">
  <%= count %>
</span>
```

```ruby
# Called after any approval_response create or arte revised update
Turbo::StreamsChannel.broadcast_replace_to(
  "admin_approvals",
  target: "pending_badge",
  partial: "admin/shared/pending_badge"
  # no locals — partial queries DB directly for accuracy
)
```

**Key points:**
- The partial re-queries the DB so the count is always accurate, not computed incrementally. This avoids race conditions when multiple clients respond simultaneously.
- Use `replace` (swaps the entire element including root tag) rather than `update` (replaces only innerHTML) — safer when the CSS classes on the root span vary with count.
- The badge must live in the layout (outside any Turbo Frame) so it persists across Turbo Frame navigations.
- `turbo_stream_from "admin_approvals"` in the layout means the badge updates on every page in the admin, not only on the Aprovações page.

---

### Calendar Cell Updates

**Pattern: stable DOM ID per day cell, broadcast `replace` targeting that ID.**

The calendar grid renders each cell as a partial with a predictable, date-keyed ID:

```erb
<%# app/views/admin/calendar/_day_cell.html.erb %>
<td id="day_cell_<%= date.strftime('%Y-%m-%d') %>"
    data-date="<%= date %>">
  <%# chips for each arte on that day %>
</td>
```

```erb
<%# app/views/client/calendar/_day_cell.html.erb %>
<td id="day_cell_<%= date.strftime('%Y-%m-%d') %>"
    data-date="<%= date %>">
  <%# arte cards with status badges %>
</td>
```

Broadcast when arte status changes:

```ruby
Turbo::StreamsChannel.broadcast_replace_to(
  "admin_calendar",
  target: "day_cell_#{arte.scheduled_on.strftime('%Y-%m-%d')}",
  partial: "admin/calendar/day_cell",
  locals: { date: arte.scheduled_on, artes: Arte.where(scheduled_on: arte.scheduled_on).includes(:client) }
)
```

**CRITICAL constraint for this project:** The admin calendar is rendered inside a Turbo Frame for month navigation. The `turbo_stream_from` tag must live in the layout (outside the frame) — not inside the frame. When the user navigates to the next month, the frame content is replaced; if the subscription tag was inside the frame, the cable subscription would be destroyed.

```erb
<%# app/views/layouts/admin.html.erb — OUTSIDE any turbo_frame_tag %>
<%= turbo_stream_from "admin_calendar" %>
```

The broadcast targets individual `day_cell_YYYY-MM-DD` elements. If the current view is showing a different month, the target element does not exist in the DOM — Turbo silently ignores the broadcast. No special handling needed.

---

### Broadcast Scoping (admin vs client)

**Two stream name conventions. Keep them simple.**

| Audience | Stream name | Subscription location |
|----------|-------------|-----------------------|
| All admins | `"admin_approvals"` | Admin layout (persistent) |
| All admins | `"admin_calendar"` | Admin layout (persistent) |
| Specific client | `"client_#{client.token}"` | Client calendar view only |

**Why `client.token` not `client.id`:** The token is the client's existing authentication credential (already used as URL slug). Using the database ID would expose an enumerable integer — a malicious user could craft `turbo_stream_from "client_1"`, `"client_2"`, etc. The token is a random secret the client must know to even reach the page.

**Signing:** `turbo_stream_from` signs stream names with `Rails.application.message_verifier`. The signed name is embedded in the `<turbo-cable-stream-source>` element. A browser cannot subscribe to a stream name it did not receive from server-rendered HTML. This protection is built in — no extra work required.

**Per-admin streams (not needed for v1.5):** If a future version has multiple admins with role-specific visibility, use `"admin_#{admin.id}"` per admin. One admin session, one subscription.

---

## Differentiators

| Feature | Value | Complexity | Recommendation |
|---------|-------|------------|---------------|
| Toast with "Ver arte" action button | Lets admin jump directly to the arte that changed | Low | Include — add `link_path` local to the toast partial |
| Badge count from DB query (not incremental) | Accurate under concurrent responses; survives partial failures | Trivial | Include by default (see pattern above) |
| Connection status indicator in admin header | Shows cable disconnected state so admin knows updates may be missed | Low | Worth adding — listen to `turbo:connected`/`turbo:disconnected` events on `document` |
| Toast on client calendar when arte is revisada | Client sees immediate feedback without reloading | Low | Include — broadcast to `"client_#{client.token}"` stream |

---

## Anti-features (don't build)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Custom ActionCable channel class in JS | `Turbo::StreamsChannel` handles everything; custom channels add JS complexity with no gain for this use case | Use `turbo_stream_from` + `broadcast_*_to` exclusively |
| Polling fallback | Single-admin local deploy — polling wastes resources and adds code paths to maintain | ActionCable with adapter `async` (dev) or `redis` (prod) is sufficient |
| Client-side event bus (custom JS pubsub) | Turbo Streams already handles DOM targeting; a JS event bus duplicates this layer | Let Turbo apply DOM changes; use Stimulus only for dismiss/animation |
| Broadcasting full page HTML or full calendar grid | Replaces too much DOM, loses scroll position and user focus | Always broadcast the smallest possible partial — one row, one cell, one badge |
| Synchronous broadcasts inside model callbacks | Fires before DB commit, causing the ActiveJob or cable push to read an uncommitted row (deadlock or stale data) | Always use `broadcast_*_later_to` in `after_create_commit` / `after_update_commit` callbacks |
| Separate WebSocket channel per client stream | `Turbo::StreamsChannel` is multiplexed — all streams share one WS connection per browser tab | No extra ActionCable channel classes needed |
| Optimistic UI (approve instantly, revert on error) | Adds JS state management complexity; at 10-30 clients the round trip is imperceptible | Server-authoritative updates via Turbo Stream are fast enough |

---

## Confidence Assessment

| Area | Confidence | Source |
|------|------------|--------|
| `turbo_stream_from` / `broadcast_*_to` API | HIGH | Context7 / turbo-rails official docs |
| `_later_` variants to avoid commit-timing deadlock | HIGH | Context7 / turbo-rails official docs |
| Stimulus `connect` lifecycle + `dispatch` | HIGH | Context7 / stimulus official docs |
| Toast via Turbo Stream append | HIGH | Established Hotwire community pattern, consistent with official docs |
| Stream name signing (HMAC, built in) | HIGH | turbo-rails source — built into `turbo_stream_from` helper |
| Badge counter via `broadcast_replace_to` + DB query partial | HIGH | Direct application of documented broadcast API |
| `turbo_stream_from` must be outside Turbo Frame | HIGH | Turbo architecture constraint — frame navigation destroys child elements |
| `client.token` for stream name scoping | MEDIUM | Security reasoning sound; not explicitly documented as recommended pattern, but consistent with signed-stream design |
