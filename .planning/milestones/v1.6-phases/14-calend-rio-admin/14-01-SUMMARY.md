---
phase: 14-calend-rio-admin
plan: "01"
subsystem: admin-routing
tags: [routing, sidebar, testing, calendar, admin]
dependency_graph:
  requires: []
  provides: [admin_calendar_index_path, test-scaffold-calendar]
  affects: [app/views/admin/shared/_sidebar.html.erb, config/routes.rb]
tech_stack:
  added: []
  patterns: [resources-plural-namespace, inline-setup-test-scaffold]
key_files:
  created:
    - test/controllers/admin/calendar_controller_test.rb
  modified:
    - config/routes.rb
    - app/views/admin/shared/_sidebar.html.erb
decisions:
  - "resources :calendar (plural) usado em vez de resource singular — garante helper _index_path e action index"
  - "Task 1 e Task 2 executadas em commits separados: infra de rota+sidebar em feat, scaffold em test"
metrics:
  duration_minutes: 15
  completed_date: "2026-06-04"
  tasks_completed: 2
  files_modified: 3
---

# Phase 14 Plan 01: Infraestrutura de Entrada do Calendário Admin Summary

**One-liner:** Rota `resources :calendar` registrada no namespace admin gerando `admin_calendar_index_path`, sidebar wired de `"#"` para o helper real, scaffold de testes com setup inline pronto para Wave 3.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Registrar rota calendar no namespace admin e wirear sidebar | 8ecd77b |
| 2 | Criar scaffold de testes Admin::CalendarControllerTest | f29af36 |

## What Was Built

### Task 1: Rota + Sidebar (8ecd77b)

`config/routes.rb` — adicionada a linha `resources :calendar, only: [ :index ]` dentro do bloco `namespace :admin do`, imediatamente após `resources :approvals, only: [ :index ]`. Mantido o estilo de espaçamento existente (2 espaços, colchetes com espaços internos).

`app/views/admin/shared/_sidebar.html.erb` — alterado apenas o valor de `path` do item "Calendário" de `"#"` para `admin_calendar_index_path`. Nenhuma outra linha modificada.

Verificação: `bin/rails routes | grep calendar` retorna `admin_calendar_index GET /admin/calendar(.:format) admin/calendar#index`.

### Task 2: Scaffold de Testes (f29af36)

`test/controllers/admin/calendar_controller_test.rb` — criado com classe `Admin::CalendarControllerTest < ActionDispatch::IntegrationTest`. Setup replica o padrão exato do `approvals_controller_test.rb`:
- `User.create!` com email_address/password/password_confirmation
- `sign_in_as(@user)`
- `Client.create!` com name/password/password_confirmation
- `Arte.create!` com todos os campos obrigatórios (client, scheduled_on, platform, media_type, status, title, caption, approval_deadline, external_url)

Suite roda sem erros: 0 tests, 0 assertions, 0 failures. Testes completos serão adicionados no plano 14-03.

## Decisions Made

1. **`resources :calendar` (plural) em vez de `resource` singular** — `resource` singular não gera helper `_index_path` e não define a action `index` no padrão esperado (conforme Pattern 5 do RESEARCH.md). Decisão crítica documentada no RESEARCH.md como Pitfall.

2. **Task 1 e Task 2 na mesma wave** — Rota e sidebar devem ser alterados juntos; se a rota não existir quando o sidebar for renderizado, Rails lança `NameError`. Os dois arquivos foram modificados no mesmo commit de Task 1.

## Verification Results

```
admin_calendar_index GET /admin/calendar(.:format) admin/calendar#index
```

```
{ label: "Calendário", path: admin_calendar_index_path }
```

```
0 runs, 0 assertions, 0 failures, 0 errors, 0 skips
```

## Deviations from Plan

None — plano executado exatamente como escrito.

## Threat Surface Scan

A nova rota `GET /admin/calendar` é adicionada ao namespace `admin`, que herda `before_action :require_authentication` do `Admin::BaseController`. Não há nova superfície fora do modelo de ameaça documentado no plano (T-14-01 mitigado por herança do BaseController).

## Known Stubs

Nenhum stub introduzido neste plano. O arquivo de testes tem um comentário `# Testes adicionados no plano 14-03` marcando o estado intencional — não é um stub de dados, mas uma indicação de trabalho futuro documentado.

## Self-Check: PASSED

- [x] config/routes.rb contém `resources :calendar` dentro do namespace :admin
- [x] app/views/admin/shared/_sidebar.html.erb contém `admin_calendar_index_path`
- [x] test/controllers/admin/calendar_controller_test.rb existe
- [x] Commit 8ecd77b existe (rota + sidebar)
- [x] Commit f29af36 existe (scaffold de testes)
- [x] Suite de testes: 0 runs, 0 assertions, 0 failures
