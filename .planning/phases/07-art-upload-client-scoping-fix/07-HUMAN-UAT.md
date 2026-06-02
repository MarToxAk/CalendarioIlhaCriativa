---
status: partial
phase: 07-art-upload-client-scoping-fix
source: [07-VERIFICATION.md]
started: 2026-06-02T17:41:46Z
updated: 2026-06-02T17:41:46Z
---

## Current Test

[aguardando testes humanos]

## Tests

### 1. Upload de arquivo via ActiveStorage
expected: Criar arte com arquivo real (imagem/vídeo), verificar que o preview aparece corretamente no portal do cliente após upload
result: [pending]

### 2. Re-exibição de erros :base
expected: Submeter formulário sem mídia (sem arquivo e sem link externo), verificar que aparece caixa vermelha com mensagem "Precisa de arquivo ou link externo"
result: [pending]

### 3. Selector de cliente sem client_id na URL
expected: Navegar para `/admin/artes/new` diretamente (sem client_id na URL), verificar que o dropdown de clientes está visível e funcional
result: [pending]

### 4. hidden_field via página do cliente
expected: Navegar por `/admin/clients/:id` → "Nova Arte", verificar que o selector de cliente NÃO aparece (campo hidden_field ativo, dropdown oculto)
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
