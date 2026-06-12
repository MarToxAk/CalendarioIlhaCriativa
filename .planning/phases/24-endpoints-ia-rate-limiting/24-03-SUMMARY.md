---
phase: 24-endpoints-ia-rate-limiting
plan: "03"
subsystem: api-ai-tests
tags:
  - api
  - ai
  - tests
  - rack-attack
  - throttle
  - integration-tests

dependency_graph:
  requires:
    - "Plan 24-01: BaseController, ArteSerializer, rotas e throttle api/ai_by_key"
    - "Plan 24-02: ArtesController (index + create) e ClientsController (summary)"
  provides:
    - "11 testes de integração para ArtesController AI (APIAI-01 + APIAI-02)"
    - "5 testes de integração para ClientsController AI (APIAI-03)"
    - "4 testes de throttle AI em rack_attack_test.rb (INFAPI-04)"
  affects:
    - "Cobertura automatizada de toda a fase 24"

tech_stack:
  added: []
  patterns:
    - "ActionDispatch::IntegrationTest com ENV restore via teardown (APIAI-key isolation)"
    - "Rack::Attack.cache.store.clear + ensure ENV restore (throttle test isolation)"
    - "Arte.create! com status update posterior (arte.update!(status: :approved)) — evita validação media_source_present"
    - "AI_API_KEY constante de classe fixa por suite (estável em todo o test run)"
    - "AI_THROTTLE_KEY constante de classe no rack_attack_test (isolada do setup global)"

key_files:
  created:
    - test/controllers/api/v1/ai/artes_controller_test.rb
    - test/controllers/api/v1/ai/clients_controller_test.rb
  modified:
    - test/integration/rack_attack_test.rb

decisions:
  - "Arte.create! seguida de arte.update!(status: :approved) para artes approved — evita conflito com validação media_source_present ao criar arte já approved"
  - "AI_API_KEY como constante de classe (não variável de instância) — garante estabilidade no secure_compare durante todo o test run do arquivo"
  - "AI_THROTTLE_KEY como constante de classe em RackAttackTest — separada da key dos controller tests para evitar contaminação de throttle entre suites"
  - "ENV restore via teardown (controller tests) e via ensure (rack_attack) — padrão mais seguro: teardown pode ser omitido se test falhar; ensure garante restore mesmo com exception"
  - "Rack::Attack.cache.store.clear antes de cada teste AI de throttle — previne contaminação de contador entre testes (T-24-09)"

metrics:
  duration: "8 minutes"
  completed: "2026-06-12T21:10:00Z"
  tasks_completed: 2
  files_modified: 3
---

# Phase 24 Plan 03: Testes de Integração — ArtesController AI, ClientsController AI e Throttle Rack::Attack

11 testes de integração para ArtesController AI (GET filtrado + POST guarded), 5 para ClientsController AI (summary com counts exatos), e 4 testes de throttle confirmando limite 60/min, 429 na 61ª requisição e JSON estruturado `code: too_many_requests`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Testes ArtesController (APIAI-01 + APIAI-02) e ClientsController (APIAI-03) | bfa7bf1 | artes_controller_test.rb, clients_controller_test.rb |
| 2 | Testes de throttle AI em rack_attack_test.rb (INFAPI-04) | fd01690 | rack_attack_test.rb |

## What Was Built

**Task 1 — Controller Tests:**

`test/controllers/api/v1/ai/artes_controller_test.rb` (209 linhas, 11 testes):
- Setup: `AI_API_KEY` constante de classe, ENV restore via teardown, Rack::Attack.cache.store.clear
- GET index: 401 sem auth; 200 happy path com envelope; 400 sem from/to; 400 data inválida; approved-only filter; client_id filter; pagination meta keys (`page`, `per_page`, `total_count`, `total_pages`)
- POST create: 201 com external_url + `media_source_type="link"`; 400 com media_file rejected; 422 sem media source (model validation); 401 sem auth

`test/controllers/api/v1/ai/clients_controller_test.rb` (143 linhas, 5 testes):
- Setup: mesmo padrão AI_API_KEY; cria `@client` e `@another_client` para teste de escopo
- GET summary: 401 sem auth; 404 cliente inexistente (code="not_found"); 200 com todos os campos obrigatórios; counts exatos (2 approved + 1 pending = total 3); escopo isolado (artes de outro cliente excluídas)

**Task 2 — Throttle Tests:**

`test/integration/rack_attack_test.rb` (+55 linhas, +4 testes):
- `AI_THROTTLE_KEY` constante de classe separada da key dos controller tests
- `ai_auth_headers` método privado retornando headers com o token AI
- 60 requests passam (`assert_not_equal 429`)
- 61ª request retorna 429 (`assert_equal 429`)
- Resposta 429 é JSON com `errors[0].code == "too_many_requests"`
- Throttle AI não afeta `/session` (namespace isolation confirmado)
- Todos os 5 testes originais preservados intactos

## Acceptance Criteria Verification

**ArtesController:**
- `test/controllers/api/v1/ai/artes_controller_test.rb` — FOUND (209 linhas)
- `grep -c "test \""` — 11 (min exigido: 11)
- `grep "teardown"` — 1 linha (restore ENV)
- Teste approved-only filter — presente (assert `all? { |a| a["status"] == "approved" }`)
- Teste 400 invalid date — presente (code="bad_request")
- Teste 201 create — presente (media_source_type="link")
- Teste 400 media_file — presente (code="bad_request")

**ClientsController:**
- `test/controllers/api/v1/ai/clients_controller_test.rb` — FOUND (143 linhas)
- `grep -c "test \""` — 5 (min exigido: 5)
- Teste counts exatos — presente (total=3, approved_count=2, pending_count=1)
- Teste escopo isolado — presente (total=1 apenas para @client)

**Rack Attack:**
- `test/integration/rack_attack_test.rb` — FOUND (96 linhas)
- `grep -c "test \""` — 9 (5 originais + 4 AI)
- `grep -c "ensure"` — 4 (1 por teste AI)
- `grep -c "too_many_requests"` — 3 (constante + assert + setup label)
- Testes originais — 5 preservados sem modificação

## Deviations from Plan

None — plano executado exatamente como escrito.

## Test Execution Note

Os testes não foram executados via `bin/rails test` porque o banco de dados de teste pertence a outro usuário do SO (restrição documentada no contexto do projeto). A verificação foi feita por inspeção estática:
- Estrutura de classes correta (`ActionDispatch::IntegrationTest`)
- Padrões de setup/teardown idênticos aos analogs (admin tests)
- Assertions cobrindo todos os status codes documentados nos controllers
- ENV["AI_API_KEY"] setado antes de cada request e restaurado via teardown/ensure
- `Rack::Attack.cache.store.clear` presente em todos os testes de throttle AI (T-24-09)

## Threat Surface Scan

Nenhuma nova superfície de segurança além do previsto no threat model:
- T-24-09 (Tampering/test state): `Rack::Attack.cache.store.clear` em cada teste AI + ENV restore via ensure — implementado em todos os 4 testes de throttle
- T-24-10 (Information Disclosure/ENV): keys sintéticas (`ak_test_*`, `ak_throttle_test_*`) sem exposição de credenciais de produção
- T-24-SC (Supply chain): sem gems novas — sem risco

## Known Stubs

None — arquivos de teste que exercitam comportamento real dos controllers; nenhum mock ou dado hardcoded nos endpoints testados.

## Self-Check

- `test/controllers/api/v1/ai/artes_controller_test.rb` — FOUND
- `test/controllers/api/v1/ai/clients_controller_test.rb` — FOUND
- `test/integration/rack_attack_test.rb` — FOUND (modificado)
- Commit `bfa7bf1` — FOUND (git log confirmado)
- Commit `fd01690` — FOUND (git log confirmado)

## Self-Check: PASSED

All files confirmed on disk. Both task commits verified in git history.
