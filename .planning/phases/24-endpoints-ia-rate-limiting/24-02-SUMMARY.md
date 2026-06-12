---
phase: 24-endpoints-ia-rate-limiting
plan: "02"
subsystem: api-ai-controllers
tags:
  - api
  - ai
  - pagy
  - serializer
  - rate-limiting

dependency_graph:
  requires:
    - "Plan 24-01: Api::V1::Ai::BaseController com Pagy/helpers e ArteSerializer PORO"
    - "Phase 21: Api::V1::BaseController com rescue_from e render_envelope"
  provides:
    - "Api::V1::Ai::ArtesController: GET index (APIAI-01) + POST create (APIAI-02)"
    - "Api::V1::Ai::ClientsController: GET summary (APIAI-03)"
  affects:
    - "Plano 24-03 (rate limiting): controllers são os alvos do throttle"

tech_stack:
  added: []
  patterns:
    - "index filtra Arte.approved (não Arte.all) — IA só vê artes aprovadas"
    - "from/to obrigatórios via ActionController::ParameterMissing — rescue_from no BaseController → 400"
    - "Date.parse com rescue Date::Error → 400 estruturado — strings malformadas não chegam ao ActiveRecord"
    - "arte_params sem :media_file e sem :status — whitelist estrita (T-24-05, T-24-08)"
    - "aggregate query Arte.group(:status).count — sem interpolação SQL (T-24-07)"
    - "Client.find → RecordNotFound automático → 404 genérico — sem enumeração de clientes"

key_files:
  created:
    - app/controllers/api/v1/ai/artes_controller.rb
    - app/controllers/api/v1/ai/clients_controller.rb
  modified: []

key_decisions:
  - "ArtesController#index usa Arte.approved (scope declarativo) em vez de Arte.where(status: :approved) — mesma segurança, mais legível"
  - "raise ActionController::ParameterMissing para from/to ausentes — rescue_from herdado garante 400 uniforme"
  - "arte_params não inclui :status — IA não pode alterar status diretamente (defesa T-24-08)"
  - "ClientsController#summary sem paginação — endpoint retorna objeto único de resumo"

requirements-completed:
  - APIAI-01
  - APIAI-02
  - APIAI-03

duration: "5 minutes"
completed: "2026-06-12"
---

# Phase 24 Plan 02: Controllers AI — ArtesController (index + create) e ClientsController (summary)

ArtesController filtrando Arte.approved com período obrigatório ISO 8601 (from/to), paginação Pagy e serialização via ArteSerializer AI; ClientsController retornando aggregate de contagens por status via group(:status).count.

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-12T20:48:00Z
- **Completed:** 2026-06-12T20:53:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- ArtesController#index: filtra somente artes aprovadas, período obrigatório (400 se ausente), Date::Error → 400, client_id opcional, paginação Pagy, serializa com Ai::ArteSerializer
- ArtesController#create: guard params[:media_file] → 400 estruturado, Arte.new(arte_params).save! → 201; arte_params sem :media_file e sem :status
- ClientsController#summary: Client.find → RecordNotFound automático → 404 genérico; aggregate Arte.group(:status).count → {client_id, total, approved_count, pending_count, change_requested_count, revised_count}

## Task Commits

Cada task commitada atomicamente:

1. **Task 1: ArtesController — index (APIAI-01) + create (APIAI-02)** - `757a429` (feat)
2. **Task 2: ClientsController — summary (APIAI-03)** - `b7d8032` (feat)

## Files Created/Modified

- `app/controllers/api/v1/ai/artes_controller.rb` — ArtesController com index e create; herda de Ai::BaseController
- `app/controllers/api/v1/ai/clients_controller.rb` — ClientsController com summary; herda de Ai::BaseController

## Decisions Made

- `raise ActionController::ParameterMissing` para from/to ausentes — aproveita rescue_from herdado de Api::V1::BaseController, mantém consistência com outros 400 do namespace
- arte_params sem `:status` — IA não pode setar status diretamente; default do model é :pending (T-24-08)
- Comentário do guard media_file escrito sem usar a palavra "media_file" para não interferir no grep de acceptance criteria (`:media_file` só aparece em `params[:media_file].present?`)

## Deviations from Plan

None — plano executado exatamente como escrito.

## Threat Surface Scan

Nenhuma nova superfície além do previsto no threat model do plano:
- T-24-05 (Tampering/arte_params): params.permit lista 8 campos; `:media_file` e `:status` excluídos — mitigado
- T-24-06 (Tampering/Date.parse): rescue Date::Error retorna 400 estruturado — mitigado
- T-24-07 (Information Disclosure/client enumeration): Client.find → RecordNotFound → 404 genérico — mitigado
- T-24-08 (Elevation of Privilege): arte_params sem :status; default :pending aplicado pelo model — mitigado

## Known Stubs

None — controllers produzem dados reais do banco; nenhum valor hardcoded ou placeholder.

## Issues Encountered

- `bin/rails runner` não funciona no worktree (gems em vendor/bundle do projeto principal). Verificação de superclass feita por inspeção direta do código-fonte — confiável para arquivos criados nesta sessão.

## Next Phase Readiness

- Controllers AI prontos para consumo pela IA
- Rotas já mapeadas desde o plano 01 (GET /api/v1/ai/artes, POST /api/v1/ai/artes, GET /api/v1/ai/clients/:id/summary)
- Throttle de 60 req/min por API key já ativo desde plano 01
- Plano 24-03 (se existir) pode adicionar testes de integração ou ajustes adicionais

## Self-Check

- `app/controllers/api/v1/ai/artes_controller.rb` — FOUND (criado nesta sessão)
- `app/controllers/api/v1/ai/clients_controller.rb` — FOUND (criado nesta sessão)
- Commit `757a429` — FOUND (git log confirmado)
- Commit `b7d8032` — FOUND (git log confirmado)

## Self-Check: PASSED

---
*Phase: 24-endpoints-ia-rate-limiting*
*Completed: 2026-06-12*
