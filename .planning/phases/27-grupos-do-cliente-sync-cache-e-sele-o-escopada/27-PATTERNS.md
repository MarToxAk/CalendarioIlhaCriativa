# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada - Pattern Map

**Mapped:** 2026-08-30
**Files analyzed:** 19 new/modified
**Analogs found:** 18 / 19 (1 role-only — first ActiveJob in the repo)

Project has **no** root `CLAUDE.md` and **no** `.claude/skills` / `.agents/skills`. Conventions
are inferred from phase 25/26 code (verified this session).

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `db/migrate/XXXX_create_whatsapp_groups.rb` | migration | schema | `db/migrate/20260830130934_create_whatsapp_instances.rb` | exact |
| `db/migrate/XXXX_add_groups_sync_columns_to_whatsapp_instances.rb` | migration | schema (add_column) | `db/migrate/20260830130934_create_whatsapp_instances.rb` (column style) | role-match |
| `app/models/whatsapp_group.rb` | model | CRUD / read-cache | `app/models/whatsapp_instance.rb` (enum, `belongs_to`, label method) + `app/models/arte.rb` (enum `prefix:`) | exact |
| `app/models/whatsapp_instance.rb` (modify) | model | CRUD | self (add `has_many` + `enum` alongside existing `enum :connection_state`) | exact |
| `app/models/client.rb` (modify) | model | association | self (`has_many :artes`, `has_one :whatsapp_instance` already present) | exact |
| `app/services/evolution/client.rb` (modify — `fetch_groups` + `query:` in `#request`) | service | request-response (HTTP GET) | same file: `fetch_instances` (`:88-98`), `connection_state` (`:103-111`), `#request` (`:123-145`) | exact |
| `app/services/whatsapp/group_synchronizer.rb` (new PORO) | service | batch / transform + persist | `app/services/evolution/instance_provisioner.rb` | exact |
| `app/jobs/whatsapp/sync_groups_job.rb` (new — FIRST ActiveJob) | job | event-driven / background | `app/jobs/application_job.rb` (bare) + RESEARCH §Code Ex. 4 | role-match (no retry precedent in repo) |
| `app/controllers/admin/whatsapp_groups_controller.rb` (new) | controller | request-response + JSON | `app/controllers/admin/whatsapp_instances_controller.rb` (`set_client`, JSON action, guards) + `app/controllers/admin/approvals_controller.rb` (Pagy) + `app/controllers/client/artes_controller.rb` (scoped finder + rescue) | exact |
| `config/routes.rb` (modify) | route | — | `config/routes.rb:13-18` (`resource :whatsapp_instance do post :verify ... end`) | exact |
| `config/initializers/rack_attack.rb` (modify) | config | — | `rack_attack.rb:41` `webhooks/evolution_by_ip` throttle | exact |
| `app/javascript/controllers/group_sync_controller.js` (new) | Stimulus controller | polling | `app/javascript/controllers/qr_pairing_controller.js` | exact |
| `app/views/admin/whatsapp_groups/index.html.erb` (new) | view | — | `app/views/admin/approvals/index.html.erb` (Pagy list + empty state) + `app/views/admin/whatsapp_instances/_panel.html.erb` (card shell) | exact |
| `app/views/admin/whatsapp_groups/_picker.html.erb` (new, reusable — phase 28 consumes verbatim) | view partial | — | `_panel.html.erb` (fieldset-in-card) + 27-UI-SPEC "Layout" markup | role-match (new contract) |
| `app/views/admin/whatsapp_groups/_group_row.html.erb` (new) | view partial | — | 27-UI-SPEC row markup + `app/views/admin/whatsapp_instances/_connection_badge.html.erb` (pill shape) | exact |
| `app/views/admin/whatsapp_instances/_panel.html.erb` (modify — "Sincronizar grupos" btn + "Ver grupos" link) | view partial | — | self, actions row `:57-61` (`button_to` + `turbo_submits_with`) | exact |
| `app/helpers/admin/whatsapp_groups_helper.rb` (new) | helper | — | `app/helpers/admin/whatsapp_instances_helper.rb` | exact |
| `test/models/whatsapp_group_test.rb` (new) | test | — | `test/models/whatsapp_instance_test.rb` | exact |
| `test/services/evolution/client_test.rb` (modify — `fetch_groups` cases) | test | — | self (`Faraday::Adapter::Test::Stubs`, `stubbed_connection`) | exact |
| `test/controllers/admin/whatsapp_groups_controller_test.rb` (new — incl. A×B cross-client 404) | test | — | `test/controllers/admin/whatsapp_instances_controller_test.rb` (`sign_in_as`, `Evolution::Client.stub`) | exact |
| `test/services/whatsapp/group_synchronizer_test.rb` (new) | test | — | `test/services/evolution/client_test.rb` (DI fake client pattern) | role-match |
| `test/jobs/whatsapp/sync_groups_job_test.rb` (new — first job test, `test/jobs/` dir does not exist yet) | test | — | none (first) — model on ActiveJob::TestCase | none |

---

## Pattern Assignments

### `db/migrate/XXXX_create_whatsapp_groups.rb` (migration, schema)

**Analog:** `db/migrate/20260830130934_create_whatsapp_instances.rb` (full file, 20 lines)

**Copy this structure verbatim** (analog `:1-19`):
```ruby
class CreateWhatsappInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_instances do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.string   :instance_name,     null: false
      t.integer  :connection_state,  null: false, default: 0
      t.datetime :last_checked_at
      t.timestamps
    end
    add_index :whatsapp_instances, :instance_name, unique: true
  end
end
```
Apply to phase 27 (from RESEARCH §Code Ex. 5): `t.references :whatsapp_instance, null: false, foreign_key: true`
(NO `index: { unique: true }` here — many groups per instance), `t.string :remote_jid, null: false`,
`t.string :subject` (nullable), `t.boolean :announce, null: false, default: false`,
`t.boolean :active, null: false, default: true`, `t.datetime :synced_at`, `t.timestamps`.
Then `add_index :whatsapp_groups, [:whatsapp_instance_id, :remote_jid], unique: true` (the `upsert_all`
conflict target) + `add_index :whatsapp_groups, [:whatsapp_instance_id, :active]`.

**Second migration** — column style from the same analog (`:8-13`, `t.integer ... null: false, default: 0`
for enums, `t.datetime` bare): `add_column :whatsapp_instances, :groups_synced_at, :datetime`;
`add_column :whatsapp_instances, :groups_sync_state, :integer, null: false, default: 0`;
`add_column :whatsapp_instances, :groups_sync_error, :string`.

---

### `app/models/whatsapp_group.rb` (model, read-cache)

**Analog:** `app/models/whatsapp_instance.rb` (`:10-14`, `:57-64`) + `app/models/arte.rb` (`:24` enum prefix)

**Imports / class shell** (`whatsapp_instance.rb:1-14`):
```ruby
# frozen_string_literal: true

class WhatsappInstance < ApplicationRecord
  belongs_to :client
  encrypts :token
  enum :connection_state, { unpaired: 0, awaiting_qr: 1, connected: 2, disconnected: 3 }
  enum :origin,           { created_by_app: 0, adopted_existing: 1 }, prefix: :origin
```

**Label-method pattern to mirror for `display_name`** (`whatsapp_instance.rb:57-64` — a pure method,
`case` over a string enum, pt-BR literals, no DB access):
```ruby
def connection_state_label
  case connection_state
  when "unpaired" then "Aguardando criação"
  ...
  end
end
```

**Phase 27 model** (RESEARCH §Code Ex. 4): `belongs_to :whatsapp_instance`;
`scope :active_groups, -> { where(active: true) }` + `:inactive_groups`;
`def display_name; subject.presence || "Grupo sem nome (#{remote_jid.to_s.first(12)}…)"; end`
(U+2026 single-char ellipsis — 27-UI-SPEC copy). **No `before_save`** — `upsert_all` skips callbacks
(RESEARCH Pitfall 3), so the fallback MUST be a plain method.

**`whatsapp_instance.rb` additions** — place beside the existing `enum :connection_state`:
```ruby
has_many :whatsapp_groups, dependent: :destroy
enum :groups_sync_state, { idle: 0, syncing: 1, error: 2 }, prefix: :groups_sync
```
(`prefix:` mirrors the existing `enum :origin, ..., prefix: :origin` on `:15` → predicates
`groups_sync_syncing?` used by `sync_status`.)

**`client.rb` addition** (`client.rb:5-6` already has `has_many :artes` / `has_one :whatsapp_instance`):
```ruby
has_many :whatsapp_groups, through: :whatsapp_instance
```

---

### `app/services/evolution/client.rb` (service, request-response) — MODIFY

**Analog:** same file — `fetch_instances` (`:88-98`), `connection_state` (`:103-111`), `#request` (`:123-145`)

**`fetch_instances` — the method to mirror** (`:88-98`):
```ruby
def fetch_instances(api_key: Evolution.global_api_key)
  body = request(:get, "/instance/fetchInstances",
                 api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST).body
  raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Array)

  body
end
```

**New `fetch_groups`** (RESEARCH §Code Ex. 1) — public class method inside `class << self`, after
`connection_state`. Same WR-07 guard (`unless body.is_a?(Array)` → `Evolution::Errors::Unknown`),
`read_timeout: Evolution::READ_TIMEOUT_FAST` (constant at `app/services/evolution.rb:63`, comment
already names `fetchAllGroups`), `api_key:` = **instance token** (`whatsapp_instance.token`, not the
global key), `query: { "getParticipants" => "false" }` (mandatory string — a 400 → `Permanent`).

**`#request` change — 3 lines** (`:123-133`): add `query: nil` kwarg to the signature; inside the block,
after `req.headers["apikey"] = api_key` (`:127`), add `req.params.update(query) if query`. Keep the
`rescue`/`ensure` (`:136-145`) untouched — logging is method/path/status/ms only (`:143-144`), never body.

---

### `app/services/whatsapp/group_synchronizer.rb` (service, batch + persist) — NEW PORO

**Analog:** `app/services/evolution/instance_provisioner.rb` (full file)

**Copy from the analog:**
- `# frozen_string_literal: true` + `module` wrapper (`:1-3`) → use `module Whatsapp` (Zeitwerk autoloads
  `app/services/whatsapp/`, no config). Namespace rationale: `Evolution::` = pure HTTP transport only;
  orchestration+persistence lives under `Whatsapp::`.
- `Result = Struct.new(:instance, :adopted, :qr_base64, keyword_init: true)` (`:11`) → phase 27:
  `Result = Struct.new(:ok, :count, :reason, keyword_init: true)`.
- **DI seam for tests** (`:25-29`):
  ```ruby
  def initialize(client, client_api: Evolution::Client)
    @client = client
    @api = client_api
  end
  ```
  → phase 27: `def initialize(instance, client: Evolution::Client)`.
- **Silent-rescue of the Evolution taxonomy** (`:90-92`) — the exact rescue tuple to reuse where a
  failure must not propagate:
  ```ruby
  rescue Evolution::Errors::Transient, Evolution::Errors::Unknown, Evolution::Errors::Permanent, Evolution::Errors::ConfigurationError
    nil
  ```
- **`find_or_initialize_by` + `assign_attributes` + `save!`** persist shape (`:66-76`) — but phase 27
  uses `WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?`
  instead (RESEARCH §Code Ex. 3 / Pattern 2).

**Phase-27 core logic** (RESEARCH §Code Ex. 3, verbatim intent):
1. `return` early with `Result.new(ok: false, reason: :not_connected)` + `@instance.update!(groups_sync_state: :error, groups_sync_error: "not_connected")` unless `@instance.connected?` (re-check — `connection_state` is a cached column; PITFALLS §7).
2. `batch_started_at = Time.current` — **captured once**, first line after the guard.
3. `raw = @api.fetch_groups(@instance.instance_name, api_key: @instance.token)`.
4. `rows = Array(raw).filter_map { |g| row_for(g, batch_started_at) }` — `row_for` returns a hash with
   exactly `whatsapp_instance_id, remote_jid, subject, announce, active, synced_at` (NO
   `created_at`/`updated_at` — Rails 8.1 auto-injects → "multiple assignments" error otherwise,
   RESEARCH Pitfall 3). `remote_jid: g["id"].to_s` verbatim, skip unless `.end_with?("@g.us")`.
   `subject: g["subject"].presence`, `announce: g["announce"] == true`.
5. `WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?`
   (`upsert_all([])` raises — Pitfall 4).
6. **Deactivation pass (GRUPO-05)** — scoped through the association, strict `<`, explicit `updated_at`:
   ```ruby
   @instance.whatsapp_groups.where(active: true)
            .where("synced_at < ?", batch_started_at)
            .update_all(active: false, updated_at: Time.current)
   ```
   Never `delete`/`destroy`. Runs even when `rows` was empty.
7. `@instance.update!(groups_synced_at: batch_started_at, groups_sync_state: :idle, groups_sync_error: nil)`.

**Error handling:** do NOT rescue the Evolution taxonomy inside `#call` for the success path — let
`Evolution::Errors::*` propagate to the job (which owns retry/discard). A read timeout raises
**before** step 5/6, so a truncated response never triggers mass-deactivation (RESEARCH Security /
"Read-timeout mid-response").

---

### `app/jobs/whatsapp/sync_groups_job.rb` (job) — NEW, first ActiveJob in repo

**Analog:** `app/jobs/application_job.rb` (bare — `retry_on`/`discard_on` are commented out `:3`,`:6`).
No in-repo retry precedent — **this file sets the pattern.** Follow RESEARCH §Code Ex. 4.

**Shape:**
```ruby
class Whatsapp::SyncGroupsJob < ApplicationJob
  queue_as :default   # config/queue.yml: single worker, queues: "*", threads: 3

  retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3
  retry_on Evolution::Errors::Unknown,   wait: 30.seconds, attempts: 3   # GET is idempotent

  discard_on(Evolution::Errors::Permanent)         { |job, _| mark_error(job, "transient") }
  discard_on(Evolution::Errors::NotConnected)       { |job, _| mark_error(job, "not_connected") }
  discard_on(Evolution::Errors::ConfigurationError) { |job, _| mark_error(job, "transient") }
  discard_on(ActiveJob::DeserializationError)       # instance deleted mid-flight

  def perform(instance)
    Whatsapp::GroupSynchronizer.new(instance).call
  end

  def self.mark_error(job, code)
    inst = job.arguments.first
    inst.update!(groups_sync_state: :error, groups_sync_error: code) if inst.is_a?(WhatsappInstance)
  end
end
```
- Taxonomy classes come from `app/services/evolution/errors.rb` (`Transient`/`Permanent`/`Unknown`/
  `NotConnected`/`ConfigurationError`) — same set the controllers rescue (`whatsapp_instances_controller.rb:7`,`:55`).
- **Argument safety:** pass the `WhatsappInstance` record (GlobalID serialises class+id only; the
  `encrypts :token` value never enters job args). Never pass `instance.token` or `instance_name`.
- Dev: the solid_queue worker must be running (`bin/jobs` / `bin/dev`) or the job sits queued and the
  JS poller hits its cap.

---

### `app/controllers/admin/whatsapp_groups_controller.rb` (controller) — NEW

**Analogs:** `admin/whatsapp_instances_controller.rb` (guards, `set_client`, JSON action),
`admin/approvals_controller.rb` (Pagy), `client/artes_controller.rb` (scoped finder + rescue).

**Class shell + `set_client`** (`whatsapp_instances_controller.rb:1-2`, `:95-97`):
```ruby
class Admin::WhatsappInstancesController < Admin::BaseController
  before_action :set_client
  ...
  def set_client
    @client = Client.find(params[:client_id])
  end
```
→ phase 27: `< Admin::BaseController` (gives `require_authentication` + `Pagy::Backend`, see
`admin/base_controller.rb:3-4`), `before_action :set_client, :set_instance`.
`def set_instance = @instance = @client.whatsapp_instance`.

**Scoped-finder pattern (GRUPO-03 / SC5 — the phase's canonical security proof)** —
`client/artes_controller.rb:9-14`:
```ruby
def set_arte
  @arte = @client.artes.includes(:approval_responses).find(params[:id])
rescue ActiveRecord::RecordNotFound
  redirect_to client_root_path(token: @client.access_token), alert: "Arte não encontrada."
end
```
→ phase 27: **every** single-group read starts from
`@client.whatsapp_instance.whatsapp_groups.find(params[:id])` → `RecordNotFound` → 404 for a
cross-client id, no existence leak. Never `WhatsappGroup.find`. Add `show` to the route (RESEARCH
Open Q2) so this has a real HTTP surface + an automated A×B test.

**Guard + enqueue pattern for `#sync`** — mirror `whatsapp_instances_controller.rb#verify` (`:35-38`)
early-return guard:
```ruby
inst = @client.whatsapp_instance
return redirect_to(admin_client_path(@client),
  alert: "Este cliente ainda não tem uma instância de WhatsApp.") if inst.nil?
```
→ phase 27 `#sync`: guard `@instance.nil? || !@instance.connected?` →
`redirect_to admin_client_whatsapp_groups_path(@client), alert: "A instância está desconectada. Reconecte o número antes de sincronizar os grupos."` (does NOT enqueue).
Else: `@instance.update!(groups_sync_state: :syncing, groups_sync_error: nil)` →
`Whatsapp::SyncGroupsJob.perform_later(@instance)` →
`redirect_to ..., notice: "Sincronização iniciada. Os grupos aparecem aqui em instantes."`

**Optional anti-spam cache guard** — `whatsapp_instances_controller.rb#pull_fresh_qr` (`:105-112`):
```ruby
return unless Rails.cache.write("wa_qr_pull_#{inst.id}", true, unless_exist: true, expires_in: 15.seconds)
```
→ phase 27: `Rails.cache.write("wa_groups_sync_#{@instance.id}", true, unless_exist: true, expires_in: 15.seconds)` before enqueue.

**JSON action pattern** — `whatsapp_instances_controller.rb#refresh_qr` (`:67-71`) is the precedent for
`render json: { ... }` from an admin controller. Phase 27 `#sync_status` (RESEARCH §Code Ex. 7):
`render json: { syncing: @instance&.groups_sync_syncing? || false, synced_at: @instance&.groups_synced_at&.iso8601, error: @instance&.groups_sync_error, count: @instance ? @instance.whatsapp_groups.where(active: true).count : 0 }`.
NO group names/JIDs, no inactive count in the payload (RESEARCH Security V13).

**Pagy in `#index`** — `approvals_controller.rb:16`:
```ruby
@pagy, @approval_responses = pagy(scope, limit: 25, params: {...}.compact_blank)
```
→ phase 27: `@pagy, @active_groups = pagy(@instance.whatsapp_groups.where(active: true).order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid), limit: 25)`.
`@index` reads **only** the cache — never `Evolution::Client` (GRUPO-02).

---

### `config/routes.rb` (route) — MODIFY

**Analog:** `config/routes.rb:13-18` — the nested `whatsapp_instance` block with custom verbs:
```ruby
resource :whatsapp_instance, only: [ :create ], controller: "whatsapp_instances" do
  post :refresh_qr
  post :verify
  post :adopt
  post :reconnect
end
```
→ phase 27, inside the same `resources :clients do ... end` (admin namespace, `:9`):
```ruby
resources :whatsapp_groups, only: [ :index, :show ], controller: "whatsapp_groups" do
  collection do
    post :sync
    get  :sync_status
  end
end
```
Helpers: `admin_client_whatsapp_groups_path(client)`, `sync_admin_client_whatsapp_groups_path(client)`,
`sync_status_admin_client_whatsapp_groups_path(client)`.

---

### `config/initializers/rack_attack.rb` (config) — MODIFY

**Analog:** `rack_attack.rb:41-43`:
```ruby
throttle("webhooks/evolution_by_ip", limit: 120, period: 60) do |req|
  req.ip if req.path == "/webhooks/evolution" && req.post?
end
```
→ phase 27 (RESEARCH §Code Ex. 8): add beside it —
```ruby
throttle("admin/whatsapp_groups_sync_by_ip", limit: 6, period: 60) do |req|
  req.ip if req.post? && req.path.match?(%r{\A/admin/clients/\d+/whatsapp_groups/sync\z})
end
```
`throttled_responder` (`:45-53`) already returns an HTML 429 for non-`/api/` paths — no change needed.

---

### `app/javascript/controllers/group_sync_controller.js` (Stimulus poller) — NEW

**Analog:** `app/javascript/controllers/qr_pairing_controller.js` (full file, 60 lines)

**Copy verbatim:** the import (`:1`), `connect()` → `this.cycles = 0` + `setInterval` (`:16-20`),
`disconnect() { clearInterval(this.timer) }` (`:22-24` — timer MUST NOT survive a Turbo nav),
the try/catch with silent network-failure (`:29-53`), the completion branch
`clearInterval(this.timer); Turbo.visit(window.location.href, { action: "replace" })` (`:42-46`),
the cap branch `if (this.cycles >= this.MAX_CYCLES) { clearInterval(this.timer); ... }` (`:55-58`).

**Differences for phase 27** (RESEARCH Pattern 7):
- `static values = { statusUrl: String, since: String }` (analog uses `{ url: String }`).
- `INTERVAL_MS = 3000`, `MAX_CYCLES = 20` (analog: `20000` / `6`).
- The fetch is a **plain GET** with `headers: { Accept: "application/json" }` and **NO
  `X-CSRF-Token`** — `sync_status` has no side effect (analog POSTs + sends CSRF because `refresh_qr`
  mutates, `:33-39`).
- Completion test: `data.synced_at` advanced past `this.sinceValue` → success toast
  `"Grupos sincronizados."` then `Turbo.visit`. `data.error` non-null → error toast + reveal inline
  error box. Cap reached → show "A sincronização está demorando. Atualize a página…" note + `Atualizar` link.
- **Never** `console.log` a group `subject`/`remote_jid`/payload (INFRA-04).

---

### Views

**`app/views/admin/whatsapp_groups/index.html.erb`** — analogs:
- `app/views/admin/approvals/index.html.erb`: `content_for(:page_title)` (`:1`),
  `<h1 class="text-2xl font-semibold text-slate-900 mb-6">` (`:3`), the `py-16 text-center` empty-state
  block with muted SVG + heading + body (`:22-33`), and the centered pagy nav
  `<div class="flex justify-center mt-6"><%= pagy_nav(@pagy) %></div>` (`:85-88`).
- `app/views/admin/whatsapp_instances/_panel.html.erb`: the card shell
  `<div class="bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl">` (`:6`), the
  section `<h2 class="text-sm font-semibold text-slate-900 border-b border-gray-100 pb-3 mb-4">` (`:7`),
  the `button_to` primary CTA class string (`:16-18`), and the amber banner
  `class="bg-[#FFFBEB] border border-[#F59E0B]/20 text-amber-800 text-sm rounded-lg p-3 leading-relaxed"` (`:44`).
- Renders `render "admin/whatsapp_groups/picker", client: @client, selected_ids: [], field_name: nil`.
- Full state/copy map is in `27-UI-SPEC.md` (empty states 1-3, blocked state, error states).

**`app/views/admin/whatsapp_groups/_picker.html.erb`** (reusable — phase 28 consumes verbatim):
locals `client:` (required), `selected_ids:` (default `[]`), `field_name:` (default `nil`). Option set is
**always** `client.whatsapp_instance.whatsapp_groups.where(active: true)`, server-resolved. `field_name:
nil` → checkboxes `disabled`, no `name` attr. Empty → the "Nenhum grupo ativo para selecionar…" line,
not an empty `<fieldset>`. Row rendered via `_group_row`. Markup skeleton in `27-UI-SPEC.md` "Layout".

**`app/views/admin/whatsapp_groups/_group_row.html.erb`** — analog:
`app/views/admin/whatsapp_instances/_connection_badge.html.erb` for the pill shape
`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border` + `●` glyph
(`:12`,`:16`,`:20`). The amber `announce` pill reuses `bg-[#FFFBEB] text-amber-800 border-[#F59E0B]/20`
(same as the `awaiting_qr` badge, `_connection_badge.html.erb:16`); the slate `Inativo` pill reuses
`bg-slate-100 text-slate-600 border-slate-200` (`:8`,`:24`). Full row markup (checkbox +
`display_name` + inline badge, `truncate`, `title=`) is in `27-UI-SPEC.md` "Row markup".

**`app/views/admin/whatsapp_instances/_panel.html.erb`** (MODIFY) — the actions row `:57-61`:
```erb
<div class="flex items-center gap-3 mt-5 pt-4 border-t border-gray-100">
  <%= button_to "Forçar verificação", verify_admin_client_whatsapp_instance_path(client),
        method: :post,
        data: { turbo_submits_with: "Verificando…" },
        class: "inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors" %>
```
→ add a `button_to "Sincronizar grupos", sync_admin_client_whatsapp_groups_path(client), method: :post,
data: { turbo_submits_with: "Sincronizando…" }`, `disabled` unless `whatsapp_instance&.connected?`, plus a
`link_to "Ver grupos", admin_client_whatsapp_groups_path(client)` (`text-[#0F7949] hover:underline`, with
count when known). This block is only rendered inside the `else` (instance present) branch — same as the
existing buttons. Panel is rendered from `app/views/admin/clients/show.html.erb:137`.

---

### `app/helpers/admin/whatsapp_groups_helper.rb` (helper) — NEW

**Analog:** `app/helpers/admin/whatsapp_instances_helper.rb` (full file)

Copy `# frozen_string_literal: true` + `module Admin::WhatsappInstancesHelper` shell and the
`wa_last_checked_label(instance)` shape (`:9-20`) — `return "—" if ... blank?`, then a relative pt-BR
string. Phase 27: `wa_groups_synced_label(instance)` → 27-UI-SPEC locks an **absolute** format
`"Sincronizado pela última vez em {DD/MM/AAAA às HH:MM}"` (America/São Paulo, INFRA-03), so use
`instance.groups_synced_at.strftime("%d/%m/%Y às %H:%M")` with the blank guard.

---

### Tests

**`test/models/whatsapp_group_test.rb`** — analog `test/models/whatsapp_instance_test.rb`:
`require "test_helper"`, `< ActiveSupport::TestCase`, `setup` builds a `Client.create!(name:, password:,
password_confirmation:)` (`:4-10`), one `test "..."` per behaviour. Cover: `display_name` returns
`subject` when present; `display_name` fallback (`"Grupo sem nome (…)"`, single-char `…`) when
`subject` nil/blank; `active_groups`/`inactive_groups` scopes.

**`test/services/evolution/client_test.rb`** (MODIFY) — same file's `Faraday::Adapter::Test::Stubs`
harness (`:11-24` `stubbed_connection` / `response_for`) and `raise_for_status!` assertion helper
(`:40-46`). Add: `fetch_groups` returns the array on 200; a 200 with a non-Array body raises
`Evolution::Errors::Unknown`; a 400 (missing `getParticipants`) surfaces as `Evolution::Errors::Permanent`;
`#request` passes `getParticipants=false` in the query string.

**`test/controllers/admin/whatsapp_groups_controller_test.rb`** — analog
`test/controllers/admin/whatsapp_instances_controller_test.rb`: `< ActionDispatch::IntegrationTest`,
`ADMIN_EMAIL`/`ADMIN_PASSWORD` consts + `User.find_or_create_by!` + `sign_in_as(@admin)` (`:5-19`),
`Evolution::Client.stub(:method, ->(**) { FAKE })` for isolation (`:28-30`), `assert_redirected_to` +
`flash[:notice]/[:alert]` assertions. **Add the canonical A×B negative test:** client A signed in,
`get admin_client_whatsapp_group_path(client_a, group_belonging_to_client_b)` → 404 / `RecordNotFound`,
no body leak. Also: `#sync` with a disconnected instance does not enqueue (assert
`Whatsapp::SyncGroupsJob` not enqueued) and redirects with the alert; `#sync_status` returns the
4-key JSON.

**`test/services/whatsapp/group_synchronizer_test.rb`** — no direct analog; use the DI-fake-client
idea from `instance_provisioner`'s `client_api:` seam. Inject a fake responding to `fetch_groups`.
Cover: upsert inserts new rows; re-run with an unchanged list is a no-op on `active`; a group absent
from the 2nd batch flips to `active: false` (never deleted); empty array → all deactivated + stamp,
no `upsert_all` crash; not-connected instance → early return + `groups_sync_error: "not_connected"`,
no HTTP call.

**`test/jobs/whatsapp/sync_groups_job_test.rb`** — `test/jobs/` does not exist yet (first job test).
Model on `ActiveJob::TestCase`; assert `retry_on`/`discard_on` route the `Evolution::Errors` taxonomy
to the right outcome and that `mark_error` sets `groups_sync_state: :error` with the right code.

> **Test-execution caveat (MEMORY `test_db_permission.md`):** `bin/rails test` does not run in this
> environment (test DB owned by another OS user). Verify by inspection + `bin/rails runner` with a
> stubbed Faraday connection, as phases 25/26 did. Flag the execution gap in the phase verification.

---

## Shared Patterns

### Per-client scope enforcement (GRUPO-03 / SC5 — security-critical)
**Source:** `app/controllers/client/artes_controller.rb:9-14` (`@client.artes.find` + `rescue
ActiveRecord::RecordNotFound`); `app/controllers/admin/whatsapp_instances_controller.rb:95-97`
(`set_client` from `params[:client_id]` only).
**Apply to:** every action and finder in `Admin::WhatsappGroupsController`, the `_picker` partial, and
any phase-28 code reusing the picker.
**Rule:** all group reads start from `@client.whatsapp_instance.whatsapp_groups`. Never
`WhatsappGroup.find`/`.where`. Cross-client id → `RecordNotFound` → 404, no existence disclosure.

### Evolution error taxonomy → control flow
**Source:** `app/services/evolution/errors.rb` (`Transient` / `Permanent` / `Unknown` / `NotConnected`
/ `ConfigurationError`); rescue tuple at `admin/whatsapp_instances_controller.rb:7`,`:55-58` and the
silent-rescue at `evolution/instance_provisioner.rb:90-92`.
**Apply to:** `Evolution::Client.fetch_groups` (raises these), `Whatsapp::SyncGroupsJob`
(`retry_on` Transient/Unknown, `discard_on` Permanent/NotConnected/ConfigurationError),
`Whatsapp::GroupSynchronizer` (lets them propagate on the success path).

### Secret handling (INFRA-04)
**Source:** `app/models/whatsapp_instance.rb:12` (`encrypts :token`); `Evolution::Client` logs
method/path/status/ms only (`client.rb:143-144`); `config/initializers/filter_parameter_logging.rb`
already covers `token`/`apikey`/`hash` (phase 26).
**Apply to:** `GroupSynchronizer` (never log the token or the raw payload), `group_sync_controller.js`
(never `console.log` group data), `SyncGroupsJob` (pass the record, never `instance.token` — GlobalID
serialises id only), `sync_status` JSON (no group names/JIDs).

### Background enqueue + Stimulus poll for completion
**Source:** `app/controllers/admin/whatsapp_instances_controller.rb:67-71` (`refresh_qr` JSON action)
+ `app/javascript/controllers/qr_pairing_controller.js` (poll + `disconnect` teardown +
`Turbo.visit(..., {action:"replace"})`).
**Apply to:** `#sync` (enqueue + redirect with notice) / `#sync_status` (JSON) / `group_sync_controller.js`.

### Anti-spam on WhatsApp-facing POSTs
**Source:** `config/initializers/rack_attack.rb:41` (throttle idiom) +
`admin/whatsapp_instances_controller.rb:105-112` (`Rails.cache.write(unless_exist:, expires_in:
15.seconds)`) + `_panel.html.erb:60` (`data: { turbo_submits_with: ... }`).
**Apply to:** the `POST .../whatsapp_groups/sync` route (Rack::Attack rule + optional cache guard +
`turbo_submits_with` on the button).

### pt-BR label helpers next to the model, not `strftime` in ERB
**Source:** `app/helpers/admin/whatsapp_instances_helper.rb` + `WhatsappInstance#connection_state_label`.
**Apply to:** `Admin::WhatsappGroupsHelper#wa_groups_synced_label`; `WhatsappGroup#display_name`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `app/jobs/whatsapp/sync_groups_job.rb` | job | background | First real ActiveJob in the repo — `ApplicationJob` is bare (`retry_on`/`discard_on` commented out). Pattern is set here from RESEARCH §Code Ex. 4 (direct translation of the `Evolution::Errors` taxonomy). |
| `test/jobs/whatsapp/sync_groups_job_test.rb` | test | — | `test/jobs/` directory does not exist. First job test. Model on `ActiveJob::TestCase`. |
| `app/views/admin/whatsapp_groups/_picker.html.erb` | view partial | — | No existing reusable form-component partial with a `field_name`/`selected_ids` contract. Closest structural analog is the fieldset-in-card in `_panel.html.erb`; the locals contract is new (defined by 27-UI-SPEC Pattern 6 for phase 28 reuse). |

---

## Metadata

**Analog search scope:** `app/controllers/admin/`, `app/controllers/client/`, `app/services/evolution/`,
`app/models/`, `app/jobs/`, `app/helpers/admin/`, `app/javascript/controllers/`,
`app/views/admin/{approvals,whatsapp_instances}/`, `config/routes.rb`,
`config/initializers/rack_attack.rb`, `db/migrate/`, `test/{models,services,controllers}/`.
**Files scanned:** ~28.
**Pattern extraction date:** 2026-08-30
