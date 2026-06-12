---
phase: 24-endpoints-ia-rate-limiting
plan: "01"
subsystem: api-ai-infrastructure
tags:
  - api
  - ai
  - rack-attack
  - rate-limiting
  - pagy
  - serializer
dependency_graph:
  requires:
    - "Phase 21: Api::V1::BaseController e render_error helper"
    - "Phase 22: Admin::BaseController como analog de Pagy/helpers"
    - "Phase 22: Admin::ArteSerializer como template para AI serializer"
  provides:
    - "Api::V1::Ai::BaseController expandido com Pagy::Backend e helpers de paginação"
    - "Api::V1::Ai::ArteSerializer PORO com serialize e serialize_collection"
    - "Throttle api/ai_by_key (60 req/min) no Rack::Attack"
    - "Rotas GET/POST /api/v1/ai/artes e GET /api/v1/ai/clients/:id/summary"
  affects:
    - "Plan 24-02: controllers AI dependem do BaseController e ArteSerializer criados aqui"
tech_stack:
  added: []
  patterns:
    - "PORO serializer copiado do namespace admin com módulo alterado"
    - "Rack::Attack throttle por API key via header Authorization Bearer"
    - "Pagy::Backend incluído no BaseController para paginação consistente com namespaces admin/client"
key_files:
  created:
    - app/serializers/api/v1/ai/arte_serializer.rb
  modified:
    - app/controllers/api/v1/ai/base_controller.rb
    - config/routes.rb
    - config/initializers/rack_attack.rb
decisions:
  - "Arte_serializer AI é cópia idêntica do admin com módulo alterado — sem divergência de campos"
  - "Throttle por API key (não por IP) — adequado para agente de IA com token fixo"
  - ".presence garante nil para string vazia no bloco do throttle"
  - "Guard de path start_with?('/api/v1/ai/') isola throttle somente ao namespace AI"
metrics:
  duration: "3 minutes"
  completed: "2026-06-12T20:47:53Z"
  tasks_completed: 2
  files_modified: 4
---

# Phase 24 Plan 01: Infraestrutura AI — BaseController, Serializer, Rotas e Rate Limiting

Infraestrutura completa para o namespace AI: BaseController expandido com Pagy e helpers, ArteSerializer PORO, 3 rotas REST e throttle de 60 req/min por API key no Rack::Attack.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Expandir Ai::BaseController + criar ArteSerializer + preencher rotas | b5fac84 | base_controller.rb, arte_serializer.rb, routes.rb |
| 2 | Adicionar throttle api/ai_by_key ao Rack::Attack | 42d8958 | rack_attack.rb |

## What Was Built

**Task 1 — BaseController + Serializer + Rotas:**

`app/controllers/api/v1/ai/base_controller.rb` expandido com:
- `include Pagy::Backend` (paginação consistente com namespaces admin/client)
- `before_action :set_active_storage_current` (URLs de ActiveStorage resolvidas corretamente)
- `rescue_from Pagy::OverflowError, with: :page_overflow`
- Métodos privados: `set_active_storage_current`, `pagination_meta`, `per_page_param`, `page_overflow`
- `authenticate_ai_key!` e `render_unauthorized` preservados sem alteração

`app/serializers/api/v1/ai/arte_serializer.rb` criado como PORO `Api::V1::Ai::ArteSerializer` com:
- `self.serialize(arte)` retorna hash com 14 campos incluindo `media_url` e `media_source_type`
- `self.serialize_collection(artes)` mapeia a coleção
- `resolve_media_url` private_class_method: media_file.url se attached, external_url caso contrário

`config/routes.rb` — namespace `:ai` preenchido:
- `GET /api/v1/ai/artes` → `api/v1/ai/artes#index`
- `POST /api/v1/ai/artes` → `api/v1/ai/artes#create`
- `GET /api/v1/ai/clients/:id/summary` → `api/v1/ai/clients#summary`

**Task 2 — Rate Limiting:**

`config/initializers/rack_attack.rb` — novo throttle inserido antes do `throttled_responder`:
- `throttle("api/ai_by_key", limit: 60, period: 60)` identifica por token Bearer no header Authorization
- Guard `req.path.start_with?("/api/v1/ai/")` limita escopo somente ao namespace AI
- `.presence` garante nil para token vazio (requests sem auth → nil → sem throttle, mas `authenticate_ai_key!` rejeita com 401)

## Acceptance Criteria Verification

- `bin/rails routes` (via worktree routes.rb): 3 rotas AI confirmadas — GET artes, POST artes, GET clients/:id/summary
- `include Pagy::Backend` na linha 4 do base_controller.rb
- `set_active_storage_current` em 2 linhas (before_action + definição)
- `pagination_meta` definido como método privado
- `app/serializers/api/v1/ai/arte_serializer.rb` contém `module Api::V1::Ai::ArteSerializer`
- `media_url` com `resolve_media_url` no serializer
- `authenticate_ai_key!` preservado (linhas 5 e 12)
- `throttle("api/ai_by_key", limit: 60, period: 60)` na linha 30
- `throttled_responder` preservado na linha 36 (após o novo throttle)
- `.presence` presente para nil-safety

## Deviations from Plan

None — plano executado exatamente como escrito.

## Threat Surface Scan

Nenhuma nova superfície de segurança além das previstas no threat model do plano:
- T-24-01 (DoS): Throttle api/ai_by_key implementado (mitigado)
- T-24-02 (Timing): secure_compare preservado sem alteração (já mitigado)
- T-24-04 (Spoofing): Requests sem token retornam nil no throttle; authenticate_ai_key! rejeita com 401 (aceito)

## Known Stubs

None — este plano cria apenas infraestrutura (base controller, serializer, rotas, throttle). Nenhum dado hardcoded ou placeholder.

## Self-Check: PASSED

All files confirmed on disk. Both task commits verified in git history.
