---
phase: 21-funda-o-da-api-autentica-o
plan: "02"
subsystem: api-foundation
tags: [jwt, base-controller, routes, auth, hs256]
dependency_graph:
  requires: [21-01]
  provides: [Api::JwtService, Api::V1::BaseController, api-v1-routes, render_envelope, render_error, domain-errors]
  affects: [app/services/api/jwt_service.rb, app/controllers/api/v1/base_controller.rb, config/routes.rb]
tech_stack:
  added: []
  patterns: [ActionController::API hierarchy, PORO JwtService, rescue_from envelope, namespace :api defaults json]
key_files:
  created:
    - app/services/api/jwt_service.rb
    - app/controllers/api/v1/base_controller.rb
  modified:
    - config/routes.rb
decisions:
  - "Api::V1::BaseController inherits from ActionController::API — not ApplicationController — to exclude CSRF, cookies, sessions, and the Authentication concern"
  - "JwtService PORO reads DEFAULT_EXPIRY from credentials.jwt_expiry_hours || 24 at class load time (per D-04 configurable expiry)"
  - "Domain errors Api::Errors::TokenExpired/TokenInvalid defined before JwtService in same file for rescue availability"
  - "routes.rb: namespace :api uses defaults: { format: :json } — no Accept header negotiation required"
  - "secret method uses private_class_method — never exposed as public class method"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 21 Plan 02: Fundação da API + Autenticação Summary

**One-liner:** Api::JwtService PORO with HS256-pinned encode/decode, Api::V1::BaseController with envelope helpers and rescue_from, and /api/v1/admin+client+ai route namespaces in config/routes.rb.

## What Was Built

### Task 1: Api::JwtService with domain errors

Created `app/services/api/` directory (first service PORO in this codebase) and `app/services/api/jwt_service.rb`:

- `ALGORITHM = "HS256".freeze` — hardcoded constant, never dynamic (alg:none defense — T-21-04)
- `DEFAULT_EXPIRY` reads `Rails.application.credentials.jwt_expiry_hours || 24` then converts to duration (D-04 configurable expiry)
- `encode(payload, expiry: DEFAULT_EXPIRY)` — merges `iat` and `exp` claims, calls `JWT.encode(full_payload, secret, ALGORITHM)`
- `decode(token)` — calls `JWT.decode(token, secret, true, { algorithm: ALGORITHM, verify_exp: true })`, returns indifferent access hash. Rescues `JWT::ExpiredSignature` → `Api::Errors::TokenExpired`; rescues `JWT::DecodeError` → `Api::Errors::TokenInvalid` (T-21-05)
- `secret` private class method reads `credentials.jwt_secret || ENV.fetch("JWT_SECRET")` — never hardcoded (T-21-06); marked `private_class_method :secret`
- `Api::Errors::TokenExpired` and `Api::Errors::TokenInvalid` defined before `JwtService` class in same file

### Task 2: Api::V1::BaseController and /api/v1/ routes

Created `app/controllers/api/v1/base_controller.rb`:
- Inherits from `ActionController::API` (not `ApplicationController`) — no CSRF, no cookies, no Authentication concern (T-21-07)
- Three `rescue_from` handlers: `RecordNotFound` → `not_found` (404), `RecordInvalid` → `unprocessable_entity` (422), `ParameterMissing` → `bad_request` (400) (T-21-08)
- `render_envelope(data:, meta: {}, status: :ok)` → `{ data, meta, errors: [] }` (D-05)
- `render_error(code:, detail:, status:, field: nil)` → `{ data: nil, meta: {}, errors: [{ code, detail, field? }] }` (D-05)
- `unprocessable_entity(exception)` maps `exception.record.errors` to array of `{ code, detail, field }` hashes

Updated `config/routes.rb` — inserted before the health check route:
- `namespace :api, defaults: { format: :json }` wrapper (INFAPI-01)
- `namespace :v1` > `namespace :admin` with `resource :session, only: [:create]`
- `namespace :v1` > `namespace :client` with `resource :session, only: [:create]`
- `namespace :v1` > `namespace :ai` (empty, Phase 24 resources)

## Verification

| Check | Command | Result |
|-------|---------|--------|
| JwtService responds | `bin/rails runner 'puts Api::JwtService.respond_to?(:encode) && Api::JwtService.respond_to?(:decode)'` | `true` |
| HS256 pinning | `grep -n "ALGORITHM.*HS256\|algorithm.*ALGORITHM" jwt_service.rb` | Line 10 + 22 |
| verify_exp | `grep "verify_exp.*true" jwt_service.rb` | Line 22 |
| Secret source | `grep "credentials.jwt_secret\|ENV.*JWT_SECRET" jwt_service.rb` | Both present |
| TokenExpired/TokenInvalid | `grep "TokenExpired\|TokenInvalid" jwt_service.rb` | 4 occurrences |
| ActionController::API | `grep "ActionController::API" base_controller.rb` | Present |
| rescue_from count | `grep -c "rescue_from" base_controller.rb` | 3 |
| Admin session route | `bin/rails routes --grep /api/v1` | `POST /api/v1/admin/session(.:format) api/v1/admin/sessions#create` |
| Client session route | `bin/rails routes --grep /api/v1` | `POST /api/v1/client/session(.:format) api/v1/client/sessions#create` |

**Test suite substitution:** `bin/rails test` cannot run (test DB owned by different OS user). Verified via `bin/rails runner` (boot check + JwtService respond_to?), source assertions (grep), and `bin/rails routes --grep` as specified in the environment constraints.

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 | eb4383d | feat(21-02): create Api::JwtService PORO with HS256-pinned encode/decode and domain errors |
| Task 2 | 4471d97 | feat(21-02): add Api::V1::BaseController and /api/v1/ route namespaces |

## Deviations from Plan

None — plan executed exactly as written.

The plan's done criteria for Task 1 stated `grep -n "ALGORITHM.*HS256\|verify_exp.*true\|algorithm.*ALGORITHM"` should "retorna 3 matches". The grep returns 2 line matches because `verify_exp: true` and `algorithm: ALGORITHM` share line 22. All three security properties are present in the file (ALGORITHM constant line 10, and both `algorithm: ALGORITHM` + `verify_exp: true` on line 22 of the JWT.decode call). No security gap.

## Threat Surface Scan

All mitigations from the plan's threat register were applied:

| Threat ID | Mitigation | Verified |
|-----------|-----------|---------|
| T-21-04 | `ALGORITHM = "HS256".freeze` + `algorithm: ALGORITHM` in JWT.decode | grep confirmed |
| T-21-05 | `verify_exp: true` explicit in JWT.decode options | grep confirmed |
| T-21-06 | `secret` reads credentials/ENV, marked `private_class_method` | code review confirmed |
| T-21-07 | `Api::V1::BaseController < ActionController::API` — not ApplicationController | grep confirmed |
| T-21-08 | `rescue_from` covers RecordNotFound/RecordInvalid/ParameterMissing | count = 3 confirmed |

No new security-relevant surface beyond what was planned.

## Known Stubs

None — this plan creates infrastructure contracts (service PORO, base controller, routes). No UI, no data rendering, no hardcoded placeholder values.

## Self-Check: PASSED

- app/services/api/jwt_service.rb: FOUND
- app/controllers/api/v1/base_controller.rb: FOUND
- config/routes.rb: modified (namespace :api present)
- Commit eb4383d: FOUND (feat(21-02): create Api::JwtService PORO...)
- Commit 4471d97: FOUND (feat(21-02): add Api::V1::BaseController...)
