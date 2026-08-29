# Phase 13: Página Aprovações - Research

**Researched:** 2026-06-04
**Domain:** Rails 8 / Pagy / Turbo Frames / Tailwind — página index admin com filtros e paginação
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Filtro de Status):** O filtro "por status" filtra pelo campo `decision` de `ApprovalResponse` — duas opções no dropdown: **Aprovado** (`approved`) e **Pediu Alteração** (`change_requested`). Não filtrar por `Arte.status`.
- **D-02 (Layout da Lista):** Lista **plana e cronológica** — uma linha por resposta, ordenada da mais recente para a mais antiga (`responded_at DESC`). Sem agrupamento por cliente ou por arte.
- **D-03 (Paginação):** Paginação com **pagy** (já no Gemfile), **25 itens por página**.

### Claude's Discretion

- Nome do controller/rota: usar `Admin::ApprovalsController` com `resources :approvals` → URL `/admin/approvals`.
- Padrão de filtros com Turbo Frame (já estabelecido no dashboard Phase 6) — replicar o mesmo padrão: form fora do turbo-frame, `data: { turbo_frame: "approvals-content" }`.
- Visual padrão de tabela: `thead` formatado com colunas em uppercase, `hover:bg-slate-50` nas linhas — padrão Phase 11.
- Coluna "status" em APRO-05 exibe o `decision` da response (não o status atual da arte).

### Deferred Ideas (OUT OF SCOPE)

Nenhuma — discussão manteve-se dentro do escopo da fase.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APRO-03 | Admin acessa a página "Aprovações" pelo link do sidebar (wired, não mais `#`) | Sidebar partial identificado: `app/views/admin/shared/_sidebar.html.erb` linha `path: "#"` → `admin_approvals_path`; rota ainda não existe em `routes.rb` |
| APRO-04 | Admin vê lista paginada de todas as respostas de aprovação, ordenada pela mais recente | `ApprovalResponse.order(responded_at: :desc)` + `pagy(scope, limit: 25)`; `Pagy::Backend` não está incluído em nenhum controller atual — precisa ser adicionado |
| APRO-05 | Cada item da lista exibe: cliente, arte, status, data da resposta e comentário (se houver) | Join `ApprovalResponse.joins(arte: :client).includes(arte: :client)` necessário; UI-SPEC define colunas, badge `_decision_badge` a criar |
| APRO-06 | Admin filtra a lista de aprovações por cliente e por status | Padrão de filtro do `DashboardController` a replicar; filtrar por `decision` (enum int), não por `Arte.status` |
| APRO-07 | Admin acessa a arte correspondente diretamente a partir de um item da lista | Rota `admin_arte_path(arte)` já existe; basta o link "Ver arte" em cada linha |
</phase_requirements>

---

## Summary

A Phase 13 cria a página `/admin/approvals` — uma listagem paginada e filtrável de todas as `ApprovalResponse` do sistema. É a peça mais simples do milestone v1.4: nenhum novo modelo, nenhuma migração, sem integração externa. Todo o trabalho é: (1) nova rota + controller, (2) query com join anti-N+1, (3) integração de pagy pela primeira vez no projeto, (4) views seguindo padrões visuais já existentes, (5) wiring do sidebar.

O padrão arquitetural já existe no projeto: `DashboardController` demonstra filtros com Turbo Frame (`form` fora do frame, `turbo-frame` envolvendo a tabela). O padrão visual de tabela existe em `artes/index.html.erb`. Ambos devem ser replicados, não reinventados.

O ponto de maior atenção técnico é a inicialização do Pagy: a gem está no Gemfile e instalada (`pagy-9.4.0`), mas `Pagy::Backend` e `Pagy::Frontend` **ainda não estão incluídos** em nenhum controller ou helper do projeto. O Wave 0 deve fazer isso antes de qualquer código de controller.

**Primary recommendation:** Criar `Admin::ApprovalsController` seguindo o template do `DashboardController`, adicionar `include Pagy::Backend` no `Admin::BaseController`, criar as views replicando `artes/index.html.erb`, e atualizar a rota + sidebar.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Listagem paginada de ApprovalResponses | API / Backend | — | Query, paginação e escopo de filtros pertencem ao controller |
| Filtros por cliente e decision | API / Backend | Browser (Turbo Frame) | Lógica de escopo no controller; Turbo Frame faz a atualização parcial no browser sem JS custom |
| Renderização da tabela e cards | Frontend Server (SSR) | — | ERB no servidor; sem JS customizado |
| Badge de decisão | Frontend Server (SSR) | — | Partial ERB/Tailwind, estado derivado do campo `decision` |
| Wiring do sidebar link | Frontend Server (SSR) | — | Apenas substituir `path: "#"` por helper de rota |
| Navegação para arte (`admin_arte_path`) | Frontend Server (SSR) | — | Rota já existente, só link HTML |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails 8.1 | 8.1.3 | Framework MVC | Já no projeto [VERIFIED: Gemfile] |
| Turbo Rails | bundled | Turbo Frames para atualização parcial | Já no projeto e padrão estabelecido na Phase 6 [VERIFIED: codebase] |
| Pagy | 9.4.0 | Paginação performática | Já instalado, Gemfile `~> 9.3` [VERIFIED: vendor/bundle] |
| Tailwind CSS | via tailwindcss-rails | Estilização | Já no projeto; tokens em `application.css` [VERIFIED: codebase] |
| PostgreSQL | via pg gem | Banco de dados | Já no projeto [VERIFIED: schema.rb] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Rails ActionDispatch::IntegrationTest | built-in | Testes de controller | Padrão já estabelecido nos testes existentes [VERIFIED: codebase] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pagy_nav (plain HTML) | pagy bootstrap extra | Bootstrap não está no projeto; pagy_nav plain gera HTML acessível sem dependência extra |
| Turbo Frame para filtros | Stimulus + fetch | Turbo Frame já é o padrão do projeto e não requer JS custom |

**Installation:** Nenhuma gem nova necessária. Pagy já está instalada.

---

## Package Legitimacy Audit

> Esta fase não instala nenhum pacote externo novo. Pagy já está presente no Gemfile e instalada em `vendor/bundle`. Auditoria de legitimidade não aplicável.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
GET /admin/approvals?client_id=X&decision=Y
         |
         v
[Admin::ApprovalsController#index]
    - Authenticate (before_action via Admin::BaseController)
    - Build scope: ApprovalResponse.joins(arte: :client)
                                   .includes(arte: :client)
                                   .order(responded_at: :desc)
    - Apply filter: .where(arte: { client_id: }) if client_id present
    - Apply filter: .where(decision: ) if decision present & valid
    - pagy(scope, limit: 25) → [@pagy, @approval_responses]
    - @clients = Client.order(:name)  [para popular dropdown]
         |
         v
[admin/approvals/index.html.erb]
    ├── form_with(url: admin_approvals_path, method: :get,
    │             data: { turbo_frame: "approvals-content" })
    │      ├── select :client_id
    │      ├── select :decision
    │      └── submit "Filtrar"
    └── <turbo-frame id="approvals-content">
           ├── table (desktop: hidden sm:block)
           │      ├── thead — CLIENTE / ARTE / DECISÃO / DATA / COMENTÁRIO / AÇÕES
           │      └── tbody — _approval_row.html.erb (each)
           │              └── _decision_badge.html.erb
           ├── cards (mobile: block sm:hidden)
           │      └── link_to admin_arte_path(arte) (cada card)
           ├── pagy_nav(@pagy) — dentro do turbo-frame
           └── empty state (se @approval_responses.empty?)

[admin/shared/_sidebar.html.erb]
    - "Aprovações" path: "#" → admin_approvals_path
```

### Recommended Project Structure

```
app/
├── controllers/
│   └── admin/
│       └── approvals_controller.rb   # novo
├── views/
│   └── admin/
│       ├── approvals/
│       │   ├── index.html.erb         # novo
│       │   ├── _approval_row.html.erb # novo (linha de tabela desktop)
│       │   └── _decision_badge.html.erb # novo (badge approved/change_requested)
│       └── shared/
│           └── _sidebar.html.erb      # modificar: path "#" → admin_approvals_path
config/
└── routes.rb                          # modificar: adicionar resources :approvals
```

### Pattern 1: Filtros com Turbo Frame (padrão Phase 6)

**What:** Form de filtro fora do turbo-frame submete via GET; o conteúdo dinâmico fica dentro do frame com id correspondente. O Turbo substitui apenas o frame, sem recarregar sidebar ou filtros.

**When to use:** Toda listagem admin que precisa de filtros sem page reload.

**Example:**
```erb
<%# Source: app/views/admin/dashboard/index.html.erb — padrão estabelecido %>
<%= form_with url: admin_approvals_path, method: :get,
              data: { turbo_frame: "approvals-content" },
              class: "flex items-center gap-3 mb-6" do |f| %>
  <%= f.select :client_id,
        [["Todos os clientes", ""]] + @clients.map { |c| [c.name, c.id] },
        { selected: params[:client_id] },
        class: "h-9 px-3 border border-gray-200 rounded-lg text-sm text-slate-700 bg-white" %>
  <%= f.select :decision,
        [["Todas as decisões", ""], ["Aprovado", "approved"], ["Pediu Alteração", "change_requested"]],
        { selected: params[:decision] },
        class: "h-9 px-3 border border-gray-200 rounded-lg text-sm text-slate-700 bg-white" %>
  <%= f.submit "Filtrar",
        class: "h-9 px-4 bg-[#0F7949] hover:bg-[#0a5c37] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer" %>
<% end %>

<turbo-frame id="approvals-content">
  <%# tabela + paginação aqui %>
</turbo-frame>
```

### Pattern 2: Pagy no Controller (primeira vez no projeto)

**What:** Pagy 9.x requer `include Pagy::Backend` no controller e `include Pagy::Frontend` no helper. Nenhum dos dois está presente no projeto atualmente.

**When to use:** Qualquer action que precise paginar uma coleção ActiveRecord.

**Example:**
```ruby
# Source: pagy 9.4.0 lib/pagy/backend.rb — VERIFIED no vendor/bundle
# Em Admin::BaseController (para herdar em todos os controllers admin):
include Pagy::Backend

# Em ApplicationHelper (para pagy_nav ficar disponível nas views):
include Pagy::Frontend

# No controller:
def index
  scope = ApprovalResponse.joins(arte: :client)
                           .includes(arte: :client)
                           .order(responded_at: :desc)
  scope = scope.where(artes: { client_id: params[:client_id] }) if params[:client_id].present?
  if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
    scope = scope.where(decision: params[:decision])
  end
  @pagy, @approval_responses = pagy(scope, limit: 25)
  @clients = Client.order(:name)
end
```

### Pattern 3: Query sem N+1

**What:** `joins` garante o filtro por cliente funcionar via SQL. `includes` carrega eager os dados associados para a view evitar N+1.

**When to use:** Sempre que a view precisar acessar `approval_response.arte.client.name`.

**Example:**
```ruby
# [VERIFIED: codebase — padrão de Admin::DashboardController]
ApprovalResponse
  .joins(arte: :client)       # necessário para filtrar por client_id no WHERE
  .includes(arte: :client)    # necessário para carregar eager e evitar N+1 na view
  .order(responded_at: :desc)
```

**Aviso:** `joins` + `includes` no mesmo campo pode gerar query redundante em alguns casos. Se performance for problema, usar `eager_load` em vez de `includes` quando `joins` já está presente. Para o volume atual do projeto isso é irrelevante.

### Pattern 4: Validação do Enum no Filtro

**What:** Antes de aplicar o filtro `decision`, validar que o valor recebido é uma chave válida do enum, igual ao padrão do DashboardController para `Arte.statuses`.

```ruby
# [VERIFIED: codebase — Admin::DashboardController linha 8]
if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
  scope = scope.where(decision: params[:decision])
end
```

### Anti-Patterns to Avoid

- **N+1 na view:** Não iterar `approval_response.arte.client.name` sem `includes(arte: :client)` no scope — cada linha faria 2 queries extras.
- **Filtrar por `Arte.status` em vez de `ApprovalResponse.decision`:** D-01 está locked — o filtro é no campo `decision` da response, não no status da arte.
- **Colocar `pagy_nav` fora do turbo-frame:** O nav de paginação deve ficar dentro do turbo-frame para ser atualizado junto com a tabela ao filtrar.
- **Usar `scope.where(decision: params[:decision])` sem validar:** Passar valor inválido de enum Rails lança `ArgumentError`. Sempre checar com `ApprovalResponse.decisions.key?(params[:decision])` primeiro.
- **Usar `truncate` do ActiveSupport sem `html_safe` depois:** `truncate` é helper de view (`ActionView::Helpers::TextHelper`) — disponível em ERB, não precisa de `html_safe`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paginação | Custom `LIMIT`/`OFFSET` + links manuais | `pagy(scope, limit: 25)` + `pagy_nav(@pagy)` | Pagy já está no projeto e lida com edge cases (página inexistente, overflow, etc.) |
| Truncar comentário | `comment[0..79]` manual | Helper `truncate(comment, length: 80)` do ActionView | Lida com nil, UTF-8 multi-byte, e adiciona `...` corretamente |
| Badge de decision | Classes inline no ERB | Partial `_decision_badge.html.erb` | Consistência visual e reutilizável; já é o padrão do projeto para `_status_badge` |

**Key insight:** O projeto já tem todos os padrões estabelecidos. O valor desta fase está em seguir os padrões, não em criar novos.

---

## Common Pitfalls

### Pitfall 1: Pagy::Backend e Pagy::Frontend não incluídos

**What goes wrong:** `NoMethodError: undefined method 'pagy' for #<Admin::ApprovalsController>` e `undefined method 'pagy_nav' for #<ActionView::Base>`.

**Why it happens:** Pagy 9.x não inclui os módulos automaticamente. É necessário incluir explicitamente.

**How to avoid:** Adicionar `include Pagy::Backend` em `Admin::BaseController` (ou `ApplicationController`) e `include Pagy::Frontend` em `ApplicationHelper` antes de qualquer uso.

**Warning signs:** Erros `NoMethodError` ao acessar `/admin/approvals`.

### Pitfall 2: Filtro por `client_id` sem qualificar a tabela no WHERE

**What goes wrong:** `ActiveRecord::StatementInvalid: column reference "client_id" is ambiguous` — tanto `artes` quanto `clients` têm colunas que podem conflitar.

**Why it happens:** Ao fazer `joins(arte: :client)`, o SQL tem múltiplas tabelas; `where(client_id: ...)` sem prefixo de tabela é ambíguo.

**How to avoid:** Usar `where(artes: { client_id: params[:client_id] })` — qualificando a tabela `artes`.

**Warning signs:** `ActiveRecord::StatementInvalid` com "ambiguous column".

### Pitfall 3: Turbo Frame não atualiza ao filtrar — link do sidebar ativa `#`

**What goes wrong:** Ao clicar "Aprovações" no sidebar, se o path ainda for `"#"`, o link não navega. Separadamente, se o `data-turbo-frame` no form não corresponder ao `id` do `<turbo-frame>`, o filtro recarrega a página inteira.

**Why it happens:** O id do frame no form (`data: { turbo_frame: "approvals-content" }`) deve ser idêntico ao `id` do `<turbo-frame>` na view.

**How to avoid:** Definir `id="approvals-content"` no turbo-frame e `data: { turbo_frame: "approvals-content" }` no form. Atualizar o sidebar na mesma wave que cria a rota.

**Warning signs:** Form de filtro recarrega a página inteira; link do sidebar fica em `#`.

### Pitfall 4: `responded_at` pode ser nil em registros antigos

**What goes wrong:** `NoMethodError: undefined method 'strftime' for nil` ao formatar a data na view.

**Why it happens:** O campo `responded_at` tem `before_create { self.responded_at ||= Time.current }`, então é populado na criação. Mas o schema define a coluna como nullable (`datetime` sem `null: false`). Registros criados antes do callback existir podem ter `nil`.

**How to avoid:** Usar `responded_at&.strftime("%d/%m/%Y") || "—"` na view para safe navigation.

**Warning signs:** `NoMethodError` em `nil:NilClass` ao renderizar datas.

### Pitfall 5: Página da paginação persistida nos filtros ao trocar de página

**What goes wrong:** Ao avançar para a página 2 com um filtro ativo, e depois selecionar outro filtro, a query mantém `page=2` com o novo filtro — possivelmente retornando página vazia.

**Why it happens:** O form de filtro não inclui `page` como parâmetro — ao submeter, `page` some da query. Mas ao usar links de página do `pagy_nav`, o `page` é adicionado à URL. O filtro, quando submetido de novo, reseta para página 1 automaticamente (porque não inclui `page`).

**How to avoid:** Este comportamento é correto por padrão — submeter o form de filtro sempre reseta para página 1. Não é necessário action extra.

---

## Code Examples

### Controller completo

```ruby
# Source: padrão Admin::DashboardController + Pagy::Backend docs (pagy-9.4.0/lib/pagy/backend.rb)
class Admin::ApprovalsController < Admin::BaseController
  def index
    scope = ApprovalResponse
              .joins(arte: :client)
              .includes(arte: :client)
              .order(responded_at: :desc)

    if params[:client_id].present?
      scope = scope.where(artes: { client_id: params[:client_id] })
    end

    if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
      scope = scope.where(decision: params[:decision])
    end

    @pagy, @approval_responses = pagy(scope, limit: 25)
    @clients = Client.order(:name)
  end
end
```

### Inclusão de Pagy no BaseController e Helper

```ruby
# Source: pagy-9.4.0/lib/pagy/backend.rb — VERIFIED no vendor/bundle
# Em app/controllers/admin/base_controller.rb:
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
  include Pagy::Backend   # ADICIONAR
end

# Em app/helpers/application_helper.rb:
module ApplicationHelper
  include Pagy::Frontend  # ADICIONAR
end
```

### Badge de decision (novo partial)

```erb
<%# app/views/admin/approvals/_decision_badge.html.erb %>
<%# Source: UI-SPEC Phase 13 — adaptado de app/views/admin/artes/_status_badge.html.erb %>
<%
  decision_config = {
    "approved"         => { label: "Aprovado",        classes: "bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20" },
    "change_requested" => { label: "Pediu Alteração",  classes: "bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20" }
  }
  config = decision_config[approval_response.decision.to_s] || { label: approval_response.decision.to_s, classes: "bg-gray-100 text-gray-700 border-gray-200" }
%>
<span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold border <%= config[:classes] %>">
  <span aria-hidden="true">●</span>
  <%= config[:label] %>
</span>
```

### Sidebar — alterar link

```erb
<%# app/views/admin/shared/_sidebar.html.erb — ANTES %>
{ label: "Aprovações", path: "#" }

<%# DEPOIS %>
{ label: "Aprovações", path: admin_approvals_path }
```

### Rota a adicionar

```ruby
# Source: config/routes.rb — padrão já existente no namespace admin
namespace :admin do
  root to: "dashboard#index"
  resources :clients, only: [ :index, :show, :new, :create, :edit, :update ] do
    member { post :rotate_token }
  end
  resources :artes do
    member { patch :mark_revised }
  end
  resources :approvals, only: [ :index ]   # ADICIONAR
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pagy 5.x: `pagy_array_get_items` para arrays | Pagy 9.x: `pagy_array` extra separado em `lib/pagy/extras/array.rb` | Pagy 6+ | Não afeta esta fase — só paginando ActiveRecord |
| Pagy nav HTML customizado | `pagy_nav` built-in retorna HTML acessível com `aria-current="page"` | Pagy 8+ | Usar `pagy_nav` diretamente, sem override |

**Deprecated/outdated:**
- `will_paginate` e `kaminari`: alternativas mais antigas — projeto já escolheu pagy, não mudar.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `pagy_nav(@pagy)` dentro do turbo-frame funciona sem configuração extra de resposta Turbo | Common Pitfalls / Code Examples | Baixo — pagy_nav gera HTML puro, Turbo substitui HTML; sem incompatibilidade conhecida |
| A2 | `include Pagy::Frontend` em `ApplicationHelper` disponibiliza `pagy_nav` em views admin | Standard Stack | Médio — verificar se o helper admin tem sua própria cadeia de include; se não funcionar, incluir em `Admin::ApprovalsHelper` |

**Se A1 ou A2 forem incorretos:** O planner deve incluir um passo de verificação após o Wave 0 antes de avançar para a view.

---

## Open Questions

1. **Pagy CSS nativo vs. sem estilo**
   - What we know: `pagy_nav` gera `<nav class="pagy nav">` com links e `<a class="current">`. O projeto não tem CSS para `.pagy.nav` definido.
   - What's unclear: O nav de paginação vai aparecer sem estilo ou invisível na primeira renderização.
   - Recommendation: No Wave 0 ou Wave de views, adicionar estilo inline via Tailwind ao wrapper do `pagy_nav`, ou envolver em `<div class="flex justify-center gap-1 mt-4">` e estilizar os `<a>` via CSS global. Alternativa: usar `pagy_nav` com `anchor_string:` para injetar classes Tailwind nos links.

---

## Environment Availability

> Esta fase é puramente código/config Rails — sem dependências de ferramentas externas além do ambiente Rails já funcional.

Step 2.6: SKIPPED (sem dependências externas além do stack Rails já verificado em produção).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Rails built-in Minitest + ActionDispatch::IntegrationTest |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/controllers/admin/approvals_controller_test.rb` |
| Full suite command | `bin/rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| APRO-03 | GET `/admin/approvals` retorna 200 e renderiza a página | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_should_get_index` | ❌ Wave 0 |
| APRO-04 | Lista ordenada por `responded_at DESC`, 25 itens por página | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_pagination` | ❌ Wave 0 |
| APRO-05 | Página exibe nome do cliente, título da arte, decision, data e comentário | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_displays_all_fields` | ❌ Wave 0 |
| APRO-06 | Filtro por `client_id` retorna apenas respostas daquele cliente | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_filter_by_client` | ❌ Wave 0 |
| APRO-06 | Filtro por `decision` retorna apenas respostas com aquele decision | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_filter_by_decision` | ❌ Wave 0 |
| APRO-06 | Filtro com `decision` inválido é ignorado (não lança erro) | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_filter_by_invalid_decision` | ❌ Wave 0 |
| APRO-07 | Página contém link para `admin_arte_path` de cada arte | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_contains_link_to_arte` | ❌ Wave 0 |
| APRO-03 | Sidebar link aponta para `admin_approvals_path` (não `#`) | integration (layout) | Verificação manual / smoke — ou assertion `assert_select "a[href='#{admin_approvals_path}']"` no test de index | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bin/rails test test/controllers/admin/approvals_controller_test.rb`
- **Per wave merge:** `bin/rails test`
- **Phase gate:** Full suite green antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/controllers/admin/approvals_controller_test.rb` — cobre APRO-03, APRO-04, APRO-05, APRO-06, APRO-07
- [ ] Fixtures necessárias: `test/fixtures/clients.yml`, `test/fixtures/artes.yml`, `test/fixtures/approval_responses.yml` — atualmente apenas `users.yml` e `files/` existem; os testes existentes criam dados via `setup` inline (não fixtures) — replicar o mesmo padrão no novo arquivo de test

---

## Security Domain

### Applicable ASVS Categories (Level 1)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim | `require_authentication` via `Admin::BaseController` — já implementado [VERIFIED: codebase] |
| V3 Session Management | não (herdado) | Gerenciado pelo Rails Authentication concern existente |
| V4 Access Control | sim (admin-only) | `Admin::BaseController` com `before_action :require_authentication` — todos os controllers admin herdam |
| V5 Input Validation | sim (filtros GET) | Validar `decision` contra `ApprovalResponse.decisions.key?()` antes de usar no WHERE; `client_id` passado diretamente para `where` é seguro pois ActiveRecord parametriza |
| V6 Cryptography | não | Página de leitura — sem dados sensíveis novos |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Acesso não autenticado a `/admin/approvals` | Spoofing | `require_authentication` before_action em `Admin::BaseController` [VERIFIED: codebase] |
| Injeção via parâmetro `decision` inválido (enum int overflow) | Tampering | `ApprovalResponse.decisions.key?(params[:decision])` antes do `where` — previne `ArgumentError` do enum Rails |
| Acesso a respostas de outros clientes via `client_id` manipulado | Information Disclosure | Não aplicável — admin tem acesso a todos os clientes por design. Não há multi-tenancy admin |
| Enumeração de `client_id` via parâmetro GET | Information Disclosure | Baixo risco — admin autenticado, acesso a todos clientes é intencional |

---

## Sources

### Primary (HIGH confidence)

- `app/controllers/admin/dashboard_controller.rb` — padrão de filtros com Turbo Frame e escopo de queries [VERIFIED: codebase]
- `app/views/admin/dashboard/index.html.erb` — padrão visual de form fora do frame + turbo-frame [VERIFIED: codebase]
- `app/views/admin/artes/index.html.erb` — padrão visual de tabela desktop + cards mobile [VERIFIED: codebase]
- `app/views/admin/shared/_sidebar.html.erb` — estrutura atual do sidebar, localização do link a corrigir [VERIFIED: codebase]
- `app/models/approval_response.rb` — enum `decision`, campos disponíveis [VERIFIED: codebase]
- `app/models/arte.rb` — associações `belongs_to :client`, `has_many :approval_responses` [VERIFIED: codebase]
- `db/schema.rb` — tabela `approval_responses`: campos `arte_id`, `decision`, `comment`, `responded_at` [VERIFIED: codebase]
- `config/routes.rb` — namespace admin existente, ausência de `resources :approvals` [VERIFIED: codebase]
- `app/controllers/admin/base_controller.rb` — ausência de `Pagy::Backend` [VERIFIED: codebase]
- `app/helpers/application_helper.rb` — ausência de `Pagy::Frontend` [VERIFIED: codebase]
- `vendor/bundle/ruby/3.3.0/gems/pagy-9.4.0` — gem instalada, versão 9.4.0, `pagy_nav` disponível em `lib/pagy/frontend.rb` [VERIFIED: vendor/bundle]
- `.planning/phases/13-p-gina-aprova-es/13-UI-SPEC.md` — contrato visual completo [VERIFIED: codebase]
- `.planning/phases/13-p-gina-aprova-es/13-CONTEXT.md` — decisões locked D-01, D-02, D-03 [VERIFIED: codebase]

### Secondary (MEDIUM confidence)

- Comportamento de `joins` + `includes` para evitar N+1 em Rails — padrão bem documentado da comunidade [ASSUMED]

### Tertiary (LOW confidence)

- Nenhuma finding LOW confidence nesta fase.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — tudo verificado no codebase e vendor/bundle
- Architecture: HIGH — padrões existentes identificados no codebase, sem especulação
- Pitfalls: HIGH — derivados de leitura direta do código existente e da gem instalada
- Security: HIGH — baseado em `Admin::BaseController` verificado e padrão enum Rails

**Research date:** 2026-06-04
**Valid until:** 2026-07-04 (stack estável; gem pagy 9.x sem breaking changes esperadas)
