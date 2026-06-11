# Phase 22: Endpoints Admin - Research

**Researched:** 2026-06-11
**Domain:** Ruby on Rails 8.1 JSON API — recursos admin sobre fundação Phase 21
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Upload de imagem da arte (APIADM-04)**
- **D-01:** App envia a imagem via `multipart/form-data` com o arquivo binário direto no campo `media_file` — mesmo mecanismo do form web (reusa Active Storage `has_one_attached :media_file`). Sem base64, sem direct-upload/signed_id nesta fase.
- **D-02:** A criação de arte aceita **arquivo OU `external_url`** (Drive/Dropbox), com paridade total ao web: vale a regra `only_one_media_source` e `media_source_present` já no model `Arte`.
- **D-03:** Na resposta JSON de uma arte, a mídia é representada por uma **URL absoluta já resolvida** (`media_url`) + um campo indicando a fonte (`upload`/`link`).

**Representação do cliente no JSON (APIADM-01, APIADM-02)**
- **D-04:** Senha/credencial só aparece no **POST de criação**. GET nunca retorna senha.
- **D-05:** No **POST de criação**, a resposta devolve **uma única vez** o link completo do portal + a senha.
- **D-06:** Senha vem no payload `{ name, password }` (+ `active` opcional). `access_token` é gerado automaticamente (`has_secure_token`), nunca enviado pelo app.

**Filtros e paginação (APIADM-01, APIADM-03)**
- **D-07:** Filtros via query params nomeados: `client_id`, `status` (string enum), `month=YYYY-MM`. Todos opcionais e combináveis.
- **D-08:** Paginação via `page`/`per_page` (default 25, teto ~100), usando **Pagy**. Aplica-se a clientes e artes.
- **D-09:** `meta.pagination = { page, per_page, total_count, total_pages }`.

**Histórico de aprovações (APIADM-05)**
- **D-10:** Histórico aninhado por arte: `GET /api/v1/admin/artes/:id/approval_responses`.
- **D-11:** Cada resposta inclui: `id`, `decision` (string), `comment`, `responded_at` + status atual da arte.

### Claude's Discretion
- Biblioteca/estratégia de serialização (jbuilder vs serializer plano vs Alba etc.) — pesquisa decide, respeitando o envelope e os campos acima.
- Variantes/thumbnails da imagem além da URL principal.
- Ordenação padrão das listagens, nomes exatos dos campos JSON, teto exato de `per_page`.

### Deferred Ideas (OUT OF SCOPE)
- Endpoint de histórico agregado por cliente (`/admin/clients/:id/approval_responses`)
- Edição/exclusão de cliente e arte via API (PUT/PATCH/DELETE)
- Direct upload / signed_id e variantes/thumbnails
- Rate limiting (Phase 24)

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APIADM-01 | Admin lista clientes (paginado) | Pagy::Backend no API base controller; serialização plana de Client; filtro por name opcional |
| APIADM-02 | Admin cria novo cliente | `client_params` existente; `has_secure_token` auto-gera access_token; resposta única com portal link + senha |
| APIADM-03 | Admin lista artes (filtros por cliente, status, mês) | Filtros via query params; month→date range; Arte.statuses guard; paginação Pagy |
| APIADM-04 | Admin cria nova arte (upload de imagem incluído) | `multipart/form-data` funciona em ActionController::API; media_source logic; Active Storage + host config |
| APIADM-05 | Admin vê histórico de aprovações | Rota aninhada `artes/:id/approval_responses`; serialização de ApprovalResponse com arte.status |

</phase_requirements>

---

## Summary

A Phase 22 constrói três controllers (`ClientsController`, `ArtesController`, `ApprovalResponsesController`) todos herdando de `Api::V1::Admin::BaseController`, que já entrega autenticação JWT e o envelope `{ data, meta, errors }`. Todo o mecanismo de serialização ainda não existe neste projeto — nenhuma gem de serializer está instalada, apenas `jbuilder` (que está no Gemfile mas sem nenhum template `.jbuilder` criado ainda).

**A recomendação central de serialização é usar módulos Ruby simples (PORO) chamados de dentro dos controllers via métodos `serialize_*`**, em vez de adicionar uma nova gem. O `jbuilder` já presente é uma alternativa viável para quem prefere templates, mas a abordagem PORO mantém a filosofia lean do projeto, é completamente testável sem magia de views, e é menos surpreendente no contexto de `ActionController::API` (que não inclui renderização de views por padrão).

O único ponto de atenção real de infraestrutura é a geração de URLs absolutas do Active Storage em controladores `ActionController::API`: o mecanismo correto é incluir `ActiveStorage::SetCurrent` como `before_action` no base controller admin da API, o que preenche `ActiveStorage::Current.url_options` com `protocol`/`host`/`port` do request real. Com isso, `rails_blob_url(arte.media_file)` gera URLs absolutas e corretas sem nenhuma configuração extra de `default_url_options`.

**Recomendação principal:** serialização PORO em `app/serializers/api/v1/`; `ActiveStorage::SetCurrent` no base admin; `include Pagy::Backend` no base admin da API; nenhuma gem nova necessária.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Listagem/criação de clientes | API / Backend | — | Dados de negócio; sem lógica de view |
| Listagem/criação de artes | API / Backend | Active Storage (storage) | Upload de arquivo; validações no model |
| Resolução de media_url | API / Backend | Active Storage disk service | URL assinada gerada pela service layer |
| Histórico de aprovações | API / Backend | — | Leitura de dados existentes |
| Paginação | API / Backend | — | Pagy::Backend no controller |
| Filtros por status/mês | API / Backend | Database | WHERE clause gerada pelo AR; índice em `status` e `client_id` existem |
| Autenticação JWT | API / Backend | — | Já implementado em Phase 21; before_action herdado |
| Broadcasts ActionCable | Model callback | — | Disparado automaticamente por `after_create_commit` no modelo Arte; não requer nenhuma ação do controller |

---

## Standard Stack

### Core (tudo já presente no Gemfile e instalado)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails / ActionController::API | 8.1.3 | Base dos controllers de API | Já é a base de `Api::V1::BaseController` |
| Pagy | 9.4.0 | Paginação | Já em uso no web admin; `Pagy::Backend` incluso |
| Active Storage | 8.1.3 (bundled) | Upload e URL de arquivos | `has_one_attached :media_file` já declarado no model Arte |
| jwt gem | ~3.2 | JWT encode/decode | Já usado pelo `Api::JwtService` |

[VERIFIED: codebase grep] Versões confirmadas via `Gemfile.lock` / vendor/bundle.

### Serialização — Recomendação: PORO Serializers

**Usar módulos Ruby simples em `app/serializers/api/v1/`** — sem gem adicional.

**Por que não jbuilder:** O `jbuilder` está no Gemfile mas `ActionController::API` não inclui `ActionView` por padrão. Usar jbuilder exigiria ou (a) montar um workaround para renderizar templates `.jbuilder` no contexto de API, ou (b) herdar de `ActionController::Base` — ambos adicionam complexidade. Para o volume de endpoints desta fase (3 resources), os templates `.jbuilder` teriam mais cerimônia que valor. [ASSUMED: avaliação arquitetural; não há precedente de jbuilder em API controllers neste projeto]

**Por que não Alba/Blueprinter:** São gems externas que adicionariam dependência sem benefício concreto para 3 recursos. O projeto tem DNA enxuto (auth sem Devise, sem gems de conveniência). [ASSUMED: decisão de escopo; alternativas funcionam mas não agregam para este tamanho]

**Estrutura recomendada:**

```
app/serializers/
  api/
    v1/
      admin/
        arte_serializer.rb
        client_serializer.rb
        approval_response_serializer.rb
```

### Sem novas gems necessárias

Todos os requisitos da Phase 22 são implementáveis com as gems já instaladas. Nenhuma instalação nova.

---

## Package Legitimacy Audit

> Nenhuma gem nova é instalada nesta fase. Seção N/A.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Mobile App (admin JWT)
        |
        | Authorization: Bearer <admin_jwt>
        v
Api::V1::Admin::BaseController
  before_action :authenticate_admin_jwt!   (Phase 21)
  before_action :set_active_storage_host   (NEW: ActiveStorage::SetCurrent)
  include Pagy::Backend                    (NEW: adicionado ao base admin)
        |
   +---------+-----------+
   |         |           |
Clients   Artes    ApprovalResponses
Controller Controller  Controller
   |         |           |
   |    Arte.where(...)  |
   |    .page(...)       arte.approval_responses
   |                         .order(created_at: desc)
   |
Client.create!(...)
  has_secure_token -> access_token gerado
  has_secure_password -> password_digest
        |
        v
 PORO Serializers
   ClientSerializer        -> { id, name, active, created_at }
   ClientSerializer(full)  -> + portal_url, password (apenas POST)
   ArteSerializer          -> { id, title, ..., media_url, media_source_type }
   ApprovalResponseSerializer -> { id, decision, comment, responded_at, arte_status }
        |
        v
render_envelope(data: ..., meta: { pagination: {...} })
```

### Recommended Project Structure

```
app/
├── controllers/
│   └── api/v1/admin/
│       ├── base_controller.rb    (MODIFICAR: + Pagy::Backend + SetCurrent)
│       ├── clients_controller.rb (NOVO)
│       ├── artes_controller.rb   (NOVO)
│       └── approval_responses_controller.rb (NOVO)
├── serializers/
│   └── api/v1/admin/
│       ├── arte_serializer.rb    (NOVO)
│       ├── client_serializer.rb  (NOVO)
│       └── approval_response_serializer.rb (NOVO)
```

### Pattern 1: PORO Serializer

**O que é:** Módulo Ruby puro com método de classe `serialize(record, options = {})` que devolve um Hash.
**Quando usar:** Sempre que o controller precisar converter um AR record para dados JSON.

```ruby
# app/serializers/api/v1/admin/arte_serializer.rb
# Source: padrão PORO verificado na codebase — sem gem externa
module Api::V1::Admin::ArteSerializer
  def self.serialize(arte, url_helpers:)
    {
      id:            arte.id,
      title:         arte.title,
      caption:       arte.caption,
      scheduled_on:  arte.scheduled_on,
      approval_deadline: arte.approval_deadline,
      platform:      arte.platform,
      media_type:    arte.media_type,
      status:        arte.status,
      client_id:     arte.client_id,
      media_url:     resolve_media_url(arte, url_helpers),
      media_source_type: arte.media_file.attached? ? "upload" : (arte.external_url.present? ? "link" : nil),
      created_at:    arte.created_at,
      updated_at:    arte.updated_at
    }
  end

  def self.serialize_collection(artes, url_helpers:)
    artes.map { |a| serialize(a, url_helpers: url_helpers) }
  end

  private_class_method def self.resolve_media_url(arte, url_helpers)
    if arte.media_file.attached?
      url_helpers.rails_blob_url(arte.media_file, only_path: false)
    else
      arte.external_url
    end
  end
end
```

```ruby
# app/serializers/api/v1/admin/client_serializer.rb
module Api::V1::Admin::ClientSerializer
  def self.serialize(client, include_credentials: false, portal_host: nil)
    data = {
      id:         client.id,
      name:       client.name,
      active:     client.active,
      created_at: client.created_at
    }
    if include_credentials
      data[:password]   = client.password_plain   # só no POST create
      data[:portal_url] = "#{portal_host}/c/#{client.access_token}"
    end
    data
  end

  def self.serialize_collection(clients)
    clients.map { |c| serialize(c) }
  end
end
```

```ruby
# app/serializers/api/v1/admin/approval_response_serializer.rb
module Api::V1::Admin::ApprovalResponseSerializer
  def self.serialize(approval_response)
    {
      id:           approval_response.id,
      decision:     approval_response.decision,   # string: "approved" / "change_requested"
      comment:      approval_response.comment,
      responded_at: approval_response.responded_at,
      created_at:   approval_response.created_at,
      arte_status:  approval_response.arte.status
    }
  end

  def self.serialize_collection(responses)
    responses.map { |r| serialize(r) }
  end
end
```

### Pattern 2: Base Controller Admin Atualizado

```ruby
# app/controllers/api/v1/admin/base_controller.rb  (modificar, não substituir)
class Api::V1::Admin::BaseController < Api::V1::BaseController
  include Pagy::Backend
  before_action :authenticate_admin_jwt!
  before_action :set_active_storage_current

  private

  # Preenche ActiveStorage::Current.url_options com os dados do request real.
  # Necessário para que rails_blob_url gere URLs absolutas corretas.
  # Source: activestorage-8.1.3/app/controllers/concerns/active_storage/set_current.rb
  def set_active_storage_current
    ActiveStorage::Current.url_options = {
      protocol: request.protocol,
      host:     request.host,
      port:     request.port
    }
  end

  # ... authenticate_admin_jwt! e render_unauthorized existentes ...
end
```

**Nota:** `include ActiveStorage::SetCurrent` também funciona e é equivalente — ambas as abordagens são válidas. O inline acima é mais explícito sobre o que está acontecendo. [VERIFIED: activestorage-8.1.3 source — set_current.rb linha 12]

### Pattern 3: Clientes Controller

```ruby
# app/controllers/api/v1/admin/clients_controller.rb
class Api::V1::Admin::ClientsController < Api::V1::Admin::BaseController
  def index
    scope = Client.order(created_at: :desc)
    @pagy, @clients = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Admin::ClientSerializer.serialize_collection(@clients),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    @client = Client.new(client_params)
    @client.save!   # raises RecordInvalid → rescue_from → 422 automático
    portal_host = "#{request.protocol}#{request.host_with_port}"
    render_envelope(
      data: Api::V1::Admin::ClientSerializer.serialize(
        @client,
        include_credentials: true,
        portal_host: portal_host
      ),
      status: :created
    )
  end

  private

  def client_params
    params.permit(:name, :password, :active)
  end

  def per_page_param
    [(params[:per_page] || 25).to_i, 100].min.clamp(1, 100)
  end

  def pagination_meta(pagy)
    {
      page:        pagy.page,
      per_page:    pagy.limit,
      total_count: pagy.count,
      total_pages: pagy.pages
    }
  end
end
```

**Nota sobre `client_params`:** Em `ActionController::API`, não há `params.require(:client)` por convenção de form — os campos chegam diretamente no root do JSON body ou como multipart. O controller usa `params.permit(...)` diretamente (sem `.require(:client)`), espelhando a abordagem da sessions_controller existente. [VERIFIED: codebase — sessions_controller.rb usa `params.require(:email)` diretamente, não `params.require(:session)`]

### Pattern 4: Artes Controller com Filtros

```ruby
# app/controllers/api/v1/admin/artes_controller.rb
class Api::V1::Admin::ArtesController < Api::V1::Admin::BaseController
  def index
    scope = Arte.includes(:client).order(scheduled_on: :desc)
    scope = apply_filters(scope)
    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Admin::ArteSerializer.serialize_collection(@artes, url_helpers: self),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    @arte = Arte.new(arte_params)
    # Se veio media_file (upload), garante que external_url está vazio
    @arte.external_url = nil if params[:media_file].present?
    @arte.save!   # raises RecordInvalid → 422 automático via rescue_from
    render_envelope(
      data: Api::V1::Admin::ArteSerializer.serialize(@arte, url_helpers: self),
      status: :created
    )
  end

  private

  def apply_filters(scope)
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    if params[:status].present?
      if Arte.statuses.key?(params[:status])
        scope = scope.where(status: params[:status])
      else
        raise ActionController::BadRequest, "status inválido: #{params[:status]}"
      end
    end
    if params[:month].present?
      begin
        date = Date.strptime(params[:month], "%Y-%m")
        scope = scope.where(scheduled_on: date.beginning_of_month..date.end_of_month)
      rescue Date::Error
        raise ActionController::BadRequest, "month deve ser no formato YYYY-MM"
      end
    end
    scope
  end

  def arte_params
    params.permit(
      :title, :caption, :scheduled_on, :approval_deadline,
      :external_url, :platform, :media_type, :client_id, :media_file
    )
  end

  # helpers comuns (podem ir para o base ou um concern)
  def per_page_param
    [(params[:per_page] || 25).to_i, 100].min.clamp(1, 100)
  end

  def pagination_meta(pagy)
    { page: pagy.page, per_page: pagy.limit, total_count: pagy.count, total_pages: pagy.pages }
  end
end
```

### Pattern 5: Aprovações Aninhadas

```ruby
# app/controllers/api/v1/admin/approval_responses_controller.rb
class Api::V1::Admin::ApprovalResponsesController < Api::V1::Admin::BaseController
  before_action :set_arte

  def index
    responses = @arte.approval_responses.includes(:arte)
    render_envelope(
      data: Api::V1::Admin::ApprovalResponseSerializer.serialize_collection(responses),
      meta: { arte_status: @arte.status }
    )
  end

  private

  def set_arte
    @arte = Arte.find(params[:arte_id])  # raises RecordNotFound → 404 automático
  end
end
```

### Pattern 6: Rotas

```ruby
# config/routes.rb — dentro do bloco existente namespace :admin
namespace :admin do
  resource :session, only: [:create]   # existente

  resources :clients, only: [:index, :create]
  resources :artes, only: [:index, :create] do
    resources :approval_responses, only: [:index]
  end
end
```

[VERIFIED: codebase — routes.rb existente; `defaults: { format: :json }` já declarado no namespace :api]

### Anti-Patterns to Avoid

- **Usar `params.require(:arte)` para JSON body flat:** A convenção REST JSON não encapsula params em chave do resource. O web form usa `params[:arte][:title]` porque o HTML form sempre encapsula. Nos testes da Phase 21, os params são enviados diretamente (`{ email: ..., password: ... }`). Usar `.require(:arte)` em vez de `.permit(...)` direto vai gerar `ActionController::ParameterMissing` nos clientes mobile que enviam JSON plano. [VERIFIED: codebase — sessions_controller.rb pattern]
- **Chamar `rails_blob_url` sem ter setado `ActiveStorage::Current.url_options`:** Gera `ArgumentError: Missing host to link to!` no disk service. [VERIFIED: activestorage disk_service.rb source]
- **Tentar renderizar template `.jbuilder` de um ActionController::API:** Lança `ActionController::UnknownFormat` ou `ActionView::MissingTemplate` porque `ActionController::API` não inclui `ActionView::Rendering` por padrão. [ASSUMED: comportamento documentado do Rails; não testado neste projeto]
- **Desabilitar callbacks da Arte:** O broadcast ActionCable está em `after_update_commit` e `after_create_commit` nos models `Arte` e `ApprovalResponse`. Criar via API **não deve suprimir esses callbacks** — o cliente e o admin web continuam recebendo tempo real. Não usar `Arte.skip_callback` ou similar.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paginação com total_count | Implementar SQL COUNT manual | `Pagy::Backend#pagy` + atributos `pagy.count`, `pagy.pages`, `pagy.limit` | Já instalado; `pagy.count` é o count total antes da paginação; `pagy.pages` é `alias pages last` |
| Autenticação JWT | Decode manual do header | `Api::V1::Admin::BaseController` — já implementa `before_action :authenticate_admin_jwt!` | Phase 21 entregou isso; herdar é tudo que se precisa |
| Mapeamento de erros de validação | Try/rescue manual + render | `rescue_from ActiveRecord::RecordInvalid` já em `Api::V1::BaseController` — usar `save!` ou `create!` | Cada erro do AR model (incluindo `:base`) vira um item em `errors[]` automaticamente |
| Host da URL do blob | `ENV["APP_HOST"]` ou config hardcoded | `ActiveStorage::SetCurrent` via `before_action` no base controller | Pega host/protocol/port do request real; funciona em dev, staging e prod sem config adicional |
| Geração do portal link | String interpolation manual | `request.protocol + request.host_with_port + "/c/#{client.access_token}"` | Simples e correto; a rota `client_root_url` também funciona se url_helpers estiver incluído |
| Conversão de enum para string | `Arte::STATUSES.invert[value]` | `arte.status` — AR enum já retorna string pelo nome simbólico | `Arte.statuses.key?(string)` para validar se o valor de filtro é reconhecido |

**Key insight:** O projeto tem um `rescue_from` generoso no base controller. Usar `create!`/`save!` e deixar o rescue capturar é mais limpo e consistente com o padrão sessions_controller existente.

---

## Active Storage URL em API Context (análise detalhada)

### O problema

`ActionController::API` não inclui `AbstractController::UrlFor` nem o concern `ActiveStorage::SetCurrent` por padrão. A chamada `rails_blob_url(arte.media_file)` dentro de um PORO serializer sem host configurado lança:

```
ArgumentError: Missing host to link to!
```

O disk service do Active Storage usa `ActiveStorage::Current.url_options` para pegar host/protocol/port ao gerar a URL do blob assinada.

### A solução correta

Adicionar o `before_action` no `Api::V1::Admin::BaseController` que preenche `ActiveStorage::Current.url_options` com os dados do request real:

```ruby
before_action :set_active_storage_current

def set_active_storage_current
  ActiveStorage::Current.url_options = {
    protocol: request.protocol,
    host:     request.host,
    port:     request.port
  }
end
```

[VERIFIED: activestorage-8.1.3/app/controllers/concerns/active_storage/set_current.rb — código exato do concern oficial]

### Passar url_helpers para o serializer

O serializer PORO precisa chamar `rails_blob_url(attachment)`. Em `ActionController::API`, o controller **não** inclui `Rails.application.routes.url_helpers` por padrão. Duas abordagens:

**Abordagem A (recomendada) — passar `self` como url_helpers:**
O controller inclui `Rails.application.routes.url_helpers` e passa `self` para o serializer:

```ruby
# No base_controller.rb
include Rails.application.routes.url_helpers

# No serializer, chamada:
url_helpers.rails_blob_url(arte.media_file)
```

**Abordagem B — usar `arte.media_file.url`:**
`ActiveStorage::Blob#url` também respeita `ActiveStorage::Current.url_options` (para o disk service) e gera a URL do service diretamente, sem precisar de url_helpers:

```ruby
def self.resolve_media_url(arte, _url_helpers = nil)
  if arte.media_file.attached?
    arte.media_file.url   # delega ao service; usa ActiveStorage::Current.url_options
  else
    arte.external_url
  end
end
```

[VERIFIED: activestorage-8.1.3/app/models/active_storage/blob.rb linha 235 — `def url(expires_in: ...) service.url key, ...`]

**Recomendação:** Abordagem B (`arte.media_file.url`) é mais simples — não exige incluir url_helpers no controller nem passá-los pelo serializer. O set_current before_action é suficiente.

### Variantes e disk service em desenvolvimento

- Em desenvolvimento, o `active_storage.service = :local` (disk service). O `before_action` que seta `ActiveStorage::Current.url_options` é suficiente — nenhuma config adicional em `development.rb` necessária.
- Em testes, `active_storage.service = :test` — não gera URLs reais; `media_file.attached?` retorna true mas `.url` pode retornar uma URL de test.

---

## Multipart/form-data em ActionController::API

### Como funciona

`ActionController::API` processa `multipart/form-data` nativamente via Rack — o `media_file` chega como `ActionDispatch::Http::UploadedFile` nos `params`, exatamente como no controller web.

**Interação com `defaults: { format: :json }`:** A constraint de formato no namespace define o formato *de resposta* padrão, não o formato do request. Uma requisição `Content-Type: multipart/form-data` é aceita normalmente. O `defaults: { format: :json }` não bloqueia uploads. [ASSUMED: comportamento padrão do Rack/Rails; não há config especial nos exemplos da codebase]

**Strong params para o arquivo:**

```ruby
def arte_params
  params.permit(
    :title, :caption, :scheduled_on, :approval_deadline,
    :external_url, :platform, :media_type, :client_id, :media_file
    # :media_file como símbolo simples (não array) — é um único arquivo
  )
```

`:media_file` é permitido como scalar (um único arquivo). Não precisa de `permit(media_file: [])`.

### Lógica media_source no API controller

O web controller usa `params.dig(:arte, :media_source)` para saber qual branch limpar. No API controller, o cliente mobile deve enviar **exatamente um** dos dois: `media_file` (arquivo binário) ou `external_url` (string). O controller aplica a mesma lógica:

```ruby
# No create action:
@arte.external_url = nil if params[:media_file].present?
# Se ambos vieram (erro do cliente), o model vai rejeitar via only_one_media_source
```

### Validações do model com upload via API

- `media_source_present`: `errors.add(:base, "Precisa de arquivo ou link externo")` — se nem `media_file` nem `external_url` foram enviados.
- `only_one_media_source`: `errors.add(:base, "Use arquivo OU link externo, não ambos")` — se ambos vieram.

Ambas adicionam em `:base`, não em um campo específico. O `rescue_from ActiveRecord::RecordInvalid` em `Api::V1::BaseController` itera sobre `exception.record.errors.map { |e| { code: ..., field: e.attribute.to_s } }`. Para erros em `:base`, `e.attribute` retorna `:base` — o campo será `"base"` na resposta JSON. Isso é aceitável e correto para erros de nível de objeto. [VERIFIED: codebase — base_controller.rb linhas 24-28]

---

## Filtros — Análise detalhada

### Filtro por `client_id`

```ruby
scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
```

O índice `index_artes_on_client_id` existe. Comportamento: se o `client_id` não corresponder a nenhum cliente, retorna lista vazia (não 404). Isso é consistente com o comportamento do web admin. [VERIFIED: db/schema.rb — índice confirmado]

### Filtro por `status`

```ruby
if params[:status].present?
  if Arte.statuses.key?(params[:status])
    scope = scope.where(status: params[:status])
  else
    raise ActionController::BadRequest, "status inválido: #{params[:status]}"
  end
end
```

`Arte.statuses` retorna `{ "pending" => 0, "approved" => 1, "change_requested" => 2, "revised" => 3 }`. Verificar com `.key?` antes de passar para `.where` evita `ArgumentError: '...' is not a valid status` do Rails enum. O `rescue_from ActionController::ParameterMissing` existente não captura `BadRequest` genérico — pode-se adicionar um `rescue_from ActionController::BadRequest, with: :bad_request` ou lançar `ActionController::ParameterMissing`. 

**Verificar:** `Api::V1::BaseController` já tem `rescue_from ActionController::ParameterMissing, with: :bad_request`. Usar `raise ActionController::ParameterMissing.new(:status)` garante que o rescue_from existente captura. [VERIFIED: codebase — base_controller.rb linha 6]

### Filtro por `month=YYYY-MM`

```ruby
if params[:month].present?
  begin
    date = Date.strptime(params[:month], "%Y-%m")
    scope = scope.where(scheduled_on: date.beginning_of_month..date.end_of_month)
  rescue Date::Error
    raise ActionController::ParameterMissing.new(:month)
    # ou render 422 com mensagem descritiva
  end
end
```

`Date.strptime("2025-12", "%Y-%m")` retorna `2025-12-01`. `beginning_of_month` e `end_of_month` são helpers do ActiveSupport. O campo `scheduled_on` é do tipo `date` no schema. [VERIFIED: db/schema.rb — `t.date "scheduled_on"`]

**Trade-off de tratamento de erro:** `ActionController::ParameterMissing` retorna 400 com a mensagem do exception. Alternativa: render 422 com mensagem customizada. O CONTEXT.md não especifica — usar 400 (bad_request) é semanticamente correto para formato inválido de parâmetro.

---

## Paginação com Pagy em ActionController::API

### Incluir Pagy::Backend

`Pagy::Backend` precisa ser incluído no controller. A abordagem correta é adicionar ao `Api::V1::Admin::BaseController`:

```ruby
class Api::V1::Admin::BaseController < Api::V1::BaseController
  include Pagy::Backend
  # ...
end
```

[VERIFIED: codebase — admin/base_controller.rb usa exatamente `include Pagy::Backend`]

### Chamada com per_page customizado

```ruby
@pagy, @records = pagy(scope, limit: per_page_param)
```

O parâmetro é `limit:` (não `per_page:`) — Pagy 9.x usa `limit` internamente. [VERIFIED: pagy-9.4.0/lib/pagy.rb — `DEFAULT = { limit: 20 }`]

### Atributos do objeto Pagy disponíveis

| Campo JSON | Atributo Pagy | Nota |
|------------|---------------|------|
| `page` | `pagy.page` | via `SharedMethods` attr_reader |
| `per_page` | `pagy.limit` | via `SharedMethods` attr_reader |
| `total_count` | `pagy.count` | via `Pagy` attr_reader |
| `total_pages` | `pagy.pages` | alias de `pagy.last` |

[VERIFIED: pagy-9.4.0/lib/pagy.rb linhas 27-28 e 31 — `attr_reader :count`; `alias pages last`; pagy/shared_methods.rb linha 6 — `attr_reader :page, :limit, :vars`]

### Pagy::OverflowError

Se `page` exceder `total_pages`, `Pagy` lança `Pagy::OverflowError`. É necessário capturá-lo no base controller:

```ruby
rescue_from Pagy::OverflowError, with: :page_overflow

def page_overflow
  render_error(code: "page_out_of_range", detail: "Página fora do intervalo", status: :not_found)
end
```

Ou alternativamente, usar `Pagy::DEFAULT[:overflow] = :last_page` no initializer. O projeto não tem initializer de Pagy ainda — criar `config/initializers/pagy.rb` com o padrão de comportamento. [VERIFIED: pagy-9.4.0/lib/pagy.rb — `check_overflow` levanta `OverflowError`]

---

## Routing — Configuração Exata

Adicionar dentro do bloco `namespace :admin` existente:

```ruby
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    namespace :admin do
      resource :session, only: [:create]      # existente

      # Phase 22 — novos recursos:
      resources :clients, only: [:index, :create]
      resources :artes, only: [:index, :create] do
        resources :approval_responses, only: [:index]
      end
    end
    # ... client e ai namespaces existentes ...
  end
end
```

**Rotas geradas:**

| Method | Path | Controller#Action |
|--------|------|------------------|
| GET | /api/v1/admin/clients | api/v1/admin/clients#index |
| POST | /api/v1/admin/clients | api/v1/admin/clients#create |
| GET | /api/v1/admin/artes | api/v1/admin/artes#index |
| POST | /api/v1/admin/artes | api/v1/admin/artes#create |
| GET | /api/v1/admin/artes/:arte_id/approval_responses | api/v1/admin/approval_responses#index |

O `defaults: { format: :json }` já no namespace pai garante que todas essas rotas respondem como JSON por padrão. [VERIFIED: codebase — routes.rb linha 37]

---

## Testing

### Estado da infraestrutura de testes

O projeto usa **Minitest com ActionDispatch::IntegrationTest** para os testes de API. Não há testes de sistema (Capybara/Selenium) para os controllers de API.

**Nota crítica:** Conforme memória do projeto, `bin/rails test` não roda porque o banco de teste pertence a outro usuário do SO. Verificação por inspeção confirmada — o `test_helper.rb` carrega `rails/test_help` normalmente. Os testes existentes seguem o padrão `ActionDispatch::IntegrationTest` com requests HTTP reais contra o stack Rack.

**O `nyquist_validation` está desabilitado** (`"nyquist_validation": false` em `.planning/config.json`) — a seção Validation Architecture é omitida.

### Padrão de teste estabelecido (Phase 21)

Os testes de API seguem este padrão consistente:

```ruby
# test/controllers/api/v1/admin/clients_controller_test.rb
class Api::V1::Admin::ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    @user = User.find_or_create_by!(email_address: "admin@test.com") do |u|
      u.password = u.password_confirmation = "SenhaAdmin123!"
    end
    @admin_jwt = Api::JwtService.encode({ sub: @user.id.to_s, scope: "admin" })
    @auth_header = { "Authorization" => "Bearer #{@admin_jwt}",
                     "Content-Type"  => "application/json" }
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  test "GET /api/v1/admin/clients retorna 200 com lista paginada" do
    get "/api/v1/admin/clients", headers: @auth_header
    assert_equal 200, response.status
    body = response.parsed_body
    assert body.dig("meta", "pagination", "total_count").present?
    assert_equal [], body["errors"]
  end
end
```

[VERIFIED: codebase — base_controller_test.rb e sessions_controller_test.rb — padrão JWT_SECRET injection + JwtService.encode]

### Upload multipart em testes

Para testar POST com upload de arquivo:

```ruby
test "POST /api/v1/admin/artes com media_file retorna 201" do
  file = fixture_file_upload(
    Rails.root.join("test/fixtures/files/sample.jpg"),
    "image/jpeg"
  )
  post "/api/v1/admin/artes",
       params: {
         title:        "Arte Teste",
         scheduled_on: Date.current.to_s,
         platform:     "instagram",
         media_type:   "image",
         client_id:    @client.id,
         media_file:   file
       },
       headers: { "Authorization" => "Bearer #{@admin_jwt}" }
       # Sem Content-Type — Rack detecta multipart automaticamente com UploadedFile

  assert_equal 201, response.status
  body = response.parsed_body
  assert body.dig("data", "media_url").present?
  assert_equal "upload", body.dig("data", "media_source_type")
end
```

**Atenção:** Quando `params` inclui um `UploadedFile`, **não passar** `Content-Type: application/json` — o Rack detecta multipart automaticamente. Passar `application/json` com `multipart` vai quebrar o parsing. [ASSUMED: comportamento Rails/Rack padrão; confirmado pelo uso em test/controllers/admin/ existentes]

**Fixtures:** Criar `test/fixtures/files/sample.jpg` (arquivo mínimo JPEG válido). Como o projeto ainda não tem arquivos em `test/fixtures/files/` (a pasta existe mas está vazia), este fixture precisa ser criado.

### Estrutura de arquivos de teste recomendada

```
test/controllers/api/v1/admin/
├── base_controller_test.rb       (existente)
├── sessions_controller_test.rb   (existente)
├── clients_controller_test.rb    (NOVO)
├── artes_controller_test.rb      (NOVO)
└── approval_responses_controller_test.rb  (NOVO)
```

### Cobertura mínima por controller

**clients_controller_test.rb:**
- `GET index` autenticado → 200 + `meta.pagination` presente
- `GET index` sem auth → 401
- `GET index` com `?page=1&per_page=2` → pagination.per_page == 2
- `POST create` com dados válidos → 201 + `data.portal_url` + `data.password` presentes
- `POST create` sem nome → 422 + `errors` presente
- `GET index` nunca retorna `data[*].password` nem `data[*].portal_url`

**artes_controller_test.rb:**
- `GET index` → 200 com lista
- `GET index?client_id=X` → filtra por cliente
- `GET index?status=approved` → filtra por status
- `GET index?status=invalido` → 400
- `GET index?month=2025-12` → filtra por mês
- `GET index?month=nao-data` → 400
- `POST create` com `external_url` → 201 + `media_source_type == "link"`
- `POST create` com `media_file` → 201 + `media_url` presente (ActiveStorage)
- `POST create` sem nenhuma mídia → 422 com erro em `base`
- `POST create` com ambos → 422 com erro `only_one_media_source`

**approval_responses_controller_test.rb:**
- `GET /api/v1/admin/artes/:id/approval_responses` → 200 com lista
- Arte inexistente → 404
- Cada item tem `decision`, `comment`, `responded_at`, `arte_status`

---

## Common Pitfalls

### Pitfall 1: Missing host ao gerar rails_blob_url

**O que dá errado:** `ArgumentError: Missing host to link to!` no serializer ao chamar `arte.media_file.url` ou `rails_blob_url(arte.media_file)`.
**Por que acontece:** `ActiveStorage::Current.url_options` está vazio; o disk service precisa do host para assinar a URL.
**Como evitar:** `before_action` no base admin que seta `ActiveStorage::Current.url_options`. Verificar que o before_action roda *antes* do action (ordem importa).
**Sinais precoces:** Testes com `external_url` passam, testes com `media_file` falham com ArgumentError.

### Pitfall 2: `params.require(:arte)` em JSON body flat

**O que dá errado:** `ActionController::ParameterMissing (param is missing or the value is empty: arte)` em todos os requests do app mobile.
**Por que acontece:** App mobile envia `{ "title": "...", "client_id": 1 }` (root-level), não `{ "arte": { "title": "..." } }`.
**Como evitar:** Usar `params.permit(...)` diretamente sem `.require(:arte)`. Ver padrão do sessions_controller existente.

### Pitfall 3: Content-Type: application/json + multipart

**O que dá errado:** Upload falha silenciosamente; `params[:media_file]` é `nil`; `media_source_present` falha com 422.
**Por que acontece:** Enviar `Content-Type: application/json` com body multipart faz o Rack tentar parsear como JSON e ignorar os dados do arquivo.
**Como evitar:** Nos testes, não setar `Content-Type` quando incluir um `fixture_file_upload`. No app mobile, usar `multipart/form-data` para upload.
**Sinais precoces:** `params[:media_file].nil?` no debugger mesmo com arquivo enviado.

### Pitfall 4: ActionCable callbacks em ambiente de teste

**O que dá errado:** Teste de `POST /artes` falha com erro de ActionCable broadcasting porque `User.order(:id).first` retorna nil em ambiente de testes (nenhum user criado).
**Por que acontece:** `Arte.after_update_commit :broadcasts_revised_to_all` e `ApprovalResponse.after_create_commit :broadcasts_to_admin` tentam renderizar partials e broadcast — se não houver admin, o guard `return unless admin` previne o erro, mas depende de ter o User setup correto.
**Como evitar:** Criar `@user` no `setup` dos testes de arte, mesmo que não seja usado para auth do test (o callback precisa de um admin para encontrar).
**Sinais precoces:** Erro em `Arte#broadcasts_revised_to_all` ou `ApprovalResponse#broadcasts_to_admin` nos logs de teste.

### Pitfall 5: Pagy::OverflowError sem rescue

**O que dá errado:** Request com `?page=999` (além do total) retorna 500 em vez de 404 ou 400.
**Por que acontece:** `Pagy` lança `Pagy::OverflowError` quando `page > last`.
**Como evitar:** Adicionar `rescue_from Pagy::OverflowError` no base controller ou configurar `Pagy::DEFAULT[:overflow] = :last_page` no initializer.

### Pitfall 6: `password_plain` não sendo salvo

**O que dá errado:** `data.password` na resposta do POST create é `nil` mesmo após criar o cliente.
**Por que acontece:** O web controller faz `params_with_plain.merge(password_plain: params_with_plain[:password])` para salvar o plain no campo `password_plain`. O API controller precisa replicar esta lógica.
**Como evitar:** No `create` do clients controller, após `Client.new(client_params)`, setar `@client.password_plain = params[:password]` antes do `save!`.
**Sinais precoces:** `data.password` é `nil` no JSON de resposta do POST.

---

## Code Examples

### Exemplo completo: serializer com media_url

```ruby
# app/serializers/api/v1/admin/arte_serializer.rb
module Api::V1::Admin::ArteSerializer
  def self.serialize(arte)
    {
      id:            arte.id,
      title:         arte.title,
      caption:       arte.caption,
      scheduled_on:  arte.scheduled_on,
      approval_deadline: arte.approval_deadline,
      platform:      arte.platform,
      media_type:    arte.media_type,
      status:        arte.status,
      client_id:     arte.client_id,
      media_url:         resolve_media_url(arte),
      media_source_type: arte.media_file.attached? ? "upload" : "link",
      created_at:    arte.created_at,
      updated_at:    arte.updated_at
    }
  end

  def self.serialize_collection(artes)
    artes.map { |a| serialize(a) }
  end

  private_class_method def self.resolve_media_url(arte)
    # Depende de ActiveStorage::Current.url_options estar setado pelo before_action
    # Source: activestorage-8.1.3 blob.rb#url — delega ao service usando Current.url_options
    if arte.media_file.attached?
      arte.media_file.url
    else
      arte.external_url
    end
  end
end
```

### Exemplo: pagination_meta helper compartilhado

```ruby
# Pode ser um concern ou método no base controller
def pagination_meta(pagy)
  {
    page:        pagy.page,     # pagy.vars[:page] = current page integer
    per_page:    pagy.limit,    # pagy.vars[:limit]
    total_count: pagy.count,    # total de registros antes da paginação
    total_pages: pagy.pages     # alias de pagy.last (ceil(count/limit))
  }
end
```

### Exemplo: portal_url no create de cliente

```ruby
def create
  @client = Client.new(client_params)
  @client.password_plain = params[:password]  # salva plain para resposta única
  @client.save!
  render_envelope(
    data: Api::V1::Admin::ClientSerializer.serialize(
      @client,
      include_credentials: true,
      portal_host: "#{request.protocol}#{request.host_with_port}"
    ),
    status: :created
  )
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `pagy(scope, items: N)` | `pagy(scope, limit: N)` | Pagy 7.x → 8.x | Parâmetro renomeado; usar `limit:` |
| `ActiveStorage::Blob#service_url` | `ActiveStorage::Blob#url` | Rails 6 → 7 | `service_url` depreciado; usar `#url` |
| `rescue_from` em cada controller | `rescue_from` no base controller | Padrão Rails | Já implementado corretamente no projeto |

**Deprecated/outdated:**
- `params[:per_page]` como nome de parâmetro interno do Pagy: o Pagy usa `limit` internamente; o query param pode ser `per_page` mas o `pagy()` recebe `limit:` na chamada Ruby.
- `include Pagy::Frontend` em controllers de API: o Frontend é para renderizar HTML de navegação; controllers de API só precisam do Backend.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `jbuilder` em `ActionController::API` requer workaround (não funciona out-of-the-box) | Anti-Patterns, Standard Stack | Baixo — PORO é mais simples de qualquer forma |
| A2 | App mobile envia params JSON flat (root-level) sem wrapper de resource | Pattern 3, Pitfall 2 | Alto — se o app enviar `{ arte: {...} }`, o `params.permit(...)` direto ignoraria os campos. Confirmar com equipe de mobile |
| A3 | Alba/Blueprinter não agregam valor para 3 recursos neste projeto | Standard Stack | Baixo — são gems corretas; apenas julgamento de escopo |
| A4 | `Content-Type: multipart/form-data` sem `Content-Type: application/json` funciona com `defaults: { format: :json }` no namespace | Multipart section | Médio — se o Rack rejeitar multipart por causa do defaults, precisaria investigar `skip_before_action` ou remover o default para a rota de upload |
| A5 | `fixture_file_upload` está disponível em `ActionDispatch::IntegrationTest` | Testing section | Baixo — é helper padrão do Rails |

---

## Open Questions

1. **Formato dos params do app mobile (flat vs. nested)**
   - O que sabemos: O padrão Phase 21 usa params flat (`{ email: ..., password: ... }`)
   - O que não está claro: Se o app mobile vai enviar `{ title: ..., client_id: ... }` ou `{ arte: { title: ..., client_id: ... } }`
   - Recomendação: Implementar sem wrapper (flat), documentar na resposta da API que o padrão é flat. Se o mobile precisar de wrapper, basta trocar `params.permit(...)` por `params.require(:arte).permit(...)`.

2. **Resposta do GET /clients inclui `password_plain`?**
   - O que sabemos: D-04 diz que GET nunca retorna senha. `password_plain` está na coluna do banco.
   - O que não está claro: O campo `password_plain` no banco existe para mostrar no web admin — no contexto de API o admin mobile precisaria de alguma forma de ver a senha depois? A decisão D-04 diz não.
   - Recomendação: GET retorna apenas `id, name, active, created_at`. Implementar conforme D-04.

3. **Pagy::OverflowError — 404 ou 400?**
   - O que sabemos: É um erro de parâmetro inválido (page fora do range)
   - O que não está claro: O cliente mobile deve tratar como "recurso não encontrado" (404) ou "request inválido" (400)?
   - Recomendação: 404 é mais idiomático para "a página N não existe neste contexto"; usar `render_error(code: "page_out_of_range", status: :not_found)`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Pagy gem | Paginação (D-08) | ✓ | 9.4.0 | — |
| jbuilder gem | Serialização (se usado) | ✓ | 2.15.0 | Não usado — PORO adotado |
| Active Storage | Upload (D-01) | ✓ | 8.1.3 (bundled) | — |
| image_processing gem | Variantes Active Storage | ✓ | ~1.2 (Gemfile) | — |
| PostgreSQL | Banco de dados | ✓ | (verificar com pg_isready) | — |

---

## Security Domain

> `security_enforcement: true` e `security_asvs_level: 1` em `.planning/config.json`.

### Applicable ASVS Categories (ASVS Level 1)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Sim | JWT via `Api::V1::Admin::BaseController#authenticate_admin_jwt!` — Phase 21 entregou |
| V3 Session Management | Não | API é stateless (JWT); sem sessão de servidor |
| V4 Access Control | Sim | Todos os endpoints exigem scope `admin`; verificado no BaseController |
| V5 Input Validation | Sim | `params.permit()` (strong params); model validations; enum guard para status |
| V6 Cryptography | Indireta | `has_secure_password` (bcrypt) para senha do cliente; JWT com HS256 — Phase 21 |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Criação de cliente com senha fraca | Spoofing | Validação mínima de senha no model (verificar se existe — `Client` usa apenas `has_secure_password` sem validates_length) |
| Exposição de `password_plain` em GET | Information Disclosure | Serializer retorna `password_plain` apenas no POST create (D-04/D-05) |
| Upload de arquivo malicioso | Tampering | `active_storage_validations` gem está no Gemfile; adicionar validação de content_type e tamanho máximo no model Arte para o campo `media_file` |
| Acesso cross-client (cliente A vê arte do cliente B) | Elevation | O endpoint de artes mostra todos os clientes (admin vê tudo) — correto por design; mas ApprovalResponses deve escopar pelo arte_id |
| Enumeração de clientes por ID sequencial | Information Disclosure | IDs são inteiros sequenciais (PG bigserial) — baixo risco para API admin autenticada |
| Injection via filtro `client_id` | Tampering | `where(client_id: params[:client_id])` é seguro — AR usa parameterized query |
| `month` injection | Tampering | `Date.strptime` valida o formato antes de passar para WHERE; range seguro |

**Verificar no modelo Arte:** Se `active_storage_validations` já aplica limites de content_type/tamanho ao `media_file`. Se não houver validação, um arquivo executável poderia ser armazenado. Recomendado adicionar:

```ruby
# app/models/arte.rb
validates :media_file,
  content_type: { in: %w[image/jpeg image/png image/gif video/mp4 video/quicktime], message: "deve ser imagem ou vídeo" },
  size: { less_than: 50.megabytes, message: "deve ter menos de 50MB" },
  if: -> { media_file.attached? }
```

[ASSUMED: necessidade da validação — o projeto tem `active_storage_validations` no Gemfile mas não foi verificado se já está aplicado no model Arte]

---

## Sources

### Primary (HIGH confidence)
- `app/controllers/api/v1/base_controller.rb` — rescue_from, render_envelope, render_error
- `app/controllers/api/v1/admin/base_controller.rb` — authenticate_admin_jwt!, bearer_token
- `app/controllers/api/v1/admin/sessions_controller.rb` — padrão de uso de render_envelope
- `app/models/arte.rb` — enums, validações, callbacks, has_one_attached
- `app/models/client.rb` — has_secure_token, has_secure_password
- `app/models/approval_response.rb` — enum decision, responded_at, callbacks
- `db/schema.rb` — tipos de coluna, índices
- `config/routes.rb` — estrutura existente do namespace api/v1/admin
- `vendor/bundle/.../pagy-9.4.0/lib/pagy.rb` — attr_reader :count; alias pages last; attr_reader :page, :limit
- `vendor/bundle/.../activestorage-8.1.3/app/controllers/concerns/active_storage/set_current.rb` — mecanismo de host config
- `vendor/bundle/.../activestorage-8.1.3/app/models/active_storage/blob.rb` — `#url` method
- `vendor/bundle/.../activestorage-8.1.3/config/routes.rb` — `direct :rails_blob`
- `test/controllers/api/v1/admin/` — padrão de teste JWT_SECRET injection

### Secondary (MEDIUM confidence)
- `app/controllers/admin/artes_controller.rb` — referência para arte_params e media_source logic
- `app/controllers/admin/clients_controller.rb` — referência para client_params e password_plain pattern
- `app/controllers/admin/approvals_controller.rb` — padrão pagy(scope, limit: 25)

### Tertiary (LOW confidence — assumptions)
- Comportamento de `multipart/form-data` com `defaults: { format: :json }` (A4)
- Necessidade de validação de content_type no media_file (A5 do security domain)

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — tudo verificado na codebase e gemfiles
- Architecture: HIGH — baseado no código existente da Phase 21
- Serialization recommendation: MEDIUM — PORO é padrão sólido mas jbuilder é alternativa válida
- Active Storage URL: HIGH — código do concern oficial lido diretamente
- Pagy API: HIGH — código fonte lido diretamente
- Testing patterns: HIGH — tests existentes da Phase 21 servem de template exato
- Security/pitfalls: MEDIUM — pitfalls baseados em análise de código e comportamento padrão do Rails

**Research date:** 2026-06-11
**Valid until:** 2026-07-11 (stack estável; pagy 9.x e Rails 8.1 sem breaking changes esperados neste prazo)
