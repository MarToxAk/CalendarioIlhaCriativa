---
phase: 23-endpoints-cliente
reviewed: 2026-06-12T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - app/controllers/api/v1/client/approval_responses_controller.rb
  - app/controllers/api/v1/client/artes_controller.rb
  - app/controllers/api/v1/client/base_controller.rb
  - app/serializers/api/v1/client/approval_response_serializer.rb
  - app/serializers/api/v1/client/arte_serializer.rb
  - config/routes.rb
  - test/controllers/api/v1/client/approval_responses_controller_test.rb
  - test/controllers/api/v1/client/artes_controller_test.rb
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-06-12
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 23 delivers three client API endpoints: `GET /api/v1/client/artes` (index), `GET /api/v1/client/artes/:id` (show), and `POST /api/v1/client/artes/:arte_id/approval_responses` (create). The general design is sound — JWT auth is scoped, cross-client isolation is enforced via AR scopes, the pessimistic lock pattern in the transaction is correct, and the enum guard prevents invalid enum coercion. One critical defect was found: a missing `return` in the authentication filter that permits inactive clients to pass authentication and reach protected actions. Three warnings cover a redundant before-action query, a silent empty-collection mismatch in the index serializer, and a fragile ENV mutation in tests. Two info items flag test coverage gaps.

---

## Critical Issues

### CR-01: Missing `return` allows inactive clients to reach protected actions

**File:** `app/controllers/api/v1/client/base_controller.rb:21`

**Issue:** Line 21 calls `render_unauthorized` without `return` when `@current_client.active?` is false. In Rails, calling `render` inside a `before_action` callback does halt the action chain via the `performed?` mechanism — but only after the current callback method returns. Because `render_unauthorized` does not halt the Ruby call frame, the method proceeds past line 21 to its end. The critical consequence is that `@current_client` is set to an inactive client instance, and if Rails for any reason re-enters the callback (e.g., a future refactor adds code after line 21, or `render_unauthorized` is made conditional), the action will execute with an inactive client. All four other `render_unauthorized` calls in this method correctly use `return render_unauthorized`, making line 21 an inconsistency that is one line of added code away from becoming a live authentication bypass. The inconsistency with the surrounding code also means the implicit contract "this method always returns after rendering" is broken.

**Fix:**
```ruby
# base_controller.rb line 21 — add `return`
return render_unauthorized unless @current_client.active?
```

This aligns with lines 14, 17, and 20 which all use `return render_unauthorized unless ...`.

---

## Warnings

### WR-01: Redundant before-action query in `ApprovalResponsesController#create`

**File:** `app/controllers/api/v1/client/approval_responses_controller.rb:13`

**Issue:** `set_arte` (line 31) issues a `SELECT` to verify ownership and existence, storing the result as `@arte`. Inside `create`, the transaction immediately issues a second `SELECT ... FOR UPDATE` against the same record using `@arte.id` (line 13). For the `create` action, `@arte` is used for nothing other than extracting its `.id`. The double query is not a correctness bug, but it adds a wasted round-trip to every POST request.

**Fix:** Remove the redundant fetch from `set_arte` and perform the scoped lock-find directly inside the transaction, using `params[:arte_id]` rather than `@arte.id`. If `set_arte` is required to support future actions that do need `@arte` before the transaction, document this explicitly.

```ruby
def create
  # ...
  result = Arte.transaction do
    locked_arte = @current_client.artes.lock.find(params[:arte_id])
    # ... rest unchanged
  end
end

# Remove set_arte before_action (or keep for future actions, but not needed now)
```

---

### WR-02: `serialize_collection` silently returns `approval_responses: []` for every index record

**File:** `app/serializers/api/v1/client/arte_serializer.rb:5`

**Issue:** `ArteSerializer.serialize` is shared between `show` (which preloads the association) and `serialize_collection` (which does not). When the association is not loaded, line 5 returns `[]` and the serialized output includes `approval_responses: []` for every arte in the index response. API consumers have no way to distinguish "this arte has no responses" from "the index endpoint never includes responses." An empty array is semantically different from an absent key, and the field name in the response schema for the index (`approval_responses: []`) implies presence, which may mislead clients or automated consumers.

**Fix:** Either omit `approval_responses` entirely from `serialize_collection` by using a separate slim serializer, or pass an explicit keyword to signal which fields to include:

```ruby
def self.serialize(arte, include_responses: false)
  payload = { id: ..., title: ..., ... }
  payload[:approval_responses] = serialize_responses(
    arte.association(:approval_responses).loaded? ? arte.approval_responses : []
  ) if include_responses
  payload
end

# show calls: serialize(@arte, include_responses: true)
# serialize_collection calls: serialize(a) — no approval_responses key emitted
```

---

### WR-03: ENV mutation in test setup is not exception-safe across concurrent or parallel test runners

**File:** `test/controllers/api/v1/client/approval_responses_controller_test.rb:7-8` and `test/controllers/api/v1/client/artes_controller_test.rb:7-8`

**Issue:** Both test files mutate `ENV["JWT_SECRET"]` in `setup` and restore it in `teardown`. Minitest's `teardown` is called after assertion failures, so the pattern is safe for sequential runs. However: (1) if the test process is terminated mid-test (SIGKILL, OOM), the env var is never restored, which can corrupt subsequent test runs; (2) if tests are ever run with `--parallel`, all workers share the same process ENV and will race on `JWT_SECRET`. The same workaround is copy-pasted in both test files, compounding the problem.

**Fix:** Introduce a helper in `test_helper.rb` that uses `stub_env` (e.g., via a thin wrapper or `ClimateControl` gem), or store the JWT secret in a per-request fixture rather than a global ENV. At minimum, extract the pattern into a shared module to avoid duplication:

```ruby
# test/support/jwt_helpers.rb
module JwtHelpers
  def with_test_jwt_secret
    original = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)
    yield
  ensure
    ENV["JWT_SECRET"] = original
  end
end
```

---

## Info

### IN-01: No test for inactive-client authentication rejection

**File:** `test/controllers/api/v1/client/approval_responses_controller_test.rb` and `test/controllers/api/v1/client/artes_controller_test.rb`

**Issue:** The critical code path guarded by `@current_client.active?` (base_controller line 21) has no test coverage. Neither test file includes a case where a JWT is valid but the client has `active: false`. Given that CR-01 identifies this exact line as defective, the absence of this test means the bug would not be caught by the suite.

**Fix:** Add a test in both files (or shared) that creates an inactive client, mints a valid JWT for it, and asserts 401:

```ruby
test "POST retorna 401 para cliente inativo" do
  @client.update!(active: false)
  post "/api/v1/client/artes/#{@arte.id}/approval_responses",
       params: { decision: "approved" }.to_json, headers: @auth_headers
  assert_equal 401, response.status
end
```

---

### IN-02: `per_page_param` has redundant upper-bound guard

**File:** `app/controllers/api/v1/client/base_controller.rb:52`

**Issue:** `[(params[:per_page] || 25).to_i, 100].min.clamp(1, 100)` — the `[x, 100].min` is redundant because `.clamp(1, 100)` already enforces the upper bound of 100. The double enforcement does not cause incorrect behavior but makes the intent harder to read.

**Fix:**
```ruby
def per_page_param
  (params[:per_page] || 25).to_i.clamp(1, 100)
end
```

---

_Reviewed: 2026-06-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
