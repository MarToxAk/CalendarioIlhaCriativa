# Phase 18: ApprovalResponse Broadcast + Admin Live Rows - Context

**Gathered:** 2026-06-05
**Updated:** 2026-06-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Quando um cliente registra uma resposta de aprovação via `Client::ResponsesController#create` (model `ApprovalResponse`), o admin logado em qualquer página do painel recebe: (1) um toast imediato com cliente + decisão + link para a arte; (2) a linha da arte no Dashboard atualiza in-place com o novo status; (3) a página Aprovações recebe uma nova linha no topo da lista; e (4) o badge numérico no sidebar incrementa se a decisão for `change_requested`. Tudo via `AdminNotificationsChannel` estabelecido na Fase 17 — nenhuma nova infraestrutura de canal é necessária.

</domain>

<decisions>
## Implementation Decisions

### Trigger do broadcast

- **D-01:** O broadcast é acionado por `after_create_commit` no model `ApprovalResponse` — padrão Rails/Turbo para ActionCable. O model fica ciente do canal, mas é a convenção estabelecida com `broadcast_to`.
- **D-02:** Um **único broadcast** com múltiplos Turbo Streams envia toast + badge + row de uma vez via `AdminNotificationsChannel.broadcast_to(user, ...)`. Atomicamente consistente na UI; evita múltiplas transmissões por evento.
- **D-03:** Lógica de broadcast em **método privado direto no model** (`broadcasts_to_admin` chamado no after_create_commit). Sem concern separado — abstração prematura para o volume atual.

### Dashboard live rows (RTUP-03)

- **D-04:** RTUP-03 significa **replace in-place da linha existente da arte** no dashboard — a arte já está lá, o status muda. Não é prepend de nova linha (evita duplicata).
- **D-05:** Criar partial `app/views/admin/dashboard/_arte_dashboard_row.html.erb` que renderiza a `<tr>` com `id: dom_id(arte)`. O dashboard refatora a iteração para usar `render "arte_dashboard_row", arte: arte`. O broadcast faz `replace` desse partial.
- **D-06:** Se admin estiver com filtro ativo e a arte não estiver na DOM, Turbo Stream `replace` falha silenciosamente — comportamento aceitável para o volume atual (10–30 clientes).

### Toast content (RTUP-02)

- **D-07:** Toast mostra: **nome do cliente + badge de decisão + botão "Ver arte"** com link para `admin_arte_path(arte)`. Informação suficiente para ação imediata sem ocupar muito espaço.
- **D-08:** Toast visual sempre **branco** (`bg-white border border-gray-200 shadow-lg rounded-lg`) — padrão da Fase 17. Badge interno **vermelho** (`bg-red-100 text-red-700`) para "Pediu Alteração" e **verde** (`bg-green-100 text-green-700`) para "Aprovado". Consistente com badges já usados no projeto.
- **D-09:** Toast **sempre aparece** independente da página atual do admin — sem supressão condicional. A nova linha na página Aprovações e o toast são complementares.

### Badge DOM strategy (RTUP-01)

- **D-10:** Remover o `if badge_count > 0` condicional do sidebar. O `<span id="sidebar-badge">` é **sempre renderizado** — com classe `hidden` quando count = 0. Turbo Stream pode sempre fazer `replace` do `#sidebar-badge` sem risco de elemento ausente na DOM.
- **D-11:** A cada broadcast, o count é **recalculado do banco** via `Arte.change_requested.count` — server-authoritative. Sem risco de dessincronismo por múltiplas respostas simultâneas ou estado stale.
- **D-12:** Badge atualizado **somente quando `decision == "change_requested"`** — aprovações não incrementam o contador. Badge reflete artes que precisam de revisão, não volume total de respostas.

### Approvals page targeting (RTUP-04) — atualizado na discussão

- **D-13:** Adicionar `id="approvals-tbody"` ao `<tbody>` da tabela desktop em `app/views/admin/approvals/index.html.erb`. O broadcast faz `prepend` nesse elemento. Mobile cards (`.block.sm:hidden`) são loops separados **sem partial compartilhado** — **não atualizar mobile cards via cable**; admin em mobile verá a linha na próxima visita/reload. Aceitável: uso de ActionCable em mobile é raro neste contexto.
- **D-14:** Adicionar `id: dom_id(approval_response)` ao `<tr>` em `app/views/admin/approvals/_approval_row.html.erb`. Sem esse ID, se o admin permanecer na página Aprovações durante o broadcast e depois recarregar, a linha aparece duplicada (broadcast + server render). O `id` único previne a duplicata.

### N+1 em broadcasts_to_admin — atualizado na discussão

- **D-15:** No método `broadcasts_to_admin`, carregar a arte com cliente via `Arte.includes(:client).find(arte_id)` antes de montar os Turbo Streams. Isso substitui `self.arte` no escopo do broadcast e garante que `arte.client.name` (toast partial) e os demais acessos a `arte.client` (dashboard row partial) não disparem queries extras. O comentário da header do partial `_approval_row.html.erb` já documenta essa expectativa: "caller MUST eager-load arte: :client via joins".

### Claude's Discretion

- Nome e localização do partial do toast: `app/views/admin/shared/_approval_toast.html.erb`
- Ordem dos Turbo Streams no broadcast: (1) append toast → (2) replace sidebar-badge → (3) replace arte row no dashboard → (4) prepend row na página Aprovações
- Para RTUP-04 (Aprovações): `prepend` na `<tbody id="approvals-tbody">` da tabela usando o partial existente `_approval_row.html.erb` — reutilização direta

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ActionCable — infraestrutura Fase 17 (já implementada)

- `app/channels/application_cable/connection.rb` — autenticação dual já expandida: admin via session cookie, cliente via URL token
- `app/channels/admin_notifications_channel.rb` — canal com `stream_for current_user`; broadcast target do after_create_commit
- `app/views/layouts/admin.html.erb` — contém `turbo_stream_from Current.user, channel: AdminNotificationsChannel` e `id="admin-toast-region"` (linha 24–25)

### Models e controllers relevantes

- `app/models/approval_response.rb` — model que recebe o `after_create_commit`; enum `decision` com `:approved` e `:change_requested`; `after_create` já faz `sync_arte_status`
- `app/models/arte.rb` — enum `status` com `:change_requested`; `Arte.change_requested.count` para badge; `dom_id(arte)` para target do replace
- `app/controllers/client/responses_controller.rb` — trigger original: `ApprovalResponse.save` via `locked_arte.approval_responses.build(response_params)`

### Views a modificar / criar

- `app/views/admin/shared/_sidebar.html.erb` — remover `if badge_count > 0`; adicionar `hidden` class ao `span#sidebar-badge` quando count = 0
- `app/views/admin/dashboard/index.html.erb` — refatorar `<tr>` para usar partial `_arte_dashboard_row.html.erb` com `id: dom_id(arte)`
- `app/views/admin/approvals/index.html.erb` — adicionar `id="approvals-tbody"` ao `<tbody>` desktop; mobile cards section não é alvo de broadcast (D-13)
- `app/views/admin/approvals/_approval_row.html.erb` — adicionar `id: dom_id(approval_response)` ao `<tr>` (D-14); partial já renderiza decisão, cliente, arte, data, comentário e link
### Partials existentes para reutilização

- `app/views/admin/approvals/_approval_row.html.erb` — renderiza linha de aprovação com cliente, arte, decisão, data e link; reutilizar no broadcast de RTUP-04
- `app/views/client/shared/_arte_status_badge.html.erb` — badge de status de arte; referência para consistência visual no dashboard row

### Requisitos

- `.planning/REQUIREMENTS.md` §RTUP-01, RTUP-02, RTUP-03, RTUP-04 — critérios de aceite desta fase
- `.planning/ROADMAP.md` Phase 18 — success criteria (2s para toast, sem reload)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/admin/approvals/_approval_row.html.erb` — partial completo para linha de ApprovalResponse; reutilizável diretamente no broadcast de RTUP-04 (Aprovações page prepend)
- `Arte.change_requested.count` — scope enum pronto; usar para badge count no broadcast
- `AdminNotificationsChannel.broadcast_to(user, turbo_stream: ...)` — canal pronto para receber broadcasts do after_create_commit
- `app/views/client/shared/_arte_status_badge.html.erb` — badge de status reutilizável para o novo `_arte_dashboard_row.html.erb`

### Established Patterns

- `after_create_commit` → broadcast é o padrão Rails 8 + Turbo Streams (ex: `broadcasts_to`, `after_create_commit { AdminNotificationsChannel.broadcast_to(...) }`)
- `dom_id(record)` → gera `"arte_42"`, `"approval_response_7"` — padrão Turbo para IDs de rows
- Badge visual: `bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full` — padrão estabelecido na Fase 17 para `#sidebar-badge`
- Badges de decisão: `bg-red-100 text-red-700` (Pediu Alteração) e `bg-green-100 text-green-700` (Aprovado) — padrão da página Aprovações existente

### Integration Points

- `ApprovalResponse#after_create_commit` → chama `broadcasts_to_admin` privado → `AdminNotificationsChannel.broadcast_to(User.first, ...)` (single-admin por ora)
- `_approval_row.html.erb` precisa de `id: dom_id(approval_response)` no `<tr>` para que o broadcast de prepend na página Aprovações funcione consistentemente
- `span#sidebar-badge` no sidebar: remover condicional, adicionar toggle de `hidden` class
- Dashboard `<tr>` de arte: adicionar `id: dom_id(arte)`, extrair para partial `_arte_dashboard_row.html.erb`

</code_context>

<specifics>
## Specific Ideas

- Badge sidebar sempre presente (D-10):
  ```erb
  <span id="sidebar-badge"
        class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full <%= 'hidden' if badge_count == 0 %>">
    <%= badge_count %>
  </span>
  ```

- **D-15 — código esperado:**
  ```ruby
  def broadcasts_to_admin
    admin = User.first  # single-admin
    return unless admin

    arte_with_client = Arte.includes(:client).find(arte_id)
    badge_count = Arte.change_requested.count

    AdminNotificationsChannel.broadcast_to(admin, turbo_stream: [
      turbo_stream.append("admin-toast-region", partial: "admin/shared/approval_toast", locals: { approval_response: self, arte: arte_with_client }),
      (turbo_stream.replace("sidebar-badge", partial: "admin/shared/sidebar_badge", locals: { badge_count: badge_count }) if decision == "change_requested"),
      turbo_stream.replace(dom_id(arte_with_client), partial: "admin/dashboard/arte_dashboard_row", locals: { arte: arte_with_client }),
      turbo_stream.prepend("approvals-tbody", partial: "admin/approvals/approval_row", locals: { approval_response: self })
    ].compact)
  end
  ```

- Toast partial mínimo esperado:
  ```erb
  <%# app/views/admin/shared/_approval_toast.html.erb %>
  <div data-controller="toast" class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
    <div class="flex-1 min-w-0">
      <p class="text-sm font-semibold text-slate-900"><%= approval_response.arte.client.name %></p>
      <%= render "admin/approvals/decision_badge", approval_response: approval_response %>
    </div>
    <%= link_to "Ver arte", admin_arte_path(approval_response.arte), class: "text-xs text-[#0F7949] font-medium hover:underline shrink-0" %>
    <button data-action="click->toast#dismiss" class="text-slate-400 hover:text-slate-600 shrink-0">×</button>
  </div>
  ```

</specifics>

<deferred>
## Deferred Ideas

- Broadcasts para canal do cliente (ClientCalendarChannel) — Phase 19
- Badge decremento quando admin marca arte como revisada — Phase 19
- Chips do calendário admin em tempo real — Phase 20
- Supressão de toast quando admin já está na página destino — complexidade desnecessária para o volume atual
- Eager loading de `arte: :client` no broadcast do after_create_commit — **resolvido: D-15** (Arte.includes(:client).find(arte_id))

</deferred>

---

*Phase: 18-ApprovalResponse-Broadcast-Admin-Live-Rows*
*Context gathered: 2026-06-05*
