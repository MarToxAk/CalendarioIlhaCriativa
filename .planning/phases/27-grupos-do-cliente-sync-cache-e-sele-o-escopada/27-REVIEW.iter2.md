---
phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
reviewed: 2026-08-30T21:00:00Z
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
  critical: 1
  warning: 4
  info: 4
  total: 9
status: issues_found
---

# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada Code Review Report

**Reviewed:** 2026-08-30T21:00:00Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** issues_found

## Summary

The cross-client isolation model — the stated goal of this phase — is implemented correctly and is
well tested: every group finder (`#show`'s `set_group`, `#sync_status`'s count, the `_picker.html.erb`
option set) is scoped through `@client.whatsapp_instance.whatsapp_groups`, never a bare
`WhatsappGroup.find`/`.where`, and the canonical A×B cross-client test in
`test/controllers/admin/whatsapp_groups_controller_test.rb` genuinely proves a foreign group id 404s
without leaking `subject`/`remote_jid`. The `upsert_all` + `synced_at < batch_started_at` deactivation
mechanics match the documented Rails 8.1 gotchas (no `created_at`/`updated_at` in the row hash, `<`
strict, single `batch_started_at` capture, `update_all` never `delete`). The instance token never enters
job arguments (GlobalID) or logs (method/path/status/ms only).

That said, one concrete functional defect ships broken: **the index page's Pagy pagination controls are
decorative — the picker partial always renders the full unpaginated group list**, directly contradicting
a stated must-have of 27-01-PLAN.md. Four further issues degrade robustness/maintainability: a job
retry-exhaustion gap that leaves `groups_sync_state` permanently stuck at `syncing`, a timing gap between
the anti-spam cache guard and worst-case job duration that allows a genuine data race in the
deactivation pass, an `enum prefix:` collision that silently shadows Rails' own attribute-presence query
method, and fragile hand-rolled HTML attribute construction in the partial phase 28 will reuse verbatim.

## Critical Issues

### CR-01: Picker pagination is non-functional — `pagy_nav` renders but never limits what's shown

**File:** `app/views/admin/whatsapp_groups/_picker.html.erb:10-11` (also
`app/views/admin/whatsapp_groups/index.html.erb:93` and
`app/controllers/admin/whatsapp_groups_controller.rb:126-136`)

**Issue:** `Admin::WhatsappGroupsController#index` computes a genuinely paginated relation:

```ruby
@pagy, @active_groups = pagy(
  @instance.whatsapp_groups.where(active: true).order(...).order(:remote_jid),
  limit: 25
)
```

`index.html.erb` renders the list via
`render "admin/whatsapp_groups/picker", client: @client, selected_ids: [], field_name: nil, pagy: @pagy`
— it passes `@pagy` (the Pagy object, used only for `pagy_nav`) but **never passes `@active_groups`**
(the already-paginated 25-row slice). `_picker.html.erb` ignores the controller's paginated relation
entirely and independently re-resolves the **full, unpaginated** collection:

```erb
<% active_groups = client.whatsapp_instance&.whatsapp_groups&.where(active: true)
     &.order(Arel.sql("subject ASC NULLS LAST"))&.order(:remote_jid) %>
...
<% active_groups.each do |g| %>
```

There is no `.page`/`.limit`/`.offset` anywhere in the partial. The result: for any client with more
than 25 active groups, the page renders **every** active group on every "page," while `pagy_nav(pagy)`
below it still shows working-looking page-2/page-3 links. Clicking those links changes `params[:page]`,
which the controller's `@pagy`/`@active_groups` respects — but `@active_groups` is dead code (its only
other use in the view is an `.blank?` check for the empty-state-3 branch, never as render content), so
the picker's own query is completely blind to `params[:page]`. Every "page" renders identical, full
content. This directly contradicts the stated must-have in `27-01-PLAN.md`: *"A lista de grupos ativos
com 25+ itens pagina via Pagy (limit 25)... sem custo de seleção na fase 27"* — the pagination never
happens; only the (non-functional) nav UI does. `27-03-SUMMARY.md`'s own "Known Stubs" section confirms
this was never exercised with >25 groups.

**Fix:** Either have the picker accept the already-resolved/paginated collection as an optional local
(keeping the "resolve inside the partial" security invariant intact by defaulting to the full query when
the local is absent), or apply pagination consistently inside the partial itself using the same `pagy`
call the controller uses:

```erb
<%# _picker.html.erb %>
<% groups = local_assigns[:groups] || client.whatsapp_instance&.whatsapp_groups&.where(active: true)
     &.order(Arel.sql("subject ASC NULLS LAST"))&.order(:remote_jid) %>
...
<% groups.each do |g| %>
```

```erb
<%# index.html.erb %>
<%= render "admin/whatsapp_groups/picker", client: @client, groups: @active_groups,
      selected_ids: [], field_name: nil, pagy: @pagy %>
```

Either way, `pagy_nav`'s links must actually change what's rendered, or the nav should be removed until
that's true.

## Warnings

### WR-01: `Whatsapp::SyncGroupsJob` never surfaces an error after retries are exhausted

**File:** `app/jobs/whatsapp/sync_groups_job.rb:12-13`

**Issue:** `retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3` and the `Unknown`
equivalent have no block. When all 3 attempts fail, ActiveJob's default behavior on exhaustion is to
re-raise (recorded as a `solid_queue_failed_executions` row) — `mark_error` is never called. Since
`#sync` already set `groups_sync_state: :syncing` before enqueueing and nothing ever flips it back,
the instance is left permanently reporting `syncing: true` from `#sync_status`, `groups_sync_error` stays
`nil` forever, and the index page's error box (gated on `groups_sync_error.present?`) never appears —
the admin has no way to learn the sync actually died, only that the poller eventually times out client-side
with "está demorando." The instance's true state (dead job, no error recorded) is invisible server-side
until a fresh manual sync happens to succeed.

**Fix:** Add the exhaustion handler, mirroring the existing `discard_on` blocks:

```ruby
retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3 do |job, _err|
  mark_error(job, "transient")
end
retry_on Evolution::Errors::Unknown, wait: 30.seconds, attempts: 3 do |job, _err|
  mark_error(job, "transient")
end
```

### WR-02: Anti-spam guard window is shorter than worst-case job duration — enables a deactivation race

**File:** `app/controllers/admin/whatsapp_groups_controller.rb:29-30`,
`app/services/whatsapp/group_synchronizer.rb`

**Issue:** The `#sync` anti-spam guard is a flat 15s cache TTL
(`Rails.cache.write("wa_groups_sync_#{@instance.id}", true, unless_exist: true, expires_in: 15.seconds)`),
but a single sync attempt can legitimately take much longer than that: `READ_TIMEOUT_FAST = 15s` per
HTTP call, and `retry_on ... wait: 30.seconds, attempts: 3` on top of that — a degraded Evolution host
can keep one `SyncGroupsJob` alive for 90s+. Once the 15s guard expires, a second admin click enqueues a
second, fully independent `SyncGroupsJob`/`GroupSynchronizer#call` for the *same instance*, and
`queue.yml` has 3 worker threads, so both can run concurrently. `GroupSynchronizer#call` captures its own
`batch_started_at = Time.current` per invocation and unconditionally sets `active: true` for everything
it fetched. If the slower run (started earlier, but finishing later with staler data) upserts *after* the
faster run already correctly deactivated a since-removed group, the slower run's `upsert_all` will
re-stamp that group's `synced_at` back down (to its own, earlier `batch_started_at`) and flip it back to
`active: true` — silently resurrecting a group the more recent sync had just correctly marked inactive.
There is no locking around the synchronizer to prevent two concurrent runs for one instance.

**Fix:** Either raise the guard TTL to comfortably exceed the job's worst-case duration (accounting for
all 3 retry attempts), or gate re-enqueue on `@instance.groups_sync_syncing?` instead of a fixed TTL, or
wrap `GroupSynchronizer#call` in a per-instance advisory lock (e.g. `with_advisory_lock` /
`instance.with_lock`) so only one sync can run at a time for a given instance.

### WR-03: `enum ..., prefix: :groups_sync` silently shadows the `groups_sync_error` column's own query method

**File:** `app/models/whatsapp_instance.rb:17`

**Issue:** `enum :groups_sync_state, { idle: 0, syncing: 1, error: 2 }, prefix: :groups_sync` generates
an instance method named `groups_sync_error?` (the enum value `error` + the `groups_sync` prefix). The
model *also* has a pre-existing plain string column named `groups_sync_error`, for which Rails
auto-generates its own `<attribute>?` presence-query method of the exact same name. Verified empirically
(`bin/rails runner`): `instance.groups_sync_error?` resolves to `ActiveRecord::Enum::EnumMethods`'s
version — i.e. it answers **"is `groups_sync_state == error`?"**, not "is the `groups_sync_error`
attribute present?" — the opposite of what the standard Rails `<attr>?` convention (used everywhere else
in this codebase, e.g. `@instance.groups_sync_error.present?` in the view) would lead a reader to assume.
No current call site trips over this — the codebase consistently uses `.groups_sync_error.present?` — but
it is a landmine for the next developer (explicitly, phase 29's motor de envio is told to follow this
exact `retry_on`/`discard_on`/state-column pattern) who reasonably calls `.groups_sync_error?` expecting
attribute presence and silently gets the wrong answer with no error raised.

**Fix:** Rename the enum value (e.g. `{ idle: 0, syncing: 1, sync_error: 2 }`) or drop `prefix:` and use
explicit method names, to eliminate the collision. At minimum, add a comment on the `groups_sync_error`
column warning that `.groups_sync_error?` means something else than expected.

### WR-04: Hand-rolled HTML attribute construction via string interpolation + `html_safe`

**File:** `app/views/admin/whatsapp_groups/_group_row.html.erb:7-9`

**Issue:**

```erb
<%= "name=#{field_name} value=#{group.id}".html_safe if field_name %>
<%= "checked".html_safe if selected_ids.include?(group.id) %>
<%= "disabled".html_safe unless field_name %>
```

builds raw HTML attribute text by string interpolation, marks it `.html_safe` unconditionally, and emits
unquoted attribute values. In phase 27 `field_name` is always the hardcoded literal `nil`, so there is no
reachable exploit today. But `27-03-SUMMARY.md` and the phase's own key-links explicitly document this
partial as "the contract phase 28 will embed verbatim," at which point `field_name` becomes a real,
threaded string (`"divulgacao[whatsapp_group_ids][]"`). Building attributes this way bypasses Rails'
normal escaping helpers entirely — any future value that isn't a compile-time literal (e.g., a
per-form-field name derived from user-influenced config, or a refactor that quotes it differently)
reintroduces an HTML/attribute-injection surface with no test coverage positioned to catch it.

**Fix:** Use the standard Rails helpers instead of manual string building:

```erb
<%= check_box_tag field_name, group.id, selected_ids.include?(group.id),
      disabled: !field_name,
      class: "h-4 w-4 rounded border-gray-300 text-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/20" %>
```

## Info

### IN-01: Test relies on two `Time.current` calls being strictly increasing

**File:** `test/services/whatsapp/group_synchronizer_test.rb:80-91`

**Issue:** `"empty batch deactivates everything and stamps groups_synced_at without crashing"` asserts
`@instance.reload.groups_synced_at > first_synced_at` across two back-to-back `synchronizer.call`
invocations. This is safe in practice on PostgreSQL (microsecond timestamp resolution), but it is an
implicit assumption about clock resolution/monotonicity rather than an explicit `travel_to`/`freeze_time`
step, making the test slightly more brittle than necessary.

**Fix:** Consider `travel_to`/explicit time stubbing between the two calls for a deterministic assertion,
though this is low priority given PG's resolution.

### IN-02: `WhatsappGroup` has no model-level uniqueness/presence validation matching the DB constraints

**File:** `app/models/whatsapp_group.rb`

**Issue:** The migration enforces `remote_jid` `NOT NULL` and a unique index on
`[whatsapp_instance_id, remote_jid]`, but the model declares neither
`validates :remote_jid, presence: true, uniqueness: { scope: :whatsapp_instance_id }` nor any other
validation. This is intentional/harmless for the `upsert_all` sync path (which bypasses validations by
design), but any future direct `WhatsappGroup.create!`/`.new.save!` call (including the test suite's own
setup helpers) will surface a raw `ActiveRecord::RecordNotUnique`/`ActiveRecord::NotNullViolation`
instead of the friendlier `ActiveRecord::RecordInvalid`, which is harder to rescue and display in a
future admin-facing form (e.g. if phase 28+ ever lets an admin hand-edit a group row).

**Fix:** Add the matching validations for defense-in-depth, purely for any future non-`upsert_all` write
path.

### IN-03: Picker's live-mode selection counter is a hardcoded "0" with no client-side initialization

**File:** `app/views/admin/whatsapp_groups/_picker.html.erb:27-29`

**Issue:** `0 de <%= active_groups.size %> grupos selecionados` hardcodes the numerator to `0`
regardless of `selected_ids`'s actual length. Phase 27 never exercises this branch (`field_name` is
always `nil` here), so it's not a bug in what ships now — but phase 28, which is expected to pass real
`selected_ids` for an existing `Divulgacao` draft, will show an incorrect "0 de N" on initial page load
until it adds its own JS to initialize the counter from `selected_ids.size`. Flagging now, while the
contract is being defined, so phase 28 doesn't inherit this silently.

**Fix:** Either seed the counter server-side (`<%= selected_ids.size %> de <%= active_groups.size %>`) or
document in the partial's header comment that phase 28 owns initializing this value via JS on connect.

### IN-04: `raise_for_status!` can still embed the raw upstream response body in exception messages for non-5xx statuses

**File:** `app/services/evolution/client.rb:167-188` (pre-existing from phase 25, exercised by the new
`fetch_groups` call path added in this phase)

**Issue:** For 5xx statuses with a non-JSON body, `raise_for_status!` deliberately uses a static message
("`#{resp.status} upstream 5xx (non-JSON body)`"). No equivalent guard exists for 400/401/403/404/422
with a non-`Hash` body (e.g. a Cloudflare interstitial responding with 403/404 HTML instead of the
Evolution JSON envelope): `raw = body.is_a?(Hash) ? body.dig(...) : body` falls through to the raw body
itself, so a non-JSON body on those statuses is interpolated verbatim into the
`Evolution::Errors::Permanent` message. That message never reaches `groups_sync_error` (which only ever
stores the short code `"transient"`/`"not_connected"` via `mark_error`), but it would be captured in
`solid_queue_failed_executions`' stored exception if `mark_error`'s `discard_on` path ever changes to log
the raw error. This is a pre-existing gap in code phase 27 modified only to add `query:` support, not a
new defect — noted for completeness since `fetch_groups` is a new caller through this exact path and the
`getParticipants` contract makes a malformed-query 400 realistic.

**Fix:** Apply the same static-message treatment used for the 5xx/non-Hash case to the 4xx/non-Hash case,
for consistency with the project's stated invariant ("nenhuma Faraday::Error nem status HTTP cru escapa
... o log de request carrega ... nunca corpo").

---

_Reviewed: 2026-08-30T21:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
