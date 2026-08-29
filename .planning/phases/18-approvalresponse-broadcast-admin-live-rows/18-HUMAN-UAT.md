---
status: partial
phase: 18-approvalresponse-broadcast-admin-live-rows
source: [18-VERIFICATION.md]
started: 2026-06-05T20:00:00Z
updated: 2026-06-05T20:00:00Z
---

## Current Test

number: 4
name: "SC4: Badge do sidebar incrementa em tempo real"
expected: |
  Badge mostrando N no sidebar. Cliente submete "Pediu Alteração". Badge muda para N+1 sem reload.
awaiting: user response

## Tests

### 1. CRÍTICO — turbo_stream disponível em contexto de Model
expected: `bin/rails test test/models/approval_response_test.rb` com DB funcional — todos os testes A-G passam sem NoMethodError. Se Tests C-G falharem com `NoMethodError: undefined method 'turbo_stream'`, a implementação core está quebrada e todos os SCs falham em runtime.
result: issue
reported: "ActionView::MissingTemplate: Missing partial application/_decision_badge — _approval_row.html.erb linha 6 chama render 'decision_badge' (path relativo) mas ApplicationController.render resolve em application/ em vez de admin/approvals/"
severity: blocker
fix_applied: "Substituído render 'decision_badge' por render 'admin/approvals/decision_badge' em _approval_row.html.erb — commit 046aa77"
reteste: pass — toast apareceu após fix
feature_request: "sinal sonoro ao receber notificação — fora do escopo da fase 18"

### 2. WARNING — SC3: Primeira resposta com página Aprovações vazia
expected: Limpar todas as ApprovalResponses. Abrir página Aprovações (estado vazio). Cliente submete resposta. Nova linha aparece no topo sem reload. (Nota: `approvals-tbody` só renderizado quando há registros — tbody ausente no estado vazio pode causar falha silenciosa do prepend)
result: pass

### 3. SC1: Admin em qualquer página recebe toast em < 2 segundos
expected: Admin logado no Dashboard. Cliente submete resposta. Toast aparece com nome do cliente, badge de decisão e link "Ver arte" dentro de 2 segundos.
result: pass

### 4. SC4: Badge do sidebar incrementa em tempo real
expected: Badge mostrando N → N+1 quando cliente submete "Pediu Alteração", sem reload da página.
result: [pendente]

## Summary

total: 4
passed: 3
issues: 1
pending: 1
skipped: 0
blocked: 0

## Gaps

- truth: "broadcasts_to_admin deve renderizar partials sem ActionView::MissingTemplate"
  status: fixed
  reason: "ApplicationController.render resolve partiais relativas ao namespace application/ — _approval_row.html.erb usava render 'decision_badge' (relativo) em vez de render 'admin/approvals/decision_badge' (absoluto)"
  severity: blocker
  test: 1
  fix_commit: "046aa77"
