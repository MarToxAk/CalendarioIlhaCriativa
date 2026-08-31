# Phase 31 — Evolution API Coverage Decision

**Capability:** api-coverage (planner contribution)
**Phase:** 31 — Instância WhatsApp Compartilhada entre Clientes
**Evolution host:** `whatsapp.bomcustoilhabela.com.br` — Evolution API 2.3.7 (behind Cloudflare)
**Contract source:** `.planning/notes/evolution-contract.md` (read-path VERIFIED); carries forward the
Phase 26/27/29 surface decisions.

---

## Detector result

The deterministic ai-integration detector fires (the phase touches Evolution / SolidQueue seams),
**but this phase integrates ZERO new external API surface.** It changes call *topology*, not the
endpoint set.

> No new external API integration: Phase 31 adds no Evolution endpoint. It re-points two existing
> call sites from "per `WhatsappInstance` row" to "per physical connection (`instance_name`)":
> (1) `Whatsapp::GroupSynchronizer` fans one `fetchAllGroups` out to N local upserts; (2)
> `Webhooks::EvolutionController` fans one `connection.update` / `qrcode.updated` out to all
> sibling rows.

---

## Two topology changes (no surface change)

| Change | Endpoint / event | Before Phase 31 | After Phase 31 | Rationale |
|--------|------------------|-----------------|----------------|-----------|
| GroupSynchronizer sibling fan-out | `GET /group/fetchAllGroups/{instance}?getParticipants=false` | called once **per `WhatsappInstance` row** (once per client) | called **once per physical `instance_name`**, fanned out to N local `upsert_all` (one per sibling row) | D-05 — `fetchAllGroups` is ~40s for a 64-group account; calling it once per sibling wastes time/load and lets sibling caches drift. One Evolution call, N local writes. |
| Webhook sibling fan-out | webhook events `connection.update`, `qrcode.updated` | `find_by(instance_name:)` updates **one** row | `where(instance_name:).find_each { apply_event(it) }` updates **all** sibling rows | Pitfall 1 — a physical `connection.update` describes the shared session; leaving siblings stale makes `SendToGroupJob`'s `instance&.connected?` guard (ENVIO-07) read the wrong state. Zero extra Evolution calls. |

**Auth:** unchanged. `fetchAllGroups` uses the instance `token` (now identical across siblings by
design — copied in `InstanceProvisioner#reuse`); send uses the instance `token`. HMAC over
`instance_name` is identical for all siblings, so `valid_signature?` is unchanged.

---

## Reuse-provisioning path — endpoints deliberately NOT called

The `InstanceProvisioner#reuse` flow (D-03/D-06) is 100% local — it copies fields from an
already-connected sibling row. It deliberately does **not** call:

| Capability | Endpoint | Why NOT called |
|------------|----------|----------------|
| Create instance | `POST /instance/create` | the physical connection already exists; reuse creates only a local row |
| Connect / fetch QR | `GET /instance/connect/{instance}` | the session is already paired — no QR |
| Set / re-point webhook | `POST /webhook/set/{instance}` | the physical webhook already points at this system; re-setting could restart another client's session |
| Connection state | `GET /instance/connectionState/{instance}` | the sibling's cached `connection_state` is copied literally; the existing "Forçar verificação" button (`#verify`) covers a manual round-trip if needed (31-RESEARCH.md Assumption A2) |

---

## Send / instance / group surface — carried forward, re-decided

| Capability | Endpoint | Decision | Owner / rationale |
|------------|----------|----------|-------------------|
| Create instance | `POST /instance/create` | INTEGRATED (Phase 26) | PAIR-01 / EVO-04 — `Evolution::Client.create_instance`. Not called on the reuse path. |
| Connect / fetch QR | `GET /instance/connect/{instance}` | INTEGRATED (Phase 26) | PAIR-03. Not called on the reuse path. |
| Connection state | `GET /instance/connectionState/{instance}` | INTEGRATED (Phase 26) | PAIR-05 — `#verify`. Phase 31 copies the sibling's cached column on reuse. |
| Fetch instances | `GET /instance/fetchInstances` | INTEGRATED (Phase 25/26) | EVO-01 + adoption path. Unchanged. |
| Set / re-point webhook | `POST /webhook/set/{instance}` | INTEGRATED (Phase 26) | PAIR-02 / PAIR-06. Not called on the reuse path. |
| List all groups of an instance | `GET /group/fetchAllGroups/{instance}?getParticipants=false` | INTEGRATED (Phase 27) — **topology change (D-05)** | GRUPO-01/02 — now one call per physical `instance_name`, fanned out to N sibling upserts. `getParticipants=false` always. |
| Send text to a group | `POST /message/sendText/{instance}` | INTEGRATED (Phase 29) | ENVIO-10. Serialization key moves to `instance_name` (D-04) — endpoint unchanged. |
| Send media to a group | `POST /message/sendMedia/{instance}` | INTEGRATED (Phase 29) | ENVIO-01/08/10. Serialization key moves to `instance_name` (D-04) — endpoint unchanged. |
| Webhook events `CONNECTION_UPDATE` / `QRCODE_UPDATED` | webhook | INTEGRATED (Phase 26) — **topology change (Pitfall 1)** | PAIR-04/06 — now fanned out to all sibling rows. |
| Group participant list | `GET /group/fetchAllGroups/{instance}?getParticipants=true` | OPT-OUT | Not needed — Phase 27 decision unchanged. |
| Single-group info / refresh | `GET /group/findGroupInfos/{instance}` | OPT-OUT | Not needed — batch sync covers the list. |
| Group mutation (subject / picture / setting / participant / create / leave / invite) | `POST|DELETE /group/*` | OPT-OUT | Read-only group model — the number's owner manages groups in WhatsApp directly (Phase 27 decision unchanged). |
| Logout / delete / restart instance | `DELETE /instance/logout|delete`, `POST /instance/restart` | OPT-OUT | No instance-teardown requirement in v1.7. Reuse never deletes a shared connection. |
| Delivery / read receipts (`MESSAGES_UPDATE` / `DELIVERY_ACK`) | webhook | OPT-OUT | Future — DELIV-01. |

**No new INTEGRATE, no new OPT-OUT** this phase.

---

## Notes

- **No packages installed** this phase — Package Legitimacy Audit **N/A** (31-RESEARCH.md
  "Standard Stack": nenhuma instalação). The new Stimulus controller is auto-registered by
  `eagerLoadControllersFrom` — no dependency.
- **Live round-trip against a real paired instance with a sibling** is a UAT item, carried
  forward from Phase 26 (pairing deferred to the operator). Build + unit tests run against an
  injected fake `Evolution::Client`; the test DB is unavailable locally (31-RESEARCH.md Pitfall
  7) so verification is by `bin/rails runner` + inspection.
- **`READ_TIMEOUT_GROUPS` (60s)** is reused as-is by the single fan-out `fetchAllGroups` call —
  no new env var (31-RESEARCH.md "Runtime State Inventory").
