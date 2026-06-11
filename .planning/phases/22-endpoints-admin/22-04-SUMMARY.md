---
phase: 22-endpoints-admin
plan: "04"
subsystem: api-admin-approval-responses
tags: [rails, api, controller, approval-responses, nested-resource, poro-serializer]
dependency_graph:
  requires:
    - app/controllers/api/v1/admin/base_controller.rb (Pagy, authenticate_admin_jwt!, render_envelope)
    - app/serializers/api/v1/admin/approval_response_serializer.rb (arte_status: kwarg)
    - app/models/arte.rb (has_many :approval_responses ordered desc, Arte.find)
    - app/models/approval_response.rb (enum decision, campos comment/responded_at)
    - config/routes.rb (GET /api/v1/admin/artes/:arte_id/approval_responses — já existia de 22-01)
  provides:
    - app/controllers/api/v1/admin/approval_responses_controller.rb
    - test/controllers/api/v1/admin/approval_responses_controller_test.rb
  affects: []
tech_stack:
  added: []
  patterns:
    - Rota aninhada com params[:arte_id] — D-10
    - arte_status como kwarg ao serializer para evitar N+1 — aproveitando @arte já em memória
    - rescue_from RecordNotFound herdado do base — sem rescue local
key_files:
  created:
    - app/controllers/api/v1/admin/approval_responses_controller.rb
    - test/controllers/api/v1/admin/approval_responses_controller_test.rb
  modified: []
decisions:
  - "params[:arte_id] usado em set_arte (rota aninhada gera :arte_id, não :id)"
  - "Arte.find levanta RecordNotFound automaticamente — capturado pelo rescue_from herdado do Api::V1::BaseController"
  - "arte_status passado como kwarg ao serialize_collection — evita N+1 (arte já carregado via @arte)"
  - "meta inclui arte_status conforme D-11 — status atual da arte acompanha o histórico de aprovações"
metrics:
  duration: "5 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  files_count: 2
---

# Phase 22 Plan 04: ApprovalResponsesController — Histórico de Aprovações por Arte

Controller de histórico de aprovações aninhado por arte (APIADM-05): GET /api/v1/admin/artes/:arte_id/approval_responses retorna todas as ApprovalResponses da arte com campos D-11 e meta.arte_status, sem N+1, com testes cobrindo campos obrigatórios, 404 e 401.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Criar Api::V1::Admin::ApprovalResponsesController | ea5cf73 | app/controllers/api/v1/admin/approval_responses_controller.rb |
| 2 | Criar testes de integração para ApprovalResponsesController | 5f54dbe | test/controllers/api/v1/admin/approval_responses_controller_test.rb |

## What Was Built

### Task 1 — ApprovalResponsesController

Criado `app/controllers/api/v1/admin/approval_responses_controller.rb` com:

- Herança de `Api::V1::Admin::BaseController` — autenticação JWT admin herdada automaticamente via `before_action :authenticate_admin_jwt!`
- `before_action :set_arte` — carrega `@arte = Arte.find(params[:arte_id])` antes da ação index
- `def index` — obtém `responses = @arte.approval_responses` (associação já ordenada `created_at: :desc` via lambda no model) e chama `render_envelope` com:
  - `data:` — `Api::V1::Admin::ApprovalResponseSerializer.serialize_collection(responses, arte_status: @arte.status)` passando arte_status como kwarg para evitar N+1
  - `meta: { arte_status: @arte.status }` — status atual da arte no meta conforme D-11
- Sem rescue local — `Arte.find` lança `ActiveRecord::RecordNotFound` capturado pelo `rescue_from` herdado de `Api::V1::BaseController` que retorna 404
- Sem `.includes(:arte)` desnecessário — `arte_status` vem de `@arte` já em memória

### Task 2 — Testes de Integração

Criado `test/controllers/api/v1/admin/approval_responses_controller_test.rb` com:

- Setup baseado no padrão de `sessions_controller_test.rb`: injeção de `JWT_SECRET`, criação de `@user`
- Fixtures adicionais: `@client`, `@arte` (status: pending, instagram, image, external_url), `@response1` (approved)
- Geração de `@admin_jwt` via `Api::JwtService.encode` e `@auth_headers`
- 4 testes cobrindo: 200 + lista + meta.arte_status, campos D-11 (id/decision/comment/responded_at/arte_status), 404 para arte inexistente, 401 sem Authorization header
- Verificação de runtime adiada (bin/rails test não executável neste ambiente — constraint do projeto)

## Deviations from Plan

None — plano executado exatamente como escrito.

## Known Stubs

None — controller lê dados reais do banco via associação `@arte.approval_responses`.

## Threat Flags

None — sem nova superfície além do previsto no `<threat_model>` do plano.
- T-22-17 (Spoofing — GET sem JWT → 401): mitigado via `authenticate_admin_jwt!` herdado
- T-22-16 (cross-arte): aceito por design (admin vê todas as artes)
- T-22-18 (arte_status no meta): aceito — não é informação sensível para admin autenticado
- T-22-19 (sem paginação): aceito — histórico de uma arte é naturalmente limitado

## Runtime Verification (Deferred)

`bin/rails test test/controllers/api/v1/admin/approval_responses_controller_test.rb` não pode ser executado neste ambiente (banco de teste pertence a outro usuário do SO). Aceitação por inspeção de código-fonte.

## Self-Check: PASSED

- app/controllers/api/v1/admin/approval_responses_controller.rb — FOUND
- test/controllers/api/v1/admin/approval_responses_controller_test.rb — FOUND
- Commit ea5cf73 — FOUND
- Commit 5f54dbe — FOUND
