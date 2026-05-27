# Phase 6: Admin Feedback Panel — Research

**Researched:** 2026-05-26
**Domain:** Rails 8 / Hotwire / Turbo Frame — dashboard admin com filtros, migração de schema, formulário de resposta interna
**Confidence:** HIGH (código existente inspecionado, stack familiar ao projeto)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Ponto de entrada (PAIN-01)**
- D-01: Dashboard raiz do admin (`/admin`) substitui o stub. `Admin::DashboardController#index` carrega todas as artes com respostas. Zero rota nova.
- D-02: Por padrão, todas as artes aparecem com todos os 4 status + badge de status colorido.
- D-03: Uma linha por arte — exibe a última resposta/status atual. Link para `admin/artes/:id` para ver histórico. Sem duplicatas.
- D-04: Artes agrupadas por cliente — cada cliente tem seção com nome e artes ordenadas por `scheduled_on` decrescente.

**Filtros (PAIN-02, PAIN-03)**
- D-05: Filtros via Turbo Frame — `<turbo-frame id="dashboard-content">`. Form GET com `data-turbo-frame="dashboard-content"`. URL preserva `?client_id=&status=`. Rails 8 nativo, zero JS extra.
- D-06: Filtros em barra horizontal acima da lista — select de cliente + select de status em linha. Submit automático ou botão "Filtrar" — Claude decide com base no padrão existente.
- D-07: Filtro de status inclui todos os 4 status + "Todos".

**Resposta do admin (PAIN-05)**
- D-08: Resposta escrita na página `admin/artes/:id` (show), junto ao botão "Marcar como Revisada".
- D-09: Campo `admin_reply: text` na tabela `artes`. Uma resposta por arte — sobrescreve se revisado novamente. Migração simples.
- D-10: Resposta interna ao admin — cliente NÃO vê no portal.

**Histórico do cliente (CLIE-05)**
- D-11: Terceiro card adicionado ao `admin/clients/show.html.erb` existente — sem rota nova.
- D-12: Card exibe artes que receberam pelo menos uma ApprovalResponse, ordenadas por `scheduled_on` decrescente. Cada item: título, data, status badge, última resposta + comentário, link para `admin_arte_path`.

### Claude's Discretion

- Ordenação dentro de cada grupo de cliente no dashboard — `scheduled_on` desc ou `responded_at` da última resposta.
- Copywriting PT-BR dos labels de status nos filtros.
- Estilo exato do card de histórico — mesma estrutura dos cards existentes (`bg-white rounded-xl border border-gray-200 shadow-card p-6`).
- Controle de submit automático do filtro — `auto-submit` Stimulus genérico ou botão "Filtrar" manual.
- Marcação de artes como revisadas no dashboard: link para a arte ou botão direto na linha.

### Deferred Ideas (OUT OF SCOPE)

- Resposta do admin visível para o cliente — fora desta fase (D-10).
- Notificações por e-mail/WhatsApp — out of scope v1.
- Fila de trabalho com filtro default `?status=change_requested` — decidido como "todas as artes" (D-02).
- Exportar relatório PDF/CSV — v2 (ADM2-01).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PAIN-01 | Admin vê dashboard com todas as respostas de todos os clientes (artes aprovadas e com pedido de alteração) | `Admin::DashboardController#index` reescrito; `Arte.includes(:client, :approval_responses).order(...)` + `group_by(&:client)` |
| PAIN-02 | Admin pode filtrar o dashboard por cliente | Select `client_id` no form GET dentro do Turbo Frame |
| PAIN-03 | Admin pode filtrar o dashboard por status | Select `status` no form GET dentro do Turbo Frame |
| PAIN-04 | Admin pode marcar uma arte como "Revisada" após fazer as alterações | `mark_revised` já existe em `Admin::ArtesController` (Phase 5) — acessível via link na linha do dashboard |
| PAIN-05 | Admin pode responder ao comentário do cliente dentro do sistema | Campo `admin_reply` adicionado à tabela `artes`; formulário PATCH na show da arte |
| CLIE-05 | Admin pode ver o histórico de aprovações de um cliente específico | Terceiro card em `admin/clients/show.html.erb` com artes que têm `approval_responses` |

</phase_requirements>

---

## Summary

Esta fase adiciona o painel central de visibilidade do admin: um dashboard agrupado por cliente com filtros Turbo Frame, o campo de resposta interna `admin_reply` na arte, e o histórico de respostas na página do cliente. Todo o trabalho é incremental sobre código existente — nenhuma rota nova, nenhuma gem nova.

O projeto usa Rails 8.1.1 com Hotwire (turbo-rails + stimulus-rails) nativos. O padrão Turbo Frame para filtros GET já existe conceptualmente no projeto (a discussão do CONTEXT.md o descreve com precisão). A única mudança de schema é `add_column :artes, :admin_reply, :text`.

A decisão mais importante de implementação (Claude's Discretion D-06) é **usar botão "Filtrar" manual** ao invés de `auto-submit` Stimulus — o projeto tem `password_toggle_controller.js` como único Stimulus de lógica de formulário, e a adição de um `auto-submit` genérico representaria complexidade desnecessária para um MVP com volume baixo (10-30 clientes). Botão manual é mais previsível e não precisa de novo controller.

**Recomendação primária:** Implementar em 4 planos: (1) migração + model, (2) dashboard controller + view com Turbo Frame, (3) formulário `admin_reply` na show da arte, (4) card de histórico em clients/show + testes.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dashboard agrupado por cliente | API / Backend | Frontend Server (SSR) | Agrupamento com `group_by` em Ruby; view renderizada server-side |
| Filtros por cliente e status | Frontend Server (SSR) | — | Form GET + Turbo Frame — servidor filtra, retorna HTML parcial |
| Badge de status das artes | Frontend Server (SSR) | — | Partial existente `_arte_status_badge.html.erb` reutilizada |
| Campo `admin_reply` + formulário | API / Backend | Frontend Server (SSR) | Escrita via PATCH controller; textarea renderizada server-side |
| Histórico de respostas do cliente | API / Backend | Frontend Server (SSR) | Query `has_many :approval_responses` escopada por cliente; card server-side |
| Migração de schema | Database / Storage | — | `add_column :artes, :admin_reply, :text` via ActiveRecord migration |

---

## Standard Stack

### Core (já instalado no projeto)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| turbo-rails | bundled Rails 8 | Turbo Frame para filtros sem reload | Nativo Rails 8 — decisão D-05 |
| stimulus-rails | bundled Rails 8 | Nenhum controller novo necessário | Existente; auto-submit dispensado |
| tailwindcss-rails | v4 | Estilos — @theme sem config.js | Padrão do projeto desde Phase 1 |
| pagy | ~9.3 | Paginação (se necessária no dashboard) | Já instalado no Gemfile |

### Nenhum pacote novo necessário

Esta fase não instala nenhuma gem ou pacote npm adicional. Toda a funcionalidade usa:
- Rails 8 nativo (Turbo Frame, form helpers, ActiveRecord)
- Tailwind v4 (classes existentes)
- Partials e controllers já criados

**Installation:** N/A — nenhum pacote novo.

---

## Package Legitimacy Audit

> Não aplicável — esta fase não instala novos pacotes externos.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
GET /admin
      │
      ▼
Admin::DashboardController#index
      │
      ├─ params[:client_id] presente? → filtra por cliente
      ├─ params[:status] presente? → filtra por status
      │
      ├─ Arte.includes(:client, approval_responses: [])
      │         .where(filtros)
      │         .order("clients.name ASC, artes.scheduled_on DESC")
      │
      └─ group_by(&:client) → @artes_by_client (Hash)
              │
              ▼
      index.html.erb
              │
        ┌─────┴──────────────────┐
        │                        │
  [Barra de filtros]    [<turbo-frame id="dashboard-content">]
  form GET               │
  select#client_id       └─ para cada cliente:
  select#status               <h3>Nome do cliente</h3>
  btn "Filtrar"               tabela compacta de artes
                              - título, data, status badge
                              - link "Ver" → admin_arte_path
                              - link "Marcar Revisada" se change_requested?

PATCH /admin/artes/:id (update admin_reply)
      │
      ▼
Admin::ArtesController#update
      │
      ├─ @arte.update(admin_reply: params[:arte][:admin_reply])
      └─ redirect_to admin_arte_path, notice: "Resposta salva."

GET /admin/clients/:id
      │
      ▼
Admin::ClientsController#show
      │
      ├─ @artes_with_responses = @client.artes
      │         .joins(:approval_responses)
      │         .includes(:approval_responses)
      │         .distinct
      │         .order(scheduled_on: :desc)
      │
      └─ clients/show.html.erb
              │
              └─ [Terceiro card]
                   artes_with_responses.each do |arte|
                     - título, data, badge status
                     - última resposta (approved/change_requested) + comentário
                     - link → admin_arte_path(arte)
```

### Recommended Project Structure

Nenhuma mudança estrutural de pastas. Apenas modificações em arquivos existentes + nova migração:

```
db/migrate/
└── TIMESTAMP_add_admin_reply_to_artes.rb   ← NOVO

app/controllers/admin/
├── dashboard_controller.rb                  ← REESCREVER #index
├── artes_controller.rb                      ← Atualizar arte_params + update action
└── clients_controller.rb                    ← Atualizar #show com @artes_with_responses

app/models/
└── arte.rb                                  ← Sem mudança (campo via migração apenas)

app/views/admin/
├── dashboard/
│   └── index.html.erb                       ← REESCREVER completamente
├── artes/
│   └── show.html.erb                        ← ADICIONAR formulário admin_reply
└── clients/
    └── show.html.erb                        ← ADICIONAR terceiro card histórico

test/controllers/admin/
└── dashboard_controller_test.rb             ← NOVO
```

### Padrão 1: Turbo Frame com Filtros GET

**O que:** Form GET cujo submit atualiza apenas o conteúdo dentro do `<turbo-frame>`, preservando a URL com parâmetros.

**Quando usar:** Filtros de lista que devem ser bookmarkáveis e não precisam de JavaScript customizado.

**Exemplo:**
```erb
<%# Barra de filtros FORA do turbo-frame (não é substituída pelo Turbo) %>
<%= form_with url: admin_root_path, method: :get, data: { turbo_frame: "dashboard-content" } do |f| %>
  <%= f.select :client_id,
        [["Todos os clientes", ""]] + @clients.map { |c| [c.name, c.id] },
        { selected: params[:client_id] },
        class: "h-9 px-3 border border-gray-200 rounded-lg text-sm text-slate-700 bg-white" %>

  <%= f.select :status,
        [["Todos os status", ""]] + Arte.statuses.keys.map { |s| [t_status(s), s] },
        { selected: params[:status] },
        class: "h-9 px-3 border border-gray-200 rounded-lg text-sm text-slate-700 bg-white" %>

  <%= f.submit "Filtrar",
        class: "h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer" %>
<% end %>

<%# Conteúdo dinâmico DENTRO do turbo-frame %>
<turbo-frame id="dashboard-content">
  <% @artes_by_client.each do |client, artes| %>
    <div class="mb-6">
      <h3 class="text-sm font-semibold text-slate-700 mb-2"><%= client.name %></h3>
      <%# tabela de artes do cliente %>
    </div>
  <% end %>
</turbo-frame>
```

**Fonte:** [ASSUMED] — padrão Hotwire Turbo Frame para filtros GET; comportamento nativo documentado em hotwired.dev.

### Padrão 2: Agrupamento por Cliente no Controller

```ruby
# Admin::DashboardController#index
def index
  scope = Arte.includes(:client, :approval_responses)
              .joins(:client)
              .order("clients.name ASC, artes.scheduled_on DESC")

  scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
  scope = scope.where(status: params[:status]) if params[:status].present?

  @artes_by_client = scope.group_by(&:client)
  @clients = Client.order(:name)
end
```

**Nota:** `joins(:client)` é necessário para `ORDER BY clients.name`. O `includes(:client)` faz o eager loading; o `joins` adiciona o JOIN para ordenação. [VERIFIED: código análogo em Admin::ArtesController#index já usa `includes(:client)`]

### Padrão 3: Campo admin_reply — Formulário na Show

```erb
<%# Em admin/artes/show.html.erb — abaixo do bloco de ações existente %>
<div class="mt-6 bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl">
  <h3 class="text-sm font-semibold text-slate-900 border-b border-gray-100 pb-3 mb-4">
    Resposta interna ao comentário
  </h3>
  <%= form_with model: [:admin, @arte], method: :patch do |f| %>
    <%= f.text_area :admin_reply,
          value: @arte.admin_reply,
          rows: 4,
          placeholder: "Escreva uma nota interna sobre o pedido de alteração do cliente...",
          class: "block w-full px-3 py-2 border border-gray-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-[#0F7949]/20 focus:border-[#0F7949]" %>
    <div class="mt-3">
      <%= f.submit "Salvar resposta",
            class: "h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer" %>
    </div>
  <% end %>
</div>
```

**Importante:** `arte_params` em `Admin::ArtesController` precisa incluir `:admin_reply` no `permit(...)`. [VERIFIED: arte_params atual está em admin/artes_controller.rb linha 67]

### Anti-Patterns a Evitar

- **group_by sem includes:** Usar `Arte.all.group_by(&:client)` sem `includes(:client)` causa N+1 query por cliente (1 query por `arte.client`). Sempre usar `.includes(:client, :approval_responses)`.
- **Turbo Frame envolvendo o form de filtro:** O form de filtros deve estar FORA do `<turbo-frame>` — se ficar dentro, ao Turbo substituir o conteúdo, o form desaparece. Apenas o conteúdo dinâmico (lista de artes) fica dentro.
- **Arte.all sem escopo:** O DashboardController deve usar `Arte.includes(:client)` (não `Arte.all`) para manter o padrão de queries com eager loading já estabelecido no projeto.
- **Dois formulários PATCH aninhados:** O `admin_reply` deve ser um form separado do bloco de ações (Editar/Excluir/Marcar Revisada) para evitar conflito de parâmetros.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Filtros sem reload de página | JavaScript customizado de fetch/XHR | Turbo Frame nativo Rails 8 | Zero JS, URL preservada, funciona com botão Voltar |
| Badge de status das artes | Nova partial CSS inline | `client/shared/_arte_status_badge.html.erb` existente | Já tem as 4 cores corretas + variante `compact:` |
| Modal de confirmação | Implementação JS própria | `_confirm_modal.html.erb` + `modal_controller.js` existentes | Focus trap + Escape key já implementados |
| Agrupamento por cliente | Query SQL complexa com GROUP BY | `group_by(&:client)` em Ruby após `includes` | Mais legível; volume baixo (10-30 clientes) não justifica SQL GROUP BY |

**Key insight:** O projeto tem um conjunto de componentes UI reutilizáveis (badges, modals, copy buttons) que devem ser aproveitados para consistência visual. Criar duplicatas quebraria o padrão visual estabelecido.

---

## Runtime State Inventory

> Esta fase adiciona uma coluna nova (`admin_reply`) à tabela `artes` existente. Não é um rename/refactor — não há dados de runtime para migrar.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Coluna `admin_reply` não existe ainda em `artes` | Criar migração `add_column :artes, :admin_reply, :text` |
| Live service config | Nenhum — sem workflows externos | None |
| OS-registered state | Nenhum | None |
| Secrets/env vars | Nenhum novo | None |
| Build artifacts | Nenhum | None |

---

## Common Pitfalls

### Pitfall 1: Turbo Frame e o form de filtros no lugar errado

**O que dá errado:** O form de filtros fica DENTRO do `<turbo-frame id="dashboard-content">`. Quando o usuário submete o form, o Turbo substitui o conteúdo do frame pelo HTML retornado — que inclui o frame com o form novamente. Aparentemente funciona, mas gera inconsistência se a resposta parcial não incluir o frame (e.g., redirect inesperado).

**Por que acontece:** Confusão sobre qual parte da página o Turbo substitui.

**Como evitar:** Form de filtros fica FORA e ANTES da `<turbo-frame>`. O frame contém apenas a lista agrupada de artes.

**Sinais de alerta:** Form some após primeira filtragem; filtros resetam ao navegar.

### Pitfall 2: N+1 query no dashboard agrupado

**O que dá errado:** `Arte.all.group_by(&:client)` sem `includes` executa 1 query por arte para carregar o cliente associado. Com 100 artes = 101 queries.

**Por que acontece:** `group_by(&:client)` acessa `arte.client` em cada iteração sem eager loading.

**Como evitar:** Sempre `Arte.includes(:client, :approval_responses).joins(:client).order(...)`.

**Sinais de alerta:** Logs de development mostram `SELECT * FROM clients WHERE id = ?` repetido N vezes.

### Pitfall 3: `arte_params` sem `:admin_reply`

**O que dá errado:** O formulário de `admin_reply` submete `params[:arte][:admin_reply]`, mas se `arte_params` não incluir `:admin_reply` no `permit(...)`, o campo é silenciosamente ignorado. O `update` retorna sucesso mas o valor não é salvo.

**Por que acontece:** Strong Parameters filtram campos não permitidos sem erro.

**Como evitar:** Adicionar `:admin_reply` ao `permit(...)` em `arte_params`.

**Sinais de alerta:** `flash[:notice]` "Resposta salva" aparece, mas ao recarregar a arte o campo está vazio.

### Pitfall 4: Badge de status nas duas fontes

**O que dá errado:** Criar uma nova partial `admin/shared/_arte_status_badge.html.erb` com cores ligeiramente diferentes da `client/shared/_arte_status_badge.html.erb` existente, quebrando a consistência visual.

**Por que acontece:** O path `client/shared/` não é óbvio para o admin namespace.

**Como evitar:** Reutilizar `render "client/shared/arte_status_badge", arte: arte` diretamente na view do admin. Rails resolve o path completo.

### Pitfall 5: Histórico CLIE-05 sem `.distinct`

**O que dá errado:** `@client.artes.joins(:approval_responses)` retorna uma linha por ApprovalResponse. Uma arte com 3 respostas aparece 3 vezes na lista de histórico.

**Por que acontece:** `joins` faz INNER JOIN e multiplica as linhas.

**Como evitar:** Adicionar `.distinct` após `.joins(:approval_responses)`, ou usar `.where("EXISTS (SELECT 1 FROM approval_responses WHERE arte_id = artes.id)")`.

---

## Code Examples

### Migração para admin_reply

```ruby
# db/migrate/TIMESTAMP_add_admin_reply_to_artes.rb
class AddAdminReplyToArtes < ActiveRecord::Migration[8.1]
  def change
    add_column :artes, :admin_reply, :text
  end
end
```

### Dashboard Controller completo

```ruby
# app/controllers/admin/dashboard_controller.rb
class Admin::DashboardController < Admin::BaseController
  def index
    scope = Arte.includes(:client, :approval_responses)
                .joins(:client)
                .order("clients.name ASC, artes.scheduled_on DESC")

    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    scope = scope.where(status: params[:status])       if params[:status].present?

    @artes_by_client = scope.group_by(&:client)
    @clients = Client.order(:name)
  end
end
```

### Clients Controller — show com histórico

```ruby
# app/controllers/admin/clients_controller.rb (apenas a action show)
def show
  @artes_with_responses = @client.artes
                                  .joins(:approval_responses)
                                  .includes(:approval_responses)
                                  .distinct
                                  .order(scheduled_on: :desc)
end
```

### Labels PT-BR para status nos filtros

```erb
<%# Helper inline — ou extrair para helper se usado em mais de 1 lugar %>
<%
  status_labels = {
    "pending"          => "Pendente",
    "approved"         => "Aprovado",
    "change_requested" => "Pediu Alteração",
    "revised"          => "Revisado"
  }
  status_options = [["Todos os status", ""]] + Arte.statuses.keys.map { |s| [status_labels[s], s] }
%>
<%= f.select :status, status_options, { selected: params[:status] }, class: "..." %>
```

### Submit automático vs botão Filtrar — Recomendação

**Decisão (Claude's Discretion D-06):** Usar **botão "Filtrar" manual**.

Razões:
1. O projeto não tem um `auto-submit` Stimulus controller genérico — criá-lo aumentaria o scope.
2. O volume de dados é pequeno (10-30 clientes) — UX de auto-submit não é crítica.
3. Botão "Filtrar" é mais acessível para usuários que preenchem dois selects (evita submit ao trocar o primeiro).
4. Padrão mais simples de testar.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| remote: true (Rails UJS) | Turbo Frame nativo | Rails 7+ | Sem dependência de JS customizado para filtros parciais |
| respond_to :js blocks | Turbo Frame substitui HTML | Rails 7+ | Views mais simples, sem arquivos .js.erb |

**Deprecated/outdated:**
- `remote: true` em forms: substituído por Turbo. Não usar neste projeto.
- `data-remote="true"`: mesma situação.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Turbo Frame com form GET preserva `?client_id=&status=` na URL | Architecture Patterns | URL não bookmarkável — impacto baixo (admin só) |
| A2 | `render "client/shared/arte_status_badge", arte: arte` funciona a partir de views admin | Code Examples | Precisaria criar partial duplicada em admin/shared/ |
| A3 | `joins(:client)` permite `ORDER BY clients.name` sem erro de ambiguidade | Code Examples | Query SQL falha — precisaria de `.references(:clients)` |

**Nota sobre A3:** No Rails 8 com PostgreSQL, ao combinar `includes` + `joins` + `order` por coluna da tabela associada, às vezes é necessário adicionar `.references(:client)` junto ao `includes` para forçar LEFT OUTER JOIN. Se o planner detectar esse risco, a query pode usar `joins(:client).order(...)` sem `includes` e fazer eager loading separado, ou usar `.includes(:client).references(:client)`.

---

## Open Questions

1. **`references(:client)` necessário?**
   - O que sabemos: `Arte.includes(:client).joins(:client).order("clients.name")` pode lançar `ActiveRecord::EagerLoadPolymorphicError` ou ser silenciosamente ineficiente em algumas versões do Rails.
   - O que não está claro: O Rails 8.1 com PostgreSQL neste projeto já testa esse padrão?
   - Recomendação: Usar `.joins(:client).order("clients.name ASC, artes.scheduled_on DESC")` e carregar o eager loading de `approval_responses` separadamente via `.includes(:approval_responses)`. Evitar combinar `includes(:client)` + `joins(:client)`.

2. **Badge de arte admin — usar `client/shared/` ou criar `admin/shared/`?**
   - O que sabemos: A partial `client/shared/_arte_status_badge.html.erb` tem as cores corretas e o local `compact:`.
   - O que não está claro: Se `render "client/shared/arte_status_badge"` funciona corretamente de dentro do namespace `admin/`.
   - Recomendação: Testar no Wave 1. Se falhar, criar `admin/shared/_arte_status_badge.html.erb` copiando o conteúdo.

---

## Environment Availability

> Step 2.6: Esta fase é puramente código + migração de schema. Sem dependências externas novas.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | Migração `add_column` | ✓ | 192.168.3.203 (configurado) | — |
| Rails 8.1.1 | Toda a fase | ✓ | 8.1.1 (Gemfile) | — |
| turbo-rails | Turbo Frame filtros | ✓ | bundled Rails 8 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest (Rails built-in) |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/controllers/admin/dashboard_controller_test.rb` |
| Full suite command | `bin/rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAIN-01 | Dashboard index retorna 200 com todas as artes | controller | `bin/rails test test/controllers/admin/dashboard_controller_test.rb -n test_should_get_index` | ❌ Wave 0 |
| PAIN-02 | Filtro por `client_id` retorna apenas artes daquele cliente | controller | `bin/rails test test/controllers/admin/dashboard_controller_test.rb -n test_filter_by_client` | ❌ Wave 0 |
| PAIN-03 | Filtro por `status` retorna apenas artes com aquele status | controller | `bin/rails test test/controllers/admin/dashboard_controller_test.rb -n test_filter_by_status` | ❌ Wave 0 |
| PAIN-04 | Link "Marcar Revisada" acessível no dashboard via `admin_arte_path` | controller | Existente em `artes_controller_test.rb` (`mark_revised_muda_status`) | ✅ |
| PAIN-05 | PATCH com `admin_reply` persiste o campo | controller | `bin/rails test test/controllers/admin/artes_controller_test.rb -n test_update_admin_reply` | ❌ Wave 0 |
| CLIE-05 | Show do cliente inclui artes com respostas | controller | `bin/rails test test/controllers/admin/clients_controller_test.rb -n test_show_inclui_historico` | ❌ Wave 0 |

### Sampling Rate
- **Por task commit:** `bin/rails test test/controllers/admin/`
- **Por wave merge:** `bin/rails test`
- **Phase gate:** Full suite green antes do `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/controllers/admin/dashboard_controller_test.rb` — cobre PAIN-01, PAIN-02, PAIN-03
- [ ] Adicionar `test_update_admin_reply` em `test/controllers/admin/artes_controller_test.rb` — cobre PAIN-05
- [ ] Adicionar `test_show_inclui_historico` em `test/controllers/admin/clients_controller_test.rb` — cobre CLIE-05

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Admin::BaseController before_action autenticação já existente |
| V3 Session Management | yes | Sessions já implementadas (Rails 8 auth generator, Phase 1) |
| V4 Access Control | yes | Namespace `admin` — todas as rotas protegidas por `before_action :require_authentication` |
| V5 Input Validation | yes | Strong Parameters (`admin_reply` via `arte_params`) |
| V6 Cryptography | no | N/A para esta fase |

### Known Threat Patterns for Rails Admin Dashboard

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Acesso não autenticado ao dashboard | Spoofing | `before_action :require_authentication` em Admin::BaseController já cobre |
| Cross-client data leak (admin vê dados de outro cliente via params) | Information Disclosure | Dashboard mostra TODOS os clientes — por design (admin). Filtro por `client_id` não precisa ser escopado; admin tem acesso total. |
| XSS via `admin_reply` exibido na view | Tampering | Rails escapa HTML por padrão em `<%= %>`. Não usar `raw()` com `admin_reply`. |
| Mass assignment em `admin_reply` | Tampering | Strong Parameters — apenas permitir `admin_reply` explicitamente em `arte_params`. |
| CSRF em form PATCH de `admin_reply` | Tampering | `csrf_meta_tags` + `form_with` — Rails protege por padrão. |

**Nota:** O campo `admin_reply` é INTERNO ao admin — o cliente não vê (D-10). Não há risco de information disclosure do admin para o cliente nesta fase.

---

## Sources

### Primary (HIGH confidence)

- Codebase inspecionada diretamente:
  - `app/controllers/admin/artes_controller.rb` — padrão de `includes`, `arte_params`, `mark_revised`
  - `app/controllers/admin/clients_controller.rb` — padrão de `set_client`, estrutura show
  - `app/controllers/admin/dashboard_controller.rb` — stub atual a ser substituído
  - `app/models/arte.rb` — enums, associations, validações
  - `app/models/approval_response.rb` — enum `decision`, `responded_at`
  - `db/schema.rb` — estrutura atual (sem `admin_reply`)
  - `app/views/admin/artes/show.html.erb` — bloco de ações existente
  - `app/views/admin/clients/show.html.erb` — estrutura dos dois cards existentes
  - `app/views/admin/clients/_confirm_modal.html.erb` — padrão de modal
  - `app/views/client/shared/_arte_status_badge.html.erb` — badge de status com 4 cores
  - `config/routes.rb` — namespace admin, rotas existentes
  - `test/controllers/admin/artes_controller_test.rb` — padrão de teste + `sign_in_as`
  - `test/test_helpers/session_test_helper.rb` — helper de autenticação em testes

### Secondary (MEDIUM confidence)

- `.planning/phases/06-admin-feedback-panel/06-CONTEXT.md` — decisões do usuário, referências canônicas, padrões estabelecidos

### Tertiary (LOW confidence)

- [ASSUMED] Comportamento Turbo Frame com form GET — baseado em conhecimento de treinamento sobre hotwired.dev; não verificado via Context7 (ctx7 não disponível no ambiente).

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — código existente inspecionado; nenhum pacote novo
- Architecture: HIGH — controllers, models e views existentes lidos diretamente
- Pitfalls: HIGH — baseados em código real do projeto (N+1 patterns, strong params)
- Turbo Frame behavior: MEDIUM — [ASSUMED] baseado em treinamento; padrão é bem estabelecido

**Research date:** 2026-05-26
**Valid until:** 2026-06-26 (stack estável; Rails 8.1 sem breaking changes esperados)
