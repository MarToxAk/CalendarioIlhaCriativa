---
status: partial
phase: 05-approval-flow
source: [05-VERIFICATION.md]
started: 2026-05-26T14:45:00-03:00
updated: 2026-05-26T14:45:00-03:00
---

## Current Test

[aguardando testes manuais no browser]

## Tests

### 1. Fluxo Aprovar no browser
expected: Flash verde "Arte aprovada!" aparece após clicar Aprovar, botões Aprovar/Pedir Alteração desaparecem da página, arte mostra status "Aprovado"
result: [pending]

### 2. Toggle do formulário Pedir Alteração
expected: Clicar "Pedir Alteração" expande o textarea inline via Stimulus sem reload de página; "Cancelar" colapsa o formulário; "Enviar" salva e redireciona com flash
result: [pending]

### 3. Botão Marcar como Revisada no admin
expected: Botão "Marcar como Revisada" aparece APENAS em artes com status change_requested; clicar muda status para revised; botão não aparece em artes pending ou approved
result: [pending]

### 4. Ciclo completo APRO-03 via browser
expected: Admin cria arte → cliente pede alteração → arte vai para change_requested → admin marca revisada → arte vai para revised → cliente aprova → arte approved; histórico mostra todas as respostas
result: [pending]

### 5. Renderização visual do histórico
expected: Seção "Histórico de respostas" aparece abaixo dos botões com ícone verde (✓) para aprovação e vermelho (✕) para alteração, data/hora formatada dd/mm/yyyy HH:MM, comentário opcional exibido
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
