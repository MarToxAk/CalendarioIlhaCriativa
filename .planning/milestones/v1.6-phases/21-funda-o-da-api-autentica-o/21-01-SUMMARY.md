---
phase: 21-funda-o-da-api-autentica-o
plan: "01"
subsystem: api-foundation
tags: [gems, cors, rack-attack, jwt, rack-cors]
dependency_graph:
  requires: []
  provides: [jwt-gem, rack-cors-gem, cors-middleware, api-throttles, json-429-responder]
  affects: [config/application.rb, config/initializers/rack_attack.rb, Gemfile]
tech_stack:
  added: [jwt ~> 3.2, rack-cors ~> 3.0]
  patterns: [Rack::Cors insert_before 0, rack-attack conditional responder]
key_files:
  created: []
  modified:
    - Gemfile
    - Gemfile.lock
    - config/application.rb
    - config/initializers/rack_attack.rb
decisions:
  - "rack-cors configured in config/application.rb (not a separate initializer) with insert_before 0 per RESEARCH.md Pitfall 6"
  - "throttled_responder uses start_with?(\"/api/\") (not \"/api/v1/\") — covers all future API versions"
  - "CORS origins read from ENV.fetch(\"CORS_ORIGINS\", \"*\") — defaults to * for dev; restrict via env var in production"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 21 Plan 01: Gems + CORS + Throttles Summary

**One-liner:** jwt 3.2.0 and rack-cors 3.0.0 installed with CORS at position 0 in middleware stack and conditional JSON/HTML 429 responder for API paths.

## What Was Built

### Task 1: Gems Added (Gemfile + Gemfile.lock)

Added `gem "jwt", "~> 3.2"` and `gem "rack-cors", "~> 3.0"` to the Gemfile under a new `# JSON API authentication` comment block, positioned after `gem "rack-attack", "~> 6.8"`. Both gems installed and vendored to `vendor/bundle`:
- `jwt 3.2.0` — loadable via `require "jwt"`
- `rack-cors 3.0.0` — loadable via `require "rack/cors"`

### Task 2: CORS + rack_attack (config/application.rb + rack_attack.rb)

**config/application.rb:** Added `config.middleware.insert_before 0, Rack::Cors` block inside `class Application < Rails::Application`. CORS is now the first middleware in the Rack stack, ensuring OPTIONS preflight requests are handled before any authentication middleware. Origins configurable via `ENV.fetch("CORS_ORIGINS", "*")`.

**config/initializers/rack_attack.rb:**
- Added two new throttles: `api/admin_login_by_ip` (POST `/api/v1/admin/session`) and `api/client_login_by_ip` (POST `/api/v1/client/session`) — both 5 req/60s/IP, matching the existing `admin/login_by_ip` pattern.
- Replaced the `throttled_responder` lambda: now conditionally returns JSON `{ data, meta, errors }` for `/api/*` paths and the original HTML for web paths. The parameter was renamed from `|_request|` to `|request|` to allow path inspection.

## Verification

All plan checks passed:

| Check | Command | Result |
|-------|---------|--------|
| jwt in Gemfile | `grep '"jwt"' Gemfile` | Line 29: `gem "jwt", "~> 3.2"` |
| rack-cors in Gemfile | `grep '"rack-cors"' Gemfile` | Line 30: `gem "rack-cors", "~> 3.0"` |
| jwt version | `bundle list \| grep jwt` | `jwt (3.2.0)` |
| rack-cors version | `bundle list \| grep rack-cors` | `rack-cors (3.0.0)` |
| jwt loads | `bundle exec ruby -e 'require "jwt"; puts JWT.class'` | `Module` |
| rack-cors loads | `bundle exec ruby -e 'require "rack/cors"; puts Rack::Cors::VERSION'` | `3.0.0` |
| CORS in middleware | `bin/rails runner '...'` | `CORS present` |
| CORS insert_before | `grep "insert_before.*Rack::Cors" config/application.rb` | Line 30 |
| API throttles | `grep -c "api/admin_login_by_ip\|api/client_login_by_ip" rack_attack.rb` | `2` |
| JSON responder | `grep "start_with.*api" rack_attack.rb` | Line 31 |

**Test suite substitution:** `bin/rails test` cannot run (test DB owned by different OS user). Verified via bundle list, gem require, and `bin/rails runner` boot check instead.

## Commits

| Task | Hash | Message |
|------|------|---------|
| Task 1 | b22594f | chore(21-01): add jwt ~> 3.2 and rack-cors ~> 3.0 to Gemfile |
| Task 2 | e82ffdb | feat(21-01): configure CORS middleware and add API throttles to rack_attack |

## Deviations from Plan

None — plan executed exactly as written.

The plan specified `gem "rack-cors", "~> 3.0"` and the PATTERNS.md noted CORS goes in `config/application.rb` (not a separate `config/initializers/cors.rb`). Both were followed. The `throttled_responder` uses `start_with?("/api/")` (matches `/api/` prefix broadly) as specified in the plan and RESEARCH.md Pitfall 3.

## Threat Surface Scan

No new security-relevant surface introduced beyond what was planned. The CORS configuration uses `origins "*"` by default (dev only; production must set `CORS_ORIGINS`). This is intentional per RESEARCH.md Open Questions #1 and per plan design. No new network endpoints, auth paths, or schema changes were introduced in this plan.

## Known Stubs

None — this plan only adds gems and configuration; no UI or data rendering.

## Self-Check: PASSED

- SUMMARY.md: FOUND at .planning/phases/21-funda-o-da-api-autentica-o/21-01-SUMMARY.md
- Commit b22594f: FOUND (chore(21-01): add jwt ~> 3.2 and rack-cors ~> 3.0 to Gemfile)
- Commit e82ffdb: FOUND (feat(21-01): configure CORS middleware and add API throttles to rack_attack)
- Gemfile: contains jwt and rack-cors declarations
- config/application.rb: Rack::Cors insert_before 0 verified via rails runner
- config/initializers/rack_attack.rb: api throttles and JSON responder present
