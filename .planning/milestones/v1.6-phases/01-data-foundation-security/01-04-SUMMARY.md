---
plan: 01-04
status: completed
completed_at: 2026-05-24
---

# Summary: Rack::Attack — Proteção contra Brute-Force

## O que foi feito

Criado `config/initializers/rack_attack.rb` com 4 throttles e teste de integração com 5 casos.

## Throttles configurados

1. `client_portal/password_by_token` — 5 tentativas / 20s por token (discriminator: token no path)
2. `client_portal/password_by_ip` — 10 tentativas / 60s por IP (fallback)
3. `admin/login_by_ip` — 5 tentativas / 60s por IP para POST /session
4. `client_portal/token_enum_by_ip` — 20 GET / 60s por IP para enumeração de tokens

Resposta 429 customizada: HTML com "Muitas tentativas".

## Desvios / Decisões

Nenhum desvio em relação ao RESEARCH.md. O Rack::Attack se auto-insere no middleware stack via gem — não foi necessário adicionar `config.middleware.use Rack::Attack` manualmente.

## Verificações

- `bin/rails middleware | grep -i attack` → `use Rack::Attack`
- 5 testes de integração passando
- 6ª tentativa de POST /c/TOKEN/session → HTTP 429 com "Muitas tentativas"
- Token diferente não bloqueado quando outro token atinge o limite (discriminator por token funciona)

## Requisitos cobertos

- AUTH-04: proteção contra brute-force no endpoint de senha do cliente
