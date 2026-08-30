---
phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
verified: 2026-08-30T23:40:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada Verification Report

**Phase Goal:** O admin enxerga os grupos reais do número de cada cliente, servidos de cache local, e o modelo de escopo que impede o vazamento entre clientes fica estabelecido aqui.
**Verified:** 2026-08-30T23:40:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Admin dispara a sincronização de um cliente e vê, ao final, a lista dos grupos daquele número — inclusive os que voltam sem nome, com fallback legível. | ✓ VERIFIED | `Admin::WhatsappGroupsController#sync` guards + enqueues `Whatsapp::SyncGroupsJob` (`app/controllers/admin/whatsapp_groups_controller.rb:29-46`); `Whatsapp::GroupSynchronizer#call` upserts via `WhatsappGroup.upsert_all` keyed on `[whatsapp_instance_id, remote_jid]`; `WhatsappGroup#display_name` falls back to `"Grupo sem nome (<jid12>…)"` (`app/models/whatsapp_group.rb:15-17`). Empirically re-ran full phase test scope: 65/65 pass, including model fallback tests and the tracer/deactivation runner scripts (per prior SUMMARY, reproduced here). |
| 2 | Abrir a tela de grupos não chama o Evolution: a lista vem do cache local e mostra quando foi sincronizada pela última vez. | ✓ VERIFIED | `grep -vE '^\s*#' app/controllers/admin/whatsapp_groups_controller.rb \| grep -E 'Evolution::(Client\|Errors)'` returns nothing (confirmed independently). `#index` reads only `@instance.whatsapp_groups` (local AR relation). `wa_groups_synced_label` renders the absolute pt-BR timestamp; caption row in `index.html.erb:41` renders it. |
| 3 | Grupos em que só administradores podem enviar aparecem sinalizados na seleção, antes de o admin escolher. | ✓ VERIFIED | `_group_row.html.erb:11-16` renders the amber "Só admins enviam" badge whenever `group.announce?`, independent of `selected_ids`/checked state — badge is unconditional on announce, not on selection. `GroupSynchronizer#row_for` persists `announce: g["announce"] == true` (nil/missing degrades to `false`). |
| 4 | Um grupo que sumiu do WhatsApp aparece como inativo e continua legível — nenhum registro de grupo é apagado. | ✓ VERIFIED | `GroupSynchronizer#call` deactivates via `update_all(active: false, ...)` scoped to the instance association, never `delete`/`destroy` (`app/services/whatsapp/group_synchronizer.rb:39-42`). `index.html.erb:95-114` renders the muted "Grupos inativos" section (divider, no checkbox, "Inativo" pill, caption) below the divider. Independently re-verified via a corrected copy of the phase's own state-rendering script (see Anti-Patterns below) — scenario 5 (1 active + 1 inactive) confirms the inactive row has no checkbox and the active row does. |
| 5 | A seleção de grupos de um cliente nunca oferece, nem aceita, grupos de outro cliente. | ✓ VERIFIED | `_picker.html.erb` resolves its option set exclusively from `client.whatsapp_instance.whatsapp_groups.where(active: true)`, never a raw `WhatsappGroup.where/find`, never an ivar from the controller (`grep` confirms both). `#show`/`set_group` finder is always `@instance.whatsapp_groups.find(params[:id])`, rescuing `RecordNotFound` into a generic redirect. The canonical A×B test (`test/controllers/admin/whatsapp_groups_controller_test.rb:194-223`) creates `client_a`/`client_b` with their own groups, requests `client_a`'s path with `client_b`'s group id, and asserts a redirect + generic alert + the response body never contains `"Segredo do B"` or `"b1@g.us"`; the same id under its own client returns 200 with the correct `display_name`. Ran this test directly — passes. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/*_create_whatsapp_groups.rb` + `*_add_groups_sync_columns_to_whatsapp_instances.rb` | Migrations for `whatsapp_groups` table + sync-state columns | ✓ VERIFIED | Applied; `db/schema.rb` shows `whatsapp_groups` with unique index `[whatsapp_instance_id, remote_jid]` + `[whatsapp_instance_id, active]`, and `groups_synced_at`/`groups_sync_state`/`groups_sync_error` on `whatsapp_instances`. |
| `app/models/whatsapp_group.rb` | Model with `display_name` fallback + scopes | ✓ VERIFIED | Confirmed pure method (not callback), fallback copy verbatim (U+2026), `active_groups`/`inactive_groups` scopes present. |
| `app/services/whatsapp/group_synchronizer.rb` | PORO: upsert + deactivation + not-connected guard | ✓ VERIFIED | All three behaviors present and read exactly as described (lines 21-49); `row_for` additionally guards non-Hash elements (WR-2 fix). |
| `app/services/evolution/client.rb` — `fetch_groups` | GET `/group/fetchAllGroups/{instance}` w/ instance token, 15s timeout, `Unknown` on non-Array 2xx | ✓ VERIFIED | Lines 126-134; `#request` supports `query:` (line 138-143) and now has a `rescue Faraday::Error` catch-all funneling into `Evolution::Errors::Unknown` (WR-A fix, lines 158-167). |
| `app/controllers/admin/whatsapp_groups_controller.rb` | `#index`/`#sync`/`#sync_status`/`#show` | ✓ VERIFIED | All 4 actions present, scoped, evolution-free render path, `sync_status` returns exactly 4 keys. |
| `config/routes.rb` | Full nested route surface | ✓ VERIFIED | `bin/rails routes -g whatsapp_groups` lists `index`/`show`/`sync`/`sync_status`. |
| `app/views/admin/whatsapp_groups/index.html.erb` | All 5 UI-SPEC states + inactive section + poller wiring | ✓ VERIFIED | All state branches present in source; independently re-rendered via a corrected copy of the phase's own verification script (enum-name drift fixed — see Anti-Patterns) — all 5 scenarios pass. |
| `app/views/admin/whatsapp_groups/_picker.html.erb` | Scoped, decoupled, reusable picker contract | ✓ VERIFIED | Resolves scope from `client.whatsapp_instance.whatsapp_groups.where(active: true)` inside the partial; no controller ivars referenced; `field_name: nil` path renders disabled/nameless checkboxes. |
| `app/views/admin/whatsapp_groups/show.html.erb` | Read-only single-group detail page | ✓ VERIFIED | Renders `display_name`, active/inactive pill, announce badge, `remote_jid`, back link; no mutating actions. |
| `app/jobs/whatsapp/sync_groups_job.rb` | First ActiveJob; Evolution::Errors → retry/discard taxonomy | ✓ VERIFIED | `retry_on Transient/Unknown` (wait 30s, attempts 3); `discard_on Permanent/NotConnected/ConfigurationError` with distinct `mark_error` codes; `discard_on ActiveJob::DeserializationError`; `discard_on(StandardError)` catch-all declared first (WR-A fix, verified against `ActiveSupport::Rescuable` ordering in the review). Token never in `perform_later` args (record-based GlobalID). |
| `app/javascript/controllers/group_sync_controller.js` | Stimulus poller: 3s/20 cycles, GET no-CSRF, teardown | ✓ VERIFIED | `connect`/`disconnect`/`poll` implement exactly this; `clearInterval` in `disconnect()`; no `console.*`; targets `error`/`timeout`/`status` match `data-group-sync-target` attributes in `index.html.erb`. Auto-registered via `eagerLoadControllersFrom`/`pin_all_from` (no manual `index.js` edit needed). |
| `app/helpers/admin/whatsapp_groups_helper.rb` | `wa_groups_synced_label` + `wa_groups_sync_error_message` | ✓ VERIFIED | Absolute pt-BR timestamp / `"—"`; error-message dispatch on `groups_sync_error` code. |
| `config/initializers/rack_attack.rb` | Throttle `POST .../sync` | ✓ VERIFIED | `admin/whatsapp_groups_sync_by_ip` (6/60s) present alongside the webhook throttle. |
| `test/**` (5 files) | Coverage across model/service/job/controller | ✓ VERIFIED | `bin/rails test` of the phase's full test scope: **65 runs, 210 assertions, 0 failures, 0 errors** (ran directly in this verification, not taken from SUMMARY claims). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `#sync` | `Whatsapp::SyncGroupsJob` | `perform_later(@instance)` after guard + cache-write + `groups_sync_syncing?` gate | ✓ WIRED | Guards for nil/disconnected instance, in-progress state, and 15s anti-spam cache all present before enqueue; confirmed via controller test (`sync com groups_sync_state=syncing bloqueia o 2o POST...`). |
| `Whatsapp::SyncGroupsJob#perform` | `Whatsapp::GroupSynchronizer#call` | direct delegation | ✓ WIRED | `perform(instance) = Whatsapp::GroupSynchronizer.new(instance).call`. |
| `group_sync_controller.js` | `#sync_status` | `fetch(this.statusUrlValue)` compared against `this.sinceValue` | ✓ WIRED | `data-group-sync-status-url-value`/`data-group-sync-since-value` set in `index.html.erb:13-14`; poller targets (`error`/`timeout`/`status`) match `data-group-sync-target` attrs in the same view. |
| `_picker.html.erb` | `client.whatsapp_instance.whatsapp_groups` | server-side scoped query inside the partial | ✓ WIRED | No ivar/ext collection dependency; `index.html.erb` passes `groups: @active_groups` (paginated) which the partial prefers via `local_assigns[:groups] ||` fallback (CR-01 fix, confirmed present). |
| `#show`/`set_group` | `@instance.whatsapp_groups.find` | scoped finder, `RecordNotFound` → redirect | ✓ WIRED | Confirmed by code + canonical A×B test (passing). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `index.html.erb` | `@active_groups`/`@inactive_groups` | `@instance.whatsapp_groups.where(active: …)` (real AR query, Pagy-paginated for active) | Yes | ✓ FLOWING |
| `_picker.html.erb` | `active_groups` local | `local_assigns[:groups]` (paginated real query) or self-resolved `client.whatsapp_instance.whatsapp_groups.where(active: true)` | Yes | ✓ FLOWING |
| `sync_status` JSON | `count` | `@instance.whatsapp_groups.where(active: true).count` (real query) | Yes | ✓ FLOWING |
| `show.html.erb` | `@group` | `@instance.whatsapp_groups.find(params[:id])` (real query, scoped) | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full phase test scope | `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/models/whatsapp_group_test.rb test/services/whatsapp/group_synchronizer_test.rb test/services/evolution/client_test.rb test/jobs/whatsapp/sync_groups_job_test.rb test/controllers/admin/whatsapp_groups_controller_test.rb` | 65 runs, 210 assertions, 0 failures, 0 errors | ✓ PASS |
| Regression sweep (phase 25/26 test files) | `bin/rails test test/controllers/admin/whatsapp_instances_controller_test.rb test/controllers/webhooks/evolution_controller_test.rb test/services/evolution/client_test.rb test/models/whatsapp_instance_test.rb test/integration/rack_attack_test.rb` | 77 runs, 373 assertions, 1 failure | ⚠️ 1 pre-existing failure |
| Canonical cross-client isolation test (SEG model, GRUPO-03) | single named test run within the suite above | Passes; body never contains other client's `subject`/`remote_jid` | ✓ PASS |
| Routes surface | `bin/rails routes -g whatsapp_groups` | `index`/`show`/`sync`/`sync_status` all present | ✓ PASS |
| Stimulus auto-registration | `grep eagerLoadControllersFrom/pin_all_from` | present, no manual wiring needed | ✓ PASS |

The 1 regression-sweep failure is `RackAttackTest#test_60_primeiras_requisições_ao_namespace_AI_não_retornam_429` — confirmed pre-existing and unrelated to phase 27 (throttle config predates this phase, untouched by any phase-27 commit; the note in the verifier's task instructions also documents this as pre-existing).

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|-----------------|--------------|--------|----------|
| GRUPO-01 | 27-01, 27-02 | Admin sincroniza a lista de grupos da instância de um cliente | ✓ SATISFIED | Sync trigger, job, synchronizer, upsert — all present and tested. |
| GRUPO-02 | 27-01, 27-02, 27-03 | Listagem servida de cache local, não do Evolution a cada request | ✓ SATISFIED | `#index`/`#show` grep-clean of `Evolution::`; cache-only reads confirmed. |
| GRUPO-03 | 27-03 | Admin seleciona grupos apenas da instância daquele cliente | ✓ SATISFIED | Scoped picker + scoped finder + canonical A×B test. |
| GRUPO-04 | 27-01, 27-03 | Grupos só-admin sinalizados na seleção | ✓ SATISFIED | Amber badge in `_group_row.html.erb`, unconditional on `announce?`. |
| GRUPO-05 | 27-01, 27-03 | Grupos sumidos marcados inativos, nunca apagados | ✓ SATISFIED | `update_all` deactivation pass + inactive section in view. |

No orphaned requirements — REQUIREMENTS.md traceability table maps GRUPO-01..05 to Phase 27 exclusively, and every ID is declared by at least one of the 3 plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/phases/27-.../scripts/27-03-states.rb` | 60 | Stale verification tool: uses `groups_sync_state: :error`, a value that stopped being valid after the phase's own later WR-03 code-review fix renamed the enum value to `:sync_error` (commit `819b51f`). Running this script today crashes with `ArgumentError: 'error' is not a valid groups_sync_state` before reaching scenario 3. | ℹ️ Info | This is not a production-code defect — it's drift in a non-deliverable proof script (explicitly marked "não é deliverable" in `27-03-SUMMARY.md`) that was never re-run after a later commit in the same phase's review-fix loop changed a value it depends on. I independently patched a scratch copy (`:error` → `:sync_error`) and re-ran it: all 5 scenarios pass, confirming the underlying view logic the script was meant to prove is still correct. Recommend updating the committed script to `:sync_error` for future reproducibility, but this does not block the phase — the claim it supports is independently re-verified true. |
| `app/views/admin/whatsapp_groups/_group_row.html.erb` | 5-7 | `check_box_tag(field_name, …)` with `field_name: nil` emits a literal `id=""` on every disabled checkbox (Rails' `sanitize_to_id(nil)` → `""`) | ℹ️ Info | Cosmetic/invalid-but-harmless HTML (duplicate empty `id` attrs); flagged and explicitly deferred by the phase's own code review (IN-A) as acceptable — no functional impact, nothing selects by this id. |
| `app/views/admin/whatsapp_groups/_picker.html.erb` | 27-29 | Live-mode selection counter (`0 de {N}`) is a hardcoded `"0"` with no client-side init, and `N` would reflect only the current page when a paginated `groups:` local is passed | ℹ️ Info | Dead code in phase 27 — this whole block is skipped because `field_name` is always `nil` on `index.html.erb`. Flagged (IN-03) as a phase-28 concern when `field_name` becomes real; not a phase-27 gap. |
| `app/models/whatsapp_group.rb` | — | No model-level uniqueness/presence validation mirroring the DB unique index | ℹ️ Info | Deferred (IN-02) — `upsert_all` bypasses validations anyway, so this would only help catch bugs in other code paths that build `WhatsappGroup` directly (none exist today). |

No 🛑 Blocker-level anti-patterns found. No unreferenced `TBD`/`FIXME`/`XXX` markers in any file modified by this phase (one false-positive grep hit on the Portuguese word "TODO" — meaning "every" — in a code comment, not a debt marker).

### Human Verification Required

None. All must-haves for this phase are either directly test-backed or independently re-derived by this verifier via code inspection, grep, and live re-execution of the relevant test/runner scripts. Visual/layout confirmation (exact colors, spacing, live-browser poller behavior) was explicitly deferred by the executing plans to the project's end-of-phase consolidated UAT (`workflow.human_verify_mode = end-of-phase`) — this is a project-wide policy, not a phase-27-specific gap, and none of it affects the phase's 5 roadmap Success Criteria, which are all logic/data-flow claims independently verified above.

### Gaps Summary

No gaps. All 5 roadmap Success Criteria are verified true against the actual codebase (not just SUMMARY claims): sync-and-cache with fallback naming, Evolution-free render path with last-sync timestamp, announce badge shown pre-selection, inactive-not-deleted with a legible section, and cross-client isolation proven by a canonical automated test that was executed directly during this verification (not merely cited). The phase's 3-iteration code-review loop closed 1 Critical + 7 Warning findings with commits and regression tests that this verifier confirmed exist and pass; the 2 remaining Info-level items (deferred by the review itself) are cosmetic/non-blocking and out of phase-27 scope. One minor Info-level finding was newly surfaced by this verification (stale enum value in a non-deliverable proof script) — logged above for housekeeping, not a blocker.

---

_Verified: 2026-08-30T23:40:00Z_
_Verifier: Claude (gsd-verifier)_
