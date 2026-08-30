---
phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
fixed_at: 2026-08-30T19:59:38Z
review_path: .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/27-REVIEW.md
iteration: 2
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada Code Review Fix Report

**Fixed at:** 2026-08-30T19:59:38Z
**Source review:** .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/27-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 3 (WR-A, WR-B, WR-03-DUP — `fix_scope: critical_warning`, 5 Info findings intentionally left out of scope)
- Fixed: 3
- Skipped: 0

All work was performed in an isolated git worktree (`gsd-reviewfix/27-*` branch) and fast-forwarded
onto `main` after each commit; the worktree was removed on completion. Test/lint verification below
ran inside that worktree, symlinking the main checkout's `.env` (gitignored — for
`ACTIVE_RECORD_ENCRYPTION_*` keys) and pointing `BUNDLE_PATH` at the main checkout's `vendor/bundle`
(also gitignored) so `bin/rails test` and `rubocop` had the same environment as the main repo.

## Fixed Issues

### WR-A: `groups_sync_syncing?` gate turns any unhandled exception into a permanent, self-locking deadlock

**Files modified:** `app/services/evolution/client.rb`, `app/jobs/whatsapp/sync_groups_job.rb`, `test/services/evolution/client_test.rb`, `test/jobs/whatsapp/sync_groups_job_test.rb`
**Commit:** `b51f305`
**Applied fix:** Combined both options the review offered, as defense-in-depth, rather than picking
one:

1. `Evolution::Client.request` now has a broad `rescue Faraday::Error => e; raise
   Evolution::Errors::Unknown, e.message` fallback, placed after the existing specific
   `ConnectionFailed`/`TimeoutError` rescues. This directly fixes the reproduced case
   (`Faraday::ParsingError` from the `:json` response middleware on a malformed 2xx body) by
   funneling it into the already-`retry_on`-covered `Evolution::Errors::Unknown` taxonomy.
2. `Whatsapp::SyncGroupsJob` gained a `discard_on(StandardError) { mark_error(job, "transient") }`
   catch-all as a last line of defense for any exception type raised anywhere inside
   `GroupSynchronizer#call`, not just HTTP-layer ones.

**Important correction to the review's own fix suggestion:** the review's fix text said to place
the catch-all "last… so it only catches what nothing more specific already handled." I verified
empirically (via `ActiveSupport::Rescuable#find_rescue_handler`, which does
`rescue_handlers.reverse_each.detect`) that ActiveJob's handler search checks the **most recently
declared** handler **first**. Placing `discard_on(StandardError)` last would make it the
highest-priority match for every exception, silently swallowing `retry_on Transient`/`Unknown` and
breaking retries entirely — I reproduced this exact failure mode with a throwaway script before
writing the real fix. The catch-all is therefore declared **first** in the class body (before every
`retry_on`/`discard_on`), which — confirmed empirically both via script and the full existing/new
test suite — lets more specific handlers keep taking priority while the catch-all only fires for
otherwise-uncovered exception types. Neither this correction nor the underlying fix touches the
controller's cache-TTL/gate logic (`Admin::WhatsappGroupsController#sync`), so the original WR-02
race protection (two concurrent `GroupSynchronizer#call` runs for the same instance) is untouched.

New regression tests: a `fetch_groups` test reproducing the malformed-JSON-body → `Unknown` mapping;
a job test proving the `StandardError` catch-all clears `groups_sync_state` for an
out-of-taxonomy exception (`Faraday::ParsingError`); and a job test proving the catch-all does
*not* shadow a `Transient` exception that should still retry normally.

### WR-B: No committed regression test exercises CR-01 pagination or WR-02/WR-A sync-gate behavior

**Files modified:** `test/controllers/admin/whatsapp_groups_controller_test.rb`
**Commit:** `72d369b`
**Applied fix:** Added exactly the two tests the review's fix section specified as minimum bar
(the third item — a job test for `retry_on` exhaustion calling `mark_error` — was added in the
WR-A commit above, `b51f305`, since it was more naturally scoped alongside the other job-test
additions there):

1. `#sync` called while `@instance.groups_sync_state == "syncing"` (cache TTL already expired, to
   exercise exactly the window WR-02 closed) redirects with "Sincronização já em andamento." and
   asserts `assert_no_enqueued_jobs`.
2. `#index` with 30 active groups renders exactly 25 checkbox rows on page 1 and the remaining 5 on
   page 2 (`params: { page: 2 }`).

**Verified these are real regression guards, not vacuous assertions:** before committing, I
temporarily reverted the underlying fixes in a scratch copy of each file and re-ran the new tests —
both failed with the exact symptom the review described (1 job enqueued instead of 0 for the gate
test; 30 checkboxes instead of 25 for the pagination test), then restored the files to the fixed
state (confirmed via `git diff` showing no changes) before running the full suite green again.

### WR-03-DUP: `Permanent`/`ConfigurationError` discards record the misleading code `"transient"`

**Files modified:** `app/jobs/whatsapp/sync_groups_job.rb`, `app/helpers/admin/whatsapp_groups_helper.rb`, `test/jobs/whatsapp/sync_groups_job_test.rb`
**Commit:** `58ec5cf`
**Applied fix:** `discard_on(Evolution::Errors::Permanent)` now records `mark_error(job,
"permanent")` and `discard_on(Evolution::Errors::ConfigurationError)` now records `mark_error(job,
"config_error")`, replacing the shared `"transient"` code both previously wrote. Per the review's
second option ("leave them falling through to the generic message intentionally, documented as
such"), `wa_groups_sync_error_message` was left unchanged in behavior — `"permanent"` and
`"config_error"` still fall through to the same generic "tente de novo" copy as `"transient"`
(retry is a reasonable instruction for the admin in all three cases) — but the helper's header
comment was rewritten to enumerate all four current codes and explicitly document that this
fallthrough is intentional, not an oversight. Updated the two existing job tests
(`discard_on Permanent …`, `discard_on ConfigurationError …`) that asserted the old shared
`"transient"` value to assert the new distinct codes.

## Skipped Issues

None — all 3 in-scope findings were fixed.

---

_Fixed: 2026-08-30T19:59:38Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
