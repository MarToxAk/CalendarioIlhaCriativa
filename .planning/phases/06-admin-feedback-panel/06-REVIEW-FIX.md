---
phase: 06-admin-feedback-panel
fixed_at: 2026-05-27T14:30:00Z
review_path: .planning/phases/06-admin-feedback-panel/06-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-05-27
**Source review:** .planning/phases/06-admin-feedback-panel/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (2 Critical + 2 Warning; 4 Info findings out of scope)
- Fixed: 4
- Skipped: 0

Test run after all fixes: `bin/rails test test/controllers/admin/` — 27 runs, 74 assertions, **0 failures, 0 errors, 0 skips**.

## Fixed Issues

### CR-01: Stored XSS — `raw(body)` renders unescaped `@client.name` in confirm modals

**Files modified:** `app/views/admin/clients/show.html.erb`
**Commit:** 1ae12f6
**Applied fix:** Both `body:` string arguments that interpolated `@client.name` directly (lines 25 and 104) were updated to wrap the name with `h()` and mark the strings as `html_safe`. This escapes any HTML special characters in the client name before they reach the `raw()` call in the partial, eliminating the stored XSS vector.

---

### CR-02: `password_plain` directly writable via HTTP, can desync from `password_digest`

**Files modified:** `app/controllers/admin/clients_controller.rb`
**Commit:** 9f1bec9
**Applied fix:** Two changes applied:
1. Removed `:password_plain` from the `permit()` list in `client_params` — now `permit(:name, :password, :active)`.
2. Simplified the `reject` filter in `update` to only exclude blank `"password"` values (since `password_plain` is no longer a permitted param, the old dual-field check was redundant).
The existing sync logic (lines 40-42: `filtered.merge(password_plain: filtered[:password]) if filtered[:password].present?`) was already correct and retained as-is.

---

### WR-01: No direct positive test for `check_editable` allowing `change_requested` and `revised`

**Files modified:** `test/controllers/admin/artes_controller_test.rb`
**Commit:** f215bcb
**Applied fix:** Added two explicit tests immediately after the existing negative test (`should not edit non-pending arte`): one asserting `assert_response :success` for a `GET edit` on a `:change_requested` arte, and one for a `:revised` arte. Both tests update `@arte` status via `update!` then issue the GET request to `edit_admin_arte_url(@arte)`.

---

### WR-02: Dashboard status filter not tested with invalid or missing values

**Files modified:** `test/controllers/admin/dashboard_controller_test.rb`
**Commit:** 21ddb44
**Applied fix:** Added test `filter by invalid status is ignored and returns all artes` that passes `status: "nonexistent_status"` to `GET admin_root_url`, asserts `assert_response :success`, and verifies `@arte.title` is present in the response body — confirming the whitelist guard discards the unknown value and falls back to the full unfiltered result without a 500 error.

---

_Fixed: 2026-05-27_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
