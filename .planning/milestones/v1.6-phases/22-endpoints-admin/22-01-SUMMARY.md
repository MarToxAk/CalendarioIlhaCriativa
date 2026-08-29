---
phase: 22-endpoints-admin
plan: "01"
subsystem: api-admin-foundation
tags: [rails, api, poro-serializer, pagy, active-storage, routing]
dependency_graph:
  requires:
    - app/controllers/api/v1/base_controller.rb
    - app/controllers/api/v1/admin/base_controller.rb (Phase 21)
  provides:
    - app/controllers/api/v1/admin/base_controller.rb (enhanced)
    - app/serializers/api/v1/admin/client_serializer.rb
    - app/serializers/api/v1/admin/arte_serializer.rb
    - app/serializers/api/v1/admin/approval_response_serializer.rb
    - config/routes.rb (Phase 22 routes)
  affects:
    - app/controllers/api/v1/admin/clients_controller.rb (Wave 2 — 22-02)
    - app/controllers/api/v1/admin/artes_controller.rb (Wave 2 — 22-03)
    - app/controllers/api/v1/admin/approval_responses_controller.rb (Wave 2 — 22-04)
tech_stack:
  added: []
  patterns:
    - PORO serializer modules em app/serializers/api/v1/admin/
    - Pagy::Backend no base controller admin da API
    - ActiveStorage::Current.url_options via before_action (sem url_helpers no serializer)
    - arte_status como kwarg obrigatório em ApprovalResponseSerializer (evita N+1)
key_files:
  created:
    - app/serializers/api/v1/admin/client_serializer.rb
    - app/serializers/api/v1/admin/arte_serializer.rb
    - app/serializers/api/v1/admin/approval_response_serializer.rb
  modified:
    - app/controllers/api/v1/admin/base_controller.rb
    - config/routes.rb
decisions:
  - "PORO serializers sem gem externa: sem jbuilder (incompatível com ActionController::API por padrão), sem Alba/Blueprinter (desnecessário para 3 recursos)"
  - "arte.media_file.url em vez de rails_blob_url: não requer url_helpers; depende de ActiveStorage::Current.url_options setado pelo before_action"
  - "arte_status como kwarg obrigatório em ApprovalResponseSerializer: evita N+1 — controller passa @arte.status já carregado em memória"
  - "per_page_param com clamp(1,100): cap de 100 registros por página (T-22-04 — previne queries unbounded)"
  - "rescue_from Pagy::OverflowError retorna 404 com code page_out_of_range (não 400 — idiomático: a página N não existe)"
metrics:
  duration: "10 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  files_count: 5
---

# Phase 22 Plan 01: Shared Infrastructure — Base Controller, Serializers, Routes Summary

Infraestrutura compartilhada da Phase 22: base controller admin da API estendido com Pagy e ActiveStorage host, três módulos PORO serializer criados, e 5 rotas novas adicionadas ao namespace admin.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Estender Api::V1::Admin::BaseController com Pagy, ActiveStorage host e helpers | 49b12ab | app/controllers/api/v1/admin/base_controller.rb |
| 2 | Criar módulos PORO serializer e adicionar rotas da Phase 22 | 0d6557a | 3 serializers + config/routes.rb |

## What Was Built

### Task 1 — Api::V1::Admin::BaseController

Modificado `app/controllers/api/v1/admin/base_controller.rb` adicionando:

- `include Pagy::Backend` — habilita o método `pagy()` nos controllers filhos
- `before_action :set_active_storage_current` — popula `ActiveStorage::Current.url_options` com `protocol/host/port` do request real; necessário para que `arte.media_file.url` gere URLs absolutas corretas
- `rescue_from Pagy::OverflowError, with: :page_overflow` — retorna 404 com `code: "page_out_of_range"` quando `page > total_pages`
- `def set_active_storage_current` — implementação inline (sem concern separado)
- `def pagination_meta(pagy)` — helper compartilhado devolvendo `{ page, per_page, total_count, total_pages }`
- `def per_page_param` — helper com `clamp(1,100)` e default 25 (D-08, T-22-04)
- `def page_overflow` — handler do rescue_from

Todo código existente (`authenticate_admin_jwt!`, `bearer_token`, `render_unauthorized`) preservado sem alteração.

### Task 2 — Serializers PORO e Rotas

**ClientSerializer** (`app/serializers/api/v1/admin/client_serializer.rb`):
- `serialize(client, include_credentials: false, portal_host: nil)` — retorna `{ id, name, active, created_at }`; com `include_credentials: true` adiciona `password` e `portal_url` (D-04/D-05, T-22-01)
- `serialize_collection(clients)` — mapeia sem credentials (GET list nunca expõe senha)

**ArteSerializer** (`app/serializers/api/v1/admin/arte_serializer.rb`):
- `serialize(arte)` — retorna todos os campos + `media_url` (via `arte.media_file.url` ou `external_url`) + `media_source_type` ("upload"/"link"/nil)
- `resolve_media_url` marcado como `private_class_method` — delega ao disk service usando `ActiveStorage::Current.url_options`

**ApprovalResponseSerializer** (`app/serializers/api/v1/admin/approval_response_serializer.rb`):
- `serialize(approval_response, arte_status:)` — `arte_status` como kwarg obrigatório (evita N+1)
- `serialize_collection(responses, arte_status:)` — passa `arte_status` para cada item

**Routes** (`config/routes.rb`):
```
GET  /api/v1/admin/clients                          → api/v1/admin/clients#index
POST /api/v1/admin/clients                          → api/v1/admin/clients#create
GET  /api/v1/admin/artes                            → api/v1/admin/artes#index
POST /api/v1/admin/artes                            → api/v1/admin/artes#create
GET  /api/v1/admin/artes/:arte_id/approval_responses → api/v1/admin/approval_responses#index
```
Namespaces `:client` e `:ai` preservados intactos.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — todos os campos dos serializers são derivados de atributos reais dos modelos.

## Threat Flags

None — sem nova superfície além do previsto no `<threat_model>` do plano. As mitigações T-22-01 (include_credentials gate) e T-22-04 (per_page_param clamp) foram implementadas conforme especificado.

## Self-Check: PASSED

- app/controllers/api/v1/admin/base_controller.rb — FOUND
- app/serializers/api/v1/admin/client_serializer.rb — FOUND
- app/serializers/api/v1/admin/arte_serializer.rb — FOUND
- app/serializers/api/v1/admin/approval_response_serializer.rb — FOUND
- config/routes.rb (rotas Phase 22) — FOUND
- Commit 49b12ab — FOUND
- Commit 0d6557a — FOUND
