# Phase 4: Client Calendar Portal — Research

**Researched:** 2026-05-25
**Domain:** Rails calendar grid, ActiveStorage serving, client-scoped portal views
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Criar `app/views/layouts/client.html.erb` como layout dedicado. `ClientController` declara `layout 'client'`.
- **D-02:** Header: logo/brand à esquerda, nome do cliente ao centro/direita, botão "Sair" (DELETE para `client_session_path`).
- **D-03:** Tela de login (`app/views/client/sessions/new.html.erb`) refatorada para usar o novo layout — elimina HTML inline duplicado.
- **D-04:** Fundo do portal: `bg-white`.
- **D-05:** Grid CSS 7 colunas (Seg–Dom), não `<table>`. Cabeçalho com abreviações dos dias.
- **D-06:** Dias sem arte: número do dia em `text-gray-300` ou `text-gray-200` (opacidade reduzida). Grade completa sempre exibida.
- **D-07:** Múltiplas artes no mesmo dia: empilhadas verticalmente. Célula cresce para acomodar. Sem truncamento "+N mais".
- **D-08:** Cada arte na grade: ícone SVG da plataforma + badge de status colorido.
- **D-09:** Preview em página separada `/c/:token/artes/:id` — novo `Client::ArtesController#show`. URL: `client_arte_path(token: @client.access_token, id: arte)`.
- **D-10:** Renderização por `media_type`: image+local→`<img>`, video+local→`<video controls>`, caption_only→texto, qualquer+external_url→botão "Abrir arquivo" `target="_blank"`.
- **D-11:** Metadados ao cliente: plataforma (ícone + nome), data agendada, prazo de aprovação, status (badge), legenda/texto. Claude decide o que mais expor.
- **D-12:** Link externo: botão "Abrir arquivo" em nova aba. Nunca iframe.
- **D-13:** Parâmetro URL `?month=YYYY-MM`. Controller valida e parseia.
- **D-14:** Sem parâmetro: exibir mês corrente (`Date.today.beginning_of_month`).
- **D-15:** Sem limite de navegação. Meses sem artes = grade vazia.
- **D-16:** Cabeçalho `< Maio 2026 >`: seta Anterior à esquerda, mês/ano centralizado, seta Próximo à direita. Setas são links com `?month` ajustado.

### Claude's Discretion

- Estrutura interna do `Client::ArtesController` (strong params, before_action, escopo de segurança).
- Copywriting PT-BR dos estados e labels no portal.
- Responsividade mobile da grade.
- Estilo exato dos blocos de arte na grade.
- Número de linhas de semana (5 ou 6 dependendo do mês).

### Deferred Ideas (OUT OF SCOPE)

- Botões "Aprovar" e "Pedir Alteração" — Fase 5.
- Estado vazio personalizado por cliente — copywriting simples, sem lógica especial.
- Resumo de status no topo (v2, CAL2-01).
- Notificações — fora do escopo v1.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAL-01 | Cliente vê um grid mensal com todas as artes agendadas para o mês | Calendário puro Ruby com `beginning_of_month.beginning_of_week`, artes agrupadas por `scheduled_on` |
| CAL-02 | Cliente pode navegar entre meses (mês anterior / próximo) | Links `?month=YYYY-MM` via `strftime('%Y-%m')` em `prev_month` / `next_month` |
| CAL-03 | Cliente pode ver o preview completo de cada arte | `Client::ArtesController#show`, `rails_blob_path` para mídia, `external_url` como botão |
| CAL-04 | Cliente vê o prazo de aprovação e o status atual de cada arte | `approval_deadline` + `status` enum; badge adaptado do `_arte_status_badge` do Phase 3 |
| CAL-05 | Cliente vê o ícone da plataforma em cada arte | SVG inline (Instagram/Facebook/LinkedIn); reutilização ou criação de partials de ícone |
</phase_requirements>

---

## Summary

Esta fase implementa o portal visual do cliente: layout dedicado, grade mensal de artes, e página de preview. A infraestrutura de autenticação (token + senha) já está completa desde a Fase 1. O que falta é o "shell" visual e as views de conteúdo.

A descoberta mais importante é que a gem `simple_calendar 3.1.0` **já está instalada** no Gemfile e disponível via `vendor/bundle`. Ela fornece o helper `month_calendar` com `date_range` e `sorted_events_for(day)` — mas usa `<table>` no partial padrão. Como a decisão D-05 exige CSS Grid (não `<table>`), a estratégia correta é gerar as views da gem (`rails g simple_calendar:views`) e substituir o partial `_month_calendar.html.erb` por uma implementação CSS Grid customizada, mantendo a lógica Ruby da gem intacta. Alternativamente, pode-se ignorar o partial da gem e usar o helper exclusivamente para `date_range` + `sorted_events_for` dentro de uma view própria.

O parâmetro `?month=YYYY-MM` (decisão D-13) é incompatível com o `start_date_param` padrão da gem (que usa YYYY-MM-DD). A solução mais limpa é **não usar** `start_date_param` da gem para navegação: o controller parseia `params[:month]` manualmente com `Date.strptime`, e as setas de navegação são links construídos diretamente na view com `strftime('%Y-%m')`.

ActiveStorage usa Disk service (dev e prod). URLs de blob são assinadas com validade de 300 segundos (5 minutos). Para a página de preview onde o cliente pode ficar mais tempo, usar `url_for(@arte.media_file)` é adequado para imagens; para vídeos considera-se aumentar `active_storage.service_urls_expire_in` ou usar proxy (`rails_service_blob_proxy_path`).

**Recomendação primária:** Usar `simple_calendar` para a lógica Ruby (date_range + event grouping), com partial customizado CSS Grid e navegação manual via `?month=YYYY-MM`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Autenticação do cliente | API / Backend | — | `ClientController#require_client_auth` já implementado; sessão via cookie |
| Layout client portal | Frontend Server (SSR) | — | `layouts/client.html.erb` renderizado server-side |
| Grade mensal (calendário) | Frontend Server (SSR) | — | `month_calendar` helper + date arithmetic; sem JS obrigatório |
| Navegação entre meses | Frontend Server (SSR) | — | Links HTML com `?month=`; sem JS |
| Preview de arte (imagem/vídeo) | Frontend Server (SSR) + Browser | — | `<img>`/`<video controls>` nativo; URL assinada do ActiveStorage |
| Scoping de artes por cliente | API / Backend | — | `@client.artes.find(params[:id])` — nunca `Arte.find` |
| Ícones de plataforma (SVG) | Frontend Server (SSR) | — | Inline SVG nas partials Rails |
| Badges de status | Frontend Server (SSR) | — | Partial reutilizável (padrão Phase 3) |
| Serving de mídia (uploads) | CDN / Static (via Disk) | — | ActiveStorage Disk service + URL assinada |

---

## Standard Stack

### Core (já instalado — sem instalação adicional)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `simple_calendar` | 3.1.0 | Date range e agrupamento de eventos por dia | Já no Gemfile; fornece `month_calendar` helper com `date_range` e `sorted_events_for` [VERIFIED: gem contents em vendor/bundle] |
| `tailwindcss-rails` | — | CSS Grid da grade, layout, badges | Já instalado (Tailwind v4, tokens via CSS custom properties) [VERIFIED: Gemfile + Procfile.dev] |
| `stimulus-rails` | — | Toggle de senha no login (refatorar de inline JS para Stimulus) | Já instalado; `password_toggle_controller.js` existente [VERIFIED: arquivo em app/javascript/controllers/] |
| Rails ActiveStorage | Rails 8.1.3 | Serving de imagens/vídeos via URL assinada | Built-in Rails, Disk service configurado [VERIFIED: config/storage.yml] |

### Nenhuma gem nova necessária

Esta fase não requer instalação de pacotes adicionais. Todo o stack está disponível:
- Calendário: `simple_calendar` (já instalado)
- Tailwind: v4 (já instalado)
- Stimulus: já instalado
- ActiveStorage: built-in Rails

---

## Package Legitimacy Audit

> Nenhum pacote novo a ser instalado nesta fase. Todos os pacotes já estão no Gemfile e instalados em vendor/bundle.

| Package | Status |
|---------|--------|
| `simple_calendar` 3.1.0 | Já instalado — sem ação necessária |

**Packages removed due to slopcheck:** nenhum (nenhum novo pacote).
**Packages flagged as suspicious:** nenhum.

---

## Architecture Patterns

### System Architecture Diagram

```
Cliente (browser)
        │
        │ GET /c/:token?month=YYYY-MM
        ▼
ClientController#load_client_from_token ──► [404 se token inválido]
        │
        ▼
ClientController#require_client_auth ──────► [redirect login se não autenticado]
        │
        ▼
Client::HomeController#index
        │
        ├── parseia params[:month] → @current_month (Date)
        ├── @prev_month, @next_month (para nav links)
        ├── @artes = @client.artes.where(scheduled_on: grid_start..grid_end)
        │                   .includes(media_file_attachment: :blob)
        │
        ▼
client/home/index.html.erb
        │
        ├── layouts/client.html.erb (header + Sair + bg-white)
        │
        ├── [Cabeçalho navegação: < Maio 2026 >]
        │    link_to "<", client_root_path(token:, month: @prev_month)
        │    link_to ">", client_root_path(token:, month: @next_month)
        │
        └── [CSS Grid 7 colunas]
             │
             ├── month_calendar(attribute: :scheduled_on, events: @artes, start_date: @current_month, partial: 'client/home/month_calendar')
             │
             └── para cada dia:
                  ├── dia sem arte → número do dia text-gray-300
                  └── dia com arte(s) → cada arte: [ícone SVG plataforma] + [badge status]
                                        link_to → client_arte_path(token:, id:)

        │ GET /c/:token/artes/:id
        ▼
Client::ArtesController#show
        ├── @arte = @client.artes.find(params[:id])  ← escopo de segurança
        ├── renderiza: image / video / caption_only / external_url
        └── client/artes/show.html.erb
```

### Recommended Project Structure

```
app/
├── controllers/
│   ├── client_controller.rb              # BASE — já existe (load_client_from_token, require_client_auth)
│   │                                     # ADICIONAR: layout 'client'
│   └── client/
│       ├── sessions_controller.rb        # já existe — sem mudança de lógica
│       ├── home_controller.rb            # SUBSTITUIR stub por lógica real do calendário
│       └── artes_controller.rb           # NOVO — só action :show
├── views/
│   ├── layouts/
│   │   └── client.html.erb              # NOVO — layout dedicado
│   └── client/
│       ├── sessions/
│       │   └── new.html.erb             # REFATORAR — só card de login (sem HTML inline)
│       ├── home/
│       │   ├── index.html.erb           # NOVO — wrapper do calendário + navegação
│       │   └── _month_calendar.html.erb # NOVO — partial CSS Grid (substitui o da gem)
│       ├── artes/
│       │   └── show.html.erb            # NOVO — preview de arte
│       └── shared/
│           ├── _arte_status_badge.html.erb  # NOVO (adaptado do admin)
│           └── _platform_icon.html.erb      # NOVO — SVG inline (ig/fb/li)
config/
└── routes.rb                            # ADICIONAR resources :artes, only: [:show] no scope do cliente
```

### Pattern 1: Calendar Grid — Lógica Ruby sem simple_calendar (abordagem recomendada)

A decisão D-13 (`?month=YYYY-MM`) é incompatível com o `url_for_next_view` padrão da `simple_calendar` (que emite `?start_date=YYYY-MM-DD`). Para manter o contrato de URL limpo, **não usar** a navegação da gem. Usar apenas `date_range` via helpers Ruby nativos e o `events` grouping pode ser feito no controller.

**Controller:**

```ruby
# Source: Rails Date helpers (VERIFIED: rails runner confirmou funcionamento)
def index
  # Parsear ?month=YYYY-MM → Date (primeiro dia do mês)
  @current_month = if params[:month].present?
    begin
      Date.strptime(params[:month], '%Y-%m').beginning_of_month
    rescue Date::Error
      Date.today.beginning_of_month
    end
  else
    Date.today.beginning_of_month
  end

  # Navegação
  @prev_month = (@current_month - 1.month).strftime('%Y-%m')
  @next_month = (@current_month + 1.month).strftime('%Y-%m')
  @month_label = I18n.l(@current_month, format: '%B %Y')  # "Maio 2026" (com locale pt-BR)

  # Grid: da segunda-feira antes do início ao domingo após o fim
  grid_start = @current_month.beginning_of_week  # Monday (padrão atual — VERIFICADO)
  grid_end   = @current_month.end_of_month.end_of_week

  # Query eficiente com índice composto (client_id, scheduled_on)
  @artes = @client.artes
                  .where(scheduled_on: grid_start..grid_end)
                  .includes(media_file_attachment: :blob)
                  .order(:scheduled_on)

  # Agrupar por data para lookup O(1) na view
  @artes_by_date = @artes.group_by(&:scheduled_on)
  @grid_dates = (grid_start..grid_end).to_a
end
```

**View (index.html.erb):**

```erb
<%# Cabeçalho de navegação: < Maio 2026 > %>
<div class="flex items-center justify-center gap-4 mb-6">
  <%= link_to client_root_path(token: @client.access_token, month: @prev_month),
        aria: { label: "Mês anterior" },
        class: "p-2 rounded-lg hover:bg-gray-100 transition-colors text-slate-600" do %>
    <%# Heroicon chevron-left 20px %>
  <% end %>

  <h2 class="text-lg font-semibold text-slate-900 min-w-[160px] text-center">
    <%= @month_label %>
  </h2>

  <%= link_to client_root_path(token: @client.access_token, month: @next_month),
        aria: { label: "Próximo mês" },
        class: "p-2 rounded-lg hover:bg-gray-100 transition-colors text-slate-600" do %>
    <%# Heroicon chevron-right 20px %>
  <% end %>
</div>

<%# Grade 7 colunas %>
<div class="grid grid-cols-7 gap-px bg-gray-200 rounded-xl overflow-hidden">
  <%# Cabeçalho dias da semana %>
  <% %w[Seg Ter Qua Qui Sex Sáb Dom].each do |day| %>
    <div class="bg-gray-50 py-2 text-center text-xs font-medium text-slate-500 uppercase tracking-wide">
      <%= day %>
    </div>
  <% end %>

  <%# Células do calendário %>
  <% @grid_dates.each do |date| %>
    <%
      artes_do_dia = @artes_by_date[date] || []
      is_current_month = date.month == @current_month.month
    %>
    <div class="bg-white min-h-[100px] p-1.5 <%= is_current_month ? '' : 'bg-gray-50' %>">
      <span class="text-xs font-medium <%= artes_do_dia.any? ? 'text-slate-700' : 'text-gray-300' %>
                   <%= date == Date.today ? 'bg-[#EA580C] text-white rounded-full w-5 h-5 flex items-center justify-center' : '' %>">
        <%= date.day %>
      </span>

      <% artes_do_dia.each do |arte| %>
        <%= link_to client_arte_path(token: @client.access_token, id: arte),
              class: "mt-1 flex items-center gap-1 p-1 rounded bg-gray-50 hover:bg-gray-100 transition-colors" do %>
          <%= render 'client/shared/platform_icon', arte: arte, size: 12 %>
          <%= render 'client/shared/arte_status_badge', arte: arte, compact: true %>
        <% end %>
      <% end %>
    </div>
  <% end %>
</div>
```

### Pattern 2: Security Scope — Arte queries

```ruby
# Source: CONTEXT.md code_context + client_isolation_test.rb (VERIFIED: teste existente)
# SEMPRE usar @client.artes.find(params[:id]) — nunca Arte.find(params[:id]) diretamente
# Exemplo no Client::ArtesController:

def show
  @arte = @client.artes.find(params[:id])
  # Se arte não pertence ao @client → ActiveRecord::RecordNotFound → 404 automático
rescue ActiveRecord::RecordNotFound
  redirect_to client_root_path(token: @client.access_token),
              alert: "Arte não encontrada."
end
```

### Pattern 3: ActiveStorage URL para cliente

```ruby
# Source: Rails guides ActiveStorage (VERIFIED: routes confirmadas, expiry confirmado via runner)
# Para imagem: URL assinada com inline disposition (5 min expiry — adequado para imagens)
# Na view:
url_for(@arte.media_file)
# ou:
rails_blob_path(@arte.media_file, disposition: "inline")

# Para vídeo: 5 min pode ser insuficiente se o cliente pausar
# Solução: usar proxy (sem signed URL, proxied pelo Rails)
rails_service_blob_proxy_path(@arte.media_file.blob)
# OU aumentar expiry no config/environments/production.rb:
# config.active_storage.service_urls_expire_in = 1.hour

# Recomendação para esta fase: usar rails_blob_path(disposition: "inline") para imagens
# e url_for(@arte.media_file) para vídeos (comportamento padrão Rails)
# Se necessário, aumentar expiry em produção
```

**View do preview (client/artes/show.html.erb):**

```erb
<%# D-10: Renderização por media_type %>
<% if @arte.external_url.present? %>
  <%= link_to "Abrir arquivo", @arte.external_url,
        target: "_blank", rel: "noopener noreferrer",
        class: "inline-flex items-center gap-2 px-4 py-2 bg-[#EA580C] text-white rounded-lg" %>
<% elsif @arte.image? && @arte.media_file.attached? %>
  <%= image_tag url_for(@arte.media_file),
        class: "max-w-full max-h-[480px] object-contain mx-auto block rounded-xl" %>
<% elsif @arte.video? && @arte.media_file.attached? %>
  <video controls class="max-w-full max-h-[480px] block mx-auto rounded-xl">
    <source src="<%= url_for(@arte.media_file) %>" type="<%= @arte.media_file.content_type %>">
    Seu navegador não suporta reprodução de vídeo.
  </video>
<% elsif @arte.caption_only? %>
  <div class="p-6 text-sm text-slate-700 leading-relaxed whitespace-pre-wrap bg-gray-50 rounded-xl">
    <%= @arte.caption.presence || "Legenda não informada." %>
  </div>
<% end %>
```

### Pattern 4: Rotas — adicionar resources :artes no scope

```ruby
# config/routes.rb — adicionar dentro do scope "/c/:token"
scope "/c/:token", as: :client do
  root to: "client/home#index"
  resource :session, only: [ :new, :create, :destroy ], controller: "client/sessions"
  resources :artes, only: [ :show ], controller: "client/artes"  # NOVO
end

# Isso gera:
# client_arte GET /c/:token/artes/:id  client/artes#show
# Helper: client_arte_path(token: @client.access_token, id: arte)
```

### Pattern 5: pt-BR month names sem rails-i18n

`rails-i18n` não está no Gemfile. `simple_calendar` usa `t('date.month_names')` — com locale `en` retorna English. Existem duas opções:

**Opção A (recomendada): Adicionar locale pt-BR manualmente**

```yaml
# config/locales/pt-BR.yml
pt-BR:
  date:
    month_names: [~, Janeiro, Fevereiro, Março, Abril, Maio, Junho, Julho, Agosto, Setembro, Outubro, Novembro, Dezembro]
    abbr_day_names: [Dom, Seg, Ter, Qua, Qui, Sex, Sáb]
    day_names: [Domingo, Segunda-feira, Terça-feira, Quarta-feira, Quinta-feira, Sexta-feira, Sábado]
  simple_calendar:
    previous: "Anterior"
    next: "Próximo"
    today: "Hoje"
```

**Opção B: Hard-code no controller**

```ruby
MONTH_NAMES_PTBR = %w[_ Janeiro Fevereiro Março Abril Maio Junho Julho Agosto
                       Setembro Outubro Novembro Dezembro]
@month_label = "#{MONTH_NAMES_PTBR[@current_month.month]} #{@current_month.year}"
```

A Opção A é a abordagem padrão Rails e deixa o terreno para i18n futuro. [ASSUMED: rails-i18n não está no Gemfile — verificado; locale pt-BR manual é abordagem correta]

### Pattern 6: Layout client.html.erb

```erb
<%# Baseado em layouts/admin.html.erb — fonte: VERIFIED lendo o arquivo %>
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <title><%= content_for(:title) || "Ilha Criativa · Calendário" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= yield :head %>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="min-h-screen bg-white flex flex-col">
    <header class="sticky top-0 bg-white border-b border-gray-100 z-10">
      <div class="px-4 sm:px-6 py-4 flex items-center justify-between">
        <span class="font-semibold text-[#0F7949]">Ilha Criativa</span>
        <span class="text-sm text-slate-600 font-medium"><%= @client&.name %></span>
        <%= button_to "Sair", client_session_path(token: @client&.access_token),
              method: :delete,
              class: "text-sm text-slate-500 hover:text-slate-900 transition-colors" %>
      </div>
    </header>

    <% if flash[:notice] %>
      <div class="mx-4 sm:mx-6 mt-4 px-4 py-3 bg-green-50 border border-green-200 rounded-lg" role="alert">
        <span class="text-green-700 text-sm"><%= flash[:notice] %></span>
      </div>
    <% end %>
    <% if flash[:alert] %>
      <div class="mx-4 sm:mx-6 mt-4 px-4 py-3 bg-red-50 border border-red-200 rounded-lg" role="alert">
        <span class="text-red-600 text-sm font-medium"><%= flash[:alert] %></span>
      </div>
    <% end %>

    <main class="flex-1 px-4 sm:px-6 py-6 sm:py-8">
      <%= yield %>
    </main>
  </body>
</html>
```

### Pattern 7: Platform icons (inline SVG)

O Phase 3 UI-SPEC já define o comportamento visual dos ícones (C3 — PlatformBadge). As SVGs devem ser das logos oficiais de cada plataforma (não Heroicons). São SVGs minimalistas de marca.

```erb
<%# app/views/client/shared/_platform_icon.html.erb %>
<%# Locals: arte (Arte), size (Integer, padrão 16) %>
<% size ||= 16 %>

<% case arte.platform %>
<% when 'instagram' %>
  <svg width="<%= size %>" height="<%= size %>" viewBox="0 0 24 24" fill="none" aria-label="Instagram">
    <rect x="2" y="2" width="20" height="20" rx="5" ry="5" stroke="#E1306C" stroke-width="2"/>
    <circle cx="12" cy="12" r="4" stroke="#E1306C" stroke-width="2"/>
    <circle cx="17.5" cy="6.5" r="1" fill="#E1306C"/>
  </svg>
<% when 'facebook' %>
  <svg width="<%= size %>" height="<%= size %>" viewBox="0 0 24 24" fill="#1877F2" aria-label="Facebook">
    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
  </svg>
<% when 'linkedin' %>
  <svg width="<%= size %>" height="<%= size %>" viewBox="0 0 24 24" fill="#0A66C2" aria-label="LinkedIn">
    <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
  </svg>
<% end %>
```

### Anti-Patterns to Avoid

- **Arte.find sem escopo**: Nunca `Arte.find(params[:id])` diretamente — sempre `@client.artes.find(...)`.
- **Iframe para links externos**: Iframes do Drive/Dropbox são instáveis — usar botão "Abrir arquivo" com `target="_blank"`.
- **Signed URLs em `<img src>` server-rendered para cache**: O signed URL expira em 5 min. Para listas/grids com muitas imagens, não pré-renderizar thumbnails de blob; manter como link clicável.
- **Date.parse com YYYY-MM**: Lança `Date::Error`. Usar `Date.strptime(params[:month], '%Y-%m')` dentro de `rescue Date::Error`.
- **Usar `params[:month]` sem sanitização**: Sempre validar/sanitizar. Se inválido, fallback para `Date.today.beginning_of_month`.
- **beginning_of_week sem configuração**: O padrão Rails é `:monday` — VERIFICADO via `rails runner`. Para calendário Seg–Dom, não precisamos configurar explicitamente.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date range para calendário mensal | Loop manual de datas | `Date#beginning_of_month.beginning_of_week..end_of_month.end_of_week` (Ruby on Rails Date helpers) | Correto para fuso horário, respeita `Date.beginning_of_week` |
| Agrupamento de artes por data | Hash manual | `@artes.group_by(&:scheduled_on)` | Uma linha, eficiente |
| Signed URLs para media | Gerar HMAC manualmente | `url_for(blob)` / `rails_blob_path(blob, disposition: "inline")` | Built-in Rails, seguro, expiração gerenciada |
| Toggle de senha no login | `onclick` inline JS | `password_toggle_controller.js` existente com `data-controller="password-toggle"` | Já implementado; migrar o botão existente para Stimulus |
| Parsing de YYYY-MM | Regex manual | `Date.strptime(str, '%Y-%m')` | stdlib Ruby, levanta `Date::Error` para input inválido |

**Key insight:** Todo o Ruby necessário para o calendário já existe na stdlib/ActiveSupport. Não há necessidade de gems adicionais.

---

## Common Pitfalls

### Pitfall 1: Cross-client data leak

**What goes wrong:** Controller usa `Arte.find(params[:id])` em vez de `@client.artes.find(params[:id])`. Cliente A consegue ver arte de Cliente B acessando `/c/TOKEN_A/artes/ID_ARTE_B`.

**Why it happens:** Padrão CRUD gerado automaticamente com scaffold usa o model diretamente.

**How to avoid:** `Client::ArtesController#show` DEVE usar `@client.artes.find(params[:id])`. Teste de integração `client_isolation_test.rb` já valida este cenário — adicionar teste para `Client::ArtesController` também.

**Warning signs:** Logs de acesso a artes de outros clientes; dados visíveis via URL manipulation.

### Pitfall 2: Date.strptime falhando silenciosamente

**What goes wrong:** `params[:month]` com valor malformado ("2026-13", "abc", etc.) causa crash não tratado ou exibe mês errado.

**Why it happens:** Confiar que o browser sempre envia YYYY-MM válido.

**How to avoid:** Sempre usar `rescue Date::Error` no bloco de parsing:
```ruby
Date.strptime(params[:month], '%Y-%m').beginning_of_month
rescue Date::Error
  Date.today.beginning_of_month
```

**Warning signs:** Erros 500 ao alterar manualmente o parâmetro `?month=` na URL.

### Pitfall 3: beginning_of_week returnando domingo

**What goes wrong:** Calendário começa no Domingo em vez de Segunda. Grade fica desalinhada.

**Why it happens:** `beginning_of_week` usa `:monday` por padrão no Rails, mas pode ser overridden por configuração ou test setup.

**How to avoid:** Confirmado via `rails runner` que o default atual é `:monday` (correto para pt-BR). Não há `config.beginning_of_week` no `application.rb`. O default funciona. Se necessário, adicionar `config.beginning_of_week = :monday` explicitamente.

**Warning signs:** Grade começa no Domingo; coluna "Dom" aparece à esquerda.

### Pitfall 4: ActiveStorage URL expirando em preview de vídeo

**What goes wrong:** O cliente abre a página de preview de vídeo, pausa por mais de 5 minutos, depois aperta Play → vídeo falha a carregar (URL expirou).

**Why it happens:** `active_storage.service_urls_expire_in` default é 300 segundos (confirmado via `rails runner`).

**How to avoid:** Para vídeos, usar `rails_service_blob_proxy_path(@arte.media_file.blob)` (sem expiração, proxied pelo Rails) ou aumentar `config.active_storage.service_urls_expire_in = 1.hour` em produção.

**Warning signs:** Vídeos falham após alguns minutos em produção.

### Pitfall 5: N+1 na grade do calendário

**What goes wrong:** Para cada arte no grid, Rails faz uma query separada para carregar o blob attachment.

**Why it happens:** `has_one_attached :media_file` gera um join extra se não carregado com includes.

**How to avoid:** Na query do controller:
```ruby
@client.artes
       .where(scheduled_on: grid_start..grid_end)
       .includes(media_file_attachment: :blob)
       .order(:scheduled_on)
```

**Warning signs:** Dezenas de queries SQL em uma única request do calendário.

### Pitfall 6: Layout do cliente renderizando `@client` nil antes de `load_client_from_token`

**What goes wrong:** `layouts/client.html.erb` usa `@client.name` no header. Em erros 404/403 do `load_client_from_token`, `@client` pode ser `nil`.

**Why it happens:** O layout é renderizado mesmo em respostas de erro.

**How to avoid:** Usar safe navigation: `@client&.name`, `@client&.access_token`. As respostas de erro em `load_client_from_token` renderizam `plain:` sem layout (já usa `render plain:`, não renderiza `layouts/client`).

**Warning signs:** `NoMethodError: undefined method 'name' for nil` nos logs quando token inválido é acessado.

---

## Code Examples

### Exemplo completo — controller index

```ruby
# app/controllers/client/home_controller.rb
# Source: Análise dos patterns existentes (VERIFIED: client_controller.rb, arte.rb, client_isolation_test.rb)
class Client::HomeController < ClientController
  def index
    @current_month = parse_month_param

    @prev_month = (@current_month - 1.month).strftime('%Y-%m')
    @next_month = (@current_month + 1.month).strftime('%Y-%m')

    grid_start = @current_month.beginning_of_week   # Monday (Rails default, confirmado)
    grid_end   = @current_month.end_of_month.end_of_week

    @artes = @client.artes
                    .where(scheduled_on: grid_start..grid_end)
                    .includes(media_file_attachment: :blob)
                    .order(:scheduled_on)

    @artes_by_date = @artes.group_by(&:scheduled_on)
    @grid_dates    = (grid_start..grid_end).to_a
  end

  private

  def parse_month_param
    return Date.today.beginning_of_month unless params[:month].present?
    Date.strptime(params[:month], '%Y-%m').beginning_of_month
  rescue Date::Error
    Date.today.beginning_of_month
  end
end
```

### Exemplo completo — Client::ArtesController

```ruby
# app/controllers/client/artes_controller.rb
# Source: Padrão de segurança (VERIFIED: client_isolation_test.rb linha 22-26)
class Client::ArtesController < ClientController
  before_action :set_arte

  def show
  end

  private

  def set_arte
    @arte = @client.artes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to client_root_path(token: @client.access_token),
                alert: "Arte não encontrada."
  end
end
```

### Exemplo — refatoração do login view (D-03)

```erb
<%# ANTES: app/views/client/sessions/new.html.erb contém DOCTYPE + <head> + <body> completos %>
<%# DEPOIS: apenas o conteúdo do card de login %>

<%# app/views/client/sessions/new.html.erb (após refatoração) %>

<div class="flex-1 flex items-center justify-center px-4 py-8">
  <div class="bg-white rounded-xl shadow-sm border border-gray-100 max-w-sm w-full p-8">
    <h1 class="text-xl font-semibold text-slate-900 mb-1">Bem-vindo(a)!</h1>
    <p class="text-slate-500 text-sm mb-6">Digite sua senha para acessar os conteúdos preparados para você.</p>

    <% if flash[:alert] %>
      <div class="mb-4 px-4 py-3 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm" role="alert">
        <%= flash[:alert] %>
      </div>
    <% end %>

    <%= form_with url: client_session_path(token: params[:token]), method: :post,
                  aria: { label: "Acesso ao calendário" }, class: "space-y-4" do |f| %>
      <div>
        <%= f.label :password, "Senha de acesso", class: "block text-sm font-medium text-slate-700 mb-1" %>
        <div class="relative" data-controller="password-toggle">
          <%= f.password_field :password,
                data: { "password-toggle-target": "field" },
                autocomplete: "current-password",
                class: "w-full h-12 sm:h-11 border-2 border-gray-200 rounded-lg px-4 pr-12 text-sm
                        focus:outline-none focus:border-[#EA580C] focus:ring-2 focus:ring-[#EA580C]/10
                        #{flash[:alert] ? 'border-red-400' : ''}" %>
          <button type="button"
                  data-password-toggle-target="toggle"
                  data-action="click->password-toggle#toggle"
                  aria-pressed="false" aria-label="Mostrar senha"
                  class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
            <%# ícone olho Heroicons 20px %>
          </button>
        </div>
      </div>
      <%= f.submit "Acessar calendário",
            class: "w-full h-11 bg-[#EA580C] hover:bg-[#C2410C] text-white font-semibold
                    rounded-lg transition-colors duration-150 cursor-pointer" %>
    <% end %>
  </div>
</div>
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Calendário com `<table>` (simple_calendar padrão) | CSS Grid 7 colunas (decisão D-05) | Esta fase | Mais controle visual; células crescem livremente para múltiplas artes |
| JavaScript para toggle de senha (inline `onclick`) | Stimulus `password_toggle_controller` | Phase 1 em diante | Remover `<script>` inline do `sessions/new.html.erb` |
| Signed URLs com expiração curta para vídeos | Proxy path (sem expiração) | Rails 7.1+ | Vídeos não expiram durante visualização |

**Nota sobre simple_calendar:** A gem está no Gemfile e instalada. O planner PODE escolher usar `month_calendar()` helper para obter `date_range` e `sorted_events_for()` (gerando as views customizadas via generator), ou pode ignorá-la totalmente e usar Ruby puro. Ambas são válidas. A abordagem Ruby puro (controller + `group_by`) é mais simples e evita a dependência do `start_date_param`. [VERIFIED: comportamento da gem lido de vendor/bundle]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Nomes de meses PT-BR serão adicionados via `config/locales/pt-BR.yml` manual (não `rails-i18n`) | Standard Stack / Pattern 5 | Exibe meses em inglês se locale não for configurado; baixo risco com Opção B (hard-code) |
| A2 | `Date.beginning_of_week` retorna `:monday` — nenhuma configuração global sobrescreve isso | Pitfall 3 | Calendário começa no domingo se sobrescrito; confirmado via `rails runner` que default é monday |
| A3 | SVGs inline de plataforma (Pattern 7) são corretos visualmente | Platform icons | SVGs podem não representar fielmente as marcas; revisar antes de commit |
| A4 | `rails_service_blob_proxy_path` é adequado para vídeos em produção com Disk service local | Pitfall 4 / Pattern 3 | Em produção atrás de CDN, proxy pode ter comportamento diferente; testar em staging |

**Se tabela vazia:** Todos os claims verificados — sem confirmação necessária. [A tabela acima tem 4 claims de baixo risco.]

---

## Open Questions

1. **simple_calendar ou Ruby puro?**
   - O que sabemos: simple_calendar 3.1.0 está instalado. Fornece `date_range` e `sorted_events_for`. Não fornece navegação compatível com `?month=YYYY-MM`.
   - O que está incerto: o planner deve decidir se quer usar `month_calendar` helper com partial customizado (gerando views) ou implementar puramente no controller + view.
   - Recomendação: Ruby puro no controller (Pattern 1). É mais simples, mais controlável, e evita a complexidade de overridar o partial da gem.

2. **Thumbnail de arte na grade?**
   - O que sabemos: D-08 diz "ícone SVG da plataforma + badge de status". Não menciona thumbnail de imagem na célula da grade.
   - O que está incerto: o cliente quer ver uma miniatura da imagem na grade ou apenas os badges?
   - Recomendação: seguir D-08 literalmente — sem thumbnail na grade (apenas ícone + badge). Preview completo só em `/c/:token/artes/:id`.

3. **Expiração de URL para vídeo**
   - O que sabemos: 300s de expiry. Proxy disponível.
   - O que está incerto: Disk service em produção — proxy é adequado?
   - Recomendação: Para MVP, usar proxy path para vídeos. Documentar em PLAN como decisão.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Rails | Core | ✓ | 8.1.3 | — |
| PostgreSQL | Database | ✓ | — (pg gem instalado) | — |
| simple_calendar | Calendar logic | ✓ | 3.1.0 (vendor/bundle) | Ruby puro (Date helpers) |
| Tailwind v4 | CSS Grid | ✓ | instalado | — |
| Stimulus | password-toggle | ✓ | instalado | inline JS (já existe no current sessions/new) |
| ActiveStorage Disk | Media serving | ✓ | Rails built-in | — |
| Inter font (Google) | Typography | ✓ (CDN) | — | System font stack |

**Missing dependencies:** nenhum.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Rails Minitest (ActionDispatch::IntegrationTest) |
| Config file | `test/test_helper.rb` |
| Quick run command | `bundle exec rails test test/controllers/client/ test/integration/client_isolation_test.rb` |
| Full suite command | `bundle exec rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAL-01 | Grid mensal exibido com artes do cliente no mês correto | Integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ Wave 0 |
| CAL-02 | Navegação para mês anterior e próximo via `?month=` param | Integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ Wave 0 |
| CAL-03 | Preview de arte (imagem, vídeo, caption) acessível em `/c/:token/artes/:id` | Integration | `bundle exec rails test test/controllers/client/artes_controller_test.rb` | ❌ Wave 0 |
| CAL-04 | Status e prazo exibidos na grade | Integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ Wave 0 |
| CAL-05 | Ícone de plataforma exibido para cada arte | Integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ Wave 0 |
| SEC | Arte de outro cliente retorna 404/redirect (cross-client isolation) | Integration | `bundle exec rails test test/integration/client_isolation_test.rb` | ✅ Existente |
| AUTH | Arte inacessível sem autenticação (redireciona para login) | Integration | `bundle exec rails test test/controllers/client/artes_controller_test.rb` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bundle exec rails test test/controllers/client/`
- **Per wave merge:** `bundle exec rails test`
- **Phase gate:** Suite completa verde antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/controllers/client/home_controller_test.rb` — cobre CAL-01, CAL-02, CAL-04, CAL-05
- [ ] `test/controllers/client/artes_controller_test.rb` — cobre CAL-03, AUTH, cross-client para artes
- [ ] Helper de login em testes de client controller:
  ```ruby
  # Adicionar em test/test_helpers/session_test_helper.rb:
  def sign_in_as_client(client, password: "senha123")
    post client_session_path(token: client.access_token), params: { password: password }
  end
  ```

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1` — seção obrigatória.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Sim (existente) | `ClientController#require_client_auth` via session cookie — já implementado Phase 1 |
| V3 Session Management | Sim (existente) | `session[:client_id]` + `session[:client_token_version]` — já implementado |
| V4 Access Control | **Sim (esta fase)** | `@client.artes.find(params[:id])` — scope obrigatório. Nunca `Arte.find` direto |
| V5 Input Validation | Sim | `Date.strptime` com `rescue Date::Error` para `params[:month]`; `params[:id]` validado pelo ActiveRecord |
| V6 Cryptography | Não aplicável | Sem operações criptográficas nesta fase; ActiveStorage signed URLs são Rails built-in |

### Known Threat Patterns for Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-client IDOR (acesso arte de outro cliente via ID na URL) | Elevation of Privilege | `@client.artes.find(params[:id])` — escopo por cliente; teste em `client_isolation_test.rb` |
| Path traversal em parâmetro `month` | Tampering | `Date.strptime` com rescue — input malformado retorna `Date.today` |
| Open redirect via `external_url` da arte | Tampering | `target="_blank" rel="noopener noreferrer"` — sem redirect server-side; o link abre no browser do cliente |
| Clickjacking via iframe de external_url | Spoofing | Decisão D-12 proíbe iframe — apenas botão `target="_blank"` |
| Brute force na rota de artes | DoS | Rack::Attack já protege `/c/:token/session` — rota de artes é autenticada (requer sessão ativa) |

---

## Sources

### Primary (HIGH confidence)

- `vendor/bundle/ruby/3.3.0/gems/simple_calendar-3.1.0/` — README.md, `lib/simple_calendar/calendar.rb`, `lib/simple_calendar/month_calendar.rb`, partials — lidos diretamente do vendor/bundle
- `app/controllers/client_controller.rb` — padrão de autenticação e escopo confirmados
- `test/integration/client_isolation_test.rb` — padrão de segurança confirmado e testado
- `db/schema.rb` — índice composto `(client_id, scheduled_on)` confirmado
- `config/application.rb` — `config.time_zone = "Brasilia"` confirmado
- `bundle exec rails runner "puts Date.beginning_of_week"` — retornou `monday`
- `bundle exec rails runner "puts ActiveStorage.service_urls_expire_in"` — retornou `300`

### Secondary (MEDIUM confidence)

- `.planning/phases/03-art-management/03-UI-SPEC.md` — tokens de design, badge colors, SVG de plataforma (padrão estabelecido)
- `app/views/layouts/admin.html.erb` — padrão de layout para replicar em `layouts/client.html.erb`
- `app/views/client/sessions/new.html.erb` — HTML atual a ser refatorado (source of truth para refatoração D-03)

### Tertiary (LOW confidence)

- SVGs de plataforma (Pattern 7) — baseados em training knowledge das logos oficiais; validar visualmente antes do commit [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — gem confirmada no vendor/bundle, versão lida diretamente
- Architecture: HIGH — padrões verificados no código existente (`client_controller.rb`, testes de isolamento)
- Calendar grid logic: HIGH — `rails runner` confirmou comportamento de `beginning_of_week`, `strptime`, `group_by`
- ActiveStorage: HIGH — routes confirmadas, expiry confirmado via runner
- Pitfalls: HIGH — todos verificados via code inspection ou runner
- SVG icons: MEDIUM — visual da marca assumido por training knowledge

**Research date:** 2026-05-25
**Valid until:** 2026-06-25 (stack estável — Rails 8.1.x, simple_calendar 3.1.0)
