# Phase 2: Admin Auth + Client Management - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

O admin consegue fazer login, criar e gerenciar clientes, e copiar o link + senha de acesso de cada cliente. Inclui o layout completo do admin (sidebar + topbar) e CRUD de clientes com desativação e rotação de token.

Auth-01 e AUTH-02 já foram implementados na Fase 1 — esta fase foca no layout do admin e no gerenciamento de clientes (CLIE-01 a CLIE-04).

</domain>

<decisions>
## Implementation Decisions

### Layout do Admin
- **D-01:** Criar `app/views/layouts/admin.html.erb` como layout dedicado para a área administrativa (separado do `application.html.erb`).
- **D-02:** `Admin::BaseController` deve declarar `layout 'admin'` — todos os controllers que herdam dele usam o layout admin automaticamente.
- **D-03:** Sidebar com links de navegação hardcoded em partial (`app/views/admin/shared/_sidebar.html.erb`). Itens: Dashboard, Aprovações, Clientes, Calendário, Configurações, Avatar + Sair.
- **D-04:** Link ativo na sidebar detectado via helper `current_page?` com CSS condicional (ex: `class: "nav-item #{'active' if current_page?(admin_clients_path)}"`). Sem Stimulus para gerenciar estado ativo.

### Rotas e Controller de Clientes
- **D-05:** `Admin::ClientsController` com actions: `index, show, new, create, edit, update`. Sem `destroy` (v1 só desativa, não exclui).
- **D-06:** Desativar/reativar cliente via `update` com `active: false` ou `active: true` como parâmetro. Não criar actions customizadas `deactivate`/`reactivate`.
- **D-07:** Rotação de token: rota member `post :rotate_token` no namespace admin. A UI-SPEC já referencia `rotate_token_admin_client_path`, confirma essa abordagem.

### Senha do Portal do Cliente
- **D-08:** Adicionar coluna `password_plain :string` na tabela `clients` via migração. A senha é salva em texto puro nessa coluna durante `create` e `update` (junto com o digest bcrypt do `has_secure_password`).
- **D-09:** Razão: o admin precisa ver e copiar a senha para enviar ao cliente por WhatsApp. O hash bcrypt é irreversível — sem `password_plain` a UI-SPEC (Screen 4) não pode ser implementada como especificado.
- **D-10:** Campo senha vazio na edição = manter a senha atual. Implementar no controller: `client_params.reject { |k, v| k.in?(['password', 'password_plain']) && v.blank? }` antes de chamar `update`.
- **D-11:** Na tela de detalhe (`/admin/clients/:id`), exibir `client.password_plain` no campo de senha — visível por padrão (type="text"), com toggle ocultar/revelar via Stimulus, conforme UI-SPEC Screen 4.

### Claude's Discretion
- Estrutura interna do `admin.html.erb` (head, meta tags, asset includes) — seguir padrões Rails 8 e herdar design tokens da Phase 1.
- Strong parameters para `Admin::ClientsController` — Claude decide quais campos são permitidos.
- Tratamento de erros de validação no form (flash vs. inline errors via ActiveRecord) — seguir padrão Rails padrão com `render :new` / `render :edit`.
- Ordenação padrão da lista de clientes — Claude decide (ex: criado_em DESC).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UI Design Contract
- `.planning/phases/02-admin-auth-client-management/02-UI-SPEC.md` — Contrato visual completo: 4 telas, 6 componentes Stimulus, copywriting PT-BR, acessibilidade, responsividade, animações. LEITURA OBRIGATÓRIA antes de qualquer view.

### Design Tokens (herdados da Phase 1)
- `.planning/phases/01-data-foundation-security/01-UI-SPEC.md` — Tokens de cor, tipografia, espaçamento, sombras, transições. A Phase 2 UI-SPEC herda todos esses tokens.

### Schema e Models
- `db/schema.rb` — Schema atual do banco. Inclui tabelas: clients, artes, approval_responses, sessions, users.
- `app/models/client.rb` — Model Client: `has_secure_token :access_token`, `has_secure_password`, `has_many :artes`.

### Auth e Controllers Existentes
- `app/controllers/concerns/authentication.rb` — Concern de autenticação do admin: `resume_session`, `require_authentication`, `start_new_session_for`, `terminate_session`.
- `app/controllers/admin/base_controller.rb` — Base do namespace admin, aplica `require_authentication`.
- `config/routes.rb` — Rotas atuais. Fase 2 expande `resources :clients` no namespace admin.

### Requisitos
- `.planning/REQUIREMENTS.md` — Requirements CLIE-01 a CLIE-04 mapeados para esta fase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/controllers/concerns/authentication.rb`: concern já incluso em `ApplicationController` — `Admin::BaseController` herda `require_authentication` automaticamente via herança.
- `app/models/client.rb`: model pronto com `has_secure_token`, `has_secure_password`, `active` boolean, `has_many :artes`. Fase 2 adiciona `password_plain`.
- `app/views/layouts/application.html.erb`: base para criar o layout admin — copiar estrutura head e adaptar body para incluir sidebar + topbar.
- `app/assets/tailwind/application.css`: design tokens via `@theme {}` já definidos na Phase 1 — disponíveis globalmente para todas as views.

### Established Patterns
- Auth admin: `Sessions#create` → `start_new_session_for(user)` → cookie `session_id`. Padrão Rails 8 generator.
- Flash messages: padrão Rails (`flash[:notice]`, `flash[:alert]`) — layout admin deve renderizá-las.
- Stimulus controllers: Fase 2 introduz 4 novos controllers (`copy`, `dropdown`, `modal`, `password-toggle`). Padrão: arquivos em `app/javascript/controllers/`.

### Integration Points
- `config/routes.rb` linha `resources :clients, only: [:index]` → expandir para CRUD completo + member `:rotate_token`.
- `Admin::BaseController` → adicionar `layout 'admin'` e quaisquer helpers admin-globais.
- `Admin::DashboardController` → já existe como stub, continua funcionando com o novo layout.

</code_context>

<specifics>
## Specific Ideas

- Senha em texto puro: campo `password_plain` na tabela `clients`. Valor exibido no Screen 4 da UI-SPEC no input readonly.
- Token rotation: `client.regenerate_access_token` (método gerado pelo `has_secure_token`) + salvar — invalida o token anterior automaticamente.
- Deactivate via update: `client.update(active: false)` na `update` action quando `params[:client][:active] == 'false'`.
- Sidebar: partial `app/views/admin/shared/_sidebar.html.erb` renderizado no layout admin.

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 2-admin-auth-client-management*
*Context gathered: 2026-05-24*
