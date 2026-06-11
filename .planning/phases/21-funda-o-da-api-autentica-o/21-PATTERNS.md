# Phase 21: Fundação da API + Autenticação — Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 11 new/modified files
**Analogs found:** 9 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Gemfile` | config | — | `Gemfile` (existing) | exact |
| `config/routes.rb` | config/route | request-response | `config/routes.rb` (existing) | exact |
| `config/initializers/rack_attack.rb` | config | request-response | `config/initializers/rack_attack.rb` (existing) | exact |
| `config/initializers/cors.rb` | config | request-response | none | no analog |
| `app/services/api/jwt_service.rb` | service | transform | none (no services exist) | no analog |
| `app/controllers/api/v1/base_controller.rb` | controller | request-response | `app/controllers/admin/base_controller.rb` | role-match |
| `app/controllers/api/v1/admin/base_controller.rb` | controller/middleware | request-response | `app/controllers/client_controller.rb` | role-match |
| `app/controllers/api/v1/client/base_controller.rb` | controller/middleware | request-response | `app/controllers/client_controller.rb` | role-match |
| `app/controllers/api/v1/ai/base_controller.rb` | controller/middleware | request-response | `app/controllers/client_controller.rb` | partial-match |
| `app/controllers/api/v1/admin/sessions_controller.rb` | controller | request-response | `app/controllers/sessions_controller.rb` | role-match |
| `app/controllers/api/v1/client/sessions_controller.rb` | controller | request-response | `app/controllers/client/sessions_controller.rb` | role-match |

---

## Pattern Assignments

### `Gemfile` (config)

**Analog:** `Gemfile` (existing — lines 1-77)

**Existing gem addition pattern** (lines 22-30 — domain gems block):
```ruby
# Security — rate limiting / brute-force protection
gem "rack-attack", "~> 6.8"

# Domain gems
gem "simple_calendar", "~> 3.1"
gem "pagy", "~> 9.3"
```

**Add after the `rack-attack` line** (between lines 26–27), following the same format:
```ruby
# JSON API authentication
gem "jwt", "~> 3.2"
gem "rack-cors", "~> 3.0"
```

---

### `config/routes.rb` (config, request-response)

**Analog:** `config/routes.rb` (existing — lines 1-38)

**Existing namespace pattern** (lines 7-25 — `namespace :admin` block):
```ruby
namespace :admin do
  root to: "dashboard#index"
  resources :clients, only: [ :index, :show, :new, :create, :edit, :update ] do
    member do
      post :rotate_token
    end
  end
  # ...
end
```

**Existing scope pattern** (lines 28-34 — client portal):
```ruby
scope "/c/:token", as: :client do
  root to: "client/home#index"
  resource :session, only: [ :new, :create, :destroy ], controller: "client/sessions"
  # ...
end
```

**New API block to append** — mirrors the namespacing style above but with `defaults: { format: :json }`:
```ruby
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    namespace :admin do
      resource :session, only: [:create]   # POST /api/v1/admin/session
    end

    namespace :client do
      resource :session, only: [:create]   # POST /api/v1/client/session
    end

    namespace :ai do
      # Phase 24 resources
    end
  end
end
```
Insert this block before the health check route (line 37).

---

### `config/initializers/rack_attack.rb` (config, request-response)

**Analog:** `config/initializers/rack_attack.rb` (existing — lines 1-29)

**Existing throttle pattern** (lines 14-16):
```ruby
throttle("admin/login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/session" && req.post?
end
```

**Existing `throttled_responder`** (lines 22-28 — HTML-only, must be replaced):
```ruby
Rack::Attack.throttled_responder = lambda do |_request|
  [
    429,
    { "Content-Type" => "text/html; charset=utf-8" },
    [ "<h1>Muitas tentativas</h1><p>Aguarde alguns instantes antes de tentar novamente.</p>" ]
  ]
end
```

**Two changes required:**
1. Append two new throttles before the `throttled_responder` block:
```ruby
throttle("api/admin_login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/api/v1/admin/session" && req.post?
end

throttle("api/client_login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/api/v1/client/session" && req.post?
end
```

2. Replace the existing `throttled_responder` lambda (lines 22-28) with one that discriminates by path:
```ruby
Rack::Attack.throttled_responder = lambda do |request|
  if request.path.start_with?("/api/")
    [429, { "Content-Type" => "application/json" },
     ['{"data":null,"meta":{},"errors":[{"code":"too_many_requests","detail":"Aguarde antes de tentar novamente."}]}']]
  else
    [429, { "Content-Type" => "text/html; charset=utf-8" },
     ["<h1>Muitas tentativas</h1><p>Aguarde alguns instantes antes de tentar novamente.</p>"]]
  end
end
```

---

### `app/services/api/jwt_service.rb` (service, transform)

**Analog:** none — no service POROs exist in the codebase. The `app/services/` directory does not exist yet.

**No-analog note:** Use the pattern from RESEARCH.md §Pattern 2 directly. The module/class nesting (`module Api; class JwtService`) follows the same Ruby constant-nesting convention used in `app/channels/application_cable/connection.rb` (lines 1-2: `module ApplicationCable; class Connection`).

**Module nesting reference** (`app/channels/application_cable/connection.rb` lines 1-3):
```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_client
```

**Key implementation requirements from RESEARCH.md:**
- `ALGORITHM = "HS256".freeze` as a constant (never dynamic)
- `JWT.decode(token, secret, true, { algorithm: ALGORITHM, verify_exp: true })` — the `algorithm:` key is mandatory to prevent alg:none attacks
- Rescue `JWT::ExpiredSignature` and `JWT::DecodeError` separately, re-raising as domain errors (`Api::Errors::TokenExpired`, `Api::Errors::TokenInvalid`)
- Secret read from `Rails.application.credentials.jwt_secret || ENV.fetch("JWT_SECRET") { raise "..." }`

---

### `app/controllers/api/v1/base_controller.rb` (controller, request-response)

**Analog:** `app/controllers/admin/base_controller.rb` (lines 1-5) — same role (base controller that others inherit from), different base class.

**Existing base controller pattern** (full file):
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
  include Pagy::Backend
end
```

**Key difference:** New file inherits from `ActionController::API` (not `ApplicationController`) to exclude CSRF, cookies, sessions, layouts, and flash — none of which belong in a JSON API.

**`rescue_from` pattern reference — `app/controllers/client_controller.rb` lines 16-18:**
```ruby
rescue ActiveRecord::RecordNotFound
  render plain: "Link inválido", status: :not_found
end
```
The API base controller centralizes all `rescue_from` handlers instead of per-controller rescue blocks.

**`render json:` response pattern reference — `app/controllers/sessions_controller.rb` lines 13-19:**
```ruby
def create
  if user = User.authenticate_by(params.permit(:email_address, :password))
    start_new_session_for user
    redirect_to after_authentication_url
  else
    redirect_to new_session_path, alert: "..."
  end
end
```
The API base replaces `redirect_to` / flash with `render json: { data:, meta:, errors: }`.

---

### `app/controllers/api/v1/admin/base_controller.rb` (controller/middleware, request-response)

**Analog:** `app/controllers/client_controller.rb` (lines 1-28) — best match: a base controller that loads/validates identity from a request parameter via `before_action`, then sets an instance variable (`@client`).

**Full analog** (`app/controllers/client_controller.rb`):
```ruby
class ClientController < ApplicationController
  layout 'client'

  skip_before_action :require_authentication

  before_action :load_client_from_token
  before_action :require_client_auth

  private

  def load_client_from_token
    @client = Client.find_by!(access_token: params[:token])
    unless @client.active?
      render plain: "Acesso bloqueado", status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "Link inválido", status: :not_found
  end

  def require_client_auth
    unless session[:client_id] == @client.id &&
           session[:client_token_version] == @client.token_version
      # ...
      redirect_to new_client_session_path(token: @client.access_token)
    end
  end
end
```

**Structural parallel to copy:**
- `before_action :authenticate_admin_jwt!` replaces `before_action :require_client_auth`
- `@current_user` replaces `@client`
- `render_error(...)` (from `Api::V1::BaseController`) replaces `render plain: ...` and `redirect_to`
- The dual-read-then-validate pattern (`find_by` → check scope → set ivar) mirrors `load_client_from_token` → `require_client_auth`

**Dual-auth discrimination reference** (`app/channels/application_cable/connection.rb` lines 10-22):
```ruby
def set_current_user
  if session = Session.find_by(id: cookies.signed[:session_id])
    self.current_user = session.user
  end
end

def set_current_client
  token = request.params[:token]
  return nil if token.blank?
  if client = Client.find_by(access_token: token, active: true)
    self.current_client = client
  end
end
```
The `authenticate_admin_jwt!` method mirrors this discrimination logic but uses `request.headers["Authorization"]` instead of cookies/params, and decodes a JWT instead of doing a DB lookup.

---

### `app/controllers/api/v1/client/base_controller.rb` (controller/middleware, request-response)

**Analog:** `app/controllers/client_controller.rb` (same analog as admin base — lines 1-28, listed above)

**Structural parallel:**
- `before_action :authenticate_client_jwt!` replaces `before_action :require_client_auth`
- `@current_client` replaces `@client`
- JWT claim check `scope == "client"` replaces `session[:client_id] == @client.id && session[:client_token_version] == @client.token_version`

**`Client.find_by` pattern** (`app/channels/application_cable/connection.rb` lines 17-20):
```ruby
token = request.params[:token]
return nil if token.blank?
if client = Client.find_by(access_token: token, active: true)
  self.current_client = client
end
```
The API version substitutes `Client.find_by(id: claims[:sub])` instead of `find_by(access_token:)`.

---

### `app/controllers/api/v1/ai/base_controller.rb` (controller/middleware, request-response)

**Analog:** `app/controllers/client_controller.rb` (partial match — the `before_action` + guard pattern, lines 6-7 and 20-27)

**Key difference from admin/client base controllers:** No DB lookup — validation is a pure string comparison against a credential. The pattern for "read from request, compare, reject if mismatch" is structurally identical to `require_client_auth`, but using `ActiveSupport::SecurityUtils.secure_compare` instead of `==`.

**`secure_compare` is built-in Rails** — no import needed beyond what `ActionController::API` already provides via Rails.

---

### `app/controllers/api/v1/admin/sessions_controller.rb` (controller, request-response)

**Analog:** `app/controllers/sessions_controller.rb` (lines 1-29) — admin login using `User` credentials.

**Full analog:**
```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "..." }

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "E-mail ou senha incorretos. Tente novamente."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
```

**Structural translation to API version:**
- Inherits from `Api::V1::BaseController` (not `ApplicationController`) — no `allow_unauthenticated_access` needed (no parent auth guard)
- `User.authenticate_by` → prefer `User.find_by(email_address: ...) &.authenticate(password)` to control the error message precisely (avoid leaking "not found" vs "wrong password" distinction — see RESEARCH.md Pitfall 4)
- `start_new_session_for user` → `Api::JwtService.encode({ sub: user.id.to_s, scope: "admin" })`
- `redirect_to` → `render_envelope(data: { token: }, status: :created)`
- `alert:` → `render_error(code: "invalid_credentials", ...)`
- Field `email_address` in model vs `email` in JSON param — use `User.find_by(email_address: params.require(:email).strip.downcase)` (RESEARCH.md Pitfall 4)

---

### `app/controllers/api/v1/client/sessions_controller.rb` (controller, request-response)

**Analog:** `app/controllers/client/sessions_controller.rb` (lines 1-28) — client login using `Client#authenticate`.

**Full analog:**
```ruby
class Client::SessionsController < ClientController
  skip_before_action :require_client_auth, only: [ :new, :create ]

  def create
    unless @client.active?
      flash.now[:alert] = "Acesso bloqueado. Entre em contato com o administrador."
      render :new, status: :unprocessable_entity
      return
    end
    if @client.authenticate(params[:password])
      session[:client_id]            = @client.id
      session[:client_token_version] = @client.token_version
      redirect_to client_root_path(token: @client.access_token)
    else
      flash.now[:alert] = "Senha incorreta. Tente novamente."
      render :new, status: :unprocessable_entity
    end
  end
end
```

**Structural translation to API version:**
- Inherits from `Api::V1::BaseController` (not `Api::V1::Client::BaseController`) — login endpoint must have no auth guard
- Lookup: `Client.find_by(access_token: params.require(:access_token))` (mirrors `connection.rb` line 19 `Client.find_by(access_token: token, active: true)`)
- `@client.authenticate(params[:password])` — identical method, already available via `has_secure_password`
- `session[:client_id] = ...` → `Api::JwtService.encode({ sub: client.id.to_s, scope: "client" })`
- `redirect_to` + `flash` → `render_envelope` / `render_error`
- Active check becomes part of the generic `invalid_credentials` response (do not reveal inactive status separately — RESEARCH.md Pitfall 3/anti-enumeration)

---

## Shared Patterns

### `before_action` guard structure
**Source:** `app/controllers/client_controller.rb` lines 6-27
**Apply to:** `Api::V1::Admin::BaseController`, `Api::V1::Client::BaseController`, `Api::V1::Ai::BaseController`
```ruby
before_action :load_client_from_token
before_action :require_client_auth

def load_client_from_token
  @client = Client.find_by!(access_token: params[:token])
  unless @client.active?
    render plain: "Acesso bloqueado", status: :forbidden
  end
rescue ActiveRecord::RecordNotFound
  render plain: "Link inválido", status: :not_found
end
```
API translation: replace `load_client_from_token` + `require_client_auth` with a single `authenticate_*_jwt!` / `authenticate_ai_key!` method that reads `Authorization: Bearer`, validates, and sets `@current_user` / `@current_client`.

### Credential lookup with active check
**Source:** `app/channels/application_cable/connection.rb` lines 17-20
**Apply to:** `Api::V1::Client::SessionsController` (finding client by access_token)
```ruby
token = request.params[:token]
return nil if token.blank?
if client = Client.find_by(access_token: token, active: true)
  self.current_client = client
end
```

### `has_secure_password` authenticate call
**Source:** `app/controllers/client/sessions_controller.rb` line 13; `app/controllers/sessions_controller.rb` line 17
**Apply to:** Both session controllers
```ruby
# Admin:
user = User.authenticate_by(params.permit(:email_address, :password))
# Client (web version):
@client.authenticate(params[:password])
```
API admin sessions controller must use `User.find_by(email_address: ...).&.authenticate(password)` pattern (not `User.authenticate_by`) to return a uniform `invalid_credentials` error regardless of whether the user exists.

### Test setup pattern
**Source:** `test/controllers/sessions_controller_test.rb` lines 1-13; `test/controllers/client/sessions_controller_test.rb` lines 1-9
**Apply to:** `test/controllers/api/v1/admin/sessions_controller_test.rb`, `test/controllers/api/v1/client/sessions_controller_test.rb`
```ruby
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    @user = User.find_by!(email_address: ADMIN_EMAIL)
  end
```
API tests: replace cookie/session assertions with JSON body parsing (`response.parsed_body["data"]["token"]`). No `sign_in_as` helper — tests call `POST /api/v1/*/session` and extract the returned JWT.

### Rack::Attack throttle pattern
**Source:** `config/initializers/rack_attack.rb` lines 14-16
**Apply to:** New throttles for `/api/v1/admin/session` and `/api/v1/client/session`
```ruby
throttle("admin/login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/session" && req.post?
end
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `app/services/api/jwt_service.rb` | service | transform | No service POROs exist in the codebase (`app/services/` directory absent). Use RESEARCH.md §Pattern 2 directly. Module nesting convention: copy from `app/channels/application_cable/connection.rb` lines 1-2. |
| `config/initializers/cors.rb` | config | request-response | No CORS configuration exists. Use RESEARCH.md §Pitfall 6 pattern: `config.middleware.insert_before 0, Rack::Cors` in `config/application.rb`, not as an initializer. |

---

## Critical Constraints (from RESEARCH.md)

These are not patterns to copy but hard guards the planner must encode as acceptance criteria:

1. **Never inherit from `ApplicationController`** for API controllers — `ApplicationController` includes the `Authentication` concern (cookies-based), `allow_browser`, and CSRF. API hierarchy must start at `ActionController::API`.

2. **`JWT.decode` must always specify `algorithm: "HS256"`** — omitting it opens the alg:none attack vector. The constant `ALGORITHM = "HS256".freeze` in `JwtService` enforces this.

3. **API key comparison must use `ActiveSupport::SecurityUtils.secure_compare`** — not `==`. Already available in Rails, no import needed.

4. **`User.find_by(email_address:)` not `User.find_by(email:)`** — model field is `email_address` (see `user.rb` line 5: `normalizes :email_address`).

5. **`throttled_responder` must be updated** to return JSON for `/api/*` paths — the current responder returns `text/html` which will break mobile clients.

---

## Metadata

**Analog search scope:** `app/controllers/`, `app/channels/`, `app/models/`, `config/`, `test/`
**Files read:** 16
**Files with no services directory:** `app/services/` does not exist — must be created
**Pattern extraction date:** 2026-06-11
