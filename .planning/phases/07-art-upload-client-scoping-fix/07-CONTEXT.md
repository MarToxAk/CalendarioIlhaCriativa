# Phase 7: Art Upload & Client Scoping Fix - Context

**Gathered:** 2026-06-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Corrigir a criação de artes no painel admin: o admin consegue criar uma arte com arquivo OU link externo independente de como navega para o form. O `client_id` é sempre derivado corretamente — pelo contexto da URL ou por seleção no próprio form. O `set_arte` expõe `@client` para que as views e actions tenham contexto de cliente disponível.

Requirements: ARTE-08, ARTE-09, ARTE-10.

**Fora do escopo desta fase:** Notificações, relatórios PDF/CSV, nested routes estruturais, mudanças no portal do cliente.

</domain>

<decisions>
## Implementation Decisions

### Causa raiz do bug (ARTE-08 + ARTE-09)

- **D-01:** O problema **não é no upload de arquivo em si**. Ao navegar direto para `/admin/artes/new` sem `?client_id=X` na URL, `set_client` retorna `@client = nil`. `Arte.new(client: nil)` deixa `client_id` vazio no `hidden_field`. Ao submeter, `validates :client, presence: true` falha — arte nunca é salva, independente de upload ou link externo. Ambos os tipos de mídia falham pelo mesmo motivo.

- **D-02:** Erros de validação podem não estar visíveis na view — confirmar que `@arte.errors` é renderizado na re-exibição do form.

### Fix do client_id no form (ARTE-09)

- **D-03:** Quando `@client` é nil (admin navegou direto para `/admin/artes/new`), o `_form.html.erb` deve exibir um `<select>` de clientes para que o admin escolha o cliente da arte. `f.select :client_id` populado com `Client.all`.

- **D-04:** Quando `@client` está presente (admin chegou via `new_admin_arte_path(client_id: @client.id)` da página do cliente), **manter o comportamento atual** — `f.hidden_field :client_id` com valor pré-preenchido. Fluxo normal intacto.

- **D-05:** No controller, `set_client` pode continuar com `Client.find_by(id: params[:client_id])` — o nil é válido quando o admin navega direto (o selector do form provê o client_id na submissão).

### Escopo de set_arte (ARTE-10)

- **D-06:** `set_arte` continua usando `Arte.includes(:approval_responses).find(params[:id])` como está. **Adicionar `@client = @arte.client`** no final do método para disponibilizar o contexto de cliente em todas as actions (show, edit, update, destroy, mark_revised). Sistema single-admin — sem restrição de acesso necessária.

- **D-07:** O admin pode navegar para artes tanto pelo dashboard/cliente quanto direto pela URL — ambos os casos devem funcionar sem restrição.

### Claude's Discretion

- Estilo visual do `<select>` de clientes no form — seguir o padrão `form-input w-full` existente no `_form.html.erb`
- Label do select (`"Cliente"` ou `"Selecione o cliente"`) — PT-BR consistente com o resto do form
- Ordenação dos clientes no select — alfabética por nome (`Client.order(:name)`)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Model e Controller

- `app/models/arte.rb` — `has_one_attached :media_file`, `belongs_to :client`, `validates :client, presence: true`, validações `media_source_present` e `only_one_media_source`
- `app/controllers/admin/artes_controller.rb` — `set_client` (find_by client_id), `set_arte` (find por ID), `arte_params` (campos permitidos incluindo `:client_id` e `:media_file`), before_actions
- `app/controllers/admin/base_controller.rb` — base do admin, verificar se há método de autenticação ou contexto compartilhado

### Views

- `app/views/admin/artes/_form.html.erb` — form multipart com `hidden_field :client_id`, `file_field :media_file`, `url_field :external_url`, Stimulus `media-type-toggle`. **ARQUIVO CENTRAL DA CORREÇÃO**.
- `app/views/admin/artes/new.html.erb` — view que renderiza o form para nova arte
- `app/views/admin/artes/show.html.erb` — exibição de `media_file` e `external_url` (linha 11-14)
- `app/views/admin/clients/show.html.erb` — link "Nova Arte" em linha 140: `new_admin_arte_path(client_id: @client.id)`

### Rotas e Config

- `config/routes.rb` — `resources :artes` flat sob namespace admin (sem nested routes)
- `config/storage.yml` — storage local configurado (`:local` service)

### Requisitos

- `.planning/REQUIREMENTS.md` — ARTE-08, ARTE-09, ARTE-10 mapeados para Phase 7

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `Client.order(:name)` — para popular o selector de clientes (mesmo padrão de `Client.all` usado no `admin/dashboard_controller.rb`)
- Padrão `form-input w-full` + `f.select` — já usado em outros selects do form (`:platform`, `:media_type`)
- `app/javascript/controllers/media_type_toggle_controller.js` — Stimulus controller que controla visibilidade dos campos upload/link. Verificar se `selectUpload`/`selectLink` deixam os campos submetíveis (sem `disabled` nos inputs ocultos)

### Established Patterns

- `f.hidden_field :client_id` já existe no form — lógica condicional: mostrar se `arte.client_id.present?`, selector se não
- `arte_params` já permite `:client_id` — nenhuma mudança necessária nos params
- Validação de presença de cliente já existe no model — o fix é no form, não no model
- Flash messages: `redirect_to ..., notice:` / `render :new, status: :unprocessable_entity` — padrão em todo o admin

### Integration Points

- `_form.html.erb`: adicionar lógica condicional `if arte.client_id.present?` para alternar entre `hidden_field` e `select`
- `Admin::ArtesController#set_arte`: adicionar `@client = @arte.client` no final
- `Admin::ArtesController#new`: passa `Arte.new(client: @client)` — quando `@client` nil, `arte.client_id` nil → selector é exibido
- `app/views/admin/artes/new.html.erb`: verificar se `@arte.errors` é renderizado quando form re-exibe após validação falha

</code_context>

<specifics>
## Specific Ideas

- O bug principal é de navegação: admin vai direto para `/admin/artes/new` sem `?client_id=X`. O fix primário é o selector de clientes — sem ele, a arte não pode ser criada por esse caminho.
- Verificar o Stimulus `media-type-toggle` controller: os campos de upload e link **iniciam ocultos** para artes novas (`arte.media_file.attached? = false` e `arte.external_url = nil`). Se o Stimulus não mostrar o campo correto ao clicar no radio, o form submete sem mídia nenhuma.
- `rails_service_blob_proxy_path` é usado para vídeos no portal do cliente — verificar que esse helper está disponível e funcional.

</specifics>

<deferred>
## Deferred Ideas

- **Nested routes** `/admin/clients/:client_id/artes` — solução mais estrutural para garantir client_id sempre na URL. Descartada nesta fase por impacto em rotas, helpers e links. Pode ser revisitada se o sistema crescer.
- **Relatório de aprovações PDF/CSV** — mencionado no backlog (ADM2-01), fora do escopo desta fase.
- **Notificações por e-mail** — NOTF-01/NOTF-02, fora do escopo desta fase.

</deferred>

---

*Phase: 7-art-upload-client-scoping-fix*
*Context gathered: 2026-06-02*
