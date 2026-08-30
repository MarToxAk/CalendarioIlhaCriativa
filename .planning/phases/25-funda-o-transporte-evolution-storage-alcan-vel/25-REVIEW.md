---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
reviewed: 2026-08-30T13:05:00Z
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
  critical: 0
  warning: 4
  info: 7
  total: 11
status: issues_found
---

# Phase 25: Code Review Report (re-review after gap-closure 25-05)

**Reviewed:** 2026-08-30T13:05:00Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found (no ship-blockers; residual + newly-introduced hardening items)

## Summary

This is a re-review of phase 25 after gap-closure plan 25-05. All eight items 25-05 set out
to fix are **confirmed closed** (details below). No new BLOCKER was introduced; `docker
compose build` and `docker compose up` are now viable as delivered.

Confirmed closed:

| Prior ID | Fix landed | Verified against |
| --- | --- | --- |
| CR-01 (boot raises abort `assets:precompile`) | `return if ENV["SECRET_KEY_BASE_DUMMY"]` in `timezone_check.rb:19`; `next if ENV["SECRET_KEY_BASE_DUMMY"]` in `evolution.rb:14`; `Dockerfile:55` runs precompile with `SECRET_KEY_BASE_DUMMY=1` | commit `ee4670a` + Dockerfile |
| CR-02 (`CORS_ORIGINS` never provided) | `CORS_ORIGINS: ${CORS_ORIGINS}` on `web` (`docker-compose.yml:43`) and `jobs` (`:84`); `.env.example` ships `CORS_ORIGINS=https://ilhacriativa.autopyweb.com.br` | commit `ef8a499` |
| WR-01 (`READ_TIMEOUT_FAST` inert) | `req.options.read_timeout = read_timeout` (was `req.options.timeout`) at `client.rb:78` | commit `7ff384f` |
| WR-07 (raw `TypeError` on non-JSON 2xx) | `fetch_instances` guards `body.is_a?(Array)` (`client.rb:42`); `connection_state` guards `resp.body.is_a?(Hash)` (`:55`); both raise `Evolution::Errors::Unknown` with a static message | commit `4557abb`/`4ad2bd4` |
| WR-02 (`web` published in cleartext on `0.0.0.0`) | `ports: - "127.0.0.1:5881:3000"` (`docker-compose.yml:30`) | commit `0d398c7` |
| WR-03 / IN-07 (`jobs` races `db:prepare`; `proxy` 502s) | `web` healthcheck on `/up` (`docker-compose.yml:52-57`); `jobs` and `proxy` both `depends_on: web: condition: service_healthy` (`:73-74`, `:105-106`) | commit `dbbae5b` |
| WR-06 (`bin/setup --reset` drops queue schema) | queue-schema load moved *after* `db:reset` (`bin/setup:26` then `:33-45`) | commit `fc100ff` |
| IN-05 (`db` container has no `TZ`) | `TZ: America/Sao_Paulo` on `db` (`docker-compose.yml:11`) | commit `ce13a35` |

Remaining findings are the prior-review items 25-05 did **not** scope (WR-04, WR-05, IN-01–IN-04,
IN-06, IN-08 — still valid, re-stated here for the fixer) plus two issues newly introduced by
the 25-05 changes (WR-C healthcheck timing, WR-D untested error path) and one residual
trade-off from the CR-01 fix (IN-G).

**Environment limitation:** `.env.example` is unreadable via the review tools in this sandbox
(permission-denied) and `config/credentials.yml.enc` is encrypted. `.env.example` content was
recovered via `git show HEAD:.env.example` and is reflected above; `credentials.yml.enc` was
not inspected (only its git diff — a 1-line re-encryption — is visible).

No `<structural_findings>` block was supplied; all findings below are narrative.

## Narrative Findings (AI reviewer)

## Warnings

### WR-A: Empty `S3_ENDPOINT=` in `.env.example` defeats the credentials fallback in `storage.yml` (residual — prior WR-04, not scoped by 25-05)

**File:** `config/storage.yml:17`, `.env.example` (`S3_ENDPOINT=`)
**Issue:**
`endpoint: <%= ENV.fetch("S3_ENDPOINT") { Rails.application.credentials.dig(:aws, :endpoint) } %>`.
`.env.example` still ships `S3_ENDPOINT=` (empty). `dotenv-rails` loads it (dev/test groups),
and a present-but-empty value makes `ENV.fetch("S3_ENDPOINT")` return `""` — the block never
runs. `endpoint: ""` is then handed to `aws-sdk-s3`. Because both `development.rb:33` and
`production.rb:27` now set `config.active_storage.service = :amazon`, the first upload in a
fresh dev checkout (from an `.env` copied verbatim) fails obscurely or silently targets real
AWS. The Evolution readers avoid this by using `.blank?`; `storage.yml` does not.
**Fix:**
```erb
endpoint: <%= ENV["S3_ENDPOINT"].presence || Rails.application.credentials.dig(:aws, :endpoint) %>
```

### WR-B: Blank `EVOLUTION_*_TIMEOUT` env var crashes eager-load / production boot (residual — prior WR-05, not scoped by 25-05)

**File:** `app/services/evolution.rb:35-37`
**Issue:**
`OPEN_TIMEOUT = Integer(ENV.fetch("EVOLUTION_OPEN_TIMEOUT", "5"))` (and the WRITE/READ
siblings). `.env.example` now ships these populated, so a verbatim copy is safe — but an
operator who blanks one (`EVOLUTION_OPEN_TIMEOUT=`) gets `Integer("")` →
`ArgumentError: invalid value for Integer(): ""`. In production (`eager_load = true`) the
`Evolution` module is loaded at boot via the `evolution.rb` initializer's `after_initialize`
hook, so this aborts the boot with a stack trace far from the cause. The `base_url` /
`global_api_key` readers guard with `.blank?`; the constants do not.
**Fix:**
```ruby
OPEN_TIMEOUT = Integer(ENV["EVOLUTION_OPEN_TIMEOUT"].presence || "5")
```

### WR-C: `web` healthcheck `start_period: 40s` can be shorter than a cold first-deploy `db:prepare` — first `docker compose up` aborts `jobs` / `proxy` (new — introduced by the WR-03 fix)

**File:** `docker-compose.yml:52-57`, `:68-74`, `:101-106`
**Issue:**
On a fresh host, `web`'s entrypoint runs `./bin/rails db:prepare` before Puma starts —
`createdb` for the primary + `_cache` + `_queue` + `_cable` databases, loading three schema
files, then all migrations, then a production boot with `eager_load = true`. The healthcheck
allows `start_period: 40s` + `retries: 5 × interval: 10s` ≈ 90s before `web` is marked
`unhealthy`. If `db:prepare` + boot exceeds that window, `docker compose up` fails with
`dependency failed to start: container ... is unhealthy` and neither `jobs` nor `proxy`
(both `condition: service_healthy`) start. Docker does **not** restart a running-but-unhealthy
container, so recovery requires re-running `docker compose up` once `web` converges. For the
by-hand deploy path (25-03 Task 1) this is a confusing first-deploy papercut.
**Fix:** Raise the tolerance for the first boot, e.g.
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://localhost:3000/up || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 180s
```
or split migrations into a one-shot `migrate` service gated with
`condition: service_completed_successfully`.

### WR-D: WR-07 / WR-01 behavior changes shipped with zero automated coverage although the test file is DB-free (new — regression risk from the 25-05 fixes)

**File:** `test/services/evolution/client_test.rb` (unchanged by 25-05), `app/services/evolution/client.rb:42`, `:55`, `:78`
**Issue:**
`client_test.rb` uses `Faraday::Adapter::Test` — "in-process, sem rede e sem banco" — so the
project's "test DB belongs to another OS user" constraint does not block adding cases here.
Yet 25-05 changed observable behavior (a 2xx with a non-JSON body now raises
`Evolution::Errors::Unknown` from `fetch_instances` / `connection_state`; the fast-endpoint
timeout key changed from `timeout` to `read_timeout`) with no new test. A future refactor
that drops the `body.is_a?(Array)` / `body.is_a?(Hash)` guards, or reverts to
`req.options.timeout`, would pass the existing suite. The commits rely on ad-hoc
`bin/rails runner` checks that leave nothing in the repo.
**Fix:** Add unit cases:
```ruby
test "fetch_instances raises Unknown on a 2xx non-Array body" do
  Evolution::Client.instance_variable_set(:@connection,
    stubbed_connection(200, "<html>cf</html>", { "Content-Type" => "text/html" },
                       path: "/instance/fetchInstances"))
  assert_raises(Evolution::Errors::Unknown) { Evolution::Client.fetch_instances }
ensure
  Evolution::Client.instance_variable_set(:@connection, nil)
end

test "connection_state raises Unknown on a 2xx non-Hash body" do
  Evolution::Client.instance_variable_set(:@connection,
    stubbed_connection(200, "[]", path: "/instance/connectionState/x"))
  assert_raises(Evolution::Errors::Unknown) { Evolution::Client.connection_state("x") }
ensure
  Evolution::Client.instance_variable_set(:@connection, nil)
end
```
and assert `Evolution::Client.connection` (or a request built from it) carries
`options.read_timeout == 15` for the fast endpoints.

## Info

### IN-A: Misleading rationale in `filter_parameter_logging.rb` (residual — prior IN-01)

**File:** `config/initializers/filter_parameter_logging.rb:7-12`
**Issue:** The comment says `:apikey`/`:hash` are added because "Evolution::Client (fase 25) já
loga requests, então esses precisam ser filtrados agora". `config.filter_parameters` only
scrubs Rails' controller *parameter* logging; it does not touch the hand-built
`Rails.logger.info("[evolution] ...")` line in `client.rb`, which is safe purely by
construction (method/path/status/duration only). The additions are reasonable forward-looking
hygiene, but the stated cause is wrong and could mislead a later maintainer into thinking the
client log is filter-protected.
**Fix:** Reword to "forward-looking: future Evolution webhook/controller params" and drop the
"Evolution::Client já loga" clause.

### IN-B: `:hash` partial match over-filters legitimate keys (residual — prior IN-02)

**File:** `config/initializers/filter_parameter_logging.rb:15`
**Issue:** `:hash` partially matches any parameter name containing "hash" (e.g. `hashtag`,
plausible in an arte/social-post app), which then logs as `[FILTERED]` — a minor
debuggability loss.
**Fix:** Use a specific token (`:instance_hash`) once the per-instance token key is finalized
in phase 26.

### IN-C: `READ_TIMEOUT_FAST` hardcoded while its siblings are env-configurable (residual — prior IN-03; now actually applied after WR-01)

**File:** `app/services/evolution.rb:38`
**Issue:** `OPEN/WRITE/READ_TIMEOUT` read from ENV with defaults; `READ_TIMEOUT_FAST = 15` is a
bare literal with no override hook. Inconsistent.
**Fix:** `READ_TIMEOUT_FAST = Integer(ENV["EVOLUTION_READ_TIMEOUT_FAST"].presence || "15")`,
and add `EVOLUTION_READ_TIMEOUT_FAST=15` to `.env.example` next to the other three.

### IN-D: apikey-leak test cannot catch a real regression (residual — prior IN-04)

**File:** `test/services/evolution/client_test.rb:12-21`, `:113-131`
**Issue:** The leak test replaces `@connection` with `stubbed_connection`, which builds a
Faraday stack *without* the `f.headers["apikey"] = ...` line and without timeouts, then
asserts `refute_includes log, "apikey"`. The real connection's header injection is never
exercised, so the test would not fail if `client.rb` started logging headers.
**Fix:** Assert against a connection built like `Evolution::Client.connection` (stub only the
adapter) and check that the outgoing request carries the `apikey` header while the log line
does not.

### IN-E: Migration backfills `service_name` for blobs missing at source (residual — prior IN-06)

**File:** `lib/tasks/storage_migration.rake:33-56`
**Issue:** Blobs reported `MISSING at source` are counted and skipped, but the unconditional
`ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")`
still flips them to `amazon`. No user-visible regression (the file was already gone), but it
removes the "restore the Disk file from backup and it just works" recovery path — after
backfill the app only looks at the empty S3 key.
**Fix:** Collect the `missing` blob ids and exclude them from the backfill scope
(`.where.not(id: missing_ids)`).

### IN-F: Memoized connection captures the global apikey for the process lifetime (residual — prior IN-08)

**File:** `app/services/evolution/client.rb:23-33`
**Issue:** `@connection ||= Faraday.new { ... f.headers["apikey"] = Evolution.global_api_key ... }`
binds the global key at first use; rotating the credential needs a process restart. The
per-request `req.headers["apikey"] = api_key` mitigates only when an explicit key is passed;
the default path uses the cached one. Acceptable, but undocumented.
**Fix:** Add a one-line comment on `connection` noting the key is captured at memoization time
and rotation requires a restart.

### IN-G: `SECRET_KEY_BASE_DUMMY` guard also disables the INFRA-03 TZ assertion and the Evolution fail-fast for maintenance commands (new — residual trade-off of the CR-01 fix)

**File:** `config/initializers/timezone_check.rb:19`, `config/initializers/evolution.rb:14`
**Issue:** The guard keys on `ENV["SECRET_KEY_BASE_DUMMY"]`, which Rails also documents as the
way to run *any* command without the master key (e.g.
`SECRET_KEY_BASE_DUMMY=1 bin/rails db:migrate` inside the container during an incident). Run
that way, a production maintenance command silently skips both the timezone determinism check
and the Evolution base_url/apikey fail-fast — the exact guarantees INFRA-03 / EVO-02 boot
checks exist to provide. The bypass is now wider than just `assets:precompile`.
**Fix:** Accept and document it (the guard is the standard Rails idiom), or tighten the
condition to also require the build context, e.g.
`next if ENV["SECRET_KEY_BASE_DUMMY"] && !File.exist?(Rails.root.join("config/master.key")) && ENV["RAILS_MASTER_KEY"].blank?`.

---

_Reviewed: 2026-08-30T13:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
