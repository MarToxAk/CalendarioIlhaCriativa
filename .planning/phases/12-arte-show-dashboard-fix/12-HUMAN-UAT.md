---
status: partial
phase: 12-arte-show-dashboard-fix
source: [12-01-VERIFICATION.md]
started: 2026-06-03T21:00:00Z
updated: 2026-06-03T21:00:00Z
---

## Current Test

[aguardando teste humano]

## Tests

### 1. Renderização visual dos botões em `/admin/artes/:id`
expected: Tailwind compilou as classes novas — botões Editar (outline border-gray-200), Excluir (vermelho #EE3537) e Marcar como Revisada (verde #0F7949) aparecem com cor e borda visíveis no browser
result: [pending]

### 2. Comportamento do turbo_confirm no Excluir
expected: Ao clicar em "Excluir", um dialog de confirmação aparece antes do request DELETE ser enviado (comportamento Turbo, não rails-ujs)
result: [pending]

### 3. Renderização visual do link "Ver" em `/admin`
expected: O link "Ver" na tabela do dashboard aparece como um pill-button com borda border-gray-200 visível e fundo hover no browser, usando `inline-flex h-8`
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
