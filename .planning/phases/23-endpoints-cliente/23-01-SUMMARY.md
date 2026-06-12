---
phase: 23-endpoints-cliente
plan: 01
subsystem: api
tags: [rails, pagy, active-storage, serializer, poro, routes, client-api]

# Dependency graph
requires:
  - phase: 21-fundacao-api-autenticacao
    provides: Api::V1::Client::BaseController com authenticate_client_jwt!, Api::V1::BaseController com rescue_from e render_envelope
  - phase: 22-endpoints-admin
    provides: Padrão PORO de serializers admin como analog exato para os serializers do cliente

provides:
  - Api::V1::Client::BaseController com Pagy::Backend, set_active_storage_current, pagination_meta, per_page_param, page_overflow
  - Api::V1::Client::ArteSerializer PORO com guard N+1 (association loaded?)
  - Api::V1::Client::ApprovalResponseSerializer PORO com arte_status keyword
  - Rotas GET /api/v1/client/artes, GET /api/v1/client/artes/:id, POST /api/v1/client/artes/:arte_id/approval_responses

affects:
  - 23-02 (ArtesController usará BaseController helpers e ArteSerializer)
  - 23-03 (ApprovalResponsesController usará BaseController helpers e ApprovalResponseSerializer)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Guard N+1 via association(:approval_responses).loaded? no serializer de index — retorna [] quando não carregado"
    - "private_class_method def self.helper em módulo PORO para encapsulamento de métodos auxiliares"
    - "set_active_storage_current como before_action para resolver URLs de mídia sem Missing host"

key-files:
  created:
    - app/serializers/api/v1/client/arte_serializer.rb
    - app/serializers/api/v1/client/approval_response_serializer.rb
  modified:
    - app/controllers/api/v1/client/base_controller.rb
    - config/routes.rb

key-decisions:
  - "Guard N+1 no ArteSerializer: usa association(:approval_responses).loaded? — retorna [] no index (sem includes), dados completos no show (com includes)"
  - "ApprovalResponseSerializer sem serialize_collection — usado apenas em create individual (D-08)"
  - "Campos excluídos do ArteSerializer: client_id, media_source_type, created_at, updated_at (segurança D-03)"

patterns-established:
  - "Pattern: PORO module com private_class_method para serializers do namespace client"
  - "Pattern: Guard de associação carregada antes de acessar has_many em serializers de coleção"

requirements-completed:
  - APICLI-01
  - APICLI-02
  - APICLI-03

# Metrics
duration: 3min
completed: 2026-06-12
---

# Phase 23 Plan 01: Client API Infrastructure Summary

**Pagy::Backend + ActiveStorage + dois serializers PORO com guard N+1 + rotas REST do cliente prontos para Wave 2**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-12T14:42:18Z
- **Completed:** 2026-06-12T14:45:47Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- BaseController do cliente estendido com paridade funcional ao admin: Pagy::Backend, set_active_storage_current (antes de qualquer serializer com media_url), pagination_meta, per_page_param, page_overflow (rescue_from Pagy::OverflowError)
- Dois serializers PORO criados: ArteSerializer com 11 campos (D-03+D-04) e guard N+1 obrigatório via `association(:approval_responses).loaded?`; ApprovalResponseSerializer com arte_status keyword (D-08)
- Três rotas do cliente registradas em config/routes.rb: GET /api/v1/client/artes, GET /api/v1/client/artes/:id, POST /api/v1/client/artes/:arte_id/approval_responses

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1: Estender Client::BaseController com Pagy e ActiveStorage (D-02)** - `6082913` (feat)
2. **Task 2: Criar serializers PORO do cliente (D-03, D-04, D-08)** - `0ede169` (feat)
3. **Task 3: Adicionar rotas do cliente em config/routes.rb (D-05, APICLI-01..03)** - `679672c` (feat)

## Files Created/Modified

- `app/controllers/api/v1/client/base_controller.rb` — Adicionados: include Pagy::Backend, before_action :set_active_storage_current, rescue_from Pagy::OverflowError, 4 métodos privados de paginação e ActiveStorage
- `app/serializers/api/v1/client/arte_serializer.rb` — Novo: serializer PORO com campos D-03+D-04, guard N+1, resolve_media_url e serialize_responses private
- `app/serializers/api/v1/client/approval_response_serializer.rb` — Novo: serializer PORO com serialize(approval_response, arte_status:) para D-08
- `config/routes.rb` — Adicionados resources :artes e resources :approval_responses dentro de namespace :client

## Decisions Made

- Guard N+1 implementado conforme especificação da revisão Gemini MEDIUM: `arte.association(:approval_responses).loaded?` retorna `[]` quando não carregado (index sem includes), retorna dados completos quando carregado (show com includes). Evita N queries no index sem quebrar o show.
- ApprovalResponseSerializer sem `serialize_collection` — usado apenas em create individual (D-08); consistente com o padrão estabelecido na Phase 22.
- Campos excluídos do ArteSerializer: `client_id`, `media_source_type`, `created_at`, `updated_at` — evita Information Disclosure (T-23-02).

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Issues Encountered

- `bin/rails routes` não pode ser executado a partir do diretório do worktree (vendor/bundle não disponível no worktree); verificação alternativa via `grep` direto no `config/routes.rb` confirmou as rotas corretas. As rotas serão verificáveis no repositório principal após merge.

## Threat Surface Scan

Nenhuma superfície nova além do plano. As rotas adicionadas estão dentro do namespace :client já protegido por `authenticate_client_jwt!` no BaseController. Campos sensíveis excluídos do ArteSerializer conforme T-23-02.

## Next Phase Readiness

- Wave 2 pode iniciar: BaseController tem todos os helpers necessários (Pagy, ActiveStorage, pagination_meta, per_page_param, page_overflow)
- ArteSerializer pronto para uso em ArtesController#index (guard N+1) e ArtesController#show (includes)
- ApprovalResponseSerializer pronto para uso em ApprovalResponsesController#create
- Rotas registradas para os 3 endpoints do cliente

---
*Phase: 23-endpoints-cliente*
*Completed: 2026-06-12*
