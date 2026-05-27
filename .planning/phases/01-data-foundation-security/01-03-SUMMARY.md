---
plan: 01-03
status: completed
completed_at: 2026-05-24
---

# Summary: Domain Models + Migrations

## O que foi feito

Três migrações e três models ActiveRecord criados. 12 testes unitários passando.

## Migrações

- `20260524215205_create_clients.rb` — tabela clients com access_token (unique), password_digest, active
- `20260524215206_create_artes.rb` — tabela artes com scheduled_on `:date` (não datetime), enums como integers
- `20260524215208_create_approval_responses.rb` — tabela approval_responses com foreign key única para arte_id

## Desvios / Decisões

**approval_responses — índice duplicado corrigido:** A migração original tinha `t.references :arte` (que cria `index_approval_responses_on_arte_id` automaticamente) E um `add_index :approval_responses, :arte_id, unique: true` explícito — conflito de nomes. Corrigido movendo `unique: true` para dentro do `t.references` via `index: { unique: true }` e removendo o `add_index` separado.

## Verificações

- `bin/rails db:migrate` → exit 0, três tabelas criadas
- `db/schema.rb` contém `t.date "scheduled_on", null: false` (não datetime)
- `Client.create!` gera token de 24 chars automaticamente
- `bin/rails test test/models/` → 12 testes, 0 falhas

## Requisitos cobertos

- AUTH-03: access_token 24 chars gerado por has_secure_token
- AUTH-04: has_secure_password autentica com bcrypt
- AUTH-05: token_version (first 8 chars) muda a cada regenerate_access_token
- AUTH-06: ApprovalResponse#sync_arte_status sincroniza status da Arte após decisão
