---
phase: 05-approval-flow
plan: "03"
subsystem: admin-ui
tags:
  - approval-flow
  - admin-view
  - mark-revised
  - APRO-03
dependency_graph:
  requires:
    - 05-01
    - 05-02
  provides:
    - admin-mark-revised-button
    - apro-03-cycle-complete
  affects:
    - app/views/admin/artes/show.html.erb
    - test/controllers/admin/artes_controller_test.rb
tech-stack:
  added: []
  patterns:
    - "button_to com method: :patch e turbo_confirm para ações destrutivas de estado"
    - "Condicional change_requested? isolado por bloco <% if %> sem variável intermediária"

key-files:
  created: []
  modified:
    - app/views/admin/artes/show.html.erb
    - test/controllers/admin/artes_controller_test.rb

key-decisions:
  - "Botão mark_revised usa turbo_confirm para confirmação inline sem modal adicional"
  - "Condicional direto change_requested? na view sem helper/variável intermediária"
  - "Teste APRO-03 via ApprovalResponse.build direto (model test) em vez de request HTTP cliente (escopo admin controller test)"

patterns-established:
  - "button_to com method: :patch + form.data.turbo_confirm para transições de estado destrutivas"

requirements-completed:
  - APRO-03

duration: 5min
completed: 2026-05-26
---

# Phase 05 Plan 03: Admin Mark Revised Button Summary

**Botão "Marcar como Revisada" adicionado ao admin show com condicional change_requested?, fechando o ciclo de re-aprovação APRO-03 (74 testes verdes).**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-26T00:00:00Z
- **Completed:** 2026-05-26T00:05:00Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Botão "Marcar como Revisada" na admin show view, visível apenas quando `change_requested?`
- Confirmação inline via `turbo_confirm` sem modal adicional
- Teste de ciclo completo APRO-03: arte revisada aceita nova aprovação do cliente (validator revised? funcional)
- Suite completa: 74 testes, 0 falhas

## Task Commits

1. **Task 1: Botão mark_revised na admin show view + testes** - `58851e5` (feat)

## Files Created/Modified

- `app/views/admin/artes/show.html.erb` - Botão "Marcar como Revisada" condicional a `change_requested?`
- `test/controllers/admin/artes_controller_test.rb` - Teste ciclo completo APRO-03 adicionado

## Decisions Made

- `button_to` com `method: :patch` e `form: { data: { turbo_confirm: ... } }` — confirmação inline adequada para ação pontual sem necessidade de modal separado
- Condicional `<% if @arte.change_requested? %>` direto na view, sem variável intermediária — consistente com padrão existente no mesmo arquivo

## Deviations from Plan

### Auto-fixed Issues

Nenhum desvio — plano executado exatamente como escrito.

O Test C (ciclo completo APRO-03) foi adicionado conforme indicado pelo plano ("Se NÃO existirem, adicioná-los agora") — os Testes A e B já existiam do plano 05-01; apenas o Test C estava faltando. Isso é execução do plano, não desvio.

## Issues Encountered

Nenhum — todos os testes passaram na primeira execução.

## User Setup Required

Nenhum — nenhuma configuração externa necessária.

## Known Stubs

Nenhum — todos os dados provêm do banco real. O botão é condicional ao status do banco; o redirecionamento e flash são do controller real.

## Threat Flags

Nenhum — superfícies cobertas pelo threat_model do plano:
- T-05-03-02: Guarda `if @arte.change_requested?` no controller rejeita transição inválida com redirect+alert — CONFIRMADO.

## Next Phase Readiness

A Fase 5 está completa. O fluxo de aprovação inteiro está funcional:
- APRO-01: Cliente aprova arte (status approved, flash "Arte aprovada!")
- APRO-02: Cliente pede alteração com comentário opcional
- APRO-03: Admin marca como revisada → cliente aprova novamente (ciclo fechado)

Pronto para `/gsd-verify-work` na Fase 5.

## Self-Check: PASSED

- [x] `app/views/admin/artes/show.html.erb` contém `mark_revised_admin_arte_path` dentro de `if @arte.change_requested?` — CONFIRMED (grep retornou 1 linha)
- [x] Nenhuma referência singular `approval_response` na view — CONFIRMED (grep retornou 0)
- [x] `test/controllers/admin/artes_controller_test.rb` contém 10 testes, incluindo ciclo APRO-03 — CONFIRMED
- [x] `bin/rails test`: 74 testes, 223 assertions, 0 falhas — CONFIRMED
- [x] Commit 58851e5 — VERIFIED

---
*Phase: 05-approval-flow*
*Completed: 2026-05-26*
