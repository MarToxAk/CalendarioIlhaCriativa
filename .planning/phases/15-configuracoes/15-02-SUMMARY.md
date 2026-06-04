---
phase: 15-configuracoes
plan: "02"
subsystem: admin-settings
tags: [controller, integration-tests, password-change, agency-name]
dependency_graph:
  requires: [15-01-PLAN.md]
  provides: [Admin::SettingsController, settings integration tests]
  affects: [app/controllers/admin/settings_controller.rb, test/controllers/admin/settings_controller_test.rb]
tech_stack:
  added: []
  patterns: [redirect-based form flow, has_secure_password authenticate, Current.user update]
key_files:
  created:
    - app/controllers/admin/settings_controller.rb
  modified:
    - test/controllers/admin/settings_controller_test.rb
decisions:
  - "Blank password check before mismatch check — more intuitive UX ordering"
  - "Rack::Attack cache cleared in test setup to prevent rate-limit flakiness across tests"
metrics:
  duration: "~10min"
  completed: "2026-06-04"
  tasks_completed: 2
  files_changed: 2
---

# Phase 15 Plan 02: Admin::SettingsController Summary

**One-liner:** Controller with three actions (show/update_password/update_agency) and 7 integration tests covering all redirect scenarios plus rate-limit isolation fix.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Create Admin::SettingsController | 0be130b |
| 2 | Replace test scaffold with full integration tests | 0be130b |

## What Was Built

### Admin::SettingsController (`app/controllers/admin/settings_controller.rb`)

Inherits from `Admin::BaseController` (gains `require_authentication` + `layout 'admin'`).

Three actions:
- `show` — renders settings page (view provided in Wave 3)
- `update_password` — validates current password via `authenticate`, checks blank, checks mismatch, calls `update(password:, password_confirmation:)`
- `update_agency` — calls `update(agency_name:)` with model validation feedback

### Integration Tests (`test/controllers/admin/settings_controller_test.rb`)

8 tests (1 skipped), covering:
- GET show: skipped pending Wave 3 view
- GET show unauthenticated: redirects to login
- PATCH update_password: correct current + valid new → notice + DB updated
- PATCH update_password: wrong current → alert + password unchanged
- PATCH update_password: blank new password → alert
- PATCH update_password: confirmation mismatch → alert
- PATCH update_agency: valid name → notice + DB updated
- PATCH update_agency: blank name → alert + name unchanged

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test flakiness caused by Rack::Attack rate limiter**

- **Found during:** Task 2 verification
- **Issue:** The `admin/login_by_ip` throttle (5 attempts per 60s) uses a `MemoryStore` cache shared across all tests in the same process. After 5 `post session_path` calls (one per test setup), subsequent logins returned HTTP 429 instead of 302, leaving the test without an authenticated session. Tests then redirected to `new_session_path` instead of the expected controller action path. The failure was seed-dependent (first 5 tests to run passed, remaining 3 failed).
- **Fix:** Added `Rack::Attack.cache.store.clear if defined?(Rack::Attack)` at the top of the `setup` block. This resets the rate-limit counters before each test without disabling Rack::Attack globally.
- **Files modified:** `test/controllers/admin/settings_controller_test.rb`
- **Commit:** 0be130b

## Self-Check: PASSED

- [x] `app/controllers/admin/settings_controller.rb` — file exists
- [x] `test/controllers/admin/settings_controller_test.rb` — file exists and updated
- [x] Commit 0be130b exists in git log
- [x] Test suite: 8 runs, 33 assertions, 0 failures, 0 errors, 1 skip (verified across seeds 58329, 12345, 99999, 11111, 47382, 20199)
