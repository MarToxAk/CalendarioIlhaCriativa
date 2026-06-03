---
phase: 08-approval-bug-fix
reviewed: 2026-06-02T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - app/views/client/artes/show.html.erb
findings:
  critical: 0
  warning: 1
  info: 1
  total: 2
status: issues_found
---

# Phase 08: Code Review Report

**Reviewed:** 2026-06-02
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

The reviewed file is `app/views/client/artes/show.html.erb`, which received a two-line fix adding `scope: :approval_response` to both `form_with` declarations in the client approval section. The fix is correctly applied on both lines (110 and 123) and resolves the reported "Resposta inválida" bug by ensuring form fields are namespaced under `approval_response[...]` as the controller expects via `params.dig(:approval_response, :decision)`.

Cross-referencing the controller (`Client::ResponsesController`), model (`ApprovalResponse`), route definitions, and the Stimulus `approval_controller.js` confirms the fix is sound and complete. The parameter flow end-to-end is correct. CSRF protection is in place via `csrf_meta_tags` in the client layout. Output of user-supplied data (`resp.comment`, `@arte.caption`) is ERB-escaped by default — no XSS risk. Eager loading of `approval_responses` via `includes` in `set_arte` prevents N+1 on the history list.

Two issues remain in the file that are not related to the fix itself but were exposed during review.

## Warnings

### WR-01: Inconsistent platform capitalization in `<title>` tag

**File:** `app/views/client/artes/show.html.erb:1`
**Issue:** The page title is built with `@arte.platform.capitalize`, which produces `"Linkedin"` for the LinkedIn platform instead of `"LinkedIn"`. The body of the view handles this correctly at lines 53–58 via an explicit `case/when` block with proper casing. The title tag silently diverges from the body display.
**Fix:** Apply the same explicit case logic in the title, or extract a helper:
```erb
<% platform_label = case @arte.platform
   when 'instagram' then 'Instagram'
   when 'facebook'  then 'Facebook'
   when 'linkedin'  then 'LinkedIn'
   else @arte.platform.capitalize
   end %>
<% content_for(:title) { "#{platform_label} · #{I18n.l(@arte.scheduled_on, format: '%d/%m/%Y')} — Ilha Criativa" } %>
```

## Info

### IN-01: Cancel button does not clear the comment textarea

**File:** `app/views/client/artes/show.html.erb:131-135`
**Issue:** The "Cancelar" button calls `approval#hideComment`, which adds the `.hidden` class back to the comment form div but does not clear the `<textarea>` content. If a client types a comment, clicks "Cancelar", then re-opens the form via "Pedir Alteração", the previous draft text is still visible. This may confuse clients into thinking their comment was submitted or cause accidental submission of a stale draft.
**Fix:** Extend the Stimulus controller's `hideComment` action to reset the textarea before hiding:
```javascript
hideComment() {
  const textarea = this.commentFormTarget.querySelector("textarea")
  if (textarea) textarea.value = ""
  this.commentFormTarget.classList.add("hidden")
}
```

---

_Reviewed: 2026-06-02_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
