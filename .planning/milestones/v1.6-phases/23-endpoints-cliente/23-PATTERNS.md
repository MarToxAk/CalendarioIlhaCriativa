# Phase 23: Endpoints Cliente - Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 7 arquivos novos/modificados
**Analogs found:** 7 / 7

---

## File Classification

| Arquivo novo/modificado | Role | Data Flow | Analog mais próximo | Qualidade |
|------------------------|------|-----------|---------------------|-----------|
| `app/controllers/api/v1/client/base_controller.rb` | middleware/base | request-response | `app/controllers/api/v1/admin/base_controller.rb` | exact |
| `app/controllers/api/v1/client/artes_controller.rb` | controller | CRUD (read-only) | `app/controllers/api/v1/admin/artes_controller.rb` | role-match |
| `app/controllers/api/v1/client/approval_responses_controller.rb` | controller | request-response | `app/controllers/client/responses_controller.rb` | exact (lógica) + `api/v1/admin/artes_controller.rb` (padrão API) |
| `app/serializers/api/v1/client/arte_serializer.rb` | utility/serializer | transform | `app/serializers/api/v1/admin/arte_serializer.rb` | exact |
| `app/serializers/api/v1/client/approval_response_serializer.rb` | utility/serializer | transform | `app/serializers/api/v1/admin/approval_response_serializer.rb` | exact |
| `config/routes.rb` | config | — | `config/routes.rb` (namespace :client existente, linhas 47-49) | exact |
| `test/controllers/api/v1/client/artes_controller_test.rb` | test | request-response | `test/controllers/api/v1/admin/artes_controller_test.rb` | role-match |
| `test/controllers/api/v1/client/approval_responses_controller_test.rb` | test | request-response | `test/controllers/api/v1/admin/approval_responses_controller_test.rb` | role-match |

---

## Pattern Assignments

### `app/controllers/api/v1/client/base_controller.rb` (middleware/base, request-response)

**Ação:** MODIFICAR — adicionar `Pagy::Backend`, helpers de paginação e `set_active_storage_current`.

**Analog:** `app/controllers/api/v1/admin/base_controller.rb`

**Estado atual do arquivo** (linhas 1-29 — ler antes de editar):
```ruby
# frozen_string_literal: true

class Api::V1::Client::BaseController < Api::V1::BaseController
  before_action :authenticate_client_jwt!

  private

  def authenticate_client_jwt!
    token = bearer_token
    return render_unauthorized unless token

    claims = Api::JwtService.decode(token)
    return render_unauthorized unless claims[:scope] == "client"

    @current_client = Client.find_by(id: claims[:sub])
    return render_unauthorized unless @current_client
    render_unauthorized unless @current_client.active?
  rescue Api::Errors::TokenExpired, Api::Errors::TokenInvalid
    render_unauthorized
  end

  def bearer_token
    request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip.presence
  end

  def render_unauthorized
    render_error(code: "unauthorized", detail: "Autenticação inválida ou expirada", status: :unauthorized)
  end
end
```

**Padrão a adicionar — extraído do admin base** (linhas 4-57 de `app/controllers/api/v1/admin/base_controller.rb`):
```ruby
# Adicionar no topo da classe (após herança):
include Pagy::Backend
# Adicionar como segundo before_action (após authenticate_client_jwt!):
before_action :set_active_storage_current
# Adicionar rescue_from para overflow de página:
rescue_from Pagy::OverflowError, with: :page_overflow

# Adicionar nos métodos privados:
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
```

---

### `app/controllers/api/v1/client/artes_controller.rb` (controller, CRUD read-only)

**Ação:** CRIAR

**Analog primário:** `app/controllers/api/v1/admin/artes_controller.rb` (padrão index + envelope + Pagy)
**Analog de lógica:** `app/controllers/client/home_controller.rb` linha 12-15 e 26 (`%w[pending revised]`) + `app/controllers/client/artes_controller.rb` linha 10 (`includes(:approval_responses)`)

**Imports pattern** — baseado em `app/controllers/api/v1/admin/artes_controller.rb` linhas 1-3:
```ruby
# frozen_string_literal: true

class Api::V1::Client::ArtesController < Api::V1::Client::BaseController
```

**Core pattern — index** (analog: admin artes_controller.rb linhas 4-12):
```ruby
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
```

**Core pattern — show** (analog: `app/controllers/client/artes_controller.rb` linha 10):
```ruby
def show
  @arte = @current_client.artes
                         .includes(:approval_responses)
                         .find(params[:id])
  render_envelope(
    data: Api::V1::Client::ArteSerializer.serialize(@arte)
  )
end
```

**Escopo de segurança obrigatório:** Nunca `Arte.find` — sempre `@current_client.artes.find` (previne IDOR → 404 automático via `rescue_from RecordNotFound` no base, linha 4 de `app/controllers/api/v1/base_controller.rb`).

**Sem rescue local:** O `rescue_from` do `Api::V1::BaseController` (linhas 4-6) trata `RecordNotFound` → 404, `RecordInvalid` → 422, `ParameterMissing` → 400 — não replicar rescue local.

---

### `app/controllers/api/v1/client/approval_responses_controller.rb` (controller, request-response)

**Ação:** CRIAR

**Analog de lógica de negócio:** `app/controllers/client/responses_controller.rb` (linhas 4-21 — lock em transação + enum guard)
**Analog de padrão API:** `app/controllers/api/v1/admin/artes_controller.rb` (params flat, `save!`, `render_envelope`)

**Imports pattern:**
```ruby
# frozen_string_literal: true

class Api::V1::Client::ApprovalResponsesController < Api::V1::Client::BaseController
```

**before_action — escopo da arte** (analog: `app/controllers/client/responses_controller.rb` linhas 25-27):
```ruby
before_action :set_arte

private

def set_arte
  @arte = @current_client.artes.find(params[:arte_id])
  # Sem rescue local — RecordNotFound → 404 pelo base rescue_from
end
```

**Enum guard antes do build** (analog: `app/controllers/client/responses_controller.rb` linhas 4-6; adaptado para API — sem redirect, com raise):
```ruby
# Verificar ANTES de entrar na transação para evitar ArgumentError não capturado:
unless ApprovalResponse.decisions.key?(params[:decision].to_s)
  raise ActionController::ParameterMissing.new(:decision)
  # → rescue_from :bad_request no base → 400 estruturado
end
```

**Core pattern — lock em transação** (analog: `app/controllers/client/responses_controller.rb` linhas 10-14):
```ruby
def create
  unless ApprovalResponse.decisions.key?(params[:decision].to_s)
    raise ActionController::ParameterMissing.new(:decision)
  end

  Arte.transaction do
    locked_arte = @current_client.artes.lock.find(@arte.id)
    response    = locked_arte.approval_responses.build(response_params)
    response.save!  # RecordInvalid propagado ao rescue_from → 422
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
```

**Params flat** (diferença crítica vs. web — D-05; analog: `app/controllers/api/v1/admin/artes_controller.rb` linhas 43-47):
```ruby
def response_params
  params.permit(:decision, :comment)
  # NÃO usar params.require(:approval_response).permit(...) — isso é o padrão web, não API
end
```

**Nota de segurança:** `save!` (com bang) é obrigatório — `save` sem bang silencia erros de validação (`arte_must_be_pending` não propagaria). Padrão confirmado no admin artes_controller.rb linha 17.

---

### `app/serializers/api/v1/client/arte_serializer.rb` (utility/serializer, transform)

**Ação:** CRIAR

**Analog:** `app/serializers/api/v1/admin/arte_serializer.rb` (linhas 1-33 — estrutura PORO completa)

**Estrutura base PORO** (copiada do admin serializer linhas 1-33, com campos D-03/D-04):
```ruby
# frozen_string_literal: true

module Api::V1::Client::ArteSerializer
  def self.serialize(arte)
    {
      id:                 arte.id,
      title:              arte.title,
      caption:            arte.caption,
      scheduled_on:       arte.scheduled_on,
      approval_deadline:  arte.approval_deadline,
      platform:           arte.platform,
      media_type:         arte.media_type,
      media_url:          resolve_media_url(arte),
      status:             arte.status,
      admin_reply:        arte.admin_reply,
      approval_responses: serialize_responses(arte.approval_responses)
    }
  end

  def self.serialize_collection(artes)
    artes.map { |a| serialize(a) }
  end

  private_class_method def self.resolve_media_url(arte)
    if arte.media_file.attached?
      arte.media_file.url   # requer ActiveStorage::Current.url_options setado no before_action
    else
      arte.external_url
    end
  end

  private_class_method def self.serialize_responses(responses)
    responses.map do |r|
      { id: r.id, decision: r.decision, comment: r.comment, responded_at: r.responded_at }
    end
  end
end
```

**Campos excluídos vs. admin:** `client_id`, `media_source_type`, `created_at`, `updated_at` — sem utilidade no app do cliente (D-03).

**Campos adicionados vs. admin:** `admin_reply` (campo da arte), `approval_responses` embutidas (array) — D-04.

**Aviso N+1:** `serialize_collection` chama `serialize` que acessa `arte.approval_responses`. No `index`, NÃO passar `includes(:approval_responses)` — approval_responses não são necessárias na listagem. O serializer para listagem pode omitir `approval_responses` (retornar `[]` ou omitir a chave) para evitar N+1. O planner deve decidir: opção A) serializer único que retorna `approval_responses: []` quando não carregado; opção B) serializer separado para index vs. show.

---

### `app/serializers/api/v1/client/approval_response_serializer.rb` (utility/serializer, transform)

**Ação:** CRIAR

**Analog:** `app/serializers/api/v1/admin/approval_response_serializer.rb` (linhas 1-18)

**Estrutura base** (copiada do admin, com `arte_status` inline no create em vez de serializer separado — D-08):
```ruby
# frozen_string_literal: true

module Api::V1::Client::ApprovalResponseSerializer
  def self.serialize(approval_response, arte_status:)
    {
      id:           approval_response.id,
      decision:     approval_response.decision,
      comment:      approval_response.comment,
      responded_at: approval_response.responded_at,
      arte_status:  arte_status
    }
  end
end
```

**Diferença vs. admin:** Sem `created_at` (não necessário no app); inclui `arte_status` como no admin (D-08 — app atualiza UI sem re-buscar).

**Alternativa inline:** O `ApprovalResponsesController#create` pode construir o hash diretamente sem este serializer (padrão já mostrado no padrão do controller acima). O planner decide se cria o módulo ou inline — o módulo é mais limpo e testável.

---

### `config/routes.rb` (config)

**Ação:** MODIFICAR — adicionar recursos dentro do `namespace :client` existente.

**Analog:** `config/routes.rb` linhas 47-49 (namespace :client já existe):
```ruby
# Estado atual (linhas 47-49):
namespace :client do
  resource :session, only: [ :create ]   # POST /api/v1/client/session — já existe
end

# Padrão a adicionar (analog: admin namespace linhas 39-45 + client/responses routes linhas 31-34):
namespace :client do
  resource :session, only: [ :create ]
  resources :artes, only: [ :index, :show ] do
    resources :approval_responses, only: [ :create ]
  end
end
```

**Rotas geradas:**

| Método | Path | Controller#Action |
|--------|------|-------------------|
| GET | `/api/v1/client/artes` | `api/v1/client/artes#index` |
| GET | `/api/v1/client/artes/:id` | `api/v1/client/artes#show` |
| POST | `/api/v1/client/artes/:arte_id/approval_responses` | `api/v1/client/approval_responses#create` |

---

### `test/controllers/api/v1/client/artes_controller_test.rb` (test, request-response)

**Ação:** CRIAR

**Analog:** `test/controllers/api/v1/admin/artes_controller_test.rb` (linhas 1-60 — estrutura setup/teardown + casos GET)

**Setup pattern** (linhas 9-33 do admin test, adaptado para cliente; fonte adicional: `test/controllers/api/v1/client/sessions_controller_test.rb` linhas 9-22):
```ruby
# frozen_string_literal: true

require "test_helper"

class Api::V1::Client::ArtesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    # Admin necessário para callback Arte#broadcasts_revised_to_all (User.order(:id).first)
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

**Padrão de assertion** (analog: admin artes_controller_test.rb linhas 39-48):
```ruby
test "GET /api/v1/client/artes retorna 200 com lista paginada" do
  get "/api/v1/client/artes", headers: @auth_headers

  assert_equal 200, response.status
  body = response.parsed_body
  assert body.dig("meta", "pagination", "total_count").is_a?(Integer)
  assert_equal [], body["errors"]
end
```

**Casos obrigatórios a cobrir:**
- 200 com lista paginada e `meta.pagination` (APICLI-01)
- Apenas `pending` e `revised` aparecem (não `approved`, não `change_requested`)
- Arte de outro cliente NÃO aparece no index (cross-client)
- 401 sem autenticação
- 200 show com campos D-03 (`id`, `title`, `caption`, `scheduled_on`, `approval_deadline`, `platform`, `media_type`, `media_url`, `status`)
- Show inclui `approval_responses` e `admin_reply` (D-04)
- 404 para arte de outro cliente no show (D-09)

---

### `test/controllers/api/v1/client/approval_responses_controller_test.rb` (test, request-response)

**Ação:** CRIAR

**Analog:** `test/controllers/api/v1/admin/approval_responses_controller_test.rb` (linhas 1-90 — estrutura de fixtures + POST)

**Setup pattern** (analog: admin approval_responses_controller_test.rb linhas 9-44):
```ruby
setup do
  @original_jwt_secret = ENV["JWT_SECRET"]
  ENV["JWT_SECRET"] = SecureRandom.hex(32)

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

  @arte = Arte.create!(
    client:       @client,
    title:        "Arte Teste",
    scheduled_on: Date.current,
    platform:     :instagram,
    media_type:   :image,
    external_url: "https://example.com/arte.jpg",
    status:       :pending
  )
end
```

**Padrão de assertion POST** (analog: admin approval_responses_controller_test.rb linhas 50-75):
```ruby
test "POST cria approval_response e retorna 201 com arte_status" do
  post "/api/v1/client/artes/#{@arte.id}/approval_responses",
       params: { decision: "approved" }.to_json,
       headers: @auth_headers

  assert_equal 201, response.status
  body = response.parsed_body
  assert_equal "approved", body.dig("data", "decision")
  assert body.dig("data", "arte_status").present?
  assert_equal [], body["errors"]
end
```

**Casos obrigatórios a cobrir:**
- 201 com payload flat `{ decision: "approved" }` (sem wrapper)
- 201 com `{ decision: "change_requested", comment: "..." }`
- Resposta inclui `id`, `decision`, `comment`, `responded_at`, `arte_status` (D-08)
- 400 para `decision` inválido (enum guard → `ParameterMissing`)
- 422 para arte já `approved` (arte_must_be_pending falha → `RecordInvalid`)
- 404 para arte de outro cliente (cross-client, D-09)
- 401 sem autenticação
- Re-aprovação de arte `revised` retorna 201 (D-08)

---

## Shared Patterns

### Envelope de resposta
**Fonte:** `app/controllers/api/v1/base_controller.rb` linhas 10-17
**Aplicar a:** Todos os controllers desta fase
```ruby
def render_envelope(data:, meta: {}, status: :ok)
  render json: { data: data, meta: meta, errors: [] }, status: status
end

def render_error(code:, detail:, status:, field: nil)
  error = { code: code, detail: detail }
  error[:field] = field if field
  render json: { data: nil, meta: {}, errors: [error] }, status: status
end
```

### Error handling centralizado (sem rescue local)
**Fonte:** `app/controllers/api/v1/base_controller.rb` linhas 4-6
**Aplicar a:** Todos os controllers desta fase
```ruby
rescue_from ActiveRecord::RecordNotFound,        with: :not_found       # → 404
rescue_from ActiveRecord::RecordInvalid,         with: :unprocessable_entity  # → 422
rescue_from ActionController::ParameterMissing,  with: :bad_request     # → 400
```
**Regra:** Nunca usar `rescue` local nos controllers de negócio. Deixar as exceções propagarem ao base.

### ActiveStorage::Current — obrigatório antes de qualquer serializer com media_url
**Fonte:** `app/controllers/api/v1/admin/base_controller.rb` linhas 34-40
**Aplicar a:** `Api::V1::Client::BaseController` (before_action)
```ruby
def set_active_storage_current
  ActiveStorage::Current.url_options = {
    protocol: request.protocol,
    host:     request.host,
    port:     request.port
  }
end
```

### Paginação Pagy — contrato meta.pagination
**Fonte:** `app/controllers/api/v1/admin/base_controller.rb` linhas 42-57
**Aplicar a:** `Api::V1::Client::BaseController` + `ArtesController#index`
```ruby
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
```

### Serializer PORO — padrão de módulo
**Fonte:** `app/serializers/api/v1/admin/arte_serializer.rb` linhas 1-33
**Aplicar a:** Todos os serializers desta fase
```ruby
module Api::V1::Client::XSerializer
  def self.serialize(record)
    { ... }
  end

  def self.serialize_collection(records)
    records.map { |r| serialize(r) }
  end

  private_class_method def self.helper_method(...)
    ...
  end
end
```

### Escopo cross-client obrigatório
**Fonte:** `app/controllers/client/artes_controller.rb` linha 10 + `app/controllers/client/responses_controller.rb` linha 11
**Aplicar a:** `ArtesController`, `ApprovalResponsesController`
```ruby
# CORRETO — escopo pelo cliente autenticado:
@current_client.artes.find(params[:id])
@current_client.artes.lock.find(params[:arte_id])

# ERRADO — nunca fazer:
Arte.find(params[:id])
```

### Row lock para submissão de aprovação
**Fonte:** `app/controllers/client/responses_controller.rb` linhas 10-14
**Aplicar a:** `ApprovalResponsesController#create`
```ruby
Arte.transaction do
  locked_arte = @current_client.artes.lock.find(@arte.id)
  response    = locked_arte.approval_responses.build(response_params)
  response.save!
  # render dentro do bloco, mas como última instrução para evitar double render
end
```

---

## No Analog Found

Todos os arquivos desta fase têm analog direto no codebase. Nenhum arquivo sem correspondência.

---

## Metadata

**Escopo de busca de analógicos:**
- `app/controllers/api/v1/` (admin + client base)
- `app/controllers/client/` (web — lógica de negócio)
- `app/serializers/api/v1/admin/`
- `test/controllers/api/v1/`
- `config/routes.rb`
- `app/models/approval_response.rb`

**Arquivos escaneados:** 12 arquivos lidos diretamente
**Data de extração:** 2026-06-12
