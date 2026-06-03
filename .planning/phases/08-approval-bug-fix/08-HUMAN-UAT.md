---
status: resolved
phase: 08-approval-bug-fix
source: [08-VERIFICATION.md]
started: 2026-06-02T23:10:00-03:00
updated: 2026-06-02T23:15:00-03:00
---

## Current Test

Todos os cenários aprovados pelo usuário no checkpoint Task 2 da fase.

## Tests

### 1. Botão Aprovar — fluxo completo
expected: Página recarrega com flash "Arte aprovada!" e badge verde "Aprovado". Sem "Resposta inválida."
result: aprovado

### 2. Botão Pedir Alteração — com comentário
expected: Flash "Pedido de alteração enviado." e badge "Revisão solicitada". Sem "Resposta inválida."
result: aprovado

### 3. Botão Pedir Alteração — sem comentário
expected: Resposta gravada com flash "Pedido de alteração enviado." sem erro.
result: aprovado

### 4. (SC3) Badge no calendário reflete estado atualizado
expected: Após aprovar, calendário do cliente mostra badge "Aprovado".
result: aprovado

### 5. (SC4) Painel admin de feedback exibe resposta registrada
expected: Respostas registradas aparecem listadas no painel admin com decisão e comentário.
result: aprovado

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
