# Phase 3: Art Management - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

O admin consegue criar, editar e excluir artes associadas a clientes, com upload de arquivo ou link externo, plataforma (Instagram/Facebook/LinkedIn), formato (imagem/vídeo/legenda), data limite de aprovação e legenda/texto.

Requirements: ARTE-01 a ARTE-09.

</domain>

<decisions>
## Implementation Decisions

### Navegação e Ponto de Entrada

- **D-01:** Artes acessíveis por **dois caminhos**: (1) seção "Artes" no show do cliente (`/admin/clients/:id`), abaixo dos dados de acesso — lista das artes daquele cliente + botão "Nova arte" pré-preenchido com o cliente; (2) lista global `/admin/artes` com tabela + filtros por cliente e status.
- **D-02:** Lista global usa tabela com filtros — mesma abordagem da lista de clientes (padrão já estabelecido). Colunas: cliente, data agendada, plataforma, status.
- **D-03:** No show do cliente, a seção "Artes" fica abaixo dos dados de acesso (link + senha). Expande a página existente, não cria tabs nem página separada.

### Formulário — Upload vs Link Externo

- **D-04:** Formulário tem **radio toggle**: "Upload de arquivo" / "Link externo". Ao selecionar um, o campo do outro some via Stimulus. Novo Stimulus controller `media_type_toggle` (ou similar) — seguir padrão `password_toggle_controller` da Phase 2.
- **D-05:** Armazenamento local com ActiveStorage disk storage (já configurado). Pode migrar para S3 depois.
- **D-06:** Limite de upload: **50 MB** por arquivo. Validação no model/controller.

### Preview na Listagem e Show

- **D-07:** Na lista (global e seção do cliente): **thumbnail pequeno (≈60×60px)** para uploads, ícone de link para URL externa. Ao lado: cliente (na global), data, plataforma, status.
- **D-08:** Tela show de arte (`/admin/artes/:id`): **preview completo** — imagem em tamanho maior, player de vídeo (tag `<video>`), ou texto da legenda conforme `media_type`. Abaixo: todos os metadados (cliente, data, plataforma, formato, prazo, status, legenda).

### Proteção de Edição e Exclusão

- **D-09:** **Edição bloqueada** para artes com `status != pending`. Controller nega `edit`/`update` se a arte já foi aprovada ou tem pedido de alteração. Admin vê mensagem de erro.
- **D-10:** **Exclusão bloqueada** para artes que têm resposta do cliente (`status != pending` ou `approval_response` presente). Modal de confirmação (reutiliza `_confirm_modal`) só aparece para artes pendentes. Preserva histórico de aprovação.

### Claude's Discretion

- Estrutura interna do `Admin::ArtesController` — strong parameters, before_action, ordenação padrão.
- Mensagem de erro ao bloquear edição/exclusão — Claude define o copywriting PT-BR.
- Número de colunas responsivas e breakpoints mobile na tabela de artes.
- Validação de tipo de arquivo (MIME types aceitos) — Claude define lista razoável para imagens e vídeos.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Modelo e Schema

- `app/models/arte.rb` — Model completo: enums (platform, media_type, status), `has_one_attached :media_file`, validações `media_source_present` e `only_one_media_source`. Leitura obrigatória antes de qualquer controller ou view.
- `db/schema.rb` — Tabela `artes`: campos approval_deadline, caption, client_id, external_url, media_type, platform, scheduled_on, status, title. Índices em client_id+scheduled_on e status.

### Padrões Estabelecidos (Phase 2)

- `app/controllers/admin/clients_controller.rb` — Padrão de controller no namespace admin: strong params, set_client, before_action. Replicar estrutura para ArtesController.
- `app/views/admin/clients/` — Padrões de views admin: `_form`, `_status_badge`, `_confirm_modal`, `index.html.erb`. Reutilizar partials onde possível.
- `app/javascript/controllers/` — Controllers Stimulus existentes: `dropdown`, `modal`, `copy`, `password-toggle`. O novo `media_type_toggle` deve seguir o mesmo padrão.
- `.planning/phases/02-admin-auth-client-management/02-UI-SPEC.md` — Design tokens, componentes, copywriting PT-BR. Herdar para views de artes.

### Requisitos

- `.planning/REQUIREMENTS.md` — ARTE-01 a ARTE-09 mapeados para esta fase.

### Configuração

- `config/routes.rb` — Rotas admin atuais. Fase 3 adiciona `resources :artes` no namespace admin e recursos aninhados em clients.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/admin/clients/_confirm_modal.html.erb` — Suporta `hidden_fields:` local (adicionado na Phase 2). Reutilizável para confirmar exclusão de arte.
- `app/views/admin/clients/_status_badge.html.erb` — Badge de status visual. Artes têm status próprio (pending/approved/change_requested/revised) — criar badge equivalente ou adaptar.
- `app/javascript/controllers/password_toggle_controller.js` — Padrão de toggle de campo via Stimulus. Base para o novo `media_type_toggle_controller`.
- `app/controllers/admin/base_controller.rb` — Herança correta para ArtesController.

### Established Patterns

- ActiveStorage já configurado com disk storage — `has_one_attached :media_file` no model Arte já pronto. Não reconfigurar.
- Enums Rails no model: `platform` (instagram/facebook/linkedin), `media_type` (image/video/caption_only), `status` (pending/approved/change_requested/revised) — usar métodos de enum (`.platform_instagram?`, `.pending?`) nas views e controllers.
- Padrão de namespace admin: `Admin::BaseController` → herança → `require_authentication` automático.

### Integration Points

- `Admin::ClientsController#show` — Precisa renderizar seção de artes do cliente (lista + botão Nova arte). Modificar view `show.html.erb` ou usar `render` para partial de artes.
- `config/routes.rb` — Adicionar `resources :artes` no namespace admin + member route para show de artes por cliente.
- Tabela `artes` já existe — sem migração necessária para campos básicos. Apenas ActiveStorage blob storage (já configurado).

</code_context>

<specifics>
## Specific Ideas

- Admin acessa artes por **dois caminhos** (decisão explícita do usuário, não um ou outro).
- Toggle upload/link deve se comportar como o password toggle existente — ocultar o campo não selecionado, não só desabilitar.
- Preview na lista: thumbnail para uploads, ícone de link externo para URLs — admin distingue visualmente o tipo sem abrir a arte.

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 3-Art Management*
*Context gathered: 2026-05-25*
