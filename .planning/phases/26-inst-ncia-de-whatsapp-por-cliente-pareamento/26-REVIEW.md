---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
reviewed: 2026-08-30T14:34:41Z
depth: standard
files_reviewed: 25
files_reviewed_list:
  - app/models/whatsapp_instance.rb
  - app/models/client.rb
  - app/services/evolution/client.rb
  - app/services/evolution/instance_provisioner.rb
  - app/services/evolution.rb
  - app/controllers/admin/whatsapp_instances_controller.rb
  - app/controllers/admin/clients_controller.rb
  - app/controllers/webhooks/evolution_controller.rb
  - app/helpers/admin/whatsapp_instances_helper.rb
  - app/javascript/controllers/qr_pairing_controller.js
  - app/views/admin/whatsapp_instances/_panel.html.erb
  - app/views/admin/whatsapp_instances/_qr.html.erb
  - app/views/admin/whatsapp_instances/_connection_badge.html.erb
  - app/views/admin/clients/show.html.erb
  - app/views/admin/clients/index.html.erb
  - app/views/admin/clients/_client_row.html.erb
  - config/initializers/evolution.rb
  - config/initializers/filter_parameter_logging.rb
  - config/initializers/rack_attack.rb
  - config/routes.rb
  - db/migrate/20260830130934_create_whatsapp_instances.rb
  - test/services/evolution/client_test.rb
  - test/models/whatsapp_instance_test.rb
  - test/controllers/admin/whatsapp_instances_controller_test.rb
  - test/controllers/webhooks/evolution_controller_test.rb
  - test/integration/rack_attack_test.rb
findings:
  critical: 0
  warning: 6
  info: 8
  total: 14
status: issues_found
---

# Phase 26: Code Review Report

**Reviewed:** 2026-08-30T14:34:41Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

Phase 26 adds per-client WhatsApp Evolution instances: a `WhatsappInstance` model with
`encrypts :token`, an HMAC-authenticated webhook receiver, an admin panel with QR polling,
and provisioning/adoption orchestration. The security-sensitive core holds up under review:

**Verified sound (no finding):**
- **PAIR-06 ordering** — `Webhooks::EvolutionController#create` calls `valid_signature?`
  as its first statement; `valid_signature?` performs only an HMAC recompute
  (`WhatsappInstance.webhook_secret_for` → `OpenSSL::HMAC` + `Evolution.webhook_hmac_key`
  reading ENV/credentials) with **no ActiveRecord query** before the check. An invalid
  secret returns `401` before `find_by` runs and before any existence disclosure.
- **Timing-safe comparison** — both sides are `Digest::SHA256.hexdigest`-normalized to a
  fixed 64-char length before `ActiveSupport::SecurityUtils.secure_compare`, so
  `secure_compare` never hits its unequal-length short-circuit and length is not leaked.
- **EVO-04 token at rest** — `encrypts :token` with no `deterministic: true` (non-deterministic
  AES-GCM); the token is never queried by value anywhere, and the four controller rescue
  blocks log `#{e.class}` only (never `e.message`, never the token). `Evolution::Client`
  logs method/path/status/duration only.
- **INFRA-04** — `filter_parameters` covers `token`, `apikey`, `hash`, `qrcode`, `base64`,
  `pairing_code`/`pairingCode`; the webhook controller never logs the raw body or
  `params.inspect`, and `X-Webhook-Secret` is a header (not logged by Rails request logging).
- **Cross-client isolation** — every admin instance action resolves through
  `@client.whatsapp_instance` with `@client = Client.find(params[:client_id])`; there is no
  path that loads a `WhatsappInstance` by a free-standing id param.
- **InstanceProvisioner rescue** — `raise unless e.message =~ /already in use/i` re-raises a
  genuine 401/`Permanent`; test `"create com erro do Evolution (não already-in-use)"` proves
  the non-collision failure propagates and no row is created.
- **N+1** — `clients#index` uses `Client.includes(:whatsapp_instance)`; the connection dot in
  `_client_row` reads the preloaded association.
- **Migration** — `create_table` + `add_index` inside `change` is auto-reversible.

Remaining issues are robustness/quality: unguarded nil-instance crash paths, a
state-changing GET, a declared-but-unimplemented `destroy` route, brittle string-matching
on upstream error copy, and a persist-before-QR ordering that produces contradictory
operator feedback.

## Warnings

### WR-01: `verify` and `reconnect` raise a 500 (NoMethodError on nil) when the client has no instance

**File:** `app/controllers/admin/whatsapp_instances_controller.rb:36-37, 74-75`
**Issue:** `refresh_qr` correctly guards with `inst&.awaiting_qr?`, but `verify` does
`state = Evolution::Client.connection_state(inst.instance_name)` and `reconnect` does
`Evolution::Client.connect(inst.instance_name)` with no nil check. Both routes
(`post :verify`, `post :reconnect`) are directly reachable; the UI only hides the buttons.
An authenticated admin POST (or a stale form after the instance was destroyed) hits
`nil.instance_name` → `NoMethodError` → unhandled 500. Not caught by the
`Evolution::Errors::*` rescue.
**Fix:**
```ruby
def verify
  inst = @client.whatsapp_instance
  return redirect_to(admin_client_path(@client),
    alert: "Este cliente ainda não tem uma instância de WhatsApp.") if inst.nil?
  # ...
end
# same guard at the top of #reconnect
```

### WR-02: `refresh_qr` is a GET that performs side effects (outbound Evolution call + DB write)

**File:** `config/routes.rb:14` and `app/controllers/admin/whatsapp_instances_controller.rb:64-68, 99-106`
**Issue:** `get :refresh_qr` triggers `pull_fresh_qr`, which calls
`Evolution::Client.connect` (outbound HTTP) and `inst.update!(last_qr_base64: ...)`.
GET requests are exempt from CSRF verification and are fair game for link prefetch,
`<img src>`, and crawlers. While an admin is authenticated, a third-party page can force a
throttled QR regeneration on a client that is mid-pairing (fires only when `awaiting_qr?`
and `last_qr_base64.blank?`). State changes belong on a non-GET verb.
**Fix:** change the route to `post :refresh_qr`; update `qr_pairing_controller.js` to
`fetch(this.urlValue, { method: "POST", headers: { Accept: "application/json",
"X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content } })`.

### WR-03: `destroy` route declared but no `destroy` action exists

**File:** `config/routes.rb:13` (`resource :whatsapp_instance, only: [ :create, :destroy ]`)
**Issue:** `Admin::WhatsappInstancesController` implements `create`, `adopt`, `verify`,
`refresh_qr`, `reconnect` — but not `destroy`. A `DELETE /admin/clients/:id/whatsapp_instance`
raises `AbstractController::ActionNotFound` (500). No template exists either. Dead/broken
surface.
**Fix:** either implement `destroy` (with a confirm modal and `inst&.destroy`) or drop
`:destroy` from the route `only:` list until the feature lands.

### WR-04: create-vs-adopt decision hinges on regex-matching Evolution's human-readable error text

**File:** `app/services/evolution/instance_provisioner.rb:27-30`
**Issue:** `rescue Evolution::Errors::Permanent => e; raise unless e.message =~ /already in use/i`.
The message is built in `Evolution::Client#raise_for_status!` from
`body.dig("response", "message")` — i.e. upstream copy. If the Evolution host changes the
403 wording (`"already exists"`, `"name taken"`, a localized string, etc.), every name
collision stops diverting to `#adopt` and becomes a hard "não foi possível criar" for the
operator, with no way forward. Conversely a future unrelated 403 whose text happens to
contain "already in use" would be mis-routed into `#adopt` and overwrite local state.
**Fix:** key the branch on structured data (HTTP 403 + an error code if the envelope
carries one), or centralize the accepted phrases in a named constant with a comment and add
a test asserting a non-collision 403 (e.g. `403 API key forbidden`) propagates unchanged.

### WR-05: `adopt` persists the row before fetching the QR, yielding contradictory operator feedback

**File:** `app/services/evolution/instance_provisioner.rb:44-61`
**Issue:** `adopt` calls `row.save!` (line 58) and only then calls `@api.connect(name)[:base64]`
(line 60) to populate `qr_base64`. If `connect` raises `Transient`/`Unknown`, the exception
propagates out of `#call`; the controller catches it and shows
*"Não foi possível criar a instância no WhatsApp"* — yet the `WhatsappInstance` row now
exists and the panel renders it (with `origin: adopted_existing` and whatever partial
`token`/`remote_instance_id` `fetch_instances` returned). The operator sees a failure
message next to a live instance card.
**Fix:** fetch the QR before `save!`, or wrap the `connect` call so a QR failure is
swallowed and `Result.new(..., qr_base64: nil)` is returned (the Stimulus poller then
recovers on the next cycle), matching the deliberately-silent handling in `pull_fresh_qr`.

### WR-06: any unrecognized Evolution connection state silently downgrades a healthy instance to `awaiting_qr`

**File:** `app/models/whatsapp_instance.rb:33-36` and `app/controllers/webhooks/evolution_controller.rb:54-64`
**Issue:** `map_evolution_state` returns `:awaiting_qr` for every value not in
`{open, connecting, close, refused}`. This map is shared by the webhook receiver, `#verify`,
and adoption. `apply_connection_update` guards only `state.blank?` — a single
`connection.update` carrying a state string Evolution adds in a future release (or a
malformed payload from a signed caller) flips a `connected` instance back to
"Aguardando pareamento", which in later phases blocks dispatch. Unknown states should be
ignored on the webhook path, not treated as "needs a new QR".
**Fix:** have `map_evolution_state` return `nil` for unknown input and let each caller
decide: the webhook `apply_connection_update` should `return if mapped.nil?` (leave state
untouched); `#verify` can persist `last_checked_at` only. Keep the "never raise KeyError"
guarantee by using `nil` rather than a default enum value.

## Info

### IN-01: `adopt` action + `post :adopt` route have no UI entry point

**File:** `app/controllers/admin/whatsapp_instances_controller.rb:16-24`, `config/routes.rb:16`, `app/views/admin/whatsapp_instances/_panel.html.erb`
**Issue:** `_panel.html.erb` never renders an "Adotar instância existente" button — the
auto-adopt inside `InstanceProvisioner#call` covers the collision case. The standalone
`adopt` action is unreachable from the app. A stray authenticated POST to `/adopt` against a
healthy app-created instance runs `#call` → 403 "already in use" → `#adopt` → flips `origin`
to `adopted_existing` and overwrites `token` from `fetch_instances`.
**Fix:** remove the `adopt` action and route, or gate it behind an explicit UI control and
a state check (only offer it when `whatsapp_instance.nil?`).

### IN-02: migration adds `qr_expires_at` and `last_error` columns that no phase-26 code touches

**File:** `db/migrate/20260830130934_create_whatsapp_instances.rb:11,14`
**Issue:** Neither column is read or written by any reviewed file. Acceptable if it is
groundwork for a later phase, but it is undocumented dead schema today.
**Fix:** add a comment in the migration noting the intended future use, or drop the columns
until needed.

### IN-03: `_qr.html.erb` emits `src=""` when no QR is cached yet

**File:** `app/views/admin/whatsapp_instances/_qr.html.erb:21`
**Issue:** `src="<%= instance.last_qr_base64 %>"` renders an empty `src` attribute while the
QR is still being generated. Several browsers resolve `src=""` as a re-request of the
current document URL.
**Fix:** `<% if instance.last_qr_base64.present? %><img src="..."><% end %>`, or point `src`
at a 1x1 transparent data-URI placeholder.

### IN-04: `whatsapp_instances.token` has no NOT NULL constraint and no presence validation

**File:** `db/migrate/20260830130934_create_whatsapp_instances.rb:7`, `app/models/whatsapp_instance.rb`, `app/services/evolution/instance_provisioner.rb:63-74`
**Issue:** `persist_new` sets `token: resp["hash"] ...` and `adopt` sets
`token: existing["token"] || existing["hash"] || existing.dig("Auth", "token")`. If the
Evolution response omits all of those, the row is created with `token: nil` and no error;
the failure surfaces only in a later phase that needs the per-instance key.
**Fix:** add `validates :token, presence: true` (or explicitly allow nil with a documented
reason), and consider raising `Evolution::Errors::Unknown` in the provisioner when the
create/adopt response carries no token.

### IN-05: connection dot added to the desktop table only; mobile card list omits it

**File:** `app/views/admin/clients/index.html.erb:46-61` vs `app/views/admin/clients/_client_row.html.erb:9-21`
**Issue:** The new "Conexão" column is rendered in the `hidden sm:block` desktop table but
the `block sm:hidden` mobile card loop shows only name + status badge. Inconsistent surface
across breakpoints.
**Fix:** add the same dot (extract the dot_class/dot_label logic into a helper or shared
partial and render it in both places).

### IN-06: `qr_pairing_controller.js` does not check `response.ok`

**File:** `app/javascript/controllers/qr_pairing_controller.js:30-44`
**Issue:** A 401/500 from `refresh_qr` makes `await response.json()` throw into the empty
`catch {}`, so a persistently failing endpoint is indistinguishable from "no QR yet" until
`MAX_CYCLES` elapses and the regenerate button appears. No soft error is surfaced to the
operator.
**Fix:** `if (!response.ok) { throw new Error(response.status) }` before `.json()`, and
consider showing a "não foi possível atualizar o QR" hint after N consecutive failures.

### IN-07: webhook returns 200 (known instance) vs 204 (unknown instance) — enumerable with the HMAC key

**File:** `app/controllers/webhooks/evolution_controller.rb:15-20`
**Issue:** A caller that already holds the global `webhook_hmac_key` can compute a valid
signature for any `livia_client_<id>` and distinguish existing instances (`200`) from
non-existing ones (`204`). Impact is low (requires key compromise, and IDs are already
sequential), but both branches could return `204` to remove the oracle.
**Fix:** `head :no_content` for the success path too, or `head :ok` for both; do not let the
status code depend on row existence.

### IN-08: `rack_attack` webhook throttle buckets all Evolution traffic under one source IP

**File:** `config/initializers/rack_attack.rb:40-42`
**Issue:** `throttle("webhooks/evolution_by_ip", limit: 120, period: 60) { req.ip ... }`.
Evolution → app traffic originates from a single (or very small set of) egress IP, so one
noisy instance's `qrcode.updated`/`connection.update` bursts share the same 120/min bucket
as every other client's legitimate webhooks; hitting the cap drops real events for all
clients. Fine at current agency scale, worth revisiting as instance count grows.
**Fix:** consider keying the throttle on `params[:instance]` (post-signature) in addition to
IP, or raising the per-IP limit with headroom for concurrent instances.

---

_Reviewed: 2026-08-30T14:34:41Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
