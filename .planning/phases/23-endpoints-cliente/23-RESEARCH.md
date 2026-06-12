# Phase 23: Endpoints Cliente - Research

**Researched:** 2026-06-12
**Domain:** Rails API — endpoints REST de cliente (listagem, detalhe, submissão de aprovação)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** Lista retorna artes com status `pending` E `revised` — espelha `Client::HomeController` (`%w[pending revised]`).
**D-02:** Lista todas as artes pendentes do cliente (independente de mês), ordenadas por `scheduled_on` (mais próxima primeiro), paginadas com `page`/`per_page` (default 25, teto 100) via Pagy. `meta.pagination = { page, per_page, total_count, total_pages }`.
**D-03:** Detalhe expõe: `id`, `title`, `caption`, `scheduled_on`, `approval_deadline`, `platform`, `media_type`, `media_url` (absoluto resolvido), `status`. Sem campos internos do admin.
**D-04:** Detalhe inclui `approval_responses` do cliente (`id`, `decision`, `comment`, `responded_at`) e `admin_reply` da arte quando presente.
**D-05:** Rota aninhada: `POST /api/v1/client/artes/:arte_id/approval_responses`, payload flat `{ decision, comment }` (sem wrapper).
**D-06:** Comentário opcional para ambas as decisões — paridade com a web.
**D-07:** Lock de linha em transação: `@current_client.artes.lock.find(id)` dentro de `Arte.transaction`. Callbacks do `ApprovalResponse` permanecem ativos (broadcasts ActionCable ao admin).
**D-08:** Resposta 201 com a `approval_response` criada (`id`, `decision`, `comment`, `responded_at`) + status resultante da arte. Re-aprovação de arte `revised` é permitida.
**D-09:** Arte de outro cliente → 404 estruturado via escopo (`@current_client.artes.find` → `RecordNotFound` → `rescue_from`). Não 403.
**D-10:** Arte não-aprovável (já `approved` ou `change_requested`) → 422 via `arte_must_be_pending`. `decision` inválido → 400/422. Cliente inativo → 401 pela fundação.

### Claude's Discretion

- Serialização: reusa `ArteSerializer` do admin ou cria `Api::V1::Client::ArteSerializer` específico. Dado D-03/D-04 (campos diferentes + histórico do cliente), serializer dedicado é recomendado.
- Código HTTP exato para `decision` inválido (400 vs 422) e nomes exatos dos campos JSON.

### Deferred Ideas (OUT OF SCOPE)

- Filtro por mês na listagem do cliente (`?month=YYYY-MM`).
- Comentário obrigatório em "pediu alteração".
- Endpoint de artes já respondidas / histórico completo (aprovadas + change_requested).
- Rate limiting (Phase 24).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APICLI-01 | Cliente lista suas artes pendentes de aprovação | D-01/D-02: escopo `@current_client.artes.where(status: %w[pending revised]).order(:scheduled_on)` + Pagy; serializer cliente sem campos admin |
| APICLI-02 | Cliente vê detalhe de uma arte (imagem, data, legenda) | D-03/D-04: `includes(:approval_responses).find(id)` escopado ao cliente; serializer com `media_url` absoluto + `approval_responses` + `admin_reply` |
| APICLI-03 | Cliente submete resposta de aprovação (aprovado / pediu alteração + comentário) | D-05..D-10: `POST` aninhado flat, lock em transação, callbacks ativos, 201 + arte status resultante |

</phase_requirements>

---

## Summary

Esta fase entrega os três endpoints REST do app mobile do cliente, construídos inteiramente sobre a fundação das Phases 21 e 22. A auth e o `@current_client` já existem em `Api::V1::Client::BaseController` — esta fase só adiciona controllers de negócio, serializers PORO e rotas.

O padrão de implementação é idêntico ao da Phase 22 (Admin), com uma diferença-chave: o escopo é sempre `@current_client.artes` (nunca `Arte.find` global), o que garante automaticamente o isolamento cross-client (IDOR → 404). O `Api::V1::Client::BaseController` precisa receber os helpers de paginação e ActiveStorage que vivem hoje apenas no base do admin — a forma mais limpa é adicioná-los diretamente ao base do cliente (sem concern compartilhado, para não introduzir acoplamento prematuro).

A submissão de aprovação espelha quase exatamente o `Client::ResponsesController` do portal web, com uma diferença crítica: o payload é flat (sem wrapper `:approval_response`) e a resposta é JSON 201 com o status resultante da arte, em vez de redirect.

**Recomendação principal:** Criar `Api::V1::Client::ArteSerializer` dedicado (não reusar o do admin) — ele inclui `approval_responses` embutidas e `admin_reply`, e exclui `client_id` e `media_source_type` que não têm utilidade no app do cliente.

---

## Architectural Responsibility Map

| Capability | Tier Primário | Tier Secundário | Rationale |
|------------|--------------|-----------------|-----------|
| Auth / escopo de cliente | API (Client::BaseController) | — | JWT já decodificado, `@current_client` disponível como before_action herdado |
| Listagem paginada de artes pendentes | API (ArtesController#index) | Database (índice `status`) | Query + Pagy no servidor; app mobile só consome JSON |
| Detalhe com mídia e histórico | API (ArtesController#show) | Active Storage / DB | Resolve URL absoluta do ActiveStorage no servidor; inclui respostas |
| Submissão de aprovação + lock | API (ApprovalResponsesController#create) | DB (row lock em transação) | Lógica de negócio e lock ficam no servidor; app mobile envia payload flat |
| Broadcasts ao admin após aprovação | Model callback (ApprovalResponse) | ActionCable | Já implementado; ativado automaticamente quando `save!` é chamado |
| Serialização sem vazamento de dados | API (serializers PORO) | — | Campos filtrados no servidor antes de sair pela rede |

---

## Standard Stack

### Core

| Biblioteca | Versão | Propósito | Por que é padrão |
|------------|--------|-----------|-----------------|
| Rails (ActionController::API) | 8.1.3 (já instalado) | Base do controller | Já em uso; herança de `Api::V1::BaseController` |
| Pagy | já instalado | Paginação | Já em uso no admin base; mesmo contrato de `meta.pagination` |
| Active Storage | já instalado | Resolução de `media_url` | `arte.media_file.url` com `ActiveStorage::Current.url_options` setado |
| JwtService (`Api::JwtService`) | já implementado | Decode do token do cliente | `Api::V1::Client::BaseController#authenticate_client_jwt!` já usa |

[VERIFIED: codebase] — Todas as bibliotecas estão instaladas e em uso nas phases 21/22.

### Sem instalações novas

Esta fase não requer nenhum pacote novo. Todos os componentes necessários já estão no projeto.

### Alternatives Considered

| Em vez de | Poderia usar | Tradeoff |
|-----------|--------------|----------|
| Serializer PORO dedicado ao cliente | Reusar `Api::V1::Admin::ArteSerializer` | Admin serializer expõe `client_id`, `media_source_type`, `created_at`, `updated_at` — campos sem utilidade no app do cliente; não inclui `approval_responses` nem `admin_reply`. Separar é mais limpo e evita acoplamento |
| Adicionar helpers ao `Client::BaseController` | Extrair para Concern compartilhado | Concern introduz acoplamento entre namespaces admin/client; como os helpers são triviais (5 métodos), duplicação direta é mais simples e alinhada com o padrão da Phase 22 |

---

## Package Legitimacy Audit

Nenhum pacote novo a instalar nesta fase. Todos os componentes usados (Pagy, Active Storage, JwtService) já estão no projeto e foram auditados em phases anteriores.

**Pacotes removidos por slopcheck:** nenhum (não há novos pacotes)
**Pacotes suspeitos:** nenhum

---

## Architecture Patterns

### System Architecture Diagram

```
App Mobile (cliente autenticado com JWT Bearer)
         |
         v
[Authorization: Bearer <client_jwt>]
         |
         v
Api::V1::Client::BaseController
  authenticate_client_jwt!  ──────────> Api::JwtService.decode(token)
  @current_client (scope)               Client.find_by(id: claims[:sub])
         |                              (active? check incluso)
         |
    ┌────┴──────────────────────┐
    |                           |
    v                           v
ArtesController             ApprovalResponsesController
  #index                      #create
  #show                         |
    |                     Arte.transaction do
    |                       locked = @current_client.artes.lock.find(arte_id)
    |                       locked.approval_responses.build(params)
    |                       response.save!  ──> after_create :sync_arte_status
    |                     end               ──> after_create_commit :broadcasts_to_admin
    |                           |                (ActionCable ao admin — sem mudança)
    v                           v
Api::V1::Client::ArteSerializer    ApprovalResponseSerializer
  (campos cliente, sem admin info)    (id, decision, comment,
  + approval_responses embutidas       responded_at) + arte.status
  + admin_reply quando presente
         |                           |
         v                           v
    render_envelope(data:, meta: { pagination: })
         |
         v
    JSON { data, meta, errors }  ──> App Mobile
```

### Estrutura de arquivos a criar

```
app/
├── controllers/
│   └── api/v1/client/
│       ├── base_controller.rb          # MODIFICAR — adicionar Pagy, helpers, ActiveStorage
│       ├── artes_controller.rb         # CRIAR
│       └── approval_responses_controller.rb  # CRIAR
├── serializers/
│   └── api/v1/
│       ├── admin/                      # já existe (Phase 22)
│       └── client/
│           ├── arte_serializer.rb      # CRIAR
│           └── approval_response_serializer.rb  # CRIAR
config/
└── routes.rb                          # MODIFICAR — adicionar recursos no namespace :client
test/controllers/api/v1/client/
├── artes_controller_test.rb            # CRIAR
└── approval_responses_controller_test.rb  # CRIAR
```

### Padrão 1: Base Controller do Cliente com helpers de paginação e ActiveStorage

**O quê:** Adicionar ao `Api::V1::Client::BaseController` os mesmos helpers que o admin base tem — necessário para Pagy e resolução de `media_url`.

**Quando usar:** Qualquer index action com paginação + qualquer serializer que acesse `media_file.url`.

```ruby
# Source: app/controllers/api/v1/admin/base_controller.rb (Phase 22 — padrão estabelecido)
class Api::V1::Client::BaseController < Api::V1::BaseController
  include Pagy::Backend
  before_action :authenticate_client_jwt!
  before_action :set_active_storage_current

  rescue_from Pagy::OverflowError, with: :page_overflow

  private

  # ... authenticate_client_jwt! (já existe) ...

  def set_active_storage_current
    ActiveStorage::Current.url_options = {
      protocol: request.protocol,
      host:     request.host,
      port:     request.port
    }
  end

  def pagination_meta(pagy)
    {
      page:        pagy.page,
      per_page:    pagy.limit,
      total_count: pagy.count,
      total_pages: pagy.pages
    }
  end

  def per_page_param
    [(params[:per_page] || 25).to_i, 100].min.clamp(1, 100)
  end

  def page_overflow
    render_error(code: "page_out_of_range", detail: "Página fora do intervalo", status: :not_found)
  end
end
```

[VERIFIED: codebase] — copiado do `Api::V1::Admin::BaseController` existente, adaptado para herança do client base.

### Padrão 2: ArtesController — index com escopo de status

**O quê:** Lista artes `pending` + `revised` do `@current_client`, ordenadas por `scheduled_on`, paginadas.

**Por que `where(status: %w[pending revised])`:** Espelha exatamente `Client::HomeController` que usa `%w[pending revised]` para contar pendências.

```ruby
# Source: app/controllers/client/home_controller.rb (web — paridade de lógica)
# + app/controllers/api/v1/admin/artes_controller.rb (padrão de envelope + Pagy)
class Api::V1::Client::ArtesController < Api::V1::Client::BaseController
  def index
    scope = @current_client.artes
                           .where(status: %w[pending revised])
                           .order(:scheduled_on)
    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Client::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def show
    @arte = @current_client.artes
                           .includes(:approval_responses)
                           .find(params[:id])
    render_envelope(
      data: Api::V1::Client::ArteSerializer.serialize(@arte)
    )
  end
end
```

[VERIFIED: codebase] — lógica de status espelha `Client::HomeController#index`; envelope/Pagy espelha `Api::V1::Admin::ArtesController`.

### Padrão 3: ApprovalResponsesController — create com lock em transação

**O quê:** Espelha `Client::ResponsesController#create` mas com payload flat, sem redirect, e resposta JSON 201.

**Diferença crítica vs. web:** O web usa `params.require(:approval_response).permit(...)` (nested). A API usa `params.permit(...)` flat (sem wrapper) — D-05.

```ruby
# Source: app/controllers/client/responses_controller.rb (lógica de negócio)
# + Phase 22 padrão flat params + rescue_from centralizado
class Api::V1::Client::ApprovalResponsesController < Api::V1::Client::BaseController
  before_action :set_arte

  def create
    unless ApprovalResponse.decisions.key?(params[:decision].to_s)
      raise ActionController::ParameterMissing.new(:decision)
    end

    Arte.transaction do
      locked_arte = @current_client.artes.lock.find(@arte.id)
      response = locked_arte.approval_responses.build(response_params)
      response.save!
      render_envelope(
        data: {
          id:           response.id,
          decision:     response.decision,
          comment:      response.comment,
          responded_at: response.responded_at,
          arte_status:  locked_arte.reload.status
        },
        status: :created
      )
    end
  end

  private

  def set_arte
    @arte = @current_client.artes.find(params[:arte_id])
  end

  def response_params
    params.permit(:decision, :comment)
  end
end
```

[VERIFIED: codebase] — lock pattern vem de `Client::ResponsesController` linha 11-12; enum guard vem da mesma; payload flat vem do padrão Phase 22.

**Nota sobre `decision` inválido:** `ActionController::ParameterMissing` dispara o `rescue_from :bad_request` no base → 400. É o comportamento mais consistente com o padrão da Phase 22 (status inválido no admin também levanta `ParameterMissing` → 400). Se o planner preferir 422, basta lançar um `ActiveRecord::RecordInvalid` manualmente — ambos são estruturados e corretos.

### Padrão 4: ArteSerializer do cliente — PORO dedicado

**O quê:** Serializer específico para o cliente, com campos D-03 + histórico D-04. Sem `client_id`, `media_source_type`, `created_at`, `updated_at`.

```ruby
# Source: app/serializers/api/v1/admin/arte_serializer.rb (Phase 22 — base do padrão PORO)
# Campos D-03: id, title, caption, scheduled_on, approval_deadline, platform, media_type, media_url, status
# Campos D-04: approval_responses (array), admin_reply (campo da arte)
module Api::V1::Client::ArteSerializer
  def self.serialize(arte)
    {
      id:                arte.id,
      title:             arte.title,
      caption:           arte.caption,
      scheduled_on:      arte.scheduled_on,
      approval_deadline: arte.approval_deadline,
      platform:          arte.platform,
      media_type:        arte.media_type,
      media_url:         resolve_media_url(arte),
      status:            arte.status,
      admin_reply:       arte.admin_reply,
      approval_responses: serialize_responses(arte.approval_responses)
    }
  end

  def self.serialize_collection(artes)
    artes.map { |a| serialize(a) }
  end

  private_class_method def self.resolve_media_url(arte)
    arte.media_file.attached? ? arte.media_file.url : arte.external_url
  end

  private_class_method def self.serialize_responses(responses)
    responses.map do |r|
      { id: r.id, decision: r.decision, comment: r.comment, responded_at: r.responded_at }
    end
  end
end
```

[VERIFIED: codebase] — campos `admin_reply` confirmados em `db/schema.rb` (t.text "admin_reply"), `approval_responses` via `has_many` em `Arte` (app/models/arte.rb linha 3).

**N+1 prevention:** O `show` usa `includes(:approval_responses)` e o `index` (listagem) NÃO inclui `approval_responses` — não há necessidade na lista, apenas no detalhe. O serializer tenta serializar `arte.approval_responses` sem `includes` na listagem → potencial N+1 se chamado no index. **O planner deve garantir que `serialize_collection` seja chamado somente em artes sem necessidade de respostas (index), e `serialize` com `includes` somente no show.**

### Padrão 5: Rotas — extensão do namespace :client

**O quê:** Adicionar recursos dentro do `namespace :client` existente em `config/routes.rb`.

```ruby
# Source: config/routes.rb linhas 47-49 (namespace :client já existe)
namespace :client do
  resource :session, only: [ :create ]   # já existe
  resources :artes, only: [ :index, :show ] do
    resources :approval_responses, only: [ :create ]
  end
end
```

**Rotas geradas:**

| Método | Path | Controller#Action |
|--------|------|-------------------|
| GET | /api/v1/client/artes | api/v1/client/artes#index |
| GET | /api/v1/client/artes/:id | api/v1/client/artes#show |
| POST | /api/v1/client/artes/:arte_id/approval_responses | api/v1/client/approval_responses#create |

[VERIFIED: codebase] — rotas confirmadas contra `config/routes.rb`; namespace :client já existe na linha 47.

### Anti-Patterns a Evitar

- **`Arte.find(params[:id])` global:** Sempre usar `@current_client.artes.find(...)` — nunca `Arte.find` sem escopo. Rompe o isolamento cross-client (IDOR).
- **`rescue` local para RecordNotFound:** Não fazer `rescue ActiveRecord::RecordNotFound` no controller — o `rescue_from` no base já trata e devolve 404 estruturado automaticamente.
- **Serializer inline (render json: {}):** Nunca `render json: arte.attributes` ou inline. Sempre passar por serializer PORO.
- **`response.save` (sem bang):** Usar `save!` para que `RecordInvalid` propague ao `rescue_from` do base. Com `save` sem bang, erros de validação ficam silenciosos.
- **Payload nested `{ approval_response: { decision: ... } }`:** O app envia flat `{ decision: ..., comment: ... }`. O web usa `params.require(:approval_response)` — a API NÃO usa wrapper.
- **`media_file.url` sem `ActiveStorage::Current.url_options`:** Levanta `Missing host to link to!`. Garantir que `set_active_storage_current` esteja no before_action do base do cliente.
- **Incluir `approval_responses` no index:** Causa N+1. Só incluir no `show`.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por quê |
|----------|---------------|-------------------|---------|
| Paginação | `LIMIT`/`OFFSET` manual | Pagy (já instalado) | Overflow handling, metadados consistentes com Phase 22 |
| Geração de URLs absolutas de mídia | Concatenação manual de host + path | `arte.media_file.url` com `ActiveStorage::Current.url_options` | Edge cases de CDN, expiração de signed URLs |
| Verificação de escopo cross-client | Checar `arte.client_id == @current_client.id` manualmente | `@current_client.artes.find(id)` — lança `RecordNotFound` automaticamente | Mais simples, mais seguro, sem risco de comparação errada |
| Lock de concorrência | Semáforo em memória, flag em DB | `@current_client.artes.lock.find(id)` dentro de `Arte.transaction` | Row-level locking nativo do PostgreSQL — espelha web exatamente |
| Serialização de erros | Hash manual em cada action | `rescue_from` + `render_envelope`/`render_error` herdados | Consistência automática de envelope `{ data, meta, errors }` |

---

## Common Pitfalls

### Pitfall 1: `media_file.url` levanta `Missing host to link to!` em testes e API

**O que vai errado:** `ActiveStorage::Current.url_options` não é setado por padrão em `ActionController::API`. `arte.media_file.url` levanta `ArgumentError: Missing host to link to!`.

**Por que acontece:** O `ApplicationController` web tem helpers de URL configurados automaticamente; `ActionController::API` não.

**Como evitar:** Adicionar `before_action :set_active_storage_current` ao `Api::V1::Client::BaseController` (igual ao admin base). Verificar que o método está presente ANTES de criar qualquer serializer que acesse `media_file.url`.

**Sinais de alerta:** `ArgumentError: Missing host` em testes; `500` em produção para artes com `media_file` attached.

[VERIFIED: codebase] — pitfall documentado em `22-CONTEXT.md` (Integration Points) e resolvido no admin base.

### Pitfall 2: N+1 em `approval_responses` se `includes` ausente no show

**O que vai errado:** `@current_client.artes.find(params[:id])` sem `includes(:approval_responses)` faz 1 query por resposta ao serializar o array `approval_responses`.

**Por que acontece:** `has_many :approval_responses` sem eager load dispara query lazy por item.

**Como evitar:** No `show`: `@current_client.artes.includes(:approval_responses).find(params[:id])`. No `index`: NÃO incluir `approval_responses` (não são serializadas na lista).

**Sinais de alerta:** Logs com múltiplos `SELECT * FROM approval_responses WHERE arte_id = ?` consecutivos.

[VERIFIED: codebase] — `Client::ArtesController#set_arte` já usa `includes(:approval_responses)` (linha 9).

### Pitfall 3: Payload nested vs. flat no create de ApprovalResponse

**O que vai errado:** Usar `params.require(:approval_response).permit(...)` copiando o web controller — o app mobile envia `{ "decision": "approved" }` (flat), não `{ "approval_response": { "decision": "approved" } }`.

**Por que acontece:** Confusão entre padrão web (nested, Rails convention) e padrão API desta fase (flat, D-05).

**Como evitar:** Usar `params.permit(:decision, :comment)` diretamente. Testar explicitamente com payload flat no teste de integração.

[VERIFIED: codebase] — D-05 locked; padrão flat confirmado em `Api::V1::Admin::ArtesController#arte_params` (Phase 22).

### Pitfall 4: Enum guard antes do lock — evitar 500 em decisão inválida

**O que vai errado:** Chamar `locked.approval_responses.build(decision: "invalido")` sem guard — o enum do Rails levanta `ArgumentError: 'invalido' is not a valid decision` (não `RecordInvalid`), que não é capturado pelo `rescue_from`.

**Por que acontece:** Rails enums levantam `ArgumentError` (não `RecordInvalid`) para valores fora do hash.

**Como evitar:** Verificar `ApprovalResponse.decisions.key?(params[:decision].to_s)` ANTES do `build`. Se inválido, levantar `ActionController::ParameterMissing` (→ 400) ou `ActiveRecord::RecordInvalid` (→ 422).

[VERIFIED: codebase] — `Client::ResponsesController#create` linhas 4-6 aplica o mesmo guard.

### Pitfall 5: Transação + render dentro do bloco

**O que vai errado:** Colocar `render_envelope` dentro do bloco `Arte.transaction do ... end` sem retornar explicitamente. Se `save!` falha e levanta exceção, o `rescue_from` no base tenta renderizar, mas Rails pode reclamar de "double render" se o bloco continua.

**Como evitar:** Estruturar o bloco de forma que `render_envelope` seja a última instrução do `create` method, após o bloco da transação retornar o objeto. Ou retornar o objeto criado do bloco e renderizar fora.

**Sinais de alerta:** `AbstractController::DoubleRenderError` nos logs.

---

## Code Examples

### Setup de teste para endpoints de cliente (JWT)

```ruby
# Source: test/controllers/api/v1/client/sessions_controller_test.rb (Phase 21 — padrão estabelecido)
setup do
  @original_jwt_secret = ENV["JWT_SECRET"]
  ENV["JWT_SECRET"] = SecureRandom.hex(32)

  # Criar admin para evitar nil no callback Arte#broadcasts_revised_to_all
  User.find_or_create_by!(email_address: "admin@ilhacriativa.com.br") do |u|
    u.password              = "SenhaSegura123!"
    u.password_confirmation = "SenhaSegura123!"
  end

  @client = Client.create!(name: "Cliente API Teste", password: "SenhaCliente456!", active: true)
  @client_jwt = Api::JwtService.encode({ sub: @client.id.to_s, scope: "client" })
  @auth_headers = {
    "Authorization" => "Bearer #{@client_jwt}",
    "Content-Type"  => "application/json"
  }
end

teardown do
  ENV["JWT_SECRET"] = @original_jwt_secret
end
```

[VERIFIED: codebase] — padrão de test setup copiado de `sessions_controller_test.rb` (Phase 21) com adaptação para scope "client".

### Query de artes pendentes escopada

```ruby
# Source: app/controllers/client/home_controller.rb linha 26 (lógica de "pendente")
# + app/controllers/api/v1/admin/artes_controller.rb (padrão Pagy)
scope = @current_client.artes
                       .where(status: %w[pending revised])
                       .order(:scheduled_on)
@pagy, @artes = pagy(scope, limit: per_page_param)
```

[VERIFIED: codebase] — `%w[pending revised]` confirmado em `Client::HomeController` linha 26.

### Lock de linha para submissão

```ruby
# Source: app/controllers/client/responses_controller.rb linhas 10-14
Arte.transaction do
  locked_arte = @current_client.artes.lock.find(@arte.id)
  response    = locked_arte.approval_responses.build(response_params)
  response.save!
  # ...
end
```

[VERIFIED: codebase] — padrão exato de `Client::ResponsesController#create`.

---

## State of the Art

| Abordagem Antiga | Abordagem Atual | Quando Mudou | Impacto |
|-----------------|-----------------|--------------|---------|
| `render json: record.as_json` inline | PORO serializer module | Phase 22 | Campos controlados explicitamente, sem vazamento |
| `rescue` local em cada action | `rescue_from` centralizado no base | Phase 21 | Envelope consistente automático |
| Params nested `require(:resource)` | `params.permit(...)` flat | Phase 21/22 | App mobile envia JSON flat; sem wrapper |

**Deprecated/Outdated:**
- `pagy(scope, items: N)`: O parâmetro é `limit:` em Pagy 9.x, não `items:`. Confirmado em uso no admin base (`limit: per_page_param`). [VERIFIED: codebase]

---

## Assumptions Log

| # | Claim | Section | Risco se errado |
|---|-------|---------|-----------------|
| A1 | `decision` inválido → 400 via `ActionController::ParameterMissing` é preferível a 422 | Architecture Patterns (Padrão 3) | Mudaria apenas o código HTTP da resposta de erro; não quebra funcionalidade |

**Nota:** A1 é a recomendação do researcher mas está na área de discretion (D-10 diz "400/422"). O planner pode escolher 422 sem problema.

---

## Open Questions

1. **Serializer no index inclui `approval_responses`?**
   - O que sabemos: D-04 especifica que o detalhe inclui respostas. D-02 não menciona o index.
   - O que está claro: O index é uma "fila de pendências" — não precisa de histórico de respostas por item (aumentaria N+1 e payload sem utilidade para o app).
   - Recomendação: Index serializa sem `approval_responses`; show inclui. Planner deve confirmar com D-03/D-04.

2. **`admin_reply` no index ou só no show?**
   - O que sabemos: D-04 menciona `admin_reply` no detalhe. D-02 não menciona.
   - Recomendação: `admin_reply` apenas no show (detalhe). No index, omitir para manter payload enxuto.

---

## Environment Availability

Step 2.6: Sem novas dependências externas. Todos os componentes (Rails, Pagy, ActiveStorage, PostgreSQL, JwtService) já estão disponíveis e em uso desde as Phases 21/22.

| Dependência | Requerida por | Disponível | Versão | Fallback |
|-------------|--------------|-----------|--------|---------|
| Rails 8.1.3 | Controller base | ✓ | 8.1.3 | — |
| Pagy | Paginação index | ✓ | já instalado | — |
| Active Storage | media_url | ✓ | já instalado | — |
| PostgreSQL | Row locking | ✓ | já em uso | — |

---

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1` (ASVS L1).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim | `authenticate_client_jwt!` no before_action herdado — já implementado na Phase 21 |
| V3 Session Management | sim (JWT) | Expiração via `Api::JwtService`; `active?` check no before_action |
| V4 Access Control | sim | Escopo `@current_client.artes.find` — IDOR → 404; cross-client impossível por construção |
| V5 Input Validation | sim | Enum guard antes de build; `params.permit` (whitelist); `save!` + `rescue_from RecordInvalid` |
| V6 Cryptography | não (esta fase) | JWT já implementado Phase 21 |

### Known Threat Patterns

| Pattern | STRIDE | Mitigação Padrão |
|---------|--------|-----------------|
| IDOR (arte de outro cliente) | Spoofing/Info Disclosure | `@current_client.artes.find(id)` → 404 sem enumeração (D-09) |
| Double-submit (race condition na aprovação) | Tampering | `Arte.transaction + .lock.find` (D-07) |
| Enum injection (decision inválido) | Tampering | Guard `ApprovalResponse.decisions.key?` antes de build (D-10) |
| Cliente inativo tentando aprovar | Elevation of Privilege | `active?` check em `authenticate_client_jwt!` → 401 (Phase 21) |
| Mass assignment em approval_response | Tampering | `params.permit(:decision, :comment)` — whitelist explícita |

---

## Sources

### Primary (HIGH confidence)
- `app/controllers/api/v1/base_controller.rb` — envelope, rescue_from, error handlers
- `app/controllers/api/v1/client/base_controller.rb` — authenticate_client_jwt!, @current_client
- `app/controllers/api/v1/admin/base_controller.rb` — helpers de paginação e ActiveStorage a replicar
- `app/controllers/client/responses_controller.rb` — lock pattern, enum guard, response_params
- `app/controllers/client/artes_controller.rb` — includes(:approval_responses) no show
- `app/controllers/client/home_controller.rb` — definição de "pendente" = %w[pending revised]
- `app/models/approval_response.rb` — enum decision, arte_must_be_pending, sync_arte_status, broadcasts_to_admin
- `app/models/arte.rb` — enum status, has_many approval_responses, admin_reply
- `app/serializers/api/v1/admin/arte_serializer.rb` — padrão PORO + resolve_media_url
- `db/schema.rb` — confirmação de campos admin_reply, approval_responses
- `config/routes.rb` — namespace :client existente
- `.planning/phases/22-endpoints-admin/22-PATTERNS.md` — padrões estabelecidos Phase 22

### Secondary (MEDIUM confidence)
- `.planning/phases/22-endpoints-admin/22-CONTEXT.md` — pitfall ActiveStorage::Current
- `test/controllers/api/v1/client/sessions_controller_test.rb` — padrão de setup JWT

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — todos os componentes verificados no codebase
- Architecture: HIGH — padrão direto da Phase 22 com adaptações pontuais verificadas nos sources
- Pitfalls: HIGH — coletados dos sources existentes e dos PLANs da Phase 22
- Serializer fields: HIGH — confirmados via schema.rb e models

**Research date:** 2026-06-12
**Valid until:** 2026-07-12 (stack estável, sem movimentação prevista)
