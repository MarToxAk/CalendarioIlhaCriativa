---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
plan: 04
subsystem: integrations
tags: [evolution-api, whatsapp, admin-panel, throttle, rails-cache]

requires:
  - phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
    provides: "WhatsappInstance model (map_evolution_state, connection_state enum), Evolution::Client#connection_state/#connect/#assert_open! (fase 25/26-01/26-02), Admin::WhatsappInstancesController#create/#adopt (26-01/26-02)"
provides:
  - "Admin::WhatsappInstancesController#verify — verificação manual SÍNCRONA e real (PAIR-05), nunca via job, nunca só cache"
  - "WhatsappInstance#connection_state_label — rótulo pt-BR por estado, reutilizável pelo controller e pela view (26-05)"
  - "Admin::WhatsappInstancesController#refresh_qr — endpoint JSON throttled (1 chamada Evolution a cada 15s por instância), pronto para o polling Stimulus do 26-05"
  - "Admin::WhatsappInstancesController#reconnect — força novo ciclo de QR (\"Parear novamente\")"
affects: [26-05-polimento-visual]

actuals:
  tokens: 3420
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "#verify grava o estado no banco ANTES de decidir a mensagem (assert_open! roda depois do update!, nunca antes) — uma leitura bem-sucedida com estado != open é diferente de uma falha de transporte"
    - "Rails.cache.write(key, true, unless_exist: true, expires_in: 15.seconds) como throttle server-side por instância — independe de quantos requests HTTP chegam"

key-files:
  created: []
  modified:
    - app/models/whatsapp_instance.rb
    - app/controllers/admin/whatsapp_instances_controller.rb
    - test/models/whatsapp_instance_test.rb
    - test/controllers/admin/whatsapp_instances_controller_test.rb

key-decisions:
  - "verify: falha de TRANSPORTE (exceção levantada pelo próprio connection_state) nunca toca o banco — connection_state/last_checked_at continuam com o último valor conhecido; um estado close/refused lido COM SUCESSO atualiza o banco normalmente, é um resultado válido, não uma falha"
  - "refresh_qr é a única ação JSON do controller — sempre render json:, mesmo quando pull_fresh_qr falha silenciosamente (o polling do Stimulus tenta de novo no próximo ciclo)"
  - "reconnect e o refresh_qr manual do 26-05 reaproveitam a mesma copy de erro ('Error — QR refresh failed') porque ambos chamam Evolution::Client.connect por baixo"

patterns-established:
  - "Throttle de custo externo via Rails.cache write+unless_exist, chave por-instância (wa_qr_pull_#{id}) — padrão reutilizável para qualquer endpoint polled no futuro"

requirements-completed: [PAIR-05]

coverage:
  - id: D1
    description: "Forçar verificação (#verify) é uma chamada síncrona real a Evolution::Client.connection_state (nunca job) que sempre reflete a verdade do Evolution quando o transporte funciona, e nunca mente sobre o estado quando o transporte falha"
    requirement: "PAIR-05"
    verification:
      - kind: unit
        ref: "ruby -e inspeção estática — update! roda antes de assert_open! dentro de #verify"
        status: pass
      - kind: integration
        ref: "bin/rails runner — Faraday stub levantando Evolution::Errors::Transient em connection_state; connection_state/last_checked_at NÃO mudam"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb — 3 cenários (open atualiza+notice, close atualiza+alert desconectada, transporte não avança)"
        status: pass
    human_judgment: false
  - id: D2
    description: "WhatsappInstance#connection_state_label cobre os 4 valores do enum connection_state com os rótulos pt-BR verbatim do UI-SPEC"
    requirement: "PAIR-05"
    verification:
      - kind: unit
        ref: "test/models/whatsapp_instance_test.rb#'connection_state_label covers the 4 enum values'"
        status: pass
    human_judgment: false
  - id: D3
    description: "refresh_qr responde sempre render json: (nunca HTML) e nunca dispara Evolution::Client.connect mais de 1x a cada 15s por instância, mesmo sob polling agressivo"
    requirement: "PAIR-03"
    verification:
      - kind: unit
        ref: "ruby -e inspeção estática — def refresh_qr contém render json: e unless_exist: true"
        status: pass
      - kind: integration
        ref: "bin/rails runner — 2 GETs seguidos a refresh_qr dentro de 15s -> Evolution::Client.connect chamado exatamente 1 vez"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb — QR em cache não chama connect, 2 polls -> 1 chamada, instância ausente responde unpaired sem 500"
        status: pass
    human_judgment: false
  - id: D4
    description: "reconnect (\"Parear novamente\") força um novo ciclo de QR, atualiza connection_state para awaiting_qr e grava o novo last_qr_base64; falha do Evolution não corrompe o estado exibido"
    requirement: "PAIR-03"
    verification:
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb — reconnect sucesso (awaiting_qr + novo QR) e reconnect com Evolution::Errors::Transient (estado inalterado + alert)"
        status: pass
    human_judgment: false

duration: ~10min
completed: 2026-08-30
status: complete
---

# Phase 26 Plan 04: Verificação Manual Síncrona (PAIR-05) + Backend refresh_qr/reconnect (PAIR-03) Summary

**`#verify` faz uma chamada síncrona real a `Evolution::Client.connection_state` dentro do próprio request e grava o estado real ANTES de decidir a mensagem; `#refresh_qr` throttla o custo Evolution a 1 chamada por instância a cada 15s via `Rails.cache`; `#reconnect` força um novo ciclo de QR — os três prontos para o Stimulus polling do 26-05 consumir.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T13:33:00Z (aprox.)
- **Completed:** 2026-08-30T13:43:00Z (aprox.)
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `WhatsappInstance#connection_state_label` — rótulo pt-BR por estado (`Aguardando criação` / `Aguardando pareamento` / `Conectada` / `Desconectada`), método puro sem contexto de origem (o sufixo "(adotada)" fica para a view no 26-05).
- `Admin::WhatsappInstancesController#verify` (PAIR-05) — chama `Evolution::Client.connection_state` de forma SÍNCRONA dentro do request (nunca `ActiveJob`), grava `connection_state`/`last_checked_at`/`paired_at` (write-once)/`last_qr_base64` SEMPRE que a leitura tem sucesso — mesmo quando o estado não é `open` — e só DEPOIS chama `Evolution::Client.assert_open!` para decidir qual mensagem mostrar. Uma falha de TRANSPORTE real (exceção levantada pelo próprio `connection_state`) nunca toca o banco: o estado exibido continua sendo o último valor conhecido.
- `Admin::WhatsappInstancesController#refresh_qr` (PAIR-03, backend) — única ação JSON do controller; `pull_fresh_qr` privado só prossegue quando `Rails.cache.write("wa_qr_pull_#{inst.id}", true, unless_exist: true, expires_in: 15.seconds)` consegue escrever a chave (ninguém puxou QR fresco nos últimos 15s), garantindo no máximo 1 chamada `Evolution::Client.connect` por instância a cada 15s independente de quantos requests HTTP chegarem. Falha do Evolution é silenciosa — o endpoint sempre responde com o que já está no banco.
- `Admin::WhatsappInstancesController#reconnect` ("Parear novamente") — força um novo ciclo de QR via `Evolution::Client.connect`, atualiza `connection_state` para `awaiting_qr` + `last_qr_base64` + `last_checked_at`, com a copy exata "Error — QR refresh failed" do UI-SPEC no caminho de erro.
- Testes: 4 estados de `connection_state_label`, 3 cenários de `#verify` (open/close/falha de transporte), 3 cenários de `#refresh_qr` (QR em cache não chama connect, throttle de 15s com contador de chamadas, instância ausente sem 500), 2 cenários de `#reconnect` (sucesso/falha).

## Task Commits

Each task was committed atomically:

1. **Task 1: #verify — verificação manual síncrona (PAIR-05)** - `908d3a9` (feat)
2. **Task 2: #refresh_qr (throttled) + #reconnect** - `45a803c` (feat)

**Plan metadata:** commit pendente (docs, gerado após este SUMMARY)

## Files Created/Modified

- `app/models/whatsapp_instance.rb` — `+connection_state_label`
- `app/controllers/admin/whatsapp_instances_controller.rb` — `+#verify`, `+#refresh_qr`, `+#reconnect`, `+pull_fresh_qr` (privado)
- `test/models/whatsapp_instance_test.rb` — +1 teste (4 asserções, um por estado)
- `test/controllers/admin/whatsapp_instances_controller_test.rb` — +8 testes (`#verify` × 3, `#refresh_qr` × 3, `#reconnect` × 2)

## Decisions Made

- **`#verify` grava antes de decidir a mensagem** — `inst.update!` roda incondicionalmente após uma leitura bem-sucedida de `connection_state` (seja `open`, `close`, ou qualquer outro valor mapeável), e só então `Evolution::Client.assert_open!(state)` decide se o fluxo segue para o `notice` de sucesso ou para o `rescue Evolution::Errors::NotConnected`. Isso separa claramente "a verificação funcionou e descobriu que está desconectado" (banco atualizado, alert específico) de "a verificação em si falhou" (banco intocado, alert genérico de transporte) — confirmado por dois testes de controller distintos além do runner do `<verify>` do plano.
- **`refresh_qr` nunca propaga erro do Evolution como 500** — `pull_fresh_qr` engole `Evolution::Errors::Transient/Unknown/Permanent/ConfigurationError` silenciosamente; o endpoint sempre responde com o estado atual do banco, e o polling do Stimulus (26-05) tenta de novo no próximo ciclo (~20s).
- **`reconnect` reaproveita a copy "Error — QR refresh failed"** do UI-SPEC, mesma mensagem do fluxo de `refresh_qr` manual planejado para o 26-05, porque os dois chamam `Evolution::Client.connect` por baixo e falham da mesma forma para o admin.

## Deviations from Plan

None - plano executado exatamente como especificado. Os dois `<verify>` automatizados de cada task (inspeção de código via `ruby -e` + simulação `bin/rails runner` com `ActionDispatch::Integration::Session` real) passaram sem ajuste na primeira tentativa, e a suíte de testes automatizados (`bin/rails test`) confirmou os quatro arquivos tocados sem regressão.

## Issues Encountered

- **19 falhas pré-existentes em `bin/rails test` (suíte completa) não relacionadas a este plano** — confirmado rodando a suíte completa (287 runs, 19 failures, 0 errors) e comparando com o baseline documentado nos SUMMARYs de 26-01/26-02 (mesmo conjunto: `api/v1/ai/*`, `integration/rack_attack_test.rb`, nenhum desses arquivos tocado por este plano). Não corrigidas — fora do escopo desta task por regra de escopo do executor.
- **`bin/rails runner` fora do harness de teste real** exige os mesmos 3 workarounds já documentados no 26-01-SUMMARY.md (`session.host = "127.0.0.1"`, remover `ActiveRecord::QueryLogs` dos `query_transformers`, `allow_forgery_protection = false`) para rodar `ActionDispatch::Integration::Session` dentro de um script ad hoc — nenhuma mudança em código de produção, exclusivo dos scripts de verificação em scratchpad.

## User Setup Required

None - nenhuma configuração de serviço externo neste plano.

## Next Phase Readiness

- PAIR-05 fechado e marcado completo em REQUIREMENTS.md.
- PAIR-03 permanece `Pending` — compartilhado com 26-01/26-02/26-03/26-05 (shared-ID gate: só fecha quando o ÚLTIMO plano que o declara, 26-05, entregar o polling Stimulus no frontend). O backend que o 26-05 vai consumir (`#refresh_qr` throttled + `#reconnect`) está pronto e testado.
- `WhatsappInstance#connection_state_label` está pronto para reuso direto na view do 26-05 (badge/dot colorido + texto), sem reimplementação.
- Nenhum blocker aberto para 26-05.

---
*Phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento*
*Completed: 2026-08-30*

## Self-Check: PASSED
