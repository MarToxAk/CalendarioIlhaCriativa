---
phase: 31
status: clean
reviewed_at: 2026-08-31
depth: standard
files_reviewed: 21
---

# Code Review: Phase 31 — Instância WhatsApp Compartilhada entre Clientes

## Summary

Re-review after the fix pass (commits `c6b93f4`, `07a76b4`, `45a8d13`, `1264612`) addressing the three Warning findings from the first pass. All three are genuinely resolved, in the codebase, not just in comments: `Webhooks::EvolutionController#create` now wraps each sibling's `apply_event` in `apply_event_safely`, which rescues `StandardError`, logs the row id + exception, and lets `find_each` continue to the remaining siblings — verified with a new regression test that stubs `WhatsappInstance#save!` to fail for one specific sibling row (patched at the instance-method level, since `find_each` loads fresh AR objects, not the local `irma_falha` reference — the first attempt at this test, before `07a76b4`, stubbed the wrong object and would have passed even without the fix) and asserts the later sibling still gets `connected` while the failing one stays `awaiting_qr`, and the request still returns `200`. `Admin::WhatsappGroupsController#sync`'s guard now checks `@instance.siblings.groups_sync_syncing.exists?` (DB-state gate, sees every sibling row) and its 15s throttle cache key is now `"wa_groups_sync_#{@instance.instance_name}"` (shared across siblings) instead of per-row `id` — both changes close the cross-sibling race identified against `Whatsapp::GroupSynchronizer`'s `batch_started_at`-keyed deactivation pass; a new test creates a sibling client already `groups_sync_syncing` with the cache key already expired and confirms the DB-state gate alone still blocks the second sibling's sync. The "Parear novamente" modal body is now conditioned on `whatsapp_instance.shared?`, warning of the exact sibling count and that disparos become unavailable "para TODOS eles, não só para este cliente" when true, falling back to the original single-client copy otherwise — covered by two new tests (shared and non-shared) asserting on `#reconnect-modal-desc` content.

No new issues were introduced by the fix commits. The webhook rescue is scoped tightly to the per-sibling `apply_event` call (signature validation and the overall `head` response are untouched), so it cannot mask a systemic problem beyond generating one log line per affected row. The shared cache key relies on the same atomic `Rails.cache.write(..., unless_exist: true)` semantics the original single-row guard already depended on (backed by `solid_cache_store` in production), so unifying the key across siblings closes the race rather than introducing a new one — confirmed by tracing the interleaving: whichever concurrent request's cache write loses is turned away with "Sincronização já em andamento." regardless of the state of the `exists?` check at the moment it ran. The modal's interpolated value is an integer count (`siblings.where.not(id:).count`), not user input, so the pre-existing `raw(body)` rendering in `_confirm_modal.html.erb` gains no new injection surface. The diff between the pre-fix and post-fix commits touches exactly the three files named in the findings (plus their tests) — no unrelated file was modified. Independently running the full relevant suite (`webhooks/evolution_controller_test.rb`, `admin/whatsapp_groups_controller_test.rb`, `admin/clients_controller_test.rb`, `admin/whatsapp_instances_controller_test.rb`, `models/whatsapp_instance_test.rb`, `jobs/whatsapp/send_to_group_job_test.rb`, `services/whatsapp/group_synchronizer_test.rb`, `services/evolution/instance_provisioner_test.rb`, `integration/cross_client_isolation_test.rb`) reproduced the fixer's claim exactly: 0 failures, 0 errors except the same 2 pre-existing `assigns has been extracted to a gem` errors in `admin/clients_controller_test.rb` (an `assigns()` call unrelated to phase 31, present before this phase touched the file). A full re-scan of all 21 originally-reviewed files plus the two files added by the fix pass (`app/controllers/admin/whatsapp_groups_controller.rb`, `app/views/admin/whatsapp_instances/_panel.html.erb`) turned up nothing new; the three Info-level items from the first review (irreversible migration index option, `params.require` on a blank string, `shareable_targets` not filtering deactivated clients) remain unaddressed but were not required for this fix pass and are not upgraded to Warning — they're minor robustness/reversibility notes, not correctness or security defects.

## Findings

### Critical
None.

### Warning
None. (All three from the previous review — webhook fan-out exception isolation, group-sync concurrency guard keyed by instance_name, reconnect modal blast-radius warning — are resolved; see Summary for verification detail.)

### Info

**db/migrate/20260831185638_deuniqueify_whatsapp_instance_name.rb:2-5** — `remove_index` followed by a bare `add_index` inside `change` is forward-safe but not cleanly reversible: `db:rollback` re-adds a *non-unique* index rather than the original `unique: true` one, since that option isn't recorded in this migration. Low risk (the phase's whole point is to permanently relax the constraint) but worth a one-line comment or explicit `down` if true reversibility is ever wanted. (Unchanged from first review; not addressed by the fix pass, not required to be.)

**app/controllers/admin/whatsapp_instances_controller.rb:99** — `params.require(:source_instance_name)` raises `ActionController::ParameterMissing` (Rails 400 page) for a blank string rather than the same friendly "Conexão indisponível…" alert used for every other invalid-target case in this action. Not reachable through the normal UI (`include_blank` + Stimulus-disabled submit), only via a direct POST. Minor robustness gap. (Unchanged from first review.)

**app/models/whatsapp_instance.rb:48-53** — `shareable_targets` does not filter out connections owned by deactivated (`active: false`) clients; a `connected` instance belonging to a deactivated client is still offered as a reuse target. Likely intentional (the physical connection is still real regardless of the owning client's portal status) but worth a quick confirmation. (Unchanged from first review.)
