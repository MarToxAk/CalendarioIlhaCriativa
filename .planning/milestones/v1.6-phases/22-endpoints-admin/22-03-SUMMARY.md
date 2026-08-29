---
phase: 22-endpoints-admin
plan: "03"
subsystem: api-admin-artes
tags: [rails, api, artes, active-storage, multipart, pagy, active_storage_validations]
dependency_graph:
  requires:
    - app/controllers/api/v1/admin/base_controller.rb (Pagy, set_active_storage_current — Wave 1)
    - app/serializers/api/v1/admin/arte_serializer.rb (serialize/serialize_collection — Wave 1)
    - app/models/arte.rb (enums, validações, callbacks ActionCable)
  provides:
    - app/controllers/api/v1/admin/artes_controller.rb (index com filtros + create com upload)
    - app/models/arte.rb (validates :media_file content_type + size — ASVS L1 V5)
    - test/controllers/api/v1/admin/artes_controller_test.rb (10 testes de integração)
    - test/fixtures/files/sample.jpg (fixture JPEG mínimo para upload multipart)
  affects:
    - Clientes mobile que criam/consultam artes via API admin
    - Pipeline de aprovação (artes criadas via API disparam callbacks ActionCable inalterados)
tech_stack:
  added: []
  patterns:
    - ArtesController herda de Api::V1::Admin::BaseController (Pagy + ActiveStorage host + JWT auth)
    - apply_filters com guard Arte.statuses.key? (T-22-11) e Date.strptime rescue (T-22-12)
    - params.permit flat sem .require(:arte) — JSON plano do app mobile (paridade com Wave 2 clients)
    - external_url = nil inferido da presença de media_file (sem media_source param)
    - active_storage_validations content_type whitelist + size cap (T-22-10)
key_files:
  created:
    - app/controllers/api/v1/admin/artes_controller.rb
    - test/controllers/api/v1/admin/artes_controller_test.rb
    - test/fixtures/files/sample.jpg
  modified:
    - app/models/arte.rb (validates :media_file adicionado após validate :only_one_media_source)
decisions:
  - "params.permit flat (sem .require(:arte)): app mobile envia JSON plano — paridade com clients_controller e sessions_controller"
  - "apply_filters levanta ActionController::ParameterMissing (não BadRequest): reusa o rescue_from existente em Api::V1::BaseController — retorna 400 sem handler extra"
  - "external_url = nil quando media_file.present?: inferência por presença do arquivo, sem param :media_source — paridade com web controller"
  - "ActionCable callbacks intactos: after_update_commit :broadcasts_revised_to_all permanece no modelo Arte sem skip_callback no controller"
  - "active_storage_validations já no Gemfile: validação de content_type e size adicionada diretamente (T-22-10); sem nova gem"
  - "Fixture JPEG de 22 bytes com cabeçalho JFIF válido: `file` command confirma JPEG image data"
metrics:
  duration: "2 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  files_count: 4
---

# Phase 22 Plan 03: ArtesController + Media Validations Summary

Endpoints de artes admin implementados: `GET /api/v1/admin/artes` com três filtros combináveis (client_id, status, month) e paginação Pagy, e `POST /api/v1/admin/artes` com suporte a upload multipart ou link externo. Validação de content_type e tamanho do arquivo adicionada ao modelo Arte via `active_storage_validations`. Callbacks ActionCable preservados sem `skip_callback`.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Criar ArtesController e adicionar validates :media_file ao modelo Arte | fa9ad45 | app/controllers/api/v1/admin/artes_controller.rb, app/models/arte.rb |
| 2 | Criar fixture JPEG e testes de integração para ArtesController | 783bc2f | test/controllers/api/v1/admin/artes_controller_test.rb, test/fixtures/files/sample.jpg |

## What Was Built

### Task 1 — Api::V1::Admin::ArtesController

Criado `app/controllers/api/v1/admin/artes_controller.rb` com:

**index:**
- `scope = Arte.includes(:client).order(scheduled_on: :desc)` — visão global (sem escopo por cliente)
- `apply_filters(scope)` — aplica filtros opcionais e combináveis
- `pagy(scope, limit: per_page_param)` — paginação via Pagy herdado do BaseController
- `render_envelope(data: ArteSerializer.serialize_collection, meta: { pagination: pagination_meta })`

**apply_filters:**
- `client_id`: `.where(client_id: params[:client_id])` se presente
- `status`: `Arte.statuses.key?(params[:status])` → `ActionController::ParameterMissing.new(:status)` se inválido (capturado pelo rescue_from existente → 400)
- `month`: `Date.strptime(params[:month], "%Y-%m")` → `ParameterMissing.new(:month)` em `Date::Error` (400)

**create:**
- `Arte.new(arte_params)` + `@arte.external_url = nil if params[:media_file].present?`
- `save!` → `rescue_from RecordInvalid → 422` automático via herança
- `render_envelope(data: ArteSerializer.serialize(@arte), status: :created)`
- Sem `skip_callback` — `after_update_commit :broadcasts_revised_to_all` permanece ativo

**arte_params:** `params.permit(:title, :caption, :scheduled_on, :approval_deadline, :external_url, :platform, :media_type, :client_id, :media_file)` — flat, sem `.require(:arte)`

Modificado `app/models/arte.rb`:
```ruby
validates :media_file,
  content_type: {
    in: %w[image/jpeg image/png image/gif video/mp4 video/quicktime],
    message: "deve ser imagem ou vídeo"
  },
  size: { less_than: 50.megabytes, message: "deve ter menos de 50MB" },
  if: -> { media_file.attached? }
```
Inserido após `validate :only_one_media_source`. Nenhuma outra linha alterada. `after_update_commit` callback preservado na linha 25.

### Task 2 — Fixture JPEG e Testes de Integração

**test/fixtures/files/sample.jpg:** 22 bytes, cabeçalho JFIF válido (FF D8 FF E0 + JFIF marker). Confirmado pelo comando `file` como "JPEG image data, JFIF standard 1.01".

**test/controllers/api/v1/admin/artes_controller_test.rb** — 10 testes:

| # | Cenário | Assertion |
|---|---------|-----------|
| 1 | GET index autenticado | 200 + meta.pagination.total_count is Integer |
| 2 | GET index sem auth | 401 |
| 3 | GET ?client_id=X | Arte de outro cliente não aparece |
| 4 | GET ?status=approved | Todos os items têm status "approved" |
| 5 | GET ?status=invalido | 400 |
| 6 | GET ?month=2025-12 | Arte do mês aparece; arte de outro mês não aparece |
| 7 | GET ?month=nao-data | 400 |
| 8 | POST com external_url | 201 + media_source_type == "link" |
| 9 | POST com media_file (multipart) | 201 + media_url presente + media_source_type == "upload" |
| 10 | POST sem mídia | 422 + errors.any? |

Setup replica padrão de sessions_controller_test.rb: `@user = User.find_or_create_by!` (guard callback ActionCable), `@admin_jwt`, `@auth_headers`. Teste de upload não passa `Content-Type: application/json`.

## Deviations from Plan

None — plano executado exatamente conforme especificado.

## Known Stubs

None — todos os campos são derivados de atributos reais dos modelos.

## Runtime Verification (Deferred)

`bin/rails test` não pode ser executado neste ambiente (banco de teste pertence a outro usuário do SO). Os 10 testes foram verificados por inspeção de código:
- Herança e métodos do BaseController (Pagy, set_active_storage_current, rescue_from) confirmados em app/controllers/api/v1/admin/base_controller.rb
- ArteSerializer.serialize/serialize_collection confirmados em app/serializers/api/v1/admin/arte_serializer.rb
- Arte.statuses enum confirmado em app/models/arte.rb (linha 23)
- rescue_from ActionController::ParameterMissing confirmado em app/controllers/api/v1/base_controller.rb (linha 6)
- active_storage_validations gem confirmada no Gemfile (linha 36)

## Threat Flags

None — toda a superfície de ataque desta fase já estava no `<threat_model>` do plano:
- T-22-10 (media_file content_type + size): mitigado via validates :media_file
- T-22-11 (status enum injection): mitigado via Arte.statuses.key? guard
- T-22-12 (month SQL injection): mitigado via Date.strptime com rescue
- T-22-13 (mass assignment): mitigado via params.permit lista explícita
- T-22-14 (DoS sem filtros): mitigado via per_page_param cap 100 + Pagy (herdado do BaseController)
- T-22-15 (ActionCable callbacks): aceito por design — callbacks intactos

## Self-Check: PASSED

- app/controllers/api/v1/admin/artes_controller.rb — FOUND
- app/models/arte.rb (validates :media_file) — FOUND
- test/controllers/api/v1/admin/artes_controller_test.rb — FOUND
- test/fixtures/files/sample.jpg — FOUND
- Commit fa9ad45 — FOUND
- Commit 783bc2f — FOUND
