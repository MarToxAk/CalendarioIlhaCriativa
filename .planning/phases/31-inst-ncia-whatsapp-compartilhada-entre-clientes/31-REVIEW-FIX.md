---
phase: 31
fixed_at: 2026-08-31T19:30:27Z
review_path: .planning/phases/31-inst-ncia-whatsapp-compartilhada-entre-clientes/31-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 31: Code Review Fix Report

**Fixed at:** 2026-08-31T19:30:27Z
**Source review:** .planning/phases/31-inst-ncia-whatsapp-compartilhada-entre-clientes/31-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (Warning only — `fix_scope: critical_warning`; the review's Critical section was empty, and the 3 Info findings were out of scope and left untouched)
- Fixed: 3
- Skipped: 0

**Verification environment:** `workflow.use_worktrees` is `false` in `.planning/config.json`, so all edits, verification, and commits ran directly in the main checkout (no isolated worktree was created). All test runs below are reproducible from this same working tree/branch.

## Fixed Issues

### WR-01: Webhook fan-out has no per-sibling exception isolation

**File:** `app/controllers/webhooks/evolution_controller.rb:22-27`
**Files modified:** `app/controllers/webhooks/evolution_controller.rb`, `test/controllers/webhooks/evolution_controller_test.rb`
**Commits:** `c6b93f4` (fix), `07a76b4` (test correction — see below)
**Applied fix:** Wrapped the per-sibling `apply_event(instance)` call in a new private `apply_event_safely` method that rescues `StandardError`, logs the failing sibling's id/class/message, and lets `find_each` continue to the remaining siblings. The endpoint still always responds `:ok` for a signature-valid, known-instance event (matches existing "never trigger an unnecessary Evolution-side retry" behavior), even if one sibling's `save!`/`update!` raises. No transaction wraps the whole loop — per-row idempotent isolation is what the finding asked for, not all-or-nothing rollback of already-processed siblings.

Added a regression test proving a mid-loop failure on one sibling (lower id) does not prevent a later sibling (higher id, processed after the failure) from still receiving the new `connection_state`. The first attempt at this test stubbed `save!` via `define_singleton_method` on a local object reference — but `siblings.find_each` in the controller loads **fresh** AR instances from the DB, so that stub never applied to the row actually processed. Commit `07a76b4` corrects the test to patch `WhatsappInstance#save!` at the class level (conditioned on the failing row's id, restored via `ensure`), which is the reachable seam given `find_each`'s reload-from-DB semantics.

**Test run:** `bin/rails test test/controllers/webhooks/evolution_controller_test.rb` → 14 runs, 43 assertions, 0 failures, 0 errors.

### WR-02: "Sincronizar grupos" guard keyed per row id instead of per shared `instance_name`

**File:** `app/controllers/admin/whatsapp_groups_controller.rb:24-38` (guard); `app/services/whatsapp/group_synchronizer.rb:21-65` (fan-out, unchanged — see note below)
**Files modified:** `app/controllers/admin/whatsapp_groups_controller.rb`, `test/controllers/admin/whatsapp_groups_controller_test.rb`
**Commit:** `45a8d13`
**Applied fix:** Two changes to `#sync`, both narrowly scoped to the guard/throttle (the `GroupSynchronizer` fan-out logic itself was left untouched — see rationale below):
1. The 15s cache throttle key changed from `"wa_groups_sync_#{@instance.id}"` to `"wa_groups_sync_#{@instance.instance_name}"`, so a double-click from a sibling client's own admin panel is throttled too, not just re-clicks from the same client.
2. The state guard changed from `@instance.groups_sync_syncing?` (only the current row's own state) to `@instance.siblings.groups_sync_syncing.exists?` — this checks the enum-generated scope across **all** sibling rows sharing the `instance_name` (siblings includes `@instance` itself per the model's existing `def siblings`), so a second client sharing the connection is blocked for the entire duration of a sibling's in-flight sync job, not just during the 15s cache window.

This closes the race the reviewer described: previously, two sibling clients could each pass their own row-scoped guard and enqueue two `Whatsapp::SyncGroupsJob`s for the same physical connection with different `batch_started_at` values, letting the later job's deactivation pass spuriously deactivate a group the earlier job had just (re)synced. With the guard now checking `siblings.groups_sync_syncing`, only one sibling can be `:syncing` at a time — a second client's `#sync` POST is blocked until the in-flight `GroupSynchronizer#call` finishes and marks every sibling's `groups_sync_state` back to `:idle` (existing behavior in `group_synchronizer.rb:59-61`, unchanged).

`GroupSynchronizer` itself was intentionally left unmodified: its `batch_started_at`-based deactivation pass is only racy when **two concurrent jobs** run for the same `instance_name`, and the widened guard now makes that concurrently-enqueued scenario unreachable through the UI entry point the reviewer flagged. Touching the synchronizer's internals (e.g. adding a job-level lock) would have gone beyond what this finding called for.

Verified the `groups_sync_syncing` scope exists and resolves correctly via `bin/rails runner` (`WhatsappInstance.groups_sync_syncing.to_sql` → `WHERE "whatsapp_instances"."groups_sync_state" = 1`) before relying on it in the fix.

Updated all pre-existing `Rails.cache.delete("wa_groups_sync_#{instance.id}")` references in the test file to use `instance_name` (matching the new cache key), and added a new test proving the cross-sibling guard: a `#sync` POST from client B is blocked when client A's sibling row (same `instance_name`, different id) is already `groups_sync_state: :syncing`, even with the 15s cache already expired.

**Test run:** `bin/rails test test/controllers/admin/whatsapp_groups_controller_test.rb` → 13 runs, 73 assertions, 0 failures, 0 errors.

### WR-03: "Parear novamente" modal doesn't warn about shared-connection blast radius

**File:** `app/views/admin/whatsapp_instances/_panel.html.erb:130-146`
**Files modified:** `app/views/admin/whatsapp_instances/_panel.html.erb`, `test/controllers/admin/clients_controller_test.rb`
**Commit:** `1264612`
**Applied fix:** Conditioned the reconnect confirmation modal's `body:` on `whatsapp_instance.shared?`, mirroring the existing "Reutilizar conexão existente" modal's approach (`_panel.html.erb:65`) and the passive "Conexão compartilhada com N cliente(s)" note already shown elsewhere on the page (`_panel.html.erb:86`). When shared, the modal now names the affected sibling count and states explicitly that disparos become unavailable for all of them, not just the client being viewed. The non-shared branch keeps the original copy verbatim.

Verification note: `erb -x` and Ruby's stdlib `ERB` both fail to compile this file (pre-existing issue confirmed via `git show HEAD:...panel.html.erb | erb -x -T - | ruby -c`, which produces the identical syntax error on the unmodified file — these tools don't understand the `form_with ... do |f| %>` block form already present in the file, unrelated to this fix). Per verification_strategy Tier 2 fallback rules, this was treated as "tool doesn't support the file type" and Tier 1 (re-read) plus a stronger ad-hoc check were used instead: rendered the partial with `ApplicationController.render` for both `shared? == true` (2 siblings) and `shared? == false`, using Rails' real `ActionView::Template::Handlers::ERB` compiler (not a naive tool), confirming no runtime error and exact expected text in both branches.

Added two new controller tests asserting the rendered `#reconnect-modal-desc` text: one with a real sibling client sharing the same `instance_name` (asserts "compartilhada com 1 outro" and "TODOS eles" appear), one without a sibling (asserts the original unmodified copy renders and no "compartilhada" text leaks in).

**Test run:** `bin/rails test test/controllers/admin/clients_controller_test.rb -n "/Parear novamente/"` → 2 runs, 12 assertions, 0 failures, 0 errors. (Two pre-existing, unrelated `assigns has been extracted to a gem` errors exist elsewhere in this same test file — confirmed via `git stash` that they fail identically on the pre-fix code, so they are not a regression from this fix.)

## Skipped Issues

None — all 3 in-scope findings (Warning tier) were fixed. The Critical section of 31-REVIEW.md was empty, and the 3 Info findings (migration reversibility comment, `params.require` blank-string edge case, `shareable_targets` deactivated-client filter) were out of scope per `fix_scope: critical_warning` and were left untouched for a human/future pass.

---

_Fixed: 2026-08-31T19:30:27Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
