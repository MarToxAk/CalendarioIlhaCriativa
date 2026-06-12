# Phase 24: Endpoints IA + Rate Limiting - Context

**Gathered:** 2026-06-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Preenche o namespace `/api/v1/ai/*` (já existe em `config/routes.rb`, hoje vazio) com 3 endpoints de negócio da IA — listar artes aprovadas com filtro de período, inserir nova arte, ler resumo de aprovações por cliente — e adiciona um throttle de rate limiting ao Rack::Attack para proteger o namespace da IA. Cobre APIAI-01, APIAI-02, APIAI-03, INFAPI-04.

**No escopo:** `GET /api/v1/ai/artes` (artes aprovadas com `from`/`to` obrigatório), `POST /api/v1/ai/artes` (inserir arte via `external_url`), `GET /api/v1/ai/clients/:id/summary` (resumo de aprovações de um cliente), throttle Rack::Attack 60 req/min por API key.

**Fora do escopo:** endpoints admin ou cliente (Phases 22/23 — completos). Upload multipart pela IA (só `external_url`). Rate limiting de outros namespaces (`/api/v1/admin/*`, `/api/v1/client/*`) além do que já existe. Documentação OpenAPI/Swagger (v1.7).

</domain>

<decisions>
## Implementation Decisions

### Listagem de artes aprovadas (APIAI-01)
- **D-01:** Filtro de período via **`from` + `to`** em formato ISO 8601 (`YYYY-MM-DD`), e.g. `?from=2026-06-01&to=2026-06-30`. Mais expressivo para a IA do que `month` — permite janelas arbitrárias (últimos 7 dias, próximas 2 semanas etc.).
- **D-02:** Filtro de período **obrigatório** — sem `from`/`to` retorna **400** estruturado. Evita retornar todas as artes aprovadas de todos os tempos à medida que o volume cresce.
- **D-03:** Filtro por **`client_id`** opcional (padrão da Phase 22 — combina com outros filtros). Sem ele a IA vê todas as artes aprovadas no período.
- **D-04:** Endpoint retorna **somente artes com status `approved`** — o requisito é "listar artes aprovadas". Paginação Pagy default 25 / teto ~100 (padrão estabelecido).
- **D-05:** Ordenação por `scheduled_on: :asc` (mais próxima primeiro) — a IA normalmente processa em ordem cronológica.

### Inserção de arte pela IA (APIAI-02)
- **D-06:** Payload **idêntico ao admin exceto `media_file`** — aceita `{ title, caption, scheduled_on, approval_deadline, platform, media_type, client_id, external_url }`. A IA usa **somente `external_url`** (Drive/Dropbox/link); campo `media_file` não é suportado (IAs não enviam binários facilmente). Receber `media_file` retorna 400.
- **D-07:** Reusa o mesmo `arte_params` / model `Arte` com suas validações (`only_one_media_source`, `media_source_present`). Resposta 201 com a arte criada (mesmo serializer da Phase 22 / a definir pela pesquisa).
- **D-08:** `external_url` é **obrigatório** neste endpoint (não há fallback de upload). A validação do model (`media_source_present`) já garante isso — sem `external_url` retorna 422 estruturado.

### Resumo de aprovações por cliente (APIAI-03)
- **D-09:** Rota **por cliente específico**: `GET /api/v1/ai/clients/:id/summary`. Retorna estado atual das aprovações daquele cliente — sem filtro de período (a IA vê o quadro geral de tudo que existe). A IA pode chamar N vezes, uma por cliente relevante.
- **D-10:** Resposta inclui os 4 campos do requisito: `{ total, approved_count, pending_count, change_requested_count }`. Opcionalmente `revised_count` (artes devolvidas para revisão) — a critério do planejamento.
- **D-11:** Cliente inexistente → 404 estruturado (padrão `rescue_from RecordNotFound`). Sem paginação neste endpoint (é um único objeto de resumo).

### Rate limiting (INFAPI-04)
- **D-12:** Throttle aplicado **somente ao namespace `/api/v1/ai/*`** — admin e client não são afetados (têm seus próprios throttles de login já configurados). Escopo mais cirúrgico.
- **D-13:** Limite: **60 requisições por minuto por API key**. Identificador de throttle = o próprio token `ak_…` extraído do header `Authorization`. Se token ausente/inválido, a autenticação já retorna 401 antes de chegar ao throttle.
- **D-14:** Resposta 429 reutiliza o **`Rack::Attack.throttled_responder`** já configurado (JSON estruturado `{ data: null, meta: {}, errors: [{ code: "too_many_requests", ... }] }`).
- **D-15:** Sem burst especial — janela de 60 segundos, 60 requisições. Se a IA precisar de mais, rotaciona para uma key diferente ou aguarda (aceitável para casos de uso de agente).

### Claude's Discretion
- Nome exato do throttle no Rack::Attack (e.g. `"api/ai_by_key"`) — a critério do planejamento.
- Se criar serializer dedicado `Api::V1::Ai::ArteSerializer` ou reusar o admin (campos são os mesmos — aprovadas têm os campos completos) — pesquisa decide. Dado que o consumidor é diferente (IA vs admin), um serializer dedicado pode adicionar clareza mas não é obrigatório.
- Se o `GET /ai/clients/:id/summary` deve carregar dados via `Arte.where(client_id: id).group(:status).count` ou via `client.artes.group(:status).count` (equivalentes, planejamento escolhe o mais legível).
- `revised_count` no resumo — incluir ou não (pedido foi APIAI-03 pede apenas 4 campos, mas `revised` existe no enum).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Fundação da API (Phase 21 — base obrigatória)
- `app/controllers/api/v1/base_controller.rb` — `render_envelope`/`render_error` + `rescue_from` (404/422/400/401). Todos os controllers herdam deste.
- `app/controllers/api/v1/ai/base_controller.rb` — `authenticate_ai_key!` já implementado (`ak_` prefix + `secure_compare`). Os controllers da IA herdam deste.
- `.planning/phases/21-funda-o-da-api-autentica-o/21-CONTEXT.md` — D-06/D-07/D-08: namespace `/api/v1/ai/`, API key em credentials/ENV, envelope.

### Padrões da Phase 22 (consistência de contrato)
- `.planning/phases/22-endpoints-admin/22-CONTEXT.md` — serializers PORO, `media_url` absoluto, paginação Pagy, filtros por `client_id`/`status`/`month`, params flat.
- `app/controllers/api/v1/admin/base_controller.rb` — helpers `pagination_meta`, `per_page_param`, `set_active_storage_current`. O base da IA precisa do equivalente (ou herdar de um concern compartilhado) para serializar `media_url`.
- `app/controllers/api/v1/admin/artes_controller.rb` — `apply_filters`, `arte_params`, padrão de `pagy` + `render_envelope`. Referência direta para o endpoint APIAI-01/APIAI-02.
- `app/serializers/api/v1/admin/arte_serializer.rb` — analog direto para o serializer de artes da IA.

### Rate limiting (Rack::Attack)
- `config/initializers/rack_attack.rb` — throttles existentes + `throttled_responder` JSON já configurado. O novo throttle da IA vai NESTE arquivo.
- `.planning/phases/21-funda-o-da-api-autentica-o/21-CONTEXT.md` §"Rack-Attack" — nota que a infra existe desde v1.0.

### Models e validações
- `app/models/arte.rb` — enum `status { pending, approved, change_requested, revised }`, validações `only_one_media_source`/`media_source_present`, `has_one_attached :media_file`. Filtragem de `approved` e inserção de arte passam por aqui.
- `app/models/approval_response.rb` — `belongs_to :arte`, enum `decision`, para construir o resumo por cliente (APIAI-03).

### Requisitos e roadmap
- `.planning/REQUIREMENTS.md` §Endpoints IA (APIAI-01..03) e §Infraestrutura (INFAPI-04).
- `.planning/ROADMAP.md` §Phase 24 — goal e 4 critérios de sucesso.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Api::V1::Ai::BaseController` — `authenticate_ai_key!` + herança de `Api::V1::BaseController` prontos; controllers da IA herdam deste.
- `Api::V1::Admin::BaseController` helpers (`pagination_meta`, `per_page_param`, `set_active_storage_current`, `page_overflow`, `rescue_from Pagy::OverflowError`) — duplicar ou extrair para concern compartilhado para servir o base da IA.
- `Api::V1::Admin::ArtesController#apply_filters` — filtro por `client_id`, `status`, `month`. Adaptar para `from`/`to` ISO nesta fase.
- `Api::V1::Admin::ArteSerializer` — referência direta para o serializer de artes da IA.
- `config/initializers/rack_attack.rb` — adicionar um `throttle("api/ai_by_key", limit: 60, period: 60)` neste arquivo.

### Established Patterns
- Auth da IA via `ak_` prefix já implementada — não reimplementar.
- Params flat (sem `.require(:resource)`) — padrão das Phases 21/22.
- `save!` + `rescue_from` centralizado (sem rescue local) — envelope 422 automático.
- Paginação Pagy + `meta.pagination = { page, per_page, total_count, total_pages }`.
- `set_active_storage_current` antes de serializar artes com `media_file` — sem isso, `url` levanta `Missing host` (pitfall identificado na Phase 22).

### Integration Points
- `config/routes.rb` namespace `:ai` já existe mas está vazio — adicionar `resources :artes, only: [:index, :create]` e `resources :clients, only: [] do get :summary, on: :member end`.
- Novo throttle em `config/initializers/rack_attack.rb`.
- Token `ak_…` já está no `Authorization: Bearer` quando o request chega — o throttle extrai com `req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")`.

</code_context>

<specifics>
## Specific Ideas

- `GET /api/v1/ai/artes?from=YYYY-MM-DD&to=YYYY-MM-DD` — período obrigatório, retorna só `approved`, paginado.
- `POST /api/v1/ai/artes` — só `external_url`, sem `media_file`; receber `media_file` → 400.
- `GET /api/v1/ai/clients/:id/summary` — `{ total, approved_count, pending_count, change_requested_count }` do estado atual.
- Throttle: `throttle("api/ai_by_key", limit: 60, period: 60) { |req| req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip if req.path.start_with?("/api/v1/ai/") }`.

</specifics>

<deferred>
## Deferred Ideas

- **Rate limiting para namespaces admin/client** — descartado desta fase; admin e client têm throttles de login mas não de operação geral. Adicionar se houver demanda de segurança futura.
- **Upload multipart pela IA** — descartado (IAs usam links); reconsiderar se um caso de uso específico exigir.
- **Filtro de período no resumo APIAI-03** — descartado (a IA vê o estado atual total); reconsiderar se o agente precisar de métricas históricas.
- **Burst allowance para a IA** — descartado (60/min flat suficiente para agente; sem SLA especial definido).
- **Documentação OpenAPI/Swagger** — explicitamente fora de escopo (v1.7 per REQUIREMENTS.md).

</deferred>

---

*Phase: 24-endpoints-ia-rate-limiting*
*Context gathered: 2026-06-12*
