# Architecture Research — WhatsApp Auto-Post via Evolution API

**Domain:** Scheduled multi-tenant WhatsApp group broadcasting bolted onto an existing Rails 8 monolith
**Project:** Calendário Livia — v1.7 WhatsApp Auto-Post + Deploy
**Researched:** 2026-08-29
**Confidence:** MEDIUM overall — HIGH for the Rails-side integration (verified by reading this codebase directly), LOW-to-MEDIUM for the Evolution API wire contract (community docs; the project has real version drift between 2.1.x / 2.2.x / 2.4.x)

> **Scope note.** This document covers ONLY how the new WhatsApp features integrate. The existing MVC layout, `@client` scoping discipline, `Arte#scheduled_on` being a `:date`, the Admin/Api namespaces and the ActionCable setup are treated as fixed context, not as open questions. The locked v1.7 decisions (separate `Divulgacao` entity, admin-chooses-groups, one instance per client, ENV-configured delay range, S3) are respected throughout.

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          ADMIN BROWSER (Turbo + Stimulus)                 │
│  ┌──────────────┐ ┌───────────────┐ ┌──────────────┐ ┌────────────────┐  │
│  │ QR / pairing │ │ Group picker  │ │ Divulgação   │ │ Send history   │  │
│  │ panel        │ │ (checkboxes)  │ │ form         │ │ (live rows)    │  │
│  └──────▲───────┘ └───────┬───────┘ └──────┬───────┘ └───────▲────────┘  │
└─────────┼─────────────────┼────────────────┼─────────────────┼───────────┘
          │ turbo_stream    │ POST           │ POST            │ turbo_stream
          │ (existing cable)│                │                 │ (existing cable)
┌─────────┴─────────────────┴────────────────┴─────────────────┴───────────┐
│                          RAILS 8.1.3 (this app)                          │
├──────────────────────────────────────────────────────────────────────────┤
│  CONTROLLERS                                                             │
│  Admin::WhatsappInstancesController   Admin::WhatsappGroupsController    │
│  Admin::DivulgacoesController         Webhooks::EvolutionController      │
├──────────────────────────────────────────────────────────────────────────┤
│  SERVICES  (app/services/whatsapp/ — PORO, Api::JwtService precedent)    │
│  ┌────────────────────┐ ┌───────────────────┐ ┌──────────────────────┐   │
│  │ InstanceProvisioner│ │ GroupSynchronizer │ │ DispatchScheduler    │   │
│  │ InstanceSynchronizer│ │ MediaResolver     │ │ GroupMessageSender   │   │
│  │ WebhookProcessor   │ └───────────────────┘ └──────────────────────┘   │
│  └────────────────────┘                                                  │
│                    ▼ all HTTP goes through ▼                             │
│              ┌───────────────────────────────────┐                       │
│              │  Whatsapp::EvolutionClient        │  ← the ONLY seam      │
│              │  (Net::HTTP, apikey, timeouts)    │    that talks HTTP    │
│              └───────────────┬───────────────────┘                       │
├──────────────────────────────┼───────────────────────────────────────────┤
│  JOBS (solid_queue)          │                                           │
│  DispatchDivulgacaoJob ──enqueues N──▶ SendDivulgacaoTargetJob (×N)      │
│  SyncGroupsJob   RefreshInstanceStateJob   ReconcileDivulgacoesJob       │
├──────────────────────────────┼───────────────────────────────────────────┤
│  MODELS                      │                                           │
│  Client ─has_one─▶ WhatsappInstance ─has_many─▶ WhatsappGroup            │
│    │                                                                     │
│    └─has_many─▶ Divulgacao ─has_many─▶ DivulgacaoTarget                  │
│                     │                                                    │
│                  belongs_to Arte (approved) ──▶ ActiveStorage blob       │
└──────────────────────────────┬─────────────────────────┬─────────────────┘
                               │ HTTPS + apikey          │ POST webhook
                               ▼                         │ (QRCODE_UPDATED,
        ┌──────────────────────────────────┐             │  CONNECTION_UPDATE)
        │  EVOLUTION API HOST (public)     │─────────────┘
        │  one instance per client         │
        └──────────────┬───────────────────┘
                       │ fetches media by URL
                       ▼
        ┌──────────────────────────────────┐
        │  S3 (presigned GET, private)     │
        └──────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `Whatsapp::EvolutionClient` | Sole HTTP transport to Evolution. Auth headers, timeouts, error classification. | PORO, `Net::HTTP`, class-level config from ENV/credentials |
| `Whatsapp::InstanceProvisioner` | Create a new Evolution instance **or** adopt an existing one; persist `WhatsappInstance` | PORO, wraps client + AR write |
| `Whatsapp::GroupSynchronizer` | `fetchAllGroups` → upsert `whatsapp_groups` | PORO called from a job |
| `Whatsapp::DispatchScheduler` | Compute and **persist** the per-group randomised send times | PORO — the only place `rand` is called |
| `Whatsapp::MediaResolver` | `Arte` → `{mediatype, mimetype, media_url, filename}` reachable from the public internet | PORO — isolates the Disk↔S3 difference |
| `Whatsapp::GroupMessageSender` | Send to exactly ONE target; claim, call, classify, record | PORO — the unit of idempotency |
| `Whatsapp::WebhookProcessor` | Parse an untrusted Evolution webhook body, update state | PORO |
| `Whatsapp::DispatchDivulgacaoJob` | Parent: preconditions + fan-out | ActiveJob |
| `Whatsapp::SendDivulgacaoTargetJob` | One group, one attempt | ActiveJob (`wait_until`) |
| `WhatsappInstance` | Connection state machine + cable broadcast on state change | AR model |
| `DivulgacaoTarget` | Per-group send record + atomic claim | AR model |
| `Webhooks::EvolutionController` | Untrusted-input boundary; secret check, no session, no CSRF | `ActionController::API` |

---

## 1. Data Model

### 1.1 Evolution instance: separate `whatsapp_instances` table — **not** columns on `clients`

**Recommendation: a separate `whatsapp_instances` table with a UNIQUE index on `client_id`.**

The 1:1 cardinality tempts you to hang ~10 columns off `clients`. Don't. Five concrete reasons, in descending order of weight:

1. **`clients` is on the hot security path.** Every portal request and every ActionCable connection runs `Client.find_by(access_token: token, active: true)` (see `app/channels/application_cable/connection.rb:19`). That row already carries `password_digest` and `password_plain`. Adding an encrypted Evolution API token to the same row means the app's most frequently loaded object now carries a second live credential into every request, view and serializer. Keeping it in a table you must explicitly `includes` is a real containment boundary.
2. **The QR blob is large and churns.** `last_qr_base64` is a multi-KB string that Evolution rotates roughly every 20–30 s during pairing. Writing that to `clients` triggers `updated_at` churn on the hot row, and any future `after_update_commit` on `Client` would fire on every QR tick.
3. **Lifecycles diverge.** An instance is created, paired, logged out, deleted and re-created independently of the client. A client can switch WhatsApp numbers. On a separate table that's a row replacement; on `clients` it's a partial-column reset you have to remember to write correctly.
4. **Nullable-column semantics rot.** Ten nullable columns admit 2^10 states, most of them nonsense (`instance_name` set but `status` NULL). One row with `NOT NULL` columns and an enum `status` admits exactly the states the state machine defines. `client.whatsapp_instance.present?` is a single honest guard.
5. **Cheap now, expensive later.** `has_one` with a unique index gives you the 1:1 guarantee today and leaves the door open to `has_many` (a client with two numbers) without ever touching `clients`.

The counter-argument — "10–30 clients, this is over-engineering" — is real but loses: the table costs one migration and one model file, and the containment of a live third-party credential is worth more than that.

```ruby
# db/migrate/XXXXXX_create_whatsapp_instances.rb
create_table :whatsapp_instances do |t|
  t.references :client, null: false, foreign_key: true, index: { unique: true }
  t.string   :instance_name,      null: false          # Evolution instanceName
  t.string   :remote_instance_id                        # Evolution instance.instanceId (UUID)
  t.string   :api_token                                 # Evolution `hash` — per-instance token
  t.string   :phone_number                              # owner JID digits, display only
  t.integer  :status,       null: false, default: 0     # enum below
  t.integer  :origin,       null: false, default: 0     # created_by_app / adopted_existing
  t.text     :last_qr_base64                            # volatile; nulled on connect
  t.datetime :qr_expires_at
  t.datetime :last_state_at
  t.datetime :connected_at
  t.datetime :groups_synced_at
  t.text     :last_error
  t.timestamps
end
add_index :whatsapp_instances, :instance_name, unique: true
```

```ruby
# app/models/whatsapp_instance.rb
class WhatsappInstance < ApplicationRecord
  belongs_to :client
  has_many :whatsapp_groups, dependent: :destroy

  encrypts :api_token                                   # Rails 8 ActiveRecord Encryption

  enum :status, { disconnected: 0, pending_qr: 1, connecting: 2,
                  connected: 3, failed: 4 }
  enum :origin, { created_by_app: 0, adopted_existing: 1 }, prefix: :origin
end
```

> **`encrypts :api_token` requires `active_record_encryption` keys** (`primary_key`, `deterministic_key`, `key_derivation_salt`) in credentials. They are **not** currently configured in this app — treat this as an explicit phase task, not an afterthought. If you skip encryption, at minimum keep the column out of any serializer and out of `inspect` via `filter_parameter`.

**Adopting an existing instance:** `origin = adopted_existing` means the app did NOT create it. `InstanceProvisioner` in adopt mode must (a) verify the name exists via `GET /instance/fetchInstances`, (b) read its current `connectionState`, and (c) `POST /webhook/set/{instance}` to point it at *our* webhook — an already-existing instance almost certainly has a different (or no) webhook configured. Forgetting (c) is how "the QR panel never updates for adopted instances" happens.

### 1.2 `whatsapp_groups` — a cache, not a view

```ruby
create_table :whatsapp_groups do |t|
  t.references :whatsapp_instance, null: false, foreign_key: true
  t.string   :jid,      null: false              # e.g. 1203630000000000000@g.us
  t.string   :subject                            # MAY BE NULL — see below
  t.integer  :participants_count
  t.boolean  :active,   null: false, default: true
  t.datetime :synced_at
  t.timestamps
end
add_index :whatsapp_groups, [:whatsapp_instance_id, :jid], unique: true
```

`subject` is deliberately nullable: Evolution's `GET /group/fetchAllGroups/{instance}` is documented to intermittently return entries with a null `subject` and `creation` ([issue #2124](https://github.com/EvolutionAPI/evolution-api/issues/2124)); `findGroupInfos` only repairs some. The picker UI must render a fallback (`group.subject.presence || "Grupo sem nome (#{jid.first(12)}…)"`) rather than a blank checkbox label.

Groups that disappear from a sync are flipped to `active: false`, never hard-deleted — old `DivulgacaoTarget` rows may still reference them.

### 1.3 `divulgacoes`

```ruby
create_table :divulgacoes do |t|
  t.references :client, null: false, foreign_key: true
  t.references :arte,   null: false, foreign_key: true
  t.datetime :scheduled_at, null: false          # THE datetime — Arte#scheduled_on stays :date
  t.string   :time_zone,    null: false, default: "America/Sao_Paulo"
  t.text     :caption                            # nil ⇒ fall back to arte.caption
  t.integer  :status,  null: false, default: 0
  t.datetime :enqueued_at
  t.datetime :started_at
  t.datetime :finished_at
  t.timestamps
end
add_index :divulgacoes, [:client_id, :scheduled_at]
add_index :divulgacoes, [:status, :scheduled_at]
```

```ruby
enum :status, { draft: 0, scheduled: 1, dispatching: 2, completed: 3,
                partially_failed: 4, failed: 5, canceled: 6 }
```

`scheduled_at` is the **only** datetime introduced by this milestone, and it lives here precisely so `artes.scheduled_on` can remain a `:date`. Store UTC in the column (Rails default) and render through `time_zone`; the explicit `time_zone` column exists so the admin's intent ("14:00 horário de Brasília") survives a future server timezone change — the v1.0 timezone anxiety is answered by *pinning* the zone, not by avoiding datetimes.

Model validations (`app/models/divulgacao.rb`):

```ruby
validates :scheduled_at, presence: true
validate  :arte_must_be_approved          # arte.approved? || arte.revised?
validate  :arte_must_belong_to_client     # arte.client_id == client_id  ← the @client scoping rule, at model level
validate  :must_have_targets, on: :create
validate  :instance_must_be_connected, on: :create
validate  :no_overlapping_dispatch_for_client, on: :create   # see §3
validate  :scheduled_at_in_the_future,    on: :create
```

`arte_must_belong_to_client` is the model-level echo of the project's load-bearing "queries always scoped by `@client`" decision. Two FKs to the same tenant is the classic cross-tenant leak shape; assert it once, in the model, so no controller can get it wrong.

### 1.4 `divulgacao_targets` — the per-group send record

**Name: `DivulgacaoTarget` (table `divulgacao_targets`).**

Rationale for `Target` over `Envio`/`Send`: the row is created *before* any send exists (`status: pending`), so naming it "envio" is false at creation and false forever for a skipped group. It is a *target* whose send state is tracked. (`DivulgacaoEnvio` is the acceptable pt-BR alternative if the team prefers linguistic consistency with `Divulgacao` — the schema below is unchanged either way.)

```ruby
create_table :divulgacao_targets do |t|
  t.references :divulgacao,     null: false, foreign_key: true
  t.references :whatsapp_group, null: true,  foreign_key: true   # convenience only
  t.string   :group_jid,     null: false          # DENORMALISED — the send path reads ONLY this
  t.string   :group_subject                       # DENORMALISED SNAPSHOT at creation time
  t.integer  :position,      null: false          # send order, 0-based
  t.integer  :status,        null: false, default: 0
  t.datetime :scheduled_for                       # computed by DispatchScheduler
  t.datetime :claimed_at
  t.datetime :sent_at
  t.integer  :attempts,      null: false, default: 0
  t.string   :provider_message_id                 # Evolution key.id — proof of delivery
  t.text     :last_error
  t.timestamps
end

add_index :divulgacao_targets, [:divulgacao_id, :group_jid], unique: true   # ← anti-duplicate
add_index :divulgacao_targets, [:status, :scheduled_for]
add_index :divulgacao_targets, :provider_message_id, unique: true,
          where: "provider_message_id IS NOT NULL"
```

```ruby
enum :status, { pending: 0, queued: 1, sending: 2, sent: 3,
                failed: 4, unknown: 5, skipped: 6, canceled: 7 }
```

### 1.5 Denormalise the groups — yes, both JID and subject

**Denormalise `group_jid` AND `group_subject` onto `divulgacao_targets`. Keep `whatsapp_group_id` as a nullable convenience FK that nothing in the send path reads.**

Four arguments:

1. **Identity vs. label.** `jid` is the immutable identity; `subject` is a mutable human label. The send path must depend only on identity. Copying the JID onto the target means a send can never be derailed by a `whatsapp_groups` row being re-synced, deactivated or deleted between scheduling and firing.
2. **History is an audit record, not a live view.** Group names change — an admin renames "Clientes VIP" to "VIP 2026". If the history table joined live, last month's report would claim the post went to "VIP 2026", a group that did not exist under that name at send time. That is a falsified audit trail. The snapshot is the correct semantics for the same reason `approval_responses` keeps its own `comment` rather than pointing at a mutable one.
3. **The upstream data is unreliable.** `fetchAllGroups` returns null subjects (§1.2). A live join renders blanks in history rows that *did* have a good name when scheduled. A snapshot taken at pick time preserves whatever was known then.
4. **Left/deleted groups.** If the number is removed from a group, the group vanishes from the next sync. A live join gives you a dangling row; the snapshot still tells you exactly where the post went.

Practical rule: **the picker UI reads `whatsapp_groups` (current state); the history UI reads `divulgacao_targets.group_subject` (historical state); the send path reads `divulgacao_targets.group_jid` (identity).** Three readers, three sources, no ambiguity.

---

## 2. Where Each Responsibility Lives

### Services — `app/services/whatsapp/` (follows the `Api::JwtService` precedent: module namespace, PORO, sibling `Errors` module)

| File | Class | Public surface | Owns |
|------|-------|----------------|------|
| `app/services/whatsapp/errors.rb` | `Whatsapp::Errors::{ConfigurationError, Transient, Permanent, Unknown, NotConnected}` | — | Error taxonomy used for retry decisions |
| `app/services/whatsapp/evolution_client.rb` | `Whatsapp::EvolutionClient` | `.create_instance`, `.connect`, `.connection_state`, `.fetch_instances`, `.set_webhook`, `.fetch_all_groups`, `.send_media`, `.send_text`, `.logout`, `.delete_instance` | The ONLY place `Net::HTTP` is used. Base URL + global apikey from ENV/credentials. Explicit `open_timeout`/`read_timeout`. Raises the taxonomy above. |
| `app/services/whatsapp/instance_provisioner.rb` | `Whatsapp::InstanceProvisioner` | `.new(client, mode:, instance_name: nil).call` | Create-or-adopt; always sets the webhook; persists `WhatsappInstance` |
| `app/services/whatsapp/instance_synchronizer.rb` | `Whatsapp::InstanceSynchronizer` | `.new(instance).call` | Pull `connectionState`, map `open/close/connecting` → enum, persist |
| `app/services/whatsapp/group_synchronizer.rb` | `Whatsapp::GroupSynchronizer` | `.new(instance).call` | `fetchAllGroups` → upsert/deactivate `whatsapp_groups`, stamp `groups_synced_at` |
| `app/services/whatsapp/dispatch_scheduler.rb` | `Whatsapp::DispatchScheduler` | `.new(divulgacao, now:, rng:).call` | **The only `rand` in the milestone.** Computes and persists `scheduled_for` per target |
| `app/services/whatsapp/media_resolver.rb` | `Whatsapp::MediaResolver` | `.new(arte).call` → `Payload` struct | Turns an `Arte` into a payload Evolution can fetch. Isolates Disk↔S3 and normalises `external_url` |
| `app/services/whatsapp/group_message_sender.rb` | `Whatsapp::GroupMessageSender` | `.new(target).call` | Claim → resolve media → send → classify → record. Unit of idempotency |
| `app/services/whatsapp/webhook_processor.rb` | `Whatsapp::WebhookProcessor` | `.new(instance, event:, data:).call` | Untrusted payload → state update. Never trusts a string from the body |

`EvolutionClient` should be injectable (`GroupMessageSender.new(target, client: ...)`) so tests never hit the network — the app has no VCR/WebMock today, so a plain injectable seam is the cheapest path.

### Jobs — `app/jobs/whatsapp/`

| File | Class | Trigger | Does |
|------|-------|---------|------|
| `app/jobs/whatsapp/dispatch_divulgacao_job.rb` | `Whatsapp::DispatchDivulgacaoJob` | `set(wait_until: divulgacao.scheduled_at)` at create | Re-check preconditions, run `DispatchScheduler`, enqueue one child per target, set status `dispatching` |
| `app/jobs/whatsapp/send_divulgacao_target_job.rb` | `Whatsapp::SendDivulgacaoTargetJob` | `set(wait_until: target.scheduled_for)` | `GroupMessageSender.new(target).call`; roll up the parent status |
| `app/jobs/whatsapp/sync_groups_job.rb` | `Whatsapp::SyncGroupsJob` | Admin button / after connect | `GroupSynchronizer` |
| `app/jobs/whatsapp/refresh_instance_state_job.rb` | `Whatsapp::RefreshInstanceStateJob` | `config/recurring.yml` (e.g. every 15 min) | Reconcile connection state for instances whose webhook may have been missed |
| `app/jobs/whatsapp/reconcile_divulgacoes_job.rb` | `Whatsapp::ReconcileDivulgacoesJob` | `config/recurring.yml` (every 5 min) | Age out `sending` targets → `unknown`; close out finished `Divulgacao` rows |

Jobs stay thin: dequeue, load, delegate to a service, roll up status. No HTTP in a job body.

### Models

| File | Holds | Does **not** hold |
|------|-------|-------------------|
| `app/models/whatsapp_instance.rb` | enums, `connected?`, `after_update_commit :broadcast_status_change` | HTTP calls |
| `app/models/whatsapp_group.rb` | `display_subject` fallback, `active` scope | sync logic |
| `app/models/divulgacao.rb` | validations (§1.3), `recompute_status!`, `estimated_finish_at` | scheduling maths, HTTP |
| `app/models/divulgacao_target.rb` | enums, `claim!` (§4), `terminal?` | HTTP, retry policy |
| `app/models/concerns/broadcastable.rb` | **NEW** — `render_partial_html` + `turbo_stream_tag`, extracted from `Arte` | — |

`Arte#render_partial_html` and `Arte#turbo_stream_tag` (`app/models/arte.rb:86-92`) are exactly what `WhatsappInstance` and `DivulgacaoTarget` need. Extract them into `Broadcastable` and `include` in all three rather than copy-pasting a third time.

### Controllers

| File | Class | Routes | Auth |
|------|-------|--------|------|
| `app/controllers/admin/whatsapp_instances_controller.rb` | `Admin::WhatsappInstancesController < Admin::BaseController` | nested under `admin/clients/:client_id`; `show`, `create`, `destroy`, member `connect` (re-issue QR), `adopt`, `refresh` | inherited `require_authentication` |
| `app/controllers/admin/whatsapp_groups_controller.rb` | `Admin::WhatsappGroupsController < Admin::BaseController` | nested under client; `index`, collection `sync` | inherited |
| `app/controllers/admin/divulgacoes_controller.rb` | `Admin::DivulgacoesController < Admin::BaseController` | `index`, `new`, `create`, `show`, member `cancel`, member `retry_target` | inherited |
| `app/controllers/webhooks/evolution_controller.rb` | `Webhooks::EvolutionController < ActionController::API` | `POST /webhooks/evolution/:instance_name` | shared secret, `secure_compare` |

**Why `Webhooks::` and not `Api::V1::`:** the v1.6 decision to make `Api::V1::BaseController < ActionController::API` was about isolating CSRF/cookies/Session from the web auth stack — that reasoning applies here too, so inherit `ActionController::API`. But the webhook has a *different auth model* (a shared secret from a machine we configured, not a JWT/API key issued to a consumer) and a *different response envelope* (Evolution ignores the body; it wants a fast `200`). Putting it under `/api/v1/` would drag it into the `{data, meta, errors}` contract and the `api/ai_by_key` Rack::Attack throttle. Keep it separate.

Controllers do: authorise, load, validate params, delegate to a service, redirect/render. They never call `EvolutionClient` directly.

---

## 3. Scheduling and the Randomised Delay

### Recommendation: **(a) — parent job fans out one child job per group with staggered `wait_until` offsets.** Reject (b).

#### Worker occupancy — decisive

`config/queue.yml` in this repo declares `threads: 3, processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>` → **three concurrent job slots in production, total.**

Under (b), a single looping job for a 12-group dispatch with a 45–180 s delay range holds one of those three slots for **up to 33 minutes**, doing nothing but `sleep`. Two overlapping dispatches consume 2/3 of the entire application's background capacity, starving ActiveStorage analyze/purge and everything else. That alone kills (b) at this configuration.

Under (a), each child occupies a slot for the duration of one HTTP call (seconds). Between sends, zero threads are held — the waiting lives in `solid_queue_scheduled_executions`, which is a table, not a thread.

#### Retry semantics

Under (b), ActiveJob's `retry_on` restarts the **whole job**. The loop re-enters at index 0 and re-sends groups 1..k unless you build a bespoke in-loop guard — i.e. you end up implementing per-target idempotency *anyway*, but with the retry granularity permanently wrong. Under (a) the retry unit *is* the idempotency unit: one job, one target, one row, one unique constraint.

#### Partial-failure recovery

Solid Queue records failures as rows in `solid_queue_failed_executions` with **no automatic retry beyond ActiveJob's `retry_on`**; recovery is `failed_execution.retry` / `.discard`. Under (a) you get one failed row **per group**, individually retryable, and the group's identity is right there in the job arguments. Under (b) you get one opaque failed row for the whole dispatch, and re-running it is unsafe.

#### Dead worker / deploy mid-run

This is the argument most people miss. Solid Queue's supervisor detects a missing heartbeat (`process_heartbeat_interval` 60 s, `process_alive_threshold` 5 min) and marks the dead process's claimed jobs **FAILED with `ProcessPrunedError`, without retrying them.**

- Under (b): a Kamal deploy at minute 4 of a 30-minute loop destroys **every remaining group**. Silently. There is no record of the 8 groups that never got a job.
- Under (a): a deploy kills at most the one child currently in flight. The other 11 are sitting in `scheduled_executions`, untouched by any worker, and fire on schedule after the restart.

#### Additional wins for (a)

- **Visibility.** `scheduled_for` is a real column, so the admin UI can show "grupo 4 — 14:07" *before* it happens. Under (b) the timeline is trapped inside a Ruby `sleep`.
- **Cancellation.** Cancelling means updating target rows to `canceled`; the child jobs still fire but no-op on the claim guard (§4). Under (b) you cannot interrupt a sleeping thread.

**The only real cost of (a)** is that `wait_until` resolution is bounded by the dispatcher's `polling_interval` (1 s in `config/queue.yml`) — sub-second precision is unavailable and completely irrelevant for a 45–180 s randomised gap.

### Exactly where the random offset is computed

**In `Whatsapp::DispatchScheduler#call`, invoked by `Whatsapp::DispatchDivulgacaoJob` at dispatch time, and persisted to `divulgacao_targets.scheduled_for` before any child is enqueued.**

Three "not here" clarifications:

- **Not at `Divulgacao` creation time (controller).** The offsets must be re-rolled if the admin reschedules, and they must be anchored to the *actual* dispatch start, which can drift from `scheduled_at` if the dispatcher was backed up or the app was down.
- **Not inside each child job.** Then no one — not the UI, not the next child — can know the timeline, and ordering is unenforceable.
- **Not in the model.** A model callback that calls `rand` is untestable and fires on unrelated saves.

```ruby
# app/services/whatsapp/dispatch_scheduler.rb
module Whatsapp
  class DispatchScheduler
    def initialize(divulgacao, now: Time.current, rng: Random.new)
      @divulgacao, @now, @rng = divulgacao, now, rng
    end

    def call
      cursor = @now
      @divulgacao.targets.pending.order(:position).each_with_index do |target, i|
        cursor += @rng.rand(min_delay..max_delay) if i.positive?   # first group fires immediately
        target.update!(scheduled_for: cursor, status: :queued)
      end
      @divulgacao.targets.queued.order(:position)
    end

    private

    # Read at CALL time, not class-load time — otherwise tests can't stub ENV.
    def min_delay = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN_SECONDS", "45"))
    def max_delay = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MAX_SECONDS", "180"))
  end
end
```

Add `config/initializers/whatsapp.rb` that fails fast at boot if `MIN > MAX` or either is non-numeric — an inverted range makes `rand` raise deep inside a background job at 2 a.m., which is the worst possible place to discover a typo in `.env`.

`rng:` is injected so a test can pass `Random.new(1234)` and assert exact offsets deterministically.

### Same-number collision

WhatsApp permits only one active Baileys connection per number, and two dispatches for the same client hitting the same instance concurrently is both a ban risk and a correctness risk. Guard it **twice**:

1. **Primary — model validation.** `Divulgacao#no_overlapping_dispatch_for_client` rejects creation if `[scheduled_at, estimated_finish_at]` overlaps another non-terminal `Divulgacao` for the same client, where `estimated_finish_at = scheduled_at + (targets.count - 1) * max_delay`. Fails loudly, in the form, at the right moment.
2. **Secondary — `limits_concurrency`** on `SendDivulgacaoTargetJob`, keyed on the client:

```ruby
limits_concurrency key: ->(target_id) { DivulgacaoTarget.find(target_id).divulgacao.client_id },
                   to: 1, duration: 5.minutes
```

Note the trade-off honestly: a *blocked* job is released the instant the semaphore frees, which **compresses the randomised spacing** for whatever got blocked. That is why validation (1) is the primary guard and `limits_concurrency` is only the safety net for cases validation missed.

---

## 4. Idempotency and Retries

The threat is concrete, not theoretical: Evolution group sends are known to **HTTP-timeout while the message is actually delivered** ([issue #1499](https://github.com/EvolutionAPI/evolution-api/issues/1499)). A naive `retry_on Net::ReadTimeout` double-posts to a real client's WhatsApp group. Four layers:

### Layer 1 — DB unique constraint

```sql
CREATE UNIQUE INDEX ON divulgacao_targets (divulgacao_id, group_jid);
```

Guarantees a group appears at most once per divulgação — so a double-submitted form or a re-run fan-out can never produce two send rows for the same group. (It does not by itself prevent two *sends* for one row; that's layer 2.)

Plus the tripwire:

```sql
CREATE UNIQUE INDEX ON divulgacao_targets (provider_message_id)
  WHERE provider_message_id IS NOT NULL;
```

### Layer 2 — atomic claim (the actual guarantee)

The first statement inside `Whatsapp::GroupMessageSender#call` is a single conditional UPDATE. The database serialises it; no advisory lock, no `with_lock`, no transaction block needed.

```ruby
def claim
  DivulgacaoTarget
    .where(id: @target.id, status: [statuses[:pending], statuses[:queued]])
    .update_all(status: statuses[:sending],
                claimed_at: Time.current,
                attempts: Arel.sql("attempts + 1"),
                updated_at: Time.current)
end

def call
  return :already_handled if claim.zero?   # duplicate enqueue, retry, or cancelled — no-op
  ...
end
```

Any re-delivery — ActiveJob retry, duplicate enqueue, a manual re-run, a re-queued `ProcessPrunedError` job — finds `status NOT IN (pending, queued)` and returns without touching the network. Cancelling a divulgação sets targets to `canceled`, which the same guard turns into a no-op for children already sitting in `scheduled_executions`.

### Layer 3 — `sending` is a manual-review state, never auto-reset

**A target stuck in `sending` must NEVER be automatically returned to `queued`.** `sending` means "we sent bytes and don't know the outcome" — the exact state where a retry double-posts. `Whatsapp::ReconcileDivulgacoesJob` ages `sending` rows older than 10 minutes into **`unknown`**, a distinct terminal-until-a-human-decides state, and the UI shows "estado desconhecido — confira o grupo antes de reenviar" with an explicit *Forçar reenvio* button (which resets to `queued`, on the admin's judgement, not the machine's).

### Layer 4 — retry policy keyed to whether the request reached the server

```ruby
class Whatsapp::SendDivulgacaoTargetJob < ApplicationJob
  queue_as :whatsapp

  # Nothing reached Evolution: safe to retry.
  retry_on Whatsapp::Errors::Transient, wait: :polynomially_longer, attempts: 3

  # We may have delivered. NEVER retry. GroupMessageSender has already written `unknown`.
  discard_on Whatsapp::Errors::Unknown

  # Bad JID, instance disconnected, 4xx. Retrying cannot help.
  discard_on Whatsapp::Errors::Permanent

  discard_on ActiveJob::DeserializationError
end
```

`EvolutionClient` classifies:

| Outcome | Error raised | Target status written | Retried? |
|---------|--------------|-----------------------|----------|
| HTTP 2xx | — | `sent` + `provider_message_id` = `key.id` | — |
| HTTP 4xx | `Permanent` | `failed` | no |
| HTTP 5xx (a response arrived) | `Transient` | reset to `queued` **before** re-raise | yes ×3 |
| `Errno::ECONNREFUSED`, `SocketError`, `Net::OpenTimeout` | `Transient` | reset to `queued` **before** re-raise | yes ×3 |
| `Net::ReadTimeout`, connection reset mid-response | `Unknown` | `unknown` | **no** |

The subtlety worth writing into the plan: on a `Transient` failure the sender must **release the claim** (`status → queued`) *before* re-raising, otherwise layer 2 blocks its own retry. `Net::OpenTimeout` is safely retryable (no request was written); `Net::ReadTimeout` is not (the request was written and may have been processed). Conflating them is the bug.

---

## 5. QR Pairing Flow

### Recommendation: **Evolution webhook → existing ActionCable stream**, with a manual "Verificar conexão" button as the fallback. Do **not** build a Stimulus polling loop.

#### Why the webhook wins

1. **The infrastructure already exists and the pattern is already proven in this repo.** `AdminNotificationsChannel` does `stream_for current_user`; `app/views/layouts/admin.html.erb` already carries `turbo_stream_from`; `Arte#broadcasts_revised_to_all` (`app/models/arte.rb:45-84`) already renders a partial in a model and pushes a `<turbo-stream action="replace">`. A QR panel is one more `turbo_stream_tag("replace", "whatsapp-instance-panel", html)`. **Zero new client-side infrastructure.**
2. **The QR rotates — this is the decisive point.** The pairing QR is refreshed by WhatsApp roughly every 20–30 s. The webhook exists precisely to push the *new* code (`QRCODE_UPDATED` carries the fresh base64). A poll is not just a worse way to learn about success — it shows a **stale, unscannable QR** unless you poll aggressively. Polling turns a push problem into a race.
3. **Poll cost lands on Evolution, not on us.** `GET /instance/connectionState/{name}` reaches into Baileys. Every open admin tab polling every 2 s, times N clients being paired, hammers a single Node process. And a re-poll doesn't regenerate an expired QR — you'd need `GET /instance/connect/{name}`, which on some builds returns `{"count": 0}` with no QR at all ([issue #2385](https://github.com/EvolutionAPI/evolution-api/issues/2385)).
4. Polling costs a new Stimulus controller, a new admin endpoint, and interval/teardown lifecycle bugs (a `setInterval` that survives a Turbo navigation is a classic).

#### Why keep a manual button anyway

The webhook requires the Evolution host to reach *this* Rails app. Today the app runs on a LAN (`192.168.3.203`). If Evolution is off-LAN in development, the webhook simply never arrives. A single **"Verificar conexão"** button that synchronously runs `Whatsapp::InstanceSynchronizer` covers development, covers a dropped webhook, and covers a misconfigured URL — at the cost of one controller action and one form button. One click is not a poll loop.

#### Integration points, concretely

```ruby
# config/routes.rb — outside every namespace, above the health check
post "/webhooks/evolution/:instance_name",
     to: "webhooks/evolution#create",
     as: :evolution_webhook
```

- `app/controllers/webhooks/evolution_controller.rb` — `< ActionController::API`. Compares a shared secret (header `X-Webhook-Token`, or a path segment) using `ActiveSupport::SecurityUtils.secure_compare` **before** looking up the instance (order matters: validating first prevents instance-name enumeration). Renders `head :ok` fast; all real work goes to the service.
- `app/services/whatsapp/webhook_processor.rb` — dispatches on the event name, accepting both `QRCODE_UPDATED` and `qrcode.updated` (Evolution emits different casings across versions). `QRCODE_UPDATED` → write `last_qr_base64` + `qr_expires_at`, status `pending_qr`. `CONNECTION_UPDATE` → map `open|close|connecting` → `connected|disconnected|connecting`; on `open`, null `last_qr_base64`, stamp `connected_at`, and enqueue `Whatsapp::SyncGroupsJob` so the group list is ready the moment pairing succeeds.
- `app/models/whatsapp_instance.rb` — `after_update_commit :broadcast_state, if: -> { saved_change_to_status? || saved_change_to_last_qr_base64? }` → renders `admin/whatsapp_instances/_panel` and pushes `AdminNotificationsChannel.broadcast_to(admin, ...)`. Reuses the extracted `Broadcastable` helpers.
- `app/views/admin/whatsapp_instances/_panel.html.erb` — wrapped in `<div id="whatsapp-instance-panel">`; renders the QR when `pending_qr`, a green connected card when `connected`. Build the data URI **server-side** (`"data:image/png;base64,#{Base64.strict_encode64(...)}"` or validate the payload against `/\A[A-Za-z0-9+\/=]+\z/`) — never interpolate a `data:` prefix that came from the webhook body.
- `config/initializers/rack_attack.rb` — add `throttle("webhooks/evolution_by_ip", limit: 120, period: 60)`; the existing file's style makes this a three-line addition.
- **Webhook registration:** pass the `webhook` object (`{url:, byEvents: false, base64: true, events: ["QRCODE_UPDATED","CONNECTION_UPDATE","SEND_MESSAGE"]}`) in `POST /instance/create`, **and** call `POST /webhook/set/{instance}` for adopted instances. `byEvents: false` keeps a single URL and lets `WebhookProcessor` branch on `params[:event]` — one route, one controller.
- Production: whatever public hostname Evolution posts to must be in `config.hosts` (`config/environments/production.rb:83`, currently commented out).

---

## 6. Media URL Handoff

### What breaks today

`config/environments/production.rb:25` reads `config.active_storage.service = :local`, and `config/storage.yml` defines only `test` and `local` Disk services. A Disk-service `blob.url` is a short-lived signed `/rails/active_storage/disk/...` path **relative to this app's host** — a LAN address. A public Evolution host cannot fetch it. This is a hard blocker, not a nice-to-have: it must land before or alongside the dispatch engine.

### Target: private S3 bucket + presigned URL generated **per target, at send time**

```yaml
# config/storage.yml — ADD
amazon:
  service: S3
  access_key_id:     <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region:            <%= Rails.application.credentials.dig(:aws, :region) %>
  bucket:            <%= Rails.application.credentials.dig(:aws, :bucket) %>
```

```ruby
# config/environments/production.rb:25 — MODIFY
config.active_storage.service = :amazon
```

```ruby
# Gemfile — ADD (missing today; ActiveStorage will not talk to S3 without it)
gem "aws-sdk-s3", require: false
```

### The expiry trap — the single most likely v1.7 production bug

ActiveStorage's presigned S3 URLs default to **300 seconds**. With a randomised 45–180 s gap across, say, 20 groups, the last group fires up to **~60 minutes** after the first. A URL generated once in the parent job and passed down through job arguments **will be expired** for most of the dispatch — and the failure looks like "Evolution says it sent but the group got a broken image", which is miserable to debug.

**Fix: generate the URL inside `Whatsapp::MediaResolver`, called from `GroupMessageSender`, i.e. per target at send time, with `expires_in: 15.minutes`.** Then the window between minting and fetching is seconds, regardless of how long the whole dispatch runs. Never serialise a signed URL into job arguments.

Rejected alternatives:
- **Public bucket (`public: true`)** — permanent unsigned URLs, simplest, but every client's artwork becomes world-readable forever and the blob keys are guessable-adjacent. Not worth it for a service whose whole premise is unpublished client content.
- **Global `config.active_storage.urls_expire_in = 6.hours`** — lengthens *every* URL in the admin panel too, weakening a control that has nothing to do with this feature. Per-call `expires_in` is surgical.
- **Proxy mode (`rails_storage_proxy`)** — requires *this* app to be publicly reachable, which is precisely the constraint we're routing around, and streams 50 MB videos through Puma (`Arte` allows up to 50 MB).

### `Whatsapp::MediaResolver` — the seam

```ruby
Payload = Struct.new(:kind, :mediatype, :mimetype, :media, :filename, :caption, keyword_init: true)

# arte.media_file.attached?  →  kind: :media
#   mediatype: image|video (from arte.media_type)
#   mimetype:  blob.content_type
#   media:     blob.url(expires_in: 15.minutes)   ← minted here, at send time
#   filename:  blob.filename.to_s
# arte.external_url.present? →  kind: :media, media: normalize_external(arte.external_url)
# arte.caption_only?         →  kind: :text
```

**`external_url` needs real work — flag this loudly.** A large share of existing artes use `external_url` pointing at Google Drive or Dropbox *share* pages. Those URLs return **HTML, not media bytes**; Evolution will either error or send a garbage file. `MediaResolver` must either normalise the known hosts —

- `drive.google.com/file/d/<ID>/view…` → `https://drive.google.com/uc?export=download&id=<ID>`
- `dropbox.com/…?dl=0` → `?dl=1`

— or refuse, with `Divulgacao` carrying a creation-time validation ("esta arte usa um link externo que o WhatsApp não consegue baixar; faça upload do arquivo"). Failing at *creation* with a clear message beats failing at 14:03 on a Tuesday inside a background job. Recommend both: normalise the two known hosts, validate-and-reject everything else that isn't a direct media URL.

**Development without S3:** Evolution's `media` field also accepts raw base64, so `MediaResolver` can branch on `ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::DiskService)` and inline base64 locally. It works, but base64-over-HTTP for a 50 MB video is grim — prefer a dev MinIO bucket or a tunnel, and keep the base64 branch as a documented last resort.

---

## 7. Suggested Build Order

Dependency spine: **transport + storage → instance pairing → group listing → divulgação CRUD → dispatch engine → history UI.** Nothing in the chain can be reordered; pairing genuinely gates group listing (no connected instance, no groups), and group listing genuinely gates dispatch (no targets to send to).

| # | Phase | Delivers | Depends on | Notes |
|---|-------|----------|------------|-------|
| 25 | **Evolution transport + S3 storage** | `EvolutionClient`, `Errors`, `config/initializers/whatsapp.rb`, ENV/credentials wiring, `aws-sdk-s3` + `storage.yml` amazon + `production.rb` switch (INFRA-01) | — | Two independent plans that can run in parallel; no UI, no models. De-risks the two things everything else assumes. Verification = a rake/console round-trip against the real Evolution host and a real S3 upload. |
| 26 | **Instance provisioning + QR pairing** | `whatsapp_instances` migration + model, `InstanceProvisioner` (create **and** adopt), `InstanceSynchronizer`, `Webhooks::EvolutionController`, `WebhookProcessor`, `Broadcastable` concern, admin panel + cable broadcast, Rack::Attack throttle | 25 | Also lands `active_record_encryption` credentials. Ends when the admin scans a QR and the panel flips to "conectado" without a reload. |
| 27 | **Group listing + picker** | `whatsapp_groups` migration + model, `GroupSynchronizer`, `SyncGroupsJob`, `Admin::WhatsappGroupsController`, picker UI + `group_picker_controller.js` | 26 | Needs a genuinely connected instance to test. Handle null `subject` from day one. |
| 28 | **Divulgação CRUD (no sending)** | `divulgacoes` + `divulgacao_targets` migrations, both models incl. all validations and the unique index, `Admin::DivulgacoesController`, form with date/time + group multi-select, snapshotting of `group_jid`/`group_subject`, "Divulgar" action on `admin/artes/show` | 27 | Deliberately stops short of sending. A phase that creates correct, well-constrained rows is independently verifiable and de-risks the hardest part (the schema) before the concurrency work. |
| 29 | **Dispatch engine** | `DispatchScheduler`, `MediaResolver`, `GroupMessageSender`, `DispatchDivulgacaoJob`, `SendDivulgacaoTargetJob`, claim/idempotency, retry taxonomy, `ReconcileDivulgacoesJob`, `queue.yml` + `recurring.yml` changes | 28 + 25 | The riskiest phase. Isolate it so a rollback doesn't take the CRUD with it. Tests must cover: duplicate enqueue no-ops, read-timeout → `unknown`, transient → claim released then retried. |
| 30 | **History + live status UI** | Per-target status rows, live updates over the existing cable, per-target *Forçar reenvio*, `cancel`, estimated-finish display, sidebar link | 29 | Reuses the v1.5 broadcast pattern wholesale. |

---

## New vs Modified Files

### New

```
db/migrate/*_create_whatsapp_instances.rb
db/migrate/*_create_whatsapp_groups.rb
db/migrate/*_create_divulgacoes.rb
db/migrate/*_create_divulgacao_targets.rb

app/models/whatsapp_instance.rb
app/models/whatsapp_group.rb
app/models/divulgacao.rb
app/models/divulgacao_target.rb
app/models/concerns/broadcastable.rb

app/services/whatsapp/errors.rb
app/services/whatsapp/evolution_client.rb
app/services/whatsapp/instance_provisioner.rb
app/services/whatsapp/instance_synchronizer.rb
app/services/whatsapp/group_synchronizer.rb
app/services/whatsapp/dispatch_scheduler.rb
app/services/whatsapp/media_resolver.rb
app/services/whatsapp/group_message_sender.rb
app/services/whatsapp/webhook_processor.rb

app/jobs/whatsapp/dispatch_divulgacao_job.rb
app/jobs/whatsapp/send_divulgacao_target_job.rb
app/jobs/whatsapp/sync_groups_job.rb
app/jobs/whatsapp/refresh_instance_state_job.rb
app/jobs/whatsapp/reconcile_divulgacoes_job.rb

app/controllers/admin/whatsapp_instances_controller.rb
app/controllers/admin/whatsapp_groups_controller.rb
app/controllers/admin/divulgacoes_controller.rb
app/controllers/webhooks/evolution_controller.rb

app/views/admin/whatsapp_instances/show.html.erb
app/views/admin/whatsapp_instances/_panel.html.erb
app/views/admin/whatsapp_instances/_qr.html.erb
app/views/admin/whatsapp_groups/index.html.erb
app/views/admin/whatsapp_groups/_group_checkbox.html.erb
app/views/admin/divulgacoes/index.html.erb
app/views/admin/divulgacoes/new.html.erb
app/views/admin/divulgacoes/show.html.erb
app/views/admin/divulgacoes/_form.html.erb
app/views/admin/divulgacoes/_target_row.html.erb

app/javascript/controllers/group_picker_controller.js
config/initializers/whatsapp.rb
```

### Modified

| File | Change |
|------|--------|
| `Gemfile` | `+ gem "aws-sdk-s3", require: false` |
| `config/storage.yml` | add the `amazon:` S3 service block |
| `config/environments/production.rb` (line 25) | `:local` → `:amazon` |
| `config/routes.rb` | admin resources (instances/groups/divulgações) + the `/webhooks/evolution/:instance_name` route |
| `config/queue.yml` | add a second worker block for `queues: "whatsapp"` so sends aren't starved by (or don't starve) ActiveStorage jobs — and raise `RAILS_MAX_THREADS` accordingly, since total threads must stay under the DB pool |
| `config/recurring.yml` | `ReconcileDivulgacoesJob` (every 5 min) + `RefreshInstanceStateJob` (every 15 min) |
| `config/initializers/rack_attack.rb` | throttle for `/webhooks/evolution/` by IP |
| `app/models/client.rb` | `has_one :whatsapp_instance, dependent: :destroy`; `has_many :divulgacoes, dependent: :destroy` |
| `app/models/arte.rb` | `has_many :divulgacoes, dependent: :restrict_with_error`; **extract** `render_partial_html`/`turbo_stream_tag` into `Broadcastable` |
| `app/views/admin/shared/_sidebar.html.erb` | "Divulgações" link |
| `app/views/admin/clients/show.html.erb` | WhatsApp instance panel |
| `app/views/admin/artes/show.html.erb` | "Divulgar no WhatsApp" action, visible only when `approved?`/`revised?` |
| credentials | `aws:` (key/secret/region/bucket), `evolution:` (base_url, global apikey, webhook secret), `active_record_encryption:` |
| `.env` / `.env.example` | see below |

### Environment variables

```
EVOLUTION_BASE_URL=https://evo.example.com
EVOLUTION_API_KEY=<global apikey>
EVOLUTION_WEBHOOK_SECRET=<shared secret>
EVOLUTION_WEBHOOK_BASE_URL=https://app.example.com     # what Evolution posts back to
WHATSAPP_SEND_DELAY_MIN_SECONDS=45
WHATSAPP_SEND_DELAY_MAX_SECONDS=180
```

`dotenv-rails` is development/test only in this Gemfile, matching the already-logged decision: `.env` in dev/test, credentials in production. `EvolutionClient` should read `Rails.application.credentials.dig(:evolution, :api_key) || ENV.fetch("EVOLUTION_API_KEY")` — the same fallback shape as `Api::JwtService.secret` (`app/services/api/jwt_service.rb:31-33`).

---

## Data Flow

### Pairing

```
Admin clicks "Conectar WhatsApp"
  → Admin::WhatsappInstancesController#create
  → Whatsapp::InstanceProvisioner  → POST /instance/create (webhook object inline)
  → WhatsappInstance created (status: pending_qr, last_qr_base64 set)
  → after_update_commit → AdminNotificationsChannel.broadcast_to(admin, replace #whatsapp-instance-panel)
  → admin scans

Evolution → POST /webhooks/evolution/:instance_name  (QRCODE_UPDATED, every ~25s)
  → Webhooks::EvolutionController (secure_compare, head :ok)
  → Whatsapp::WebhookProcessor → instance.update!(last_qr_base64:)
  → broadcast → panel swaps in the fresh QR

Evolution → POST /webhooks/evolution/:instance_name  (CONNECTION_UPDATE state=open)
  → status: connected, last_qr_base64: nil, connected_at
  → broadcast → panel turns green
  → Whatsapp::SyncGroupsJob enqueued
```

### Dispatch

```
Admin creates Divulgacao (client + approved arte + N groups + scheduled_at)
  → targets built with position, group_jid, group_subject SNAPSHOT (status: pending)
  → Whatsapp::DispatchDivulgacaoJob.set(wait_until: scheduled_at).perform_later(id)

--- at scheduled_at ---
DispatchDivulgacaoJob
  → re-check: instance connected? arte still approved? divulgação not canceled?
  → Whatsapp::DispatchScheduler   ← the ONLY rand; writes scheduled_for, status: queued
  → for each target: SendDivulgacaoTargetJob.set(wait_until: target.scheduled_for).perform_later(id)
  → divulgacao.status = dispatching

--- per target, minutes apart ---
SendDivulgacaoTargetJob
  → Whatsapp::GroupMessageSender
      1. atomic claim (UPDATE ... WHERE status IN (pending, queued))  → no-op if lost
      2. Whatsapp::MediaResolver → presigned S3 URL, expires_in: 15.minutes  ← minted HERE
      3. POST /message/sendMedia/{instance}  { number: group_jid, mediatype, media, caption }
      4. 2xx → sent + provider_message_id ; 4xx → failed ;
         5xx/conn → release claim, raise Transient ; read-timeout → unknown
      5. divulgacao.recompute_status!
  → broadcast the target row over AdminNotificationsChannel
```

---

## Anti-Patterns

### Anti-Pattern 1: One long-running job that sleeps between sends
**What people do:** `groups.each { send; sleep rand(45..180) }` in a single job.
**Why it's wrong:** occupies 1 of only 3 worker threads for up to 30 minutes; a retry restarts the loop from group 1; a deploy or worker death loses every remaining group with no record (Solid Queue marks pruned jobs failed and does not retry them).
**Instead:** one child job per target with a persisted `scheduled_for` and `wait_until`.

### Anti-Pattern 2: Retrying on read timeout
**What people do:** `retry_on Net::ReadTimeout` alongside every other network error.
**Why it's wrong:** Evolution group sends are documented to time out *while delivering*. A retry double-posts into a real client's group — the exact failure this product cannot afford.
**Instead:** split the taxonomy. `Net::OpenTimeout`/`ECONNREFUSED` = nothing sent = retry. `Net::ReadTimeout` = unknown = never retry, surface for human review.

### Anti-Pattern 3: Passing a signed media URL through job arguments
**What people do:** resolve the S3 URL once in the parent job and serialise it into each child's arguments.
**Why it's wrong:** the default presigned expiry is 300 s; a dispatch runs for up to an hour. Later groups receive an expired URL and get a broken or missing image, while Evolution still reports success.
**Instead:** mint the URL inside `MediaResolver`, per target, at send time.

### Anti-Pattern 4: Joining the send history live to the group table
**What people do:** `divulgacao_targets belongs_to :whatsapp_group` and render `target.whatsapp_group.subject`.
**Why it's wrong:** group names change and groups disappear; history then reports names that never applied at send time, or renders blanks. An audit trail that mutates is not an audit trail.
**Instead:** snapshot `group_jid` + `group_subject` onto the target; keep the FK as a nullable convenience nothing depends on.

### Anti-Pattern 5: Two FKs to the same tenant without a validation
**What people do:** `divulgacoes` has both `client_id` and `arte_id` and trusts the form.
**Why it's wrong:** a crafted or stale `arte_id` sends client A's artwork to client B's WhatsApp groups — the worst possible failure for this product, and precisely what the project's "always scope by `@client`" rule exists to prevent.
**Instead:** `validate :arte_must_belong_to_client` in the model, plus controller-side `@client.artes.find(...)` following the `set_arte` precedent.

### Anti-Pattern 6: Adopting an existing instance without re-pointing its webhook
**What people do:** accept an instance id, store it, done.
**Why it's wrong:** an instance created elsewhere has someone else's webhook (or none). Pairing and connection state then never reach this app, and the panel hangs on "conectando" forever.
**Instead:** `InstanceProvisioner` in adopt mode always calls `POST /webhook/set/{instance}`.

---

## Scaling Considerations

| Scale | Adjustment |
|-------|------------|
| 10–30 clients, ≤20 groups each (today) | Current shape is right. Watch: total worker threads must stay under the `pool` in `database.yml` (`RAILS_MAX_THREADS`, default 5) once a second `whatsapp` worker block is added. |
| 50+ clients / concurrent dispatches | Evolution becomes the bottleneck (single Node process, one Baileys session per number). Add per-instance concurrency limits and consider sharding across multiple Evolution hosts — `EvolutionClient` should already take `base_url` per instance to make this a config change, so store `base_url` on `whatsapp_instances` if that future is plausible. |
| Hundreds of groups per dispatch | `solid_queue_scheduled_executions` grows linearly but stays trivial. The real limit is WhatsApp's own anti-spam behaviour — the ENV delay range is the control, and it should probably widen, not narrow, with volume. |

**First bottleneck:** worker threads (3) versus concurrent dispatches. Fix by dedicating a `whatsapp` queue with its own worker block, not by raising `threads` on the `*` worker.
**Second bottleneck:** Evolution's single-process throughput during `fetchAllGroups` for many clients at once. Fix by staggering `SyncGroupsJob` rather than syncing all instances on a single recurring tick.

---

## Integration Points

### External Services

| Service | Integration | Gotchas |
|---------|-------------|---------|
| Evolution API | HTTPS + `apikey` header via `Whatsapp::EvolutionClient` | Global apikey manages `/instance/*`; the per-instance `hash` token is used for `/message/*` — do not mix them. Wire format drifts across 2.1/2.2/2.4; event-name casing varies. `/instance/connect` can return `{"count":0}` with no QR on some builds. Group sends can time out while delivering. |
| Evolution webhooks | Inbound `POST /webhooks/evolution/:instance_name` | Requires this app to be publicly reachable; add the host to `config.hosts`. Untrusted body — validate the secret before any lookup, never interpolate payload strings into HTML/URLs. |
| AWS S3 | ActiveStorage `amazon` service, presigned GET | Default expiry 300 s — always pass `expires_in:` explicitly at send time. Needs `aws-sdk-s3`, absent from the Gemfile today. |
| Google Drive / Dropbox (`arte.external_url`) | Pass-through URL, normalised | Share links serve HTML, not bytes. Normalise or reject at `Divulgacao` creation. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Controller ↔ Evolution | never direct — always via a service | mirrors how controllers never touch `JWT` directly, only `Api::JwtService` |
| Job ↔ Evolution | via `GroupMessageSender` / `EvolutionClient` | jobs hold no HTTP logic |
| Model ↔ browser | `after_update_commit` → `AdminNotificationsChannel` | identical to `Arte#broadcasts_revised_to_all`; share the `Broadcastable` concern |
| `Divulgacao` ↔ `Arte` | read-only reference | `Arte` gains an association and nothing else — `scheduled_on` stays a `:date` |
| Client portal ↔ WhatsApp | **none** | the portal is untouched; the admin owns groups and timing |

---

## Confidence

| Area | Level | Reason |
|------|-------|--------|
| Rails-side structure, file paths, integration points | HIGH | Read directly from this repo: `queue.yml`, `storage.yml`, `production.rb`, `rack_attack.rb`, `application_cable/connection.rb`, `arte.rb`, `client.rb`, `jwt_service.rb`, `routes.rb`, `schema.rb` |
| Solid Queue semantics (scheduling, failures, pruning, concurrency) | MEDIUM–HIGH | Official `rails/solid_queue` README; the `ProcessPrunedError`/no-auto-retry behaviour is the load-bearing claim and should be re-confirmed against the installed gem version during phase 29 |
| ActiveStorage S3 expiry defaults | MEDIUM | Widely corroborated 300 s default; verify against Rails 8.1 before relying on the exact number |
| Evolution API wire contract (paths, bodies, event names) | LOW | Community docs and Postman collections; real version drift across 2.1/2.2/2.4. **Phase 25 must verify every endpoint against the actual deployed Evolution host before anything is built on top.** |
| Denormalisation / idempotency / job-topology reasoning | HIGH | Derived from this app's own constraints (3 worker threads, ENV delay range) and from documented Evolution failure modes |

**Open questions for phase 25 to settle empirically:** the exact Evolution version deployed; whether `sendMedia` accepts a group JID in `number` on that build; the precise `QRCODE_UPDATED` / `CONNECTION_UPDATE` payload shapes and casing; whether the Evolution host can reach this Rails app for webhooks in development.

## Sources

- [rails/solid_queue README](https://github.com/rails/solid_queue/blob/main/README.md) — scheduled_executions, dispatcher polling, `limits_concurrency`, failed_executions, ProcessPrunedError
- [Evolution API — Instance Connect docs](https://doc.evolution-api.com/v1/api-reference/instance-controller/instance-connect)
- [Manual de Integração Evolution API V2 (gist)](https://gist.github.com/dantetesta/b8b7e7e2d6196beae968c8b0a61afb7a) — endpoint paths, bodies, global vs instance token
- [Evolution API issue #2124 — fetchAllGroups returns groups without subject](https://github.com/EvolutionAPI/evolution-api/issues/2124)
- [Evolution API issue #1499 — request timeout when sending to WhatsApp groups](https://github.com/EvolutionAPI/evolution-api/issues/1499)
- [Evolution API issue #2385 — /instance/connect returns count:0 with no QR](https://github.com/EvolutionAPI/evolution-api/issues/2385)
- [Evolution API issue #2380 — QR / instance linking flow](https://github.com/evolution-foundation/evolution-api/issues/2380)
- [Evolution API v2.2 Postman documentation](https://www.postman.com/agenciadgcode/evolution-api/documentation/1wphumy/evolution-api-v2-2-0-v2-2-1) — webhook `byEvents`, event list
- [ActiveStorage::Service::S3Service API](https://api.rubyonrails.org/classes/ActiveStorage/Service/S3Service.html)
- [rails/rails issue #32236 — S3 presigned URL expired before access](https://github.com/rails/rails/issues/32236)
- This repository (authoritative for all internal claims): `config/queue.yml`, `config/storage.yml`, `config/environments/production.rb`, `config/initializers/rack_attack.rb`, `app/channels/application_cable/connection.rb`, `app/models/arte.rb`, `app/services/api/jwt_service.rb`, `db/schema.rb`

---
*Architecture research for: WhatsApp group auto-posting via Evolution API, integrated into an existing Rails 8.1.3 monolith*
*Researched: 2026-08-29*
