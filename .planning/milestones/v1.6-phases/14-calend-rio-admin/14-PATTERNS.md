# Phase 14: Calendário Admin - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 6 (3 novos + 3 modificados)
**Analogs found:** 6 / 6

---

## File Classification

| Arquivo Novo/Modificado | Role | Data Flow | Analog Mais Próximo | Qualidade |
|-------------------------|------|-----------|---------------------|-----------|
| `app/controllers/admin/calendar_controller.rb` | controller | request-response | `app/controllers/client/home_controller.rb` | exact |
| `app/views/admin/calendar/index.html.erb` | view | request-response | `app/views/client/home/index.html.erb` | exact |
| `app/views/admin/calendar/_calendar_grid.html.erb` | view (partial) | request-response | `app/views/client/home/_month_calendar.html.erb` | exact |
| `app/helpers/application_helper.rb` (modificar) | helper/utility | transform | badges existentes no design system (classes hex literais) | role-match |
| `config/routes.rb` (modificar) | config | — | bloco `namespace :admin` existente em `config/routes.rb` | exact |
| `app/views/admin/shared/_sidebar.html.erb` (modificar) | view (partial) | — | `_sidebar.html.erb` linha 16 atual | exact |
| `test/controllers/admin/calendar_controller_test.rb` | test | request-response | `test/controllers/admin/approvals_controller_test.rb` | exact |

---

## Pattern Assignments

### `app/controllers/admin/calendar_controller.rb` (controller, request-response)

**Analog:** `app/controllers/client/home_controller.rb`

**Imports / Herança** (linha 1):
```ruby
# app/controllers/client/home_controller.rb — linha 1
class Client::HomeController < ClientController
# → Admin replica como:
class Admin::CalendarController < Admin::BaseController
```

**Auth pattern** — herdado de `Admin::BaseController` (linhas 1-5):
```ruby
# app/controllers/admin/base_controller.rb — linhas 1-5
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
  include Pagy::Backend
end
# Admin::CalendarController herda tudo isso automaticamente — não precisa declarar before_action
```

**Core pattern — action index** (`app/controllers/client/home_controller.rb` linhas 2-31):
```ruby
def index
  @current_month = parse_month_param

  @prev_month = (@current_month - 1.month).strftime("%Y-%m")
  @next_month = (@current_month + 1.month).strftime("%Y-%m")
  @month_label = I18n.l(@current_month, format: "%B %Y")

  grid_start = @current_month.beginning_of_week   # Monday (Rails default)
  grid_end   = @current_month.end_of_month.end_of_week

  # DIFERENÇA CHAVE vs. client/home: busca TODOS os clientes, includes(:client), order(:id)
  @artes = Arte.where(scheduled_on: grid_start..grid_end)
               .includes(:client)
               .order(:id)

  @artes_by_date = @artes.group_by(&:scheduled_on)
  @grid_dates    = (grid_start..grid_end).to_a
  # Sem @summary — não necessário na view admin
end
```

**Error handling / parse_month_param** (`app/controllers/client/home_controller.rb` linhas 35-40):
```ruby
private

def parse_month_param
  return Date.today.beginning_of_month unless params[:month].present?
  Date.strptime(params[:month], "%Y-%m").beginning_of_month
rescue Date::Error
  Date.today.beginning_of_month
end
```

---

### `app/views/admin/calendar/index.html.erb` (view, request-response)

**Analog:** `app/views/client/home/index.html.erb`

**Imports / page_title** (linha 1):
```erb
<%# app/views/client/home/index.html.erb — linha 1 %>
<% content_for(:title) { "#{@month_label} · Ilha Criativa" } %>
<%# → Admin replica como: %>
<% content_for(:page_title) { "Calendário" } %>
<%# Nota: admin layout usa :page_title (ver approvals/index.html.erb linha 1) %>
```

**Setas de navegação FORA do turbo-frame** (`app/views/client/home/index.html.erb` linhas 3-23):
```erb
<div class="flex items-center justify-center gap-4 mb-6">
  <%= link_to admin_calendar_index_path(month: @prev_month),
        data: { turbo_frame: "calendar-content" },
        aria: { label: "Mês anterior" },
        class: "p-2 rounded-lg hover:bg-gray-100 transition-colors text-slate-600" do %>
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M15 19l-7-7 7-7"/>
    </svg>
  <% end %>

  <h2 class="text-lg font-semibold text-slate-900 min-w-[160px] text-center">
    <%= @month_label %>
  </h2>

  <%= link_to admin_calendar_index_path(month: @next_month),
        data: { turbo_frame: "calendar-content" },
        aria: { label: "Próximo mês" },
        class: "p-2 rounded-lg hover:bg-gray-100 transition-colors text-slate-600" do %>
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none"
         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M9 5l7 7-7 7"/>
    </svg>
  <% end %>
</div>
```

**Turbo Frame envolvendo o grid** — padrão de `app/views/admin/approvals/index.html.erb` (linha 21):
```erb
<%# app/views/admin/approvals/index.html.erb — linha 21 %>
<turbo-frame id="approvals-content">
  ...
</turbo-frame>
<%# → Admin calendar usa id "calendar-content": %>
<turbo-frame id="calendar-content">
  <%= render "calendar_grid",
        grid_dates: @grid_dates,
        artes_by_date: @artes_by_date,
        current_month: @current_month %>
</turbo-frame>
```

---

### `app/views/admin/calendar/_calendar_grid.html.erb` (view partial, request-response)

**Analog:** `app/views/client/home/_month_calendar.html.erb`

**Estrutura da grade 7 colunas** (linhas 1-7):
```erb
<%# app/views/client/home/_month_calendar.html.erb — linhas 1-7 %>
<div class="grid grid-cols-7 gap-px bg-gray-200 rounded-xl overflow-hidden">
  <%# Cabeçalho dias da semana %>
  <% %w[Seg Ter Qua Qui Sex Sáb Dom].each do |day| %>
    <div class="bg-gray-50 py-2 text-center text-xs font-medium text-slate-500 uppercase tracking-wide">
      <%= day %>
    </div>
  <% end %>
```

**Célula do calendário com estilo por mês** (linhas 10-24):
```erb
<%# app/views/client/home/_month_calendar.html.erb — linhas 10-24 %>
<% grid_dates.each do |date| %>
  <%
    artes_do_dia = artes_by_date[date] || []
    is_current_month = date.month == current_month.month
  %>
  <div class="<%= is_current_month ? 'bg-white' : 'bg-gray-50' %> min-h-[100px] p-1.5">
    <%# → Admin usa min-h-[80px] (D-02 do CONTEXT.md): %>
    <%# <div class="<%= is_current_month ? 'bg-white' : 'bg-gray-50' %> min-h-[80px] p-1.5"> %>
    <% if date == Date.today %>
      <span class="text-xs font-medium bg-[#EA580C] text-white rounded-full w-5 h-5 inline-flex items-center justify-center">
        <%= date.day %>
      </span>
    <% else %>
      <span class="text-xs font-medium <%= artes_do_dia.any? ? 'text-slate-700' : 'text-gray-300' %>">
        <%= date.day %>
      </span>
    <% end %>
```

**Chips de arte admin com cor por cliente + overflow +N** (substitui linhas 26-33 do analog):
```erb
<%# Substituir loop de link_to do client/home por: %>
<% visible = artes_do_dia.first(3) %>
<% overflow = artes_do_dia.size - 3 %>

<% visible.each do |arte| %>
  <% color = client_color(arte.client) %>
  <%= link_to admin_arte_path(arte),
        class: "mt-1 flex items-center justify-center rounded px-1 py-0.5 text-xs font-semibold #{color[:bg]} #{color[:text]} hover:opacity-80 transition-opacity" do %>
    <%= arte.client.name.split.map(&:first).first(2).join.upcase %>
  <% end %>
<% end %>

<% if overflow > 0 %>
  <span class="mt-1 block text-xs text-gray-400 text-center">+<%= overflow %></span>
<% end %>
```

---

### `app/helpers/application_helper.rb` (helper/utility, transform)

**Analog:** design system existente — classes hex literais em toda a codebase (ex: `bg-[#EA580C]` em `_month_calendar.html.erb` linha 17, `bg-[#0F7949]` em `approvals/index.html.erb` linha 18)

**Estado atual** (`app/helpers/application_helper.rb` linhas 1-3):
```ruby
module ApplicationHelper
  include Pagy::Frontend
end
```

**Padrão de cores hex literais** (extraído de `app/views/admin/approvals/index.html.erb` linha 18 e `app/views/admin/shared/_sidebar.html.erb` linha 1):
```ruby
# CORRETO — string literal completa que Tailwind JIT detecta:
"bg-[#F0FDF4]"
"text-[#14A958]"

# NUNCA concatenar:
# "bg-[#{hex}]"  ← Tailwind não detecta em produção
```

**Método `client_color` a adicionar** (D-01 do CONTEXT.md — paleta de 8 cores):
```ruby
module ApplicationHelper
  include Pagy::Frontend

  def client_color(client)
    palette = [
      { bg: "bg-[#F0FDF4]", text: "text-[#14A958]" },  # verde (já no design system)
      { bg: "bg-[#EFF6FF]", text: "text-[#2563EB]" },  # azul
      { bg: "bg-[#FAF5FF]", text: "text-[#7C3AED]" },  # roxo
      { bg: "bg-[#FFF7ED]", text: "text-[#EA580C]" },  # laranja
      { bg: "bg-[#FFF0F3]", text: "text-[#E11D48]" },  # rosa
      { bg: "bg-[#F0FDFA]", text: "text-[#0D9488]" },  # teal
      { bg: "bg-[#FEFCE8]", text: "text-[#CA8A04]" },  # amarelo
      { bg: "bg-[#EEF2FF]", text: "text-[#4F46E5]" },  # índigo
    ]
    palette[client.id % palette.size]
  end
end
```

---

### `config/routes.rb` (config)

**Analog:** bloco `namespace :admin` existente em `config/routes.rb` (linhas 7-20)

**Padrão de recursos de coleção admin** (linha 19):
```ruby
# config/routes.rb — linha 19 (analog direto)
resources :approvals, only: [ :index ]
# → Calendar replica o mesmo padrão:
resources :calendar,  only: [ :index ]
```

**Bloco completo após modificação** (`config/routes.rb` linhas 7-20):
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
  resources :approvals, only: [ :index ]
  resources :calendar,  only: [ :index ]   # ADICIONAR esta linha
end
```

---

### `app/views/admin/shared/_sidebar.html.erb` (view partial, modificação)

**Analog:** o próprio arquivo atual — `_sidebar.html.erb` linhas 11-19

**Estado atual — linha 16** (`app/views/admin/shared/_sidebar.html.erb`):
```erb
{ label: "Calendário",    path: "#" },
```

**Estado após modificação:**
```erb
{ label: "Calendário",    path: admin_calendar_index_path },
```

**Contexto completo do bloco nav_items** (linhas 10-19):
```erb
<%
  nav_items = [
    { label: "Dashboard",     path: admin_root_path },
    { label: "Aprovações",    path: admin_approvals_path },
    { label: "Clientes",      path: admin_clients_path },
    { label: "Artes",         path: admin_artes_path },
    { label: "Calendário",    path: admin_calendar_index_path },  # ← alterar
    { label: "Configurações", path: "#" },
  ]
%>
```

**Nota:** `current_page?` neste sidebar usa o path para aplicar `bg-white/20 text-white` ao item ativo (linha 23). Com `"#"` nunca ativa; com `admin_calendar_index_path` passa a ativar corretamente quando na página do calendário. Rota e sidebar DEVEM ser alterados na mesma wave.

---

### `test/controllers/admin/calendar_controller_test.rb` (test, request-response)

**Analog:** `test/controllers/admin/approvals_controller_test.rb`

**Setup pattern** (linhas 1-20):
```ruby
# test/controllers/admin/approvals_controller_test.rb — linhas 1-20
require "test_helper"

class Admin::ApprovalsControllerTest < ActionDispatch::IntegrationTest
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

**Padrão de teste de autenticação** (linhas 27-30):
```ruby
test "test_redirects_when_unauthenticated" do
  delete session_path
  get admin_approvals_url
  assert_response :redirect
end
```

**Padrão de teste de conteúdo renderizado** (linhas 32-38):
```ruby
test "test_displays_approval_data" do
  get admin_approvals_url
  assert_response :success
  assert_includes response.body, @client.name
  assert_includes response.body, @arte.title
end
```

**Adaptação para Calendar** — testes adicionais necessários além do padrão approvals:
```ruby
# Padrão para testar navegação de mês com parâmetro
test "test_navigates_to_specific_month" do
  get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
  assert_response :success
end

# Parâmetro inválido não causa 500 (cobre Date::Error rescue)
test "test_invalid_month_param_does_not_crash" do
  get admin_calendar_index_url, params: { month: "invalid" }
  assert_response :success
end

# Chip contém iniciais do cliente
test "test_chip_contains_client_initials" do
  get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
  initials = @client.name.split.map(&:first).first(2).join.upcase
  assert_includes response.body, initials
end

# Chip é link para a arte
test "test_chip_links_to_arte" do
  get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
  assert_includes response.body, admin_arte_path(@arte)
end

# Overflow: máximo 3 chips + "+N"
test "test_overflow_shows_plus_n" do
  4.times do |i|
    Arte.create!(client: @client, scheduled_on: @arte.scheduled_on,
                 platform: :instagram, media_type: :image, status: :pending,
                 title: "Extra #{i}", caption: "cap", approval_deadline: Date.current + 5,
                 external_url: "https://drive.google.com/file/exemplo#{i}")
  end
  get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
  assert_includes response.body, "+2"  # 5 artes total: 3 visíveis + "+2"
end
```

---

## Shared Patterns

### Autenticação
**Fonte:** `app/controllers/admin/base_controller.rb` linhas 1-5
**Aplicar a:** `Admin::CalendarController`
```ruby
# Herdado automaticamente via Admin::BaseController:
before_action :require_authentication
layout 'admin'
```
Admin::CalendarController herda `Admin::BaseController` — zero declaração adicional necessária.

### Turbo Frame (conteúdo parcial)
**Fonte:** `app/views/admin/approvals/index.html.erb` linha 21
**Aplicar a:** `app/views/admin/calendar/index.html.erb`
```erb
<turbo-frame id="calendar-content">
  <%# Conteúdo substituído na navegação de mês %>
</turbo-frame>
```
Setas de navegação ficam FORA do `<turbo-frame>` mas carregam com `data: { turbo_frame: "calendar-content" }`.

### Classes Tailwind hex literais
**Fonte:** codebase inteiro — ex: `app/views/admin/approvals/index.html.erb` linha 18, `app/views/admin/shared/_sidebar.html.erb` linha 1
**Aplicar a:** `app/helpers/application_helper.rb` — método `client_color`
```ruby
# SEMPRE strings literais completas — nunca interpolação:
"bg-[#F0FDF4]"  # correto
"bg-[#{hex}]"   # proibido — Tailwind JIT não detecta
```

### content_for(:page_title)
**Fonte:** `app/views/admin/approvals/index.html.erb` linha 1
**Aplicar a:** `app/views/admin/calendar/index.html.erb`
```erb
<% content_for(:page_title) { "Calendário" } %>
```
Nota: admin layout usa `:page_title`; client layout usa `:title`. Não trocar.

### Iniciais do cliente (2 chars)
**Fonte:** CONTEXT.md `## Specific Ideas`
**Aplicar a:** `_calendar_grid.html.erb` no chip de cada arte
```ruby
arte.client.name.split.map(&:first).first(2).join.upcase
# "Ilha Criativa" → "IC" | "Mercado Verde" → "MV" | "Ana" → "A" (1 char — aceitável)
```

---

## No Analog Found

Nenhum arquivo desta fase ficou sem analog. Todos têm correspondência direta no codebase.

---

## Metadata

**Escopo de busca de analogs:** `app/controllers/`, `app/views/`, `app/helpers/`, `config/routes.rb`, `test/controllers/`
**Arquivos lidos:** 10
**Data de extração:** 2026-06-04
