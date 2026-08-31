# Phase 31: Instância WhatsApp Compartilhada entre Clientes - Pattern Map

**Mapped:** 2026-08-31
**Files analyzed:** 13 (7 modified, 3 new, 3 test)
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `db/migrate/XXXX_deuniqueify_whatsapp_instance_name.rb` (new) | migration | schema/index | `db/migrate/20260830130934_create_whatsapp_instances.rb` (line 18) + `db/migrate/20260830184901_add_groups_sync_columns_to_whatsapp_instances.rb` | role-match (no drop-index migration exists yet) |
| `app/models/whatsapp_instance.rb` (modified) | model | CRUD / lookup | itself — extend existing enum + add scopes/class methods | exact |
| `app/services/evolution/instance_provisioner.rb` (modified: `#reuse`) | service (PORO) | transform / local-copy | `#adopt` / `#persist_new` in the same file | exact |
| `app/services/whatsapp/group_synchronizer.rb` (modified: sibling fan-out) | service (PORO) | batch / fan-out | itself — `#call` loop body (lines 29-48) | exact |
| `app/jobs/whatsapp/send_to_group_job.rb` (modified: `limits_concurrency` key) | job | event-driven / concurrency-gate | itself — `limits_concurrency` block (lines 57-61) | exact |
| `app/controllers/webhooks/evolution_controller.rb` (modified: fan-out) | controller | webhook / request-response | itself — `#create` + `apply_event` (lines 12-20, 43-77) | exact |
| `app/controllers/admin/whatsapp_instances_controller.rb` (modified: `#reuse` action) | controller | request-response | `#adopt` / `#verify` in the same file (lines 16-24, 35-59) | exact |
| `app/controllers/admin/clients_controller.rb` (modified: `#show` collection) | controller | request-response | `#show` in the same file (lines 8-17) | exact |
| `config/routes.rb` (modified: `post :reuse`) | route/config | — | `resource :whatsapp_instance` block (lines 13-18) | exact |
| `app/views/admin/whatsapp_instances/_panel.html.erb` (modified: toggle in `nil?` branch) | view (ERB) | form / conditional-fields | `app/views/admin/artes/_form.html.erb` (lines 4, 36-64) | role-match |
| `app/javascript/controllers/whatsapp_provision_toggle_controller.js` (new) | stimulus controller | client-side toggle | `app/javascript/controllers/media_type_toggle_controller.js` | exact |
| `test/jobs/whatsapp/send_to_group_job_test.rb` (modified: assertion line 316-319) | test | assertion update | test at lines 311-338 in same file | exact |
| `test/services/whatsapp/group_synchronizer_test.rb` (modified: regression + sibling test) | test | service test | `FakeEvolutionClient` + tests (a)/(b)/(c) lines 6-70 in same file | exact |

---

## Pattern Assignments

### `db/migrate/XXXX_deuniqueify_whatsapp_instance_name.rb` (migration, index)

**Analog:** `db/migrate/20260830130934_create_whatsapp_instances.rb` line 18 (`add_index :whatsapp_instances, :instance_name, unique: true`).

**Pattern to copy** — plain `ActiveRecord::Migration[8.1]` with `def change`, no data backfill (matches `add_groups_sync_columns` migration style):

```ruby
class DeuniqueifyWhatsappInstanceName < ActiveRecord::Migration[8.1]
  def change
    remove_index :whatsapp_instances, :instance_name          # drops the unique index
    add_index    :whatsapp_instances, :instance_name          # recreate NON-unique — where(instance_name:) / find_by still indexed
  end
end
```

Note: the `client_id` unique index (`t.references :client, ... index: { unique: true }`, line 4 of the create migration) is untouched — `Client has_one` stays enforced at DB level.

---

### `app/models/whatsapp_instance.rb` (model)

**Analog:** itself (lines 15-16, 28, 33-35).

**Enum extension** (line 16) — add third value, code-only (no migration, integer enum):

```ruby
enum :origin, { created_by_app: 0, adopted_existing: 1, reused_sibling: 2 }, prefix: :origin
```

**Scope + class-method pattern** — follows the existing `self.evolution_name_for` / `self.webhook_secret_for` style (pure class methods, lines 28-35). Add:

```ruby
scope :connected, -> { where(connection_state: :connected) }

# sibling rows sharing the same physical connection (includes self when called on an instance)
def siblings = self.class.where(instance_name: instance_name)
def shared? = self.class.where(instance_name: instance_name).where.not(id: id).exists?

# for the D-06 <select>; keeps GROUP BY out of the ERB
def self.shareable_targets(excluding_client_id:)
  connected.where.not(client_id: excluding_client_id)
           .includes(:client)
           .group_by(&:instance_name)
           .map { |name, rows| { instance_name: name, client_names: rows.map { |r| r.client.name } } }
end
```

---

### `app/services/evolution/instance_provisioner.rb` (service — new `#reuse`)

**Analog:** `#persist_new` (lines 94-105) and `#adopt` (lines 59-79) in the same file.

**Result struct is already defined** (line 11): `Result = Struct.new(:instance, :adopted, :qr_base64, keyword_init: true)`.

**Copy the `WhatsappInstance.create!(...)` shape from `#persist_new` (lines 95-103)**, but source every field from the sibling and do NO network I/O (contrast with `#call` which hits `@api.create_instance`):

```ruby
# public, alongside #call — does NOT modify #call/#adopt (D-07)
def reuse(existing:)
  row = WhatsappInstance.create!(
    client:             @client,
    instance_name:      existing.instance_name,      # COPY — points at same physical connection
    token:              existing.token,              # COPY — encrypts is transparent on read+write (model line 12)
    remote_instance_id: existing.remote_instance_id,
    origin:             :reused_sibling,
    connection_state:   existing.connection_state,   # expected :connected
    paired_at:          existing.paired_at,
    last_checked_at:    Time.current
  )
  Result.new(instance: row, adopted: true, qr_base64: nil)
end
```

**Anti-pattern (from RESEARCH):** do NOT call `@api.set_webhook` / `@api.connect` / `@api.create_instance` here — the physical session is already paired and its webhook already points at this system.

---

### `app/services/whatsapp/group_synchronizer.rb` (service — sibling fan-out, D-05, ISOLATED TASK)

**Analog:** the current `#call` body (lines 29-48) and `row_for` (lines 64-78) in the same file.

**Current single-instance coupling** — 4 points bound to `@instance`:
- `row_for` → `whatsapp_instance_id: @instance.id` (line 71)
- `WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid])` (line 33)
- GRUPO-05 deactivation: `@instance.whatsapp_groups.where(active: true).where("synced_at < ?", batch_started_at).update_all(active: false, updated_at: Time.current)` (lines 39-42)
- `@instance.update!(groups_synced_at: batch_started_at, groups_sync_state: :idle, groups_sync_error: nil)` (lines 44-46)

**Pattern to apply** — keep ONE `@api.fetch_groups(@instance.instance_name, api_key: @instance.token)` (line 30) OUTSIDE a loop, then iterate siblings resolved internally (do NOT change `SyncGroupsJob#perform` signature):

```ruby
batch_started_at = Time.current
raw = @api.fetch_groups(@instance.instance_name, api_key: @instance.token)   # 1 slow call (~40s, READ_TIMEOUT_GROUPS=60s)

WhatsappInstance.where(instance_name: @instance.instance_name).find_each do |sib|
  rows = Array(raw).filter_map { |g| row_for(g, batch_started_at, sib) }     # row_for takes the sib now, not @instance
  WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid]) if rows.any?
  sib.whatsapp_groups.where(active: true).where("synced_at < ?", batch_started_at)
     .update_all(active: false, updated_at: Time.current)                    # GRUPO-05 per sibling, SAME batch_started_at
  sib.update!(groups_synced_at: batch_started_at, groups_sync_state: :idle, groups_sync_error: nil)
end
```

**Failure path (RESEARCH Pitfall 5):** the not-connected guard (lines 24-27) and any `:sync_error` write stay on `@instance` only — do NOT fan-out `:syncing`/`:sync_error` to siblings (they never entered `:syncing`).

**Regression required (D-05):** an instance with no siblings → `where(instance_name:)` returns `[self]` → exactly 1 upsert / 1 GRUPO-05 pass / 1 `update!` — byte-identical to today.

---

### `app/jobs/whatsapp/send_to_group_job.rb` (job — D-04)

**Analog:** the `limits_concurrency` block in the same file (lines 57-61).

**Current** (lines 57-61):
```ruby
limits_concurrency to: 1,
  key: ->(group) {
    group.divulgacao.client.whatsapp_instance&.id ||
      "send_to_group:no_instance:#{group.id}"
  }
```

**After (D-04)** — swap `&.id` → `&.instance_name`, keep the sentinel fallback UNCHANGED:
```ruby
limits_concurrency to: 1,
  key: ->(group) {
    group.divulgacao.client.whatsapp_instance&.instance_name ||
      "send_to_group:no_instance:#{group.id}"
  }
```

`instance_name` is `t.string null: false` (create migration line 5) so it is always present when the row exists. Update the doc-comment at lines 31-42 to say "por conexão física / instance_name". No migration — the key lives only in `solid_queue_semaphores` at runtime.

---

### `app/controllers/webhooks/evolution_controller.rb` (controller — fan-out, RESEARCH Pitfall 1)

**Analog:** `#create` (lines 12-20) and `apply_event` (lines 43-52) in the same file.

**Current** (lines 15-18):
```ruby
instance = WhatsappInstance.find_by(instance_name: params[:instance].to_s)
return head(:no_content) if instance.nil?
apply_event(instance)
```

**After** — fan-out, reusing the already-idempotent `apply_event` per row:
```ruby
siblings = WhatsappInstance.where(instance_name: params[:instance].to_s)
return head(:no_content) if siblings.empty?
siblings.find_each { |instance| apply_event(instance) }
```

`valid_signature?` (lines 28-37) is unchanged — the HMAC is over `instance_name`, identical for all siblings. `apply_connection_update` / `apply_qrcode_updated` (lines 54-77) already do per-row `save!`/`update!` with the `known_evolution_state?` / `blank?` guards — no change inside them.

---

### `app/controllers/admin/whatsapp_instances_controller.rb` (controller — new `#reuse` action)

**Analog:** `#adopt` (lines 16-24) for the happy-path + rescue shape; `#verify` (lines 35-59) for the "resolve row, nil-guard, redirect" shape; `set_client` (lines 95-97) for the per-client scoping.

**Pattern to copy:**
- `before_action :set_client` already runs → `@client = Client.find(params[:client_id])` (never a raw instance id from params — SEG-01).
- Resolve the sibling with a scoped `find_by` (NOT `WhatsappInstance.find(params[:id])`):
```ruby
def reuse
  target = WhatsappInstance.connected
                           .where.not(client_id: @client.id)
                           .find_by(instance_name: params.require(:source_instance_name))
  return redirect_to(admin_client_path(@client),
    alert: "Conexão indisponível para reutilização. Atualize a página e tente de novo.") if target.nil?

  Evolution::InstanceProvisioner.new(@client).reuse(existing: target)
  redirect_to admin_client_path(@client),
    notice: "Conexão reutilizada. Sincronize os grupos deste cliente para popular a lista."
rescue ActiveRecord::RecordNotUnique
  redirect_to admin_client_path(@client), alert: "Este cliente já possui uma instância de WhatsApp."
end
```
- Copy the `rescue Evolution::Errors::ConfigurationError, ...Permanent, ...Transient, ...Unknown => e` + `Rails.logger.warn("[whatsapp_instances] reuse falhou client=#{@client.id}: #{e.class}")` block verbatim from `#adopt` (lines 20-23) — never log token/instance_name pair.

---

### `app/controllers/admin/clients_controller.rb` (`#show` — target collection)

**Analog:** `#show` in the same file (lines 8-17).

**Pattern:** add one memo assignment next to `@whatsapp_instance = @client.whatsapp_instance` (line 9), only meaningful when it is nil:
```ruby
@reusable_targets = WhatsappInstance.shareable_targets(excluding_client_id: @client.id) if @whatsapp_instance.nil?
```
Follows the existing `@artes = ...` / `@divulgacoes = ...` eager-memo style; keep the `GROUP BY` in the model method, not the controller.

---

### `config/routes.rb` (`post :reuse`)

**Analog:** the `resource :whatsapp_instance` block (lines 13-18) with its `post :refresh_qr` / `post :verify` / `post :adopt` / `post :reconnect` members.

**Pattern:** add one line inside the same block:
```ruby
resource :whatsapp_instance, only: [ :create ], controller: "whatsapp_instances" do
  post :refresh_qr
  post :verify
  post :adopt
  post :reconnect
  post :reuse            # NEW — phase 31
end
```

---

### `app/views/admin/whatsapp_instances/_panel.html.erb` (toggle in the `nil?` branch)

**Analog for the toggle markup:** `app/views/admin/artes/_form.html.erb` lines 4, 36-64.
**Insertion point:** the `if whatsapp_instance.nil?` branch of `_panel.html.erb` (lines 9-19) — today just an empty-state + a single `button_to "Criar instância"`. The QR flow lives entirely in the `else` branch (line 20+), untouched (D-07).

**Toggle pattern to mirror** (from `_form.html.erb` lines 4, 38-55):
- `data: { controller: "whatsapp-provision-toggle" }` on the wrapper.
- Two `<label data-whatsapp-provision-toggle-target="newLabel|reuseLabel" class="cursor-pointer flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium transition-colors">` each wrapping:
  - `radio_button_tag "provision_mode", "new"|"reuse", <default>, class: "sr-only", data: { action: "whatsapp-provision-toggle#selectNew|selectReuse", "whatsapp-provision-toggle-target": "newRadio|reuseRadio" }`
- Two conditional `<div data-whatsapp-provision-toggle-target="newField|reuseField" class="... hidden">` — mirrors `_form.html.erb` lines 57-64 (`data-media-type-toggle-target="uploadField"` + `hidden` class toggled by JS).
- `newField` → the existing `button_to "Criar instância", admin_client_whatsapp_instance_path(client), method: :post` (panel lines 16-18, keep as-is).
- `reuseField` → a `form_with url: reuse_admin_client_whatsapp_instance_path(client), method: :post` containing `select_tag :source_instance_name` populated from `@reusable_targets` (`option` value = `instance_name`, label = `"#{t[:instance_name]} — usado por: #{t[:client_names].join(', ')}"`) + submit button.

**Confirmation pattern** (Claude's Discretion → recommended yes): reuse the `data: { turbo_submits_with: "..." }` idiom already in `_panel.html.erb` lines 60, 69, and add `data: { turbo_confirm: "Isto vincula ESTE cliente ao MESMO número físico já usado por: <nomes>. A mesma sessão de WhatsApp e o mesmo limite de envio passam a ser compartilhados. Confirmar?" }` on the submit button. (Full modal like `_panel.html.erb` lines 77-92 is overkill for a one-click select.)

---

### `app/javascript/controllers/whatsapp_provision_toggle_controller.js` (NEW)

**Analog:** `app/javascript/controllers/media_type_toggle_controller.js` (whole file, 47 lines) — copy verbatim and rename.

**Copy exactly:**
- `import { Controller } from "@hotwired/stimulus"` + `export default class extends Controller`.
- `static targets = ["newField", "reuseField", "newRadio", "reuseRadio", "newLabel", "reuseLabel"]` (renamed from `upload*`/`link*` — RESEARCH Pitfall 8: dedicated controller, not reuse, because target names are semantically bound to media).
- `connect() { this.toggleFields() }`.
- `toggleFields()` → `classList.remove("hidden")` / `classList.add("hidden")` per branch, then `this.togglePills()`.
- `togglePills()` → copy the pill class arrays **verbatim**: `activeClasses = ["border-[#0F7949]", "bg-green-50", "text-[#0F7949]"]`, `inactiveClasses = ["border-gray-200", "text-slate-700"]`.
- `selectNew()` / `selectReuse()` → set `.checked = true` then `this.toggleFields()`.

**Optional extra behavior** (not in the media analog): disable the reuse submit unless the `<select>` has a chosen option. Auto-registered by `eagerLoadControllersFrom("controllers", application)` — do NOT edit `index.js`.

---

### `test/jobs/whatsapp/send_to_group_job_test.rb` (assertion update, RESEARCH Pitfall 3)

**Analog:** the test at lines 316-319 in the same file.

**Current** (line 318): `assert_includes job.concurrency_key, @instance.id.to_s`
**After (D-04):** `assert_includes job.concurrency_key, @instance.instance_name` — rename the test and add a comment pointing at phase 31.

Neighbouring tests stay green untouched: lines 311-314 (`concurrency_limit == 1`, `concurrency_on_conflict == :block`); lines 321-331 (sentinel `send_to_group:no_instance:<id>` — uses `group.id`, not the instance); lines 333-338 (token never serialized).

---

### `test/services/whatsapp/group_synchronizer_test.rb` (regression + sibling fan-out)

**Analog:** `FakeEvolutionClient` (lines 7-19), `setup` (lines 21-33), `group` helper (lines 35-37), and tests (a)/(b)/(c) (lines 40-70) in the same file.

**Patterns to copy:**
- `FakeEvolutionClient` with `@calls` counter — the single-instance regression test asserts `fake.calls == 1` even with N siblings (RESEARCH Pitfall 6).
- `setup` creates `@client` + `@instance` via `WhatsappInstance.create!(client:, instance_name: WhatsappInstance.evolution_name_for(@client), token:, connection_state: :connected)`.
- **New regression test:** instance with no sibling → `result.count`, `@instance.whatsapp_groups.active_groups.count`, and `fake.calls` identical to test (a).
- **New sibling fan-out test:** create a second `WhatsappInstance` for a second client with the SAME `instance_name`/`token` (needs the de-uniqueify migration), run `.call` on one, assert BOTH instances got the upserted groups scoped to their own `whatsapp_instance_id`, `fake.calls == 1`, and both rows share the same `groups_synced_at`.

---

## Shared Patterns

### Per-physical-connection fan-out (`where(instance_name:)`)
**Sources:** `webhooks/evolution_controller.rb:15`, `whatsapp/group_synchronizer.rb:30`
**Apply to:** webhook receiver, GroupSynchronizer
**Pattern:** replace `find_by(instance_name:)` (written when the column was unique) with `WhatsappInstance.where(instance_name: ...).find_each { ... }`. Zero extra Evolution calls; each iteration reuses an already-idempotent per-row body.

### Scoped resolution — never a raw id from params (SEG-01)
**Source:** `admin/whatsapp_instances_controller.rb:95-97` (`set_client`), `#verify` line 36 (`@client.whatsapp_instance`)
**Apply to:** the new `#reuse` action
**Pattern:** `WhatsappInstance.connected.where.not(client_id: @client.id).find_by(instance_name: params.require(:source_instance_name))` — chained scope + `find_by`, nil-guarded with a redirect. Never `WhatsappInstance.find(params[:id])`.

### Controller redirect + rescue taxonomy
**Source:** `admin/whatsapp_instances_controller.rb` — `#create` (7-11), `#adopt` (20-24), `#verify` (55-59)
**Apply to:** `#reuse`
**Pattern:** `rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e` → `Rails.logger.warn("[whatsapp_instances] <action> falhou client=#{@client.id}: #{e.class}")` → `redirect_to admin_client_path(@client), alert: "<pt-BR message>"`. Only the exception class is logged, never the message body, never token.

### encrypts token is transparent
**Source:** `app/models/whatsapp_instance.rb:12` (`encrypts :token`), used at `instance_provisioner.rb:69,98`
**Apply to:** `InstanceProvisioner#reuse`
**Pattern:** `new.token = existing.token` — plain assignment. Read decrypts, write re-encrypts (fresh non-deterministic ciphertext, expected).

### Enum-value-add without migration
**Source:** `app/models/whatsapp_instance.rb:16` (`origin` enum, integer-backed)
**Apply to:** `origin += reused_sibling: 2`
**Pattern:** integer enums add new mappings in code only; no migration, no backfill. Same as never adding a `shared:boolean` column.

### Stimulus radio-toggle + conditional fields
**Source:** `app/views/admin/artes/_form.html.erb:4,38-64` + `app/javascript/controllers/media_type_toggle_controller.js`
**Apply to:** `_panel.html.erb` empty-state + `whatsapp_provision_toggle_controller.js`
**Pattern:** `data-controller` wrapper; `sr-only` radios inside clickable `<label>` targets; `connect()` calls `toggleFields()`; pills toggle Tailwind classes `border-[#0F7949] bg-green-50 text-[#0F7949]` ⇄ `border-gray-200 text-slate-700`; conditional `<div>` targets get/lose the `hidden` class. New `*_controller.js` auto-registered by `eagerLoadControllersFrom` — never edit `index.js`.

### Migration style
**Source:** `db/migrate/20260830184901_add_groups_sync_columns_to_whatsapp_instances.rb`
**Apply to:** the de-uniqueify migration
**Pattern:** `class X < ActiveRecord::Migration[8.1]` + `def change`, no `up`/`down`, no data statements. `remove_index` + `add_index` are reversible automatically.

### GroupSynchronizer / SyncGroupsJob test harness
**Source:** `test/services/whatsapp/group_synchronizer_test.rb:7-37`
**Apply to:** both new GroupSynchronizer tests
**Pattern:** `FakeEvolutionClient` responding to `fetch_groups(name, api_key:)` with a `@calls` counter and a canned `groups_by_call` array; `group(id, subject:, announce:)` payload helper; DI via `Whatsapp::GroupSynchronizer.new(instance, client_api: fake)`. `bin/rails test` cannot run here (RESEARCH Pitfall 7) — verify by inspection / `bin/rails runner` with stubs.

---

## No Analog Found

None. Every file this phase touches has a direct in-repo analog (usually the same file, or a sibling method in the same class). The single "new pattern" is the de-uniqueify migration, and even that mirrors the existing `add_index ... unique: true` line it reverses.

## Metadata

**Analog search scope:** `app/services/{evolution,whatsapp}/`, `app/jobs/whatsapp/`, `app/controllers/{admin,webhooks}/`, `app/models/`, `app/views/admin/{whatsapp_instances,artes,clients}/`, `app/javascript/controllers/`, `config/routes.rb`, `db/migrate/`, `test/{jobs,services}/whatsapp/`
**Files scanned:** 16
**Pattern extraction date:** 2026-08-31
