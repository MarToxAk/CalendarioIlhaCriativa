# Phase 21: Fundação da API + Autenticação — Research

**Pesquisado:** 2026-06-11
**Domínio:** Rails 8 JSON API — versionamento, autenticação JWT/API-key, envelope de resposta
**Confiança geral:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01/D-02:** Cliente autentica com `{ access_token, password }` → JWT de cliente (`scope: "client"`, `sub: client.id`). `access_token` sozinho NUNCA é credencial de API.
- **D-03:** Admin autentica com email + senha → JWT de admin (`scope: "admin"`, `sub: user.id`). Endpoint `POST /api/v1/admin/session`. Usa `User#authenticate` existente, emite JWT em vez de cookie.
- **D-04:** JWT único, sem refresh token. Expiração configurável, padrão **24h**. Revogação por expiração natural.
- **D-05:** Envelope `{ data, meta, errors }`. `errors: [{ code, detail, field? }]`. HTTP correto: 401, 404, 422. Não é JSON:API.
- **D-06:** Namespaces: `/api/v1/admin/*`, `/api/v1/client/*` (inclui `/client/session`), `/api/v1/ai/*`.
- **D-07:** Middleware distingue pelo `Authorization: Bearer <token>`: (1) prefixo `ak_` → IA; (2) decode como JWT → `scope` → admin/client; (3) else → 401.
- **D-08:** API key da IA é opaca e prefixada, armazenada como secret de ambiente (não no banco).

### Claude's Discretion

- Gem JWT concreta (pesquisa escolhe — ex. `ruby-jwt`)
- Biblioteca de serialização concreta (jbuilder / AMS / Alba / serializer plano)
- Prefixo exato da API key (ex. `ak_`)
- Estrutura concreta dos claims do JWT

### Deferred Ideas (OUT OF SCOPE)

- Refresh tokens
- Claim `token_version` / denylist para revogação imediata
- Swagger/OpenAPI (v1.7)
- Rate limiting (Phase 24)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Descrição | Suporte da Pesquisa |
|----|-----------|---------------------|
| AUTH-01 | Admin autentica na API com e-mail e senha e recebe JWT | D-03; seção JWT Strategy; padrão `User#authenticate` → `JWT.encode` |
| AUTH-02 | JWT de admin tem expiração configurável (padrão 24h) | D-04; `exp: N.hours.from_now.to_i` no payload; constante `JWT_EXPIRY` via credentials |
| AUTH-03 | Cliente autentica na API usando token + senha → JWT | D-01/D-02; `Client#authenticate` existente; endpoint `POST /api/v1/client/session` |
| AUTH-04 | IA autentica com API key via `Authorization: Bearer` | D-08; prefixo `ak_`; `secure_compare`; secret em credentials |
| AUTH-05 | Requisições sem auth válida retornam 401 estruturado | D-07; `before_action :authenticate_api_*` nos base controllers; `render_error 401` |
| INFAPI-01 | API versionada em `/api/v1/` | Routing com `namespace :api do namespace :v1`; `defaults: { format: :json }` |
| INFAPI-02 | Respostas em JSON com formato consistente (data + meta + errors) | D-05; helper `render_envelope` em `Api::V1::BaseController`; serializer PORO |
| INFAPI-03 | Erros retornam código HTTP correto e corpo estruturado | `rescue_from` centralizado; mapeamento `RecordNotFound→404`, validação→422, auth→401 |
</phase_requirements>

---

## Summary

Esta fase implementa a fundação de uma API JSON REST sobre um app Rails 8.1.3 que já serve HTML — um cenário híbrido com implicações específicas para o isolamento de middleware. A estratégia central usa um base controller separado (`Api::V1::BaseController < ActionController::API`) sob um namespace próprio, o que isola automaticamente CSRF, cookies e sessão web dos endpoints de API sem nenhuma configuração extra.

A gem `jwt` (ruby-jwt, versão 3.2.0, lançada em maio de 2026, 767M+ downloads) é a escolha óbvia para emissão e decodificação de tokens. Ela está na rubygems há anos, é referenciada na documentação oficial do Rails, passou no slopcheck [OK] e não exige dependências adicionais para HS256. O padrão recomendado é um PORO `Api::JwtService` com métodos `encode`/`decode` que lê o segredo via `Rails.application.credentials.jwt_secret` (com fallback para `ENV["JWT_SECRET"]`). O envelope `{ data, meta, errors }` é mais simples de implementar como helper Ruby puro em `BaseController` do que via jbuilder ou ActiveModel::Serializers, especialmente para uma API com apenas 2 consumidores conhecidos neste milestone.

**Recomendação primária:** `gem "jwt", "~> 3.2"` + serialização por hashes Ruby + `rescue_from` centralizado no `Api::V1::BaseController`. Sem bibliotecas extras de serialização.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Emissão de JWT (login admin) | API / Backend | — | Stateless; segredo nunca sai do servidor |
| Emissão de JWT (login cliente) | API / Backend | — | Segredo no servidor; `Client#authenticate` valida |
| Validação de API key IA | API / Backend | — | Comparação constante no servidor; sem DB |
| Discriminação de consumidor (Bearer parse) | API / Backend | — | `before_action` no base controller de cada namespace |
| Envelope `{ data, meta, errors }` | API / Backend | — | Helper centralizado; renderização no controller |
| Tratamento de erros → HTTP | API / Backend | — | `rescue_from` no `Api::V1::BaseController` |
| Routing `/api/v1/*` | Rails Router | — | `namespace :api do namespace :v1` |
| Segredo JWT / API key | Config (credentials) | ENV fallback | Nunca no banco; rotation via credentials edit |
| CORS (se mobile for cross-origin) | Rack middleware | — | `rack-cors` gem (não instalada ainda) |

---

## Standard Stack

### Core

| Gem | Versão | Propósito | Por que padrão |
|-----|--------|-----------|----------------|
| `jwt` | `~> 3.2` (atual: 3.2.0) | Encode/decode JWT com HS256 | 767M+ downloads; referência da comunidade Rails; slopcheck OK; pura Ruby, sem deps extras para HS256 [VERIFIED: rubygems.org] |
| `rack-cors` | `~> 3.0` (atual: 3.0.0) | CORS para clientes mobile de origens diferentes | 260M+ downloads; padrão do ecossistema Rails para CORS; slopcheck OK [VERIFIED: rubygems.org] |

> **`rack-cors` é condicional.** Só necessário se o app mobile fizer requisições de uma origem diferente do domínio do servidor Rails. Para testes com curl e consumo server-to-server (IA), não é necessário. Incluir agora como plumbing mínimo com `origins "*"` no desenvolvimento (restringir em produção).

### Supporting (sem gem adicional)

| Recurso | Implementação | Motivo |
|---------|--------------|--------|
| Serialização do envelope | PORO / hash Ruby + `render json:` | Nenhuma lib extra necessária para 2 consumidores; jbuilder já está no Gemfile mas é mais pesado para APIs |
| `ActiveSupport::SecurityUtils.secure_compare` | Built-in Rails | Comparação em tempo constante para API key; já disponível sem gem [CITED: api.rubyonrails.org] |
| `has_secure_password` + `#authenticate` | Built-in Rails + bcrypt (já no Gemfile) | Reaproveitamento de `User#authenticate` e `Client#authenticate` existentes |

### Alternatives Considered

| Em vez de | Poderia usar | Trade-off |
|-----------|-------------|-----------|
| `jwt` (~> 3.2) | `ruby-jwt` (mesmo gem, nome antigo) | O nome no Gemfile é `jwt`, não `ruby-jwt` — não confundir |
| PORO serializer | `alba` (gem rápida de serialização) | Alba é boa mas adiciona dependência para um nível de uso simples neste milestone; reavaliar em Phase 22/23 se houver objetos complexos |
| PORO serializer | `active_model_serializers` | AMS tem histórico de bugs com meta/errors e está em modo de manutenção lento |
| `rack-cors` | Configuração manual de CORS no middleware | rack-cors tem 12+ anos de uso; não vale reimplementar |
| `Rails.application.credentials` | ENV var pura | credentials encrypt em git; ENV é aceitável como fallback e para desenvolvimento |

**Instalação:**
```bash
bundle add jwt --version "~> 3.2"
bundle add rack-cors --version "~> 3.0"
```

> Gems vendorizadas em `vendor/bundle` — após `bundle add`, rodar `bundle install --path vendor/bundle` ou conforme o Bundler config do projeto.

---

## Package Legitimacy Audit

| Package | Registry | Idade | Downloads | Source Repo | slopcheck | Disposição |
|---------|----------|-------|-----------|-------------|-----------|------------|
| `jwt` | rubygems | ~12 anos | 767M total | github.com/jwt/ruby-jwt | [OK] | Aprovado |
| `rack-cors` | rubygems | ~12 anos | 260M total | github.com/cyu/rack-cors | [OK] | Aprovado |

**Packages removidos por slopcheck [SLOP]:** nenhum
**Packages com aviso [SUS]:** nenhum

---

## Architecture Patterns

### System Architecture Diagram

```
Request (Authorization: Bearer <token>)
        │
        ▼
  Rails Router (/api/v1/*)
        │
        ├─► POST /api/v1/admin/session ──► Api::V1::Admin::SessionsController
        │         (sem auth guard)              └─ User#authenticate → JWT.encode → { data: { token } }
        │
        ├─► POST /api/v1/client/session ──► Api::V1::Client::SessionsController
        │         (sem auth guard)               └─ Client.find_by(access_token) → #authenticate → JWT.encode
        │
        ├─► /api/v1/admin/* ──► Api::V1::Admin::BaseController
        │         before_action :authenticate_admin_jwt!
        │              │
        │              ├─ parse Bearer → prefixo ak_? → 401
        │              ├─ decode JWT → scope == "admin"? → set @current_user
        │              └─ else → 401 estruturado
        │
        ├─► /api/v1/client/* ──► Api::V1::Client::BaseController
        │         before_action :authenticate_client_jwt!
        │              └─ decode JWT → scope == "client" → set @current_client
        │
        └─► /api/v1/ai/* ──► Api::V1::Ai::BaseController
                  before_action :authenticate_ai_key!
                       └─ prefixo ak_? → secure_compare(key, credentials.ai_api_key)
                            ├─ match → ok
                            └─ no match → 401 estruturado

Shared in Api::V1::BaseController (< ActionController::API):
  - rescue_from → 401 / 404 / 422 envelope
  - render_envelope(data:, meta: {}, status: :ok)
  - render_error(code:, detail:, status:, field: nil)
```

### Recommended Project Structure

```
app/
├── controllers/
│   └── api/
│       └── v1/
│           ├── base_controller.rb          # < ActionController::API; rescue_from; envelope helpers
│           ├── admin/
│           │   ├── base_controller.rb      # authenticate_admin_jwt!
│           │   └── sessions_controller.rb  # POST /api/v1/admin/session
│           ├── client/
│           │   ├── base_controller.rb      # authenticate_client_jwt!
│           │   └── sessions_controller.rb  # POST /api/v1/client/session
│           └── ai/
│               └── base_controller.rb      # authenticate_ai_key!
├── services/
│   └── api/
│       └── jwt_service.rb                  # encode / decode com HS256
lib/
└── (existente — BrazilianHolidays etc.)
config/
├── initializers/
│   ├── rack_attack.rb     # adicionar throttles para /api/v1/*/session
│   └── cors.rb            # (novo) rack-cors config
└── routes.rb              # adicionar bloco namespace :api
```

### Pattern 1: ActionController::API em app híbrido

**O que é:** `Api::V1::BaseController` herda de `ActionController::API` enquanto o `ApplicationController` existente continua herdando de `ActionController::Base`. Ambos coexistem no mesmo processo Rails sem conflito.

**Por que funciona:** Rails suporta hierarquias de controllers paralelas desde o Rails 5. `ActionController::API` não inclui `RequestForgeryProtection`, `Sessions`, nem `Cookies` — esses middlewares ficam completamente fora do stack de API. Não é preciso `skip_before_action :verify_authenticity_token` — o módulo simplesmente não existe.

**Implicação importante:** `ActionController::API` não tem `helper_method`, layouts, nem flash. Nada disso é necessário aqui. O `Current` object ainda funciona (é ActiveSupport, não AC-specific). [CITED: edgeguides.rubyonrails.org/api_app.html]

```ruby
# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,    with: :not_found
  rescue_from ActiveRecord::RecordInvalid,     with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def render_envelope(data:, meta: {}, status: :ok)
    render json: { data: data, meta: meta, errors: [] }, status: status
  end

  def render_error(code:, detail:, status:, field: nil)
    error = { code: code, detail: detail }
    error[:field] = field if field
    render json: { data: nil, meta: {}, errors: [error] }, status: status
  end

  def not_found
    render_error(code: "not_found", detail: "Recurso não encontrado", status: :not_found)
  end

  def unprocessable_entity(exception)
    errors = exception.record.errors.map do |e|
      { code: "validation_error", detail: e.full_message, field: e.attribute.to_s }
    end
    render json: { data: nil, meta: {}, errors: errors }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render_error(code: "bad_request", detail: exception.message, status: :bad_request)
  end
end
```

### Pattern 2: JwtService PORO

**O que é:** Classe de serviço simples que centraliza encode/decode. Mantém a gem `jwt` fora dos controllers.

```ruby
# app/services/api/jwt_service.rb
module Api
  class JwtService
    ALGORITHM = "HS256".freeze
    DEFAULT_EXPIRY = 24.hours

    def self.encode(payload, expiry: DEFAULT_EXPIRY)
      exp = expiry.from_now.to_i
      full_payload = payload.merge(iat: Time.now.to_i, exp: exp)
      JWT.encode(full_payload, secret, ALGORITHM)
    end

    def self.decode(token)
      decoded = JWT.decode(token, secret, true, { algorithm: ALGORITHM, verify_exp: true })
      decoded.first.with_indifferent_access
    rescue JWT::ExpiredSignature
      raise Api::Errors::TokenExpired
    rescue JWT::DecodeError
      raise Api::Errors::TokenInvalid
    end

    def self.secret
      Rails.application.credentials.jwt_secret ||
        ENV.fetch("JWT_SECRET") { raise "JWT_SECRET not configured" }
    end
    private_class_method :secret
  end
end
```

> **Segurança crítica:** `JWT.decode` DEVE receber `{ algorithm: "HS256" }` como opção — nunca omitir. Sem isso, um atacante pode trocar o alg para `none` no header e receber um token aceito sem assinatura (ataque alg:none). A gem `jwt` 3.x obriga especificação de algoritmo quando `verify: true` é passado, mas é uma boa prática explicitá-lo sempre. [CITED: github.com/jwt/ruby-jwt — README, seção de segurança]

### Pattern 3: Discriminação de consumidor por base controller

```ruby
# app/controllers/api/v1/admin/base_controller.rb
class Api::V1::Admin::BaseController < Api::V1::BaseController
  before_action :authenticate_admin_jwt!

  private

  def authenticate_admin_jwt!
    token = bearer_token
    return render_unauthorized unless token
    return render_unauthorized if token.start_with?("ak_")  # API key, não JWT admin

    claims = Api::JwtService.decode(token)
    return render_unauthorized unless claims[:scope] == "admin"

    @current_user = User.find_by(id: claims[:sub])
    render_unauthorized unless @current_user
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

```ruby
# app/controllers/api/v1/ai/base_controller.rb
class Api::V1::Ai::BaseController < Api::V1::BaseController
  before_action :authenticate_ai_key!

  private

  def authenticate_ai_key!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip
    return render_unauthorized unless token&.start_with?("ak_")

    expected = Rails.application.credentials.dig(:api, :ai_key) ||
               ENV["AI_API_KEY"]
    return render_unauthorized unless expected

    unless ActiveSupport::SecurityUtils.secure_compare(token, expected)
      render_unauthorized
    end
  end

  def render_unauthorized
    render_error(code: "unauthorized", detail: "API key inválida", status: :unauthorized)
  end
end
```

### Pattern 4: Routing aninhado com defaults JSON

```ruby
# config/routes.rb — adicionar dentro do bloco draw
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    namespace :admin do
      resource :session, only: [:create]       # POST /api/v1/admin/session
      # outros recursos da Phase 22
    end

    namespace :client do
      resource :session, only: [:create]       # POST /api/v1/client/session
      # outros recursos da Phase 23
    end

    namespace :ai do
      # recursos da Phase 24
    end
  end
end
```

> `defaults: { format: :json }` faz o Rails assumir JSON sem precisar de `.json` na URL ou `Accept: application/json`. Sem esse `defaults`, algumas verificações de formato podem falhar. [CITED: Rails Routing Guide — namespace defaults]

### Pattern 5: Login endpoints (sem guard de auth)

```ruby
# app/controllers/api/v1/admin/sessions_controller.rb
class Api::V1::Admin::SessionsController < Api::V1::BaseController
  def create
    user = User.find_by(email_address: params.require(:email).strip.downcase)
    unless user&.authenticate(params.require(:password))
      return render_error(code: "invalid_credentials",
                          detail: "E-mail ou senha inválidos",
                          status: :unauthorized)
    end

    expiry = (params[:remember_me] ? 7.days : 24.hours)
    token = Api::JwtService.encode(
      { sub: user.id.to_s, scope: "admin" },
      expiry: expiry
    )
    render_envelope(
      data: { token: token, expires_in: expiry.to_i },
      status: :created
    )
  end
end
```

### Anti-Patterns a Evitar

- **Herdar de `ApplicationController` para controllers de API:** `ApplicationController` inclui `Authentication` concern (cookie-based), `allow_browser`, CSRF protection. Um API controller que herda dela vai quebrar ou exigir muitos `skip_before_action`.
- **Omitir `algorithm:` no `JWT.decode`:** Abre vetor de ataque alg:none. Sempre passar `{ algorithm: "HS256" }`.
- **Usar `JWT.decode` sem rescue:** `JWT::DecodeError` é lançado para qualquer token mal-formado. Sem rescue, vira 500.
- **Comparar API key com `==`:** Usa comparação em tempo variável. Sempre usar `ActiveSupport::SecurityUtils.secure_compare`.
- **Guardar o segredo JWT ou API key em texto claro no código ou em variável de instância de classe:** Ler de `credentials` ou `ENV` a cada chamada (ou memoizar com `@@` de forma thread-safe se performance for crítica — não é o caso aqui).
- **Retornar informação diferente para "usuário não existe" vs "senha errada":** Ambos devem retornar `invalid_credentials` genérico para evitar enumeração de usuários.
- **Colocar throttle de login apenas na rota web:** Os novos endpoints `/api/v1/admin/session` e `/api/v1/client/session` precisam de throttles próprios no `rack_attack.rb`.

---

## Don't Hand-Roll

| Problema | Não construir | Usar | Por quê |
|----------|--------------|------|---------|
| Encode/decode JWT | Parser JWT manual | `gem "jwt"` v3.2 | Alg confusion attacks, Base64 edge cases, claim verification são non-trivial |
| Comparação de API key | `key == stored_key` | `ActiveSupport::SecurityUtils.secure_compare` | Timing attack via early-exit comparison |
| Hash de senha | Bcrypt manual | `has_secure_password` (já existe) | Salt, work factor, constant-time compare — já implementados |
| CORS headers | Middleware manual | `rack-cors` | Headers variam por método (OPTIONS preflight), múltiplas origens são complexas |
| Proteção CSRF em HTML | Não desabilitar no `ApplicationController` | Isolar em controller hierarquia separada | `ActionController::API` não inclui CSRF automaticamente; não mexer no `ApplicationController` existente |

---

## Common Pitfalls

### Pitfall 1: `session` e `cookies` chamados em controller API

**O que dá errado:** Se um `before_action` herdado ou include chamar `session[]` ou `cookies[]`, Rails lança `ActionDispatch::Session::SessionRestoreError` ou `NoMethodError` porque `ActionController::API` não inclui esses módulos.

**Por que acontece:** O `Authentication` concern atual usa `cookies.signed[:session_id]`. Se qualquer controller API herdar de `ApplicationController` (que inclui `Authentication`), o concern é executado.

**Como evitar:** Toda hierarquia de API começa em `Api::V1::BaseController < ActionController::API`. Nunca incluir o concern `Authentication` em controllers de API.

**Sinais de alerta:** Stack trace com `ActionDispatch::Request::Session` ou `NoMethodError: undefined method 'cookies'`.

### Pitfall 2: JWT alg:none / algorithm confusion

**O que dá errado:** Um atacante remove a assinatura do JWT e seta `"alg": "none"` no header. Se o decode não especificar o algoritmo esperado, a gem (em versões antigas ou com config errada) pode aceitar o token sem verificar assinatura.

**Por que acontece:** Implementações que usam `JWT.decode(token, secret)` sem o hash de opções `{ algorithm: "HS256" }`.

**Como evitar:** Sempre chamar `JWT.decode(token, secret, true, { algorithm: "HS256" })`. Em `JwtService`, o algoritmo está hardcoded como constante `ALGORITHM = "HS256"`. [CITED: github.com/jwt/ruby-jwt — security notes]

**Sinais de alerta:** Tokens com payload decodificável mas sem assinatura sendo aceitos.

### Pitfall 3: Rack::Attack throttle_responder retorna HTML para endpoints de API

**O que dá errado:** O `throttled_responder` atual retorna HTML (`<h1>Muitas tentativas</h1>`). Um cliente mobile que receba um 429 com Content-Type `text/html` ao tentar `POST /api/v1/admin/session` vai falhar no parse do corpo.

**Por que acontece:** O responder foi configurado antes dos endpoints de API existirem.

**Como evitar:** Criar um segundo responder condicional que retorna JSON para rotas `/api/v1/*`:

```ruby
Rack::Attack.throttled_responder = lambda do |request|
  if request.path.start_with?("/api/")
    [429, { "Content-Type" => "application/json" },
     ['{"data":null,"meta":{},"errors":[{"code":"too_many_requests","detail":"Aguarde antes de tentar novamente."}]}']]
  else
    [429, { "Content-Type" => "text/html; charset=utf-8" },
     ["<h1>Muitas tentativas</h1><p>Aguarde alguns instantes.</p>"]]
  end
end
```

**Sinais de alerta:** Cliente mobile recebe 429 com `Content-Type: text/html`.

### Pitfall 4: `normalizes :email_address` no `User` vs parâmetro `email` na API

**O que dá errado:** O model `User` normaliza o campo `email_address` (strip + downcase). Se o controller de login de API receber o parâmetro como `:email` e fizer `User.find_by(email: ...)`, vai falhar — o campo no banco é `email_address`.

**Por que acontece:** Inconsistência entre o nome do atributo no model (`email_address`, padrão Rails 8 auth generator) e o nome do parâmetro JSON convencional (`email`).

**Como evitar:** No controller de sessão admin, usar `params.require(:email)` mas buscar via `User.find_by(email_address: params[:email].strip.downcase)`. O normalize do model não é chamado em find_by, apenas em save.

### Pitfall 5: Credentials não carregadas no ambiente correto

**O que dá errado:** `Rails.application.credentials.jwt_secret` retorna `nil` em produção se a chave foi adicionada apenas ao arquivo de credentials do ambiente de desenvolvimento ou sem o master.key correto.

**Por que acontece:** Rails 7.1+ suporta per-environment credentials, mas o projeto atual tem apenas `config/credentials.yml.enc` (arquivo único). A chave mestra está em `config/master.key` (confirmado no repo). Em produção, master.key vem de `RAILS_MASTER_KEY` env var.

**Como evitar:** Adicionar `jwt_secret` (e `api.ai_key`) ao arquivo de credentials compartilhado. Em produção, garantir que `RAILS_MASTER_KEY` está definida. Implementar fallback `|| ENV["JWT_SECRET"]` para facilitar desenvolvimento sem expor o arquivo.

### Pitfall 6: `rack-cors` posicionado depois de outros middlewares de auth

**O que dá errado:** Se `rack-cors` for adicionado depois de um middleware que retorna 401 (como um futuro middleware de autenticação), as requisições OPTIONS de preflight recebem 401 sem o header `Access-Control-Allow-Origin` — o browser bloqueia a requisição antes mesmo de tentar.

**Por que acontece:** Ordem de middleware no stack Rack importa. CORS preflight deve ser respondido antes de qualquer auth check.

**Como evitar:** Inserir `rack-cors` no início do stack em `config/application.rb`:
```ruby
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "*")
    resource "/api/*", headers: :any, methods: [:get, :post, :patch, :put, :delete, :options]
  end
end
```

---

## Code Examples

### Verificação de rotas sem rodar a suite de testes

```bash
# Confirmar que as rotas API foram registradas corretamente
bin/rails routes --grep /api/v1

# Esperado (exemplo):
#   POST /api/v1/admin/session   api/v1/admin/sessions#create
#   POST /api/v1/client/session  api/v1/client/sessions#create
```

### Teste manual via curl (servidor dev rodando)

```bash
# Login admin
curl -s -X POST http://localhost:3000/api/v1/admin/session \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@ilhacriativa.com.br","password":"SenhaSegura123!"}' | jq .

# Esperado: { "data": { "token": "eyJ..." }, "meta": {}, "errors": [] }

# Tentativa sem auth
curl -s -X GET http://localhost:3000/api/v1/admin/some_endpoint \
  -H "Authorization: Bearer token_invalido" | jq .

# Esperado: 401 { "data": null, "meta": {}, "errors": [{ "code": "unauthorized", "detail": "..." }] }
```

### Geração de API key para IA (one-time, via console)

```ruby
# rails console — geração do valor para colocar em credentials
require "securerandom"
key = "ak_" + SecureRandom.hex(32)
# => "ak_a3f7b2e1c9d4..." (67 chars total)
# Adicionar via: bin/rails credentials:edit
# api:
#   ai_key: ak_a3f7b2e1c9d4...
```

### JWT com `scope` e `sub` (claims para emissão)

```ruby
# Admin JWT
payload = {
  sub: user.id.to_s,
  scope: "admin",
  iat: Time.now.to_i,
  exp: 24.hours.from_now.to_i
}
token = JWT.encode(payload, secret, "HS256")

# Client JWT
payload = {
  sub: client.id.to_s,
  scope: "client",
  iat: Time.now.to_i,
  exp: 24.hours.from_now.to_i
}
```

### rack-attack — adicionar throttles para endpoints de API

```ruby
# Adicionar ao config/initializers/rack_attack.rb (abaixo dos throttles existentes)

throttle("api/admin_login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/api/v1/admin/session" && req.post?
end

throttle("api/client_login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/api/v1/client/session" && req.post?
end
```

---

## State of the Art

| Abordagem antiga | Abordagem atual | Quando mudou | Impacto |
|-----------------|-----------------|--------------|---------|
| `ruby-jwt` gem para JWT | `jwt` gem (mesmo projeto, nome simplificado) | ~2017 | Gemfile usa `gem "jwt"`, não `gem "ruby-jwt"` |
| `JWT.encode` / `JWT.decode` clássico | API OO com `JWT::Token` / `JWT::EncodedToken` | v3.0 (jun 2025) | Ambas as APIs coexistem; a clássica continua suportada; v3 OO mais expressiva mas desnecessária para HS256 simples |
| Rails API-only (`rails new --api`) | Hierarquia paralela de controllers em app híbrido | Rails 5+ | App híbrido suporta `ActionController::API` numa sub-hierarquia sem `--api` flag |
| Segredos em `config/secrets.yml` | `Rails.application.credentials` (encrypted) | Rails 5.2 | credentials.yml.enc commitável; decriptado pela master key |

**Deprecated/outdated:**
- `Knock` gem para JWT em Rails: não mantida, não usar [CITED: github.com/nsarno/knock — archived]
- `rails_jwt_auth` gem: pequena, pouco adotada, não necessária dado o modelo manual simples
- `active_model_serializers` para envelope custom: dificulta formato não-JSON:API; usar PORO

---

## Assumptions Log

| # | Claim | Seção | Risco se errado |
|---|-------|-------|-----------------|
| A1 | App mobile será cross-origin (origem diferente do servidor Rails) exigindo CORS | Standard Stack (rack-cors) | Se for mesmo domínio (ex: API e web no mesmo host), rack-cors é desnecessária mas inofensiva |
| A2 | `rails credentials:edit` funciona no ambiente de deploy atual (master.key disponível) | Pitfall 5 | Se master.key não estiver em produção, usar ENV vars puras; não bloqueia a fase |
| A3 | O campo email do User no banco é `email_address` (não `email`) | Pitfall 4, Code Examples | Confirmado visualmente em `app/models/user.rb` (`normalizes :email_address`) [VERIFIED: codebase] |
| A4 | `has_secure_password` do `Client` expõe `#authenticate(password)` que retorna o objeto ou `false` | Pattern 5 | Padrão do Rails — confirmado em `app/models/client.rb` [VERIFIED: codebase] |

---

## Open Questions

1. **CORS para mobile**
   - O que sabemos: o app mobile é um consumidor previsto; origem ainda não definida
   - O que está incerto: se o mobile fará requests do domínio do servidor (WebView embedded) ou de origem própria (app nativo)
   - Recomendação: incluir `rack-cors` agora com `origins "*"` em dev e restricting via ENV em produção; sem impacto de segurança para endpoints stateless com Bearer token

2. **Prefixo exato da API key da IA (`ak_`)**
   - O que sabemos: D-08 define prefixo como exemplo `ak_...` — "Claude's Discretion" confirma que o planejamento decide
   - O que está incerto: nada técnico — é escolha arbitrária
   - Recomendação: usar `ak_` seguido de 32 bytes hex (`SecureRandom.hex(32)`) → 67 chars no total

3. **Expiração configurável — via credentials ou via constante?**
   - O que sabemos: D-04 diz "expiração configurável, padrão 24h"
   - O que está incerto: se "configurável" significa por environment (credentials) ou por parâmetro de request
   - Recomendação: constante `JWT_EXPIRY` em `JwtService` que lê `Rails.application.credentials.jwt_expiry_hours || 24`, convertida para duration. Não expor via parâmetro de request.

---

## Environment Availability

| Dependência | Requerida por | Disponível | Versão | Fallback |
|-------------|--------------|-----------|--------|----------|
| `config/master.key` | Rails credentials (jwt_secret, ai_key) | Confirmado no repo | — | ENV vars (`JWT_SECRET`, `AI_API_KEY`) |
| PostgreSQL | Banco de dados existente | Sim (app em produção) | — | — |
| `rack-attack` | Throttle de login | Sim (já no Gemfile, 4 throttles ativos) | ~6.8 | — |
| `jbuilder` | (Opcional — não usado aqui) | Sim (no Gemfile) | — | PORO hash (recomendado) |
| Bundler com `vendor/bundle` | Instalação de gems | Sim (gems vendorizadas) | — | — |

---

## Security Domain

### Applicable ASVS Categories (L1)

| Categoria ASVS | Aplica | Controle padrão |
|----------------|--------|-----------------|
| V2 Authentication | Sim | `has_secure_password` + bcrypt (já existente); credentials inválidas → mensagem genérica |
| V3 Session Management | Sim (tokens JWT = sessões stateless) | JWT assinado HS256; `exp` obrigatório; `algorithm:` hardcoded no decode |
| V4 Access Control | Sim | Base controllers por namespace; `scope` claim verifica tipo de consumidor; admin ≠ cliente ≠ IA |
| V5 Input Validation | Sim | `params.require()` para campos obrigatórios no login; `ActionController::ParameterMissing` → rescue_from |
| V6 Cryptography | Sim | bcrypt para senhas (existente); HS256 com secret de 256+ bits via credentials; `secure_compare` para API key |

### Known Threat Patterns

| Pattern | STRIDE | Mitigação padrão |
|---------|--------|-----------------|
| JWT alg:none / algorithm confusion | Tampering | Hardcode `algorithm: "HS256"` no `JWT.decode`; nunca aceitar `none` |
| JWT expirado aceito | Elevation of Privilege | `verify_exp: true` no decode (padrão da gem quando `verify: true`) |
| Brute force em `/api/v1/admin/session` | Repudiation / DoS | Throttle rack-attack `5 req/min/IP`; resposta genérica `invalid_credentials` |
| Enumeração de usuário ("e-mail não existe" vs "senha errada") | Information Disclosure | Retornar sempre `invalid_credentials` para ambos os casos |
| Timing attack na comparação de API key | Information Disclosure | `ActiveSupport::SecurityUtils.secure_compare` — comparação em tempo constante |
| Token JWT vazado (ex: log) | Repudiation | Não logar o header `Authorization`; `Rails.application.config.filter_parameters` já inclui `:password` — adicionar padrão para tokens |
| CORS preflight bloqueado por auth middleware | Spoofing | `rack-cors` inserido antes (insert_before 0) de qualquer auth middleware |
| Força bruta em `/api/v1/client/session` | Repudiation | Throttle rack-attack `5 req/min/IP`; mesmo padrão do admin |

### Threat Model Block (para o planner)

```xml
<threat_model>
  <threat id="TM-01" stride="Tampering" severity="high">
    <description>JWT alg:none — atacante remove assinatura e seta alg:none no header</description>
    <mitigation>JWT.decode sempre com algorithm: "HS256" hardcoded; constante ALGORITHM em JwtService</mitigation>
    <verification>Code review: grep "JWT.decode" em toda a codebase; verificar que options hash inclui algorithm</verification>
  </threat>
  <threat id="TM-02" stride="Elevation of Privilege" severity="medium">
    <description>Scope tampering — atacante forja claim scope:"admin" num JWT de cliente</description>
    <mitigation>JWT assinado com segredo que só o servidor conhece; qualquer alteração invalida a assinatura</mitigation>
    <verification>Tentar decode manual de JWT modificado → deve retornar JWT::VerificationError</verification>
  </threat>
  <threat id="TM-03" stride="Information Disclosure" severity="medium">
    <description>Enumeração de usuários via diferença de resposta em credenciais inválidas</description>
    <mitigation>Sempre retornar "invalid_credentials" independente de usuário existir ou não</mitigation>
    <verification>POST /session com email inexistente e com email válido+senha errada devem retornar mesmo código/mensagem/latência</verification>
  </threat>
  <threat id="TM-04" stride="Information Disclosure" severity="medium">
    <description>Timing attack na comparação de API key da IA</description>
    <mitigation>ActiveSupport::SecurityUtils.secure_compare em vez de ==</mitigation>
    <verification>Code review: grep para comparação de API key; confirmar uso de secure_compare</verification>
  </threat>
  <threat id="TM-05" stride="Repudiation" severity="medium">
    <description>Brute force nos endpoints de login da API</description>
    <mitigation>rack-attack throttle 5 req/60s/IP para ambos os endpoints de session</mitigation>
    <verification>curl loop simulando 10 logins rápidos → deve receber 429 a partir do 6o</verification>
  </threat>
</threat_model>
```

---

## Sources

### Primary (HIGH confidence)

- `rubygems.org/gems/jwt` — versão atual 3.2.0, total downloads, verificado via API [VERIFIED: rubygems.org]
- `github.com/jwt/ruby-jwt` — README: encode/decode API, claims, alg:none security note [CITED: github.com/jwt/ruby-jwt]
- `github.com/jwt/ruby-jwt/blob/main/UPGRADING.md` — breaking changes v2→v3 [CITED: github.com/jwt/ruby-jwt]
- `edgeguides.rubyonrails.org/api_app.html` — ActionController::API vs Base, módulos incluídos/excluídos [CITED: edgeguides.rubyonrails.org]
- `api.rubyonrails.org/classes/ActiveSupport/SecurityUtils.html` — secure_compare [CITED: api.rubyonrails.org]
- Codebase: `app/models/user.rb`, `app/models/client.rb`, `app/controllers/concerns/authentication.rb`, `app/channels/application_cable/connection.rb`, `config/initializers/rack_attack.rb` [VERIFIED: codebase]

### Secondary (MEDIUM confidence)

- `rubygems.org/gems/rack-cors` — versão 3.0.0, 260M downloads [VERIFIED: rubygems.org]
- `github.com/cyu/rack-cors` — configuração de middleware CORS [CITED: github.com/cyu/rack-cors]
- `dev.to/ruwhan/part-1-rails-8-authentication-but-with-jwt-2if6` — padrões Rails 8 + JWT
- `github.com/OWASP/ASVS` — categorias V2/V3/V4/V5/V6 L1

### Tertiary (LOW confidence — não usados em recomendações primárias)

- Artigos de blog (Medium, DEV.to) sobre padrões de serialização — usados apenas como confirmação secundária

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — jwt 3.2.0 verificado no rubygems; slopcheck OK em ambas as gems; padrão amplamente adotado
- Architecture: HIGH — baseado em codebase real lida e em guias oficiais do Rails
- Pitfalls: HIGH — pitfalls 1-4 verificados contra codebase e documentação oficial; 5-6 baseados em docs e experiência verificada com o projeto
- Security: HIGH — ASVS L1 verificado contra OWASP; mitigações concretas e verificáveis

**Research date:** 2026-06-11
**Valid until:** 2026-07-11 (gems estáveis; reavaliar se ruby-jwt lançar 3.x breaking change)
