---
status: partial
phase: 18-approvalresponse-broadcast-admin-live-rows
source: [18-VERIFICATION.md]
started: 2026-06-05T20:00:00Z
updated: 2026-06-05T20:00:00Z
---

## Current Test

[aguardando testes humanos]

## Tests

### 1. CRÍTICO — turbo_stream disponível em contexto de Model
expected: `bin/rails test test/models/approval_response_test.rb` com DB funcional — todos os testes A-G passam sem NoMethodError. Se Tests C-G falharem com `NoMethodError: undefined method 'turbo_stream'`, a implementação core está quebrada e todos os SCs falham em runtime.
result: [pendente]

### 2. WARNING — SC3: Primeira resposta com página Aprovações vazia
expected: Limpar todas as ApprovalResponses. Abrir página Aprovações (estado vazio). Cliente submete resposta. Nova linha aparece no topo sem reload. (Nota: `approvals-tbody` só renderizado quando há registros — tbody ausente no estado vazio pode causar falha silenciosa do prepend)
result: [pendente]

### 3. SC1: Admin em qualquer página recebe toast em < 2 segundos
expected: Admin logado no Dashboard. Cliente submete resposta. Toast aparece com nome do cliente, badge de decisão e link "Ver arte" dentro de 2 segundos.
result: [pendente]

### 4. SC4: Badge do sidebar incrementa em tempo real
expected: Badge mostrando N → N+1 quando cliente submete "Pediu Alteração", sem reload da página.
result: [pendente]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
