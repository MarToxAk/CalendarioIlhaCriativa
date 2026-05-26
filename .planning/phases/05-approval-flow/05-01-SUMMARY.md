---
phase: 05-approval-flow
plan: "01"
subsystem: approval-data-foundation
tags:
  - approval-flow
  - migration
  - has-many
  - routes
dependency_graph:
  requires:
    - 04-client-calendar-portal
  provides:
    - approval-response-history
    - mark-revised-action
    - consolidated-admin-routes
  affects:
    - app/models/arte.rb
    - app/models/approval_response.rb
    - app/controllers/admin/artes_controller.rb
    - config/routes.rb
tech_stack:
  added: []
  patterns:
    - has_many com scope de ordenação (created_at desc)
    - Validator com múltiplos estados permitidos (pending? || revised?)
    - member route para ação de estado (mark_revised)
key_files:
  created:
    - db/migrate/20260526000001_allow_multiple_approval_responses.rb
    - app/models/approval_response.rb
    - db/migrate/20260524215205_create_clients.rb
    - db/migrate/20260524215208_create_approval_responses.rb
    - test/models/approval_response_test.rb
  modified:
    - app/models/arte.rb
    - app/controllers/admin/artes_controller.rb
    - app/views/admin/artes/show.html.erb
    - config/routes.rb
    - test/controllers/admin/artes_controller_test.rb
    - db/schema.rb
decisions:
  - "has_many com scope ordered: facilita exibição de histórico sem query extra"
  - "Validator aceita pending? || revised?: permite re-aprovação após ciclo de revisão (APRO-03)"
  - "mark_revised como member route PATCH: consistente com convenção REST de transições de estado"
  - "Sem Client::ResponsesController ainda: será implementado em 05-02 (Wave 2)"
metrics:
  duration: "6 minutes"
  completed_date: "2026-05-26"
  tasks_completed: 2
  files_changed: 10
---

# Phase 05 Plan 01: Approval Data Foundation Summary

**One-liner:** Migração remove índice único em approval_responses.arte_id, Arte muda para has_many :approval_responses, validator aceita revised?, rotas admin consolidadas com mark_revised.

## What Was Built

### Task 1: Migração + Arte model has_many + ApprovalResponse validator (TDD)

**Migração `20260526000001_allow_multiple_approval_responses`:**
- Remove o índice `unique: true` em `approval_responses.arte_id`
- Recria o índice sem unicidade (permite histórico de múltiplas respostas por arte)
- db/schema.rb atualizado: índice sem `unique: true`

**Arte model (`app/models/arte.rb`):**
- `has_one :approval_response` → `has_many :approval_responses, -> { order(created_at: :desc) }, dependent: :destroy`
- Scope de ordenação garante que a resposta mais recente vem primeiro

**ApprovalResponse model (`app/models/approval_response.rb`):**
- Validator `arte_must_be_pending`: `unless arte.pending?` → `unless arte.pending? || arte.revised?`
- Mensagem de erro: "já foi respondida" → "não está em estado aprovável"
- Permite re-aprovação após ciclo de revisão (APRO-03)

**Testes TDD (5 testes verdes):**
- Segunda ApprovalResponse falha por validator, não por unique violation
- ApprovalResponse válida para arte com status `revised`
- `arte.approval_responses` retorna CollectionProxy (has_many)
- ApprovalResponse inválida para arte `approved`

### Task 2: Consolidar rotas admin + corrigir check_deletable + action mark_revised

**Routes (`config/routes.rb`):**
- Removida duplicação dos dois blocos `namespace :admin { resources :artes }`
- Único bloco admin com `resources :artes` + `member { patch :mark_revised }`
- Portal cliente: `resources :artes` aninhados com `resources :responses` para fluxo de aprovação

**Admin::ArtesController:**
- `before_action :set_arte` inclui `:mark_revised`
- `check_deletable`: `@arte.approval_response.nil?` → `@arte.approval_responses.none?`
- Action `mark_revised`: verifica `change_requested?`, chama `revised!`, redireciona com notice/alert

**View `show.html.erb`:**
- Botão Excluir: `approval_response.nil?` → `approval_responses.none?`

**Testes adicionados (2 novos, total 9 no controller):**
- `mark_revised muda status para revised quando change_requested`
- `mark_revised rejeita arte nao change_requested`

## Verification Results

```
68 runs, 186 assertions, 0 failures, 0 errors, 0 skips
```

Rotas verificadas:
- `mark_revised_admin_arte PATCH /admin/artes/:id/mark_revised` — sem duplicatas
- `client_arte_responses POST /c/:token/artes/:arte_id/responses` — rota aninhada para Wave 2

Nenhum uso singular de `approval_response` em controllers/views (grep retornou 0 linhas).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Bloqueio] Arquivos não commitados no repo principal não estavam no worktree**
- **Found during:** Task 1
- **Issue:** O worktree foi criado antes de `approval_response.rb`, `client.rb` e suas migrações serem commitadas no repo principal. O worktree não tinha esses arquivos.
- **Fix:** Copiados para o worktree: `app/models/approval_response.rb`, `db/migrate/20260524215205_create_clients.rb`, `db/migrate/20260524215208_create_approval_responses.rb`.
- **Files modified:** Arquivos adicionados ao worktree como novos arquivos.
- **Commit:** 18af5a7

**2. [Observação] Flakiness pré-existente do Rack::Attack em testes paralelos**
- **Found during:** Verificação final
- **Issue:** `SessionsControllerTest#test_login_com_credenciais_corretas_redireciona_para_admin_dashboard` falha com 429 em execuções paralelas por contaminação de estado do Rack::Attack entre workers.
- **Fix:** Não aplicável — falha pré-existente, passa isoladamente e na maioria das execuções paralelas. Documentado aqui para o verifier.
- **Scope:** Fora do escopo desta task (pré-existente). Deferir para `deferred-items.md` se necessário.

## Known Stubs

Nenhum — todos os dados estão roteados via models reais e banco de dados.

## Threat Flags

Nenhum — todas as superfícies cobertas pelo threat_model do plano:
- T-05-01-02: `mark_revised` protegido por `Admin::BaseController` com autenticação de admin em before_action.

## Self-Check: PASSED

- [x] `db/migrate/20260526000001_allow_multiple_approval_responses.rb` — EXISTS
- [x] `app/models/arte.rb` tem `has_many :approval_responses` — CONFIRMED
- [x] `app/models/approval_response.rb` tem `arte.pending? || arte.revised?` — CONFIRMED
- [x] `test/models/approval_response_test.rb` — EXISTS (5 testes verdes)
- [x] `config/routes.rb` — consolidado, sem duplicatas
- [x] `app/controllers/admin/artes_controller.rb` — `approval_responses.none?` + `mark_revised`
- [x] Commits: 6601620 (test RED), 18af5a7 (feat GREEN), 9d73ffe (feat Task 2) — VERIFIED
- [x] Suite completa: 68 testes verdes (sem falhas nas nossas mudanças)
