---
phase: 05-approval-flow
reviewed: 2026-05-26T00:00:00Z
depth: standard
files_reviewed: 16
files_reviewed_list:
  - app/controllers/admin/artes_controller.rb
  - app/controllers/client/responses_controller.rb
  - app/javascript/controllers/approval_controller.js
  - app/models/approval_response.rb
  - app/models/arte.rb
  - app/views/admin/artes/show.html.erb
  - app/views/client/artes/show.html.erb
  - app/views/sessions/new.html.erb
  - config/routes.rb
  - db/migrate/20260524215205_create_clients.rb
  - db/migrate/20260524215208_create_approval_responses.rb
  - db/migrate/20260526000001_allow_multiple_approval_responses.rb
  - db/schema.rb
  - test/controllers/admin/artes_controller_test.rb
  - test/controllers/client/responses_controller_test.rb
  - test/models/approval_response_test.rb
findings:
  critical: 4
  warning: 6
  info: 3
  total: 13
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-05-26T00:00:00Z
**Depth:** standard
**Files Reviewed:** 16
**Status:** issues_found

## Summary

This phase implements the client approval flow: clients can approve or request changes to artes, and admins can mark changed artes as revised. The overall architecture is sound — IDOR is correctly blocked by scoping `@arte` through `@client.artes`, the Stimulus controller is minimal and correct, and the validator guard on `arte_must_be_pending` prevents double-submission at the model layer.

However, four critical issues were found: an unguarded `ArgumentError` raised by Rails enums when an invalid `decision` value is submitted (crashing with 500), a stored plaintext password in the `clients` table (existing security debt surfaced by schema), a missing `rel="noopener noreferrer"` on an admin-facing external link, and a mass-assignment hole where the admin `arte_params` permits `:status` — allowing an admin to directly set any status and bypass the approval state machine entirely. Six warnings cover race conditions, N+1 queries, a dangerous `check_editable` bypass, missing test coverage, and a fragile `token_version` implementation.

---

## Critical Issues

### CR-01: Invalid `decision` value raises unhandled `ArgumentError` (500 error)

**File:** `app/controllers/client/responses_controller.rb:5`

**Issue:** Rails enums raise `ArgumentError` when an unknown string value is assigned. If a client submits `decision=hacked` (or any value not in `{ approved: 0, change_requested: 1 }`), the line `@arte.approval_responses.build(response_params)` raises `ArgumentError: 'hacked' is not a valid decision` before validation runs, producing an unhandled 500 response. Because `decision` comes from user-controlled `params`, this is a denial-of-service vector (any client can crash the action for any arte they own) and leaks a stack trace in development.

**Fix:** Validate and reject invalid values before building the record, or rescue the error:
```ruby
def create
  unless ApprovalResponse.decisions.key?(params.dig(:approval_response, :decision))
    return redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                       alert: "Resposta inválida."
  end
  response = @arte.approval_responses.build(response_params)
  if response.save
    redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                notice: flash_notice_for(response.decision)
  else
    redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                alert: response.errors.full_messages.to_sentence
  end
end
```

---

### CR-02: Plaintext password stored in `clients.password_plain` column

**File:** `db/schema.rb:79`

**Issue:** The schema contains `t.string "password_plain"` on the `clients` table. Cross-referencing `app/controllers/admin/clients_controller.rb` confirms this column is actively populated with the client's plaintext password at creation/update time so that admins can copy it to share with clients. This is a critical security vulnerability: a database read (SQL injection, backup leak, or insider access) exposes every client's password in plaintext. The password is also rendered directly in the admin UI at `app/views/admin/clients/show.html.erb`.

**Fix:** Remove `password_plain`. Generate a random one-time-use token or magic link instead of sharing passwords. If a human-readable credential is business-critical, store a separate short-lived PIN encrypted with `attr_encrypted` or use Rails `has_secure_token` for a separate "share link" pattern. At minimum, encrypt with `ActiveSupport::MessageEncryptor` rather than storing raw text.

---

### CR-03: `:status` permitted in admin `arte_params` — state machine bypass

**File:** `app/controllers/admin/artes_controller.rb:67`

**Issue:** `arte_params` includes `:status` in the permit list. This means any admin (including a compromised or malicious admin account) can submit `arte[status]=approved` on a `create` or `update` request and set the status to any value — `approved`, `change_requested`, `revised` — without going through the `ApprovalResponse` approval flow. This bypasses the state machine, creates artes with inconsistent history (no `ApprovalResponse` record for an `approved` arte), and subverts the audit trail.

**Fix:** Remove `:status` from `arte_params`. Status transitions should only occur through dedicated actions (`mark_revised`, and the `ApprovalResponse` `after_create` callback). If a seed/admin-only override is ever needed, add a separate privileged action with explicit intent.
```ruby
def arte_params
  params.require(:arte).permit(
    :title, :caption, :scheduled_on, :approval_deadline,
    :external_url, :platform, :media_type, :client_id, :media_file
  )
end
```

---

### CR-04: `target: "_blank"` without `rel="noopener noreferrer"` in admin view

**File:** `app/views/admin/artes/show.html.erb:14`

**Issue:** The admin show view renders `link_to @arte.external_url, @arte.external_url, target: "_blank"` without `rel: "noopener noreferrer"`. The `external_url` is admin-supplied, but the omission of `rel` means the opened page can access `window.opener` and navigate the admin tab to a phishing URL (reverse tabnapping). This also applies to any client-supplied content that could reach the admin view in future.

**Fix:**
```erb
<p><strong>Link externo:</strong> <%= link_to @arte.external_url, @arte.external_url,
      target: "_blank", rel: "noopener noreferrer" %></p>
```

---

## Warnings

### WR-01: Race condition — concurrent approval submissions can produce duplicate `ApprovalResponse` records

**File:** `app/models/approval_response.rb:7-9`

**Issue:** The `arte_must_be_pending` validation runs in Ruby and then `sync_arte_status` updates the arte status in an `after_create` callback, both outside a database-level lock. Two concurrent POST requests from the same client can both pass validation (both see the arte as `pending`) before either callback fires, resulting in two `ApprovalResponse` rows with potentially contradictory decisions (e.g., `approved` and `change_requested` simultaneously) and a final arte status determined by whichever callback ran last. The unique index was removed by migration `20260526000001`, so there is no database-level guard.

**Fix:** Wrap the creation in a pessimistic lock on the arte:
```ruby
# In Client::ResponsesController#create
def create
  Arte.transaction do
    arte = @client.artes.lock.find(params[:arte_id])
    response = arte.approval_responses.build(response_params)
    if response.save
      redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                  notice: flash_notice_for(response.decision)
    else
      redirect_to client_arte_path(token: @client.access_token, id: @arte.id),
                  alert: response.errors.full_messages.to_sentence
    end
  end
end
```
Alternatively, add a unique partial index (`WHERE status IN (0, 3)` for pending/revised) at the database level.

---

### WR-02: `check_editable` only checks `pending?` — a `revised` arte can be edited by admin

**File:** `app/controllers/admin/artes_controller.rb:70-74`

**Issue:** The `check_editable` guard only permits editing when the arte is `pending?`. However, based on the approval flow design (`arte_must_be_pending` accepts `pending` OR `revised`), a `revised` arte is in an active cycle where the client is about to re-approve. Allowing admin edits during the `revised` state would change the arte content after the client has already submitted a `change_requested` response, but a separate design question is whether `revised` artes should also be editable. More critically, the `check_deletable` guard has the same ambiguity — it permits deletion of `pending` artes with no responses, which is correct, but there is no guard for `revised` artes (they cannot be deleted because they have at least one response, but this relies on the data flow rather than an explicit check).

If the intent is that `revised` artes should also be editable by admins (to apply the requested changes), fix:
```ruby
def check_editable
  unless @arte.pending? || @arte.revised?
    redirect_to admin_arte_path(@arte), alert: "Edição bloqueada: só é possível editar artes pendentes ou revisadas."
  end
end
```
If the intent is that `revised` artes should NOT be editable, add a test to enforce that invariant.

---

### WR-03: N+1 query — `approval_responses` loaded separately in `show` views without preloading

**File:** `app/views/client/artes/show.html.erb:143` and `app/views/admin/artes/show.html.erb:18`

**Issue:** Both show views call `@arte.approval_responses.any?` or `@arte.approval_responses.none?` and then iterate with `.each`. Neither the `Client::ArtesController#set_arte` nor the `Admin::ArtesController#set_arte` preloads `approval_responses`. This produces 2–3 extra queries per page load (one for `any?`/`none?`, one for `each`). While performance is out of v1 scope, the pattern also has a correctness edge: if Rails reloads the association between the `none?` check in `check_deletable` and the actual `destroy`, a response created concurrently could be missed.

**Fix:**
```ruby
# In set_arte (both controllers)
@arte = Arte.includes(:approval_responses).find(params[:id])
```

---

### WR-04: `responded_at` column is never populated

**File:** `db/migrate/20260524215208_create_approval_responses.rb:7` / `db/schema.rb:51`

**Issue:** The `approval_responses` table has a `responded_at` datetime column that is never written anywhere in the application code. The model has no callback or default to set it; the controller does not set it; there is no migration to backfill it. The column is dead weight that misleads future developers into thinking response timestamps are tracked separately from `created_at`.

**Fix:** Either remove the column with a new migration, or populate it explicitly:
```ruby
# In ApprovalResponse model
before_create { self.responded_at ||= Time.current }
```

---

### WR-05: `token_version` derived from first 8 chars of `access_token` — brittle session invalidation

**File:** `app/models/client.rb:10-12`

**Issue:** `token_version` is `access_token&.first(8)`. The session invalidation check in `ClientController` compares `session[:client_token_version] == @client.token_version`. Because `token_version` is a prefix of the full token, rotating the token (via `rotate_token` admin action) will invalidate all sessions — which is the intended behavior. However, the first 8 characters of two different SecureRandom tokens have a non-zero collision probability. If two successive tokens happen to share the same 8-char prefix (probability ~1/(62^8) per rotation, negligible but non-zero), a session that should be invalidated will remain valid. More practically, this is fragile: if `access_token` is ever `nil` (e.g., during a failed token generation), `token_version` returns `nil`, and `nil == nil` evaluates to `true`, bypassing authentication for any client whose token is nil.

**Fix:** Store a dedicated `token_version` integer column (increment on each rotation) or compare the full token. At minimum, add a nil guard:
```ruby
def token_version
  raise "access_token is nil" if access_token.nil?
  access_token.first(8)
end
```
Or simply remove the indirection and compare `session[:client_access_token] == @client.access_token` directly.

---

### WR-06: `email_address` reflected from params into login form — XSS vector in non-HTTPS contexts

**File:** `app/views/sessions/new.html.erb:38`

**Issue:** The email field is prefilled with `value: params[:email_address]`. Rails `erb` auto-escapes this value, so a direct XSS exploit is prevented. However, the pattern reflects a URL parameter directly into a form field, which enables a phishing vector: an attacker can craft a link like `/session?email_address=victim@example.com` and the victim sees their email pre-filled, increasing trust in a credential-harvesting page. In a strict Content Security Policy environment this is low risk, but combined with an open redirect vulnerability elsewhere it becomes exploitable.

**Fix:** Only prefill from the session (e.g., `session[:email_address]`) if a failed login was submitted, not from raw `params`. Remove the `value: params[:email_address]` line:
```erb
<%# Remove the value: prefill entirely, or only use it after a POST failure %>
<%= form.email_field :email_address, required: true, autofocus: true, ... %>
```

---

## Info

### IN-01: No test for invalid/tampered `decision` param in `Client::ResponsesController`

**File:** `test/controllers/client/responses_controller_test.rb`

**Issue:** There is no test verifying that submitting `decision=invalid_value` (an enum value not in the `approved`/`change_requested` set) is handled gracefully. Given CR-01, this is a coverage gap that would have caught the `ArgumentError` bug.

**Fix:** Add a test:
```ruby
test "POST com decision inválido não cria resposta e retorna sem erro 500" do
  sign_in_as_client(@client_a)
  assert_no_difference "ApprovalResponse.count" do
    post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_a.id),
         params: { approval_response: { decision: "hacked" } }
  end
  assert_response :redirect
  assert flash[:alert].present?
end
```

---

### IN-02: No test for admin `create`/`update` with `:status` param (state machine bypass)

**File:** `test/controllers/admin/artes_controller_test.rb`

**Issue:** There is no test verifying that submitting `arte[status]=approved` via `create` or `update` is rejected. Given CR-03, adding a test would both document the expected behavior and catch any regression if `:status` is accidentally re-added to the permit list.

**Fix:** Add tests:
```ruby
test "create should not accept status from params" do
  post admin_artes_url, params: { arte: { ..., status: :approved } }
  assert Arte.last.pending?, "Status should be pending regardless of param"
end
```

---

### IN-03: Rack Attack throttle for client portal uses path suffix `session|login` but route is only `session`

**File:** `config/initializers/rack_attack.rb:5`

**Issue:** The throttle regex matches `/c/:token/session` or `/c/:token/login`, but from `config/routes.rb` the client session route is only `/c/:token/session` (singular). The `login` alternative is dead — it matches no route. This is not a security hole (the real route is protected), but it adds noise and could mislead future maintainers into thinking `/login` is a valid endpoint.

**Fix:** Simplify the regex to match only the actual route:
```ruby
throttle("client_portal/password_by_token", limit: 5, period: 20) do |req|
  if req.path.match?(%r{\A/c/[^/]+/session\z}) && req.post?
    req.path.match(%r{\A/c/([^/]+)/})[1]
  end
end
```

---

_Reviewed: 2026-05-26T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
