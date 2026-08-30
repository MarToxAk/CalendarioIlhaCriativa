---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
reviewed: 2026-08-30T02:30:14Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - .env.example
  - Gemfile
  - Procfile.dev
  - README.md
  - app/services/evolution.rb
  - app/services/evolution/client.rb
  - app/services/evolution/errors.rb
  - bin/setup
  - config/environments/development.rb
  - config/environments/production.rb
  - config/initializers/evolution.rb
  - config/initializers/filter_parameter_logging.rb
  - config/initializers/timezone_check.rb
  - config/storage.yml
  - deploy/Caddyfile
  - docker-compose.yml
  - lib/tasks/storage_migration.rake
  - test/services/evolution/client_test.rb
findings:
  critical: 2
  warning: 7
  info: 8
  total: 17
status: issues_found
---

# Phase 25: Code Review Report

**Reviewed:** 2026-08-30T02:30:14Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

Phase 25 adds the Evolution HTTP transport seam, S3/MinIO ActiveStorage, a docker-compose
production topology, and a blob-migration rake task. The Evolution client's error taxonomy,
timeout classification, and safe-logging design are sound and well tested at the unit level,
and the storage rake task is genuinely copy-only and idempotent.

However, the review found two ship-blocking problems in the deploy topology and several
correctness/robustness defects:

- **Two boot-time `raise`s were added on the production asset-precompile path.** The
  `timezone_check.rb` initializer and the `evolution.rb` `after_initialize` both abort when
  run under `RAILS_ENV=production` without `TZ` / master key — exactly the conditions inside
  the Dockerfile's `assets:precompile` build step. `docker compose build` (the delivered
  deploy path) cannot produce an image.
- **The compose services never receive `CORS_ORIGINS`** (nor Evolution/S3 secrets), and
  `config/application.rb` does `ENV.fetch("CORS_ORIGINS")` with no fallback in production.
  `web`/`jobs` KeyError-crash-loop at boot; `.env.example` does not mention the variable.
- The intended "fast" 15s read timeout for cheap Evolution endpoints has **no effect** —
  Faraday resolves the inherited 30s `read_timeout` first, so `READ_TIMEOUT_FAST` is dead.
- The compose `web` service publishes the app on a host port in cleartext, bypassing Caddy.
- Several empty-string / ordering footguns in `.env.example` consumers and `bin/setup`.

No structural pre-pass (`<structural_findings>`) was supplied, so all findings below are
narrative.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Production-env boot raises abort `assets:precompile` — Docker image cannot build

**File:** `config/initializers/timezone_check.rb:20-30`, `config/initializers/evolution.rb:9-17`
**Issue:**
`Dockerfile` runs `RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` in a stage with
`ENV RAILS_ENV="production"`. Propshaft's `assets:precompile` task is `task precompile: :environment`,
so it executes `Rails.application.initialize!` — every initializer plus all `after_initialize`
hooks run during the build.

- `timezone_check.rb` is unguarded top-level code. In the build stage `ENV["TZ"]` is unset
  (the `ruby:3.3.3-slim` base does not set it), so `ok` is false and, because
  `Rails.env.production?` is true, it calls `raise(message)`. The build fails here.
- Even with `TZ` fixed, `evolution.rb`'s `after_initialize` does `next unless Rails.env.production?`
  (does *not* skip in the build), then calls `Evolution.global_api_key`. `EVOLUTION_GLOBAL_API_KEY`
  is not in the build env, and `config/master.key` is excluded by `.dockerignore:14`, so
  `Rails.application.credentials.dig(:evolution, :global_api_key)` returns `nil` →
  `value.blank?` → `raise Evolution::Errors::ConfigurationError`.

`docker-compose.yml` uses `build: .`, so the entire phase-25 deploy topology is unbuildable
as delivered.

**Fix:** Skip runtime validation during asset precompilation (Rails sets
`ENV["SECRET_KEY_BASE_DUMMY"]` for exactly this purpose), and make the timezone check
non-fatal when secrets/boot context are absent:

```ruby
# config/initializers/timezone_check.rb
return if ENV["SECRET_KEY_BASE_DUMMY"] # asset precompile / build stage — no real boot

# config/initializers/evolution.rb
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  next if ENV["SECRET_KEY_BASE_DUMMY"]

  Evolution.global_api_key
  # ...
end
```

Alternatively pass `RAILS_MASTER_KEY` + `TZ` as build args/secrets in the Dockerfile, but the
`SECRET_KEY_BASE_DUMMY` guard is the standard Rails idiom and keeps the build secret-free.

### CR-02: `web` / `jobs` containers crash-loop at boot — `CORS_ORIGINS` never provided

**File:** `docker-compose.yml:24-35`, `docker-compose.yml:51-61`, `.env.example` (whole file)
**Issue:**
`config/application.rb` evaluates, in the application class body (runs on every boot):

```ruby
allowed_origins = Rails.env.production? ? ENV.fetch("CORS_ORIGINS") : ENV.fetch("CORS_ORIGINS", "http://localhost:3000")
```

In production `ENV.fetch("CORS_ORIGINS")` has no default and raises `KeyError` when unset. The
new `web` and `jobs` services set `RAILS_ENV: production` but never pass `CORS_ORIGINS`, and
`.env.example` — the documented operator contract for this topology — does not list it. Running
`docker compose up` with an `.env` built from `.env.example` gives `web` and `jobs` a
`KeyError: key not found: "CORS_ORIGINS"` on boot; `restart: unless-stopped` then turns it
into a crash-loop. (The same omission also contributes to the CR-01 build failure, since the
class body runs during `assets:precompile` too.)

The Evolution and S3 secrets are intentionally credentials-only in production, but `CORS_ORIGINS`
has no credentials fallback anywhere.

**Fix:** Add `CORS_ORIGINS` to the `environment:` block of both `web` and `jobs` (via
`${CORS_ORIGINS}`), and add it to `.env.example` with the real public origin, e.g.:

```yaml
# docker-compose.yml (web and jobs)
CORS_ORIGINS: ${CORS_ORIGINS}
```
```sh
# .env.example
CORS_ORIGINS=https://ilhacriativa.autopyweb.com.br
```

## Warnings

### WR-01: `READ_TIMEOUT_FAST` (15s) is never applied — fast reads still use 30s

**File:** `app/services/evolution/client.rb:60-67`, `app/services/evolution.rb:38`
**Issue:**
`request` sets `req.options.timeout = read_timeout if read_timeout` for the "fast" endpoints
(`fetch_instances`, `connection_state`). The memoized connection already sets
`f.options.read_timeout = Evolution::READ_TIMEOUT` (30). Faraday's
`Adapter#request_timeout(:read, options)` returns `options[:read_timeout] || options[:timeout]`,
and `req.options` inherits `read_timeout = 30` from the connection. So the per-request
`timeout = 15` is shadowed and the fast endpoints actually wait up to 30s. The documented
requirement ("read 15s nas leituras rápidas") is not met, and phase-29 retry budgeting will be
based on a wrong assumption. No test exercises this wiring.

**Fix:** Set the specific key that Faraday checks first:

```ruby
req.options.read_timeout = read_timeout if read_timeout
```

### WR-02: `web` service publishes the app in cleartext on the host, bypassing Caddy

**File:** `docker-compose.yml:22-23`
**Issue:**
`ports: - "5881:3000"` binds Rails to `0.0.0.0:5881` on the host with no TLS. The intended
ingress is Caddy (`proxy`) terminating TLS and forwarding to `web:3000` on the internal
network. Because `production.rb` sets `config.assume_ssl = true`, Rails treats requests
arriving on `:5881` as already-secure and does not redirect, so session/auth traffic is
served over plain HTTP on that port to anything that can reach the host. `config.hosts` only
requires a matching `Host:` header, which an attacker sets trivially.

**Fix:** Use an internal-only expose, or bind to loopback for debugging:

```yaml
# option A — no host publish, Caddy reaches it on the compose network
expose:
  - "3000"
# option B — loopback only
ports:
  - "127.0.0.1:5881:3000"
```

### WR-03: `jobs` can crash-loop on first deploy — races `web`'s `db:prepare`

**File:** `docker-compose.yml:45-64`
**Issue:**
`jobs` and `web` both `depends_on: db: condition: service_healthy` and start concurrently.
`web`'s entrypoint runs `./bin/rails db:prepare` (migrations). `jobs` runs `./bin/jobs`, which
boots the SolidQueue supervisor and immediately queries `solid_queue_*`. On a fresh database
those tables do not exist until `web` finishes migrating, so `jobs` raises
`ActiveRecord::StatementInvalid`, exits, and `restart: unless-stopped` loops it until `web`
converges. Noisy, and on a deploy that ships a `solid_queue` schema change the worker can boot
against a stale schema.

**Fix:** Gate `jobs` on migrations completing — e.g. a one-shot `migrate` service that runs
`bin/rails db:prepare` and which both `web` and `jobs` `depends_on: condition: service_completed_successfully`,
or give `web` a healthcheck and have `jobs` `depends_on: web: condition: service_healthy`.

### WR-04: Empty `S3_ENDPOINT` defeats the credentials fallback in `storage.yml`

**File:** `config/storage.yml:17`, `.env.example` (`S3_ENDPOINT=`)
**Issue:**
`endpoint: <%= ENV.fetch("S3_ENDPOINT") { Rails.application.credentials.dig(:aws, :endpoint) } %>`.
`.env.example` ships `S3_ENDPOINT=` (empty). If an operator/dev copies it verbatim, `dotenv`
loads `S3_ENDPOINT` as `""` — a present value — so `ENV.fetch` returns `""` and the block
never runs. `endpoint: ""` is then handed to `aws-sdk-s3`, which either errors obscurely or
silently targets real AWS. Since both `development.rb` and `production.rb` now set
`config.active_storage.service = :amazon`, the first upload fails in a confusing way.

**Fix:**

```erb
endpoint: <%= ENV["S3_ENDPOINT"].presence || Rails.application.credentials.dig(:aws, :endpoint) %>
```

### WR-05: Blank Evolution timeout env var crashes boot

**File:** `app/services/evolution.rb:35-37`
**Issue:**
`OPEN_TIMEOUT = Integer(ENV.fetch("EVOLUTION_OPEN_TIMEOUT", "5"))` (and the WRITE/READ
siblings). The `.env.example` ships these populated, but if an operator blanks one
(`EVOLUTION_OPEN_TIMEOUT=`), `ENV.fetch` returns `""`, `Integer("")` raises
`ArgumentError: invalid value for Integer(): ""`, and the app fails to load with a stack
trace far from the cause. The `base_url` / `global_api_key` readers guard against this with
`.blank?`; the constants do not.

**Fix:**

```ruby
OPEN_TIMEOUT = Integer(ENV["EVOLUTION_OPEN_TIMEOUT"].presence || "5")
```

### WR-06: `bin/setup --reset` drops the queue schema it just loaded

**File:** `bin/setup:26-41`
**Issue:**
The new "Carregando o schema da fila" block was inserted immediately before the pre-existing
`system! "bin/rails db:reset" if ARGV.include?("--reset")` line. On `bin/setup --reset`,
the queue tables are loaded, then `db:reset` runs `db:drop` + `db:setup` which reloads only
`db/schema.rb` (the `solid_queue_*` tables live in `db/queue_schema.rb`, not `schema.rb`).
Result: after `bin/setup --reset` the dev database has no queue tables and the `jobs` process
from `Procfile.dev` crash-loops.

**Fix:** Move the queue-schema load to *after* the `--reset` line, so it runs against the
final database state.

### WR-07: Raw `TypeError` can escape `connection_state` on a non-JSON 2xx

**File:** `app/services/evolution/client.rb:44-48`
**Issue:**
`connection_state` does `resp.body.dig("instance", "state")`. The class invariant is "nenhuma
Faraday::Error nem status HTTP cru escapa — tudo vira Evolution::Errors::*". If the host
returns a 2xx with a non-JSON body (e.g. a Cloudflare interstitial with `Content-Type:
text/html`), the `:json` response middleware leaves `resp.body` a `String`, and
`String#dig` raises `TypeError: no implicit conversion of String into Integer`, which escapes
uncaught. `fetch_instances` has the same latent shape (`.body` returned as-is, callers expect
an Array).

**Fix:** Normalize/guard the body type before digging, e.g.
`resp.body.is_a?(Hash) ? resp.body.dig("instance", "state") : (raise Evolution::Errors::Unknown, "resposta 2xx não-JSON")`.

## Info

### IN-01: Misleading rationale in `filter_parameter_logging.rb`

**File:** `config/initializers/filter_parameter_logging.rb:7-12`
**Issue:** The comment justifies adding `:apikey`/`:hash` with "Evolution::Client (fase 25)
já loga requests, então esses precisam ser filtrados agora". `config.filter_parameters` only
scrubs Rails' controller *parameter* logging; it does not touch the hand-built
`Rails.logger.info("[evolution] ...")` line in `client.rb`, which is safe purely by
construction. The additions are still reasonable forward-looking hygiene (future webhook
params), but the stated cause is wrong and could mislead a later maintainer into assuming the
client log is filter-protected.

### IN-02: `:hash` partial match over-filters legit keys

**File:** `config/initializers/filter_parameter_logging.rb:15`
**Issue:** `:hash` partially matches any parameter name containing "hash" — e.g. `hashtag`,
plausible in a social-post/arte app — which will show as `[FILTERED]` in request logs, a
minor debuggability loss. Consider a more specific token (`:instance_hash`) when the
per-instance token key is finalized in phase 26.

### IN-03: `READ_TIMEOUT_FAST` hardcoded while siblings are env-configurable

**File:** `app/services/evolution.rb:35-38`
**Issue:** `OPEN/WRITE/READ_TIMEOUT` read from ENV with defaults; `READ_TIMEOUT_FAST = 15` is
a bare literal with no override hook. Inconsistent, and combined with WR-01 it is currently
inert. Make it `Integer(ENV["EVOLUTION_READ_TIMEOUT_FAST"].presence || "15")` once WR-01 is
fixed.

### IN-04: `client_test.rb` apikey-leak test cannot catch a real regression

**File:** `test/services/evolution/client_test.rb:113-131`
**Issue:** The test replaces `@connection` with `stubbed_connection`, which builds a Faraday
stack *without* the `f.headers["apikey"] = ...` line and without timeouts, then asserts
`refute_includes log, "apikey"`. Since the real connection's header injection is never
exercised, the test would not fail if `client.rb` started logging headers. It also leaves the
fast-timeout wiring (WR-01) and the real `connection` builder entirely untested. Consider
asserting against `Evolution::Client.connection` with a stubbed adapter injected, or add a
test that the request `apikey` header equals the passed key while the log line does not
contain it.

### IN-05: `db` container has no `TZ` pin

**File:** `docker-compose.yml:2-15`
**Issue:** `web` and `jobs` pin `TZ: America/Sao_Paulo` (required by `timezone_check.rb`),
but `db` runs on UTC. With `config.active_record.default_timezone = :local`, any DB-side
default (`CURRENT_TIMESTAMP`) or `now()` used in SQL runs in a different wall clock than the
app writes/reads. Migrating to `:utc` is explicitly out of scope, but pinning
`TZ: America/Sao_Paulo` on `db` too costs nothing and removes the divergence.

### IN-06: Migration backfills `service_name` for blobs missing at source

**File:** `lib/tasks/storage_migration.rake:33-56`
**Issue:** Blobs that are `MISSING at source` are counted and skipped, but the unconditional
`update_all(service_name: "amazon")` at the end still flips them to `amazon`. User-visible
behavior does not regress (the file was already gone), but it removes the "restore the Disk
file from backup and it just works again" recovery path — after backfill the app only looks
at the empty S3 key. Consider excluding keys recorded as `missing` from the backfill scope.

### IN-07: `web` has no Docker healthcheck though `proxy` depends on it

**File:** `docker-compose.yml:17-38`, `docker-compose.yml:75-86`
**Issue:** `proxy` uses `depends_on: - web` (start-order only, no condition) and `web` has no
`healthcheck`. Caddy comes up and returns 502s until Rails finishes booting + migrating.
Add a healthcheck hitting `/up` (already excluded from SSL redirect and host auth) and switch
`proxy` to `condition: service_healthy`. This also enables the WR-03 fix.

### IN-08: Memoized connection caches the global apikey for the process lifetime

**File:** `app/services/evolution/client.rb:23-33`
**Issue:** `@connection ||= Faraday.new { ... f.headers["apikey"] = Evolution.global_api_key ... }`
captures the global key at first use; rotating the credential requires a process restart.
Per-request `req.headers["apikey"] = api_key` mitigates when an explicit key is passed, but
the default path uses the cached one. Acceptable for now — worth a one-line comment so it is a
known constraint rather than a surprise during a key rotation.

---

_Reviewed: 2026-08-30T02:30:14Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
