---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
verified: 2026-08-30T09:55:55Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "SC5 (metade build) — CR-01: guards `SECRET_KEY_BASE_DUMMY` em timezone_check.rb + evolution.rb; boot tipo-precompile não aborta, boot de runtime real sem TZ AINDA aborta"
    - "Topologia de produção (web + jobs) sobe — CR-02: `CORS_ORIGINS` em web+jobs no docker-compose.yml + `.env.example`; `config/application.rb` intacto (KeyError segue sendo o contrato)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "No host de deploy (com Docker): `docker compose build 2>&1 | tail -20`"
    expected: "Conclui sem abortar em `assets:precompile` — prova final de CR-01. O equivalente local (`env -u TZ SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production CORS_ORIGINS=... bin/rails runner`) já passa neste ambiente; falta a construção real da imagem."
    why_human: "Sem Docker / sem rede no ambiente de verificação. `assets:precompile` roda `Rails.application.initialize!` (os initializers) mais a compilação de assets; a falha de initializer que abortava o build está fechada e reproduzida localmente, mas a imagem em si não foi construída aqui."
  - test: "No host de deploy: `docker compose --env-file .env up -d && sleep 40 && docker compose ps` e `docker compose logs web jobs | grep -iE 'KeyError|key not found|timezone' || echo sem-erros`"
    expected: "`web` e `jobs` em `running`/`healthy`, nunca `restarting`; nenhum `KeyError: key not found: \"CORS_ORIGINS\"` nos logs — prova final de CR-02. ATENÇÃO WR-C: no primeiro deploy a frio, `db:prepare` pode exceder o `start_period: 40s` do healthcheck do `web`; se `up` falhar com `container is unhealthy`, rodar `docker compose up` de novo depois que `web` convergir (ou subir `start_period`)."
    why_human: "Sem Docker / sem rede. Verificado in-environment por parse YAML (CORS_ORIGINS presente no `environment:` de web e jobs) + `config/application.rb` inalterado; a subida real da stack é passo de operador (25-05-PLAN `user_setup` / 25-USER-SETUP.md)."
deferred:
  - truth: "App deployado publicamente em ilhacriativa.autopyweb.com.br; inbound `curl -I /up` do host do Evolution → 200; `storage:migrate_to_s3` rodado contra o DB de produção"
    addressed_in: "Phase 26 / passo de operador de go-live"
    evidence: "ROADMAP §Phase 25 Wave 4: 'Inbound /up carregado adiante para operador / fase 26 (app não deployado) — não bloqueia a fase 25 (D-12 / A4)'. evolution-contract.md §Deploy reachability confirma o mesmo. Phase 26 depende da Phase 25 e assume a instância pareada pelo painel."
warnings:
  - "WR-A (25-REVIEW 2026-08-30, prior WR-04): `.env.example` ainda traz `S3_ENDPOINT=` vazio; `dotenv-rails` carrega a string vazia e `ENV.fetch(\"S3_ENDPOINT\")` retorna `\"\"`, derrotando o fallback de credentials em `config/storage.yml:17`. Um `.env` copiado verbatim quebra o primeiro upload em dev. Fix: `ENV[\"S3_ENDPOINT\"].presence || credentials.dig(:aws,:endpoint)`."
  - "WR-B (25-REVIEW, prior WR-05): `Integer(ENV.fetch(\"EVOLUTION_OPEN_TIMEOUT\", \"5\"))` em `app/services/evolution.rb:35-37` — um operador que ZERA a var (`EVOLUTION_OPEN_TIMEOUT=`) recebe `Integer(\"\") → ArgumentError` no boot de produção (eager_load). Os readers `base_url`/`global_api_key` guardam com `.blank?`; as constantes não."
  - "WR-C (25-REVIEW, NOVO — introduzido pelo fix WR-03): `web.healthcheck.start_period: 40s` pode ser menor que um `db:prepare` de primeiro deploy a frio (cria 4 bancos + carrega 3 schemas + migra + boot eager_load). Se estourar a janela (~90s), `docker compose up` aborta com `dependency failed to start ... unhealthy` e `jobs`/`proxy` (ambos `condition: service_healthy`) não sobem — recuperável re-rodando `up`. Fix: `start_period: 180s` ou um serviço `migrate` one-shot com `condition: service_completed_successfully`."
  - "WR-D (25-REVIEW, NOVO): as mudanças de comportamento do 25-05 (WR-07: 2xx não-JSON → `Errors::Unknown`; WR-01: chave `read_timeout` em vez de `timeout`) foram entregues SEM caso de teste commitado, embora `test/services/evolution/client_test.rb` seja DB-free (`Faraday::Adapter::Test`). O comportamento FOI verificado nesta verificação por `bin/rails runner` com conexão stub (2xx text/html → `Unknown` em ambos os métodos; caminho JSON feliz inalterado), mas um refactor futuro que remova os type-guards passaria na suíte atual. Adicionar 2-3 casos unitários."
  - "IN-G (25-REVIEW, NOVO — trade-off residual do fix CR-01): o guard chaveia em `ENV[\"SECRET_KEY_BASE_DUMMY\"]`, que o Rails também documenta para rodar QUALQUER comando sem a master key (ex.: `SECRET_KEY_BASE_DUMMY=1 bin/rails db:migrate` num incidente). Rodado assim, um comando de manutenção em produção pula silenciosamente tanto o check de TZ (INFRA-03) quanto o fail-fast do Evolution (EVO-02). O boot normal do container (`./bin/rails server`, sem a var) foi verificado e AINDA aborta sem TZ. Aceitar e documentar, ou apertar a condição (exigir também ausência de `config/master.key` E `RAILS_MASTER_KEY`)."
  - "Segurança (carry 25-03/25-04): `aws.access_key_id` / `aws.secret_access_key` em `credentials.yml.enc` são as credenciais ROOT do MinIO. Emitir uma access key com escopo dos buckets `calendario-livia-*` e rotacionar antes / logo após o go-live. Ação de operador — rastreada no threat model (T-25 HIGH transferido ao operador)."
  - "Doc-sync: `.planning/REQUIREMENTS.md` linhas 145-153 ainda marcam INFRA-02 / INFRA-05 / EVO-01 como `Gaps Found` (estado da verificação anterior). Todos os 7 requisitos da fase estão agora satisfeitos — a tabela deve ser atualizada no ship/aggregate."
---

# Phase 25: Fundação — Transporte Evolution + Storage Alcançável — Relatório de Verificação (re-verificação)

**Phase Goal:** O app conversa com o host Evolution real da agência por uma única costura HTTP, e serve mídia por uma URL que esse host consegue baixar de fora da LAN — com jobs agendados sobrevivendo a reinício em development.
**Verificado:** 2026-08-30T09:55:55Z
**Status:** human_needed
**Re-verificação:** Sim — após o plano de gap-closure 25-05 (8 commits `ee4670a..ce13a35`)

## Veredito

Os **dois defeitos ship-blocking** da verificação anterior (`gaps_found` 4/5) estão
**genuinamente resolvidos no código**, confirmados por inspeção e pelos equivalentes locais
que rodam neste ambiente:

- **CR-01 — FECHADO.** `config/initializers/timezone_check.rb:19` tem
  `return if ENV["SECRET_KEY_BASE_DUMMY"]` como primeira linha executável (o ramo
  `raise(message)` na linha 36 segue intacto); `config/initializers/evolution.rb:14` tem
  `next if ENV["SECRET_KEY_BASE_DUMMY"]` imediatamente após `next unless Rails.env.production?`
  (só comentário entre as duas), com o assert `start_with?("https://")` intacto. Prova local:
  `env -u TZ SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production CORS_ORIGINS=... bin/rails runner "puts 'BUILD_BOOT_OK'"`
  → `BUILD_BOOT_OK`, exit 0 (o `assets:precompile` deixa de abortar). E o guard NÃO é um
  bypass de produção: `env -u TZ -u SECRET_KEY_BASE_DUMMY RAILS_ENV=production ... bin/rails runner`
  ainda aborta em `timezone_check.rb:36` (exit 1) — o boot check de runtime real continua vivo.

- **CR-02 — FECHADO.** `docker-compose.yml` tem `CORS_ORIGINS: ${CORS_ORIGINS}` no
  `environment:` de `web` (linha 43) E de `jobs` (linha 84) — 2 ocorrências em linhas
  não-comentário, confirmadas por parse YAML. `.env.example` (via `git show HEAD:.env.example`,
  linha 33) traz `CORS_ORIGINS=https://ilhacriativa.autopyweb.com.br` com comentário pt-BR.
  `config/application.rb` NÃO foi tocado pelo 25-05 (`git diff` vazio) — a `KeyError` em
  produção sem a var continua sendo o contrato, como a prohibition do plano exige.

Os **6 endurecimentos** que o verificador anterior pediu para embutir também estão aplicados
e verificados (WR-01 `read_timeout`, WR-07 type-guard → `Errors::Unknown`, WR-02 bind loopback,
WR-03/IN-07 healthcheck + `depends_on service_healthy`, WR-06 ordem do `queue_schema` em
`bin/setup`, IN-05 `TZ` no `db`). A re-review de código de 2026-08-30 (`25-REVIEW.md`,
`critical: 0`) confirma os 8 itens fechados e **nenhum novo ship-blocker**.

**Todos os 5 Success Criteria estão VERIFICADOS** no nível de código + equivalente local.
O status é `human_needed` (não `passed`) porque as **provas finais end-to-end de CR-01/CR-02
exigem Docker** (`docker compose build` / `docker compose up`), que não roda neste ambiente —
são passos de paste-back do operador documentados no `25-05-PLAN.md` `user_setup` e no
`25-USER-SETUP.md`. O deploy público real, o inbound `/up` e a migração no DB de produção
continuam legitimamente carregados adiante para a fase 26 / go-live (D-12 / A4).

## Goal Achievement

### Observable Truths (Success Criteria do ROADMAP)

| # | Truth | Status | Evidência |
|---|---|---|---|
| 1 | Uma arte com upload é servida por URL de S3 que o host público do Evolution baixa com sucesso — download real originado de fora de `192.168.3.203` | ✓ VERIFIED | `config/storage.yml` stanza `amazon` intacta (service S3, `force_path_style: true`, `bucket calendario-livia-#{Rails.env}`, sem chave `public`, endpoint ENV-first). 25-04: presigned GET buscado de fora da LAN (DNS público → Cloudflare → MinIO) → `HTTP/2 200`, content-type/length/disposition corretos, bytes conferem. 25-05 não tocou este escopo. Download iniciado pelo próprio host do Evolution + inbound `/up` = deferido (fase 26). |
| 2 | Chamada de leitura ao Evolution (header `apikey`, timeouts explícitos) → 200 contra o host da agência; versão/shape registrados por escrito antes de código depender | ✓ VERIFIED | `Evolution::Client.fetch_instances` → `Array[6]`, HTTP 200, ~654ms contra o host real (25-04). `evolution-contract.md` registra versão 2.3.7, envelope de erro, front Cloudflare — verificado 2026-08-29, antes do código downstream. Header `apikey` explícito (`client.rb:27,74`); nunca `Authorization: Bearer`. 3 timeouts explícitos (`client.rb:28-30`). 25-05/WR-01: `request` agora seta `req.options.read_timeout` — `READ_TIMEOUT_FAST` (15s) deixou de ser inerte. |
| 3 | Falha de rede / timeout / credencial inválida / instância não conectada → classificadas transitório/permanente/incerto/não-conectado; nenhuma exceção crua de HTTP escapa do client | ✓ VERIFIED | `Evolution::Errors` (5 classes) + `raise_for_status!` + `classify_timeout` + `assert_open!`. Runner de taxonomia do 25-01: "ALL TAXONOMY CASES OK". **WARNING WR-07 da verificação anterior FECHADO**: `bin/rails runner` com stub `Faraday::Adapter::Test` `200 text/html` → `fetch_instances` E `connection_state` levantam `Evolution::Errors::Unknown` (mensagem estática, corpo nunca ecoado); stub `200 application/json` → `Array` / `"open"` (caminho feliz inalterado). Nenhum `TypeError` cru escapa. WARNING WR-D: mudança sem teste commitado (comportamento verificado aqui à mão). |
| 4 | Um job agendado para daqui a alguns minutos continua executando depois de reiniciar o servidor de desenvolvimento | ✓ VERIFIED | `config/environments/development.rb:39` `queue_adapter = :solid_queue`; `Procfile.dev` `jobs: bin/jobs`; `bin/setup` carrega `db/queue_schema.rb` idempotente. Timeline verbatim do gate SC4 (25-02-SUMMARY:162-167): enqueue 17:35:34 → worker `kill -TERM` 17:35:49 → restart 17:36:43 → job disparou 17:37:04 (21s pós-restart), linha durável sobreviveu em `solid_queue_scheduled_executions`, zero `failed_executions`. 25-05/WR-06 fortalece o caminho `--reset` (carga do `queue_schema` movida para depois do `db:reset`). |
| 5 | O horário do app é o mesmo em development e em produção (TZ fixado e verificado no boot) + bundle com um único adapter de fila | ✓ VERIFIED (era ✗ FAILED) | **Único adapter: ✓** — `good_job`/`GoodJob` ausente de `Gemfile`/`Gemfile.lock`/`config`/`app`/`lib`/`db` (grep exit 1); `gem "solid_queue"` é o único adapter (`Gemfile:49`, `queue_adapter = :solid_queue` em dev e prod). **TZ pinado: ✓** — `docker-compose.yml` `TZ: America/Sao_Paulo` em `web` (46), `jobs` (87) E `db` (11, novo IN-05). **Verificado no boot: ✓ (era ✗ CR-01)** — guard `SECRET_KEY_BASE_DUMMY` em ambos os initializers; boot tipo-precompile completa (`BUILD_BOOT_OK`, exit 0), boot de runtime real sem TZ AINDA aborta (`timezone_check.rb:36`, exit 1). `default_timezone = :local` intacto (`application.rb:25`). Prova final `docker compose build` = paste-back do operador. |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Deferred Items

| # | Item | Endereçado em | Evidência |
|---|---|---|---|
| 1 | Deploy público real + inbound `/up` do host do Evolution + `storage:migrate_to_s3` contra o DB de produção | Phase 26 / go-live do operador | ROADMAP §Phase 25 Wave 4 + `evolution-contract.md §Deploy reachability`: "carregado adiante para operador / fase 26 — não bloqueia a fase 25 (D-12 / A4)". Phase 26 depende da Phase 25 e assume a instância pareada pelo painel. |

### Required Artifacts (must_haves 25-05 + regressão SC1-SC4)

| Artifact | Esperado | Status | Detalhes |
|---|---|---|---|
| `config/initializers/timezone_check.rb` | guard `return if ENV["SECRET_KEY_BASE_DUMMY"]` como 1a linha executável; ramo `raise` intacto | ✓ VERIFIED | Linha 19 (após header de comentário 1-18). Ramo `if Rails.env.production? then raise(message)` na linha 35-36 intacto. Shape check + boot local (ambas as direções) PASS. |
| `config/initializers/evolution.rb` | guard `next if ENV["SECRET_KEY_BASE_DUMMY"]` logo após `next unless Rails.env.production?`; assert `https://` intacto | ✓ VERIFIED | Linha 14, imediatamente após a linha 10 (só comentário 11-13 entre elas). Assert `start_with?("https://")` na linha 17. |
| `docker-compose.yml` | `CORS_ORIGINS: ${CORS_ORIGINS}` em web+jobs; healthcheck web `/up`; `depends_on service_healthy` em jobs+proxy; `web.ports` em `127.0.0.1`; `TZ` no `db` | ✓ VERIFIED | Parse YAML: `web.environment` + `jobs.environment` têm `CORS_ORIGINS`; `web.ports == ["127.0.0.1:5881:3000"]`; `web.healthcheck.test` bate em `/up`; `jobs.depends_on == {db: service_healthy, web: service_healthy}`; `proxy.depends_on == {web: service_healthy}`; `proxy.ports == ["80:80","443:443"]` inalterado; `db.environment.TZ == "America/Sao_Paulo"`. `grep -cF` de linha não-comentário == 2. WARNING WR-C (start_period). |
| `.env.example` | linha `CORS_ORIGINS=https://ilhacriativa.autopyweb.com.br` + comentário pt-BR | ✓ VERIFIED | `git show HEAD:.env.example` linha 33; comentário pt-BR linhas 31-32. Todas as chaves pré-existentes intactas. WARNING WR-A (`S3_ENDPOINT=` vazio segue). |
| `app/services/evolution/client.rb` | `req.options.read_timeout` em `request` (WR-01); type-guard Hash/Array levantando `Errors::Unknown` num 2xx não-JSON (WR-07) | ✓ VERIFIED | Linha 78 `req.options.read_timeout = read_timeout if read_timeout` (nenhuma atribuição a `req.options.timeout` resta). Linha 42 `raise ... unless body.is_a?(Array)`; linha 55 `raise ... unless resp.body.is_a?(Hash)`. Comportamento verificado por `bin/rails runner` stub. `raise_for_status!` / `classify_timeout` intactos. |
| `bin/setup` | bloco de carga do `queue_schema` DEPOIS do `db:reset ... if ARGV.include?("--reset")` | ✓ VERIFIED | Linha 26 `db:reset --reset`; bloco `db:schema:load:queue` linhas 33-45 (depois). `db:prepare` segue primeiro (linha 24). Bloco idempotente preservado. |
| `config/storage.yml` | serviço `amazon` S3/MinIO privado, `force_path_style`, bucket por env | ✓ VERIFIED (regressão) | Stanza ativa (linha 15+), sem `public`, `force_path_style: true`, `bucket: calendario-livia-#{Rails.env}`, endpoint ENV-first. Inalterado pelo 25-05. |
| `app/services/evolution/errors.rb` | módulo Errors + 5 classes `< StandardError` | ✓ VERIFIED (regressão) | `ConfigurationError`, `Transient`, `Permanent`, `Unknown`, `NotConnected`. Inalterado. |
| `config/initializers/filter_parameter_logging.rb` | `:apikey` e `:hash` filtrados | ✓ VERIFIED (regressão) | Ambos na linha 15. IN-A/IN-B (racional impreciso; `:hash` casa `hashtag`) — não bloqueiam. |
| `deploy/Caddyfile` | reverse proxy TLS `web:3000` | ✓ VERIFIED (regressão) | Site block `ilhacriativa.autopyweb.com.br { reverse_proxy web:3000 }`. Inalterado. |
| `lib/tasks/storage_migration.rake` | `storage:migrate_to_s3` idempotente, copy-only, backfill `service_name` | ✓ VERIFIED (regressão) | Provada em dev (25-04): `copied 12 / skipped 0 / missing 2 / backfilled 12`, 2ª rodada no-op. IN-E: backfilla também linhas `missing` — info, não bloqueia. |
| `test/services/evolution/client_test.rb` | cobertura `Faraday::Adapter::Test` da taxonomia | ✓ VERIFIED (existência) | 13 casos `test "..."` in-process. Suíte não roda aqui (`PG::InsufficientPrivilege` — banco de teste de outro usuário do SO, constraint conhecida). WARNING WR-D: os fixes WR-07/WR-01 não ganharam caso novo (embora o arquivo seja DB-free). |

### Key Link Verification

| From | To | Via | Status | Detalhes |
|---|---|---|---|---|
| Dockerfile `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` | `config/initializers/timezone_check.rb` + `config/initializers/evolution.rb` | `Rails.application.initialize!` roda os initializers; o guard `SECRET_KEY_BASE_DUMMY` faz eles pularem no build | ✓ WIRED (era ✗ NOT_WIRED) | Guard presente nos dois; boot local sob as condições exatas do precompile (`RAILS_ENV=production`, sem `TZ`, `SECRET_KEY_BASE_DUMMY=1`) completa. |
| `docker-compose.yml` `web`/`jobs` `environment:` | `config/application.rb` `ENV.fetch("CORS_ORIGINS")` | `CORS_ORIGINS: ${CORS_ORIGINS}` fornece a var que o corpo da classe `Application` exige em produção | ✓ WIRED (era ✗ NOT_WIRED) | Parse YAML confirma a chave no `environment:` de ambos os serviços; `application.rb:32-34` inalterado (sem fallback). |
| `app/services/evolution/client.rb` `request` | Faraday `req.options.read_timeout` | a chave que `Adapter#request_timeout(:read, options)` resolve antes de `options[:timeout]` | ✓ WIRED | `client.rb:78`; `fetch_instances`/`connection_state` passam `read_timeout: Evolution::READ_TIMEOUT_FAST`. |
| `docker-compose.yml` `jobs.depends_on` / `proxy.depends_on` | `web` healthcheck | `condition: service_healthy` — `jobs`/`proxy` só sobem depois de `web` migrar/bootar | ✓ WIRED | Parse YAML: ambos `{web: {condition: service_healthy}}`; `web.healthcheck` bate em `/up`. WARNING WR-C (start_period pode ser curto no 1º deploy). |
| `client.rb` | `errors.rb` | todo raise é `Evolution::Errors::*` inclusive no caminho 2xx não-JSON | ✓ WIRED | Verificado por runner: 2xx `text/html` → `Errors::Unknown` (nenhum `TypeError`/`Faraday::Error` vaza). |
| `development.rb` | `db/queue_schema.rb` | `queue_adapter = :solid_queue` + tabelas na base primária | ✓ WIRED (regressão) | dev linha 39; `bin/setup` carrega o schema; gate SC4 provou tabelas presentes. |
| `deploy/Caddyfile` | `docker-compose.yml web` | `reverse_proxy web:3000` | ✓ WIRED (regressão) | Site block presente. |

### Data-Flow Trace (Level 4)

| Artifact | Variável | Fonte | Produz dado real | Status |
|---|---|---|---|---|
| `Evolution::Client.fetch_instances` | corpo da resposta | `GET /instance/fetchInstances` no host real | ✓ (Array[6], 200, ~654ms — 25-04) | ✓ FLOWING |
| `storage:migrate_to_s3` | blobs origem/destino | `ActiveStorage::Blob.services.fetch(:local/:amazon)` | ✓ (12 blobs copiados, provado em dev) | ✓ FLOWING |
| presigned media URL | `blob.url` | serviço `amazon` (MinIO externo) | ✓ (fetch externo → HTTP/2 200) | ✓ FLOWING |
| `timezone_check` boot assertion | `ENV["TZ"]` / `Time.zone.name` | env do container | ✓ (pinado em web+jobs+db; guard `SECRET_KEY_BASE_DUMMY` só pula no build; runtime real ainda aborta sem TZ) | ✓ FLOWING (era ⚠️ HOLLOW) |
| `CORS_ORIGINS` → `Rails.application.config.middleware` CORS `origins` | `allowed_origins` | `ENV.fetch("CORS_ORIGINS")` ← `environment:` do compose ← `.env` do host | ✓ (var fornecida por web e jobs; `.env.example` documenta) | ✓ FLOWING (era ✗ DISCONNECTED) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Boot tipo-precompile (production, sem TZ, `SECRET_KEY_BASE_DUMMY=1`) não aborta | `env -u TZ SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production CORS_ORIGINS=... bin/rails runner "puts 'BUILD_BOOT_OK'"` | `BUILD_BOOT_OK`, exit 0 | ✓ PASS |
| Boot de runtime real (sem `SECRET_KEY_BASE_DUMMY`), sem TZ, AINDA aborta | `env -u TZ -u SECRET_KEY_BASE_DUMMY RAILS_ENV=production CORS_ORIGINS=... bin/rails runner "puts :x"` | exit 1, `timezone_check.rb:36 ... Timezone não determinístico (RuntimeError)` | ✓ PASS |
| WR-07: 2xx `text/html` → `Errors::Unknown` (sem `TypeError` cru), ambos os métodos | `bin/rails runner` + stub `Faraday::Adapter::Test` `200 text/html` | `OK fetch_instances -> Evolution::Errors::Unknown` / `OK connection_state -> Evolution::Errors::Unknown` (msg estática) | ✓ PASS |
| WR-07 regressão: 2xx `application/json` → caminho feliz inalterado | `bin/rails runner` + stub `200 application/json` | `fetch_instances` → `[{"a"=>1}]`; `connection_state` → `"open"` | ✓ PASS |
| `good_job` removido de todo o runtime | `grep -rniE 'good_?job|GoodJob' Gemfile Gemfile.lock config app lib db` | exit 1 (nenhum match) | ✓ PASS |
| `docker-compose.yml` parseia e tem CR-02 + hardening | `ruby -ryaml` parse | CORS_ORIGINS em web+jobs; healthcheck `/up`; `depends_on service_healthy`; `web.ports` loopback; `db.TZ` | ✓ PASS |
| `bin/setup` carrega `queue_schema` depois do `--reset` | índice de linha `db:schema:load:queue` > índice de `db:reset ... --reset` | 33-45 > 26 | ✓ PASS |
| Suíte de testes completa | `bin/rails test` | não roda — `PG::InsufficientPrivilege` (banco de teste de outro usuário do SO — constraint conhecida) | ? SKIP |
| `docker compose build` | — | sem Docker/rede; equivalente local passa; imagem real = paste-back do operador | ? SKIP → human_verification |
| `docker compose up` (web+jobs sem crash-loop) | — | sem Docker/rede; parse YAML + `application.rb` intacto; subida real = paste-back do operador | ? SKIP → human_verification |

### Probe Execution

Nenhuma probe `scripts/*/tests/probe-*.sh` no repositório; a fase não declara probes (o
`flagged_assumptions` do 25-05 registra "Probe spec-less: os 7 requisitos classificados
`unresolved` — probe produziu zero edges aplicáveis"). Não aplicável.

### Requirements Coverage

| Requirement | Source Plan | Descrição | Status | Evidência |
|---|---|---|---|---|
| INFRA-01 | 25-02/03/04/05 | ActiveStorage serve via S3 em produção, URL alcançável pelo host público do Evolution | ✓ SATISFIED | Config + prova empírica de download externo (SC1). A metade "em produção" (topologia que constrói/sobe) estava bloqueada por CR-01/CR-02 — **agora desbloqueada**. Deploy público real + migração no DB de produção = passo de operador (deferido, D-12). |
| INFRA-02 | 25-02 | Jobs agendados sobrevivem a reinício em development | ✓ SATISFIED | Timeline SC4 (25-02-SUMMARY): job disparou 21s pós-restart; linha durável sobreviveu. WR-06 fortalece `bin/setup --reset`. |
| INFRA-03 | 25-02/03/05 | Fuso determinístico dev/prod (`TZ` fixado no deploy + verificação no boot) | ✓ SATISFIED (era ⚠️ PARCIAL) | `TZ` em web+jobs+db; `timezone_check.rb` verificado no boot **e** build-context-scoped corretamente (guard pula só no precompile; runtime real ainda aborta). |
| INFRA-05 | 25-01 | `good_job` removido; um único adapter de fila | ✓ SATISFIED | Ausente de Gemfile/lock/refs; `solid_queue` sole adapter (dev + prod). |
| EVO-01 | 25-01/04 | Contrato Evolution verificado empiricamente contra o host real antes de código depender | ✓ SATISFIED | `evolution-contract.md` — versão 2.3.7, envelope, rotas, verificado 2026-08-29; `fetch_instances` → 200 no 25-04. Write-path permanece PENDENTE por D-08 (UAT 26/28/29) — como planejado. |
| EVO-02 | 25-01/05 | Toda comunicação HTTP via um PORO único, timeouts explícitos, header `apikey` | ✓ SATISFIED | `Evolution::Client` PORO; open/write/read explícitos; header `apikey`. WR-01 fechado — `READ_TIMEOUT_FAST` agora efetivo. |
| EVO-03 | 25-01/05 | Erros classificados transitório/permanente/incerto/não-conectado, tratamento distinto | ✓ SATISFIED | Taxonomia + runner "ALL TAXONOMY CASES OK" + WR-07 fechado (2xx não-JSON → `Unknown`, verificado à mão). WARNING WR-D (sem teste commitado do novo caminho). |

Todos os 7 IDs do frontmatter dos planos (INFRA-01/02/03/05, EVO-01/02/03) constam de
`REQUIREMENTS.md` mapeados para a Phase 25 (linha 199, 7 requisitos). **INFRA-04** está
corretamente FORA desta fase (mapeado para a fase 26, linha 147/200). Nenhum requisito órfão.
Nota doc-sync: a tabela de status em `REQUIREMENTS.md:145-153` ainda reflete a verificação
anterior (`Gaps Found` para INFRA-02/05, EVO-01) — deve ser atualizada no ship/aggregate.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `docker-compose.yml` | 52-57 | `web.healthcheck.start_period: 40s` possivelmente < `db:prepare` de 1º deploy a frio | ⚠️ Warning (WR-C, novo) | `docker compose up` pode abortar `jobs`/`proxy` no primeiro deploy; recuperável re-rodando `up` |
| `test/services/evolution/client_test.rb` | — | fixes WR-07/WR-01 sem caso de teste commitado (arquivo é DB-free) | ⚠️ Warning (WR-D, novo) | refactor futuro que remova os type-guards passa na suíte; comportamento verificado à mão nesta verificação |
| `config/initializers/timezone_check.rb` `evolution.rb` | 19 / 14 | guard `SECRET_KEY_BASE_DUMMY` também desliga INFRA-03/EVO-02 para comandos de manutenção rodados com essa var | ⚠️ Warning (IN-G, novo) | `SECRET_KEY_BASE_DUMMY=1 bin/rails db:migrate` num incidente pula os checks; boot normal do container (sem a var) verificado e ainda aborta |
| `config/storage.yml` + `.env.example` | 17 / `S3_ENDPOINT=` | string vazia derrota o fallback de credentials | ⚠️ Warning (WR-A, residual) | primeiro upload em dev de um checkout novo falha obscuro |
| `app/services/evolution.rb` | 35-37 | `Integer(ENV.fetch(...))` crasha com valor em branco | ⚠️ Warning (WR-B, residual) | operador que zera `EVOLUTION_*_TIMEOUT` aborta o boot de produção |
| `app/services/evolution/client.rb` | 23-33 | conexão memoizada captura a apikey global pelo tempo de vida do processo | ℹ️ Info (IN-F) | rotação de credencial exige restart; mitigado parcialmente pelo `req.headers["apikey"]` por-request |
| `lib/tasks/storage_migration.rake` | 33-56 | backfill de `service_name` inclui blobs `missing` | ℹ️ Info (IN-E) | remove o caminho de recovery via Disk |
| `config/initializers/filter_parameter_logging.rb` | 7-15 | racional impreciso; `:hash` casa `hashtag` | ℹ️ Info (IN-A/IN-B) | debuggabilidade; não bloqueia |

Nenhum marcador de dívida (`TODO`/`FIXME`/`XXX`/`HACK`/`PLACEHOLDER`) nos 6 arquivos
modificados pelo 25-05 (grep exit 1).

### Prohibitions (25-05 must_haves.prohibitions)

| Prohibition | verification | Status | Evidência |
|---|---|---|---|
| Nunca usar o guard `SECRET_KEY_BASE_DUMMY` como caminho para pular o boot check em runtime real | test | ✓ (não violada) | Boot de runtime real (sem a var), production, sem TZ → aborta em `timezone_check.rb:36` (exit 1). Ver IN-G: comandos de manutenção rodados COM a var pulam os checks — aceito/documentável, não é o caminho de runtime normal. |
| Nunca adicionar fallback de `CORS_ORIGINS` em `config/application.rb` | test | ✓ (não violada) | `git diff ee4670a~1 ce13a35 -- config/application.rb` vazio; linha 33 segue `ENV.fetch("CORS_ORIGINS")` sem default em produção. |
| Nunca mudar `config.active_record.default_timezone` de `:local` | judgment | ✓ (não violada) | `config/application.rb:25` `= :local` intacto. |
| Nunca deixar `Faraday::Error` / status HTTP cru escapar do `Evolution::Client` (inclusive 2xx não-JSON) | test | ✓ (não violada) | Runner stub `200 text/html` → `Errors::Unknown` em ambos os métodos; nenhum `TypeError`/`Faraday::Error` vaza. |
| Não tocar nos planos/SUMMARYs 25-01..25-04 nem re-executar seu escopo | judgment | ✓ (não violada) | `git diff --stat` do 25-05 = 6 arquivos (os declarados no frontmatter); nenhum plano/summary anterior. |
| Não planejar o deploy público real / inbound `/up` / `storage:migrate_to_s3` contra prod | judgment | ✓ (não violada) | Nenhuma task nesse sentido; itens registrados como deferred (fase 26). |
| Não emitir task para rotação das credenciais ROOT do MinIO | judgment | ✓ (não violada) | Registrado como recomendação de operador em `25-05-SUMMARY` "User Setup Required"; sem task. |

Nenhuma prohibition test-tier ficou sem enforcement observável — as 4 test-tier foram
exercitadas por boot local / runner stub / `git diff`.

### Human Verification Required

Status `human_needed` — os fixes de CR-01/CR-02 estão verificados no código e pelos
equivalentes locais, mas as **provas finais end-to-end exigem Docker**, ausente neste ambiente.
São passos de paste-back do operador (documentados em `25-05-PLAN.md` `user_setup` /
`25-USER-SETUP.md`):

1. **`docker compose build`** — no host de deploy: `docker compose build 2>&1 | tail -20`.
   **Esperado:** conclui sem abortar em `assets:precompile` (prova final de CR-01). O
   equivalente local (`SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production` sem `TZ` → `bin/rails runner`
   boota) já passa; falta a construção real da imagem.
   **Por que humano:** sem Docker / sem rede no ambiente de verificação.

2. **`docker compose up`** — `docker compose --env-file .env up -d && sleep 40 && docker compose ps`
   e `docker compose logs web jobs | grep -iE 'KeyError|key not found|timezone' || echo sem-erros`.
   **Esperado:** `web` e `jobs` em `running`/`healthy`, nunca `restarting`; sem
   `KeyError: key not found: "CORS_ORIGINS"` (prova final de CR-02). **Atenção WR-C:** no
   primeiro deploy a frio, se `up` falhar com `container is unhealthy`, re-rodar `docker compose up`
   depois que `web` convergir, ou subir `start_period` do healthcheck.
   **Por que humano:** sem Docker / sem rede; verificado in-environment só por parse YAML +
   `application.rb` inalterado.

3. **(deferido, fase 26 / go-live)** Deploy público real + `curl -I /up` originado do host do
   Evolution → 200 + `storage:migrate_to_s3` contra o DB de produção. Não é gate da fase 25
   (D-12 / A4).

### Gaps Summary

**Nenhum gap.** Os 2 ship-blockers da verificação anterior estão fechados:

- **CR-01** — guards `SECRET_KEY_BASE_DUMMY` em `timezone_check.rb:19` e `evolution.rb:14`.
  Boot tipo-precompile completa; boot de runtime real sem TZ ainda aborta (o guard é
  build-context-scoped, não um bypass de produção). Verificado localmente nas duas direções.
- **CR-02** — `CORS_ORIGINS: ${CORS_ORIGINS}` em `web` + `jobs` no `docker-compose.yml`;
  `CORS_ORIGINS=https://ilhacriativa.autopyweb.com.br` no `.env.example`; `config/application.rb`
  intacto (a `KeyError` segue sendo o contrato). Verificado por parse YAML + `git show` + `git diff`.

Os 6 endurecimentos WR/IN pedidos pelo verificador anterior também estão aplicados. A
re-review de código de 2026-08-30 confirma `critical: 0`.

Os **5 Success Criteria estão VERIFICADOS** no nível de código + equivalente local. O status
é `human_needed` (não `passed`) só porque `docker compose build` / `docker compose up` — as
provas finais da topologia de deploy que esta fase entrega — não rodam neste ambiente e são
paste-back do operador. Não há nada a corrigir no código; há dois comandos a confirmar no host.

Warnings residuais/novos (WR-A, WR-B, WR-C, WR-D, IN-G, segurança MinIO) estão no frontmatter
`warnings:` — nenhum bloqueia o goal; endereçar oportunamente antes das fases 28/29 / go-live.

---

_Verificado: 2026-08-30T09:55:55Z_
_Verificador: Claude (gsd-verifier) — re-verificação após gap-closure 25-05_
