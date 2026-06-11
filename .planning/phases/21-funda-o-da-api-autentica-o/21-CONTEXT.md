# Phase 21: Fundação da API + Autenticação - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Entrega a fundação de uma API JSON REST versionada em `/api/v1/` com os três modos de autenticação funcionando e um middleware que distingue cada tipo de consumidor (admin, cliente, IA). Inclui o envelope de resposta consistente e o tratamento estruturado de erros.

**No escopo:** versionamento `/api/v1/`, login admin (JWT), login cliente (JWT), auth IA (API key), middleware de discriminação de consumidor, envelope `{ data, meta, errors }`, mapeamento de erros → HTTP. Cobre AUTH-01..05, INFAPI-01, INFAPI-02, INFAPI-03.

**Fora do escopo (outras fases):** endpoints de negócio admin (Phase 22), cliente (Phase 23), IA + rate limiting (Phase 24).

</domain>

<decisions>
## Implementation Decisions

### Autenticação do cliente na API
- **D-01:** Cliente autentica com `access_token` + senha (paridade com o portal) e recebe um **JWT de cliente curto** usado como `Authorization: Bearer`. O `access_token` (que viaja no link do calendário, semi-público) **nunca** é credencial de API sozinho.
- **D-02:** Novo endpoint `POST /api/v1/client/session` recebe `{ access_token, password }` → valida via `Client#authenticate` (já existe `has_secure_password`) → retorna JWT de cliente (subject = `client.id`, claim `scope: "client"`).
- **Porquê:** submeter aprovação é mutação no coração do produto; exige autenticação real, não um link encaminhável. Mantém o modelo do portal (token identifica, senha prova) sem regressão de segurança. Contraria a nota `api-auth-strategy.md` ("não criar senha para clientes") — mas o `Client` já tem senha e o portal já a exige, então a premissa da nota era inválida.

### Autenticação admin na API
- **D-03:** Admin autentica com email + senha → recebe **JWT de admin** (subject = `user.id`, claim `scope: "admin"`). Endpoint `POST /api/v1/admin/session`. Valida contra `User#authenticate` (já existe `has_secure_password` + modelo `Session`), mas emite JWT em vez de cookie de sessão (stateless para mobile).

### Estratégia de expiração/renovação do JWT
- **D-04:** **JWT único, sem refresh token.** Expiração configurável, padrão **24h** (AUTH-02). Ao expirar, o app re-loga. Revogação por expiração natural.
- **Porquê:** alinha com o DNA enxuto do projeto (auth sem Devise, status binário, sem notificações v1). Evita tabela de refresh, rotação e lógica de revogação. Trade-off aceito: credencial comprometida permanece válida até expirar (mitigação operacional: rotacionar `access_token` do cliente / trocar senha do admin). Refresh token e claim `token_version` ficam como ideias deferidas se a UX mobile exigir.

### Formato do envelope de resposta
- **D-05:** Toda resposta segue envelope custom leve **`{ data, meta, errors }`**. `errors` é uma lista de objetos `{ code, detail, field? }`. Erros retornam o **status HTTP correto** (INFAPI-03): 401 sem auth (AUTH-05), 404 não encontrado, 422 validação. (429 de rate limit entra na Phase 24.)
- **Porquê:** casa literalmente com INFAPI-02 ("data + meta + errors"), simples para os 2 consumidores conhecidos (mobile + IA), alinha com simplicidade. JSON:API foi descartado por verbosidade/cerimônia desproporcional ao tamanho da API. A biblioteca de serialização concreta (jbuilder / ActiveModel::Serializers / Alba / serializer plano) fica para a pesquisa decidir.

### Discriminação dos 3 consumidores e namespaces
- **D-06:** Namespaces por consumidor: **`/api/v1/admin/*`** (JWT admin), **`/api/v1/client/*`** (JWT cliente, inclui `/client/session`), **`/api/v1/ai/*`** (API key). Espelha a estrutura web atual (namespace `admin` + scope `client`), isola a IA para auditoria (sugestão da nota) e habilita rate-limit segmentado na Phase 24.
- **D-07:** Middleware de autenticação distingue pelo `Authorization: Bearer <token>`: (1) token com prefixo de API key (ex. `ak_…`) → consumidor IA; (2) senão, decodifica como JWT → claim `scope` define admin ou cliente; (3) senão → 401 estruturado. Um base controller de API por consumidor declara o auth exigido (precedente: `connection.rb` já faz dual-auth admin-cookie/cliente-token).
- **D-08:** API key da IA é **opaca e prefixada**, armazenada como **secret de ambiente** (não no banco), validada contra o(s) valor(es) configurado(s). Facilita rotação e mantém escopo separado do admin.

### Claude's Discretion
- Áreas 1 e 2 foram delegadas ("Você decide") e decididas acima (D-01/02, D-04) com o raciocínio registrado. A escolha da gem JWT, da lib de serialização, do prefixo exato da API key e da estrutura concreta dos claims do JWT ficam a critério da pesquisa/planejamento, respeitando as decisões acima.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Estratégia de autenticação (design original — ler com a ressalva abaixo)
- `.planning/notes/api-auth-strategy.md` — três modos de auth e justificativas. **Ressalva:** a decisão "não criar senha para clientes / token sozinho como Bearer" foi **substituída** por D-01/D-02 (cliente usa token + senha → JWT). O restante (JWT admin, API key da IA em env, namespace `/api/v1/ai/` para auditoria) permanece válido.

### Requisitos e roadmap
- `.planning/REQUIREMENTS.md` §Autenticação (AUTH-01..05) e §Infraestrutura (INFAPI-01..03) — requisitos desta fase + tabela de rastreabilidade.
- `.planning/ROADMAP.md` §Phase 21 — goal e 5 critérios de sucesso (envelope, 401 estruturado, três modos de auth).

### Sem ADRs externos adicionais
- Não há ADRs/specs externos além dos acima — as decisões de implementação estão capturadas em `<decisions>`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/channels/application_cable/connection.rb` — já faz **dual-auth** (admin via `Session`/cookie, cliente via `access_token`); precedente direto de como distinguir consumidores. Reaproveitar a lógica de lookup (`Session.find_by`, `Client.find_by(access_token:, active: true)`).
- `app/models/client.rb` — `has_secure_token :access_token` + `has_secure_password`; `#authenticate(password)` e `#token_version` (primeiros 8 chars do token) já disponíveis para o login de cliente da API.
- `app/models/user.rb` — `has_secure_password` + `has_many :sessions`; base do login admin (validar credenciais, emitir JWT em vez de Session).
- `app/controllers/concerns/authentication.rb` — concern de auth web (cookie/Session). A API NÃO reusa o fluxo de cookie, mas serve de referência de `allow_unauthenticated_access` / `require_authentication` para modelar o equivalente da API (`require_api_admin` etc.).
- `rack-attack` (Gemfile, já configurado com 4 throttles desde v1.0) — base para o rate limiting da Phase 24; não usado nesta fase mas a infra existe.

### Established Patterns
- Rotas já segmentadas por consumidor: `namespace :admin` e `scope "/c/:token", as: :client` (`config/routes.rb`). A API espelha isso com `namespace :api do namespace :v1 do namespace :admin/client/ai`.
- Auth Rails 8 nativo (sem Devise) — manter o estilo: validação via `has_secure_password`, sem dependências pesadas de auth.
- **Sem gem JWT no Gemfile** — precisa adicionar uma (pesquisa escolhe; ex. `ruby-jwt`).

### Integration Points
- Novas rotas sob `/api/v1/` em `config/routes.rb` (admin/client/ai namespaces) + `POST /api/v1/admin/session` e `POST /api/v1/client/session`.
- Novo base controller de API (ex. `Api::V1::BaseController < ActionController::API`) com o middleware de discriminação e o helper de envelope `{ data, meta, errors }`.
- Segredo da API key da IA via `Rails.application.credentials` ou ENV.

</code_context>

<specifics>
## Specific Ideas

- Header único `Authorization: Bearer <token>` para os três modos (consistente com a nota de design).
- Envelope literal `{ data, meta, errors }` com `errors: [{ code, detail, field? }]`.
- Namespace `/api/v1/ai/` separado especificamente para auditabilidade da IA.

</specifics>

<deferred>
## Deferred Ideas

- **Refresh tokens** (access JWT curto + refresh de longa duração) — descartado nesta fase por complexidade; reconsiderar se a UX mobile (re-login a cada 24h) incomodar.
- **Claim `token_version` / denylist para revogação imediata** de JWT antes da expiração — fora do escopo; adicionar se houver requisito de logout/revogação forçada.
- **Swagger/OpenAPI** — já fora de escopo do milestone (planejado p/ v1.7).
- **Rate limiting** — pertence à Phase 24 (infra `rack-attack` já existe).

</deferred>

---

*Phase: 21-funda-o-da-api-autentica-o*
*Context gathered: 2026-06-11*
