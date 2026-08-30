---
phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
fixed_at: 2026-08-30T21:45:00Z
review_path: .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/27-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada Fix Report

**Fixed at:** 2026-08-30T21:45:00Z
**Source review:** .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/27-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope (Critical + Warning): 5
- Fixed: 5
- Skipped: 0

Info-level findings (IN-01 through IN-04) were out of scope for this run
(`fix_scope: critical_warning`) and were left untouched.

## Fixed Issues

### CR-01: Picker pagination is non-functional — `pagy_nav` renders but never limits what's shown

**Files modified:** `app/views/admin/whatsapp_groups/_picker.html.erb`, `app/views/admin/whatsapp_groups/index.html.erb`
**Commit:** 916de98
**Applied fix:** `_picker.html.erb` now accepts an optional `groups` local
(`local_assigns[:groups]`) and falls back to the original full-collection
query only when it's absent, preserving the "resolve inside the partial"
security invariant for any future caller that doesn't pass it.
`index.html.erb` now passes `groups: @active_groups` (the controller's
already-`pagy`-paginated 25-row slice) into the render call, so
`pagy_nav`'s page-2/page-3 links now actually change what's rendered.
Verified manually with a 30-group fixture: page 1 renders exactly 25
checkboxes, page 2 renders the remaining 5.

### WR-01: `Whatsapp::SyncGroupsJob` never surfaces an error after retries are exhausted

**Files modified:** `app/jobs/whatsapp/sync_groups_job.rb`
**Commit:** 6c9cca7
**Applied fix:** Added exhaustion blocks to both `retry_on Evolution::Errors::Transient` and
`retry_on Evolution::Errors::Unknown` (mirroring the existing `discard_on` pattern), calling
`mark_error(job, "transient")` when all 3 attempts are exhausted. This flips
`groups_sync_state` to `:sync_error` (see WR-03) instead of leaving it stuck at `:syncing`
forever, and surfaces the error in the UI via `groups_sync_error`.

### WR-02: Anti-spam guard window is shorter than worst-case job duration — enables a deactivation race

**Files modified:** `app/controllers/admin/whatsapp_groups_controller.rb`
**Commit:** d4124cf
**Applied fix:** `#sync` now checks `@instance.groups_sync_syncing?` before the cache-TTL guard and
bails out with the existing "Sincronização já em andamento" notice if a sync is genuinely still in
progress. This state-based check closes the race regardless of how long the job actually runs
(unlike the fixed 15s cache TTL, which can expire mid-job), while the original cache write is kept
as a fast-path guard for the sub-15s double-click case. `groups_sync_state` is correctly cleared by
every job exit path (success -> `:idle` in `GroupSynchronizer#call`, `discard_on` -> `:sync_error`,
and now the WR-01 retry-exhaustion handler -> `:sync_error`), so the gate never gets permanently
stuck.

### WR-03: `enum ..., prefix: :groups_sync` silently shadows the `groups_sync_error` column's own query method

**Files modified:** `app/models/whatsapp_instance.rb`, `app/jobs/whatsapp/sync_groups_job.rb`,
`app/services/whatsapp/group_synchronizer.rb`, `test/jobs/whatsapp/sync_groups_job_test.rb`,
`test/services/whatsapp/group_synchronizer_test.rb`
**Commit:** 819b51f
**Applied fix:** Renamed the enum value `error: 2` to `sync_error: 2` on
`groups_sync_state`, eliminating the `groups_sync_error?` method-name collision with the
plain-string `groups_sync_error` column's own Rails-generated presence method. Since the column is
a plain integer (not a Postgres native enum type), this is a Ruby-side-only rename — no data
migration needed. Updated all 2 non-test call sites that referenced the old `:error` symbol/string
and the 4 test assertions that checked for the string `"error"`, to `"sync_error"`. Grepped the full
`app/` and `test/` trees afterward to confirm no other reference to the old value survived.

### WR-04: Hand-rolled HTML attribute construction via string interpolation + `html_safe`

**Files modified:** `app/views/admin/whatsapp_groups/_group_row.html.erb`
**Commit:** 37e7023
**Applied fix:** Replaced the manual `"name=#{field_name} value=#{group.id}".html_safe` /
`"checked".html_safe` / `"disabled".html_safe` string-building with a single
`check_box_tag field_name, group.id, selected_ids.include?(group.id), disabled: !field_name, class: "..."`
call, using Rails' standard escaping instead of unconditional `.html_safe` on unquoted
interpolated values — closing the injection-risk-on-reuse noted for phase 28 (where `field_name`
becomes a real threaded string). Verified end-to-end together with CR-01's fix via a manual
30-group fixture render (checkboxes render/paginate correctly); the ad hoc test file used for
that check was removed afterward, it is not part of this commit.

## Skipped Issues

None — all in-scope findings were fixed.

## Verification

All fixes were verified inside an isolated git worktree
(`.claude/worktrees/rf-27-3243503-1788118575`, branch `gsd-reviewfix/27-3243503`, based on `main`),
using `bundle` pointed at the main checkout's `vendor/bundle` and a copy of `config/master.key`.
The worktree was fast-forward-merged into `main` and removed after all 5 commits landed — the
numbers below are reproducible from the current `main` checkout.

- Tier 1 (re-read modified sections): passed for all 5 fixes.
- Tier 2 (syntax check): `ruby -c` for all modified `.rb` files, and an `ERB.new(...).src` +
  `RubyVM::InstructionSequence.compile` check for all modified `.erb` files. All passed.
- Additional: ran the full existing test suite for the phase's affected files after each commit
  (`test/models/whatsapp_group_test.rb`, `test/services/whatsapp/group_synchronizer_test.rb`,
  `test/services/evolution/client_test.rb`, `test/jobs/whatsapp/sync_groups_job_test.rb`,
  `test/controllers/admin/whatsapp_groups_controller_test.rb`) — 57 runs, 176 assertions, 0
  failures throughout. Also ran an ad hoc integration-test-style manual check (written, run, then
  deleted — not committed) with a 30-active-group fixture that confirmed CR-01's pagination and
  WR-04's `check_box_tag` refactor work correctly together (25 checkboxes on page 1, 5 on page 2).
- No fix in this batch involves a logic/algorithm judgment call flagged by the reviewer as needing
  human sign-off beyond normal code review; none are marked "requires human verification."

---

_Fixed: 2026-08-30T21:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
