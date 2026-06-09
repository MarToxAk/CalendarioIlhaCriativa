# Phase 20: Admin Calendar Chips Real-time - Context

**Gathered:** 2026-06-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Quando o status de uma arte muda, o chip correspondente na grade do calendário admin (`app/views/admin/calendar/_calendar_grid.html.erb`) é atualizado em tempo real, sem recarregar a página. Isso fecha **RTUP-08** e é a última fase do milestone v1.5.

A infraestrutura de broadcast já existe e **não é construída nesta fase** — os dois eventos que mudam o status de uma arte já fazem `AdminNotificationsChannel.broadcast_to(admin, ...)` e o layout admin já tem o `turbo_stream_from`. Phase 20 apenas **acrescenta um turbo-stream de replace do chip** a esses broadcasts existentes e introduz um indício visual de status no chip do admin.

**Fora de escopo:** novo canal, nova conexão WebSocket, atualização de chips do cliente (Phase 19), badge do sidebar (Phases 18/19), recontagem do "+N" de overflow em tempo real.

</domain>

<decisions>
## Implementation Decisions

### Indicador visual de status no chip admin

- **D-01:** O chip do calendário admin passa a exibir um **anel/borda colorido por status**, mantendo o **fundo com a cor do cliente** (`client_color`) — a identidade do cliente é preservada e o status vira um sinal visível ao vivo. Hoje o chip é colorido só por cliente e o status existe apenas em `data-arte_status` (consumido pelo tooltip/modal do `arte-preview`). Sem este anel, a "atualização em tempo real" seria imperceptível sem hover.
- **D-02:** Cores do anel reutilizam o `STATUS_MAP` do `app/javascript/controllers/arte_preview_controller.js` (campo `color`, que é o tom saturado/acento): `approved` → `#14A958`, `change_requested` → `#EE3537`, `revised` → `#475569`.
- **D-03:** **Cobertura do anel:** apenas `approved`, `change_requested` e `revised`. `pending` = **sem anel** (estado neutro/inicial; a maioria das artes novas é pending, então um anel em tudo poluiria a grade). O surgimento do anel é, em si, o sinal de "algo mudou".

### Transições que disparam o update

- **D-04:** O chip é atualizado nas **três transições**: `approved`, `change_requested` (ambas via `ApprovalResponse#broadcasts_to_admin`, Phase 18) e `revised` (via `Arte#broadcasts_revised_to_all`, Phase 19). Os dois métodos já fazem broadcast ao admin — basta acrescentar **um turbo-stream de replace do chip** ao array de streams de cada um. Custo mínimo, cobertura completa, inclusive multi-admin / múltiplas abas.

### Granularidade do replace e overflow

- **D-05:** **Replace cirúrgico do chip** (não da célula do dia). O chip inline atual do `_calendar_grid.html.erb` é extraído para uma partial `app/views/admin/calendar/_admin_calendar_chip.html.erb`, com `id: dom_id(arte, "admin_calendar_chip")` (gera `"arte_42_admin_calendar_chip"`). O broadcast faz `<turbo-stream action="replace" target="arte_42_admin_calendar_chip">`. Simétrico com Phase 19 D-05 (chip do cliente).
- **D-06:** **Overflow:** o grid renderiza apenas `artes_do_dia.first(3)`; artes na 4ª+ posição aparecem como badge "+N" sem chip no DOM. Se uma arte em overflow muda de status, o replace mira um `dom_id` inexistente e **falha silenciosamente** — comportamento aceitável, mesma tolerância da Phase 19 D-07 (mês diferente). A recontagem do "+N" em tempo real está **fora de escopo**.
- **D-07:** **Mês diferente:** se o admin está vendo um mês que não contém a arte alterada, o replace também falha silenciosamente. Aceitável (Phase 19 D-07).

### Claude's Discretion

- Espessura/estilo exato do anel (ex.: `ring-2` Tailwind com a cor do `STATUS_MAP`, ou `border`/`outline`) — escolher o que renderiza bem no chip pequeno (`px-1 py-0.5`, `text-xs`) sem quebrar o layout do grid.
- Como expor as cores de status no lado Ruby/ERB para a partial (ex.: um helper `arte_status_ring_color(arte)` ou um hash em helper espelhando o `STATUS_MAP`). O `STATUS_MAP` em JS é a fonte de verdade das cores — manter os valores em sincronia.
- Onde renderizar a partial fora do contexto de request no broadcast: `ApplicationController.render(partial: "admin/calendar/admin_calendar_chip", locals: { arte: ... }, formats: [:html])` — mesmo padrão dos métodos existentes.
- Locals exatos da partial extraída (precisa de `arte` e `client_color`/cor do cliente; reconstruir o cálculo de `client_color` para funcionar tanto no grid quanto no broadcast do model).
- Ordem do turbo-stream do chip dentro do array de streams existente em cada broadcast.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### View e controller do calendário admin (alvo da modificação)
- `app/views/admin/calendar/_calendar_grid.html.erb` — grid do mês; o `link_to` inline do chip (linhas ~33-72) é o que será extraído para partial com `dom_id` e ganhará o anel de status
- `app/controllers/admin/calendar_controller.rb` — monta `@artes_by_date`, `@grid_dates`, `@current_month`; só os 3 primeiros por dia viram chip (`first(3)`)

### Broadcasts existentes a estender (NÃO recriar)
- `app/models/approval_response.rb` §`broadcasts_to_admin` — já faz `AdminNotificationsChannel.broadcast_to(admin, content)` com array de turbo-streams (toast, badge, dashboard row, approval row). Acrescentar o replace do chip aqui cobre `approved` + `change_requested`.
- `app/models/arte.rb` §`broadcasts_revised_to_all` (after_update_commit, guard `saved_change_to_status? && revised?`) — já faz broadcast ao admin (badge). Acrescentar o replace do chip aqui cobre `revised`. Helpers `render_partial_html` e `turbo_stream_tag` já existem nos dois models — reutilizar.
- `app/views/layouts/admin.html.erb` linha 24 — `turbo_stream_from Current.user, channel: AdminNotificationsChannel if Current.user` já presente; o admin já recebe os broadcasts em qualquer página, inclusive o calendário.

### Cores e status
- `app/javascript/controllers/arte_preview_controller.js` linhas 3-8 — `STATUS_MAP` é a fonte de verdade das cores por status (`approved` #14A958, `change_requested` #EE3537, `revised` #475569, `pending` #FFFBEB/#92400E). Reutilizar os valores `color` para o anel.
- `app/models/arte.rb` linha 23 — enum `status: { pending: 0, approved: 1, change_requested: 2, revised: 3 }`

### Requisitos e padrões a seguir
- `.planning/REQUIREMENTS.md` §RTUP-08 — critério de aceite desta fase (único requisito pendente do v1.5)
- `.planning/ROADMAP.md` Phase 20 — descrição e posição no milestone
- `.planning/phases/19-client-real-time-arte-status-broadcast/19-CONTEXT.md` — padrões D-05 (chip cirúrgico + dom_id + partial), D-07 (falha silenciosa em mês diferente), e a mecânica `turbo_stream_tag`/`render_partial_html` a espelhar
- `.planning/phases/18-approvalresponse-broadcast-admin-live-rows/18-CONTEXT.md` — padrão de broadcast ao admin via `AdminNotificationsChannel`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Arte#render_partial_html` e `Arte#turbo_stream_tag` (privados) — já existem; copiar/reutilizar a mesma mecânica em ambos os models para o stream do chip
- `ApprovalResponse#render_partial_html` e `#turbo_stream_tag` — equivalentes no outro model
- `STATUS_MAP` (JS) — paleta de status pronta; espelhar em Ruby/helper para o anel
- `client_color(client)` helper — usado no grid para a cor de fundo do chip; precisa estar acessível na partial extraída e no render do broadcast
- `ActionView::RecordIdentifier.dom_id` — já usado nos dois broadcasts para alvos de turbo-stream

### Established Patterns
- Broadcast estendendo array de turbo-streams existente: `content = [ turbo_stream_tag(...), ... ].join` → adicionar mais um elemento
- `after_update_commit(when: -> { ... })` para callbacks condicionais (Arte)
- `after_create_commit` (ApprovalResponse) dispara em toda nova resposta (approve ou change_requested)
- Replace cirúrgico por `dom_id(record, prefix)` + partial extraída (Phase 19 D-05)
- Falha silenciosa de replace quando o alvo não está no DOM (mês diferente / overflow) — Phase 19 D-07

### Integration Points
- `app/models/approval_response.rb` → `broadcasts_to_admin` → adicionar `turbo_stream_tag("replace", dom_id(arte, "admin_calendar_chip"), chip_html)`
- `app/models/arte.rb` → `broadcasts_revised_to_all` → adicionar o mesmo replace ao `admin_stream`
- `_calendar_grid.html.erb` → extrair o `link_to` do chip → `admin/calendar/_admin_calendar_chip.html.erb` (com `id: dom_id(arte, "admin_calendar_chip")` + anel de status)

</code_context>

<specifics>
## Specific Ideas

- O anel deve preservar a leitura do chip: fundo = cor do cliente (iniciais), anel = status. Os dois eixos de informação coexistem (quem + em que estado).
- `pending` permanece sem anel propositalmente — a ausência de anel comunica "ainda não houve resposta".
- Estrutura esperada (ilustrativa) do stream adicionado a cada broadcast:
  ```ruby
  chip_html = render_partial_html(
    partial: "admin/calendar/admin_calendar_chip",
    locals:  { arte: arte_with_client }
  )
  # ...
  turbo_stream_tag("replace", ActionView::RecordIdentifier.dom_id(arte_with_client, "admin_calendar_chip"), chip_html)
  ```

</specifics>

<deferred>
## Deferred Ideas

- Recontagem do badge "+N" de overflow em tempo real — fora de escopo; só os 3 chips visíveis atualizam
- Atualização ao vivo do chip quando uma arte NOVA é criada/agendada (append na célula do dia) — fora do escopo do v1.5; o admin vê ao recarregar
- Indicador de presença / "cliente está visualizando" — complexidade desnecessária para o volume atual (já deferido na Phase 19)

None — discussion stayed within phase scope (todos os itens acima são extensões futuras, não ambiguidades desta fase).

</deferred>

---

*Phase: 20-Admin-Calendar-Chips-Real-time*
*Context gathered: 2026-06-09*
