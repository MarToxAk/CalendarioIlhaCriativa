# Phase 32: Divulgações na API de IA - Research

**Researched:** 2026-11-07
**Domain:** Rails 8.1 JSON API (namespace `/api/v1/ai/*`) expondo o model `Divulgacao` (agendamento de disparo WhatsApp via Evolution)
**Confidence:** HIGH (fase aditiva, 100% código in-repo lido nesta sessão; nenhum pacote novo)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Operações expostas: `index`, `show`, `create`, e `cancel` (member action). Sem `update`/`destroy` — mesma tríade de verbos que o resto da API de IA usa, mais o cancel por paralelo direto com o botão do admin.
- **D-02:** `POST` não exige nenhum campo de confirmação extra (`confirm: true` etc.) — mesmo contrato direto que `POST /api/v1/ai/artes` já usa hoje; a responsabilidade de confirmar antes de chamar fica em quem opera a IA (documentar isso explicitamente na descrição do endpoint).
- **D-03:** `GET /api/v1/ai/divulgacoes` exige `client_id` como filtro **obrigatório** (400 se ausente, mesmo padrão de `from`/`to` em Artes#index) — nunca lista cross-client numa chamada só, consistente com o isolamento SEG-01..04 que o resto do sistema trata como invariante.
- **D-04:** `POST /api/v1/ai/divulgacoes/:id/cancel` espelha `Divulgacao#cancelar!` tal como está — idempotente, só efetivamente cancela se o status atual for `agendada`; qualquer outro status é no-op (mesma semântica do admin, retorna 200 com o estado atual em ambos os casos, não 422).
- **D-05:** Payload exige `client_id` + `arte_id` explícitos (nunca inferir client_id a partir da arte) — mesma convenção explícita que `POST /api/v1/ai/artes` já usa.
- **D-06:** Grupos via `whatsapp_group_ids` (array de ids internos, igual ao formulário do admin). Para a IA descobrir esses ids, esta fase também adiciona `GET /api/v1/ai/clients/:id/whatsapp_groups` — reusa a mesma fonte do admin (`client.whatsapp_instance.whatsapp_groups.where(active: true)`), retornando pelo menos `{ id, remote_jid, display_name }` por grupo.
- **D-07:** `scheduled_for` aceita ISO 8601 com offset explícito (ex. `"2026-11-05T14:00:00-03:00"`) — mais seguro para um agente de IA que pode estar rodando num timezone diferente do America/Sao_Paulo fixo do app; `Time.zone.parse`/cast do Rails já normaliza isso para o fuso correto ao persistir.
- **D-08:** Nenhuma validação nova — reusa `Divulgacao.new(...).save` (ou `save!` + `rescue_from ActiveRecord::RecordInvalid` herdado do `Api::V1::BaseController`) com as mesmas 7 validações de `on: :create` já existentes (arte aprovada, mesmo cliente, sem link externo, teto de 16MB, ao menos um grupo, scheduled_for presente e no futuro). Erros chegam em `errors[:base]` e devem ser mapeados para o formato `{code: "validation_error", detail, field}` já usado pelo resto da API de IA — igual ao `unprocessable_entity` do `Api::V1::BaseController`, que hoje assume `exception.record.errors.map` com `field: e.attribute` (`:base` nesse caso).
- **D-09:** Resolução de `arte_id`/`client_id`/`whatsapp_group_ids` segue o MESMO padrão de segurança do controller admin (`@client.artes.find(...)`, grupos escopados por `client.whatsapp_instance.whatsapp_groups.where(active: true).find(...)`) — nunca um `Arte.find`/`WhatsappGroup.find` cru. Um id forasteiro cai em `ActiveRecord::RecordNotFound` → 404 estruturado (já herdado do `Api::V1::BaseController`), nunca revela a quem pertence.
- **D-10:** Serializer de Divulgação (`Api::V1::Ai::DivulgacaoSerializer`) expõe: `id, client_id, arte_id, status, scheduled_for, created_at, updated_at` + `grupos: [{ group_name, remote_jid, status, sent_at, error_code }]`.
- **D-11:** `index` filtra opcionalmente por `status` (`agendada|em_andamento|concluida|cancelada` — os 4 valores do enum do model).
- **D-12:** `index` filtra opcionalmente por `from`/`to` (ISO `YYYY-MM-DD`) sobre `scheduled_for` — OPCIONAL, não obrigatório como em Artes#index, porque `client_id` já é obrigatório aqui e reduz o volume por chamada.
- **D-13:** Paginação Pagy padrão (25/100), reusando `pagination_meta`/`per_page_param` já existentes em `Api::V1::Ai::BaseController`.

### Claude's Discretion

- Nome exato da classe do serializer e se o endpoint auxiliar de grupos (`GET /api/v1/ai/clients/:id/whatsapp_groups`) vai num controller novo (`Api::V1::Ai::WhatsappGroupsController`) ou como uma action extra dentro do `ClientsController` existente — pesquisa/planejamento decide pelo que ficar mais consistente com o resto do namespace.
- Ordenação default do `index` de divulgações (sugestão: `scheduled_for: :asc`, espelhando Artes#index da IA — mas o admin usa `:desc`; dado que a IA tipicamente quer "o que vem a seguir", `:asc` parece mais natural, porém fica a critério do planejamento confirmar contra o padrão already estabelecido).
- Se o campo de erro de "divulgação não encontrada" no `cancel` deve distinguir "não existe" de "já estava em outro status" — D-04 já resolve isso como no-op idempotente (sempre 200), então não há ambiguidade real aqui.

### Deferred Ideas (OUT OF SCOPE)

- **Reenvio por grupo (`resend`) pela API** — descartado por ora (Phase 30 só no admin).
- **Acompanhamento ao vivo (ActionCable) exposto pela API** — descartado; a IA consulta por polling via GET.
- **Campo `confirm: true` como salvaguarda no POST** — descartado (D-02).
- Também fora de escopo (do `<domain>`): qualquer rate limit novo; qualquer mudança no model `Divulgacao`/`DivulgacaoGrupo` ou nas validações.
</user_constraints>

<phase_requirements>
## Phase Requirements

Fase aditiva do milestone v1.7 — **sem REQ-ID novo** (`ROADMAP.md` §Phase 32: "Requirements: TBD"; CONTEXT: "sem REQ-ID novo, mesmo padrão da Phase 31"). O planner deve mapear os planos às decisões D-01..D-13, não a REQ-IDs.

| ID | Description | Research Support |
|----|-------------|------------------|
| D-01..D-13 | Decisões travadas do 32-CONTEXT.md | Seções "Architecture Patterns", "Code Examples" e "Common Pitfalls" abaixo |
</phase_requirements>

## Summary

A fase é uma camada fina de apresentação sobre código já existente: o model `Divulgacao` (7 validações `on: :create` + `#cancelar!`), o job `Divulgacoes::DispatchJob` e o padrão de resolução escopada do `Admin::DivulgacoesController#create`. O namespace `ai` (Phase 24) já fornece auth por `ak_` key, envelope `{data, meta, errors}`, paginação Pagy 9.4 e throttle por prefixo de path. Nenhum pacote novo, nenhuma migração, nenhuma mudança de model, nenhuma mudança no `rack_attack.rb`.

Entregáveis: (1) `Api::V1::Ai::DivulgacoesController` (`index/show/create/cancel`), (2) `Api::V1::Ai::DivulgacaoSerializer` (PORO módulo, mesmo estilo do `ArteSerializer`), (3) action `whatsapp_groups` em `Api::V1::Ai::ClientsController` (+ serializer PORO opcional de grupo), (4) rotas em `config/routes.rb`, (5) testes de integração espelhando `artes_controller_test.rb` + um teste cross-client mutation-sensitive pro caminho da API. A suíte **não roda neste ambiente** (banco de teste pertence a outro usuário do SO) — verificação é por inspeção + `rubocop`/`brakeman`/`rails routes`/`rails runner`, todos confirmados funcionais aqui.

Os três pontos onde a implementação "óbvia" falha silenciosamente (verificados empiricamente): (a) `where(status: "bogus")` vira `status IS NULL` (lista vazia 200, sem erro) — validar o enum explicitamente; (b) `where(scheduled_for: Date..Date)` gera `BETWEEN '2026-11-01' AND '2026-11-30'` e **exclui o último dia inteiro** — converter para `in_time_zone.beginning_of_day..end_of_day`; (c) `scheduled_for` lixo vira `nil` sem exceção e cai na mensagem "Informe a data e hora do envio." (422, field `base`) — comportamento aceitável, mas deve ser coberto por teste.

**Primary recommendation:** Copiar quase 1:1 a resolução do `Admin::DivulgacoesController#create` para um `Api::V1::Ai::DivulgacoesController` novo, trocando redirect/render por `render_envelope`/`save!`; adicionar `whatsapp_groups` como member action no `ClientsController` existente; validar `status`/`from`/`to` explicitamente (400) antes de montar a query.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Autenticação `ak_` + throttle | API / Backend (`Api::V1::Ai::BaseController`, Rack::Attack) | — | Já pronto; herdar. Throttle cobre por prefixo de path |
| Resolução escopada client→arte→grupos | API / Backend (controller) | Database (FK/scope por associação) | Invariante de segurança SEG-01/02: `.find` pela associação do cliente |
| Regras de negócio do agendamento | API / Backend (model `Divulgacao`) | — | Nenhuma regra nova; controller só chama `save!` |
| Disparo real (job com `wait_until`) | API / Backend (ActiveJob/Solid Queue) | Database (fila `queue` Solid Queue) | Controller só enfileira `Divulgacoes::DispatchJob`; execução é da Phase 29 |
| Serialização JSON | API / Backend (serializer PORO) | — | Serializer próprio do namespace AI, nunca o do admin |
| Descoberta de grupos | API / Backend (`ClientsController#whatsapp_groups`) | Database (`whatsapp_groups` cache local) | Lê só o cache local; nunca fala com a Evolution |
| Progresso ao vivo | — (fora de escopo) | — | IA faz polling via GET `show` |

## Standard Stack

### Core

Nenhuma dependência nova. Tudo já está no `Gemfile.lock`:

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rails | 8.1.3.1 | Framework | [VERIFIED: Gemfile.lock:291 `rails (8.1.3.1)`] |
| pagy | 9.4.0 | Paginação (`pagy(scope, limit:)`, `pagy.limit/.page/.count/.pages`) | [VERIFIED: Gemfile.lock:253 `pagy (9.4.0)`]; já usado em `Api::V1::Ai::BaseController` |
| solid_queue | já configurado | Backend do `DispatchJob` | [VERIFIED: config/environments/production.rb:56-57 `config.active_job.queue_adapter = :solid_queue` / `config.solid_queue.connects_to = { database: { writing: :queue } }`] |
| rack-attack | já configurado | Throttle `api/ai_by_key` | [VERIFIED: config/initializers/rack_attack.rb] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Action `whatsapp_groups` em `ClientsController` | `Api::V1::Ai::WhatsappGroupsController` aninhado | Controller novo = rota aninhada + namespace extra para 1 action de leitura; o `ClientsController` já é o dono de member actions por cliente (`summary`). **Recomendado: member action no `ClientsController`** |
| Duplicar ~10 linhas de build de grupos do admin | Extrair um service `Divulgacoes::Scheduler` compartilhado | Extrair exigiria tocar o `Admin::DivulgacoesController` (CONTEXT: "reusar como está, não modificar"). **Recomendado: duplicar** (blast radius mínimo); extração fica como refator futuro |

**Installation:** nenhuma.

## Package Legitimacy Audit

Esta fase não instala nenhum pacote externo. Auditoria não aplicável.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
 IA (Bearer ak_...) ──HTTPS──> Rack::Attack (api/ai_by_key 60/min, por prefixo /api/v1/ai/)
                                   │
                                   v
                     Api::V1::Ai::BaseController
                     (authenticate_ai_key!, envelope, pagy helpers)
                                   │
        ┌──────────────┬───────────┼────────────────┬─────────────────────────┐
        v              v           v                v                         v
  GET divulgacoes  GET divulgacoes/:id  POST divulgacoes     POST divulgacoes/:id/cancel   GET clients/:id/whatsapp_groups
  (client_id obrig.)                    (client_id,arte_id,
   valida status/from/to                 whatsapp_group_ids,
        │              │                 scheduled_for ISO8601)        │                         │
        │              │                       │                       │                         │
  Client.find ──> client.divulgacoes     Client.find                   Divulgacao.find          Client.find
  .includes(grupos)  Divulgacao.find     ├─ client.artes.find(arte_id)  └─ #cancelar!            └─ whatsapp_instance&.whatsapp_groups
  .where(status/período)  .includes      ├─ scoped_active_groups              (no-op se != agendada)     .where(active: true) (ou .none)
  .order(asc,id)          (grupos)       │   .find(gids)                      │                          │
  pagy(limit)                            ├─ Divulgacao.new + build grupos     │                          │
        │                                ├─ save!  ──(RecordInvalid)──> 422   │                          │
        │                                │   (7 validações do model)          │                          │
        │                                └─ DispatchJob.set(wait_until:)      │                          │
        │                                      .perform_later  ──> Solid Queue│                          │
        v                                      v                             v                          v
   DivulgacaoSerializer.serialize_collection / .serialize          (200 sempre, estado atual)   pagy + {id,remote_jid,display_name}
        │                                      │                             │                          │
        └───────────────> render_envelope({data, meta, errors:[]}) <─────────┴──────────────────────────┘

 RecordNotFound -> 404 not_found | ParameterMissing -> 400 bad_request | RecordInvalid -> 422 validation_error (herdados de Api::V1::BaseController)
```

### Recommended Project Structure

```
app/controllers/api/v1/ai/
├── base_controller.rb          # existente (herdar)
├── artes_controller.rb         # existente (padrão a espelhar)
├── clients_controller.rb       # + action whatsapp_groups
└── divulgacoes_controller.rb   # NOVO (index/show/create/cancel)
app/serializers/api/v1/ai/
├── arte_serializer.rb          # existente
├── divulgacao_serializer.rb    # NOVO (módulo PORO .serialize/.serialize_collection)
└── whatsapp_group_serializer.rb# NOVO, opcional (módulo PORO, 3 campos)
config/routes.rb                # namespace :ai (linha ~74)
test/controllers/api/v1/ai/
├── divulgacoes_controller_test.rb   # NOVO
└── clients_controller_test.rb       # + testes de whatsapp_groups
test/integration/cross_client_isolation_test.rb   # + teste do caminho API (opcional, recomendado)
```

### Pattern 1: Rotas

Estado atual [VERIFIED: config/routes.rb:74-79]:

```ruby
      namespace :ai do
        resources :artes, only: [ :index, :create ]
        resources :clients, only: [] do
          get :summary, on: :member
        end
      end
```

Alvo (o namespace `api` já tem `defaults: { format: :json }` — [VERIFIED: config/routes.rb:`namespace :api, defaults: { format: :json } do`]; `bin/rails routes` confirma `{:format=>:json}` nas rotas AI existentes):

```ruby
      namespace :ai do
        resources :artes, only: [ :index, :create ]
        resources :divulgacoes, only: [ :index, :show, :create ] do
          post :cancel, on: :member
        end
        resources :clients, only: [] do
          get :summary, on: :member
          get :whatsapp_groups, on: :member
        end
      end
```

`resources :divulgacoes` resolve para o controller `api/v1/ai/divulgacoes` — a inflexão irregular de `divulgacao/divulgacoes` já existe (o model usa `self.table_name = "divulgacoes"` "alem da inflexao irregular em config/initializers/inflections.rb") e as rotas admin já usam `resources :divulgacoes`. [VERIFIED: app/models/divulgacao.rb:2-3; config/routes.rb:27]. Nomes de helper gerados: `cancel_api_v1_ai_divulgacao`, `whatsapp_groups_api_v1_ai_client` (confirmar com `bin/rails routes -g divulgacoes`).

### Pattern 2: Controller `DivulgacoesController`

**What:** herda `Api::V1::Ai::BaseController`; usa `save!` (→ `RecordInvalid` → 422 herdado); filtros validados explicitamente.

```ruby
# frozen_string_literal: true

class Api::V1::Ai::DivulgacoesController < Api::V1::Ai::BaseController
  # 400 estruturado para filtros inválidos (status/from/to) — mesmo code "bad_request" do Artes#index.
  class InvalidFilter < StandardError; end
  rescue_from InvalidFilter do |e|
    render_error(code: "bad_request", detail: e.message, status: :bad_request)
  end

  def index
    # D-03: client_id obrigatório -> ParameterMissing -> 400 (herdado). permit antes de require
    # descarta formatos Hash/Array (viram ausência -> 400, nunca 500).
    client = Client.find(params.permit(:client_id).require(:client_id))

    scope = client.divulgacoes.includes(:divulgacao_grupos).order(scheduled_for: :asc, id: :asc)
    scope = scope.where(status: status_filter) if params[:status].present?   # D-11
    scope = scope.where(scheduled_for: period_range) if params[:from].present? || params[:to].present?  # D-12

    @pagy, @divulgacoes = pagy(scope, limit: per_page_param)                  # D-13
    render_envelope(
      data: Api::V1::Ai::DivulgacaoSerializer.serialize_collection(@divulgacoes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def show
    divulgacao = Divulgacao.includes(:divulgacao_grupos).find(params[:id])
    render_envelope(data: Api::V1::Ai::DivulgacaoSerializer.serialize(divulgacao))
  end

  def create
    p      = create_params
    client = Client.find(p.require(:client_id))               # D-05
    arte   = client.artes.find(p.require(:arte_id))           # D-09 (escopado)
    gids   = Array(p[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
    groups = scoped_active_groups(client).find(gids)          # D-09 (escopado, só ativos)

    divulgacao = client.divulgacoes.new(arte: arte, scheduled_for: p[:scheduled_for])  # D-07: cast do Rails
    groups.each do |g|
      divulgacao.divulgacao_grupos.build(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid)
    end

    divulgacao.save!                                           # D-08 -> RecordInvalid -> 422
    # MESMO job real do admin (ENVIO-01): wait_until, nunca scan periódico.
    Divulgacoes::DispatchJob.set(wait_until: divulgacao.scheduled_for).perform_later(divulgacao)
    render_envelope(data: Api::V1::Ai::DivulgacaoSerializer.serialize(divulgacao), status: :created)
  end

  def cancel
    divulgacao = Divulgacao.includes(:divulgacao_grupos).find(params[:id])
    divulgacao.cancelar!                                       # D-04: idempotente; 200 em ambos os casos
    render_envelope(data: Api::V1::Ai::DivulgacaoSerializer.serialize(divulgacao))
  end

  private

  def create_params
    params.permit(:client_id, :arte_id, :scheduled_for, whatsapp_group_ids: [])
  end

  # Mesma fonte do admin (scoped_active_groups) — nunca WhatsappGroup.find cru.
  def scoped_active_groups(client)
    client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
  end

  def status_filter
    value = params[:status]
    return value if Divulgacao.statuses.key?(value)
    raise InvalidFilter, "Status inválido. Use: #{Divulgacao.statuses.keys.join(', ')}."
  end

  # `where(scheduled_for: Date..Date)` EXCLUI o último dia (gera BETWEEN '2026-11-01' AND '2026-11-30').
  # Converter para limites de dia no fuso do app. Range aberto (nil) é suportado pelo Rails.
  def period_range
    from = parse_date(:from)
    to   = parse_date(:to)
    raise InvalidFilter, "O parâmetro 'from' deve ser anterior ou igual a 'to'." if from && to && from > to
    from&.in_time_zone&.beginning_of_day..to&.in_time_zone&.end_of_day
  end

  def parse_date(key)
    return nil if params[key].blank?
    Date.iso8601(params[key].to_s)
  rescue Date::Error
    raise InvalidFilter, "Formato de data inválido. Use YYYY-MM-DD."
  end
end
```

`Divulgacao.statuses` e `enum :status` [VERIFIED: app/models/divulgacao.rb:`enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status`]. O endpoint de grupos e o `Admin::DivulgacoesController#create` [VERIFIED: app/controllers/admin/divulgacoes_controller.rb: `arte   = @client.artes.find(divulgacao_params[:arte_id])`, `groups = scoped_active_groups.find(gids)`, `Divulgacoes::DispatchJob.set(wait_until: @divulgacao.scheduled_for).perform_later(@divulgacao)`, `@client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none`].

> Nota ao planner: o trecho acima é um esqueleto de referência verificado contra os arquivos lidos; ajustar estilo (rubocop omakase) e comentários em pt-BR conforme o resto do namespace. `Rails.application.config.action_controller.action_on_unpermitted_parameters` é `nil` [VERIFIED: rails runner nesta sessão] → chaves extras (inclusive o hash `divulgaco` criado pelo `ParamsWrapper` do JSON) são ignoradas silenciosamente, não levantam.

### Pattern 3: Serializer (D-10)

```ruby
# frozen_string_literal: true

module Api::V1::Ai::DivulgacaoSerializer
  def self.serialize(divulgacao)
    {
      id:            divulgacao.id,
      client_id:     divulgacao.client_id,
      arte_id:       divulgacao.arte_id,
      status:        divulgacao.status,          # rótulo do enum ("agendada"), não o inteiro
      scheduled_for: divulgacao.scheduled_for,   # TimeWithZone -> "2026-11-05T14:00:00.000-03:00"
      created_at:    divulgacao.created_at,
      updated_at:    divulgacao.updated_at,
      grupos:        divulgacao.divulgacao_grupos.sort_by(&:id).map { |g| serialize_grupo(g) }
    }
  end

  def self.serialize_collection(divulgacoes)
    divulgacoes.map { |d| serialize(d) }
  end

  private_class_method def self.serialize_grupo(g)
    { group_name: g.group_name, remote_jid: g.remote_jid, status: g.status, sent_at: g.sent_at, error_code: g.error_code }
  end
end
```

- **Sem N+1:** usar `divulgacao.divulgacao_grupos` (já pré-carregado por `includes`) e ordenar em Ruby (`sort_by(&:id)`) — um `.order(...)` dentro do serializer dispararia 1 query por divulgação. Em `create`, os grupos já estão em memória (recém-construídos).
- **Formato do timestamp:** `Divulgacao.new(scheduled_for: "2026-11-05T14:00:00-03:00").scheduled_for.as_json` → `"2026-11-05T14:00:00.000-03:00"` [VERIFIED: rails runner nesta sessão]. A IA recebe de volta ISO 8601 com offset `-03:00`.
- **Enums de grupo:** `DivulgacaoGrupo` status `{ pendente: 0, enviado: 1, falhou: 2, incerto: 3 }` [VERIFIED: app/models/divulgacao_grupo.rb: `enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }`].
- **NÃO expor** `evolution_message_id` (não está em D-10) nem `whatsapp_group_id`. `error_code` já é sanitizado pelo job (URLs presignadas redigidas) [VERIFIED: app/jobs/whatsapp/send_to_group_job.rb `sanitize_error_code` → `.gsub(URL_IN_TEXT, "[url-redigida]")`…`.first(ERROR_CODE_MAX_LENGTH)`], logo é seguro devolver.
- Colunas de `divulgacoes`: `arte_id, client_id, created_at, scheduled_for, status, updated_at` [VERIFIED: db/schema.rb `create_table "divulgacoes"`]; de `divulgacao_grupos`: `error_code, evolution_message_id, group_name, remote_jid, sent_at, status, whatsapp_group_id…` [VERIFIED: db/schema.rb `create_table "divulgacao_grupos"`].

### Pattern 4: Endpoint de grupos (D-06) — action em `ClientsController`

```ruby
  def whatsapp_groups
    client = Client.find(params[:id])   # RecordNotFound -> 404 herdado (igual a #summary)

    groups = client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
    groups = groups.order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid)   # mesma ordenação do admin

    @pagy, @groups = pagy(groups, limit: per_page_param)
    render_envelope(
      data: @groups.map { |g| { id: g.id, remote_jid: g.remote_jid, display_name: g.display_name } },
      meta: { pagination: pagination_meta(@pagy) }
    )
  end
```

- Mesma fonte e ordenação do admin [VERIFIED: app/controllers/admin/whatsapp_groups_controller.rb: `@instance.whatsapp_groups.where(active: true).order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid)`]. `Arel.sql` é necessário para `NULLS LAST` (o `order` do Rails rejeita SQL cru sem ele).
- `display_name` = `subject.presence || "Grupo sem nome (#{remote_jid.to_s.first(12)}…)"` [VERIFIED: app/models/whatsapp_group.rb].
- Cliente sem instância → lista vazia 200 (não 404): a IA entende "sem grupos" e o `create` correspondente falharia em 422 "Selecione ao menos um grupo". Instância desvinculada (`unpaired`) tem os grupos soft-desativados pela quick task 260831-o9t [CITED: .planning/STATE.md, Quick Tasks], portanto também retorna vazia.
- Grupos podem ser centenas → paginar (consistente com D-13 e com o admin). Teto `per_page` = 100 → a IA pode precisar de várias páginas; o throttle de 60/min comporta.
- Serializer PORO opcional `Api::V1::Ai::WhatsappGroupSerializer` (3 campos) mantém o padrão "serializer por namespace"; inline em hash também é aceitável (o `#summary` monta o hash inline).
- Phase 31 (instância compartilhada): cada cliente tem sua PRÓPRIA linha `WhatsappInstance` e seus próprios `whatsapp_groups` (a conexão física é compartilhada via `instance_name`, mas as linhas e grupos são por cliente) [VERIFIED: app/models/whatsapp_instance.rb: "N linhas podem apontar para a MESMA conexão física (mesmo instance_name/token), uma por cliente que a compartilha" ; app/models/client.rb `has_one :whatsapp_instance`]. A mesma expressão do admin continua correta e isolada por cliente.

### Anti-Patterns to Avoid

- **`Arte.find` / `WhatsappGroup.find` / `Divulgacao.where(client_id: …)` cru no create:** quebra SEG-01/02 (D-09). Sempre pela associação do cliente.
- **Inferir `client_id` da arte:** proibido (D-05).
- **Adicionar `rescue_from RecordNotFound` local com mensagem específica** ("arte não pertence ao cliente"): revela existência cross-client (D-09). Deixar o 404 genérico herdado.
- **Reusar `Admin::…` serializer/partial ou view helpers:** consumidores diferentes (Phase 24).
- **Chamar `Whatsapp::SendToGroupJob` direto do controller:** só enfileirar o `DispatchJob` (que faz o fan-out).
- **Modificar `config/initializers/rack_attack.rb`:** o prefixo já cobre (D-throttle).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Envelope/erros JSON | `render json:` manual | `render_envelope` / `render_error` / `rescue_from` herdados | Contrato `{data, meta, errors}` único em toda a API |
| Mapeamento de `errors[:base]` → `{code, detail, field}` | Loop próprio | `unprocessable_entity` do `Api::V1::BaseController` ([VERIFIED: app/controllers/api/v1/base_controller.rb] `{ code: "validation_error", detail: e.full_message, field: e.attribute.to_s }`) | Já gera `field: "base"` para `errors[:base]` |
| Paginação | `limit/offset` manual | `pagy(scope, limit: per_page_param)` + `pagination_meta` | `Pagy::OverflowError` já mapeado para 404 `page_out_of_range` |
| Parse/normalização de timezone de `scheduled_for` | `Time.zone.parse` manual + conversão | Atribuir a string direto ao attribute (`Divulgacao.new(scheduled_for: str)`) | Cast do Rails normaliza offset/`Z` para `Brasilia` [VERIFIED: rails runner: `"2026-11-05T14:00:00-03:00"` e `"2026-11-05T17:00:00Z"` → `2026-11-05 14:00:00 -03:00`] |
| Regras de agendamento | Revalidar arte aprovada/16MB/etc. no controller | As 7 validações do model via `save!` | D-08: nenhuma regra nova; backstop de SEG-02 já no model |
| Disparo | Loop de envio / sleep | `Divulgacoes::DispatchJob.set(wait_until:).perform_later` | Fan-out, jitter e idempotência já são da Phase 29 |
| Cancelamento | `update(status: :cancelada)` direto | `Divulgacao#cancelar!` | Guard `status_agendada?` + broadcast ACOMP-01 |

**Key insight:** esta fase não tem lógica de domínio nova — qualquer linha de regra escrita no controller é duplicação de algo que já vive no model/job e divergirá com o tempo.

## Runtime State Inventory

Não aplicável — fase aditiva (greenfield de endpoints), sem rename/refactor/migração. Nenhum dado armazenado, config de serviço, estado de SO, secret ou artefato de build é renomeado ou migrado.

## Common Pitfalls

### Pitfall 1: Filtro `status` inválido vira lista vazia silenciosa
**What goes wrong:** `GET …?status=bogus` retorna 200 com `data: []`.
**Why it happens:** `Divulgacao.where(status: "bogus").to_sql` → `WHERE "divulgacoes"."status" IS NULL` [VERIFIED: rails runner]. Não levanta.
**How to avoid:** validar contra `Divulgacao.statuses.key?` e responder 400 (`status_filter` acima). Teste: `status=bogus` → 400, `status=agendada` → só agendadas.
**Warning signs:** teste de status inválido passando com 200.

### Pitfall 2: `from..to` de `Date` exclui o último dia
**What goes wrong:** divulgação em `2026-11-30 15:00` não aparece em `to=2026-11-30`.
**Why it happens:** `where(scheduled_for: Date.new(2026,11,1)..Date.new(2026,11,30))` → `BETWEEN '2026-11-01' AND '2026-11-30'` (meia-noite) [VERIFIED: rails runner]. (O `ArtesController` não sofre disso porque `scheduled_on` é coluna `date`.) `scheduled_for` é `datetime` [VERIFIED: db/schema.rb `t.datetime "scheduled_for", null: false`].
**How to avoid:** `from.in_time_zone.beginning_of_day..to.in_time_zone.end_of_day` → `BETWEEN '2026-11-01 00:00:00' AND '2026-11-30 23:59:59.999999'`; com só um extremo, range endless/beginless (`>=`/`<=`) [VERIFIED: rails runner]. App usa `config.active_record.default_timezone = :local` + `config.time_zone = "Brasilia"` com TZ fixo (INFRA-03) [VERIFIED: config/application.rb:24-25], então os limites ficam no fuso certo. Teste de fronteira: divulgação às 23:30 do dia `to` deve aparecer.

### Pitfall 3: `scheduled_for` malformado não levanta — vira `nil`
**What goes wrong:** `scheduled_for: "lixo"` não dá 400; dá 422 com "Informe a data e hora do envio." (`field: "base"`).
**Why it happens:** cast datetime do Rails devolve `nil` para string não parseável [VERIFIED: rails runner: `Divulgacao.new(scheduled_for: "lixo").scheduled_for` → `nil`]; a validação `scheduled_for_presente` cobre.
**How to avoid:** aceitar como está (D-08: nenhuma validação nova); mensagem é aceitável. Documentar no endpoint e cobrir com teste. Passado → 422 "A data e hora do envio precisam estar no futuro."
**Nota D-07:** o Rails aceita também datas sem offset (interpretadas em `Brasilia`) e com `Z`; não há como "exigir offset" sem validação nova — a exigência é só contratual/documental.

### Pitfall 4: Duplo POST = dupla mensagem em grupos reais
**What goes wrong:** retry da IA após timeout cria 2 divulgações idênticas → cada grupo recebe 2 mensagens.
**Why it happens:** não há chave de idempotência, nem unicidade (arte, cliente, horário) no model; D-02 recusa `confirm: true`; D-08 recusa novas validações.
**How to avoid:** não resolver nesta fase (decisões travadas); **documentar no comentário/descrição do endpoint** que o POST agenda de verdade e não é idempotente — a IA deve consultar `GET index?client_id=…&status=agendada` antes de repetir um POST que deu timeout. Registrar como risco aceito no PLAN (`## Risks`).

### Pitfall 5: `cancelar!` não é atômico contra o `DispatchJob`
**What goes wrong:** cancel chega exatamente quando o job vira `agendada→em_andamento`; o `update(status: :cancelada)` pode sobrescrever `em_andamento` e a divulgação aparece cancelada enquanto envios já foram enfileirados.
**Why it happens:** `cancelar!` checa `status_agendada?` no objeto em memória e faz `update` sem lock [VERIFIED: app/models/divulgacao.rb: `return false unless status_agendada?` / `update(status: :cancelada)`]. Comportamento pré-existente igual no admin.
**How to avoid:** D-04 manda espelhar `cancelar!` "tal como está". Hardening opcional sem tocar o model: `divulgacao.with_lock { divulgacao.cancelar! }` (reload sob lock). Janela é de milissegundos; tratar como discricionário do planner `[ASSUMED: risco baixo]`. Se adotado, o `lock!` faz `reload` e descarta o `includes` — o serializer refaz 1 query de grupos (aceitável em member action).

### Pitfall 6: Resolução forasteira revelando existência
**What goes wrong:** devolver 422 "arte de outro cliente" distingue "existe" de "não existe".
**How to avoid:** `client.artes.find` e `scoped_active_groups.find(gids)` levantam `RecordNotFound` → 404 genérico `not_found` ("Recurso não encontrado"). Um grupo `active: false` do próprio cliente também dá 404 (igual ao admin). Teste: arte de B com client_id de A → 404; grupo de B → 404; grupo inativo de A → 404; **zero linhas gravadas** (`assert_no_difference`) e **zero jobs enfileirados**.

### Pitfall 7: Params malformados
**What goes wrong:** `whatsapp_group_ids` como Hash/string, `arte_id` como Array → 500.
**How to avoid:** `params.permit(..., whatsapp_group_ids: [])` descarta formatos errados (mesmo racional do WR-02/CR-02 do admin [VERIFIED: comentário em admin/divulgacoes_controller.rb `divulgacao_params`]); `Array(nil).map(&:to_i)` → `[]`; `find([])` → `[]` → o model responde 422 "Selecione ao menos um grupo para a divulgação." Para `client_id`/`arte_id` ausentes usar `require` → 400. Para `status`/`from`/`to` array/hash: `Divulgacao.statuses.key?(array)` → false → 400; `Date.iso8601(array.to_s)` → `Date::Error` → 400.

### Pitfall 8: N+1 no `index`
**What goes wrong:** serializer chama `divulgacao.divulgacao_grupos` por linha → 1+N queries (25–100 por página).
**How to avoid:** `client.divulgacoes.includes(:divulgacao_grupos)` e nunca `.order`/`.where` na associação dentro do serializer. (Admin faz `includes(:arte, :divulgacao_grupos)`; a API não serializa arte, então só os grupos.)

### Pitfall 9: Rotas/helpers e `show`/`cancel` sem `client_id`
**What goes wrong:** `show` e `cancel` recebem só `:id` (D-01); um `Divulgacao.find` cru é cross-client.
**Contexto:** a API key `ak_` é única e agency-wide (um segredo em `credentials.dig(:api, :ai_key)`/`ENV["AI_API_KEY"]` [VERIFIED: base_controller.rb]); `Artes#index` já lista cross-client quando `client_id` é omitido e `ClientsController#summary` faz `Client.find` cru. O invariante SEG isola clientes entre si no portal/admin, não escopa o operador de IA, que por desenho enxerga a agência inteira. Portanto `Divulgacao.find(params[:id])` é consistente com o namespace e o serializer devolve `client_id`.
**Recomendação:** `Divulgacao.find` para `show`/`cancel` (id inexistente → 404 genérico). Ver Open Question 1.

### Pitfall 10: Callback de broadcast no cancel
`cancelar!` dispara `after_update_commit :broadcast_status` (renderiza partials admin via Turbo/SolidCable) dentro do request da API. É o mesmo caminho do admin e do `DispatchJob`, já funcional em produção; não requer nada de novo, mas uma falha de render/Cable levantaria no after_commit. Sem mitigação necessária; só não mockar/"pular" callbacks nos testes sem motivo.

## Code Examples

### Teste de create (padrão a espelhar)

Setup espelhado de [VERIFIED: test/controllers/admin/divulgacoes_controller_test.rb:12-36] (cliente + instância `connected` + 2 grupos + arte aprovada com `media_file` — **necessário**, pois `arte_nao_usa_link_externo` rejeita arte com `external_url`, e o `ArtesControllerTest` da IA usa só `external_url`) combinado com o cabeçalho de [VERIFIED: test/controllers/api/v1/ai/artes_controller_test.rb:6-22] (`AI_API_KEY`, `ENV["AI_API_KEY"]`, `Rack::Attack.cache.store.clear`, headers `Authorization`/`Content-Type: application/json`):

```ruby
# frozen_string_literal: true
require "test_helper"

class Api::V1::Ai::DivulgacoesControllerTest < ActionDispatch::IntegrationTest
  AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

  setup do
    @original_ai_key = ENV["AI_API_KEY"]; ENV["AI_API_KEY"] = AI_API_KEY
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    @auth_headers = { "Authorization" => "Bearer #{AI_API_KEY}", "Content-Type" => "application/json" }

    @client   = Client.create!(name: "AI Divulgacoes", password: "SenhaIA123!", active: true)
    @instance = @client.create_whatsapp_instance!(instance_name: WhatsappInstance.evolution_name_for(@client),
                                                  connection_state: :connected, groups_synced_at: Time.current)
    @g1 = @instance.whatsapp_groups.create!(remote_jid: "g1@g.us", subject: "Grupo Um", active: true, synced_at: Time.current)
    @arte = @client.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte")
    @arte.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    @arte.save!
  end
  teardown { ENV["AI_API_KEY"] = @original_ai_key }

  test "POST create agenda, enfileira DispatchJob e responde 201" do
    scheduled = 3.days.from_now.change(usec: 0)
    assert_enqueued_with(job: Divulgacoes::DispatchJob, at: scheduled) do
      assert_difference [ "Divulgacao.count" ], 1 do
        post "/api/v1/ai/divulgacoes", headers: @auth_headers, as: :json,
             params: { client_id: @client.id, arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ],
                       scheduled_for: scheduled.iso8601 }
      end
    end
    assert_equal 201, response.status
    assert_equal "agendada", response.parsed_body.dig("data", "status")
  end
end
```

(`as: :json` serializa `params` como corpo JSON e define Content-Type; o `Content-Type` do `@auth_headers` do `ArtesControllerTest` é usado com `params` — conferir o padrão exato de POST em `artes_controller_test.rb` ao escrever.)

### Matriz mínima de testes (para o PLAN)

- **Auth:** 401 sem Bearer em cada endpoint (index/show/create/cancel/whatsapp_groups).
- **index:** sem `client_id` → 400; `client_id` inexistente → 404; escopo (divulgação do cliente B não aparece); `status` válido filtra; `status=bogus` → 400; `from/to` inclusivo no último dia (fronteira 23:30); `from > to` → 400; data inválida → 400; ordenação `asc`; paginação meta (`per_page` clamp 100); `grupos` presentes por item.
- **show:** 200 com `grupos`; id inexistente → 404.
- **create:** 201 + `DivulgacaoGrupo.count` +N + job `assert_enqueued_with(… at:)`; offset diferente de -03:00 (`"…T17:00:00Z"`) persiste o mesmo instante; sem `client_id`/`arte_id` → 400; `whatsapp_group_ids` vazio/ausente → 422 `field: "base"`; arte pendente → 422; arte com link externo → 422; `scheduled_for` passado → 422; `scheduled_for` lixo → 422; arte de B + client A → 404; grupo de B → 404; grupo inativo → 404; nos 404/422: `assert_no_difference` de `Divulgacao`/`DivulgacaoGrupo` e `assert_no_enqueued_jobs`; `whatsapp_group_ids` Hash-shaped → 422 (não 500).
- **cancel:** `agendada → cancelada` 200; já `cancelada`/`em_andamento`/`concluida` → 200 sem mudar status; id inexistente → 404.
- **whatsapp_groups:** só ativos; cliente sem instância → 200 `[]`; cliente inexistente → 404; escopo (grupos de B nunca aparecem em A); `display_name` fallback para `subject` nulo.
- **Isolamento (mutation-sensitive):** em `test/integration/cross_client_isolation_test.rb` (estilo dos `assert_raises(ActiveRecord::RecordNotFound)` existentes) ou no próprio controller test, provar 404 para arte/grupo forasteiros pelo caminho API.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| (n/a) | (n/a) | — | Fase usa os mesmos padrões da Phase 24/28/29; nada mudou no ecossistema relevante |

**Deprecated/outdated:** nada identificado. Pagy está em 9.4.0 (`limit:`, `pagy.limit`) — a Phase 24 já usa essa API; não migrar para Pagy 43.x aqui.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Divulgacao.find` cru em `show`/`cancel` é aceitável porque a API key de IA é única e agency-wide (consistente com `Artes#index` sem `client_id` e `Clients#summary`) | Pitfall 9 | Se o dono quiser isolamento por cliente também em `show/cancel`, exigir `client_id` e escopar pela associação; mudança pequena |
| A2 | Ordenação default `scheduled_for: :asc, id: :asc` (com tiebreaker por `id` para paginação estável) | Pattern 2 | Preferência de produto; trocar por `:desc` é uma palavra |
| A3 | `with_lock` ao redor de `cancelar!` é hardening opcional de baixo risco | Pitfall 5 | Nenhum se omitido (comportamento = admin atual) |
| A4 | Paginar o endpoint de grupos (em vez de devolver lista inteira) | Pattern 4 | Se a IA preferir lista completa numa chamada, remover pagy; risco de payload grande em contas com centenas de grupos |
| A5 | Cliente sem instância → 200 `[]` em `whatsapp_groups` (não 404) | Pattern 4 | Se preferirem 404/erro explícito, ajustar; o fluxo de create já falha seguro em 422 |

## Open Questions

1. **`show`/`cancel` por `:id` sem `client_id` — escopar ou não?**
   - What we know: D-01/D-04 definem as rotas só com `:id`; D-03 (client_id obrigatório) vale apenas para `index`; D-09 cobre só `create`. A key é agency-wide.
   - What's unclear: se o isolamento SEG deve se estender ao operador de IA.
   - Recommendation: `Divulgacao.find(params[:id])` (A1). Se o planner/usuário quiser mais estrito, aceitar `client_id` opcional e usar `Client.find(...).divulgacoes.find` quando presente — sem quebrar o contrato do CONTEXT.

2. **`from`/`to` aceitam só um dos dois?**
   - What we know: D-12 diz "opcional"; não define o caso de um só extremo.
   - Recommendation: aceitar um só (range aberto, verificado `>=`/`<=`), 400 só quando ambos presentes e `from > to`.

3. **Onde "documentar na descrição do endpoint" (D-02)?**
   - What we know: não existe OpenAPI/Swagger (explicitamente fora de escopo da Phase 24, adiado para v1.7 — [VERIFIED: 24-CONTEXT.md "Documentação OpenAPI/Swagger — explicitamente fora de escopo"]); README não cita a API.
   - Recommendation: comentário de cabeçalho no controller (pt-BR) descrevendo contrato, não-idempotência do POST e semântica de `scheduled_for`/cancel; sem arquivo de docs novo.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby / Bundler (vendor/bundle) | tudo | ✓ | ruby 3.3.3 | — |
| `bin/rails routes` | conferir rotas/helpers | ✓ | Rails 8.1.3.1 | — |
| `bin/rails runner` (DB de dev) | smoke de cast/SQL | ✓ | — | — |
| `bin/rubocop` | estilo | ✓ | 1.86.2 (`13 files inspected, no offenses detected` em `app/controllers/api`) | — |
| `bin/brakeman` | segurança estática | ✓ | 8.1.0 (`Security Warnings: 0`, `Ignored Warnings: 1`) | — |
| `bin/rails test` (banco de teste) | rodar a suíte | ✗ | — | Verificação por inspeção + ferramentas acima (banco de teste pertence a outro usuário do SO — [CITED: memória do projeto `test_db_permission.md`]) |
| PostgreSQL / Solid Queue DB | runtime | n/a para esta fase | — | — |

**Missing dependencies with no fallback:** nenhuma que bloqueie a escrita; a suíte não roda localmente (executa no CI).

## Verification Approach (suíte não executável aqui)

`workflow.nyquist_validation` está `false` em `.planning/config.json` [VERIFIED: .planning/config.json `"nyquist_validation": false`] — a seção "Validation Architecture" completa é omitida. Orientação prática para o planner:

- Os testes (`test/controllers/api/v1/ai/divulgacoes_controller_test.rb` etc.) **devem ser escritos** (CI roda a suíte; o histórico mostra workflow de CI com `bundler-audit`/`brakeman`), mas **não podem ser executados aqui**. Cada task deve ter verificação por inspeção explícita: rotas (`bin/rails routes -g divulgacoes`), `ruby -c`/`bin/rubocop <arquivos>`, `bin/brakeman -q --no-pager`.
- Smoke opcional com `bin/rails runner` contra o DB de dev **dentro de transação com rollback** (`ActiveRecord::Base.transaction { …; raise ActiveRecord::Rollback }`) e `ActiveJob::Base.queue_adapter = :test` para não enfileirar jobs reais no Solid Queue de dev. Útil para conferir serializer/SQL; evitar criar dados persistentes.
- Exemplos já comprovados nesta sessão via runner: cast de `scheduled_for` com offset/`Z`/lixo, SQL de `where(status:)`, SQL de ranges de data, formato `as_json` do timestamp.
- Registrar no PLAN/SUMMARY que a verificação dos testes é "por inspeção, não executados localmente" para evitar falsa alegação de suíte verde.

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1` [VERIFIED: .planning/config.json].

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (herdado) | `authenticate_ai_key!` com prefixo `ak_` e `secure_compare` (constant-time) — nada a mudar [VERIFIED: base_controller.rb] |
| V3 Session Management | no | API stateless por Bearer key |
| V4 Access Control | yes | Resolução escopada pela associação do cliente (D-09) para arte/grupos; 404 genérico; key agency-wide por desenho (Pitfall 9) |
| V5 Input Validation | yes | `params.permit(... whatsapp_group_ids: [])`, `require` para obrigatórios, enum `status` validado, `Date.iso8601`, validações do model; nunca interpolar params em SQL (usar hash conditions / ranges) |
| V6 Cryptography | no | Sem novo uso; `WhatsappInstance#token` já `encrypts` e **não** é exposto |
| V7/V13 (erros/API) | yes | Erros via envelope; sem stack/mensagem interna; 404 não distingue dono; `error_code` já sanitizado (URLs redigidas) |

### Known Threat Patterns for Rails JSON API + WhatsApp dispatch

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| IDOR: arte/grupo de outro cliente no POST | Tampering / Info Disclosure | `client.artes.find` + `scoped_active_groups.find` → 404 genérico; backstop `arte_e_grupos_do_mesmo_cliente` no model |
| Mass assignment (`status`, `client_id` forçado) | Tampering | `permit` allowlist explícito; `status` nunca permitido no create (nasce `agendada` por default); só `cancelar!` muda status |
| Enumeração de ids via diferença de resposta | Info Disclosure | 404 único para "não existe" e "não é seu" |
| Envio acidental/duplicado (replay/retry) | Repudiation / DoS (spam a grupos reais) | Risco aceito (D-02); documentar não-idempotência; throttle 60/min por key; monitorar |
| Vazamento de URL presignada via `error_code` | Info Disclosure | Já redigida em `sanitize_error_code` na Phase 29; serializer só repassa `error_code` |
| Exposição de `evolution_message_id`/token da instância | Info Disclosure | Não incluir no serializer (fora de D-10) |
| Abuso por volume | DoS | `api/ai_by_key` (60/min) e `api/ai_by_ip` (30/min sem Bearer) por prefixo — sem mudança |
| SQL injection em filtros | Tampering | Hash conditions/ranges parametrizados; `Arel.sql` apenas com literal constante (ordenação de grupos) |

## Project Constraints (from CLAUDE.md)

Não existe `CLAUDE.md` na raiz (`ls CLAUDE.md` → inexistente) nem `.claude/skills`/`.agents/skills`. Convenções observadas no código/memória, a respeitar:

- **Idioma:** pt-BR em comentários, mensagens de erro e testes (memória do usuário: "português brasileiro em todas as interações"; código existente comenta em pt-BR).
- **Estilo:** `# frozen_string_literal: true` nos arquivos da API de IA; rubocop (omakase + performance) deve passar — `bin/rubocop` funcional.
- **Testes:** `bin/rails test` não roda localmente (banco de teste de outro usuário do SO) — verificação por inspeção; CI executa a suíte.
- **Segurança:** invariante SEG-01..04 (resolução sempre pela associação do cliente).
- **Whatsapp/Evolution:** decisões v1.7 travadas (risco de ToS aceito) — não re-perguntar.

## Sources

### Primary (HIGH confidence — arquivos lidos/executados nesta sessão)
- `app/controllers/api/v1/base_controller.rb`, `app/controllers/api/v1/ai/{base,artes,clients}_controller.rb`, `app/serializers/api/v1/ai/arte_serializer.rb`
- `app/models/{divulgacao,divulgacao_grupo,whatsapp_group,whatsapp_instance,client}.rb`
- `app/controllers/admin/{divulgacoes,whatsapp_groups}_controller.rb`, `app/jobs/divulgacoes/dispatch_job.rb`, `app/jobs/whatsapp/send_to_group_job.rb` (sanitize_error_code)
- `config/routes.rb`, `config/initializers/rack_attack.rb`, `config/application.rb`, `config/environments/production.rb`, `db/schema.rb`, `Gemfile.lock`, `.planning/config.json`
- `test/test_helper.rb`, `test/controllers/api/v1/ai/{artes,clients}_controller_test.rb`, `test/controllers/admin/divulgacoes_controller_test.rb`, `test/integration/{rack_attack,cross_client_isolation}_test.rb`
- Execuções: `bin/rails routes`, `bin/rails runner` (cast de datetime, SQL de enum/range, `as_json`), `bin/rubocop`, `bin/brakeman`

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` (decisões Phases 26-31 e quick tasks), `.planning/ROADMAP.md` §Phase 32, `24-CONTEXT.md` (OpenAPI fora de escopo)

### Tertiary (LOW confidence)
- Nenhuma — não foi necessária pesquisa web (fase 100% in-repo; sem bibliotecas novas).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — nenhuma dependência nova; versões lidas do `Gemfile.lock`
- Architecture: HIGH — padrão copiado de controllers/serializers existentes lidos nesta sessão
- Pitfalls: HIGH — os três principais (enum→NULL, range de Date, `scheduled_for` lixo) reproduzidos empiricamente via `rails runner`

**Research date:** 2026-11-07
**Valid until:** 2026-12-07 (stack estável; revalidar só se Phase 31/model `Divulgacao` mudarem antes da execução)
