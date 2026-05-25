---
phase: 02-admin-auth-client-management
plan: "05"
subsystem: client-auth-portal
tags: [client-auth, portal-guard, admin-ui, active-flag, clie-03]
dependency_graph:
  requires: ["02-01", "02-02", "02-03", "02-04"]
  provides: ["CLIE-03-complete", "inactive-client-block"]
  affects: ["client_controller", "sessions_controller", "confirm_modal"]
tech_stack:
  added: []
  patterns:
    - "hidden_fields local em partial com iteração de hash dois níveis"
    - "guard unless active? antes de render/authenticate com return explícito"
key_files:
  created: []
  modified:
    - app/views/admin/clients/_confirm_modal.html.erb
    - app/views/admin/clients/show.html.erb
    - app/controllers/client_controller.rb
    - app/controllers/client/sessions_controller.rb
    - test/controllers/admin/clients_controller_test.rb
    - test/controllers/client/sessions_controller_test.rb
decisions:
  - "Guard inactive em load_client_from_token retorna 403 para todas as rotas do portal — sessions#create recebe 403 (não 422) porque load_client_from_token dispara primeiro via before_action"
  - "hidden_fields: local no _confirm_modal com iteração dois níveis (outer_key[inner_key]) preserva compatibilidade com modais existentes sem hidden_fields"
metrics:
  duration: "~20 min"
  completed_date: "2026-05-25"
  tasks_completed: 2
  files_modified: 6
---

# Phase 02 Plan 05: Fechar Blockers CLIE-03 (hidden_fields + guards active?) Summary

**One-liner:** Guard `unless active?` no portal bloqueia clientes inativos com 403; `_confirm_modal` com suporte a `hidden_fields:` local envia `client[active]=false` no PATCH.

## What Was Built

Dois blockers do CLIE-03 foram resolvidos:

**Blocker 1 — _confirm_modal sem payload de desativação:**
- Adicionado local `hidden_fields:` ao partial `_confirm_modal.html.erb` com iteração de hash dois níveis
- `show.html.erb` agora passa `hidden_fields: { client: { active: false } }` no render de desativação
- Modal de rotação de token preservado sem alterações

**Blocker 2 — Portal não bloqueava clientes inativos:**
- `client_controller.rb`: guard `unless @client.active?` após `find_by!` retorna 403 imediato
- `client/sessions_controller.rb`: guard `unless @client.active?` antes de `authenticate` com `return` explícito
- Testes de regressão cobrem o fluxo completo CLIE-03

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Corrigir _confirm_modal + show.html.erb | b01fbcb | _confirm_modal.html.erb, show.html.erb, admin clients_controller_test.rb |
| 2 | Guards active? no portal + testes | b41ac9d | client_controller.rb, sessions_controller.rb, sessions_controller_test.rb |

## Test Results

- `bin/rails test test/controllers/admin/clients_controller_test.rb`: 6 runs, 0 failures (4 existentes + 2 CLIE-03)
- `bin/rails test test/controllers/client/sessions_controller_test.rb`: 7 runs, 0 failures (5 existentes + 2 CLIE-03)
- `bin/rails test test/controllers/`: 25 runs, 0 failures, 0 errors

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrigido status esperado no teste de POST cliente inativo**
- **Found during:** Task 2 (fase GREEN)
- **Issue:** O plano especificava que `sessions#create` retornaria 422 para cliente inativo. Porém, `load_client_from_token` é um `before_action` que roda ANTES de `create` — incluindo para `:new` e `:create` (apenas `require_client_auth` é pulado). O guard em `load_client_from_token` retorna 403 antes de chegar ao método `create`, tornando o guard no `create` redundante mas mantido por defesa em profundidade.
- **Fix:** Teste ajustado para `assert_response :forbidden` (403) em vez de `:unprocessable_entity` (422). O comportamento funcional é correto — cliente inativo não autentica.
- **Files modified:** test/controllers/client/sessions_controller_test.rb
- **Commit:** b41ac9d

## Known Stubs

None.

## Threat Surface Scan

Nenhuma nova superfície além das documentadas no threat model do plano (T-02-14, T-02-15, T-02-16). Os guards adicionados reduzem a superfície de ataque (T-02-15 e T-02-16 mitigados).

## Self-Check: PASSED

- [x] app/views/admin/clients/_confirm_modal.html.erb — modificado, contém 4 ocorrências de "hidden_fields"
- [x] app/views/admin/clients/show.html.erb — contém "active: false" no render de desativação
- [x] app/controllers/client_controller.rb — contém guard "active?" e status :forbidden
- [x] app/controllers/client/sessions_controller.rb — contém guard "active?" e return explícito
- [x] test/controllers/admin/clients_controller_test.rb — 6 runs, 0 failures
- [x] test/controllers/client/sessions_controller_test.rb — 7 runs, 0 failures
- [x] Commit b01fbcb (Task 1) existe
- [x] Commit b41ac9d (Task 2) existe
