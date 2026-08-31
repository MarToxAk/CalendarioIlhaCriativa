# Phase 30: Acompanhamento ao Vivo + Hardening - Pattern Map

**Mapped:** 2026-08-31
**Files analyzed:** 15 (5 new, 10 modified)
**Analogs found:** 14 / 15 (1 partial — no prior live-per-record broadcast, but `arte.rb` + turbo-rails cover it)

No RESEARCH.md (skipped per ROADMAP — incremental phase on the validated v1.5 broadcast + Phase 29 send engine).

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/models/divulgacao_grupo.rb` (mod) | model | event-driven (broadcast on commit) | `app/models/arte.rb:27` | exact (callback shape); partial (uses `broadcast_replace_to`, not manual assembly) |
| `app/models/divulgacao.rb` (mod) | model | event-driven (broadcast on commit) | `app/models/arte.rb:27` | exact |
| `app/controllers/admin/divulgacoes_controller.rb` (mod: `#resend`, `#index` includes) | controller | request-response → job enqueue | same file `#cancel` + `#create` rescue + `set_divulgacao` | exact (same file, same scoping idiom) |
| `config/routes.rb` (mod: nested `resend`) | route | request-response | `config/routes.rb:19-27` (`whatsapp_groups` collection, `divulgacoes` member `:cancel`) | exact |
| `app/views/admin/divulgacoes/_grupo_row.html.erb` (mod) | component (partial) | request-response + live-replace target | itself + `show.html.erb:48-51` (`button_to` + `turbo_confirm` + `turbo_submits_with`) | exact |
| `app/views/admin/divulgacoes/_status_badge.html.erb` | component (partial) | live-replace target | no change — already isolated partial | exact |
| `app/views/admin/divulgacoes/show.html.erb` (mod: `turbo_stream_from`, wrapper ids) | view | pub-sub subscription | `app/views/layouts/client.html.erb:18` + `layouts/admin.html.erb:24` | role-match (subscription on page, not layout) |
| `app/views/admin/divulgacoes/_progresso_resumo.html.erb` (new) | component (partial) | transform (aggregate counts) | `_status_badge.html.erb` (small locals-only partial) | role-match |
| `app/views/admin/divulgacoes/resend.turbo_stream.erb` (new) | view (turbo_stream) | request-response | none in repo (first `.turbo_stream.erb` — repo uses model-side `turbo_stream_tag`) | no analog (turbo-rails `turbo_stream.replace` API) |
| `app/views/admin/divulgacoes/index.html.erb` (mod: placar cell) | view | CRUD list | itself (`index.html.erb:47`, `:71`) | exact |
| `app/views/admin/clients/show.html.erb` (mod: placar mirror) | view | CRUD list | itself (`show.html.erb:151-167`) | exact |
| `app/helpers/admin/divulgacoes_helper.rb` (mod: 2 helpers) | helper | transform | same file `divulgacao_datetime_label`, `divulgacao_duration_estimate` | exact |
| `config/recurring.yml` (mod: prune entry) | config | batch | `config/recurring.yml:13-15` (`clear_solid_queue_finished_jobs`) | exact |
| `test/integration/cross_client_isolation_test.rb` (new, SEG-04) | test | request-response + job | `test/integration/client_isolation_test.rb` + `test/jobs/whatsapp/send_to_group_job_test.rb` | exact |
| `.env.example` (mod: `SOLID_QUEUE_FAILED_RETENTION_DAYS`) | config | n/a | existing `.env.example` | exact |

---

## Pattern Assignments

### `app/models/divulgacao_grupo.rb` (model, event-driven)

**Analog:** `app/models/arte.rb:27` (callback shape) + turbo-rails `Turbo::Broadcastable#broadcast_replace_to` (mechanism — preferred over `arte.rb`'s manual `render_partial_html` / `turbo_stream_tag` assembly per UI-SPEC line 69).

**Current file (complete):**
```ruby
class DivulgacaoGrupo < ApplicationRecord
  belongs_to :divulgacao
  belongs_to :whatsapp_group

  enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }

  validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }
  validates :group_name, :remote_jid, presence: true
end
```

**Callback pattern to copy — from `arte.rb:27`:**
```ruby
after_update_commit :broadcasts_revised_to_all, if: -> { saved_change_to_status? && revised? }
```
Phase 30 shape (guard is `saved_change_to_status?` only — no second predicate; UI-SPEC lines 381-391):
```ruby
after_update_commit :broadcast_progresso, if: -> { saved_change_to_status? }

private

def broadcast_progresso
  broadcast_replace_to [divulgacao.client, divulgacao],
    target: ActionView::RecordIdentifier.dom_id(self),
    partial: "admin/divulgacoes/grupo_row", locals: { dg: self }
  broadcast_replace_to [divulgacao.client, divulgacao],
    target: ActionView::RecordIdentifier.dom_id(divulgacao, :progresso),
    partial: "admin/divulgacoes/progresso_resumo", locals: { divulgacao: divulgacao }
end
```
Note: `arte.rb` uses `ActionView::RecordIdentifier.dom_id(self, "calendar_chip")` (string suffix) at line 74 — reuse that exact idiom for the `:progresso` / `:status_badge` suffixed targets.

**Stream name:** `[divulgacao.client, divulgacao]` — must match `turbo_stream_from [@client, @divulgacao]` on `show.html.erb` byte-for-byte (Turbo signs the stream name from the array).

---

### `app/models/divulgacao.rb` (model, event-driven)

**Analog:** `arte.rb:27` again. Insert callback near the existing `enum :status … prefix: :status` (line 26) and the `cancelar!` method (lines 48-51).

```ruby
after_update_commit :broadcast_status, if: -> { saved_change_to_status? }

private

def broadcast_status
  broadcast_replace_to [client, self],
    target: ActionView::RecordIdentifier.dom_id(self, :status_badge),
    partial: "admin/divulgacoes/status_badge", locals: { divulgacao: self }
  broadcast_replace_to [client, self],
    target: ActionView::RecordIdentifier.dom_id(self, :progresso),
    partial: "admin/divulgacoes/progresso_resumo", locals: { divulgacao: self }
end
```
- Fires automatically when Phase 29 `Whatsapp::SendToGroupJob.finalize_divulgacao_if_done` does `divulgacao.update!(status: :concluida)` (`send_to_group_job.rb:174-177`) and when `#resend` does `update!(status: :em_andamento)`.
- File already has a `private` section (line 53) with validation methods — add the callback method there, keep the `after_update_commit` declaration up with line 27-ish next to `enum`.
- `cancelar!` (lines 48-51) uses `update(status: :cancelada)` — that too now triggers `broadcast_status`, which is desired (badge goes red live).

---

### `app/controllers/admin/divulgacoes_controller.rb` (controller, request-response → job)

**Analog:** same file. Three existing patterns to compose:

**1. Scoped `.find` chain — from `set_divulgacao` (line 116) + `set_client` (line 111):**
```ruby
def set_client = @client = Client.find(params[:client_id])
def set_divulgacao = @divulgacao = @client.divulgacoes.find(params[:id])
```
`#resend` extends the chain one more hop:
```ruby
@divulgacao = @client.divulgacoes.find(params[:divulgacao_id])
@dg = @divulgacao.divulgacao_grupos.find(params[:id])   # foreign id => RecordNotFound => 404
```

**2. Guard + `redirect_to … alert:` — from `#cancel` (lines 15-23):**
```ruby
def cancel
  if @divulgacao.cancelar!
    redirect_to admin_client_divulgacao_path(@client, @divulgacao), notice: "Divulgação cancelada. Nenhum envio será feito."
  else
    redirect_to admin_client_divulgacao_path(@client, @divulgacao), alert: "Só é possível cancelar uma divulgação ainda agendada."
  end
end
```
`#resend` guard (UI-SPEC lines 347-363):
```ruby
if @divulgacao.status_cancelada?
  redirect_to admin_client_divulgacao_path(@client, @divulgacao),
              alert: "Não é possível reenviar: esta divulgação foi cancelada."
  return
end
@dg.update!(status: :pendente, error_code: nil, sent_at: nil, evolution_message_id: nil)
@divulgacao.update!(status: :em_andamento) if @divulgacao.status_concluida?
Whatsapp::SendToGroupJob.perform_later(@dg)
respond_to do |format|
  format.turbo_stream   # renders resend.turbo_stream.erb
  format.html { redirect_back fallback_location: admin_client_divulgacao_path(@client, @divulgacao),
                              notice: "Reenvio para o grupo \"#{@dg.group_name}\" reenfileirado." }
end
```
Job enqueue idiom `Whatsapp::SendToGroupJob.perform_later(@dg)` is verbatim from `divulgacoes_controller.rb:64` (`Divulgacoes::DispatchJob.set(...).perform_later(@divulgacao)`) and `send_to_group_job_test.rb`.

**3. `RecordNotFound` handling** — `#create` already `rescue ActiveRecord::RecordNotFound` (line 71) for form re-render. `#resend` does NOT rescue — it wants the default 404 (like `set_divulgacao`). CONTEXT line 72 / UI-SPEC line 190 confirm: foreign id ⇒ standard 404, no custom copy.

**`#index` change (UI-SPEC line 367):** line 7 currently
```ruby
@client.divulgacoes.includes(:arte).order(scheduled_for: :desc)
```
→ add `:divulgacao_grupos`:
```ruby
@client.divulgacoes.includes(:arte, :divulgacao_grupos).order(scheduled_for: :desc)
```
Mirror the same `includes(:divulgacao_grupos)` addition in `Admin::ClientsController#show` (`clients_controller.rb:16`).

**`before_action`:** add `:resend` — but it needs `set_client` only (it resolves `@divulgacao`/`@dg` itself), or add a dedicated `set_divulgacao` variant. Current line 3: `before_action :set_divulgacao, only: [ :show, :cancel ]`.

---

### `config/routes.rb` (route)

**Analog:** lines 19-27 (inside `namespace :admin { resources :clients do … }`):
```ruby
resources :whatsapp_groups, only: [ :index, :show ], controller: "whatsapp_groups" do
  collection do
    post :sync
    get  :sync_status
  end
end
resources :divulgacoes, only: [ :index, :new, :create, :show ] do
  member { patch :cancel }
end
```
Phase 30 — nest a `divulgacao_grupos` resource with a `member :resend` (CONTEXT lines 67-70, discretion allows a `divulgacoes` member taking `group_id` instead):
```ruby
resources :divulgacoes, only: [ :index, :new, :create, :show ] do
  member { patch :cancel }
  resources :divulgacao_grupos, only: [] do
    member { post :resend }
  end
end
```
Helper produced: `resend_admin_client_divulgacao_divulgacao_grupo_path(client, divulgacao, dg)` — matches the `button_to` target in UI-SPEC line 327.

---

### `app/views/admin/divulgacoes/_grupo_row.html.erb` (component / live-replace target)

**Analog:** itself (current, below) + `show.html.erb:48-51` for the `button_to`.

**Current file (complete):**
```erb
<li class="flex items-center gap-3 py-3 px-4 border-b border-gray-100 last:border-0">
  <span class="text-sm font-medium text-slate-900 min-w-0 flex-1 truncate" title="<%= dg.group_name %>"><%= dg.group_name %></span>
  <% case dg.status %>
  <% when "pendente" %>
    <span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border bg-slate-100 text-slate-600 border-slate-200 shrink-0">
      <span aria-hidden="true">●</span> Pendente
    </span>
  <% when "enviado" %>
    <span class="… bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20 shrink-0"><span aria-hidden="true">●</span> Enviado</span>
  <% when "falhou" %>
    <span class="… bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20 shrink-0"><span aria-hidden="true">●</span> Falhou</span>
  <% when "incerto" %>
    <span class="… bg-[#FFFBEB] text-amber-800 border-[#F59E0B]/20 shrink-0"><span aria-hidden="true">●</span> Incerto</span>
  <% end %>
</li>
```

**Additive edits (UI-SPEC lines 295-345):**
1. `<li>` gains `id="<%= dom_id(dg) %>"` and `flex items-center` → `flex items-start`.
2. Name wrapped in `div.flex.flex-col.gap-1.min-w-0.flex-1` with a sub-line:
   - `enviado` + `sent_at.present?` → `Enviado em <%= divulgacao_datetime_label(dg.sent_at) %>`
   - `falhou`/`incerto` + `error_code.present?` → `<%= divulgacao_grupo_error_label(dg) %>` in a `break-words` span
3. `button_to "Reenviar"` when `dg.status.in?(%w[falhou incerto]) && !dg.divulgacao.status_cancelada?`.

**`button_to` pattern — copy from `show.html.erb:48-51` (the Cancelar button):**
```erb
<%= button_to "Cancelar divulgação", cancel_admin_client_divulgacao_path(@client, @divulgacao),
      method: :patch,
      data: { turbo_confirm: "Cancelar esta divulgação? …", turbo_submits_with: "Cancelando…" },
      class: "inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors cursor-pointer" %>
```
Phase 30 "Reenviar" (secondary style, `h-8`, `method: :post`, `form_class: "shrink-0"`, `turbo_confirm` names `dg.group_name`, `turbo_submits_with: "Reenfileirando…"`) — full ERB in UI-SPEC lines 326-334.

---

### `app/views/admin/divulgacoes/_status_badge.html.erb` (live-replace target)

**No content change.** Phase 30 only wraps its render site on `show.html.erb` (line 42) with `<span id="<%= dom_id(@divulgacao, :status_badge) %>">…</span>` and adds it as a `broadcast_replace_to` target. Already a clean locals-only (`divulgacao:`) partial — the model callback re-renders it verbatim.

---

### `app/views/admin/divulgacoes/show.html.erb` (pub-sub subscription)

**Analog:** `app/views/layouts/client.html.erb:18`
```erb
<%= turbo_stream_from @client, channel: ClientCalendarChannel if @client %>
```
and `layouts/admin.html.erb:24`
```erb
<%= turbo_stream_from Current.user, channel: AdminNotificationsChannel if Current.user %>
```
Phase 30 puts a **default `Turbo::StreamsChannel`** subscription (no `channel:` arg) on the page, not the layout (UI-SPEC line 51, 250):
```erb
<%= turbo_stream_from [@client, @divulgacao] %>
```
placed near the top of `show.html.erb` (after `content_for(:page_title)`, line 3).

**Other edits to `show.html.erb`:**
- line 42 `<dd><%= render "status_badge", divulgacao: @divulgacao %></dd>` → wrap render in `<span id="<%= dom_id(@divulgacao, :status_badge) %>">`.
- Grupos card (lines 56-67): insert `<%= render "progresso_resumo", divulgacao: @divulgacao %>` between the `<h2>` (line 57) and `<ul>` (line 59), inside the `if …any?` branch.
- `<ul>` loop (lines 60-62) unchanged — `order(:group_name)` stays; `_grupo_row` now carries its own `id`.

Admin session auth already enforced by `Admin::BaseController` (controller extends it, line 1) — no channel-level auth needed.

---

### `app/views/admin/divulgacoes/_progresso_resumo.html.erb` (NEW — component, transform)

**Analog:** `_status_badge.html.erb` (small partial, single local, `case`/count logic inline).

**Contract (UI-SPEC lines 273-293):** locals `divulgacao:`. One `<p id="<%= dom_id(divulgacao, :progresso) %>" class="text-sm text-slate-600 mb-4">` with four always-shown segments `{X} enviados · {Y} falhou · {Z} pendente · {W} incerto`. Counts via `divulgacao.divulgacao_grupos.group(:status).count` (single admin view — query acceptable) or `group_by` on the loaded assoc. Numerals `font-medium text-slate-900`, words `text-slate-500`, `·` `text-slate-300`. Rendered only when `divulgacao_grupos.any?` (the `show.html.erb` `else` keeps the existing `Nenhum grupo.` line).

---

### `app/views/admin/divulgacoes/resend.turbo_stream.erb` (NEW — view, request-response)

**No repo analog** — this is the first `*.turbo_stream.erb` template in the codebase (existing real-time code is model-side `Turbo::Broadcastable` / manual `turbo_stream_tag` in `arte.rb` & `approval_response.rb`). Use the turbo-rails view helper (`turbo-rails` is in the Gemfile, line 14):
```erb
<%= turbo_stream.replace dom_id(@dg) do %>
  <%= render "grupo_row", dg: @dg, just_resent: true %>
<% end %>
<%= turbo_stream.replace dom_id(@divulgacao, :progresso) do %>
  <%= render "progresso_resumo", divulgacao: @divulgacao %>
<% end %>
```
Targets are identical to the model-broadcast targets (UI-SPEC line 76). `just_resent: true` triggers the muted `· reenfileirado` note — passed **only** here, never by the partial's normal render or the live broadcast (UI-SPEC lines 321-323, 340-341). `_grupo_row` must therefore accept `just_resent:` as an optional local (`local_assigns[:just_resent]`).

---

### `app/views/admin/divulgacoes/index.html.erb` (view, CRUD list)

**Analog:** itself. Desktop `Grupos` cell — line 47:
```erb
<td class="py-3 px-4 text-sm text-slate-700"><%= d.divulgacao_grupos.size %></td>
```
→ two lines: keep count on line 1, add
```erb
<span class="block text-xs text-slate-500"><%= divulgacao_placar(d) %></span>
```
Mobile card sub-line — line 71:
```erb
<p class="text-xs text-slate-500 mt-1"><%= divulgacao_datetime_label(d.scheduled_for) %> · <%= d.divulgacao_grupos.size %> grupo(s)</p>
```
→ append ` · <%= divulgacao_placar(d) %>`. N+1 avoided by the `includes(:divulgacao_grupos)` controller change.

---

### `app/views/admin/clients/show.html.erb` (view, CRUD list — mirror)

**Analog:** itself, lines 151-167 (recent divulgações list, `@divulgacoes.first(5)`). After the datetime `<p>` (line 157-159):
```erb
<p class="text-xs text-slate-500 mt-0.5"><%= divulgacao_datetime_label(d.scheduled_for) %></p>
```
append `divulgacao_placar(d)` as a `text-xs text-slate-500` line/span. Controller `clients_controller.rb:16` gets `includes(:arte, :divulgacao_grupos)`.

---

### `app/helpers/admin/divulgacoes_helper.rb` (helper, transform)

**Analog:** same file — `divulgacao_datetime_label` (lines 7-11) and `divulgacao_duration_estimate` (lines 18-24). Same shape: guard for zero/blank → `"—"`, no `n == 1` pluralization (comment lock, line 17).

**Add (UI-SPEC lines 413-434):**
```ruby
SENTINEL_ERROR_LABELS = {
  "arte_nao_aprovada"      => "Motivo: a aprovação da arte foi retirada antes do envio.",
  "instancia_desconectada" => "Motivo: o número do cliente estava desconectado no momento do envio.",
}.freeze

def divulgacao_grupo_error_label(dg)
  SENTINEL_ERROR_LABELS[dg.error_code] || "Motivo: #{dg.error_code}"
end

def divulgacao_placar(divulgacao)
  by = divulgacao.divulgacao_grupos.group_by(&:status)
  total = divulgacao.divulgacao_grupos.size
  return "—" if total.zero?
  enviado, falhou   = by["enviado"].to_a.size, by["falhou"].to_a.size
  incerto, pendente = by["incerto"].to_a.size, by["pendente"].to_a.size
  return "#{pendente} pendentes" if pendente == total
  parts = ["#{enviado} enviados", "#{falhou} falhou"]
  parts << "#{incerto} incerto"  if incerto.positive?
  parts << "#{pendente} pendente" if pendente.positive?
  parts.join(" · ")
end
```
The two sentinel codes match `send_to_group_job.rb:141` (`"arte_nao_aprovada"`) and `:104`/`:148` (`"instancia_desconectada"`). `divulgacao_grupo_error_label` is **copy mapping only** — it never re-runs `Whatsapp::SendToGroupJob.sanitize_error_code` (already applied upstream, `send_to_group_job.rb:223-229`).

Helper test analog: `test/helpers/admin/divulgacoes_helper_test.rb` — `ActionView::TestCase`, one `assert_equal` per case incl. the `"—"` zero-state and the "1 grupos" no-pluralize case.

---

### `config/recurring.yml` (config, batch)

**Analog — current file (complete):**
```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
```

**Add (CONTEXT lines 133-143) under BOTH `production:` and a new `development:` block (CONTEXT line 141 / INFRA-02):**
```yaml
  prune_solid_queue_failed_executions:
    command: "SolidQueue::FailedExecution.where('created_at < ?', Integer(ENV.fetch('SOLID_QUEUE_FAILED_RETENTION_DAYS', '14')).days.ago).find_each(&:discard)"
    schedule: every day at 3am
```

**IMPORTANT — verified against `solid_queue-1.4.0` + `db/queue_schema.rb:22-27`:**
- `SolidQueue::FailedExecution` **has `created_at` (`null: false`)**, `belongs_to :job` (via `SolidQueue::Execution`, `execution.rb:12`), unique index on `job_id`.
- FK `solid_queue_failed_executions.job_id → solid_queue_jobs` is `on_delete: :cascade` (`queue_schema.rb:125`) — cascade is **parent→child only**: deleting the *job* removes the failed_execution, **NOT** the reverse.
- ⇒ **the CONTEXT's proposed `.delete_all` on `FailedExecution` orphans the `solid_queue_jobs` rows** (the job args in clear text — exactly what INFRA-07 targets). Use one of:
  - `...find_each(&:discard)` — `Execution#discard` (`execution.rb:73-79`) does `job.destroy; destroy` inside `with_lock`. Cleanest, row-by-row.
  - `SolidQueue::FailedExecution.where('created_at < ?', ...).discard_all_in_batches` — `Execution.discard_all_in_batches` (`execution.rb:31-49`) deletes jobs then executions in `batch_size: 500` transactions. But it ignores the `where` scope's non-`limit` filtering? — it operates on `self` (the relation), so `.where(...).discard_all_in_batches` respects the scope. Preferred for volume.
- Planner: pick `discard_all_in_batches` for the batch semantics mirroring `clear_finished_in_batches`; the one-liner `command:` form keeps parity with the existing entry.

---

### `test/integration/cross_client_isolation_test.rb` (NEW — test, SEG-04)

**Analog A — `test/integration/client_isolation_test.rb` (complete, read):**
```ruby
class ClientIsolationTest < ActionDispatch::IntegrationTest
  def setup
    @client_a = Client.create!(name: "Cliente A", password: "senhaA", password_confirmation: "senhaA")
    @client_b = Client.create!(name: "Cliente B", password: "senhaB", password_confirmation: "senhaB")
    @arte_b = Arte.create!(client: @client_b, scheduled_on: Date.current, external_url: "https://drive.google.com/file/exemplo")
  end

  test "escopo de artes por cliente impede acesso cross-client (isolamento model)" do
    assert_raises(ActiveRecord::RecordNotFound) { @client_a.artes.find(@arte_b.id) }
  end
end
```
This is the exact shape SEG-04 wants — `assert_raises(ActiveRecord::RecordNotFound)` on a scoped `.find`, and it "fails if someone swaps `@client.divulgacoes.find` for `Divulgacao.find`" (CONTEXT line 264).

**Analog B — `test/jobs/whatsapp/send_to_group_job_test.rb` setup (lines 9-42) + stub idiom (lines 44-52):**
```ruby
class Whatsapp::SendToGroupJobTest < ActiveJob::TestCase
  def setup
    ActiveStorage::Current.url_options = { host: "example.com", protocol: "https" }
    @client = Client.create!(name: "...", password: "senha1234", password_confirmation: "senha1234")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected, token: "SEGREDO-INSTANCIA", groups_synced_at: Time.current)
    @group = @instance.whatsapp_groups.create!(remote_jid: "g1@g.us", subject: "Grupo Um", active: true, synced_at: Time.current)
    @arte = @client.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "...")
    @arte.media_file.attach(io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")), filename: "sample.jpg", content_type: "image/jpeg")
    @arte.save!
    @divulgacao = @client.divulgacoes.create!(arte: @arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ])
    @group_row = @divulgacao.divulgacao_grupos.first
  end

  test "..." do
    Evolution::Client.stub(:send_media, ->(name, number:, mediatype:, media:, api_key:, caption:) {
      assert_equal @instance.token, api_key   # SEG-03 assertion style
      { "key" => { "id" => "MSG1" } }
    }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end
  end
end
```

**SEG-04 test build (CONTEXT lines 113-125):**
1. Build `client_a` (arte approved + instance + groups) and `client_b` (instance + own groups) — dual-client setup from Analog A, enriched with the WhatsApp scaffolding from Analog B.
2. Assert `client_a.divulgacoes` cannot be created referencing a `client_b` `whatsapp_group` — either the controller `.find` raises `RecordNotFound` (drive via `post admin_client_divulgacoes_path`, needs admin sign-in — see `divulgacoes_controller_test.rb:7-11` `sign_in_as`), or `Divulcagao#arte_e_grupos_do_mesmo_cliente` (`divulgacao.rb:101-109`) adds a `base` error → `assert_not divulgacao.valid?`.
3. Force-build a cross-client `DivulgacaoGrupo` at model level, run `Whatsapp::SendToGroupJob.perform_now`, stub `Evolution::Client` (`.stub(:send_text …)` / `.stub(:send_media …)`) and assert it's **never** called with `client_b`'s `remote_jid` — or that the job marks `falhou`/`instancia_desconectada` before any I/O (the `instance&.connected?` guard, `send_to_group_job.rb:147`).
4. Token-chain belt: `assert_not_equal client_a...whatsapp_instance.token, client_b...whatsapp_instance.token` and that `SendToGroupJob` resolves the token via `divulgacao.client.whatsapp_instance.token` (`send_to_group_job.rb:234`, SEG-03) — same assertion style as `send_to_group_job_test.rb:48`.

**Live-progress test (SC1, `<specifics>` line 271):** turbo-rails ships `Turbo::Broadcastable::TestHelper` (`assert_turbo_stream_broadcasts [@client, @divulgacao], count: n { ... }`). Capybara + selenium-webdriver are in the Gemfile (lines 84-85) so a system test is also possible; prefer the broadcast assertion (no browser). Assert that flipping `@group_row.update!(status: :enviado)` broadcasts a `replace` on `dom_id(dg)` and `dom_id(divulgacao, :progresso)`.

**Run invocation (CONTEXT line 126, memory `test_db_permission`):**
```
POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/integration/cross_client_isolation_test.rb
```
If `bin/rails test` cannot run (test DB owned by another OS user), planner must plan verification-by-inspection and leave the test written + ready for operator UAT.

---

### `.env.example` (config)

**Analog:** existing `.env.example` (present at repo root). Add a documented line for `SOLID_QUEUE_FAILED_RETENTION_DAYS` (default `14`), grouped near other solid_queue / `JOB_CONCURRENCY` vars. Mirrors the `WHATSAPP_SEND_DELAY_MIN_SECONDS` cross-phase env-var contract convention (`divulgacao.rb:17`, read in one place).

---

## Shared Patterns

### Live broadcast (model → Turbo Stream)
**Source:** `app/models/arte.rb:27` (callback guard) + turbo-rails `broadcast_replace_to`
**Apply to:** `divulgacao_grupo.rb`, `divulgacao.rb`
```ruby
after_update_commit :broadcast_x, if: -> { saved_change_to_status? }
# body: broadcast_replace_to [client, divulgacao], target: ActionView::RecordIdentifier.dom_id(record, :suffix), partial: "...", locals: {...}
```
- Guard is `saved_change_to_*?` — never an unguarded `after_commit`.
- Stream name array `[client, divulgacao]` must be byte-identical between `turbo_stream_from` (view) and `broadcast_replace_to` (model).
- `broadcast_replace_to` (high-level) is preferred over `arte.rb`/`approval_response.rb`'s manual `render_partial_html` + `turbo_stream_tag` for per-record replacement (UI-SPEC line 69).
- **Do NOT touch** `AdminNotificationsChannel` / `ClientCalendarChannel` — the approval flow keeps them (CONTEXT line 43).

### Cross-client scoping (the SEG barrier)
**Source:** `divulgacoes_controller.rb:111,116` (`set_client`, `set_divulgacao`)
**Apply to:** `#resend` action, SEG-04 test
```ruby
@client.divulgacoes.find(params[:divulgacao_id]).divulgacao_grupos.find(params[:id])
```
- Every id re-resolved through the client association — never `Divulgacao.find` / `DivulgacaoGrupo.find` / `WhatsappGroup.find` on a bare param (`scoped_active_groups`, line 121, is the canonical "never bare `.find`" comment).
- Foreign id ⇒ `ActiveRecord::RecordNotFound` ⇒ Rails 404. No custom copy (CONTEXT line 72).
- Model backstop already exists: `Divulcagao#arte_e_grupos_do_mesmo_cliente` (`divulgacao.rb:101-109`).

### `button_to` mutating action
**Source:** `show.html.erb:48-51` (Cancelar divulgação)
**Apply to:** "Reenviar" button in `_grupo_row`
```erb
<%= button_to LABEL, PATH, method: :post,
      data: { turbo_confirm: "… name the group, not an id …", turbo_submits_with: "Reenfileirando…" },
      class: "inline-flex items-center h-8 px-3 border border-gray-200 rounded-lg text-xs font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors" %>
```
- `turbo_confirm` for dangerous/irreversible actions (v1.3+); it **must interpolate `dg.group_name`**, never an id (`<specifics>` line 268).
- `turbo_submits_with` for in-flight disable + label swap (mirrors "Cancelando…").
- Secondary (white/grey) style, **not** the `#EE3537` destructive fill — "Reenviar" is recovery, not destructive (UI-SPEC lines 146-147).

### Recurring-job retention entry
**Source:** `config/recurring.yml:13-15` (`clear_solid_queue_finished_jobs`)
**Apply to:** `prune_solid_queue_failed_executions` (prod + new dev block)
- `command:` one-liner form, `schedule:` natural-language. Add to BOTH `production` and `development` (INFRA-02: scheduled jobs must survive dev restart for UAT).

### Job enqueue, never synchronous I/O in controller
**Source:** `divulgacoes_controller.rb:64`, `send_to_group_job_test.rb`
**Apply to:** `#resend`
```ruby
Whatsapp::SendToGroupJob.perform_later(@dg)
```
- Reuses the Phase 29 job verbatim: atomic claim (`send_to_group_job.rb:135`), `arte.reload.approved?`, `instance&.connected?`, `divulgacao.status_cancelada?` re-check, `limits_concurrency to: 1, key: instance_id` (`:57-61`), full error taxonomy (`:71-120`), `finalize_divulgacao_if_done` (`:174-177`).
- `#resend` only resets the row to `pendente` (clears `error_code`/`sent_at`/`evolution_message_id`) and reopens `concluida → em_andamento` **in the controller**, not in the job (CONTEXT line 164).

### Helper: pt-BR formatting with zero-state guard
**Source:** `divulgacoes_helper.rb:7-24`
**Apply to:** `divulgacao_placar`, `divulgacao_grupo_error_label`
- `return "—" if total.zero?` pattern; no `n == 1` pluralization (comment lock).
- Test as `ActionView::TestCase`, one `assert_equal` per branch (`divulgacoes_helper_test.rb`).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `app/views/admin/divulgacoes/resend.turbo_stream.erb` | view (turbo_stream template) | request-response | First `*.turbo_stream.erb` in the repo — all existing real-time HTML is assembled model-side (`arte.rb`, `approval_response.rb`) via `turbo_stream_tag` strings. Use turbo-rails' `turbo_stream.replace dom_id(x) do … end` view API (gem present, Gemfile:14). Targets mirror the model-broadcast targets exactly. |

Partial gap: no prior **per-record live replace** (existing broadcasts are toast/badge/append on global user channels). Mitigated — `arte.rb:27` gives the callback shape and turbo-rails `Turbo::Broadcastable` gives `broadcast_replace_to`; the two compose without a bespoke channel.

---

## Metadata

**Analog search scope:** `app/models/`, `app/controllers/admin/`, `app/views/admin/divulgacoes/`, `app/views/admin/clients/`, `app/views/layouts/`, `app/jobs/whatsapp/`, `app/helpers/admin/`, `config/`, `test/`, `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/`, `db/queue_schema.rb`
**Files scanned:** ~30
**Pattern extraction date:** 2026-08-31
