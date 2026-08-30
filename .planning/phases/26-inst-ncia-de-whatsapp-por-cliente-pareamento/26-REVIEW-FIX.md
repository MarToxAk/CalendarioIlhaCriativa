---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
fixed_at: 2026-08-30T00:00:00Z
review_path: .planning/phases/26-inst-ncia-de-whatsapp-por-cliente-pareamento/26-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 26: Code Review Fix Report

**Fixed at:** 2026-08-30
**Source review:** .planning/phases/26-inst-ncia-de-whatsapp-por-cliente-pareamento/26-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (WR-01..WR-06; 0 Critical, 8 Info out of scope)
- Fixed: 6
- Skipped: 0

## Verification

- **Where gates ran:** the **main checkout** (`/home/bot/calendario_livia`, branch `main`), not an isolated worktree. The project vendors gems in the gitignored `vendor/bundle` (`.bundle/config` sets `BUNDLE_PATH`) and needs the gitignored `config/master.key` and `.env` to boot Rails, so a fresh `git worktree` cannot run `bin/rails test`. `workflow.use_worktrees` is unset in `.planning/config.json`. Per the fixer's own #2825 rationale ("the hand-rolled worktree also cannot run the project's gates safely ... so the opt-out is also the safe path"), and because the orchestrator explicitly requires running the phase-26 suite after every fix, all edits and commits were made directly on `main`.
- **Per-fix:** Tier 1 (re-read) + Tier 2 syntax checks — `ruby -c` for `.rb`, `node -c` for the Stimulus controller, `bin/rails runner` route load for `config/routes.rb`. Targeted `bin/rails test` on the affected phase-26 files after each fix.
- **Final full phase-26 run:** `test/services/evolution/client_test.rb test/models/whatsapp_instance_test.rb test/controllers/admin/whatsapp_instances_controller_test.rb test/controllers/webhooks/evolution_controller_test.rb test/integration/rack_attack_test.rb` → **70 runs, 362 assertions, 1 failure, 0 errors**. The single failure is `test/integration/rack_attack_test.rb:52` (AI-namespace throttle), a KNOWN pre-existing failure flagged as out of scope by the orchestrator and unrelated to phase 26. Baseline before fixes: 65 runs / same 1 failure. 5 new regression tests added, all green. No regressions.

## Fixed Issues

### WR-01: `verify` and `reconnect` raise a 500 (NoMethodError on nil) when the client has no instance

**Files modified:** `app/controllers/admin/whatsapp_instances_controller.rb`, `test/controllers/admin/whatsapp_instances_controller_test.rb`
**Commit:** e3dd140
**Applied fix:** Added an early `return redirect_to(admin_client_path(@client), alert: "Este cliente ainda não tem uma instância de WhatsApp.") if inst.nil?` at the top of `#verify` and `#reconnect`, mirroring the existing `refresh_qr` guard style. Added two regression tests (POST verify / POST reconnect with no instance → redirect + pt-BR alert, no 500).

### WR-02: `refresh_qr` is a GET that performs side effects

**Files modified:** `config/routes.rb`, `app/javascript/controllers/qr_pairing_controller.js`, `test/controllers/admin/whatsapp_instances_controller_test.rb`
**Commit:** a2be435
**Applied fix:** Route changed from `get :refresh_qr` to `post :refresh_qr`. `qr_pairing_controller.js#poll` now calls `fetch(this.urlValue, { method: "POST", headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content } })`. Confirmed `csrf_meta_tags` is present in `app/views/layouts/admin.html.erb`. The three existing `get refresh_qr_...` controller tests were updated to `post` (this is the intended contract change, not test gaming). `_qr.html.erb` needed no change — it only passes the path helper as a Stimulus value.

### WR-03: `destroy` route declared but no `destroy` action exists

**Files modified:** `config/routes.rb`
**Commit:** e2f53aa
**Applied fix:** `resource :whatsapp_instance, only: [ :create, :destroy ]` → `only: [ :create ]`. No stub action added: per SUMMARY/COVERAGE there is no local destroy in phase-26 scope (deleting on the shared Evolution manager is explicit opt-out). `Client` model keeps `has_one :whatsapp_instance, dependent: :destroy` (DB cascade on client deletion — unrelated to the HTTP route).

### WR-04: create-vs-adopt decision hinges on regex-matching Evolution's human-readable error text

**Files modified:** `app/services/evolution/instance_provisioner.rb`, `test/controllers/admin/whatsapp_instances_controller_test.rb`
**Commit:** 0716978
**Applied fix:** The bare `e.message =~ /already in use/i` is replaced by `name_collision?(error)`, which requires **both** the `403 ` status prefix (emitted by `Evolution::Client#raise_for_status!` as `"#{resp.status} #{msg}"`) **and** the phrase, now held in a named `NAME_IN_USE_MESSAGE` constant with a comment. Evolution 2.3.7 exposes **no structured error code** in the error envelope (verified in `26-RESEARCH.md` against the Evolution source); this is an **accepted, documented constraint** — no fake structured field was invented. The 403-status gate is the extra robustness the orchestrator asked for: a 401/404 whose copy happens to contain "already in use" no longer diverts to `#adopt`. Added a regression test asserting `"403 API key forbidden ..."` propagates as a hard failure (no adoption, `fetch_instances` never called).

### WR-05: `adopt` persists the row before fetching the QR, yielding contradictory operator feedback

**Files modified:** `app/services/evolution/instance_provisioner.rb`, `test/controllers/admin/whatsapp_instances_controller_test.rb`
**Commit:** 4cf6d0a
**Applied fix:** The inline `state == "open" ? nil : @api.connect(name)[:base64]` after `row.save!` is extracted to a private `adopt_qr(name, state)` that rescues `Evolution::Errors::{Transient,Unknown,Permanent,ConfigurationError}` and returns `nil` — the same deliberately-silent handling as `pull_fresh_qr`. A post-`save!` QR failure no longer escapes `#call`, so the controller shows the normal creation notice next to the live instance card; the Stimulus poller fetches the QR on its next cycle. Added a regression test: 403-collision adoption with `connection_state: "connecting"` and `connect` raising `Transient` → row created (`origin: adopted_existing`, `awaiting_qr`, `last_qr_base64` nil), creation notice shown.

### WR-06: any unrecognized Evolution connection state silently downgrades a healthy instance to `awaiting_qr`

**Files modified:** `app/models/whatsapp_instance.rb`, `app/controllers/webhooks/evolution_controller.rb`, `test/controllers/webhooks/evolution_controller_test.rb`
**Commit:** 0a035cb
**Status:** fixed — requires human verification (state-handling / logic change)
**Applied fix:** The state hash is lifted into `EVOLUTION_STATE_MAP` (single source) and a new `WhatsappInstance.known_evolution_state?(state)` predicate is added. `Webhooks::EvolutionController#apply_connection_update` now does `return unless WhatsappInstance.known_evolution_state?(state)` after the existing `state.blank?` guard — an unknown/future/malformed state from a signed caller is now a silent no-op on the webhook path instead of flipping a `connected` instance to `awaiting_qr`. `map_evolution_state` keeps its `:awaiting_qr` default and its "never raises KeyError" guarantee, so all existing model tests stay green (the reviewer's suggested `nil`-return signature change was **not** applied — it would have broken the documented `map_evolution_state` contract and its 3 test assertions, and forced changes to `#verify` and `#adopt` `update!` calls). `#verify` deliberately left mapping unknown → `awaiting_qr`: it is operator-initiated, synchronous, and immediately visible, so the shared-map downgrade risk the finding describes (asynchronous, signed caller, future release) does not apply there. Added a webhook regression test: `connection.update` with `state: "reconnecting"` on a `connected` instance stays `connected`, responds 200.

**Human verification note:** confirm that ignoring unknown `connection.update` states on the webhook (rather than, e.g., recording `last_checked_at`) is the desired behavior, and that no current Evolution 2.3.7 state string outside `{open, connecting, close, refused}` needs handling.

## Skipped Issues

None.

---

_Fixed: 2026-08-30_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
