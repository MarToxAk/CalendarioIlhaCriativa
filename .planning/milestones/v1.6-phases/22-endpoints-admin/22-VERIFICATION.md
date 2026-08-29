---
phase: 22-endpoints-admin
verified: 2026-06-11T00:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification_result: "passed — 3/3 validados em runtime contra o servidor de dev em 2026-06-11 (ver 22-HUMAN-UAT.md)"
human_verification:
  - test: "POST /api/v1/admin/clients — confirmar que password_plain é devolvido na resposta (D-05) e que o valor bate com a senha enviada"
    expected: "Campo 'password' em data contém a senha em texto plano exatamente como enviada pelo app"
    why_human: "Requer requisição HTTP real ao servidor; comportamento depende de password_plain ser persistido na coluna e lido de volta corretamente pelo serializer"
  - test: "POST /api/v1/admin/artes com multipart/form-data — confirmar que media_url retorna URL absoluta válida de blob Active Storage"
    expected: "data.media_url contém URL com host correto do servidor (não ArgumentError nem URL parcial)"
    why_human: "Requer servidor rodando para gerar URL de blob signed; set_active_storage_current está presente mas o efeito no url_for só é verificável em runtime"
  - test: "GET /api/v1/admin/artes?status=invalido — confirmar que retorna 400 (não 500) dado que ActionController::ParameterMissing é usada como substituto semântico para valor inválido"
    expected: "HTTP 400 com body JSON { data: null, meta: {}, errors: [...] }"
    why_human: "Conforme WR-01 do 22-REVIEW.md, o uso de ParameterMissing para valor inválido é semanticamente incorreto mas funcionalmente depende do rescue_from existente em base_controller; confirmar que a cadeia de rescue_from cobre o caso"
---

# Phase 22: Endpoints Admin — Relatório de Verificação

**Objetivo da fase:** Admin mobile consegue listar clientes, criar artes e consultar histórico de aprovações via API.
**Verificado em:** 2026-06-11
**Status:** human_needed
**Re-verificação:** Não — verificação inicial

---

## Resumo da verificação

Todos os cinco critérios de sucesso do ROADMAP.md foram verificados contra o código-fonte real. Os quatro controllers, três serializers PORO, as rotas e o modelo `Arte` estão presentes, substanciais e corretamente conectados. O CR-01 identificado no 22-REVIEW.md (missing `return` em `authenticate_admin_jwt!`) foi corrigido antes desta verificação. Três itens requerem execução do servidor para confirmação humana e estão documentados abaixo.

---

## Critérios de sucesso do ROADMAP

| # | Critério | Status | Evidência |
|---|----------|--------|-----------|
| 1 | `GET` de clientes retorna lista paginada com metadados de paginação | VERIFIED | `clients_controller.rb:6-10` — `pagy(scope, limit: per_page_param)` + `meta: { pagination: pagination_meta(@pagy) }` |
| 2 | `POST` de cliente cria novo cliente e retorna o recurso criado | VERIFIED | `clients_controller.rb:13-26` — `Client.new`, `save!`, `ClientSerializer.serialize(include_credentials: true)` com `status: :created` |
| 3 | `GET` de artes aceita filtros por cliente, status e mês | VERIFIED | `artes_controller.rb:26-41` — `apply_filters` com `client_id`, `Arte.statuses.key?` para status, `Date.strptime` para month |
| 4 | `POST` de arte cria arte com upload de imagem (Active Storage) autenticado como admin | VERIFIED | `artes_controller.rb:14-21` — `Arte.new(arte_params)` + `@arte.external_url = nil if params[:media_file].present?` + `save!`; validação de content_type/size em `arte.rb:35-41` |
| 5 | Histórico de aprovações de uma arte é retornado com as respostas registradas | VERIFIED | `approval_responses_controller.rb:6-13` — `@arte.approval_responses` + `ApprovalResponseSerializer.serialize_collection(responses, arte_status: @arte.status)` |

**Pontuação:** 5/5 critérios de sucesso verificados

---

## Verdades observáveis (must-haves dos PLANs)

### 22-01-PLAN.md — Infraestrutura base

| # | Verdade | Status | Evidência |
|---|---------|--------|-----------|
| 1 | `BaseController` inclui `Pagy::Backend` e expõe `pagination_meta`/`per_page_param` | VERIFIED | `base_controller.rb:4` — `include Pagy::Backend`; métodos definidos em `:42-53` |
| 2 | `BaseController` tem `before_action :set_active_storage_current` | VERIFIED | `base_controller.rb:6`; definição em `:34-40` com atribuição de `{ protocol:, host:, port: }` |
| 3 | `BaseController` tem `rescue_from Pagy::OverflowError` | VERIFIED | `base_controller.rb:8` — `rescue_from Pagy::OverflowError, with: :page_overflow`; handler em `:55-57` retorna 404 |
| 4 | Módulos serializer PORO existem para Client, Arte e ApprovalResponse | VERIFIED | Três arquivos presentes em `app/serializers/api/v1/admin/` com conteúdo substancial |
| 5 | Rotas GET/POST `/api/v1/admin/clients`, `/api/v1/admin/artes` e GET nested `approval_responses` definidas | VERIFIED | `routes.rb:41-44`; confirmado via `bin/rails routes` — 6 rotas mapeadas corretamente com `arte_id` como param aninhado |

### 22-02-PLAN.md — ClientsController

| # | Verdade | Status | Evidência |
|---|---------|--------|-----------|
| 1 | `GET /api/v1/admin/clients` retorna 200 com lista paginada e `meta.pagination` | VERIFIED | Controller + teste `clients_controller_test.rb:32-41` |
| 2 | `POST /api/v1/admin/clients` cria cliente e retorna 201 com `portal_url` e `password` (D-05) | VERIFIED | `clients_controller.rb:13-26`; `include_credentials: true` apenas no `create`; teste `:74-85` |
| 3 | `GET` nunca inclui `password` nem `portal_url` (D-04) | VERIFIED | `ClientSerializer.serialize` sem `include_credentials` omite ambos; teste `:61-72` com `refute c.key?("password")` |
| 4 | `POST` sem nome retorna 422 com `errors` não vazio | VERIFIED | `rescue_from RecordInvalid` em `Api::V1::BaseController:5`; teste `:87-96` |
| 5 | Requisições sem token JWT retornam 401 | VERIFIED | `authenticate_admin_jwt!` retorna `render_unauthorized` para token ausente; teste `:43-46` |

### 22-03-PLAN.md — ArtesController + Arte model

| # | Verdade | Status | Evidência |
|---|---------|--------|-----------|
| 1 | `GET /api/v1/admin/artes` retorna 200 com lista paginada | VERIFIED | `artes_controller.rb:4-11`; teste `:39-48` |
| 2 | `?client_id=X` filtra por cliente | VERIFIED | `apply_filters:27` — `scope.where(client_id: params[:client_id])`; teste `:56-83` |
| 3 | `?status=approved` retorna apenas artes aprovadas | VERIFIED | `apply_filters:29-31`; teste `:85-114` |
| 4 | `?status=invalido` retorna 400 | VERIFIED (runtime check pending) | `apply_filters:29` — `raise ActionController::ParameterMissing.new(:status)`; `rescue_from ParameterMissing → bad_request` em `base_controller.rb:6`; teste `:116-120` — ver human_verification #3 |
| 5 | `?month=2025-12` filtra por mês de `scheduled_on` | VERIFIED | `apply_filters:33-39`; teste `:122-152` |
| 6 | `?month=nao-data` retorna 400 | VERIFIED | `Date::Error → ParameterMissing`; teste `:154-158` |
| 7 | `POST` com `external_url` retorna 201 com `media_source_type='link'` | VERIFIED | `ArteSerializer:16` — ternário de `media_source_type`; teste `:164-182` |
| 8 | `POST` com `media_file` retorna 201 com `media_url` e `media_source_type='upload'` | VERIFIED (runtime check pending) | `ArteSerializer:26-32` — `resolve_media_url`; `set_active_storage_current` em base; teste `:184-208` — ver human_verification #2 |
| 9 | `POST` sem mídia retorna 422 | VERIFIED | `Arte#media_source_present` em `arte.rb:94-97`; `rescue_from RecordInvalid → 422`; teste `:210-227` |
| 10 | Callbacks ActionCable não desabilitados | VERIFIED | Nenhuma linha de `skip_callback` em `artes_controller.rb`; `after_update_commit :broadcasts_revised_to_all` preservado em `arte.rb:25` |
| 11 | `validates :media_file` com content_type e size no modelo Arte | VERIFIED | `arte.rb:35-41` — whitelist `image/jpeg image/png image/gif video/mp4 video/quicktime` + `50.megabytes` + guard `if: -> { media_file.attached? }` |

### 22-04-PLAN.md — ApprovalResponsesController

| # | Verdade | Status | Evidência |
|---|---------|--------|-----------|
| 1 | `GET /api/v1/admin/artes/:id/approval_responses` retorna 200 com lista e `meta.arte_status` | VERIFIED | `approval_responses_controller.rb:6-13`; teste `:50-61` |
| 2 | Cada item contém `id, decision, comment, responded_at, created_at, arte_status` (D-11) | VERIFIED | `ApprovalResponseSerializer:4-13`; teste `:63-75` itera sobre esses campos |
| 3 | Arte inexistente retorna 404 | VERIFIED | `Arte.find(params[:arte_id])` lança `RecordNotFound`; `rescue_from RecordNotFound → not_found → 404` em `base_controller.rb:4`; teste `:77-81` |
| 4 | Sem JWT retorna 401 | VERIFIED | Herdado de `authenticate_admin_jwt!`; teste `:83-88` |
| 5 | Sem N+1 ao resolver `arte_status` | VERIFIED | `@arte` já carregado por `before_action :set_arte`; `arte_status: @arte.status` passado diretamente ao serializer sem novo query |

---

## Artefatos verificados

| Artefato | Nível 1 (existe) | Nível 2 (substancial) | Nível 3 (conectado) | Status |
|----------|------------------|-----------------------|---------------------|--------|
| `app/controllers/api/v1/admin/base_controller.rb` | Sim | Sim — 58 linhas com Pagy, ActiveStorage, helpers | Herdado por todos os 3 controllers | VERIFIED |
| `app/serializers/api/v1/admin/client_serializer.rb` | Sim | Sim — `serialize` com `include_credentials` gate | Chamado em `clients_controller.rb:8,19` | VERIFIED |
| `app/serializers/api/v1/admin/arte_serializer.rb` | Sim | Sim — `resolve_media_url`, `media_source_type` ternário | Chamado em `artes_controller.rb:9,19` | VERIFIED |
| `app/serializers/api/v1/admin/approval_response_serializer.rb` | Sim | Sim — `arte_status:` param obrigatório em ambos métodos | Chamado em `approval_responses_controller.rb:9` | VERIFIED |
| `app/controllers/api/v1/admin/clients_controller.rb` | Sim | Sim — index paginado, create com credenciais, `password_plain` | Rota mapeada via routes; herda de BaseController | VERIFIED |
| `app/controllers/api/v1/admin/artes_controller.rb` | Sim | Sim — `apply_filters` com 3 filtros, create com upload lógico | Rota mapeada; herda de BaseController | VERIFIED |
| `app/controllers/api/v1/admin/approval_responses_controller.rb` | Sim | Sim — `set_arte`, index com `arte_status` no meta | Rota aninhada mapeada com `arte_id`; herda de BaseController | VERIFIED |
| `app/models/arte.rb` | Sim | Sim — `validates :media_file` com content_type + size + guard | Usado por ArtesController; callbacks preservados | VERIFIED |
| `config/routes.rb` | Sim | Sim — 5 rotas sob `namespace :admin` | Confirmado via `bin/rails routes` | VERIFIED |
| `test/controllers/api/v1/admin/clients_controller_test.rb` | Sim | 6 testes; cobre D-04, D-05, 401, 422, per_page | Conectado ao controller real; setup com JWT | VERIFIED |
| `test/controllers/api/v1/admin/artes_controller_test.rb` | Sim | 10 testes; cobre todos os filtros, upload, link, 401, 400, 422 | Usa `fixture_file_upload` com `sample.jpg` | VERIFIED |
| `test/controllers/api/v1/admin/approval_responses_controller_test.rb` | Sim | 4 testes; cobre D-11, 404, 401, meta.arte_status | Conectado ao controller real | VERIFIED |
| `test/fixtures/files/sample.jpg` | Sim | JPEG válido (22 bytes, cabeçalho JFIF) | Usado em `artes_controller_test.rb:185` | VERIFIED |

---

## Verificação de links-chave

| De | Para | Via | Status | Detalhe |
|----|------|-----|--------|---------|
| `clients_controller.rb` | `client_serializer.rb` | `ClientSerializer.serialize(include_credentials: true)` em create | WIRED | linha 19; `include_credentials:` apenas no create, nunca no index |
| `clients_controller.rb` | `base_controller.rb` | herança `< Api::V1::Admin::BaseController` | WIRED | linha 3; `pagy`, `per_page_param`, `pagination_meta` herdados |
| `artes_controller.rb` | `arte_serializer.rb` | `ArteSerializer.serialize(@arte)` e `serialize_collection` | WIRED | linhas 9 e 19 |
| `artes_controller.rb` | `arte.rb` | `Arte.statuses.key?(params[:status])` | WIRED | linha 29 do controller |
| `approval_responses_controller.rb` | `approval_response_serializer.rb` | `ApprovalResponseSerializer.serialize_collection(responses, arte_status: @arte.status)` | WIRED | linha 9 |
| `approval_responses_controller.rb` | `arte.rb` | `Arte.find(params[:arte_id])` em `set_arte` | WIRED | linha 19; `RecordNotFound` capturado pelo `rescue_from` herdado |
| `base_controller.rb` | `arte_serializer.rb` | `set_active_storage_current` popula `ActiveStorage::Current.url_options` antes de qualquer action | WIRED (runtime check pending) | ver human_verification #2 |

---

## Verificação de cobertura de requisitos

| Requisito | Plano | Descrição | Status | Evidência |
|-----------|-------|-----------|--------|-----------|
| APIADM-01 | 22-01, 22-02 | Admin lista clientes (paginado) | SATISFIED | `GET /api/v1/admin/clients` com Pagy + `meta.pagination` |
| APIADM-02 | 22-01, 22-02 | Admin cria novo cliente | SATISFIED | `POST /api/v1/admin/clients` com `include_credentials: true` |
| APIADM-03 | 22-01, 22-03 | Admin lista artes (filtros por cliente, status, mês) | SATISFIED | `apply_filters` com três filtros combinávies |
| APIADM-04 | 22-01, 22-03 | Admin cria nova arte (upload de imagem incluído) | SATISFIED | `POST /api/v1/admin/artes` com suporte multipart + `validates :media_file` |
| APIADM-05 | 22-01, 22-04 | Admin vê histórico de aprovações | SATISFIED | `GET /api/v1/admin/artes/:arte_id/approval_responses` |

Todos os cinco requisitos mapeados para Phase 22 em `REQUIREMENTS.md` têm cobertura completa. Nenhum requisito órfão identificado.

---

## Análise de anti-padrões

Nenhum marcador de dívida técnica não-resolvido encontrado (`TBD`, `FIXME`, `XXX`) nos arquivos modificados pela fase. Todos os arquivos começam com `# frozen_string_literal: true`. Nenhum `return null`, `return []`, ou handler vazio encontrado nos controllers.

| Arquivo | Padrão | Severidade | Impacto |
|---------|--------|------------|---------|
| `artes_controller.rb:29,37` | `ActionController::ParameterMissing` usado para validação de valor inválido (não param faltando) | Aviso | Mensagem de erro confusa ao consumidor (`"param is missing or the value is empty: status"`); funciona porque `rescue_from ParameterMissing → bad_request` existe; nenhum bloqueador |
| `approval_responses_controller.rb:7` | `@arte.approval_responses` sem paginação | Aviso | Histórico por arte é pequeno por design; `Pagy::Backend` herdado mas não usado aqui; não é bloqueador para a fase atual |
| `clients_controller.rb:14-15` | `password` chega duas vezes (`client_params` + atribuição direta a `password_plain`) | Aviso | Manutenção: se `client_params` mudar, `password_digest` pode não ser setado silenciosamente; comportamento atual correto |
| `clients.password_plain` (coluna DB) | Senha em texto plano persiste no banco | Aviso (design intencional) | Risco de exposição em dump/backup; CR-02 do 22-REVIEW.md documenta isso como decisão de produto intencional; não é bloqueador nesta fase |

**Nenhum bloqueador** (TBD/FIXME/XXX sem referência a issue/PR) encontrado.

---

## Verificação estrutural (Zeitwerk + rotas)

`bin/rails zeitwerk:check` passou: "all is good!"

`bin/rails routes` confirmou as 6 rotas admin API geradas corretamente:

```
GET    /api/v1/admin/clients                               api/v1/admin/clients#index
POST   /api/v1/admin/clients                               api/v1/admin/clients#create
GET    /api/v1/admin/artes/:arte_id/approval_responses     api/v1/admin/approval_responses#index
GET    /api/v1/admin/artes                                 api/v1/admin/artes#index
POST   /api/v1/admin/artes                                 api/v1/admin/artes#create
POST   /api/v1/admin/session                               api/v1/admin/sessions#create
```

Os namespaces `:client` e `:ai` foram preservados inalterados em `routes.rb:47-53`.

---

## Verificação humana requerida

### 1. Resposta do POST de cliente inclui password via coluna `password_plain`

**Teste:** `POST /api/v1/admin/clients` com `{ name: "Teste", password: "Senha123!" }` e JWT de admin válido
**Esperado:** Resposta 201 com `data.password == "Senha123!"` e `data.portal_url` com formato `http(s)://host/c/<access_token>`
**Por que humano:** A coluna `password_plain` deve ser escrita em `clients#create` e lida pelo serializer no mesmo request. O caminho existe no código, mas requer servidor rodando para confirmar que `password_plain` está sendo persistido e devolvido corretamente.

### 2. Upload multipart retorna `media_url` absoluta válida (Active Storage)

**Teste:** `POST /api/v1/admin/artes` com `multipart/form-data` contendo um JPEG em `media_file`, campos `title`, `scheduled_on`, `platform`, `media_type`, `client_id` e JWT de admin
**Esperado:** Resposta 201 com `data.media_url` contendo URL absoluta do blob (ex.: `http://localhost:3000/rails/active_storage/blobs/...`) e `data.media_source_type == "upload"`
**Por que humano:** `set_active_storage_current` popula `ActiveStorage::Current.url_options` corretamente no código, mas o efeito sobre `arte.media_file.url` só é verificável com servidor rodando e Active Storage configurado para disk service.

### 3. Filtros inválidos retornam 400 (não 500) via cadeia de rescue_from

**Teste:** `GET /api/v1/admin/artes?status=invalido` e `GET /api/v1/admin/artes?month=nao-data` com JWT de admin
**Esperado:** HTTP 400 em ambos os casos, com body `{ data: null, meta: {}, errors: [{ code: "bad_request", ... }] }`
**Por que humano:** `ActionController::ParameterMissing` é usada intencionalmente fora de seu propósito semântico (WR-01 do 22-REVIEW.md). O `rescue_from ActionController::ParameterMissing, with: :bad_request` existe em `Api::V1::BaseController`, mas a cadeia de herança e o comportamento em runtime requerem confirmação.

---

## Observações sobre o 22-REVIEW.md

O CR-01 (missing `return` em `authenticate_admin_jwt!` para usuário deletado) foi **corrigido**: todas as quatro guards em `base_controller.rb:14-21` agora usam `return render_unauthorized`. O CR-02 (coluna `password_plain`) foi explicitamente aceito como decisão de produto pré-existente e não constitui gap desta fase.

Os warnings WR-01, WR-02, WR-03, WR-04 e os itens informativos IN-01..03 são melhorias de qualidade documentadas, não blocadores para o objetivo da fase.

---

_Verificado: 2026-06-11_
_Verificador: Claude (gsd-verifier)_
