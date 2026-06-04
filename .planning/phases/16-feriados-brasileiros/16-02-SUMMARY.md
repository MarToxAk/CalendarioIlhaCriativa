---
phase: 16-feriados-brasileiros
plan: "02"
subsystem: ui
tags: [erb, tailwind, holidays, calendar, tdd, integration-tests]
status: checkpoint

requires:
  - phase: 16-01
    provides: "BrazilianHolidays.for(year) module and ApplicationHelper#brazilian_holiday_for(date)"

provides:
  - "Holiday span in _month_calendar.html.erb: text-xs text-red-400 after day number block"
  - "Holiday span in _calendar_grid.html.erb: same span after day number block"
  - "Integration tests: FERI-02 (client) + FERI-03 (admin) with assert_includes Tiradentes for 2026-04"

affects:
  - "Visual verification checkpoint: human must confirm red text appears correctly in browser"

tech-stack:
  added: []
  patterns:
    - "Holiday span inserted outside if/else of day number — not inside any branch (Pitfall 3 avoidance)"
    - "Nil-safe ERB pattern: <% if (holiday = brazilian_holiday_for(date)) %>"
    - "truncate(holiday, length: 15) via Rails helper for long holiday names"

key-files:
  created: []
  modified:
    - app/views/client/home/_month_calendar.html.erb
    - app/views/admin/calendar/_calendar_grid.html.erb
    - test/controllers/client/home_controller_test.rb
    - test/controllers/admin/calendar_controller_test.rb

key-decisions:
  - "Holiday span placed after end of if/else block for day number — ensures today+holiday shows both circle and name"
  - "Span classes exactly text-xs text-red-400 block truncate leading-snug mt-0.5 per UI-SPEC contract"
  - "Tests use month=2026-04 (Tiradentes on 21/04, Páscoa on 05/04) — deterministic, date-independent"

patterns-established:
  - "FERI integration test pattern: GET with month param + assert_includes response.body for holiday name"

requirements-completed:
  - FERI-02
  - FERI-03

duration: 9min
completed: "2026-06-04"
---

# Phase 16 Plan 02: Holiday Span in Calendar Views Summary

**Span de feriado text-red-400 inserido nos dois calendários ERB (cliente e admin) com testes de integração verdes para Tiradentes e Páscoa em abril 2026.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-06-04T20:48:30Z
- **Completed:** 2026-06-04T20:57:54Z
- **Tasks:** 1 (TDD RED/GREEN) + checkpoint visual pendente
- **Files modified:** 4

## Accomplishments

- Inseriu `<% if (holiday = brazilian_holiday_for(date)) %>` span após o bloco de número do dia em `_month_calendar.html.erb`
- Mesma inserção em `_calendar_grid.html.erb` (usa `Time.zone.today`, não alterada)
- Span usa exatamente `text-xs text-red-400 block truncate leading-snug mt-0.5` per UI-SPEC
- Testes de integração FERI-02 (cliente) e FERI-03 (admin) passam: `assert_includes response.body, "Tiradentes"` e `"Páscoa"`
- Suite completa: 144 runs, 407 assertions, 0 failures, 0 errors, 0 skips

## Task Commits

Ciclo TDD:

1. **RED — Testes failing FERI-02 + FERI-03** - `7130b8e` (test)
2. **GREEN — Holiday span nas duas views** - `06c7bcc` (feat)

## Files Created/Modified

- `app/views/client/home/_month_calendar.html.erb` — Span de feriado inserido linha 26, após `<% end %>` do if/else do número
- `app/views/admin/calendar/_calendar_grid.html.erb` — Span de feriado inserido linha 24, após `<% end %>` do if/else do número
- `test/controllers/client/home_controller_test.rb` — Testes FERI-02: exibe feriado (Tiradentes + Páscoa) + regressão sem brazilianholiday
- `test/controllers/admin/calendar_controller_test.rb` — Testes FERI-03: exibe feriado + regressão

## Decisions Made

- Holiday span colocado fora do if/else (não dentro de nenhum branch) — garante que dia atual + feriado exibe ambos corretamente
- Classes Tailwind exatamente conforme UI-SPEC (não usar accent orange para feriado, apenas text-red-400)
- truncate(holiday, length: 15) aplicado apenas na view, o módulo retorna nome completo

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `.bundle/config` não estava configurado no worktree — configurado para apontar para `/home/bot/calendario_livia/vendor/bundle` (mesmo workaround do Plan 01, não commitado)
- Testes de cliente falham quando executados em conjunto com a suite (interferência de sessão/paralelismo) — comportamento pré-existente no projeto, não causado por este plano. Novos testes passam individualmente e na suite paralela completa (144 runs, 0 failures)

## TDD Gate Compliance

- RED commit: `7130b8e` — `test(16-02): add failing tests for holiday display in both calendar views`
- GREEN commit: `06c7bcc` — `feat(16-02): insert holiday span in both calendar ERB views`
- Gate sequence: RED antes de GREEN — PASSED

## Checkpoint: Verificação Visual Pendente

**Status:** Aguardando aprovação humana do visual no browser.

O Task 2 é um `checkpoint:human-verify` — requer que o usuário acesse os calendários em abril de 2026 e confirme:

1. Célula do dia 5 de abril exibe "Páscoa" em vermelho (text-red-400 / #F87171) abaixo do número
2. Célula do dia 21 de abril exibe "Tiradentes" em vermelho abaixo do número
3. Células sem feriado não têm texto extra
4. Chips de artes (se houver) aparecem abaixo do nome do feriado
5. Layout não quebrado em ambos os calendários (cliente e admin)

Para verificar: acessar `/admin/calendar?month=2026-04` e calendário do cliente com `?month=2026-04`.

## Known Stubs

Nenhum. Os dados de feriados são reais e verificados (Plan 01).

## Self-Check: PASSED

- `app/views/client/home/_month_calendar.html.erb` — FOUND (modified)
- `app/views/admin/calendar/_calendar_grid.html.erb` — FOUND (modified)
- `test/controllers/client/home_controller_test.rb` — FOUND (modified)
- `test/controllers/admin/calendar_controller_test.rb` — FOUND (modified)
- RED commit `7130b8e` — FOUND
- GREEN commit `06c7bcc` — FOUND
- `bin/rails test`: 144 runs, 0 failures, 0 errors — PASSED
