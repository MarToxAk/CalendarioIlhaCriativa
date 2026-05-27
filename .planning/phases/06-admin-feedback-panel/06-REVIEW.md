---
phase: 06-admin-feedback-panel
reviewed: 2026-05-27T04:00:00Z
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
  critical: 3
  warning: 4
  info: 2
  total: 9
status: issues_found
---

# Phase 06: Code Review Report

**Reviewed:** 2026-05-27T04:00:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

This phase introduced the `admin_reply` field (migration + permitting + UI form), the `mark_revised` action, approval-history on the client show page, and a filterable dashboard. Cross-referencing the view conditions, controller guards, and test coverage reveals three blockers: an XSS vector via `raw()` in the confirm modal, a functional break where the admin-reply form is shown for `change_requested` artes but the `update` action rejects them, and a crash path in the dashboard filter when an arbitrary string is passed as `?status=`. Two additional warnings cover a password-plain staleness bug on update and an unreachable-UI test. Two info items cover dead instance variables and a test class naming inconsistency.

---

## Critical Issues

### CR-01: XSS via `raw(body)` in `_confirm_modal` with unescaped `@client.name`

**File:** `app/views/admin/clients/show.html.erb:25` and `:104`

**Issue:** Both `confirm_modal` invocations build the `body:` string with plain Ruby string interpolation of `@client.name`:

```erb
body: "Desativar <strong>#{@client.name}</strong> bloqueará o acesso..."
body: "...link atual de <strong>#{@client.name}</strong> para de funcionar..."
```

The partial `_confirm_modal.html.erb:34` renders that string with `raw(body)`, bypassing Rails' automatic HTML escaping. The `Client` model validates `name` for presence only — no format restriction or sanitization. If an admin creates a client with a name containing HTML, e.g. `</strong><script>alert(document.cookie)</script><strong>`, the script executes for any admin who opens the deactivate or rotate-token modal.

**Fix:** Use `html_escape` (alias `h`) when interpolating user data into the body string, then keep `raw()` in the partial to allow the intended static HTML tags:

```erb
body: "Desativar <strong>#{h(@client.name)}</strong> bloqueará o acesso..."
body: "...link atual de <strong>#{h(@client.name)}</strong> para de funcionar..."
```

Alternatively, pass `name` as a separate local and escape it inside the partial where it is rendered.

---

### CR-02: Admin-reply form shown for `change_requested` arte, but `update` action blocks save

**File:** `app/views/admin/artes/show.html.erb:30` and `app/controllers/admin/artes_controller.rb:71`

**Issue:** The admin-reply form is rendered whenever the arte is `change_requested` **or** `revised`:

```erb
<% if @arte.change_requested? || @arte.revised? %>
  <%= form_with model: [:admin, @arte], method: :patch do |f| %>
    <%= f.text_area :admin_reply ... %>
    ...
  <% end %>
<% end %>
```

But `check_editable` — which runs before `update` — only allows the action to proceed when the arte is `pending` **or** `revised`:

```ruby
def check_editable
  unless @arte.pending? || @arte.revised?
    redirect_to admin_arte_path(@arte), alert: "Edição bloqueada: ..."
  end
end
```

Consequence: the primary use-case for `admin_reply` (responding to a client's `change_requested` arte) is fully blocked. The admin sees the form, submits it, and receives "Edição bloqueada" instead of a saved reply. The reply is silently discarded. The feature does not work.

**Fix:** Add `change_requested?` to the `check_editable` guard, or introduce a dedicated `update_reply` action that is not gated by `check_editable`:

Option A — extend the guard (simplest):
```ruby
def check_editable
  unless @arte.pending? || @arte.revised? || @arte.change_requested?
    redirect_to admin_arte_path(@arte), alert: "Edição bloqueada: ..."
  end
end
```

Option B — dedicated route + action (cleanest, avoids exposing full `arte_params` for `change_requested`):
```ruby
# routes.rb: add member route :patch :update_reply
def update_reply
  if @arte.change_requested? || @arte.revised?
    @arte.update!(admin_reply: params.dig(:arte, :admin_reply))
    redirect_to admin_arte_path(@arte), notice: "Resposta salva."
  else
    redirect_to admin_arte_path(@arte), alert: "Ação inválida."
  end
end
```

---

### CR-03: Dashboard status filter crashes with `ArgumentError` on arbitrary input

**File:** `app/controllers/admin/dashboard_controller.rb:8`

**Issue:**

```ruby
scope = scope.where(status: params[:status]) if params[:status].present?
```

In Rails 7+ (this project uses Rails 8.1), passing an unrecognised string to `where(status:)` on an enum column raises `ArgumentError: 'xyz' is not a valid status`. This is an unhandled exception that results in a 500 response. Any user — or an automated probe — can crash the dashboard by requesting `GET /admin?status=anything`.

**Fix:** Whitelist the value before passing it to the query:

```ruby
allowed_statuses = Arte.statuses.keys  # ["pending", "approved", "change_requested", "revised"]
if params[:status].present? && allowed_statuses.include?(params[:status])
  scope = scope.where(status: params[:status])
end
```

---

## Warnings

### WR-01: `password_plain` becomes stale when admin updates password via edit form

**File:** `app/controllers/admin/clients_controller.rb:36-39`

**Issue:** The `create` action correctly syncs `password_plain` from the submitted `password`:

```ruby
params_with_plain = params_with_plain.merge(password_plain: params_with_plain[:password])
```

But the `update` action does not perform this sync. The edit form (`_form.html.erb`) has only a `password` field, not `password_plain`. When an admin submits a new password, `filtered` contains `password: "newpwd"` (not blank → kept) and omits `password_plain` entirely (it is blank and excluded by the reject block). The model's `update` call updates `password_digest` via `has_secure_password`, but `password_plain` in the database retains the previous value. The client show page then displays the **old** password as the portal password, which is wrong.

**Fix:** Mirror the `create` sync in `update`:

```ruby
def update
  was_active = @client.active
  filtered = client_params.reject { |k, v| ["password", "password_plain"].include?(k) && v.blank? }
  # Keep password_plain in sync with password when password is being changed
  if filtered[:password].present?
    filtered = filtered.merge(password_plain: filtered[:password])
  end
  if @client.update(filtered)
    ...
  end
end
```

---

### WR-02: `update_admin_reply` test verifies an unreachable UI state

**File:** `test/controllers/admin/artes_controller_test.rb:90-94`

**Issue:**

```ruby
test "update_admin_reply persiste campo" do
  patch admin_arte_url(@arte), params: { arte: { admin_reply: "Nota interna do admin" } }
  ...
end
```

`@arte` has `status: :pending`. `check_editable` passes because `pending?` is true. However, the admin-reply form in `show.html.erb` is **never rendered** for pending artes (the guard is `change_requested? || revised?`). The test therefore exercises a PATCH request that cannot be triggered through the UI. More critically, it masks the actual blocker (CR-02): a test for the real use-case (`change_requested` arte) would fail, revealing the bug. This test gives false confidence that `admin_reply` works.

**Fix:** Change the test to use `status: :change_requested` and assert that the save succeeds (after CR-02 is resolved). Also add a test for `status: :revised` to confirm that path works. Remove or rename the `pending` variant if it has no value.

---

### WR-03: `@artes_with_responses` N+1 risk masked by misleading `distinct` + `joins`

**File:** `app/controllers/admin/clients_controller.rb:9-13`

**Issue:**

```ruby
@artes_with_responses = @client.artes
                                .joins(:approval_responses)
                                .includes(:approval_responses)
                                .distinct
                                .order(scheduled_on: :desc)
```

`joins` and `includes` on the same association in Rails can interact unpredictably: depending on Rails version and query shape, Active Record may issue a separate `SELECT approval_responses.*` query for the preload phase rather than using the join's result set. The `distinct` is necessary to undo the duplication from `joins`, but the combination is fragile. If the association preload is not working as expected, each iteration of `@artes_with_responses.each` that calls `arte.approval_responses` will trigger a new query.

**Fix:** Replace the `joins` + `includes` + `distinct` combination with a subquery filter using `where`:

```ruby
@artes_with_responses = @client.artes
                                .where(id: ApprovalResponse.select(:arte_id))
                                .includes(:approval_responses)
                                .order(scheduled_on: :desc)
```

This guarantees a clean preload without the joins-induced row duplication.

---

### WR-04: Dead instance variables in `artes_controller#index`

**File:** `app/controllers/admin/artes_controller.rb:10-12`

**Issue:**

```ruby
@status_options = Arte.statuses.keys
@platform_options = Arte.platforms.keys
# Filtering logic can be added here
```

These two instance variables are not referenced in any view (confirmed by searching `app/views/admin/artes/index.html.erb`). They incur unnecessary database-layer calls and mislead future maintainers into thinking filtering UI exists for the artes index.

**Fix:** Remove both lines until filtering is implemented, or add the corresponding view UI. Do not keep commented-out roadmap notes in controller code.

---

## Info

### IN-01: Test class for `Admin::ClientsController` missing namespace

**File:** `test/controllers/admin/clients_controller_test.rb:3`

**Issue:**

```ruby
class AdminClientsControllerTest < ActionDispatch::IntegrationTest
```

All other admin controller tests follow the convention `Admin::XxxControllerTest`. This one is `AdminClientsControllerTest` (no namespace). Rails integration tests route via path helpers so this does not break test execution, but it breaks the naming convention used throughout the suite, makes the test harder to locate by class name, and can cause confusion when using test runner output or grep.

**Fix:**

```ruby
class Admin::ClientsControllerTest < ActionDispatch::IntegrationTest
```

---

### IN-02: Dashboard filter does not validate `client_id` existence before querying

**File:** `app/controllers/admin/dashboard_controller.rb:7`

**Issue:**

```ruby
scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
```

If `params[:client_id]` is a non-existent ID, the query silently returns an empty result set — no error, no feedback. This is functionally acceptable but can confuse an admin who accidentally pastes a stale ID. Unlike `status` (CR-03), this does not crash, so it is info-level.

**Fix:** Optionally validate that `params[:client_id]` matches a known client ID, or simply accept that an empty result set is self-explanatory for the admin audience.

---

_Reviewed: 2026-05-27T04:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
