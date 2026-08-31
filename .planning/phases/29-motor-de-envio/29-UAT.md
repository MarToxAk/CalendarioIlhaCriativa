---
status: testing
phase: 29-motor-de-envio
source: [29-VERIFICATION.md]
started: 2026-08-31
updated: 2026-08-31
---

## Current Test

number: 1
name: Round-trip real de envio pelo Evolution (sendText / sendMedia)
expected: |
  Com uma instância WhatsApp pareada e um grupo de teste, agendar uma Divulgação e deixar
  o motor disparar:
  - arte com legenda chega ao grupo como MÍDIA COM LEGENDA;
  - arte caption_only chega como MENSAGEM DE TEXTO;
  - o Evolution consegue baixar a URL presignada da mídia do começo ao fim do disparo;
  - a resposta de sucesso traz `key.id` (gravado em `divulgacao_grupos.evolution_message_id`);
  - `divulgacao_grupos.status` vira `enviado` e `sent_at` fica preenchido SÓ após o 2xx.
awaiting: user response

## Tests

### 1. Round-trip real de envio pelo Evolution (sendText / sendMedia)
expected: mídia+legenda / texto puro chegam ao grupo; Evolution baixa a URL presignada; `key.id` presente; `status=enviado` + `sent_at` só pós-2xx.
result: [pending]

### 2. Formato real do erro 4xx do sendMedia (grupo announce / número não-admin / arquivo inválido)
expected: o texto livre do `BadRequestException` do Evolution é truncado (≤500) e gravado em `divulgacao_grupos.error_code` via `sanitize_error_code` (sem vazar URL presignada nem token); `status=falhou`; o job faz `discard_on` (sem retry automático).
result: [pending]

### 3. Teto real de mídia deste gateway (imagem e vídeo: 5 / 15 / 20 / 30 MB)
expected: confirmar o teto real que o gateway/WhatsApp aceita e comparar com `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES` (16 MB, heurística). Se divergir, só a constante muda.
result: [pending]

### 4. Decisão de escopo — SC5 "cancelar uma Divulgação EM ANDAMENTO"
expected: |
  O ROADMAP SC5 da fase 29 diz "Cancelar uma Divulgação em andamento impede os grupos ainda
  não atendidos de receber". O código atual: `Divulgacao#cancelar!` só transiciona de
  `agendada`, e o `DispatchJob` vira o status para `em_andamento` no início do disparo. Os
  jobs individuais JÁ checam `divulgacao.status_cancelada?` no `perform` (então a mecânica de
  respeitar o cancelamento existe), mas não há caminho de UI para o admin marcar `cancelada`
  depois que o disparo começou. O requisito DIVU-08 em REQUIREMENTS.md diz "agendada", e o
  29-03-PLAN.md defere explicitamente o cancelamento in-flight para a fase 30 (ACOMP-02 /
  reenvio + controle ao vivo).
  DECISÃO NECESSÁRIA: a fase 30 deve adicionar o botão "cancelar disparo em andamento"
  (transição `em_andamento → cancelada`), ou o escopo do v1.7 para de fato em "cancelar antes
  de começar"?
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps

- Itens 1–3: caminho de escrita do Evolration (write-path) é UAT de operador — `.planning/notes/evolution-contract.md` marca como PENDENTE; nenhuma instância pareada alcançável neste ambiente. O contrato de código, a taxonomia de erro, a idempotência e a revalidação foram verificados por inspeção + 112 testes automatizados (0 falhas).
- Item 4: decisão de produto/escopo que afeta o planejamento da fase 30.
