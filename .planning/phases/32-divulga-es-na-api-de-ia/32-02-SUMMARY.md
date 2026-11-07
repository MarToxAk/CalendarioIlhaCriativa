---
phase: 32-divulga-es-na-api-de-ia
plan: 02
subsystem: api
tags: [rails, api, ai, divulgacoes, pagy, filters]

requires:
  - phase: 32-divulga-es-na-api-de-ia
    provides: "plano 32-01: controller#create, DivulgacaoSerializer, rotas index/show/cancel, harness tmp/ai_smoke"
  - phase: 28-divulgacoes
    provides: "Divulgacao#cancelar! e enum de status"
provides:
  - GET /api/v1/ai/divulgacoes (client_id obrigatorio, filtros status/from/to, Pagy, sem N+1)
  - GET /api/v1/ai/divulgacoes/:id (divulgacao com resumo por grupo)
  - POST /api/v1/ai/divulgacoes/:id/cancel (idempotente, 200 sempre, sob lock de linha)
  - 23 testes de integracao de index/show/cancel (para o CI)
affects: [32-03, 32-04]

actuals:
  tokens: 7000
  tasks: 3
  commits: 3

plan_head_before: 312bc24b3356c50581e4bb7d019fbf6bed581838
plan_head_after: 6fdb2d1f3da1d846a7609eec91556b35f7e8a0d9

tech-stack:
  added: []
  patterns:
    - "Filtro invalido vira 400 bad_request via InvalidFilter + rescue_from local (nunca lista vazia silenciosa)"
    - "Intervalo de datas sobre coluna datetime com limites beginning_of_day..end_of_day (nunca range de Date)"

key-files:
  created: []
  modified:
    - app/controllers/api/v1/ai/divulgacoes_controller.rb
    - test/controllers/api/v1/ai/divulgacoes_controller_test.rb

key-decisions:
  - "Ordenacao default scheduled_for asc com desempate por id (a IA quer o que vem a seguir)"
  - "show/cancel resolvem por Divulgacao.find agency-wide (key ak_ unica), 404 generico para id inexistente"
  - "cancel reusa Divulgacao#cancelar! sob with_lock, sem tocar o model; retorno ignorado, sempre 200"

requirements-completed: []  # o plano declara requirements: [TBD] (nao e um ID real; nada a marcar)

coverage:
  - id: D1
    description: "index: client_id obrigatorio (401/400/404), escopo por cliente, ordem asc, filtro status valido/invalido, from/to inclusivos (23:30 de 'to' entra), extremo unico, from>to e data ilegivel -> 400, Pagy com teto 100 e page_out_of_range, no maximo 1 query de grupos"
    verification:
      - kind: other
        ref: "bin/rails runner tmp/ai_smoke/index_smoke.rb (AI-DIV-INDEX-OK, 25 checks)"
        status: pass
    human_judgment: false
  - id: D2
    description: "show (200 com chaves D-10, 404 para id 0/abc, 401) e cancel (agendada -> cancelada, idempotente, no-op em em_andamento/concluida com banco inalterado, 404, nenhum job enfileirado)"
    verification:
      - kind: other
        ref: "bin/rails runner tmp/ai_smoke/show_cancel_smoke.rb (AI-DIV-SHOWCANCEL-OK, 21 checks)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Suite Minitest de integracao de index/show/cancel (14 + 3 + 6 casos) escrita para o CI"
    verification: []
    human_judgment: true
    rationale: "bin/rails test nao roda localmente (banco de teste pertence a outro usuario do SO); testes escritos mas NAO executados — verificados por ruby -c, rubocop, contagem de casos e pelo harness runtime equivalente das Tasks 1-2"

duration: 15min
completed: 2026-11-07
status: complete
---

# Phase 32 Plan 02: Listar, consultar e cancelar Divulgacoes pela API de IA Summary

**index/show/cancel no controller de divulgacoes da API de IA: listagem por cliente com filtros validados (400, nunca lista vazia silenciosa), dia final de `to` inclusivo e Pagy sem N+1; cancel idempotente espelhando `cancelar!` sob lock de linha.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-11-07
- **Tasks:** 3
- **Files modified:** 2 rastreados (controller e arquivo de teste); harness em `tmp/ai_smoke/` (gitignored)

## Accomplishments

- `index` exige `client_id` (400 ausente/Hash, 404 inexistente) e parte sempre de `client.divulgacoes`, com `includes(:divulgacao_grupos)` e ordem `scheduled_for asc, id asc`.
- Filtro `status` validado contra `Divulgacao.statuses` (evita o `IS NULL` silencioso); `from`/`to` por `Date.iso8601` com limites `beginning_of_day`/`end_of_day`, aceitando um so extremo.
- `show` devolve o resumo por grupo (polling); `cancel` chama `cancelar!` dentro de `with_lock`, responde 200 sempre e nao enfileira job. Model, jobs e initializers intocados.
- Cabecalho de contrato do controller estendido (index, show, cancel, ausencia de update/destroy).

## Task Commits

1. **Task 1: index com filtros, Pagy e sem N+1** - `e4a4e9f` (feat)
2. **Task 2: show + cancel idempotente** - `dac45c7` (feat)
3. **Task 3: testes de integracao index/show/cancel** - `6fdb2d1` (test)

## Verificacao (honesta)

- **Testes Minitest: escritos, NAO executados localmente.** `bin/rails test` nao roda aqui (banco de teste de outro usuario do SO). Nao ha suite verde a reportar; execucao real fica para o CI. Contagens por grep: 14 `GET index`, 3 `GET show`, 6 `POST cancel`, 19 `POST create` (create intacto).
- Executado e aprovado localmente: `ruby -c` e `bin/rubocop` limpos no controller e no arquivo de teste; gates por grep (`includes(:divulgacao_grupos)`, `Divulgacao.statuses`, `end_of_day`, `per_page_param`, `Date.iso8601`, `with_lock`, `cancelar!`, `def show`, `def cancel`); gate negativo (sem `update(status`, `status: :cancelada`, `update_column` no controller); `git diff --stat 90e56cb -- app/models app/jobs config/initializers` vazio.
- Harness runtime (transacao revertida, ActiveJob em `:test`): `index_smoke.rb` imprimiu `AI-DIV-INDEX-OK` e `show_cancel_smoke.rb` imprimiu `AI-DIV-SHOWCANCEL-OK`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — superficie nova coberta pelo threat_model do plano (T-32-09 a T-32-13).

## Issues Encountered

None.

## Notes for Follow-up

- `tmp/ai_smoke/` segue gitignored com `index_smoke.rb` e `show_cancel_smoke.rb` alem dos scripts do 32-01; o plano 32-04 remove o diretorio.
- `show`/`cancel` sao agency-wide por desenho (T-32-13, aceito); isolar por cliente seria aceitar `client_id` opcional e escopar por `client.divulgacoes.find`.
- A race do cancel contra o `DispatchJob` e mitigada por `with_lock`, mas nao foi exercitada com concorrencia real (so a semantica sequencial foi provada).

## Next Phase Readiness

Pronto para 32-03 (`clients#whatsapp_groups`); a superficie de divulgacoes da API de IA (create/index/show/cancel) esta completa.

## Self-Check: PASSED

- FOUND: app/controllers/api/v1/ai/divulgacoes_controller.rb, test/controllers/api/v1/ai/divulgacoes_controller_test.rb
- FOUND commits: e4a4e9f, dac45c7, 6fdb2d1 (ancestrais de HEAD)
