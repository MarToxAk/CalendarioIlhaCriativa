# Phase 22: Endpoints Admin - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Expõe os endpoints de negócio do admin sobre a fundação da API (Phase 21): listar e criar clientes (paginado), listar e criar artes (com upload de imagem), e consultar o histórico de aprovações de uma arte. Tudo sob `/api/v1/admin/*`, autenticado por JWT de admin, usando o envelope `{ data, meta, errors }` e o mapeamento de erros já existentes.

**No escopo:** `GET/POST` de clientes (paginação + criação), `GET/POST` de artes (filtros por cliente/status/mês + criação com upload ou link externo), `GET` do histórico de aprovações aninhado por arte. Cobre APIADM-01..05.

**Fora do escopo (outras fases):** endpoints do cliente mobile (Phase 23), endpoints da IA + rate limiting (Phase 24). Edição/exclusão de cliente ou arte via API não está nos requisitos desta fase (não solicitado pelo roadmap).

</domain>

<decisions>
## Implementation Decisions

### Upload de imagem da arte (APIADM-04)
- **D-01:** App envia a imagem via **`multipart/form-data`** com o arquivo binário direto no campo `media_file` — mesmo mecanismo do form web (reusa Active Storage `has_one_attached :media_file`). Sem base64, sem direct-upload/signed_id nesta fase.
- **D-02:** A criação de arte aceita **arquivo OU `external_url`** (Drive/Dropbox), com paridade total ao web: vale a regra `only_one_media_source` (exatamente uma fonte) e `media_source_present` (pelo menos uma) já no model `Arte`. Não regride a opção de link que o admin tem no painel.
- **D-03:** Na resposta JSON de uma arte, a mídia é representada por uma **URL absoluta já resolvida** (campo tipo `media_url`: URL do blob Active Storage quando upload, ou o `external_url` quando link) **+ um campo indicando a fonte** (`upload`/`link`). O app só carrega a URL pronta, sem conhecer Active Storage.

### Representação do cliente no JSON (APIADM-01, APIADM-02)
- **D-04:** Senha/credencial só aparece no **POST de criação**. `GET` (lista e detalhe) **nunca** retorna senha; o `access_token` só aparece como parte da URL do portal, não como credencial avulsa.
- **D-05:** No **POST de criação**, a resposta devolve **uma única vez** o link completo do portal do cliente + a senha, para o admin repassar ao cliente.
- **D-06:** A senha vem **no payload** enviado pelo app: `{ name, password }` (+ `active` opcional), espelhando `client_params` do web (`:name, :password, :active`). O `access_token` é **gerado automaticamente** (`has_secure_token :access_token`), nunca enviado pelo app.

### Filtros e paginação (APIADM-01, APIADM-03)
- **D-07:** Filtros da listagem de artes via **query params nomeados com valores string**, todos opcionais e combináveis: `client_id`, `status` (string do enum: `pending`/`approved`/`change_requested`/`revised`), `month` no formato **`YYYY-MM`**. Não usar índices numéricos crus do enum.
- **D-08:** Paginação via `page` e `per_page` (**default 25**, alinhado ao web/Pagy; teto sugerido ~100), reusando **Pagy** (`Pagy::Backend`, já no projeto). Aplica-se tanto à lista de clientes quanto à de artes.
- **D-09:** Metadados de paginação no envelope: **`meta.pagination = { page, per_page, total_count, total_pages }`**.

### Histórico de aprovações (APIADM-05)
- **D-10:** Histórico exposto **aninhado por arte**: `GET /api/v1/admin/artes/:id/approval_responses`. Mapeia direto a `has_many :approval_responses, -> { order(created_at: :desc) }`. (Filtro/visão por cliente é coberto pela listagem de artes filtrada por `client_id` — não há endpoint separado por cliente nesta fase.)
- **D-11:** Cada resposta inclui: `id`, `decision` (string `approved`/`change_requested`), `comment`, `responded_at` (e `created_at`). O **status atual da arte** acompanha a resposta (no recurso da arte ou no `meta`).

### Claude's Discretion
- Biblioteca/estratégia de serialização (jbuilder / serializer plano / Alba / etc.) continua **em aberto** da Phase 21 — pesquisa/planejamento decide, respeitando o envelope e os campos acima.
- Variantes/thumbnails da imagem (além da URL principal) ficam a critério da pesquisa, se fizer sentido para o app.
- Ordenação padrão das listagens (ex.: artes por `scheduled_on: :desc` como no web), nomes exatos dos campos JSON, e o teto exato de `per_page` ficam a critério do planejamento, respeitando as decisões acima.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Fundação da API (Phase 21 — base obrigatória desta fase)
- `.planning/phases/21-funda-o-da-api-autentica-o/21-CONTEXT.md` — decisões D-01..D-08 da fundação: envelope `{ data, meta, errors }`, namespaces, auth dos 3 consumidores, mapeamento de erros.
- `app/controllers/api/v1/base_controller.rb` — `render_envelope`/`render_error` e `rescue_from` (404/422/400) que TODO endpoint desta fase deve reusar.
- `app/controllers/api/v1/admin/base_controller.rb` — `authenticate_admin_jwt!` + `@current_user`; os controllers de negócio admin herdam deste.

### Requisitos e roadmap
- `.planning/REQUIREMENTS.md` §Endpoints Admin (APIADM-01..05) + tabela de rastreabilidade.
- `.planning/ROADMAP.md` §Phase 22 — goal e 5 critérios de sucesso.

### Sem ADRs externos adicionais
- Não há ADRs/specs externos além dos acima — as decisões de implementação estão capturadas em `<decisions>`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/controllers/admin/artes_controller.rb` — `arte_params` (`:title, :caption, :scheduled_on, :approval_deadline, :external_url, :platform, :media_type, :client_id, :media_file, :admin_reply`) e a lógica `media_source` (upload zera `external_url`); base direta para o POST de arte da API.
- `app/controllers/admin/clients_controller.rb` — `client_params` (`:name, :password, :active`); base do POST de cliente.
- `app/controllers/admin/approvals_controller.rb` — uso de `pagy(scope, limit: 25, ...)`; precedente direto da paginação (D-08/D-09).
- `app/controllers/admin/base_controller.rb` — `include Pagy::Backend`; reaproveitar para o base controller admin da API.
- Models: `Arte` (enums `platform`/`media_type`/`status`, validações `only_one_media_source`/`media_source_present`, `has_one_attached :media_file`, `has_many :approval_responses` ordenado desc), `Client` (`has_secure_token :access_token`, `has_secure_password`), `ApprovalResponse` (enum `decision`, `comment`, `responded_at`).

### Established Patterns
- Queries admin web NÃO escopam por `@client` na listagem global de artes (mostram todos os clientes) — a API admin segue o mesmo: vê todos os clientes, filtra opcionalmente por `client_id`.
- Auth Rails 8 nativo via `has_secure_password` (sem Devise) — POST de cliente reusa esse fluxo.
- `Arte` dispara broadcasts ActionCable em callbacks (`after_create`/`after_update_commit`); criar arte via API **manterá** esses callbacks (cliente/admin web continuam recebendo tempo real). Planejamento deve estar ciente, não desabilitar.

### Integration Points
- Novas rotas REST sob `namespace :admin` em `config/routes.rb` (hoje só tem `resource :session`): `resources :clients` (index/create), `resources :artes` (index/create) com `resources :approval_responses, only: [:index]` aninhado.
- Novos controllers `Api::V1::Admin::ClientsController`, `Api::V1::Admin::ArtesController`, `Api::V1::Admin::ApprovalResponsesController`, todos herdando de `Api::V1::Admin::BaseController`.
- Serialização da arte precisa resolver URL absoluta do blob Active Storage (D-03) — requer host configurado para `url_for`/`rails_blob_url` no contexto de API.

</code_context>

<specifics>
## Specific Ideas

- `month=YYYY-MM` como formato do filtro de mês (legível, casa com a navegação mensal do calendário).
- `meta.pagination = { page, per_page, total_count, total_pages }` literal.
- Resposta do POST de criação de cliente devolve link do portal + senha **uma única vez** (não reexposto em GET).
- Histórico aninhado: `GET /api/v1/admin/artes/:id/approval_responses`.

</specifics>

<deferred>
## Deferred Ideas

- **Endpoint de histórico agregado por cliente** (`/admin/clients/:id/approval_responses`) — não necessário nesta fase; reconsiderar se o app de admin precisar de uma timeline por cliente.
- **Edição/exclusão de cliente e arte via API** (PUT/PATCH/DELETE) — fora dos requisitos APIADM-01..05; adicionar em fase futura se o app mobile precisar gerenciar, não só criar/listar.
- **Direct upload / signed_id e variantes/thumbnails** de imagem — descartado nesta fase por complexidade; reconsiderar se arquivos grandes ou performance no app exigirem.
- **Rate limiting** — pertence à Phase 24 (infra `rack-attack` já existe).

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 22-endpoints-admin*
*Context gathered: 2026-06-11*
