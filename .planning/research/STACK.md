# Stack Research — WhatsApp Auto-Post via Evolution API (v1.7)

**Domain:** Rails 8 app integrating a self-hosted WhatsApp HTTP API (Evolution API) + scheduled fan-out sends + S3 media
**Researched:** 2026-08-29
**Confidence:** HIGH — every version and API-shape claim below was verified against a primary source (rubygems.org API, the Evolution API upstream source on `main`, Docker Hub tag API, or the gem source installed in this repo's `vendor/bundle`). Sources are named inline. The one MEDIUM item is the Faraday-vs-Net::HTTP judgement call, which is a design opinion, not a fact.

**Bottom line:** this milestone needs **exactly 2 new production gems** — `faraday` and `aws-sdk-s3` — plus **1 gem removal** (`good_job`). Everything else (scheduling, QR rendering, encryption, JSON) is already in Rails 8.1.3 / solid_queue and needs zero additions.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Evolution API** (server, not a gem) | pin `evoapicloud/evolution-api:v2.3.7` | Self-hosted WhatsApp HTTP gateway at `whatsapp.bomcustoilhabela.com.br` | v2 is the live line; v1 is EOL. See "Evolution API" section below for the version evidence and the exact auth/route shape. |
| **faraday** | `2.14.3` | HTTP client for `Evolution::Client` PORO | Only new HTTP dependency. Gives connection-level defaults (base_url, `apikey` header, JSON encode/decode, open/read/write timeouts) and the built-in `Faraday::Adapter::Test` so Evolution can be stubbed in tests with **no WebMock gem**. Deps are only `faraday-net_http`, `json`, `logger`. Version from `rubygems.org/api/v1/gems/faraday.json`. |
| **aws-sdk-s3** | `1.229.0` (`~> 1.229`, `require: false`) | ActiveStorage S3 service for production | Mandatory for INFRA-01. Rails 8.1.3 itself declares `gem "aws-sdk-s3", "~> 1.48"` at `activestorage-8.1.3/lib/active_storage/service/s3_service.rb:3`, so 1.229.0 satisfies it. Version from rubygems.org API. |
| **solid_queue** | `1.4.0` installed (`1.7.0` latest) — **already present, already wired** | Durable scheduled sends | Verified as the only wired adapter: `config/environments/production.rb:53`. `enqueue_at` is implemented, so `set(wait_until:)` works. See "Scheduling" below. |
| **ActiveRecord::Encryption** | built into Rails 8.1.3 — **zero gems** | Encrypt each client's Evolution instance token at rest | `activerecord-8.1.3/lib/active_record/encryption/` present; `bin/rails db:encryption:init` confirmed available in this app. |
| **ActiveStorage** | 8.1.3 — already present | Media source for `sendMedia` | `blob.url(expires_in:)` returns a direct presigned S3 URL the Evolution host can fetch. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `faraday-retry` | `2.4.0` | In-request retry with backoff/jitter | **Do NOT add up front.** See "HTTP Client" §Retry — ActiveJob `retry_on` is the correct retry layer here. Add only if UAT proves the Evolution host flaps *mid-request* (transient `Errno::ECONNRESET` on an otherwise-healthy call). |
| `active_storage_validations` | already in Gemfile | Enforce max byte size / content-type on `Arte` media | Needed regardless: an oversized video will be accepted by ActiveStorage and then silently rejected by WhatsApp at send time. Validate at upload, not at send. |
| `mission_control-jobs` | `1.2.0` | Web UI for solid_queue (see scheduled jobs, retry a failed send) | **Optional, defer to a later phase.** It is a real quality-of-life win for debugging "why didn't group 7 get the post" but it is a mountable engine that needs its own auth wiring. Not required for v1.7. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `bin/jobs` | Runs the solid_queue supervisor | Already exists in `bin/`. Must actually be running for any scheduled send to fire. |
| `Faraday::Adapter::Test` | Stub Evolution responses in tests | Ships inside faraday — no WebMock, no VCR, no extra gem, no cassette files. |
| `dotenv-rails 3.2.0` | dev/test env vars | Already present, **development/test only** (`Gemfile:55`). Keep it that way — see "Secrets". |

## Installation

```ruby
# Gemfile — ADD
gem "faraday", "~> 2.14"                       # Evolution API HTTP client
gem "aws-sdk-s3", "~> 1.229", require: false   # Active Storage S3 (INFRA-01)

# Gemfile — REMOVE (line 35)
# gem "good_job", "~> 4.0"
```

```bash
bundle install

# One-time: generate Active Record encryption keys into credentials
bin/rails db:encryption:init
# then paste the emitted active_record_encryption block into:
bin/rails credentials:edit
```

Net gem delta: **+3 installed** (`faraday`, `faraday-net_http`, `aws-sdk-s3` and its `aws-sdk-core`/`aws-sigv4`/`aws-partitions` chain), **-2 installed** (`good_job`, `fugit`).

---

## 1. HTTP Client — Faraday 2.14.3

**Recommendation: `gem "faraday", "~> 2.14"`. Do not add `faraday-retry`. Do not add HTTParty, http.rb, httpx, rest-client, or typhoeus.**

**Verified versions** (rubygems.org `/api/v1/versions/<gem>/latest.json`, queried 2026-08-29):

| Gem | Latest | Verdict |
|-----|--------|---------|
| `faraday` | **2.14.3** | ✅ recommended |
| `faraday-retry` | 2.4.0 | ⛔ not now — wrong retry layer (below) |
| `faraday-net_http` | 3.4.4 | transitive dep of faraday, no action |
| `httpx` | 1.8.3 | ⛔ |
| `http` (http.rb) | 6.0.4 | ⛔ |
| `typhoeus` | 1.6.0 | ⛔ (needs libcurl at the OS level) |
| `rest-client` | 2.1.0 | ⛔ effectively unmaintained since 2019 |

### Why Faraday and not zero gems

The "add nothing, use `Net::HTTP`" option is genuinely on the table and I considered it seriously — this project's DNA is lean (Rails-native auth instead of Devise, solid_cable instead of Redis, POROs instead of a service-object gem), and the Evolution surface is small: roughly 7 endpoints (`instance/create`, `instance/connect`, `instance/connectionState`, `instance/delete`, `group/fetchAllGroups`, `message/sendMedia`, `message/sendText`).

Faraday wins on two concrete, non-negotiable points:

1. **Test stubbing without a second gem.** This repo has no WebMock and no VCR. With `Net::HTTP` you cannot unit-test `Evolution::Client` without either hitting the real WhatsApp gateway (which would send real messages to real groups) or adding WebMock. Faraday ships `Faraday::Adapter::Test`, so `Evolution::ClientTest` becomes a pure in-process test. Choosing `Net::HTTP` doesn't save you a gem — it trades `faraday` for `webmock` and adds ~80 lines of hand-rolled client code.
2. **Connection-level defaults in one place.** `base_url`, the `apikey` header, JSON request/response encoding, and separate `open_timeout`/`read_timeout`/`write_timeout` are all configured once on the `Faraday::Connection`. With `Net::HTTP` each of those is re-specified per call site, and a forgotten `read_timeout` on the send path is exactly the bug that hangs a solid_queue worker thread forever.

Community consensus and download volume agree (1.24 billion downloads; Faraday is the standard answer for Rails service objects) — but that is the weakest of the three arguments, and it's the reason this specific item is MEDIUM rather than HIGH.

### Timeout configuration (mandatory)

Evolution is a self-hosted Node service that proxies a live WhatsApp socket. It hangs. Every call must be bounded:

```ruby
# app/services/evolution/client.rb
def connection
  @connection ||= Faraday.new(url: Evolution.base_url) do |f|
    f.request  :json
    f.response :json, content_type: /\bjson$/
    f.headers["apikey"] = @api_key      # NOT Authorization: Bearer — see §2
    f.options.open_timeout  = 5         # TCP connect
    f.options.write_timeout = 10        # request body flush
    f.options.read_timeout  = 30        # sendMedia is slow: Evolution downloads
                                        # the S3 file before it can reply
    f.adapter Faraday.default_adapter
  end
end
```

`read_timeout: 30` is deliberately generous on the send path because Evolution fetches the media URL server-side *before* responding. A 16 MB video over the Evolution host's uplink can take 10–20 s. Consider a shorter (`10 s`) read timeout on the read-only calls (`connectionState`, `fetchAllGroups`) via a per-request `req.options.timeout`.

### Retry: use ActiveJob, not Faraday middleware

`faraday-retry`'s `interval` / `backoff_factor` are implemented with `sleep` **inside the calling thread**. `config/queue.yml` gives this app **3 worker threads total**. A retry chain that sleeps 0.5 s + 1 s + 2 s inside a worker burns 1/3 of the app's entire job capacity for 3.5 s and, worse, the retry state is lost if the process is restarted.

The correct layer is the job:

```ruby
class Divulgacao::SendToGroupJob < ApplicationJob
  retry_on Evolution::TransientError, wait: :polynomially_longer, attempts: 5
  discard_on Evolution::InstanceNotConnectedError   # QR expired — needs a human
end
```

`retry_on` re-enqueues a *scheduled DB row* — the worker thread is released immediately, the backoff survives deploys and restarts, and a failed attempt is visible in `solid_queue_failed_executions`. That is strictly better than middleware here, and it's why `faraday-retry` is a "no" rather than a "yes".

The one thing worth adding without a gem is `f.response :raise_error`, so non-2xx becomes a `Faraday::Error` you can map onto your own `Evolution::TransientError` / `Evolution::PermanentError` classes.

---

## 2. Evolution API — v2 is current; auth is the `apikey` header

**All claims in this section were read from the upstream source on `main`, not from a blog post or from memory.**

### Version

| Fact | Value | Source |
|------|-------|--------|
| Canonical repo | **`evolution-foundation/evolution-api`** (GitHub 301-redirects the old `EvolutionAPI/evolution-api` here) | GitHub REST `/repositories/651487266` |
| Stars / last push | 9,456 / 2026-07-14 | same |
| **Latest stable release** | **`v2.3.7`** (2025-12-05) | GitHub Releases API |
| Pre-release | `2.4.0-rc1` (2026-05-06), `2.4.0-rc2` (2026-05-17) | same |
| v1 status | **EOL** — last v1 image `v1.8.7`, 2025-06-25 | Docker Hub tags API |
| Canonical Docker image | **`evoapicloud/evolution-api`** | Docker Hub. The widely-blogged `atendai/evolution-api` has had **no push since 2025-06** — do not use it. |
| `:latest` tag | points at the 2.4.0-rc line (2026-05-06) | Docker Hub |

**Recommendation: pin the server to `evoapicloud/evolution-api:v2.3.7`.** Do not run `:latest` — it currently resolves to a release candidate, and an unpinned WhatsApp gateway that auto-upgrades mid-milestone will change response shapes under you. **Record the exact deployed version in `.env`/credentials** so the app can assert it at boot; v2.4.0 is close enough that a phase planner should re-check before pinning.

### Authentication — `apikey` header, NOT `Authorization: Bearer`

From `src/api/guards/auth.guard.ts` (upstream `main`):

```ts
const key = req.get('apikey');
if (!key) throw new UnauthorizedException();
if (env.KEY === key) return next();                     // global AUTHENTICATION_API_KEY
...
const instance = await prismaRepository.instance.findUnique({ where: { name: param.instanceName } });
if (instance.token === key) return next();              // per-instance token
```

There are exactly **two** valid credentials and **one** header name:

| Credential | Header | Works on |
|-----------|--------|----------|
| **Global key** (`AUTHENTICATION_API_KEY` env on the Evolution host) | `apikey: <global>` | every route, including `POST /instance/create` and `GET /instance/fetchInstances` |
| **Per-instance token** (the `hash` returned by `instance/create`, a UUID; or one you supply as `token` in the create body) | `apikey: <instance token>` | only routes that carry `:instanceName` in the path, plus `/instance/fetchInstances` |

Architectural consequence for this app: **instance lifecycle** (create / list / delete) requires the *global* key, while **day-to-day sending** for a client only needs that client's *instance token*. Use the global key for admin-only instance management and the per-client token for every send. That means a leaked per-client token can only reach that one client's WhatsApp number, not the whole gateway — worth designing for.

There is no OAuth, no Bearer, no refresh. `Authorization: Bearer <key>` will get you a 401.

### Route shape

`src/api/abstract/abstract.router.ts`:

```ts
public routerPath(path: string, param = true) {
  let route = '/' + path;
  param ? (route += '/:instanceName') : null;
  return route;
}
```

Mounted in `src/api/routes/index.router.ts` under `/instance`, `/message`, `/group`, `/chat`, `/settings`, `/label`, `/proxy`, `/template`, `/call`, `/business`.

So the shape is **`{BASE}/{resource}/{action}/{instanceName}`**:

| Call | Method + path | Notes |
|------|---------------|-------|
| Create instance | `POST /instance/create` | **No path param** — `instanceName` goes in the JSON body. Needs the global key. Body fields (`src/api/dto/instance.dto.ts`): `instanceName`, `qrcode: true`, `integration: "WHATSAPP-BAILEYS"`, optional `token` (bring your own instance key), `number`, `groupsIgnore`, `alwaysOnline`, `readMessages`, `syncFullHistory`, `webhook: { url, enabled, events, byEvents, base64 }`. |
| Get QR / reconnect | `GET /instance/connect/{instanceName}` | Returns the QR payload. If state is already `open` it returns the connection state instead. |
| Connection state | `GET /instance/connectionState/{instanceName}` | `{ instance: { instanceName, state: "open" \| "connecting" \| "close" } }` |
| List instances | `GET /instance/fetchInstances` | Used to **adopt an already-existing instance** (the "register an instance that already exists" requirement). |
| Delete instance | `DELETE /instance/delete/{instanceName}` |  |
| List groups | `GET /group/fetchAllGroups/{instanceName}?getParticipants=false` | **`getParticipants` is REQUIRED and must be the literal string `"true"` or `"false"`** — `src/validate/group.schema.ts` declares `required: ['getParticipants']` with `enum: ['true','false']`. Omitting it is a 400. Pass `"false"` — participant hydration is slow and you only need JID + subject. |
| Send image/video | `POST /message/sendMedia/{instanceName}` | Body from `SendMediaDto`: `{ number, mediatype: "image"\|"video"\|"document"\|"audio"\|"ptv", mimetype?, caption?, fileName?, media: "<URL or base64>", delay? }`. For a group, `number` is the **group JID** (`...@g.us`). |
| Send caption-only | `POST /message/sendText/{instanceName}` | For text-only artes. |

### The `delay` field is a trap

`SendMediaDto` has a `delay` (ms) field. It is **not** an inter-message delay — it is a "typing…" presence simulation applied *before* the send, and it **blocks the Evolution HTTP request** for that whole duration (`whatsapp.baileys.service.ts` ~L2306: `sendPresenceUpdate('composing'); await delay(options.delay);`).

Setting `delay: 90000` to space out groups would hold an HTTP connection — and a solid_queue worker thread — open for 90 seconds per group. **Use `delay` only for a small human-like typing pause (1000–3000 ms) and do all inter-group spacing with `wait_until` (§3).**

---

## 3. Scheduling & randomised inter-group delay

### `wait_until` is fully supported — verified in the installed gem

`vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/queue_adapters/solid_queue_adapter.rb`:

```ruby
def enqueue_at(active_job, timestamp)
  SolidQueue::Job.enqueue(active_job, scheduled_at: Time.at(timestamp))
end
```

So `MyJob.set(wait_until: divulgacao.send_at).perform_later(...)` writes a durable row with a `scheduled_at`. `config/queue.yml` sets `dispatchers[0].polling_interval: 1`, so a job becomes runnable within ~1 s of its scheduled time. **No `sidekiq-scheduler`, no `whenever`, no cron, no gem.** Note `config/recurring.yml` is for *repeating* schedules — it is the wrong tool for a one-off `Divulgacao` at a user-picked datetime.

### Recommended pattern: staggered fan-out, one job per (divulgação × grupo)

At `Divulgacao` create time, compute the cumulative offsets, **persist them**, and enqueue one job per group:

```ruby
# app/models/divulgacao.rb
def schedule!
  cursor = send_at
  divulgacao_grupos.ordered.each_with_index do |dg, i|
    cursor += rand(Evolution.delay_min..Evolution.delay_max).seconds if i.positive?
    dg.update!(scheduled_for: cursor, status: :pendente)
    Divulgacao::SendToGroupJob.set(wait_until: cursor).perform_later(dg)
  end
end
```

```ruby
# app/jobs/divulgacao/send_to_group_job.rb
class Divulgacao::SendToGroupJob < ApplicationJob
  queue_as :whatsapp
  # Never let two sends through the SAME client's WhatsApp number overlap,
  # even if the admin schedules two Divulgações that collide.
  limits_concurrency to: 1, key: ->(dg) { dg.divulgacao.client_id }, duration: 30.minutes
  retry_on Evolution::TransientError, wait: :polynomially_longer, attempts: 5

  def perform(dg)
    return if dg.divulgacao.cancelada?    # cooperative cancellation — see below
    Evolution::SendArteToGroup.call(dg)
  end
end
```

`limits_concurrency(key:, to:, group:, duration:, on_conflict:)` is confirmed present in the installed solid_queue 1.4.0 (`lib/active_job/concurrency_controls.rb:20`).

**Why this and not a looping job with `sleep`:**

| | Staggered fan-out (recommended) | One job, loop + `sleep` |
|---|---|---|
| Worker occupancy | ~2 s per group, released between groups | **Holds 1 of only 3 worker threads for the whole window.** 12 groups × 60–180 s = up to 36 min, i.e. 33% of total job capacity blocked. |
| Restart safety | Every un-sent group is an independent scheduled DB row — survives deploy/reboot | The un-sent tail is lost; solid_queue has no mid-job checkpoint. On retry the job restarts from group 1 and **re-sends to groups that already received the post.** |
| Per-group status | Each row has its own `status` + `scheduled_for` — the "histórico de envio por grupo" requirement falls out for free | Requires manual bookkeeping inside the loop |
| Observability | `solid_queue_scheduled_executions` shows exactly when each group fires; admin UI can show "grupo 4 às 19:07" | Opaque single row |
| Failure isolation | Group 3 failing does not stop group 4 | An exception at group 3 kills groups 4..N |
| Total window | Known and displayable at creation time | Unknown until it finishes |

A third option — a **self-rescheduling chain** (job sends group *i*, then enqueues itself for group *i+1* with a fresh `rand` delay) — is also non-blocking and produces a truly runtime-random delay. Its downside is that a crash between "send" and "re-enqueue self" silently ends the chain with no scheduled row to show for it, and the total window can't be shown to the admin up front. **Prefer the staggered fan-out**; the delay is still random (drawn per-gap at schedule time), just drawn earlier.

**Cancellation:** `set(wait_until:)` gives you no cancel handle. Do **not** try to delete `SolidQueue::ScheduledExecution` rows by hand. Use cooperative cancellation — a `status` on `Divulgacao` plus a guard clause at the top of `perform`. The stale job still wakes up, but returns in microseconds.

**`sleep` is not banned outright** — a `sleep 1..3` between two calls inside one job is fine. The rule is: never `sleep` for the *configured inter-group delay*, which is minutes.

### good_job: remove it

**`good_job` is dead weight in this repo and should be deleted from the Gemfile in this milestone.**

Evidence: `grep -rln "good_job\|GoodJob" config/ db/ app/ lib/` returns **zero files**. There is no `config.active_job.queue_adapter = :good_job` anywhere, no `config/initializers/good_job.rb`, no `good_jobs` table in `db/schema.rb`, and no GoodJob engine mount in `config/routes.rb`. The only wired adapter is `config/environments/production.rb:53` → `:solid_queue`, backed by `db/queue_schema.rb`, the `queue` database in `config/database.yml`, `config/queue.yml`, and `bin/jobs`.

Removing `gem "good_job", "~> 4.0"` (Gemfile:35) drops `good_job 4.18.2` and its otherwise-unused `fugit` dependency. It also removes a genuine hazard: two ActiveJob adapters in the bundle means a future `queue_adapter` typo, or a copy-pasted `GoodJob::ActiveJobExtensions` snippet, fails silently instead of loudly.

Do this **early in the milestone, as an isolated commit**, before any job code is written — not at the end.

### Development environment gap (must fix in phase 1 of the milestone)

`config/environments/development.rb` sets **no** queue adapter. ActiveJob's fallback is `:async` (`activejob-8.1.3/lib/active_job/queue_adapter.rb:35`), which is an in-process thread pool: `wait_until` works, but **every scheduled send is lost when you restart `bin/dev`**. You cannot meaningfully UAT "agendei para amanhã às 9h" on `:async`.

Action: set `config.active_job.queue_adapter = :solid_queue` in `development.rb`. Note `config.solid_queue.connects_to` is currently production-only, so in development solid_queue will use the primary connection — the queue tables from `db/queue_schema.rb` must be loaded into `calendario_livia_development`. Budget this as real setup work, and run `bin/jobs` alongside `bin/dev`.

---

## 4. QR code — **no gem needed**

**Evolution returns a complete base64 PNG data URI. Do not add `rqrcode`.**

`src/api/types/wa.types.ts`:

```ts
export type QrCode = {
  count?: number;
  pairingCode?: string;
  base64?: string;
  code?: string;
};
```

And `whatsapp.baileys.service.ts` (~L370–390) shows how `base64` is produced:

```ts
qrcode.toDataURL(qr, { margin: 3, scale: 4, errorCorrectionLevel: 'H', color: {...} },
  (error, base64) => {
    this.instance.qrcode.base64 = base64;   // ← full "data:image/png;base64,..." URI
    this.instance.qrcode.code   = qr;       // ← raw pairing string
  });
```

`qrcode.toDataURL` (npm) emits a **full data URI including the `data:image/png;base64,` prefix**. So the view is literally:

```erb
<%= image_tag @qr[:base64], alt: "QR Code do WhatsApp", class: "w-64 h-64" %>
```

You get **all three** forms back and can choose:
- `base64` — render as `<img>`. **Use this.**
- `code` — the raw WhatsApp pairing string, if you ever want to re-render client-side.
- `pairingCode` — an 8-character phone-linking code, populated **only when you pass `number` on instance create**. Offering this as an alternative to scanning is a nice UX touch for a client who can't hold a second phone.

For the record, had a gem been needed it would be `rqrcode 3.2.0` (rubygems.org, verified) — but it is **not** needed and adding it would be pure waste.

**Two operational notes the phase planner needs:** the QR expires in tens of seconds and Evolution regenerates it (`qrcode.count` increments). The pairing screen therefore needs to refresh. This app already has **ActionCable over solid_cable** wired from v1.5 — the natural implementation is to point Evolution's `QRCODE_UPDATED` webhook at a Rails endpoint and `broadcast_replace_to` the QR frame, giving live QR refresh with no polling. Fall back to a Stimulus poll of `GET /instance/connect/{name}` only if the webhook is awkward to expose.

---

## 5. Secrets

Three distinct things with three different homes. Do not treat them alike.

| Secret | Scope | Where it goes | Why |
|--------|-------|---------------|-----|
| `EVOLUTION_BASE_URL` (`https://whatsapp.bomcustoilhabela.com.br`) | Deployment-wide | Credentials (`evolution.base_url`) with an ENV override | Not really a secret, but it belongs next to the key so there's one config object. |
| **Global** `AUTHENTICATION_API_KEY` | Deployment-wide, **high blast radius** — grants create/delete on every instance | **`config/credentials/production.yml.enc`**, read via `Rails.application.credentials.dig(:evolution, :global_api_key)` | Encrypted at rest, in the deploy artifact, unlocked by `RAILS_MASTER_KEY`. This is exactly the pattern v1.6 already uses for `jwt_secret` and `api.ai_key` — stay consistent. |
| **Per-client** instance token | One row of `clients`, scoped to one WhatsApp number | **Database column, `encrypts :evolution_token`** | It is per-record runtime data, not deployable config. It's created at runtime by `instance/create` (or pasted by the admin when adopting an existing instance), so it cannot live in a file that's baked at deploy time. |

### Deployment-level config

```ruby
# app/models/evolution.rb  (or config/initializers/evolution.rb)
module Evolution
  def self.base_url
    ENV.fetch("EVOLUTION_BASE_URL") { Rails.application.credentials.dig(:evolution, :base_url) } ||
      raise("EVOLUTION_BASE_URL não configurado")
  end

  def self.global_api_key
    ENV.fetch("EVOLUTION_GLOBAL_API_KEY") { Rails.application.credentials.dig(:evolution, :global_api_key) }
  end

  def self.delay_min = Integer(ENV.fetch("EVOLUTION_DELAY_MIN_SECONDS", 60))
  def self.delay_max = Integer(ENV.fetch("EVOLUTION_DELAY_MAX_SECONDS", 180))
end
```

ENV-first-with-credentials-fallback lets `dotenv-rails` keep serving dev/test (where `.env` points at a staging Evolution) while production reads from the encrypted store. This satisfies the existing PROJECT.md decision (*"credenciais Evolution em `.env` (dev/test) + credentials (prod)"*) with no gem changes, and it should **fail loudly at boot** if neither source is set — a silently-`nil` base URL turns every send into a confusing `Faraday::ConnectionFailed`.

**Do NOT move `dotenv-rails` to the production group.** A `.env` on the production host is a plaintext secret at rest, sits outside the deploy artifact so it drifts from the repo, and bypasses the credentials pattern this app already uses and that `brakeman`/`bundler-audit` (both in the Gemfile) understand. Credentials + `RAILS_MASTER_KEY` is already working for `jwt_secret`; use it.

### Per-client token — `encrypts`, not plaintext, not credentials

```ruby
class Client < ApplicationRecord
  encrypts :evolution_token   # non-deterministic (the default)
end
```

```ruby
# migration
add_column :clients, :evolution_instance_name, :string
add_column :clients, :evolution_token,         :text     # NOT :string
add_column :clients, :evolution_status,        :string, default: "desconectado"
add_index  :clients, :evolution_instance_name, unique: true
```

- **`:text`, not `:string`.** Non-deterministic encryption stores base64 JSON containing ciphertext + IV + auth tag; a 36-char UUID token expands well past a naive `string(255)` budget once you account for headers. Use `text` and stop thinking about it.
- **Non-deterministic** (the default) is right — you never need `Client.where(evolution_token: x)`. Only use `deterministic: true` if a phase actually requires querying by the token.
- **Logs are already safe:** `ActiveRecord::Encryption.config.add_to_filter_parameters` defaults to `true` (`activerecord-8.1.3/lib/active_record/encryption/config.rb:54`, applied at `railtie.rb:371`), so `evolution_token` is auto-added to `filter_parameters`. Still add it explicitly if you want the intent visible in `config/initializers/filter_parameter_logging.rb`.
- **Prerequisite:** this app's credentials currently contain only `[:secret_key_base, :jwt_secret, :api]` (verified via `bin/rails runner`). `bin/rails db:encryption:init` must be run and its three keys (`primary_key`, `deterministic_key`, `key_derivation_salt`) added to credentials **before** any `encrypts` code ships, or the app raises on boot.

Plaintext is rejected: this token can send messages from the client's real WhatsApp number. A DB dump, a `pg_dump` on a backup drive, or an over-broad admin API response leaks the ability to impersonate the client to their entire contact list. `encrypts` costs one word and needs no gem.

---

## 6. ActiveStorage on S3 — and the URL the Evolution host must fetch

### Gem + config

```ruby
gem "aws-sdk-s3", "~> 1.229", require: false   # latest 1.229.0 (rubygems.org)
```

`require: false` because ActiveStorage `require`s it lazily from `s3_service.rb`. Rails 8.1.3 declares `gem "aws-sdk-s3", "~> 1.48"` at `s3_service.rb:3` — 1.229.0 satisfies it. **`aws-sdk-rails` is not needed** (that's for SES/SQS/parameter-store integration).

```yaml
# config/storage.yml
amazon:
  service: S3
  access_key_id:     <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: <%= Rails.application.credentials.dig(:aws, :region) %>
  bucket: <%= Rails.application.credentials.dig(:aws, :bucket) %>
  # public: false   ← leave it false (the default). Do NOT set true.
```

```ruby
# config/environments/production.rb:25 — CHANGE
config.active_storage.service = :amazon   # was :local
```

Migrating the existing local blobs is a separate task — plan an explicit `bin/rails active_storage:...`/mirror-service step or accept that pre-deploy artes lose their files.

### The critical part: a URL a third-party server can fetch

Evolution's `sendMedia` takes `media: "<url or base64>"` and the Evolution host downloads it server-side. Two candidate URLs, and only one is right:

| Option | What it is | Verdict |
|--------|-----------|---------|
| `rails_blob_url(blob)` | A URL on **your** app that 302-redirects to a presigned S3 URL | ⛔ Routes third-party traffic through your Rails app, requires your app to be publicly reachable, and depends on the fetcher following redirects. Works, but adds a hop and a failure mode for zero benefit. |
| **`blob.url(expires_in: 15.minutes)`** | The **direct presigned S3 URL** | ✅ **Use this.** No hop through Rails, no dependency on your app's public availability, and the credential is a time-boxed SigV4 signature. |

Verified: `ActiveStorage::Service::S3Service#private_url` (`s3_service.rb:129`) is `object_for(key).presigned_url(:get, expires_in: ..., response_content_disposition: ..., response_content_type: ...)`.

### Expiry — the thing that will bite you

`ActiveStorage.service_urls_expire_in` **defaults to 5 minutes** (`activestorage-8.1.3/lib/active_storage.rb:357`).

That default is fine for a browser click and **actively dangerous for a scheduled send**. The failure mode: you generate the media URL when the admin creates the Divulgação at 14:00, persist it on the row, the job runs at 19:00 for group 1 and again at 19:03 for group 2 — and every single one 403s because the signature expired 4h55m ago.

Rules for the phase planner:

1. **Generate the presigned URL inside the job, at send time.** Never at Divulgação-creation time. Never persist it on the `divulgacao_grupos` row.
2. **Pass `expires_in:` explicitly per call** — `blob.url(expires_in: 15.minutes)` — rather than raising the global `config.active_storage.service_urls_expire_in`. Raising the global default weakens every URL in the app, including ones handed to browsers. 15 minutes covers a slow Evolution download of a large video with margin; the URL is discarded immediately after the HTTP call returns.
3. SigV4 caps presigned lifetime at **7 days**, which is irrelevant once you follow rule 1 — but it's the reason "just make it expire in a year" isn't an option.

### Do not make the bucket public

`public: true` on the S3 service makes ActiveStorage use `public_url` (`s3_service.rb:135`) and sets `acl: "public-read"` on every upload. That would put **every client's unpublished artwork permanently on the open internet**. This is client-confidential pre-publication material. Presigned URLs cost nothing extra and solve the problem correctly.

### Other integration details

- Send `mimetype: blob.content_type` and `fileName: blob.filename.to_s` explicitly in the `sendMedia` body — Evolution's sniffing is imperfect and a video sent without a `video/*` mimetype can land as a document.
- Map `Arte`'s media kind to Evolution's `mediatype` enum (`image` | `video` | `document` | `audio` | `ptv`). A text-only arte goes to `/message/sendText` instead.
- The bucket must be reachable **from the public internet** — the Evolution host at `whatsapp.bomcustoilhabela.com.br` is outside your `192.168.3.203` network. A VPC-endpoint-only or IP-allowlisted bucket policy will break sends silently (Evolution logs the 403 on its side, your Rails job sees only a generic Evolution error).
- Artes with an `external_url` (Google Drive / Dropbox) — the existing v1.0 path — are a real hazard here. Drive share links serve an HTML interstitial, not bytes; Evolution will fetch the HTML and either fail or send garbage. **Either restrict Divulgação to artes with an attached ActiveStorage blob, or add an explicit validation.** Flag this to the roadmapper as a scoping decision.
- Add byte-size validation at upload via the already-present `active_storage_validations`. WhatsApp rejects oversized media at send time, which is far too late — the admin finds out hours after scheduling. The exact caps are enforced by WhatsApp/Baileys, not by Evolution, and are not documented in the Evolution repo — **determine them empirically during UAT** and encode the measured value; do not hard-code a number from a blog post.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `faraday 2.14.3` | `Net::HTTP` (stdlib, zero gems) | If the team accepts adding `webmock` for tests instead, or is willing to test `Evolution::Client` only through integration tests against a staging instance. Legitimate but it does not actually reduce the gem count. |
| `faraday 2.14.3` | `httpx 1.8.3` | Only if you needed concurrent multiplexed requests — e.g. fan-out sends inside one process. You don't; solid_queue provides the concurrency. |
| `faraday 2.14.3` | `http` (http.rb) `6.0.4` | Nicer chainable API, but no middleware stack and no built-in test adapter. |
| ActiveJob `retry_on` | `faraday-retry 2.4.0` | Add later, narrowly (`max: 1`, `interval: 0.3`, connection errors only) if UAT shows genuinely transient mid-request failures. Never for the multi-second backoff. |
| Staggered fan-out (`wait_until` per group) | Self-rescheduling chain job | If the admin must be able to abort mid-run *and* you want the delay drawn at runtime rather than at schedule time. Costs observability and total-window predictability. |
| Staggered fan-out | One job looping with `sleep` | Never in this app — only 3 worker threads. |
| `blob.url(expires_in: 15.minutes)` | `rails_blob_url` | If you deliberately want all Evolution media fetches to be logged/audited by your Rails app. Costs a redirect hop and couples sends to your app's uptime. |
| `encrypts :evolution_token` | Plaintext column | Never for this token. |
| Rails credentials for the global key | Kamal secrets / ENV on the host | If deploy moves fully to Kamal (the gem is present but unwired), Kamal secrets become a reasonable second home. Until then, credentials is the established pattern. |
| Cooperative cancellation (status guard) | Deleting `SolidQueue::ScheduledExecution` rows | Never — reaching into solid_queue's internal tables is unsupported and breaks across gem upgrades. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`good_job`** | 4.18.2 is installed but wired to **nothing** — zero references across `config/`, `db/`, `app/`, `lib/`. Dead weight plus a real "two adapters in the bundle" hazard. | Delete `Gemfile:35`. solid_queue is already the adapter. |
| **`rqrcode` / `rqrcode_core` / `chunky_png`** | Evolution already returns a complete `data:image/png;base64,…` URI via `qrcode.toDataURL`. Rendering it again in Ruby is pure waste. | `image_tag @qr[:base64]` |
| **`faraday-retry`** (for now) | Its backoff `sleep`s in a worker thread; you have 3. ActiveJob `retry_on` gives durable, non-blocking, restart-safe backoff. | `retry_on ..., wait: :polynomially_longer` |
| **`httparty` / `rest-client` / `typhoeus` / `httpx`** | HTTParty is a thin wrapper with worse testability; rest-client is effectively unmaintained (last release 2.1.0, 2019); typhoeus needs libcurl at the OS level; httpx solves a concurrency problem you don't have. | `faraday` |
| **`webmock` / `vcr`** | Not needed once you pick Faraday. | `Faraday::Adapter::Test` |
| **`sidekiq` / `sidekiq-scheduler` / `resque` / `delayed_job`** | Would reintroduce Redis, which this project deliberately dropped (solid_cache / solid_queue / solid_cable). solid_queue already does timed enqueue. | `set(wait_until:)` |
| **`whenever` / system cron** | Wrong shape — the schedule is a user-picked one-off datetime, not a recurring pattern. `config/recurring.yml` is likewise the wrong tool. | `set(wait_until:)` |
| **`aws-sdk-rails`** | That gem is for SES / SQS / parameter store. ActiveStorage only needs the S3 client. | `aws-sdk-s3` |
| **`dotenv-rails` in the production group** | Plaintext secrets at rest, outside the deploy artifact, bypassing the credentials pattern already used for `jwt_secret`. | Rails credentials + `RAILS_MASTER_KEY` |
| **`public: true` on the S3 service** | Publishes every client's unpublished artwork to the open internet, permanently. | Default `public: false` + `blob.url(expires_in:)` |
| **`Authorization: Bearer <key>`** against Evolution | Not a supported scheme — `auth.guard.ts` reads only `req.get('apikey')`. Returns 401. | `apikey: <key>` header |
| **`atendai/evolution-api` Docker image** | Widely blogged but no push since 2025-06. | `evoapicloud/evolution-api:v2.3.7` |
| **`evoapicloud/evolution-api:latest`** | Currently resolves to the 2.4.0 **release-candidate** line. An unpinned WhatsApp gateway that self-upgrades mid-milestone will change response shapes under you. | Pin `:v2.3.7` |
| **Any WhatsApp Business Cloud API gem** | PROJECT.md Out of Scope: no Meta app review. Group sending isn't offered by the official Cloud API anyway. | Evolution (Baileys) |
| **Persisting a presigned S3 URL on the Divulgação row** | Default expiry is 5 minutes; a job running hours later gets a 403 on every group. | Generate `blob.url(expires_in: 15.minutes)` inside the job |

## Stack Patterns by Variant

**If the admin registers an instance that already exists (rather than creating one):**
- Call `GET /instance/fetchInstances` with the **global** key to enumerate, let the admin pick, and store `name` + `token` from the response.
- Skip the QR flow entirely; go straight to `GET /instance/connectionState/{name}` to confirm `state == "open"`.
- The stored token must still be `encrypts`-protected — it's the same class of credential.

**If Evolution webhooks can be exposed publicly:**
- Point `QRCODE_UPDATED` and `CONNECTION_UPDATE` at a Rails endpoint and broadcast over the **existing solid_cable ActionCable** stack (v1.5). Live QR refresh and live connection-status badge, no polling. This is the higher-quality path and reuses infrastructure that already works.
- **Guard the webhook endpoint** — it's unauthenticated by default and lives outside the JWT/session world. Use a shared secret in the path or a header, and register it in Rack::Attack (already in the Gemfile) so a flood can't drown the app.

**If webhooks cannot be exposed (firewall, no public ingress from the Evolution host):**
- Stimulus polls `GET /instance/connect/{name}` every ~5 s while the QR modal is open, replacing the `<img>` src. Acceptable but strictly worse — and it must stop polling when the modal closes.

**If the arte has no ActiveStorage attachment (external Drive/Dropbox `external_url`):**
- Either block it from Divulgação with a validation, or download-and-reattach server-side first. Do not pass a Drive share link to Evolution — it serves HTML, not bytes.

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `faraday 2.14.3` | Ruby 3.3.3 ✅ | Runtime deps: `faraday-net_http < 3.5`, `json`, `logger`. Nothing conflicts with the current lockfile. |
| `faraday-retry 2.4.0` | `faraday ~> 2.0` ✅ | Compatible if later added. |
| `aws-sdk-s3 1.229.0` | ActiveStorage 8.1.3 requires `~> 1.48` ✅ | Verified at `s3_service.rb:3`. |
| `solid_queue 1.4.0` (installed) | Rails 8.1.3 ✅ | Latest is **1.7.0** — upgrading is optional and out of scope for v1.7; nothing this milestone needs is missing from 1.4.0 (`enqueue_at` and `limits_concurrency` both confirmed present in the installed copy). |
| Evolution API `v2.3.7` | This client design ✅ | Route + auth shapes read from upstream `main`, which is the 2.4.0-rc line. **Verify the two are identical against the pinned v2.3.7 tag before writing the client** — `main` is ahead of the last stable release. This is the single most important verification the first phase should perform. |
| ActiveRecord::Encryption | Rails 8.1.3 ✅ | Requires `bin/rails db:encryption:init` + credentials entry before first use. |

---

## Confidence & Sources

| Claim area | Confidence | Source |
|------------|------------|--------|
| Gem versions (faraday 2.14.3, faraday-retry 2.4.0, aws-sdk-s3 1.229.0, rqrcode 3.2.0, solid_queue 1.7.0, mission_control-jobs 1.2.0) | **HIGH** | `rubygems.org/api/v1/versions/<gem>/latest.json`, queried 2026-08-29 |
| Evolution repo identity, v2.3.7 stable, 2.4.0-rc, v1 EOL, `evoapicloud` image | **HIGH** | GitHub REST `/repositories/651487266` + `/releases`; Docker Hub `/v2/repositories/evoapicloud/evolution-api/tags` |
| Evolution `apikey` auth, dual credential model | **HIGH** | `src/api/guards/auth.guard.ts` read directly from upstream `main` |
| Evolution route shape, `getParticipants` required-string, `sendMedia` DTO, `delay` semantics | **HIGH** | `abstract.router.ts`, `index.router.ts`, `group.schema.ts`, `sendMessage.dto.ts`, `whatsapp.baileys.service.ts` on upstream `main` |
| QR returns base64 data URI + raw code + pairingCode | **HIGH** | `wa.types.ts` QrCode type + `qrcode.toDataURL` call site in `whatsapp.baileys.service.ts` |
| solid_queue `enqueue_at` / `limits_concurrency` / ActiveJob `:async` default | **HIGH** | Gem source installed in this repo's `vendor/bundle` — `solid_queue-1.4.0`, `activejob-8.1.3` |
| ActiveStorage S3 gem constraint, `private_url`, 5-minute default expiry | **HIGH** | `activestorage-8.1.3/lib/active_storage/service/s3_service.rb`, `lib/active_storage.rb:357` |
| AR Encryption availability + `add_to_filter_parameters` default | **HIGH** | `activerecord-8.1.3/lib/active_record/encryption/config.rb:54`, `railtie.rb:371`; `bin/rails -T` |
| good_job unwired; solid_queue is the only adapter | **HIGH** | Direct grep of this repo's `config/`, `db/`, `app/`, `lib/` |
| Faraday-over-Net::HTTP recommendation | **MEDIUM** | Design judgement + community consensus via WebSearch; the seam classifies websearch-derived findings as LOW, so this is deliberately framed as a reasoned recommendation with the counter-argument stated, not a fact. |
| WhatsApp media size limits | **LOW — do not encode from memory** | Not documented in the Evolution repo; enforced by WhatsApp/Baileys. Measure during UAT. |

### Open items for the first phase to verify
1. Diff upstream `main` against the **`v2.3.7` tag** for `auth.guard.ts`, `group.schema.ts`, and `sendMessage.dto.ts` before writing `Evolution::Client`. `main` is ahead of stable.
2. Confirm the actual Evolution version running at `whatsapp.bomcustoilhabela.com.br` (`GET /` returns a version banner) — it may not be 2.3.7.
3. Measure the real WhatsApp media size ceiling for image and video sends through this gateway.
4. Decide the `external_url` (Drive/Dropbox) arte policy for Divulgação — block, or download-and-reattach.
