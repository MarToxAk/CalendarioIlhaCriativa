---
status: complete
phase: 20-admin-calendar-chips-real-time
source:
  - 20-00-SUMMARY.md
  - 20-01-SUMMARY.md
started: 2026-06-09T00:00:00Z
updated: 2026-06-09T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Anel de status no chip (estado inicial)
expected: Ao abrir /admin/calendar, chips de artes approved/change_requested/revised exibem anel colorido (verde/vermelho/cinza); artes pending sem anel; fundo permanece na cor do cliente com as iniciais.
result: pass

### 2. Chip atualiza ao vivo quando cliente responde
expected: Com o calendário admin aberto numa aba, o cliente registra uma aprovação ou um pedido de alteração (outra aba/dispositivo via link do cliente). O chip da arte correspondente ganha/atualiza o anel (verde para aprovada, vermelho para pediu alteração) dentro de ~2 segundos, SEM recarregar a página.
result: pass

### 3. Chip atualiza ao vivo quando admin marca Revisada
expected: Com o calendário admin aberto, marcar uma arte como "Revisada" (ação mark_revised). O chip daquela arte passa a exibir o anel cinza (#475569) em tempo real, sem recarregar a página.
result: pass

### 4. Sem chips duplicados / DOM extra
expected: Após uma ou mais atualizações ao vivo, cada arte tem exatamente UM chip na célula do dia. Nenhum chip duplicado, nenhum elemento extra aparece, e o badge "+N" de overflow continua coerente.
result: pass

### 5. Badge do sidebar correto após sequência de eventos (RTUP-01)
expected: Após uma sequência de eventos (aprovação, pedido de alteração, revisão), o número do badge no sidebar admin reflete corretamente a contagem de artes com "Pediu Alteração" não revisadas — incrementa no pedido de alteração e decrementa quando a arte é revisada.
result: pass

## Summary

total: 5
passed: 5
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
