---
phase: 15-configuracoes
plan: "03"
subsystem: admin-settings-view
tags: [view, erb, forms, password-change, agency-name]
dependency_graph:
  requires: [15-01-PLAN.md, 15-02-PLAN.md]
  provides: [app/views/admin/settings/show.html.erb, GET settings 200]
  affects:
    - app/views/admin/settings/show.html.erb
    - test/controllers/admin/settings_controller_test.rb
tech_stack:
  added: []
  patterns: [form_with url:, password_field_tag, text_field_tag, content_for layout]
key_files:
  created:
    - app/views/admin/settings/show.html.erb
  modified:
    - test/controllers/admin/settings_controller_test.rb
decisions:
  - "form_with url: (não model:) — não há objeto ActiveRecord sendo editado diretamente"
  - "password_field_tag e text_field_tag — evita binding a objeto de modelo"
  - "Dois cards independentes — erro num não afeta submit do outro"
  - "GET settings test habilitado nesta wave (estava skip pending view)"
metrics:
  duration: "~5min"
  completed: "2026-06-04"
  tasks_completed: 1
  files_changed: 2
---

# Phase 15 Plan 03: Settings Show View Summary

**One-liner:** View `admin/settings/show.html.erb` com dois cards independentes — troca de senha e dados da agência — seguindo padrão visual do projeto; teste GET habilitado, todos os 8 testes passam.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Criar view show.html.erb com cards de senha e agência + habilitar teste GET | 29965d9 |

## What Was Built

### Settings View (`app/views/admin/settings/show.html.erb`)

Dois cards brancos com `rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl`:

**Card 1 — Alterar senha:**
- Campos: senha atual (`password_current`), nova senha (`password`), confirmação (`password_confirmation`)
- Submit → `PATCH update_password_admin_settings_path`
- `autocomplete="current-password"` / `autocomplete="new-password"` para cada campo

**Card 2 — Dados da agência:**
- Campo `agency_name` pré-preenchido com `Current.user.agency_name`
- `maxlength: 100` alinhado com validação do model
- Hint "Aparece no topo do menu lateral."
- Submit → `PATCH update_agency_admin_settings_path`

### Test update (`test/controllers/admin/settings_controller_test.rb`)

Teste "GET settings — autenticado: 200" habilitado (estava com `skip`). Suite completa: 8 runs, 0 failures, 0 errors.

## Deviations from Plan

Nenhum desvio — task executada conforme especificado.

## Self-Check: PASSED

- [x] `app/views/admin/settings/show.html.erb` — file exists
- [x] View contém `update_password_admin_settings_path` — confirmado
- [x] View contém `update_agency_admin_settings_path` — confirmado
- [x] View pré-preenche `Current.user&.agency_name` — confirmado
- [x] Commit 29965d9 existe no git log
- [x] GET settings test habilitado e passando
