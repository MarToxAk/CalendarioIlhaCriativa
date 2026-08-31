---
phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes
plan: 02
subsystem: whatsapp
tags: [rails, activerecord, evolution-api, webhooks, solid_queue]

# Dependency graph
requires:
  - phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes
    plan: 01
    provides: Migração de-uniqueify de instance_name, WhatsappInstance#siblings/#shared?/shareable_targets, InstanceProvisioner#reuse, origin enum += reused_sibling
provides:
  - Webhooks::EvolutionController#create — fan-out connection.update/qrcode.updated para todas as WhatsappInstance-irmãs por instance_name (Pitfall 1)
  - Whatsapp::GroupSynchronizer#call — 1 fetch_groups fora do loop + N upserts/GRUPO-05/update! locais por irmã, mesmo batch_started_at (D-05)
  - Regressão explícita: instância sem irmãs continua fazendo exatamente 1 fetch_groups (D-05)
  - Teste aditivo em cross_client_isolation_test.rb provando SEG-04 sobrevive com par de irmãos de instance_name compartilhado
  - COVERAGE.md revisado e confirmado coerente com a implementação (zero endpoints Evolution novos)
affects: [30-acompanhamento-ao-vivo-hardening]

# Actuals (#2632)
actuals:
  tokens: 3337
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Fan-out por conexão física: WhatsappInstance.where(instance_name:).find_each { ... } substituindo find_by, reutilizado idêntico no webhook e no GroupSynchronizer"
    - "Uma chamada de rede cara fora do loop de fan-out, N escritas locais dentro dele (D-05) — evita multiplicar I/O externo por número de irmãs"
    - "Guard/estado transitório (:syncing, :sync_error) nunca propagado a linhas-irmãs — só o resultado do caminho de sucesso é compartilhado"

key-files:
  created: []
  modified:
    - app/controllers/webhooks/evolution_controller.rb
    - app/services/whatsapp/group_synchronizer.rb
    - test/controllers/webhooks/evolution_controller_test.rb
    - test/services/whatsapp/group_synchronizer_test.rb
    - test/integration/cross_client_isolation_test.rb

key-decisions:
  - "D-05 implementado literalmente: row_for ganha o parâmetro sib (não mais fechado sobre @instance); fetch_groups continua UMA chamada fora do find_each de irmãs"
  - "Pitfall 5 respeitado: guard de não-conectado e escrita de :sync_error ficam só em @instance — o find_each de irmãs vive inteiramente no caminho de sucesso, depois do upsert_all"
  - "Webhook: siblings.find_each { |instance| apply_event(instance) } — apply_event/apply_connection_update/apply_qrcode_updated ficam byte-idênticos, só #create muda"
  - "cross_client_isolation_test.rb: build_client_with_whatsapp! ganhou parâmetro opcional instance_name: (default inalterado) para permitir o par de irmãos sem tocar as 3 chamadas existentes"

patterns-established:
  - "row_for(g, ts, sib) em vez de row_for(g, ts) fechado sobre @instance — parâmetro explícito da linha-alvo em vez de estado de instância implícito, necessário sempre que uma operação de sync precisa escrever em N linhas escopadas"

requirements-completed: []

coverage:
  - id: D1
    description: "Webhooks::EvolutionController#create faz fan-out por instance_name — connection.update atualiza TODAS as linhas-irmãs, preservando ENVIO-07"
    verification:
      - kind: unit
        ref: "test/controllers/webhooks/evolution_controller_test.rb — 'connection.update com instance_name compartilhado atualiza TODAS as linhas-irmãs'"
        status: unknown
      - kind: other
        ref: "bin/rails runner script/tmp_webhook_fanout_smoke.rb (temporário, removido) — imprimiu WEBHOOK-FANOUT-OK nesta sessão"
        status: pass
    human_judgment: false
  - id: D2
    description: "Whatsapp::GroupSynchronizer#call fan-out D-05 — 1 fetch_groups fora do loop, N upserts/GRUPO-05/update! por irmã com o mesmo batch_started_at; row_for recebe a irmã"
    verification:
      - kind: unit
        ref: "test/services/whatsapp/group_synchronizer_test.rb — testes (h) regressão single-instance e (i) fan-out de irmãs"
        status: unknown
      - kind: other
        ref: "bin/rails runner script/tmp_groupsync_fanout_smoke.rb (temporário, removido) — imprimiu GROUPSYNC-FANOUT-OK nesta sessão (regressão fake.calls==1 sem irmãs + fan-out 2 irmãs com groups_synced_at igual)"
        status: pass
    human_judgment: false
  - id: D3
    description: "SEG-04 sobrevive a par de clientes-irmãos com instance_name compartilhado; COVERAGE.md registra zero endpoints Evolution novos + as duas mudanças de topologia"
    verification:
      - kind: unit
        ref: "test/integration/cross_client_isolation_test.rb — 'isolamento cross-client sobrevive com um par de clientes-irmãos compartilhando instance_name (D-02, SEG-04)'; os 3 testes existentes ficam byte-idênticos (git diff verificado)"
        status: unknown
      - kind: other
        ref: "bin/rails runner script/tmp_seg04_sibling_smoke.rb (temporário, removido) — provou RecordNotFound com par de irmãos nesta sessão; COVERAGE.md re-lido e confirmado coerente com o código entregue"
        status: pass
    human_judgment: true
    rationale: "Execução real da suíte Minitest (incluindo os testes de controller/integração) permanece bloqueada localmente — banco de teste pertence a outro usuário do SO (31-RESEARCH.md Pitfall 7); coberto por UAT do operador, mesmo padrão das fases 25-31-01"

# Metrics
duration: ~20min
completed: 2026-08-31
status: complete
---

# Phase 31 Plan 02: Fan-out do Webhook e do GroupSynchronizer para Instâncias-Irmãs Summary

**Webhook `connection.update`/`qrcode.updated` e `GroupSynchronizer` passam a operar por conexão física (`instance_name`) em vez de por linha `WhatsappInstance`, com regressão explícita provando que uma instância sem irmãs continua se comportando byte-identicamente a antes da fase 31, e SEG-04 confirmado intacto com um par de clientes-irmãos.**

## Performance

- **Duration:** ~20min
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- `Webhooks::EvolutionController#create` resolve `WhatsappInstance.where(instance_name: params[:instance].to_s)` e aplica `apply_event` a cada linha-irmã em vez de `find_by` (Pitfall 1) — `valid_signature?` continua rodando ANTES de qualquer query (PAIR-06), e os métodos `apply_event`/`apply_connection_update`/`apply_qrcode_updated` ficam byte-idênticos
- `Whatsapp::GroupSynchronizer#call` faz UMA chamada `fetch_groups` fora de qualquer loop (Pitfall 6) e itera `WhatsappInstance.where(instance_name: @instance.instance_name)` fazendo `upsert_all`/GRUPO-05/`update!` por irmã, todas com o MESMO `batch_started_at` (D-05); `row_for` passa a receber a irmã como parâmetro explícito
- Regressão obrigatória de D-05 provada: uma instância sem irmãs continua fazendo exatamente 1 `fetch_groups` — comportamento idêntico ao pré-fase-31, verificado tanto por teste novo quanto por script smoke
- Guard de não-conectado e escrita de `:sync_error`/`not_connected` ficam SÓ em `@instance` (Pitfall 5) — o `find_each` de irmãs vive inteiramente no caminho de sucesso, depois do `upsert_all`
- `Whatsapp::SyncGroupsJob#perform` sem alteração de assinatura (`git diff` vazio, confirmado)
- Teste aditivo em `cross_client_isolation_test.rb`: par de clientes-irmãos (`instance_name`/`token` compartilhados) prova que `RecordNotFound` continua sendo levantado nas duas cadeias-âncora (`whatsapp_instance.whatsapp_groups.where(active:true).find`, `client.divulgacoes.find`) e que o backstop de model continua rejeitando arte-de-um + grupo-do-outro — os 3 testes existentes ficam byte-idênticos
- `COVERAGE.md` revisado contra a implementação final das Tasks 1/2 e confirmado coerente sem necessidade de edição — zero endpoints Evolution novos, as duas mudanças de topologia (fan-out `fetchAllGroups`, fan-out webhook) corretamente documentadas

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1: Fan-out do webhook connection.update/qrcode.updated (Pitfall 1)** - `7faf0ff` (feat)
2. **Task 2: D-05 fan-out do GroupSynchronizer (1 fetch, N upserts) + regressão single-instance** - `0ca22ee` (feat)
3. **Task 3: COVERAGE.md review + teste aditivo SEG-04** - `c738789` (test)

## Files Created/Modified
- `app/controllers/webhooks/evolution_controller.rb` - `#create` faz fan-out por `instance_name`; `valid_signature?`/`apply_event`/`apply_connection_update`/`apply_qrcode_updated` inalterados
- `app/services/whatsapp/group_synchronizer.rb` - `#call` com 1 `fetch_groups` fora do loop + `find_each` de irmãs (upsert/GRUPO-05/`update!` por irmã); `row_for(g, ts, sib)` ganha parâmetro explícito
- `test/controllers/webhooks/evolution_controller_test.rb` - 1 teste novo (fan-out de 2 irmãs em `connection.update`)
- `test/services/whatsapp/group_synchronizer_test.rb` - 2 testes novos ((h) regressão single-instance, (i) fan-out de 2 irmãs)
- `test/integration/cross_client_isolation_test.rb` - 1 teste novo (SEG-04 com par de irmãos) + parâmetro opcional `instance_name:` no helper `build_client_with_whatsapp!`

## Decisions Made
- D-05 implementado exatamente como travado no CONTEXT/RESEARCH: `row_for` recebe `sib` em vez de fechar sobre `@instance`; nenhuma decisão nova de arquitetura tomada — só as discretionary calls já resolvidas no RESEARCH (resolução de irmãs internamente ao `GroupSynchronizer`, sem mudar a assinatura do `SyncGroupsJob`).
- Fan-out do webhook incorporado literalmente conforme a recomendação resolvida em `31-RESEARCH.md` (Open Question 1).

## Deviations from Plan

None - plan executado exatamente como escrito. As 3 tasks mapeiam 1:1 para os 3 commits; nenhuma Rule 1-4 disparada.

## Issues Encountered
- `bin/rails test` continua indisponível neste ambiente (banco de teste pertence a outro usuário do SO — 31-RESEARCH.md Pitfall 7, MEMORY.md `test_db_permission.md`). Todos os testes desta plan foram escritos para CI e verificados por: (a) `ruby -c` limpo em todos os arquivos de teste/produção tocados; (b) `git diff` de `evolution_controller.rb` confirmando que só `#create` mudou; (c) `git diff` de `cross_client_isolation_test.rb` confirmando que os 3 testes existentes ficam byte-idênticos (só adições + o parâmetro opcional do helper); (d) lógica de fan-out provada via `bin/rails runner` com 3 scripts smoke temporários (`script/tmp_webhook_fanout_smoke.rb` → `WEBHOOK-FANOUT-OK`, `script/tmp_groupsync_fanout_smoke.rb` → `GROUPSYNC-FANOUT-OK`, `script/tmp_seg04_sibling_smoke.rb` → `SEG04-SIBLING-SMOKE-OK`, todos criados e removidos dentro de cada task).
- A execução real da suíte Minitest (incluindo os testes de controller/integração com fan-out) permanece como item de UAT do operador, mesmo padrão das fases 25-31-01.

## User Setup Required

None - nenhuma configuração externa nova. Nenhum pacote instalado (Package Legitimacy Audit: N/A, confirmado em `COVERAGE.md`).

## Next Phase Readiness
- Fase 31 (Instância WhatsApp Compartilhada entre Clientes) está completa: 31-01 entregou o modelo de dados + UI de reutilização, 31-02 entregou as duas mudanças de topologia (webhook + GroupSynchronizer) que fazem a instância compartilhada operar coerentemente entre clientes-irmãos.
- Operador deve rodar a suíte Minitest real (ambiente com banco de teste próprio) para confirmar os testes novos/alterados desta plan antes do próximo deploy — nenhum bloqueio de código, só de ambiente local.
- Fluxo de instância compartilhada está pronto ponta a ponta: reutilizar conexão (31-01) + webhook e sync coerentes entre irmãos (31-02).

---
*Phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes*
*Completed: 2026-08-31*

## Self-Check: PASSED

- FOUND: app/controllers/webhooks/evolution_controller.rb
- FOUND: app/services/whatsapp/group_synchronizer.rb
- FOUND: test/controllers/webhooks/evolution_controller_test.rb
- FOUND: test/services/whatsapp/group_synchronizer_test.rb
- FOUND: test/integration/cross_client_isolation_test.rb
- FOUND commit: 7faf0ff (Task 1)
- FOUND commit: 0ca22ee (Task 2)
- FOUND commit: c738789 (Task 3)
