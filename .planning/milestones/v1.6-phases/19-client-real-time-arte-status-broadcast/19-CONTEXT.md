# Phase 19: Client Real-time + Arte Status Broadcast - Context

**Gathered:** 2026-06-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Quando o admin executa `mark_revised` em `Admin::ArtesController`, a arte muda de `:change_requested` para `:revised`. Isso dispara broadcasts para **dois destinatários simultâneos**: (1) o `ClientCalendarChannel` do cliente dono da arte — que recebe replace do chip na grade, replace da faixa de resumo e toast de notificação; e (2) o `AdminNotificationsChannel` do admin — que recebe o decremento do badge no sidebar (parte de RTUP-01 deferred da Phase 18). Tudo sem recarregar a página de nenhum dos dois lados.

</domain>

<decisions>
## Implementation Decisions

### Trigger do broadcast

- **D-01:** O broadcast é acionado por `after_update_commit(when: -> { saved_change_to_status? && revised? })` no model `Arte`. Simétrico com `ApprovalResponse#after_create_commit` (Phase 18 D-03). Lógica em método privado `broadcasts_revised_to_all` no model.
- **D-02:** Um único método dispara broadcasts para os dois destinos: `ClientCalendarChannel` (cliente) + `AdminNotificationsChannel` (badge do admin). Atomicamente consistente.

### Canal do cliente

- **D-03:** Novo `ClientCalendarChannel` com `stream_for current_client`. Simétrico com `AdminNotificationsChannel` (Phase 17). Broadcast: `ClientCalendarChannel.broadcast_to(@arte.client, ...)`.
- **D-04:** Canal guarda `current_client` presente como defesa em profundidade — mesmo padrão de `AdminNotificationsChannel` (Phase 17 D-17).

### Granularidade do replace no calendário

- **D-05:** Chip da arte (RTUP-05): o `link_to` da arte em `_month_calendar.html.erb` ganha `id: dom_id(arte, "calendar_chip")` e é extraído para partial `app/views/client/home/_arte_calendar_chip.html.erb`. Broadcast faz `replace` cirúrgico só daquele chip.
- **D-06:** Faixa de resumo (RTUP-06): a div do resumo em `index.html.erb` ganha `id="calendar-summary"` e é extraída para `app/views/client/home/_calendar_summary.html.erb`. Broadcast faz `replace` com contagens recalculadas server-side para `arte.scheduled_on.beginning_of_month`.
- **D-07:** Se o cliente está vendo um mês diferente do da arte revisada, ambos os replaces falham silenciosamente — comportamento aceitável, padrão Phase 18 D-06.

### `turbo_stream_from` e toast region no cliente

- **D-08:** `turbo_stream_from @client, channel: ClientCalendarChannel` adicionado ao `layouts/client.html.erb` com guard `if @client`. Guard garante que a tag não aparece na página de login (`@client` nil). Padrão do layout admin.
- **D-09:** Toast region do cliente: `id="client-toast-region"` no layout, mesma posição `fixed bottom-4 right-4 z-50` do admin. Reutiliza `toast_controller.js` existente (Phase 17) — auto-dismiss 5s, botão ×, max 3 toasts. Zero JavaScript novo.

### Badge admin — decremento (RTUP-01 complement)

- **D-10:** O método `broadcasts_revised_to_all` no model Arte também faz `replace` do `#sidebar-badge` via `AdminNotificationsChannel.broadcast_to(User.first, ...)`. `Arte.change_requested.count` recalculado server-authoritative (Phase 18 D-11). Este completa o ciclo de RTUP-01: Phase 18 fez o incremento, Phase 19 faz o decremento.

### Claude's Discretion

- Nome do partial do toast do cliente: `app/views/client/shared/_arte_revised_toast.html.erb`
- ID do chip: `dom_id(arte, "calendar_chip")` → gera `"arte_42_calendar_chip"` — consistente com convenção Turbo
- Ordem dos Turbo Streams no broadcast para o cliente: (1) replace chip da arte → (2) replace faixa de resumo → (3) append toast
- Toast content do cliente: "Arte revisada" + título/data da arte + link para `client_arte_path`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Canal e infraestrutura ActionCable (já implementados)

- `app/channels/application_cable/connection.rb` — `current_client` identificado via `params[:token]`; disponível em `ClientCalendarChannel`
- `app/channels/admin_notifications_channel.rb` — padrão completo a replicar para `ClientCalendarChannel` (stream_for, guard, broadcast_to)
- `app/views/layouts/admin.html.erb` — referência para onde/como adicionar `turbo_stream_from` e toast region no layout do cliente

### Model e controller do trigger

- `app/models/arte.rb` — model que recebe o `after_update_commit`; enum `status` com `:revised`; `dom_id` convenção
- `app/controllers/admin/artes_controller.rb` — action `mark_revised` que chama `@arte.revised!`; onde o callback é acionado

### Views do cliente a modificar / criar

- `app/views/layouts/client.html.erb` — adicionar `turbo_stream_from` (guard `if @client`) e `id="client-toast-region"`
- `app/views/client/home/index.html.erb` — extrair faixa de resumo para `_calendar_summary.html.erb` com `id="calendar-summary"`
- `app/views/client/home/_month_calendar.html.erb` — adicionar `id: dom_id(arte, "calendar_chip")` ao `link_to` e extrair para `_arte_calendar_chip.html.erb`
- `app/views/client/shared/_arte_status_badge.html.erb` — reutilizar dentro do novo `_arte_calendar_chip.html.erb`

### Badge admin para decremento

- `app/views/admin/shared/_sidebar.html.erb` — `span#sidebar-badge` já preparado para replace por Turbo Stream (Phase 18 D-10)
- `app/views/admin/shared/_sidebar_badge.html.erb` — partial do badge criado na Phase 18; reutilizar no broadcast de decremento

### Requisitos

- `.planning/REQUIREMENTS.md` §RTUP-01 (decremento), RTUP-05, RTUP-06, RTUP-07 — critérios de aceite desta fase
- `.planning/ROADMAP.md` Phase 19 — success criteria
- `.planning/phases/18-approvalresponse-broadcast-admin-live-rows/18-CONTEXT.md` — padrões D-06, D-10, D-11 a seguir

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/channels/admin_notifications_channel.rb` — template para `ClientCalendarChannel`: copiar estrutura `stream_for`, guard `current_user`→`current_client`, método `subscribed`/`unsubscribed`
- `app/views/admin/shared/_sidebar_badge.html.erb` — partial do badge criado na Phase 18; reutilizar no broadcast de decremento do badge admin
- `app/views/client/shared/_arte_status_badge.html.erb` — partial de badge de status; incluir no `_arte_calendar_chip.html.erb`
- `app/javascript/controllers/toast_controller.js` — Stimulus controller existente com auto-dismiss 5s, botão ×, max 3; reutilizar sem modificação
- `Arte.change_requested.count` — scope enum pronto para recalcular badge admin

### Established Patterns

- `after_update_commit(when: -> { ... })` — padrão Rails para callbacks condicionais de model
- `dom_id(record, prefix)` — gera IDs Turbo-safe como `"arte_42_calendar_chip"`
- `ApplicationController.render(partial: ..., locals: {...})` — renderização fora do contexto de request para broadcasts do model
- Visual do toast: `bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3` (Phase 17 D-10)
- Broadcast duplo: admin e cliente no mesmo método do model (D-02)

### Integration Points

- `app/models/arte.rb` → `after_update_commit` → `broadcasts_revised_to_all` → `ClientCalendarChannel.broadcast_to` + `AdminNotificationsChannel.broadcast_to`
- `layouts/client.html.erb` → `turbo_stream_from @client, channel: ClientCalendarChannel` (guard `if @client`)
- `_month_calendar.html.erb` → extrair link_to da arte → `_arte_calendar_chip.html.erb` (com DOM id)
- `client/home/index.html.erb` → extrair faixa de resumo → `_calendar_summary.html.erb` (com DOM id)

</code_context>

<specifics>
## Specific Ideas

- Estrutura esperada do `ClientCalendarChannel`:
  ```ruby
  # app/channels/client_calendar_channel.rb
  class ClientCalendarChannel < ActionCable::Channel::Base
    def subscribed
      reject_unauthorized_connection unless current_client
      stream_for current_client
    end
  end
  ```

- `after_update_commit` no model Arte:
  ```ruby
  after_update_commit :broadcasts_revised_to_all,
    if: -> { saved_change_to_status? && revised? }

  private

  def broadcasts_revised_to_all
    admin = User.first
    return unless admin

    badge_count = Arte.change_requested.count
    current_month_start = scheduled_on.beginning_of_month
    current_month_end   = scheduled_on.end_of_month
    summary = client.artes
                    .where(scheduled_on: current_month_start..current_month_end)
                    .group(:status).count
    # ... broadcast to ClientCalendarChannel + AdminNotificationsChannel
  end
  ```

- Chip com DOM id no `_month_calendar.html.erb`:
  ```erb
  <%= link_to client_arte_path(token: client.access_token, id: arte),
        id: dom_id(arte, "calendar_chip"),
        class: "mt-1 flex items-center gap-1 p-1 rounded bg-gray-50 hover:bg-orange-50 transition-colors" do %>
    <%= render "client/shared/platform_icon", arte: arte, size: 14 %>
    <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
  <% end %>
  ```

- Faixa de resumo com DOM id (em `index.html.erb`):
  ```erb
  <% if @summary[:total] > 0 %>
    <div id="calendar-summary" role="status" aria-label="Resumo do mês" class="flex flex-wrap gap-2 mb-4 justify-center">
      <%# ... chips de resumo ... %>
    </div>
  <% end %>
  ```

</specifics>

<deferred>
## Deferred Ideas

- Chips do calendário admin em tempo real — Phase 20
- Toast no cliente quando admin cria nova arte — fora do escopo do v1.5 (cliente vê ao carregar o calendário)
- Presença online / indicador de "admin está revisando" — complexidade desnecessária para o volume atual

</deferred>

---

*Phase: 19-Client-Real-time-Arte-Status-Broadcast*
*Context gathered: 2026-06-06*
