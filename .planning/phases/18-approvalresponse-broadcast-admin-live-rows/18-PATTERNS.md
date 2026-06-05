# Phase 18: ApprovalResponse Broadcast + Admin Live Rows — Pattern Map

**Mapped:** 2026-06-05
**Files analyzed:** 7 (2 criar + 5 modificar)
**Analogs found:** 7 / 7

---

## File Classification

| Arquivo Novo/Modificado | Role | Data Flow | Analog Mais Próximo | Qualidade |
|-------------------------|------|-----------|---------------------|-----------|
| `app/models/approval_response.rb` (MOD) | model | event-driven | `app/models/arte.rb` + padrão Rails `after_create_commit` | role-match |
| `app/views/admin/shared/_sidebar.html.erb` (MOD) | view-partial | request-response | si mesmo (cirurgia mínima) | exact |
| `app/views/admin/dashboard/index.html.erb` (MOD) | view | request-response | si mesmo (refatorar iteração) | exact |
| `app/views/admin/dashboard/_arte_dashboard_row.html.erb` (CREATE) | view-partial | event-driven | `app/views/admin/artes/_arte_row.html.erb` | exact |
| `app/views/admin/approvals/index.html.erb` (MOD) | view | request-response | si mesmo (adicionar id ao tbody) | exact |
| `app/views/admin/approvals/_approval_row.html.erb` (MOD) | view-partial | event-driven | si mesmo (adicionar id ao tr) | exact |
| `app/views/admin/shared/_approval_toast.html.erb` (CREATE) | view-partial | event-driven | `app/views/admin/approvals/_decision_badge.html.erb` + `toast_controller.js` | role-match |

---

## Pattern Assignments

---

### `app/models/approval_response.rb` — ADD `after_create_commit + broadcasts_to_admin`

**Analog:** próprio arquivo + convenção Rails `after_create_commit`

**Estado atual** (linhas 1–24):
```ruby
class ApprovalResponse < ApplicationRecord
  belongs_to :arte

  enum :decision, { approved: 0, change_requested: 1 }

  validates :decision, presence: true
  validate  :arte_must_be_pending, on: :create

  before_create { self.responded_at ||= Time.current }
  after_create  :sync_arte_status   # ← já existe; novo callback virá APÓS este

  private

  def arte_must_be_pending
    errors.add(:arte, "não está em estado aprovável") unless arte.pending? || arte.revised?
  end

  def sync_arte_status
    case decision
    when "approved"         then arte.approved!
    when "change_requested" then arte.change_requested!
    end
  end
end
```

**Padrão de callback a adicionar** — logo após `after_create :sync_arte_status`:
```ruby
# ADICIONAR estas duas linhas após after_create :sync_arte_status
after_create_commit :broadcasts_to_admin   # MUST be after_create_commit, not after_create
```

**Padrão do método privado** — adicionar no bloco `private`:
```ruby
def broadcasts_to_admin
  admin = User.first   # single-admin por enquanto
  return unless admin

  # D-15: eager-load para evitar N+1 no toast (arte.client.name) e dashboard row
  arte_with_client = Arte.includes(:client).find(arte_id)
  badge_count      = Arte.change_requested.count   # server-authoritative (D-11)

  streams = [
    turbo_stream.append(
      "admin-toast-region",
      partial: "admin/shared/approval_toast",
      locals:  { approval_response: self, arte: arte_with_client }
    ),
    # D-12: badge somente quando change_requested
    (turbo_stream.replace(
      "sidebar-badge",
      partial: "admin/shared/sidebar_badge",
      locals:  { badge_count: badge_count }
    ) if decision == "change_requested"),
    turbo_stream.replace(
      dom_id(arte_with_client),
      partial: "admin/dashboard/arte_dashboard_row",
      locals:  { arte: arte_with_client }
    ),
    turbo_stream.prepend(
      "approvals-tbody",
      partial: "admin/approvals/approval_row",
      locals:  { approval_response: self }
    )
  ].compact

  AdminNotificationsChannel.broadcast_to(admin, turbo_stream: streams)
end
```

> **Nota crítica:** `after_create_commit` (não `after_create`) garante broadcast FORA da transação aberta — dados já visíveis para outras conexões DB.

---

### `app/views/admin/shared/_sidebar.html.erb` — FIX badge condicional (D-10)

**Analog:** próprio arquivo

**Estado atual** (linhas 31–36) — condicional que impede presença DOM quando count = 0:
```erb
<% if item[:path] == admin_approvals_path && badge_count > 0 %>
  <span id="sidebar-badge"
        class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full">
    <%= badge_count %>
  </span>
<% end %>
```

**Padrão a aplicar** — remover `&& badge_count > 0`; adicionar toggle `hidden`:
```erb
<% if item[:path] == admin_approvals_path %>
  <span id="sidebar-badge"
        class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full <%= 'hidden' if badge_count == 0 %>">
    <%= badge_count %>
  </span>
<% end %>
```

> **Por quê:** Turbo Stream `replace` exige que `#sidebar-badge` esteja **sempre** na DOM. Se o elemento não existe, o replace falha silenciosamente e o badge nunca aparece.

---

### `app/views/admin/dashboard/index.html.erb` — REFATORAR iteração para usar partial

**Analog:** próprio arquivo

**Estado atual — bloco inline a substituir** (linhas 49–60):
```erb
<tbody class="divide-y divide-gray-100">
  <% artes.each do |arte| %>
    <tr class="hover:bg-slate-50">
      <td class="px-4 py-3 text-sm text-slate-900"><%= arte.title.presence || "Sem título" %></td>
      <td class="px-4 py-3 text-sm text-slate-600"><%= arte.scheduled_on.strftime("%d/%m/%Y") %></td>
      <td class="px-4 py-3">
        <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
      </td>
      <td class="px-4 py-3">
        <%= link_to "Ver", admin_arte_path(arte), class: "...", data: { turbo_frame: "_top" } %>
      </td>
    </tr>
  <% end %>
</tbody>
```

**Padrão a aplicar — tbody refatorado**:
```erb
<tbody class="divide-y divide-gray-100">
  <% artes.each do |arte| %>
    <%= render "admin/dashboard/arte_dashboard_row", arte: arte %>
  <% end %>
</tbody>
```

> **Analog de referência:** `app/views/admin/approvals/index.html.erb` linhas 50–52 — já usa `render "approval_row", approval_response: ar` dentro do loop.

---

### `app/views/admin/dashboard/_arte_dashboard_row.html.erb` — CREATE (NOVO)

**Analog:** `app/views/admin/artes/_arte_row.html.erb` — mesmo padrão de `<tr>` com partial de row

**Padrão de imports/estrutura do analog** (`_arte_row.html.erb`, linhas 1–10):
```erb
<%# app/views/admin/artes/_arte_row.html.erb %>
<tr class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">
  <td class="py-3 px-4 text-sm text-slate-900"><%= arte.client.name %></td>
  <td class="py-3 px-4 text-sm text-slate-900"><%= arte.scheduled_on.strftime("%d/%m/%Y") %></td>
  <td class="py-3 px-4 text-sm text-slate-900"><%= arte.platform.humanize %></td>
  <td class="py-3 px-4 text-sm text-slate-900"><%= render "status_badge", arte: arte %></td>
  <td class="py-3 px-4">
    <%= link_to "Ver", admin_arte_path(arte), class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors" %>
  </td>
</tr>
```

**Padrão a criar** — diferença chave: `id: dom_id(arte)` + colunas do dashboard (título, data, status, ações):
```erb
<%# app/views/admin/dashboard/_arte_dashboard_row.html.erb %>
<%# Partial com id dom_id para ser alvo de Turbo Stream replace (RTUP-03) %>
<tr id="<%= dom_id(arte) %>" class="hover:bg-slate-50">
  <td class="px-4 py-3 text-sm text-slate-900"><%= arte.title.presence || "Sem título" %></td>
  <td class="px-4 py-3 text-sm text-slate-600"><%= arte.scheduled_on.strftime("%d/%m/%Y") %></td>
  <td class="px-4 py-3">
    <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
  </td>
  <td class="px-4 py-3">
    <%= link_to "Ver", admin_arte_path(arte),
          class: "inline-flex items-center h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors",
          data: { turbo_frame: "_top" } %>
  </td>
</tr>
```

**Padrão de `dom_id` para row target:** O id gerado será `"arte_42"` para `Arte` com id=42. O Turbo Stream `replace` usa esse mesmo id como target: `turbo_stream.replace(dom_id(arte_with_client), partial: ...)`.

**Badge de status reutilizado:** `app/views/client/shared/_arte_status_badge.html.erb` (linhas 1–20) — aceita `compact: true/false` para tamanho reduzido.

---

### `app/views/admin/approvals/index.html.erb` — ADD `id="approvals-tbody"` (D-13)

**Analog:** próprio arquivo

**Estado atual** (linha 49) — `<tbody>` sem ID:
```erb
<tbody>
  <% @approval_responses.each do |ar| %>
    <%= render "approval_row", approval_response: ar %>
  <% end %>
</tbody>
```

**Padrão a aplicar** — adicionar `id="approvals-tbody"`:
```erb
<tbody id="approvals-tbody">
  <% @approval_responses.each do |ar| %>
    <%= render "approval_row", approval_response: ar %>
  <% end %>
</tbody>
```

> **Escopo:** Somente o `<tbody>` da tabela **desktop** (dentro de `.hidden.sm:block`). Os cards mobile (`.block.sm:hidden`, linhas 57–81) **não recebem** o id — broadcasts não afetam mobile (D-13).

---

### `app/views/admin/approvals/_approval_row.html.erb` — ADD `id: dom_id(approval_response)` (D-14)

**Analog:** próprio arquivo

**Estado atual** (linhas 1–17) — `<tr>` sem ID:
```erb
<%# app/views/admin/approvals/_approval_row.html.erb — caller MUST eager-load arte: :client via joins %>
<tr class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">
  <td class="py-3 px-4 text-sm text-slate-900"><%= approval_response.arte&.client&.name || "—" %></td>
  ...
</tr>
```

**Padrão a aplicar** — adicionar `id`:
```erb
<%# app/views/admin/approvals/_approval_row.html.erb — caller MUST eager-load arte: :client via joins %>
<tr id="<%= dom_id(approval_response) %>"
    class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">
  <td class="py-3 px-4 text-sm text-slate-900"><%= approval_response.arte&.client&.name || "—" %></td>
  ...
</tr>
```

> **Por quê:** `dom_id(approval_response)` gera `"approval_response_7"`. Se o admin estiver na página Aprovações quando o broadcast chega, o Turbo Stream `prepend` insere a linha. Na próxima visita/reload, o server render também gera o mesmo `<tr id="approval_response_7">`. Com IDs únicos, o browser não duplica elementos.

---

### `app/views/admin/shared/_approval_toast.html.erb` — CREATE (NOVO)

**Analogs:**
- `app/javascript/controllers/toast_controller.js` — define `data-controller="toast"` + `data-action="click->toast#dismiss"` (linhas 1–34)
- `app/views/admin/approvals/_decision_badge.html.erb` — badge de decisão reutilizável (linhas 1–13)
- `app/views/layouts/admin.html.erb` linha 25 — `id="admin-toast-region"` é o container de append

**Padrão de integração do toast_controller.js** (linhas 6–9):
```javascript
connect() {
  this._enforceLimit()
  this._timerId = setTimeout(() => this.dismiss(), DISMISS_DELAY)  // auto-dismiss em 5s
}
```

**Padrão de estrutura do toast partial:**
```erb
<%# app/views/admin/shared/_approval_toast.html.erb %>
<%# Renderizado via Turbo Stream append em #admin-toast-region               %>
<%# Locals: approval_response (ApprovalResponse), arte (Arte c/ :client eager-loaded) %>
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
  <div class="flex-1 min-w-0">
    <p class="text-sm font-semibold text-slate-900 truncate">
      <%= arte.client.name %>
    </p>
    <%# Reutiliza partial existente de decisão — mesmas classes de badge já definidas %>
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

**Padrão de cor do badge de decisão** (do `_decision_badge.html.erb`, linhas 3–9):
```erb
"approved"         => { classes: "bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20", label: "Aprovado" }
"change_requested" => { classes: "bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20", label: "Pediu Alteração" }
```

> **Integração com layout:** `admin.html.erb` linha 25 já define `<div id="admin-toast-region" class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end">`. O partial é appended a esse container pelo Turbo Stream.

---

## Shared Patterns

### Padrão: `dom_id(record)` para Turbo Stream targets

**Fonte:** Convenção Rails/Turbo — verificado em `_arte_row.html.erb` e na infraestrutura existente

**Aplica a:** `_arte_dashboard_row.html.erb` (RTUP-03) e `_approval_row.html.erb` (RTUP-04)

```erb
<%# Gera: id="arte_42" para Arte#42, id="approval_response_7" para ApprovalResponse#7 %>
<tr id="<%= dom_id(record) %>" class="...">
```

```ruby
# No model — Turbo Streams usam o mesmo helper
turbo_stream.replace(dom_id(arte_with_client), partial: "...")
turbo_stream.prepend("approvals-tbody", partial: "...")
```

### Padrão: Sidebar badge toggle de visibilidade

**Fonte:** `app/views/admin/shared/_sidebar.html.erb` após modificação (D-10)

**Aplica a:** `_sidebar.html.erb` + helper partial `_sidebar_badge.html.erb` referenciado no broadcast

```erb
<%# O elemento SEMPRE existe na DOM; visibilidade controlada por classe hidden %>
<span id="sidebar-badge"
      class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full <%= 'hidden' if badge_count == 0 %>">
  <%= badge_count %>
</span>
```

> **Nota:** O broadcast de `replace` de `#sidebar-badge` usa o partial `admin/shared/sidebar_badge` com locals `{ badge_count: badge_count }`. O planner deve criar `app/views/admin/shared/_sidebar_badge.html.erb` como partial isolado do span.

### Padrão: `after_create_commit` (não `after_create`) para broadcasts

**Fonte:** `app/models/approval_response.rb` (existente usa `after_create`) + RESEARCH.md §Architecture Patterns

**Aplica a:** `app/models/approval_response.rb` único ponto de broadcast nesta fase

```ruby
# CORRETO — fora da transação, dados visíveis para todas as conexões DB
after_create_commit :broadcasts_to_admin

# INCORRETO — dentro da transação aberta; broadcast pode transmitir dados não visíveis
after_create :broadcasts_to_admin
```

### Padrão: Turbo Stream ignorar Turbo Frame wrapper

**Fonte:** RESEARCH.md §Summary — "Turbo Streams ignoram frames e substituem/acrescentam diretamente pelo ID"

**Aplica a:** `dashboard/index.html.erb` (envolvido em `<turbo-frame id="dashboard-content">`) e `approvals/index.html.erb` (envolvido em `<turbo-frame id="approvals-content">`)

```erb
<%# dashboard/index.html.erb — turbo-frame envolve o conteúdo %>
<turbo-frame id="dashboard-content">
  <%# ... %>
  <tbody class="divide-y divide-gray-100">
    <%# Turbo Stream replace age diretamente sobre #arte_42 DENTRO desse frame %>
    <%# Nenhum wrapper adicional necessário %>
    <%= render "admin/dashboard/arte_dashboard_row", arte: arte %>
  </tbody>
</turbo-frame>
```

### Padrão: Row partial sem partial de toast — mesmos helpers de rota

**Fonte:** `app/views/admin/artes/_arte_row.html.erb` linha 8 — usa `admin_arte_path(arte)`

**Aplica a:** `_arte_dashboard_row.html.erb` e `_approval_toast.html.erb`

```erb
<%# Rotas admin disponíveis em partials sem necessidade de include explícito %>
<%= link_to "Ver arte", admin_arte_path(arte), ... %>
<%= link_to "Ver",      admin_arte_path(arte), data: { turbo_frame: "_top" } %>
```

---

## No Analog Found

Todos os arquivos desta fase têm analogs diretos no codebase. Nenhum arquivo sem referência.

---

## Metadata

**Escopo de busca de analogs:** `app/models/`, `app/views/admin/`, `app/channels/`, `app/javascript/controllers/`
**Arquivos lidos:** 13
**Data de extração:** 2026-06-05

### Resumo de Referências por Arquivo

| Arquivo | Linhas-chave lidas | Analog utilizado |
|---------|--------------------|------------------|
| `app/models/approval_response.rb` | 1–24 (completo) | próprio + convenção Rails |
| `app/views/admin/shared/_sidebar.html.erb` | 1–47 (completo) | próprio |
| `app/views/admin/dashboard/index.html.erb` | 1–66 (completo) | próprio + `_approval_row` pattern |
| `app/views/admin/approvals/index.html.erb` | 1–88 (completo) | próprio |
| `app/views/admin/approvals/_approval_row.html.erb` | 1–17 (completo) | próprio |
| `app/views/admin/artes/_arte_row.html.erb` | 1–10 (completo) | analog para `_arte_dashboard_row` |
| `app/views/admin/approvals/_decision_badge.html.erb` | 1–13 (completo) | analog para toast badge |
| `app/javascript/controllers/toast_controller.js` | 1–34 (completo) | analog para toast data-controller |
| `app/views/layouts/admin.html.erb` | 1–49 (completo) | referência toast-region + turbo_stream_from |
| `app/channels/admin_notifications_channel.rb` | 1–6 (completo) | referência broadcast target |
| `app/models/arte.rb` | 1–44 (completo) | referência enum status + scopes |
| `app/views/client/shared/_arte_status_badge.html.erb` | 1–20 (completo) | reutilizado em dashboard row |
