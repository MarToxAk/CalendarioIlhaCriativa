---
status: testing
phase: 30-acompanhamento-ao-vivo-hardening
source: [30-VERIFICATION.md]
started: 2026-08-31T14:30:00Z
updated: 2026-08-31T14:30:00Z
---

## Current Test

number: 1
name: SC1 (ACOMP-01) — Progresso ao vivo entre processos
expected: |
  Com `bin/dev` rodando (web + jobs + css), abra a página de uma Divulgação (#show), depois
  dispare a mudança de status de um grupo a partir de um processo separado (console, ou um
  disparo agendado real) enquanto a aba fica aberta. A pill de status da linha e a linha-resumo
  agregada (_progresso_resumo) devem atualizar ao vivo, sem recarregar a página, sem re-render
  da lista inteira.
awaiting: user response

## Tests

### 1. SC1 (ACOMP-01) — Progresso ao vivo entre processos
expected: |
  Com `bin/dev` rodando (web + jobs + css), abra a página de uma Divulgação (#show), depois
  dispare a mudança de status de um grupo a partir de um processo separado (console, ou um
  disparo agendado real) enquanto a aba fica aberta. A pill de status da linha e a linha-resumo
  agregada (_progresso_resumo) devem atualizar ao vivo, sem recarregar a página, sem re-render
  da lista inteira.
result: [pending]

### 2. SC2 (ACOMP-02) — Confirmação visual do reenvio
expected: |
  Numa Divulgação #show com uma linha `falhou`, clique em "Reenviar". Um diálogo nativo do
  navegador deve nomear o grupo específico; ao confirmar, a linha deve virar "Pendente ·
  reenfileirado" no mesmo lugar (sem reload); quando o job reenfileirado realmente rodar, a linha
  deve atualizar para o estado final ao vivo. O botão "Reenviar" não deve aparecer numa
  divulgação cancelada.
result: [pending]

### 3. SC5 (INFRA-07) — Retenção seletiva de failed_executions
expected: |
  Em desenvolvimento com `bin/dev` rodando, semeie um `SolidQueue::FailedExecution` com
  ~20 dias de idade e um com ~1 dia (cada um com um `SolidQueue::Job` pai real), depois rode a
  tarefa `prune_solid_queue_failed_executions`. A linha de ~20 dias e seu job pai devem
  desaparecer; a linha de ~1 dia e seu job pai devem sobreviver.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps

Nenhum gap de implementação — os 3 itens acima são invariantes de comportamento que só um
humano observando um navegador real / rodando a tarefa de retenção num ambiente real pode
confirmar; testes automatizados de processo único não conseguem provar entrega cross-process
do ActionCable, interação visual de diálogo nativo, nem o comportamento seletivo de descarte em
lote. ACOMP-02, ACOMP-03 e SEG-04 estão totalmente satisfeitos e comprovados por testes que o
verificador rodou diretamente (67 + 3 + demais execuções, 0 falhas).
