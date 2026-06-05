---
phase: 18-approvalresponse-broadcast-admin-live-rows
reviewed: 2026-06-05T03:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - app/models/approval_response.rb
  - app/views/admin/approvals/_approval_row.html.erb
  - app/views/admin/approvals/index.html.erb
  - app/views/admin/dashboard/_arte_dashboard_row.html.erb
  - app/views/admin/dashboard/index.html.erb
  - app/views/admin/shared/_approval_toast.html.erb
  - app/views/admin/shared/_sidebar_badge.html.erb
  - app/views/admin/shared/_sidebar.html.erb
  - test/models/approval_response_test.rb
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 18: Code Review Report (Post-Gap-Closure)

**Reviewed:** 2026-06-05
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

This is the post-gap-closure review for Phase 18. The three previously identified fixes in plan 18-03 were verified as correctly applied: the nil guard in `arte_must_be_pending` is present (line 16), the badge is always broadcast (4 streams in all decision paths), and `arte_with_client` is passed as a local to the approvals prepend partial (line 48). The custom `turbo_stream_tag` string builder introduced in 18-03 has one new critical defect: it calls `dom_id` as an unqualified instance method that is not available in the model context — this will raise `NoMethodError` at runtime for every `ApprovalResponse` creation. Three warnings remain around N+1 query risk in the broadcast path, fragile admin user lookup, and inconsistent nil-safety in the approval row partial. Two info-level items address a raw DB query in the sidebar view and a weak N+1 test assertion.

---

## Critical Issues

### CR-01: `dom_id` called as instance method in model context — `NoMethodError` at runtime

**File:** `app/models/approval_response.rb:54`

**Issue:** The model calls `dom_id(arte_with_client)` inside `broadcasts_to_admin`. `dom_id` is defined in `ActionView::RecordIdentifier`, which is included into views and helpers but **not** into ActiveRecord model instances. `Turbo::Broadcastable` (auto-included in all ActiveRecord models by turbo-rails engine line 71) does not delegate or re-export `dom_id`. The call therefore raises `NoMethodError: undefined method 'dom_id' for an instance of ApprovalResponse` on every `ApprovalResponse` creation in production. The tests in the file stub `AdminNotificationsChannel.broadcast_to` before `broadcasts_to_admin` is entered, so they do not exercise this line and will not catch the crash.

**Fix:** Replace the bare `dom_id` call with the fully-qualified module reference, which is callable without including the module:

```ruby
# app/models/approval_response.rb, line 54
turbo_stream_tag("replace",
  ActionView::RecordIdentifier.dom_id(arte_with_client),
  dashboard_html),
```

Alternatively, include the module at the top of the class:

```ruby
class ApprovalResponse < ApplicationRecord
  include ActionView::RecordIdentifier
  # ...
end
```

The second option makes `dom_id` available as an instance method throughout the class, which is cleaner if the method is called in more than one place.

---

## Warnings

### WR-01: N+1 query for `arte.client` in `_approval_row` when rendered via broadcast in controller-driven page loads

**File:** `app/views/admin/approvals/_approval_row.html.erb:3`

**Issue:** The partial is called from `index.html.erb` via `render "approval_row", approval_response: ar` (line 53) without an explicit `arte:` local. Inside the partial, `approval_response.arte&.client&.name` on line 3 and `approval_response.arte.title` on line 4 reach through the `approval_response -> arte -> client` association chain. The controller at `Admin::ApprovalsController` does eager-load `arte: :client` with `.includes(arte: :client)`, so the page-load path avoids N+1. However, the partial comment states "caller MUST eager-load arte: :client via joins" — this contract is enforced only for the broadcast path (where `arte: arte_with_client` is passed), not for the controller-driven render which passes only `approval_response:`. If the controller ever changes the scope or if a new caller uses this partial, the silent N+1 will reappear. The partial itself has no defensive include and no documented fallback.

**Fix:** Accept `arte` as an optional local in the partial and default to `approval_response.arte` if absent, removing the ambiguity and making the partial self-documenting:

```erb
<%# _approval_row.html.erb %>
<% _arte = local_assigns.fetch(:arte, approval_response.arte) %>
<tr id="<%= dom_id(approval_response) %>" class="...">
  <td ...><%= _arte&.client&.name || "—" %></td>
  <td ...><%= _arte.title.presence || "Sem título" %></td>
  ...
  <%= link_to "Ver arte", admin_arte_path(_arte), ... %>
</tr>
```

---

### WR-02: Fragile admin user lookup — broadcasts sent to first-inserted user regardless of role

**File:** `app/models/approval_response.rb:28`

**Issue:** `User.order(:id).first` selects the user with the lowest primary key. The `users` table has no `role` or `admin` flag (confirmed via schema). For the current single-admin scenario this is functional, but the selection is purely positional. Any second user record inserted (e.g., during seeding, testing, or a future multi-admin scenario) silently redirects all admin notifications without any error. The model has no guard against `User` being `nil` only when `admin` is nil — the nil guard on line 29 (`return unless admin`) prevents the crash, but the wrong user receiving (or missing) broadcasts is a data correctness bug, not just style.

**Fix:** Name the intent explicitly. At minimum, document that only one `User` row should ever exist. For robustness, add a named scope or constant:

```ruby
# app/models/user.rb
scope :notification_recipient, -> { order(:id).first }

# app/models/approval_response.rb
admin = User.notification_recipient
return unless admin
```

This makes the selection strategy visible and easy to change when the requirement changes.

---

### WR-03: Inconsistent nil-safety on `approval_response.arte` within `_approval_row`

**File:** `app/views/admin/approvals/_approval_row.html.erb:3-4,13`

**Issue:** Line 3 guards against nil arte with `approval_response.arte&.client&.name`. Line 4 calls `approval_response.arte.title.presence` without any nil guard. Line 13 passes `approval_response.arte` directly to `admin_arte_path` without guarding. If `arte` is nil (orphaned record, destroyed mid-request, or partial called without eager-loaded association present), line 3 silently renders "—" while line 4 immediately raises `NoMethodError: undefined method 'title' for nil`. The inconsistency means the partial fails in a less predictable way than it would with a consistent approach.

**Fix:** Establish a single nil check at the top of the partial and use a local variable throughout:

```erb
<% _arte = approval_response.arte %>
<% return if _arte.nil? %> <%# or raise, depending on tolerance %>
<tr id="<%= dom_id(approval_response) %>" ...>
  <td ...><%= _arte.client&.name || "—" %></td>
  <td ...><%= _arte.title.presence || "Sem título" %></td>
  ...
  <%= link_to "Ver arte", admin_arte_path(_arte), ... %>
</tr>
```

---

## Info

### IN-01: Raw DB query embedded in sidebar view partial on every admin page render

**File:** `app/views/admin/shared/_sidebar.html.erb:21`

**Issue:** `badge_count = Arte.where(status: :change_requested).count` runs a database query inline in the view partial. The sidebar is included in the admin layout, so this SELECT runs on every admin page load. The real-time badge is kept fresh via Turbo Stream replace (RTUP-01), but the initial count query belongs in a controller or layout-level `before_action`, not in a view partial.

**Fix:** Move `badge_count` computation to `Admin::BaseController`:

```ruby
# app/controllers/admin/base_controller.rb
before_action :set_badge_count

def set_badge_count
  @badge_count = Arte.change_requested.count
end
```

Then in the sidebar partial:

```erb
<%= render "admin/shared/sidebar_badge", badge_count: @badge_count %>
```

---

### IN-02: Test G N+1 assertion does not verify `client` pre-loading — only checks queries against `artes`

**File:** `test/models/approval_response_test.rb:158-165`

**Issue:** Test G asserts that at least one query against the `artes` table uses a JOIN or IN clause. This confirms that `Arte` itself is not loaded row-by-row. However, the N+1 that WR-01 describes concerns the `clients` table — a subsequent lazy load of `approval_response.arte.client` during partial rendering. The test does not filter for `clients` queries and will pass even if client is loaded via a separate single-row SELECT, making the N+1 guarantee weaker than the comment implies.

**Fix:** Add an assertion on client-table queries:

```ruby
client_queries = queries.grep(/SELECT.*FROM.*"?clients"?/i)
isolated_client_queries = client_queries.reject { |q| q.match?(/JOIN|\ IN\ /i) }
assert_empty isolated_client_queries,
  "clients must not be fetched via isolated N+1 queries — use includes(:client)"
```

---

_Reviewed: 2026-06-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
