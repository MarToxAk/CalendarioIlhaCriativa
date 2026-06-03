---
phase: 10-arte-form-polish
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - app/views/admin/artes/_form.html.erb
  - app/javascript/controllers/media_type_toggle_controller.js
  - app/views/admin/artes/new.html.erb
  - app/views/admin/artes/edit.html.erb
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 10: Code Review Report

**Reviewed:** 2026-06-03T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Four files reviewed: the shared form partial, Stimulus JS controller, and the two page-level views (new/edit). No security vulnerabilities were found. Three bugs/quality gaps were identified as warnings: field-level validation errors are silently swallowed by the form (users receive no feedback when, e.g., `scheduled_on` is blank), the `caption_only` enum key is displayed as the garbled string "Caption_only" due to misuse of `String#capitalize`, and the `create` action has an asymmetric `media_source` branch relative to `update` (only the `"upload"` case is handled). Two informational items round out the review.

## Warnings

### WR-01: Field-level validation errors are never shown to the user

**File:** `app/views/admin/artes/_form.html.erb:5-11`

**Issue:** The error banner only renders messages from `arte.errors[:base]`. The model validates `:scheduled_on`, `:platform`, `:media_type`, and `:client` with `presence: true`, all of which produce errors on their respective field keys — not on `:base`. When those validations fail, the form re-renders with `status: 422` but the error div is invisible because `arte.errors[:base].any?` returns `false`. The user sees a blank form with no indication of what went wrong.

**Fix:** Display all errors, not only base errors:
```erb
<% if arte.errors.any? %>
  <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
    <ul class="list-disc list-inside space-y-1">
      <% arte.errors.full_messages.each do |msg| %>
        <li><%= msg %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

---

### WR-02: `caption_only` enum key rendered as "Caption_only" in the media type select

**File:** `app/views/admin/artes/_form.html.erb:34`

**Issue:** `Arte.media_types.keys` returns `["image", "video", "caption_only"]`. The view maps them with `.capitalize`, which only upcases the first character and leaves the rest untouched — producing the visible label `"Caption_only"` (lowercase `o`, literal underscore). This is the label a user reads when selecting the media type.

**Fix:** Replace `.capitalize` with a helper or explicit humanization for the media_type select (the platform select on line 30 has the same pattern but happens to be safe because none of its values contain underscores):
```erb
<%= f.select :media_type,
      Arte.media_types.keys.map { |k| [k.humanize, k] }, {},
      class: "..." %>
```
`"caption_only".humanize` returns `"Caption only"`. Apply the same change defensively to the platform select on line 30 for consistency and forward-safety.

---

### WR-03: `create` action lacks the `"link"` branch present in `update` — asymmetric media_source handling

**File:** `app/controllers/admin/artes_controller.rb:27-30` (context for the view's hidden dependency)

**Issue:** The `update` action handles both `when "upload"` (clears `external_url`) and `when "link"` (purges the attached file). The `create` action only handles `when "upload"`. If a user submits the new-arte form with `media_source=link` AND a file attached (possible via devtools or form tampering), the controller does not clear the attachment before save. The `only_one_media_source` model validation then fires and adds a `:base` error ("Use arquivo OU link externo, não ambos"), but this occurs only because the controller neglected to clean the state — the fix belongs in the controller, not the validation. The Stimulus controller mitigates this in the normal flow by hiding the file input when "link" is selected, but that is a client-side guard only.

**Fix:** Add the `"link"` branch to `create` to mirror `update`:
```ruby
def create
  @arte = Arte.new(arte_params)
  case params.dig(:arte, :media_source)
  when "upload"
    @arte.external_url = nil
  when "link"
    # On create the attachment hasn't been persisted yet;
    # clearing the param is sufficient.
    @arte.media_file = nil
  end
  # ...
end
```

---

## Info

### IN-01: Direct database query in the view — `Client.order(:name)` called from the partial

**File:** `app/views/admin/artes/_form.html.erb:70`

**Issue:** The `else` branch (when `arte.client_id` is blank) calls `Client.order(:name)` directly inside the template. Neither `new` nor `create` sets `@clients` in the controller; the query is issued from the view each time the select renders. This violates the MVC separation that the rest of the codebase maintains (`@clients` is only set in `index`).

**Fix:** Set `@clients` in the `new` and `create` (re-render) actions, and reference it from the partial:
```ruby
# admin/artes_controller.rb
def new
  @arte = Arte.new(client: @client)
  @clients = Client.order(:name) unless @client
end

def create
  # on validation failure re-render:
  @clients = Client.order(:name) unless @client
  # ...
end
```
```erb
<%# _form.html.erb line 70 %>
<%= f.select :client_id, @clients.map { |c| [c.name, c.id] }, ... %>
```

---

### IN-02: `toggleFields()` leaves both panels in their server-rendered state when neither radio is checked

**File:** `app/javascript/controllers/media_type_toggle_controller.js:10-18`

**Issue:** `toggleFields()` has an `if/else if` structure: if neither radio is checked, the function returns without touching either panel's visibility. In the same scenario, `togglePills()` (line 25) falls into the `else` branch and applies link-active styles even though no selection has been made. In practice the server always renders one radio as `checked`, so this is an unreachable path under normal conditions — but if the controller's `connect()` fires on a page where the DOM radio state is temporarily inconsistent (e.g., Turbo cache restore of a pre-filled form), the visual state can diverge from the field visibility state.

**Fix:** Add an explicit fallback to `toggleFields()` that defaults to showing the upload field, and align `togglePills()` to use the same guard:
```javascript
toggleFields() {
  if (this.uploadRadioTarget.checked) {
    this.uploadFieldTarget.classList.remove("hidden")
    this.linkFieldTarget.classList.add("hidden")
  } else if (this.linkRadioTarget.checked) {
    this.linkFieldTarget.classList.remove("hidden")
    this.uploadFieldTarget.classList.add("hidden")
  } else {
    // Default: show upload, hide link
    this.uploadFieldTarget.classList.remove("hidden")
    this.linkFieldTarget.classList.add("hidden")
  }
  this.togglePills()
}
```

---

_Reviewed: 2026-06-03T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
