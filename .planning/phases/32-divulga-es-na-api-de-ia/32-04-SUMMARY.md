---
phase: 32-divulga-es-na-api-de-ia
plan: 04
subsystem: api
tags: [rails, api, ai, security, isolation, minitest]

requires:
  - phase: 32-divulga-es-na-api-de-ia
    provides: "planos 32-01..32-03: create/index/show/cancel de divulgacoes e clients#whatsapp_groups"
  - phase: 30-seguranca-cross-client
    provides: "cross_client_isolation_test.rb (SEG-04) com 4 testes e helpers"
  - phase: 31-reuso-de-instancia
    provides: "linha de instancia por cliente mesmo com conexao fisica compartilhada"
provides:
  - 4 testes "API de IA:" de isolamento cross-client (mutation-sensitive) anexados a cross_client_isolation_test.rb
  - Portao final da fase 32 (rubocop, brakeman, ruby -c, 8 rotas, 5 harnesses juntos) e remocao de tmp/ai_smoke/
affects: []

actuals:
  tokens: 1800
  tasks: 2
  commits: 1

plan_head_before: b4948dcbcf0100cf2e5dda83db5eac87945656a3
plan_head_after: 788521779d8006b972bdd1e746e7010eefde9af5

tech-stack:
  added: []
  patterns:
    - "Teste de isolamento por camada de controller: controle positivo (201) antes da tentativa forasteira (404 + zero linhas + zero jobs)"
    - "Isolamento por linha de instancia verificado com cliente-irmao de mesmo instance_name"

key-files:
  created: []
  modified:
    - test/integration/cross_client_isolation_test.rb

key-decisions:
  - "Testes da API de IA anexados ao CrossClientIsolationTest existente (setup, 4 testes e helpers intactos; diff so de insercoes)"
  - "AI_API_KEY de teste guardada uma unica vez no helper ai_headers e restaurada num teardown, sem tocar no setup existente"
  - "Task 2 e so verificacao/limpeza: nenhum arquivo rastreado muda, portanto sem commit proprio"

requirements-completed: []  # o plano declara requirements: [TBD] (nao e um ID real; nada a marcar)

coverage:
  - id: D1
    description: "Isolamento pelo caminho da API de IA: create com arte/grupo de outro cliente -> 404 (controle positivo 201), index sem vazamento, whatsapp_groups sem vazamento nem de cliente-irmao"
    verification: []
    human_judgment: true
    rationale: "bin/rails test nao roda localmente (banco de teste pertence a outro usuario do SO); testes escritos mas NAO executados — verificados por ruby -c, rubocop, contagem de casos e inspecao; o comportamento equivalente foi provado em runtime pelos harnesses dos planos 32-01..32-03"
  - id: D2
    description: "Portao final: rubocop e brakeman limpos, 8 rotas /api/v1/ai, 5 harnesses passando juntos, fase aditiva, tmp/ai_smoke removido"
    verification:
      - kind: other
        ref: "bin/rubocop (35 arquivos), bin/brakeman -q --no-pager (0 avisos), bin/rails routes -g api/v1/ai (8 rotas), 5 harnesses AI-DIV-*-OK, git diff 90e56cb -- app/models app/jobs app/controllers/admin config/initializers config/environments db (vazio)"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-11-07
status: complete
---

# Phase 32 Plan 04: Isolamento pela API de IA e portao final Summary

**Quatro testes "API de IA:" travam o isolamento cross-client na camada do controller (create 404 com controle positivo 201, index e whatsapp_groups sem vazamento nem para cliente-irmao), e o portao final da fase 32 passou (rubocop, brakeman, 8 rotas, 5 harnesses) antes de remover tmp/ai_smoke/.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-11-07
- **Tasks:** 2
- **Files modified:** 1 rastreado (`test/integration/cross_client_isolation_test.rb`, +119 linhas, 0 removidas)

## Accomplishments

- Casos 1 e 2 (arte e grupo do cliente B no `client_id` do A): primeiro um POST do proprio cliente A responde 201 e cria 1 `Divulgacao`; depois a tentativa forasteira, envolta em `assert_no_difference` (`Divulgacao`, `DivulgacaoGrupo`) e `assert_no_enqueued_jobs`, responde 404 `not_found`. Um lookup cru no controller faria o backstop do model responder 422 e o teste quebraria.
- Caso 3 (index): a listagem do cliente A traz a divulgacao de A e nunca a de B.
- Caso 4 (grupos com irmao): cliente-irmao criado com o `instance_name` de B; `whatsapp_groups` de A nao contem o `remote_jid` de B nem o do irmao; B e irmao nao se enxergam; controles positivos provam que cada um ve o proprio grupo.
- Cabecalho do arquivo estendido com o paragrafo da fase 32 explicando a mutation-sensitivity da camada de controller.
- Portao final: todos os gates abaixo passaram e `tmp/ai_smoke/` foi removido (nada dele rastreado).

## Task Commits

1. **Task 1: Isolamento pelo caminho da API de IA** - `7885217` (test)
2. **Task 2: Portao final + limpeza de tmp/ai_smoke** - sem commit (verificacao e remocao de diretorio gitignored; nenhum arquivo rastreado mudou)

## Verificacao (honesta)

- **Testes Minitest: escritos para o CI, nao executados localmente (banco de teste de outro usuario do SO); verificado por inspecao + harness runtime.** Nao ha suite verde a reportar.
- `ruby -c` limpo nos 7 arquivos da fase; `bin/rubocop` sem ofensas (35 arquivos: controllers/serializers/testes da API, teste de isolamento e `config/routes.rb`); `bin/brakeman -q --no-pager`: 0 avisos (1 ignorado, como em HEAD).
- Contagens por grep em `cross_client_isolation_test.rb`: 4 testes `API de IA:` e 8 testes no total (os 4 originais preservados; `git diff --stat` mostra so insercoes).
- `bin/rails routes -g api/v1/ai`: 8 rotas (artes x2, summary, whatsapp_groups, divulgacoes index/create/show/cancel), sem update/destroy/resend.
- Os 5 harnesses runtime rodaram juntos e imprimiram `AI-DIV-CREATE-OK`, `AI-DIV-CREATE-FAIL-OK`, `AI-DIV-INDEX-OK`, `AI-DIV-SHOWCANCEL-OK` e `AI-DIV-GROUPS-OK` (transacao revertida), e so depois `tmp/ai_smoke/` foi removido; `git ls-files tmp/ai_smoke` vazio.
- Escopo aditivo: `git diff --name-only 90e56cb -- app/models app/jobs app/controllers/admin config/initializers config/environments db` vazio; o diff de codigo da fase (fora de `.planning`) tem 8 arquivos, todos adicoes (1009 insercoes, 0 remocoes).

<human-check>
Rodar a suite Minitest no CI (ou localmente com um banco de teste proprio): `bin/rails test test/controllers/api/v1/ai test/integration/cross_client_isolation_test.rb test/controllers/admin/divulgacoes_controller_test.rb` e confirmar verde — os testes desta fase foram escritos mas NAO executados no ambiente de desenvolvimento.
</human-check>

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. T-32-18 mitigado pelos testes "API de IA:"; T-32-19 mitigado pela remocao de `tmp/ai_smoke/` (nada rastreado).

## Issues Encountered

None.

## Notes for Follow-up

- Fase 32 completa em codigo; resta a execucao real da suite no CI/UAT (item `human-check` acima).
- Os testes novos assumem fixtures/factories do proprio arquivo (`@client_a/@client_b/@group_a/@group_b/@arte_a/@arte_b`); um erro de setup so apareceria no CI.

## Self-Check: PASSED

- FOUND: test/integration/cross_client_isolation_test.rb
- FOUND commit: 7885217 (ancestral de HEAD)
- CONFIRMED absent: tmp/ai_smoke/
