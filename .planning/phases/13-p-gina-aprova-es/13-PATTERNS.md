# Phase 13: Página Aprovações - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 8 (5 novos + 3 modificados)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/controllers/admin/approvals_controller.rb` | controller | request-response / CRUD (read-only) | `app/controllers/admin/dashboard_controller.rb` | exact |
| `app/controllers/admin/base_controller.rb` | base controller (modify) | — | — | modificação pontual |
| `app/helpers/application_helper.rb` | helper (modify) | — | — | modificação pontual |
| `app/views/admin/approvals/index.html.erb` | view / template | request-response | `app/views/admin/dashboard/index.html.erb` | exact |
| `app/views/admin/approvals/_approval_row.html.erb` | partial / component | request-response | `app/views/admin/artes/_arte_row.html.erb` | exact |
| `app/views/admin/approvals/_decision_badge.html.erb` | partial / component | transform | `app/views/admin/artes/_status_badge.html.erb` | exact |
| `app/views/admin/shared/_sidebar.html.erb` | partial (modify) | — | (modificação de 1 linha) | modificação pontual |
| `config/routes.rb` | config (modify) | — | (padrão namespace admin já existente) | modificação pontual |
| `test/controllers/admin/approvals_controller_test.rb` | test | request-response | `test/controllers/admin/dashboard_controller_test.rb` | exact |

---

## Pattern Assignments

### `app/controllers/admin/approvals_controller.rb` (controller, request-response)

**Analog:** `app/controllers/admin/dashboard_controller.rb`

**Imports / herança** (linha 1):
```ruby
class Admin::ApprovalsController < Admin::BaseController
```

**Auth pattern** (herdado de `app/controllers/admin/base_controller.rb` linhas 1-4):
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
end
```
Nenhuma action adicional de auth necessária — herança cobre tudo.

**Core pattern — scope com joins + filtros enumerados** (`dashboard_controller.rb` linhas 1-12):
```ruby
# Padrão exato do DashboardController — adaptar para ApprovalResponse:
scope = Arte.includes(:approval_responses)
            .joins(:client)
            .order("clients.name ASC, artes.scheduled_on DESC")

scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
scope = scope.where(status: params[:status]) if params[:status].present? && Arte.statuses.keys.include?(params[:status].to_s)
```
Para ApprovalResponse, o equivalente é:
```ruby
scope = ApprovalResponse
          .joins(arte: :client)
          .includes(arte: :client)
          .order(responded_at: :desc)

scope = scope.where(artes: { client_id: params[:client_id] }) if params[:client_id].present?
if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
  scope = scope.where(decision: params[:decision])
end

@pagy, @approval_responses = pagy(scope, limit: 25)
@clients = Client.order(:name)
```
Atenção: qualificar com `artes:` no WHERE para evitar ambiguidade de coluna (ver Pitfall 2 no RESEARCH.md).

**Enum validation pattern** (`dashboard_controller.rb` linha 8):
```ruby
# Arte.statuses.keys.include?(params[:status].to_s)
# → equivalente para decision:
ApprovalResponse.decisions.key?(params[:decision])
```

---

### `app/controllers/admin/base_controller.rb` (modificação pontual)

**Arquivo atual** (linhas 1-4):
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
end
```

**Modificação — adicionar `include Pagy::Backend`** (inserir antes do `end`):
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
  include Pagy::Backend   # ADICIONAR — necessário para o método pagy() nos controllers
end
```

---

### `app/helpers/application_helper.rb` (modificação pontual)

**Arquivo atual** (linhas 1-2):
```ruby
module ApplicationHelper
end
```

**Modificação — adicionar `include Pagy::Frontend`**:
```ruby
module ApplicationHelper
  include Pagy::Frontend  # ADICIONAR — disponibiliza pagy_nav nas views
end
```

---

### `app/views/admin/approvals/index.html.erb` (view, request-response)

**Analog:** `app/views/admin/dashboard/index.html.erb`

**Padrão de cabeçalho de página** (`dashboard/index.html.erb` linha 1-3):
```erb
<% content_for(:page_title) { "Painel de Respostas" } %>
<h1 class="text-2xl font-bold text-slate-900 mb-6">Painel de Respostas</h1>
```
Para aprovações: substituir título e usar `font-semibold` (padrão de `artes/index.html.erb` linha 5).

**Padrão de form de filtros FORA do turbo-frame** (`dashboard/index.html.erb` linhas 5-28):
```erb
<%# Barra de filtros FORA do turbo-frame %>
<%= form_with url: admin_root_path, method: :get, data: { turbo_frame: "dashboard-content" }, class: "flex items-center gap-3 mb-6" do |f| %>
  <%= f.select :client_id,
        [["Todos os clientes", ""]] + @clients.map { |c| [c.name, c.id] },
        { selected: params[:client_id] },
        class: "h-9 px-3 border border-gray-200 rounded-lg text-sm text-slate-700 bg-white" %>
  <%= f.select :status,
        status_options,
        { selected: params[:status] },
        class: "h-9 px-3 border border-gray-200 rounded-lg text-sm text-slate-700 bg-white" %>
  <%= f.submit "Filtrar",
        class: "h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer" %>
<% end %>
```
Para aprovações: `url: admin_approvals_path`, `turbo_frame: "approvals-content"`, segundo select usa `decision` com `[["Todas as decisões", ""], ["Aprovado", "approved"], ["Pediu Alteração", "change_requested"]]`.

**Padrão de turbo-frame envolvendo tabela** (`dashboard/index.html.erb` linhas 30-66):
```erb
<turbo-frame id="dashboard-content">
  <% if @artes_by_client.empty? %>
    <p class="text-sm text-slate-500 py-4">Nenhuma arte encontrada.</p>
  <% else %>
    <%# ... tabela ... %>
  <% end %>
</turbo-frame>
```
Para aprovações: `id="approvals-content"`, verificar `@approval_responses.empty?`.

**Padrão de tabela desktop** (`artes/index.html.erb` linhas 26-44):
```erb
<div class="bg-white rounded-xl border border-gray-200 shadow-card overflow-hidden hidden sm:block">
  <table aria-label="Lista de artes" class="w-full">
    <caption class="sr-only">...</caption>
    <thead class="bg-gray-50 border-b border-gray-200">
      <tr>
        <th scope="col" class="py-3 px-4 text-xs font-medium text-slate-500 uppercase tracking-wide text-left">Cliente</th>
        ...
      </tr>
    </thead>
    <tbody>
      <% @artes.each do |arte| %>
        <%= render "arte_row", arte: arte %>
      <% end %>
    </tbody>
  </table>
</div>
```
Para aprovações: colunas são CLIENTE / ARTE / DECISÃO / DATA / COMENTÁRIO / AÇÕES; usar `render "approval_row", approval_response: ar` no loop.

**Padrão de cards mobile** (`artes/index.html.erb` linhas 47-62):
```erb
<div class="block sm:hidden space-y-3">
  <% @artes.each do |arte| %>
    <%= link_to admin_arte_path(arte), class: "block bg-white rounded-xl border border-gray-200 shadow-card px-4 py-3" do %>
      ...
    <% end %>
  <% end %>
</div>
```
Para aprovações: cada card linka para `admin_arte_path(ar.arte)`.

**Pagy nav** — inserir dentro do turbo-frame, após a tabela, antes do `</turbo-frame>`:
```erb
<div class="flex justify-center mt-6">
  <%== pagy_nav(@pagy) %>
</div>
```
Nota: `<%==` (raw output) é necessário pois `pagy_nav` retorna HTML já montado.

---

### `app/views/admin/approvals/_approval_row.html.erb` (partial, request-response)

**Analog:** `app/views/admin/artes/_arte_row.html.erb` (linhas 1-10)

**Padrão de linha de tabela:**
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
Para aprovações, adaptar com:
- `approval_response.arte.client.name` (eager-loaded via `includes(arte: :client)`)
- `approval_response.arte.title`
- `render "decision_badge", approval_response: approval_response`
- `approval_response.responded_at&.strftime("%d/%m/%Y") || "—"` (safe navigation — Pitfall 4)
- `truncate(approval_response.comment.to_s, length: 80)` para o comentário
- `link_to "Ver arte", admin_arte_path(approval_response.arte), class: "h-8 px-3 border border-gray-200 ..."` (mesmas classes do `_arte_row`)

---

### `app/views/admin/approvals/_decision_badge.html.erb` (partial, transform)

**Analog:** `app/views/admin/artes/_status_badge.html.erb` (linhas 1-21)

**Padrão exato de badge — case/when com config de classes:**
```erb
<%# app/views/admin/artes/_status_badge.html.erb %>
<% case arte.status
   when "pending"
     badge_classes = "bg-[#FFFBEB] text-amber-800 border-[#F59E0B]/20"
     badge_label   = "Pendente"
   when "approved"
     badge_classes = "bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20"
     badge_label   = "Aprovada"
   when "change_requested"
     badge_classes = "bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20"
     badge_label   = "Alteração pedida"
   ...
   end %>
<span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border <%= badge_classes %>">
  <span aria-hidden="true">●</span> <%= badge_label %>
</span>
```
Para `_decision_badge`, adaptar para `approval_response.decision`:
- `"approved"` → classes `"bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20"`, label `"Aprovado"`
- `"change_requested"` → classes `"bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20"`, label `"Pediu Alteração"`
- `else` → classes `"bg-gray-50 text-slate-600 border-gray-200"`, label `approval_response.decision.to_s`

Diferença em relação ao analog: usar `hash config` (conforme UI-SPEC) em vez de `case/when`. Ambas as abordagens são válidas — o hash é mais conciso para apenas 2 casos.

---

### `app/views/admin/shared/_sidebar.html.erb` (modificação pontual)

**Arquivo atual — linha a modificar** (linha 13):
```erb
{ label: "Aprovações",    path: "#" },
```

**Após modificação:**
```erb
{ label: "Aprovações",    path: admin_approvals_path },
```
Nenhuma outra alteração no arquivo.

Atenção: `current_page?(item[:path])` (linha 22) funciona corretamente com `admin_approvals_path` — o link ficará destacado ao visitar `/admin/approvals`.

---

### `config/routes.rb` (modificação pontual)

**Padrão existente do namespace admin** (linhas 7-19):
```ruby
namespace :admin do
  root to: "dashboard#index"
  resources :clients, only: [ :index, :show, :new, :create, :edit, :update ] do
    member do
      post :rotate_token
    end
  end
  resources :artes do
    member do
      patch :mark_revised
    end
  end
end
```

**Linha a inserir** (após `resources :artes do ... end`, antes do `end` do namespace):
```ruby
resources :approvals, only: [ :index ]
```

---

### `test/controllers/admin/approvals_controller_test.rb` (test, request-response)

**Analog:** `test/controllers/admin/dashboard_controller_test.rb` (linhas 1-41)

**Padrão de setup inline** (sem fixtures — padrão do projeto):
```ruby
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")
    sign_in_as(@user)
    @client = Client.create!(name: "Test Client", password: "senha123", password_confirmation: "senha123")
    @arte = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :pending,
      title: "Arte Teste",
      caption: "Legenda",
      approval_deadline: Date.current + 5,
      external_url: "https://drive.google.com/file/exemplo"
    )
  end
```
Para `ApprovalsControllerTest`, acrescentar no `setup`:
```ruby
@approval_response = ApprovalResponse.create!(
  arte: @arte,
  decision: :approved
)
```
Nota: `responded_at` é populado pelo `before_create` do modelo — não precisa passar.

**Padrão de testes de filtro** (`dashboard_controller_test.rb` linhas 26-40):
```ruby
test "filter by client_id" do
  get admin_root_url, params: { client_id: @client.id }
  assert_response :success
end

test "filter by invalid status is ignored and returns all artes" do
  get admin_root_url, params: { status: "nonexistent_status" }
  assert_response :success
  assert_includes response.body, @arte.title
end
```
Para aprovações: `get admin_approvals_url`, filtrar por `client_id` e `decision`; testar decision inválida não lança erro.

---

## Shared Patterns

### Autenticação (admin-only)
**Source:** `app/controllers/admin/base_controller.rb` linhas 1-4
**Apply to:** `Admin::ApprovalsController` (herdado automaticamente)
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
end
```

### Enum validation no filtro GET
**Source:** `app/controllers/admin/dashboard_controller.rb` linha 8
**Apply to:** `Admin::ApprovalsController#index` (filtro por `decision`)
```ruby
scope = scope.where(status: params[:status]) if params[:status].present? && Arte.statuses.keys.include?(params[:status].to_s)
# → equivalente para decision:
# ApprovalResponse.decisions.key?(params[:decision])
```

### Tabela desktop — thead e tbody
**Source:** `app/views/admin/artes/index.html.erb` linhas 29-43
**Apply to:** `app/views/admin/approvals/index.html.erb`
```erb
<thead class="bg-gray-50 border-b border-gray-200">
  <tr>
    <th scope="col" class="py-3 px-4 text-xs font-medium text-slate-500 uppercase tracking-wide text-left">...</th>
  </tr>
</thead>
<tbody>
  <%# render partial por linha %>
</tbody>
```

### Linha de tabela — hover + borda
**Source:** `app/views/admin/artes/_arte_row.html.erb` linha 2
**Apply to:** `app/views/admin/approvals/_approval_row.html.erb`
```erb
<tr class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">
```

### Botão "Ver" outline
**Source:** `app/views/admin/artes/_arte_row.html.erb` linha 8
**Apply to:** `app/views/admin/approvals/_approval_row.html.erb` (coluna Ações)
```erb
<%= link_to "Ver arte", admin_arte_path(arte), class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors" %>
```

### Formato de data
**Source:** `app/views/admin/dashboard/index.html.erb` linha 52 e `_arte_row.html.erb` linha 5
**Apply to:** `app/views/admin/approvals/_approval_row.html.erb` (coluna Data)
```erb
<%= arte.scheduled_on.strftime("%d/%m/%Y") %>
# → para responded_at com safe navigation (campo nullable):
<%= approval_response.responded_at&.strftime("%d/%m/%Y") || "—" %>
```

### Test setup inline (sem fixtures)
**Source:** `test/controllers/admin/dashboard_controller_test.rb` linhas 4-19
**Apply to:** `test/controllers/admin/approvals_controller_test.rb`
```ruby
setup do
  @user = User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")
  sign_in_as(@user)
  @client = Client.create!(name: "Test Client", password: "senha123", password_confirmation: "senha123")
  @arte = Arte.create!(client: @client, scheduled_on: Date.current, platform: :instagram,
                       media_type: :image, status: :pending, title: "Arte Teste",
                       caption: "Legenda", approval_deadline: Date.current + 5,
                       external_url: "https://drive.google.com/file/exemplo")
end
```

---

## No Analog Found

Nenhum arquivo desta fase está sem analog. Todos os padrões necessários existem no codebase.

---

## Metadata

**Analog search scope:** `app/controllers/admin/`, `app/views/admin/`, `app/models/`, `config/routes.rb`, `test/controllers/admin/`, `app/helpers/`
**Files scanned:** 12 arquivos lidos diretamente
**Pattern extraction date:** 2026-06-04

### Dependência crítica de ordem (Wave 0)

Antes de qualquer controller ou view de aprovações funcionar, duas modificações devem existir:

1. `app/controllers/admin/base_controller.rb` — adicionar `include Pagy::Backend`
2. `app/helpers/application_helper.rb` — adicionar `include Pagy::Frontend`
3. `config/routes.rb` — adicionar `resources :approvals, only: [:index]` no namespace admin

Sem (1) e (2), o controller lança `NoMethodError: undefined method 'pagy'` e a view lança `undefined method 'pagy_nav'`.
