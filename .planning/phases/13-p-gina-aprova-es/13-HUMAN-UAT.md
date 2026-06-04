---
status: partial
phase: 13-p-gina-aprova-es
source: [13-VERIFICATION.md]
started: 2026-06-04T04:09:22Z
updated: 2026-06-04T04:09:22Z
---

## Current Test

[aguardando verificação humana]

## Tests

### 1. Filtros via Turbo Frame + Highlight do Sidebar
expected: Ao selecionar um cliente no dropdown e clicar Filtrar, apenas a tabela atualiza sem recarregar o sidebar (comportamento Turbo Frame). O link "Aprovações" no sidebar fica destacado (current_page? true).
result: [pending]

### 2. Fidelidade das cores dos badges
expected: Badge "Aprovado" exibe fundo verde (#F0FDF4), texto verde (#14A958). Badge "Pediu Alteração" exibe fundo vermelho (#FEF2F2), texto vermelho (#EE3537).
result: [pending]

### 3. Responsividade mobile
expected: Em viewport mobile (< 640px), cards aparecem (block sm:hidden) com cliente, badge de decisão, título da arte, data e comentário truncado. Tabela desktop some (hidden sm:block).
result: [pending]

### 4. Paginação com filtros ativos
expected: Ao navegar para página 2 enquanto filtros estão ativos, os filtros são mantidos na URL e a tabela exibe os resultados corretos.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
