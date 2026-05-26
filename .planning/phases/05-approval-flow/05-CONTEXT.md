# Phase 5: Approval Flow - Context

**Gathered:** 2026-05-26
**Status:** Ready for planning

<domain>
## Phase Boundary

O cliente, na página de preview de uma arte, consegue aprovar a arte ou pedir alteração com comentário. Após o admin revisar e marcar a arte como "revisada", a arte volta para um estado aprovável e o cliente pode agir novamente. O histórico de todas as decisões é visível na página da arte. Botões de aprovação ficam desabilitados/ocultos para artes que não estão em estado aprovável.

Requirements: APRO-01, APRO-02, APRO-03, APRO-04, APRO-05.

**Fora do escopo desta fase:** Painel do admin com todas as respostas (Fase 6), notificações, aprovação inline na grade do calendário.

</domain>

<decisions>
## Implementation Decisions

### Localização dos Botões de Aprovação

- **D-01:** Botões "Aprovar" e "Pedir Alteração" ficam na **página da arte** (`/c/:token/artes/:id`) — não na grade do calendário. A grade permanece somente-leitura (Phase 4, sem mudança). Rationale: o cliente precisa ver o conteúdo completo antes de decidir; o campo de comentário não cabe na célula da grade.
- **D-02:** Os botões aparecem apenas quando a arte está em estado aprovável (`pending?` ou `revised?`). Para artes em `approved` ou `change_requested`, os botões ficam ocultos (não apenas desabilitados) — o status badge já comunica o estado atual (APRO-05).

### Formulário de Comentário

- **D-03:** Ao clicar "Pedir Alteração", um formulário se expande **inline** via Stimulus toggle: uma `<textarea>` aparece abaixo do botão com o campo de comentário e um botão de confirmação "Enviar". Clicar "Pedir Alteração" novamente (ou um botão "Cancelar") colapsa o formulário. Rationale: sem mudança de URL, sem modal overhead, padrão existente no projeto.
- **D-04:** O comentário é **opcional** para "Pedir Alteração" — o cliente pode pedir alteração sem escrever texto (alinhado com APRO-02 que diz "pode escrever comentário"). O campo deve ter placeholder "Descreva o que precisa ser alterado (opcional)".
- **D-05:** "Aprovar" submete diretamente via `form_with` POST sem campo de comentário — um clique envia a aprovação.

### Histórico de Decisões

- **D-06:** O histórico aparece na **página da arte**, abaixo dos botões de ação, em seção "Histórico de respostas". Lista todas as `ApprovalResponse` em ordem cronológica reversa (mais recente primeiro). Cada item mostra: decisão (Aprovado/Pediu Alteração), comentário se presente, e data/hora (APRO-04).
- **D-07:** O histórico é visível para o cliente mesmo quando a arte está aprovada — o cliente pode sempre consultar o que decidiu.

### Feedback Pós-Ação

- **D-08:** Após submeter (aprovar ou pedir alteração), o cliente recebe um **flash notice** ("Arte aprovada!" / "Pedido de alteração enviado.") e é redirecionado de volta para a **mesma página da arte** (`/c/:token/artes/:id`). O cliente vê o status atualizado e o novo item no histórico imediatamente. Rationale: flash já existe no layout client.html.erb; redirect para a mesma página é o padrão mais simples.

### Admin — Marcar como Revisada (APRO-03)

- **D-09:** O admin tem uma ação "Marcar como Revisada" acessível na view do admin de cada arte quando o status é `change_requested`. Esta ação muda o status da arte para `revised` (não para `pending`). O portal do cliente exibe artes `revised` com badge "Revisado" (já implementado no Phase 4) e mostra os botões de aprovação — o cliente vê que o admin agiu e pode re-aprovar.
- **D-10:** A action do admin é `PATCH /admin/artes/:id/mark_revised` adicionada em `Admin::ArtesController`. Renderiza flash "Arte marcada como revisada." e redireciona para `admin_arte_path`.

### Claude's Discretion

- Rota de aprovação: `resources :responses, only: [:create], controller: 'client/responses'` nested sob `:artes` no scope `/c/:token` → gera `client_arte_responses_path(token:, arte_id:)`
- Controller: `Client::ResponsesController < ClientController` com `set_arte` (usando `@client.artes.find`) e `create` action
- Migração necessária: remover o índice único em `approval_responses.arte_id` (atualmente `unique: true`) — APRO-04 (histórico) requer múltiplas respostas por arte
- Arte model: mudar `has_one :approval_response` → `has_many :approval_responses, dependent: :destroy` com scope `order(created_at: :desc)`
- ApprovalResponse validator `arte_must_be_pending`: atualizar para aceitar `arte.pending? || arte.revised?` (permitir re-aprovação após revisão do admin)
- Stimulus controller: criar `approval_controller` (ou `toggle_controller` genérico) para expandir/colapsar o formulário de comentário — ou reutilizar pattern do `password_toggle_controller` existente
- Coprywriting PT-BR dos labels e flash messages

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Modelos e Schema Existentes

- `app/models/approval_response.rb` — modelo existente com enum `decision`, validator `arte_must_be_pending`, `after_create :sync_arte_status`. LEITURA OBRIGATÓRIA — a migração desta fase modifica o índice único nesta tabela.
- `app/models/arte.rb` — enums `status` (pending/approved/change_requested/revised), `has_one :approval_response`. Esta fase muda para `has_many`.
- `db/schema.rb` — índice `unique: true` em `approval_responses.arte_id` deve ser removido via migração.

### Controllers e Views do Portal do Cliente

- `app/controllers/client/artes_controller.rb` — padrão `set_arte` com `@client.artes.find`; `Client::ResponsesController` segue o mesmo padrão.
- `app/views/client/artes/show.html.erb` — view que receberá os botões de aprovação e a seção de histórico (D-01, D-06).
- `app/controllers/client_controller.rb` — `load_client_from_token` + `require_client_auth`; todos os controllers do portal herdam.

### Controllers do Admin

- `app/controllers/admin/artes_controller.rb` — recebe a nova action `mark_revised` (D-10).
- `app/views/admin/artes/` — views do admin onde o botão "Marcar como Revisada" será adicionado.

### Rotas

- `config/routes.rb` — scope `/c/:token`: adicionar `resources :responses, only: [:create]` nested sob `:artes`. Admin: adicionar `member { patch :mark_revised }` em `resources :artes`.

### Design e Padrões Visuais

- `.planning/phases/03-art-management/03-UI-SPEC.md` — tokens de cor, badges de status. Portal do cliente usa `#EA580C` (laranja) como acento.
- `app/views/client/shared/_arte_status_badge.html.erb` — badge de status já suporta todos os 4 estados incluindo `revised`.
- `app/javascript/controllers/password_toggle_controller.js` — padrão de toggle Stimulus para o formulário inline de comentário.

### Requisitos

- `.planning/REQUIREMENTS.md` — APRO-01 a APRO-05 mapeados para esta fase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/client/shared/_arte_status_badge.html.erb` — badge com suporte a `revised` já implementado (slate colors) — reutilizar diretamente.
- `app/javascript/controllers/password_toggle_controller.js` — padrão Stimulus de toggle (show/hide element) — base para o `approval_controller` de expansão inline do formulário de comentário.
- `app/views/layouts/client.html.erb` — flash messages já renderizados (notice verde, alert vermelho) — D-08 usa isso diretamente.

### Established Patterns

- Escopo de segurança: `@client.artes.find(params[:arte_id])` em `Client::ResponsesController#set_arte` — NUNCA `Arte.find` direto.
- `form_with url: ..., method: :post` para submissão de aprovação sem necessidade de Turbo Streams.
- `redirect_to client_arte_path(...), notice: "..."` — padrão de redirect com flash.
- Admin actions: `member { patch :mark_revised }` — padrão visto em `post :rotate_token` no admin.

### Integration Points

- `app/views/client/artes/show.html.erb` — recebe a seção de botões de aprovação (abaixo dos metadados) e a seção de histórico (abaixo dos botões).
- `config/routes.rb` — scope `/c/:token`: adicionar `resources :artes, only: [:show] { resources :responses, only: [:create] }`.
- `app/controllers/admin/artes_controller.rb` — adicionar `mark_revised` action.
- `app/views/admin/artes/show.html.erb` (ou index) — adicionar botão "Marcar como Revisada" quando `arte.change_requested?`.

### Schema Change Required

- Migração: `remove_index :approval_responses, :arte_id` (remove unique) + `add_index :approval_responses, :arte_id` (sem unique).
- Arte model: `has_one :approval_response` → `has_many :approval_responses, dependent: :destroy`.
- ApprovalResponse validator: `arte_must_be_pending` → aceitar `arte.pending? || arte.revised?`.

</code_context>

<specifics>
## Specific Ideas

- Botão "Aprovar" com bg-[#10B981] (verde) e botão "Pedir Alteração" com bg-[#EF4444] (vermelho) — cores semânticas claras para o cliente.
- Formulário de comentário expande com transição suave (Stimulus toggle + CSS transition) — não é necessário JavaScript manual.
- Histórico com linha do tempo simples: ícone de check (aprovado) ou X (alteração) + data + comentário — visual limpo.
- Botão "Marcar como Revisada" no admin em `show.html.erb` da arte, só visível quando `arte.change_requested?`.

</specifics>

<deferred>
## Deferred Ideas

- **Painel do admin com todas as respostas** — Fase 6 (PAIN-01 a PAIN-05).
- **Notificações por email/WhatsApp** — Out of scope v1.
- **Aprovação inline na grade do calendário** — v2; botões na grade adicionam complexidade sem ganho claro para v1.
- **Comentário obrigatório para pedido de alteração** — rejeitado; D-04 define como opcional para reduzir fricção do cliente.

</deferred>

---

*Phase: 5-approval-flow*
*Context gathered: 2026-05-26*
