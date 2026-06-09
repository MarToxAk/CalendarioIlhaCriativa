---
phase: 20-admin-calendar-chips-real-time
reviewed: 2026-06-09T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - app/helpers/application_helper.rb
  - app/models/approval_response.rb
  - app/models/arte.rb
  - app/views/admin/calendar/_admin_calendar_chip.html.erb
  - app/views/admin/calendar/_calendar_grid.html.erb
  - test/models/approval_response_test.rb
  - test/models/arte_test.rb
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-06-09
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 20 extracted the inline admin calendar chip into `_admin_calendar_chip.html.erb` and wired it into the existing real-time broadcast pipeline via `ApprovalResponse#broadcasts_to_admin` and `Arte#broadcasts_revised_to_all`. The extraction is clean: the partial `id` and every broadcast `target` consistently resolve to `arte_[id]_admin_calendar_chip` through `ActionView::RecordIdentifier.dom_id`. The `arte_status_ring_class` helper maps all four enum values correctly and matches the hex values in `STATUS_MAP` in the Stimulus controller. No leftover inline chip code was found in `_calendar_grid.html.erb`.

Two warnings were found: misleading test names in `approval_response_test.rb` (names say "4 streams" but assertions and descriptions say 5), and a latent N+1 in `Arte#broadcasts_revised_to_all` when the admin chip is rendered without an explicit `includes(:client)` re-fetch. One info item covers code duplication of the two broadcast utility methods across both models.

---

## Warnings

### WR-01: Test names claim 4 turbo streams but implementation asserts 5

**File:** `test/models/approval_response_test.rb:119` and `test/models/approval_response_test.rb:131`

**Issue:** Tests E and F were updated in Phase 20 to verify the new 5th stream (the admin calendar chip replace), but only the assertion value and the failure message were updated — the test *name* string was not. Both tests are named `"… gera 4 turbo streams …"` while the assertion is `assert_equal 5` and the failure message says "5 turbo-stream tags". When these tests fail, the Minitest output prints the test name, which will mislead the developer into believing the expectation is 4 streams.

**Fix:** Rename both tests to match their actual assertion:

```ruby
# line 119
test "change_requested broadcast gera 5 turbo streams" do

# line 131
test "approved broadcast gera 5 turbo streams com badge" do
```

---

### WR-02: `Arte#broadcasts_revised_to_all` renders admin chip with `arte: self` without eagerly loading `:client`

**File:** `app/models/arte.rb:56-59`

**Issue:** The `broadcasts_revised_to_all` callback passes `arte: self` to `render_partial_html` for the `admin/calendar/admin_calendar_chip` partial. The partial accesses `arte.client` three times (line 3 — `client_color`; line 28 — `data-arte-client`; line 39 — initials). No `Arte.includes(:client).find(id)` re-fetch is performed before this render (unlike `ApprovalResponse#broadcasts_to_admin` which does `Arte.includes(:client).find(arte_id)`).

In the primary controller code path (`Admin::ArtesController#mark_revised`), the `:client` association is in the AR cache on `@arte` before `revised!` is called — either populated by `@arte.client` on line 77 of `set_arte`, or by Rails' auto-`inverse_of` when loading via `@client.artes.find`. However, any call to `arte.revised!` from outside that controller flow (console, jobs, tests, future code) will trigger a lazy-load query for each `arte.client` access in the partial, producing an N+1 that is invisible in the current test coverage.

**Fix:** Mirror the pattern used in `ApprovalResponse#broadcasts_to_admin` — re-fetch the arte with `includes` before rendering the admin chip:

```ruby
def broadcasts_revised_to_all
  admin = User.order(:id).first
  return unless admin

  arte_with_client = Arte.includes(:client).find(id)
  badge_count = Arte.change_requested.count

  chip_html  = render_partial_html(
    partial: "client/home/arte_calendar_chip",
    locals:  { arte: arte_with_client, client: arte_with_client.client }
  )
  toast_html = render_partial_html(
    partial: "client/shared/arte_revised_toast",
    locals:  { arte: arte_with_client, client: arte_with_client.client }
  )
  badge_html = render_partial_html(
    partial: "admin/shared/sidebar_badge",
    locals:  { badge_count: badge_count }
  )
  admin_chip_html = render_partial_html(
    partial: "admin/calendar/admin_calendar_chip",
    locals:  { arte: arte_with_client }
  )
  # ... rest unchanged
end
```

---

## Info

### IN-01: `turbo_stream_tag` and `render_partial_html` are duplicated verbatim in two models

**File:** `app/models/arte.rb:78-83` and `app/models/approval_response.rb:66-71`

**Issue:** Both `Arte` and `ApprovalResponse` define identical private `turbo_stream_tag` and `render_partial_html` methods. This duplication means any future change (e.g. adding HTML escaping, changing render options) must be applied in two places.

**Fix:** Extract into a shared concern:

```ruby
# app/models/concerns/broadcastable.rb
module Broadcastable
  private

  def render_partial_html(partial:, locals:)
    ApplicationController.render(partial: partial, locals: locals, formats: [:html])
  end

  def turbo_stream_tag(action, target, template_html = "")
    %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
  end
end
```

Then `include Broadcastable` in both models.

---

_Reviewed: 2026-06-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
