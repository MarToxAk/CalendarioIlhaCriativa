---
phase: 18-approvalresponse-broadcast-admin-live-rows
reviewed: 2026-06-05T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - app/views/admin/shared/_sidebar_badge.html.erb
  - app/views/admin/shared/_approval_toast.html.erb
  - app/views/admin/shared/_sidebar.html.erb
  - app/views/admin/approvals/_approval_row.html.erb
  - app/views/admin/approvals/index.html.erb
  - app/views/admin/dashboard/_arte_dashboard_row.html.erb
  - app/views/admin/dashboard/index.html.erb
  - app/models/approval_response.rb
  - test/models/approval_response_test.rb
findings:
  critical: 2
  warning: 3
  info: 2
  total: 7
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-06-05
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 18 adds an `after_create_commit :broadcasts_to_admin` callback on `ApprovalResponse` and the associated view partials for admin sidebar badge, toast notification, approval row, and dashboard row. The integration is structurally sound but contains two blockers: a crash-level nil dereference in the custom validator and a stale badge count that permanently misleads the admin when a client approves an arte (as opposed to requesting a change). Three warnings address an N+1 in the broadcast path, an unsafe assumption about which user receives notifications, and an inconsistent nil-safety pattern in a partial. Two info items cover a raw DB query embedded in a sidebar view and an incomplete N+1 test assertion.

---

## Critical Issues

### CR-01: `arte_must_be_pending` crashes with `NoMethodError` when `arte` is nil

**File:** `app/models/approval_response.rb:16`

**Issue:** `belongs_to :arte` is required by default (Rails 5+), but the `belongs_to` presence validation runs in the same validation pass as `arte_must_be_pending`. When `arte` is not set — e.g., `ApprovalResponse.new(decision: :approved).valid?` — `arte` returns `nil` and calling `arte.pending?` raises `NoMethodError` before the `belongs_to` error is ever recorded. The validator does not guard against nil.

**Fix:**
```ruby
def arte_must_be_pending
  return unless arte  # guard against nil arte before calling status methods
  errors.add(:arte, "não está em estado aprovável") unless arte.pending? || arte.revised?
end
```

---

### CR-02: Sidebar badge never updates when decision is `approved` — stale count shown to admin

**File:** `app/models/approval_response.rb:39-43`

**Issue:** The `sidebar-badge` Turbo Stream replace is only emitted when `decision == "change_requested"`. However, when a client subsequently creates an `ApprovalResponse` with `decision: :approved`, `sync_arte_status` transitions the arte to `:approved`, which removes it from `Arte.change_requested` scope. No badge refresh is broadcast for this path. The admin sidebar badge then shows a count that is **permanently too high** until the next full page load.

The symmetrical case — a client approving a previously change-requested arte — is a normal, expected workflow and should trigger a badge decrement.

**Fix:** Always compute and broadcast the badge update, regardless of decision:

```ruby
streams = [
  turbo_stream.append(
    "admin-toast-region",
    partial: "admin/shared/approval_toast",
    locals:  { approval_response: self, arte: arte_with_client }
  ),
  turbo_stream.replace(       # always broadcast — count may decrease on :approved
    "sidebar-badge",
    partial: "admin/shared/sidebar_badge",
    locals:  { badge_count: badge_count }
  ),
  turbo_stream.replace(
    dom_id(arte_with_client),
    partial: "admin/dashboard/arte_dashboard_row",
    locals:  { arte: arte_with_client }
  ),
  turbo_stream.prepend(
    "approvals-tbody",
    partial: "admin/approvals/approval_row",
    locals:  { approval_response: self }
  )
]
```

Also update Test F expectation from 3 to 4 streams, and remove Test E/F distinction (both should be 4).

---

## Warnings

### WR-01: N+1 query for `client` when `_approval_row` partial is rendered via broadcast

**File:** `app/models/approval_response.rb:49-53` / `app/views/admin/approvals/_approval_row.html.erb:3`

**Issue:** The broadcast passes `approval_response: self` to the `_approval_row` partial. Inside the partial, line 3 accesses `approval_response.arte&.client&.name`. While `self.arte` is typically cached in the association target after the record is built, `self.arte.client` is **not** pre-loaded. This fires an additional SELECT for `clients` every time the partial is rendered via broadcast, contradicting the partial's own comment ("caller MUST eager-load arte: :client via joins").

`arte_with_client` is already fetched with `Arte.includes(:client).find(arte_id)` above but is never passed to `_approval_row` — only the undecorated `self` is.

**Fix:** Pass `arte_with_client` to the partial and use it:

```ruby
# in broadcasts_to_admin
turbo_stream.prepend(
  "approvals-tbody",
  partial: "admin/approvals/approval_row",
  locals:  { approval_response: self, arte: arte_with_client }
)
```

```erb
<%# _approval_row.html.erb — use explicit arte local when available %>
<%
  _arte = local_assigns.fetch(:arte, approval_response.arte)
%>
<tr id="<%= dom_id(approval_response) %>" ...>
  <td ...><%= _arte&.client&.name || "—" %></td>
  <td ...><%= _arte.title.presence || "Sem título" %></td>
  ...
  <%= link_to "Ver arte", admin_arte_path(_arte), ... %>
```

---

### WR-02: `User.first` is non-deterministic for multi-admin setups and couples broadcast to insertion order

**File:** `app/models/approval_response.rb:27`

**Issue:** `User.first` returns the user with the lowest primary-key, with no ordering guarantee beyond database default. If this system ever has more than one admin user (or if database row ordering differs from creation order), the wrong user receives notifications — or a non-admin user receives them. There is no `admin` flag on `User` and no scoping to restrict which user is the recipient.

Even for a single-admin system today, the choice is fragile: any accidental seeding of a second `User` record silently misdirects all notifications.

**Fix:** Introduce either a scope or a configuration constant:

```ruby
# Option A: named scope on User
# app/models/user.rb
scope :admin, -> { order(:id).first }  # deterministic

# approval_response.rb
admin = User.admin
```

```ruby
# Option B: dedicated method
# approval_response.rb
admin = User.order(:id).first   # at minimum, make ordering explicit
```

---

### WR-03: Inconsistent nil-safety on `approval_response.arte` within `_approval_row`

**File:** `app/views/admin/approvals/_approval_row.html.erb:3-4`

**Issue:** Line 3 uses safe navigation (`approval_response.arte&.client&.name`), but line 4 calls `approval_response.arte.title.presence` without any guard. If `arte` were nil for any reason (e.g., orphaned record after dependent destroy completes mid-broadcast), line 3 silently renders "—" while line 4 raises `NoMethodError: undefined method 'title' for nil`.

The same unguarded reference appears on line 13 (`admin_arte_path(approval_response.arte)`), which would raise `ActionController::UrlGenerationError` if `arte` is nil.

**Fix:** Either use consistent safe navigation throughout, or assert non-nil once at the top of the partial:

```erb
<%# At the top of _approval_row.html.erb %>
<% _arte = approval_response.arte || raise("_approval_row requires a persisted arte") %>
<td ...><%= _arte.client&.name || "—" %></td>
<td ...><%= _arte.title.presence || "Sem título" %></td>
...
<%= link_to "Ver arte", admin_arte_path(_arte), ... %>
```

---

## Info

### IN-01: Raw DB query (`Arte.where(status:).count`) embedded directly in sidebar view

**File:** `app/views/admin/shared/_sidebar.html.erb:21`

**Issue:** `badge_count = Arte.where(status: :change_requested).count` runs a database query inline in the view on every admin page render. The sidebar is included in the admin layout, so this query executes on every admin page load. The real-time badge is already kept fresh via Turbo Stream replace (RTUP-01), so the initial value only needs to be correct at layout render time — but the query should live in a controller or helper, not in a view partial.

**Fix:** Compute `badge_count` in `Admin::BaseController` (or a before_action helper) and expose it as an instance variable or `content_for` slot, keeping the view free of DB calls.

---

### IN-02: Test G N+1 assertion does not verify `client` pre-loading — only checks `artes` queries

**File:** `test/models/approval_response_test.rb:158-162`

**Issue:** Test G subscribes to `sql.active_record` notifications and asserts that at least one query against `artes` uses a JOIN or IN clause. This validates that `Arte` is loaded with `includes(:client)` on the SQL level. However, the actual N+1 risk described in WR-01 is a **separate** query against the `clients` table when `approval_response.arte.client` is accessed inside `_approval_row`. The test does not grep for `clients` queries and would pass even if the client association is loaded lazily.

**Fix:** Extend the assertion to verify no isolated single-row `clients` SELECT is fired:

```ruby
client_queries = queries.grep(/SELECT.*FROM.*"clients"/i)
# No single-row lookup should occur; client must be batch-loaded with arte
assert_empty client_queries.select { |q| !q.include?("JOIN") && !q.include?(" IN ") },
             "clients must not be loaded via separate N+1 queries"
```

---

_Reviewed: 2026-06-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
