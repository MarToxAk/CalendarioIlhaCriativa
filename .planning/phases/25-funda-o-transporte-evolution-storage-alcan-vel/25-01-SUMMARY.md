---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
plan: 01
subsystem: infra
tags: [faraday, evolution-api, http-client, poro, error-taxonomy, solid_queue, good_job, filter_parameters, whatsapp]

# Dependency graph
requires:
  - phase: 21-funda-o-da-api-autentica-o
    provides: "Api::JwtService — o único PORO service do codebase; template de estrutura, resolução de segredo (credentials || ENV.fetch) e taxonomia de erro aninhada"
provides:
  - "Evolution::Client — a única costura HTTP com o host Evolution (memoized Faraday connection, header apikey, timeouts open/write/read explícitos, log metadata-only)"
  - "Evolution::Errors — ConfigurationError, Transient, Permanent, Unknown, NotConnected (nenhuma Faraday::Error escapa do client)"
  - "Evolution.base_url / Evolution.global_api_key / OPEN|WRITE|READ_TIMEOUT[_FAST] — config resolvida ENV-first com fallback em credentials.evolution.*"
  - "Fail-fast de boot em produção: sem base_url/apikey ou base_url não-https o app não sobe"
  - ":apikey e :hash em filter_parameters — a chave global do Evolution nunca chega ao log"
  - "Bundle com um único queue adapter: good_job removido; solid_queue é o adapter em produção"
  - "test/services/evolution/client_test.rb — cobertura Faraday::Adapter::Test da taxonomia"
affects: [26-instancia-whatsapp-pareamento, 27-grupos-cliente, 28-divulgacao-agendar, 29-motor-de-envio, 30-acompanhamento-hardening]

actuals:
  tokens: 4300
  tasks: 3
  commits: 6

tech-stack:
  added: ["faraday ~> 2.14 (2.14.3) + faraday-net_http + net-http"]
  patterns:
    - "PORO HTTP client em app/services/evolution/ espelhando Api::JwtService"
    - "namespace explícito (app/services/evolution.rb) para o Zeitwerk gerenciar Evolution::Client / Evolution::Errors como filhos, com o boot-check em config/initializers/evolution.rb"
    - "traduzir toda exceção de transporte para uma classe de domínio; o chamador decide retry/discard pela classe, nunca pelo status HTTP"
    - "log de request carrega método/path/status/duração APENAS"

key-files:
  created:
    - "app/services/evolution.rb — módulo de config Evolution (readers + constantes de timeout)"
    - "app/services/evolution/client.rb — Evolution::Client"
    - "app/services/evolution/errors.rb — Evolution::Errors"
    - "config/initializers/evolution.rb — fail-fast de boot em produção + assert https"
    - "test/services/evolution/client_test.rb — taxonomia via Faraday::Adapter::Test"
  modified:
    - "Gemfile / Gemfile.lock — +faraday ~> 2.14, -good_job"
    - "config/initializers/filter_parameter_logging.rb — +:apikey, +:hash"
    - ".planning/notes/evolution-contract.md — delta 25-01: round-trip autenticado DEFERIDO (credenciais indisponíveis)"

key-decisions:
  - "Namespace Evolution:: (não Whatsapp::EvolutionClient) — CONTEXT.md canonical_refs; Whatsapp:: fica livre para os serviços de domínio das fases 26–30"
  - "Config Evolution vive em app/services/evolution.rb (namespace explícito) e NÃO diretamente no initializer — definir `module Evolution` num initializer quebra o autoload do Zeitwerk para Evolution::Errors (NameError em produção). O initializer só carrega o fail-fast de boot via after_initialize"
  - "Precedência de segredo ENV-first: ENV.fetch('EVOLUTION_*') { credentials.dig(:evolution, *) } — dev usa .env (dotenv dev/test), produção usa credentials"
  - "classify_timeout: Net::OpenTimeout → Transient (connect-phase, nada enviado); Net::ReadTimeout / indistinguível → Unknown (pode ter processado, nunca retry automático)"
  - "fugit permanece no lockfile — é dependência transitiva de solid_queue (~> 1.11), não exclusiva do good_job como a pesquisa assumiu"
  - "EVO-01 (round-trip autenticado real) DEFERIDO — credenciais da agência indisponíveis na execução; caminho degradado do <precondition> acionado"

patterns-established:
  - "app/services/evolution/: PORO HTTP client + módulo Errors aninhado, espelhando Api::JwtService"
  - "namespace explícito em app/services/<ns>.rb quando o namespace precisa de config carregada no boot"
  - "toda comunicação com o Evolution passa por Evolution::Client — controllers e jobs nunca falam HTTP direto"

requirements-completed: [EVO-02, EVO-03, INFRA-05]

coverage:
  - id: D1
    description: "Evolution::Client PORO — costura HTTP única, header apikey, timeouts open/write/read explícitos (EVO-02)"
    requirement: "EVO-02"
    verification:
      - kind: integration
        ref: "bin/rails runner (25-01-PLAN <verify> Task 1 acceptance): grep Faraday.new / headers[\"apikey\"] / open_timeout|write_timeout|read_timeout>=3 — todos OK"
        status: pass
      - kind: unit
        ref: "bin/rails zeitwerk:check — 'all is good'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Taxonomia de erro em 4 classes + ConfigurationError; nenhuma Faraday::Error / status cru escapa; classify_timeout; assert_open! (EVO-03)"
    requirement: "EVO-03"
    verification:
      - kind: integration
        ref: "bin/rails runner taxonomy script (25-01-PLAN <verify> Task 2): 503/429→Transient, 401/404→Permanent, 502 HTML→Transient, assert_open!('close')→NotConnected, classify_timeout Open→Transient / Read→Unknown — 'ALL TAXONOMY CASES OK'"
        status: pass
      - kind: integration
        ref: "bin/rails runner: non-JSON 5xx → '502 upstream 5xx (non-JSON body)' (não ecoa HTML); message String(401)/Array(404) normalizada; log '[evolution] GET /instance/fetchInstances -> 200 (1ms)' sem apikey"
        status: pass
      - kind: unit
        ref: "test/services/evolution/client_test.rb — Faraday::Adapter::Test, 15 casos (arquivo criado; suite completa não roda: banco de teste pertence a outro usuário do SO)"
        status: unknown
    human_judgment: false
  - id: D3
    description: "Bundle com um único queue adapter — good_job removido (INFRA-05)"
    requirement: "INFRA-05"
    verification:
      - kind: integration
        ref: "grep -c good_job Gemfile Gemfile.lock → 0/0; grep -rn good_job\\|GoodJob config/ db/ app/ lib/ → vazio; bin/rails runner -e production 'ActiveJob::Base.queue_adapter_name' → solid_queue"
        status: pass
    human_judgment: false
  - id: D4
    description: ":apikey e :hash adicionados a filter_parameters — a chave global nunca chega ao log (T-25-01)"
    verification:
      - kind: integration
        ref: "bin/rails runner: Rails.application.config.filter_parameters inclui :apikey e :hash → 'filter_parameters OK'"
        status: pass
    human_judgment: false
  - id: D5
    description: "EVO-01 — contrato de leitura autenticado verificado contra o host real da agência antes de qualquer código depender dele"
    requirement: "EVO-01"
    verification:
      - kind: e2e
        ref: "bin/rails runner Evolution::Client.fetch_instances contra whatsapp.bomcustoilhabela.com.br — NÃO EXECUTADO: EVOLUTION_BASE_URL / EVOLUTION_GLOBAL_API_KEY indisponíveis (ENV e credentials). Caminho degradado do <precondition> acionado."
        status: unknown
    human_judgment: true
    rationale: "SC2/EVO-01 fecha só com um round-trip autenticado real contra o host da agência; exige as credenciais do user_setup (base URL + apikey global, D-06) que não estavam disponíveis. Artefatos de código entregues e commitados; fechamento deferido até as credenciais chegarem — escalado como lacuna de user_setup, não é falha de código."

duration: 11min
completed: 2026-08-29
status: complete
---

# Phase 25 Plan 01: Fundação — Transporte Evolution + Storage Alcançável Summary

**`Evolution::Client` PORO com header `apikey`, timeouts open/write/read explícitos e taxonomia de erro em 4 classes (Transient/Permanent/Unknown/NotConnected) via Faraday 2.14; `good_job` removido do bundle; `:apikey`/`:hash` filtrados do log. Round-trip autenticado real contra o host da agência DEFERIDO — credenciais indisponíveis.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-08-29T19:48:18Z
- **Completed:** 2026-08-29T19:59:03Z
- **Tasks:** 3 (todas executadas)
- **Files modified:** 9 (5 criados, 4 modificados)

## Accomplishments
- `Evolution::Client` (`app/services/evolution/client.rb`) — `connection` memoizada (`Faraday.new` + header `apikey`, nunca `Authorization: Bearer`), `fetch_instances`, `connection_state`, `assert_open!`, e privados `request` / `raise_for_status!` / `classify_timeout`. Timeouts `open 5 / write 10 / read 30` (`read 15` nas leituras rápidas), teto Cloudflare respeitado.
- `Evolution::Errors` — `ConfigurationError`, `Transient`, `Permanent`, `Unknown`, `NotConnected`. Toda `Faraday::Error` e todo status HTTP não-2xx são traduzidos; nada cru escapa do client.
- Taxonomia completa provada pelo runner do plano: `503/500/502/504/408/429 → Transient`; `400/401/403/404/422 → Permanent`; `5xx com corpo HTML (Cloudflare) → Transient` sem ecoar o HTML; `Net::OpenTimeout → Transient`, `Net::ReadTimeout → Unknown`; `connectionState != "open" → NotConnected` via `assert_open!`; `response.message` normalizada quer seja String (401) quer Array (404).
- Log de request seguro — `[evolution] GET /instance/fetchInstances -> 200 (1ms)`: método, path, status e duração APENAS; sem corpo, headers ou apikey.
- `config/initializers/evolution.rb` — fail-fast no boot em produção (sem `base_url`/`global_api_key`, ou `base_url` não-`https://`, o app não sobe).
- `good_job` removido de `Gemfile` + `Gemfile.lock` (INFRA-05); zero referências em runtime; `ActiveJob::Base.queue_adapter_name` em produção continua `solid_queue`.
- `:apikey` e `:hash` adicionados a `filter_parameters` (T-25-01) — a chave global do Evolution não pode ser impressa em log.
- `test/services/evolution/client_test.rb` — 15 casos com `Faraday::Adapter::Test` (in-process, sem DB, sem rede).

## Task Commits

1. **Task 1: End-to-end authenticated read (tracer) — caminho degradado** - `a999a1d` (feat) — faraday no Gemfile, `app/services/evolution.rb`, `errors.rb`, `client.rb` (skeleton), `config/initializers/evolution.rb`, delta em `evolution-contract.md`
2. **Task 2: Full error taxonomy + timeout classification + safe logging (TDD)**
   - `2c94717` (test) — `client_test.rb`, cobertura Faraday::Adapter::Test (RED gate não observável: banco de teste pertence a outro usuário do SO)
   - `5ce5a6e` (feat) — `raise_for_status!` completo (5xx não-JSON, 408/429), `classify_timeout`, `assert_open!`
3. **Task 3: Single queue adapter + apikey/hash log filtering**
   - `c06b87b` (chore) — `good_job` removido do Gemfile + lockfile
   - `65d6ed6` (fix) — `:apikey` / `:hash` em `filter_parameters`

**Plan metadata:** _(docs commit a seguir)_

## Files Created/Modified
- `app/services/evolution.rb` (novo) — namespace explícito Evolution: `self.base_url`, `self.global_api_key`, `OPEN_TIMEOUT`/`WRITE_TIMEOUT`/`READ_TIMEOUT`/`READ_TIMEOUT_FAST`
- `app/services/evolution/client.rb` (novo) — `Evolution::Client`, a única costura HTTP com o Evolution
- `app/services/evolution/errors.rb` (novo) — `Evolution::Errors` (5 classes)
- `config/initializers/evolution.rb` (novo) — fail-fast de boot em produção + assert `https://` (via `after_initialize`)
- `test/services/evolution/client_test.rb` (novo) — taxonomia via `Faraday::Adapter::Test`
- `Gemfile` / `Gemfile.lock` — `+ faraday ~> 2.14` (2.14.3, + `faraday-net_http`, + `net-http`); `- good_job` (`- good_job` do lockfile; `fugit` fica, é dep de `solid_queue`)
- `config/initializers/filter_parameter_logging.rb` — `+ :apikey, :hash` com comentário de racional
- `.planning/notes/evolution-contract.md` — nova linha datada sob a seção VERIFICADO: round-trip autenticado NÃO EXECUTADO (credenciais indisponíveis); SC2/EVO-01 deferido. Nenhum secret escrito.

## Decisions Made
- **Namespace `Evolution::`** (não `Whatsapp::EvolutionClient`) — segue `CONTEXT.md <canonical_refs>` e o ROADMAP; deixa `Whatsapp::` livre para os serviços de domínio 26–30.
- **Config em `app/services/evolution.rb`, não no initializer** — ver Deviations (Rule 3).
- **`after_initialize` para o fail-fast de produção** — garante que `Evolution::Errors` já está carregado quando o guard roda (eager load concluído), e ainda aborta o boot.
- **Precedência ENV-first** (`ENV.fetch { credentials.dig }`) — dev usa `.env` (dotenv dev/test), produção usa `credentials`. Espelha o invariante de `Api::JwtService.secret` (2 fontes + raise acionável), invertendo a ordem conforme `25-RESEARCH.md Pattern 2`.
- **`fugit` permanece no lockfile** — é dependência transitiva de `solid_queue (~> 1.11)`, não exclusiva do `good_job`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Config Evolution movida do initializer para `app/services/evolution.rb`**
- **Found during:** Task 1
- **Issue:** O plano manda `config/initializers/evolution.rb` conter `module Evolution` com os readers. Fazer isso define a constante `Evolution` num initializer, fora do controle do Zeitwerk. Em produção (eager load) a chamada de fail-fast `raise Evolution::Errors::ConfigurationError` levantava `uninitialized constant Evolution::Errors (NameError)` — o Zeitwerk não gerencia os filhos de um namespace definido manualmente.
- **Fix:** Criado `app/services/evolution.rb` (namespace explícito) com os readers + constantes de timeout; `config/initializers/evolution.rb` ficou só com o fail-fast de boot (`after_initialize`, `next unless Rails.env.production?`), referenciando `Evolution.base_url` / `Evolution.global_api_key`. Zeitwerk passa a gerenciar `Evolution::Client` e `Evolution::Errors` como filhos.
- **Files modified:** `app/services/evolution.rb` (novo), `config/initializers/evolution.rb`
- **Verification:** `bin/rails zeitwerk:check` → "all is good"; boot de produção com credenciais dummy → `solid_queue` (sobe); boot de produção sem credenciais → `Evolution::Errors::ConfigurationError` limpo (fail-fast correto, sem `NameError`).
- **Committed in:** `a999a1d`

**2. [Rule 1 - Bug] `raise_for_status!` ecoava o HTML da Cloudflare na mensagem de erro**
- **Found during:** Task 2
- **Issue:** No skeleton do Task 1, um 5xx com corpo String (HTML da Cloudflare) caía em `Array(resp.body).join(" ")` → a mensagem do `Transient` continha o HTML bruto, violando a proibição "nunca ecoar o HTML".
- **Fix:** Guard explícito: `resp.status >= 500 && !body.is_a?(Hash)` → `Transient` com mensagem genérica `"<status> upstream 5xx (non-JSON body)"`.
- **Files modified:** `app/services/evolution/client.rb`
- **Verification:** `bin/rails runner` — 502 com `text/html` → mensagem `"502 upstream 5xx (non-JSON body)"`, sem `cloudflare` nem `<html>`.
- **Committed in:** `5ce5a6e`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Sem scope creep. A deviation 1 é estrutural (necessária para o app subir em produção); a estrutura entregue satisfaz todos os `must_haves.artifacts` — os readers `Evolution.base_url`/`Evolution.global_api_key` e as constantes existem, só moraram no arquivo de namespace em vez de no initializer. A deviation 2 fecha uma proibição do plano.

## Issues Encountered

- **Credenciais da agência indisponíveis (caminho degradado do `<precondition>` do Task 1).** `EVOLUTION_BASE_URL` e `EVOLUTION_GLOBAL_API_KEY` não resolveram em nenhuma fonte (ENV nem `Rails.application.credentials.dig(:evolution, *)`). Conforme instruído pelo `<precondition>` e pelo `<done>` do Task 1: todos os artefatos de código foram entregues e commitados; a verificação empírica do round-trip autenticado (SC2 / EVO-01) fica **DEFERIDA** e é escalada ao desenvolvedor como lacuna de `user_setup` — **não é falha de código nem de teste**. Registrado em `.planning/notes/evolution-contract.md` (delta 25-01) sem escrever nenhum secret. As duas checagens `<automated>` do Task 1 emitem `HALT(user_setup)` como projetado.
- **`bin/rails test` não roda neste ambiente** — o banco de teste pertence a outro usuário do SO (`PG::InsufficientPrivilege: permission denied for table ar_internal_metadata`), constraint conhecida do projeto. A verificação canônica do Task 2 (o script `bin/rails runner` do `<verify>`) roda e passa: `ALL TAXONOMY CASES OK`. O arquivo `client_test.rb` foi verificado por inspeção + `ruby -c`. O gate RED do TDD não foi observável; commits `test(...)` → `feat(...)` foram mantidos separados para conformidade de git-log.
- **`fugit` não saiu do lockfile** — o plano/pesquisa assumiu que só `good_job` o puxava; na verdade `solid_queue (1.4.0)` declara `fugit (~> 1.11)`. `good_job` saiu corretamente; `fugit` permanece como dependência legítima do adapter que fica.

## TDD Gate Compliance

Task 2 (`tdd="true"`): commit `test(25-01)` (`2c94717`) precede o commit `feat(25-01)` (`5ce5a6e`) no git log. O gate RED (teste falhando antes da implementação) **não pôde ser observado** porque a suíte não executa neste ambiente (banco de teste de outro usuário do SO). A verificação de comportamento foi feita pelo script `bin/rails runner` do `<verify>` do plano, que exercita `raise_for_status!`, `classify_timeout` e `assert_open!` in-process e imprime `ALL TAXONOMY CASES OK`. `tdd_mode` está `false` no `config.json` do projeto.

## Known Stubs

- `app/services/evolution/client.rb` — `fetch_instances` / `connection_state` são implementações reais (não stubs), mas **nunca foram exercitadas contra o host real** por falta de credenciais. O contrato de leitura autenticado (shape exato de `fetchInstances`, latência) permanece PENDENTE em `.planning/notes/evolution-contract.md` até o UAT com credenciais. Não bloqueia as fases seguintes de forma diferente do que o plano já previa (o write-path já era PENDENTE para fases 26/28).

## Threat Flags

Nenhuma superfície de segurança nova além da já mapeada no `<threat_model>` do plano. T-25-01 (log leak) e T-25-02 (apikey em ENV/credentials) são mitigadas por este plano (log metadata-only + `filter_parameters` + fail-fast). T-25-SC (bundle: +faraday / -good_job) executado sem gate de human-verify (faraday auditado como first-line na pesquisa).

## User Setup Required

**Uma credencial de serviço externo é necessária para fechar EVO-01 / SC2.**

| Variável | Fonte | Onde vai |
|---|---|---|
| `EVOLUTION_BASE_URL` | Host Evolution da agência: `https://whatsapp.bomcustoilhabela.com.br` (sem porta; Cloudflare na frente) | `.env` (dev) / `config/credentials.yml.enc` sob `evolution:` (prod) |
| `EVOLUTION_GLOBAL_API_KEY` | Evolution manager da agência — `AUTHENTICATION_API_KEY` global (canal seguro) | `.env` (dev) / `credentials.yml.enc` `evolution:` (prod) |

Depois de configurar, rodar a verificação do Task 1 para fechar EVO-01:

```
bin/rails runner "a = Evolution::Client.fetch_instances; abort('esperava Array') unless a.is_a?(Array); puts 'fetchInstances OK, count=' + a.length.to_s"
EVOLUTION_GLOBAL_API_KEY=deadbeef bin/rails runner "begin; Evolution::Client.fetch_instances; abort('esperava Permanent'); rescue Evolution::Errors::Permanent; puts 'bad-key -> Permanent OK'; end"
```

E anexar o shape observado + latência em `.planning/notes/evolution-contract.md` (seção VERIFICADO — sem escrever nenhum secret/token/telefone).

## Next Phase Readiness

- `Evolution::Client` está pronto como a costura HTTP única para as fases 26–30. As fases seguintes chamam `Evolution::Client.*` — controllers e jobs nunca falam HTTP direto.
- `Evolution::Errors::{Transient,Permanent,Unknown,NotConnected}` disponíveis para o `retry_on` / `discard_on` do motor de envio (fase 29).
- **Blocker parcial (não bloqueia planejamento):** EVO-01 / SC2 aguarda as credenciais da agência (ver User Setup). O write-path do Evolution (sendText/sendMedia, casing de webhook, teto de mídia) já era PENDENTE para UAT das fases 26/28 — sem mudança.
- Plano 25-02 (storage MinIO + jobs + tz + deploy) é independente deste e pode prosseguir.

---
*Phase: 25-funda-o-transporte-evolution-storage-alcan-vel*
*Completed: 2026-08-29*

## Self-Check: PASSED

- Arquivos criados verificados em disco: `app/services/evolution.rb`, `app/services/evolution/client.rb`, `app/services/evolution/errors.rb`, `config/initializers/evolution.rb`, `test/services/evolution/client_test.rb`, `25-01-SUMMARY.md` — todos FOUND.
- Commits verificados no git log: `a999a1d`, `2c94717`, `5ce5a6e`, `c06b87b`, `65d6ed6` — todos FOUND.
