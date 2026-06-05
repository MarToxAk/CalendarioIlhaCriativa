# Pitfalls Research — ActionCable Integration

**Project:** Calendário de Aprovação de Artes  
**Researched:** 2026-06-05  
**Scope:** Adding ActionCable + Turbo Streams real-time to Rails 8.1.3 existing app  
**Confidence:** HIGH (official Rails guides + source code verified)

---

## PostgreSQL Adapter Pitfalls

### Pitfall 1: cable.yml already uses solid_cable in production — adapter choice has real consequences

The existing `config/cable.yml` uses `solid_cable` in production (polling-based, separate `cable`
DB). The milestone constraint says "PostgreSQL adapter (no Redis)." These are distinct choices:

- `solid_cable` — polling at 0.1s intervals, uses a dedicated `cable` DB already declared in
  `database.yml`, zero extra connection model complexity, but introduces polling latency.
- `postgresql` — uses LISTEN/NOTIFY on the primary DB, true push-based, no separate DB needed,
  but requires understanding the connection model (see Pitfall 2).

**Current cable.yml state:**
- `development: adapter: async` — correct, do not change (same-process only; cable comment in
  file explains this correctly)
- `test: adapter: test` — correct, must not change
- `production: adapter: solid_cable` — already wired to a `cable` DB entry in database.yml

If switching to `postgresql` adapter for production, remove the entire solid_cable block and
write:
```yaml
production:
  adapter: postgresql
```
It picks up the primary DB config from `database.yml` automatically. Extra YAML keys cause
silent fallback to async.

---

### Pitfall 2: PostgreSQL adapter creates LISTEN connections outside the AR pool

The PostgreSQL adapter uses two strategies internally:
- **Broadcasts:** `connection_pool.with_connection` — normal AR pool checkout, returns cleanly.
- **Subscriptions (LISTEN/NOTIFY):** `connection_pool.new_connection` — deliberately bypasses
  pool to avoid pinned connections. Each ActionCable worker thread that handles a subscription
  opens a **dedicated, persistent PostgreSQL connection** that does NOT count against `pool:` in
  `database.yml` but DOES consume a PostgreSQL server slot.

With Puma at 3 threads and 30 concurrent WebSocket clients, expect 3–5 persistent extra
connections beyond the normal pool. For a server with `max_connections = 100` (PostgreSQL
default), this is not a crisis at this scale, but must be known.

**Prevention:** Leave pool size at `RAILS_MAX_THREADS` (already in database.yml). Monitor
`SELECT count(*) FROM pg_stat_activity` in production.

---

### Pitfall 3: Pool exhaustion from broadcast + HTTP request contention

Broadcasts inside model callbacks use `with_connection` (pool checkout). If all 5 pool
connections are busy (concurrent HTTP requests mid-query) and a broadcast fires, it blocks until
a connection is free. Under load this manifests as ActionCable worker timeouts in logs.

**Prevention:** The existing `pool: 5` with Puma at 3 threads has 2 headroom connections — just
adequate for light use. If moving to production with higher concurrency, set
`RAILS_MAX_THREADS=5` and ensure pool matches.

---

### Pitfall 4: PostgreSQL NOTIFY has an 8 KB hard payload limit

Rails hashes channel names over 63 bytes (SHA1) automatically — that is handled. But the
**broadcast payload itself** (rendered HTML Turbo Stream) must fit in 8,000 bytes. A broadcast
containing a full calendar row with multiple art chips, Tailwind classes, and inline SVG will
exceed this limit. The failure mode: the broadcast is silently dropped or raises
`PG::InvalidParameterValue` inside the background job.

**Prevention:** Broadcast small, focused partials. A status badge update should broadcast only
the badge HTML, not the entire calendar cell. If a partial regularly exceeds ~4 KB rendered,
split it or broadcast a page refresh signal instead.

---

### Pitfall 5: Development `async` adapter — console broadcasts do not reach the browser

The `async` adapter (current dev config) works only within the same OS process. Running
`ActionCable.server.broadcast(...)` from `bin/rails console` in a terminal does nothing in the
browser — it is a different process. The cable.yml comment in this project already warns about
this correctly.

**Prevention:** Use the web console (`console` in a view), or temporarily switch development to
`postgresql` adapter while testing broadcasts. Never use `solid_cable` or `postgresql` in the
test environment.

---

## Authentication Pitfalls (client without session)

### Pitfall 1: CRITICAL — existing connection.rb rejects all client users

The current `app/channels/application_cable/connection.rb` authenticates only via:
```ruby
Session.find_by(id: cookies.signed[:session_id])
```

Client users have no `Session` record. They authenticate via `session[:client_id]` +
`session[:client_token_version]` set by `ClientController#require_client_auth`. Every client
who opens their calendar page will have their WebSocket upgrade rejected with "An unauthorized
connection attempt was rejected." Turbo Streams real-time will silently not work for clients.

**Required fix — extend connection.rb to dual-path authentication:**

```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_client

    def connect
      set_current_user || set_current_client || reject_unauthorized_connection
    end

    private

    def set_current_user
      if session = Session.find_by(id: cookies.signed[:session_id])
        self.current_user = session.user
      end
    end

    def set_current_client
      client_id      = request.session[:client_id]
      token_version  = request.session[:client_token_version]
      return unless client_id && token_version
      client = Client.find_by(id: client_id)
      return unless client&.active? && client.token_version == token_version
      self.current_client = client
    end
  end
end
```

`identified_by` accepts multiple identifiers. The connection is accepted when any one is non-nil.

---

### Pitfall 2: ActionCable connection.rb does NOT expose bare `session` — use `request.session`

In controllers, `session` is a DSL method. In `ApplicationCable::Connection`, the object is an
`ActionCable::Connection::Base` — there is no `session` method by default. The HTTP session IS
accessible but only via `request.session[:key]`. Using bare `session` raises `NoMethodError` or
returns nil silently.

**Prevention:** Always use `request.session[:client_id]` in connection.rb, never `session[:client_id]`.

---

### Pitfall 3: Passing access_token in the WebSocket URL is a security vulnerability

A tempting shortcut:
```javascript
createConsumer(`/cable?token=${clientToken}`)
```

The `access_token` is the client's only credential — it never expires and gives full calendar
access. WebSocket upgrade URLs appear in: server access logs (plaintext), Nginx/Apache logs,
browser network history, and proxy logs. This permanently compromises the client's calendar if
any log is leaked.

**Prevention:** Do not pass tokens in URLs. Use `request.session` in connection.rb. The client's
session is already established by `ClientController` login — it contains all needed state.

---

### Pitfall 4: Channel subscription must scope the stream to the specific client

Without scoping, all clients share one stream and receive each other's real-time updates:

```ruby
# Wrong — every subscriber receives every broadcast
def subscribed
  stream_from "arts_updates"
end
```

```ruby
# Right — each client only receives their own updates
def subscribed
  stream_from "client_#{current_client.id}_updates"
end

# Or using Turbo helper (generates same scoped name automatically)
def subscribed
  stream_for current_client
end
```

A client from account A receiving account B's approval updates is a data privacy breach.

---

### Pitfall 5: `reject_unauthorized_connection` generates logged errors — expected but noisy

Every WebSocket attempt from an unauthenticated context (pre-login page, bot, wrong origin) logs
an error. In production this creates log noise but is correct behavior. With 30 clients, each
calendar page load before login fires one rejected connection.

**Prevention:** This is expected. Filter at the log aggregator if noisy. Do not suppress the
rejection itself — it is the security mechanism.

---

## Turbo Frames vs Turbo Streams Coexistence

### Pitfall 1: `turbo_stream.replace` targeting a `<turbo-frame>` destroys the frame element

This project has three active Turbo Frames:
- `dashboard-content` (admin/dashboard/index.html.erb)
- `calendar-content` (admin/calendar/index.html.erb)
- `approvals-content` (admin/approvals/index.html.erb)

If a broadcast uses `turbo_stream.replace("approvals-content", ...)`, the `<turbo-frame>` element
itself is replaced with non-frame HTML. Subsequent filter link clicks (which target the frame by
its ID) then trigger full page navigations instead of frame-scoped requests. The page looks fine
visually but Turbo Frame behavior is permanently broken for that page session.

**Prevention:** When targeting an element that IS a `<turbo-frame>`, use `turbo_stream.update`
(replaces inner content, preserves the frame element and its event bindings). Use `replace` only
for elements that are NOT turbo-frame wrappers.

```ruby
# Safe — updates content inside the frame, frame element survives
turbo_stream.update("approvals-content", partial: "admin/approvals/list")

# Dangerous — kills the frame wrapper itself
turbo_stream.replace("approvals-content", partial: "admin/approvals/list")
```

---

### Pitfall 2: Broadcasts and Turbo Frame navigations are independent — do not confuse them

A Turbo Frame link click sends an HTTP request with `Turbo-Frame:` header and expects an HTML
response with a matching frame. ActionCable is a persistent WebSocket — completely separate
infrastructure that does not see or respond to frame navigation.

Wrong mental model: "I'll push a broadcast to update the frame when a filter is applied."
Right mental model: Filter clicks go through HTTP as they do now (unchanged). Broadcasts push
real-time updates that happen independently of user navigation.

**Prevention:** Keep the two systems orthogonal. Filters and pagination stay pure Turbo Frames
over HTTP. Real-time status updates go through cable broadcasts targeting specific record IDs
inside the frame — not the frame itself.

---

### Pitfall 3: DOM target IDs inside a Turbo Frame become stale when the frame navigates

When the `approvals-content` frame loads new content (filter click), all old DOM IDs inside it
are destroyed. If a broadcast fires targeting an ID that was inside the old frame content,
it is silently discarded. If a broadcast fires targeting an ID inside the new frame content
before the frame finishes loading, it is also discarded.

**Prevention:** This is acceptable for this use case. The next frame render shows the current
database state. Design broadcasts to be idempotent: a missed broadcast means the next page
interaction shows the correct state. Do not architect around catching every broadcast.

---

## DOM ID / Broadcast Target Pitfalls

### Pitfall 1: Missing broadcast targets fail completely silently

When a Turbo Stream arrives and the target ID is not in the DOM, Turbo receives the message,
finds no element, and does nothing. No JavaScript error. No server error. The server logs show
the broadcast as successful. This is the leading cause of "real-time isn't working" bugs.

**Debugging procedure:**
1. Open browser DevTools → Network tab → filter by WS
2. Click on the `/cable` connection
3. Watch Messages tab — incoming turbo-stream frames appear here
4. If messages arrive but DOM does not update: target ID mismatch
5. If no messages arrive: channel subscription or broadcast scoping is wrong

---

### Pitfall 2: Calendar cell IDs — day-number-only IDs collide across months

The calendar grid renders 28–31 day cells per month. A naive `id="day-5"` collides across months
if the DOM ever has two calendar months visible, and more critically, when months are compared in
admin calendar (which shows all clients). Month navigation replaces the frame content, so
collisions only matter within one rendered page — but if two calendar grids are ever on the same
page (e.g., a mini-preview), collisions cause the wrong cell to update.

**Prevention:**
- Day cells: `id="cal_<%= date.iso8601 %>"` e.g., `id="cal_2026-06-05"`
- Art chips inside a cell: `id="<%= dom_id(arte) %>"` (e.g., `id="arte_42"`) — Rails `dom_id`
  guarantees globally unique IDs for persisted records
- Status badge inside a chip: `id="status_<%= dom_id(arte) %>"` e.g., `id="status_arte_42"`

---

### Pitfall 3: `dom_id` on unsaved (new) records is not unique

`dom_id(Arte.new)` returns `"new_arte"`. Broadcasting to `"new_arte"` when there are two pending
creation broadcasts means both target the same non-existent element. Only persisted records have
meaningful IDs.

**Prevention:** Only broadcast in `after_create_commit` and `after_update_commit` — by that
point the record has an integer `id` and `dom_id` is globally unique.

---

### Pitfall 4: Partial path convention mismatch raises `MissingTemplate` in broadcast jobs

`Turbo::Broadcastable` uses `to_partial_path` to locate the partial. For an `Arte` model it
expects `app/views/artes/_arte.html.erb`. This project's arte partials live under
`app/views/admin/artes/`. The broadcast job will raise `ActionView::MissingTemplate` silently
(in job logs, invisible to the user).

**Prevention:** Always pass `partial:` explicitly in any broadcast call in this codebase:
```ruby
broadcast_replace_later_to(
  client,
  target:  dom_id(self),
  partial: "admin/artes/arte",
  locals:  { arte: self }
)
```
Do not rely on the convention-based path discovery when partials are namespaced.

---

## Testing Pitfalls (Minitest)

### Pitfall 1: `cable.yml` test env is already correct — do not touch it

`test: adapter: test` is the right configuration. The test adapter is built into Rails since
Rails 6 — no extra gem is needed. It intercepts broadcasts in memory with no async behavior,
making tests deterministic. Do not change to `async` (non-deterministic) or `postgresql`
(requires real DB connection in tests).

---

### Pitfall 2: `assert_broadcast_on` takes the stream name string, not the model

```ruby
# Wrong — this is not the stream name ActionCable uses internally
assert_broadcast_on(Arte, { ... })

# Right for a Turbo stream scoped to a model (matches stream_for(arte))
assert_broadcast_on(
  Turbo::StreamsChannel.broadcasting_for(arte),
  { ... }
)

# Right for a named stream
assert_broadcast_on("admin_updates", { ... })
```

Getting the stream name wrong causes the assertion to always fail or — if checking
`assert_no_broadcasts` — to give a false pass.

**Debug tip:** Call `Turbo::StreamsChannel.broadcasting_for(record)` in a test console to see
the exact string ActionCable uses for that model, then copy it into the assertion.

---

### Pitfall 3: Block form required for `assert_broadcast_on` with model callbacks

```ruby
# Wrong — asserts on broadcasts that happened BEFORE the block, not after
arte.update!(status: :approved)
assert_broadcast_on("admin_updates", { ... })   # always fails

# Right — intercepts broadcasts triggered during block execution
assert_broadcast_on("admin_updates", { ... }) do
  arte.update!(status: :approved)
end
```

---

### Pitfall 4: `broadcast_later` enqueues a job — must flush Active Job queue in tests

Any `_later` broadcast variant (the recommended pattern for model callbacks) enqueues an
`Turbo::Streams::BroadcastJob`. With the default `test` Active Job adapter, jobs are queued but
not executed. `assert_broadcast_on` will not see the broadcast because the job never ran.

**Fix options:**

Option A — flush queue in the test block:
```ruby
assert_broadcast_on("admin_updates", { ... }) do
  perform_enqueued_jobs do
    arte.update!(status: :approved)
  end
end
```

Option B — use inline adapter for the whole test file:
```ruby
setup { ActiveJob::Base.queue_adapter = :inline }
teardown { ActiveJob::Base.queue_adapter = :test }
```

Option C — test the job directly without testing the callback trigger.

---

### Pitfall 5: Channel tests require `ActionCable::Channel::TestCase`

```ruby
# Wrong — no subscription lifecycle, no transmit helpers
class NotificationsChannelTest < ActiveSupport::TestCase; end

# Right
class NotificationsChannelTest < ActionCable::Channel::TestCase; end
```

`ActionCable::Channel::TestCase` provides `subscribe`, `unsubscribe`, and `assert_broadcasts`.
Using the wrong superclass gives no helpful errors — methods simply do not exist or the channel
is never instantiated.

---

## Performance & N+1 Pitfalls

### Pitfall 1: Synchronous broadcast inside a DB transaction holds the connection open

`after_save` and `after_create` run inside the transaction. Broadcasting synchronously there
holds the DB connection occupied during template rendering, increasing lock contention under
concurrent writes. `after_commit` callbacks run outside the transaction but synchronous rendering
still blocks the worker thread.

**Prevention:** Use `_later` variants in all model callbacks:
```ruby
after_create_commit :broadcast_append_later_to_admin
```
Not:
```ruby
after_create_commit :broadcast_append_to_admin   # synchronous render, blocks thread
```
Exception: `broadcast_remove_to` needs no `_later` because it sends only the dom_id — no template render.

---

### Pitfall 2: Broadcast partials cannot access `current_user`, `current_client`, or helpers

Background jobs that render broadcast partials have no request context. These are all
unavailable:
- `current_user` → `NameError`
- `current_client` → `NameError`  
- `session` → `NameError`
- `flash` → `NameError`
- Route helpers requiring a host (e.g., `url_for`) → may raise without `default_url_options`

**When this bites in this project:** Any partial that conditionally renders admin vs client
content by checking `current_user.present?` will raise inside a broadcast job.

**Prevention:** Design broadcast partials to be context-free. Pass everything needed as `locals:`:
```ruby
broadcast_replace_later_to(
  "admin_updates",
  target:  dom_id(self),
  partial: "admin/artes/status_badge",
  locals:  { arte: self, status: self.status }
)
```
Broadcast separate partials to admin and client streams when viewer-specific rendering is needed.

---

### Pitfall 3: N+1 in broadcast partials when accessing associations

A broadcast partial for `ApprovalResponse` that renders `response.arte.client.name` triggers
2 queries per broadcast job if the arte and client were not loaded. With 30 concurrent approvals,
that is 60 extra queries.

**Prevention:** Use `includes` when the job reloads the record, or pass pre-resolved values as locals:
```ruby
after_create_commit do
  arte = Arte.includes(:client).find(self.arte_id)
  broadcast_append_later_to(
    "admin_approvals",
    partial: "admin/approvals/row",
    locals: { approval: self, arte: arte, client: arte.client }
  )
end
```

---

### Pitfall 4: `after_update_commit` fires on EVERY update, not just status changes

```ruby
# Fires on EVERY column write — deadline, notes, media_url, etc.
after_update_commit :broadcast_status_update
```

This floods the cable on unrelated admin edits and may leak data if scoping is wrong.

**Prevention:** Gate broadcasts on the specific change:
```ruby
after_update_commit do
  broadcast_replace_later_to(...) if saved_change_to_status?
end
```
`saved_change_to_attribute?(:column)` is the correct Active Record method. `changed?` does not
work in `after_commit` callbacks — the change tracking has already reset.

---

### Pitfall 5: Memory growth from open WebSocket connections

Each connected client holds an `ApplicationCable::Connection` object and subscription state in
the Ruby heap. With 30 clients all subscribed, this is 30 persistent objects plus subscription
lists. If channels do not clean up on disconnect, memory grows.

**Prevention:** Always implement `unsubscribed`:
```ruby
def unsubscribed
  stop_all_streams
end
```
`stop_all_streams` is called automatically for `stream_from`/`stream_for` channels, but explicit
cleanup is required for any timers or instance variables set in `subscribed`.

---

## Prevention Strategies (Per Pitfall)

| Pitfall | Category | Severity | Prevention |
|---------|----------|----------|------------|
| solid_cable vs postgresql adapter choice | Config | HIGH | Decide adapter before writing channel code; test env must stay `test` |
| LISTEN connections bypass AR pool | Config | LOW | Monitor PG `pg_stat_activity`; adequate for 30 users |
| PG NOTIFY 8 KB payload limit | Config | MEDIUM | Keep broadcast payloads small; partial, not full page sections |
| Pool exhaustion under broadcast+HTTP concurrency | Config | LOW | Existing pool=5, Puma=3 threads has headroom for this scale |
| Dev `async` adapter — console broadcasts invisible | Config | INFO | Use web console or temporarily switch dev to `postgresql` |
| connection.rb rejects client users | Auth | CRITICAL | Dual-path auth: Session-based admin + request.session-based client |
| `session` vs `request.session` in connection.rb | Auth | HIGH | Always use `request.session` in connection.rb |
| access_token in WebSocket URL | Auth | HIGH | Never — use session state established by ClientController |
| Stream not scoped to client | Auth/Privacy | HIGH | Use `stream_for(current_client)` or `"client_#{id}_updates"` |
| `replace` destroys turbo-frame element | Frames/Streams | HIGH | Use `update` when targeting a `<turbo-frame>` wrapper |
| Broadcasts and frame navigations are independent | Frames | MEDIUM | Keep HTTP frame navigation and cable broadcasts orthogonal |
| Stale IDs after frame navigation | Frames | LOW | Idempotent broadcasts — next frame load shows current state |
| Missing broadcast target is completely silent | Streams | HIGH | Verify IDs with DevTools WS → Messages tab |
| Day-number-only calendar IDs collide | DOM IDs | MEDIUM | Use `id="cal_2026-06-05"` format; use `dom_id(arte)` for chips |
| `dom_id` on unsaved records not unique | DOM IDs | MEDIUM | Broadcast only in `after_commit` (persisted records only) |
| Partial path mismatch (namespaced views) | Broadcast | HIGH | Always specify `partial:` explicitly — do not rely on convention |
| Wrong test cable adapter | Testing | HIGH | Already correct; never change `test: adapter: test` |
| Wrong stream name in assertions | Testing | MEDIUM | Use `Turbo::StreamsChannel.broadcasting_for(model)` for exact name |
| `assert_broadcast_on` without block | Testing | HIGH | Always use block form to capture broadcasts triggered by action |
| `broadcast_later` jobs not executed in tests | Testing | HIGH | Wrap with `perform_enqueued_jobs { }` or use inline adapter |
| Wrong test case superclass for channels | Testing | MEDIUM | Use `ActionCable::Channel::TestCase`, not `ActiveSupport::TestCase` |
| Synchronous broadcast inside transaction | Performance | HIGH | Always use `_later` variants in model callbacks |
| `current_user` in broadcast partial | Performance | HIGH | Pass everything as `locals:`; design context-free partials |
| N+1 in broadcast partials | Performance | MEDIUM | Use `includes` in job; pass pre-resolved associations as locals |
| Broadcasts on every `after_update_commit` | Performance | MEDIUM | Gate with `saved_change_to_status?` — use `saved_change_to_attribute?` |
| Memory from open connections | Performance | LOW | Always implement `unsubscribed { stop_all_streams }` |

---

## Sources

- [Action Cable Overview — Ruby on Rails Guides](https://guides.rubyonrails.org/action_cable_overview.html) — HIGH confidence
- [PostgreSQL Adapter source — Rails 8 stable](https://msp-greg.github.io/rails_stable/ActionCable/SubscriptionAdapter/PostgreSQL.html) — HIGH confidence (source code)
- [ActionCable::TestHelper — Edge Rails API](https://edgeapi.rubyonrails.org/classes/ActionCable/TestHelper.html) — HIGH confidence
- [ActionCable can deplete AR connection pool — rails/rails#23778](https://github.com/rails/rails/issues/23778) — HIGH confidence (upstream issue)
- [Turbo::Broadcastable docs — rubydoc.info main](https://rubydoc.info/github/hotwired/turbo-rails/Turbo/Broadcastable) — HIGH confidence (gem docs)
- [Turbo Streams on Rails — David Colby](https://www.colby.so/posts/turbo-streams-on-rails) — MEDIUM confidence (practitioner)
- [Solving Turbo Frame Replacement Issues — DEV Community](https://dev.to/flstudio4/solving-turbo-frame-replacement-issues-in-rails-g9a) — MEDIUM confidence
- [Difference between replace and update — Hotwire Discussion](https://discuss.hotwired.dev/t/difference-between-replace-and-update-turbo-streams/3148) — MEDIUM confidence
- [Connection Management — Stanza](https://www.stanza.dev/courses/rails-action-cable/scaling-action-cable/rails-action-cable-connection-management) — MEDIUM confidence
- [ActionCable memory leak — rails/rails#26119](https://github.com/rails/rails/issues/26119) — HIGH confidence (upstream issue)
- [Decoding Turbo-Stream Errors](https://junkangworld.com/blog/decoding-turbo-stream-errors-my-ultimate-2025-fix-guide) — MEDIUM confidence
