---
phase: 23-endpoints-cliente
plan: 03
subsystem: api
tags: [rails, test, integration-test, client-api, security, cross-client]

# Dependency graph
requires:
  - phase: 23-02
    provides: Api::V1::Client::ArtesController (index+show) e Api::V1::Client::ApprovalResponsesController (create) com enum guard + row-lock

provides:
  - test/controllers/api/v1/client/artes_controller_test.rb — 7 casos de integração cobrindo APICLI-01 e APICLI-02
  - test/controllers/api/v1/client/approval_responses_controller_test.rb — 7 casos de integração cobrindo APICLI-03

affects:
  - Nenhum arquivo de produção modificado — apenas testes

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "JWT setup com ENV['JWT_SECRET'] isolado por run + teardown (padrão da fase 22)"
    - "User.find_or_create_by! para guard de callback broadcasts_revised_to_all"
    - "response.parsed_body + body.dig() para asserção de JSON aninhado"
    - "refute_includes ids_retornados, arte_outro.id para verificação de isolamento cross-client"
    - "arte.update!(status: :approved) antes do POST para testar arte_must_be_pending"

key-files:
  created:
    - test/controllers/api/v1/client/artes_controller_test.rb
    - test/controllers/api/v1/client/approval_responses_controller_test.rb
  modified: []

key-decisions:
  - "Payload flat { decision: '...' }.to_json sem wrapper :approval_response — conforme D-05"
  - "Caso D-09 (cross-client) testado em 3 pontos: index (refute_includes), show (404), approval_responses create (404)"
  - "Caso D-10 testado em 2 dimensões: enum inválido → 400, arte já approved → 422"
  - "Re-aprovação (revised → approved) testada com arte separada criada no status :revised"
  - "7 testes por arquivo — mínimo exigido pelo plano (14 total)"

# Metrics
duration: 2 minutes
completed: 2026-06-12
---

# Phase 23 Plan 03: Testes de Integração dos Endpoints do Cliente Summary

**14 testes de integração que provam os contratos de segurança (IDOR cross-client), envelopes D-03/D-04/D-08 e guards de validação D-10 para os endpoints do cliente**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-06-12T15:13:58Z
- **Completed:** 2026-06-12T15:16:10Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- `test/controllers/api/v1/client/artes_controller_test.rb` criado com 7 casos de integração cobrindo APICLI-01 (index com paginação, filtro pending+revised, cross-client isolation, 401) e APICLI-02 (show com campos D-03, approval_responses+admin_reply D-04, 404 cross-client D-09). Setup com JWT scope:"client", JWT_SECRET isolado por run, User.find_or_create_by! para guard de callback.

- `test/controllers/api/v1/client/approval_responses_controller_test.rb` criado com 7 casos de integração cobrindo APICLI-03: happy path approved (201 com todos os 5 campos D-08), change_requested com comment (201 com D-06), enum guard decision inválido (400), arte_must_be_pending arte já approved (422), re-aprovação arte revised (201 D-08), cross-client IDOR (404 D-09), unauthenticated (401). Todos os POSTs usam payload flat `.to_json` sem wrapper `:approval_response`.

## Task Commits

1. **Task 1: Testes ArtesController (APICLI-01, APICLI-02)** - `b6619ca` (test)
2. **Task 2: Testes ApprovalResponsesController (APICLI-03)** - `4c651b8` (test)

## Files Created/Modified

- `test/controllers/api/v1/client/artes_controller_test.rb` — Novo: 172 linhas; 7 testes cobrindo APICLI-01 e APICLI-02 com segurança cross-client (D-09)
- `test/controllers/api/v1/client/approval_responses_controller_test.rb` — Novo: 146 linhas; 7 testes cobrindo APICLI-03 com enum guard (D-10), arte_must_be_pending (D-10), re-aprovação (D-08) e cross-client (D-09)

## Decisions Made

- `User.find_or_create_by!` no setup de ambos os arquivos — necessário porque o callback `broadcasts_revised_to_all` chama `User.order(:id).first`; sem User no DB, o callback faz guard e retorna, mas deixar explícito garante consistência com os demais testes de fase.
- Caso de re-aprovação (D-08) usa arte separada criada diretamente com `status: :revised` — evita dependência de transição de estado (approved! de um POST anterior) que poderia interferir com outros casos.
- `@arte.update!(status: :approved)` no caso D-10 (arte_must_be_pending) — atualização direta para status que impede nova resposta; conforme validação do model `arte_must_be_pending`.
- Verificação D-03 no show usa `%w[...]` iterado com `assert body["data"].key?(campo)` — padrão mais claro que verificar cada campo individualmente; falha com mensagem específica do campo ausente.

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Threat Surface Scan

Nenhuma superfície nova introduzida. Arquivos de teste não expõem endpoints novos; apenas verificam os endpoints já existentes nos namespaces protegidos por `authenticate_client_jwt!`.

Os 3 threats do registro foram mitigados pelos testes:
- T-23-10 (cross-client IDOR): Caso 3 do artes_test (index) e Caso 7 (show) provam 404; Caso 6 do approval_responses_test prova 404
- T-23-11 (enum guard): Caso 3 do approval_responses_test prova 400 para decision inválido
- T-23-12 (arte não-aprovável): Caso 4 do approval_responses_test prova 422 para arte approved

## Self-Check: PASSED

- `test/controllers/api/v1/client/artes_controller_test.rb` — FOUND
- `test/controllers/api/v1/client/approval_responses_controller_test.rb` — FOUND
- `b6619ca` — FOUND em git log
- `4c651b8` — FOUND em git log
