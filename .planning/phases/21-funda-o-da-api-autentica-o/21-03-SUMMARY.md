---
phase: 21-funda-o-da-api-autentica-o
plan: "03"
subsystem: api-auth
tags: [jwt, session-controllers, admin-login, client-login, anti-enumeration]
dependency_graph:
  requires: [21-02]
  provides: [Api::V1::Admin::SessionsController, Api::V1::Client::SessionsController, POST /api/v1/admin/session, POST /api/v1/client/session]
  affects:
    - app/controllers/api/v1/admin/sessions_controller.rb
    - app/controllers/api/v1/client/sessions_controller.rb
tech_stack:
  added: []
  patterns: [User.find_by(email_address:) + #authenticate, Client.find_by(access_token:) + #authenticate + active?, Api::JwtService.encode, render_envelope, render_error]
key_files:
  created:
    - app/controllers/api/v1/admin/sessions_controller.rb
    - app/controllers/api/v1/client/sessions_controller.rb
  modified: []
decisions:
  - "Client sessions controller uses two sequential checks — client&.authenticate first, then client.active? — so the inactive case is indistinguishable from a wrong-password case at the response level (anti-enumeration T-21-10)"
  - "Admin controller strips and downcases the email param before find_by(email_address:) because the model normalize is not called on queries — only on save"
  - "Both controllers inherit Api::V1::BaseController directly (not namespace base controllers) so no auth guard before_action fires on the login action (T-21-11)"
  - "Scope hardcoded as string literal in each controller — not derived from request parameters (T-21-13)"
  - "Live curl with valid admin credentials returned HTML 500 (web-console rendered) due to missing jwt_secret credential — verified via bin/rails runner + JWT_SECRET env var instead (plan 21-05 sets credentials)"
metrics:
  duration: "~2 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 21 Plan 03: Fundação da API + Autenticação Summary

**One-liner:** Admin and client API login controllers using User.find_by(email_address:)+#authenticate and Client.find_by(access_token:)+#authenticate+active?, both issuing JWTs via Api::JwtService.encode with hardcoded scope literals and generic invalid_credentials 401 for all failure paths.

## What Was Built

### Task 1: Api::V1::Admin::SessionsController

Created `app/controllers/api/v1/admin/sessions_controller.rb`:

- Inherits `Api::V1::BaseController` — no authentication `before_action` guard
- `POST /api/v1/admin/session` accepts `{ email, password }` JSON body
- Finds user: `User.find_by(email_address: params.require(:email).strip.downcase)` — uses the model field name `email_address`, not `email` (Critical Constraint #4 from PATTERNS.md / RESEARCH.md Pitfall 4)
- Authenticates: `user&.authenticate(params.require(:password))` — safe null-conditional; both nonexistent user and wrong password produce a single falsy result
- On failure: `render_error(code: "invalid_credentials", ...)` with HTTP 401 — same message regardless of whether the user exists (anti-enumeration T-21-09)
- On success: `Api::JwtService.encode({ sub: user.id.to_s, scope: "admin" })` with `render_envelope(data: { token:, expires_in: }, status: :created)` (201)

### Task 2: Api::V1::Client::SessionsController

Created `app/controllers/api/v1/client/sessions_controller.rb`:

- Inherits `Api::V1::BaseController` — no authentication `before_action` guard (T-21-11)
- `POST /api/v1/client/session` accepts `{ access_token, password }` JSON body
- Finds client: `Client.find_by(access_token: params.require(:access_token))` — `access_token` identifies the client, not the Bearer header token
- Authenticates: `client&.authenticate(params.require(:password))` — nonexistent client returns same 401 as wrong password (anti-enumeration T-21-09)
- Checks `client.active?` after authentication — inactive client returns same `invalid_credentials` 401, not a revealing "account blocked" message (anti-enumeration T-21-10)
- On success: `Api::JwtService.encode({ sub: client.id.to_s, scope: "client" })` with `render_envelope(data: { token:, expires_in: }, status: :created)` (201)

## Verification

| Check | Command | Result |
|-------|---------|--------|
| email_address field (admin) | `grep "find_by.*email_address"` | PASS — line 5 |
| access_token lookup (client) | `grep "find_by.*access_token"` | PASS — line 5 |
| invalid_credentials count (admin) | `grep -c "invalid_credentials"` | 1 |
| invalid_credentials count (client) | `grep -c "invalid_credentials"` | 2 (wrong creds + inactive) |
| scope literals | `grep "scope.*admin\|scope.*client"` | Both present, hardcoded |
| Route admin | `bin/rails routes --grep /api/v1` | `POST /api/v1/admin/session api/v1/admin/sessions#create` |
| Route client | `bin/rails routes --grep /api/v1` | `POST /api/v1/client/session api/v1/client/sessions#create` |
| Curl admin 401 | `POST /api/v1/admin/session` invalid creds | `{ errors: [{ code: "invalid_credentials" }] }` HTTP 401 |
| Curl client 401 | `POST /api/v1/client/session` invalid creds | `{ errors: [{ code: "invalid_credentials" }] }` HTTP 401 |
| Anti-enumeration admin | Known email + wrong password | HTTP 401 (same as nonexistent email) |
| JwtService round-trip | `bin/rails runner` with `JWT_SECRET` env | Token encoded + decoded; scope and sub correct |

**Test suite substitution:** `bin/rails test` cannot run (test DB owned by different OS user). Verified via source assertions (grep), `bin/rails routes`, curl against live dev server, and `bin/rails runner` JwtService round-trip with temporary `JWT_SECRET` env var.

**Live curl substitution for valid login:** `POST /api/v1/admin/session` with real credentials returned an HTML 500 because `jwt_secret` is not yet set in credentials (that is plan 21-05's responsibility). Substituted with `bin/rails runner` + temporary `JWT_SECRET=test-secret-for-verification-only` env var — encode produced a valid `eyJ...` JWT, decode returned `sub: "1"` and `scope: "admin"`. Source assertions confirm the client controller follows the identical pattern.

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 | fb32218 | feat(21-03): create Api::V1::Admin::SessionsController login endpoint |
| Task 2 | 902fdb4 | feat(21-03): create Api::V1::Client::SessionsController login endpoint |

## Deviations from Plan

None — plan executed exactly as written.

The plan's Task 2 action described checking `client.active?` "after" authenticate — this is implemented as written: auth check first, then active? check. Both failure branches return identical `invalid_credentials` response to prevent enumeration.

## Threat Surface Scan

All mitigations from the plan's threat register were applied:

| Threat ID | Category | Mitigation Applied | Verified |
|-----------|----------|--------------------|---------|
| T-21-09 | Information Disclosure | Single `invalid_credentials` for both user-not-found and wrong password (admin and client) | curl confirmed: known email + wrong password = same 401 as nonexistent email |
| T-21-10 | Information Disclosure | `client.active?` check returns same `invalid_credentials` — inactive status not revealed separately | Code review confirmed: two separate render_error calls with identical code+detail+status |
| T-21-11 | Elevation of Privilege | Both controllers inherit `Api::V1::BaseController` directly, not namespace base_controllers with auth guards | Code review confirmed: no `before_action :authenticate_*` in either controller |
| T-21-12 | Repudiation | Rack::Attack throttles for API login endpoints added in plan 21-01 | Pre-existing mitigation |
| T-21-13 | Tampering | `scope` is a string literal hardcoded in each controller — `"admin"` and `"client"` respectively, not derived from params | Source assertions confirmed |

No new security-relevant surface beyond what was planned.

## Known Stubs

None — controllers implement full logic. No hardcoded empty values or placeholder text.

## Self-Check: PASSED

- app/controllers/api/v1/admin/sessions_controller.rb: FOUND
- app/controllers/api/v1/client/sessions_controller.rb: FOUND
- Commit fb32218: FOUND (feat(21-03): create Api::V1::Admin::SessionsController...)
- Commit 902fdb4: FOUND (feat(21-03): create Api::V1::Client::SessionsController...)
