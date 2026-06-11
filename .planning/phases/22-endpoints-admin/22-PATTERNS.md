# Phase 22: Endpoints Admin - Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 10 (7 new, 2 modified, 1 existing test infra reference)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `app/controllers/api/v1/admin/base_controller.rb` | base-controller | request-response | `app/controllers/admin/base_controller.rb` + current file | exact (additive) |
| `app/controllers/api/v1/admin/clients_controller.rb` | controller | CRUD | `app/controllers/api/v1/admin/sessions_controller.rb` + `app/controllers/admin/clients_controller.rb` | role-match |
| `app/controllers/api/v1/admin/artes_controller.rb` | controller | CRUD + file-I/O | `app/controllers/admin/artes_controller.rb` + sessions_controller | role-match |
| `app/controllers/api/v1/admin/approval_responses_controller.rb` | controller | request-response | `app/controllers/admin/approvals_controller.rb` | role-match |
| `app/serializers/api/v1/admin/client_serializer.rb` | serializer (PORO) | transform | none (no serializer dir exists yet) | no-analog |
| `app/serializers/api/v1/admin/arte_serializer.rb` | serializer (PORO) | transform + file-I/O | none | no-analog |
| `app/serializers/api/v1/admin/approval_response_serializer.rb` | serializer (PORO) | transform | none | no-analog |
| `config/routes.rb` | config | — | self (lines 37-51) | exact (additive) |
| `test/controllers/api/v1/admin/clients_controller_test.rb` | test | request-response | `test/controllers/api/v1/admin/sessions_controller_test.rb` | exact |
| `test/controllers/api/v1/admin/artes_controller_test.rb` | test | request-response + file-I/O | `test/controllers/api/v1/admin/sessions_controller_test.rb` | role-match |
| `test/controllers/api/v1/admin/approval_responses_controller_test.rb` | test | request-response | `test/controllers/api/v1/admin/sessions_controller_test.rb` | role-match |

---

## Pattern Assignments

### `app/controllers/api/v1/admin/base_controller.rb` (base-controller, additive modification)

**Analog:** Current file (`app/controllers/api/v1/admin/base_controller.rb`) + `app/controllers/admin/base_controller.rb`

**Current file — full content** (lines 1-29):
```ruby
# frozen_string_literal: true

class Api::V1::Admin::BaseController < Api::V1::BaseController
  before_action :authenticate_admin_jwt!

  private

  def authenticate_admin_jwt!
    token = bearer_token
    return render_unauthorized unless token
    return render_unauthorized if token.start_with?("ak_")

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

**Web analog for `include Pagy::Backend`** (`app/controllers/admin/base_controller.rb` lines 1-5):
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
  include Pagy::Backend
end
```

**What to ADD to `Api::V1::Admin::BaseController`** — insert after `before_action :authenticate_admin_jwt!`:
```ruby
include Pagy::Backend
before_action :set_active_storage_current

# shared pagination meta — all business controllers call this
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

def set_active_storage_current
  ActiveStorage::Current.url_options = {
    protocol: request.protocol,
    host:     request.host,
    port:     request.port
  }
end
```

**rescue_from to ADD** (for Pagy overflow) — add to `Api::V1::BaseController` or the admin base:
```ruby
rescue_from Pagy::OverflowError, with: :page_overflow

def page_overflow
  render_error(code: "page_out_of_range", detail: "Página fora do intervalo", status: :not_found)
end
```

---

### `app/controllers/api/v1/admin/clients_controller.rb` (controller, CRUD)

**Primary analog:** `app/controllers/api/v1/admin/sessions_controller.rb` (envelope pattern)
**Secondary analog:** `app/controllers/admin/clients_controller.rb` (params, `password_plain` logic)

**Envelope pattern from sessions_controller** (lines 15-20):
```ruby
render_envelope(
  data: { token: token, expires_in: Api::JwtService::DEFAULT_EXPIRY.to_i },
  status: :created
)
```

**`password_plain` pattern from web clients_controller** (lines 22-26):
```ruby
params_with_plain = client_params
if params_with_plain[:password].present?
  params_with_plain = params_with_plain.merge(password_plain: params_with_plain[:password])
end
@client = Client.new(params_with_plain)
```

**`client_params` from web clients_controller** (line 69):
```ruby
params.require(:client).permit(:name, :password, :active)
# NOTE: API version uses params.permit(...) WITHOUT .require(:client) — flat JSON body
```

**save! + rescue_from pattern** (inherited from `Api::V1::BaseController` lines 5, 24-28):
```ruby
rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
# ...
def unprocessable_entity(exception)
  errors = exception.record.errors.map do |e|
    { code: "validation_error", detail: e.full_message, field: e.attribute.to_s }
  end
  render json: { data: nil, meta: {}, errors: errors }, status: :unprocessable_entity
end
```
Use `@client.save!` — the rescue_from at base level handles `RecordInvalid` automatically.

**Complete controller to create:**
```ruby
# frozen_string_literal: true

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
    @client.password_plain = params[:password] if params[:password].present?
    @client.save!
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
end
```

---

### `app/controllers/api/v1/admin/artes_controller.rb` (controller, CRUD + file-I/O)

**Primary analog:** `app/controllers/admin/artes_controller.rb` (arte_params, media_source logic, index scope)
**Secondary analog:** `app/controllers/admin/approvals_controller.rb` (filter pattern with enum guard)

**`arte_params` from web artes_controller** (line 90):
```ruby
params.require(:arte).permit(:title, :caption, :scheduled_on, :approval_deadline,
  :external_url, :platform, :media_type, :client_id, :media_file, :admin_reply)
# NOTE: API version uses params.permit(...) directly — no :admin_reply (not a user-facing field)
```

**`media_source` cleanup from web artes_controller** (lines 23-27):
```ruby
case params.dig(:arte, :media_source)
when "upload"
  @arte.external_url = nil
end
# API version: no :media_source param — infer from presence of :media_file
# @arte.external_url = nil if params[:media_file].present?
```

**Index scope from web artes_controller** (lines 7-13):
```ruby
@artes = if params[:client_id].present?
  Arte.where(client_id: params[:client_id]).includes(:client).order(scheduled_on: :desc)
else
  Arte.includes(:client).order(scheduled_on: :desc)
end
```

**Enum guard pattern from web approvals_controller** (lines 12-14):
```ruby
if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
  scope = scope.where(decision: params[:decision])
end
# Arte version: Arte.statuses.key?(params[:status]) — same guard idiom
```

**Model enum values to filter by** (from `app/models/arte.rb` line 23):
```ruby
enum :status, { pending: 0, approved: 1, change_requested: 2, revised: 3 }
# Arte.statuses => { "pending" => 0, "approved" => 1, "change_requested" => 2, "revised" => 3 }
```

**Complete controller to create:**
```ruby
# frozen_string_literal: true

class Api::V1::Admin::ArtesController < Api::V1::Admin::BaseController
  def index
    scope = Arte.includes(:client).order(scheduled_on: :desc)
    scope = apply_filters(scope)
    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Admin::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    @arte = Arte.new(arte_params)
    @arte.external_url = nil if params[:media_file].present?
    @arte.save!
    render_envelope(
      data: Api::V1::Admin::ArteSerializer.serialize(@arte),
      status: :created
    )
  end

  private

  def apply_filters(scope)
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    if params[:status].present?
      raise ActionController::ParameterMissing.new(:status) unless Arte.statuses.key?(params[:status])
      scope = scope.where(status: params[:status])
    end
    if params[:month].present?
      begin
        date = Date.strptime(params[:month], "%Y-%m")
        scope = scope.where(scheduled_on: date.beginning_of_month..date.end_of_month)
      rescue Date::Error
        raise ActionController::ParameterMissing.new(:month)
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
end
```

---

### `app/controllers/api/v1/admin/approval_responses_controller.rb` (controller, request-response)

**Primary analog:** `app/controllers/admin/approvals_controller.rb` (scope + pagy pattern)

**Pagy call from web approvals_controller** (lines 16-17):
```ruby
@pagy, @approval_responses = pagy(scope, limit: 25,
  params: { client_id: params[:client_id], decision: params[:decision] }.compact_blank)
```

**`has_many :approval_responses` scope from `app/models/arte.rb`** (line 3):
```ruby
has_many :approval_responses, -> { order(created_at: :desc) }, dependent: :destroy
# arte.approval_responses already ordered desc by the association lambda
```

**`RecordNotFound` rescue from `app/controllers/api/v1/base_controller.rb`** (line 4):
```ruby
rescue_from ActiveRecord::RecordNotFound, with: :not_found
# Arte.find(params[:arte_id]) raises RecordNotFound automatically -> 404
```

**Complete controller to create:**
```ruby
# frozen_string_literal: true

class Api::V1::Admin::ApprovalResponsesController < Api::V1::Admin::BaseController
  before_action :set_arte

  def index
    responses = @arte.approval_responses
    render_envelope(
      data: Api::V1::Admin::ApprovalResponseSerializer.serialize_collection(responses),
      meta: { arte_status: @arte.status }
    )
  end

  private

  def set_arte
    @arte = Arte.find(params[:arte_id])
  end
end
```

---

### `app/serializers/api/v1/admin/client_serializer.rb` (PORO serializer, transform)

**No analog exists** — `app/serializers/` directory does not exist yet. Use PORO module pattern from RESEARCH.md.

**Pattern to follow:**
```ruby
# frozen_string_literal: true

module Api::V1::Admin::ClientSerializer
  def self.serialize(client, include_credentials: false, portal_host: nil)
    data = {
      id:         client.id,
      name:       client.name,
      active:     client.active,
      created_at: client.created_at
    }
    if include_credentials
      data[:password]   = client.password_plain
      data[:portal_url] = "#{portal_host}/c/#{client.access_token}"
    end
    data
  end

  def self.serialize_collection(clients)
    clients.map { |c| serialize(c) }
  end
end
```

**Key constraint from `app/models/client.rb`** (lines 1-3):
```ruby
class Client < ApplicationRecord
  has_secure_token :access_token
  has_secure_password
# password_plain is a DB column set explicitly in create action
# access_token is auto-generated by has_secure_token
```

---

### `app/serializers/api/v1/admin/arte_serializer.rb` (PORO serializer, transform + file-I/O)

**No analog exists.** Active Storage URL generation relies on `ActiveStorage::Current.url_options` being populated by the `set_active_storage_current` before_action added to the base controller.

**Enum string values from `app/models/arte.rb`** (lines 21-23):
```ruby
enum :platform,   { instagram: 0, facebook: 1, linkedin: 2 }, prefix: :platform
enum :media_type, { image: 0, video: 1, caption_only: 2 }
enum :status,     { pending: 0, approved: 1, change_requested: 2, revised: 3 }
# arte.platform, arte.media_type, arte.status all return the string key (e.g. "instagram")
```

**`has_one_attached` and media determination from `app/models/arte.rb`** (lines 4, 86-93):
```ruby
has_one_attached :media_file

def media_source_present
  return if media_file.attached? || external_url.present?
  errors.add(:base, "Precisa de arquivo ou link externo")
end
# media_file.attached? is the authoritative check for upload vs. link
```

**Pattern to follow (using `arte.media_file.url` — no url_helpers needed):**
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
      arte.media_file.url   # uses ActiveStorage::Current.url_options set by before_action
    else
      arte.external_url
    end
  end
end
```

---

### `app/serializers/api/v1/admin/approval_response_serializer.rb` (PORO serializer, transform)

**No analog exists.** Follows same PORO module pattern.

**Enum values from `app/models/approval_response.rb`** (line 4):
```ruby
enum :decision, { approved: 0, change_requested: 1 }
# approval_response.decision returns "approved" or "change_requested"
```

**Pattern to follow** (assinatura definitiva — `arte_status:` como kwarg, decisão do planner em 22-01 supera a versão N+1 acima):
```ruby
# frozen_string_literal: true

module Api::V1::Admin::ApprovalResponseSerializer
  def self.serialize(approval_response, arte_status:)
    {
      id:           approval_response.id,
      decision:     approval_response.decision,
      comment:      approval_response.comment,
      responded_at: approval_response.responded_at,
      created_at:   approval_response.created_at,
      arte_status:  arte_status
    }
  end

  def self.serialize_collection(responses, arte_status:)
    responses.map { |r| serialize(r, arte_status: arte_status) }
  end
end
```

**Important (N+1 resolvido):** NÃO usar `approval_response.arte.status` dentro do serializer — isso dispara um N+1 por resposta. Em vez disso, o `arte_status` é passado como **kwarg obrigatório** a partir do `@arte` já carregado no controller (`ApprovalResponseSerializer.serialize_collection(responses, arte_status: @arte.status)`). Como `approval_response.arte_id == @arte.id`, o status é o mesmo para todas as respostas. **Esta assinatura (com `arte_status:` kwarg) é a autoritativa** — os planos 22-01 e 22-04 dependem dela; seguir esta versão, não a variante sem kwarg.

---

### `config/routes.rb` (config, additive modification)

**Analog:** Current file lines 37-51 — extend the existing `namespace :admin` block inside `namespace :v1`.

**Existing block to modify** (`config/routes.rb` lines 37-51):
```ruby
namespace :api, defaults: { format: :json } do
  namespace :v1 do
    namespace :admin do
      resource :session, only: [ :create ]   # POST /api/v1/admin/session  ← keep this
    end

    namespace :client do
      resource :session, only: [ :create ]
    end

    namespace :ai do
      # Phase 24 resources
    end
  end
end
```

**Lines to add inside `namespace :admin do`:**
```ruby
resources :clients, only: [:index, :create]
resources :artes, only: [:index, :create] do
  resources :approval_responses, only: [:index]
end
```

**Resulting routes generated:**

| Method | Path | Controller#Action |
|---|---|---|
| GET | /api/v1/admin/clients | api/v1/admin/clients#index |
| POST | /api/v1/admin/clients | api/v1/admin/clients#create |
| GET | /api/v1/admin/artes | api/v1/admin/artes#index |
| POST | /api/v1/admin/artes | api/v1/admin/artes#create |
| GET | /api/v1/admin/artes/:arte_id/approval_responses | api/v1/admin/approval_responses#index |

---

### Test files (controller, request-response)

**Analog:** `test/controllers/api/v1/admin/sessions_controller_test.rb` — copy this file's setup/teardown verbatim for every new test file.

**Full setup/teardown pattern** (lines 5-24, 32-34):
```ruby
class Api::V1::Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password              = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    @user = User.find_by!(email_address: ADMIN_EMAIL)
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end
```

**Auth header construction pattern** (lines 26-30):
```ruby
post "/api/v1/admin/session",
     params: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD }.to_json,
     headers: { "Content-Type" => "application/json" }
# For authenticated requests in new tests:
# @admin_jwt = Api::JwtService.encode({ sub: @user.id.to_s, scope: "admin" })
# @auth_headers = { "Authorization" => "Bearer #{@admin_jwt}", "Content-Type" => "application/json" }
```

**Response assertion pattern** (lines 33-37):
```ruby
body = response.parsed_body
assert body.dig("data", "token").present?, "..."
assert_equal [], body["errors"], "..."
# For new tests:
# assert_equal 200, response.status
# assert body.dig("meta", "pagination", "total_count").is_a?(Integer)
# assert_equal [], body["errors"]
```

**Multipart upload test pattern** (no existing analog — use Rails built-in):
```ruby
# Do NOT set Content-Type when using fixture_file_upload
file = fixture_file_upload(Rails.root.join("test/fixtures/files/sample.jpg"), "image/jpeg")
post "/api/v1/admin/artes",
     params: { title: "Arte Teste", ..., media_file: file },
     headers: { "Authorization" => "Bearer #{@admin_jwt}" }
     # No Content-Type header — Rack auto-detects multipart
```

**ActionCable side-effect guard for artes tests** (from `app/models/arte.rb` lines 37-42):
```ruby
# Arte#broadcasts_revised_to_all calls User.order(:id).first
# Ensure @user is created in setup (already done by the sessions_controller_test pattern above)
# The existing setup block creates @user, which prevents nil errors in Arte callbacks
```

---

## Shared Patterns

### Authentication (apply to all 3 new controllers — inherited automatically)

**Source:** `app/controllers/api/v1/admin/base_controller.rb` lines 4, 8-19
```ruby
before_action :authenticate_admin_jwt!

def authenticate_admin_jwt!
  token = bearer_token
  return render_unauthorized unless token
  return render_unauthorized if token.start_with?("ak_")
  claims = Api::JwtService.decode(token)
  return render_unauthorized unless claims[:scope] == "admin"
  @current_user = User.find_by(id: claims[:sub])
  render_unauthorized unless @current_user
rescue Api::Errors::TokenExpired, Api::Errors::TokenInvalid
  render_unauthorized
end
```
No action needed in the new controllers — `inherit from Api::V1::Admin::BaseController` is sufficient.

### Response Envelope (apply to all render calls)

**Source:** `app/controllers/api/v1/base_controller.rb` lines 10-18
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
Call `render_envelope(data: ..., meta: {...})` — never call `render json:` directly in new controllers.

### Error Handling (apply to all save!/create!/find calls)

**Source:** `app/controllers/api/v1/base_controller.rb` lines 4-6
```ruby
rescue_from ActiveRecord::RecordNotFound,        with: :not_found
rescue_from ActiveRecord::RecordInvalid,         with: :unprocessable_entity
rescue_from ActionController::ParameterMissing,  with: :bad_request
```
Use `save!`/`find` (not `save`/`find_by`) so exceptions propagate to `rescue_from`. Do not write local `rescue` blocks.

### Paginação (apply to clients#index and artes#index)

**Source:** `app/controllers/admin/approvals_controller.rb` lines 16-17 + `app/controllers/admin/base_controller.rb` line 4
```ruby
include Pagy::Backend   # in base controller

@pagy, @records = pagy(scope, limit: 25)
# Use limit: (not items: or per_page:) — Pagy 9.x parameter name
```
`pagination_meta` and `per_page_param` helpers are added to `Api::V1::Admin::BaseController` — call them from index actions without redefining.

### Strong Params — flat JSON (apply to all new controllers)

**Source:** `app/controllers/api/v1/admin/sessions_controller.rb` lines 5-7
```ruby
user = User.find_by(email_address: params.require(:email).strip.downcase)
# params.require(:field) on the root — no resource wrapper
```
All API controllers use `params.permit(...)` or `params.require(:field)` at root level. Never use `params.require(:arte)` or `params.require(:client)` — the mobile app sends flat JSON, not nested under a resource key.

---

## No Analog Found

Files with no close match in the codebase (planner uses RESEARCH.md PORO patterns):

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `app/serializers/api/v1/admin/client_serializer.rb` | serializer | transform | No serializer layer exists in this project yet — `app/serializers/` directory does not exist |
| `app/serializers/api/v1/admin/arte_serializer.rb` | serializer | transform + file-I/O | Same; Active Storage URL generation via `arte.media_file.url` (Blob#url, blob.rb line 235) |
| `app/serializers/api/v1/admin/approval_response_serializer.rb` | serializer | transform | Same; no prior PORO serializer to copy from |

For these three files, use the PORO module patterns documented in the Pattern Assignments section above (derived from RESEARCH.md code examples, validated against model attribute names read from source).

---

## Metadata

**Analog search scope:** `app/controllers/api/v1/`, `app/controllers/admin/`, `app/models/`, `test/controllers/api/v1/admin/`, `config/routes.rb`
**Files read:** 13
**Pattern extraction date:** 2026-06-11
