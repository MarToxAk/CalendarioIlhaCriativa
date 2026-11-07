---
phase: 32-divulga-es-na-api-de-ia
plan: 03
subsystem: api
tags: [rails, api, ai, whatsapp, pagy, serializer]

requires:
  - phase: 32-divulga-es-na-api-de-ia
    provides: "plano 32-01: rota clients#whatsapp_groups, harness tmp/ai_smoke"
  - phase: 27-grupos-whatsapp
    provides: "cache local whatsapp_groups e WhatsappGroup#display_name"
  - phase: 31-reuso-de-instancia
    provides: "linha de instancia por cliente mesmo com conexao fisica compartilhada"
provides:
  - GET /api/v1/ai/clients/:id/whatsapp_groups (grupos ativos do cliente, ordenados e paginados)
  - Api::V1::Ai::WhatsappGroupSerializer (allowlist id, remote_jid, display_name)
  - 9 testes de integracao de whatsapp_groups (para o CI)
affects: [32-04]

actuals:
  tokens: 4500
  tasks: 2
  commits: 2

plan_head_before: cd7a9ecc8860aef2027d35b33186b8c4557996a9
plan_head_after: 58498f30b788a637d0f239f644317ef660073030

tech-stack:
  added: []
  patterns:
    - "Fonte de grupos = client.whatsapp_instance&.whatsapp_groups (linha propria), nunca por instance_name"
    - "Serializer PORO como allowlist explicita de campos"

key-files:
  created:
    - app/serializers/api/v1/ai/whatsapp_group_serializer.rb
  modified:
    - app/controllers/api/v1/ai/clients_controller.rb
    - test/controllers/api/v1/ai/clients_controller_test.rb

key-decisions:
  - "Acao whatsapp_groups no ClientsController existente (consistencia com summary), sem controller novo"
  - "Cliente sem instancia responde 200 com lista vazia (o POST correspondente falha seguro em 422)"
  - "Lista paginada com Pagy 25/100 e mesma ordem do admin (subject asc, nulos por ultimo, remote_jid)"

requirements-completed: []  # o plano declara requirements: [TBD] (nao e um ID real; nada a marcar)

coverage:
  - id: D1
    description: "whatsapp_groups: 401/404, so ativos, ordem subject asc/nulos por ultimo/remote_jid, chaves exatas, fallback de display_name, isolamento (outro cliente e irmao com instance_name compartilhado), sem instancia -> 200 vazio, paginacao + clamp 100 + page_out_of_range"
    verification:
      - kind: other
        ref: "bin/rails runner tmp/ai_smoke/groups_smoke.rb (AI-DIV-GROUPS-OK, 24 checks)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Suite Minitest de integracao de whatsapp_groups (9 casos) escrita para o CI"
    verification: []
    human_judgment: true
    rationale: "bin/rails test nao roda localmente (banco de teste pertence a outro usuario do SO); testes escritos mas NAO executados — verificados por ruby -c, rubocop, contagem de casos e pelo harness runtime equivalente da Task 1"

duration: 8min
completed: 2026-11-07
status: complete
---

# Phase 32 Plan 03: Descoberta de grupos pela API de IA Summary

**GET /api/v1/ai/clients/:id/whatsapp_groups lista so os grupos ativos da linha de instancia do proprio cliente (cache local, mesma ordem do admin, Pagy 25/100) com allowlist de 3 campos, para a IA preencher `whatsapp_group_ids` no POST de divulgacoes.**

## Performance

- **Duration:** ~8 min
- **Completed:** 2026-11-07
- **Tasks:** 2
- **Files modified:** 3 rastreados (1 novo serializer, controller, arquivo de teste); harness em `tmp/ai_smoke/` (gitignored)

## Accomplishments

- `Api::V1::Ai::WhatsappGroupSerializer` devolve exatamente `{id, remote_jid, display_name}`; nenhum dado da conexao nem metadado de sincronizacao sai.
- `ClientsController#whatsapp_groups` le so o cache local pela associacao do cliente (isolado mesmo com conexao fisica compartilhada), ordena como o admin e pagina; `summary` ficou intocado.
- Cliente sem instancia -> 200 com `data: []`; cliente inexistente -> 404 herdado; sem Bearer -> 401.
- 9 testes de integracao anexados ao arquivo de teste existente, sem alterar os 5 de `summary`.

## Task Commits

1. **Task 1: Serializer + ClientsController#whatsapp_groups + harness** - `c2cca8f` (feat)
2. **Task 2: Testes de integracao de whatsapp_groups** - `58498f3` (test)

## Verificacao (honesta)

- **Testes Minitest: escritos, NAO executados localmente.** `bin/rails test` nao roda aqui (banco de teste de outro usuario do SO). Nao ha suite verde a reportar; a execucao real fica para o CI. Contagens por grep: 9 `GET /whatsapp_groups`, 5 `GET /summary` (intactos).
- Executado e aprovado localmente: `ruby -c` e `bin/rubocop` limpos nos 3 arquivos; gates por grep (`def whatsapp_groups`, `whatsapp_instance&.whatsapp_groups`, `WhatsappGroupSerializer`, `NULLS LAST`); gate negativo (serializer sem a palavra proibida); `bin/rails routes` lista exatamente 1 rota `clients#whatsapp_groups`; `git diff --stat 90e56cb -- app/models app/jobs app/controllers/admin config/initializers` vazio.
- Harness runtime (transacao revertida, ActiveJob em `:test`): `groups_smoke.rb` imprimiu `AI-DIV-GROUPS-OK` (24 checks), cobrindo isolamento contra outro cliente e contra um irmao com o mesmo `instance_name`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — superficie nova coberta pelo threat_model do plano (T-32-14 a T-32-17).

## Issues Encountered

None.

## Notes for Follow-up

- `tmp/ai_smoke/` segue gitignored com `groups_smoke.rb` alem dos scripts anteriores; o plano 32-04 remove o diretorio.
- O teste mutation-sensitive de isolamento da API fica para o plano 32-04 (T-32-14).
- Cliente sem instancia -> 200 vazio (A5): trocar por 404 explicito e ajuste de uma linha se a IA preferir.

## Self-Check: PASSED

- FOUND: app/serializers/api/v1/ai/whatsapp_group_serializer.rb, app/controllers/api/v1/ai/clients_controller.rb, test/controllers/api/v1/ai/clients_controller_test.rb
- FOUND commits: c2cca8f, 58498f3 (ancestrais de HEAD)
