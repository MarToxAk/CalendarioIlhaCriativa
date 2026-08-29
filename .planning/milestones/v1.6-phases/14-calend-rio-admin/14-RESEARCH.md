# Phase 14: Calendário Admin - Research

**Researched:** 2026-06-04
**Domain:** Rails admin calendar — Turbo Frame navigation, multi-client color palette, chip overflow
**Confidence:** HIGH

## Summary

Esta fase é majoritariamente de adaptação de código existente: o calendário do cliente
(`client/home`) já implementa toda a lógica de grade mensal com Turbo Frame — o trabalho é
replicar e adaptar esse padrão para o contexto admin (todos os clientes, chips coloridos por
cliente, iniciais no lugar de status badge).

O projeto não usa nenhuma gem de calendário (ex: `simple_calendar`); a grade é construída
manualmente com `grid-cols-7` do Tailwind e lógica Ruby pura no controller.
Nenhuma migration é necessária: a paleta de cores é derivada deterministicamente de
`client.id % 8`, sem campo adicional no banco.

A única parte nova é o helper `client_color(client)` e o chip de arte com overflow `+N`.
Todo o resto (parse_month_param, grid_start/grid_end, Turbo Frame, rota admin) segue padrões
já estabelecidos e verificados nas fases anteriores.

**Primary recommendation:** Copiar e adaptar `client/home_controller.rb` e
`_month_calendar.html.erb`; adicionar `client_color` em `ApplicationHelper`; registrar a
rota e wirear o sidebar.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Navegação entre meses (setas) | Frontend Server (Rails view) | — | Links com `data-turbo-frame` disparam request parcial — sem JS customizado |
| Grade mensal (células + chips) | Frontend Server (Rails view) | — | Renderizado server-side via ERB; Turbo Frame entrega HTML parcial |
| Query de artes do período | API / Backend (controller) | Database | Controller calcula grid_start..grid_end e faz query com `includes(:client)` |
| Paleta de cores por cliente | Frontend Server (helper) | — | `client_color` em ApplicationHelper — cálculo puro, sem banco |
| Link chip → show da arte | Frontend Server (view) | — | `link_to admin_arte_path(arte)` — rota já existente |
| Wiring sidebar | Frontend Server (view partial) | — | Substituir `"#"` por `admin_calendar_index_path` em `_sidebar.html.erb` |

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: Cores por cliente**
- Paleta automática baseada no índice do cliente: `client.id % palette_size` → cor da paleta. **Sem migration.**
- Helper `client_color(client)` em `ApplicationHelper` — retorna par de classes Tailwind (fundo suave + texto escuro), ex: `{ bg: "bg-[#F0FDF4]", text: "text-[#14A958]" }`.
- Paleta com 8 cores distintas e acessíveis (fundo suave + texto escuro, estilo badges existentes do design system).

**D-02: Navegação entre meses**
- **Turbo Frame** — setas de navegação e título do mês ficam FORA do turbo-frame; grade do calendário fica DENTRO. Padrão Phase 6/13.
- Layout: `[← seta] [Mês Ano] [seta →]` no cabeçalho da página, acima do turbo-frame.
- Frame id: `"calendar-content"` (padrão do projeto).

**D-03: Chip de arte na célula do dia**
- Cada arte exibe: **fundo colorido do cliente + iniciais do cliente (2 chars)**, sem informações adicionais.
- Chip é um `link_to admin_arte_path(arte)` — clique leva ao show da arte (CADM-05).
- Sem ícone de plataforma, sem título da arte no chip.

**D-04: Overflow de artes por dia**
- Mostrar **máximo 3 chips** por célula; se houver mais, exibir contador `+N` em cinza.
- O `+N` é texto estático (não clicável) nesta fase. Modal/expansão é funcionalidade futura.
- Ordenação dos chips: por `id` (insertion order) — sem ordenação especial.

### Claude's Discretion
- Nome do controller/rota: `Admin::CalendarController`, rota `resources :calendar, only: [:index]` → URL `/admin/calendar`.
- Wiring do sidebar: alterar `{ label: "Calendário", path: "#" }` para `{ label: "Calendário", path: admin_calendar_index_path }`.
- Altura mínima das células: `min-h-[80px]` para manter grid consistente independente do conteúdo.
- Paleta de 8 cores sugerida (fundo/texto): verde, azul, roxo, laranja, rosa, teal, amarelo, índigo — adaptar ao design system.

### Deferred Ideas (OUT OF SCOPE)
- Clique no `+N` para expandir artes do dia (modal ou página) — fase futura
- Admin escolher cor de cada cliente manualmente (campo `color` na tabela) — fase futura
- Chips com ícone de plataforma (Instagram/Facebook/LinkedIn) — fase futura
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CADM-01 | Admin acessa a página "Calendário" pelo link do sidebar (wired, não mais `#`) | Sidebar `_sidebar.html.erb` linha 16 já identificada; substituir `"#"` por `admin_calendar_index_path` após rota registrada |
| CADM-02 | Admin vê calendário mensal com artes de todos os clientes agrupadas por dia | Query `Arte.where(scheduled_on: ...).includes(:client)` — sem N+1; grade 7-colunas herdada do client/home |
| CADM-03 | Cada arte no calendário admin exibe cor de fundo única por cliente e nome/iniciais do cliente visível | Helper `client_color(client)` + iniciais derivadas de `client.name` |
| CADM-04 | Admin navega entre meses no calendário admin | Turbo Frame `"calendar-content"` + setas fora do frame com `data: { turbo_frame: "calendar-content" }` |
| CADM-05 | Admin clica numa arte no calendário admin e acessa a página da arte diretamente | Chip é `link_to admin_arte_path(arte)` — rota já existente desde Phase 3 |
</phase_requirements>

---

## Standard Stack

### Core (tudo já presente no projeto — sem instalações novas)

| Biblioteca | Versão | Propósito | Por que padrão |
|------------|--------|-----------|----------------|
| Rails 8.1 | 8.1 | Framework base | Stack do projeto [VERIFIED: schema.rb] |
| Turbo (Hotwire) | bundled | Navegação parcial sem reload | Já usado em fases 6 e 13 [VERIFIED: codebase] |
| Tailwind CSS | via CDN/app | Utilitários CSS — grid, cores hex arbitrárias | Design system do projeto [VERIFIED: codebase] |
| I18n (Rails) | bundled | `I18n.l(date, format: "%B %Y")` para label do mês | Já usado no client/home_controller [VERIFIED: codebase] |

### Nenhum pacote novo necessário

Esta fase não instala dependências externas. Todo o stack necessário está presente.

## Package Legitimacy Audit

> Nenhum pacote externo será instalado nesta fase.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Requisição HTTP GET /admin/calendar?month=YYYY-MM
        |
        v
Admin::CalendarController#index
  - parse_month_param → current_month (Date)
  - calcula grid_start (beginning_of_week) e grid_end (end_of_month.end_of_week)
  - Arte.where(scheduled_on: grid_start..grid_end).includes(:client).order(:id)
  - group_by(&:scheduled_on) → @artes_by_date
        |
        v
views/admin/calendar/index.html.erb
  [FORA do frame]
    - Cabeçalho: ← seta | Mês Ano | seta →
      (links com data-turbo-frame: "calendar-content")
  [DENTRO do <turbo-frame id="calendar-content">]
    - render partial: "calendar_grid"
      - grid 7 colunas (Seg..Dom)
      - células: cada data do grid_start..grid_end
        - chips: máximo 3 por célula
          - link_to admin_arte_path(arte) com bg/text do client_color
          - iniciais do cliente (2 chars)
        - se total > 3: span "+N" cinza estático

ApplicationHelper#client_color(client)
  - client.id % 8 → índice na paleta
  - retorna { bg: "bg-[#HEX]", text: "text-[#HEX]" }
```

### Recommended Project Structure

```
app/
├── controllers/admin/
│   └── calendar_controller.rb      # NOVO — herda Admin::BaseController
├── helpers/
│   └── application_helper.rb       # MODIFICAR — adicionar client_color(client)
└── views/admin/
    └── calendar/
        ├── index.html.erb           # NOVO — cabeçalho + turbo-frame
        └── _calendar_grid.html.erb  # NOVO — grade 7 colunas + chips

config/
└── routes.rb                        # MODIFICAR — resources :calendar, only: [:index]

app/views/admin/shared/
└── _sidebar.html.erb                # MODIFICAR — path: "#" → admin_calendar_index_path
```

### Pattern 1: Controller — replicar client/home_controller

**O que:** Copiar a lógica de `parse_month_param`, `grid_start/grid_end` e `group_by` do
`Client::HomeController`, adaptando para buscar artes de todos os clientes.

**Quando usar:** Todo calendário admin usa este padrão.

**Código verificado:**
```ruby
# Source: app/controllers/client/home_controller.rb [VERIFIED: codebase]
class Admin::CalendarController < Admin::BaseController
  def index
    @current_month = parse_month_param

    @prev_month = (@current_month - 1.month).strftime("%Y-%m")
    @next_month = (@current_month + 1.month).strftime("%Y-%m")
    @month_label = I18n.l(@current_month, format: "%B %Y")

    grid_start = @current_month.beginning_of_week   # Segunda-feira (padrão Rails)
    grid_end   = @current_month.end_of_month.end_of_week

    @artes = Arte.where(scheduled_on: grid_start..grid_end)
                 .includes(:client)
                 .order(:id)

    @artes_by_date = @artes.group_by(&:scheduled_on)
    @grid_dates    = (grid_start..grid_end).to_a
  end

  private

  def parse_month_param
    return Date.today.beginning_of_month unless params[:month].present?
    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue Date::Error
    Date.today.beginning_of_month
  end
end
```

**Diferenças-chave vs. client/home:**
- Busca `Arte` de TODOS os clientes (sem filtro `@client.artes`)
- `includes(:client)` em vez de `includes(media_file_attachment: :blob)` — precisa do cliente para cor e iniciais
- `order(:id)` para consistência determinística dos chips
- Sem cálculo de `@summary` (não necessário no admin)

### Pattern 2: Helper de cor determinística

**O que:** `client_color(client)` retorna par `{ bg:, text: }` de classes Tailwind com cores
hex inline (`bg-[#HEX]`), mantendo o padrão do design system existente.

**Código a implementar:**
```ruby
# Source: decision D-01 do CONTEXT.md + análise do design system [VERIFIED: codebase]
# Em app/helpers/application_helper.rb
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
```

### Pattern 3: Chip de arte com overflow

**O que:** Cada célula mostra até 3 chips clicáveis + texto estático `+N` quando há mais.

**Código a implementar:**
```erb
<%# Source: adaptação de _month_calendar.html.erb + D-03/D-04 [VERIFIED: codebase] %>
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

### Pattern 4: Turbo Frame + setas de navegação

**O que:** Setas ficam FORA do frame para que ao clicar o browser não execute frame navigation
antes de substituir o conteúdo — padrão estabelecido nas fases 6 e 13.

**Referência verificada:**
```erb
<%# Source: app/views/admin/approvals/index.html.erb + client/home/index.html.erb [VERIFIED: codebase] %>

<%# FORA do turbo-frame — atualiza apenas o conteúdo interno %>
<div class="flex items-center justify-center gap-4 mb-6">
  <%= link_to admin_calendar_index_path(month: @prev_month),
        data: { turbo_frame: "calendar-content" },
        aria: { label: "Mês anterior" },
        class: "p-2 rounded-lg hover:bg-gray-100 transition-colors text-slate-600" do %>
    <%# SVG seta esquerda %>
  <% end %>

  <h2 class="text-lg font-semibold text-slate-900 min-w-[160px] text-center">
    <%= @month_label %>
  </h2>

  <%= link_to admin_calendar_index_path(month: @next_month),
        data: { turbo_frame: "calendar-content" },
        aria: { label: "Próximo mês" },
        class: "p-2 rounded-lg hover:bg-gray-100 transition-colors text-slate-600" do %>
    <%# SVG seta direita %>
  <% end %>
</div>

<turbo-frame id="calendar-content">
  <%= render "calendar_grid", ... %>
</turbo-frame>
```

### Pattern 5: Rota resources singular vs. plural

**Situação:** `resources :calendar` gera rotas no plural (index = `GET /admin/calendar`),
helper = `admin_calendar_index_path`. Isso é correto e esperado — NÃO usar `resource :calendar`
(singular) pois o calendário é uma view de coleção (index), não um recurso singleton.

**Verificado em routes.rb:** O padrão do projeto é `resources :approvals, only: [:index]`
para views de coleção. Replicar o mesmo.

### Anti-Patterns to Avoid

- **N+1 na query de clientes:** Nunca iterar `arte.client` sem `includes(:client)`. O padrão correto é `.includes(:client)` na query do controller. [VERIFIED: codebase — approvals_controller usa includes(arte: :client)]
- **Turbo Frame nas setas dentro do frame:** As setas de navegação DEVEM ficar fora do `<turbo-frame>`. Se colocadas dentro, ao clicar a resposta substitui o frame completo mas as setas também são substituídas, causando comportamento correto mas potencialmente quebrando o layout se o frame não incluir as setas na resposta parcial.
- **`resource :calendar` singular no lugar de `resources :calendar`:** Gerar `resource` (singular) cria rotas sem o helper `_index_path` e sem o action `index` no padrão esperado. Usar `resources :calendar, only: [:index]`.
- **Cores CSS inline em vez de classes Tailwind:** O projeto usa consistentemente `bg-[#HEX]` em vez de `style="background: #HEX"`. Manter esse padrão para o Tailwind purge funcionar (JIT escaneia classes, não valores inline). [VERIFIED: codebase]

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por que |
|----------|--------------|-------------------|---------|
| Parse do parâmetro `?month=` | Parser próprio com rescue | `Date.strptime(params[:month], "%Y-%m").beginning_of_month rescue Date::Error` | Já implementado e testado em client/home_controller — copiar verbatim |
| Cálculo do grid da semana | Lógica de dias da semana manual | `beginning_of_week` / `end_of_month.end_of_week` do Rails | Rails garante segunda-feira como início (padrão do projeto) |
| Agrupamento de artes por data | Loop com hash manual | `group_by(&:scheduled_on)` | Idioma Ruby padrão, já validado nas fases anteriores |
| Eager loading de clientes | Carregar `arte.client` em loop | `.includes(:client)` na query | Previne N+1 — obrigatório com múltiplos clientes |

---

## Common Pitfalls

### Pitfall 1: `current_page?` no sidebar com `"#"`

**O que dá errado:** O helper `current_page?` em `_sidebar.html.erb` é chamado para cada
`nav_item`. Se `path: "#"` estiver presente quando a rota ainda não existe, o helper não falha
— mas se a rota for adicionada antes do sidebar ser atualizado, `current_page?` nunca retorna
`true` para o link do calendário.

**Por que acontece:** O sidebar é alterado JUNTO com a rota — ambos na mesma wave.

**Como evitar:** Na task de wiring do sidebar, alterar path e registrar rota na mesma
wave/commit. Não separar em waves diferentes.

**Sinal de alerta:** Link do calendário não fica com `bg-white/20` (estado ativo) quando na
página do calendário.

### Pitfall 2: Grade mostrando dias fora do mês sem estilo

**O que dá errado:** O grid pode ter datas do mês anterior/próximo (preenchimento da semana).
Sem distinguir visualmente, parece que artes estão no mês errado.

**Por que acontece:** `beginning_of_week` pode cair no mês anterior (ex: 1 de julho é
domingo → grid começa na segunda 29 de junho).

**Como evitar:** Usar `is_current_month = date.month == current_month.month` para aplicar
`bg-gray-50` nas células fora do mês e `text-gray-300` no número do dia. Exato padrão do
`_month_calendar.html.erb` existente. [VERIFIED: codebase]

### Pitfall 3: Tailwind não purga classes dinâmicas

**O que dá errado:** Classes como `bg-[#F0FDF4]` geradas dinamicamente pelo helper
`client_color` são purgadas pelo Tailwind em produção se o scanner não encontrar a string
literal no código.

**Por que acontece:** Tailwind v3+ usa JIT que escaneia arquivos por strings de classe; se a
classe é montada via concatenação em Ruby, não é detectada.

**Como evitar:** O helper DEVE retornar as strings completas como literais, não concatenadas:
```ruby
# CORRETO: string literal completa
{ bg: "bg-[#F0FDF4]", text: "text-[#14A958]" }

# ERRADO: concatenação que Tailwind não detecta
{ bg: "bg-[#{color_hex}]" }  # nunca fazer isso
```
[VERIFIED: padrão do design system do projeto — todas as cores hex são literais]

### Pitfall 4: Ordenação de chips não determinística

**O que dá errado:** Sem `order(:id)` na query, PostgreSQL pode retornar artes em ordens
diferentes entre requests. O chip de overflow `+N` pode mostrar clientes diferentes a cada
refresh.

**Por que acontece:** PostgreSQL não garante ordem sem `ORDER BY` explícito.

**Como evitar:** Sempre incluir `.order(:id)` na query do controller. [VERIFIED: codebase — approvals_controller usa order explícito]

### Pitfall 5: Turbo Frame não atualiza quando seta está dentro do frame

**O que dá errado:** Se a seta de navegação for renderizada DENTRO do `<turbo-frame>`, ao
clicar o Turbo procura um frame com o mesmo id na resposta. Se o frame não wrapar as setas na
resposta parcial, a navegação funciona mas as setas desaparecem do DOM.

**Como evitar:** Manter setas FORA do turbo-frame. Já documentado em D-02 e confirmado pelo
padrão das fases 6 e 13. [VERIFIED: codebase]

---

## Code Examples

### Iniciais do cliente (2 chars)

```ruby
# Source: CONTEXT.md ## Specific Ideas [VERIFIED: CONTEXT.md]
# "Ilha Criativa" → "IC", "Mercado Verde" → "MV", "Ana" → "AN" (first 2 chars do primeiro word)
client.name.split.map(&:first).first(2).join.upcase
```

**Nota:** Se o cliente tiver nome de uma palavra (ex: "Zara"), `split` retorna `["Zara"]`,
`.map(&:first)` retorna `["Z"]`, `.first(2)` retorna `["Z"]`, `.join` = `"Z"`. Comportamento
correto — 1 char é aceitável nesse caso-limite.

### Rota a adicionar em config/routes.rb

```ruby
# Source: routes.rb análise + D-02 CONTEXT.md [VERIFIED: codebase]
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
  resources :calendar,  only: [ :index ]   # ADICIONAR
end
```

### Wiring do sidebar

```erb
<%# Source: app/views/admin/shared/_sidebar.html.erb linha 16 [VERIFIED: codebase] %>
<%# ANTES: %>
{ label: "Calendário", path: "#" },
<%# DEPOIS: %>
{ label: "Calendário", path: admin_calendar_index_path },
```

---

## State of the Art

| Abordagem antiga | Abordagem atual | Mudança | Impacto |
|------------------|-----------------|---------|---------|
| Gems de calendário (simple_calendar) | Grade manual ERB + Tailwind | Projeto nunca usou gem de calendário — grade manual desde Phase 6 | Mais controle, zero dependência extra |
| Navegação com redirect completo | Turbo Frame parcial | Phase 6 estabeleceu o padrão | Navegação de mês sem reload |

**Deprecated/outdated:**
- Nada obsoleto identificado nesta fase.

---

## Environment Availability

| Dependência | Necessária em | Disponível | Versão | Fallback |
|-------------|---------------|------------|--------|----------|
| Rails I18n | Label do mês em pt-BR | ✓ | bundled | — |
| Turbo (importmap) | Navegação parcial | ✓ | bundled via importmap | — |
| PostgreSQL | Query de artes | ✓ | em uso pelo projeto | — |

**Missing dependencies with no fallback:** nenhuma.
**Missing dependencies with fallback:** nenhuma.

---

## Validation Architecture

### Test Framework

| Propriedade | Valor |
|-------------|-------|
| Framework | Minitest (Rails padrão) |
| Config file | `test/test_helper.rb` |
| Quick run command | `rails test test/controllers/admin/calendar_controller_test.rb` |
| Full suite command | `rails test` |

### Phase Requirements → Test Map

| Req ID | Comportamento | Tipo | Comando Automatizado | Arquivo existe? |
|--------|--------------|------|----------------------|-----------------|
| CADM-01 | GET /admin/calendar retorna 200 e sidebar tem link correto | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| CADM-01 | Unauthenticated redirect para login | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| CADM-02 | Artes de todos os clientes aparecem nas células corretas | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| CADM-03 | Chip contém iniciais do cliente no HTML | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| CADM-04 | Navegação com ?month= retorna mês correto | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| CADM-04 | Parâmetro month inválido não causa 500 | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| CADM-05 | Chip é link para admin_arte_path | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |
| D-04 | Máximo 3 chips visíveis + "+N" quando há mais | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ Wave 0 |

### Sampling Rate
- **Por commit de task:** `rails test test/controllers/admin/calendar_controller_test.rb`
- **Por wave merge:** `rails test`
- **Phase gate:** Suite completa verde antes de `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/controllers/admin/calendar_controller_test.rb` — cobre CADM-01 a CADM-05 e D-04

*(Nenhuma lacuna de infraestrutura de teste — Minitest, fixtures e SessionTestHelper já existem)*

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1` — seção obrigatória.

### Applicable ASVS Categories (ASVS Level 1)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim | `before_action :require_authentication` em `Admin::BaseController` — herdado automaticamente |
| V3 Session Management | sim | Gerenciado pelo `Admin::BaseController` e `sessions_controller` do Rails 8 auth generator |
| V4 Access Control | sim | Apenas usuários autenticados acessam `/admin/calendar` — mesmo mecanismo das outras páginas admin |
| V5 Input Validation | sim | `parse_month_param` com `rescue Date::Error` — previne 500 em param inválido |
| V6 Cryptography | não | Nenhuma operação criptográfica nesta fase |

### Known Threat Patterns

| Padrão | STRIDE | Mitigação Padrão |
|--------|--------|------------------|
| Acesso não autenticado a dados de todos os clientes | Elevação de Privilégio | `before_action :require_authentication` herdado — verificado funcionar em todas as pages admin [VERIFIED: codebase] |
| Parâmetro `?month=` malicioso causando 500 | Tampering | `rescue Date::Error` em `parse_month_param` — padrão já validado no client/home e coberto por teste |
| N+1 vazando dados de clientes via lentidão | Divulgação de Informação | `includes(:client)` evita N+1 — sem dados extras expostos |

**Nota de segurança:** Esta página é admin-only. Nenhum dado de cliente é exposto publicamente.
O `admin_arte_path(arte)` nos chips não usa tokens (é rota admin autenticada).
Nenhuma mutation (POST/PATCH/DELETE) ocorre nesta fase — apenas GET.

---

## Assumptions Log

| # | Afirmação | Seção | Risco se errada |
|---|-----------|-------|-----------------|
| A1 | `I18n.l(@current_month, format: "%B %Y")` retorna nome do mês em pt-BR conforme locale do projeto | Code Examples | Label do mês ficaria em inglês — ajustar para `.strftime` com meses hardcoded se locale não estiver configurado |

**Nota sobre A1:** O client/home_controller já usa `I18n.l` com o mesmo formato e o projeto
não tem evidência de locale pt-BR configurado no `config/application.rb`. Vale confirmar ou
usar `Date::MONTHNAMES` / strftime manual como fallback. Baixo risco — workaround é trivial.

---

## Open Questions

1. **Locale pt-BR para I18n.l**
   - O que sabemos: `client/home_controller` usa `I18n.l(@current_month, format: "%B %Y")`
   - O que é incerto: se `config/application.rb` tem `config.i18n.default_locale = :pt_BR` e se a gem `rails-i18n` está presente
   - Recomendação: verificar Gemfile e application.rb; se locale não estiver configurado, implementar strftime manual com array de nomes de meses em pt-BR (mesmo que o client/home use I18n.l funcionando, pode ser que locale esteja configurado e não apareça nos arquivos lidos)

---

## Sources

### Primary (HIGH confidence)
- `app/controllers/client/home_controller.rb` — lógica completa de calendário verificada no codebase
- `app/views/client/home/_month_calendar.html.erb` — grade 7 colunas verificada no codebase
- `app/views/admin/shared/_sidebar.html.erb` — linha 16 com `path: "#"` verificada
- `config/routes.rb` — estrutura de rotas admin verificada
- `app/helpers/application_helper.rb` — ponto de extensão verificado
- `app/controllers/admin/base_controller.rb` — `before_action :require_authentication` verificado
- `db/schema.rb` — confirmado: `scheduled_on date not null`, sem coluna `color` em `clients`
- `.planning/phases/14-calend-rio-admin/14-CONTEXT.md` — decisões bloqueadas verificadas

### Secondary (MEDIUM confidence)
- `app/views/admin/approvals/index.html.erb` — padrão Turbo Frame de filtros fora/dentro verificado
- `app/views/admin/dashboard/index.html.erb` — padrão original Phase 6 verificado
- `test/controllers/admin/approvals_controller_test.rb` — padrão de testes de integração admin

### Tertiary (LOW confidence)
- A1: Configuração de locale pt-BR — não verificada no codebase nesta sessão

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero dependências novas; todo stack verificado no codebase
- Architecture: HIGH — padrão exato replicado de fases 6, 9 e 13 verificadas
- Pitfalls: HIGH — derivados de análise do codebase existente, não de fontes externas
- Tests: HIGH — padrão de testes idêntico ao approvals_controller_test verificado

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stack estável; sem dependências externas)
