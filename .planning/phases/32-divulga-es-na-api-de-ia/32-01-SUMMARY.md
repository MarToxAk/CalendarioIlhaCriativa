---
phase: 32-divulga-es-na-api-de-ia
plan: 01
subsystem: api
tags: [rails, api, ai, divulgacoes, activejob, whatsapp]

requires:
  - phase: 28-divulgacoes
    provides: model Divulgacao/DivulgacaoGrupo e suas validacoes
  - phase: 29-motor-de-envio
    provides: Divulgacoes::DispatchJob
  - phase: 24-api-de-ia
    provides: Api::V1::Ai::BaseController (auth ak_) e envelope JSON
provides:
  - POST /api/v1/ai/divulgacoes (agenda Divulgacao real e enfileira o mesmo DispatchJob do admin)
  - Api::V1::Ai::DivulgacaoSerializer (serialize/serialize_collection, allowlist D-10)
  - superficie de rotas da fase 32 (index/show/create/cancel + clients/:id/whatsapp_groups)
  - suite de integracao do create (19 casos, para o CI)
affects: [32-02, 32-03, 32-04]

actuals:
  tokens: 4500
  tasks: 2
  commits: 2

plan_head_before: d0e7b109a76f6edd07fba874a0ea3b73d80d353d
plan_head_after: 88d876f6fb09f26770decc2f4d920a6b16c80eef

tech-stack:
  added: []
  patterns:
    - "Resolucao de arte/grupos sempre pela associacao do cliente (client.artes.find, scoped_active_groups(client).find)"
    - "Erros herdados do Api::V1::BaseController (404 generico, 422 validation_error field base, 400 bad_request)"

key-files:
  created:
    - app/controllers/api/v1/ai/divulgacoes_controller.rb
    - app/serializers/api/v1/ai/divulgacao_serializer.rb
    - test/controllers/api/v1/ai/divulgacoes_controller_test.rb
  modified:
    - config/routes.rb

key-decisions:
  - "POST direto, sem campo de confirmacao; nao-idempotencia e formato ISO 8601 de scheduled_for documentados no cabecalho do controller (D-02)"
  - "scheduled_for ilegivel cai em 422 com a mensagem do model, nao 400 (D-08: sem validacao nova)"
  - "Nenhum tratamento local de not-found: 404 generico herdado nao revela de quem e o id (D-09)"

patterns-established:
  - "Harness runtime temporario em tmp/ai_smoke (gitignored): transacao sempre revertida, ActiveJob no adapter :test, marcador *-OK"

requirements-completed: []  # o plano declara requirements: [TBD] (nao e um ID real; nada a marcar)

coverage:
  - id: D1
    description: "POST /api/v1/ai/divulgacoes agenda uma Divulgacao (201, status agendada, uma linha pendente por grupo) e enfileira DispatchJob com wait_until = scheduled_for"
    verification:
      - kind: other
        ref: "bin/rails runner tmp/ai_smoke/create_smoke.rb (AI-DIV-CREATE-OK)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Contrato de erro: 400 (ids obrigatorios), 404 generico (cliente inexistente, arte/grupo forasteiro, grupo inativo), 422 (regras do model), status forcado ignorado, UTC==offset"
    verification:
      - kind: other
        ref: "bin/rails runner tmp/ai_smoke/create_failures_smoke.rb (AI-DIV-CREATE-FAIL-OK)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Suite Minitest de integracao do create (19 casos) escrita para o CI"
    verification: []
    human_judgment: true
    rationale: "bin/rails test nao roda localmente (banco de teste pertence a outro usuario do SO); testes escritos mas NAO executados — verificados por ruby -c, rubocop e pelo harness equivalente"

duration: 12min
completed: 2026-11-07
status: complete
---

# Phase 32 Plan 01: Criacao de Divulgacoes pela API de IA Summary

**POST /api/v1/ai/divulgacoes agenda Divulgacao real via ak_ key, resolvendo arte e grupos pela associacao do cliente (404 generico para ids forasteiros) e enfileirando o mesmo DispatchJob do admin em scheduled_for.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-11-07
- **Tasks:** 2
- **Files modified:** 4 rastreados (3 novos + routes.rb)

## Accomplishments

- Tracer ponta a ponta: rota -> controller -> resolucao escopada -> model/validacoes -> DispatchJob -> serializer -> envelope, provado em runtime contra o banco de dev dentro de transacao revertida.
- Superficie de rotas da fase inteira declarada de uma vez (index/show/create/cancel de divulgacoes e `clients#whatsapp_groups`), sem tocar rack_attack.
- Contrato de erro completo e isolamento cross-client (T-32-01/05) provados: 401, 400 x3, 404 x4, 422 x8, sempre com zero linhas e zero jobs.
- Suite de 19 casos de integracao escrita para o CI.

## Task Commits

1. **Task 1: Tracer — rota + serializer + controller#create** - `ec1af9a` (feat)
2. **Task 2: Expansao — contrato de erro e testes de integracao** - `88d876f` (test)

## Verificacao (honesta)

- **Testes Minitest: escritos, NAO executados localmente.** `bin/rails test` nao roda aqui (banco de teste de outro usuario do SO). Nao ha suite verde a reportar; a execucao real fica para o CI.
- Executado e aprovado localmente: `ruby -c` nos 4 arquivos, `bin/rubocop` limpo nos 4, `bin/rails routes` (4 rotas de divulgacoes + `clients#whatsapp_groups`), gates negativos (sem lookup cru de Arte/WhatsappGroup, sem handler local de not-found, sem campos internos do gateway no serializer), `git diff --stat 90e56cb -- app/models app/jobs app/controllers/admin config/initializers` vazio.
- Harness runtime: `create_smoke.rb` imprimiu `AI-DIV-CREATE-OK` (12 checks) e `create_failures_smoke.rb` imprimiu `AI-DIV-CREATE-FAIL-OK` (~75 checks), ambos em transacao revertida com ActiveJob no adapter `:test`.
- Tracer gate (end-of-phase, verify so automatizado): o harness do tracer foi re-executado antes da expansao e passou.

## Deviations from Plan

**Observacao de precondicao (nao e desvio de codigo):** a precondicao da Task 1 diz que `Divulgacao.count` sai com 0; no banco de dev saiu 1 (registro preexistente, nao tocado). O que a precondicao protege — conexao com o DB de dev e tabelas das fases 28-31 migradas — estava satisfeito, e o harness conta apenas as linhas do proprio cliente SMOKE dentro de transacao revertida, entao o registro existente nao interfere. Seguiu-se adiante.

Fora isso, o plano foi executado como escrito. Nenhum Rule 1-4 acionado.

## Known Stubs

None.

## Threat Flags

None — a superficie nova (endpoint POST) e exatamente a coberta pelo threat_model do plano (T-32-01 a T-32-08).

## Issues Encountered

None.

## Notes for Follow-up

- `tmp/ai_smoke/` (support.rb, create_smoke.rb, create_failures_smoke.rb) permanece, gitignored, para reuso nos planos 32-02/32-03; o plano 32-04 remove o diretorio.
- Rotas `index/show/cancel` e `whatsapp_groups` ja existem mas as acoes ainda nao (planos 32-02/32-03): chamar essas rotas hoje resulta em erro de acao ausente.
- `.planning/` mostra `state.json` e `.gitkeep` nao rastreados e `public/assets/` — preexistentes, nao tocados.

## Next Phase Readiness

Pronto para 32-02 (index/show/cancel); o serializer ja ordena `grupos` em Ruby para suportar `includes` na listagem.

## Self-Check: PASSED

- FOUND: app/controllers/api/v1/ai/divulgacoes_controller.rb, app/serializers/api/v1/ai/divulgacao_serializer.rb, test/controllers/api/v1/ai/divulgacoes_controller_test.rb, config/routes.rb (modificado)
- FOUND commits: ec1af9a, 88d876f (ancestrais de HEAD)
