# Phase 23: Endpoints Cliente - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Expõe os endpoints do app mobile do cliente sobre a fundação da API: listar as artes pendentes do cliente, ver o detalhe de uma arte e submeter resposta de aprovação. Tudo escopado ao `@current_client` (já resolvido pelo JWT de cliente da Phase 21), usando o envelope `{ data, meta, errors }` e os serializers PORO/Pagy estabelecidos na Phase 22. Cobre APICLI-01, APICLI-02, APICLI-03.

**No escopo:** `GET` lista de artes pendentes (paginada), `GET` detalhe de uma arte, `POST` resposta de aprovação aninhada na arte. Garantia de escopo cross-client. Sob `/api/v1/client/*`.

**Fora do escopo (outras fases):** endpoints da IA + rate limiting (Phase 24). Edição de arte pelo cliente (cliente só aprova/pede alteração, nunca cria/edita arte). Login/sessão do cliente já entregue na Phase 21 (`POST /api/v1/client/session`).

</domain>

<decisions>
## Implementation Decisions

### Listagem de artes pendentes (APICLI-01)
- **D-01:** A lista retorna artes com status **`pending` E `revised`** — ambos exigem ação do cliente. Espelha exatamente o portal web, que conta como "pendente" `%w[pending revised]` (`Client::HomeController`). Não incluir `approved` nem `change_requested` (já respondidas / aguardando admin).
- **D-02:** Lista **todas** as artes pendentes do cliente (independente de mês), ordenadas por **`scheduled_on`** (mais próxima primeiro), **paginadas** com `page`/`per_page` (default 25, teto ~100) via Pagy — mesmo contrato da Phase 22. `meta.pagination = { page, per_page, total_count, total_pages }`. O app vê uma fila de pendências, não um calendário mensal.

### Detalhe da arte (APICLI-02)
- **D-03:** O detalhe expõe: `id`, `title`, `caption`, `scheduled_on`, `approval_deadline`, `platform`, `media_type`, `media_url` (absoluto resolvido, como D-03 da Phase 22), `status`. **Sem** campos internos do admin (ex.: nenhum dado de outros clientes).
- **D-04:** O detalhe **inclui o histórico das próprias respostas** do cliente (`approval_responses`: `id`, `decision`, `comment`, `responded_at`) para o cliente ver o que já enviou, e o **`admin_reply`** (resposta interna do admin a um pedido de alteração) **quando presente** — útil na re-aprovação de arte `revised`. Não vaza respostas/dados de outros clientes (sempre escopado à arte do `@current_client`).

### Submissão da aprovação (APICLI-03)
- **D-05:** Rota REST **aninhada**: `POST /api/v1/client/artes/:arte_id/approval_responses`, payload **flat** `{ decision, comment }` (sem wrapper `:approval_response`). `decision` é string do enum (`approved` / `change_requested`).
- **D-06:** **Comentário opcional** para ambas as decisões — paridade exata com a web (APRO-02 não exige comentário). Não adicionar regra de obrigatoriedade que a web não tem.
- **D-07:** A criação usa **lock de linha em transação** (`@current_client.artes.lock.find(id)` dentro de `Arte.transaction`), espelhando `Client::ResponsesController` para evitar corrida em duplo-submit. Os callbacks do `ApprovalResponse` (sync de status da arte + broadcasts ActionCable ao admin) **permanecem ativos** — é o mesmo fluxo da web.
- **D-08:** Resposta **201** com a `approval_response` criada (`id`, `decision`, `comment`, `responded_at`) **+ o status resultante da arte** (`approved`/`change_requested`), para o app atualizar a UI sem re-buscar. **Re-aprovar arte `revised` é permitido** (o model `ApprovalResponse#arte_must_be_pending` aceita `pending?` OU `revised?`).

### Erros e escopo de borda
- **D-09:** Arte de **outro cliente** → **404 estruturado** via escopo (`@current_client.artes.find` levanta `RecordNotFound` → 404 pelo `rescue_from` herdado). Não vaza existência do recurso (sem enumeração). Atende o critério 4 do roadmap e espelha a web. **Não** usar 403.
- **D-10:** Submissão em arte **não-aprovável** (já `approved` ou em `change_requested`) → **422** estruturado (a validação `arte_must_be_pending` falha → `rescue_from ActiveRecord::RecordInvalid` já existente). `decision` fora do enum (`approved`/`change_requested`) → **400/422** estruturado. Nunca 500. Cliente inativo já cai em 401 pela fundação (`authenticate_client_jwt!` checa `active?`).

### Claude's Discretion
- Biblioteca/estratégia de serialização permanece PORO (Phase 22) — pesquisa/planejamento decide se reusa o `ArteSerializer` admin ou cria um `Api::V1::Client::ArteSerializer` específico (sem campos internos). Dado D-03/D-04 (campos diferentes do admin + histórico do cliente), um serializer de cliente dedicado é provavelmente mais limpo, mas fica a critério da pesquisa.
- Código HTTP exato para `decision` inválido (400 vs 422) e nomes exatos dos campos JSON ficam a critério do planejamento, respeitando as decisões acima.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Fundação da API + auth do cliente (Phase 21 — base obrigatória)
- `app/controllers/api/v1/base_controller.rb` — `render_envelope`/`render_error` + `rescue_from` (404/422/400). Reusar em todos os endpoints.
- `app/controllers/api/v1/client/base_controller.rb` — `authenticate_client_jwt!` + `@current_client` (já checa `active?`); os controllers de negócio do cliente herdam deste. Escopo cross-client vem daqui.
- `.planning/phases/21-funda-o-da-api-autentica-o/21-CONTEXT.md` — decisões da fundação (envelope, JWT de cliente, namespaces).

### Padrões da Phase 22 (consistência de contrato)
- `.planning/phases/22-endpoints-admin/22-CONTEXT.md` — serializers PORO, `media_url` absoluto resolvido (D-03), paginação Pagy + `meta.pagination`, params flat. Manter o mesmo contrato.
- `app/controllers/api/v1/admin/base_controller.rb` — helpers `pagination_meta`, `per_page_param`, `set_active_storage_current`. O base do cliente precisa do equivalente (Pagy + ActiveStorage host) para listar/serializar mídia.
- `app/serializers/api/v1/admin/arte_serializer.rb` — analog direto para o serializer de arte do cliente.

### Paridade com o portal web do cliente
- `app/controllers/client/home_controller.rb` — define "pendente" = `pending` + `revised` (D-01).
- `app/controllers/client/responses_controller.rb` — submissão com lock de linha + `{decision, comment}`, validação de enum, escopo `@client.artes` (D-05/D-07).
- `app/controllers/client/artes_controller.rb` — detalhe escopado com `includes(:approval_responses)` (D-04/D-09).
- `app/models/approval_response.rb` — `arte_must_be_pending` (pending OU revised), `sync_arte_status`, broadcasts (D-08/D-10).

### Requisitos e roadmap
- `.planning/REQUIREMENTS.md` §Endpoints Cliente (APICLI-01..03).
- `.planning/ROADMAP.md` §Phase 23 — goal e 4 critérios de sucesso (inclui escopo cross-client).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Api::V1::Client::BaseController` — auth + `@current_client` + active check prontos; herdar dele em todos os controllers desta fase.
- `Api::V1::Admin::BaseController` helpers (`pagination_meta`, `per_page_param`, `set_active_storage_current`, `page_overflow`, `rescue_from Pagy::OverflowError`) — extrair/duplicar o necessário para o base do cliente (ou promover a um concern compartilhado).
- `Api::V1::Admin::ArteSerializer` — analog para o serializer de arte do cliente (mesma resolução de `media_url`).
- `Client::ResponsesController` — referência exata do fluxo de submissão (lock, transação, validação de enum, escopo).
- `ApprovalResponse` model — enum `decision { approved, change_requested }`, validação `arte_must_be_pending`, `sync_arte_status`, broadcasts ao admin (mantidos).
- `Arte` model — enum `status { pending, approved, change_requested, revised }`; scope por `@current_client.artes`.

### Established Patterns
- Escopo SEMPRE por `@current_client.artes` (nunca `Arte.find` global) — previne cross-client (D-09).
- Params flat (sem `.require(:resource)`) — padrão das Phases 21/22.
- `save!`/`find` + `rescue_from` centralizado (sem rescue local) — envelope estruturado automático.
- Callbacks do `ApprovalResponse` disparam broadcasts ActionCable ao admin ao submeter via API — intencional (o admin web vê a resposta ao vivo, como na web).

### Integration Points
- Novas rotas sob `namespace :client` em `config/routes.rb` (hoje só `resource :session`): `resources :artes, only: [:index, :show] do resources :approval_responses, only: [:create] end`.
- Novos controllers `Api::V1::Client::ArtesController` (index/show) e `Api::V1::Client::ApprovalResponsesController` (create), herdando de `Api::V1::Client::BaseController`.
- Serialização de mídia precisa do `ActiveStorage::Current.url_options` setado no base do cliente (mesmo pitfall da Phase 22 — sem isso, `media_file.url` levanta `Missing host`).

</code_context>

<specifics>
## Specific Ideas

- "Pendente" = `pending` + `revised` (igual à web).
- Fila de pendências ordenada por `scheduled_on`, paginada (não calendário mensal).
- `POST /api/v1/client/artes/:arte_id/approval_responses` flat `{ decision, comment }`.
- 201 devolve a resposta criada + o novo status da arte.
- Cross-client → 404 (sem enumeração); não-aprovável → 422.

</specifics>

<deferred>
## Deferred Ideas

- **Filtro por mês na listagem do cliente** (`?month=YYYY-MM`, como a web) — descartado nesta fase em favor de uma fila única de pendências; reconsiderar se o app quiser uma visão de calendário.
- **Comentário obrigatório em "pediu alteração"** — descartado para manter paridade com a web; reconsiderar se o admin reclamar de pedidos sem contexto (mudaria o contrato dos dois canais).
- **Endpoint de artes já respondidas / histórico completo do cliente** (aprovadas + change_requested) — fora do escopo (APICLI-01 é só pendentes); adicionar se o app precisar de uma aba "histórico".
- **Rate limiting** — pertence à Phase 24.

</deferred>

---

*Phase: 23-endpoints-cliente*
*Context gathered: 2026-06-11*
