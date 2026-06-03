---
phase: 11-arte-index-polish
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - app/views/admin/artes/_arte_row.html.erb
  - app/views/admin/artes/_status_badge.html.erb
  - app/views/admin/artes/index.html.erb
findings:
  critical: 0
  warning: 3
  info: 1
  total: 4
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-06-03T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three view files implementing the arte index UI were reviewed: the table row partial, the status badge partial, and the main index template (which renders both a desktop table and a mobile card list). The implementation is structurally sound and includes eager-loading of `client` records to avoid N+1 queries. No security vulnerabilities were found. Three warnings were identified: two date format inconsistencies that produce different output on desktop vs. mobile for the same user, and dead controller variable assignments that add noise to every index request. One info item flags an incomplete `else` branch in the status badge that would silently display a raw enum key instead of a labelled badge for any future status value.

---

## Warnings

### WR-01: Date year format inconsistent between desktop table and mobile cards

**File:** `app/views/admin/artes/_arte_row.html.erb:4` and `app/views/admin/artes/index.html.erb:59`

**Issue:** The desktop table row renders `scheduled_on` with a four-digit year (`%d/%m/%Y` → "03/06/2026"), while the mobile card list renders the same date with a two-digit year (`%d/%m/%y` → "03/06/26"). A user who switches between viewport sizes — or sees a screenshot from another device — will observe different date strings for the same arte. For dates near century boundaries (2100, or misread as 1926) this can cause genuine confusion.

**Fix:** Align both to the same format. Prefer the four-digit year as it is unambiguous:

```erb
<%# _arte_row.html.erb line 4 — already correct %>
<%= arte.scheduled_on.strftime("%d/%m/%Y") %>

<%# index.html.erb line 59 — change %y to %Y %>
<p class="text-xs text-slate-500 mt-1"><%= arte.scheduled_on.strftime("%d/%m/%Y") %> · <%= arte.platform.humanize %></p>
```

---

### WR-02: Dead variable assignments in controller index action

**File:** `app/controllers/admin/artes_controller.rb:13-14` (affects `app/views/admin/artes/index.html.erb`)

**Issue:** The `index` action assigns three instance variables that `index.html.erb` never reads:

```ruby
@clients         = Client.all           # triggers a full Client table scan
@status_options  = Arte.statuses.keys
@platform_options = Arte.platforms.keys
```

`@clients` performs a database query on every page load. Neither this variable nor the other two are referenced anywhere in `index.html.erb` or any shared partial it renders. They are remnants of a filter UI that was either removed or never built.

**Fix:** Remove the three dead assignments from the `index` action:

```ruby
def index
  @artes = if params[:client_id].present?
    Arte.where(client_id: params[:client_id]).includes(:client).order(scheduled_on: :desc)
  else
    Arte.includes(:client).order(scheduled_on: :desc)
  end
  # Remove: @clients, @status_options, @platform_options
end
```

If a filter UI is planned, keep the assignments but also add the UI; do not leave them as silent dead code.

---

### WR-03: No pagination — unbounded query rendered to both table and card list

**File:** `app/controllers/admin/artes_controller.rb:8-15` and `app/views/admin/artes/index.html.erb:39-61`

**Issue:** The index action fetches all `Arte` records with no page limit. The project already has `pagy` (~> 9.3) in the Gemfile but the index action does not call it. As arte records accumulate, both the `@artes.each` in the desktop table (line 39) and the second `@artes.each` in the mobile card list (line 48) will iterate the entire result set. Note also that `@artes.empty?` (line 12) on an unloaded `ActiveRecord::Relation` that includes `:client` triggers a separate COUNT query followed by the full eager-load query when the `else` branch renders — three database hits total on a non-empty result.

**Fix:** Wire in `pagy`:

```ruby
# Controller
include Pagy::Backend

def index
  scope = Arte.includes(:client).order(scheduled_on: :desc)
  scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
  @pagy, @artes = pagy(scope)
end
```

```erb
<%# index.html.erb — add after the table/card block %>
<%== pagy_nav(@pagy) if @pagy.pages > 1 %>
```

---

## Info

### IN-01: Status badge `else` branch silently degrades for unknown status values

**File:** `app/views/admin/artes/_status_badge.html.erb:15-18`

**Issue:** The `else` branch displays `arte.status.humanize` as the badge label using the same neutral gray style as `"revised"`:

```erb
else
  badge_classes = "bg-gray-50 text-slate-600 border-gray-200"
  badge_label   = arte.status.humanize
end
```

All four current enum values (`pending`, `approved`, `change_requested`, `revised`) are explicitly handled, so this branch is unreachable today. If a fifth status is added to the `Arte` model without a corresponding `when` branch, the badge will render in gray with a humanized key — visually indistinguishable from `"Revisada"`. This is a silent failure mode rather than a crash.

**Fix:** Either raise an explicit error to catch missing cases during development, or add a distinct "unknown" visual style so new statuses are immediately visible during testing:

```erb
else
  badge_classes = "bg-yellow-50 text-yellow-700 border-yellow-300"
  badge_label   = "? #{arte.status.humanize}"
end
```

---

_Reviewed: 2026-06-03T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
