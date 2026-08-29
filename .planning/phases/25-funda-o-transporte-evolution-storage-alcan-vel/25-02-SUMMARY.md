---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
plan: 02
subsystem: infra
tags: [activestorage, aws-sdk-s3, minio, s3, solid_queue, active_job, procfile, timezone, boot-check, presigned-url]

# Dependency graph
requires:
  - phase: 25-funda-o-transporte-evolution-storage-alcan-vel
    provides: "25-01 — bundle com um único queue adapter (good_job removido, solid_queue é o adapter de produção); Gemfile é o único arquivo compartilhado entre os dois seams (por isso este plano é wave 2)"
provides:
  - "config/storage.yml — serviço `amazon` ativo: driver S3 contra o endpoint MinIO, force_path_style: true, bucket calendario-livia-<Rails.env>, privado (sem chave public)"
  - "config/environments/development.rb — config.active_storage.service = :amazon (o caminho presignado é exercitado localmente) + config.active_job.queue_adapter = :solid_queue (jobs agendados duráveis, não mais :async)"
  - "config/initializers/timezone_check.rb — asserção de TZ/Time.zone no boot: raise em produção, warn (log + $stderr) em development quando ENV['TZ'] != America/Sao_Paulo ou Time.zone != Brasilia"
  - "Procfile.dev — linha `jobs: bin/jobs` para bin/dev subir o worker solid_queue junto de web + css"
  - "bin/setup — passo guardado e idempotente que carrega db/queue_schema.rb na base única de development"
  - "README.md — seção 'Background jobs in development'"
  - "aws-sdk-s3 ~> 1.229 no bundle (require: false — ActiveStorage carrega sob demanda)"
affects: [25-03-deploy-topology, 25-04-reachable-media, 28-divulgacao-agendar, 29-motor-de-envio]

actuals:
  tokens: 5200
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: ["aws-sdk-s3 ~> 1.229 (require: false) + aws-sdk-core / aws-sigv4 / aws-partitions / jmespath"]
  patterns:
    - "ActiveStorage sobre S3-compatível via endpoint custom + force_path_style: true (MinIO não faz virtual-host-style buckets)"
    - "bucket por ambiente derivado de Rails.env (calendario-livia-#{Rails.env}) — nunca um bucket compartilhado dev/prod"
    - "segredos do object store resolvidos ENV-first para o endpoint (S3_ENDPOINT) e credentials-only para as chaves (aws.access_key_id / aws.secret_access_key / aws.region)"
    - "solid_queue como queue_adapter em development com as tabelas na base primária (dev tem base única; connects_to é production-only)"
    - "asserção de invariante de ambiente no boot via initializer: raise em produção / warn em dev (mesmo padrão do fail-fast de produção do 25-01)"

key-files:
  created:
    - "config/initializers/timezone_check.rb — asserção de TZ no boot (INFRA-03)"
  modified:
    - "Gemfile / Gemfile.lock — + aws-sdk-s3 ~> 1.229 (require: false)"
    - "config/storage.yml — stanza `amazon` descomentada e reescrita para MinIO (S3 driver, endpoint, force_path_style, bucket por env, privado)"
    - "config/environments/development.rb — active_storage.service = :amazon + active_job.queue_adapter = :solid_queue"
    - "Procfile.dev — + linha `jobs: bin/jobs`"
    - "bin/setup — + passo guardado de carga do db/queue_schema.rb após db:prepare"
    - "README.md — + seção 'Background jobs in development'"

key-decisions:
  - "storage.yml `amazon`: endpoint via ENV.fetch('S3_ENDPOINT') { credentials.dig(:aws,:endpoint) } (ENV-first, .env em dev); chaves só via credentials.dig(:aws,*); region default 'us-east-1'; bucket calendario-livia-#{Rails.env}; force_path_style: true; SEM chave public (bucket privado, toda URL de mídia é presigned)"
  - "development.rb NÃO recebe config.solid_queue.connects_to — dev tem base única; as tabelas solid_queue_* vivem em calendario_livia_development (só produção tem base :queue separada)"
  - "bin/setup tenta `bin/rails db:schema:load:queue` primeiro; se a task não existir, faz fallback para `bin/rails runner` que dá `load db/queue_schema.rb` só se solid_queue_jobs não existir (idempotente, no-op na segunda execução)"
  - "timezone_check.rb: raise em produção (TZ errado publica na hora errada de forma irreversível — falhar no boot é mais barato), warn em development (o dev pode legitimamente estar noutro fuso). Discrição de Claude resolvida no 25-RESEARCH.md Pattern 4 / 25-CONTEXT.md"
  - "timezone_check.rb no ramo de warn escreve em Rails.logger.warn E em $stderr (Kernel#warn) — em development o Rails.logger vai só para log/development.log quando rodado via bin/rails runner/console; o dev precisa ver o aviso no terminal (bin/dev / foreman). Ver Deviations (Rule 1)"
  - "config.active_record.default_timezone = :local MANTIDO — migrar para :utc é Out of Scope (REQUIREMENTS.md)"

patterns-established:
  - "ActiveStorage S3-compatível: endpoint custom + force_path_style + bucket por Rails.env, serviço privado, presigned por chamada (nunca public: true)"
  - "solid_queue em development sem connects_to — tabelas na base primária, carga guardada em bin/setup"
  - "invariante de ambiente verificada no boot por initializer (raise prod / warn dev), citando o requisito no texto da mensagem"

requirements-completed: [INFRA-02]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "aws-sdk-s3 no bundle + serviço `amazon` S3/MinIO em storage.yml (privado, force_path_style: true, bucket por env, endpoint de S3_ENDPOINT/credentials) + development usa :amazon (INFRA-01, metade config)"
    requirement: "INFRA-01"
    verification:
      - kind: integration
        ref: "ruby grep Gemfile: gem \"aws-sdk-s3\" presente; ERB render de storage.yml: sem public:true, com force_path_style; grep development.rb: active_storage.service = :amazon — todos PASS"
        status: pass
      - kind: e2e
        ref: "bin/rails runner — ActiveStorage::Blob.create_and_upload! + blob.url(expires_in:) + fetch presignado round-trip contra o MinIO dev — NÃO EXECUTADO: S3_ENDPOINT ausente, sem credenciais aws.*, MinIO não provisionado no host (Aws::Errors::MissingCredentialsError no probe)"
        status: unknown
    human_judgment: true
    rationale: "SC1 / INFRA-01 fecha só com um round-trip presignado real contra o MinIO dev; exige o user_setup (bucket calendario-livia-development privado + access key/secret + S3_ENDPOINT no .env / MinIO provisionado no host da agência) que não estava disponível na execução. Artefatos de config entregues e commitados (6ce3a06). Fechamento deferido — lacuna de user_setup, não falha de código. Consistente com EVO-01 no 25-01."
  - id: D2
    description: "Jobs agendados duráveis em development: queue_adapter = :solid_queue + schema de fila carregado na base dev + Procfile.dev roda `jobs` + bin/setup carrega o schema idempotentemente + README documenta (INFRA-02, SC4)"
    requirement: "INFRA-02"
    verification:
      - kind: integration
        ref: "grep development.rb: queue_adapter = :solid_queue (sem connects_to); grep -x Procfile.dev: 'jobs: bin/jobs'; grep bin/setup: queue_schema/db:schema:load:queue; bin/rails runner: table_exists?(:solid_queue_jobs) => true — todos PASS"
        status: pass
      - kind: integration
        ref: "bin/rails runner — enfileirar Phase25RestartProbeJob.set(wait: 90.seconds); SolidQueue::ScheduledExecution join solid_queue_jobs where class_name = 'Phase25RestartProbeJob' => count >= 1 (linha durável persistida) — PASS"
        status: pass
      - kind: manual_procedural
        ref: "Restart-survival gate (SC4): enfileirar job set(wait: 90.seconds), confirmar a linha em solid_queue_scheduled_executions, parar (kill -TERM) e reiniciar bin/jobs, aguardar além do horário agendado, confirmar tmp/phase25_job_marker.txt escrito APÓS o restart. Timeline observada reproduzida verbatim abaixo em 'Restart timeline'."
        status: pass
    human_judgment: true
    rationale: "SC4 exige observar um job atravessar um restart real do worker — não automatizável in-process. O gate foi executado pelo orquestrador com um probe job em disco contra um worker bin/jobs real; a timeline verbatim é o artefato exigido e está registrada nesta SUMMARY."
  - id: D3
    description: "config/initializers/timezone_check.rb — asserção de TZ/Time.zone no boot: raise em produção, warn (log + $stderr) em development; default_timezone permanece :local (INFRA-03, SC5)"
    requirement: "INFRA-03"
    verification:
      - kind: integration
        ref: "grep timezone_check.rb: 'America/Sao_Paulo' + 'Rails.env.production?'; grep application.rb: 'default_timezone = :local'; ruby regex: ramo raise(message) E ramo Rails.logger.warn presentes — todos PASS"
        status: pass
      - kind: integration
        ref: "TZ=America/Sao_Paulo bin/rails runner => 'boot OK with correct TZ: Brasilia' sem aviso; TZ=Etc/UTC bin/rails runner 2>&1 | grep -qi 'timezone_check' => aviso [timezone_check] emitido, boot não aborta — PASS"
        status: pass
      - kind: manual_procedural
        ref: "Ramo raise em produção verificado por inspeção do código (if Rails.env.production? then raise(message)); boot de produção completo não executável neste ambiente (application.rb:33 exige ENV['CORS_ORIGINS'] antes de o initializer rodar — fora de escopo). Consistente com a verificação de produção do 25-01."
        status: unknown
    human_judgment: false
    rationale: "Os 5 checks <automated> do plano passam; o ramo de produção é verificado por inspeção pois o boot de produção completo exige provisão de ambiente (CORS_ORIGINS, RAILS_MASTER_KEY) fora do escopo deste plano. A metade 'TZ fixado no deploy' de INFRA-03 é entregue no plano 25-03 (env TZ nos serviços web + jobs do docker-compose)."

# Metrics
duration: ~35min (inclui o gate humano SC4 executado pelo orquestrador)
completed: 2026-08-29
status: complete
---

# Phase 25 Plan 02: Fundação — Transporte Evolution + Storage Alcançável Summary

**Storage do ActiveStorage passa a S3-compatível (serviço `amazon`/MinIO privado, `force_path_style: true`, bucket por ambiente, presigned por chamada); jobs agendados em development ficam duráveis (`queue_adapter = :solid_queue` + schema de fila na base dev + `jobs: bin/jobs` no Procfile) — provado por um job que sobreviveu a um restart real do worker; e o relógio do app é assertado no boot (`timezone_check.rb`: raise em produção / warn em dev). O round-trip presignado real contra o MinIO (SC1 / INFRA-01) fica deferido — MinIO não provisionado no host.**

## Performance

- **Duration:** ~35 min (Tasks 1-2 code: 17:05–17:10; gate humano SC4 executado pelo orquestrador: 17:35–17:37; Task 3 + finalização: 17:38–17:40, horário local -03:00)
- **Tasks:** 3 (todas executadas)
- **Files modified:** 7 (1 criado, 6 modificados)
- **Commits:** 3 de tarefa + 1 de checkpoint pause + 1 de metadados (docs)

## Accomplishments

### Task 1 — aws-sdk-s3 + serviço MinIO + development em :amazon (commit `6ce3a06`)

- `gem "aws-sdk-s3", "~> 1.229", require: false` adicionado ao Gemfile (`require: false` — ActiveStorage carrega o SDK sob demanda); `bundle install` OK.
- `config/storage.yml`: a stanza `amazon:` comentada foi descomentada e reescrita para MinIO:
  - `service: S3`
  - `endpoint: <%= ENV.fetch("S3_ENDPOINT") { Rails.application.credentials.dig(:aws, :endpoint) } %>` (ENV-first, `.env` em dev)
  - `access_key_id` / `secret_access_key` só via `Rails.application.credentials.dig(:aws, ...)`
  - `region: <%= ... || "us-east-1" %>`
  - `bucket: <%= "calendario-livia-#{Rails.env}" %>` (bucket por ambiente — D-03)
  - `force_path_style: true` (MinIO não faz virtual-host-style buckets por padrão)
  - **sem chave `public`** — o bucket é privado, toda URL de mídia é presigned (D-02); um object store público exporia toda arte ainda não divulgada.
  - Stanzas `test:` e `local:` (Disk) intactas — `local:` é a fonte da migração do plano 04.
- `config/environments/development.rb`: `config.active_storage.service` de `:local` para `:amazon` (o caminho presignado é exercitado localmente — D-03). `ActiveStorage.service_urls_expire_in` NÃO tocado (o job de envio da fase 29 seta `expires_in:` por chamada).

### Task 2 — jobs agendados duráveis em development (commit `6fac8fd`)

- `config/environments/development.rb`: `config.active_job.queue_adapter = :solid_queue` adicionado junto da linha de active-storage (antes ausente → ActiveJob caía em `:async` e todo job agendado se perdia ao reiniciar `bin/dev`). **Sem** `config.solid_queue.connects_to` — dev tem base única.
- `bin/setup`: novo passo após `bin/rails db:prepare` — carrega o schema da fila na base primária de development, guardado e idempotente:
  - tenta `system("bin/rails", "db:schema:load:queue", ...)` primeiro;
  - fallback: `bin/rails runner` que dá `load Rails.root.join("db/queue_schema.rb")` **só se** `solid_queue_jobs` não existir;
  - imprime nota distinta quando carrega vs. quando pula.
- `Procfile.dev`: terceira linha `jobs: bin/jobs` → `bin/dev` (foreman) sobe o worker solid_queue junto de `web` e `css`.
- `README.md`: seção "Background jobs in development" — dev usa `solid_queue`; tabelas em `calendario_livia_development`; rodar `bin/setup` (ou o runner guardado) uma vez; `bin/dev` sobe o processo `jobs`.

### Task 3 — asserção de timezone no boot (commit `7f319a1`)

- `config/initializers/timezone_check.rb` criado. `expected_tz = "America/Sao_Paulo"`, `expected_zone = "Brasilia"` (bate com `config.time_zone` em `application.rb`). `ok = ENV["TZ"] == expected_tz && Time.zone.name == expected_zone`.
- Quando não `ok`: mensagem nomeando os dois valores observados, os dois esperados, e o motivo (`config.active_record.default_timezone = :local` exige um `TZ` fixo — INFRA-03). Então `Rails.env.production? ? raise(message) : (Rails.logger.warn + warn para $stderr)`.
- Comentário cita `25-RESEARCH.md Pattern 4`, `Pitfall 3` e INFRA-03. `config.active_record.default_timezone = :local` **não** foi tocado.

## Task 2 verification — SC4 restart-survival gate

O gate humano `<verify><human-check>` do Task 2 (SC4 / INFRA-02) foi executado pelo orquestrador com um probe job em disco (`Phase25RestartProbeJob`, já removido) contra um worker `bin/jobs` real. A timeline observada, artefato **exigido** do plano, é reproduzida verbatim abaixo.

### Restart timeline (artefato exigido — verbatim)

- Enqueue: 2026-08-29T17:35:34-03:00 — `Phase25RestartProbeJob.set(wait: 90.seconds).perform_later(marker, 'fired')`; durable row id=6 in `solid_queue_scheduled_executions`, scheduled fire 2026-08-29T17:37:03-03:00.
- Worker stopped (`kill -TERM` on `bin/jobs`): 2026-08-29T17:35:49-03:00.
- Outage window: 17:35:49 -> 17:36:43 (~54s) — ALL solid_queue processes down, `tmp/phase25_job_marker.txt` absent throughout, durable scheduled row survived in Postgres.
- Worker restarted (`bin/jobs`): 2026-08-29T17:36:43-03:00.
- Job fired: 2026-08-29T17:37:04-03:00 — marker written `fired 2026-08-29T17:37:04-03:00`, `solid_queue_jobs.finished_at = 17:37:04`, zero `solid_queue_failed_executions`, scheduled queue drained to 0.
- Conclusion: the scheduled job was enqueued before the outage and executed 21s AFTER the worker restart — proves `solid_queue` durability vs the old `:async` default (which loses in-memory scheduled jobs on restart). The throwaway probe job file, marker file, and worker logs were all removed; git working tree is clean.

**SC4 / INFRA-02: MET.** Um job agendado para alguns minutos à frente continua executando depois de reiniciar o processo de jobs de development — a linha de agendamento é durável em `solid_queue_scheduled_executions`, não some como no default `:async`.

## Task Commits

1. **Task 1: aws-sdk-s3 + MinIO storage service + development flips to :amazon** — `6ce3a06` (feat)
2. **Task 2: Durable scheduled jobs in development — queue adapter + schema load + Procfile** — `6fac8fd` (feat)
   - Checkpoint pause registrado em `9b0c258` (docs) — pausa no `<human-check>` do Task 2, agora satisfeito.
3. **Task 3: Deterministic timezone — boot check initializer** — `7f319a1` (feat)

**Plan metadata:** _(docs commit a seguir)_

## Files Created/Modified

- `config/initializers/timezone_check.rb` (novo) — asserção de `ENV["TZ"]` / `Time.zone.name` no boot; raise em produção, `Rails.logger.warn` + `$stderr` em development.
- `Gemfile` / `Gemfile.lock` — `+ aws-sdk-s3 ~> 1.229` (`require: false`; puxa `aws-sdk-core`, `aws-sigv4`, `aws-partitions`, `jmespath`).
- `config/storage.yml` — stanza `amazon` ativa: `service: S3`, `endpoint` de `S3_ENDPOINT`/credentials, `access_key_id`/`secret_access_key` de credentials, `region` com default, `bucket: calendario-livia-#{Rails.env}`, `force_path_style: true`, **sem `public`**. `test:` e `local:` (Disk) intactas.
- `config/environments/development.rb` — `config.active_storage.service = :amazon`; `config.active_job.queue_adapter = :solid_queue` (sem `connects_to`).
- `Procfile.dev` — `+ jobs: bin/jobs`.
- `bin/setup` — `+` passo guardado/idempotente de carga do `db/queue_schema.rb` após `db:prepare`.
- `README.md` — `+` seção "Background jobs in development".

## Decisions Made

- **`storage.yml` `amazon` — endpoint ENV-first, chaves credentials-only, `force_path_style: true`, bucket por env, sem `public`.** MinIO precisa de `endpoint` custom e path-style; o bucket por `Rails.env` evita colisão dev/prod; a ausência da chave `public` mantém o bucket privado e força presigned em toda URL de mídia (D-02).
- **`development.rb` sem `config.solid_queue.connects_to`.** Dev tem uma base única (`calendario_livia_development`, sem sub-chave `queue:` em `database.yml`); as tabelas `solid_queue_*` vivem nessa base primária. `connects_to` é production-only.
- **`bin/setup` tenta `db:schema:load:queue` e faz fallback para o runner guardado.** Idempotente: no-op se `solid_queue_jobs` já existe. Cobre ambientes onde a task Rails do schema de fila não está registrada.
- **`timezone_check.rb`: raise em produção / warn em dev.** Discrição de Claude resolvida no research (Pattern 4): em produção um `TZ` errado publica na hora errada de forma irreversível — falhar no boot é mais barato; em dev o desenvolvedor pode legitimamente estar noutro fuso e não deve ser bloqueado.
- **`default_timezone = :local` mantido.** Migrar para `:utc` é Out of Scope (REQUIREMENTS.md); INFRA-03 resolve o risco fixando `TZ` no container (plano 03) + a verificação no boot (aqui).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] O aviso de development do `timezone_check` não chegava ao terminal**
- **Found during:** Task 3, verificação `<automated>` #4 (`TZ=Etc/UTC bin/rails runner ... 2>&1 | grep -qi 'timezone_check'`).
- **Issue:** O plano manda usar `Rails.logger.warn("[timezone_check] #{message}")`. Em Rails 8.1.3, rodando via `bin/rails runner`/`console` em development, o `Rails.logger` escreve **só** em `log/development.log` — nada em stdout/stderr. A verificação #4 falhava e, mais importante, o `<done>` do Task 3 ("visível warning em development") ficava só parcialmente atendido: o aviso ficava enterrado num arquivo de log em vez de aparecer para o dev que roda `bin/dev`.
- **Fix:** No ramo `else` (não-produção), além de `Rails.logger.warn(...)`, emitir `warn("[timezone_check] #{message}")` (Kernel#warn → `$stderr`) com um comentário explicando o porquê. O ramo `Rails.logger.warn` permanece (o plano o exige e a verificação #5 checa `/logger\.warn/`).
- **Files modified:** `config/initializers/timezone_check.rb`
- **Verification:** `TZ=Etc/UTC bin/rails runner` → `[timezone_check] ...` em `$stderr` **e** em `log/development.log`; `TZ=America/Sao_Paulo bin/rails runner` → sem aviso, boot limpo; boot não aborta em nenhum dos casos de dev.
- **Committed in:** `7f319a1`

---

**Total deviations:** 1 auto-fixed (1 bug/Rule 1). Sem scope creep — o comportamento entregue é o do plano (`raise` prod / `warn` dev), só com o aviso de dev também no `$stderr` para ser de fato visível.

## Issues Encountered

- **`bin/rails test` não roda neste ambiente** — o banco de teste pertence a outro usuário do SO (constraint conhecida do projeto). Todas as verificações do plano são `bin/rails runner` / `grep` / `ruby -e` por inspeção, que rodam e passam. Registrado em cada entrada de `coverage.verification.ref`.
- **Boot de produção não executável aqui** — `config/application.rb:33` faz `ENV.fetch("CORS_ORIGINS")` (fail-fast de produção, pré-existente) antes de qualquer initializer rodar. O ramo `raise` de produção do `timezone_check.rb` foi verificado por inspeção do código, consistente com como o 25-01 verificou o fail-fast de produção do Evolution.
- **`timezone_check` agora avisa em todo `bin/rails runner`** neste ambiente, porque o shell não tem `TZ` setado (`ENV["TZ"]` = `nil`). É o comportamento pretendido (warn em dev) — não é um defeito. Some quando `TZ=America/Sao_Paulo` está no ambiente.

## Known Stubs

Nenhum stub de código. `config/storage.yml` `amazon` é uma configuração real e completa — o que falta é o **serviço externo** (MinIO provisionado + credenciais), não código. Ver "User Setup Required".

## Deferred / User Setup Required

### INFRA-01 / SC1 — round-trip presignado real contra o MinIO (DEFERIDO — user_setup)

O probe `<automated>` do Task 1 (`ActiveStorage::Blob.create_and_upload!` + `blob.url(expires_in:)` + fetch presignado round-trip) **não foi executado**: `S3_ENDPOINT` não está setado, não há credenciais `aws.*` em `config/credentials.yml.enc`, e o MinIO não está provisionado no host da agência. O probe dá `Aws::Errors::MissingCredentialsError`.

Os artefatos de **config** do Task 1 estão entregues e commitados (`6ce3a06`). O fechamento de SC1 / INFRA-01 fica **deferido** e é escalado ao desenvolvedor como lacuna de `user_setup` — **não é falha de código**, consistente com o EVO-01 do 25-01.

| Item | Fonte | Onde vai |
|---|---|---|
| `S3_ENDPOINT` | MinIO no host da agência — `https://s3.bomcustoilhabela.com.br` (mesmo endpoint dev + prod; bucket por env) | `.env` (dev) / `config/credentials.yml.enc` sob `aws:` (prod) |
| `aws.access_key_id` / `aws.secret_access_key` / `aws.region` | Access key + secret emitidos para o app no console/`mc` do MinIO | `config/credentials.yml.enc` sob `aws:` |
| Bucket `calendario-livia-development` (privado) | Console MinIO / `mc` no host da agência — policy privada | infra do host |

Depois de provisionar, rodar a verificação do Task 1 para fechar SC1 / INFRA-01:

```
bin/rails runner "b = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('phase25-probe'), filename: 'probe.txt', content_type: 'text/plain'); u = b.url(expires_in: 5.minutes); require 'open-uri'; body = URI.parse(u).open.read; abort('round-trip mismatch') unless body == 'phase25-probe'; b.purge; puts 'MinIO presigned round-trip OK'"
```

O plano 25-04 (download real de fora da LAN + rake de migração de blobs) também carrega INFRA-01 e depende do mesmo provisionamento.

### INFRA-03 — metade "TZ fixado no deploy" pendente para o plano 25-03

A verificação no boot está entregue aqui (`timezone_check.rb`). A outra metade do requisito — `TZ=America/Sao_Paulo` no `environment:` dos serviços `web` **e** `jobs` do `docker-compose.yml` — é entregue no plano 25-03. Por isso INFRA-03 não é marcado completo nesta SUMMARY.

## Requirements

- **INFRA-02** — MARCADO COMPLETO. `queue_adapter = :solid_queue` explícito + schema de fila carregado na base dev + processo `jobs` no `Procfile.dev` + prova de sobrevivência a restart (timeline acima). SC4 MET.
- **INFRA-01** — PENDENTE. Metade config entregue (`6ce3a06`); SC1 deferido em user_setup (MinIO não provisionado). Fecha com o plano 04 + provisionamento.
- **INFRA-03** — PENDENTE. Boot check entregue (`7f319a1`); `TZ` no container é o plano 03. Fecha com o plano 03.

## Threat Flags

Nenhuma superfície de segurança nova além do `<threat_model>` do plano.

- **T-25-06** (bucket exposto) — mitigado: `storage.yml` sem `public: true` (verificado por render ERB); policy privada do bucket é user_setup.
- **T-25-07** (presigned longevo) — mitigado: nenhuma mudança global em `ActiveStorage.service_urls_expire_in`; `expires_in:` por chamada é da fase 29.
- **T-25-08** (MITM app↔MinIO) — mitigado por config: `endpoint` é o subdomínio TLS (`https://`); `force_path_style: true`.
- **T-25-09** (TZ errado → job na hora errada) — mitigado: `timezone_check.rb` raise em produção; `TZ` nos containers é o plano 03.
- **T-25-10** (credenciais em `storage.yml`/ENV) — mitigado: chaves via `credentials.dig(:aws, ...)`, `S3_ENDPOINT` via ENV, `.env` gitignored, `dotenv-rails` dev/test-only.
- **T-25-SC** (`bundle install` de `aws-sdk-s3`) — sem gate de human-verify: `aws-sdk-s3` é a dependência que o próprio ActiveStorage declara (`~> 1.48`), ~10 anos, dezenas de M downloads/mês, auditada na RESEARCH.md `## Package Legitimacy Audit`.

## Next Phase Readiness

- **Plano 25-03** (deploy topology) pode prosseguir: precisa da stanza `amazon` (entregue) para o `production.rb` apontar `:amazon`, e adiciona `TZ` + serviço `jobs` ao `docker-compose.yml` (fecha INFRA-03 e a metade prod de INFRA-01).
- **Plano 25-04** (reachable media) depende do provisionamento do MinIO (user_setup acima) para o download real de fora da LAN e a rake de migração de blobs.
- **Fases 28-29** (Divulgação / Motor de Envio): `queue_adapter = :solid_queue` em dev agora viabiliza UAT de agendamento; o job de envio gerará a presigned URL por chamada dentro do `perform`.

---
*Phase: 25-funda-o-transporte-evolution-storage-alcan-vel*
*Completed: 2026-08-29*

## Self-Check: PASSED

- **Arquivos verificados em disco:** `config/initializers/timezone_check.rb` (FOUND), `config/storage.yml` (FOUND, stanza `amazon` ativa), `config/environments/development.rb` (FOUND, `:amazon` + `queue_adapter = :solid_queue`), `Procfile.dev` (FOUND, `jobs: bin/jobs`), `bin/setup` (FOUND, passo `queue_schema`), `README.md` (FOUND, seção "Background jobs in development"), `25-02-SUMMARY.md` (FOUND).
- **Commits verificados no git log:** `6ce3a06` (feat Task 1), `6fac8fd` (feat Task 2), `9b0c258` (docs checkpoint pause), `7f319a1` (feat Task 3) — todos FOUND.
- **Verificações `<automated>` do plano:** Task 1 checks 1-3 PASS (grep/ERB); check 4 (round-trip MinIO) DEFERIDO (user_setup, sem credenciais). Task 2 checks 1-5 PASS + gate SC4 humano MET (timeline acima). Task 3 checks 1-5 PASS.
