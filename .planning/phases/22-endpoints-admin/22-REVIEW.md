---
phase: 22-endpoints-admin
reviewed: 2026-06-11T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - app/controllers/api/v1/admin/approval_responses_controller.rb
  - app/controllers/api/v1/admin/artes_controller.rb
  - app/controllers/api/v1/admin/base_controller.rb
  - app/controllers/api/v1/admin/clients_controller.rb
  - app/models/arte.rb
  - app/serializers/api/v1/admin/approval_response_serializer.rb
  - app/serializers/api/v1/admin/arte_serializer.rb
  - app/serializers/api/v1/admin/client_serializer.rb
  - config/routes.rb
  - test/controllers/api/v1/admin/approval_responses_controller_test.rb
  - test/controllers/api/v1/admin/artes_controller_test.rb
  - test/controllers/api/v1/admin/clients_controller_test.rb
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-06-11
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Reviewed the Phase 22 admin JSON API endpoints: controllers for `clients`, `artes`, and `approval_responses`; their serializers; the admin `BaseController`; the `Arte` model; routes; and all three test files.

The inheritance chain is correct — all business controllers extend `Api::V1::Admin::BaseController`, which enforces JWT admin auth. The credential-leak invariant (no `password`/`portal_url` on GET list) is upheld by the serializer and confirmed by test. Strong params correctly exclude `:status` from `arte_params`, blocking status injection on create.

Two blockers were found: a missing `return` keyword in `authenticate_admin_jwt!` that causes `AbstractController::DoubleRenderError` (500) when a valid-scope token references a deleted user, and the storage of client passwords in plaintext in the database. Four warnings cover semantic misuse of `ActionController::ParameterMissing`, unbounded collection fetch in `approval_responses#index`, permitted `:active` on client create, and the password being set twice in `clients#create`. Three info items cover code redundancy and test gaps.

---

## Critical Issues

### CR-01: Missing `return` in `authenticate_admin_jwt!` causes DoubleRenderError (500) on deleted-user JWT

**File:** `app/controllers/api/v1/admin/base_controller.rb:21`

**Issue:** Line 21 calls `render_unauthorized unless @current_user` without a preceding `return`. In Rails, calling `render` inside a `before_action` without `throw :abort` does not halt the filter chain. The action method (e.g., `ArtesController#index`) executes after the before-action returns, calls `render_envelope`, and Rails raises `AbstractController::DoubleRenderError` — returning a 500 to the caller instead of the intended 401.

The trigger condition is a JWT that carries `scope: "admin"` but whose `sub` refers to a user that has since been deleted. All other guard lines use `return render_unauthorized` (lines 14, 15, 18), making line 21 the sole inconsistency. The parallel implementation in `Api::V1::Client::BaseController` correctly uses `return render_unauthorized unless @current_client` (line 16 of that file).

**Fix:**
```ruby
# app/controllers/api/v1/admin/base_controller.rb
@current_user = User.find_by(id: claims[:sub])
return render_unauthorized unless @current_user   # add `return`
```

---

### CR-02: Plaintext password persisted to database (`password_plain` column)

**File:** `app/controllers/api/v1/admin/clients_controller.rb:15`
**Also:** `db/schema.rb:80`, `app/serializers/api/v1/admin/client_serializer.rb:12`

**Issue:** `clients#create` explicitly stores the raw plaintext password in a real database column (`clients.password_plain`, type `string`, introduced in migration `20260525052827`). The controller does `@client.password_plain = params[:password]`, which ActiveRecord persists alongside the bcrypt digest. Any database exposure (backup leak, read replica, SQL injection elsewhere, accidental log of a SELECT *) reveals every client's cleartext password.

The design intent is to allow the admin to display the password once after creation. This can be achieved by keeping `password_plain` as a transient in-memory attribute (a non-persisted `attr_accessor`) and reading it immediately from the instance, rather than writing it to disk.

**Fix:**
```ruby
# In Client model — replace the DB column with a virtual attribute:
attr_accessor :password_plain   # in-memory only; NOT persisted

# Remove migration / drop the column:
# remove_column :clients, :password_plain

# In clients_controller.rb (no change needed — the attribute is set and serialized
# from the same object within a single request lifecycle)
```

The serializer and controller code require no further change once `password_plain` is non-persisted; the value is available on `@client` immediately after `save!` because `password=` (via `has_secure_password`) is called before `save!` and the accessor holds the last assigned value.

---

## Warnings

### WR-01: `ActionController::ParameterMissing` misused for invalid-value validation

**File:** `app/controllers/api/v1/admin/artes_controller.rb:29,37`

**Issue:** `ActionController::ParameterMissing` is designed for missing required parameters. Using it to signal an invalid value (`status=invalido`, `month=nao-data`) is semantically incorrect. The error message rendered will read "param is missing or the value is empty: status" — misleading to API consumers. It also couples filter validation to the wrong exception class; a future developer adding an actual missing-param check nearby may be confused.

**Fix:** Raise a dedicated exception or respond directly:
```ruby
# Option A — respond directly (no exception path needed):
if params[:status].present?
  unless Arte.statuses.key?(params[:status])
    return render_error(code: "invalid_param", detail: "status inválido", status: :bad_request)
  end
  scope = scope.where(status: params[:status])
end

# Option B — define a custom exception and rescue_from it in BaseController.
```

---

### WR-02: `approval_responses#index` fetches all records without pagination

**File:** `app/controllers/api/v1/admin/approval_responses_controller.rb:7`

**Issue:** `@arte.approval_responses` returns every `ApprovalResponse` row for that `Arte` with no `LIMIT`. Under the current business model, the number of responses per arte is small. However, there is no database-level constraint preventing accumulation, and the controller does include `Pagy::Backend` (inherited from `BaseController`) but never uses it here. If the assumption about bounded responses is violated in the future, this silently becomes an unbounded query.

**Fix:**
```ruby
def index
  @pagy, responses = pagy(@arte.approval_responses, limit: per_page_param)
  render_envelope(
    data: Api::V1::Admin::ApprovalResponseSerializer.serialize_collection(
      responses, arte_status: @arte.status
    ),
    meta: { arte_status: @arte.status, pagination: pagination_meta(@pagy) }
  )
end
```

---

### WR-03: `client_params` permits `:active` on POST create, allowing immediate deactivation

**File:** `app/controllers/api/v1/admin/clients_controller.rb:31`

**Issue:** `params.permit(:name, :password, :active)` allows the API caller to create a client with `active: false` in the same request. This is not protected by any guard. If the intent is that newly created clients are always active, the `active` field should be excluded from create's permitted params (and only allowed via a dedicated update or deactivate endpoint). If intentional, it should be documented and tested explicitly — the current test suite has no test for this path.

**Fix:**
```ruby
# Separate create params from update params, or document the intent explicitly:
def client_create_params
  params.permit(:name, :password)  # active defaults to true from DB default
end
```

---

### WR-04: Password set twice in `clients#create` — inconsistency risk

**File:** `app/controllers/api/v1/admin/clients_controller.rb:14-15`

**Issue:** `@client = Client.new(client_params)` receives `password:` via `client_params` (which permits `:password`), causing `has_secure_password` to set `password_digest`. Then line 15 separately assigns `@client.password_plain = params[:password]`. The same `params[:password]` value flows through two different code paths. If `client_params` is modified in the future to exclude `:password`, the `password_digest` will not be set (silent failure with no validation error, since `has_secure_password` validates presence but `password:` nil skips the setter). The dual path creates a maintenance trap.

**Fix:** Remove `:password` from `client_params` and set both attributes explicitly in the action:
```ruby
def create
  @client = Client.new(client_params)     # client_params: only :name, :active
  if params[:password].present?
    @client.password = params[:password]
    @client.password_plain = params[:password]
  end
  @client.save!
  ...
end

def client_params
  params.permit(:name, :active)
end
```

---

## Info

### IN-01: `arte_status` duplicated in every item of the collection AND in `meta`

**File:** `app/controllers/api/v1/admin/approval_responses_controller.rb:8-13`
**Also:** `app/serializers/api/v1/admin/approval_response_serializer.rb:11`

**Issue:** `arte_status` appears once per item in `data[]` (via the serializer) and also as `meta.arte_status`. For a collection of N responses, the same static value is serialized N+1 times. It cannot change between items since it refers to a single `Arte`. The serializer signature requires passing `arte_status:` to each `serialize()` call, which suggests the item-level field was intentional (perhaps for D-11 spec), but the duplication in `meta` is redundant.

**Fix:** Keep `arte_status` only in `meta` (single authoritative location) and remove it from each serialized item, or keep it per-item only and remove from `meta`. Decide based on the API contract spec.

---

### IN-02: Constant duplication in test files (`ADMIN_EMAIL`, `ADMIN_PASSWORD`)

**File:** `test/controllers/api/v1/admin/approval_responses_controller_test.rb:6-7`
**Also:** `test/controllers/api/v1/admin/artes_controller_test.rb:6-7`
**Also:** `test/controllers/api/v1/admin/clients_controller_test.rb:6-7`

**Issue:** `ADMIN_EMAIL = "admin@ilhacriativa.com.br"` and `ADMIN_PASSWORD = "SenhaSegura123!"` are defined identically in all three test files (and also in at least four other test files in the project). If the admin credentials are changed, all copies must be updated in sync.

**Fix:** Extract to a shared `ApiAdminTestHelper` module in `test/support/` and include it:
```ruby
# test/support/api_admin_test_helper.rb
module ApiAdminTestHelper
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"
end
```

---

### IN-03: No test covering JWT-for-deleted-user scenario (the CR-01 scenario)

**File:** `test/controllers/api/v1/admin/clients_controller_test.rb` (and sibling test files)

**Issue:** None of the three test files include a test case where a valid admin-scoped JWT references a user that does not exist in the database. This is the exact scenario that triggers the double-render bug (CR-01). Even after CR-01 is fixed, the absence of this test means regressions can be silently reintroduced.

**Fix:**
```ruby
test "GET retorna 401 quando JWT refere usuário inexistente" do
  jwt_for_ghost = Api::JwtService.encode({ sub: "999999", scope: "admin" })
  get "/api/v1/admin/clients",
      headers: { "Authorization" => "Bearer #{jwt_for_ghost}", "Content-Type" => "application/json" }

  assert_equal 401, response.status
end
```

---

_Reviewed: 2026-06-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
