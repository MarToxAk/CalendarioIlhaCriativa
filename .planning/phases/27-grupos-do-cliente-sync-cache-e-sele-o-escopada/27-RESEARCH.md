# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada - Research

**Researched:** 2026-08-30
**Domain:** Rails 8.1 batch upsert of a slow third-party list (Evolution API `fetchAllGroups`) into a local cache table, served read-only, with per-client association scoping as the security boundary. Background job (solid_queue) + Stimulus poll for completion.
**Confidence:** HIGH for the code seam, the schema, and the upsert mechanics (all read from source this session or from the source-verified contract notes). MEDIUM for the exact `fetchAllGroups` JSON at this host (shape is source-read at tag 2.3.7 but not hit against a real paired instance yet — a UAT item). HIGH for pitfalls (documented Evolution issues + this repo's own precedents).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Modelo de dados dos grupos**
- `whatsapp_groups` `belongs_to :whatsapp_instance` (o grupo pertence ao número, não ao cliente diretamente). `Client has_many :whatsapp_groups, through: :whatsapp_instance`.
- Colunas: `whatsapp_instance_id`, `remote_jid` (`…@g.us`), `subject` (nullable), `announce` (boolean, default false), `active` (boolean, default true), `synced_at` (datetime), timestamps.
- `groups_synced_at` (datetime) adicionado ao `whatsapp_instances` — um carimbo por lote de sync, mostrado na tela ("sincronizado pela última vez em …"). `synced_at` por linha serve para detectar quais grupos NÃO vieram no último lote.
- Índice único `[whatsapp_instance_id, remote_jid]` — o upsert do synchronizer casa por esse par. `remote_jid` sozinho colidiria entre instâncias.

**Sincronização (trigger, job, robustez)**
- Disparo: botão "Sincronizar grupos" no painel WhatsApp do cliente → enfileira `SyncGroupsJob` (solid_queue). `fetchAllGroups` é lento demais para rodar no request. Feedback via reload / polling de `groups_synced_at`.
- SEM job recorrente nesta fase — só o botão manual. Recorrência staggered fica pra fase 30 / hardening.
- Grupo sumido do WhatsApp: após o upsert do lote, os grupos da instância cujo `synced_at` é anterior ao início do lote viram `active: false` (`update_all`, nunca `delete`) — GRUPO-05. A linha e o histórico são preservados.
- Instância não conectada no momento do sync: `SyncGroupsJob` / o synchronizer aborta cedo com mensagem "instância não conectada — pareie antes de sincronizar", NÃO chama o Evolution.

**Tela de grupos e seleção escopada**
- Nova página `admin/clients/:client_id/whatsapp_groups` (index): lista os grupos do cache com `groups_synced_at`, badge `announce` ("só admins enviam"), marcador visual de inativo, fallback de nome. Link a partir do painel WhatsApp do `clients#show`.
- Esta fase entrega a tela COM checkboxes + um partial/componente de picker reutilizável escopado por `whatsapp_instance`, que a fase 28 embute na `Divulgacao`. Esta fase NÃO persiste a seleção — só prova que o escopo funciona.
- Enforcement do escopo (GRUPO-03 / SC5): SEMPRE server-side. O controller / finder parte de `@client.whatsapp_instance.whatsapp_groups`; um `group_id` de outro cliente levanta `ActiveRecord::RecordNotFound` (404) — nunca oferecido, nunca aceito. Mesmo padrão de `@client.artes.find` já usado no projeto.
- Grupos inativos: MOSTRADOS na tela, visualmente distintos ("inativo"), ao fim da lista, NÃO selecionáveis. Legíveis para o histórico (SC4), fora da escolha.

**Evolution::Client + contrato de dados**
- Novo método: `Evolution::Client.fetch_groups(instance_name, api_key:)` → `GET /group/fetchAllGroups/{instance}?getParticipants=false` (a query `getParticipants` é OBRIGATÓRIA como string `"true"`/`"false"`, senão HTTP 400 — contrato verificado, tag 2.3.7). `READ_TIMEOUT_FAST=15s`, mesma taxonomia `Evolution::Errors`. Espelha `fetch_instances` / `connection_state`.
- Chave usada: o token da INSTÂNCIA (`whatsapp_instance.token`), não a apikey global. Leitura de grupos é operação da instância pareada.
- `subject` nulo / grupo sem nome: fallback no model — `display_name = subject.presence || "Grupo sem nome (#{remote_jid.first(12)}…)"`. Nunca um checkbox em branco (Evolution issue #2124).
- `announce` ausente / `nil` no payload: tratar como `false` (grupo aberto).

### Claude's Discretion
- Forma exata do `SyncGroupsJob` (retry/backoff — seguir o precedente do solid_queue no projeto), e se ele usa `perform_later` direto do controller ou via um service.
- Como o feedback de "sync concluído" chega à tela (reload simples vs Turbo Stream vs polling do `groups_synced_at`) — seguir o que o UI-SPEC decidir.
- Nome/estrutura do partial de picker reutilizável e como a fase 28 vai referenciá-lo.
- Textos exatos (pt-BR), cores Tailwind dos estados (ativo/inativo/announce).
- Se `whatsapp_groups` ganha um `scope :selectable` (active + …) agora ou na fase 28.

### Deferred Ideas (OUT OF SCOPE)
- Job recorrente staggered de sync de grupos — fase 30 / hardening.
- `getParticipants=true` / contagem de participantes / lista de admins do grupo — só se uma fase futura precisar.
- Persistir a seleção de grupos numa tabela — fase 28 (`Divulgacao`).
- Cache com TTL / invalidação automática — não; o cache é a tabela, atualizada só pelo sync manual nesta fase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GRUPO-01 | Admin sincroniza a lista de grupos da instância de um cliente | `Evolution::Client.fetch_groups` (novo método, §Code Examples 1) + `Whatsapp::GroupSynchronizer` PORO (§Code Examples 3) + `Whatsapp::SyncGroupsJob` (§Code Examples 4). Botão "Sincronizar grupos" no `_panel.html.erb` (linha de ações existente, `_panel.html.erb:57`) e na página de grupos. |
| GRUPO-02 | A listagem de grupos é servida de cache local, não de uma chamada ao Evolution a cada request | Tabela `whatsapp_groups` (§Architecture Patterns — migration). `index` e `sync_status` leem SÓ `@client.whatsapp_instance.whatsapp_groups` — nenhum `Evolution::Client` no caminho de render. `fetchAllGroups` é medido em segundos (chamada `profilePicture` por grupo dentro do loop — FEATURES.md:243), daí o cache é obrigatório. |
| GRUPO-03 | Admin seleciona quais grupos recebem o post, a partir apenas dos grupos da instância daquele cliente | Partial reutilizável `admin/whatsapp_groups/_picker.html.erb` (locals `client:`, `selected_ids:`, `field_name:`) cujas opções vêm SEMPRE de `client.whatsapp_instance.whatsapp_groups.where(active: true)` (§Architecture Patterns — Pattern 6). Finder escopado `@client.whatsapp_instance.whatsapp_groups.find(id)` → `RecordNotFound`/404 cross-client. Fase 27 renderiza read-only (`field_name: nil`). |
| GRUPO-04 | Grupos onde só administradores podem enviar aparecem sinalizados na seleção | Coluna `announce:boolean` populada de `payload["announce"] == true` no upsert; badge âmbar "Só admins enviam" inline em cada linha do picker (26-UI-SPEC "Group-state → visual treatment map"). `announce` lido de `fetchAllGroups` — não há pré-checagem de "sou admin" (FEATURES.md:241). |
| GRUPO-05 | Grupos que sumiram do WhatsApp são marcados como inativos, nunca apagados, preservando o histórico | Passada de desativação pós-upsert: `instance.whatsapp_groups.where(active: true).where("synced_at < ?", batch_started_at).update_all(active: false, updated_at: Time.current)` (§Code Examples 3, §Pitfall 2). `update_all`, nunca `delete_all`/`destroy`. Linhas inativas aparecem na tela ao fim da lista, não selecionáveis (SC4). |
</phase_requirements>

---

## Summary

Phase 27 is a **cache-fill + read-only-render + scoping-boundary** phase. There are no new gems and no new external service — the Evolution HTTP seam (`Evolution::Client`), the `WhatsappInstance` model, solid_queue, Pagy, Stimulus/Turbo and the admin panel all exist from phases 25–26. The work is: (1) one new HTTP method `Evolution::Client.fetch_groups`, (2) a `whatsapp_groups` migration + model, (3) a `Whatsapp::GroupSynchronizer` PORO that does an idempotent `upsert_all` keyed on `[whatsapp_instance_id, remote_jid]` followed by a "vanished → `active: false`" pass, (4) the project's **first** ActiveJob (`Whatsapp::SyncGroupsJob` — `ApplicationJob` is currently bare), (5) a nested `Admin::WhatsappGroupsController` with `index` + `sync` + `sync_status`, (6) the reusable scoped picker partial, and (7) a `group_sync_controller.js` Stimulus poller modelled on the existing `qr_pairing_controller.js`.

The two mechanics that most often go wrong are both resolved here with verified specifics. **`upsert_all` timestamps:** Rails 8.1 auto-manages `created_at`/`updated_at` for `upsert_all`; if you *also* put `updated_at` in the row payload, PostgreSQL raises `multiple assignments to same column i` — so row hashes carry `synced_at` + `active` and nothing else timestamp-shaped. **The deactivation pass:** it must compare against a single `batch_started_at = Time.current` captured once at the top of `#call` and written verbatim into every upserted row's `synced_at`; then `where("synced_at < ?", batch_started_at)` deactivates exactly the groups that did not appear in this batch, with no in-memory JID set diffing.

The security boundary (GRUPO-03 / SC5) is the same association-scoping pattern the project already uses for `@client.artes.find`: every read of a group starts from `@client.whatsapp_instance.whatsapp_groups`, never from `WhatsappGroup.where(...)`, so a cross-client id is a `RecordNotFound`/404 with no existence leak. The reusable picker partial renders only server-resolved scoped rows, so there is nothing foreign to tamper with client-side.

**Primary recommendation:** Follow the locked schema and the code skeletons in §Code Examples verbatim. Add `query:` support to `Evolution::Client#request` (3-line change, §Code Examples 2) rather than string-interpolating the query onto the path. Persist sync state with three small columns on `whatsapp_instances` (`groups_synced_at`, `groups_sync_state` enum, `groups_sync_error`) so `sync_status` needs no solid_queue introspection. Build and unit-test everything against an **injected fake `Evolution::Client`**; the real end-to-end sync needs an operator-paired instance (carried forward from phase 26) and is a UAT item.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fetch the live group list from Evolution | API / Backend — `Evolution::Client.fetch_groups` | — | The one HTTP seam. Returns raw parsed JSON, raises `Evolution::Errors::*`, no persistence. |
| Batch upsert + deactivate vanished + stamp | API / Backend — `Whatsapp::GroupSynchronizer` (PORO) | Database (`upsert_all`, `update_all` push work to PG) | Orchestration + persistence, not transport. Testable with an injected client. |
| Run the sync off the request path | Background job — `Whatsapp::SyncGroupsJob` (solid_queue) | — | `fetchAllGroups` takes seconds; the request must not wait. First ActiveJob in the repo. |
| Serve the cached list | API / Backend — `Admin::WhatsappGroupsController#index` | Frontend Server (ERB) | Reads only `@client.whatsapp_instance.whatsapp_groups`; **never** calls Evolution (GRUPO-02). |
| Enforce per-client scope | API / Backend — association finder `@client.whatsapp_instance.whatsapp_groups` | Model (`belongs_to`/`has_many :through`) | Server-side only. Cross-client id → `RecordNotFound`/404. Same pattern as `@client.artes.find`. |
| Reusable group picker | Frontend Server (ERB partial) + Browser (checkboxes) | — | `_picker.html.erb`; phase 28 supplies `field_name` to make it a live form control. Phase 27 = read-only proof. |
| Report sync progress to an open page | Browser — `group_sync_controller.js` polling `GET sync_status` | API / Backend (`sync_status` JSON) | solid_queue has no app-facing job-status table; 3 columns on the instance + a 3s poll is the minimal state. |

---

## Standard Stack

### Core — everything is already in the repo; no `bundle add` in this phase

| Library | Version (Gemfile.lock) | Purpose here | Why standard |
|---------|------------------------|--------------|--------------|
| `rails` | 8.1.3 `[VERIFIED: Gemfile.lock]` | `upsert_all` / `insert_all`, `update_all`, `enum`, `has_many :through` | Framework. `upsert_all` on PG is `INSERT … ON CONFLICT DO UPDATE` — the exact primitive this phase needs. |
| `faraday` | 2.14.3 `[VERIFIED: Gemfile.lock]` | `Evolution::Client.fetch_groups` HTTP call | Already the transport for `Evolution::Client` (phase 25). Per-request query params via `req.params` in the block. `[CITED: github.com/lostisland/faraday]` |
| `solid_queue` | 1.4.0 `[VERIFIED: Gemfile.lock]` | `Whatsapp::SyncGroupsJob` backend | Already the Active Job adapter (phase 25 decision). PG-backed, no Redis. |
| `pagy` | 9.4.0 `[VERIFIED: Gemfile.lock]` | Paginate the active-groups list at `limit: 25` | Already used by `Admin::ApprovalsController` `[VERIFIED: app/controllers/admin/approvals_controller.rb:16]`; `Pagy::Backend` is included in `Admin::BaseController` `[VERIFIED: app/controllers/admin/base_controller.rb:5]`. |
| `stimulus-rails` | 1.3.4 `[VERIFIED: Gemfile.lock]` | `group_sync_controller.js` completion poller | `qr_pairing_controller.js` is the exact precedent `[VERIFIED: app/javascript/controllers/qr_pairing_controller.js]`. |
| `turbo-rails` | 2.0.23 `[VERIFIED: Gemfile.lock]` | `button_to` + `turbo_submits_with`; `Turbo.visit` replace after sync | Already used across the admin panel. |

### Supporting — patterns/objects to create (not packages)

| Artifact | Path | Purpose |
|----------|------|---------|
| `Whatsapp::GroupSynchronizer` | `app/services/whatsapp/group_synchronizer.rb` | PORO: `new(instance, client: Evolution::Client).call`. Upsert + deactivate + stamp. |
| `Whatsapp::SyncGroupsJob` | `app/jobs/whatsapp/sync_groups_job.rb` | `perform(instance)` → `GroupSynchronizer`. retry/discard on `Evolution::Errors::*`. |
| `WhatsappGroup` model | `app/models/whatsapp_group.rb` | `belongs_to :whatsapp_instance`; `display_name`; `active`/`inactive` scopes. |
| `Admin::WhatsappGroupsController` | `app/controllers/admin/whatsapp_groups_controller.rb` | `< Admin::BaseController`; `index`, `sync` (POST collection), `sync_status` (GET collection). |
| `_picker.html.erb` + `_group_row.html.erb` | `app/views/admin/whatsapp_groups/` | Reusable scoped picker (locals `client:`, `selected_ids: []`, `field_name: nil`). |
| `group_sync_controller.js` | `app/javascript/controllers/` | 3s poll of `sync_status`, cap ~20 cycles, toast + `Turbo.visit` on completion. |
| `Admin::WhatsappGroupsHelper` | `app/helpers/admin/whatsapp_groups_helper.rb` | `wa_groups_synced_label(instance)` — mirrors `Admin::WhatsappInstancesHelper` `[VERIFIED: app/helpers/admin/whatsapp_instances_helper.rb]`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| 3 status columns on `whatsapp_instances` + 3s poll | Turbo Stream broadcast from the job (repo has `Broadcastable` + `AdminNotificationsChannel` from v1.5) | Broadcast removes polling, but the 26-UI-SPEC **locked** the poll + `GET sync_status` approach; and the job would need the instance's cable stream. Keep the poll; note broadcast as a phase-30 simplification. |
| `upsert_all` (one statement) | Row-by-row `find_or_initialize_by` + `save` | Loses atomicity, runs N× validations/callbacks, slow for 100+ groups, and re-introduces the "which rows vanished" bookkeeping the `synced_at < batch_started_at` pass avoids. |
| Pass the `WhatsappInstance` record to the job (GlobalID) | Pass `instance.id` (Integer) | Both are safe (GlobalID serialises class+id only, **not** the encrypted `token`). Record is more ergonomic and matches the 26-UI-SPEC text. Either is fine. |
| `resources :whatsapp_groups, only: [:index]` + collection routes | Member `show` route for the picker proof | `show` gives a real HTTP surface for the canonical cross-client 404 test in *this* phase (see Open Questions). |

**Installation:** none. `git grep` confirms no `bundle add` is required.

**Version verification performed this session:**
- `Gemfile.lock` read directly `[VERIFIED]`: `faraday (2.14.3)`, `pagy (9.4.0)`, `solid_queue (1.4.0)`, `rails (8.1.3)`, `turbo-rails (2.0.23)`, `stimulus-rails (1.3.4)`.
- No registry lookups needed — zero new dependencies.

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** Every library it uses is already resolved in `Gemfile.lock` and was verified by direct file read this session. No `bundle add`, no `npm install`, no new importmap pin.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| — | — | — | No new packages in phase 27 |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

---

## Architecture Patterns

### System Architecture Diagram

```
 Admin clicks "Sincronizar grupos"  (button_to POST, turbo_submits_with "Sincronizando…")
        │
        ▼
 Admin::WhatsappGroupsController#sync
        │  guard: @client.whatsapp_instance present AND .connected?      ── no ──▶ redirect_back, flash[:alert], NO enqueue
        │  instance.update!(groups_sync_state: :syncing, groups_sync_error: nil)
        │  Whatsapp::SyncGroupsJob.perform_later(instance)
        │  redirect_to index, flash[:notice] "Sincronização iniciada…"
        ▼
 solid_queue worker  ──▶  Whatsapp::SyncGroupsJob#perform(instance)
        │                         │
        │                         ▼
        │                 Whatsapp::GroupSynchronizer.new(instance).call
        │                         │  re-check instance.connected?  ── no ──▶ mark error :not_connected, return
        │                         │  batch_started_at = Time.current
        │                         │  raw = Evolution::Client.fetch_groups(instance.instance_name, api_key: instance.token)
        │                         │        └─ GET /group/fetchAllGroups/{instance}?getParticipants=false
        │                         │           (instance token header; READ_TIMEOUT_FAST=15s; raises Evolution::Errors::*)
        │                         │  rows = raw.filter_map { map id→remote_jid, subject.presence, announce==true, active:true, synced_at:batch_started_at }
        │                         │  WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid])   if rows.any?
        │                         │  instance.whatsapp_groups.where(active:true)
        │                         │          .where("synced_at < ?", batch_started_at)
        │                         │          .update_all(active:false, updated_at: Time.current)          ── GRUPO-05
        │                         │  instance.update!(groups_synced_at: batch_started_at,
        │                         │                   groups_sync_state: :idle, groups_sync_error: nil)
        │                 retry_on Evolution::Errors::Transient/Unknown (attempts: 3) → on exhaust: state :error
        │                 discard_on Evolution::Errors::Permanent / NotConnected     → state :error
        ▼
 group_sync_controller.js (page open)  ──poll every 3s, cap ~20──▶  GET .../whatsapp_groups/sync_status
        │                                                            → { syncing:, synced_at:, error:, count: }
        │  synced_at advanced past sinceValue ─▶ toast "Grupos sincronizados." + Turbo.visit(replace)
        │  error non-null                     ─▶ error toast + reveal inline error box
        │  cap reached                        ─▶ "Atualize a página" note + link
        ▼
 Admin::WhatsappGroupsController#index   (reads ONLY the cache — GRUPO-02)
        │  @instance = @client.whatsapp_instance
        │  @pagy, @active_groups = pagy(@instance.whatsapp_groups.where(active:true).order("subject ASC NULLS LAST").order(:remote_jid), limit: 25)
        │  @inactive_groups     = @instance.whatsapp_groups.where(active:false).order("subject ASC NULLS LAST")
        ▼
 index.html.erb  ─renders─▶  _picker.html.erb (client:, selected_ids: [], field_name: nil)  ─per row─▶  _group_row.html.erb
                             + inactive section (muted, no checkbox, "Inativo" pill)
```

### Recommended Project Structure

```
app/
├── controllers/admin/whatsapp_groups_controller.rb   # index, sync (POST coll), sync_status (GET coll)
├── services/whatsapp/group_synchronizer.rb           # Whatsapp::GroupSynchronizer PORO
├── jobs/whatsapp/sync_groups_job.rb                  # Whatsapp::SyncGroupsJob < ApplicationJob
├── models/whatsapp_group.rb                          # belongs_to :whatsapp_instance; display_name; scopes
├── helpers/admin/whatsapp_groups_helper.rb           # wa_groups_synced_label
├── javascript/controllers/group_sync_controller.js   # poll sync_status
└── views/admin/whatsapp_groups/
    ├── index.html.erb
    ├── _picker.html.erb                              # PHASE 28 CONSUMES THIS VERBATIM
    └── _group_row.html.erb
db/migrate/
├── XXXX_create_whatsapp_groups.rb
└── XXXX_add_groups_sync_columns_to_whatsapp_instances.rb   # groups_synced_at, groups_sync_state, groups_sync_error
config/
├── routes.rb                                         # nested resources :whatsapp_groups
└── initializers/rack_attack.rb                       # throttle POST .../whatsapp_groups/sync
```

> **Namespace choice (Claude's discretion, resolved):** put the synchronizer at `app/services/whatsapp/group_synchronizer.rb` → `Whatsapp::GroupSynchronizer`. Keep `Evolution::` for the pure HTTP transport only; `GroupSynchronizer` is orchestration + persistence, not transport. `.planning/research/ARCHITECTURE.md:261` proposes exactly this. Zeitwerk autoloads `app/services/whatsapp/` with no config.

### Pattern 1: `Evolution::Client.fetch_groups` — mirror `fetch_instances`, add a query hash

**What:** A new class method on `Evolution::Client` that GETs `fetchAllGroups`, guards the non-JSON-2xx case (WR-07 pattern), and returns the raw parsed Array. The `request` private method `[VERIFIED: app/services/evolution/client.rb:123-133]` currently takes `(method, path, api_key:, body: nil, read_timeout: nil)` and has **no** query-param path — add one.

**When to use:** Called only from `Whatsapp::GroupSynchronizer`.

**Key facts (all read this session):**
- `request` already lets the caller override the apikey header per call: `req.headers["apikey"] = api_key` `[VERIFIED: app/services/evolution/client.rb:127]` — so passing `api_key: instance.token` works with the memoized connection that otherwise carries the global key.
- `Evolution::READ_TIMEOUT_FAST = 15` `[VERIFIED: app/services/evolution.rb:60]` — comment on that line already names `fetchAllGroups`.
- `raise_for_status!` maps `400 → Evolution::Errors::Permanent` `[VERIFIED: app/services/evolution/client.rb:164-166]` — a missing/blank `getParticipants` is a 400, so it surfaces as `Permanent` (retry won't fix it → the job discards).
- `Faraday::TimeoutError` on the read phase → `Evolution::Errors::Unknown` via `classify_timeout` `[VERIFIED: app/services/evolution/client.rb:178-188]`. For a read-only GET, `Unknown` is safe to retry (idempotent).

### Pattern 2: Idempotent batch upsert keyed on `[whatsapp_instance_id, remote_jid]`

**What:** `WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid])`. On PostgreSQL this compiles to `INSERT … ON CONFLICT (whatsapp_instance_id, remote_jid) DO UPDATE SET …`. The unique index the locked schema requires is what `unique_by` resolves against.

**Verified mechanics `[CITED: rails/rails PR #43003; Dosu "Rails Upsert_all Gotchas"]`:**
- Rails 8.1 **auto-sets** `created_at` (insert only) and `updated_at` (insert + update) for `upsert_all`, governed by the model's `record_timestamps` (default `true`). You do **not** add them to the row hash.
- **Gotcha — do not put `updated_at` in the row hash.** Rails 8.1+ already injects it into the `ON CONFLICT … DO UPDATE` set; a duplicate assignment makes PostgreSQL raise `ERROR: multiple assignments to same column "updated_at"`. Row hashes carry only: `whatsapp_instance_id`, `remote_jid`, `subject`, `announce`, `active`, `synced_at`.
- Columns named in `unique_by` are **excluded** from the update set — `whatsapp_instance_id` and `remote_jid` are never overwritten on conflict. Good.
- `upsert_all([])` **raises** `ArgumentError: Empty list of attributes passed`. Guard with `if rows.any?`. When zero groups come back, skip the upsert, still run the deactivation pass (deactivates everything) and still stamp `groups_synced_at` — that produces the "synced, 0 groups" empty state (26-UI-SPEC empty state 3).
- `upsert_all` runs **no validations and no model callbacks**. The `display_name` fallback therefore must live in the model as a method (not a `before_save`), and `announce`/`active` defaults must be enforced in the row hash, not by AR.

### Pattern 3: The "vanished group" deactivation pass (GRUPO-05)

**What:** After the upsert, one `update_all` flips groups that did not appear in this batch to `active: false`. Never `delete`.

```ruby
instance.whatsapp_groups
        .where(active: true)
        .where("synced_at < ?", batch_started_at)
        .update_all(active: false, updated_at: Time.current)
```

**Why it is correct:**
- `batch_started_at` is captured **once** at the top of `#call` (`Time.current`) and written verbatim into every upserted row's `synced_at`. So after the upsert, every group present in the batch has `synced_at == batch_started_at`; every group absent from the batch still has its older `synced_at`. `synced_at < batch_started_at` selects exactly the absent ones. This is the locked "Specific Idea" from CONTEXT.md — **never** diff JID sets in memory (fragile at 100+ groups).
- `update_all` does **not** auto-touch `updated_at` (unlike `upsert_all`) — pass `updated_at: Time.current` explicitly. It's a plain `UPDATE`, so no "multiple assignments" problem.
- Scope it through `instance.whatsapp_groups` so it can never touch another instance's rows.
- A re-run with an unchanged group list is a no-op on `active` (all rows get `synced_at = new batch_started_at` in the upsert; the `< batch_started_at` filter then matches nothing).

### Pattern 4: `Whatsapp::SyncGroupsJob` — the repo's first ActiveJob

**What:** `ApplicationJob` is currently bare — `retry_on`/`discard_on` are commented out `[VERIFIED: app/jobs/application_job.rb]`. There is **no** existing job retry precedent to copy; phase 26 did its Evolution I/O synchronously. So this phase sets the pattern.

**Recommended config (maps `Evolution::Errors` taxonomy → retry decision):**
```ruby
class Whatsapp::SyncGroupsJob < ApplicationJob
  queue_as :default   # queue.yml has a single worker on queues: "*" — no dedicated queue this phase

  # GET is idempotent → both Transient and Unknown are safe to retry.
  retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3
  retry_on Evolution::Errors::Unknown,   wait: 30.seconds, attempts: 3

  # Retry can't fix these → record the failure for the UI and stop.
  discard_on(Evolution::Errors::Permanent)     { |job, err| mark_error(job, "transient") }
  discard_on(Evolution::Errors::NotConnected)  { |job, err| mark_error(job, "not_connected") }
  discard_on(Evolution::Errors::ConfigurationError) { |job, err| mark_error(job, "transient") }
  discard_on(ActiveJob::DeserializationError)   # instance deleted mid-flight — nothing to do

  def perform(instance)
    Whatsapp::GroupSynchronizer.new(instance).call
  end

  def self.mark_error(job, code)
    inst = job.arguments.first
    inst.update!(groups_sync_state: :error, groups_sync_error: code) if inst.is_a?(WhatsappInstance)
  end
end
```
- The final `retry_on … attempts:` exhaustion re-raises by default; add a block form if you want it to also `mark_error` on the last failure: `retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3 do |job, err| mark_error(job, "transient") end`.
- **Argument safety:** passing `instance` serialises via GlobalID (class + id only). The encrypted `token` is **not** in the job arguments. ActiveJob does not filter arguments, so never pass `instance.token`.
- solid_queue 1.4.0 records terminal failures as `solid_queue_failed_executions` rows; recovery is `failed_execution.retry` / `.discard` — fine for a manual read sync.
- **Dev:** the solid_queue worker must be running (`bin/jobs`, or whatever `bin/dev`/Procfile wires) for `perform_later` to execute. Phase-25 decision: dev uses solid_queue as the adapter on the primary DB.

### Pattern 5: Sync-state persistence — 3 columns, no solid_queue introspection

**What:** solid_queue has no app-facing "is job X running" table. The 26-UI-SPEC locked a `GET sync_status` JSON endpoint + 3s poll. Minimal backing state on `whatsapp_instances`:

| Column | Type | Meaning |
|--------|------|---------|
| `groups_synced_at` | `datetime` | Last **successful** batch completion. The timestamp the UI shows. Poller compares to `sinceValue`. (Also in the locked schema.) |
| `groups_sync_state` | `integer` enum `{ idle: 0, syncing: 1, error: 2 }`, default 0 | `syncing` set by the controller before enqueue; `idle` by the synchronizer on success; `error` by the job's discard/exhaust handlers. |
| `groups_sync_error` | `string`, nullable | Short code the UI maps to copy: `"not_connected"` or `"transient"`. `nil` on success. |

`sync_status` response: `{ syncing: instance.groups_sync_syncing?, synced_at: instance.groups_synced_at&.iso8601, error: instance.groups_sync_error, count: instance.whatsapp_groups.where(active: true).count }`.

> `groups_sync_state` predicate methods (`groups_sync_syncing?` etc.) come free from `enum`. Prefix isn't required but consider `enum :groups_sync_state, {...}, prefix: :groups_sync` if `idle`/`error` would collide with other enums on the model (they don't today).

### Pattern 6: The reusable scoped picker partial (contract for phase 28)

**Path:** `app/views/admin/whatsapp_groups/_picker.html.erb`. **Locals:** `client:` (required), `selected_ids:` (default `[]`), `field_name:` (default `nil`).

| Aspect | Phase 27 (this phase) | Phase 28 (Divulgação) |
|--------|----------------------|------------------------|
| `field_name` | `nil` → checkboxes render **`disabled`** and carry **no `name`** attribute | `"divulgacao[whatsapp_group_ids][]"` → live checkboxes |
| `selected_ids` | `[]` | real ids of already-picked groups |
| Extra chrome | none | select-all row + `{N} de {M} grupos selecionados` counter |
| Persistence | none — the page only proves the scope resolves | controller does `@client.whatsapp_instance.whatsapp_groups.where(id: params[...])` / `.find(...)` |

**Invariant:** the option set is **always** `client.whatsapp_instance.whatsapp_groups.where(active: true)`, resolved server-side. Inactive groups are excluded from the picker entirely (they render only in the read-only inactive section of the phase-27 index). The partial never emits a foreign id, so there is nothing to tamper with; and any id that *is* submitted in phase 28 is re-resolved through the scoped relation → `RecordNotFound`/404 (SC5, same as `@client.artes.find` `[VERIFIED: app/controllers/client/artes_controller.rb:10]`).

**Empty picker:** when `client.whatsapp_instance.whatsapp_groups.where(active: true)` is empty, render the "Nenhum grupo ativo para selecionar. Sincronize os grupos deste cliente primeiro." line — not an empty `<fieldset>`.

### Pattern 7: `group_sync_controller.js` — poll, don't broadcast

Model on `qr_pairing_controller.js` `[VERIFIED: app/javascript/controllers/qr_pairing_controller.js]`:
- `static values = { statusUrl: String, since: String }`; `INTERVAL_MS = 3000`; `MAX_CYCLES = 20` (~60s).
- `connect()` → `this.cycles = 0`, `this.timer = setInterval(...)`. `disconnect()` → `clearInterval(this.timer)` (timer must never survive a Turbo navigation — same teardown as `toast_controller.js` / `qr_pairing_controller.js`).
- **Difference from the QR controller:** `sync_status` is a **GET** with no side effect, so the fetch is a plain `GET` with `Accept: application/json` and **no CSRF header** (the QR poller POSTs and sends `X-CSRF-Token` because `refresh_qr` mutates).
- On `synced_at` advancing past `sinceValue`: `clearInterval`, fire success toast `Grupos sincronizados.`, `Turbo.visit(window.location.href, { action: "replace" })`.
- On `error` non-null: `clearInterval`, error toast, reveal the inline error box.
- On `cycles >= MAX_CYCLES`: `clearInterval`, show the "A sincronização está demorando. Atualize a página…" note + `Atualizar` link.
- **Never** `console.log` a group `subject` / `remote_jid` / payload (INFRA-04).

### Anti-Patterns to Avoid

- **Rendering the group list from a live Evolution call.** GRUPO-02 is explicit: `index` and `sync_status` read only the cache. `fetchAllGroups` is measured in seconds (a `profilePicture(group.id)` call per group inside the Evolution service loop — FEATURES.md:243).
- **Starting a group query from `WhatsappGroup.where(...)`.** Always `@client.whatsapp_instance.whatsapp_groups…`. A bare `WhatsappGroup` query is the cross-client leak shape (PITFALLS.md:391).
- **Putting `updated_at`/`created_at` in the `upsert_all` row hash.** PostgreSQL raises "multiple assignments to same column".
- **In-memory JID-set diffing to find vanished groups.** Use `synced_at < batch_started_at`.
- **`delete`/`destroy` on vanished groups.** `update_all(active: false, …)` — GRUPO-05, history preservation (SC4). Future `divulgacao_targets` will still reference these rows.
- **`sleep` in the job.** Not relevant here (single call, no loop) but the repo-wide rule stands: `queue.yml` has 3 threads total.
- **Passing `instance.token` or `instance_name` as a job/service argument that bypasses re-scoping.** The synchronizer derives everything from the `WhatsappInstance` record it is handed.
- **Reconstructing / normalising the JID.** Store `payload["id"]` verbatim into `remote_jid` (FEATURES.md §2 — `createJid` passes anything containing `@g.us` through untouched).

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Upsert N rows keyed on a composite unique key | A loop of `find_or_initialize_by` + `save`, or `INSERT` rescuing `RecordNotUnique` | `WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid])` | One statement, atomic, no per-row validation/callback overhead, PG `ON CONFLICT` handles the race. |
| Detect which cached rows disappeared upstream | Load all JIDs, `Set#-`, iterate, update each | `where("synced_at < ?", batch_started_at).update_all(...)` | O(1) statements, no memory blow-up at 100+ groups, no partial-failure window. |
| "Is the sync job still running?" | Query `solid_queue_jobs` / `solid_queue_ready_executions` from the controller | `groups_sync_state` enum + `groups_synced_at` on the instance | solid_queue internals are not a public app API; a 3-column state machine on the instance is testable and stable. |
| Per-client authorization on groups | A Pundit policy / manual `if group.whatsapp_instance.client_id == @client.id` | `@client.whatsapp_instance.whatsapp_groups.find(id)` → `RecordNotFound` | The project's established pattern (`@client.artes.find`); a foreign id is a 404 with zero existence leak, no extra code. |
| Query-string on a Faraday GET | `URI.encode_www_form` onto the path string | `req.params["getParticipants"] = "false"` inside the block | Faraday's `NestedParamsEncoder` handles encoding; keeps the logged path clean; no interpolation of caller data into a URL. `[CITED: github.com/lostisland/faraday]` |
| pt-BR relative/absolute timestamp label | `strftime` scattered in ERB | A helper (`wa_groups_synced_label`) next to `Admin::WhatsappInstancesHelper` | The repo already centralises this (`wa_last_checked_label`). |
| Poll teardown on Turbo navigation | Ad-hoc `beforeunload` listener | Stimulus `disconnect() { clearInterval(this.timer) }` | Exact precedent in `qr_pairing_controller.js` / `toast_controller.js`. |

**Key insight:** Everything hard in this phase is a database primitive (`upsert_all`, `update_all` with a timestamp predicate) or an existing repo pattern (association scoping, Stimulus polling, the Evolution seam). The only genuinely new thing is the first ActiveJob, and its shape is a direct translation of the `Evolution::Errors` taxonomy into `retry_on`/`discard_on`.

---

## Runtime State Inventory

Phase 27 is **greenfield-additive** — a new table, new columns, new files. No rename, no rebrand, no data migration of existing values. The five categories are answered explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `whatsapp_groups` is created empty by this phase; nothing existing keys on it. `whatsapp_instances` gains 3 nullable columns (no backfill needed). | None. |
| Live service config | None — no recurring job registered this phase (locked: manual button only). `config/recurring.yml` is **not** touched. Evolution webhook events are unchanged (phase 26 owns `QRCODE_UPDATED` / `CONNECTION_UPDATE`). | None. Note: phase 26's `WebhookProcessor` may enqueue `SyncGroupsJob` on `open` per ARCHITECTURE.md:501 — verify whether phase 26 actually wired that; if so, this phase's job must exist before that path fires. |
| OS-registered state | None. | None. |
| Secrets / env vars | None new. `fetch_groups` reuses `whatsapp_instance.token` (already `encrypts :token`, already in `filter_parameter_logging` via phase 26). No new credential key. | None. |
| Build artifacts | None — no gem added, no `bin/rails` generator output beyond migrations + files. `db/schema.rb` regenerates on migrate. | Run migrations; `db/schema.rb` diff is expected. |

**Nothing found in "Stored data", "OS-registered state", "Secrets", "Build artifacts" — verified by reading `config/recurring.yml`, `config/queue.yml`, `db/schema.rb`, `app/models/whatsapp_instance.rb`, `config/initializers/rack_attack.rb` this session.**

---

## Common Pitfalls

### Pitfall 1: `fetchAllGroups` response field is `id`, not `remote_jid`; and `subject` is intermittently null
**What goes wrong:** The synchronizer maps `payload["remote_jid"]` (nil) → every row has `remote_jid: nil` → unique index violation or all-null rows. Separately, `payload["subject"]` is `null` for some entries and a blank checkbox label ships.
**Why it happens:** The Evolution 2.3.7 shape (source-read, FEATURES.md:143-160) is `{ "id": "1203...@g.us", "subject": "...", "announce": true, "isCommunity": false, ... }` — the JID key is **`id`**. Null `subject`/`creation` is a documented, intermittent Evolution bug ([issue #2124](https://github.com/EvolutionAPI/evolution-api/issues/2124)); `findGroupInfos` only repairs some.
**How to avoid:** Row mapping: `remote_jid: g["id"].to_s` (verbatim, no reformatting), `subject: g["subject"].presence` (→ nil, not `""`). Model `display_name = subject.presence || "Grupo sem nome (#{remote_jid.first(12)}…)"` — **U+2026 ellipsis `…`, one char**, per 26-UI-SPEC copy ("Grupo sem nome (120363012345…)"). The picker row renders `display_name`, never a bare `subject`.
**Warning signs:** `ActiveRecord::RecordNotUnique` on first sync; blank rows in the picker; `display_name` showing `Grupo sem nome (…)` for *every* group (means you read the wrong key).

### Pitfall 2: The deactivation pass deactivates groups that are still present (or none)
**What goes wrong:** Every group flips to `active: false` after a successful sync, or a re-sync with no changes churns `active`.
**Why it happens:** `batch_started_at` computed twice (once for rows, once for the `where`), or `Time.current` called inside the row map per-row, so upserted rows get `synced_at` values that are all `>= ` **and** `< ` the comparison value inconsistently; or the comparison uses `<=` and catches the just-upserted rows.
**How to avoid:** `batch_started_at = Time.current` **once**, first line of `#call`. Same variable into every row's `synced_at` and into `where("synced_at < ?", batch_started_at)`. Strictly `<`. Scope through `instance.whatsapp_groups`. Pass `updated_at: Time.current` to `update_all` explicitly (it won't auto-touch).
**Warning signs:** Active count drops to 0 after a sync that clearly returned groups; `updated_at` never changes on deactivated rows.

### Pitfall 3: `upsert_all` with `updated_at` in the payload → PG "multiple assignments to same column"
**What goes wrong:** First real sync raises `PG::SyntaxError`/`ActiveRecord::StatementInvalid: … multiple assignments to same column "updated_at"`.
**Why it happens:** Rails 8.1 auto-injects `updated_at` into the `ON CONFLICT … DO UPDATE` set; adding it to the row hash duplicates the assignment. `[CITED: Dosu "Rails Upsert_all Gotchas"; rails/rails PR #43003]`
**How to avoid:** Row hash keys are exactly `whatsapp_instance_id, remote_jid, subject, announce, active, synced_at`. Nothing else. Let Rails manage `created_at`/`updated_at`.
**Warning signs:** `StatementInvalid` mentioning `updated_at` or `created_at` on the very first `upsert_all` call.

### Pitfall 4: `upsert_all([])` raises on an account with zero groups
**What goes wrong:** A number that is in no groups (or a still-warming chip) makes the job crash instead of producing the "0 groups" empty state.
**Why it happens:** `upsert_all` rejects an empty list (`ArgumentError: Empty list of attributes passed`).
**How to avoid:** `WhatsappGroup.upsert_all(rows, unique_by: …) if rows.any?`. Always run the deactivation pass and the `groups_synced_at` stamp regardless. Zero rows + deactivation-of-all + stamp = 26-UI-SPEC empty state 3.
**Warning signs:** Job fails only for specific clients; `groups_synced_at` never advances for a number that genuinely has no groups.

### Pitfall 5: `READ_TIMEOUT_FAST = 15s` may be too short for a number in many groups
**What goes wrong:** Sync intermittently fails with `Evolution::Errors::Unknown` (read timeout) for the busiest clients, even though the data is fine.
**Why it happens:** Evolution's `fetchAllGroups` loop calls `profilePicture(group.id)` **per group** even with `getParticipants=false` (FEATURES.md:243); dozens of groups → seconds, occasionally >15s. Cloudflare sits in front with its own ~100s ceiling (evolution-contract.md:67).
**How to avoid:** This runs in a **background job** with `retry_on Evolution::Errors::Unknown` — a transient timeout self-heals on retry, so 15s is *acceptable* but not ideal. Consider a dedicated `READ_TIMEOUT_GROUPS = 30` (still well under the CF ceiling) and pass it as `read_timeout:` — but this deviates from the CONTEXT.md-locked "READ_TIMEOUT_FAST=15s". **Flag to the user** (Open Question 1). Do **not** exceed 60s.
**Warning signs:** `groups_sync_error: "transient"` recurring for the same one or two clients; job succeeds on manual retry.

### Pitfall 6: Cross-client leak via a group id in `params`
**What goes wrong:** Phase 27 (or the phase-28 code that reuses the picker) accepts a `whatsapp_group_id` and loads it with `WhatsappGroup.find` — client A can address client B's group.
**Why it happens:** The scoping invariant is only enforced when the query *starts* from `@client`. `WhatsappGroup.find(params[:id])` bypasses it. Evolution ids (`…@g.us`) are strings from outside the DB (PITFALLS.md:376).
**How to avoid:** Every finder: `@client.whatsapp_instance.whatsapp_groups.find(params[:id])` (or `.where(id: params[:ids])`). Cross-client → `RecordNotFound` → 404, rescued to a generic "não encontrado". The picker partial never renders a foreign id. Add an **explicit negative test** (client A, group id belonging to B → 404) — this is the phase's canonical proof (CONTEXT.md "Specific Ideas"), and `security_enforcement` is on.
**Warning signs:** Any `WhatsappGroup.where`/`.find` not prefixed by `@client…`; `params[:group_jid]` reaching a model or job.

### Pitfall 7: Stale session — the instance reports `connected` but the sync fails at run time
**What goes wrong:** Controller guard passes (`instance.connected?` from the last check), but by the time the job runs the WhatsApp session dropped; `fetch_groups` returns a Baileys error or a 4xx.
**Why it happens:** `connection_state` is a cached column, refreshed by phase-26's manual verify / webhook — it can lag reality (PITFALLS.md:181).
**How to avoid:** Re-check `instance.connected?` at the top of `GroupSynchronizer#call` (defense in depth). Map a run-time not-connected / Baileys failure to `groups_sync_error: "not_connected"` so the 26-UI-SPEC error box shows the "número apareceu como desconectado" copy. The `index` page still renders the last good cache (GRUPO-02).
**Warning signs:** `groups_sync_error: "not_connected"` right after a green connection badge; UAT only.

### Pitfall 8: Accidental sync-spam hammering Evolution + WhatsApp
**What goes wrong:** A double-click, a crawler, or an impatient admin fires `POST .../sync` repeatedly; each enqueues a job; Evolution gets pounded (PITFALLS.md:520, 497).
**How to avoid:** (a) `button_to` with `data: { turbo_submits_with: "Sincronizando…" }` disables on click (26-UI-SPEC). (b) Add a Rack::Attack throttle for `POST` on the groups `sync` path (the initializer already throttles `webhooks/evolution` — same file `[VERIFIED: config/initializers/rack_attack.rb:41]`). (c) Optionally a `Rails.cache.write("wa_groups_sync_#{instance.id}", true, unless_exist: true, expires_in: 15.seconds)` guard in `#sync` before enqueue — exact precedent in `Admin::WhatsappInstancesController#pull_fresh_qr` `[VERIFIED: app/controllers/admin/whatsapp_instances_controller.rb:105-112]` (T-26-15).
**Warning signs:** Multiple `SyncGroupsJob` for one instance in `solid_queue_jobs`; Evolution 429s.

---

## Code Examples

### 1. `Evolution::Client.fetch_groups` — mirrors `fetch_instances` `[VERIFIED: app/services/evolution/client.rb:88-98]`

```ruby
# app/services/evolution/client.rb  (add as a public class method, after connection_state)

# GET /group/fetchAllGroups/{instance}?getParticipants=false — leitura da instância.
# `getParticipants` é OBRIGATÓRIO como string (senão 400 -> Evolution::Errors::Permanent).
# Usa o TOKEN DA INSTÂNCIA (api_key: whatsapp_instance.token), não a apikey global.
# Retorna o corpo cru (Array). Espelha fetch_instances, inclusive o guard WR-07.
def fetch_groups(instance_name, api_key:)
  body = request(:get, "/group/fetchAllGroups/#{instance_name}",
                 api_key: api_key,
                 query: { "getParticipants" => "false" },
                 read_timeout: Evolution::READ_TIMEOUT_FAST).body
  raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Array)

  body
end
```

### 2. Add `query:` to the private `request` `[VERIFIED: app/services/evolution/client.rb:123-133]` — 3 lines

```ruby
#   was: def request(method, path, api_key:, body: nil, read_timeout: nil)
def request(method, path, api_key:, body: nil, read_timeout: nil, query: nil)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  resp = nil
  resp = connection.public_send(method, path) do |req|
    req.headers["apikey"] = api_key
    req.params.update(query) if query          # <-- NEW: Faraday NestedParamsEncoder handles encoding
    req.options.read_timeout = read_timeout if read_timeout
    req.body = body if body
  end
  raise_for_status!(resp)
  resp
  # ... rescue / ensure unchanged
end
```
`[CITED: github.com/lostisland/faraday]` — `conn.get do |req| req.params['k'] = v end` is the supported per-request query idiom in Faraday 2.x. `req.params` is a `Faraday::Utils::ParamsHash`; `.update` merges.

### 3. `Whatsapp::GroupSynchronizer` PORO

```ruby
# app/services/whatsapp/group_synchronizer.rb
module Whatsapp
  class GroupSynchronizer
    Result = Struct.new(:ok, :count, :reason, keyword_init: true)

    def initialize(instance, client: Evolution::Client)
      @instance = instance
      @client   = client
    end

    def call
      unless @instance.connected?
        @instance.update!(groups_sync_state: :error, groups_sync_error: "not_connected")
        return Result.new(ok: false, reason: :not_connected)
      end

      batch_started_at = Time.current
      raw  = @client.fetch_groups(@instance.instance_name, api_key: @instance.token)
      rows = Array(raw).filter_map { |g| row_for(g, batch_started_at) }

      WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?

      @instance.whatsapp_groups
               .where(active: true)
               .where("synced_at < ?", batch_started_at)
               .update_all(active: false, updated_at: Time.current)   # GRUPO-05, never delete

      @instance.update!(groups_synced_at:  batch_started_at,
                        groups_sync_state: :idle,
                        groups_sync_error: nil)

      Result.new(ok: true, count: rows.size)
    end

    private

    def row_for(g, ts)
      jid = g["id"].to_s
      return nil unless jid.end_with?("@g.us")   # store verbatim; skip non-group entries defensively

      {
        whatsapp_instance_id: @instance.id,
        remote_jid: jid,
        subject:    g["subject"].presence,       # nil, never "" (issue #2124)
        announce:   g["announce"] == true,       # nil / absent -> false
        active:     true,
        synced_at:  ts
        # NO created_at / updated_at — Rails 8.1 manages them for upsert_all
      }
    end
  end
end
```

### 4. `WhatsappGroup` model

```ruby
# app/models/whatsapp_group.rb
class WhatsappGroup < ApplicationRecord
  belongs_to :whatsapp_instance

  scope :active_groups,   -> { where(active: true) }
  scope :inactive_groups, -> { where(active: false) }

  # subject nulo (Evolution issue #2124) -> nunca um rótulo em branco.
  # Ellipsis = U+2026 (um caractere), copy verbatim do 26-UI-SPEC.
  def display_name
    subject.presence || "Grupo sem nome (#{remote_jid.to_s.first(12)}…)"
  end
end
```
```ruby
# app/models/whatsapp_instance.rb — additions
has_many :whatsapp_groups, dependent: :destroy
enum :groups_sync_state, { idle: 0, syncing: 1, error: 2 }, prefix: :groups_sync
```
```ruby
# app/models/client.rb — addition (has_one :whatsapp_instance already exists [VERIFIED: app/models/client.rb:6])
has_many :whatsapp_groups, through: :whatsapp_instance
```

### 5. Migrations

```ruby
# db/migrate/XXXX_create_whatsapp_groups.rb
class CreateWhatsappGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_groups do |t|
      t.references :whatsapp_instance, null: false, foreign_key: true
      t.string   :remote_jid, null: false            # "...@g.us", verbatim from payload["id"]
      t.string   :subject                            # nullable — issue #2124
      t.boolean  :announce, null: false, default: false
      t.boolean  :active,   null: false, default: true
      t.datetime :synced_at
      t.timestamps
    end
    add_index :whatsapp_groups, [:whatsapp_instance_id, :remote_jid], unique: true
    add_index :whatsapp_groups, [:whatsapp_instance_id, :active]      # index for the picker/list query
  end
end
```
```ruby
# db/migrate/XXXX_add_groups_sync_columns_to_whatsapp_instances.rb
class AddGroupsSyncColumnsToWhatsappInstances < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_instances, :groups_synced_at,  :datetime
    add_column :whatsapp_instances, :groups_sync_state, :integer, null: false, default: 0
    add_column :whatsapp_instances, :groups_sync_error, :string
  end
end
```

### 6. Routes `[VERIFIED: config/routes.rb:9-19]`

```ruby
# config/routes.rb — inside `resources :clients do ... end` in the admin namespace
resources :whatsapp_groups, only: [:index], controller: "whatsapp_groups" do
  collection do
    post :sync
    get  :sync_status
  end
end
# helpers: admin_client_whatsapp_groups_path(client)
#          sync_admin_client_whatsapp_groups_path(client)
#          sync_status_admin_client_whatsapp_groups_path(client)
```

### 7. `Admin::WhatsappGroupsController`

```ruby
# app/controllers/admin/whatsapp_groups_controller.rb
class Admin::WhatsappGroupsController < Admin::BaseController
  before_action :set_client
  before_action :set_instance

  def index
    return if @instance.nil?

    active_scope = @instance.whatsapp_groups.where(active: true)
                            .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid)
    @pagy, @active_groups = pagy(active_scope, limit: 25)
    @inactive_groups = @instance.whatsapp_groups.where(active: false)
                                .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid)
  end

  def sync
    if @instance.nil? || !@instance.connected?
      return redirect_to admin_client_whatsapp_groups_path(@client),
             alert: "A instância está desconectada. Reconecte o número antes de sincronizar os grupos."
    end
    @instance.update!(groups_sync_state: :syncing, groups_sync_error: nil)
    Whatsapp::SyncGroupsJob.perform_later(@instance)
    redirect_to admin_client_whatsapp_groups_path(@client),
                notice: "Sincronização iniciada. Os grupos aparecem aqui em instantes."
  end

  def sync_status
    render json: {
      syncing:   @instance&.groups_sync_syncing? || false,
      synced_at: @instance&.groups_synced_at&.iso8601,
      error:     @instance&.groups_sync_error,
      count:     @instance ? @instance.whatsapp_groups.where(active: true).count : 0
    }
  end

  private

  def set_client   = @client = Client.find(params[:client_id])
  def set_instance = @instance = @client.whatsapp_instance

  # Phase 28 / any future single-group read MUST go through this — cross-client -> 404.
  # def set_group = @group = @client.whatsapp_instance.whatsapp_groups.find(params[:id])
end
```

### 8. Rack::Attack throttle `[VERIFIED: config/initializers/rack_attack.rb:41]`

```ruby
# config/initializers/rack_attack.rb — add beside the webhooks/evolution throttle
throttle("admin/whatsapp_groups_sync_by_ip", limit: 6, period: 60) do |req|
  req.ip if req.post? && req.path.match?(%r{\A/admin/clients/\d+/whatsapp_groups/sync\z})
end
```

---

## State of the Art

| Old approach | Current approach | When changed | Impact here |
|--------------|------------------|--------------|-------------|
| `insert_all`/`upsert_all` did **not** set `created_at`/`updated_at` | Rails auto-manages timestamps for `insert_all`/`upsert_all`, governed by `record_timestamps` (default true); can be forced with `record_timestamps:` | Rails 7.0 (rails/rails PR #43003), still true in 8.1 | Row hashes must **omit** `updated_at`/`created_at` or PG raises "multiple assignments to same column". `[CITED: rails/rails#43003]` |
| Faraday 1.x `conn.get(path, params, headers)` positional | Faraday 2.x block form `conn.get(path) { |req| req.params[...] = ...; req.headers[...] = ... }` | Faraday 2.0 | The repo is on 2.14.3; the `request` helper already uses the block form — just add `req.params`. `[CITED: github.com/lostisland/faraday]` |
| `announce`-as-"restrict" confusion | Baileys `announce` == "group only allows admins to write messages"; `restrict` == "only admins can edit group settings" (irrelevant to posting) | — | Store `announce` only; ignore `restrict`. (FEATURES.md §2) |

**Deprecated / not used:**
- `getParticipants=true` — slow (per-group `profilePicture`), unreliable under the `@lid` migration, and explicitly deferred by CONTEXT.md.
- `findGroupInfos` (single-group refetch) — not needed this phase; only partially repairs null `subject` anyway (issue #2124).
- Evolution API v1 body shapes — host is pinned at 2.3.7 (evolution-contract.md), v2 paths/bodies only.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `GET /group/fetchAllGroups/{instance}` at this host returns a **bare JSON array** whose group-identity key is `id` (`…@g.us`), with `subject` (nullable), `announce` (bool), `isCommunity`/`isCommunityAnnounce` present. | Pattern 1, Pitfall 1, Code Ex. 3 | Source-read at tag 2.3.7 (FEATURES.md:143-160) but **not yet hit against a real paired instance**. If the top level is wrapped (`{ "groups": [...] }`) or the key is `remote_jid`/`jid`, the synchronizer's `Array(raw)` + `g["id"]` mapping breaks. **UAT item** — confirm with one real sync. |
| A2 | The **instance token** (`whatsapp_instance.token`) authorizes `GET /group/fetchAllGroups/{instance}`. | CONTEXT (locked) + Pattern 1 | Contract says instance token is valid on any `:instanceName`-path route (evolution-contract.md:36) and the global key also works on every route — so the global key is a viable fallback. Not empirically verified. UAT item. If the instance token 401s, fall back to `Evolution.global_api_key`. |
| A3 | `fetchAllGroups` at 2.3.7 is **not paginated** — one call returns the full array. | Pitfall 5, Summary | `group.schema.ts` only requires `getParticipants` (STACK.md:197); no `limit`/`offset`/`cursor` params documented; the Baileys service builds and returns the whole array in one loop (FEATURES.md:143). Not tested against a 100+ group account. If pagination exists, a client with many groups would sync only the first page. UAT item for a large account. |
| A4 | `announce` arrives as a JSON boolean (`true`/`false`), occasionally absent/`null`. | GRUPO-04, Code Ex. 3 | Documented as `"announce": true` in the shape. `g["announce"] == true` coerces `nil`/absent/`"false"` to `false` (the locked "announce nil → false" rule), so a string or missing value degrades safely. Low risk. |
| A5 | `READ_TIMEOUT_FAST = 15s` is enough for `fetchAllGroups` in this deployment. | Pitfall 5, Open Q1 | Per-group `profilePicture` calls make the endpoint slow; a busy number may exceed 15s. Mitigated by `retry_on Unknown` in the job. If it recurs, a dedicated 30s timeout is the fix — but that edits a CONTEXT-locked value. |
| A6 | Phase 26 did **not** already wire `WhatsappGroup`/`SyncGroupsJob` into `WebhookProcessor` (ARCHITECTURE.md:501 proposed enqueuing the job on `CONNECTION_UPDATE open`). | Runtime State Inventory | If phase 26 *did* stub that call, there may be a dangling reference to `Whatsapp::SyncGroupsJob` already. Planner: grep `SyncGroupsJob` before creating it. Low risk (phase 26 verification notes don't mention it). |
| A7 | Adding a member `show` route/action is the cleanest way to make the cross-client 404 test real in phase 27 (vs deferring the canonical test to phase 28). | Open Q2 | The 26-UI-SPEC routes list is `only: [:index]` + 2 collection routes. If the planner prefers not to add `show`, the scope proof is a controller/request test on the scoped finder helper — still valid, just not an HTTP surface. |

**Anything not in this table is either `[VERIFIED: …]` from a file read this session or `[CITED: …]` from the source referenced inline.**

---

## Open Questions

1. **`fetchAllGroups` read timeout for busy numbers.**
   - What we know: CONTEXT.md locks `READ_TIMEOUT_FAST=15s`. The endpoint does a `profilePicture` call per group and is measured in seconds. The job has `retry_on Evolution::Errors::Unknown`.
   - What's unclear: whether 15s will intermittently time out for the agency's largest clients.
   - Recommendation: ship with 15s + retry (self-healing). If UAT or production shows recurring `groups_sync_error: "transient"` for the same clients, introduce `READ_TIMEOUT_GROUPS = 30` (still << the ~100s Cloudflare ceiling) — treat that as a one-line follow-up, and confirm with the user since it touches a locked value.

2. **How does phase 27 *prove* the cross-client scope (SC5) without a selection endpoint?**
   - What we know: CONTEXT.md's canonical test is "a POST/GET of selection with a `whatsapp_group.id` belonging to another client → 404". Phase 27 persists nothing and the 26-UI-SPEC routes are `index` + `sync` + `sync_status`.
   - What's unclear: whether to add a real HTTP surface now or defer the canonical negative test to phase 28.
   - Recommendation: add `show` to the nested resource (`only: [:index, :show]`) with `@group = @client.whatsapp_instance.whatsapp_groups.find(params[:id])`; the `show` view can be minimal (or redirect to `index#anchor`). This gives phase 27 a genuine scoped finder + an automated `RecordNotFound`/404 test, and phase 28 reuses the exact finder. Cheap, and `security_enforcement` is on.

3. **Should communities (`isCommunity` / `isCommunityAnnounce`) be filtered or flagged?**
   - What we know: `fetchAllGroups` returns these booleans; FEATURES.md:226 suggests hiding/marking community announce channels because they don't behave like normal groups. CONTEXT.md's locked column list does **not** include them.
   - What's unclear: whether the agency ever wants to post to a community announce channel.
   - Recommendation: follow the locked schema — do **not** add columns, show all `@g.us` entries. If communities cause confusion in UAT, add `is_community:boolean` + a filter in a later phase. Note it as a UAT observation point.

4. **`WhatsappInstance#connected?` freshness before enqueue.**
   - What we know: `connection_state` is a cached column (phase 26); the controller guard reads it, the synchronizer re-checks it.
   - What's unclear: whether the `sync` action should first run a synchronous `Evolution::Client.connection_state` refresh (like `#verify` does) before enqueuing.
   - Recommendation: don't — that reintroduces a slow Evolution call on the request path. Rely on the guard + the synchronizer's re-check + the `not_connected` error state. The admin already has "Forçar verificação" in the panel.

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Evolution API host (outbound) | `fetch_groups` | ✓ (proven phase 25-04: `fetch_instances` → 200, ~654ms) | Evolution 2.3.7 behind Cloudflare | none — hard dependency, but only exercised in the job, not render |
| A **genuinely paired** `WhatsappInstance` (`connection_state = connected`) | End-to-end sync test | ✗ in this session — phase 26 pairing was **deferred to the operator** (STATE.md "Deferred Verification"; 26-UAT.md 4 items) | — | Unit-test the synchronizer + job with an **injected fake `Evolution::Client`**; real sync is a UAT item gated on operator pairing |
| solid_queue worker process (dev) | `SyncGroupsJob.perform_later` to actually run | ✓ (adapter configured phase 25-02; `bin/jobs` / `bin/dev`) | solid_queue 1.4.0 | If the worker isn't running in dev, the job sits in `solid_queue_ready_executions` — the poller will hit its cap and show the "Atualize a página" note. Document "start the worker" in the phase's dev-run notes. |
| PostgreSQL (`upsert_all` `ON CONFLICT`, `NULLS LAST`) | synchronizer + list ordering | ✓ | PG (adapter `postgresql`, `[VERIFIED: config/database.yml]`) | none needed — PG is the only supported DB here |
| Test DB | Running the automated negative/scope tests | ✗ `bin/rails test` blocked (`PG::InsufficientPrivilege` — test DB owned by another OS user; MEMORY `test_db_permission.md`, STATE 25-05) | — | Verify by inspection + `bin/rails runner` with a stubbed Faraday connection, as phases 25/26 did. Flag the test-execution gap in verification. |

**Missing dependencies with no fallback:** none that block *building* the phase. The Evolution host is reachable; everything else has a stub/inspection path.
**Missing dependencies with fallback:** a paired instance (→ fake client for unit tests; real sync deferred to operator UAT); test DB (→ inspection + `runner`, per established project practice).

---

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high`.

### Applicable ASVS L1 Categories

| ASVS category | Applies | Standard control in this phase |
|---------------|---------|--------------------------------|
| V1 Architecture | yes | Group reads flow through one association path (`@client.whatsapp_instance.whatsapp_groups`); Evolution I/O isolated in `Evolution::Client` + a single PORO. |
| V2 Authentication | no (inherited) | `Admin::BaseController` `before_action :require_authentication` `[VERIFIED: app/controllers/admin/base_controller.rb:3]` covers every new action. No new auth surface. |
| V3 Session Management | no | No changes. `sync_status` is a same-origin GET behind the admin session. |
| V4 Access Control | **yes — the core of GRUPO-03 / SC5** | Every group read starts from `@client.whatsapp_instance.whatsapp_groups`; cross-client id → `ActiveRecord::RecordNotFound` → 404, no existence disclosure. Same pattern as `@client.artes.find`. Add an explicit A-vs-B negative test. `sync`/`sync_status`/`index` all scoped by `params[:client_id]` → `Client.find`. |
| V5 Input Validation | yes | No raw `remote_jid`/`group_jid` accepted from params anywhere in phase 27. `getParticipants` is a hard-coded `"false"` string, never user input. `payload["id"]` stored verbatim (no reconstruction) but only after an `@g.us` suffix check. Pagy `limit` is fixed at 25, not param-driven. |
| V6 Cryptography | no | `whatsapp_instance.token` already `encrypts` (phase 26). This phase reads it to pass as an HTTP header via the existing seam; it is never logged (INFRA-04, `filter_parameter_logging` covers `token`/`apikey`/`hash`) and never enters job arguments (GlobalID serialises id only). |
| V7 Error Handling & Logging | yes | `Evolution::Client` logs method/path/status/duration only — never the body `[VERIFIED: app/services/evolution/client.rb:143-144]`. The synchronizer and `group_sync_controller.js` must not log group `subject`/`remote_jid`/payload. `groups_sync_error` stores a short code (`not_connected`/`transient`), never a raw upstream string. |
| V11 Business Logic | yes | `sync` guarded against not-connected (no Evolution call). Rack::Attack throttle + `turbo_submits_with` + optional 15s cache guard prevent sync-spam (a real anti-ban concern — repeated `fetchAllGroups` and downstream WhatsApp load). Vanished groups are deactivated, never deleted (audit/history integrity for future `divulgacao_targets`). |
| V13 API / Web Service | yes | `sync_status` returns only `{ syncing, synced_at, error, count }` — no group names, no JIDs, no counts of *inactive* groups. It is scoped by `params[:client_id]`. |

### Known Threat Patterns for {Rails 8.1 + Evolution API + solid_queue}

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Cross-client group access via crafted/stale `whatsapp_group_id` (arte of A into groups of B, later) | Elevation of Privilege / Information Disclosure | Association-scoped finder only; `RecordNotFound` → 404; picker renders no foreign id; negative test A×B (PITFALLS.md:369) |
| Group-list enumeration for another client | Information Disclosure | `sync_status` and `index` scoped by `params[:client_id]`; 404 (not 403) on any cross-client id — no existence signal |
| Secret leakage: instance `token` into logs / job args / error state | Information Disclosure | `encrypts :token`; `filter_parameter_logging` (phase 26); GlobalID job serialization (id only); `Evolution::Client` never logs bodies |
| Sync-spam → Evolution rate-limit / WhatsApp scrutiny of the client's number | Denial of Service (self-inflicted, feeds ban risk) | Rack::Attack throttle on `POST …/sync`; `turbo_submits_with` disable; optional `Rails.cache` 15s guard (T-26-15 precedent) |
| Untrusted `fetchAllGroups` payload (null `subject`, unexpected keys, non-array body) treated as trusted | Tampering | `body.is_a?(Array)` guard → `Evolution::Errors::Unknown`; `subject.presence`; `announce == true`; `@g.us` suffix check; `upsert_all` runs no callbacks so no payload-driven code path |
| Read-timeout mid-response misread as "no groups" → mass deactivation | Tampering / Integrity | A timeout raises `Evolution::Errors::Unknown` **before** the upsert/deactivation runs — `#call` never reaches the `update_all`. Deactivation only runs after a successful parse. |
| `SSRF`-style abuse of the Evolution call | — | Not applicable: URL is `Evolution.base_url` + a fixed path; `instance_name` is server-derived (`livia_client_#{client.id}` `[VERIFIED: app/models/whatsapp_instance.rb:21]`), never user-supplied. |

**`security_block_on: high` check:** no HIGH-severity item identified. The one security-critical requirement (GRUPO-03 / SC5 cross-client scope) has a concrete, testable control (association finder + negative test). Planner MUST include the A×B negative test as a task.

---

## Sources

### Primary (HIGH confidence) — read this session
- `app/services/evolution/client.rb` — `request` signature & block (`:123-133`), per-call apikey override (`:127`), `fetch_instances` pattern (`:88-98`), `raise_for_status!` status→error map (`:151-172`), `classify_timeout` (`:178-188`), log line = method/path/status/duration only (`:143-144`).
- `app/services/evolution.rb` — `READ_TIMEOUT_FAST = 15` (`:60`), timeout constants (`:57-60`).
- `app/services/evolution/errors.rb` — `Transient`/`Permanent`/`Unknown`/`NotConnected`/`ConfigurationError` (`:9-20`).
- `app/models/whatsapp_instance.rb` — `connection_state` enum `{unpaired,awaiting_qr,connected,disconnected}` (`:14`), `encrypts :token` (`:12`), `evolution_name_for` (`:21`); **no `groups_synced_at`**.
- `db/schema.rb` — `whatsapp_instances` columns (`:224-240`); **no `whatsapp_groups` table**.
- `config/routes.rb` — admin `resources :clients` nesting (`:9-19`).
- `config/queue.yml` — single worker, `threads: 3`, `processes: 1`, `queues: "*"`.
- `config/recurring.yml` — only `clear_solid_queue_finished_jobs`; no group job.
- `app/jobs/application_job.rb` — bare; `retry_on`/`discard_on` commented out (repo's first real job is this one).
- `app/controllers/admin/base_controller.rb` — `require_authentication` + `Pagy::Backend` (`:1-5`).
- `app/controllers/admin/approvals_controller.rb` — `pagy(scope, limit: 25, params: …)` precedent (`:16`).
- `app/controllers/client/artes_controller.rb` — `@client.artes.find` + `rescue RecordNotFound` (`:9-14`).
- `app/controllers/admin/whatsapp_instances_controller.rb` — `set_client` scoping (`:95-97`), `pull_fresh_qr` `Rails.cache.write(unless_exist:, expires_in: 15.seconds)` throttle (`:105-112`).
- `app/views/admin/whatsapp_instances/_panel.html.erb` — actions row `flex items-center gap-3 mt-5 pt-4 border-t border-gray-100` (`:57`), `button_to` + `turbo_submits_with` (`:58-61`).
- `app/javascript/controllers/qr_pairing_controller.js` — `setInterval`/`disconnect` teardown, `Turbo.visit(..., {action:"replace"})`, POST-with-CSRF (the poller precedent).
- `config/initializers/rack_attack.rb` — `throttle` idiom + `webhooks/evolution_by_ip` (`:41`), `throttled_responder`.
- `app/helpers/admin/whatsapp_instances_helper.rb` — pt-BR label helper precedent.
- `Gemfile` / `Gemfile.lock` — `faraday 2.14.3`, `pagy 9.4.0`, `solid_queue 1.4.0`, `rails 8.1.3`, `turbo-rails 2.0.23`, `stimulus-rails 1.3.4`.
- `.planning/notes/evolution-contract.md` — `getParticipants` mandatory string (`:38`); timeouts + ~100s CF ceiling (`:67`); error envelope `response.message` string-or-array (`:31`); instance token valid on `:instanceName` routes (`:36`).
- `.planning/research/FEATURES.md` — `fetchAllGroups` 400-without-`getParticipants` (`:139`); response shape at tag 2.3.7 (`:143-160`); UI-relevant fields incl. `announce`/`isCommunity` (`:222-232`); `announce` semantics + no pre-check (`:241`); per-group `profilePicture` → slow (`:243`); JID stored verbatim (`§2`).
- `.planning/research/ARCHITECTURE.md` — `GroupSynchronizer` responsibility (`:261`), phase-27 scope row (`:582`), `whatsapp_groups` as cache-not-view + issue #2124 (`:143-160`), webhook may enqueue `SyncGroupsJob` on `open` (`:501`).
- `.planning/research/PITFALLS.md` — cross-client leak mechanics + prevention (`:364-396`), throttle admin WhatsApp paths (`:520`), list-groups-in-request anti-pattern (`:497`), stale session (`:181`).
- `.planning/phases/27-…/27-CONTEXT.md`, `27-UI-SPEC.md` — locked decisions, routes, copy, state maps.

### Secondary (MEDIUM confidence) — web, cross-checked
- [rails/rails PR #43003 — Set timestamps on insert_all/upsert_all](https://github.com/rails/rails/pull/43003) and [commit 3902322 — document `record_timestamps` option](https://github.com/rails/rails/commit/39023225d5010f6c93d545dad5f1decce6a8de73) — auto-timestamps for `upsert_all`, `record_timestamps` override.
- [Dosu — "Rails Upsert_all Gotchas"](https://app.dosu.dev/12c2f1a2-0216-4b5c-8130-cf69efaa2dc1/documents/492a78bf-0a16-41ea-bb17-3f5fa70578bf) — the "multiple assignments to same column" error when `updated_at` is in the payload on Rails 8.1+.
- [ActiveRecord::Relation#upsert_all — rails 8.0.2 API](https://www.rubydoc.info/docs/rails/ActiveRecord/Relation:upsert_all) — `unique_by` semantics, columns excluded from the update set.
- [lostisland/faraday — request.rb](https://github.com/lostisland/faraday/blob/main/lib/faraday/request.rb) and [Faraday::Connection.get 2.14.3 API](https://www.rubydoc.info/gems/faraday/Faraday/Connection.get) — per-request `req.params['k'] = v` in a GET block; `NestedParamsEncoder` default.

### Tertiary (LOW confidence) — flagged for UAT
- Exact `fetchAllGroups` JSON at the agency host (array shape, `id` key, pagination absence) — source-read at tag 2.3.7 only; confirm with one real sync against an operator-paired instance (Assumptions A1–A3).
- Instance-token authorization for `fetchAllGroups` (A2) — contract-implied, not round-tripped.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new packages; every version read from `Gemfile.lock` this session.
- Schema & upsert mechanics: HIGH — locked in CONTEXT.md; `upsert_all`/`update_all`/timestamp behavior cross-checked against Rails source PR + API docs.
- Evolution `fetch_groups` seam: HIGH for the call/error plumbing (read from `Evolution::Client` source); MEDIUM for the response body shape (source-read at tag 2.3.7, not yet hit against a live paired instance — UAT).
- Job pattern: MEDIUM-HIGH — no in-repo ActiveJob precedent, but the shape is a direct translation of the verified `Evolution::Errors` taxonomy; solid_queue 1.4.0 behavior is well-documented.
- Pitfalls: HIGH — documented Evolution issues (#2124) + this repo's own phase 25/26 precedents + verified Rails 8.1 upsert gotcha.
- Security: HIGH — the scope boundary reuses an established, testable project pattern.

**Research date:** 2026-08-30
**Valid until:** 2026-09-29 for the Rails/Faraday/upsert facts (stable). ~2026-09-13 for the Evolution response-shape assumptions — revisit after the first real operator-paired sync (UAT), which should promote A1–A3 from ASSUMED to VERIFIED.
