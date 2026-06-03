---
phase: 12-arte-show-dashboard-fix
plan: "01"
subsystem: admin-views
tags: [tailwind, ui-polish, show-page, dashboard, v1.3]
dependency_graph:
  requires: [phase-10-arte-form-polish, phase-11-arte-index-polish]
  provides: [SHOW-01, DASH-01]
  affects: [app/views/admin/artes/show.html.erb, app/views/admin/dashboard/index.html.erb]
tech_stack:
  added: []
  patterns: [tailwind-action-bar, text-back-link, button-to-inline-form, outline-secondary-button, destructive-red-button, green-cta-button]
key_files:
  created: []
  modified:
    - app/views/admin/artes/show.html.erb
    - app/views/admin/dashboard/index.html.erb
decisions:
  - "Preservar data: { confirm: } no botão Excluir (arquivo original usava confirm:, não turbo_confirm)"
  - "form: { class: 'inline' } adicionado em ambos os button_to para preservar layout flex"
  - "Botão Marcar Revisada usa px-4 (mais largo) para destacar o CTA principal"
metrics:
  duration_minutes: 2
  completed_date: "2026-06-03"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
  files_created: 0
---

# Phase 12 Plan 01: Arte Show & Dashboard Fix Summary

## One-liner

Substituição cirúrgica de classes placeholder btn/btn-secondary/btn-danger/btn-sm por Tailwind concreto em `artes/show.html.erb` (barra de ações reestruturada com back link, Editar outline, Excluir #EE3537, Marcar Revisada #0F7949) e `dashboard/index.html.erb` (link "Ver" com borda border-gray-200).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Reestruturar barra de ações em artes/show.html.erb (D-01 a D-05) | 9c09754 | app/views/admin/artes/show.html.erb |
| 2 | Estilizar link "Ver" em dashboard/index.html.erb (D-06) | 28d49ed | app/views/admin/dashboard/index.html.erb |

## What Was Built

### Task 1: Barra de ações em artes/show.html.erb

O bloco `<div class="mt-4 flex gap-2">` com quatro elementos sem estilo foi substituído pela estrutura canônica da Fase 12:

- **Wrapper:** `<div class="flex items-center gap-3 mb-6">` (D-01)
- **Back link:** `link_to admin_artes_path` com bloco, `aria: { label: "Voltar para lista de artes" }`, classe `text-sm text-slate-600 hover:text-slate-900 transition-colors`, texto `← Artes` (D-02)
- **Editar:** `link_to "Editar"` com `inline-flex items-center h-9 px-3 border border-gray-200 rounded-lg text-sm font-medium text-slate-700 bg-white hover:bg-gray-50 transition-colors`, condicional preservada (D-03)
- **Excluir:** `button_to "Excluir"` com `bg-[#EE3537] hover:bg-red-700`, `form: { class: "inline" }` para preservar layout flex, condicional preservada (D-04)
- **Marcar Revisada:** `button_to "Marcar como Revisada"` com `bg-[#0F7949] hover:bg-[#0a5c37]`, `px-4` (mais largo para destacar CTA), `form: { class: "inline", data: { turbo_confirm: } }`, condicional preservada (D-05)

### Task 2: Link "Ver" no dashboard

Substituição cirúrgica na linha 57 de `dashboard/index.html.erb`: `class: "btn btn-sm"` → `class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors"` (D-06, carry-forward de D-02 da Fase 11).

## Verification Results

| Check | Expected | Result |
|-------|----------|--------|
| grep 'btn' em show.html.erb | 0 linhas | PASS |
| grep 'btn' em dashboard/index.html.erb | 0 linhas | PASS |
| flex items-center gap-3 mb-6 em show.html.erb | 1 | 1 |
| EE3537 em show.html.erb | 1 | 1 |
| Voltar para lista de artes em show.html.erb | 1 | 1 |
| h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 em dashboard | 1 | 1 |
| rails runner "Arte; Client; puts 'models ok'" | sem erro | PASS |

## Deviations from Plan

### Auto-preserved — data: { confirm: }

**Found during:** Task 1
**Issue:** O plano mencionava verificar se o arquivo usa `confirm:` ou `turbo_confirm:` no botão Excluir e preservar como está. O arquivo original usava `data: { confirm: "Tem certeza?" }` (não `turbo_confirm:`).
**Fix:** Mantido `data: { confirm: "Tem certeza?" }` sem alteração, conforme instrução do plano.
**Files modified:** app/views/admin/artes/show.html.erb

Nenhuma outra desvio — plano executado conforme especificação.

## Known Stubs

Nenhum. Todos os botões e links são funcionais com rotas reais.

## Threat Surface Scan

Nenhuma nova superfície de segurança introduzida. Esta fase é styling puro — zero novas rotas, zero novos controllers, zero novos parâmetros. CSRF automático do Rails mantido em todos os `button_to`. Ver threat model em 12-01-PLAN.md para registro completo (T-12-01 a T-12-SC: todos `accept`).

## Self-Check: PASSED

- app/views/admin/artes/show.html.erb — FOUND (modificado)
- app/views/admin/dashboard/index.html.erb — FOUND (modificado)
- Commit 9c09754 — FOUND (Task 1)
- Commit 28d49ed — FOUND (Task 2)
