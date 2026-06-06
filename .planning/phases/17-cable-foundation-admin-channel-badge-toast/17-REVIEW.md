---
phase: 17-cable-foundation-admin-channel-badge-toast
reviewed: 2026-06-05T11:38:48Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - app/channels/admin_notifications_channel.rb
  - app/channels/application_cable/channel.rb
  - app/channels/application_cable/connection.rb
  - app/javascript/controllers/toast_controller.js
  - app/views/admin/shared/_sidebar.html.erb
  - app/views/layouts/admin.html.erb
  - test/channels/admin_notifications_channel_test.rb
  - test/channels/application_cable/connection_test.rb
  - test/controllers/admin/dashboard_controller_test.rb
  - test/fixtures/clients.yml
  - test/fixtures/sessions.yml
findings:
  critical: 2
  warning: 3
  info: 1
  total: 6
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-06-05T11:38:48Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

This phase introduces ActionCable infrastructure (Connection, AdminNotificationsChannel), a Stimulus toast controller, a sidebar badge, and integration tests. Two blockers were found: a channel authorization bug that can expose broadcasts to unauthenticated connections, and a fixture missing a required column that will cause the entire test suite to fail to load. Three warnings cover connection authentication edge cases, a raw DB query in a partial, and a fragile test setup. One info item flags a single-shot `_enforceLimit` that does not enforce the stated cap.

---

## Critical Issues

### CR-01: `reject` does not halt execution — `stream_for nil` runs after rejection

**File:** `app/channels/admin_notifications_channel.rb:3-4`

**Issue:** In ActionCable, calling `reject` inside `subscribed` only sets a flag (`@reject_subscription = true`). It does **not** raise or return — execution continues to the next line. When `current_user` is `nil`, line 4 calls `stream_for nil`, which resolves to the broadcast key `"admin_notifications:"` (the channel name with an empty-string model param). Any future broadcast to that key — including accidental ones — would be delivered to the rejected (unauthenticated) connection before the framework calls `reject_subscription` after the callback returns. This is both incorrect behavior and a potential information-disclosure vulnerability.

Verified against ActionCable 8.1.3 source: `stream_from` guards only against `unsubscribed?`, not `subscription_rejected?`. The nil-model broadcast key is a real, subscribable channel name.

**Fix:**
```ruby
def subscribed
  reject and return unless current_user
  stream_for current_user
end
```
Or equivalently:
```ruby
def subscribed
  if current_user
    stream_for current_user
  else
    reject
  end
end
```

---

### CR-02: `clients.yml` fixture missing `access_token` — NOT NULL constraint violation crashes test suite

**File:** `test/fixtures/clients.yml:1-17`

**Issue:** The `clients` table has `t.string "access_token", null: false` (schema.rb:75) with a unique index. The `Client` model uses `has_secure_token :access_token`, which generates the token through a model callback. Rails fixtures bypass all model callbacks, so no token is generated. Loading fixtures will raise a `NOT NULL` constraint violation, causing every test that touches the `clients` fixture (including `connection_test.rb` which calls `clients(:one).access_token` on line 17) to fail at setup time.

**Fix:** Supply deterministic token values directly in the fixture:
```yaml
one:
  name: Client One
  password_digest: <%= BCrypt::Password.create("password") %>
  access_token: token_client_one_fixed_32chars_abc
  active: true

two:
  name: Client Two
  password_digest: <%= BCrypt::Password.create("password") %>
  access_token: token_client_two_fixed_32chars_def
  active: true

inactive:
  name: Inactive Client
  password_digest: <%= BCrypt::Password.create("password") %>
  access_token: token_inactive_client_fixed_32chars
  active: false
```

---

## Warnings

### WR-01: Orphaned session silently falls through to client authentication

**File:** `app/channels/application_cable/connection.rb:10-14`

**Issue:** `set_current_user` returns the result of the `if` expression. If a valid `session_id` cookie exists but the session's associated `user` has been deleted (orphaned session), then `Session.find_by(id:)` succeeds and `self.current_user = session.user` assigns `nil`. The assignment returns `nil`, so `set_current_user` returns `nil` (falsy). The `||` chain then proceeds to `set_current_client`, potentially authenticating the connection as a client entity when the intent was admin-user authentication. The connection does not explicitly reject or log this case.

`Session` belongs_to `:user` without `optional: true`, so this can only occur if the DB constraint is missing or rows are deleted out of band — but the silent fall-through is still a correctness risk.

**Fix:**
```ruby
def set_current_user
  session = Session.find_by(id: cookies.signed[:session_id])
  return nil unless session
  self.current_user = session.user
  current_user  # explicit return; nil if user was deleted
end
```
Consider adding an explicit guard: `return nil unless session&.user`.

---

### WR-02: Raw `Arte.where(...).count` query executed unconditionally in a shared partial

**File:** `app/views/admin/shared/_sidebar.html.erb:21`

**Issue:** `Arte.where(status: :change_requested).count` fires an unscoped `COUNT(*)` query against the entire `artes` table on every admin page render. There is no caching, no per-user scoping, and this query runs even when the result is not displayed (i.e., when `badge_count == 0`). As the `artes` table grows this becomes a recurring query tax on every page load. More importantly: if the application ever supports multiple admin users, this count is not scoped to the current user's clients, which would be a data-visibility issue.

**Fix:** Move the query to the controller and pass it as a helper method or instance variable, where it can be memoized and scoped:
```ruby
# In ApplicationController or a concern
def sidebar_badge_count
  @sidebar_badge_count ||= Arte.where(status: :change_requested).count
end
helper_method :sidebar_badge_count
```
Then in the partial: `badge_count = sidebar_badge_count`.

---

### WR-03: Dashboard controller test creates `User` without `agency_name` — relies on DB default bypassing model validation

**File:** `test/controllers/admin/dashboard_controller_test.rb:5`

**Issue:** `User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")` omits `agency_name`. The `User` model validates `agency_name` with `presence: true` (user.rb:6). This test passes only because the DB column has `default: "Ilha Criativa"` (schema.rb:95), which is applied at the DB level after the model's validation is satisfied by the column default being populated before the INSERT. This is a fragile arrangement: if the DB default is ever removed, or if the validation is ever tightened, the test setup silently breaks without any indication of why.

**Fix:**
```ruby
@user = User.create!(
  email_address: "admin@example.com",
  password: "password",
  password_confirmation: "password",
  agency_name: "Admin Agency"
)
```

---

## Info

### IN-01: `_enforceLimit` removes at most one toast per connect — stated cap of `MAX_TOASTS` is not enforced

**File:** `app/javascript/controllers/toast_controller.js:26-33`

**Issue:** The comment says "the region stays bounded" and `MAX_TOASTS = 3` is the stated cap, but `_enforceLimit` removes only `toasts[0]` (one element) even if `toasts.length` exceeds `MAX_TOASTS` by more than one. If three toasts arrive simultaneously before any `connect()` callback fires (a realistic Turbo Stream batch scenario), the region could end up with more than `MAX_TOASTS` items after the batch. The single-removal logic only enforces `<= MAX_TOASTS` asymptotically (one per connect) rather than absolutely.

**Fix:** Remove all excess toasts in a loop:
```javascript
_enforceLimit() {
  const region = document.getElementById("admin-toast-region")
  if (!region) return
  const toasts = Array.from(region.children)
  const excess = toasts.length - MAX_TOASTS
  if (excess > 0) {
    toasts.slice(0, excess).forEach(t => t.remove())
  }
}
```

---

_Reviewed: 2026-06-05T11:38:48Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
