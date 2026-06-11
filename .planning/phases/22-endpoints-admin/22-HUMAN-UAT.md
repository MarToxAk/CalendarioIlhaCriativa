---
status: partial
phase: 22-endpoints-admin
source: [22-VERIFICATION.md]
started: 2026-06-11T00:00:00Z
updated: 2026-06-11T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. POST /api/v1/admin/clients devolve a senha do portal
expected: Campo `password` em `data` contém a senha em texto plano exatamente como enviada pelo app (D-05); GET de clientes nunca devolve `password`.
result: [pending]

### 2. POST /api/v1/admin/artes com multipart/form-data retorna media_url absoluta
expected: `data.media_url` contém URL absoluta com host correto do servidor (blob Active Storage), sem `ArgumentError: Missing host` nem URL parcial; `media_source_type='upload'`.
result: [pending]

### 3. GET /api/v1/admin/artes?status=invalido retorna 400 (não 500)
expected: HTTP 400 com body `{ data: null, meta: {}, errors: [...] }` via cadeia de `rescue_from` (mesmo comportamento para `month` inválido).
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
