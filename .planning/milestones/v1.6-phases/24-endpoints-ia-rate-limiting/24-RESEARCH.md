# Phase 24: Endpoints IA + Rate Limiting - Research

**Researched:** 2026-06-12
**Domain:** Rails API controllers, Rack::Attack throttling, PORO serializers, Pagy pagination
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**APIAI-01 — Listagem de artes aprovadas:**
- D-01: Filtro `from` + `to` em ISO 8601 (`YYYY-MM-DD`), e.g. `?from=2026-06-01&to=2026-06-30`
- D-02: Filtro de período obrigatório — sem `from`/`to` retorna 400 estruturado
- D-03: Filtro por `client_id` opcional (padrão Phase 22)
- D-04: Somente artes com `status: :approved`; paginação Pagy default 25 / teto 100
- D-05: Ordenação `scheduled_on: :asc`

**APIAI-02 — Inserção de arte pela IA:**
- D-06: Payload aceita `{ title, caption, scheduled_on, approval_deadline, platform, media_type, client_id, external_url }`; `media_file` não suportado — recebê-lo retorna 400
- D-07: Reutiliza modelo `Arte` com suas validações (`only_one_media_source`, `media_source_present`); resposta 201 com arte criada
- D-08: `external_url` é obrigatório neste endpoint (validação do model já garante)

**APIAI-03 — Resumo por cliente:**
- D-09: Rota `GET /api/v1/ai/clients/:id/summary` — sem filtro de período
- D-10: Resposta inclui `{ total, approved_count, pending_count, change_requested_count }` (+ `revised_count` a critério do planejamento)
- D-11: Cliente inexistente → 404 estruturado via `rescue_from RecordNotFound`

**INFAPI-04 — Rate limiting:**
- D-12: Throttle somente no namespace `/api/v1/ai/*`
- D-13: Limite 60 req/min por API key (`ak_…` extraído do header `Authorization`)
- D-14: Resposta 429 reutiliza o `Rack::Attack.throttled_responder` já configurado (JSON estruturado)
- D-15: Sem burst especial — janela 60s, 60 requisições flat

### Claude's Discretion

- Nome exato do throttle no Rack::Attack (e.g. `"api/ai_by_key"`)
- Se criar `Api::V1::Ai::ArteSerializer` dedicado ou reusar o admin
- `Arte.where(client_id: id).group(:status).count` vs `client.artes.group(:status).count` para o summary
- `revised_count` no resumo — incluir ou não

### Deferred Ideas (OUT OF SCOPE)

- Rate limiting para namespaces admin/client
- Upload multipart pela IA
- Filtro de período no resumo APIAI-03
- Burst allowance para a IA
- Documentação OpenAPI/Swagger
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APIAI-01 | IA lista artes aprovadas com filtros de período (`from`/`to` obrigatório) | Adaptação de `apply_filters` do admin; índice em `status` + `scheduled_on` já existe |
| APIAI-02 | IA insere nova arte para aprovação (mesmo payload do admin, sem `media_file`) | Reutiliza `Arte.new(arte_params)` + `save!`; validações do model garantem consistência |
| APIAI-03 | IA lê resumo do estado das aprovações por cliente (total, aprovadas, pendentes, alteração) | Query `Arte.where(client_id:).group(:status).count` — simples e direto |
| INFAPI-04 | Rate limiting por API key/token — 429 quando excede limite | Throttle Rack::Attack já configurado; só adicionar entrada para namespace `/api/v1/ai/*` |
</phase_requirements>

---

## Summary

Esta fase é inteiramente de extensão sobre infraestrutura já existente. Todas as peças fundamentais (autenticação da IA, base da API, envelope JSON, Pagy, Rack::Attack) foram implementadas nas Phases 21-23. O trabalho consiste em: (1) preencher o namespace `api/v1/ai` em routes.rb com 3 endpoints, (2) criar `Api::V1::Ai::BaseController` que inclua Pagy e os helpers de paginação como admin e client fazem, (3) criar os dois controllers (`ArtesController`, `ClientsController`) e o serializer de artes para a IA, e (4) adicionar um único throttle em `config/initializers/rack_attack.rb`.

Nenhuma gem nova é necessária. O padrão de serializer PORO já está estabelecido para admin e client. O `Api::V1::Ai::BaseController` já tem `authenticate_ai_key!` mas ainda não inclui Pagy nem os helpers de paginação — isso precisa ser adicionado para suportar APIAI-01. A decisão de criar serializer dedicado vs reutilizar o admin é de baixo risco: os campos são idênticos, mas um módulo separado (`Api::V1::Ai::ArteSerializer`) evita acoplamento entre namespaces.

**Recomendação primária:** Criar `Api::V1::Ai::ArteSerializer` dedicado copiando o admin (campos idênticos, isolamento de namespace); expandir `Api::V1::Ai::BaseController` com Pagy e helpers; implementar os 3 controllers; adicionar o throttle ao `rack_attack.rb` existente.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Autenticação da IA | API / Backend | — | `authenticate_ai_key!` já no `Ai::BaseController` |
| Listagem de artes aprovadas (APIAI-01) | API / Backend | Database / Storage | Query filtrada e paginada, serialização PORO |
| Inserção de arte pela IA (APIAI-02) | API / Backend | Database / Storage | Persistência via model `Arte` com validações |
| Resumo de aprovações por cliente (APIAI-03) | API / Backend | Database / Storage | Aggregate query `group(:status).count` |
| Rate limiting (INFAPI-04) | API / Backend (Rack middleware) | — | Rack::Attack opera na camada Rack, antes do controller |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rack-attack | 6.8.0 [VERIFIED: npm registry] | Rate limiting / throttling por Rack middleware | Já instalado e configurado no projeto; gem padrão para throttle Rails |
| pagy | 9.4.0 [VERIFIED: npm registry] | Paginação | Já instalado e em uso nos namespaces admin e client |
| Rails 8.1.3 | 8.1.3 | Framework | Stack do projeto; ActionController::API, rescue_from, etc |

> Nota: "npm registry" aqui indica verificação via `bundle exec gem list`. As gems são Ruby — a tag reflete verificação local contra instalação real.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ActiveSupport::SecurityUtils | (Rails built-in) | `secure_compare` para API key | Já usado em `Ai::BaseController` — não reimplementar |
| ActiveStorage::Current | (Rails built-in) | Resolver `media_url` absoluta | Necessário para `media_file.url` sem raise `Missing host` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Pagy no namespace AI | Kaminari | Pagy já instalado e em uso — sem motivo para trocar |
| PORO serializer | ActiveModelSerializers / jsonapi-serializer | PORO já é o padrão estabelecido nas Phases 22/23; mais simples |
| `group(:status).count` para summary | N+1 queries individuais | Aggregate query é a forma correta — O(1) vs O(N) |

**Installation:** Nenhuma gem nova necessária. Todas as dependências já estão no Gemfile e instaladas.

---

## Package Legitimacy Audit

Nenhum pacote novo é instalado nesta fase. Toda a infraestrutura de gems (rack-attack, pagy, jwt, rails) já está no Gemfile e foi instalada nas fases anteriores.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
HTTP Request (Bearer ak_...)
         |
         v
  Rack::Attack middleware
  throttle("api/ai_by_key", 60/60s) <-- NOVO (INFAPI-04)
  identifica por req.get_header("HTTP_AUTHORIZATION") strip
         |
         | > 60 req/min → 429 JSON (throttled_responder já configurado)
         | <= limite → pass-through
         v
  Api::V1::Ai::BaseController#authenticate_ai_key!
  (secure_compare token vs credentials.api.ai_key)
         |
         | inválido → 401 JSON
         | válido → pass-through
         v
  ┌──────────────────────────────────────────┐
  │  GET /api/v1/ai/artes?from=&to=          │  APIAI-01
  │  Arte.approved.where(scheduled_on: range) │
  │  paginado Pagy, serializado PORO          │
  └──────────────────────────────────────────┘
  ┌──────────────────────────────────────────┐
  │  POST /api/v1/ai/artes                   │  APIAI-02
  │  Arte.new(arte_params), save!            │
  │  external_url obrigatório; media_file→400│
  └──────────────────────────────────────────┘
  ┌──────────────────────────────────────────┐
  │  GET /api/v1/ai/clients/:id/summary      │  APIAI-03
  │  Arte.where(client_id:).group(:status)   │
  │  .count → { total, approved_count, ... } │
  └──────────────────────────────────────────┘
         |
         v
  render_envelope (data:, meta:, errors:[])
  (herança de Api::V1::BaseController)
```

### Recommended Project Structure

```
app/
├── controllers/api/v1/ai/
│   ├── base_controller.rb          # já existe — adicionar Pagy + helpers
│   ├── artes_controller.rb         # NOVO — APIAI-01 + APIAI-02
│   └── clients_controller.rb       # NOVO — APIAI-03
├── serializers/api/v1/ai/
│   └── arte_serializer.rb          # NOVO — PORO, idêntico ao admin mas isolado
config/
└── initializers/
    └── rack_attack.rb              # editar — adicionar throttle ai_by_key
config/
└── routes.rb                       # editar — preencher namespace :ai
test/controllers/api/v1/ai/
├── base_controller_test.rb         # NOVO (opcional, auth já testada em Phase 21)
├── artes_controller_test.rb        # NOVO
└── clients_controller_test.rb      # NOVO
test/integration/
└── rack_attack_test.rb             # editar — adicionar casos de teste para throttle AI
```

### Pattern 1: Ai::BaseController com Pagy e helpers

**What:** Expandir o `Ai::BaseController` existente para incluir `Pagy::Backend` e os helpers de paginação, espelhando o padrão admin e client.

**When to use:** Sempre que o controller da IA precisar de paginação (APIAI-01) ou serializar artes com `media_file` (precisa de `set_active_storage_current`).

**Example:**
```ruby
# app/controllers/api/v1/ai/base_controller.rb
# Source: padrão estabelecido em Api::V1::Admin::BaseController e Api::V1::Client::BaseController
class Api::V1::Ai::BaseController < Api::V1::BaseController
  include Pagy::Backend
  before_action :authenticate_ai_key!
  before_action :set_active_storage_current

  rescue_from Pagy::OverflowError, with: :page_overflow

  private

  def authenticate_ai_key!
    # ... (já implementado — não alterar)
  end

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

### Pattern 2: ArtesController — filtro from/to + approved

**What:** `GET /api/v1/ai/artes` filtra por status `approved` e período ISO 8601 obrigatório.

**Example:**
```ruby
# app/controllers/api/v1/ai/artes_controller.rb
# Source: adaptação de Api::V1::Admin::ArtesController#apply_filters (Phase 22)
class Api::V1::Ai::ArtesController < Api::V1::Ai::BaseController
  def index
    validate_period_params!
    scope = Arte.approved.order(scheduled_on: :asc)
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    from  = Date.parse(params[:from])
    to    = Date.parse(params[:to])
    scope = scope.where(scheduled_on: from..to)
    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Ai::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  rescue Date::Error
    render_error(code: "bad_request", detail: "Formato de data inválido. Use YYYY-MM-DD.", status: :bad_request)
  end

  def create
    if params[:media_file].present?
      return render_error(code: "bad_request",
                          detail: "Upload de arquivo não é suportado. Use external_url.",
                          status: :bad_request)
    end
    @arte = Arte.new(arte_params)
    @arte.save!
    render_envelope(data: Api::V1::Ai::ArteSerializer.serialize(@arte), status: :created)
  end

  private

  def validate_period_params!
    unless params[:from].present? && params[:to].present?
      raise ActionController::ParameterMissing.new("from e to são obrigatórios")
    end
  end

  def arte_params
    params.permit(:title, :caption, :scheduled_on, :approval_deadline,
                  :external_url, :platform, :media_type, :client_id)
  end
end
```

### Pattern 3: ClientsController — summary aggregate

**What:** `GET /api/v1/ai/clients/:id/summary` retorna contagens por status para um cliente específico.

**Example:**
```ruby
# app/controllers/api/v1/ai/clients_controller.rb
class Api::V1::Ai::ClientsController < Api::V1::Ai::BaseController
  def summary
    client = Client.find(params[:id])  # rescue_from RecordNotFound → 404
    counts = Arte.where(client_id: client.id).group(:status).count
    # Arte.statuses = { "pending" => 0, "approved" => 1, "change_requested" => 2, "revised" => 3 }
    total = counts.values.sum
    render_envelope(data: {
      client_id:              client.id,
      total:                  total,
      approved_count:         counts["approved"].to_i,
      pending_count:          counts["pending"].to_i,
      change_requested_count: counts["change_requested"].to_i,
      revised_count:          counts["revised"].to_i
    })
  end
end
```

### Pattern 4: Throttle Rack::Attack por API key no namespace AI

**What:** Adicionar throttle na posição correta do `rack_attack.rb` — após os throttles de login existentes e antes do `throttled_responder`.

**Example:**
```ruby
# config/initializers/rack_attack.rb — adicionar este bloco
# Source: padrão do arquivo existente + D-13 do CONTEXT.md
throttle("api/ai_by_key", limit: 60, period: 60) do |req|
  if req.path.start_with?("/api/v1/ai/")
    req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip.presence
  end
end
```

Ponto crítico: este throttle retorna `nil` se o token estiver ausente (autenticação rejeitará primeiro com 401 antes do throttle ser relevante). O `throttled_responder` existente já trata `/api/` com JSON estruturado — sem alteração necessária.

### Pattern 5: Serializer PORO dedicado para IA

**What:** Módulo PORO isolado no namespace IA, idêntico em campos ao admin mas independente.

**Example:**
```ruby
# app/serializers/api/v1/ai/arte_serializer.rb
# Source: espelho de app/serializers/api/v1/admin/arte_serializer.rb (Phase 22)
module Api::V1::Ai::ArteSerializer
  def self.serialize(arte)
    {
      id:                arte.id,
      title:             arte.title,
      caption:           arte.caption,
      scheduled_on:      arte.scheduled_on,
      approval_deadline: arte.approval_deadline,
      platform:          arte.platform,
      media_type:        arte.media_type,
      status:            arte.status,
      client_id:         arte.client_id,
      media_url:         resolve_media_url(arte),
      media_source_type: arte.media_file.attached? ? "upload" : (arte.external_url.present? ? "link" : nil),
      created_at:        arte.created_at,
      updated_at:        arte.updated_at
    }
  end

  def self.serialize_collection(artes)
    artes.map { |a| serialize(a) }
  end

  private_class_method def self.resolve_media_url(arte)
    arte.media_file.attached? ? arte.media_file.url : arte.external_url
  end
end
```

### Anti-Patterns to Avoid

- **Não testar throttle sem `Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new`:** O initializer já configura isso para `test`, mas o teste de integração do throttle AI deve fazer `Rack::Attack.cache.store.clear` no `setup` para evitar estado remanescente de outros testes.
- **Não usar `Arte.approved.where(status: :approved)`:** Redundante — `Arte.approved` já é o scope correto via enum. Usar `.where(status: Arte.statuses[:approved])` ou simplesmente `.approved`.
- **Não omitir `set_active_storage_current` no Ai::BaseController:** Sem isso, qualquer arte com `media_file` attached gera `Missing host to link to` ao serializar.
- **Não usar `validate_period_params!` com `raise ActionController::ParameterMissing`:** O `rescue_from ActionController::ParameterMissing, with: :bad_request` no `BaseController` já trata isso e devolve 400 estruturado. Conveniente reutilizar.
- **Não parsear `from`/`to` sem `rescue Date::Error`:** Strings malformadas levantam `Date::Error`; capturar e retornar 400 estruturado (ver padrão do admin para `month` em Phase 22).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Paginação | Loop manual / OFFSET sem LIMIT | Pagy (já instalado) | Pagy gerencia overflow, meta, window automático |
| Rate limiting | Contador manual em Redis/cache | Rack::Attack (já instalado) | Janela deslizante, isolamento por key, responder configurável |
| Comparação de API key | `token == expected` | `ActiveSupport::SecurityUtils.secure_compare` | Previne timing attacks; já em uso no `Ai::BaseController` |
| Resolução de URL de media | Construir URL manualmente | `arte.media_file.url` com `ActiveStorage::Current` configurado | `url` usa `Current.url_options` injetado pelo `set_active_storage_current` |
| Contagem por status | N+1 queries | `Arte.where(...).group(:status).count` | Uma query SQL com GROUP BY |

---

## Common Pitfalls

### Pitfall 1: Missing host ao serializar artes com media_file

**What goes wrong:** `arte.media_file.url` levanta `ActionController::RoutingError: Missing host to link to` se `ActiveStorage::Current.url_options` não estiver configurado.

**Why it happens:** `ActiveStorage::Current` é thread-local e não é populado automaticamente em controllers que herdam de `ActionController::API` (ao contrário de `ActionController::Base`).

**How to avoid:** Adicionar `before_action :set_active_storage_current` no `Ai::BaseController` — idêntico ao admin e client. [VERIFIED: codebase — admin e client base controllers já usam este padrão]

**Warning signs:** Teste falha com `Missing host to link to!` ao acessar `media_url` para artes com `media_file`.

---

### Pitfall 2: Throttle retorna nil para requests não-AI — sem efeito colateral

**What goes wrong:** O bloco do throttle não retornar `nil` explicitamente para paths fora de `/api/v1/ai/` faz o Rack::Attack throttlar todos os outros endpoints também.

**Why it happens:** Rack::Attack throttla quando o bloco retorna qualquer valor não-nil/falsy.

**How to avoid:** Usar `if req.path.start_with?("/api/v1/ai/")` dentro do bloco (retorna nil implicitamente quando a condição não é satisfeita). [VERIFIED: codebase — padrão já usado nos throttles existentes]

---

### Pitfall 3: Rack::Attack cache não resetado em testes

**What goes wrong:** Testes de throttle acumulam contagens de outros testes — o 1º hit já pode retornar 429.

**Why it happens:** `ActiveSupport::Cache::MemoryStore` persiste entre testes na mesma sessão quando não limpa.

**How to avoid:** Chamar `Rack::Attack.cache.store.clear` no `setup` de qualquer teste de throttle. [VERIFIED: codebase — `rack_attack_test.rb` usa `MemoryStore` sem `.clear`; testes de controller que fazem múltiplos `post` usam `.clear` no setup]

---

### Pitfall 4: from/to com formato inválido não capturado

**What goes wrong:** `Date.parse("not-a-date")` levanta `Date::Error` sem tratamento → 500 internal server error.

**Why it happens:** `Date.parse` não é tolerante a entradas inválidas.

**How to avoid:** Capturar `Date::Error` no `index` action do `ArtesController` e retornar `render_error(..., status: :bad_request)`. [VERIFIED: codebase — admin usa `Date.strptime` com `rescue Date::Error` para o filtro `month`]

---

### Pitfall 5: Arte.approved em vez de Arte.where(status: :pending) — diferença semântica

**What goes wrong:** Usar scope errado no index de artes da IA (ex: esquecer o filtro `approved` e retornar todas as artes).

**Why it happens:** `Arte.all` ou `Arte.includes(:client)` sem filtro de status retorna pending/change_requested/revised também.

**How to avoid:** Iniciar o scope com `Arte.approved` — o enum Rails gera este scope automaticamente. [VERIFIED: codebase — `Arte` define `enum :status, { pending: 0, approved: 1, ... }` que gera `.approved` scope]

---

### Pitfall 6: Indice de performance para APIAI-01

**What goes wrong:** A query `Arte.approved.where(scheduled_on: from..to)` pode fazer full scan em tabelas grandes.

**Why it happens:** O índice existente é `index_artes_on_status` (status isolado) e `index_artes_on_client_id_and_scheduled_on` (client + date). Não há índice composto `(status, scheduled_on)`.

**How to avoid:** Para o volume atual (projeto em produção inicial), o índice em `status` filtra suficientemente. Se `status=approved` representar uma fração pequena das artes, o índice em status funciona. Monitorar e adicionar índice composto `(status, scheduled_on)` se `EXPLAIN ANALYZE` mostrar seq scan custoso. [ASSUMED — decisão de adicionar índice fica a critério do planejamento]

---

## Code Examples

### Throttle Rack::Attack — extrair token do header

```ruby
# Source: config/initializers/rack_attack.rb (padrão existente adaptado para AI)
throttle("api/ai_by_key", limit: 60, period: 60) do |req|
  if req.path.start_with?("/api/v1/ai/")
    req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip.presence
  end
end
```

### Filtro de data com validação

```ruby
# Source: adaptação de Api::V1::Admin::ArtesController#apply_filters
begin
  from = Date.parse(params[:from])
  to   = Date.parse(params[:to])
  scope = scope.where(scheduled_on: from..to)
rescue Date::Error
  render_error(code: "bad_request", detail: "Formato de data inválido. Use YYYY-MM-DD.", status: :bad_request)
  return
end
```

### Aggregate query para summary

```ruby
# Source: Rails ActiveRecord group + count — padrão ORM padrão
counts = Arte.where(client_id: client.id).group(:status).count
# Retorna: { "pending" => 3, "approved" => 10, "change_requested" => 1, "revised" => 2 }
total = counts.values.sum
```

### Test setup para AI key

```ruby
# Source: adaptação de padrão dos testes de admin/client (Phases 22/23)
AI_API_KEY = "ak_test_key_fixture_#{SecureRandom.hex(8)}"

setup do
  @original_ai_key = ENV["AI_API_KEY"]
  ENV["AI_API_KEY"] = AI_API_KEY
  Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  @auth_headers = {
    "Authorization" => "Bearer #{AI_API_KEY}",
    "Content-Type"  => "application/json"
  }
  @client = Client.create!(name: "AI Test Client", password: "SenhaIA123!", active: true)
end

teardown do
  ENV["AI_API_KEY"] = @original_ai_key
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Arte.statuses[:approved]` em where | `Arte.approved` scope via enum | Rails 4.1+ | Mais legível e menos propenso a erro |
| Serializers ActiveModelSerializers | PORO module com `self.serialize` | Decisão Phase 22 | Sem gem extra, transparente, testável |
| Filtro por `month=YYYY-MM` | Filtro por `from=YYYY-MM-DD&to=YYYY-MM-DD` | Decisão Phase 24 (D-01) | Janelas arbitrárias para agentes de IA |

**Deprecated/outdated:**
- Filtro `month=YYYY-MM` para namespace AI: substituído por `from`/`to` ISO 8601 (mantido no admin — D-01)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Índice `(status, scheduled_on)` não necessário para volume atual | Common Pitfalls #6 | Query lenta em produção com volume alto; solução: adicionar migração com índice composto |
| A2 | `revised_count` deve ser incluído no summary (todos os 4 status do enum estão presentes) | Code Examples | Inconsistência com D-10 se o planner decidir omitir; impacto mínimo |

---

## Open Questions

1. **Serializer dedicado vs reutilizar admin**
   - What we know: Campos são idênticos; namespaces diferentes isolam evolução independente
   - What's unclear: Se o consumidor (IA) precisará de campos diferentes no futuro
   - Recommendation: Criar `Api::V1::Ai::ArteSerializer` dedicado (2 linhas extras, isolamento total) — custo mínimo, benefício de desacoplamento

2. **`revised_count` no summary**
   - What we know: D-10 lista 4 campos; `revised` existe no enum
   - What's unclear: Se a IA precisa distinguir `revised` de `pending` para tomada de decisão
   - Recommendation: Incluir `revised_count` como campo extra — é um aggregate gratuito e alinha com o enum completo

3. **Rota para clients no namespace AI**
   - What we know: Routes.rb tem namespace `:ai` vazio; a rota precisa de `GET /api/v1/ai/clients/:id/summary`
   - What's unclear: Se usar `resources :clients, only: []` com `member do get :summary end` ou rota customizada
   - Recommendation: `resources :clients, only: [] do get :summary, on: :member end` — padrão Rails idiomático

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| rack-attack gem | INFAPI-04 | ✓ | 6.8.0 | — |
| pagy gem | APIAI-01 | ✓ | 9.4.0 | — |
| Rails 8.1.3 | Todos | ✓ | 8.1.3 | — |
| Ruby 3.3.3 | Todos | ✓ | 3.3.3 | — |
| ActiveStorage (Rails) | Serializer media_url | ✓ | built-in | — |
| Credentials `api.ai_key` | Autenticação | [ASSUMED] presente em produção | — | ENV["AI_API_KEY"] como fallback já implementado |

**Missing dependencies with no fallback:** Nenhuma.

**Missing dependencies with fallback:** `credentials.api.ai_key` — fallback via `ENV["AI_API_KEY"]` já implementado no `Ai::BaseController`.

---

## Security Domain

> `security_enforcement: true` e `security_asvs_level: 1` em `.planning/config.json`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `authenticate_ai_key!` via `secure_compare` — já implementado |
| V3 Session Management | no | API stateless por API key; sem sessão |
| V4 Access Control | yes | Namespace `/api/v1/ai/` acessível somente com `ak_` key válida |
| V5 Input Validation | yes | `Date.parse` com rescue, `arte_params` com permit, `Arte` model validations |
| V6 Cryptography | no | API key não é derivada criptograficamente; é comparada com `secure_compare` |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Timing attack na comparação de API key | Information Disclosure | `ActiveSupport::SecurityUtils.secure_compare` — já implementado |
| Rate limit bypass por rotação de key | Denial of Service | Aceito por D-15 (agente pode rotar key — comportamento esperado) |
| Injeção via `external_url` malformado | Tampering | `Arte` model valida presença; SSRF não aplicável (URL não é fetchada pelo servidor) |
| Mass assignment via `arte_params` | Tampering | `params.permit` explícito sem `media_file`; status não pode ser setado diretamente |
| Enumeração de clientes via APIAI-03 | Information Disclosure | `rescue_from RecordNotFound` → 404 genérico; autenticação por API key limita surface |

---

## Sources

### Primary (HIGH confidence)

- Codebase: `app/controllers/api/v1/ai/base_controller.rb` — autenticação existente, padrão de herança
- Codebase: `app/controllers/api/v1/admin/base_controller.rb` — padrão Pagy, helpers, set_active_storage_current
- Codebase: `app/controllers/api/v1/client/base_controller.rb` — confirmação do padrão duplicado em ambos os namespaces
- Codebase: `app/controllers/api/v1/admin/artes_controller.rb` — apply_filters, arte_params, padrão create
- Codebase: `config/initializers/rack_attack.rb` — throttles existentes, throttled_responder
- Codebase: `app/models/arte.rb` — enum status, validações, scopes
- Codebase: `db/schema.rb` — índices em artes (status, client_id+scheduled_on)
- Codebase: `test/integration/rack_attack_test.rb` — padrão de teste de throttle

### Secondary (MEDIUM confidence)

- Codebase: `app/serializers/api/v1/admin/arte_serializer.rb` — template para o serializer AI
- CONTEXT.md Phase 24: todas as decisões D-01 a D-15

### Tertiary (LOW confidence)

- Nenhuma fonte de baixa confiança utilizada.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — gems verificadas localmente via `bundle exec gem list`
- Architecture: HIGH — baseada em leitura direta dos controllers existentes nas Phases 21-23
- Pitfalls: HIGH — identificados via análise do código existente e padrões já em uso no projeto
- Rate limiting: HIGH — `rack_attack.rb` lido diretamente; padrão de throttle verificado

**Research date:** 2026-06-12
**Valid until:** 2026-07-12 (stack estável; gems não mudam rapidamente)
