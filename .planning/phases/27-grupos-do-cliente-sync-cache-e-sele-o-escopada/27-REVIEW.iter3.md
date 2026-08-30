---
phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
reviewed: 2026-08-30T22:15:00Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - db/migrate/20260830184858_create_whatsapp_groups.rb
  - db/migrate/20260830184901_add_groups_sync_columns_to_whatsapp_instances.rb
  - app/models/whatsapp_group.rb
  - app/services/whatsapp/group_synchronizer.rb
  - app/controllers/admin/whatsapp_groups_controller.rb
  - app/views/admin/whatsapp_groups/index.html.erb
  - app/views/admin/whatsapp_groups/_group_row.html.erb
  - app/views/admin/whatsapp_groups/_picker.html.erb
  - app/views/admin/whatsapp_groups/show.html.erb
  - app/views/admin/whatsapp_instances/_panel.html.erb
  - app/models/whatsapp_instance.rb
  - app/models/client.rb
  - app/services/evolution/client.rb
  - app/jobs/whatsapp/sync_groups_job.rb
  - app/javascript/controllers/group_sync_controller.js
  - app/helpers/admin/whatsapp_groups_helper.rb
  - config/routes.rb
  - config/initializers/rack_attack.rb
  - db/schema.rb
  - test/models/whatsapp_group_test.rb
  - test/services/whatsapp/group_synchronizer_test.rb
  - test/services/evolution/client_test.rb
  - test/jobs/whatsapp/sync_groups_job_test.rb
  - test/controllers/admin/whatsapp_groups_controller_test.rb
findings:
  critical: 0
  warning: 3
  info: 5
  total: 8
status: issues_found
---

# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada Code Review Report (Re-review after fix pass)

**Reviewed:** 2026-08-30T22:15:00Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

This is a re-review of the 5 fixes committed on top of the original 27-REVIEW.md (1 Critical + 4
Warning). All 5 fixes were read in context, cross-referenced against call sites, and — where the
claim was behavioral rather than purely textual — empirically verified against the real test
database (`POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test`), including two
throwaway probe tests written specifically for this review (not committed) to exercise the
`retry_on` exhaustion path and an unhandled-exception path that the committed test suite doesn't
cover.

**Verification results for the 5 fixes:**

- **CR-01** (picker renders paginated `@active_groups`): **Confirmed fixed.** `index.html.erb` now
  passes `groups: @active_groups` (the `pagy`-sliced 25-row relation) into `_picker.html.erb`, which
  uses `local_assigns[:groups]` when present and only falls back to the full unpaginated query when
  it's absent (preserving the "resolve inside the partial" invariant for future phase-28 callers that
  don't pass it). Correct.
- **WR-01** (`SyncGroupsJob` calls `mark_error` on retry exhaustion): **Confirmed fixed, empirically.**
  I reproduced the exhaustion path directly (`job.exception_executions = { "[Evolution::Errors::Transient]" => 3 }`
  then `perform_now`, bypassing the need to sleep through 3×30s waits) and confirmed
  `groups_sync_state` transitions to `sync_error` with `groups_sync_error == "transient"` exactly as
  claimed. Correct. (Note: this exact scenario is *not* covered by any committed test — see WR-B
  below.)
- **WR-02** (gate re-enqueue on `groups_sync_syncing?`): **Fixed for its stated race** (a second click
  after the 15s cache TTL expires but before a slow job finishes is now blocked), **but the fix
  introduces a new, verified regression** — see **WR-A** below. The fix report's claim that
  "`groups_sync_state` is correctly cleared by every job exit path... so the gate never gets
  permanently stuck" is not true for any exception type outside the explicit `retry_on`/`discard_on`
  list, which I reproduced empirically.
- **WR-03** (enum value rename `error` → `sync_error`): **Confirmed fixed.** Grepped the full `app/`
  and `test/` trees for `groups_sync_error?`, stray `:error` state assignments, and the string
  `"error"` used as a `groups_sync_state` value — all call sites (`whatsapp_instance.rb`,
  `sync_groups_job.rb`, `group_synchronizer.rb`, both affected test files) consistently use
  `:sync_error`/`"sync_error"`. No collision, no missed call site.
- **WR-04** (`check_box_tag` instead of hand-rolled HTML): **Confirmed fixed for the injection
  concern** — Rails' own escaping is now used instead of unconditional `.html_safe` on interpolated,
  unquoted values. **Introduces a minor new HTML-output regression** — see **IN-E** below.

Beyond the 5 targeted fixes, this re-review did not find any new Critical issues. It found one new
Warning-tier regression directly caused by WR-02, one Warning-tier test-coverage gap for the two most
behaviorally significant fixes (CR-01, WR-02), and confirmed the 4 original Info findings (IN-01
through IN-04) are still present and unchanged, as expected since they were explicitly left out of
this fix pass's scope.

## Critical Issues

None found in this re-review.

## Warnings

### WR-A: WR-02's `groups_sync_syncing?` gate turns any unhandled exception into a permanent, self-locking deadlock (verified empirically)

**File:** `app/controllers/admin/whatsapp_groups_controller.rb:35-37`, `app/jobs/whatsapp/sync_groups_job.rb:15-26`, `app/services/evolution/client.rb:138-161`

**Issue:** `SyncGroupsJob` only recovers `groups_sync_state` back out of `:syncing` for the exception
classes it explicitly lists: `Evolution::Errors::Transient`, `Evolution::Errors::Unknown` (via the new
WR-01 exhaustion blocks), and `discard_on`'s `Permanent`/`NotConnected`/`ConfigurationError`/
`ActiveJob::DeserializationError`. Any other exception raised inside `Whatsapp::GroupSynchronizer#call`
propagates uncaught out of `#perform`, the job fails, and `groups_sync_state` is left at `:syncing`
with no handler ever running.

`Evolution::Client.request` (used by `fetch_groups`) only rescues `Faraday::ConnectionFailed` and
`Faraday::TimeoutError` — it does **not** rescue other `Faraday::Error` subclasses. In particular,
Faraday's `:json` response middleware raises `Faraday::ParsingError` when a response's `Content-Type`
matches `/\bjson$/` but the body fails `JSON.parse` (e.g., a truncated/malformed body from a flaky
backend — this codebase's own comments repeatedly describe the Evolution host as unreliable:
`evolution-contract.md`, Pitfall 6, WR-07/SC3 guards for non-JSON 2xx bodies). `Faraday::ParsingError`
is not one of the rescued/retried/discarded classes, so it propagates uncaught.

I reproduced this directly against the real job class (not a paraphrase — `Whatsapp::SyncGroupsJob.perform_now`
called with a synchronizer stub raising `Faraday::ParsingError`):

```
JOB RAISED UNCAUGHT: Faraday::ParsingError: unexpected token
AFTER JOB: groups_sync_state="syncing" groups_sync_error=nil
groups_sync_syncing? = true   # <- this is exactly what #sync's WR-02 gate checks
```

**Before WR-02**, this same failure mode already left `groups_sync_state` stuck at `syncing` forever,
but the admin could still click "Sincronizar grupos" again once the 15s cache TTL expired — a fresh
job would run, and on success `GroupSynchronizer#call` sets `groups_sync_state: :idle`, self-healing
the stale state. **After WR-02**, the `@instance.groups_sync_syncing?` check runs *before* the cache-TTL
guard and unconditionally redirects with "Sincronização já em andamento." — permanently blocking every
future `#sync` request for that instance, forever, with no UI affordance to recognize the problem (the
error box is gated on `groups_sync_error.present?`, which stays `nil` in this path) and no recovery
path short of a Rails console `update!(groups_sync_state: :idle)`. WR-02 traded a rare race condition
for a rare-but-worse permanent lockout.

**Fix:** Wrap the exhaustion/discard surface more defensively, e.g. add a catch-all `discard_on(StandardError)`
(placed last, per ActiveJob's "handlers searched bottom to top" resolution order, so it only catches
what nothing more specific already handled) that calls `mark_error(job, "transient")`, or rescue
`Faraday::Error` broadly inside `Evolution::Client.request` and re-raise as `Evolution::Errors::Unknown`
so all HTTP-layer failures funnel through the already-covered taxonomy:

```ruby
rescue Faraday::ConnectionFailed => e
  raise Evolution::Errors::Transient, e.message
rescue Faraday::TimeoutError => e
  raise classify_timeout(e), e.message
rescue Faraday::Error => e
  raise Evolution::Errors::Unknown, e.message
```

Either approach guarantees `groups_sync_state` always leaves `:syncing` on any failure, restoring the
self-healing property WR-02 silently removed.

### WR-B: No committed regression test exercises the two most behaviorally significant fixes (CR-01 pagination, WR-02 sync-in-progress gate)

**File:** `test/controllers/admin/whatsapp_groups_controller_test.rb`

**Issue:** The fix report states the CR-01 pagination behavior and the WR-04 `check_box_tag` refactor
were verified via "an ad hoc integration-test-style manual check (written, run, then deleted — not
committed) with a 30-active-group fixture." That means there is currently **no automated test in the
suite that would catch a regression** of either fix — e.g. someone reverting `index.html.erb`'s
`groups: @active_groups` local back to omitting it, or the picker's `local_assigns[:groups] ||`
fallback being dropped, would silently un-fix CR-01 again with zero test failures.

Similarly, WR-02's actual behavioral change — a second `#sync` POST while `groups_sync_state ==
"syncing"` must redirect with "Sincronização já em andamento." *and not enqueue a second job* — has no
test. I confirmed this by grepping the full test file for `syncing`/`já em andamento`/
`groups_sync_syncing`: the only hits are the existing "connected instance enqueues" test (checks the
state is set *after* a successful first `#sync`, not the gate's behavior on a *second* call) and the
`#sync_status` JSON tests (which assert the reported value, not the gate).

Separately: WR-01's exhaustion path (this review's own empirical reproduction above) also has no test —
`test/jobs/whatsapp/sync_groups_job_test.rb`'s `retry_on Transient`/`retry_on Unknown` tests only assert
that a *single* attempt re-enqueues (`assert_nil @instance.reload.groups_sync_error`), never that the
3rd/final attempt actually calls `mark_error`. `job.exception_executions` can be set directly in a test
(as demonstrated in this review) without needing to sleep through the real `wait: 30.seconds` delays.

**Fix:** Commit at minimum:
1. A controller test: `#sync` called while `@instance.groups_sync_state == "syncing"` redirects with
   the "já em andamento" notice and does not enqueue `Whatsapp::SyncGroupsJob` (`assert_no_enqueued_jobs`).
2. A view/request test asserting `index` renders exactly 25 (not 26+) checkbox rows for an instance
   with 30+ active groups, and that page 2 renders the remaining rows.
3. A job test that sets `exception_executions` directly to simulate the final attempt and asserts
   `mark_error` runs (`groups_sync_state == "sync_error"`).

### WR-03-DUP (pre-existing, not newly introduced): `discard_on(Evolution::Errors::Permanent)` and `discard_on(Evolution::Errors::ConfigurationError)` both record the misleading code `"transient"`

**File:** `app/jobs/whatsapp/sync_groups_job.rb:23,25`

**Issue:** Not introduced by this fix pass (confirmed via `git show 6c9cca7` — this line was already
`mark_error(job, "transient")` before WR-01 touched the file), but worth flagging since WR-01's own
commit message and this review's mandate is specifically about `mark_error` correctness: a `Permanent`
(e.g. a 400/404/422 from Evolution) or `ConfigurationError` failure is recorded in
`groups_sync_error` as `"transient"` — the exact same code used for genuinely transient/retriable
failures (`Transient`, `Unknown`). `wa_groups_sync_error_message` only special-cases `"not_connected"`
and falls through to the same generic "não foi possível falar com o WhatsApp agora. Tente
sincronizar novamente em instantes." copy for both, so the admin-facing UI text isn't wrong per se
(retrying is a reasonable universal instruction), but anyone debugging via `groups_sync_error` in the
DB or Rails console (explicitly the pattern phase 29's motor de envio is told to replicate) will read
`"transient"` for a `Permanent`/`ConfigurationError` failure, which is actively misleading for
diagnosing a systemic misconfiguration (e.g., a bad `getParticipants` query param, or an invalid
instance-level token that Evolution rejects with 401/403) versus real network flakiness.

**Fix:** Use distinct codes, e.g. `mark_error(job, "permanent")` / `mark_error(job, "config_error")`,
and either extend `wa_groups_sync_error_message`'s `case` with matching branches or leave them falling
through to the generic message intentionally (documented as such).

## Info

### IN-A (new): WR-04's `check_box_tag` refactor emits `id=""` on every row when `field_name` is `nil`

**File:** `app/views/admin/whatsapp_groups/_group_row.html.erb:5-7`

**Issue:** `check_box_tag(field_name, group.id, ..., disabled: !field_name, ...)` internally computes
`id: sanitize_to_id(name)`; when `name` is `nil` (phase 27's read-only index/show pages, where
`field_name` is always the hardcoded literal `nil`), `sanitize_to_id(nil)` evaluates `nil.to_s` → `""`,
so every rendered checkbox gets a literal `id=""` attribute — verified empirically
(`check_box_tag(nil, 5, false, disabled: true, class: "...")` →
`<input type="checkbox" id="" value="5" disabled="disabled" class="..." />`). Every row on the index
page therefore ships a duplicate, empty `id` attribute, which is invalid HTML (ids must be unique and
non-empty when present). This is harmless in practice — nothing in this codebase selects these
checkboxes by `id`, and browsers tolerate it — but it's a strictly-worse HTML output than the pre-fix
hand-rolled version, which emitted no `name`/`value`/`id` attributes at all when `field_name` was
falsy (the old code guarded `name=`/`value=` together behind `if field_name`, and never emitted `id`).

**Fix:** Pass an explicit `id: nil` to suppress the attribute entirely when there's no `field_name`, or
accept it as a cosmetic non-issue and note it in the partial's header comment for phase 28's context
(where `field_name` will be a real string, and `sanitize_to_id` will produce a legitimate id).

### IN-01 (unchanged from original review): Test relies on two `Time.current` calls being strictly increasing

**File:** `test/services/whatsapp/group_synchronizer_test.rb:80-91`

Still present, unchanged by this fix pass (correctly out of scope — `fix_scope: critical_warning`).
See original 27-REVIEW.md for full detail; low priority.

### IN-02 (unchanged from original review): `WhatsappGroup` has no model-level uniqueness/presence validation matching the DB constraints

**File:** `app/models/whatsapp_group.rb`

Still present, unchanged. See original 27-REVIEW.md for full detail.

### IN-03 (unchanged from original review): Picker's live-mode selection counter is a hardcoded "0" with no client-side initialization

**File:** `app/views/admin/whatsapp_groups/_picker.html.erb:27-29`

Still present, unchanged. Worth a one-line addendum now that CR-01 is fixed: when a future caller
passes a paginated `groups:` local (as `index.html.erb` now does), `active_groups.size` in this counter
line reflects only the *current page's* size, not the full active-group total — not exercised today
(`field_name` is `nil` on the index page, so this whole block is skipped), but phase 28 should be aware
the counter's denominator will need its own total-count local if it ever combines pagination with the
live counter. See original 27-REVIEW.md IN-03 for full detail.

### IN-04 (unchanged from original review): `raise_for_status!` can still embed the raw upstream response body in exception messages for non-5xx statuses

**File:** `app/services/evolution/client.rb:167-188`

Still present, unchanged. See original 27-REVIEW.md for full detail.

---

_Reviewed: 2026-08-30T22:15:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
