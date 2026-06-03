---
status: partial
phase: 09-calendar-summary-strip
source: [09-VERIFICATION.md]
started: 2026-06-03T11:13:57Z
updated: 2026-06-03T11:13:57Z
---

## Current Test

[aguardando testes humanos]

## Tests

### 1. Faixa visível sem scroll em mobile (SC3)
expected: A summary strip aparece acima do calendário sem necessidade de rolar a página, com os 4 chips legíveis em viewport mobile (375px)
result: [pendente]

### 2. Contagens atualizam após aprovação (SC4)
expected: Após aprovar uma arte, o reload da página mostra o contador "aprovadas" incrementado e "pendentes" decrementado automaticamente (SSR puro, sem JS)
result: [pendente]

### 3. Faixa ausente em mês sem artes
expected: Ao navegar para um mês sem artes cadastradas, a summary strip não aparece (nenhum elemento com role="status")
result: [pendente]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
