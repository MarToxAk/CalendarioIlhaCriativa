# Phase 6: Admin Feedback Panel - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

O admin tem visibilidade centralizada de todas as artes e respostas dos clientes num dashboard (a raiz do painel admin). Pode filtrar por cliente e por status via Turbo Frame sem recarregar a página, marcar artes com pedido de alteração como revisadas, escrever notas internas de resposta ao comentário do cliente, e consultar o histórico de artes respondidas de um cliente específico na página desse cliente.

Requirements: PAIN-01, PAIN-02, PAIN-03, PAIN-04, PAIN-05, CLIE-05.

**Fora do escopo desta fase:** Notificações (e-mail/WhatsApp), visibilidade da resposta do admin para o cliente no portal, exportação de relatórios.

</domain>

<decisions>
## Implementation Decisions

### Ponto de entrada do painel (PAIN-01)

- **D-01:** O **dashboard raiz do admin** (`/admin`) substitui o stub atual. `Admin::DashboardController#index` passa a carregar todas as artes com suas respostas. Zero rota nova — o admin abre o sistema e já vê o painel de feedback.
- **D-02:** Por padrão (sem filtros), **todas as artes** aparecem com todos os 4 status (pending/approved/change_requested/revised) e badge de status colorido. O admin vê o quadro completo.
- **D-03:** **Uma linha por arte** — exibe a última resposta/status atual de cada arte. Link para `admin/artes/:id` para ver histórico completo e agir. Sem duplicatas por múltiplas respostas.
- **D-04:** Artes **agrupadas por cliente** — cada cliente tem uma seção com o nome e suas artes abaixo, ordenadas por `scheduled_on` decrescente.

### Filtros (PAIN-02, PAIN-03)

- **D-05:** Filtros implementados via **Turbo Frame** — o conteúdo do dashboard fica dentro de um `<turbo-frame id="dashboard-content">`. Os filtros são um `form GET` que submete com `data-turbo-frame="dashboard-content"`. URL preserva `?client_id=&status=` (bookmarkável). Rails 8 nativo, zero JS extra.
- **D-06:** Os filtros ficam numa **barra horizontal acima da lista agrupada** — select de cliente + select de status em linha. Submit automático via `data-action="change->auto-submit#submit"` (ou botão "Filtrar" — Claude decide com base no padrão existente do projeto).
- **D-07:** O filtro de status inclui **todos os 4 status** (Pendente / Aprovado / Pediu Alteração / Revisado) mais uma opção "Todos". O dashboard é o painel geral do admin, não só a fila de pedidos.

### Resposta do admin ao comentário (PAIN-05)

- **D-08:** A resposta do admin é escrita na **página `admin/artes/:id`** (show da arte), junto ao botão "Marcar como Revisada". Admin navega para a arte pelo link no dashboard e responde diretamente no detalhe.
- **D-09:** Armazenado como **campo `admin_reply: text`** na tabela `artes`. Uma resposta por arte — se o admin revisar e responder novamente, o campo é sobrescrito. Migração simples, sem tabela nova.
- **D-10:** A resposta do admin é **interna ao admin** — o cliente **não** vê no portal. É uma nota de trabalho do admin, não uma mensagem para o cliente.

### Histórico do cliente (CLIE-05)

- **D-11:** Histórico como **terceiro card** adicionado ao `admin/clients/show.html.erb` existente — sem rota nova. Admin acessa pelo link já existente na listagem de clientes.
- **D-12:** O card exibe **artes que receberam pelo menos uma ApprovalResponse**, ordenadas por `scheduled_on` decrescente. Cada item mostra: título da arte, data agendada, status atual (badge), última resposta + comentário do cliente, link para `admin_arte_path`.

### Claude's Discretion

- Ordenação dentro de cada grupo de cliente no dashboard — `scheduled_on` decrescente ou `responded_at` da última resposta.
- Copywriting PT-BR dos labels de status nos filtros (ex: "Pediu Alteração" vs "Alteração Solicitada").
- Estilo exato do card de histórico na página do cliente — mesma estrutura dos cards existentes (bg-white, rounded-xl, border, shadow-card, p-6).
- Controle de submit automático do filtro — `auto-submit` Stimulus genérico ou botão "Filtrar" manual.
- Marcação de artes como revisadas no dashboard: link para a arte ou botão direto na linha (Claude decide).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Controllers e Models existentes

- `app/controllers/admin/dashboard_controller.rb` — controller stub que será substituído. LEITURA OBRIGATÓRIA — é aqui que a lógica do painel vive.
- `app/controllers/admin/artes_controller.rb` — padrão de `includes(:client)`, variáveis de filtro (`@clients`, `@status_options`). A action `mark_revised` já existe aqui (Phase 5).
- `app/controllers/admin/clients_controller.rb` — `show` action que será expandida com o histórico (CLIE-05).
- `app/models/arte.rb` — enums `status` (pending/approved/change_requested/revised), `has_many :approval_responses`. Receberá a nova coluna `admin_reply`.
- `app/models/approval_response.rb` — enum `decision` (approved/change_requested), `comment`, `responded_at`. Lido para o histórico.
- `db/schema.rb` — estrutura atual das tabelas. Migração desta fase: adicionar `admin_reply: text` em `artes`.

### Views do admin

- `app/views/admin/dashboard/index.html.erb` — view stub que será reescrita com o painel de feedback.
- `app/views/admin/artes/show.html.erb` — receberá o formulário de `admin_reply` abaixo do bloco de ações existente.
- `app/views/admin/clients/show.html.erb` — receberá o terceiro card de histórico (D-11, D-12).
- `app/views/admin/artes/index.html.erb` — padrão de tabela admin com colunas e links — referência visual para o dashboard.

### Layouts e componentes

- `app/views/layouts/admin.html.erb` — layout base do admin com sidebar. Flash messages já renderizados.
- `app/views/admin/shared/_sidebar.html.erb` — sidebar com links de navegação. O link "Dashboard" já aponta para `admin_root_path`.
- `app/views/admin/clients/_status_badge.html.erb` — padrão de badge de status para clientes.
- `app/views/client/shared/_arte_status_badge.html.erb` — badge de status de artes (pending/approved/change_requested/revised) — adaptar ou criar equivalente admin.

### Rotas

- `config/routes.rb` — `namespace :admin { root to: "dashboard#index" }` já aponta para o DashboardController. Nenhuma rota nova necessária para PAIN-01 a 04. CLIE-05 também não exige rota nova (seção na show existente).

### Requisitos

- `.planning/REQUIREMENTS.md` — PAIN-01 a PAIN-05 e CLIE-05 mapeados para esta fase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/admin/artes/index.html.erb` — tabela com estrutura `min-w-full bg-white border border-gray-200 rounded-xl shadow-card` — reutilizar como base visual do dashboard agrupado.
- `app/javascript/controllers/password_toggle_controller.js` — padrão Stimulus de toggle — base para auto-submit de filtros se necessário.
- `app/views/admin/clients/_confirm_modal.html.erb` + `modal_controller.js` — padrão de modal de confirmação disponível para ações destrutivas no dashboard.
- `app/views/admin/artes/show.html.erb` — estrutura do card de ações (flex gap-2, btn classes) — referência para adicionar o campo `admin_reply`.

### Established Patterns

- Agrupamento por associação: `Arte.includes(:client).order(...)` com `group_by(&:client)` em Ruby, ou query com `joins(:client).order("clients.name, artes.scheduled_on DESC")`.
- Turbo Frame: `<turbo-frame id="...">` em Rails 8 — nenhuma gem extra. Form GET com `data: { turbo_frame: "dashboard-content" }` para filtros sem reload.
- Flash messages: `redirect_to ..., notice: "..."` — padrão em todo o admin.
- Segurança: queries sempre escopadas por associação; `Arte.includes(:client)` no DashboardController (não `Arte.all` diretamente sem escopo de cliente).
- Cards de layout: `bg-white rounded-xl border border-gray-200 shadow-card p-6` — padrão visual em clients/show e artes/show.

### Integration Points

- `Admin::DashboardController#index` — reescrever para carregar `@artes_by_client` (hash `{client => [artes]}`) com eager loading de `approval_responses`.
- `app/views/admin/dashboard/index.html.erb` — reescrever completamente com o painel agrupado + barra de filtros + Turbo Frame.
- `Admin::ArtesController#show` (e view) — adicionar formulário `admin_reply` abaixo do bloco de ações existente (D-08, D-09).
- `Admin::ClientsController#show` (e view `clients/show.html.erb`) — adicionar terceiro card com histórico de respostas (D-11, D-12).
- `db/migrate/` — migração `add_column :artes, :admin_reply, :text` (D-09).

### Schema Change Required

- Migração: `add_column :artes, :admin_reply, :text` — sem valor default (nil = sem resposta).
- Arte model: nenhuma mudança nos enums ou associations. Apenas o novo campo `admin_reply`.

</code_context>

<specifics>
## Specific Ideas

- Agrupamento por cliente no dashboard — cada grupo tem cabeçalho com o nome do cliente em destaque (semelhante a um `<h3>` ou divider com `text-slate-700 font-semibold`) seguido pelas artes em tabela compacta.
- Badge de status das artes no dashboard deve usar as mesmas cores semânticas do portal do cliente: verde (aprovado), laranja/vermelho (pediu alteração), cinza (pendente), azul/índigo (revisado) — manter consistência visual.
- Campo `admin_reply` na página da arte: `<textarea>` simples com label "Resposta interna ao comentário", botão "Salvar resposta" via `button_to PATCH`. Sem Stimulus necessário — form simples.

</specifics>

<deferred>
## Deferred Ideas

- **Resposta do admin visível para o cliente** — explicitamente decidido como fora do escopo desta fase (D-10). Pode ser revisitado numa fase futura de comunicação admin↔cliente.
- **Notificações por e-mail/WhatsApp** — Out of scope v1 (documentado em REQUIREMENTS.md).
- **Fila de trabalho (default: só pedidos de alteração)** — considerado como default do dashboard mas decidido como "todas as artes" (D-02). Se o volume crescer, um filtro default `?status=change_requested` pode ser adotado sem mudança de código.
- **Exportar relatório de aprovações (PDF/CSV)** — v2, documentado em REQUIREMENTS.md como ADM2-01.

</deferred>

---

*Phase: 6-admin-feedback-panel*
*Context gathered: 2026-05-26*
