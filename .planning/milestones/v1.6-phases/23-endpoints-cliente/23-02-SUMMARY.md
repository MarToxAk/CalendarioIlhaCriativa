---
phase: 23-endpoints-cliente
plan: 02
subsystem: api
tags: [rails, pagy, controller, client-api, security, row-lock]

# Dependency graph
requires:
  - phase: 23-01
    provides: BaseController com Pagy::Backend + pagination_meta + per_page_param, ArteSerializer e ApprovalResponseSerializer POROs, rotas REST do cliente

provides:
  - Api::V1::Client::ArtesController com index (pending+revised paginado) e show (com approval_responses) escopados ao @current_client
  - Api::V1::Client::ApprovalResponsesController com create (enum guard + transaction + row-lock + save! + 201 com arte_status)

affects:
  - 23-03 (nenhuma dependência direta — plano de verificação/UAT)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Enum guard via ApprovalResponse.decisions.key? antes do build — levanta ParameterMissing → 400 estruturado"
    - "Arte.transaction + @current_client.artes.lock.find para row-level lock (PostgreSQL SELECT FOR UPDATE)"
    - "Render fora do bloco da transação via variável result — evita double render (Pitfall 5)"
    - "Escopo sempre via @current_client.artes.find — IDOR impossível por construção"

key-files:
  created:
    - app/controllers/api/v1/client/artes_controller.rb
    - app/controllers/api/v1/client/approval_responses_controller.rb
  modified: []

key-decisions:
  - "ArtesController#index sem includes(:approval_responses) — guard N+1 do ArteSerializer retorna [] quando associação não carregada"
  - "ApprovalResponsesController usa payload flat params.permit(:decision, :comment) sem .require(:approval_response) (D-05)"
  - "result = Arte.transaction do ... end — dados retornados do bloco para render fora da transação (Pitfall 5)"
  - "locked_arte.reload.status após save! para garantir status pós-callback sync_arte_status (D-08)"

# Metrics
duration: 10min
completed: 2026-06-12
---

# Phase 23 Plan 02: Controllers de Negócio do Cliente Summary

**Dois controllers REST completos com isolamento cross-client, row-level lock e enum guard — núcleo funcional dos endpoints do cliente (APICLI-01..03)**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-06-12
- **Completed:** 2026-06-12
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- ArtesController criado com `index` (artes pending+revised do @current_client paginadas com Pagy, serializadas via ArteSerializer sem includes — guard N+1 ativo) e `show` (com includes(:approval_responses) para eager load, serialização completa com admin_reply e histórico). Sem rescue local — RecordNotFound propaga ao BaseController → 404 automático sem enumeração (T-23-04, T-23-05, APICLI-01, APICLI-02).
- ApprovalResponsesController criado com `create` cobrindo todo o ciclo: enum guard antes da transação (ParameterMissing → 400), Arte.transaction + lock.find (row-level lock PostgreSQL — T-23-06), approval_responses.build + save! (RecordInvalid → 422 com errors array via rescue_from do BaseController — D-10), render_envelope fora do bloco com arte_status: locked_arte.reload.status + status: :created (D-08, APICLI-03). Callbacks broadcasts_to_admin e sync_arte_status permanecem ativos.

## Task Commits

1. **Task 1: ArtesController (index + show)** - `cab3fb0` (feat)
2. **Task 2: ApprovalResponsesController (create)** - `25d2203` (feat)

## Files Created/Modified

- `app/controllers/api/v1/client/artes_controller.rb` — Novo: 17 linhas; index + show escopados ao @current_client; sem rescue local; sem Arte.find global
- `app/controllers/api/v1/client/approval_responses_controller.rb` — Novo: 37 linhas; before_action :set_arte; enum guard; transaction + lock; save!; render_envelope :created com arte_status

## Decisions Made

- ArtesController#index não usa `includes(:approval_responses)` — o guard N+1 do ArteSerializer (`arte.association(:approval_responses).loaded?`) retorna `[]` no index (evita N queries na listagem), retorna dados completos no show (onde includes está presente).
- `result = Arte.transaction do ... end` — retorna `{ response:, arte: }` do bloco para render fora da transação. Evita Pitfall 5 (double render / render dentro de transaction).
- `locked_arte.reload.status` após `response.save!` — o callback `sync_arte_status` altera o status via `arte.approved!` / `arte.change_requested!` diretamente no objeto `arte` do callback, mas o `locked_arte` na transação pode estar stale. Reload garante o valor correto para o payload D-08.
- `params.permit(:decision, :comment)` sem `.require(:approval_response)` — payload flat conforme D-05; o guard já valida a presença de `:decision` antes.

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Threat Surface Scan

Nenhuma superfície nova além do plano. Controllers dentro do namespace :client protegido por `authenticate_client_jwt!` no BaseController. IDOR mitigado por construção (`@current_client.artes.find` em todos os lookups). Enum guard explícito antes do build evita ArgumentError do Rails como 500.

## Self-Check: PASSED

- `app/controllers/api/v1/client/artes_controller.rb` — FOUND
- `app/controllers/api/v1/client/approval_responses_controller.rb` — FOUND
- `cab3fb0` — FOUND em git log
- `25d2203` — FOUND em git log
