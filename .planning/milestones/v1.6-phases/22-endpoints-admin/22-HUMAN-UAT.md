---
status: passed
phase: 22-endpoints-admin
source: [22-VERIFICATION.md]
started: 2026-06-11T00:00:00Z
updated: 2026-06-11T17:05:00Z
---

## Current Test

[all tests passed — runtime validated against dev server on 2026-06-11]

## Tests

### 1. POST /api/v1/admin/clients devolve a senha do portal
expected: Campo `password` em `data` contém a senha em texto plano exatamente como enviada pelo app (D-05); GET de clientes nunca devolve `password`.
result: passed — POST retornou 201 com `data.password="segredo-do-portal-123"` e `data.portal_url="http://.../c/<token>"`. GET index do mesmo cliente expôs apenas `id, name, active, created_at` (sem password/access_token/portal_url). 401 sem token confirmado.

### 2. POST /api/v1/admin/artes com multipart/form-data retorna media_url absoluta
expected: `data.media_url` contém URL absoluta com host correto do servidor (blob Active Storage), sem `ArgumentError: Missing host` nem URL parcial; `media_source_type='upload'`.
result: passed — POST multipart retornou 201 com `media_url="http://127.0.0.1:3210/rails/active_storage/disk/...sample.jpg"` (absoluta) e `media_source_type="upload"`. A própria media_url respondeu 200 `image/jpeg`. POST com `external_url` retornou `media_source_type="link"` (D-02); POST sem mídia retornou 422.

### 3. GET /api/v1/admin/artes?status=invalido retorna 400 (não 500)
expected: HTTP 400 com body `{ data: null, meta: {}, errors: [...] }` via cadeia de `rescue_from` (mesmo comportamento para `month` inválido).
result: passed — `?status=invalido` e `?month=nao-data` retornaram ambos 400 com envelope `{ data: null, meta: {}, errors: [{code:"bad_request", ...}] }`. Filtros válidos combinados (client_id+status+month) retornaram 200.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

Nenhum. Verificação extra também confirmou APIADM-05: GET /api/v1/admin/artes/:arte_id/approval_responses retornou 200 com `meta.arte_status`. Dados de QA criados durante o teste foram removidos (cascade destroy).
