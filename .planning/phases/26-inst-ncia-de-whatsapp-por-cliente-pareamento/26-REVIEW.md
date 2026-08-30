---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
reviewed: 2026-08-30T00:00:00Z
depth: standard
iteration: 2
re_review_of: 26-REVIEW-FIX.md (iteration 1)
files_reviewed: 7
files_reviewed_list:
  - app/models/whatsapp_instance.rb
  - app/services/evolution/instance_provisioner.rb
  - app/controllers/admin/whatsapp_instances_controller.rb
  - app/controllers/webhooks/evolution_controller.rb
  - app/javascript/controllers/qr_pairing_controller.js
  - config/routes.rb
  - config/initializers/rack_attack.rb
findings:
  critical: 0
  warning: 0
  info: 9
  total: 9
status: issues_found
verdict: verification_passed
---

# Phase 26: Code Review Report (Re-Review — Iteration 2)

**Reviewed:** 2026-08-30
**Depth:** standard
**Scope:** verify WR-01..WR-06 fixes from `26-REVIEW-FIX.md` (commits e3dd140, a2be435,
e2f53aa, 0716978, 4cf6d0a, 0a035cb) actually resolve the iteration-1 findings and introduce
no new defect.

## VERIFICATION PASSED

All six Warnings from iteration 1 are resolved. No Critical or Warning remains. The six
fix commits introduce no new correctness, security, or robustness defect. Supporting
regression tests were added for every fix and are green (fixer reports 70 runs / 362
assertions / 1 pre-existing unrelated failure in `rack_attack_test.rb:52`).

The 8 Info findings from iteration 1 are out of fix scope and carried forward unchanged.
One additional Info (IN-09) records the deliberately-narrowed scope of the WR-06 fix.

---

## Per-fix verification

### WR-01 — nil-instance guard on `verify` / `reconnect` — RESOLVED

`app/controllers/admin/whatsapp_instances_controller.rb:37-38, 78-79` now early-return
`redirect_to admin_client_path(@client), alert: "Este cliente ainda não tem uma instância
de WhatsApp."` before any `inst.instance_name` dereference. Guard style matches the
pre-existing `refresh_qr` `inst&.` pattern. `set_client` still resolves `@client` via
`Client.find`, so a missing client is a 404 as before; a present client with no instance is
now a clean redirect. Two regression tests added (`post verify` / `post reconnect` with no
instance → redirect + pt-BR alert, no 500). No new path introduced.

### WR-02 — `refresh_qr` GET → POST — RESOLVED

`config/routes.rb:14` is now `post :refresh_qr`; `qr_pairing_controller.js:33-39` issues
`fetch(this.urlValue, { method: "POST", headers: { Accept, "X-CSRF-Token": …meta… } })`.
Verified:
- `csrf_meta_tags` is present in `app/views/layouts/admin.html.erb:9`, and the QR panel
  renders through the `admin` layout (`clients/show.html.erb` → `_panel` → `_qr`), so the
  meta token is available to the Stimulus controller.
- `ApplicationController < ActionController::Base` keeps Rails' default
  `protect_from_forgery with: :exception`; Rails validates the `X-CSRF-Token` request
  header for non-GET, so the POST is now CSRF-protected. Same-origin `fetch` sends the
  session cookie (`credentials: "same-origin"` default), so `require_authentication`
  still passes.
- No `link_to` / `button_to` targets `refresh_qr` anywhere in `app/views` — `_qr.html.erb`
  only passes the path helper as a Stimulus `url` value — so removing the GET route breaks
  nothing.
- The three existing `get refresh_qr_…` controller tests were updated to `post` (contract
  change, not test-gaming). Integration tests run with `allow_forgery_protection = false`
  (`config/environments/test.rb:29`), so they exercise the verb change but not CSRF itself;
  the CSRF path is covered by Rails' own guarantees.

State-changing behaviour is now off GET. Resolved.

### WR-03 — undeclared `destroy` route — RESOLVED

`config/routes.rb:13` is now `resource :whatsapp_instance, only: [ :create ]`. The custom
`post :refresh_qr/:verify/:adopt/:reconnect` members inside the block are unaffected (they
do not depend on `only:`). `Client has_one :whatsapp_instance, dependent: :destroy` is a
DB-cascade concern, unrelated to the HTTP route, and correctly left in place. No view or
test issues a `DELETE` to the instance path. `DELETE /admin/clients/:id/whatsapp_instance`
now returns a routing 404 instead of `ActionNotFound` 500. Resolved.

### WR-04 — create-vs-adopt no longer keyed on a bare phrase match — RESOLVED

`app/services/evolution/instance_provisioner.rb:49-52`: `name_collision?(error)` now
requires **both** `msg.start_with?("403 ")` **and** `msg.match?(NAME_IN_USE_MESSAGE)`.
Verified against `Evolution::Client#raise_for_status!` (`app/services/evolution/client.rb`):
403 maps to `Evolution::Errors::Permanent` with message `"#{resp.status} #{msg}".strip`,
i.e. `"403 …"` — so the `"403 "` prefix gate is real, not assumed. A 401/404 whose copy
contains "already in use" now re-propagates instead of diverting to `#adopt`; a non-403
adoption can no longer overwrite local state. The accepted residual (Evolution could change
the 403 wording) is documented at the single chokepoint (`NAME_IN_USE_MESSAGE` constant +
comment referencing `26-RESEARCH.md`, which verified Evolution 2.3.7 exposes no structured
error code). Regression test added: `"403 API key forbidden for this resource"` →
`WhatsappInstance.count` unchanged, `fetch_instances` never called, alert shown. This is
exactly the "HTTP 403 + …" structured gate the finding asked for. Resolved.

### WR-05 — `adopt` QR fetch failure no longer escapes `#call` — RESOLVED

`app/services/evolution/instance_provisioner.rb:86-92`: the post-`save!` QR fetch is
extracted to `adopt_qr(name, state)`, which returns `nil` for `state == "open"` and
otherwise rescues `Evolution::Errors::{Transient,Unknown,Permanent,ConfigurationError}` →
`nil`. Cross-checked the rescue list against `Evolution::Client.connect`: it raises only
`Unknown` / `Transient` directly, plus `Permanent` / `ConfigurationError` via
`raise_for_status!` / config — all four are covered, so no connect-path exception can now
propagate out of `#call` after the row is persisted. Behaviour matches the deliberately
silent `pull_fresh_qr`; the Stimulus poller recovers the QR on its next cycle. Regression
test added: 403-collision adoption with `connection_state: "connecting"` and `connect`
raising `Transient` → row created (`origin: adopted_existing`, `awaiting_qr`,
`last_qr_base64` nil), normal creation notice shown. Resolved.

### WR-06 — unknown Evolution state no longer downgrades a healthy instance on the webhook — RESOLVED (scope narrowed, see IN-09)

`app/models/whatsapp_instance.rb:31-48`: the state hash is lifted to the frozen
`EVOLUTION_STATE_MAP` single source; `known_evolution_state?(state)` →
`EVOLUTION_STATE_MAP.key?(state.to_s)` added. `Webhooks::EvolutionController#apply_connection_update`
(`app/controllers/webhooks/evolution_controller.rb:57-60`) now does
`return unless WhatsappInstance.known_evolution_state?(state)` after the existing
`state.blank?` guard — an unknown / future / malformed state from a signed caller is a
**silent no-op** on the webhook path, so a `connected` instance is no longer flipped to
`awaiting_qr`. `map_evolution_state` keeps its `:awaiting_qr` default and its
"never raises KeyError" contract (existing model tests unchanged). `known_evolution_state?`
is safe for non-string input (`state.to_s` before `key?`), and strictly safer than the old
behaviour for array / hash params. Webhook regression test added: `connection.update` with
`state: "reconnecting"` on a `connected` instance stays `connected`, responds 200.

The finding's concrete harm — asynchronous, signed-caller / malformed-payload,
future-release downgrade that later blocks dispatch — is on the webhook path and is now
closed. The `#verify` path was intentionally left mapping unknown → `awaiting_qr`; that is
a much weaker case (operator-initiated, synchronous, immediately visible, and the state is
read directly from Evolution rather than from an untrusted caller). Recorded as IN-09, not
a blocker: no Evolution 2.3.7 state string outside `{open, connecting, close, refused}`
exists today (verified in `26-RESEARCH.md`), so there is no live trigger.

---

## Info (carried forward from iteration 1 — out of fix scope)

### IN-01: `adopt` action + `post :adopt` route have no UI entry point

**File:** `app/controllers/admin/whatsapp_instances_controller.rb:16-24`, `config/routes.rb:16`
**Issue:** `_panel.html.erb` renders no "Adotar instância existente" control; auto-adopt
inside `InstanceProvisioner#call` covers the collision case. A stray authenticated POST to
`/adopt` against a healthy app-created instance runs `#call` → 403 "already in use" →
`#adopt` → flips `origin` to `adopted_existing` and overwrites `token` from
`fetch_instances`.
**Fix:** remove the `adopt` action + route, or gate it behind an explicit UI control and a
`whatsapp_instance.nil?` check.

### IN-02: migration adds `qr_expires_at` and `last_error` columns no phase-26 code touches

**File:** `db/migrate/20260830130934_create_whatsapp_instances.rb:11,14`
**Issue:** Undocumented dead schema today; acceptable only as future groundwork.
**Fix:** add a migration comment naming the intended future use, or drop the columns.

### IN-03: `_qr.html.erb` emits `src=""` when no QR is cached yet

**File:** `app/views/admin/whatsapp_instances/_qr.html.erb:21`
**Issue:** `src="<%= instance.last_qr_base64 %>"` renders an empty `src` while the QR is
still generating; several browsers resolve `src=""` as a re-request of the current URL.
**Fix:** wrap the `<img>` in `if instance.last_qr_base64.present?`, or use a 1x1 data-URI
placeholder.

### IN-04: `whatsapp_instances.token` has no NOT NULL constraint and no presence validation

**File:** `db/migrate/20260830130934_create_whatsapp_instances.rb:7`, `app/models/whatsapp_instance.rb`, `app/services/evolution/instance_provisioner.rb:67-74,94-105`
**Issue:** `persist_new` and `adopt` both fall through to `token: nil` if the Evolution
response omits every token key; failure surfaces only in a later phase.
**Fix:** `validates :token, presence: true` (or document the nil allowance), and consider
raising `Evolution::Errors::Unknown` when the create/adopt response carries no token.

### IN-05: connection dot added to the desktop table only; mobile card list omits it

**File:** `app/views/admin/clients/index.html.erb` vs `app/views/admin/clients/_client_row.html.erb`
**Issue:** The new "Conexão" column renders only in the `hidden sm:block` desktop table;
the mobile card loop shows name + status badge only.
**Fix:** extract the dot class/label logic into a helper and render it in both places.

### IN-06: `qr_pairing_controller.js` does not check `response.ok`

**File:** `app/javascript/controllers/qr_pairing_controller.js:40-53`
**Issue:** A 401/422/500 from `refresh_qr` makes `await response.json()` throw into the
empty `catch {}`, so a persistently failing endpoint is indistinguishable from "no QR yet"
until `MAX_CYCLES` elapses. Still unaddressed after the WR-02 verb change (the POST can now
also fail with 422 on a stale CSRF token).
**Fix:** `if (!response.ok) throw new Error(response.status)` before `.json()`, and surface
a soft "não foi possível atualizar o QR" hint after N consecutive failures.

### IN-07: webhook returns 200 (known instance) vs 204 (unknown instance) — enumerable with the HMAC key

**File:** `app/controllers/webhooks/evolution_controller.rb:15-19`
**Issue:** A caller holding the global `webhook_hmac_key` can compute a valid signature for
any `livia_client_<id>` and distinguish existing (`200`) from non-existing (`204`)
instances. Low impact (requires key compromise; IDs already sequential).
**Fix:** return the same status for both branches (`head :ok` or `head :no_content`
regardless of row existence).

### IN-08: `rack_attack` webhook throttle buckets all Evolution traffic under one source IP

**File:** `config/initializers/rack_attack.rb:40-42`
**Issue:** `throttle("webhooks/evolution_by_ip", limit: 120, period: 60) { req.ip }` —
Evolution egresses from a single/small IP set, so one noisy instance's bursts share the
120/min bucket with every other client's legitimate webhooks; hitting the cap drops real
events for all clients. Fine at current scale.
**Fix:** additionally key the throttle on `params[:instance]` (post-signature), or raise
the per-IP limit with headroom for concurrent instances.

### IN-09: `#verify` still maps an unknown Evolution state to `awaiting_qr` (WR-06 residual)

**File:** `app/controllers/admin/whatsapp_instances_controller.rb:40-48`
**Issue:** The WR-06 fix added `known_evolution_state?` only on the webhook path. `#verify`
still does `mapped = WhatsappInstance.map_evolution_state(state)` and `inst.update!(
connection_state: mapped, …)`, so if a future Evolution release emits a state string
outside `{open, connecting, close, refused}`, an operator "Forçar verificação" on a
`connected` instance would persist `awaiting_qr` and render an empty QR panel. No live
trigger today (Evolution 2.3.7 emits only the four known states, per `26-RESEARCH.md`), and
the change is operator-initiated and immediately visible — hence Info, not a blocker. The
one-line guard (`return … unless WhatsappInstance.known_evolution_state?(state)`, persisting
only `last_checked_at`) is already available.
**Fix:** apply the same `known_evolution_state?` gate in `#verify`, or accept and document
the divergence (the fixer left a human-verification note for exactly this).

---

_Reviewed: 2026-08-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard — re-review iteration 2_
