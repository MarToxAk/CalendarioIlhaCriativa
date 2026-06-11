---
phase: 21-funda-o-da-api-autentica-o
plan: "04"
subsystem: api-auth
tags: [jwt, api-key, base-controllers, authentication, secure-compare, scope-guard]
dependency_graph:
  requires: [21-02]
  provides: [Api::V1::Admin::BaseController, Api::V1::Client::BaseController, Api::V1::Ai::BaseController, authenticate_admin_jwt!, authenticate_client_jwt!, authenticate_ai_key!]
  affects:
    - app/controllers/api/v1/admin/base_controller.rb
    - app/controllers/api/v1/client/base_controller.rb
    - app/controllers/api/v1/ai/base_controller.rb
tech_stack:
  added: []
  patterns: [before_action JWT guard, scope claim verification, ak_ prefix discrimination, ActiveSupport::SecurityUtils.secure_compare, credentials/ENV fallback for secrets]
key_files:
  created:
    - app/controllers/api/v1/admin/base_controller.rb
    - app/controllers/api/v1/client/base_controller.rb
    - app/controllers/api/v1/ai/base_controller.rb
  modified: []
decisions:
  - "bearer_token and render_unauthorized duplicated in each namespace base controller — not extracted to concern — for per-consumer auditability per D-06"
  - "authenticate_admin_jwt! explicitly rejects ak_-prefixed tokens before attempting JWT decode to satisfy T-21-16 (prevents API key from masquerading as admin)"
  - "authenticate_client_jwt! does not explicitly reject ak_ prefix — any non-JWT token will raise TokenInvalid during decode, producing the same 401"
  - "authenticate_ai_key! returns 401 (not 500) when expected key is nil — credentials not configured treated as auth failure, not config error (T-21-19)"
  - "No DB lookup in Ai::BaseController — API key validated purely against credentials/ENV per D-08"
metrics:
  duration: "~10 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 0
---

# Phase 21 Plan 04: Fundação da API + Autenticação Summary

**One-liner:** Three per-consumer API base controllers with JWT scope guards for admin/client and constant-time ak_-prefixed API key guard for AI, all inheriting render_error from Api::V1::BaseController.

## What Was Built

### Task 1: Api::V1::Admin::BaseController and Api::V1::Client::BaseController

Created `app/controllers/api/v1/admin/base_controller.rb`:

- `Api::V1::Admin::BaseController < Api::V1::BaseController`
- `before_action :authenticate_admin_jwt!`
- Guard flow: extract Bearer token → reject if nil → reject if `start_with?("ak_")` (T-21-16, D-07) → `Api::JwtService.decode(token)` → verify `claims[:scope] == "admin"` → `User.find_by(id: claims[:sub])` → set `@current_user`
- Rescues `Api::Errors::TokenExpired` and `Api::Errors::TokenInvalid` → 401
- `render_unauthorized` calls `render_error(code: "unauthorized", detail: "Autenticação inválida ou expirada", status: :unauthorized)`

Created `app/controllers/api/v1/client/base_controller.rb`:

- `Api::V1::Client::BaseController < Api::V1::BaseController`
- `before_action :authenticate_client_jwt!`
- Guard flow: extract Bearer token → reject if nil → `Api::JwtService.decode(token)` → verify `claims[:scope] == "client"` → `Client.find_by(id: claims[:sub])` → set `@current_client` → verify `@current_client.active?` (T-21-18)
- Rescues `Api::Errors::TokenExpired` and `Api::Errors::TokenInvalid` → 401
- `render_unauthorized` calls `render_error(code: "unauthorized", detail: "Autenticação inválida ou expirada", status: :unauthorized)`

Both controllers duplicate `bearer_token` and `render_unauthorized` methods rather than sharing a concern — intentional for per-namespace auditability per D-06.

### Task 2: Api::V1::Ai::BaseController

Created `app/controllers/api/v1/ai/` directory and `app/controllers/api/v1/ai/base_controller.rb`:

- `Api::V1::Ai::BaseController < Api::V1::BaseController`
- `before_action :authenticate_ai_key!`
- Guard flow: extract Bearer token → reject unless `start_with?("ak_")` (D-07) → read `expected = Rails.application.credentials.dig(:api, :ai_key) || ENV["AI_API_KEY"]` → reject if nil (T-21-19) → `ActiveSupport::SecurityUtils.secure_compare(token, expected)` (T-21-17)
- No DB query — purely against credentials/ENV per D-08
- `render_unauthorized` calls `render_error(code: "unauthorized", detail: "API key inválida", status: :unauthorized)`

## Verification

| Check | Command | Result |
|-------|---------|--------|
| scope:admin guard | `grep "scope.*admin" admin/base_controller.rb` | PASS — line 14 |
| scope:client guard | `grep "scope.*client" client/base_controller.rb` | PASS — line 13 |
| secure_compare (not ==) | `grep "secure_compare" ai/base_controller.rb` | PASS — line 20 |
| ak_ rejection in admin | `grep "start_with.*ak_" admin/base_controller.rb` | PASS — line 12 |
| client.active? check | `grep "active?" client/base_controller.rb` | PASS — line 17 |
| credentials + ENV source | `grep "credentials.*ai_key\|ENV.*AI_API_KEY" ai/base_controller.rb` | PASS — lines 15-16 |
| No DB query in ai guard | `grep -c "find_by\|where\|query" ai/base_controller.rb` | 0 |
| Rails runner boot check | `bin/rails runner '...'` — all 3 classes load | PASS — all superclasses correct, before_actions registered |

**Test suite substitution:** `bin/rails test` cannot run (test DB owned by different OS user). Verified via source assertions (grep) and `bin/rails runner` confirming all three classes load with correct superclasses and `before_action` filters.

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 | 4a5442c | feat(21-04): create Admin and Client API base controllers with JWT guards |
| Task 2 | 62e00e8 | feat(21-04): create Api::V1::Ai::BaseController with ak_ prefix + secure_compare guard |

## Deviations from Plan

None — plan executed exactly as written.

The plan's Task 2 action note "Não rejeita prefixo `ak_` explicitamente" for the client controller was followed as specified — the client guard does not explicitly check for `ak_` because any non-JWT token (including API keys) will fail `JwtService.decode` and raise `TokenInvalid`, producing the same 401 outcome.

## Threat Surface Scan

All mitigations from the plan's threat register were applied:

| Threat ID | Category | Mitigation Applied | Verified |
|-----------|----------|--------------------|---------|
| T-21-14 | Elevation of Privilege | `authenticate_admin_jwt!` verifies `claims[:scope] == "admin"` — client-scoped JWT → 401 | grep confirmed |
| T-21-15 | Elevation of Privilege | `authenticate_client_jwt!` verifies `claims[:scope] == "client"` — admin-scoped JWT → 401 | grep confirmed |
| T-21-16 | Elevation of Privilege | `authenticate_admin_jwt!` explicitly rejects tokens starting with `ak_` before decode | grep confirmed |
| T-21-17 | Information Disclosure | `ActiveSupport::SecurityUtils.secure_compare(token, expected)` — no `==` for API key comparison | grep confirmed |
| T-21-18 | Elevation of Privilege | `authenticate_client_jwt!` checks `@current_client.active?` — inactive client with valid JWT → 401 | grep confirmed |
| T-21-19 | Elevation of Privilege | `expected` nil check before `secure_compare` — unconfigured credentials → 401, not 500 | code review confirmed |

No new security-relevant surface beyond what was planned.

## Known Stubs

None — all three controllers implement full guard logic. No placeholder values or hardcoded data.

## Self-Check: PASSED

- app/controllers/api/v1/admin/base_controller.rb: FOUND
- app/controllers/api/v1/client/base_controller.rb: FOUND
- app/controllers/api/v1/ai/base_controller.rb: FOUND
- Commit 4a5442c: FOUND (feat(21-04): create Admin and Client API base controllers...)
- Commit 62e00e8: FOUND (feat(21-04): create Api::V1::Ai::BaseController...)
