---
status: testing
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
source: [26-VERIFICATION.md]
started: "2026-08-30T15:06:45Z"
updated: "2026-08-30T15:06:45Z"
---

## Current Test

number: 1
name: "QR rotativo ao vivo — criar instância com host Evolution real"
expected: |
  bin/dev, autenticar como admin, cliente sem instância, clicar "Criar instância" com o host
  Evolution real acessível. O QR renderiza de last_qr_base64; qr_pairing_controller.js troca o
  <img> a cada ~20s sem quebrar; ao parear, a página recarrega e o card mostra badge "Conectada".
awaiting: user response

## Tests

### 1. QR rotativo ao vivo
expected: |
  QR aparece e rotaciona ~20-25s/ciclo até o pareamento concluir; para em "connected".
  Exige host Evolution real (whatsapp.bomcustoilhabela.com.br) + app deployado.
result: [pending]

### 2. Entrega inbound do webhook
expected: |
  Com o app em ilhacriativa.autopyweb.com.br, provocar connection.update real (parear/desconectar).
  POST Evolution -> /webhooks/evolution chega, autentica pelo X-Webhook-Secret, atualiza
  connection_state/last_checked_at/paired_at sem o admin clicar; POST sem header -> 401.
  (LÓGICA já coberta por test/controllers/webhooks/evolution_controller_test.rb — 12 testes verdes.)
result: [pending]

### 3. Inspeção visual (deferida pelo planejador em 26-05 Task 3)
expected: |
  Cliente "connected" recém-pareado (paired_at < 7 dias) + outro "awaiting_qr". Conferir:
  (1) badge de estado com cor certa, não quebra o layout do card "Informações";
  (2) banner de banimento âmbar, legível, acima do QR, sem checkbox;
  (3) texto de cautela de idade não estoura a largura do card;
  (4) clients#index — bolinha de conexão não quebra a linha da tabela em telas estreitas.
result: [pending]

### 4. OPERATOR paste-back do .env.example (carregado da 26-01)
expected: |
  grep -n EVOLUTION_WEBHOOK .env.example no host real -> as 5 chaves de exemplo presentes
  (ACTIVE_RECORD_ENCRYPTION_*, EVOLUTION_WEBHOOK_HMAC_KEY, EVOLUTION_WEBHOOK_BASE_URL), valores
  vazios exceto EVOLUTION_WEBHOOK_BASE_URL=https://ilhacriativa.autopyweb.com.br.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
