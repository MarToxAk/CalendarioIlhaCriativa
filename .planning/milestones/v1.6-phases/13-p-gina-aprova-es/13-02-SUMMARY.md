---
phase: 13-p-gina-aprova-es
plan: "02"
subsystem: api
tags: [rails, pagy, activerecord, controller, testing, tdd]

# Dependency graph
requires:
  - phase: 13-01
    provides: Pagy::Backend incluído no Admin::BaseController, rota admin_approvals registrada, arquivo de testes com setup inline
  - phase: 12
    provides: Admin::BaseController com before_action :require_authentication e layout admin

provides:
  - Admin::ApprovalsController com action index paginada (25 itens) e filtrável por client_id e decision
  - Query sem N+1 usando joins(arte: :client) + includes(arte: :client)
  - Ordenação por responded_at DESC
  - Filtro decision seguro com ApprovalResponse.decisions.key?() para prevenir ArgumentError
  - View index mínima renderizando dados de aprovação com link para admin_arte_path
  - 8 testes de integração cobrindo APRO-03, APRO-04, APRO-06, APRO-07
affects: [13-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Admin controller com scope em etapas: base → filtro client_id → filtro decision → pagy"
    - "Validação de enum com ApprovalResponse.decisions.key?(param) antes de where(decision:) — previne ArgumentError"
    - "Filtro client_id qualifica tabela: where(artes: { client_id: }) — evita ambiguidade de coluna SQL com joins"
    - "TDD RED: arquivo de testes commitado separado (29de188); GREEN: controller + view commitados após testes passarem (f53d4f8)"

key-files:
  created:
    - app/controllers/admin/approvals_controller.rb
    - app/views/admin/approvals/index.html.erb
  modified:
    - test/controllers/admin/approvals_controller_test.rb

key-decisions:
  - "View mínima criada como desvio Rule 3 (bloqueante) — os testes precisavam de template para rodar; será expandida no Wave 3 (plano 13-03)"
  - "Testes rodados a partir do diretório do worktree com BUNDLE_PATH apontando para vendor/bundle do projeto principal — abordagem necessária para carregar o controller do worktree"

patterns-established:
  - "Controller scope em etapas com validação de enum antes de filtro decision"
  - "Query anti-N+1 com joins + includes para associações aninhadas"

requirements-completed: [APRO-04, APRO-06, APRO-07]

# Metrics
duration: 15min
completed: 2026-06-04
---

# Phase 13 Plan 02: Admin::ApprovalsController com Index Paginado e Filtrável Summary

**Admin::ApprovalsController com query anti-N+1 (joins+includes), paginação pagy de 25 itens, filtros por client_id e decision (validado com .decisions.key?), e 8 testes de integração passando**

## Performance

- **Duration:** 15 min
- **Started:** 2026-06-04T03:41:00Z
- **Completed:** 2026-06-04T03:56:00Z
- **Tasks:** 2 (TDD: RED + GREEN commits por task)
- **Files modified:** 3 criados/modificados

## Accomplishments
- Admin::ApprovalsController criado com action index: scope base com joins+includes+order, filtro client_id, filtro decision seguro, paginação pagy com limit 25, @clients para dropdown
- View mínima index.html.erb criada (necessária para testes passarem) — renderiza client.name, arte.title, decision, responded_at e link admin_arte_path por linha
- 8 testes de integração passando (20 assertions, 0 failures, 0 errors) cobrindo: acesso autenticado, redirect sem auth, dados renderizados no body, filtros por client_id/decision/invalid, link para arte
- Suite completa sem regressões: 105 tests, 308 assertions, 0 failures, 0 errors, 0 skips

## Task Commits

Cada task commitada atomicamente com TDD RED/GREEN:

1. **Task 1 (RED) — Testes de integração (falham sem controller)** - `29de188` (test)
2. **Task 1+2 (GREEN) — Controller + View mínima (testes passam)** - `f53d4f8` (feat)

_Nota: Tasks 1 e 2 do plano integradas em ciclo TDD único — testes primeiro (RED), implementação depois (GREEN)._

## Files Created/Modified
- `app/controllers/admin/approvals_controller.rb` - Admin::ApprovalsController com index paginado e filtrável, query anti-N+1, validação de enum segura
- `app/views/admin/approvals/index.html.erb` - View mínima com tabela de aprovações, filtros e link para arte (base para Wave 3)
- `test/controllers/admin/approvals_controller_test.rb` - 8 testes de integração cobrindo todos os requisitos APRO-03..07

## Decisions Made
- View mínima criada como desvio Rule 3 — os testes do plano precisam de template para rodar (`assert_includes response.body`); o Wave 3 (plano 13-03) vai expandir com UI completa de Turbo Frames e filtros
- Testes rodados com `BUNDLE_PATH=/home/bot/calendario_livia/vendor/bundle BUNDLE_GEMFILE=<worktree>/Gemfile bundle exec rails test` a partir do diretório do worktree para carregar o app/ correto

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Criada view mínima app/views/admin/approvals/index.html.erb**
- **Found during:** Task 1/2 (testes de integração)
- **Issue:** Testes com `assert_includes response.body` requerem template existente; sem view, todos os testes falham com "ActionController::MissingExactTemplate" em vez de testar o comportamento do controller
- **Fix:** Criada view mínima que renderiza todos os dados necessários para os 8 testes passarem (client.name, arte.title, decision, admin_arte_path)
- **Files modified:** app/views/admin/approvals/index.html.erb
- **Verification:** 8 runs, 20 assertions, 0 failures
- **Committed in:** f53d4f8 (feat — GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 blocking — view mínima necessária para testes)
**Impact on plan:** Desvio necessário para correctude dos testes. A view será expandida no plano 13-03 (Wave 3). Sem scope creep — view apenas renderiza dados já disponíveis via @approval_responses e @clients.

## Issues Encountered
- Testes rodados do diretório principal `/home/bot/calendario_livia` carregam `app/` do projeto principal (sem o controller do worktree) — resolvido rodando do diretório do worktree com BUNDLE_PATH apontando para vendor/bundle do projeto principal

## Known Stubs
Nenhum — view renderiza dados reais de @approval_responses, sem valores hardcoded ou placeholders.

## User Setup Required
Nenhum — nenhuma configuração externa necessária.

## Next Phase Readiness
- Controller funcional com todos os comportamentos testados
- View mínima serve como base para plano 13-03 expandir com UI completa (Turbo Frames, filtros, paginação visual)
- Suite completa passa sem regressões — plano 13-03 pode prosseguir com segurança

---
*Phase: 13-p-gina-aprova-es*
*Completed: 2026-06-04*
