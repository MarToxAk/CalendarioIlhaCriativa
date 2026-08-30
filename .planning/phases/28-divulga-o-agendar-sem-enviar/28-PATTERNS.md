# Phase 28: Divulgação — Agendar sem Enviar - Pattern Map

**Mapped:** 2026-08-30
**Files analyzed:** 22 (new + modified)
**Analogs found:** 21 / 22 (1 partial — Stimulus estimate controller has no exact analog)

All analogs read from source this session. This phase adds **zero gems**, **zero external calls**.
Every pattern below is copy-from-existing.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `db/migrate/XXXX_create_divulgacoes.rb` | migration | schema | `db/migrate/20260830184858_create_whatsapp_groups.rb` | exact |
| `db/migrate/XXXX_create_divulgacao_grupos.rb` | migration | schema | `db/migrate/20260830184858_create_whatsapp_groups.rb` | exact |
| `config/initializers/inflections.rb` | config | n/a | Rails default scaffold (file exists, only comments) | exact (edit) |
| `app/models/divulgacao.rb` | model | CRUD + validation-boundary | `app/models/arte.rb` (custom `validate :method` + enum) | exact |
| `app/models/divulgacao_grupo.rb` | model | CRUD | `app/models/whatsapp_group.rb` (frozen-column + `display_name` snapshot source) | role-match |
| `app/models/client.rb` (edit) | model | association | `app/models/client.rb:5` `has_many :artes, dependent: :destroy` | exact |
| `app/models/arte.rb` (edit) | model | association | `app/models/arte.rb:3` `has_many :approval_responses` | exact |
| `app/controllers/admin/divulgacoes_controller.rb` | controller | request-response CRUD | `app/controllers/admin/whatsapp_groups_controller.rb` (nested, `set_client`, scoped finders) + `app/controllers/admin/artes_controller.rb` (full CRUD + `errors[:base]` re-render) | exact |
| `app/controllers/admin/clients_controller.rb` (edit `#show`) | controller | request-response | `app/controllers/admin/clients_controller.rb:8-16` (`@artes = @client.artes.order(...)`) | exact |
| `config/routes.rb` (edit) | route | n/a | `config/routes.rb:19-24` nested `resources :whatsapp_groups` | exact |
| `app/views/admin/divulgacoes/new.html.erb` | view | form | `app/views/admin/artes/_form.html.erb` + `app/views/admin/whatsapp_groups/index.html.erb` (blocked/empty states) | role-match |
| `app/views/admin/divulgacoes/index.html.erb` | view | list | `app/views/admin/whatsapp_groups/index.html.erb` + `app/views/admin/artes/index.html.erb` (table+mobile) | role-match |
| `app/views/admin/divulgacoes/show.html.erb` | view | detail | `app/views/admin/whatsapp_groups/show.html.erb` (`dl` rows + status pills) | exact |
| `app/views/admin/divulgacoes/_preview.html.erb` | view (partial) | file-I/O render | `app/views/client/artes/show.html.erb:26-56` (media + caption, no JS) | exact |
| `app/views/admin/divulgacoes/_grupo_row.html.erb` | view (partial) | list row | `app/views/admin/whatsapp_groups/_group_row.html.erb` (truncate + `title=` + pill) | exact |
| `app/views/admin/divulgacoes/_status_badge.html.erb` | view (partial) | presentation | `app/views/admin/whatsapp_groups/show.html.erb:15-23` (pill shape) | exact |
| `app/views/admin/clients/show.html.erb` (edit) | view | list section | `app/views/admin/clients/show.html.erb:139-169` ("Artes" card mirror) | exact |
| `app/helpers/admin/divulgacoes_helper.rb` | helper | transform | `app/helpers/admin/whatsapp_groups_helper.rb` (pt-BR absolute datetime label) | exact |
| `app/javascript/controllers/divulgacao_estimate_controller.js` | hook (Stimulus) | event-driven | `app/javascript/controllers/group_sync_controller.js` (connect/targets/values shape only) | partial |
| `app/javascript/controllers/divulgacao_preview_controller.js` | hook (Stimulus) | event-driven | `app/javascript/controllers/media_type_toggle_controller.js` (show/hide panes) | role-match |
| `app/javascript/controllers/picker_controller.js` | hook (Stimulus) | event-driven | `app/javascript/controllers/group_sync_controller.js` (shape) | partial |
| `test/models/divulgacao_test.rb` | test | n/a | `test/models/arte_test.rb` (`ActiveSupport::TestCase`, `Client.create!` setup, `errors[:base]` asserts) | exact |
| `test/controllers/admin/divulgacoes_controller_test.rb` | test | n/a | `test/controllers/admin/whatsapp_groups_controller_test.rb` (canonical A×B cross-client) | exact |

---

## Pattern Assignments

### `db/migrate/*_create_divulgacoes.rb` + `*_create_divulgacao_grupos.rb` (migration, schema)

**Analog:** `db/migrate/20260830184858_create_whatsapp_groups.rb` (full file):

```ruby
class CreateWhatsappGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_groups do |t|
      t.references :whatsapp_instance, null: false, foreign_key: true
      t.string   :remote_jid, null: false
      t.string   :subject
      t.boolean  :announce, null: false, default: false
      t.boolean  :active, null: false, default: true
      t.datetime :synced_at
      t.timestamps
    end
    add_index :whatsapp_groups, [ :whatsapp_instance_id, :remote_jid ], unique: true
    add_index :whatsapp_groups, [ :whatsapp_instance_id, :active ]
  end
end
```

**Copy:** `ActiveRecord::Migration[8.1]`, `t.references … null: false, foreign_key: true`, `t.integer :status, null: false, default: 0` for enums (repo stores every enum as integer — `artes.status`, `whatsapp_instances.connection_state`), composite `add_index … unique: true`. `t.timestamps` last.

**Schema per RESEARCH §Pattern 2 (verbatim):**
- `divulgacoes`: `t.references :client` + `t.references :arte` (both `null: false, foreign_key: true`), `t.datetime :scheduled_for, null: false`, `t.integer :status, null: false, default: 0`, `add_index :divulgacoes, [:client_id, :scheduled_for]`.
- `divulgacao_grupos`: `t.references :divulgacao` + `t.references :whatsapp_group`, `t.integer :status, null: false, default: 0`, `t.string :group_name, null: false`, `t.string :remote_jid, null: false`, nullable phase-29 columns `t.datetime :sent_at` / `t.string :error_code` / `t.string :evolution_message_id` (staged, no logic), `add_index :divulgacao_grupos, [:divulgacao_id, :whatsapp_group_id], unique: true`.

---

### `config/initializers/inflections.rb` (config)

**Current state:** file exists, comments only (no active `inflect` block).

**Action:** add an active `:en` block (default locale) — `Divulgacao` pluralizes to `divulgacaos` by default, which breaks the `divulgacoes` table name:

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "divulgacao", "divulgacoes"
  inflect.irregular "divulgacao_grupo", "divulgacao_grupos"
end
```

Alternative (belt-and-suspenders, planner discretion): also set `self.table_name = "divulgacoes"` on the model.

---

### `app/models/divulgacao.rb` (model, CRUD + validation-boundary)

**Analog:** `app/models/arte.rb` — the custom-validation style is verbatim.

**Enum pattern** (`arte.rb:21-23`):
```ruby
enum :platform,   { instagram: 0, facebook: 1, linkedin: 2 }, prefix: :platform
enum :media_type, { image: 0, video: 1, caption_only: 2 }
enum :status,     { pending: 0, approved: 1, change_requested: 2, revised: 3 }
```
→ `Divulgacao`: `enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status`
(prefix REQUIRED — `divulgacao_grupos.status` also has `pendente/enviado`; keeps `status_agendada?` / `status_cancelada!` explicit, per RESEARCH §Pattern 5).
→ `DivulgacaoGrupo`: `enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }` (text verbatim from DIVU-09).

**Association pattern** (`arte.rb:1-4`):
```ruby
belongs_to :client
has_many :approval_responses, -> { order(created_at: :desc) }, dependent: :destroy
has_one_attached :media_file
```
→ `belongs_to :client` / `belongs_to :arte` / `has_many :divulgacao_grupos, dependent: :destroy`.

**Custom validation pattern** (`arte.rb:32-33, 94-102`) — copy this shape exactly:
```ruby
validate :media_source_present
validate :only_one_media_source
# ...
def media_source_present
  return if media_file.attached? || external_url.present?
  errors.add(:base, "Precisa de arquivo ou link externo")
end

def only_one_media_source
  return unless media_file.attached? && external_url.present?
  errors.add(:base, "Use arquivo OU link externo, não ambos")
end
```
→ Private methods, guard-clause early return, `errors.add(:base, "pt-BR sentence")`.
The five `Divulgacao` validations (`arte_deve_estar_aprovada`, `arte_tem_arquivo_anexado`,
`arquivo_dentro_do_teto_whatsapp`, `arte_e_grupos_do_mesmo_cliente`, `ao_menos_um_grupo`,
`scheduled_for_no_futuro`) + `validates :scheduled_for, presence: true` — full bodies +
pt-BR copy in RESEARCH §Pattern 5 and 28-UI-SPEC Copywriting Contract.

**Constant colocation:** `WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` and
`SEND_DELAY_MIN = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN_SECONDS", "25"))` /
`SEND_DELAY_MAX = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MAX_SECONDS", "45"))` at top of class.
Mirrors `app/services/evolution.rb:57-60`:
```ruby
OPEN_TIMEOUT  = Integer(ENV.fetch("EVOLUTION_OPEN_TIMEOUT", "5"))
READ_TIMEOUT  = Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT", "30"))
```
Note: CONTEXT "Perguntas em aberto RESOLVIDAS" locks the delay fallback to **25 / 45** (not the
RESEARCH-body 30/90) to match the "≈ 8–14 min para 20 grupos" example. Use 25/45.

**`Arte#approved?`:** `Arte enum :status` has NO prefix (`arte.rb:23`), so `arte.approved?` is the generated predicate — use it directly in `arte_deve_estar_aprovada`.

**`cancelar!`:** guard on `status_agendada?` then `update(status: :cancelada)` — mirrors
`Arte#mark_revised` controller guard (`artes_controller.rb:61-67` checks `change_requested?` before `revised!`).

---

### `app/models/divulgacao_grupo.rb` (model, CRUD)

**Analog:** `app/models/whatsapp_group.rb` — this is the SOURCE of the frozen snapshot:
```ruby
def display_name
  subject.presence || "Grupo sem nome (#{remote_jid.to_s.first(12)}…)"
end
```
The controller reads `g.display_name` / `g.remote_jid` at `build` time and freezes them into
`divulgacao_grupos.group_name` / `.remote_jid` (DIVU-09). This model itself is thin:
`belongs_to :divulgacao` / `belongs_to :whatsapp_group`, the `status` enum, and
`validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }`
(mirrors the DB unique index — same doubling as `whatsapp_groups` `[whatsapp_instance_id, remote_jid]`).

---

### `app/controllers/admin/divulgacoes_controller.rb` (controller, request-response CRUD)

**Analog A — nesting + scoped finders:** `app/controllers/admin/whatsapp_groups_controller.rb`.

```ruby
class Admin::WhatsappGroupsController < Admin::BaseController
  before_action :set_client, :set_instance
  # ...
  def set_client   = @client = Client.find(params[:client_id])
  def set_instance = @instance = @client.whatsapp_instance

  def set_group
    raise ActiveRecord::RecordNotFound if @instance.nil?
    @group = @instance.whatsapp_groups.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_client_whatsapp_groups_path(@client), alert: "Grupo não encontrado."
  end
end
```

**Copy:** `< Admin::BaseController` (gives `require_authentication` + `Pagy::Backend`, no new auth surface),
`before_action :set_client`, one-line `def set_client = @client = Client.find(params[:client_id])`,
and the `raise RecordNotFound if @instance.nil?` guard before `.whatsapp_groups.find` so a
client with no instance degrades to 404, never `NoMethodError`. For `#create` re-resolve:
`arte = @client.artes.find(...)` and
`groups = @client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none`
then `.find(gids)` — cross-client / inactive id → `RecordNotFound` (SEG-01/SEG-02).

**Analog B — full CRUD + `errors[:base]` re-render:** `app/controllers/admin/artes_controller.rb:22-33`:
```ruby
def create
  @arte = Arte.new(arte_params)
  # ...
  if @arte.save
    redirect_to admin_arte_path(@arte), notice: "Arte criada com sucesso."
  else
    render :new, status: :unprocessable_entity
  end
end
```
**Copy:** `if save → redirect_to … , notice:` / `else render :new, status: :unprocessable_entity`.
For the `RecordNotFound` path in `#create`, rescue → `flash.now[:alert] = "…"` + `render :new, status: :unprocessable_entity` (copy in UI-SPEC).

**Analog C — guarded state-transition member action:** `artes_controller.rb:61-68` (`mark_revised`):
```ruby
def mark_revised
  if @arte.change_requested?
    @arte.revised!
    redirect_to admin_arte_path(@arte), notice: "Arte marcada como revisada."
  else
    redirect_to admin_arte_path(@arte), alert: "Ação inválida para o status atual."
  end
end
```
→ `#cancel`: `if @divulgacao.status_agendada? → update(status: :cancelada), redirect_to … notice:` else `alert:`.

**`#create` full skeleton + strong params** in RESEARCH §Pattern 3 (the `divulgacao.divulgacao_grupos.build(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid)` loop inside one `save` transaction — NOT `insert_all`).

**Anti-pattern (RESEARCH):** never `Arte.find` / `WhatsappGroup.find` bare in this controller; never `Time.parse(params[...][:scheduled_for])` — assign the raw string to the AR attribute.

---

### `app/controllers/admin/clients_controller.rb` `#show` (edit)

**Analog:** same file, lines 8-16:
```ruby
def show
  @whatsapp_instance = @client.whatsapp_instance
  @artes = @client.artes.order(scheduled_on: :desc)
end
```
**Add:** `@divulgacoes = @client.divulgacoes.includes(:arte).order(scheduled_for: :desc)` (UI-SPEC caps the mirror at 5 most recent + "Ver todas" link).

---

### `config/routes.rb` (edit)

**Analog:** lines 19-24 inside `namespace :admin { resources :clients do … end }`:
```ruby
resources :whatsapp_groups, only: [ :index, :show ], controller: "whatsapp_groups" do
  collection do
    post :sync
    get  :sync_status
  end
end
```
Also `resources :artes do member { patch :mark_revised } end` (lines 26-30) is the member-action precedent.

**Add:**
```ruby
resources :divulgacoes, only: [ :index, :new, :create, :show ] do
  member { patch :cancel }
end
```
Helpers: `admin_client_divulgacoes_path`, `new_admin_client_divulgacao_path`,
`admin_client_divulgacao_path`, `cancel_admin_client_divulgacao_path`.

---

### `app/views/admin/divulgacoes/_preview.html.erb` (partial, file-I/O render — DIVU-06)

**Analog:** `app/views/client/artes/show.html.erb:26-56` (verbatim media block):
```erb
<% elsif @arte.media_file.attached? %>
  <% if @arte.media_file.image? %>
    <%= image_tag rails_storage_proxy_path(@arte.media_file),
          class: "max-w-full max-h-[480px] object-contain mx-auto block rounded-lg",
          alt: "Preview da arte" %>
  <% elsif @arte.media_file.video? %>
    <video controls playsinline preload="metadata" class="max-w-full max-h-[480px] block mx-auto rounded-lg shadow-sm">
      <source src="<%= rails_storage_proxy_path(@arte.media_file) %>"
              type="<%= @arte.media_file.content_type %>">
      Seu navegador não suporta reprodução de vídeo.
    </video>
  <% end %>
<% elsif @arte.caption_only? %>
  <div class="… whitespace-pre-wrap …"><%= @arte.caption.presence || "Legenda não informada." %></div>
<% end %>
```
**Copy:** `rails_storage_proxy_path` (NOT `url_for`/`rails_blob_path` — no presign expiry while
form is open), `.image?` / `.video?` blob predicates, `<video controls playsinline>`, the
`whitespace-pre-wrap` caption, ERB auto-escape (no `raw`/`html_safe`). Local `arte:` not ivar.
`caption_only` → "(sem mídia — mensagem de texto)". Full markup + Tailwind in UI-SPEC §Preview partial
(`preload="none"` on multi-pane pre-render, `loading: "lazy"` on images, `max-h-[420px]`, `max-h-64 overflow-y-auto` on caption).

---

### `app/views/admin/divulgacoes/show.html.erb` (detail) + `_grupo_row.html.erb` + `_status_badge.html.erb`

**Analog:** `app/views/admin/whatsapp_groups/show.html.erb` (full file):
- Page `<h1 class="text-2xl font-semibold text-slate-900 mb-6">`, back link `← #{@client.name}` `text-sm text-slate-600`.
- Card shell `bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl`.
- `<dl class="space-y-3">` with `<dt class="text-sm font-medium text-slate-500 w-36">` / `<dd>`.
- **Status pill shape (verbatim, lines 15-23):**
```erb
<span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20">
  <span aria-hidden="true">●</span> Ativo
</span>
```
`_status_badge.html.erb` maps `divulgacao.status` → the palette table in UI-SPEC §Color
(agendada=success green, cancelada=error red, em_andamento/incerto=warning amber, concluida/pendente=neutral slate).

**`_grupo_row.html.erb` analog:** `app/views/admin/whatsapp_groups/_group_row.html.erb`:
```erb
<span class="text-sm min-w-0 flex-1 … truncate" title="<%= group.display_name %>">
  <%= group.display_name %>
</span>
```
→ render frozen `dg.group_name` (truncate + `title=`) + `_status_badge`-style pill for `dg.status`. Local `dg:`.

**Cancel button** (UI-SPEC §Detail page) — `button_to` + `turbo_confirm` + `turbo_submits_with`,
only when `@divulgacao.status_agendada?`. Precedent for `button_to` + `turbo_submits_with`:
`app/views/admin/whatsapp_groups/index.html.erb:25-29`.

---

### `app/views/admin/divulgacoes/new.html.erb` (form) — DIVU-01/02/05/06/07

**Analog A — form + `errors[:base]` box:** `app/views/admin/artes/_form.html.erb:1-11`:
```erb
<%= form_with model: arte, url: …, local: true, html: { multipart: true, data: { controller: "media-type-toggle" } } do |f| %>
  <% if arte.errors[:base].any? %>
    <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
      <% arte.errors[:base].each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>
  <div class="mb-4">
    <%= f.label :title, "Título", class: "block text-sm font-medium text-slate-900 mb-1.5" %>
    <%= f.text_field :title, class: "block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm … focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10 …" %>
  </div>
```
**Copy:** `form_with model: [@client, @divulgacao]`, the red `errors[:base]` box verbatim,
`mb-4` field rhythm, `mb-1.5` label gap, the `h-11 … focus:border-[#0F7949] focus:ring-2` input class.
Add `html: { data: { controller: "divulgacao-estimate divulgacao-preview" } }`.

**Analog B — blocked / empty states:** `app/views/admin/whatsapp_groups/index.html.erb:47-63`:
- `@instance.nil?` → `py-16 text-center` empty-state block with `text-slate-300` SVG + heading + body + primary link "Ir para o pareamento".
- `unless @instance.connected?` → amber banner `bg-[#FFFBEB] border border-[#F59E0B]/20 text-amber-800 text-sm rounded-lg p-3 leading-relaxed mb-4`.
- Connection badge: `render "admin/whatsapp_instances/connection_badge", whatsapp_instance: @instance`.

**Picker render (SEG-01)** — `app/views/admin/whatsapp_groups/_picker.html.erb` verbatim, now with `field_name`:
```erb
<%= render "admin/whatsapp_groups/picker",
      client:       @client,
      selected_ids: (@divulgacao.divulgacao_grupos.map(&:whatsapp_group_id).presence || []),
      field_name:   "divulgacao[whatsapp_group_ids][]" %>
```
The partial resolves its OWN option set (`client.whatsapp_instance&.whatsapp_groups&.where(active: true)`) —
never pass a foreign collection. With `field_name` present it renders the `data-picker-select-all`
checkbox + `data-picker-counter` markup (phase 27 shipped these unwired — `picker_controller.js` wires them).
UI-SPEC locks: do NOT paginate the picker in the form (pass no `groups:`/`pagy:`), wrap in
`max-h-[380px] overflow-y-auto` container carrying `data-divulgacao-estimate-min-value` / `-max-value`.

**Datetime (DIVU-05):** `f.datetime_field :scheduled_for, min: Time.current` — Rails 8.1
time-zone-aware attributes cast the raw `"YYYY-MM-DDTHH:MM"` string through `Time.zone` (Brasília).
Never `Time.parse`. Help text "Interpretada no fuso de Brasília (BRT)." `text-xs text-slate-500 mt-1`.

Full layout (arte select → picker → datetime → estimate block → preview panes → submit) in UI-SPEC §Layout & Interaction Contract.

---

### `app/views/admin/divulgacoes/index.html.erb` (list)

**Analog:** `app/views/admin/whatsapp_groups/index.html.erb` (header + card shell + back link) for
structure; `app/views/admin/artes/index.html.erb` for the desktop `<table>` + mobile
`block sm:hidden space-y-3` card-list pattern. Pagy: `pagy(scope, limit: 25)` in controller
(precedent `whatsapp_groups_controller.rb:10-14`), `pagy_nav(@pagy)` centered `mt-6` when `@pagy.pages > 1`.
Empty → `py-16 text-center` full-page empty state (copy in UI-SPEC).

---

### `app/views/admin/clients/show.html.erb` (edit — mirror section + entry point)

**Analog:** same file, lines 139-169 — the "Artes" card. Copy this block wholesale:
```erb
<div class="bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl mt-4">
  <div class="flex items-center justify-between border-b border-gray-100 pb-3 mb-4">
    <h2 class="text-sm font-semibold text-slate-900">Artes</h2>
    <%= link_to "Nova Arte", new_admin_arte_path(client_id: @client.id),
          class: "inline-flex items-center h-8 px-3 bg-[#0F7949] hover:bg-green-800 text-white text-xs font-medium rounded-lg transition-colors" %>
  </div>
  <% if @artes.empty? %>
    <p class="text-sm text-slate-500">Nenhuma arte cadastrada.</p>
  <% else %>
    <div class="space-y-2">
      <% @artes.each do |arte| %>
        <div class="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-slate-900 truncate"><%= arte.title.presence || "Arte sem título" %></p>
            <p class="text-xs text-slate-500 mt-0.5"><%= arte.scheduled_on.strftime("%d/%m/%Y") %> &middot; …</p>
          </div>
          <div class="ml-4 shrink-0">
            <%= link_to "Ver", admin_arte_path(arte), class: "text-xs text-[#0F7949] hover:underline" %>
          </div>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```
→ swap: `<h2>Divulgações</h2>`, button → `new_admin_client_divulgacao_path(@client)` "Nova divulgação",
empty copy "Nenhuma divulgação agendada.", rows use `divulgacao_datetime_label` + `_status_badge` +
"Ver" → `admin_client_divulgacao_path(@client, d)`, "Ver todas" when count > 5.
Place after the WhatsApp panel render (line 137), consistent with UI-SPEC.

---

### `app/helpers/admin/divulgacoes_helper.rb` (helper, transform)

**Analog:** `app/helpers/admin/whatsapp_groups_helper.rb` (full file):
```ruby
module Admin::WhatsappGroupsHelper
  def wa_groups_synced_label(instance)
    return "—" if instance&.groups_synced_at.blank?
    instance.groups_synced_at.strftime("%d/%m/%Y às %H:%M")
  end
end
```
**Copy:** `# frozen_string_literal: true`, `module Admin::DivulgacoesHelper`, `"—"` blank sentinel,
`strftime` absolute pt-BR format (INFRA-03 locks absolute, not relative).
- `divulgacao_datetime_label(t)` → `"#{t.strftime('%d/%m/%Y %H:%M')} (BRT)"` (DIVU-05 explicit offset).
- `divulgacao_duration_estimate(n, min: Divulgacao::SEND_DELAY_MIN, max: Divulgacao::SEND_DELAY_MAX)` →
  `"—"` when `n.to_i.zero?`, else `lo = (n*min/60.0).ceil` / `hi = (n*max/60.0).ceil`,
  `"≈ #{lo}–#{hi} min para #{n} grupos"` (or `"≈ #{lo} min para #{n} grupos"` when `lo == hi`).
  This is the no-JS fallback + source of truth on `#show` (full body in RESEARCH §Pattern 8).

---

### Stimulus controllers

**`divulgacao_estimate_controller.js` (partial analog):** `app/javascript/controllers/group_sync_controller.js` for
the class shape only:
```js
export default class extends Controller {
  static targets = [ "error", "timeout", "status" ]
  static values = { statusUrl: String, since: String, active: Boolean }
  connect() { if (!this.activeValue) return; /* … */ }
}
```
**Copy:** `import { Controller } from "@hotwired/stimulus"`, `static targets` / `static values` (typed),
`connect()` entry, private `_helpers`. **This controller does NO network** (pure arithmetic — count
`input[type="checkbox"][name="divulgacao[whatsapp_group_ids][]"]:checked`, rewrite `textTarget`).
Register in `app/javascript/controllers/index.js` (same as every existing controller).
`static values = { min: Number, max: Number }` read from `data-divulgacao-estimate-min-value` /
`-max-value`. Full behaviour locked in UI-SPEC §Stimulus controllers.

**`divulgacao_preview_controller.js` (role-match):** `app/javascript/controllers/media_type_toggle_controller.js`
(show/hide DOM panes on a `<select>` `change`) — read it for the toggle idiom. `static targets = ["pane", "placeholder"]`,
each pane carries `data-arte-id`; `show()` unhides the matching pane.

**`picker_controller.js` (partial):** ships with `_picker.html.erb` (reusable). Wires
`data-picker-select-all` + `data-picker-counter` (phase 27 markers, unwired). Dispatches a bubbling
`change` so `divulgacao-estimate` recomputes after select-all.

---

### `test/models/divulgacao_test.rb`

**Analog:** `test/models/arte_test.rb`:
```ruby
class ArteTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(name: "Test", password: "senha123", password_confirmation: "senha123")
    # ...
  end
  test "arte sem media_file e sem external_url é inválida" do
    arte = Arte.new(client: @client, scheduled_on: Date.current)
    assert_not arte.valid?
    assert_includes arte.errors[:base], "Precisa de arquivo ou link externo"
  end
  test "status default é pending" do
    assert_equal "pending", Arte.new.status
  end
end
```
**Copy:** `ActiveSupport::TestCase`, `Client.create!` in `setup`, `assert_not …valid?` +
`assert_includes …errors[:base], "pt-BR message"`, enum-default assertions
(`assert_equal "agendada", Divulgacao.new.status`, `"pendente"` for `DivulgacaoGrupo`).
Cover each of the 6 custom validations + the frozen snapshot.

### `test/controllers/admin/divulgacoes_controller_test.rb`

**Analog:** `test/controllers/admin/whatsapp_groups_controller_test.rb` — the canonical A×B test:
```ruby
test "show com id de grupo de OUTRO cliente -- RecordNotFound sem vazar subject/remote_jid de B" do
  client_a = @client
  instance_a = client_a.create_whatsapp_instance!(instance_name: WhatsappInstance.evolution_name_for(client_a), connection_state: :connected)
  group_a = instance_a.whatsapp_groups.create!(remote_jid: "a1@g.us", subject: "Grupo do A", active: true, synced_at: Time.current)
  client_b = Client.create!(name: "…B", password: "senha1234", password_confirmation: "senha1234")
  # … build group_b under client_b …
  get admin_client_whatsapp_group_path(client_a, group_b)
  assert_redirected_to admin_client_whatsapp_groups_path(client_a)
  refute_includes response.body.to_s, "Segredo do B"
end
```
**Copy:** `ActionDispatch::IntegrationTest`, `ADMIN_EMAIL`/`ADMIN_PASSWORD` consts +
`User.find_or_create_by!` + `sign_in_as(@admin)` in `setup`, `Client.create!` with
`password`/`password_confirmation`, the A×B two-client build, `assert_redirected_to` /
`refute_includes response.body` leak checks, `ensure` cache cleanup where relevant.
**New A×B cases for phase 28 (SEG-01/SEG-02):**
- `#create` with `arte_id` belonging to client B → `RecordNotFound` path → re-render `:new`, no `Divulgacao` created.
- `#create` with a `whatsapp_group_ids[]` id from client B's instance → same.
- `#create` with an inactive group id → same.
- `#create` happy path → `Divulgacao` + N `divulgacao_grupos` rows, each `pendente`, `group_name`/`remote_jid` frozen.
- `#cancel` sets `status: :cancelada`, no `destroy` route exists.
- `assert_no_difference "Divulgacao.count"` on each rejection (mirrors `assert_no_enqueued_jobs` idiom).

---

## Shared Patterns

### Cross-client isolation (SEG-01 / SEG-02)
**Source:** `app/controllers/admin/whatsapp_groups_controller.rb:70-85` + `app/controllers/admin/artes_controller.rb:74`
**Apply to:** every action in `Admin::DivulgacoesController`
- `@client = Client.find(params[:client_id])` (bare `.find` → 404).
- `raise ActiveRecord::RecordNotFound if @client.whatsapp_instance.nil?` before touching `.whatsapp_groups`.
- Every id from the form re-resolved through the scoped relation: `@client.artes.find(...)`,
  `@client.whatsapp_instance.whatsapp_groups.where(active: true).find(...)`.
- Model backstop: `validate :arte_e_grupos_do_mesmo_cliente`.
- NEVER `Arte.find` / `WhatsappGroup.find` bare.

### Custom validation + error surfacing
**Source:** `app/models/arte.rb:94-102` (model) + `app/views/admin/artes/_form.html.erb:5-11` (view) + `app/controllers/admin/artes_controller.rb:28-32` (controller)
**Apply to:** `Divulgacao` model, `divulgacoes/new.html.erb`, `Admin::DivulgacoesController#create`
- Private `validate :method`, guard clause, `errors.add(:base, "pt-BR sentence with what to do")`.
- View: `mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700`, one `<p>` per `errors[:base]`.
- Controller: `render :new, status: :unprocessable_entity` on failure; `redirect_to …, notice:` on success.

### Enum-as-integer
**Source:** `app/models/arte.rb:21-23`, `db/schema.rb` (`artes.status`, `whatsapp_instances.connection_state` all `t.integer`)
**Apply to:** both new models + both migrations. `t.integer :status, null: false, default: 0` + `enum :status, { … }`.
`Divulgacao` enum takes `prefix: :status` (collision avoidance with `DivulgacaoGrupo`).

### pt-BR absolute datetime formatting
**Source:** `app/helpers/admin/whatsapp_groups_helper.rb:10-14`
**Apply to:** `Admin::DivulgacoesHelper` — `strftime("%d/%m/%Y %H:%M")` + explicit `(BRT)` suffix, `"—"` for nil.

### Nested-resource card section on `clients#show`
**Source:** `app/views/admin/clients/show.html.erb:139-169` ("Artes" card)
**Apply to:** the "Divulgações" mirror section — same card shell, header row, empty-state `<p>`, row markup, "Ver" link.

### `button_to` state mutation with loading label + confirm
**Source:** `app/views/admin/whatsapp_groups/index.html.erb:25-29` (`turbo_submits_with`) + established `turbo_confirm` (admin/artes, v1.3+)
**Apply to:** the "Cancelar divulgação" button on `show` (`method: :patch`, `turbo_confirm:`, `turbo_submits_with: "Cancelando…"`) and the "Agendar divulgação" submit (`turbo_submits_with: "Agendando…"`).

### No-JS ActiveStorage media render
**Source:** `app/views/client/artes/show.html.erb:26-56`
**Apply to:** `_preview.html.erb` — `rails_storage_proxy_path`, `.image?`/`.video?` predicates, `<video controls playsinline>`, `whitespace-pre-wrap` caption, ERB auto-escape.

### ENV-fetched integer constants
**Source:** `app/services/evolution.rb:57-60`
**Apply to:** `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES` (literal `16.megabytes`) + `SEND_DELAY_MIN`/`SEND_DELAY_MAX` (`Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN_SECONDS", "25"))` / `"45"`). Add both to `.env.example`.

### Stimulus controller registration
**Source:** every file in `app/javascript/controllers/` + `index.js`
**Apply to:** the 3 new controllers — `import { Controller } from "@hotwired/stimulus"`, `static targets`/`static values`, `connect()` entry, register in `index.js`. None make network calls (unlike `group_sync`).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `app/javascript/controllers/divulgacao_estimate_controller.js` | hook | event-driven | No existing Stimulus controller does pure client-side arithmetic on checkbox count. `group_sync_controller.js` supplies the class *shape* (targets/values/connect) but its behaviour (polling fetch) is the opposite of what's needed. Build from the shape + UI-SPEC spec; no logic to copy. |

`picker_controller.js` is also close to no-analog (shape only from `group_sync`), but its DOM
contract is fully specified by the phase-27 `_picker.html.erb` markers + UI-SPEC, so it is
"partial" rather than "none".

---

## Metadata

**Analog search scope:** `app/controllers/admin/`, `app/models/`, `app/views/admin/`,
`app/views/client/artes/`, `app/helpers/admin/`, `app/javascript/controllers/`,
`config/routes.rb`, `config/initializers/`, `db/migrate/`, `test/models/`, `test/controllers/admin/`,
`app/services/evolution.rb`
**Files scanned:** ~24 read in full or in relevant part this session
**Pattern extraction date:** 2026-08-30
