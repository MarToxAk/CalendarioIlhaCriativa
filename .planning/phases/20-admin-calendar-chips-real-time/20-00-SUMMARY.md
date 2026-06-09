---
phase: 20-admin-calendar-chips-real-time
plan: "00"
subsystem: admin-calendar-ui
tags: [partial-extraction, tailwind, helper, real-time-prep]
dependency_graph:
  requires: []
  provides:
    - "app/views/admin/calendar/_admin_calendar_chip.html.erb — partial reutilizável com dom_id estável para Turbo Stream replace"
    - "ApplicationHelper#arte_status_ring_class — helper de anel visual por status"
  affects:
    - "app/views/admin/calendar/_calendar_grid.html.erb — grid simplificado que delega ao partial"
tech_stack:
  added: []
  patterns:
    - "Partial extraction com dom_id(arte, prefix) — mesma convenção de Phase 19 D-05"
    - "Helper de anel Tailwind espelhando STATUS_MAP do JS (ring-2 ring-inset ring-[hex])"
key_files:
  created:
    - app/views/admin/calendar/_admin_calendar_chip.html.erb
  modified:
    - app/helpers/application_helper.rb
    - app/views/admin/calendar/_calendar_grid.html.erb
decisions:
  - "ring-inset usado para evitar expansão de layout no chip compacto (px-1 py-0.5 text-xs)"
  - "pending não recebe anel — ausência do anel comunica estado neutro/inicial"
  - "Hex values copiados literalmente do STATUS_MAP JS para manter sincronia sem conversão"
metrics:
  duration: "~7 min"
  completed: "2026-06-09"
  tasks_completed: 2
  files_modified: 3
---

# Phase 20 Plan 00: Admin Calendar Chip Extraction Summary

Partial `_admin_calendar_chip.html.erb` extraída do grid com `dom_id` estável e anel de status Tailwind colorido por status (approved/change_requested/revised), preparando o DOM para o Turbo Stream replace do Plan 01.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Adicionar helper arte_status_ring_class em ApplicationHelper | b010a6a | app/helpers/application_helper.rb |
| 2 | Extrair chip para partial e atualizar calendar grid | 030a11c | app/views/admin/calendar/_admin_calendar_chip.html.erb, app/views/admin/calendar/_calendar_grid.html.erb |

## What Was Built

### ApplicationHelper#arte_status_ring_class

Método adicionado logo após `client_color`. Retorna classes Tailwind de anel para os três status com sinalização visual:

- `approved` → `"ring-2 ring-inset ring-[#14A958]"` (verde, idêntico ao STATUS_MAP JS)
- `change_requested` → `"ring-2 ring-inset ring-[#EE3537]"` (vermelho)
- `revised` → `"ring-2 ring-inset ring-[#475569]"` (cinza)
- `pending` → `""` (string vazia — sem anel)

`ring-inset` escolhido para que o anel não expanda o layout no chip compacto (`px-1 py-0.5 text-xs`).

### _admin_calendar_chip.html.erb

Nova partial com:
- `id: dom_id(arte, "admin_calendar_chip")` → gera `"arte_42_admin_calendar_chip"` (alvo de Turbo Stream replace em Plan 01)
- Todos os 9 `data:` attributes preservados do inline original (action, arte_client, arte_title, arte_date, arte_platform, arte_status, arte_url, arte_preview_source, arte_preview_url, turbo_frame: "_top")
- Lógica preview_source/preview_url (image/video/external/none) replicada exatamente do grid
- Classe `arte_status_ring_class(arte)` interpolada ao final da string de classes do `link_to`
- Iniciais do cliente renderizadas: `arte.client.name.split.map(&:first).first(2).join.upcase`

### _calendar_grid.html.erb

Bloco de 38 linhas (cálculo de color/preview + link_to inline) substituído por uma única linha:
```erb
<%= render "admin/calendar/admin_calendar_chip", arte: arte %>
```

Loop `visible.each`, cálculo `visible`/`overflow`, bloco `+N` e toda a estrutura do grid preservados sem alteração.

## Verification

```
1. grep -c 'render.*admin_calendar_chip' _calendar_grid.html.erb → 1 ✓
2. grep -c 'dom_id.*admin_calendar_chip' _admin_calendar_chip.html.erb → 1 ✓
3. grep -c 'arte_status_ring_class' application_helper.rb → 1 ✓
4. grep -c 'link_to admin_arte_path' _calendar_grid.html.erb → 0 ✓ (chip inline removido)
5. bin/rails runner "include ApplicationHelper; ..." → OK ✓
```

Nota: `bin/rails test test/controllers/admin/artes_controller_test.rb` falha com `PG::InsufficientPrivilege: permission denied for table ar_internal_metadata` — problema pré-existente de permissão no banco de dados de teste (não relacionado às mudanças deste plano; verificado que o Rails carrega corretamente via `bin/rails runner`).

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Known Stubs

Nenhum — nenhum dado hardcoded ou placeholder introduzido.

## Threat Flags

Nenhuma superfície nova além do descrito no threat model do plano (T-20-01, T-20-02 analisados e aceitos).

## Self-Check: PASSED

- [x] app/views/admin/calendar/_admin_calendar_chip.html.erb existe
- [x] app/helpers/application_helper.rb contém arte_status_ring_class
- [x] app/views/admin/calendar/_calendar_grid.html.erb contém render "admin/calendar/admin_calendar_chip"
- [x] commit b010a6a existe: feat(20-00): adicionar helper arte_status_ring_class
- [x] commit 030a11c existe: feat(20-00): extrair chip do calendário admin para partial
