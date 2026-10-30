# Phase 32: Divulgações na API de IA - Context

**Gathered:** 2026-10-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Preenche o namespace `/api/v1/ai/*` com acesso a Divulgações (os agendamentos de disparo de WhatsApp criados na Phase 28) — hoje esse namespace só cobre Artes (listar/criar) e resumo de cliente (Phase 24). A IA passa a poder listar, consultar, criar e cancelar Divulgações pela mesma API key `ak_...` que já usa, reusando o model `Divulgacao` e suas validações como estão (nenhuma regra nova).

**No escopo:** `GET /api/v1/ai/divulgacoes` (lista escopada por `client_id` obrigatório, com filtros opcionais de `status` e `from`/`to`), `GET /api/v1/ai/divulgacoes/:id` (uma divulgação, com resumo por grupo), `POST /api/v1/ai/divulgacoes` (agenda uma divulgação real — mesmo efeito do botão "Agendar" do admin, incluindo o job real de disparo), `POST /api/v1/ai/divulgacoes/:id/cancel` (espelha `Divulgacao#cancelar!`), e um endpoint auxiliar `GET /api/v1/ai/clients/:id/whatsapp_groups` pra IA descobrir os ids de grupo antes de criar.

**Fora do escopo:** reenvio por grupo (`resend`, Phase 30 — só no admin). Qualquer rate limit novo (o throttle `api/ai_by_key` da Phase 24 já cobre todo `/api/v1/ai/*` por path prefix). Mudar o model `Divulgacao`/`DivulgacaoGrupo` ou suas validações. Expor o acompanhamento ao vivo (ActionCable) pela API — a IA consulta por polling via GET, não por broadcast.

</domain>

<decisions>
## Implementation Decisions

### Escopo de operações expostas
- **D-01:** Operações expostas: `index`, `show`, `create`, e `cancel` (member action). Sem `update`/`destroy` — mesma tríade de verbos que o resto da API de IA usa, mais o cancel por paralelo direto com o botão do admin.
- **D-02:** `POST` não exige nenhum campo de confirmação extra (`confirm: true` etc.) — mesmo contrato direto que `POST /api/v1/ai/artes` já usa hoje; a responsabilidade de confirmar antes de chamar fica em quem opera a IA (documentar isso explicitamente na descrição do endpoint).
- **D-03:** `GET /api/v1/ai/divulgacoes` exige `client_id` como filtro **obrigatório** (400 se ausente, mesmo padrão de `from`/`to` em Artes#index) — nunca lista cross-client numa chamada só, consistente com o isolamento SEG-01..04 que o resto do sistema trata como invariante.
- **D-04:** `POST /api/v1/ai/divulgacoes/:id/cancel` espelha `Divulgacao#cancelar!` tal como está — idempotente, só efetivamente cancela se o status atual for `agendada`; qualquer outro status é no-op (mesma semântica do admin, retorna 200 com o estado atual em ambos os casos, não 422).

### Contrato de criação (POST)
- **D-05:** Payload exige `client_id` + `arte_id` explícitos (nunca inferir client_id a partir da arte) — mesma convenção explícita que `POST /api/v1/ai/artes` já usa.
- **D-06:** Grupos via `whatsapp_group_ids` (array de ids internos, igual ao formulário do admin). Para a IA descobrir esses ids, esta fase também adiciona `GET /api/v1/ai/clients/:id/whatsapp_groups` — reusa a mesma fonte do admin (`client.whatsapp_instance.whatsapp_groups.where(active: true)`), retornando pelo menos `{ id, remote_jid, display_name }` por grupo.
- **D-07:** `scheduled_for` aceita ISO 8601 com offset explícito (ex. `"2026-11-05T14:00:00-03:00"`) — mais seguro para um agente de IA que pode estar rodando num timezone diferente do America/Sao_Paulo fixo do app; `Time.zone.parse`/cast do Rails já normaliza isso para o fuso correto ao persistir.
- **D-08:** Nenhuma validação nova — reusa `Divulgacao.new(...).save` (ou `save!` + `rescue_from ActiveRecord::RecordInvalid` herdado do `Api::V1::BaseController`) com as mesmas 7 validações de `on: :create` já existentes (arte aprovada, mesmo cliente, sem link externo, teto de 16MB, ao menos um grupo, scheduled_for presente e no futuro). Erros chegam em `errors[:base]` e devem ser mapeados para o formato `{code: "validation_error", detail, field}` já usado pelo resto da API de IA — igual ao `unprocessable_entity` do `Api::V1::BaseController`, que hoje assume `exception.record.errors.map` com `field: e.attribute` (`:base` nesse caso, igual já acontece para qualquer erro de model que caia em `errors[:base]`).
- **D-09:** Resolução de `arte_id`/`client_id`/`whatsapp_group_ids` segue o MESMO padrão de segurança do controller admin (`@client.artes.find(...)`, grupos escopados por `client.whatsapp_instance.whatsapp_groups.where(active: true).find(...)`) — nunca um `Arte.find`/`WhatsappGroup.find` cru. Um id forasteiro cai em `ActiveRecord::RecordNotFound` → 404 estruturado (já herdado do `Api::V1::BaseController`), nunca revela a quem pertence.

### Contrato de leitura e serialização
- **D-10:** Serializer de Divulgação (`Api::V1::Ai::DivulgacaoSerializer`) expõe: `id, client_id, arte_id, status, scheduled_for, created_at, updated_at` + `grupos: [{ group_name, remote_jid, status, sent_at, error_code }]` — a IA precisa ver o progresso por grupo pra decidir se vale cancelar/reenviar (reenviar fica fora do escopo da API, mas saber o estado não).
- **D-11:** `index` filtra opcionalmente por `status` (`agendada|em_andamento|concluida|cancelada` — os 4 valores do enum do model).
- **D-12:** `index` filtra opcionalmente por `from`/`to` (ISO `YYYY-MM-DD`) sobre `scheduled_for` — OPCIONAL, não obrigatório como em Artes#index, porque `client_id` já é obrigatório aqui e reduz o volume por chamada.
- **D-13:** Paginação Pagy padrão (25/100), reusando `pagination_meta`/`per_page_param` já existentes em `Api::V1::Ai::BaseController`.

### Claude's Discretion
- Nome exato da classe do serializer e se o endpoint auxiliar de grupos (`GET /api/v1/ai/clients/:id/whatsapp_groups`) vai num controller novo (`Api::V1::Ai::WhatsappGroupsController`) ou como uma action extra dentro do `ClientsController` existente — pesquisa/planejamento decide pelo que ficar mais consistente com o resto do namespace.
- Ordenação default do `index` de divulgações (sugestão: `scheduled_for: :asc`, espelhando Artes#index da IA — mas o admin usa `:desc`; dado que a IA tipicamente quer "o que vem a seguir", `:asc` parece mais natural, porém fica a critério do planejamento confirmar contra o padrão already estabelecido).
- Se o campo de erro de "divulgação não encontrada" no `cancel` deve distinguir "não existe" de "já estava em outro status" — D-04 já resolve isso como no-op idempotente (sempre 200), então não há ambiguidade real aqui.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Padrão da API de IA (Phase 24 — base obrigatória, replicar estilo)
- `app/controllers/api/v1/ai/base_controller.rb` — `authenticate_ai_key!`, `render_envelope`/`render_error` (herdado via `Api::V1::BaseController`), `pagination_meta`, `per_page_param`.
- `app/controllers/api/v1/ai/artes_controller.rb` — padrão direto de `index`/`create` a espelhar (parse de datas com `rescue Date::Error`, `arte_params` com `.permit` flat, `render_envelope`/`render_error`).
- `app/controllers/api/v1/ai/clients_controller.rb` — padrão de `summary`/member action, `Client.find(params[:id])` deixando `RecordNotFound` subir pro `rescue_from` herdado.
- `app/serializers/api/v1/ai/arte_serializer.rb` — módulo PORO com `.serialize`/`.serialize_collection` — mesmo padrão pro `DivulgacaoSerializer` novo.
- `config/initializers/rack_attack.rb` — throttle `"api/ai_by_key"` já cobre QUALQUER path sob `/api/v1/ai/` (por prefixo, `req.path.start_with?("/api/v1/ai/")`) — nenhum throttle novo necessário nesta fase.

### Model e controller de Divulgação (Phase 28 — reusar como está, não modificar)
- `app/models/divulgacao.rb` — `belongs_to :client`/`:arte`, `has_many :divulgacao_grupos`, enum `status`, as 7 validações `on: :create`, `#cancelar!`.
- `app/models/divulgacao_grupo.rb` — `belongs_to :whatsapp_group`, enum `status` (`pendente/enviado/falhou/incerto`), campos `group_name`/`remote_jid`/`sent_at`/`error_code`/`evolution_message_id`.
- `app/controllers/admin/divulgacoes_controller.rb` — `#create` é a referência EXATA de como resolver `arte`/`whatsapp_group_ids` escopados por cliente (`@client.artes.find`, `scoped_active_groups.find`) e como disparar `Divulgacoes::DispatchJob.set(wait_until: scheduled_for).perform_later(@divulgacao)` após salvar — a API de IA precisa enfileirar o MESMO job, não reimplementar o disparo.
- `app/models/whatsapp_group.rb` — `#display_name`, `belongs_to :whatsapp_instance` — fonte do endpoint auxiliar de grupos (D-06).

### Requisitos e roadmap
- `.planning/ROADMAP.md` §Phase 32 — fase aditiva do milestone v1.7, sem REQ-ID novo (mesmo padrão da Phase 31).
- `.planning/phases/28-divulga-o-agendar-sem-enviar/28-CONTEXT.md` e `.planning/phases/24-endpoints-ia-rate-limiting/24-CONTEXT.md` — contexto completo das duas fases que esta combina.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Api::V1::Ai::BaseController` — auth, envelope, paginação já prontos, herdar direto.
- `Divulgacoes::DispatchJob` (Phase 29) — o job real de disparo; a API de IA só precisa agendá-lo (`.set(wait_until:).perform_later`), igual ao admin.
- `admin/divulgacoes_controller.rb#create` — lógica de resolução/scoping a portar quase 1:1 pro controller novo da IA (troca só a camada de apresentação: JSON em vez de redirect/render).

### Established Patterns
- Serializer PORO por namespace (`Api::V1::Ai::*Serializer`), nunca reusar serializer do admin diretamente (consumidores diferentes, campos podem divergir — Phase 24 já estabeleceu isso).
- Resolução de recursos SEMPRE escopada pela associação do cliente (`@client.algo.find`), nunca `Model.find` cru — invariante de segurança repetido em toda fase desde a 21.
- Erros de validação do model caem em `errors[:base]` neste domínio (Divulgacao) — o `unprocessable_entity` do `Api::V1::BaseController` já mapeia isso para `field: "base"` automaticamente, sem código novo.

### Integration Points
- `config/routes.rb` namespace `:ai` — adicionar `resources :divulgacoes, only: [:index, :show, :create] do post :cancel, on: :member end` + o endpoint auxiliar de grupos (rota exata a critério do planejamento, D-Claude's-Discretion acima).
- Nenhuma mudança em `config/initializers/rack_attack.rb` (D-throttle já cobre por prefixo de path).

</code_context>

<specifics>
## Specific Ideas

- `GET /api/v1/ai/divulgacoes?client_id=2&status=agendada&from=2026-11-01&to=2026-11-30` — client_id obrigatório, status e from/to opcionais.
- `POST /api/v1/ai/divulgacoes` — `{ client_id, arte_id, whatsapp_group_ids: [...], scheduled_for: "2026-11-05T14:00:00-03:00" }`, agenda de verdade (mesmo job real da Phase 29).
- `POST /api/v1/ai/divulgacoes/:id/cancel` — idempotente, 200 sempre, só muda estado se `agendada`.
- `GET /api/v1/ai/clients/:id/whatsapp_groups` — endpoint auxiliar pra IA descobrir ids de grupo antes de criar.

</specifics>

<deferred>
## Deferred Ideas

- **Reenvio por grupo (`resend`) pela API** — descartado por ora; é uma operação de recuperação manual (Phase 30) que normalmente envolve julgamento humano sobre por que falhou. Reconsiderar se houver demanda de automação de retry.
- **Acompanhamento ao vivo (ActionCable) exposto pela API** — descartado; a IA consulta por polling via GET, não por broadcast. Reconsiderar só se latência de polling virar problema real.
- **Campo `confirm: true` como salvaguarda no POST** — descartado (D-02); se no futuro houver um incidente de agendamento acidental por IA, reconsiderar adicionar essa salvaguarda retroativamente.

</deferred>

---

*Phase: 32-divulga-es-na-api-de-ia*
*Context gathered: 2026-10-30*
