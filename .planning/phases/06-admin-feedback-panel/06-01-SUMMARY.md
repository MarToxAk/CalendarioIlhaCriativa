---
phase: 06-admin-feedback-panel
plan: "01"
subsystem: admin-dashboard
tags:
  - dashboard
  - turbo-frame
  - migration
  - tdd
dependency_graph:
  requires:
    - "05: approval-flow (mark_revised, approval_responses)"
    - "02: admin-auth-client-management (Admin::BaseController, clients)"
  provides:
    - "Admin dashboard at /admin grouped by client with Turbo Frame filters"
    - "admin_reply:text column on artes table"
    - "Wave 0 test stubs for PAIN-01/02/03/05/CLIE-05"
  affects:
    - "app/controllers/admin/dashboard_controller.rb"
    - "app/views/admin/dashboard/index.html.erb"
    - "db/schema.rb"
tech_stack:
  added: []
  patterns:
    - "Turbo Frame with GET form for partial page updates (filter bar outside frame)"
    - "group_by(&:client) in Ruby after joins(:client) for client-grouped dashboard"
    - "includes(:approval_responses) + joins(:client) for eager loading without N+1"
key_files:
  created:
    - db/migrate/20260527025238_add_admin_reply_to_artes.rb
    - test/controllers/admin/dashboard_controller_test.rb
  modified:
    - db/schema.rb
    - app/controllers/admin/dashboard_controller.rb
    - app/views/admin/dashboard/index.html.erb
    - test/controllers/admin/artes_controller_test.rb
    - test/controllers/admin/clients_controller_test.rb
decisions:
  - "Botão 'Filtrar' manual em vez de auto-submit Stimulus (D-06) — mais simples, sem novo controller JS"
  - "joins(:client) sem includes(:client) para ordenação por nome do cliente — evita conflito includes+joins com references"
  - "admin_reply:text sem null constraint e sem default (D-09) — campo opcional"
  - "Turbo Frame envolve apenas a lista dinâmica; form de filtros fica fora para não ser substituído"
metrics:
  duration: "~20 min"
  completed_date: "2026-05-27"
  tasks_completed: 2
  files_changed: 7
requirements:
  - PAIN-01
  - PAIN-02
  - PAIN-03
  - PAIN-04
---

# Phase 06 Plan 01: Admin Dashboard + Migração admin_reply Summary

**One-liner:** Dashboard central do admin em /admin com artes agrupadas por cliente, filtros Turbo Frame por cliente e status, e migração add_column admin_reply:text.

## What Was Built

Este plano entrega a fatia vertical completa do dashboard central do admin (PAIN-01, PAIN-02, PAIN-03) como descrito no plano.

### Task 1: Migração admin_reply + Wave 0 Test Stubs (TDD RED)

- Gerada migração `AddAdminReplyToArtes` com `add_column :artes, :admin_reply, :text` (sem null constraint, sem default — D-09)
- `db:migrate` executado em development e test — schema.rb atualizado
- Criado `test/controllers/admin/dashboard_controller_test.rb` com 3 stubs: `should get index`, `filter by client_id`, `filter by status` (assert_response :success)
- Adicionado `test_update_admin_reply` em artes_controller_test.rb (falha em RED — sera implementado em Plano 02)
- Adicionado `test_show_inclui_historico_de_aprovacoes` em clients_controller_test.rb (passa — show existente nao quebra)

### Task 2: DashboardController#index + View com Turbo Frame (TDD GREEN)

- Reescrito `Admin::DashboardController#index` com query: `Arte.includes(:approval_responses).joins(:client).order("clients.name ASC, artes.scheduled_on DESC")`
- Filtros aplicados via `params[:client_id].present?` e `params[:status].present?`
- `@artes_by_client = scope.group_by(&:client)` e `@clients = Client.order(:name)`
- Reescrita completa de `dashboard/index.html.erb`:
  - Form de filtros com `data: { turbo_frame: "dashboard-content" }` FORA da turbo-frame
  - Select de cliente + select de status com labels PT-BR + botao "Filtrar"
  - `<turbo-frame id="dashboard-content">` contendo lista agrupada por cliente
  - Partial `client/shared/arte_status_badge` reutilizada com `compact: true`
  - Link "Ver" para `admin_arte_path` em cada arte
  - Estado vazio quando nenhuma arte encontrada

## Verification Results

```
bin/rails test test/controllers/admin/dashboard_controller_test.rb
3 runs, 3 assertions, 0 failures, 0 errors, 0 skips

bin/rails test test/controllers/admin/
21 runs, 59 assertions, 1 failures, 0 errors, 0 skips
```

A 1 falha esperada e intencional: `test_update_admin_reply` (PAIN-05 — sera implementado em Plano 02 quando `arte_params` receber `:admin_reply`).

## Success Criteria Assessment

- [x] Admin abre /admin e ve artes agrupadas por cliente com badge de status (PAIN-01)
- [x] Admin seleciona cliente no filtro e clica Filtrar — apenas artes daquele cliente no frame (PAIN-02)
- [x] Admin seleciona status no filtro e clica Filtrar — apenas artes com aquele status (PAIN-03)
- [x] Link "Ver" em cada arte leva para admin_arte_path (PAIN-04 — mark_revised ja existe via Phase 5)
- [x] Sem autenticacao GET /admin redireciona (Admin::BaseController herda require_authentication)
- [x] 3 testes do dashboard: 0 failures, 0 errors

## Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1 (RED) | 9308fe2 | test | Migration + Wave 0 test stubs |
| Task 2 (GREEN) | ce9dc51 | feat | DashboardController#index + Turbo Frame view |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ApprovalResponse creation error in clients_controller_test**
- **Found during:** Task 1 — running tests after creating stubs
- **Issue:** `test_show_inclui_historico_de_aprovacoes` criava arte com `status: :change_requested` e tentava criar ApprovalResponse, mas o validator `arte_must_be_pending` bloqueia criacao quando status nao e pending/revised
- **Fix:** Alterado status da arte de `:change_requested` para `:pending` no setup do teste — ApprovalResponse.create! passa e muda o status via after_create callback
- **Files modified:** test/controllers/admin/clients_controller_test.rb
- **Commit:** 9308fe2

**2. [Rule 3 - Blocker] Worktree sem .bundle/config e sem .env**
- **Found during:** Inicio da execucao
- **Issue:** Worktree nao herdou `.bundle/config` do repo principal (BUNDLE_PATH: vendor/bundle) nem o arquivo `.env` com credenciais do PostgreSQL
- **Fix:** Criado `.bundle/config` no worktree apontando para `/home/bot/calendario_livia/vendor/bundle`; criado symlink `.env -> /home/bot/calendario_livia/.env`
- **Files modified:** .bundle/config (worktree-local), .env (symlink)

### Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `test_update_admin_reply` falha RED | test/controllers/admin/artes_controller_test.rb | `arte_params` nao inclui `:admin_reply` ainda — sera implementado em Plano 02 (PAIN-05) |

## Threat Flags

Nenhuma superfice nova fora do threat model do plano.

## Self-Check: PASSED

- [x] `db/migrate/20260527025238_add_admin_reply_to_artes.rb` existe
- [x] `test/controllers/admin/dashboard_controller_test.rb` existe
- [x] `app/controllers/admin/dashboard_controller.rb` contem `group_by(&:client)`
- [x] `app/views/admin/dashboard/index.html.erb` contem `turbo-frame id="dashboard-content"`
- [x] Commits 9308fe2 e ce9dc51 existem no historico
- [x] 3 testes do dashboard passando, 0 failures
