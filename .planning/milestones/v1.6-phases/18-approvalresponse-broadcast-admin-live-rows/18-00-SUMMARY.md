# Plan 18-00 Summary — RED Tests: broadcasts_to_admin

**Status:** Complete
**Wave:** 1
**Completed:** 2026-06-05

## O que foi entregue

**Tarefa 1 — Testes RED (callback e broadcast call):**
- Adicionados ao `test/models/approval_response_test.rb` os testes A–D que falham assertivamente até que Plan 02 implemente `broadcasts_to_admin`
- Test A: `respond_to?(:broadcasts_to_admin, true)` — verifica método privado existe
- Test B: `_commit_callbacks` inclui `:broadcasts_to_admin` — verifica after_create_commit registrado
- Test C: `change_requested` chama `broadcast_to` exatamente 1x
- Test D: `approved` chama `broadcast_to` exatamente 1x

**Tarefa 2 — Testes RED (contagem de streams e eager-load):**
- Test E: `change_requested` gera 4 Turbo Streams (toast + badge + dashboard + approvals)
- Test F: `approved` gera 3 Turbo Streams (sem badge — D-12 honrado)
- Test G: `Arte.includes(:client)` — verifica ausência de N+1 via JOIN/IN na query

**Alterações adicionais:**
- `config/database.yml`: adicionado `port: POSTGRES_PORT` para compatibilidade de ambiente
- `test/fixtures/clients.yml`: adicionado `access_token` nos 3 fixtures (requerido por `has_secure_token`)

## Commits
- `0cb9fa5`: fix(18-00): add postgres port config + fixture access_tokens for test setup
- `b111710`: test(18-00): RED tests for broadcasts_to_admin — callback, streams, eager-load

## Estado dos testes
Todos os novos testes (A–G) falham RED — `broadcasts_to_admin` não existe ainda em `ApprovalResponse`. Plan 02 os torna GREEN.

## Próximo passo
Plan 18-02: criar `_arte_dashboard_row.html.erb`, refatorar dashboard e adicionar `after_create_commit :broadcasts_to_admin` ao model.
