# Stack Research — ActionCable + Turbo Streams (Rails 8.1.3)

**Researched:** 2026-06-05
**Confidence:** HIGH — findings based entirely on gems already installed in vendor/bundle and config files present in the repo.

---

## Already Available (no changes needed)

**ActionCable** is built into Rails. No gem needed. Already available at Rails 8.1.3.

**turbo-rails 2.0.23** is already installed (confirmed in vendor/bundle). It ships `Turbo::StreamsChannel` and the full `Turbo::Broadcastable` concern. Turbo Streams over WebSockets work out of the box — zero additional gems.

**solid_cable 4.0.0** is already in the Gemfile and vendor/bundle. It is the database-backed ActionCable adapter for Rails 8, developed by 37signals alongside Solid Queue and Solid Cache. No Redis needed.

**The `cable.yml` is already fully configured** for production (`adapter: solid_cable`) and development (`adapter: async`). The production config already points to the `cable` database defined in `database.yml` with `polling_interval: 0.1.seconds` and `message_retention: 1.day`.

**`db/cable_schema.rb`** already exists with the `solid_cable_messages` table definition.

**`app/channels/application_cable/connection.rb`** already exists. The Rails generator created it and it already contains admin session auth via `cookies.signed[:session_id]` — exactly matching the app's auth mechanism in the `Authentication` concern.

**`app/javascript/application.js`** already imports `@hotwired/turbo-rails`, which automatically connects ActionCable when a `turbo_stream_from` tag is present on the page. No additional JS import needed.

**`importmap.rb`** already pins `@hotwired/turbo-rails` to `turbo.min.js`.

---

## Config Changes Required

### 1. `cable.yml` — development adapter

The current development adapter is `async`. This works within a single Puma process but broadcasts from model callbacks triggered by HTTP requests are delivered correctly because Puma runs everything in the same process. For this app's development workflow (single `bin/dev` process), `async` is fine.

**Decision: keep `async` for development, no change needed.** Production is already correct with `solid_cable`.

### 2. `routes.rb` — ActionCable mount

Rails mounts ActionCable at `/cable` automatically when the app boots — no manual route needed. The `routes.rb` does not and should not have `mount ActionCable::Server`.

### 3. `cable_schema.rb` migration for production

The `db/cable_schema.rb` exists. On first production deploy, run:

```bash
bin/rails db:create:cable db:schema:load:cable
```

In development with `async` adapter, no cable table is needed.

### 4. Content Security Policy

`config/initializers/content_security_policy.rb` exists. If it restricts `connect-src`, it must allow `ws:` / `wss:` for WebSockets. Add if missing:

```ruby
policy.connect_src :self, :https, "ws://localhost:3000", "wss://yourdomain.com"
```

---

## PostgreSQL Adapter Setup

**solid_cable IS the PostgreSQL adapter** for this app. It uses the `pg` gem (already installed) and polls the `solid_cable_messages` table. No Redis, no `actioncable-postgresql-adapter` gem, no external dependency.

How it works:
- Broadcasts write a row to `solid_cable_messages`
- The `SolidCable::Listener` thread polls the table every `polling_interval` (0.1s in production)
- Messages are delivered to subscribers and trimmed after `message_retention` (1 day)
- At this app's scale (10–30 clients, 1 admin), polling at 0.1s on PostgreSQL is entirely adequate

**No changes needed to the adapter setup** — already wired correctly in `cable.yml` and `database.yml`.

---

## Authentication in Channels

### Admin connection — already coded correctly

`app/channels/application_cable/connection.rb` already handles admin auth:

```ruby
def set_current_user
  if session = Session.find_by(id: cookies.signed[:session_id])
    self.current_user = session.user
  end
end
```

This matches exactly how `Authentication` concern works in controllers (`find_session_by_cookie`). Admin channels use `current_user` as the identifier — if nil, `reject_unauthorized_connection` fires.

**No changes needed for admin channel auth.**

### Client connection — two options

The client portal authenticates via a `token` in the URL path (`/c/:token`) plus a simple password. There is no `session_id` cookie for clients. The current `Connection` class only handles the admin case and calls `reject_unauthorized_connection` for clients.

**Option A — Signed stream names via Turbo::StreamsChannel (recommended for client streams)**

`Turbo::StreamsChannel` verifies a signed stream name in the subscription params — it does not rely on `Connection#connect` auth at all. When views use `turbo_stream_from @client`, the helper generates an HMAC-signed stream name using `Rails.application.message_verifier`. The channel verifies the signature on subscribe and rejects if invalid.

This means: admin pages guard with `current_user` in the channel; client pages use signed stream names from `turbo_stream_from @client` — the signed name is the auth token. No connection-level client auth needed for Turbo Stream subscriptions.

**Option B — Second identifier for client in Connection (needed only for custom channels)**

If custom client-side channels are created (not `Turbo::StreamsChannel`), add a second identifier:

```ruby
identified_by :current_user, :current_client

def connect
  set_current_user || set_current_client || reject_unauthorized_connection
end

def set_current_client
  # Client auth cookie set after portal login
  token = cookies.signed[:client_token]
  self.current_client = Client.active.find_by(token: token) if token
end
```

**Recommendation: Use Option A (signed stream names) for all client-facing Turbo Streams. Use Option B only if custom client channels are added beyond Turbo::StreamsChannel.**

---

## Versions & Compatibility

| Component | Version | Status |
|-----------|---------|--------|
| Rails / ActionCable | 8.1.3 | Built-in, no gem needed |
| turbo-rails | 2.0.23 | Already installed — supports Turbo Streams over WS |
| solid_cable | 4.0.0 | Already installed — DB-backed adapter, no Redis |
| stimulus-rails | (installed) | Already wired — Stimulus controllers for toast work normally |
| importmap-rails | (installed) | turbo-rails already pinned |
| pg | ~1.1 | Already installed — solid_cable uses it |
| good_job | ~4.0 | Already installed — `broadcast_later` jobs enqueue here |

**`broadcast_later` methods in `Turbo::Broadcastable` enqueue ActiveJob jobs.** The app already has `good_job` as the ActiveJob backend. Confirm `config.active_job.queue_adapter = :good_job` is set in `application.rb` or `production.rb` — if missing, broadcasts will use the default inline adapter and may block requests.

---

## What NOT to Add

- **Redis** — solid_cable replaces it entirely
- **`actioncable-postgresql-adapter` gem** — an older community gem; solid_cable is the Rails-official successor
- **Anycable or separate cable server** — overkill for 10–30 clients; solid_cable polling is sufficient
- **`hotwire-rails` gem** — project already uses `turbo-rails` + `stimulus-rails` directly; do not add
- **Separate `@hotwired/turbo` JS import** — already covered by `@hotwired/turbo-rails` in application.js
- **Any turbo-rails version upgrade** — 2.0.23 is current enough; do not bump without reason

---

## Summary: What Actually Needs to Happen

| Task | Effort | Notes |
|------|--------|-------|
| Add `turbo_stream_from` tags to admin views | Low | Helper available from turbo-rails already |
| Add `after_create_commit :broadcast_later_to` in `ApprovalResponse` | Low | `Turbo::Broadcastable` already available |
| Create Stimulus controller for toast notifications | Low | Standard Stimulus, no new libs |
| Check/update CSP for ws:/wss: | Low | Check `content_security_policy.rb` |
| Confirm `good_job` as queue adapter | Low | Check `application.rb` or env configs |
| Run `db:schema:load:cable` on production deploy | One-time | `cable_schema.rb` already exists |
| Update `Connection` for client token (if custom client channels) | Medium | Only needed if going beyond `Turbo::StreamsChannel` |

**No new gems. No new infrastructure. Everything needed is already installed.**
