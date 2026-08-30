# Phase 27 — Evolution API Coverage Decision

**Capability:** api-coverage (planner contribution)
**Phase:** 27 — Grupos do Cliente — Sync, Cache e Seleção Escopada
**Evolution host:** `whatsapp.bomcustoilhabela.com.br` — Evolution API 2.3.7 (behind Cloudflare)
**Contract source:** `.planning/notes/evolution-contract.md` (read-path VERIFIED; group-list shape source-read at tag 2.3.7, live sync = UAT)

Phase 27 adds exactly **one** new Evolution read: `GET /group/fetchAllGroups/{instance}?getParticipants=false`.
This document re-decides the whole group surface for this phase and carries the Phase 26 send/instance
baseline forward (re-decided, not copied).

---

## Group surface

| Capability | Endpoint | Decision | Rationale |
|------------|----------|----------|-----------|
| List all groups of an instance | `GET /group/fetchAllGroups/{instance}?getParticipants=false` | **INTEGRATE** | GRUPO-01 / GRUPO-02 — the one seam this phase adds (`Evolution::Client.fetch_groups`), consumed only by `Whatsapp::GroupSynchronizer` in a background job; result cached in `whatsapp_groups`. `getParticipants=false` always (mandatory string; `true` is much slower and adds timeout risk). |
| Single-group info / refresh | `GET /group/findGroupInfos/{instance}?groupJid=…` | **OPT-OUT** | Not needed — the batch sync covers the list; no single-group refresh requirement in v1.7. (`findGroupInfos` only partially repairs null `subject` anyway — Evolution issue #2124.) |
| Group participant list | `GET /group/fetchAllGroups/{instance}?getParticipants=true` (and `/group/participants`) | **OPT-OUT** | Not needed yet — Phase 27 passes `getParticipants=false`. A future phase may need it to check the instance is a group admin before send. Deferred in 27-CONTEXT.md "Deferred Ideas". |
| Group invite code (read) | `GET /group/inviteCode/{instance}` | **OPT-OUT** | Not needed — this app reads groups, never mutates them; the number's owner manages groups in WhatsApp directly. |
| Accept invite code | `GET /group/acceptInviteCode/{instance}` | **OPT-OUT** | Not needed — read-only group model; the number's owner joins groups in WhatsApp directly. |
| Update group subject | `POST /group/updateGroupSubject/{instance}` | **OPT-OUT** | Not needed — this app reads groups, never mutates them. |
| Update group picture | `POST /group/updateGroupPicture/{instance}` | **OPT-OUT** | Not needed — this app reads groups, never mutates them. |
| Update group setting (announce/restrict) | `POST /group/updateGroupSetting/{instance}` | **OPT-OUT** | Not needed — `announce` is read from `fetchAllGroups` and surfaced as a badge; the app never changes it. |
| Update participant (add/remove/promote) | `POST /group/updateParticipant/{instance}` | **OPT-OUT** | Not needed — the number's owner manages membership in WhatsApp directly. |
| Create group | `POST /group/create/{instance}` | **OPT-OUT** | Not needed — the product posts to existing consumer groups; it never creates them (out of scope per REQUIREMENTS.md). |
| Leave group | `DELETE /group/leaveGroup/{instance}` | **OPT-OUT** | Not needed — read-only group model. |

---

## Send / instance surface (Phase 26 baseline carried forward — re-decided for this surface)

| Capability | Endpoint | Decision | Owner / rationale |
|------------|----------|----------|-------------------|
| Create instance | `POST /instance/create` | INTEGRATED (Phase 26) | PAIR-01 / EVO-04 — `Evolution::Client.create_instance`. |
| Connect / fetch QR | `GET /instance/connect/{instance}` | INTEGRATED (Phase 26) | PAIR-03 — `Evolution::Client.connect`. |
| Connection state | `GET /instance/connectionState/{instance}` | INTEGRATED (Phase 26) | PAIR-05 — `Evolution::Client.connection_state`; Phase 27 reads the cached `connection_state` column, not this endpoint, in the sync guard. |
| Fetch instances | `GET /instance/fetchInstances` | INTEGRATED (Phase 25/26) | EVO-01 round-trip proof + adoption path. |
| Set / re-point webhook | `POST /webhook/set/{instance}` | INTEGRATED (Phase 26) | PAIR-02 / PAIR-06 — `Evolution::Client.set_webhook`. |
| Send text to a group | `POST /message/sendText/{instance}` | **OPT-OUT (Phase 27)** | Phase 29 owner (ENVIO-10) — Phase 27 deliberately stops before any send. |
| Send media to a group | `POST /message/sendMedia/{instance}` | **OPT-OUT (Phase 27)** | Phase 29 owner (ENVIO-01/04/08/10); media ceiling verification is a Phase 28 UAT item. |
| Logout / delete instance | `DELETE /instance/logout/{instance}`, `DELETE /instance/delete/{instance}` | **OPT-OUT** | Not needed — v1.7 has no instance-teardown requirement; `Client dependent: :destroy` handles local rows. |
| Restart instance | `POST /instance/restart/{instance}` | **OPT-OUT** | Not needed — Phase 26 "Parear novamente" (`connect`) covers recovery; no restart requirement. |
| Delivery / read receipts via webhook (`MESSAGES_UPDATE` / `DELIVERY_ACK`) | webhook events | **OPT-OUT** | Future — DELIV-01 (Future Requirements). Phase 26 subscribes only `QRCODE_UPDATED` / `CONNECTION_UPDATE`. |

---

## Notes

- **Auth for `fetchAllGroups`:** Phase 27 uses the **instance token** (`whatsapp_instance.token`,
  already `encrypts`), not the global apikey — group reads are an operation of the paired instance.
  Fallback to `Evolution.global_api_key` if the instance token 401s (contract-implied, UAT — Assumption
  A2 in 27-RESEARCH.md).
- **No new packages** this phase — Package Legitimacy Audit N/A (27-RESEARCH.md).
- **Live `fetchAllGroups` against a real paired instance** is a UAT item, carried forward from Phase 26
  (pairing deferred to the operator). Build + unit-test against an injected fake `Evolution::Client`.
