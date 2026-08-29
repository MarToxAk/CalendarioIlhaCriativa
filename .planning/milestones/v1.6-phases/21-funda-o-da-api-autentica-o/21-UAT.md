---
status: complete
phase: 21-funda-o-da-api-autentica-o
source: [21-01-SUMMARY.md, 21-02-SUMMARY.md, 21-03-SUMMARY.md, 21-04-SUMMARY.md, 21-05-SUMMARY.md]
started: 2026-06-11
updated: 2026-06-11
---

## Current Test

[testing complete — 7/7 pass, signed off 2026-06-11]

## Tests

### 1. Cold Start Smoke Test
expected: App boots from scratch with the new gems (jwt, rack-cors), CORS middleware, and /api/v1 routes; `/up` returns 200; the API routes are mounted.
result: pass
evidence: Servidor sobe (Puma :8080), `/up` → 200; `POST /api/v1/client/session` responde (não-404), rotas montadas.

### 2. Admin login → JWT 24h (success criterion 1)
expected: POST /api/v1/admin/session com email+senha válidos retorna 201 + JWT com expiração configurável (padrão 24h).
result: pass
evidence: HTTP 201, `data.token` JWT `scope:"admin"`, `expires_in: 86400` (24h).

### 3. Client login token+senha → client JWT (success criterion 2)
expected: POST /api/v1/client/session com access_token+senha válidos retorna JWT de cliente (scope client); access_token sozinho não basta.
result: pass
evidence: HTTP 201, `data.token` JWT `scope:"client"`. Login exige senha além do token (D-01).

### 4. IA auth via API key ak_ (success criterion 3)
expected: IA autentica com API key dedicada (`ak_`) via Authorization: Bearer, comparada em tempo constante.
result: pass
evidence: `Ai::BaseController` exige prefixo `ak_` + `ActiveSupport::SecurityUtils.secure_compare`; chave de credentials presente (`ak_`); compare correta=true/errada=false. Endpoint HTTP da IA chega na fase 24 — guard verificado a nível de serviço.

### 5. Sem credencial válida → 401 estruturado (success criterion 4)
expected: Requisição sem credencial válida retorna 401 com corpo JSON estruturado (`errors`); mensagens genéricas (sem enumeração).
result: pass
evidence: Admin senha errada / email inexistente / cliente senha errada / cliente inativo → todos 401 `{errors:[{code:"invalid_credentials",...}]}`, mesma mensagem (sem enumeração).

### 6. Envelope consistente + HTTP correto (success criterion 5)
expected: Toda resposta segue `{ data, meta, errors }`; erros com código HTTP correto.
result: pass
evidence: 201 (sucesso), 401 (auth inválida), 400 (param faltando) — todos no envelope `{data, meta, errors}`.

### 7. Defesas do JWT (alg:none / adulterado / expirado)
expected: Tokens com `alg:none`, assinatura adulterada ou expirados são rejeitados.
result: pass
evidence: alg:none → `Api::Errors::TokenInvalid`; adulterado → `TokenInvalid`; expirado → `TokenExpired`. HS256 fixado no decode.

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0

## Gaps

[none]
