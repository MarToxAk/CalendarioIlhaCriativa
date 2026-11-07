---
phase: 32-divulga-es-na-api-de-ia
fixed_at: 2026-11-07T00:00:00Z
review_path: .planning/phases/32-divulga-es-na-api-de-ia/32-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 4
skipped: 1
status: partial
---

# Phase 32: Code Review Fix Report

**Fixed at:** 2026-11-07
**Source review:** .planning/phases/32-divulga-es-na-api-de-ia/32-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (CR-01, CR-02, WR-01, WR-02, WR-04; WR-03 was in the review's Warning tier but is out of phase scope, see below)
- Fixed: 4
- Skipped: 1 (WR-03, scope)

**Verification environment:** all checks ran in the main checkout (`workflow.use_worktrees=false`, no worktree created). `bin/rails test` cannot run locally (test DB owned by another OS user), so verification was `ruby -c`, `bin/rubocop` and a `bin/rails runner` script that drove the real controllers through an `ActionDispatch::Integration::Session` inside a pinned, rolled-back transaction (ActiveJob adapter `:test`, AI key generated in-process and never printed, the credentials key bypassed for the run, Active Storage validations stubbed so no file was attached or uploaded). No data was left behind (leftover count 0). The tests added or changed were NOT executed.

## Fixed Issues

### CR-01: Index tests use `index_day + N`, which adds seconds

**Files modified:** `test/controllers/api/v1/ai/divulgacoes_controller_test.rb`
**Commit:** 1331166
**Applied fix:** `index_day` now takes `offset_days` and uses Date arithmetic (`(Date.current + 10 + offset_days).in_time_zone`). The three call sites (`+ 1`, `+ 2` twice) became `index_day(1)` and `index_day(2)`. Checked in the runner that `index_day(1)` falls one calendar day after `index_day`.

### CR-02: Bare `assert_no_enqueued_jobs` after a setup that enqueues Active Storage jobs

**Files modified:** `test/controllers/api/v1/ai/divulgacoes_controller_test.rb`
**Commit:** f04d78b
**Applied fix:** Switched to the block form in `assert_rejected_without_effects` (so every 400/404/422 test) and in the 401 `create` test. This matches the rest of the repo and does not depend on clearing the queue in `setup`.

### WR-01: Malformed `whatsapp_group_ids` entries are silently dropped

**Files modified:** `app/controllers/api/v1/ai/divulgacoes_controller.rb`, `test/controllers/api/v1/ai/divulgacoes_controller_test.rb`
**Commit:** 4ff8154
**Applied fix:** The raw ids are validated against `/\A\d+\z/` before the lookup; anything else returns 400 `bad_request` and nothing is written. `Hash` and empty lists still give 422 "ao menos um grupo" as before. Added two tests (`["abc", id]` and `"<id>abc"`). Runner check: 400 for both payloads, no row created, 201 for numeric ids and numeric strings.
**Status note:** logic change, requires human verification.

### WR-02: `page=abc` / `page=0` returns 500 on the new list endpoints

**Files modified:** `app/controllers/api/v1/ai/divulgacoes_controller.rb`, `app/controllers/api/v1/ai/clients_controller.rb`, `test/controllers/api/v1/ai/divulgacoes_controller_test.rb`, `test/controllers/api/v1/ai/clients_controller_test.rb`
**Commit:** 80980b2
**Applied fix:** Added `rescue_from Pagy::VariableError` to each phase-owned AI controller (not to the shared base controller or `artes#index`), returning 400 `bad_request`. `Pagy::OverflowError` is a subclass of `VariableError`, and the newer handler would shadow the base's 404 handler, so the block delegates back to `page_overflow` for overflow errors and the 404 `page_out_of_range` contract is preserved. Runner check on both endpoints: `page=abc|0|-1` gives 400 `bad_request`, `page=99` gives 404 `page_out_of_range`. Added tests for both endpoints.
**Residual:** `artes#index` still has the same gap (outside this phase's scope).
**Status note:** logic change, requires human verification.

### WR-04: Divulgacao persisted and job enqueued in two steps, no recovery path

**Files modified:** `app/controllers/api/v1/ai/divulgacoes_controller.rb`, `test/controllers/api/v1/ai/divulgacoes_controller_test.rb`
**Commit:** cd9cbb6
**Applied fix:** The review's suggested transaction was NOT used: in production the Solid Queue database is separate (`connects_to ... :queue`), so a transaction would not make the two steps atomic, and a deferred enqueue could fail outside it. Instead the enqueue is rescued: the row is cancelled with `cancelar!` (the `DispatchJob` ignores cancelled rows, so this is safe even if the job was partly enqueued), the error is logged, and the endpoint returns 503 `enqueue_failed` telling the agent nothing is scheduled and it can create again. The compensation is best effort and cannot mask the 503. The contract header comment was updated. Added a test that stubs `DispatchJob.set` to raise (503, row exists and is `cancelada`, no scheduled rows). Runner check confirmed 503 `enqueue_failed` and a `cancelada` row.
**Residual:** the admin controller has the same sequence (not touched, outside phase scope).
**Status note:** logic change, requires human verification.

## Skipped Issues

### WR-03: The row lock in `cancel` protects only one direction of the cancel/dispatch race

**File:** `app/jobs/divulgacoes/dispatch_job.rb:14-17` (counterpart: `app/controllers/api/v1/ai/divulgacoes_controller.rb`)
**Reason:** skipped, out of phase scope (needs job-level lock; follow-up). The fix lives in `app/jobs/`, which phase 32 must not change (additive only).
**Original issue:** `DispatchJob#perform` does `reload`, `return if cancelada?`, then `update!(status: :em_andamento)` without a lock. A cancel that commits between the `reload` and the `update!` is overwritten with `em_andamento`, and the sends proceed although the API already answered 200 "cancelada". Follow-up: wrap the transition in `divulgacao.with_lock { return if status_cancelada?; update!(status: :em_andamento) if status_agendada? }`.

---

_Fixed: 2026-11-07_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
