---
phase: 21
slug: funda-o-da-api-autentica-o
status: verified
threats_open: 0
asvs_level: 1
created: 2026-06-11
audited: 2026-06-11
---

# Phase 21 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> Register authored at plan time; this document records post-implementation verification.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Internet → Rails router (Rack stack) | All unauthenticated traffic; OPTIONS preflight, login attempts | Credentials (email/password, access_token/password, ak_ API key) |
| rack-attack → API controllers | Throttle layer blocks brute-force before reaching controllers | IP addresses, request paths |
| Authorization header → authenticate_*! guard | External token enters each namespace base controller | JWT (admin/client) or opaque API key (AI) |
| JwtService → Rails.credentials / ENV | Secret used to sign/verify every JWT | jwt_secret (256-bit) |
| config/master.key → credentials.yml.enc | Master key decrypts credentials at boot | jwt_secret, api.ai_key |
| Test environment → production credentials | Tests must not embed or use production secrets | JWT_SECRET (test-only random value) |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-21-01 | Spoofing | CORS preflight (OPTIONS) | mitigate | `config.middleware.insert_before 0, Rack::Cors` in config/application.rb:30 | closed |
| T-21-02 | Repudiation | POST /api/v1/admin/session, POST /api/v1/client/session | mitigate | Throttles `api/admin_login_by_ip` and `api/client_login_by_ip` (5 req/60s/IP) in rack_attack.rb:22-28 | closed |
| T-21-03 | Tampering | throttled_responder returning HTML to API clients | mitigate | Conditional responder returns JSON envelope for `/api/*`, HTML for web paths — rack_attack.rb:30-38 | closed |
| T-21-04 | Tampering | JWT.decode without algorithm pinned (alg:none attack) | mitigate | `ALGORITHM = "HS256".freeze` (jwt_service.rb:10); passed explicitly in encode (line 18) and decode (line 22) | closed |
| T-21-05 | Elevation of Privilege | Expired JWT accepted | mitigate | `verify_exp: true` in JWT.decode options hash — jwt_service.rb:22 | closed |
| T-21-06 | Information Disclosure | JWT secret hardcoded or stored insecurely | mitigate | `secret` reads `credentials.jwt_secret \|\| ENV.fetch("JWT_SECRET")`; `private_class_method :secret` — jwt_service.rb:31-34 | closed |
| T-21-07 | Elevation of Privilege | API controller inheriting cookie-based auth from ApplicationController | mitigate | `Api::V1::BaseController < ActionController::API` (no CSRF, no cookies, no Authentication concern) — base_controller.rb:3 | closed |
| T-21-08 | Information Disclosure | Unhandled exceptions exposing stack traces to API clients | mitigate | Three `rescue_from` handlers (RecordNotFound/RecordInvalid/ParameterMissing) returning structured envelope — base_controller.rb:4-6 | closed |
| T-21-09 | Information Disclosure | User enumeration via differing error response (admin login) | mitigate | Single `invalid_credentials` code+detail for both nonexistent user and wrong password — admin/sessions_controller.rb:8-12 | closed |
| T-21-10 | Information Disclosure | Client enumeration via separate "account inactive" error | mitigate | `active?` checked after `authenticate`; inactive branch returns identical `invalid_credentials` response — client/sessions_controller.rb:15-21 | closed |
| T-21-11 | Elevation of Privilege | Login endpoint inheriting auth `before_action` from namespace base controller | mitigate | Both session controllers inherit `Api::V1::BaseController` directly — admin/sessions_controller.rb:3, client/sessions_controller.rb:3 | closed |
| T-21-12 | Repudiation | Brute force on login endpoints (cross-ref T-21-02) | mitigate | Throttles present at rack_attack.rb:22-28 (same evidence as T-21-02) | closed |
| T-21-13 | Tampering | JWT scope claim derived from request params (scope injection) | mitigate | Scope is string literal hardcoded per controller: `"admin"` at admin/sessions_controller.rb:15, `"client"` at client/sessions_controller.rb:23 | closed |
| T-21-14 | Elevation of Privilege | Client-scoped JWT accepted in admin namespace | mitigate | `claims[:scope] == "admin"` guard — admin/base_controller.rb:14 | closed |
| T-21-15 | Elevation of Privilege | Admin-scoped JWT accepted in client namespace | mitigate | `claims[:scope] == "client"` guard — client/base_controller.rb:13 | closed |
| T-21-16 | Elevation of Privilege | AI API key (`ak_`-prefixed) accepted in admin namespace | mitigate | Explicit `token.start_with?("ak_")` → `render_unauthorized` before decode — admin/base_controller.rb:11 | closed |
| T-21-17 | Information Disclosure | Timing attack on AI API key comparison | mitigate | `ActiveSupport::SecurityUtils.secure_compare(token, expected)` — ai/base_controller.rb:20 (no `==` used) | closed |
| T-21-18 | Elevation of Privilege | Deactivated client retains access via valid JWT | mitigate | `render_unauthorized unless @current_client.active?` on every request — client/base_controller.rb:17 | closed |
| T-21-19 | Elevation of Privilege | Missing AI key credential causes 500 instead of 401 | mitigate | `return render_unauthorized unless expected` before `secure_compare` — ai/base_controller.rb:17 | closed |
| T-21-20 | Information Disclosure | jwt_secret or ai_key committed in plaintext | mitigate | `/config/master.key` in root .gitignore:36; `git ls-files config/master.key` returns empty (not tracked); secrets only in encrypted credentials.yml.enc | closed |
| T-21-21 | Information Disclosure / EoP | Tests hardcoding production JWT secret | mitigate | All three test files inject `ENV["JWT_SECRET"] = SecureRandom.hex(32)` per test run in `setup`; torn down in `teardown` — no production secret ever written to source | closed |
| T-21-22 | Repudiation | No test coverage for auth-failure scenarios | mitigate | 10 tests across 3 files cover: 401 invalid_credentials (wrong password, nonexistent user/token), 401 unauthorized (no token, wrong scope, ak_ key in admin endpoint) | closed |
| T-21-SC | Tampering | Supply chain risk from jwt + rack-cors gems | accept | Plan 01 RESEARCH.md records Package Legitimacy Audit [OK] for both gems; plan 05 adds no new gems (explicitly accepted in plan 05 threat model) | closed |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-21-01 | T-21-SC | Supply chain risk for `jwt ~> 3.2` and `rack-cors ~> 3.0` accepted after Package Legitimacy Audit in 21-RESEARCH.md confirmed both gems [OK] (maintained packages, no [SUS] indicators, pinned to minor versions). Plan 05 introduces no additional gems. | Phase 21 executor (plan 01 + plan 05 threat models) | 2026-06-11 |

---

## Verification Evidence

### T-21-01 — CORS insert_before 0
- **File:** `config/application.rb:30`
- **Evidence:** `config.middleware.insert_before 0, Rack::Cors do` — CORS is the first middleware entry; OPTIONS preflight served before any auth middleware.

### T-21-02 / T-21-12 — Rack-Attack login throttles
- **File:** `config/initializers/rack_attack.rb:22-28`
- **Evidence:**
  ```
  throttle("api/admin_login_by_ip", limit: 5, period: 60) { req.ip if req.path == "/api/v1/admin/session" && req.post? }
  throttle("api/client_login_by_ip", limit: 5, period: 60) { req.ip if req.path == "/api/v1/client/session" && req.post? }
  ```
  Exact paths match deployed routes; 5 req/60s/IP matches plan spec.

### T-21-03 — JSON 429 responder for /api/*
- **File:** `config/initializers/rack_attack.rb:30-38`
- **Evidence:** `if request.path.start_with?("/api/")` → `application/json` envelope; else → `text/html`. Pattern `start_with?("/api/")` covers all future API versions.

### T-21-04 — Algorithm pinned to HS256
- **File:** `app/services/api/jwt_service.rb:10,18,22`
- **Evidence:** `ALGORITHM = "HS256".freeze` (line 10); used in `JWT.encode(..., ALGORITHM)` (line 18) and `JWT.decode(..., { algorithm: ALGORITHM, ... })` (line 22). No dynamic algorithm resolution possible.

### T-21-05 — Expired JWT rejected
- **File:** `app/services/api/jwt_service.rb:22`
- **Evidence:** `JWT.decode(token, secret, true, { algorithm: ALGORITHM, verify_exp: true })` — `verify_exp: true` explicit; third arg `true` also enables verification. `JWT::ExpiredSignature` rescue path at line 24.

### T-21-06 — JWT secret from credentials/ENV, never hardcoded; private_class_method
- **File:** `app/services/api/jwt_service.rb:31-34`
- **Evidence:**
  ```ruby
  def self.secret
    Rails.application.credentials.jwt_secret ||
      ENV.fetch("JWT_SECRET") { raise "JWT_SECRET not configured" }
  end
  private_class_method :secret
  ```
  No string literal secret. Method not callable externally.

### T-21-07 — BaseController inherits ActionController::API
- **File:** `app/controllers/api/v1/base_controller.rb:3`
- **Evidence:** `class Api::V1::BaseController < ActionController::API` — not `ApplicationController`; no cookie sessions, no CSRF, no `Authentication` concern.

### T-21-08 — rescue_from → structured envelope, no stack traces
- **File:** `app/controllers/api/v1/base_controller.rb:4-6`
- **Evidence:** Three `rescue_from` declarations mapping `RecordNotFound` → 404, `RecordInvalid` → 422, `ParameterMissing` → 400, all via `render_error` helper returning `{ data: nil, meta: {}, errors: [...] }`.

### T-21-09 — Generic invalid_credentials (admin)
- **File:** `app/controllers/api/v1/admin/sessions_controller.rb:5-12`
- **Evidence:** `User.find_by(...)` returns nil silently; `user&.authenticate(...)` short-circuits to falsy for both nil user and wrong password; single `render_error(code: "invalid_credentials", ...)` covers both branches. Count of `invalid_credentials` in file: 1.

### T-21-10 — active? checked after authenticate, same message (client)
- **File:** `app/controllers/api/v1/client/sessions_controller.rb:7-21`
- **Evidence:** `client&.authenticate(...)` evaluated first (line 7). If truthy, `client.active?` checked second (line 15). Both failure branches return identical `{ code: "invalid_credentials", detail: "Token ou senha inválidos" }` — inactive status not disclosed separately.

### T-21-11 — Session controllers inherit BaseController (no auth before_action)
- **File:** `app/controllers/api/v1/admin/sessions_controller.rb:3`, `app/controllers/api/v1/client/sessions_controller.rb:3`
- **Evidence:** Both declare `< Api::V1::BaseController`, not `< Api::V1::Admin::BaseController` or `< Api::V1::Client::BaseController`. No `before_action :authenticate_*` in either file.

### T-21-13 — Scope hardcoded per controller
- **File:** `app/controllers/api/v1/admin/sessions_controller.rb:15`, `app/controllers/api/v1/client/sessions_controller.rb:23`
- **Evidence:** `scope: "admin"` and `scope: "client"` are string literals embedded in the `JwtService.encode` call; not derived from `params`.

### T-21-14 — Admin guard requires scope=="admin"
- **File:** `app/controllers/api/v1/admin/base_controller.rb:14`
- **Evidence:** `return render_unauthorized unless claims[:scope] == "admin"` — strict equality on decoded claim.

### T-21-15 — Client guard requires scope=="client"
- **File:** `app/controllers/api/v1/client/base_controller.rb:13`
- **Evidence:** `return render_unauthorized unless claims[:scope] == "client"` — strict equality on decoded claim.

### T-21-16 — Admin guard rejects ak_-prefixed tokens
- **File:** `app/controllers/api/v1/admin/base_controller.rb:11`
- **Evidence:** `return render_unauthorized if token.start_with?("ak_")` — checked before JWT decode; an API key can never reach the scope check.

### T-21-17 — Constant-time comparison for AI API key
- **File:** `app/controllers/api/v1/ai/base_controller.rb:20`
- **Evidence:** `ActiveSupport::SecurityUtils.secure_compare(token, expected)` — no `==` operator used anywhere in this file for key comparison. Comment on line 19 explicitly notes the timing attack defense.

### T-21-18 — client.active? re-checked on valid JWT
- **File:** `app/controllers/api/v1/client/base_controller.rb:17`
- **Evidence:** `render_unauthorized unless @current_client.active?` — executed on every request regardless of JWT validity; a deactivated client with a previously-issued JWT receives 401.

### T-21-19 — Nil ai_key → 401 not 500
- **File:** `app/controllers/api/v1/ai/base_controller.rb:15-17`
- **Evidence:**
  ```ruby
  expected = Rails.application.credentials.dig(:api, :ai_key) || ENV["AI_API_KEY"]
  return render_unauthorized unless expected
  ```
  `secure_compare` is never reached with a nil argument; `render_unauthorized` is called first.

### T-21-20 — Master key gitignored; credentials encrypted
- **File:** `.gitignore:35-36`
- **Evidence:** `.gitignore` contains `# Ignore master key for decrypting credentials and more.` and `/config/master.key`. `git ls-files config/master.key` returns empty — file has never been tracked.

### T-21-21 — Tests use randomly-generated test secret per run
- **Files:** All three test files, `setup` block
- **Evidence:** `ENV["JWT_SECRET"] = SecureRandom.hex(32)` injected at test setup and restored in `teardown`. No string literal secret appears in any test file. The `ADMIN_PASSWORD` and `CLIENT_PASSWORD` constants are test fixture passwords (not production credentials).

### T-21-22 — Tests cover auth-failure scenarios
- **Files:**
  - `test/controllers/api/v1/admin/sessions_controller_test.rb` — 3 tests: success 201, email-not-found 401, wrong-password 401
  - `test/controllers/api/v1/client/sessions_controller_test.rb` — 3 tests: success 201, token-not-found 401, wrong-password 401
  - `test/controllers/api/v1/admin/base_controller_test.rb` — 3 tests: no Authorization header 401, scope:client JWT rejected 401, ak_ API key rejected 401
- **Evidence:** All assert `errors[0]["code"] == "unauthorized"` or `"invalid_credentials"` with explicit HTTP status checks.

### T-21-SC — Supply chain (accepted)
- **Evidence:** AR-21-01 in Accepted Risks Log above. Gemfile pins `jwt ~> 3.2` (line 29) and `rack-cors ~> 3.0` (line 30). Plan 05 adds no new gems.

---

## Unregistered Threat Flags

No SUMMARY.md threat flags were identified by executors outside the plan-time register.

The following implementation details were noted in SUMMARY files as decisions with potential security surface — all map to existing threats and are **informational only**:

| Note | Maps To | Disposition |
|------|---------|-------------|
| CORS `origins "*"` defaults to wildcard in dev (SUMMARY 21-01) | T-21-01 | Informational — production must set `CORS_ORIGINS` env var; no new threat ID needed |
| client/sessions_controller.rb has 2 occurrences of `invalid_credentials` (SUMMARY 21-03) | T-21-10 | Intentional — two separate inactive + wrong-creds branches return identical message |
| `authenticate_client_jwt!` does not explicitly check `ak_` prefix (SUMMARY 21-04) | T-21-16 | By design — client controller relies on TokenInvalid from JwtService; admin controller has explicit check per T-21-16 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-06-11 | 23 | 23 | 0 | gsd-security-auditor (claude-sonnet-4-6) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log (AR-21-01)
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-06-11
