---
phase: 12-arte-show-dashboard-fix
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - app/views/admin/artes/show.html.erb
  - app/views/admin/dashboard/index.html.erb
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-06-03
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed two ERB view files that replaced legacy CSS class names (`btn`, `btn-sm`, `btn-secondary`, `btn-danger`) with Tailwind utility classes and restructured the action bar on the arte show page. The logic-preservation and XSS surface are sound — all output is escaped via standard ERB `<%= %>` tags and no `raw`/`html_safe` calls are present. CSRF is correctly handled through Rails' `form_with` and `button_to` helpers (both emit hidden authenticity tokens automatically). HTTP method spoofing for `:delete` and `:patch` is handled correctly by Rails' `button_to`.

One critical defect was found: the delete confirmation dialog is silently broken because the wrong confirm attribute key is used. Two warnings address a rendering inconsistency on the dashboard "Ver" link and an inverted margin direction on the action bar. One info item flags a dead HTML attribute on a textarea.

---

## Critical Issues

### CR-01: `data: { confirm: }` on Excluir button is silently ignored — delete fires without confirmation

**File:** `app/views/admin/artes/show.html.erb:27-31`

**Issue:** The Excluir `button_to` passes `data: { confirm: "Tem certeza?" }`, which renders as the HTML attribute `data-confirm`. This attribute is processed by **rails-ujs**, which is **not loaded** in this project. The importmap (`config/importmap.rb`) pins only `@hotwired/turbo-rails`; there is no `@rails/ujs` pin and `app/javascript/application.js` imports only Turbo. Turbo listens for `data-turbo-confirm`, not `data-confirm`. The result: clicking "Excluir" submits the delete request immediately with no confirmation dialog, bypassing the intended safety guard and making irreversible deletion a single-click operation.

The `Marcar como Revisada` button on line 34 uses the correct attribute (`form: { data: { turbo_confirm: "..." } }`), so the inconsistency is demonstrably a mistake on the delete button, not an intentional pattern.

**Fix:** Move the confirm string into the `form:` hash using `turbo_confirm`, exactly as the sibling button does:

```erb
<%= button_to "Excluir", admin_arte_path(@arte),
      method: :delete,
      class: "inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors",
      form: { class: "inline", data: { turbo_confirm: "Tem certeza? Esta ação não pode ser desfeita." } } if @arte.pending? && @arte.approval_responses.none? %>
```

---

## Warnings

### WR-01: "Ver" link in dashboard missing `inline-flex items-center` — text will not vertically center

**File:** `app/views/admin/dashboard/index.html.erb:57`

**Issue:** The link receives `h-8` (a fixed height of 2rem) but is rendered as a bare `<a>` element, which defaults to `display: inline`. An inline element ignores the `height` property entirely. The text will overflow the intended bounding box and the border/rounded styling will not produce the pill-button appearance intended. Every action button in `show.html.erb` correctly uses `inline-flex items-center` to activate fixed-height layout.

**Fix:**

```erb
<%= link_to "Ver", admin_arte_path(arte),
      class: "inline-flex items-center h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors" %>
```

### WR-02: Action bar uses `mb-6` (margin-bottom) but is the last element inside the card — margin has no effect on layout

**File:** `app/views/admin/artes/show.html.erb:17`

**Issue:** The action bar `<div class="flex items-center gap-3 mb-6">` is positioned after the article metadata block (lines 4–15) and is the last child inside the outer card `<div>` (which closes at line 41). `mb-6` adds margin below the flex row, inside the card's own `p-6` padding — it does not produce visible separation because the card padding already provides the bottom gap. What is almost certainly intended is `mt-4` or `mt-6` to visually separate the action bar from the metadata rows above it. Without this top margin, the action buttons sit directly beneath the last `<p>` tag with only line-height as separation.

**Fix:**

```erb
<div class="flex items-center gap-3 mt-6">
```

---

## Info

### IN-01: `value: @arte.admin_reply` on `f.text_area` is a dead HTML option

**File:** `app/views/admin/artes/show.html.erb:47-48`

**Issue:** `<textarea>` elements do not have a `value` HTML attribute — their content is placed between the opening and closing tags. Rails' `ActionView::Helpers::FormBuilder#text_area` reads the model attribute (`:admin_reply`) and places it as tag content automatically. The explicit `value: @arte.admin_reply` option is treated as an arbitrary HTML attribute, rendering as `<textarea value="...">`, which browsers ignore. The field still displays the correct value (from the model binding), so this is harmless, but it is misleading: it implies the content depends on the `value:` option when it does not, and it may confuse future maintainers into thinking removal of `value:` would clear the field.

**Fix:** Remove the redundant option:

```erb
<%= f.text_area :admin_reply,
                rows: 4,
                placeholder: "Escreva uma nota interna sobre o pedido de alteração do cliente...",
                class: "block w-full px-3 py-2 border border-gray-200 rounded-lg text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-[#0F7949]/20 focus:border-[#0F7949]" %>
```

---

_Reviewed: 2026-06-03_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
