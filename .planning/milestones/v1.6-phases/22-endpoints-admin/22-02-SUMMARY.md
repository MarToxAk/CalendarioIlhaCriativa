---
phase: 22-endpoints-admin
plan: "02"
subsystem: api-admin-clients
tags: [rails, api, controller, pagy, pagination, serializer, jwt-auth, integration-test]
dependency_graph:
  requires:
    - app/controllers/api/v1/admin/base_controller.rb (Phase 22 Plan 01 — Pagy, pagination_meta, per_page_param)
    - app/serializers/api/v1/admin/client_serializer.rb (Phase 22 Plan 01 — include_credentials gate)
    - app/models/client.rb (has_secure_token, has_secure_password, password_plain column)
    - config/routes.rb (GET/POST /api/v1/admin/clients — Phase 22 Plan 01)
  provides:
    - app/controllers/api/v1/admin/clients_controller.rb
    - test/controllers/api/v1/admin/clients_controller_test.rb
  affects:
    - app/controllers/api/v1/admin/artes_controller.rb (Wave 2 — 22-03, mesmo padrão de paginação)
tech_stack:
  added: []
  patterns:
    - Controller flat JSON params sem .require(:client) (mobile envia JSON raiz)
    - password_plain setado explicitamente antes de save! (has_secure_password não popula a coluna)
    - include_credentials: true apenas no create — GET nunca expõe senha (D-04/D-05)
    - setup/teardown com ENV["JWT_SECRET"] + Api::JwtService.encode para testes de integração
key_files:
  created:
    - app/controllers/api/v1/admin/clients_controller.rb
    - test/controllers/api/v1/admin/clients_controller_test.rb
  modified: []
decisions:
  - "params.permit sem .require(:client): app mobile envia JSON flat — .require quebraria todos os requests (D-06)"
  - "password_plain setado via @client.password_plain = params[:password]: has_secure_password só popula password_digest, não a coluna password_plain; sem isso, data.password seria nil no create (D-05)"
  - "include_credentials: true somente no create: nunca no index — ClientSerializer.serialize_collection não recebe include_credentials por design (D-04)"
metrics:
  duration: "8 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  files_count: 2
---

# Phase 22 Plan 02: Clients Controller — Index Paginado e Create com Credenciais

Controller de clientes admin da API com lista paginada (D-08/D-09) e criação com retorno único de senha e portal_url (D-04/D-05/D-06), mais 6 testes de integração cobrindo segurança e paginação.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Criar Api::V1::Admin::ClientsController (index + create) | c135d71 | app/controllers/api/v1/admin/clients_controller.rb |
| 2 | Criar testes de integração para ClientsController | 337fbb3 | test/controllers/api/v1/admin/clients_controller_test.rb |

## What Was Built

### Task 1 — Api::V1::Admin::ClientsController

Criado `app/controllers/api/v1/admin/clients_controller.rb` com:

- `def index`: escopo `Client.order(created_at: :desc)`, paginação via `pagy(scope, limit: per_page_param)` (D-08), render com `serialize_collection` sem `include_credentials` (D-04), `meta: { pagination: pagination_meta(@pagy) }` (D-09)
- `def create`: `Client.new(client_params)`, `@client.password_plain = params[:password]` explicitamente antes de `save!` (D-05/D-06), resposta 201 com `ClientSerializer.serialize(..., include_credentials: true, portal_host:)` contendo password e portal_url
- `def client_params`: `params.permit(:name, :password, :active)` sem `.require(:client)` — JSON flat do app mobile (D-06)
- Herda `authenticate_admin_jwt!`, `pagination_meta`, `per_page_param`, `render_envelope`, `rescue_from RecordInvalid` do BaseController — nada redefinido

### Task 2 — Testes de Integração

Criado `test/controllers/api/v1/admin/clients_controller_test.rb` com 6 testes:

1. GET /api/v1/admin/clients retorna 200 com lista paginada e `meta.pagination.total_count` Integer
2. GET /api/v1/admin/clients sem autenticação retorna 401
3. GET /api/v1/admin/clients respeita per_page=1 na meta.pagination
4. GET /api/v1/admin/clients nunca retorna `password` nem `portal_url` em nenhum item (D-04)
5. POST /api/v1/admin/clients com dados válidos retorna 201 com `data.portal_url` e `data.password` presentes (D-05)
6. POST /api/v1/admin/clients sem nome retorna 422 com `errors` não vazio

Setup replica `sessions_controller_test.rb`: ENV["JWT_SECRET"] injetado/restaurado, User criado via `find_or_create_by!`, `@admin_jwt` gerado via `Api::JwtService.encode`, `@auth_headers` com Authorization + Content-Type.

## Deviations from Plan

None — plano executado exatamente como escrito.

## Runtime Verification

`bin/rails test` não pode ser executado neste ambiente (banco de teste pertence a outro usuário do SO). Verificação por inspeção de fonte realizada; execução de runtime marcada como diferida/manual.

**Itens verificados por inspeção:**
- `include_credentials` presente apenas no `create`, ausente do `index` — confirmado
- `password_plain` setado no `create` antes do `save!` — confirmado
- `params.permit` sem `.require(:client)` — confirmado
- 6 blocos `test "..."` presentes no arquivo de testes — confirmado via `grep -c`
- `refute c.key?("password")` e `refute c.key?("portal_url")` no teste D-04 — confirmado
- `body.dig("data", "portal_url").present?` e `body.dig("data", "password").present?` no teste D-05 — confirmado

## Known Stubs

None — todos os campos são derivados de atributos reais do model Client.

## Threat Flags

None — sem nova superfície além do previsto no `<threat_model>` do plano.

- T-22-06 (Information Disclosure GET /clients): mitigado — `serialize_collection` sem `include_credentials`; teste D-04 refuta ambos os campos
- T-22-07 (Tampering mass assignment): mitigado — `params.permit(:name, :password, :active)` exclui `access_token` (gerado por `has_secure_token`)
- T-22-08 (Spoofing POST sem auth): mitigado — `authenticate_admin_jwt!` herdado bloqueia antes do action

## Self-Check: PASSED

- app/controllers/api/v1/admin/clients_controller.rb — FOUND
- test/controllers/api/v1/admin/clients_controller_test.rb — FOUND
- Commit c135d71 — FOUND
- Commit 337fbb3 — FOUND
