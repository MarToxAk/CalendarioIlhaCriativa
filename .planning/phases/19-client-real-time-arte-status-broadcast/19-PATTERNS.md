# Phase 19: Client Real-time + Arte Status Broadcast - Pattern Map

**Mapped:** 2026-06-06
**Files analyzed:** 10 (7 new + 3 modified)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `app/channels/client_calendar_channel.rb` | channel | event-driven | `app/channels/admin_notifications_channel.rb` | exact |
| `app/models/arte.rb` (modificar) | model | event-driven | `app/models/approval_response.rb` | exact |
| `app/views/layouts/client.html.erb` (modificar) | layout | request-response | `app/views/layouts/admin.html.erb` | exact |
| `app/views/client/home/index.html.erb` (modificar) | view | request-response | `app/views/client/home/index.html.erb` (si mesmo) | self |
| `app/views/client/home/_month_calendar.html.erb` (modificar) | partial | request-response | `app/views/client/home/_month_calendar.html.erb` (si mesmo) | self |
| `app/views/client/home/_arte_calendar_chip.html.erb` | partial | request-response | `app/views/client/home/_month_calendar.html.erb` (link_to extraído) | role-match |
| `app/views/client/home/_calendar_summary.html.erb` | partial | request-response | `app/views/client/home/index.html.erb` (div extraída) | role-match |
| `app/views/client/shared/_arte_revised_toast.html.erb` | partial | event-driven | `app/views/admin/shared/_approval_toast.html.erb` | exact |
| `test/channels/client_calendar_channel_test.rb` | test | — | `test/channels/admin_notifications_channel_test.rb` | exact |
| `test/models/arte_test.rb` (modificar) | test | — | `test/models/arte_test.rb` (si mesmo) + `approval_response` pattern | role-match |

---

## Pattern Assignments

### `app/channels/client_calendar_channel.rb` (channel, event-driven)

**Analog:** `app/channels/admin_notifications_channel.rb`

**Estrutura completa do analog** (linhas 1-6):
```ruby
class AdminNotificationsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user
    stream_for current_user
  end
end
```

**Padrão a copiar — trocar `current_user` por `current_client` e nome da classe:**
```ruby
class ClientCalendarChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_client
    stream_for current_client
  end
end
```

**Nota crítica:** `reject` (sem prefixo) é o método correto do `ActionCable::Channel::Base` — conforme usado em `AdminNotificationsChannel`. Não usar `reject_unauthorized_connection` (esse é método de `Connection`, não de `Channel`).

**`current_client` disponível via Connection** (`app/channels/application_cable/connection.rb` linhas 3-4):
```ruby
identified_by :current_user, :current_client
# set_current_client autentica via request.params[:token]
```

---

### `app/models/arte.rb` (model, event-driven) — MODIFICAR

**Analog:** `app/models/approval_response.rb` (linhas 11, 27-67)

**Padrão do callback** (analog linha 11):
```ruby
after_create_commit :broadcasts_to_admin
# → adaptar para:
after_update_commit :broadcasts_revised_to_all,
  if: -> { saved_change_to_status? && revised? }
```

**Padrão do método de broadcast** (analog linhas 27-58):
```ruby
def broadcasts_to_admin
  admin = User.order(:id).first
  return unless admin

  arte_with_client = Arte.includes(:client).find(arte_id)
  badge_count      = Arte.change_requested.count

  toast_html    = render_partial_html(
    partial: "admin/shared/approval_toast",
    locals:  { approval_response: self, arte: arte_with_client }
  )
  badge_html    = render_partial_html(
    partial: "admin/shared/sidebar_badge",
    locals:  { badge_count: badge_count }
  )
  # ...

  content = [
    turbo_stream_tag("append",  "admin-toast-region", toast_html),
    turbo_stream_tag("replace", "sidebar-badge",      badge_html),
    # ...
  ].join

  AdminNotificationsChannel.broadcast_to(admin, content)
end
```

**Padrão `dom_id` fora de view context** (analog linha 54):
```ruby
ActionView::RecordIdentifier.dom_id(arte_with_client)
# Para prefix "calendar_chip":
ActionView::RecordIdentifier.dom_id(self, "calendar_chip")  # => "arte_42_calendar_chip"
```

**Helpers privados a copiar** (analog linhas 61-67):
```ruby
def render_partial_html(partial:, locals:)
  ApplicationController.render(partial: partial, locals: locals, formats: [ :html ])
end

def turbo_stream_tag(action, target, template_html = "")
  %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
end
```

**Broadcast duplo (Phase 19 — dois canais):**
```ruby
ClientCalendarChannel.broadcast_to(client, client_streams)
AdminNotificationsChannel.broadcast_to(admin, admin_stream)
```

**Cálculo do summary — usar queries SQL (não Ruby enumeration):**
```ruby
# Correto no model callback (sem acesso a @artes em memória):
artes_do_mes = client.artes.where(scheduled_on: current_month_start..current_month_end)
summary = {
  total:            artes_do_mes.count,
  approved:         artes_do_mes.where(status: :approved).count,
  pending:          artes_do_mes.where(status: [:pending, :revised]).count,
  change_requested: artes_do_mes.where(status: :change_requested).count
}
```

**Enum `:status` existente no model** (arte.rb linha 23):
```ruby
enum :status, { pending: 0, approved: 1, change_requested: 2, revised: 3 }
# Scopes gerados: .change_requested, .revised, etc.
```

---

### `app/views/layouts/client.html.erb` (layout) — MODIFICAR

**Analog:** `app/views/layouts/admin.html.erb` (linhas 23-25)

**Padrão a copiar** (admin.html.erb linhas 23-25):
```erb
<body class="min-h-screen bg-gray-50 flex">
  <%= turbo_stream_from Current.user, channel: AdminNotificationsChannel if Current.user %>
  <div id="admin-toast-region" class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end"></div>
```

**Adaptação para o cliente** — inserir imediatamente após `<body ...>` no client.html.erb (linha 14):
```erb
<body class="min-h-screen bg-white flex flex-col">
  <%= turbo_stream_from @client, channel: ClientCalendarChannel if @client %>
  <div id="client-toast-region" class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end"></div>
```

**Guard `if @client`:** mesmo padrão do admin (`if Current.user`). Defesa em profundidade — `@client` é definido em todas as páginas do cliente via `load_client_from_token` em `ClientController`, mas o guard protege contra futuros controllers inesperados.

---

### `app/views/client/home/index.html.erb` (view) — MODIFICAR

**Analog:** si mesmo (linhas 25-40) — extrair a div de resumo para partial

**Estado atual** (linhas 25-40):
```erb
<% if @summary[:total] > 0 %>
  <div role="status" aria-label="Resumo do mês" class="flex flex-wrap gap-2 mb-4 justify-center">
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700">
      <span class="font-semibold"><%= @summary[:total] %></span> total
    </span>
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
      <span class="font-semibold"><%= @summary[:approved] %></span> aprovadas
    </span>
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
      <span class="font-semibold"><%= @summary[:pending] %></span> pendentes
    </span>
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
      <span class="font-semibold"><%= @summary[:change_requested] %></span> pediu alteração
    </span>
  </div>
<% end %>
```

**Após modificação** — substituir bloco acima por render do partial:
```erb
<%= render "client/home/calendar_summary", summary: @summary %>
```

---

### `app/views/client/home/_month_calendar.html.erb` (partial) — MODIFICAR

**Analog:** si mesmo (linhas 32-38) — extrair o `link_to` da arte para partial

**Estado atual do loop** (linhas 32-38):
```erb
<% artes_do_dia.each do |arte| %>
  <%= link_to client_arte_path(token: client.access_token, id: arte),
        class: "mt-1 flex items-center gap-1 p-1 rounded bg-gray-50 hover:bg-orange-50 transition-colors" do %>
    <%= render "client/shared/platform_icon", arte: arte, size: 14 %>
    <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
  <% end %>
<% end %>
```

**Após modificação** — substituir por render do partial (adiciona `id: dom_id(arte, "calendar_chip")`):
```erb
<% artes_do_dia.each do |arte| %>
  <%= render "client/home/arte_calendar_chip", arte: arte, client: client %>
<% end %>
```

---

### `app/views/client/home/_arte_calendar_chip.html.erb` (partial, NOVO)

**Analog:** `app/views/client/home/_month_calendar.html.erb` linhas 32-38 (link_to extraído)

**Conteúdo do partial** — reutiliza `_arte_status_badge` e `_platform_icon` existentes:
```erb
<%# Locals: arte (Arte), client (Client) %>
<%= link_to client_arte_path(token: client.access_token, id: arte),
      id: dom_id(arte, "calendar_chip"),
      class: "mt-1 flex items-center gap-1 p-1 rounded bg-gray-50 hover:bg-orange-50 transition-colors" do %>
  <%= render "client/shared/platform_icon", arte: arte, size: 14 %>
  <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
<% end %>
```

**`_arte_status_badge` aceita `compact: true`** (arte_status_badge.html.erb linhas 1-2, 12-14):
```erb
<%
  compact ||= false
  # ...
%>
<% if compact %>
  <span class="px-1 py-0.5 text-[10px] font-medium rounded <%= config[:classes] %>">
```

---

### `app/views/client/home/_calendar_summary.html.erb` (partial, NOVO)

**Analog:** `app/views/client/home/index.html.erb` linhas 25-40 (div extraída)

**Conteúdo do partial** — `id="calendar-summary"` deve estar na `div` externa (sempre presente no DOM, mesmo quando total == 0, para que o Turbo Stream replace sempre encontre o target):
```erb
<%# Locals: summary (Hash com :total, :approved, :pending, :change_requested) %>
<div id="calendar-summary" role="status" aria-label="Resumo do mês"
     class="flex flex-wrap gap-2 mb-4 justify-center <%= 'hidden' if summary[:total] == 0 %>">
  <span class="px-3 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700">
    <span class="font-semibold"><%= summary[:total] %></span> total
  </span>
  <span class="px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
    <span class="font-semibold"><%= summary[:approved] %></span> aprovadas
  </span>
  <span class="px-3 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
    <span class="font-semibold"><%= summary[:pending] %></span> pendentes
  </span>
  <span class="px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
    <span class="font-semibold"><%= summary[:change_requested] %></span> pediu alteração
  </span>
</div>
```

**Nota (Pitfall 3 do RESEARCH.md):** Colocar o `id="calendar-summary"` fora da condicional `if total > 0` garante que o elemento existe no DOM. Usar `hidden` CSS em vez de omitir o elemento. O Turbo Stream `replace` falha silenciosamente se o target não existe no DOM.

---

### `app/views/client/shared/_arte_revised_toast.html.erb` (partial, NOVO)

**Analog:** `app/views/admin/shared/_approval_toast.html.erb` (linhas 1-19)

**Estrutura do analog**:
```erb
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
  <div class="flex-1 min-w-0">
    <p class="text-sm font-semibold text-slate-900 truncate">
      <%= arte.client.name %>
    </p>
    <%= render "admin/approvals/decision_badge", approval_response: approval_response %>
  </div>
  <%= link_to "Ver arte", admin_arte_path(arte),
        class: "text-xs text-[#0F7949] font-medium hover:underline shrink-0" %>
  <button data-action="click->toast#dismiss"
          class="text-slate-400 hover:text-slate-600 shrink-0 leading-none"
          aria-label="Fechar notificação">
    &times;
  </button>
</div>
```

**Adaptação para o cliente** — mesma estrutura, conteúdo diferente:
```erb
<%# Locals: arte (Arte), client (Client) %>
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
  <div class="flex-1 min-w-0">
    <p class="text-sm font-semibold text-slate-900">Arte revisada</p>
    <p class="text-xs text-slate-500 truncate">
      <%= arte.title.presence || arte.platform.humanize %>
      &middot;
      <%= l(arte.scheduled_on, format: :short) %>
    </p>
  </div>
  <%= link_to "Ver arte", client_arte_path(token: client.access_token, id: arte),
        class: "text-xs text-[#0F7949] font-medium hover:underline shrink-0" %>
  <button data-action="click->toast#dismiss"
          class="text-slate-400 hover:text-slate-600 shrink-0 leading-none"
          aria-label="Fechar notificação">
    &times;
  </button>
</div>
```

**`toast_controller.js` — comportamento relevante** (linhas 8-9):
```javascript
connect() {
  this._enforceLimit()       // hardcoda "admin-toast-region" → no-op no cliente
  this._timerId = setTimeout(() => this.dismiss(), DISMISS_DELAY)  // auto-dismiss 5s — funciona
}
```

**Advertência:** `_enforceLimit()` (linha 27) usa `document.getElementById("admin-toast-region")` — retorna `null` no layout do cliente (region é `client-toast-region`). O limite de 3 toasts não se aplica ao cliente. Auto-dismiss de 5s e botão × funcionam normalmente. Zero JavaScript novo — comportamento aceito (D-09).

---

### `test/channels/client_calendar_channel_test.rb` (test, NOVO)

**Analog:** `test/channels/admin_notifications_channel_test.rb` (linhas 1-16)

**Estrutura completa do analog:**
```ruby
require "test_helper"

class AdminNotificationsChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current user" do
    stub_connection(current_user: users(:one))
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for users(:one)
  end

  test "rejects subscription without current user" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert subscription.rejected?
  end
end
```

**Adaptação — trocar `current_user`/`users(:one)` por `current_client`/`clients(:one)`:**
```ruby
require "test_helper"

class ClientCalendarChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current client" do
    stub_connection(current_client: clients(:one))
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for clients(:one)
  end

  test "rejects subscription without current client" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert subscription.rejected?
  end
end
```

**Nota:** Verificar se existe fixture `clients(:one)` em `test/fixtures/clients.yml`. Se não existir, criar a fixture ou usar `Client.create!` no setup (padrão do `arte_test.rb`).

---

### `test/models/arte_test.rb` (test) — MODIFICAR

**Analog:** si mesmo (setup linhas 3-15) + padrão de stub de `approval_response_test.rb`

**Setup existente a reutilizar** (linhas 3-15):
```ruby
class ArteTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(
      name: "Test",
      password: "senha123",
      password_confirmation: "senha123"
    )
    @arte_valida = Arte.new(
      client: @client,
      scheduled_on: Date.current,
      external_url: "https://drive.google.com/file/exemplo"
    )
  end
```

**Padrão de stub para broadcasts** (padrão Ruby Minitest — sem Mocha):
```ruby
test "revised! dispara broadcast para ClientCalendarChannel e AdminNotificationsChannel" do
  arte = Arte.create!(client: @client, scheduled_on: Date.current,
                      platform: :instagram, media_type: :image,
                      status: :change_requested,
                      external_url: "https://drive.google.com/file/test")

  client_calls = []
  admin_calls  = []

  ClientCalendarChannel.stub(:broadcast_to,      ->(c, content) { client_calls << content }) do
    AdminNotificationsChannel.stub(:broadcast_to, ->(u, content) { admin_calls  << content }) do
      arte.revised!
    end
  end

  assert_equal 1, client_calls.length
  assert_equal 1, admin_calls.length
  assert_equal 3, client_calls.first.scan(/<turbo-stream/).count,
               "Cliente deve receber 3 turbo streams: chip, summary, toast"
  assert_equal 1, admin_calls.first.scan(/<turbo-stream/).count,
               "Admin deve receber 1 turbo stream: badge decremento"
end
```

---

## Shared Patterns

### Canal ActionCable — estrutura canônica
**Fonte:** `app/channels/admin_notifications_channel.rb`
**Aplicar a:** `client_calendar_channel.rb`
```ruby
class XxxChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_xxx   # current_user ou current_client
    stream_for current_xxx
  end
end
```

### Broadcast de model — helpers privados
**Fonte:** `app/models/approval_response.rb` linhas 61-67
**Aplicar a:** `app/models/arte.rb` (método `broadcasts_revised_to_all`)
```ruby
def render_partial_html(partial:, locals:)
  ApplicationController.render(partial: partial, locals: locals, formats: [ :html ])
end

def turbo_stream_tag(action, target, template_html = "")
  %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
end
```

### dom_id fora de view context
**Fonte:** `app/models/approval_response.rb` linha 54
**Aplicar a:** `app/models/arte.rb` (método `broadcasts_revised_to_all`)
```ruby
ActionView::RecordIdentifier.dom_id(self, "calendar_chip")
# Nunca usar dom_id(self, ...) diretamente no model — dom_id é helper do ActionView
```

### Guard `return unless admin`
**Fonte:** `app/models/approval_response.rb` linhas 28-29
**Aplicar a:** `app/models/arte.rb` (início de `broadcasts_revised_to_all`)
```ruby
admin = User.order(:id).first
return unless admin
```

### Toast partial — estrutura HTML
**Fonte:** `app/views/admin/shared/_approval_toast.html.erb`
**Aplicar a:** `app/views/client/shared/_arte_revised_toast.html.erb`
```erb
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
  <!-- conteúdo -->
  <button data-action="click->toast#dismiss" ...>&times;</button>
</div>
```

### `turbo_stream_from` + toast region no layout
**Fonte:** `app/views/layouts/admin.html.erb` linhas 24-25
**Aplicar a:** `app/views/layouts/client.html.erb` (após `<body>`)
```erb
<%= turbo_stream_from @record, channel: XxxChannel if @record %>
<div id="xxx-toast-region" class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end"></div>
```

### Teste de canal — ActionCable::Channel::TestCase
**Fonte:** `test/channels/admin_notifications_channel_test.rb`
**Aplicar a:** `test/channels/client_calendar_channel_test.rb`
```ruby
stub_connection(current_xxx: record)
subscribe
assert subscription.confirmed?
assert_has_stream_for record
```

---

## No Analog Found

Nenhum arquivo desta fase fica sem analog — todos têm correspondentes diretos ou parciais no codebase.

---

## Metadata

**Analog search scope:** `app/channels/`, `app/models/`, `app/views/`, `test/channels/`, `test/models/`
**Files scanned:** 10
**Pattern extraction date:** 2026-06-06
