# Phase 25: Fundação — Transporte Evolution + Storage Alcançável - Pattern Map

**Mapped:** 2026-08-29
**Files analyzed:** 16 (5 new code/task files, 1 new doc, 10 modified config/deploy files)
**Analogs found:** 12 / 16 (4 no-analog: rake task, timezone_check initializer, reverse-proxy config, evolution-contract doc has a style-analog)

Este é um phase de infra + deploy. Não cria models/controllers/views/migrations de domínio.
O único código Ruby novo de aplicação é `Evolution::Client` + `Evolution::Errors`. Tudo o mais é
configuração, um rake task e artefatos de deploy.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/services/evolution/client.rb` (new) | service (HTTP client PORO) | request-response | `app/services/api/jwt_service.rb` | role-match (PORO service; different transport) |
| `app/services/evolution/errors.rb` (new) | utility (error taxonomy) | — | `app/services/api/jwt_service.rb` lines 3-7 (`module Api::Errors`) | exact |
| `config/initializers/evolution.rb` (new) | config (secret resolution + constants + fail-fast) | — | `app/services/api/jwt_service.rb#secret` (30-34) + `config/application.rb` (30-34) | role-match |
| `config/initializers/timezone_check.rb` (new) | config (boot assertion) | — | `config/application.rb` (32-34) `ENV.fetch` + raise precedent | partial |
| `lib/tasks/storage_migration.rake` (new) | task (data migration) | batch / file-I/O | — (`lib/tasks/` has only `.keep`) | **no analog** |
| `config/storage.yml` (modify) | config | — | commented `amazon:` stanza in the same file (lines 9-15) | exact (in-file template) |
| `config/environments/development.rb` (modify) | config | — | `config/environments/production.rb` lines 25, 53-54 | exact |
| `config/environments/production.rb` (modify) | config | — | self — uncomment Rails-generated lines 28, 31, 83-86 | exact (in-file template) |
| `Gemfile` (modify) | config | — | existing gem lines / RESEARCH.md install block | exact |
| `Procfile.dev` (modify) | config | — | existing `web:` / `css:` lines + `bin/jobs` | exact |
| `config/initializers/filter_parameter_logging.rb` (modify) | config | — | self (line 6-8 list) | exact |
| `docker-compose.yml` (modify) | deploy artifact | — | existing `web:` service (lines 17-35) in same file | exact (in-file template) |
| `Dockerfile` (modify, if needed) | deploy artifact | — | self (Rails 8 generated) | exact |
| reverse-proxy config (new — Caddy/nginx/Traefik) | deploy artifact | request-response (TLS termination) | — | **no analog** (nothing in repo; D-10 tool pending) |
| `.env.example` (modify) | config | — | existing keys (`CORS_ORIGINS`, `JWT_SECRET`) | role-match |
| `.planning/notes/evolution-contract.md` (already created in research) | doc | — | `.planning/notes/api-auth-strategy.md` | style-analog |

**D-10 deploy-tool caveat:** the repo carries BOTH a hand-rolled `docker-compose.yml` (`db` + `web`,
port `5881:3000`, Disk volume `storage:`) AND a Kamal skeleton (`config/deploy.yml` + `.kamal/secrets`,
Kamal 2.11.0, role `job:` commented, `SOLID_QUEUE_IN_PUMA: true`, `proxy.ssl` commented). CONTEXT.md
D-10 chose `docker compose` by interpretation and flags it as the **first planning question**.
- If `docker compose` confirmed → extend `docker-compose.yml` (add `jobs` + proxy), optionally delete `config/deploy.yml` + `.kamal/` as dead scaffolding.
- If Kamal → uncomment role `job:` (lines 11-14), `proxy:` block (lines 23-25), configure `registry`, set `SOLID_QUEUE_IN_PUMA`; `docker-compose.yml` becomes dev/accessory only.
Planner: pick the analog after the answer; both in-repo files are the templates.

---

## Pattern Assignments

### `app/services/evolution/errors.rb` (utility, error taxonomy)

**Analog:** `app/services/api/jwt_service.rb` lines 3-7

**Pattern to copy — nested `module Errors` with one-line `StandardError` subclasses:**
```ruby
# app/services/api/jwt_service.rb:3-7
module Api
  module Errors
    class TokenExpired < StandardError; end
    class TokenInvalid < StandardError; end
  end
```

**Apply as (shape from RESEARCH.md Pattern 3, EVO-03):**
```ruby
# app/services/evolution/errors.rb
module Evolution
  module Errors
    class ConfigurationError < StandardError; end  # base_url/apikey ausente — falha no boot
    class Transient    < StandardError; end  # timeout de conexão, 5xx, ECONNREFUSED → retry seguro (fase 29)
    class Permanent    < StandardError; end  # 401/403, 400/404/422 → retry não conserta
    class Unknown      < StandardError; end  # ReadTimeout / reset no meio → PODE ter enviado; nunca retry automático
    class NotConnected < StandardError; end  # connectionState != "open" → novo QR (fase 26)
  end
end
```
4 classes obrigatórias (Transient/Permanent/Unknown/NotConnected) + `ConfigurationError`.
Nenhuma `Faraday::Error` deve escapar do client — sempre traduzida para uma destas.

---

### `app/services/evolution/client.rb` (service, request-response)

**Analog:** `app/services/api/jwt_service.rb` (PORO, class methods, `# frozen_string_literal: true`, `module` namespace, `private_class_method`)

**Imports / file-header pattern** (`jwt_service.rb:1-9`):
```ruby
# frozen_string_literal: true

module Api
  class JwtService
    ALGORITHM = "HS256".freeze
```
→ new file: `# frozen_string_literal: true` + `module Evolution` + `class Client`. Constantes em SCREAMING_CASE
com `.freeze` para strings.

**Secret / config resolution pattern** (`jwt_service.rb:30-34` — the canonical precedent):
```ruby
def self.secret
  Rails.application.credentials.jwt_secret ||
    ENV.fetch("JWT_SECRET") { raise "JWT_SECRET not configured" }
end
private_class_method :secret
```
> Nota: `jwt_service.rb` faz `credentials || ENV.fetch`. RESEARCH.md Pattern 2 recomenda inverter para
> `ENV.fetch("X") { credentials.dig(...) }` para o Evolution (ENV-first, dev usa `.env`). Ambas as ordens
> existem como precedente do projeto; o planner escolhe uma e documenta. O invariante copiado é:
> **resolve de 2 fontes, `raise` com mensagem acionável se nenhuma.**

**Error-translation pattern** (`jwt_service.rb:21-28` — rescue lib exception, re-raise domain error):
```ruby
def self.decode(token)
  decoded = JWT.decode(token, secret, true, { algorithm: ALGORITHM, verify_exp: true })
  decoded.first.with_indifferent_access
rescue JWT::ExpiredSignature
  raise Api::Errors::TokenExpired
rescue JWT::DecodeError
  raise Api::Errors::TokenInvalid
end
```
→ no client: `rescue Faraday::TimeoutError` / `Faraday::ConnectionFailed` → `raise Evolution::Errors::Transient|Unknown`;
`raise_for_status!` mapeia `resp.status` → classe (ver RESEARCH.md Pattern 2, verificado empiricamente:
header `apikey` único esquema, envelope de erro `{status, error, response:{message: String|Array}}` — o
parser tem que aceitar String E Array).

**Core HTTP pattern** (no analog no repo — repo não tem outro client HTTP; seguir RESEARCH.md Pattern 2):
- `Faraday.new(url: Evolution.base_url)` memoizado em `@connection ||=`
- `f.request :json` / `f.response :json, content_type: /\bjson$/`
- `f.headers["apikey"] = ...` — **NUNCA** `Authorization: Bearer` (verificado → 401)
- `f.options.open_timeout = 5` / `write_timeout = 10` / `read_timeout = 30` (15 nas leituras); teto CF ~100 s
- log só `método / path / status / duração` — nunca headers, corpo cru, `apikey`, `hash`, QR base64

---

### `config/initializers/evolution.rb` (config)

**Analog:** `app/services/api/jwt_service.rb#secret` (resolution) + `config/application.rb:30-34` (env-fetch com raise em produção + comentário citando pesquisa)

**Comment-cites-research precedent** (`config/application.rb:28-34`):
```ruby
# CORS — insert before all other middleware so OPTIONS preflight
# is handled before any authentication middleware (RESEARCH.md Pitfall 6)
# Em produção, CORS_ORIGINS deve ser explicitamente provisionado; a ausência
# da variável levanta KeyError (falha visível) em vez de aceitar qualquer origin.
allowed_origins = Rails.env.production? \
  ? ENV.fetch("CORS_ORIGINS")
  : ENV.fetch("CORS_ORIGINS", "http://localhost:3000")
```
→ Copy the style: module-level `self.base_url` / `self.global_api_key` readers doing
`ENV.fetch(...) { credentials.dig(:evolution, ...) }`, fail-fast on boot, and a comment citing
`25-RESEARCH.md Pattern 2` / `evolution-contract.md`. Timeout constants via `Integer(ENV.fetch("EVOLUTION_*_TIMEOUT", "N"))`.

---

### `config/initializers/timezone_check.rb` (config, boot assertion)

**Analog:** partial — `config/application.rb:32-33` (branch on `Rails.env.production?`, `ENV.fetch` / raise).
No dedicated boot-check initializer exists in the repo.

**Pattern** (from RESEARCH.md Pattern 4, INFRA-03 — Claude's discretion resolved: **raise in production, warn in dev**):
```ruby
# config/initializers/timezone_check.rb
expected_tz   = "America/Sao_Paulo"
expected_zone = "Brasilia"   # config.time_zone em application.rb:24
unless ENV["TZ"] == expected_tz && Time.zone.name == expected_zone
  msg = "Timezone não determinístico: ENV['TZ']=#{ENV['TZ'].inspect} ... default_timezone=:local exige TZ fixo — ver INFRA-03."
  Rails.env.production? ? raise(msg) : Rails.logger.warn("[timezone_check] #{msg}")
end
```
`config.active_record.default_timezone = :local` (`config/application.rb:25`) permanece — NÃO migrar para `:utc`.

---

### `lib/tasks/storage_migration.rake` (task, batch / file-I/O)

**Analog:** NONE — `lib/tasks/` contém apenas `.keep`. `config.autoload_lib(ignore: %w[assets tasks])`
(`application.rb:17`) confirma que tasks não são autoloaded — arquivo `.rake` standalone.

**Pattern:** use RESEARCH.md Pattern 6 verbatim as the starting point:
- `namespace :storage do ... task migrate_to_s3: :environment do`
- `source = ActiveStorage::Blob.services.fetch(:local)` / `dest = ...fetch(:amazon)`
- `ActiveStorage::Blob.find_each` → skip se `dest.exist?(blob.key)`, warn se falta na origem, senão `dest.upload(blob.key, StringIO.new(source.download(blob.key)), checksum:, content_type:)`
- **também** `ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")` depois de copiar (Pitfall 6 — inspecionar a coluna antes, Open Question Q3)
- `Rails.logger.info`/`warn` por blob; idempotente e reexecutável (D-05)
- 13 blobs / 21 MB; rodada manualmente no deploy após `service = :amazon` ativo

---

### `config/storage.yml` (modify)

**Analog:** the commented `amazon:` stanza already in the file, lines 9-15:
```yaml
# amazon:
#   service: S3
#   access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
#   secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
#   region: us-east-1
#   bucket: your_own_bucket-<%= Rails.env %>
```
**Apply** (RESEARCH.md Pattern 5): uncomment + add `endpoint: <%= ENV.fetch("S3_ENDPOINT") { credentials.dig(:aws, :endpoint) } %>`,
`force_path_style: true`, `bucket: <%= "calendario-livia-#{Rails.env}" %>` (bucket per env, D-03).
Do NOT set `public: true`. Existing `test:` (Disk → `tmp/storage`) and `local:` (Disk → `storage`) stanzas stay
(needed as migration source).

---

### `config/environments/development.rb` (modify)

**Analog:** `config/environments/production.rb` lines 25, 53-54 (same settings, prod already has them):
```ruby
# production.rb:53-54
config.active_job.queue_adapter = :solid_queue
config.solid_queue.connects_to = { database: { writing: :queue } }   # production-only — NÃO copiar p/ dev
```
**Apply:**
- line ~32: `config.active_storage.service = :local` → `:amazon` (D-03)
- near line 32 add: `config.active_job.queue_adapter = :solid_queue` (INFRA-02) — **without** `connects_to` (dev tem base única; carregar `db/queue_schema.rb` na base primária de dev via `bin/rails runner "load Rails.root.join('db/queue_schema.rb')"`)

---

### `config/environments/production.rb` (modify)

**Analog:** self — uncomment Rails-generated commented lines:
- line 25: `config.active_storage.service = :local` → `:amazon` (INFRA-01)
- line 28: `# config.assume_ssl = true` → uncomment (D-09, reverse proxy TLS)
- line 31: `# config.force_ssl = true` → uncomment
- lines 83-86: `# config.hosts = [...]` → uncomment + set app hostname (anti DNS-rebinding, Security V14)
- line 34 `config.ssl_options` (health-check exclude) — consider uncommenting alongside `force_ssl`
`queue_adapter = :solid_queue` (53) already present — no change.

---

### `Gemfile` (modify)

**Analog:** existing gem lines / RESEARCH.md install block.
- ADD `gem "faraday", "~> 2.14"` (EVO-02)
- ADD `gem "aws-sdk-s3", "~> 1.229", require: false` (INFRA-01) — mirror `require: false` style already used by `kamal`
- REMOVE line 35 `gem "good_job", "~> 4.0"` (INFRA-05) — **isolated commit, early, before any job code**
- `bundle install`; then `grep -rn "good_job\|GoodJob" config/ db/ app/ lib/` must be empty; `bin/rails runner "puts ActiveJob::Base.queue_adapter_name"` → `solid_queue`

---

### `Procfile.dev` (modify)

**Analog:** the two existing lines:
```
web: bin/rails server -b 0.0.0.0 -p 8080
css: bin/rails tailwindcss:watch
```
**Apply:** add `jobs: bin/jobs` (INFRA-02). `bin/jobs` already exists (`SolidQueue::Cli.start(ARGV)`).

---

### `config/initializers/filter_parameter_logging.rb` (modify)

**Analog:** self — the list at lines 6-8:
```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
```
**Apply:** add `:apikey`, `:hash` (partial-match; `:_key` does NOT match `apikey`, `:token` does NOT match `hash`).
CONTEXT.md flags this as a phase-25 candidate (client already logs requests); full fix is INFRA-04 / fase 26.

---

### `docker-compose.yml` (modify — pending D-10)

**Analog:** the existing `web:` service in the same file, lines 17-35:
```yaml
  web:
    build: .
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "5881:3000"
    environment:
      RAILS_ENV: production
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      POSTGRES_HOST: db
      ...
    volumes:
      - storage:/rails/storage
    restart: unless-stopped
```
**Apply** (RESEARCH.md Pitfall 5):
- new `jobs:` service — `build: .`, `command: ./bin/jobs`, **same `environment:` block as `web` + `TZ: America/Sao_Paulo`**, `depends_on: db (service_healthy)`, `restart: unless-stopped`, `volumes: storage:/rails/storage`
- add `TZ: America/Sao_Paulo` to `web`'s `environment:` too (INFRA-03)
- reverse proxy service (Caddy/nginx/Traefik) terminating TLS for the app and the MinIO subdomain — no in-repo analog

---

### `Dockerfile` (modify only if needed)

**Analog:** self — Rails 8 generated multi-stage. Entrypoint `bin/docker-entrypoint` runs `db:prepare` only for `./bin/rails server`. `BUNDLE_WITHOUT="development"`, non-root `USER 1000:1000`, `COPY vendor/* ./vendor/`.
Likely no change needed — `jobs` service reuses the same image with an overridden `command`. Touch only if the
solid_queue worker needs a package not in the runtime stage (it should not).

---

### `.planning/notes/evolution-contract.md` (already created in research)

**Style analog:** `.planning/notes/api-auth-strategy.md` (design note outside the phase dir, serves a whole
milestone). Already written by the researcher (9.1 KB) with VERIFIED vs PENDENTE items → UAT fases 26/28.
No planner action beyond referencing it.

---

## Shared Patterns

### Secret / config resolution (2 sources + fail-fast)
**Source:** `app/services/api/jwt_service.rb:30-34`
```ruby
Rails.application.credentials.jwt_secret ||
  ENV.fetch("JWT_SECRET") { raise "JWT_SECRET not configured" }
```
**Apply to:** `config/initializers/evolution.rb` (base_url, global_api_key, timeouts), `config/storage.yml` (endpoint/keys via `credentials.dig(:aws, ...)`).
RESEARCH.md recommends ENV-first ordering for Evolution (`ENV.fetch { credentials.dig }`); dev uses `.env`, prod uses credentials. `dotenv-rails` is dev/test only (`Gemfile:55`) — never in production.

### Domain-error translation (never leak library exceptions)
**Source:** `app/services/api/jwt_service.rb:3-7` + `21-28`
**Apply to:** `app/services/evolution/errors.rb` (nested `module Errors`, one-line `StandardError` subclasses) and `app/services/evolution/client.rb` (`rescue Faraday::* => e; raise Evolution::Errors::*`). Callers switch on the error class, never on raw HTTP status.

### Comment cites research by name for non-obvious decisions
**Source:** `config/application.rb:29` (`# ... (RESEARCH.md Pitfall 6)`)
**Apply to:** `config/initializers/evolution.rb`, `config/initializers/timezone_check.rb`, `config/storage.yml`, `docker-compose.yml` — cite `25-RESEARCH.md Pattern N` / `evolution-contract.md` where the value/behavior comes from research.

### Production branch for required env vars
**Source:** `config/application.rb:32-34` — `Rails.env.production? ? ENV.fetch("X") : ENV.fetch("X", default)`
**Apply to:** `config/initializers/timezone_check.rb` (raise in prod / warn in dev), `config/initializers/evolution.rb` (fail-fast in prod).

### `frozen_string_literal` + `module` namespace + class methods PORO
**Source:** `app/services/api/jwt_service.rb:1-9`, services live in `app/services/<namespace>/`
**Apply to:** `app/services/evolution/client.rb`, `app/services/evolution/errors.rb`. Namespace decision: **`Evolution::`** (per CONTEXT.md `<canonical_refs>` and ROADMAP), leaving `Whatsapp::` free for fases 26-30 domain services.

---

## No Analog Found

| File | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| `lib/tasks/storage_migration.rake` | task | batch / file-I/O | `lib/tasks/` has only `.keep`; no rake task precedent in repo | Use `25-RESEARCH.md` Pattern 6 verbatim |
| reverse-proxy config (Caddy/nginx/Traefik) | deploy artifact | request-response (TLS) | No proxy config anywhere in repo; `config/deploy.yml` `proxy:` block is commented Kamal skeleton | Kamal `proxy.ssl` block (deploy.yml:23-25) if Kamal chosen; else a fresh Caddyfile per D-10 answer |
| HTTP client core (Faraday connection wiring) | service | request-response | Repo has zero HTTP clients — `jwt_service` is crypto-only, not transport | `25-RESEARCH.md` Pattern 2 (verified against live host) |
| `config/initializers/timezone_check.rb` | config (boot check) | — | No boot-assertion initializer exists | `25-RESEARCH.md` Pattern 4 |

---

## Metadata

**Analog search scope:** `app/services/`, `config/initializers/`, `config/environments/`, `config/`, `lib/tasks/`, `Gemfile`, `Procfile.dev`, `Dockerfile`, `docker-compose.yml`, `config/deploy.yml`, `.kamal/`, `.planning/notes/`
**Files scanned:** ~18
**Key finding:** only 1 PORO service exists in the codebase (`Api::JwtService`) — it is the single template for `Evolution::Client` structure, secret resolution, and error taxonomy. All transport specifics have no in-repo analog and come from `25-RESEARCH.md` (verified empirically against the live host 2026-08-29).
**Pattern extraction date:** 2026-08-29
```
