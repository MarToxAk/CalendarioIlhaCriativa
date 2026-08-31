---
status: testing
phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes
source: [31-VERIFICATION.md]
started: 2026-08-31T22:05:00Z
updated: 2026-08-31T22:05:00Z
---

## Current Test

number: 1
name: Toggle Stimulus "Novo número (QR)" vs "Reutilizar conexão existente" — comportamento visual/interativo
expected: |
  No painel WhatsApp (admin/clients#show) de um cliente SEM instância, ao clicar entre os
  rótulos "Novo número (QR)" e "Reutilizar conexão existente" (radios sr-only via Stimulus
  whatsapp-provision-toggle):
  - O pill clicado assume a classe ativa (borda/fundo/texto verde #0F7949), o outro volta
    ao estilo inativo (borda cinza).
  - O campo correspondente aparece/some: botão "Criar instância" (Novo número) vs formulário
    de seleção de conexão com <select> (Reutilizar).
  - O botão "Reutilizar conexão" começa DESABILITADO e só habilita depois de escolher uma
    opção no <select>.
  - Ao submeter "Reutilizar conexão", o turbo_confirm com o aviso pt-BR de compartilhamento
    (MESMO número físico, MESMA sessão, compartilhada) aparece ANTES do POST.
awaiting: user response

## Tests

### 1. Toggle Stimulus "Novo número (QR)" vs "Reutilizar conexão existente"
expected: (ver acima)
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
