# Phase 26: Instância de WhatsApp por Cliente + Pareamento - Pattern Map

**Mapped:** 2026-08-30
**Files analyzed:** 24 (11 new, 13 modified)
**Analogs found:** 22 / 24 (2 partial — see "No Analog Found")

All codebase interaction here was read-only. This file is the only output.

---

## File Classification

| New/Modified File | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|---------|------|-----------|----------------|---------------|
| `db/migrate/XXXX_create_whatsapp_instances.rb` | new | migration | schema | `db/migrate/20260524215206_create_artes.rb` | exact |
| `app/models/whatsapp_instance.rb` | new | model | CRUD + crypto | `app/models/arte.rb` (enums), `app/models/client.rb` (has_secure_token, class helpers) | role-match |
| `app/models/client.rb` | mod | model | CRUD | self (`has_many :artes` line 5) | exact |
| `app/services/evolution/client.rb` | mod | service (HTTP seam) | request-response | self (`fetch_instances` L36-45, `connection_state` L50-58, `request` L70-92) | exact |
| `app/services/evolution/instance_provisioner.rb` | new | service (PORO orchestrator) | request-response + CRUD | `app/services/evolution/client.rb`, `app/services/api/jwt_service.rb` | role-match |
| `app/controllers/admin/whatsapp_instances_controller.rb` | new | controller | request-response + CRUD | `app/controllers/admin/clients_controller.rb` (`rotate_token` L56-60, `set_client` L64-66) | exact |
| `app/controllers/webhooks/evolution_controller.rb` | new | controller | event-driven (inbound webhook) | `app/controllers/api/v1/base_controller.rb` (`< ActionController::API`) | role-match |
| `app/controllers/admin/clients_controller.rb` | mod | controller | request-response | self (`show` L8-15, `index` L4-6) | exact |
| `config/routes.rb` | mod | route | — | self (`member do post :rotate_token end` L10-12) | exact |
| `config/initializers/filter_parameter_logging.rb` | mod | config | — | self (L13-16) | exact |
| `config/initializers/rack_attack.rb` | mod | config | — | self (`throttle("admin/login_by_ip"...)` L14-16) | exact |
| `config/initializers/evolution.rb` | mod (maybe) | config | — | self | exact |
| `app/services/evolution.rb` | mod (maybe — webhook_base_url reader) | config | — | self (`self.base_url` L16-23) | exact |
| `config/credentials.yml.enc` | mod | config (secrets) | — | existing `evolution:` block (referenced in `evolution.rb`) | exact |
| `.env` / `.env.example` | mod | config (secrets) | — | existing `EVOLUTION_*` vars | exact |
| `config/environments/production.rb` | mod | config | — | `config.hosts` (commented) | partial |
| `app/javascript/controllers/qr_pairing_controller.js` | new | stimulus controller | polling (fetch) | `app/javascript/controllers/toast_controller.js` (setTimeout+disconnect teardown), `copy_controller.js` (static values) | role-match |
| `app/views/admin/whatsapp_instances/_panel.html.erb` | new | view partial | — | `app/views/admin/clients/show.html.erb` cards (L42-46, L115-134) | exact |
| `app/views/admin/whatsapp_instances/_qr.html.erb` | new | view partial | — | `app/views/admin/clients/show.html.erb` (QR block conventions) | partial |
| `app/views/admin/whatsapp_instances/_connection_badge.html.erb` | new | view partial | — | `app/views/admin/clients/_status_badge.html.erb` | exact |
| `app/views/admin/clients/show.html.erb` | mod | view | — | self (card stack) | exact |
| `app/views/admin/clients/_client_row.html.erb` | mod | view partial | — | self (status cell L6-8) | exact |
| `app/views/admin/clients/index.html.erb` | mod | view | — | self (`<th>` L31) | exact |
| `test/services/evolution/client_test.rb` | mod | test | — | self (Faraday::Adapter::Test stubs L11-32) | exact |
| `test/models/whatsapp_instance_test.rb` | new | test | — | `test/models/arte_test.rb` | exact |
| `test/controllers/admin/whatsapp_instances_controller_test.rb` | new | test | — | `test/controllers/admin/clients_controller_test.rb` (`sign_in_as`, setup) | exact |

---

## Pattern Assignments

### `app/services/evolution/client.rb` (modify — add `create_instance`, `connect`, `set_webhook`)

**Analog:** self — the existing `class << self` methods.

**Method shape to mirror** (`fetch_instances`, `connection_state` — L36-58):
- class method inside `class << self`
- `api_key:` kwarg defaulting to `Evolution.global_api_key`
- fast reads pass `read_timeout: Evolution::READ_TIMEOUT_FAST` (L38, L52)
- delegate to private `request(method, path, api_key:, body:, read_timeout:)` (L70-92)
- guard non-Hash/non-Array 2xx body → `raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution"` (L42, L55) — **static message, never interpolate body**
- return `resp.body` (a Hash/Array)

**`request` already supports POST bodies** (L70-80): `req.body = body if body`. No change needed to `request`.

**Error mapping already covers this phase** (`raise_for_status!` L98-119): 403 → `Evolution::Errors::Permanent` with message `"403 This name \"livia_client_5\" is already in use."`. The provisioner's adoption `rescue` keys off `e.message =~ /already in use/i`.

**Logging** (L90-91): `ensure` block logs `[evolution] POST /instance/create -> 201 (123ms)` — method/path/status/ms only. New methods inherit this automatically via `request`. Do NOT add any `logger` call that touches `body`.

**New method bodies:** verbatim contracts in 26-RESEARCH.md "Pattern 1" (L216-267) and "Code Examples" (L530-595). `POST /instance/create` puts `instanceName` in the body (only route that does); `GET /instance/connect/{name}` must check `body["error"]` (HTTP 200 + `{error:true}` pitfall); `POST /webhook/set/{name}` returns 201, always pass explicit `events` list.

---

### `app/services/evolution/instance_provisioner.rb` (new — PORO orchestrator)

**Analog:** `app/services/evolution/client.rb` (namespace + file placement) + `app/services/api/jwt_service.rb` (nested `module Errors` precedent, `self.` methods, `credentials || ENV.fetch` secret resolution L30-33).

**Placement:** `app/services/evolution/` — same folder as `Client` (Zeitwerk child of `module Evolution`, mirrors phase-25 layout). Do NOT create `app/services/whatsapp/`.

**Secret resolution pattern** (from `evolution.rb` L17 / `jwt_service.rb` L31-32):
```ruby
ENV.fetch("EVOLUTION_WEBHOOK_HMAC_KEY") { Rails.application.credentials.dig(:evolution, :webhook_hmac_key) }
```
Note: `evolution.rb` is ENV-first; `jwt_service.rb` is credentials-first. Follow **ENV-first** (phase-25 precedent for the Evolution namespace, `evolution.rb` L7 comment).

**Structure:** `Result = Struct.new(..., keyword_init: true)`; `initialize(client, client_api: Evolution::Client)` for DI (test seam); `call` does create → `rescue Evolution::Errors::Permanent => e; raise unless e.message =~ /already in use/i; adopt(...)`. Full reference body in 26-RESEARCH.md "Pattern 2" (L271-334).

**Anti-pattern (RESEARCH L430, Pitfall 4):** `adopt` MUST call `Evolution::Client.set_webhook` unconditionally before reading `connection_state`.

**Pitfall 8 (RESEARCH L508-510):** `row.paired_at ||= Time.current` — never overwrite. Use `Time.current`, never `Time.now` (timezone check initializer exists).

---

### `app/models/whatsapp_instance.rb` (new)

**Analog:** `app/models/arte.rb` (enum style) + `app/models/client.rb` (class-level helpers, secret handling).

**Enum pattern** (`arte.rb` L25-27):
```ruby
enum :platform, { instagram: 0, facebook: 1, linkedin: 2 }, prefix: :platform
enum :status,   { pending: 0, approved: 1, change_requested: 2, revised: 3 }
```
Apply:
```ruby
enum :connection_state, { unpaired: 0, awaiting_qr: 1, connected: 2, disconnected: 3 }
enum :origin,           { created_by_app: 0, adopted_existing: 1 }, prefix: :origin
```

**Association** (`arte.rb` L2): `belongs_to :client`.

**Encryption:** `encrypts :token` — non-deterministic (default). No project precedent for `encrypts` yet (this is the first). Keys come from `credentials.active_record_encryption` OR `ACTIVE_RECORD_ENCRYPTION_*` env — Rails native, NO initializer (RESEARCH L640-655). `token` column is `text`, not `string` (ciphertext overflow).

**Class helpers** (mirror `client.rb` L10-13 `token_version` style — small pure methods on the model):
```ruby
def self.evolution_name_for(client) = "livia_client_#{client.id}"
def self.webhook_secret_for(instance_name)
  key = ENV.fetch("EVOLUTION_WEBHOOK_HMAC_KEY") { Rails.application.credentials.dig(:evolution, :webhook_hmac_key) }
  OpenSSL::HMAC.hexdigest("SHA256", key, instance_name)
end
```
Full model reference in 26-RESEARCH.md L688-712.

---

### `app/models/client.rb` (modify)

**Analog:** self, L5.

```ruby
has_many :artes, dependent: :destroy          # existing L5
has_one :whatsapp_instance, dependent: :destroy   # add
```

---

### `db/migrate/XXXX_create_whatsapp_instances.rb` (new)

**Analog:** `db/migrate/20260524215206_create_artes.rb` (verbatim structure).

**Copy exactly** (`create_artes.rb` L1-18):
- `class CreateWhatsappInstances < ActiveRecord::Migration[8.1]` / `def change`
- `t.references :client, null: false, foreign_key: true` — but add `index: { unique: true }` (1:1, unlike artes)
- integer enum cols with `null: false, default: 0` (matches `artes.platform/status` L10-12)
- `t.timestamps`
- trailing `add_index` calls (L16-17 style) — add `add_index :whatsapp_instances, :instance_name, unique: true`

Full column list in 26-RESEARCH.md L664-682. Note `token`, `last_qr_base64`, `last_error` are `t.text`.

---

### `app/controllers/admin/whatsapp_instances_controller.rb` (new)

**Analog:** `app/controllers/admin/clients_controller.rb`.

**Inherit** `Admin::BaseController` (`clients_controller.rb` L1) — gives `layout 'admin'` + `before_action :require_authentication` (`admin/base_controller.rb` L2-3).

**Custom member actions precedent** (`clients_controller.rb` `rotate_token` L56-60):
```ruby
def rotate_token
  @client.regenerate_access_token
  redirect_to admin_client_path(@client), notice: "Token rotacionado. ..."
end
```
Mirror for `create` / `verify` / `adopt` / `reconnect`: do work, then `redirect_to admin_client_path(@client), notice:` (MVP flash path — layout renders it). `refresh_qr` is the only JSON action: `render json: { state:, qr_base64: }`.

**Scoping (RESEARCH Anti-pattern L433):** always `@client.whatsapp_instance` — never `WhatsappInstance.find(params[:id])`. `set_client` mirrors `clients_controller.rb` L64-66 but load via nested route param, e.g. `Client.find(params[:client_id])`.

**Error rescue:** rescue `Evolution::Errors::Permanent/Transient/Unknown/NotConnected` → redirect back with the exact pt-BR copy from 26-UI-SPEC "Copywriting Contract" (error rows).

---

### `app/controllers/webhooks/evolution_controller.rb` (new)

**Analog:** `app/controllers/api/v1/base_controller.rb` L3 — `< ActionController::API` (no CSRF, no session). This one does NOT need the envelope helpers; keep it minimal.

**Namespace:** new `Webhooks::` module → `app/controllers/webhooks/evolution_controller.rb`, action `create`.

**PAIR-06 order (RESEARCH "Pattern 3" L337-384, verbatim reference):**
1. `valid_signature?` — recompute `OpenSSL::HMAC.hexdigest("SHA256", key, params[:instance].to_s)`, compare with `ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(presented), Digest::SHA256.hexdigest(expected))` (hash both sides — length-safe, Pitfall 5). `presented.blank? → return false`. Mismatch → `head :unauthorized` **before any DB query**.
2. `WhatsappInstance.find_by(instance_name: params[:instance].to_s)` — nil → `head :no_content` (don't leak existence, Pitfall 9).
3. Normalize event: `params[:event].to_s.tr(".-", "__").upcase` → whitelist `CONNECTION_UPDATE` / `QRCODE_UPDATED` (Pitfall 3 — dotcase emission).
4. `head :ok`.

**`secure_compare` precedent:** project rule "`secure_compare` em toda comparação de segredo (v1.6)". No existing webhook controller — this is the first; the API auth code in `api/v1/` is the closest secret-compare precedent.

**Logging (RESEARCH L387):** never `Rails.logger.info(request.raw_post)` / `params.inspect`. Log only `params[:event]` + `params[:instance]` + outcome. `filter_parameters` does NOT cover manual `logger.info`.

---

### `config/routes.rb` (modify)

**Analog:** self, L9-13.

```ruby
# existing precedent
resources :clients, only: [...] do
  member do
    post :rotate_token
  end
end
```

Add nested `resource :whatsapp_instance` block (singular — 1:1) with `get :refresh_qr` + `post :verify/:adopt/:reconnect`, inside `namespace :admin` / `resources :clients`. Add top-level `post "/webhooks/evolution", to: "webhooks/evolution#create"` above the health check (L64). Reference in 26-RESEARCH.md L714-730.

---

### `config/initializers/filter_parameter_logging.rb` (modify)

**Analog:** self, L13-16.

```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :apikey, :hash
]
```
Append (substring match, same symbol style — do NOT switch to regex, RESEARCH L448): `:api_key, :instance_token, :qrcode, :base64, :pairing_code, :pairingCode`.

---

### `config/initializers/rack_attack.rb` (modify)

**Analog:** self — `throttle("admin/login_by_ip", limit: 5, period: 60)` L14-16.

```ruby
throttle("webhooks/evolution_by_ip", limit: 120, period: 60) do |req|
  req.ip if req.path == "/webhooks/evolution" && req.post?
end
```
`throttled_responder` (L40-48) already branches on `/api/` vs HTML — `/webhooks/` falls to the HTML branch, acceptable (machine caller ignores body).

---

### `app/javascript/controllers/qr_pairing_controller.js` (new)

**Analog:** `toast_controller.js` (timer + mandatory `disconnect()` teardown L17-19) + `copy_controller.js` (`static values` L4).

**Teardown pattern (`toast_controller.js` L17-19, Pitfall 10):**
```js
disconnect() { clearInterval(this.timer) }
```
Also `clearInterval` on `state === "connected"` and after `MAX_CYCLES`.

**Registration:** `index.js` uses `eagerLoadControllersFrom` (L4) — no manual registration needed, just drop the file in `app/javascript/controllers/`.

**`static values = { url: String }`** (copy_controller L4 style). Full reference body in 26-RESEARCH.md "Pattern 4" L389-414. Never write the base64 payload to console/log (INFRA-04).

---

### `app/views/admin/whatsapp_instances/_connection_badge.html.erb` (new)

**Analog:** `app/views/admin/clients/_status_badge.html.erb` (verbatim pill shape).

```erb
<span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20">
  <span aria-hidden="true">●</span> Ativo
</span>
```
Fork into 4 `connection_state` variants using the exact palettes from 26-UI-SPEC "Connection-state → color map":
- `connected` → `bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20` (same as "Ativo")
- `awaiting_qr` → `bg-[#FFFBEB] text-amber-800 border-[#F59E0B]/20` (same as "Inativo")
- `disconnected` → `bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20`
- `unpaired` → `bg-slate-100 text-slate-600 border-slate-200`

---

### `app/views/admin/whatsapp_instances/_panel.html.erb` (new — WhatsApp section on show)

**Analog:** `app/views/admin/clients/show.html.erb` "Informações" card (L115-134) + modal usage (L92-112).

**Card shell (verbatim, show.html.erb L116-119):**
```erb
<div class="bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl mt-4">
  <h2 class="text-sm font-semibold text-slate-900 border-b border-gray-100 pb-3 mb-4">WhatsApp</h2>
```

**`<dl>` rows (L120-133):** `<div class="flex items-center gap-4"><dt class="text-sm text-slate-500 w-36">Estado</dt><dd>...</dd></div>` — reuse for Estado / Última verificação / Pareado em.

**Confirm modal for "Parear novamente" (L92-112 pattern):** wrap in `<div data-controller="modal">`, button `data-action="click->modal#open"`, then `render "admin/clients/confirm_modal", id:, title:, body: (...).html_safe, confirm_label:, cancel_label:, confirm_variant: "warning", form_action:, method: :post`. Copy strings from 26-UI-SPEC.

**Empty state (no instance):** mirror `clients/index.html.erb` empty block (L11-22) — centered, `py-16`, muted icon, heading + body + single primary button `Criar instância` (`bg-[#0F7949]` L6).

**Buttons:** primary `h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] ...` (index.html.erb L6); secondary `inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50` (show.html.erb L12).

---

### `app/views/admin/clients/_client_row.html.erb` + `index.html.erb` (modify)

**Analog:** self — status cell (`_client_row` L6-8) and `<th>` (`index.html.erb` L31 `w-[100px]` centered).

Add a `Conexão` column: `<th ... text-center w-[90px]>` and a `<td class="px-4 py-0 h-12 text-center">` rendering a `w-2 h-2 rounded-full` dot (26-UI-SPEC dot spec) with `title=`/`aria-label`. Mobile card block (L45-59) optionally gets the dot beside `_status_badge`. Controller `#index` must `includes(:whatsapp_instance)` to avoid N+1 (add to `clients_controller.rb` L5).

---

### `test/services/evolution/client_test.rb` (modify)

**Analog:** self — `stubbed_connection` / `Faraday::Adapter::Test::Stubs` (L11-32), safe-logging test (L112-134).

Add stubs for `s.post("/instance/create")`, `s.get("/instance/connect/...")`, `s.post("/webhook/set/...")`. Assert: 403 body → `Evolution::Errors::Permanent` matching `/already in use/i`; `connect` with `{error:true}` HTTP 200 → raises; log carries no base64/apikey. `bin/rails test` does NOT run here (test DB owned by another OS user — see MEMORY) — verification is the phase runner + `bin/rails runner` with Faraday stub, per phase-25 STATE.

---

### `test/models/whatsapp_instance_test.rb` (new)

**Analog:** `test/models/arte_test.rb` — `class ... < ActiveSupport::TestCase`, `setup` builds a `Client.create!(name:, password:, password_confirmation:)`, enum-default assertions (`assert_equal "instagram", Arte.new.platform` L24). Test: `connection_state` default `unpaired`, `evolution_name_for`, `webhook_secret_for` HMAC stability, `encrypts :token` (ciphertext != plaintext in DB), `paired_at` write-once.

---

### `test/controllers/admin/whatsapp_instances_controller_test.rb` (new)

**Analog:** `test/controllers/admin/clients_controller_test.rb` — `< ActionDispatch::IntegrationTest`, `ADMIN_EMAIL`/`ADMIN_PASSWORD` consts, `User.find_or_create_by!` + `sign_in_as(@admin)` in `setup` (L6-19), `assert_redirected_to` + `flash[:notice]` assertions. Stub `Evolution::Client` / `Evolution::InstanceProvisioner` via DI seam. Add a `test/controllers/webhooks/` sibling for the webhook (401 without secret, 204 unknown instance, 200 + state update with valid HMAC).

---

## Shared Patterns

### Secret resolution (ENV-first for the Evolution namespace)
**Source:** `app/services/evolution.rb` L16-33, `config/initializers/evolution.rb` L17
**Apply to:** `instance_provisioner.rb`, `whatsapp_instance.rb` (`webhook_secret_for`), `evolution_controller.rb`
```ruby
ENV.fetch("EVOLUTION_WEBHOOK_HMAC_KEY") { Rails.application.credentials.dig(:evolution, :webhook_hmac_key) }
```
Contrast: `jwt_service.rb` L30-33 is credentials-first — the Evolution namespace deliberately inverts this.

### Timing-safe secret comparison
**Source:** project rule (v1.6 API auth); primitive `ActiveSupport::SecurityUtils.secure_compare`
**Apply to:** `webhooks/evolution_controller.rb` only
```ruby
ActiveSupport::SecurityUtils.secure_compare(
  Digest::SHA256.hexdigest(presented), Digest::SHA256.hexdigest(expected)
)
```
Hash both sides so lengths match (Pitfall 5). Guard `presented.blank? → return false`.

### Evolution error taxonomy (already complete for this phase)
**Source:** `app/services/evolution/errors.rb` (L11-19), `client.rb#raise_for_status!` (L98-119)
**Apply to:** `instance_provisioner.rb` (rescue `Permanent`, match `/already in use/i`), `admin/whatsapp_instances_controller.rb` (rescue all 4 → pt-BR flash from 26-UI-SPEC)
No new error classes needed. `NotConnected` already exists for the `verify` path.

### Safe logging (metadata only, never body)
**Source:** `client.rb` L90-91 `ensure` block; `test/services/evolution/client_test.rb` L112-134
**Apply to:** new `Evolution::Client` methods (inherited via `request`), `webhooks/evolution_controller.rb` (manual — log only `event` + `instance` + outcome), `qr_pairing_controller.js` (never console.log base64)
`config.filter_parameters` covers auto param logging, NOT manual `logger.info` or job args.

### enum + `belongs_to` model style
**Source:** `app/models/arte.rb` L2, L25-27
**Apply to:** `whatsapp_instance.rb`

### Admin controller base + custom member action
**Source:** `admin/base_controller.rb` L1-5, `admin/clients_controller.rb` L1-2, L56-66
**Apply to:** `admin/whatsapp_instances_controller.rb`
`< Admin::BaseController` gives auth + layout for free; custom verbs are plain actions that `redirect_to admin_client_path(@client), notice:`.

### Card shell + section heading (Tailwind, verbatim)
**Source:** `app/views/admin/clients/show.html.erb` L116-119
**Apply to:** `_panel.html.erb`, `_qr.html.erb`
```
bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl mt-4
```
+ `<h2 class="text-sm font-semibold text-slate-900 border-b border-gray-100 pb-3 mb-4">`

### Status pill shape (verbatim)
**Source:** `app/views/admin/clients/_status_badge.html.erb` L2
**Apply to:** `_connection_badge.html.erb`
```
inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border
```
+ `<span aria-hidden="true">●</span>`

### Confirm modal
**Source:** `app/views/admin/clients/_confirm_modal.html.erb` + `modal_controller.js`
**Apply to:** "Parear novamente" — `confirm_variant: "warning"` (yellow `bg-[#F59E0B]`, L58). Render the shared partial with `render "admin/clients/confirm_modal", ...`.

### Stimulus timer teardown
**Source:** `app/javascript/controllers/toast_controller.js` L7-19
**Apply to:** `qr_pairing_controller.js` — `disconnect() { clearInterval(this.timer) }` is mandatory (Pitfall 10).

### Integration-test harness
**Source:** `test/controllers/admin/clients_controller_test.rb` L1-19
**Apply to:** all new admin controller tests — `sign_in_as(@admin)` in `setup`, `Client.create!(name:, password:, password_plain:)`.

### Rack::Attack throttle
**Source:** `config/initializers/rack_attack.rb` L14-16
**Apply to:** `/webhooks/evolution` — `limit: 120, period: 60`, keyed by `req.ip`.

---

## No Analog Found

| File | Role | Data Flow | Reason / Guidance |
|------|------|-----------|-------------------|
| `app/controllers/webhooks/evolution_controller.rb` | controller | inbound webhook (machine→machine) | No existing inbound webhook receiver in the codebase. Closest is `Api::V1::BaseController` (`< ActionController::API`, no CSRF/session) for the class shape only. HMAC auth flow, event normalization, and 401-before-query ordering come from 26-RESEARCH.md "Pattern 3" (verbatim), not from a repo analog. `secure_compare` usage has no in-repo call site to copy — follow the v1.6 project rule + `ActiveSupport::SecurityUtils` docs. |
| `encrypts :token` on `app/models/whatsapp_instance.rb` | model (crypto) | at-rest encryption | First use of Active Record Encryption in this codebase. `grep -rn "encrypts" app/models` returns nothing today. No analog — follow the Rails guide (RESEARCH L640-655): `bin/rails db:encryption:init`, keys in credentials OR `ACTIVE_RECORD_ENCRYPTION_*` env, non-deterministic (default), `text` column, no initializer, no `support_unencrypted_data`. Ordering gate: keys + `filter_parameters` fix land BEFORE the migration/model plan. |
| `app/views/admin/whatsapp_instances/_qr.html.erb` | view partial | — | Partial analog only (card shell). The QR `<img data:image/png;base64,...>` slot, loading placeholder (`w-64 h-64 bg-gray-50`), ban banner (amber, above QR), and recency caution have no repo precedent — build from 26-UI-SPEC "UI Considerations" + "Copywriting Contract". Do NOT re-prefix `data:image/png;base64,` (Evolution sends the full data-URI). Validate the base64 prefix server-side before render (RESEARCH Security Domain V5). |

---

## Metadata

**Analog search scope:** `app/models/`, `app/services/`, `app/services/evolution/`, `app/controllers/`, `app/controllers/admin/`, `app/controllers/api/v1/`, `app/views/admin/clients/`, `app/views/admin/shared/`, `app/javascript/controllers/`, `db/migrate/`, `config/initializers/`, `config/routes.rb`, `test/models/`, `test/controllers/admin/`, `test/services/evolution/`
**Files scanned:** ~35
**Pattern extraction date:** 2026-08-30
**Key upstream references:** 26-RESEARCH.md Patterns 1-4 (verbatim Evolution contracts + reference bodies), 26-UI-SPEC.md Design System / Color map / Copywriting Contract, `.planning/notes/evolution-contract.md` (empirical host contract — executor confirms 403 shape before coding the `rescue`).
