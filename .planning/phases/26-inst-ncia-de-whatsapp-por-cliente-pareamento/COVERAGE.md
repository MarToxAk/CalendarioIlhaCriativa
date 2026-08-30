# Phase 26 — Evolution API Coverage Decision Matrix

**Produced:** 2026-08-30 (gsd-plan-phase, api-coverage capability)
**Scope rule:** Phase 26 legitimately covers only instance provisioning + pairing + inbound
webhook. Everything on the send / group surface is OPT-OUT with an explicit downstream owner.

External service: **Evolution API `2.3.7`** at `https://whatsapp.bomcustoilhabela.com.br`
(shared agency manager, Cloudflare in front). Contract source: `.planning/notes/evolution-contract.md`
+ `26-RESEARCH.md` (read from tag `2.3.7` source).

---

## Capability surface

| # | Capability | Evolution endpoint | Disposition | Reason / downstream owner |
|---|------------|--------------------|-------------|---------------------------|
| 1 | Create instance | `POST /instance/create` | **INTEGRATE** | PAIR-01 — `Evolution::Client.create_instance` + `Evolution::InstanceProvisioner` (create mode). `instanceName` in body (only route without a path param). |
| 2 | Connect / fetch current QR | `GET /instance/connect/{instance}` | **INTEGRATE** | PAIR-03 — dev fallback + "Parear novamente" pull a fresh QR when the webhook `qrcode.updated` has not landed. Guards HTTP-200 `{error:true}`. |
| 3 | Connection state (read) | `GET /instance/connectionState/{instance}` | **INTEGRATE** (already exists — Phase 25) | PAIR-05 — synchronous "Forçar verificação" reconciles state without the webhook. `READ_TIMEOUT_FAST=15s`. |
| 4 | Set webhook | `POST /webhook/set/{instance}` | **INTEGRATE** | PAIR-02 — adoption re-points the webhook to this app **unconditionally** (Pitfall 4). Explicit `events` list always passed. |
| 5 | Fetch instances (list) | `GET /instance/fetchInstances` | **INTEGRATE** (already exists — Phase 25) | PAIR-02 — adoption looks the existing instance up by `livia_client_<id>` and reads its `token`/`hash` (assumption A1, closes in UAT). |
| 6 | Inbound webhook receiver (our endpoint) | `POST /webhooks/evolution` | **INTEGRATE** | PAIR-06 — HMAC-authenticated receiver for `connection.update` + `qrcode.updated` only. `messages.*` → OPT-OUT here (Phase 29). |
| 7 | Find webhook config | `GET /webhook/find/{instance}` | OPT-OUT | Not needed yet — adoption sets the webhook unconditionally; reading it back is a manual UAT nicety, not a phase requirement. |
| 8 | Restart instance | `POST /instance/restart/{instance}` | OPT-OUT | Not needed yet — "Parear novamente" uses `connect`; no restart requirement in v1.7. |
| 9 | Logout instance | `DELETE /instance/logout/{instance}` | OPT-OUT | Not needed yet — no requirement to end a WhatsApp session from the panel in v1.7. |
| 10 | Delete remote instance | `DELETE /instance/delete/{instance}` | OPT-OUT | `resource :whatsapp_instance` `destroy` removes only the **local** row. Deleting on the shared agency manager is out of scope (deferred). |
| 11 | Send text | `POST /message/sendText/{instance}` | OPT-OUT | Not needed yet — Phase 29 (send engine). |
| 12 | Send media | `POST /message/sendMedia/{instance}` | OPT-OUT | Not needed yet — Phase 29 (send engine); media ceiling closes in Phase 28 UAT. |
| 13 | Fetch all groups | `GET /group/fetchAllGroups/{instance}` | OPT-OUT | Not needed yet — Phase 27 (groups sync + cache). |
| 14 | Group participants / membership | `GET /group/participants/{instance}` | OPT-OUT | Not needed yet — Phase 27 (groups). |
| 15 | Webhook events `messages.*` | inbound | OPT-OUT | Not needed yet — Phase 29 (send engine tracks delivery). Receiver no-ops unknown events → `head :ok`. |

**INTEGRATE count:** 6 (create, connect, connectionState, webhook-set, fetchInstances, inbound receiver).
**OPT-OUT count:** 9, each with a named downstream phase or an explicit scope exclusion.

---

## Notes

- No new package is installed this phase (`26-RESEARCH.md` Package Legitimacy Audit — zero rows).
  `faraday` (Phase 25), Active Record Encryption, `OpenSSL`, `ActiveSupport::SecurityUtils` are all
  built-in / already in the bundle.
- The **write path** (`sendText`/`sendMedia`, media ceiling, `sendMedia` error shape) stays PENDING
  in `evolution-contract.md` and is owned by Phases 28/29 — Phase 26 must not encode any assumption
  about it.
- Inbound reachability (Evolution host → `POST /webhooks/evolution`) is not yet provable (app not
  deployed at `ilhacriativa.autopyweb.com.br`). The locked design makes `refresh_qr` polling +
  "Forçar verificação" (PAIR-05) the primary path in dev — the webhook is an enrichment hint, not a
  gate (D-12 / A4).
