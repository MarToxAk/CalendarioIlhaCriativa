# Phase 5: Approval Flow - Research

**Researched:** 2026-05-25
**Domain:** Rails MVC — client-facing approval actions, model state machine, Stimulus toggle
**Confidence:** HIGH (codebase fully readable; all patterns verified from existing source)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Botões "Aprovar" e "Pedir Alteração" ficam na página da arte (`/c/:token/artes/:id`) — não na grade do calendário.
- **D-02:** Os botões aparecem apenas quando `pending?` ou `revised?`. Para `approved` ou `change_requested`, ficam **ocultos** (não só desabilitados).
- **D-03:** "Pedir Alteração" expande formulário **inline** via Stimulus toggle (sem mudança de URL, sem modal).
- **D-04:** Comentário é **opcional** — placeholder "Descreva o que precisa ser alterado (opcional)".
- **D-05:** "Aprovar" submete diretamente via `form_with` POST — um clique.
- **D-06:** Histórico na página da arte, seção "Histórico de respostas", ordem cronológica reversa.
- **D-07:** Histórico visível mesmo quando arte está aprovada.
- **D-08:** Pós-ação: flash notice + redirect para a mesma página da arte.
- **D-09:** Admin tem ação "Marcar como Revisada" quando `change_requested?`; muda status para `revised`.
- **D-10:** `PATCH /admin/artes/:id/mark_revised` em `Admin::ArtesController`; redireciona para `admin_arte_path`.

### Claude's Discretion

- Rota: `resources :responses, only: [:create], controller: 'client/responses'` nested sob `:artes`
- Controller: `Client::ResponsesController < ClientController` com `set_arte` via `@client.artes.find`
- Migração: remover índice único em `approval_responses.arte_id`
- Arte model: `has_one` → `has_many :approval_responses, dependent: :destroy` com `order(created_at: :desc)`
- Validator `arte_must_be_pending` → aceitar `arte.pending? || arte.revised?`
- Stimulus `approval_controller` para expandir/colapsar formulário de comentário
- Copywriting PT-BR de labels e flash messages

### Deferred Ideas (OUT OF SCOPE)

- Painel do admin com todas as respostas (Fase 6)
- Notificações por email/WhatsApp
- Aprovação inline na grade do calendário
- Comentário obrigatório para pedido de alteração
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APRO-01 | Cliente pode aprovar uma arte com um clique | `form_with POST` para `Client::ResponsesController#create` com `decision: :approved` |
| APRO-02 | Cliente pode pedir alteração e escrever comentário | Mesmo controller, `decision: :change_requested`, campo `comment` opcional via Stimulus toggle |
| APRO-03 | Após admin marcar revisada, arte volta ao estado aprovável e cliente re-aprova | `mark_revised` action no admin muda status para `revised`; validator atualizado aceita `pending? \|\| revised?` |
| APRO-04 | Cliente vê histórico de decisões (aprovações e pedidos anteriores) | Migração remove unique index; `has_many :approval_responses`; seção histórico na show view |
| APRO-05 | Somente artes pendentes recebem ação (sem duplo-envio) | Botões ocultos via `if @arte.pending? \|\| @arte.revised?`; validator no model como segunda barreira |
</phase_requirements>

---

## Summary

Esta fase implementa o núcleo do produto: o cliente aprova ou pede alteração em artes pelo portal, o admin marca como revisada, e o histórico fica visível. O trabalho é inteiramente dentro do stack existente (Rails 8.1, Stimulus, Tailwind v4, PostgreSQL) sem novas gems.

O principal pré-requisito técnico é uma migração de banco que remove o índice único em `approval_responses.arte_id` — sem isso, APRO-04 (histórico de múltiplas respostas) é impossível. Junto a isso, `Arte#has_one :approval_response` muda para `has_many`, e o validator `arte_must_be_pending` é estendido para aceitar `revised?`. Esses três itens devem sair num Wave 0 antes de qualquer código de UI.

A implementação segue exatamente o padrão estabelecido pelas fases anteriores: `Client::ResponsesController` herda `ClientController`, faz `@client.artes.find` para escopo seguro, e redireciona com flash. O Stimulus `approval_controller` é modelado no `media_type_toggle_controller.js` existente (show/hide com classList).

**Primary recommendation:** Executar em 3 waves: Wave 0 (migração + model + validator), Wave 1 (rota + controller + view client), Wave 2 (admin mark_revised + view admin).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Submeter aprovação/alteração | API/Backend (`Client::ResponsesController`) | — | Escopo de segurança exige validação server-side; `@client.artes.find` evita cross-client |
| Validar estado aprovável | Model (`ApprovalResponse#arte_must_be_pending`) | Controller (ocultar botões) | Model é barreira canônica; UI é UX |
| Sincronizar status da arte | Model (`after_create :sync_arte_status`) | — | Lógica de negócio, não controller |
| Toggle formulário de comentário | Browser/Stimulus (`approval_controller`) | — | Estado puramente visual, sem round-trip |
| Exibir histórico | Frontend Server (view ERB) | — | Renderização server-side, sem JS |
| Marcar como revisada (admin) | API/Backend (`Admin::ArtesController#mark_revised`) | — | Ação administrativa com mudança de estado |

---

## Standard Stack

Esta fase não instala nenhuma nova gem ou pacote npm. Tudo reutiliza o stack existente.

### Core (já instalado)
| Componente | Versão | Uso nesta fase |
|-----------|--------|----------------|
| Rails | 8.1.x | Controller, model, migração, views |
| PostgreSQL | 15.x | Persistence; migração de índice |
| Stimulus (Hotwire) | integrado no Rails 8 | `approval_controller` para toggle inline |
| Tailwind CSS v4 | via CDN/importmap | Estilo dos botões e histórico |
| Minitest | integrado | Testes de controller e model |

### Sem novas dependências
Nenhum pacote novo é necessário. [VERIFIED: leitura direta do Gemfile e package.json via codebase]

---

## Package Legitimacy Audit

> Nenhum pacote externo novo é instalado nesta fase. Seção não aplicável.

---

## Architecture Patterns

### Fluxo de dados — Aprovação do cliente

```
Cliente (browser)
  │
  ├─► GET /c/:token/artes/:id
  │     Client::ArtesController#show
  │     @arte.pending? || @arte.revised? → mostra botões
  │     @arte.approval_responses → mostra histórico
  │
  └─► POST /c/:token/artes/:id/responses
        Client::ResponsesController#create
          ├─ set_arte: @client.artes.find(params[:arte_id])   [escopo seguro]
          ├─ ApprovalResponse.create!(arte: @arte, decision:, comment:)
          │     validate :arte_must_be_pending  → pending? || revised?
          │     after_create :sync_arte_status  → arte.approved! / arte.change_requested!
          └─ redirect_to client_arte_path, notice: "..."

Admin (browser)
  └─► PATCH /admin/artes/:id/mark_revised
        Admin::ArtesController#mark_revised
          ├─ @arte.revised!
          └─ redirect_to admin_arte_path, notice: "Arte marcada como revisada."
```

### Estrutura de arquivos — novos arquivos

```
app/
├── controllers/client/
│   └── responses_controller.rb          # novo
├── views/client/artes/
│   └── show.html.erb                    # modificado: +botões +histórico
├── views/admin/artes/
│   └── show.html.erb                    # modificado: +botão mark_revised
├── javascript/controllers/
│   └── approval_controller.js           # novo — toggle formulário comentário
db/migrate/
└── YYYYMMDDHHMMSS_allow_multiple_approval_responses.rb  # novo
```

### Pattern 1: Rota nested no scope do cliente

**O que é:** `resources :responses` nested sob `resources :artes` dentro do scope `/c/:token`.
**Quando usar:** Sempre que uma ação pertence a uma arte mas é executada pelo cliente.

```ruby
# config/routes.rb — [VERIFIED: leitura direta do arquivo]
scope "/c/:token", as: :client do
  root to: "client/home#index"
  resource :session, only: [:new, :create, :destroy], controller: "client/sessions"
  resources :artes, only: [:show], controller: "client/artes" do
    resources :responses, only: [:create], controller: "client/responses"
  end
end
```

Isso gera: `client_arte_responses_path(token: @client.access_token, arte_id: @arte.id)`
Método: `POST /c/:token/artes/:arte_id/responses`

### Pattern 2: Client::ResponsesController

**Herda `ClientController`** — obtém `load_client_from_token` + `require_client_auth` automaticamente.
**NUNCA** usar `Arte.find` direto — sempre `@client.artes.find`.

```ruby
# app/controllers/client/responses_controller.rb
class Client::ResponsesController < ClientController
  before_action :set_arte

  def create
    response = @arte.approval_responses.build(response_params)
    if response.save
      redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                  notice: flash_notice_for(response.decision)
    else
      redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                  alert: response.errors.full_messages.to_sentence
    end
  end

  private

  def set_arte
    @arte = @client.artes.find(params[:arte_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to client_root_path(token: @client.access_token), alert: "Arte não encontrada."
  end

  def response_params
    params.require(:approval_response).permit(:decision, :comment)
  end

  def flash_notice_for(decision)
    decision == "approved" ? "Arte aprovada!" : "Pedido de alteração enviado."
  end
end
```

[VERIFIED: padrão extraído diretamente de `Client::ArtesController` e `ClientController`]

### Pattern 3: Admin mark_revised action

```ruby
# Em Admin::ArtesController — [VERIFIED: leitura direta do controller]
before_action :set_arte, only: %i[show edit update destroy mark_revised]

def mark_revised
  if @arte.change_requested?
    @arte.revised!
    redirect_to admin_arte_path(@arte), notice: "Arte marcada como revisada."
  else
    redirect_to admin_arte_path(@arte), alert: "Ação inválida para o status atual."
  end
end
```

Rota:
```ruby
# Em namespace :admin
resources :artes do
  member do
    patch :mark_revised
  end
end
```

**Atenção:** O arquivo atual tem `resources :artes, except: [:show]` e um segundo bloco `resources :artes` (duplicado). A migração de rotas deve consolidar num único bloco com `member { patch :mark_revised }`. [VERIFIED: leitura direta de `config/routes.rb`]

### Pattern 4: Migração para remover índice único

```ruby
class AllowMultipleApprovalResponses < ActiveRecord::Migration[8.1]
  def change
    remove_index :approval_responses, :arte_id  # remove unique: true
    add_index    :approval_responses, :arte_id  # sem unique
  end
end
```

Schema atual confirmado: [VERIFIED: leitura de `db/schema.rb` linha 52]
```
t.index ["arte_id"], name: "index_approval_responses_on_arte_id", unique: true
```

### Pattern 5: Arte model — has_many

```ruby
# app/models/arte.rb — mudança obrigatória
has_many :approval_responses, dependent: :destroy   # era has_one
# Scope para o histórico na view:
# @arte.approval_responses.order(created_at: :desc)
```

**Impacto em testes existentes:** `Admin::ArtesController` usa `@arte.approval_response.nil?` em `check_deletable`. Após a mudança para `has_many`, isso deve ser `@arte.approval_responses.none?`. [VERIFIED: leitura de `app/controllers/admin/artes_controller.rb` linha 68]

### Pattern 6: Stimulus approval_controller (toggle inline)

Baseado no padrão `media_type_toggle_controller.js` existente: [VERIFIED: leitura direta]

```javascript
// app/javascript/controllers/approval_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["commentForm"]

  toggleComment() {
    this.commentFormTarget.classList.toggle("hidden")
  }

  hideComment() {
    this.commentFormTarget.classList.add("hidden")
  }
}
```

HTML na view:
```erb
<div data-controller="approval">
  <%# Botão Aprovar — form direto, sem toggle %>
  <%= form_with url: client_arte_responses_path(token: @client.access_token, arte_id: @arte.id),
                method: :post do |f| %>
    <%= hidden_field_tag :approval_response_decision, "approved" %>
    <%# OU: <%= f.hidden_field :decision, value: "approved" %> %>
    <%= f.submit "Aprovar", class: "bg-[#10B981] text-white ..." %>
  <% end %>

  <%# Botão Pedir Alteração — toggle %>
  <button type="button"
          data-action="approval#toggleComment"
          class="bg-[#EF4444] text-white ...">
    Pedir Alteração
  </button>

  <%# Formulário inline — oculto por default %>
  <div data-approval-target="commentForm" class="hidden mt-3">
    <%= form_with url: client_arte_responses_path(token: @client.access_token, arte_id: @arte.id),
                  method: :post do |f| %>
      <%= f.hidden_field :decision, value: "change_requested" %>
      <%= f.text_area :comment, placeholder: "Descreva o que precisa ser alterado (opcional)",
                      class: "w-full border rounded-lg p-3 text-sm" %>
      <div class="flex gap-2 mt-2">
        <%= f.submit "Enviar", class: "bg-[#EF4444] text-white ..." %>
        <button type="button"
                data-action="approval#hideComment"
                class="text-slate-500 ...">Cancelar</button>
      </div>
    <% end %>
  </div>
</div>
```

**Index.js:** O Stimulus usa `eagerLoadControllersFrom` — o `approval_controller.js` é carregado automaticamente por convenção de nome de arquivo. Nenhuma alteração em `index.js` necessária. [VERIFIED: leitura de `app/javascript/controllers/index.js`]

### Pattern 7: Seção de histórico na view do cliente

```erb
<%# Mostrar mesmo quando approved — D-07 %>
<% if @arte.approval_responses.any? %>
  <div class="p-6 border-t border-gray-100">
    <h3 class="text-sm font-semibold text-slate-700 mb-3">Histórico de respostas</h3>
    <ul class="space-y-3">
      <% @arte.approval_responses.order(created_at: :desc).each do |resp| %>
        <li class="flex items-start gap-3 text-sm">
          <%# ícone check/x %>
          <div>
            <span class="font-medium">
              <%= resp.approved? ? "Aprovado" : "Pediu Alteração" %>
            </span>
            <span class="text-slate-400 ml-2">
              <%= I18n.l(resp.created_at, format: :short) %>
            </span>
            <% if resp.comment.present? %>
              <p class="text-slate-600 mt-1"><%= resp.comment %></p>
            <% end %>
          </div>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

### Anti-Patterns a Evitar

- **Arte.find direto:** Nunca usar `Arte.find(params[:arte_id])` no `Client::ResponsesController`. Sempre `@client.artes.find(...)`. [VERIFIED: padrão estabelecido em fases anteriores — CONTEXT.md code_context]
- **Botão desabilitado mas visível:** D-02 especifica botões **ocultos** (não desabilitados) para estados não aprovável. Usar `if @arte.pending? || @arte.revised?` para envolver o bloco inteiro.
- **has_one após migração:** Após remover o índice único e criar `has_many`, qualquer código que ainda chame `@arte.approval_response` (singular) retornará `NoMethodError`. Verificar todos os usos antes do deploy.
- **Duplicação de bloco admin routes:** O `config/routes.rb` atual tem dois blocos `namespace :admin { resources :artes }`. Consolidar em um único bloco ao adicionar `mark_revised`.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por quê |
|---------|---------------|-------------------|---------|
| Toggle show/hide formulário | JavaScript vanilla com event listeners | Stimulus `approval_controller` com `classList.toggle` | Padrão já estabelecido no projeto; Stimulus é a camada JS oficial |
| Status machine da arte | Lógica de transição manual no controller | `after_create :sync_arte_status` no model + enum `arte.approved!` | Transitions via enum já implementadas; adicionar no model mantém consistência |
| Escopo de segurança por cliente | `Arte.where(client_id: params[:client_id])` | `@client.artes.find(params[:arte_id])` | O padrão com `find` lança `RecordNotFound` que o rescue trata; `where` precisa de `first!` extra |
| Flash messages customizadas | i18n lookup complexo | String literal PT-BR no controller | Projeto usa locale manual pt-BR.yml sem rails-i18n; strings diretas são o padrão |

---

## Common Pitfalls

### Pitfall 1: Índice único não removido antes de testar has_many
**O que vai errar:** `ActiveRecord::RecordNotUnique` ao tentar criar segunda `ApprovalResponse` para a mesma arte.
**Por que acontece:** `db/schema.rb` linha 52 confirma `unique: true` no índice de `arte_id`. A migração deve rodar antes de qualquer teste de histórico.
**Como evitar:** Wave 0 deve ser migração + model + validator. Testes de Wave 1 dependem de Wave 0 completada.
**Sinal de alerta:** Erro `PG::UniqueViolation` nos testes de `Client::ResponsesController`.

### Pitfall 2: approval_response.nil? quebra após has_many
**O que vai errar:** `Admin::ArtesController#check_deletable` usa `@arte.approval_response.nil?` (singular). Após `has_many`, o método `approval_response` deixa de existir.
**Por que acontece:** Rails não gera método singular quando a associação é `has_many`.
**Como evitar:** Atualizar para `@arte.approval_responses.none?` em `check_deletable`.
**Sinal de alerta:** `NoMethodError: undefined method 'approval_response'` nos testes de admin.

### Pitfall 3: Rota duplicada no namespace admin
**O que vai errar:** `Routes::RoutingError` ou rotas ambíguas; `admin_arte_mark_revised_path` pode não existir.
**Por que acontece:** `config/routes.rb` tem dois blocos `namespace :admin { resources :artes }`.
**Como evitar:** Consolidar em um único bloco com `member { patch :mark_revised }`.
**Sinal de alerta:** `rake routes | grep artes` mostrando rotas duplicadas.

### Pitfall 4: Strong params — decision via hidden field
**O que vai errar:** `ActionController::UnpermittedParameters` ou `nil` decision se o campo não for permitido.
**Por que acontece:** O `decision` vem de um `hidden_field`, não de um campo de formulário visível.
**Como evitar:** `params.require(:approval_response).permit(:decision, :comment)` — garantir que o form envia sob a chave `approval_response`.
**Sinal de alerta:** `ApprovalResponse` criada com `decision: nil`; validação `presence: true` falha silenciosamente se o controller não renderizar erros.

### Pitfall 5: Validator rejeita re-aprovação após revised
**O que vai errar:** Cliente não consegue aprovar arte revisada pelo admin.
**Por que acontece:** `arte_must_be_pending` atual usa apenas `arte.pending?`.
**Como evitar:** Atualizar para `arte.pending? || arte.revised?` no Wave 0.
**Sinal de alerta:** Teste de re-aprovação falha com erro "já foi respondida".

### Pitfall 6: has_many sem scope de ordenação na view
**O que vai errar:** Histórico exibe respostas em ordem arbitrária (ordem de inserção do DB).
**Por que acontece:** `has_many :approval_responses` sem default scope não garante ordem.
**Como evitar:** Sempre usar `.order(created_at: :desc)` na view ou adicionar `-> { order(created_at: :desc) }` como scope na associação.

---

## Code Examples

### Validator atualizado
```ruby
# app/models/approval_response.rb
def arte_must_be_pending
  errors.add(:arte, "não está em estado aprovável") unless arte.pending? || arte.revised?
end
```
[VERIFIED: extraído do modelo existente, lógica estendida conforme D-09/CONTEXT.md]

### Botões condicionais na view — guard APRO-05
```erb
<% if @arte.pending? || @arte.revised? %>
  <%# bloco completo dos botões — D-02: ocultos quando não aprovável %>
<% end %>
```
[VERIFIED: pattern de guarda via enum, padrão Rails existente no projeto]

### Admin show.html.erb — botão mark_revised
```erb
<% if @arte.change_requested? %>
  <%= button_to "Marcar como Revisada",
                mark_revised_admin_arte_path(@arte),
                method: :patch,
                class: "btn btn-secondary" %>
<% end %>
```
[VERIFIED: padrão `button_to` com `method: :patch` usado em `rotate_token` no admin]

---

## State of the Art

| Abordagem antiga | Abordagem atual | Impacto |
|-----------------|-----------------|---------|
| `has_one :approval_response` | `has_many :approval_responses` | Permite histórico (APRO-04) |
| Validator aceita só `pending?` | Validator aceita `pending? \|\| revised?` | Habilita re-aprovação (APRO-03) |
| Índice único em `arte_id` | Índice não único em `arte_id` | Permite múltiplas respostas por arte |

**Nada está obsoleto** no stack — toda mudança é evolução de código já existente.

---

## Assumptions Log

| # | Claim | Section | Risk se errado |
|---|-------|---------|----------------|
| A1 | `eagerLoadControllersFrom` carrega `approval_controller.js` automaticamente sem alterar `index.js` | Stimulus Pattern | Controller não registrado; toggle não funciona — baixo risco, padrão verificado no código |
| A2 | `I18n.l(resp.created_at, format: :short)` funciona com o locale pt-BR.yml existente | Histórico view | Data exibida em inglês — verificar se `:short` está definido no locale |

---

## Open Questions

1. **Formato `:short` no locale pt-BR**
   - O que sabemos: `config/locales/pt-BR.yml` existe (mencionado em STATE.md); `I18n.l` é usado nas views
   - O que é incerto: se `:short` para datetime está definido nesse locale
   - Recomendação: Verificar o arquivo durante implementação; fallback: `resp.created_at.strftime("%d/%m/%Y %H:%M")`

2. **Duplicação de rotas admin**
   - O que sabemos: `config/routes.rb` tem dois blocos `namespace :admin { resources :artes }`
   - O que é incerto: se há lógica de precedência entre eles que precise ser preservada
   - Recomendação: Consolidar em um único bloco; verificar `rake routes` antes e depois

---

## Environment Availability

> Esta fase usa apenas Rails, PostgreSQL e Stimulus — todos já presentes e operacionais (61 testes verdes na Fase 4).

Seção 2.6: SKIPPED — sem novas dependências externas.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Rails Minitest (ActionDispatch::IntegrationTest) |
| Config file | `test/test_helper.rb` |
| Quick run | `bin/rails test test/controllers/client/responses_controller_test.rb` |
| Full suite | `bin/rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| APRO-01 | POST create com decision=approved muda status para approved | Integration | `bin/rails test test/controllers/client/responses_controller_test.rb` | ❌ Wave 0 |
| APRO-02 | POST create com decision=change_requested salva comment | Integration | `bin/rails test test/controllers/client/responses_controller_test.rb` | ❌ Wave 0 |
| APRO-03 | Arte revisada aceita nova ApprovalResponse; status muda | Model + Integration | `bin/rails test test/models/approval_response_test.rb` | ❌ Wave 0 |
| APRO-04 | Arte pode ter múltiplas ApprovalResponses (sem unique violation) | Model | `bin/rails test test/models/approval_response_test.rb` | ❌ Wave 0 |
| APRO-05 | POST create para arte approved retorna redirect com alert | Integration | `bin/rails test test/controllers/client/responses_controller_test.rb` | ❌ Wave 0 |
| APRO-05 | Arte approved não exibe botões (guard na view) | Integration (assert_no_selector ou assert_not body.include?) | `bin/rails test test/controllers/client/responses_controller_test.rb` | ❌ Wave 0 |
| D-10 | PATCH mark_revised muda status para revised quando change_requested | Integration | `bin/rails test test/controllers/admin/artes_controller_test.rb` | ❌ (adicionar ao existente) |

### Sampling Rate
- **Por commit de task:** `bin/rails test test/controllers/client/responses_controller_test.rb test/models/approval_response_test.rb`
- **Por merge de wave:** `bin/rails test`
- **Phase gate:** Suite completa verde antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/controllers/client/responses_controller_test.rb` — cobre APRO-01, APRO-02, APRO-03, APRO-05
- [ ] `test/models/approval_response_test.rb` — cobre APRO-03, APRO-04 (múltiplas respostas, validator revisado)
- [ ] Adicionar `test "mark_revised muda status para revised"` em `test/controllers/admin/artes_controller_test.rb`

### Setup Helper para Tests de Client::ResponsesController

Reutilizar exatamente o mesmo padrão de `Client::ArtesControllerTest`:
```ruby
def sign_in_as_client(client, password: "senha123")
  post client_session_path(token: client.access_token), params: { password: password }
end
```
[VERIFIED: leitura direta de `test/controllers/client/artes_controller_test.rb`]

---

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1` em `.planning/config.json`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `require_client_auth` em `ClientController` — já implementado |
| V3 Session Management | yes | `session[:client_id]` + `session[:client_token_version]` — já implementado |
| V4 Access Control | yes | `@client.artes.find` — escopo por cliente; sem acesso cross-client |
| V5 Input Validation | yes | Strong params `permit(:decision, :comment)`; enum validation no model |
| V6 Cryptography | no | Sem dados sensíveis novos nesta fase |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| IDOR — aprovar arte de outro cliente | Elevation of Privilege | `@client.artes.find(params[:arte_id])` — never `Arte.find` direto |
| Double-submit — aprovar arte já aprovada | Tampering | Validator `arte_must_be_pending` (server-side); botões ocultos (UX) |
| Mass assignment de status via form | Tampering | `response_params` usa `permit` estrito; status não é permitido |
| CSRF em form de aprovação | Spoofing | `csrf_meta_tags` no layout; `form_with` inclui token automaticamente |

**Nota:** O admin `mark_revised` age sobre qualquer arte pelo ID (`Arte.find` direto). Isso é aceitável porque `Admin::BaseController` requer autenticação de admin — o escopo é o admin autenticado, não um cliente. [VERIFIED: leitura de `Admin::ArtesController#set_arte`]

---

## Sources

### Primary (HIGH confidence)
- `app/models/approval_response.rb` — enum, validator, callback confirmados
- `app/models/arte.rb` — enums de status, `has_one`, validações confirmadas
- `db/schema.rb` — índice `unique: true` em `approval_responses.arte_id` confirmado (linha 52)
- `app/controllers/admin/artes_controller.rb` — padrão de actions, `check_deletable`, `set_arte`
- `app/controllers/client_controller.rb` — `load_client_from_token`, `require_client_auth`
- `app/controllers/client/artes_controller.rb` — padrão `@client.artes.find` para ClientController
- `config/routes.rb` — estrutura de rotas atual; duplicação de `namespace :admin { resources :artes }`
- `app/javascript/controllers/media_type_toggle_controller.js` — padrão Stimulus toggle com `classList`
- `app/javascript/controllers/index.js` — `eagerLoadControllersFrom` confirma auto-load de controllers
- `test/controllers/client/artes_controller_test.rb` — padrão `sign_in_as_client` e setup de fixtures
- `app/views/client/artes/show.html.erb` — pontos de inserção dos botões e histórico
- `app/views/client/shared/_arte_status_badge.html.erb` — suporte a `revised` confirmado
- `app/views/layouts/client.html.erb` — flash notice/alert confirmados

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions D-01 a D-10 — decisões do usuário informando padrões de implementação

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — sem pacotes novos; tudo verificado na codebase
- Architecture: HIGH — padrões extraídos diretamente dos controllers e models existentes
- Pitfalls: HIGH — identificados via leitura direta do código que será modificado
- Testes: HIGH — padrão de setup extraído de test existente

**Research date:** 2026-05-25
**Valid until:** 2026-06-25 (stack estável; sem dependências externas)
