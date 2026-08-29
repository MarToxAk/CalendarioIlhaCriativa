# Phase 25 — Evolution API Coverage Matrix

**Produced:** 2026-08-29 (plan-phase)
**Gate:** `api-coverage.verify-pre` reads this file at seal time.
**Rule:** `INTEGRATE` is the default. Every `OPT-OUT` carries a one-line reason naming the owning phase. This matrix is the *subtraction record* — Phase 25's own scope is only the read/health path + the `Evolution::Client` seam + the error taxonomy, so most send/pairing/group capabilities are legitimately `OPT-OUT` here.

Host contract source: `.planning/notes/evolution-contract.md` (host verified `2.3.7`, read-path VERIFICADO, write-path PENDENTE → UAT 26/28).

| # | Capability | Endpoint / surface | Disposition | Reason |
|---|-----------|--------------------|-------------|--------|
| 1 | API health / version banner | `GET /` (no auth) | INTEGRATE | EVO-01 contract verification; re-probe before writing client code if the planning→execution gap exceeds research "valid until" 2026-09-28. |
| 2 | List instances | `GET /instance/fetchInstances` (global `apikey`) | INTEGRATE | Tracer read path (Plan 01); proves the seam + auth enforcement; is the phase-26 "adopt existing instance" data source. |
| 3 | Connection state | `GET /instance/connectionState/{instance}` | INTEGRATE | Read method on `Evolution::Client` (Plan 01); the basis of the pre-send `open` check in phase 29. Returns the raw state string in phase 25 — raising `NotConnected` is the caller's job later. |
| 4 | Create instance | `POST /instance/create` | OPT-OUT | phase 26 — instance provisioning / pairing. |
| 5 | Connect / fetch QR | `GET /instance/connect/{instance}` | OPT-OUT | phase 26 — QR pairing screen with auto-refresh. |
| 6 | Set / re-point webhook | `POST /webhook/set/{instance}` | OPT-OUT | phase 26 — webhook receiver + mandatory re-point on instance adoption. |
| 7 | Inbound webhook events | inbound `POST` (`QRCODE_UPDATED`, `CONNECTION_UPDATE`, …) | OPT-OUT | phase 26 — `Webhooks::EvolutionController` + `secure_compare` + Rack::Attack. Event casing is an `evolution-contract.md` PENDENTE item — phase 25 code must not depend on it. |
| 8 | Fetch all groups (+ participants) | `GET /group/fetchAllGroups/{instance}?getParticipants=` | OPT-OUT | phase 27 — group sync & local cache. `getParticipants` is a mandatory string query param. |
| 9 | Send text | `POST /message/sendText/{instance}` | OPT-OUT | phase 29 — send engine. |
| 10 | Send media | `POST /message/sendMedia/{instance}` | OPT-OUT | phase 29 — send engine. Real media ceiling + success/error response shape are `evolution-contract.md` PENDENTE items → measured in phase 28/29 UAT. |
| 11 | Per-instance token (`hash`) auth | credential model | OPT-OUT | phase 26 — EVO-04 `encrypts` the per-instance token. Phase 25 uses the global `apikey` only. |
| 12 | Logout / delete instance | `DELETE /instance/logout/{instance}`, `DELETE /instance/delete/{instance}` | OPT-OUT | No v1.7 requirement for instance teardown from the app. Revisit if instance lifecycle management is added post-v1.7. |
| 13 | Typing-simulation `delay` field on send | `delay` (ms) in send payloads | OPT-OUT | phase 29 — and even there it is NOT the inter-group spacing (it blocks the HTTP request). Inter-group delay is Rails-side `wait_until` from ENV. |
| 14 | Restart / set presence / profile / chat endpoints | `/instance/restart`, `/chat/*`, `/settings/*`, profile ops | OPT-OUT | Out of milestone scope — the product is art approval + scheduled group posting, not inbox/profile management (REQUIREMENTS.md "Out of Scope"). |

**Integrate count:** 3 of 14 (health, fetchInstances, connectionState) — the read/health surface only.
**Opt-out count:** 11 of 14, each with a named owning phase or an explicit out-of-scope citation.
