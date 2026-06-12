# Phase 24: Endpoints IA + Rate Limiting - Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 7 (5 new + 2 modified)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/controllers/api/v1/ai/base_controller.rb` | controller (base) | request-response | `app/controllers/api/v1/admin/base_controller.rb` | exact |
| `app/controllers/api/v1/ai/artes_controller.rb` | controller | CRUD + request-response | `app/controllers/api/v1/admin/artes_controller.rb` | exact |
| `app/controllers/api/v1/ai/clients_controller.rb` | controller | request-response | `app/controllers/api/v1/admin/artes_controller.rb` | role-match |
| `app/serializers/api/v1/ai/arte_serializer.rb` | utility (serializer) | transform | `app/serializers/api/v1/admin/arte_serializer.rb` | exact |
| `config/initializers/rack_attack.rb` | config (middleware) | request-response | self (modify existing) | self |
| `config/routes.rb` | config | — | self (modify existing) | self |
| `test/controllers/api/v1/ai/artes_controller_test.rb` | test | request-response | `test/controllers/api/v1/admin/artes_controller_test.rb` | exact |
| `test/controllers/api/v1/ai/clients_controller_test.rb` | test | request-response | `test/controllers/api/v1/admin/clients_controller_test.rb` | role-match |
| `test/integration/rack_attack_test.rb` | test | event-driven | self (modify existing) | self |

---

## Pattern Assignments

### `app/controllers/api/v1/ai/base_controller.rb` (controller base, request-response)

**Analog:** `app/controllers/api/v1/admin/base_controller.rb`

This file already exists with `authenticate_ai_key!` only. It needs to be expanded to mirror admin and client base controllers.

**Current state** (lines 1-28 of existing file):
```ruby
# frozen_string_literal: true

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

**Additions to copy from analog** `app/controllers/api/v1/admin/base_controller.rb` (lines 4-57):

```ruby
# Add at class level (after existing before_action :authenticate_ai_key!):
include Pagy::Backend
before_action :set_active_storage_current
rescue_from Pagy::OverflowError, with: :page_overflow

# Add to private section (do NOT duplicate authenticate_ai_key! — keep existing):
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

**Source analog — full structure for reference** (`app/controllers/api/v1/admin/base_controller.rb` lines 1-58):
```ruby
# frozen_string_literal: true

class Api::V1::Admin::BaseController < Api::V1::BaseController
  include Pagy::Backend
  before_action :authenticate_admin_jwt!
  before_action :set_active_storage_current

  rescue_from Pagy::OverflowError, with: :page_overflow

  private

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

---

### `app/controllers/api/v1/ai/artes_controller.rb` (controller, CRUD + request-response)

**Analog:** `app/controllers/api/v1/admin/artes_controller.rb`

**Imports / class declaration pattern** (analog lines 1-3):
```ruby
# frozen_string_literal: true

class Api::V1::Ai::ArtesController < Api::V1::Ai::BaseController
```

**Core index pattern — adapted from analog** (`app/controllers/api/v1/admin/artes_controller.rb` lines 4-12):
```ruby
# Analog (admin) — note: IA replaces apply_filters with inline approved+period filter:
def index
  scope = Arte.includes(:client).order(scheduled_on: :desc)
  scope = apply_filters(scope)
  @pagy, @artes = pagy(scope, limit: per_page_param)
  render_envelope(
    data: Api::V1::Admin::ArteSerializer.serialize_collection(@artes),
    meta: { pagination: pagination_meta(@pagy) }
  )
end
```

**AI adaptation — key differences from analog:**
- Start scope with `Arte.approved` (not `Arte.includes(:client).order(...)`)
- Order `scheduled_on: :asc` (not `:desc`)
- Mandatory `from`/`to` period filter — raise `ActionController::ParameterMissing` if absent
- No `status` or `month` filter params — replaced by fixed `approved` + `from`/`to`
- Rescue `Date::Error` inline (same pattern as admin's `apply_filters` for `month`)
- Reject `media_file` with explicit 400 in `create`
- Use `Api::V1::Ai::ArteSerializer` (not admin serializer)

**Date filter pattern — from analog** (`app/controllers/api/v1/admin/artes_controller.rb` lines 32-39):
```ruby
# Admin uses Date.strptime for month; AI uses Date.parse for from/to — same rescue:
if params[:month].present?
  begin
    date = Date.strptime(params[:month], "%Y-%m")
    scope = scope.where(scheduled_on: date.beginning_of_month..date.end_of_month)
  rescue Date::Error
    raise ActionController::ParameterMissing.new(:month)
  end
end
# AI equivalent:
begin
  from = Date.parse(params[:from])
  to   = Date.parse(params[:to])
  scope = scope.where(scheduled_on: from..to)
rescue Date::Error
  render_error(code: "bad_request", detail: "Formato de data inválido. Use YYYY-MM-DD.", status: :bad_request)
  return
end
```

**Core create pattern** (`app/controllers/api/v1/admin/artes_controller.rb` lines 14-23):
```ruby
# Analog (admin):
def create
  @arte = Arte.new(arte_params)
  @arte.external_url = nil if params[:media_file].present?
  @arte.save!
  render_envelope(
    data: Api::V1::Admin::ArteSerializer.serialize(@arte),
    status: :created
  )
end
# AI adaptation: guard params[:media_file].present? → render_error 400 (not nil-out),
# then Arte.new(arte_params); arte_params excludes :media_file entirely.
```

**arte_params pattern — analog** (`app/controllers/api/v1/admin/artes_controller.rb` lines 43-48):
```ruby
# Analog (admin) — includes :media_file:
def arte_params
  params.permit(
    :title, :caption, :scheduled_on, :approval_deadline,
    :external_url, :platform, :media_type, :client_id, :media_file
  )
end
# AI adaptation: remove :media_file from permit list entirely.
```

**Error handling — inherited from base** (`app/controllers/api/v1/base_controller.rb` lines 4-7):
```ruby
rescue_from ActiveRecord::RecordNotFound,        with: :not_found
rescue_from ActiveRecord::RecordInvalid,         with: :unprocessable_entity
rescue_from ActionController::ParameterMissing,  with: :bad_request
# No local rescue needed — use raise ActionController::ParameterMissing for missing from/to.
```

---

### `app/controllers/api/v1/ai/clients_controller.rb` (controller, request-response)

**Analog:** `app/controllers/api/v1/admin/artes_controller.rb` (role-match — same rescue_from pattern)

**Class declaration:**
```ruby
# frozen_string_literal: true

class Api::V1::Ai::ClientsController < Api::V1::Ai::BaseController
```

**RecordNotFound pattern — from BaseController** (`app/controllers/api/v1/base_controller.rb` lines 4-5, 19-21):
```ruby
# Already registered in Api::V1::BaseController:
rescue_from ActiveRecord::RecordNotFound, with: :not_found

def not_found
  render_error(code: "not_found", detail: "Recurso não encontrado", status: :not_found)
end
# Use Client.find(params[:id]) — will raise RecordNotFound automatically → 404.
```

**render_envelope pattern** (`app/controllers/api/v1/base_controller.rb` lines 10-12):
```ruby
def render_envelope(data:, meta: {}, status: :ok)
  render json: { data: data, meta: meta, errors: [] }, status: status
end
# summary action returns a single Hash as data (no serializer class needed).
```

**No existing analog for aggregate summary** — pattern is straightforward ActiveRecord:
```ruby
# Arte.where(client_id:).group(:status).count returns:
# { "pending" => N, "approved" => N, "change_requested" => N, "revised" => N }
# Keys matching Arte.statuses hash keys (string keys from group by enum column)
```

---

### `app/serializers/api/v1/ai/arte_serializer.rb` (utility/serializer, transform)

**Analog:** `app/serializers/api/v1/admin/arte_serializer.rb`

**Full analog to copy verbatim, changing only module name** (lines 1-33):
```ruby
# frozen_string_literal: true

module Api::V1::Admin::ArteSerializer
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
    if arte.media_file.attached?
      arte.media_file.url
    else
      arte.external_url
    end
  end
end
# Change module name to Api::V1::Ai::ArteSerializer — all other lines identical.
```

---

### `config/initializers/rack_attack.rb` (config/middleware, request-response)

**Analog:** self — add one throttle block to existing file

**Existing throttle structure to follow** (lines 4-27):
```ruby
# Pattern: throttle(name, limit:, period:) { |req| identifier_or_nil }
# Identifier returns nil when throttle should NOT apply — preventing side effects on other paths.

throttle("client_portal/password_by_token", limit: 5, period: 20) do |req|
  if req.path.match?(%r{\A/c/[^/]+/(?:session|login)\z}) && req.post?
    req.path.match(%r{\A/c/([^/]+)/})[1]
  end
end

throttle("api/admin_login_by_ip", limit: 5, period: 60) do |req|
  req.ip if req.path == "/api/v1/admin/session" && req.post?
end
```

**New throttle to add** — insert before `Rack::Attack.throttled_responder` assignment (line 30):
```ruby
throttle("api/ai_by_key", limit: 60, period: 60) do |req|
  if req.path.start_with?("/api/v1/ai/")
    req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip.presence
  end
end
```

**Critical:** `.presence` at end returns `nil` for blank string — avoids throttling unauthenticated requests by their shared nil identifier. The `if` guard returns nil implicitly for non-AI paths.

**throttled_responder — do not modify** (lines 30-38):
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
# Already handles /api/ paths with JSON — new AI throttle is covered automatically.
```

---

### `config/routes.rb` (config)

**Analog:** self — fill empty `:ai` namespace (lines 54-56):
```ruby
# Current state:
namespace :ai do
  # Phase 24 resources
end

# Pattern to follow from admin namespace (lines 39-45):
namespace :admin do
  resource :session, only: [ :create ]
  resources :clients, only: [ :index, :create ]
  resources :artes, only: [ :index, :create ] do
    resources :approval_responses, only: [ :index ]
  end
end

# AI namespace replacement:
namespace :ai do
  resources :artes, only: [ :index, :create ]
  resources :clients, only: [] do
    get :summary, on: :member
  end
end
```

---

### `test/controllers/api/v1/ai/artes_controller_test.rb` (test, request-response)

**Analog:** `test/controllers/api/v1/admin/artes_controller_test.rb`

**Setup pattern — adapted for AI key** (analog lines 5-29):
```ruby
# frozen_string_literal: true

require "test_helper"

class Api::V1::Ai::ArtesControllerTest < ActionDispatch::IntegrationTest
  AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

  setup do
    @original_ai_key = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_API_KEY
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    @auth_headers = {
      "Authorization" => "Bearer #{AI_API_KEY}",
      "Content-Type"  => "application/json"
    }
    @client = Client.create!(name: "Cliente AI Teste", password: "SenhaIA123!", active: true)
  end

  teardown do
    ENV["AI_API_KEY"] = @original_ai_key
  end
```

**401 pattern** (analog lines 50-53):
```ruby
test "GET /api/v1/ai/artes sem autenticação retorna 401" do
  get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30",
      headers: { "Content-Type" => "application/json" }
  assert_equal 401, response.status
end
```

**200 + envelope assertion pattern** (analog lines 39-47):
```ruby
test "GET /api/v1/ai/artes retorna 200 com lista paginada" do
  get "/api/v1/ai/artes?from=2026-06-01&to=2026-06-30", headers: @auth_headers
  assert_equal 200, response.status
  body = response.parsed_body
  assert body.dig("meta", "pagination", "total_count").is_a?(Integer)
  assert_equal [], body["errors"]
end
```

**400 for missing period params** (analogous to admin month filter test, lines 154-158):
```ruby
test "GET /api/v1/ai/artes sem from/to retorna 400" do
  get "/api/v1/ai/artes", headers: @auth_headers
  assert_equal 400, response.status
end
```

**Filter assertion pattern** (analog lines 56-83 — client_id filter):
```ruby
test "GET /api/v1/ai/artes?client_id filtra por cliente" do
  # Create artes for two clients, assert only target client's artes returned
  # Mirror exactly analog lines 57-83 but with AI auth headers and from/to params
end
```

**201 create pattern** (analog lines 164-182):
```ruby
test "POST /api/v1/ai/artes com external_url retorna 201" do
  post "/api/v1/ai/artes",
       params: {
         title:        "Arte IA",
         scheduled_on: Date.current.to_s,
         platform:     "instagram",
         media_type:   "image",
         client_id:    @client.id,
         external_url: "https://drive.google.com/file/exemplo"
       }.to_json,
       headers: @auth_headers
  assert_equal 201, response.status
  body = response.parsed_body
  assert_equal "link", body.dig("data", "media_source_type")
  assert_equal [], body["errors"]
end
```

---

### `test/controllers/api/v1/ai/clients_controller_test.rb` (test, request-response)

**Analog:** `test/controllers/api/v1/admin/clients_controller_test.rb` (setup structure)

**Setup pattern** — identical to artes test (same AI key setup above).

**404 pattern:**
```ruby
test "GET /api/v1/ai/clients/0/summary retorna 404 para cliente inexistente" do
  get "/api/v1/ai/clients/0/summary", headers: @auth_headers
  assert_equal 404, response.status
  body = response.parsed_body
  assert_equal "not_found", body.dig("errors", 0, "code")
end
```

**200 summary structure assertion:**
```ruby
test "GET /api/v1/ai/clients/:id/summary retorna campos corretos" do
  # Create artes with various statuses for @client
  get "/api/v1/ai/clients/#{@client.id}/summary", headers: @auth_headers
  assert_equal 200, response.status
  body = response.parsed_body
  data = body["data"]
  assert data.key?("total")
  assert data.key?("approved_count")
  assert data.key?("pending_count")
  assert data.key?("change_requested_count")
end
```

---

### `test/integration/rack_attack_test.rb` (test, event-driven)

**Analog:** self — add new test cases to existing file

**Existing setup pattern to preserve** (lines 3-10):
```ruby
class RackAttackTest < ActionDispatch::IntegrationTest
  def setup
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    @client = Client.create!(...)
  end
```

**New test cases pattern — copy structure from existing** (lines 13-35):
```ruby
# Mirror the "Nth tentativa retorna 429" pattern for AI throttle:
test "60 primeiras requisições AI não retornam 429" do
  # Setup: ENV["AI_API_KEY"] = "ak_test_...", Rack::Attack.cache.store.clear
  # 60.times { get "/api/v1/ai/artes?from=...&to=...", headers: ai_auth }
  # assert_not_equal 429, response.status (check last response)
end

test "61ª requisição AI retorna 429" do
  # 61.times { get "/api/v1/ai/artes?from=...&to=...", headers: ai_auth }
  # assert_equal 429, response.status
end

test "resposta 429 da AI é JSON estruturado" do
  # 61.times { ... }
  # body = response.parsed_body
  # assert_equal "too_many_requests", body.dig("errors", 0, "code")
end
```

**Critical setup addition for AI throttle tests:**
```ruby
# Add to setup block (or in a sub-setup for AI tests):
@original_ai_key = ENV["AI_API_KEY"]
ENV["AI_API_KEY"] = "ak_throttle_test_key"
Rack::Attack.cache.store.clear  # prevent state from other throttle tests
```

---

## Shared Patterns

### Authentication
**Source:** `app/controllers/api/v1/ai/base_controller.rb` (lines 8-23)
**Apply to:** All AI controller files (inherited via `Api::V1::Ai::BaseController`)
```ruby
# Already implemented — do NOT reimplement in child controllers.
# ai key extracted from Authorization: Bearer ak_...
# secure_compare prevents timing attacks
# render_unauthorized on ak_ prefix mismatch or invalid key
```

### Error Handling Envelope
**Source:** `app/controllers/api/v1/base_controller.rb` (lines 10-33)
**Apply to:** All controllers and tests — inherited two levels up
```ruby
def render_envelope(data:, meta: {}, status: :ok)
  render json: { data: data, meta: meta, errors: [] }, status: status
end

def render_error(code:, detail:, status:, field: nil)
  error = { code: code, detail: detail }
  error[:field] = field if field
  render json: { data: nil, meta: {}, errors: [error] }, status: status
end

# rescue_from chain (automatic, no local rescue needed):
rescue_from ActiveRecord::RecordNotFound,        with: :not_found       # → 404
rescue_from ActiveRecord::RecordInvalid,         with: :unprocessable_entity  # → 422
rescue_from ActionController::ParameterMissing,  with: :bad_request     # → 400
```

### Pagination
**Source:** `app/controllers/api/v1/admin/base_controller.rb` (lines 42-57)
**Apply to:** `Api::V1::Ai::BaseController` (add), `Api::V1::Ai::ArtesController` (use)
```ruby
# In BaseController:
include Pagy::Backend
rescue_from Pagy::OverflowError, with: :page_overflow

def pagination_meta(pagy)
  { page: pagy.page, per_page: pagy.limit, total_count: pagy.count, total_pages: pagy.pages }
end

def per_page_param
  [(params[:per_page] || 25).to_i, 100].min.clamp(1, 100)
end

# In ArtesController#index:
@pagy, @artes = pagy(scope, limit: per_page_param)
render_envelope(data: ..., meta: { pagination: pagination_meta(@pagy) })
```

### ActiveStorage URL Resolution
**Source:** `app/controllers/api/v1/admin/base_controller.rb` (lines 34-40)
**Apply to:** `Api::V1::Ai::BaseController` (add `before_action :set_active_storage_current`)
```ruby
def set_active_storage_current
  ActiveStorage::Current.url_options = {
    protocol: request.protocol,
    host:     request.host,
    port:     request.port
  }
end
# Without this, arte.media_file.url raises Missing host to link to!
```

### Throttle Block Structure
**Source:** `config/initializers/rack_attack.rb` (lines 4-27)
**Apply to:** New `"api/ai_by_key"` throttle block
```ruby
# Pattern: return identifier string OR nil (nil = no throttle applied)
throttle("name", limit: N, period: S) do |req|
  <identifier> if <path_condition>
  # implicit nil for other paths
end
```

### Test Auth Header Setup
**Source:** `test/controllers/api/v1/admin/artes_controller_test.rb` (lines 9-29)
**Apply to:** All AI controller test files
```ruby
# AI equivalent (replace JWT with ENV API key):
AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

setup do
  @original_ai_key = ENV["AI_API_KEY"]
  ENV["AI_API_KEY"] = AI_API_KEY
  Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  @auth_headers = {
    "Authorization" => "Bearer #{AI_API_KEY}",
    "Content-Type"  => "application/json"
  }
end

teardown do
  ENV["AI_API_KEY"] = @original_ai_key
end
```

---

## No Analog Found

All files have analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

| File | Note |
|------|------|
| `app/controllers/api/v1/ai/clients_controller.rb` — `summary` action | No aggregate summary action exists anywhere in the codebase, but the pattern is standard ActiveRecord (`group(:status).count`). The controller class structure has a role-match analog. |

---

## Metadata

**Analog search scope:** `app/controllers/api/v1/`, `app/serializers/`, `config/initializers/`, `config/routes.rb`, `test/controllers/api/v1/`, `test/integration/`
**Files scanned:** 12 (9 read + 3 via Bash/directory listing)
**Pattern extraction date:** 2026-06-12
