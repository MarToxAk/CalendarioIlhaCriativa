---
phase: 14-calend-rio-admin
plan: "02"
subsystem: admin-calendar-controller
tags: [controller, helper, calendar, admin, tailwind, tdd]
dependency_graph:
  requires: [14-01]
  provides: [Admin::CalendarController#index, client_color, @artes_by_date, @grid_dates]
  affects:
    - app/controllers/admin/calendar_controller.rb
    - app/helpers/application_helper.rb
    - app/views/admin/calendar/index.html.erb
    - app/views/admin/calendar/_calendar_grid.html.erb
    - test/controllers/admin/calendar_controller_test.rb
tech_stack:
  added: []
  patterns:
    - admin-basecontroller-inheritance
    - includes-anti-n1
    - deterministic-color-palette
    - literal-tailwind-classes
    - tdd-red-green
key_files:
  created:
    - app/controllers/admin/calendar_controller.rb
    - app/views/admin/calendar/index.html.erb
    - app/views/admin/calendar/_calendar_grid.html.erb
  modified:
    - app/helpers/application_helper.rb
    - test/controllers/admin/calendar_controller_test.rb
decisions:
  - "client_color implementado antes do commit do controller — dependência de view (Rule 3)"
  - "Views criadas no mesmo plano (não no Plano 03) para permitir testes GREEN"
  - "MONTH_NAMES_PT fallback incluído mesmo com pt-BR.yml presente — defensive coding"
metrics:
  duration_minutes: 20
  completed_date: "2026-06-04"
  tasks_completed: 2
  files_modified: 5
---

# Phase 14 Plan 02: Controller e Helper do Calendário Admin Summary

**One-liner:** `Admin::CalendarController#index` com query `includes(:client).order(:id)` sem N+1, `parse_month_param` com `rescue Date::Error`, e `client_color` em `ApplicationHelper` com paleta de 8 cores Tailwind hex literais determinísticas por `client.id % 8`.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| RED  | Testes falhos para Admin::CalendarController | 69e7bb8 |
| 1    | Criar Admin::CalendarController + views | b8a1ccf |
| 2    | Adicionar client_color ao ApplicationHelper | 538a833 |

## What Was Built

### RED Phase (69e7bb8)

`test/controllers/admin/calendar_controller_test.rb` — 4 testes adicionados ao scaffold do Plano 01:
- `GET /admin/calendar` autenticado → 200
- `GET /admin/calendar` sem auth → redirect
- `GET /admin/calendar?month=2026-06` → 200
- `GET /admin/calendar?month=invalid` → 200 (valida rescue Date::Error)

Testes falhavam com `ActionDispatch::MissingController: uninitialized constant Admin::CalendarController` — RED confirmado.

### Task 1: Controller + Views (b8a1ccf)

`app/controllers/admin/calendar_controller.rb` — `Admin::CalendarController < Admin::BaseController`:
- Herda `before_action :require_authentication` e `layout 'admin'` do BaseController — nenhuma re-declaração
- Query: `Arte.where(scheduled_on: grid_start..grid_end).includes(:client).order(:id)` — `includes(:client)` evita N+1 na view ao acessar `arte.client`
- `parse_month_param` com `rescue Date::Error` — param inválido retorna `Date.today.beginning_of_month`
- `@month_label` via `I18n.l(@current_month, format: "%B %Y")` com fallback `MONTH_NAMES_PT` para garantia
- Atribui: `@artes_by_date`, `@grid_dates`, `@prev_month`, `@next_month`, `@month_label`

`app/views/admin/calendar/index.html.erb` — navegação de mês com setas fora do turbo-frame, `<turbo-frame id="calendar-content">` envolvendo o partial.

`app/views/admin/calendar/_calendar_grid.html.erb` — grade 7 colunas, células com estilo por mês atual/fora, chips coloridos por cliente com iniciais (2 chars), overflow "+N" para > 3 artes por dia.

### Task 2: Helper client_color (538a833)

`app/helpers/application_helper.rb` — método `client_color(client)` adicionado ao `ApplicationHelper`:
- Paleta de 8 hashes `{ bg:, text: }` com strings Tailwind hex literais completas (Tailwind JIT safe)
- Índice calculado por `client.id % palette.size` — determinístico, sem estado
- Todas as 8 cores declaradas como strings literais (não interpolação) — conforme D-01 e Pitfall 3 do RESEARCH.md

## Decisions Made

1. **client_color implementado antes do commit GREEN do controller** — A view `_calendar_grid.html.erb` chama `client_color` para cada arte. Como o setup de teste cria uma arte, os testes do controller falhariam com `undefined method 'client_color'` se o helper não existisse. Aplicado Rule 3 (bloqueio): helper implementado para desbloquear o GREEN da Task 1.

2. **Views criadas neste plano** — O plano especificou apenas controller + helper, mas o controller precisa de views para retornar 200. Criadas `index.html.erb` e `_calendar_grid.html.erb` como parte da Task 1 (necessário para que os testes passem e o endpoint funcione).

3. **MONTH_NAMES_PT fallback** — Mesmo com `pt-BR.yml` presente, o fallback foi incluído para robustez em ambientes sem `config.i18n.default_locale = :'pt-BR'` configurado.

## Verification Results

```
admin_calendar_index GET /admin/calendar(.:format) admin/calendar#index
```

```ruby
grep: includes(:client) ✓
grep: rescue Date::Error ✓
grep: def client_color ✓
grep: palette[client.id % palette.size] ✓
```

```
4 runs, 4 assertions, 0 failures, 0 errors, 0 skips
```

Runner check:
```
{:bg=>"bg-[#F0FDF4]", :text=>"text-[#14A958]"}
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Views criadas para desbloquear testes GREEN**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** Controller precisa de views para retornar 200. Testes também falhavam com `undefined method 'client_color'` porque a view chama o helper e o setup de teste cria uma arte que vai aparecer no grid.
- **Fix:** Criadas `app/views/admin/calendar/index.html.erb` e `_calendar_grid.html.erb` no mesmo commit da Task 1; helper `client_color` implementado antes do commit GREEN do controller.
- **Files modified:** `app/views/admin/calendar/index.html.erb`, `app/views/admin/calendar/_calendar_grid.html.erb`
- **Commit:** b8a1ccf

## Threat Surface Scan

`GET /admin/calendar` é novo endpoint no namespace `admin`. Herdado de `Admin::BaseController`: `before_action :require_authentication` bloqueia acesso não autenticado — confirmado por Test 2 (redirect sem auth). Query busca artes de todos os clientes mas é acessível apenas pelo admin autenticado. Nenhuma nova superfície fora do modelo de ameaça do plano (T-14-02 mitigado, T-14-03 mitigado, T-14-04 aceito).

## Known Stubs

Nenhum stub introduzido. As views criadas são funcionais e completas — não há placeholders de dados nem "TODO" pendentes neste plano.

## TDD Gate Compliance

- [x] RED gate: commit `69e7bb8` — testes falhos confirmados (`uninitialized constant Admin::CalendarController`)
- [x] GREEN gate: commit `b8a1ccf` + `538a833` — 4/4 testes passando
- [ ] REFACTOR: não necessário — código limpo na primeira implementação

## Self-Check: PASSED

- [x] `app/controllers/admin/calendar_controller.rb` existe com `class Admin::CalendarController < Admin::BaseController`
- [x] Controller contém `.includes(:client)` na query
- [x] Controller contém `rescue Date::Error` em `parse_month_param`
- [x] `app/helpers/application_helper.rb` contém `def client_color`
- [x] Helper contém `palette[client.id % palette.size]`
- [x] 4 testes passando: `4 runs, 4 assertions, 0 failures, 0 errors, 0 skips`
- [x] Rota `admin_calendar_index GET /admin/calendar` registrada
- [x] Commit 69e7bb8 (RED), b8a1ccf (GREEN controller), 538a833 (GREEN helper) existem
