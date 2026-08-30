---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
verified: 2026-08-29T00:00:00Z
status: gaps_found
score: 4/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "SC5 — o TZ é verificado no boot em produção sem quebrar o build/boot da topologia de deploy entregue por esta fase"
    status: failed
    reason: >
      CR-01 (25-REVIEW, commit ee2c07f), confirmado por inspeção de código.
      config/initializers/timezone_check.rb é código top-level SEM guarda que executa
      raise(message) quando Rails.env.production? && ENV['TZ'] != 'America/Sao_Paulo'.
      Dockerfile:55 roda `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` num
      stage com ENV RAILS_ENV="production" e sem TZ — o initializer roda durante o
      Rails.application.initialize! do precompile e aborta o build. config/initializers/evolution.rb
      (after_initialize) tem o mesmo problema: `next unless Rails.env.production?` NÃO
      pula durante o build e Evolution.global_api_key levanta ConfigurationError (config/master.key
      fora da imagem). docker-compose.yml usa `build: .` nos serviços web e jobs → a
      topologia de deploy inteira (o "+Deploy" ancorado nesta fase, D-09) não produz imagem.
      Regressão introduzida por esta fase (ambos os initializers são novos no 25-02/25-01).
    artifacts:
      - path: "config/initializers/timezone_check.rb"
        issue: "raise top-level sem guarda para o contexto de build (assets:precompile roda em RAILS_ENV=production sem TZ)"
      - path: "config/initializers/evolution.rb"
        issue: "after_initialize não pula durante assets:precompile; Evolution.global_api_key levanta ConfigurationError no build (sem master.key)"
      - path: "docker-compose.yml"
        issue: "web + jobs usam build: . — dependem de uma imagem que não constrói"
    missing:
      - "Guarda `return if ENV['SECRET_KEY_BASE_DUMMY']` no topo de config/initializers/timezone_check.rb"
      - "Guarda `next if ENV['SECRET_KEY_BASE_DUMMY']` no after_initialize de config/initializers/evolution.rb"
      - "Verificação: `docker compose build` (ou `SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails assets:precompile` sem TZ) conclui sem abortar"
  - truth: "A topologia de produção (web + worker jobs dedicado, ambos TZ-pinados) sobe, para que jobs agendados disparem em produção (must_have 25-03; metade prod de SC5 / INFRA-03)"
    status: failed
    reason: >
      CR-02 (25-REVIEW), confirmado por inspeção. config/application.rb:32-34 faz
      `ENV.fetch("CORS_ORIGINS")` SEM default quando Rails.env.production? (raise KeyError).
      Os serviços web e jobs do docker-compose.yml setam RAILS_ENV=production mas nunca
      passam CORS_ORIGINS no environment:, e .env.example (o contrato do operador para esta
      topologia) não lista a chave. `docker compose up` com um .env derivado do .env.example
      dá `KeyError: key not found: "CORS_ORIGINS"` no boot de web e jobs; `restart: unless-stopped`
      transforma em crash-loop. CORS_ORIGINS não tem fallback em credentials nem em lugar nenhum.
    artifacts:
      - path: "docker-compose.yml"
        issue: "serviços web e jobs sem CORS_ORIGINS (nem segredos Evolution/S3) no bloco environment:"
      - path: ".env.example"
        issue: "não documenta CORS_ORIGINS — operador que copia o arquivo verbatim não sobe a stack"
    missing:
      - "CORS_ORIGINS: ${CORS_ORIGINS} no environment: de web E jobs em docker-compose.yml"
      - "CORS_ORIGINS=https://ilhacriativa.autopyweb.com.br em .env.example"
      - "Verificação: `docker compose up` sobe web + jobs sem crash-loop"
deferred:
  - truth: "App deployado publicamente em ilhacriativa.autopyweb.com.br; inbound curl -I /up do host do Evolution → 200; migração storage:migrate_to_s3 rodada contra o DB de produção"
    addressed_in: "Phase 26 / passo de operador de go-live"
    evidence: "25-04-SUMMARY + evolution-contract.md §Deploy reachability: 'inbound /up carregado adiante para operador / fase 26 (app não deployado) — não bloqueia a fase 25 (D-12 / A4: fase 26 lidera com o botão PAIR-05)'. Phase 26 goal depende da Phase 25 e assume a instância pareada pelo painel."
warnings:
  - "WR-07 (25-REVIEW): connection_state faz resp.body.dig(\"instance\",\"state\") e fetch_instances retorna resp.body cru. Num 2xx com corpo não-JSON (interstitial HTML da Cloudflare) resp.body é String, String#dig levanta TypeError CRU — vaza o invariante 'nenhuma exceção crua escapa do client' de SC3. Caminho estreito (2xx + HTML), sem teste. Não falha SC3 (os quatro casos nomeados — rede, timeout, credencial, não-conectado — classificam corretamente) mas deve ser endurecido antes das fases 28/29."
  - "WR-01 (25-REVIEW): Evolution::READ_TIMEOUT_FAST (15s) é inerte. request seta req.options.timeout, mas a connection memoizada já seta f.options.read_timeout = 30; Faraday resolve read_timeout primeiro, então fetch_instances/connection_state esperam 30s, não 15s. 'timeouts explícitos' de SC2/EVO-02 é atendido (open/write/read todos setados) mas o valor rápido documentado não tem efeito. Fix: req.options.read_timeout = read_timeout."
  - "WR-02 (25-REVIEW): docker-compose web publica `ports: 5881:3000` em 0.0.0.0 sem TLS, contornando o Caddy; com config.assume_ssl=true o Rails serve tráfego de sessão/auth em HTTP puro nessa porta. Usar expose: ou bind 127.0.0.1."
  - "WR-03 / IN-07 (25-REVIEW): jobs e web sobem concorrentes; jobs (bin/jobs) consulta solid_queue_* antes de web rodar db:prepare no primeiro deploy → StatementInvalid + crash-loop até web convergir. web não tem healthcheck e proxy usa depends_on sem condition."
  - "WR-06 (25-REVIEW): em bin/setup o bloco de carga do queue_schema está ANTES de `db:reset if --reset`; `bin/setup --reset` recarrega só db/schema.rb e apaga as tabelas solid_queue_* recém-carregadas → jobs do Procfile.dev em crash-loop. Mover para depois do --reset."
  - "IN-05 (25-REVIEW): o container db não tem TZ pinado (roda UTC) enquanto default_timezone = :local; defaults SQL (CURRENT_TIMESTAMP / now()) rodam noutro wall-clock. Pinar TZ: America/Sao_Paulo no db custa nada."
  - "Segurança (25-03/25-04): aws.access_key_id / aws.secret_access_key gravados em credentials.yml.enc são as credenciais ROOT do MinIO. Emitir uma access key com escopo dos buckets calendario-livia-* e rotacionar antes / logo após o go-live."
---

# Phase 25: Fundação — Transporte Evolution + Storage Alcançável — Verification Report

**Phase Goal:** O app conversa com o host Evolution real da agência por uma única costura HTTP, e serve mídia por uma URL que esse host consegue baixar de fora da LAN — com jobs agendados sobrevivendo a reinício em development.
**Verified:** 2026-08-29
**Status:** gaps_found
**Re-verification:** No — initial verification

## Verdict

O **núcleo empírico da fase está provado**: a costura HTTP única com o Evolution real,
o download externo de mídia presignada, e a sobrevivência de job agendado a reinício
em development foram todos exercitados contra sistemas reais e registrados. As 4 dos 5
Success Criteria que dependem de comportamento (SC1-SC4) estão VERIFICADAS.

Porém o code review (25-REVIEW.md, commit ee2c07f) achou **dois defeitos ship-blocking na
topologia de deploy** que esta fase entrega (o "+Deploy" ancorado aqui por D-09), e a
verificação confirmou os dois por inspeção de código:

- **CR-01** — `timezone_check.rb` e o `after_initialize` de `evolution.rb` levantam durante
  `assets:precompile` (RAILS_ENV=production, sem TZ, sem master.key no build). Como
  `docker-compose.yml` usa `build: .`, a imagem de produção **não constrói**.
- **CR-02** — `web`/`jobs` nunca recebem `CORS_ORIGINS`, e `config/application.rb` faz
  `ENV.fetch("CORS_ORIGINS")` sem fallback em produção → **crash-loop no boot**.

A topologia de produção existe como artefato (`docker-compose.yml`, `deploy/Caddyfile`,
`production.rb`) mas **não é funcional como entregue**. A metade "verificado no boot" de
SC5 e a metade "em produção" de INFRA-01 ficam bloqueadas por esses defeitos.

**Recomendação:** marcar a fase 25 como `gaps_found` e criar um plano de correção curto
(CR-01 + CR-02 — fixes de uma linha cada) antes do go-live / abertura da fase 26. O deploy
público real, o inbound `/up` e a migração no DB de produção continuam legitimamente
carregados adiante (D-12 / A4) e **não** são gate desta fase.

## Goal Achievement

### Observable Truths

| # | Truth (Success Criteria do ROADMAP) | Status | Evidence |
|---|---|---|---|
| 1 | Arte com upload servida por URL de S3 baixada com sucesso de fora de `192.168.3.203` | ✓ VERIFIED | `config/storage.yml` stanza `amazon` real (service S3, `force_path_style: true`, `bucket calendario-livia-#{Rails.env}`, sem chave `public`). 25-04: presigned GET buscado de fora da LAN (DNS público → Cloudflare → MinIO) → `HTTP/2 200`, `content-type: text/plain`, `content-length: 28`, `content-disposition: attachment`, bytes conferem. Endpoint corrigido (console→API S3, commit 947413f); buckets criados privados. Registrado em `.planning/notes/evolution-contract.md §Deploy reachability`. Nota: o download iniciado pelo próprio host do Evolution é carregado adiante (D-12) — o critério é "download real originado de fora de .203", que foi cumprido. |
| 2 | Chamada de leitura ao Evolution (header `apikey`, timeouts explícitos) → 200 contra o host da agência; versão/shape registrados por escrito antes de código depender | ✓ VERIFIED | `Evolution::Client.fetch_instances` (`app/services/evolution/client.rb`) → `Array[6]`, HTTP 200, ~654ms contra `whatsapp.bomcustoilhabela.com.br` (25-04). `evolution-contract.md` registra versão `2.3.7`, envelope de erro `{status,error,response:{message:String\|Array}}`, front Cloudflare, rotas — verificado no host real 2026-08-29, antes do código downstream. Header `apikey` explícito (client.rb:27,64); nunca `Authorization: Bearer`. |
| 3 | Falha de rede / timeout / credencial inválida / instância não conectada → classificadas transitório/permanente/incerto/não-conectado; nenhuma exceção crua de HTTP escapa | ✓ VERIFIED | `Evolution::Errors` (5 classes) + `raise_for_status!` + `classify_timeout` + `assert_open!` em `client.rb`. Runner de taxonomia do 25-01 (`<verify>` Task 2): "ALL TAXONOMY CASES OK" — 503/500/502/504/408/429→Transient, 400/401/403/404/422→Permanent, 5xx HTML→Transient sem ecoar, Net::OpenTimeout→Transient, Net::ReadTimeout→Unknown, state≠open→NotConnected. `test/services/evolution/client_test.rb` — 15 casos Faraday::Adapter::Test (suíte não roda: banco de teste de outro usuário do SO — constraint conhecida do projeto). **WARNING WR-07**: `TypeError` cru pode escapar em 2xx com corpo não-JSON (caminho estreito, não nomeado no SC). |
| 4 | Job agendado para alguns minutos à frente continua executando depois de reiniciar o servidor de development | ✓ VERIFIED | `config/environments/development.rb:39` `queue_adapter = :solid_queue`; `Procfile.dev` `jobs: bin/jobs`; `bin/setup` carrega `db/queue_schema.rb`. Timeline verbatim do gate SC4 (25-02): enqueue 17:35:34 → worker kill 17:35:49 → restart 17:36:43 → job disparou 17:37:04 (21s pós-restart), linha durável sobreviveu em `solid_queue_scheduled_executions`, zero `failed_executions`. |
| 5 | Horário igual em dev e prod (TZ fixado e verificado no boot) + bundle com um único adapter de fila | ✗ FAILED (parcial) | **Single adapter: ✓** — `good_job` ausente de `Gemfile`/`Gemfile.lock`/refs em config,app,lib,db; `solid_queue` é o único adapter. **TZ pinado: ✓ (config)** — `docker-compose.yml` `TZ: America/Sao_Paulo` em `web` e `jobs`. **Verificado no boot: ✗** — `config/initializers/timezone_check.rb` é raise top-level sem guarda; roda durante `assets:precompile` (RAILS_ENV=production, sem TZ) e **aborta o `docker compose build`** (CR-01). O mesmo vale para o `after_initialize` de `config/initializers/evolution.rb`. A topologia de deploy entregue não constrói/sobe (CR-01 + CR-02). |

**Score:** 4/5 truths verified

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | Deploy público real + inbound `/up` do host do Evolution + migração no DB de produção | Phase 26 / go-live do operador | `evolution-contract.md §Deploy reachability`: "carregado adiante para operador / fase 26 (app não deployado) — não bloqueia a fase 25 (D-12 / A4)". Phase 26 depende da Phase 25 e assume instância pareada pelo painel. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `app/services/evolution/client.rb` | Costura HTTP única — Faraday memoizado, header apikey, 3 timeouts, log metadata-only | ✓ VERIFIED | `class Client`, `connection`/`fetch_instances`/`connection_state`/`assert_open!` + privados `request`/`raise_for_status!`/`classify_timeout`. `open_timeout`/`write_timeout`/`read_timeout` os 3 setados (client.rb:28-30). Log linha `[evolution] METHOD path -> status (Nms)` só (client.rb:78). WR-01: `READ_TIMEOUT_FAST` inerte. |
| `app/services/evolution/errors.rb` | Módulo Errors + 5 classes | ✓ VERIFIED | `ConfigurationError`, `Transient`, `Permanent`, `Unknown`, `NotConnected` — todas `< StandardError`. |
| `app/services/evolution.rb` | Readers `base_url`/`global_api_key` (ENV-first) + constantes de timeout | ✓ VERIFIED | Namespace explícito (desvio do plano: mover do initializer para cá foi necessário p/ o Zeitwerk — 25-01 Deviation 1). Guardas `.blank?` nos readers; `Integer(ENV.fetch(...))` nas constantes (WR-05: crasha com valor em branco). |
| `config/initializers/evolution.rb` | Fail-fast de boot em produção + assert https | ⚠️ ORPHANED (defeito) | `after_initialize`, `next unless Rails.env.production?`, `Evolution.global_api_key` + assert `https://`. **CR-01**: não pula durante `assets:precompile` → levanta ConfigurationError no build. |
| `config/initializers/timezone_check.rb` | Asserção de TZ no boot — raise prod / warn dev | ⚠️ ORPHANED (defeito) | `America/Sao_Paulo` + `Rails.env.production? ? raise : warn`. `default_timezone = :local` intacto. **CR-01**: raise top-level sem guarda aborta `assets:precompile`. |
| `config/initializers/filter_parameter_logging.rb` | `:apikey` e `:hash` filtrados | ✓ VERIFIED | Ambos adicionados (linha 15). IN-01: comentário de racional impreciso; IN-02: `:hash` casa `hashtag`. Não bloqueia. |
| `config/storage.yml` | Serviço `amazon` S3/MinIO — privado, force_path_style, bucket por env | ✓ VERIFIED | Stanza ativa, sem `public`, `force_path_style: true`, `bucket: calendario-livia-#{Rails.env}`, endpoint ENV-first. WR-04: `S3_ENDPOINT=""` no `.env.example` derrota o fallback de credentials (`ENV.fetch` retorna `""`). |
| `config/environments/development.rb` | `:amazon` + `queue_adapter = :solid_queue` | ✓ VERIFIED | Linhas 33 + 39; sem `connects_to` (dev base única). |
| `config/environments/production.rb` | `:amazon` + assume_ssl + force_ssl + ssl_options + config.hosts + host_authorization | ✓ VERIFIED | Todas ativas (linhas 27/31/34/37/89-94). `action_mailer` host real (desvio Rule 2). Boot de produção completo com `CORS_ORIGINS` + `SECRET_KEY_BASE_DUMMY=1` + `TZ` explícitos passou (25-03) — mas isso mascara CR-01/CR-02, que só aparecem no caminho de build/compose real. |
| `docker-compose.yml` | Serviço `jobs` (./bin/jobs) + `TZ` em web+jobs + proxy Caddy | ✗ STUB (não funcional) | `jobs` + `proxy` + `TZ` + volumes presentes e bem formados. **Mas** `build: .` depende de imagem que não constrói (CR-01) e web/jobs crash-loop sem `CORS_ORIGINS` (CR-02). WR-02/WR-03/IN-05/IN-07 adicionais. |
| `deploy/Caddyfile` | Reverse proxy TLS `web:3000` | ✓ VERIFIED | Site block `ilhacriativa.autopyweb.com.br { reverse_proxy web:3000 }`. Bloco `s3.` comentado (desvio Rule 2 — MinIO externo, não co-locado). |
| `.env.example` | Chaves EVOLUTION_* / S3_ENDPOINT / TZ documentadas | ⚠️ INCOMPLETO | 7 chaves novas presentes (per 25-03-SUMMARY). **CR-02**: falta `CORS_ORIGINS` — chave obrigatória para a topologia subir. WR-04: `S3_ENDPOINT=` vazio é um footgun. (Arquivo não legível diretamente pelo verificador — permissão; baseado em 25-REVIEW + 25-03-SUMMARY.) |
| `lib/tasks/storage_migration.rake` | `storage:migrate_to_s3` idempotente, copy-only, backfill service_name | ✓ VERIFIED | `dest.exist?` skip / `!source.exist?` warn-não-raise / `dest.upload(checksum:,content_type:)` / `update_all(service_name:"amazon")` where `[nil,"local"]` / resumo greppável. Copy-only (origem Disk nunca mutada). Provada em dev: `copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12`, 2ª rodada só-skip. IN-06: backfilla também linhas `missing` (remove o caminho de recovery via Disk). |
| `test/services/evolution/client_test.rb` | Cobertura Faraday::Adapter::Test da taxonomia | ✓ VERIFIED (existência + substância) | 15 casos, in-process. Não executável neste ambiente (banco de teste de outro usuário do SO — MEMORY.md). Comportamento coberto pelo runner do plano. IN-04: o teste de log-leak usa uma connection stub sem a linha de header — não pegaria uma regressão real de log de header. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `client.rb` | `app/services/evolution.rb` | `Evolution.base_url` / `Evolution.global_api_key` + constantes de timeout | ✓ WIRED | client.rb:24,27,28-30,36,38,44,46 |
| `client.rb` | `errors.rb` | `raise Evolution::Errors::{Transient,Permanent,Unknown,NotConnected}` | ✓ WIRED | client.rb:55,72,75,93,100,102,104,116,118,120 — todo raise é `Evolution::Errors::*` (nenhum `Faraday::` num raise). WR-07: um `TypeError` cru pode escapar de `connection_state` sem passar por aqui. |
| `development.rb` | `config/storage.yml` | `active_storage.service = :amazon` | ✓ WIRED | dev linha 33 |
| `development.rb` | `db/queue_schema.rb` | `queue_adapter = :solid_queue` + tabelas na base primária | ✓ WIRED | dev linha 39; `bin/setup` carrega o schema; gate SC4 provou tabelas presentes |
| `Procfile.dev` | `bin/jobs` | `jobs: bin/jobs` | ✓ WIRED | Procfile.dev:3 |
| `docker-compose.yml jobs` | `bin/jobs` | `command: ["./bin/jobs"]` | ⚠️ PARTIAL | Linha presente e válida, mas o serviço não sobe (CR-01 build / CR-02 boot) |
| `production.rb` | `config/storage.yml` | `active_storage.service = :amazon` | ✓ WIRED | prod linha 27 |
| `deploy/Caddyfile` | `docker-compose.yml web` | `reverse_proxy web:3000` | ✓ WIRED | Caddyfile:9 |
| `docker-compose.yml web/jobs` | `config/application.rb` | boot lê `ENV.fetch("CORS_ORIGINS")` | ✗ NOT_WIRED | CR-02 — variável nunca fornecida; KeyError no boot |
| Dockerfile `assets:precompile` | `config/initializers/*.rb` | `Rails.application.initialize!` roda os initializers | ✗ NOT_WIRED (quebra) | CR-01 — `timezone_check.rb` / `evolution.rb` levantam e abortam o build |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `Evolution::Client.fetch_instances` | corpo da resposta | `GET /instance/fetchInstances` no host real | ✓ (Array[6], 200, ~654ms — 25-04) | ✓ FLOWING |
| `storage:migrate_to_s3` | blobs origem/destino | `ActiveStorage::Blob.services.fetch(:local/:amazon)` | ✓ (12 blobs copiados, provado em dev) | ✓ FLOWING |
| presigned media URL | `blob.url` | serviço `amazon` (MinIO via `minio.bomcustoilhabela.com.br`) | ✓ (fetch externo → HTTP/2 200) | ✓ FLOWING |
| `timezone_check` boot assertion | `ENV["TZ"]` / `Time.zone.name` | env do container | ⚠️ pinado em compose, mas o mecanismo de assert quebra o build | ⚠️ HOLLOW |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| `good_job` removido de todo o runtime | `grep -rnE 'good_job\|GoodJob' Gemfile Gemfile.lock config app lib db` | exit 1 (nenhum match) | ✓ PASS |
| `faraday` + `aws-sdk-s3` no Gemfile | `grep -nE 'faraday\|aws-sdk' Gemfile` | linhas 38, 42 | ✓ PASS |
| `storage:migrate_to_s3` registrada | (25-04) `bin/rails -T storage` | task listada com descrição | ✓ PASS (per SUMMARY) |
| Taxonomia de erro classifica os 5 grupos | (25-01) runner `bin/rails runner` do `<verify>` Task 2 | "ALL TAXONOMY CASES OK" | ✓ PASS (per SUMMARY) |
| Suíte de testes completa | `bin/rails test` | não roda — banco de teste pertence a outro usuário do SO (MEMORY.md / constraint conhecida) | ? SKIP |
| `docker compose build` | não executado pelo verificador (sem Docker/rede); CR-01 confirmado por inspeção de Dockerfile:55 + initializers sem guarda | build abortaria no precompile | ✗ FAIL (inspeção) |

### Probe Execution

Nenhuma probe `scripts/*/tests/probe-*.sh` no repositório; fase não declara probes. Não aplicável.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| INFRA-01 | 25-02, 25-03, 25-04 | ActiveStorage serve via S3 **em produção**, URL alcançável pelo host público do Evolution | ⚠️ PARCIAL | Config + prova empírica de download externo OK em **development** (SC1 ✓). A metade "em produção" fica bloqueada por CR-01/CR-02 (a imagem não constrói / crash-loop). Migração no DB de produção = passo de operador (deferido). |
| INFRA-02 | 25-02 | Jobs agendados sobrevivem a reinício em development | ✓ SATISFIED | Timeline SC4: job disparou 21s pós-restart do worker; linha durável sobreviveu. |
| INFRA-03 | 25-02, 25-03 | Fuso determinístico dev/prod (`TZ` fixado no deploy + verificação no boot) | ⚠️ PARCIAL | `TZ` em `docker-compose.yml` (web+jobs) ✓; `timezone_check.rb` existe ✓; mas o mecanismo "verificação no boot" tem defeito (CR-01) — raise no `assets:precompile` quebra o build. |
| INFRA-05 | 25-01 | `good_job` removido; um único adapter de fila | ✓ SATISFIED | Ausente de Gemfile/lock/refs; `solid_queue` sole adapter. |
| EVO-01 | 25-01, 25-04 | Contrato Evolution verificado empiricamente contra o host real antes de código depender | ✓ SATISFIED | `evolution-contract.md` — versão 2.3.7, envelope, rotas, Cloudflare, verificado 2026-08-29; `fetch_instances` → 200 no 25-04. Write-path permanece PENDENTE por D-08 (UAT 26/28/29) — como planejado. |
| EVO-02 | 25-01 | Toda comunicação HTTP via um PORO único, timeouts explícitos, header `apikey` | ✓ SATISFIED | `Evolution::Client` PORO; open/write/read explícitos; header `apikey` por conexão e por request. WR-01 (fast timeout inerte) é qualidade, não viola o requisito. |
| EVO-03 | 25-01 | Erros classificados transitório/permanente/incerto/não-conectado, cada classe com tratamento distinto | ✓ SATISFIED | Taxonomia + runner "ALL TAXONOMY CASES OK" + 15 testes. WARNING WR-07 (TypeError cru em 2xx não-JSON) a endurecer. |

Todos os 7 IDs do frontmatter dos planos (INFRA-01/02/03/05, EVO-01/02/03) constam de `REQUIREMENTS.md` mapeados para a Phase 25 (linhas 144-153) e marcados `[x]`. **INFRA-04** está corretamente FORA desta fase (mapeado para a fase 26). Nenhum requisito órfão.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `config/initializers/timezone_check.rb` | 22-35 | `raise` top-level sem guarda de contexto de build | 🛑 Blocker (CR-01) | `docker compose build` aborta no `assets:precompile` |
| `config/initializers/evolution.rb` | 9-16 | `after_initialize` sem guarda `SECRET_KEY_BASE_DUMMY` | 🛑 Blocker (CR-01) | idem — `Evolution.global_api_key` levanta no build |
| `docker-compose.yml` | 24-35, 51-61 | serviços de produção sem `CORS_ORIGINS` (obrigatória, sem fallback) | 🛑 Blocker (CR-02) | web/jobs `KeyError` → crash-loop |
| `.env.example` | — | `CORS_ORIGINS` ausente do contrato do operador | 🛑 Blocker (CR-02) | operador não consegue subir a stack |
| `app/services/evolution/client.rb` | 44-48, 36-39 | `resp.body.dig` / `.body` cru sem guarda de tipo | ⚠️ Warning (WR-07) | `TypeError` cru pode escapar em 2xx não-JSON |
| `app/services/evolution/client.rb` | 60-67 | `req.options.timeout` sombreado por `read_timeout` herdado | ⚠️ Warning (WR-01) | `READ_TIMEOUT_FAST` (15s) inerte — fast reads usam 30s |
| `docker-compose.yml` | 22-23 | `ports: 5881:3000` em 0.0.0.0 sem TLS, contorna Caddy | ⚠️ Warning (WR-02) | tráfego auth em HTTP puro na porta do host |
| `docker-compose.yml` | 45-64 | `jobs` corre com `web` no db:prepare do primeiro deploy | ⚠️ Warning (WR-03) | crash-loop transitório até `web` migrar |
| `bin/setup` | 28-41 | carga do queue_schema antes de `db:reset if --reset` | ⚠️ Warning (WR-06) | `bin/setup --reset` apaga as tabelas de fila |
| `config/storage.yml` | 17 | `ENV.fetch("S3_ENDPOINT")` + `.env.example` com `S3_ENDPOINT=` vazio | ⚠️ Warning (WR-04) | string vazia derrota o fallback de credentials |
| `docker-compose.yml` | 2-15 | `db` sem `TZ` pin (roda UTC) | ℹ️ Info (IN-05) | divergência de wall-clock em defaults SQL |
| `lib/tasks/storage_migration.rake` | 56 | backfill de `service_name` inclui blobs `missing` | ℹ️ Info (IN-06) | remove o caminho de recovery via Disk |

Nenhum marcador de dívida (`TODO`/`FIXME`/`XXX`/`HACK`) não-referenciado nos arquivos da fase.

### Human Verification Required

Status é `gaps_found` (regra 1 do decision tree tem precedência), então não há gate de
human-verify formal. Registrado para contexto do operador:

1. **Download real iniciado pelo host do Evolution + inbound `/up`** — carregado adiante (D-12 / A4). O 25-04 provou o download externo de uma vantagem fora de `192.168.3.203` via DNS público/Cloudflare (headers `HTTP/2 200`, `server: cloudflare` registrados); o download iniciado pelo próprio host do Evolution e o `curl -I /up` desse host acontecem na abertura da fase 26 / go-live.
2. **`docker compose build` + `docker compose up`** após aplicar os fixes de CR-01/CR-02 — confirmar que a imagem constrói e web+jobs sobem sem crash-loop.

### Gaps Summary

A fase entrega e prova o que o **enunciado do Goal** pede: costura HTTP única com o
Evolution real (fetch_instances → 200), mídia servida por presigned URL baixável de fora
da LAN (HTTP/2 200 de vantagem externa), e job agendado sobrevivendo a reinício em
development (timeline de 21s pós-restart). SC1-SC4 VERIFICADOS; EVO-01/02/03, INFRA-02,
INFRA-05 SATISFEITOS.

O que falha é a **topologia de deploy** — o escopo "+Deploy" ancorado nesta fase por D-09:

- **CR-01** (blocker): dois initializers novos desta fase levantam durante
  `assets:precompile` (RAILS_ENV=production, sem TZ/master.key no stage de build). Como
  `docker-compose.yml` usa `build: .`, a imagem de produção não constrói. Fix: guarda
  `ENV["SECRET_KEY_BASE_DUMMY"]` no topo de `timezone_check.rb` e no `after_initialize`
  de `evolution.rb`.
- **CR-02** (blocker): `web`/`jobs` nunca recebem `CORS_ORIGINS` e
  `config/application.rb` faz `ENV.fetch("CORS_ORIGINS")` sem fallback em produção →
  crash-loop. Fix: `CORS_ORIGINS: ${CORS_ORIGINS}` no `environment:` de web+jobs +
  a chave no `.env.example`.

Ambos são fixes de uma/duas linhas. Recomendação: `gaps_found` → plano de correção
`--gaps` curto cobrindo CR-01 + CR-02 (e, oportunamente, WR-01/WR-07 no client e
WR-02/WR-03/WR-06 na topologia), depois re-verificar antes da fase 26 / go-live.

---

_Verified: 2026-08-29_
_Verifier: Claude (gsd-verifier)_
