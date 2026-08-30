---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
plan: 03
subsystem: integrations
tags: [evolution-api, webhook, hmac, secure_compare, rack-attack]

requires:
  - phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
    provides: "WhatsappInstance.webhook_secret_for / .map_evolution_state (26-01), rota post /webhooks/evolution já registrada (26-01)"
provides:
  - "Webhooks::EvolutionController#create — receiver autenticado por HMAC, segredo comparado por secure_compare ANTES de qualquer WhatsappInstance.find_by (PAIR-06 literal)"
  - "Normalização de grafia de evento (dotcase/UPPER_SNAKE) reutilizando WhatsappInstance.map_evolution_state"
  - "Throttle Rack::Attack webhooks/evolution_by_ip (120/60s)"
affects: [26-04-verificao-manual-qr-refresh, 26-05-polimento-visual, 29-motor-de-envio]

actuals:
  tokens: 3300
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "secure_compare sempre sobre dois digests SHA256 (nunca os valores crus) — evita ArgumentError de comprimento vazando tamanho do segredo"
    - "Webhooks::EvolutionController < ActionController::API sem CSRF/sessão, mesmo precedente de Api::V1::BaseController"

key-files:
  created:
    - app/controllers/webhooks/evolution_controller.rb
    - test/controllers/webhooks/evolution_controller_test.rb
  modified:
    - config/initializers/rack_attack.rb
    - test/integration/rack_attack_test.rb
    - .planning/phases/26-inst-ncia-de-whatsapp-por-cliente-pareamento/deferred-items.md

key-decisions:
  - "secure_compare compara dois digests SHA256 (Digest::SHA256.hexdigest dos dois lados), nunca os valores crus — Pitfall 5, comprimento sempre 64 hex chars, ArgumentError estruturalmente impossível"
  - "throttle webhooks/evolution_by_ip cai no ramo HTML de throttled_responder (path não começa com /api/) — aceitável, chamador é máquina que ignora o corpo, fora do escopo mudar"
  - "Rack::Attack.cache.store.clear adicionado ao setup do teste do controller do webhook (mesmo padrão de settings/dashboard/ai controllers) — sem isso os testes herdavam contador de throttle de execuções anteriores na suíte paralela"

patterns-established:
  - "valid_signature? é sempre a primeira chamada de #create em qualquer controller de webhook futuro deste app"

requirements-completed: [PAIR-06]

coverage:
  - id: D1
    description: "Segredo comparado por secure_compare ANTES de qualquer consulta ao banco — provado com instance_name inexistente no banco + segredo errado ainda recebendo 401 (não 204)"
    requirement: "PAIR-06"
    verification:
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#segredo errado + instance_name inexistente no banco AINDA retorna 401"
        status: pass
      - kind: integration
        ref: "bin/rails runner — ActionDispatch::Integration::Session real contra a rota, mesma prova fora do harness de teste"
        status: pass
    human_judgment: false
  - id: D2
    description: "connection.update e CONNECTION_UPDATE (dotcase/upper-snake) convergem no mesmo resultado; state refused mapeia para disconnected"
    requirement: "PAIR-06"
    verification:
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#CONNECTION_UPDATE (upper-snake) produz o mesmo resultado que connection.update"
        status: pass
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#state refused mapeia para disconnected"
        status: pass
    human_judgment: false
  - id: D3
    description: "paired_at write-once — segunda reconexão state:open não sobrescreve"
    requirement: "PAIR-06"
    verification:
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#paired_at não é sobrescrito numa segunda reconexão state open"
        status: pass
    human_judgment: false
  - id: D4
    description: "qrcode.updated sem data.qrcode.base64 (limite de QR) é no-op silencioso, nunca NoMethodError; instância desconhecida e evento não tratado respondem 204/200 sem revelar existência"
    requirement: "PAIR-06"
    verification:
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#qrcode.updated sem data.qrcode.base64 (limite de QR atingido) é um no-op silencioso, não quebra"
        status: pass
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#segredo correto + instance_name desconhecido retorna 204 sem corpo"
        status: pass
      - kind: integration
        ref: "test/controllers/webhooks/evolution_controller_test.rb#evento não tratado (ex: messages.upsert) é um no-op, responde 200"
        status: pass
    human_judgment: false
  - id: D5
    description: "Nenhum Rails.logger neste arquivo referencia request.raw_post nem params.inspect"
    requirement: "PAIR-06"
    verification:
      - kind: unit
        ref: "ruby -e checagem estática da <verify> do plano sobre app/controllers/webhooks/evolution_controller.rb"
        status: pass
    human_judgment: false
  - id: D6
    description: "Throttle webhooks/evolution_by_ip (120/60s) protege o endpoint contra flood sem custo de HMAC correto"
    requirement: "PAIR-06"
    verification:
      - kind: integration
        ref: "test/integration/rack_attack_test.rb#120 primeiros POSTs ao webhook não retornam 429 / #121ª requisição ao webhook retorna 429"
        status: pass
    human_judgment: false
  - id: D7
    description: "Live inbound webhook round-trip (host Evolution real -> este app) — app ainda não está deployado publicamente nesta sessão"
    human_judgment: true
    rationale: "Ambiente sem rede para o host real do Evolution e app não deployado em ilhacriativa.autopyweb.com.br. Round-trip real é UAT/operador — verificado por request specs que exercitam a rota diretamente com headers/bodies forjados (idêntico ao que o host real enviaria), o que já cobre toda a lógica de guard HMAC-antes-do-banco e parsing de evento."

duration: ~25min
completed: 2026-08-30
status: complete
---

# Phase 26 Plan 03: Webhook Receiver Autenticado por HMAC Summary

**Webhooks::EvolutionController — HMAC secure_compare de dois digests SHA256 sempre antes de qualquer query, com normalização dotcase/UPPER_SNAKE de evento e write-once de paired_at, protegido por throttle dedicado de 120 req/min.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-30T13:32:03Z
- **Completed:** 2026-08-30T~13:57Z
- **Tasks:** 2
- **Files modified:** 5 (2 criados, 3 modificados)

## Accomplishments

- `Webhooks::EvolutionController#create` — primeira linha do método é `valid_signature?`, que recalcula o HMAC-SHA256 do `instance_name` (mesma fórmula de `WhatsappInstance.webhook_secret_for`, fonte única desde 26-01) e compara via `ActiveSupport::SecurityUtils.secure_compare` sobre dois digests SHA256 (nunca os valores crus — Pitfall 5). Segredo errado → `401` imediato, **antes** de qualquer `WhatsappInstance.find_by` rodar — provado dinamicamente com um `instance_name` que não existe no banco e um segredo errado, ainda assim recebendo 401 (não 204, o que provaria que a query rodou primeiro).
- Instância desconhecida (segredo certo, `instance_name` sem linha correspondente) responde `204 No Content` silencioso — idêntico ao comportamento de "evento não tratado", sem revelar a existência ou não de um cliente (Pitfall 9 / T-26-11).
- Normalização de evento (`event.to_s.tr(".-", "__").upcase`) aceita `connection.update` (dotcase, grafia real observada em research) e `CONNECTION_UPDATE` (upper-snake) como o mesmo evento — ambos convergem no mesmo `map_evolution_state` já extraído em 26-01 (nenhuma reimplementação do mapa).
- `connection.update` atualiza `connection_state` + `last_checked_at`; `paired_at` só é gravado na primeira vez que o webhook vê `state: "open"` (write-once, PAIR-08) — provado com duas chamadas reais ao endpoint, a segunda não altera o `paired_at` da primeira. `last_qr_base64` é limpo quando `state == "open"`.
- `qrcode.updated` sem `data.qrcode.base64` (limite de 30 QRs do Evolution atingido) é um no-op silencioso no campo `last_qr_base64` — nunca um `NoMethodError` (Pitfall 7).
- `messages.*` e qualquer evento futuro não mapeado caem no `else` (no-op, `head :ok`) — fase 29 trata `messages.*`.
- `throttle("webhooks/evolution_by_ip", limit: 120, period: 60)` adicionado a `config/initializers/rack_attack.rb`, mesmo estilo dos throttles existentes (`admin/login_by_ip`); provado com 120 POSTs sem 429 e o 121º com 429.
- Nenhum `Rails.logger` do arquivo referencia `request.raw_post` ou `params.inspect` — checagem estática incluída na `<verify>` do plano e reconfirmada.

## Task Commits

Each task was committed atomically:

1. **Task 1: Webhooks::EvolutionController — segredo antes do banco (PAIR-06)** - `ffeeb7d` (feat)
2. **Task 2: Throttle Rack::Attack para /webhooks/evolution** - `e94a6f3` (feat)
3. **Fix de isolamento de teste (Rule 1)** - `d29f448` (fix)

**Plan metadata:** commit pendente (docs, gerado após este SUMMARY)

## Files Created/Modified

- `app/controllers/webhooks/evolution_controller.rb` — receiver autenticado por HMAC (`#create`, `#valid_signature?`, `#apply_event`, `#apply_connection_update`, `#apply_qrcode_updated`)
- `test/controllers/webhooks/evolution_controller_test.rb` — 11 testes cobrindo o `<behavior>` inteiro do plano
- `config/initializers/rack_attack.rb` — `throttle("webhooks/evolution_by_ip", limit: 120, period: 60)`
- `test/integration/rack_attack_test.rb` — 2 testes novos (120 sem 429, 121ª com 429)
- `.planning/phases/26-inst-ncia-de-whatsapp-por-cliente-pareamento/deferred-items.md` — novo, registra 1 falha pré-existente fora do escopo

## Decisions Made

- `secure_compare` compara **dois digests SHA256** (`Digest::SHA256.hexdigest` dos dois lados), nunca os valores crus — Pitfall 5 do RESEARCH: comparar strings de comprimento diferente pode levantar `ArgumentError`, o que vazaria (via stack trace/500) informação sobre o tamanho do segredo esperado. Hasheados, o comprimento é sempre 64 hex chars, então o `ArgumentError` fica estruturalmente impossível.
- O throttle `webhooks/evolution_by_ip` cai no ramo HTML de `throttled_responder` (o path não começa com `/api/`) em vez do ramo JSON — aceitável e explicitamente fora do escopo desta fase (o chamador é uma máquina — o host Evolution — que não interpreta o corpo da resposta 429, só o status).
- `Rack::Attack.cache.store.clear` adicionado ao `setup` do teste do controller do webhook, seguindo o padrão já estabelecido em `settings_controller_test.rb`/`dashboard_controller_test.rb`/`api/v1/ai/*_controller_test.rb` — sem essa limpeza, os 11 testes do webhook herdavam o contador de throttle de execuções anteriores quando rodados junto com `rack_attack_test.rb` na mesma suíte paralela, produzindo 429 em vez do status esperado.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rack::Attack cache não limpo no setup do teste do webhook controller**
- **Found during:** Verificação final (rodando a suíte completa junto com o novo throttle da Task 2)
- **Issue:** `test/controllers/webhooks/evolution_controller_test.rb` não limpava `Rack::Attack.cache.store` no `setup`. Isolado, o arquivo passava (11/11); rodado junto com `test/integration/rack_attack_test.rb` (que soma 120+ POSTs ao mesmo endpoint) na mesma suíte paralela, os testes do webhook controller herdavam o contador do throttle e recebiam `429` em vez do status esperado.
- **Fix:** Adicionada `Rack::Attack.cache.store.clear if defined?(Rack::Attack)` no início do `setup`, mesmo padrão já usado em `settings_controller_test.rb`/`dashboard_controller_test.rb`/`api/v1/ai/*_controller_test.rb`.
- **Files modified:** `test/controllers/webhooks/evolution_controller_test.rb`
- **Verification:** suíte completa dos 5 arquivos relacionados rodada de novo — 56 testes, apenas a falha pré-existente documentada abaixo (não relacionada) permanece.
- **Committed in:** `d29f448`

---

**Total deviations:** 1 auto-fixado (Rule 1 — bug de isolamento de teste). **Impact on plan:** Nenhuma mudança de comportamento de produção; só corrige um falso-negativo de teste introduzido pela combinação das duas tasks deste próprio plano. Sem scope creep.

## Issues Encountered

- **Ambiente `bin/rails runner` + `ActionDispatch::Integration::Session` aninhada** (não código de produção): as duas `<verify>` dinâmicas do plano, escritas para rodar via `bin/rails runner`, precisaram dos mesmos 2 workarounds já documentados em `26-01-SUMMARY.md` deviation #4 — `session.host = "127.0.0.1"` (evita `ActionDispatch::HostAuthorization` bloqueando o host default `www.example.com`) e `ActiveRecord.query_transformers.delete(ActiveRecord::QueryLogs)` (evita `NoMethodError` em `ActiveSupport::ExecutionContext.to_h` dentro de uma `Integration::Session` aninhada num processo `runner`). Nenhuma mudança em código de produção — só nos scripts de verificação ad hoc (não commitados). O teste real do controller (`ActionDispatch::IntegrationTest`) não sofre esse problema e passou sem workarounds.
- **19 falhas pré-existentes em `bin/rails test` (suíte completa) não relacionadas a este plano** — mesmas falhas já documentadas em `26-01-SUMMARY.md` (`api/v1/ai/artes_controller_test.rb`, `api/v1/ai/clients_controller_test.rb`, `client/home_controller_test.rb`, `dashboard_controller_test.rb`, `approval_response_test.rb`, `arte_test.rb`), mais 1 nova identificada e registrada em `deferred-items.md` (`RackAttackTest#test_60_primeiras_requisições_ao_namespace_AI_não_retornam_429` — throttle por-IP de 30/min, phase 24, colide com o próprio nome do teste que assume 60 por-key; falha em isolamento, confirmado pré-existente via `git log` no arquivo). Nenhum desses arquivos está em `files_modified` deste plano.

## Live Webhook Round-Trip (Deferred — Explicitly Flagged)

**PENDENTE, não silenciosamente ignorado.** O round-trip real (host Evolution → `POST https://ilhacriativa.autopyweb.com.br/webhooks/evolution` → este app) **não pôde ser exercitado** nesta sessão pelos mesmos dois motivos já registrados em `evolution-contract.md` §"Deploy reachability": (1) este ambiente de execução não tem rede para o host real `whatsapp.bomcustoilhabela.com.br`; (2) o app ainda não está deployado publicamente em `ilhacriativa.autopyweb.com.br` (confirmado em `25-04-SUMMARY.md`/`evolution-contract.md` — "Inbound — Evolution host → app `/up`: NÃO EXECUTADO... CARREGADO ADIANTE (operador / fase 26)").

**O que cobre a lacuna:** os 11 request specs de `test/controllers/webhooks/evolution_controller_test.rb` exercitam a rota `POST /webhooks/evolution` diretamente via `ActionDispatch::IntegrationTest`, com headers e corpos forjados no shape exato documentado em `evolution-contract.md` (`event`/`instance`/`data.state`/`data.qrcode.base64`, ambas as grafias de evento). Isso cobre 100% da lógica do guard HMAC-antes-do-banco e do parsing de evento — o único elemento que um round-trip real acrescentaria é a confirmação de que o host Evolution real emite exatamente esses campos (já **VERIFICADO** em `evolution-contract.md` para o shape do envelope; o casing exato do `event` seguia **PENDENTE** e agora é irrelevante para a correção do código, já que o controller aceita as duas grafias).

**Fecha em:** UAT/operador pós-deploy da fase 26, conforme já carregado adiante pela fase 25. Não bloqueia o fechamento deste plano — PAIR-06 é sobre a ordem HMAC-antes-do-banco e a normalização de grafia, ambos provados dinamicamente aqui sem depender do host real.

## User Setup Required

None — nenhuma configuração de serviço externo neste plano. O round-trip real com o host Evolution depende do deploy público (já rastreado como pendência de operador desde a fase 25, não uma novidade deste plano).

## Next Phase Readiness

- PAIR-06 fechado e marcado completo em `REQUIREMENTS.md`.
- PAIR-03/PAIR-08 permanecem `Pending` (compartilhados com 26-04/26-05, shared-ID gate — só fecham quando o último plano que os declara terminar).
- `Webhooks::EvolutionController` está pronto para receber eventos reais assim que o app for deployado publicamente e o Evolution reapontar o webhook (26-01/26-02 já configuram `webhook_url` em toda criação/adoção de instância).
- Nenhum blocker aberto para 26-04 (verificação manual / QR refresh) ou 26-05 (polimento visual).

---
*Phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento*
*Completed: 2026-08-30*

## Self-Check: PASSED
