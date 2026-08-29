# Phase 17: Cable Foundation + Admin Channel + Badge + Toast - Context

**Gathered:** 2026-06-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Estabelecer a infraestrutura WebSocket funcional para o milestone v1.5: expandir `connection.rb` para autenticar tanto admin (session cookie) quanto cliente (URL token), criar o `AdminNotificationsChannel` com stream por-usuário, adicionar o badge numérico no item "Aprovações" do sidebar (calculado server-side no page load), e montar a região de toast + Stimulus `toast_controller` no layout admin. Nenhum broadcast real acontece nesta fase — a infraestrutura estará pronta para receber broadcasts das phases 18–20.

</domain>

<decisions>
## Implementation Decisions

### connection.rb — Autenticação multi-tipo

- **D-01:** Expandir `connection.rb` agora para suportar **ambos** os tipos de conexão: admin via session cookie (`cookies.signed[:session_id]`) e cliente via URL token (`params[:token]`). Usar `identified_by :current_user, :current_client`. Essa é a "foundation" real — phases 18–20 não precisam tocar em `connection.rb`.
- **D-02:** Token do cliente chega via `params[:token]` no handshake WebSocket (URL query param: `/cable?token=abc123`). `set_current_client` faz `Client.find_by(access_token: request.params[:token], active: true)`.
- **D-03:** Cliente com `active: false` é **rejeitado na connection** (não chega ao canal). Consistente com o bloqueio de acesso ao portal client.
- **D-04:** Quando nem sessão admin nem token cliente são válidos, a conexão é rejeitada (`reject_unauthorized_connection`). Sem conexões anônimas.

### Badge no sidebar

- **D-05:** Badge **some completamente** quando count = 0 (não mostra "0"). Padrão Gmail/GitHub/Slack — sidebar fica limpo quando não há pendências.
- **D-06:** Badge fica **junto ao item "Aprovações"** no sidebar (inline no link, à direita do label). Não é um indicador genérico no topo.
- **D-07:** Cor vermelha **`bg-red-500 text-white`** — consistente com os badges de "Pediu Alteração" já usados na página Aprovações (`red-500`/`red-600`).
- **D-08:** Badge calculado server-side no render da sidebar: `Arte.where(status: :change_requested).count`. Phase 17 só renderiza — updates em tempo real chegam na Phase 18.
- **D-09:** ID do elemento badge: `id="sidebar-badge"` — target para Turbo Stream replace/remove nas phases seguintes.

### Toast — Stimulus controller

- **D-10:** Posição: **canto inferior direito** (`fixed bottom-4 right-4` via Tailwind), z-index alto para ficar acima do conteúdo.
- **D-11:** Auto-dismiss: **5 segundos** após o toast aparecer.
- **D-12:** Botão de fechar manual **×** em cada toast (além do auto-dismiss). Acessibilidade.
- **D-13:** Comportamento com múltiplos toasts: **stack** (empilha), máximo 3 visíveis simultaneamente. Toasts mais antigos somem primeiro quando o máximo é atingido. Cada toast tem seu próprio timer de 5s independente.
- **D-14:** Região no layout admin: `id="admin-toast-region"` — target para Turbo Stream append das phases seguintes. Posição fixed, sem interferir no fluxo da página.

### AdminNotificationsChannel — escopo do stream

- **D-15:** Stream **por-usuário**: `stream_for current_user` (gera internamente `"admin_notifications_#{user.id}"`). Mais seguro para eventual multi-admin no futuro; custo zero com single-admin atual.
- **D-16:** Canal **não** envia badge count no subscribe. Badge já está renderizado server-side no page load — cable só envia deltas de mudança (Phase 18+).
- **D-17:** Canal verifica `current_user` presente como **defesa em profundidade**: `reject_unauthorized_connection unless current_user`. Não confia exclusivamente na connection.

### Claude's Discretion

- Nome do arquivo do canal: `app/channels/admin_notifications_channel.rb`
- Stimulus controller: `app/javascript/controllers/toast_controller.js`
- `turbo_stream_from` no layout admin para assinar `AdminNotificationsChannel` (tag no `<body>` do admin layout, antes do sidebar)
- Badge HTML: `<span id="sidebar-badge" class="...">N</span>` dentro do link "Aprovações" — condicional `<% if count > 0 %>`
- Tamanho do badge: `text-xs font-bold`, padding pequeno (`px-1.5 py-0.5`), `rounded-full`
- Toast visual: `bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3` — mesmo padrão de card usado no projeto

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ActionCable — infraestrutura existente
- `app/channels/application_cable/connection.rb` — arquivo a ser expandido: adicionar `identified_by :current_client`, `set_current_client` via `params[:token]`
- `config/cable.yml` — adapter async (dev), solid_cable + PostgreSQL (prod); verificar se dev precisa de ajuste para testes locais

### Sidebar e layout admin
- `app/views/admin/shared/_sidebar.html.erb` — nav items existentes; badge vai inline no link "Aprovações"
- `app/views/layouts/admin.html.erb` — adicionar `turbo_stream_from` e `id="admin-toast-region"` neste arquivo

### Models relevantes
- `app/models/arte.rb` — `Arte.where(status: :change_requested).count` para badge count; enum `status` com `:change_requested`
- `app/models/client.rb` — `has_secure_token :access_token`, campo `active: boolean` em `clients` table (schema.rb:76)

### Requisitos
- `.planning/REQUIREMENTS.md` §CABLE-01, CABLE-02 — critérios de aceite da infraestrutura cable e badge

### Patterns de Stimulus existentes (referência para toast_controller)
- `app/javascript/controllers/modal_controller.js` — padrão de controller Stimulus com show/hide
- `app/javascript/controllers/dropdown_controller.js` — padrão de toggle e outside-click

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Arte.change_requested` — scope enum disponível (`Arte.where(status: :change_requested).count` ou `Arte.change_requested.count`)
- Flash messages no admin layout — padrão `role="alert"` e `aria-live="assertive"` reutilizável como referência para toast (mesma semântica de acessibilidade)
- Stimulus controllers existentes: seguem o padrão `{name}_controller.js`, registrados via `index.js` com importmap

### Established Patterns
- Tailwind utility classes (`bg-red-500`, `text-white`, `rounded-full`) — padrão de badges no projeto (página Aprovações)
- `flex items-center gap-3` — padrão dos nav items no sidebar; badge vai `ml-auto` dentro do `<a>`
- Connection.rb já usa `Session.find_by(id: cookies.signed[:session_id])` — padrão Rails 8 nativo (sem Devise)

### Integration Points
- `app/channels/application_cable/connection.rb` — expandir `identified_by` e adicionar `set_current_client` privado
- `app/views/layouts/admin.html.erb` — body tag: adicionar `turbo_stream_from` e toast-region antes do `render "admin/shared/sidebar"`
- `app/views/admin/shared/_sidebar.html.erb` — inline badge no link "Aprovações" (item index 1 no array `nav_items`)
- `app/javascript/controllers/index.js` — registrar `toast_controller`

</code_context>

<specifics>
## Specific Ideas

- Badge inline no sidebar (padrão esperado):
  ```erb
  <% badge_count = Arte.where(status: :change_requested).count %>
  <%# ... dentro do link "Aprovações" ... %>
  <%= item[:label] %>
  <% if badge_count > 0 %>
    <span id="sidebar-badge"
          class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full">
      <%= badge_count %>
    </span>
  <% end %>
  ```

- Toast region no admin layout (antes do sidebar, dentro do body):
  ```erb
  <div id="admin-toast-region"
       class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end">
  </div>
  ```

- WebSocket connection para cliente (Phase 19 usará):
  ```js
  ActionCable.createConsumer('/cable?token=' + clientToken)
  ```
  (Admin usa `ActionCable.createConsumer('/cable')` — sem token, usa cookie de sessão)

- `turbo_stream_from` no admin layout assina o AdminNotificationsChannel:
  ```erb
  <%= turbo_stream_from current_user, channel: AdminNotificationsChannel %>
  ```

</specifics>

<deferred>
## Deferred Ideas

- Broadcasts reais (toast payload, badge increment/decrement) — Phase 18
- Canal do cliente (`ClientCalendarChannel`) — Phase 19
- Chips do calendário admin em tempo real — Phase 20
- Push notifications do browser (Web Push API) — out of scope v1.5
- Contador de "não lidas" persistente no banco — badge calculado dinamicamente é suficiente

</deferred>

---

*Phase: 17-Cable-Foundation-Admin-Channel-Badge-Toast*
*Context gathered: 2026-06-05*
