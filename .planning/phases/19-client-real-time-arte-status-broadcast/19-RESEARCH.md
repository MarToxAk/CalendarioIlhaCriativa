# Phase 19: Client Real-time + Arte Status Broadcast — Research

**Researched:** 2026-06-06
**Domain:** ActionCable / Turbo Streams — broadcast bidirecional do model Arte para cliente e admin
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Trigger via `after_update_commit(if: -> { saved_change_to_status? && revised? })` no model `Arte`. Lógica em método privado `broadcasts_revised_to_all`.
- **D-02:** Um único método `broadcasts_revised_to_all` dispara para os dois destinos: `ClientCalendarChannel` (cliente) + `AdminNotificationsChannel` (badge do admin).
- **D-03:** Novo `ClientCalendarChannel` com `stream_for current_client`. Simétrico ao `AdminNotificationsChannel`.
- **D-04:** Canal guarda `current_client` presente (`reject unless current_client`).
- **D-05:** Chip da arte ganha `id: dom_id(arte, "calendar_chip")` e é extraído para `app/views/client/home/_arte_calendar_chip.html.erb`. Broadcast faz `replace` cirúrgico.
- **D-06:** Faixa de resumo ganha `id="calendar-summary"` e é extraída para `app/views/client/home/_calendar_summary.html.erb`. Broadcast faz `replace` com contagens recalculadas server-side.
- **D-07:** Se cliente está em mês diferente do da arte revisada, replaces falham silenciosamente — comportamento aceitável.
- **D-08:** `turbo_stream_from @client, channel: ClientCalendarChannel` no `layouts/client.html.erb` com guard `if @client`.
- **D-09:** Toast region `id="client-toast-region"` no layout do cliente. Reutiliza `toast_controller.js` existente. Zero JavaScript novo.
- **D-10:** `broadcasts_revised_to_all` também faz `replace` do `#sidebar-badge` via `AdminNotificationsChannel.broadcast_to(User.first, ...)`. Completa ciclo RTUP-01.

### Claude's Discretion

- Nome do partial do toast do cliente: `app/views/client/shared/_arte_revised_toast.html.erb`
- ID do chip: `dom_id(arte, "calendar_chip")` → `"arte_42_calendar_chip"`
- Ordem dos Turbo Streams no broadcast para o cliente: (1) replace chip → (2) replace faixa de resumo → (3) append toast
- Toast content do cliente: "Arte revisada" + título/data da arte + link para `client_arte_path`

### Deferred Ideas (OUT OF SCOPE)

- Chips do calendário admin em tempo real — Phase 20
- Toast no cliente quando admin cria nova arte — fora do escopo do v1.5
- Presença online / indicador de "admin está revisando"

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RTUP-05 | Célula do calendário do cliente atualiza em tempo real quando admin marca arte como revisada (badge de status muda) | `ClientCalendarChannel.broadcast_to` + `replace` do `#arte_<id>_calendar_chip` via partial `_arte_calendar_chip.html.erb` |
| RTUP-06 | Faixa de resumo de status no topo do calendário do cliente atualiza em tempo real quando arte muda de status | `replace` do `#calendar-summary` via partial `_calendar_summary.html.erb` com contagens recalculadas |
| RTUP-07 | Cliente recebe toast no calendário quando arte é revisada pelo admin | `append` ao `#client-toast-region` via partial `_arte_revised_toast.html.erb` + `toast_controller.js` existente |
| RTUP-01 (decremento) | Badge no sidebar do admin decrementa quando admin marca arte como revisada | `AdminNotificationsChannel.broadcast_to(User.first, ...)` com `replace` do `#sidebar-badge` usando `Arte.change_requested.count` |

</phase_requirements>

---

## Summary

A Phase 19 estende a infraestrutura ActionCable do projeto (já operacional desde a Phase 17/18) para o lado do cliente. Quando `Arte#revised!` é chamado em `mark_revised`, um `after_update_commit` no model `Arte` dispara `broadcasts_revised_to_all` — método privado que faz dois broadcasts simultâneos: um para o `ClientCalendarChannel` do cliente dono da arte (3 Turbo Streams: replace do chip, replace do resumo, append do toast) e um para `AdminNotificationsChannel` do admin (1 Turbo Stream: replace do badge com contagem decrementada).

Toda a infraestrutura necessária já existe no projeto: o `ApplicationCable::Connection` já autentica cliente via `params[:token]`, o `AdminNotificationsChannel` serve como template exato para o novo `ClientCalendarChannel`, o `toast_controller.js` já funciona com auto-dismiss e dismiss manual, e os partials do badge do admin já estão preparados para replace. O trabalho se resume a: criar o canal, adicionar o callback no model, extrair dois partials do cliente com DOM IDs, criar o toast partial do cliente, e atualizar o layout do cliente.

Há um pitfall relevante de JavaScript: `toast_controller.js` hardcoda `document.getElementById("admin-toast-region")` no método `_enforceLimit()`. No contexto do layout do cliente (onde o region é `client-toast-region`), esse `getElementById` retorna `null` e o método faz return silenciosamente — o auto-dismiss de 5s ainda funciona, mas o limite de 3 toasts não se aplica ao cliente. O CONTEXT.md instrui "zero JavaScript novo" e o comportamento é aceitável, mas deve ser documentado explicitamente no plano para que o verificador saiba não testar o limite de 3 toasts no cliente.

**Primary recommendation:** Seguir o padrão `ApprovalResponse#broadcasts_to_admin` (Phase 18) como template direto — estrutura de `render_partial_html` + `turbo_stream_tag` + `broadcast_to` é idêntica; apenas o canal, os targets e os partials diferem.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Trigger do broadcast | Model (`Arte`) | — | `after_update_commit` vive no model; simétrico com `ApprovalResponse` |
| Canal do cliente | ActionCable (`ClientCalendarChannel`) | — | Stream scoped por `current_client`; autenticação via token |
| Replace do chip de arte | Browser (Turbo Stream receiver) | Server (partial render) | Server renderiza HTML, browser aplica via Turbo |
| Replace da faixa de resumo | Browser (Turbo Stream receiver) | Server (partial render) | Contagens recalculadas server-side; browser aplica replace |
| Toast do cliente | Browser (`toast_controller.js`) | Server (partial render) | Server faz append do HTML, Stimulus gerencia lifecycle |
| Decremento do badge admin | AdminNotificationsChannel | Arte model | Broadcast do badge já existe (Phase 18 incremento); decremento usa mesmo canal/partial |
| Assinatura do canal | Layout (`client.html.erb`) | — | `turbo_stream_from` no layout garante subscrição em todas as páginas do cliente |

---

## Standard Stack

### Core (tudo já instalado — zero pacotes novos)

| Componente | Versão | Propósito | Status |
|-----------|--------|-----------|--------|
| ActionCable | Rails 8.1.3 (built-in) | WebSocket — canal `ClientCalendarChannel` | Já instalado |
| `@hotwired/turbo-rails` | importmap | Turbo Streams over cable | Já instalado |
| `@hotwired/stimulus` | importmap | `toast_controller.js` — lifecycle de toast | Já instalado |
| solid_cable | gem | Adapter PostgreSQL para ActionCable (sem Redis) | Já instalado; produção usa `solid_cable` |

**Nenhum pacote novo é necessário nesta fase.** [VERIFIED: codebase grep]

### Package Legitimacy Audit

> Não aplicável — esta fase não instala pacotes externos.

---

## Architecture Patterns

### Fluxo de dados — broadcast revisada

```
Admin clica "Marcar como Revisada"
         |
         v
Admin::ArtesController#mark_revised
  @arte.revised!   (enum transition via ActiveRecord)
         |
         v
Arte#after_update_commit  (if: saved_change_to_status? && revised?)
  -> broadcasts_revised_to_all
         |
         +---> ClientCalendarChannel.broadcast_to(@arte.client, turbo_streams_html)
         |           |
         |           v
         |     Cliente recebe 3 Turbo Streams:
         |       1. replace #arte_<id>_calendar_chip  -> _arte_calendar_chip.html.erb
         |       2. replace #calendar-summary         -> _calendar_summary.html.erb
         |       3. append  #client-toast-region      -> _arte_revised_toast.html.erb
         |
         +---> AdminNotificationsChannel.broadcast_to(User.first, turbo_stream_html)
                     |
                     v
               Admin recebe 1 Turbo Stream:
                 replace #sidebar-badge -> _sidebar_badge.html.erb (contagem decrementada)
```

### Estrutura de arquivos — novos / modificados

```
app/
├── channels/
│   └── client_calendar_channel.rb           # NOVO
├── models/
│   └── arte.rb                              # MODIFICAR — after_update_commit + broadcasts_revised_to_all
├── views/
│   ├── layouts/
│   │   └── client.html.erb                  # MODIFICAR — turbo_stream_from + client-toast-region
│   └── client/
│       ├── home/
│       │   ├── index.html.erb               # MODIFICAR — extrair faixa de resumo para partial
│       │   ├── _month_calendar.html.erb     # MODIFICAR — extrair link_to arte para partial
│       │   ├── _arte_calendar_chip.html.erb # NOVO
│       │   └── _calendar_summary.html.erb  # NOVO
│       └── shared/
│           └── _arte_revised_toast.html.erb # NOVO
test/
└── channels/
    └── client_calendar_channel_test.rb      # NOVO
```

### Pattern 1: ClientCalendarChannel — simétrico ao AdminNotificationsChannel

**What:** Canal ActionCable para o cliente, autenticado via `current_client` (já disponível na connection).
**When to use:** Qualquer broadcast destinado especificamente ao cliente dono de uma arte.

```ruby
# app/channels/client_calendar_channel.rb
# Source: padrão do app/channels/admin_notifications_channel.rb (codebase)
class ClientCalendarChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_client
    stream_for current_client
  end
end
```

**Nota:** `reject_unauthorized_connection` foi considerado mas `reject` (sem underscore no começo) é o método correto do `ActionCable::Channel::Base`. [VERIFIED: codebase — `AdminNotificationsChannel` usa `reject unless current_user`]

### Pattern 2: after_update_commit condicional no model Arte

**What:** Callback disparado somente quando `status` muda para `revised`.

```ruby
# app/models/arte.rb — acrescentar após os validates
# Source: ApprovalResponse#after_create_commit (codebase Phase 18)
after_update_commit :broadcasts_revised_to_all,
  if: -> { saved_change_to_status? && revised? }

private

def broadcasts_revised_to_all
  admin = User.order(:id).first
  return unless admin

  badge_count          = Arte.change_requested.count
  current_month_start  = scheduled_on.beginning_of_month
  current_month_end    = scheduled_on.end_of_month

  artes_do_mes = client.artes
                       .where(scheduled_on: current_month_start..current_month_end)

  summary = {
    total:            artes_do_mes.count,
    approved:         artes_do_mes.where(status: :approved).count,
    pending:          artes_do_mes.where(status: [:pending, :revised]).count,
    change_requested: artes_do_mes.where(status: :change_requested).count
  }

  chip_html    = render_partial_html("client/home/arte_calendar_chip",  { arte: self })
  summary_html = render_partial_html("client/home/calendar_summary",    { summary: summary })
  toast_html   = render_partial_html("client/shared/arte_revised_toast",
                                     { arte: self, client: client })
  badge_html   = render_partial_html("admin/shared/sidebar_badge",      { badge_count: badge_count })

  client_streams = [
    turbo_stream_tag("replace", "#{dom_id(self)}_calendar_chip", chip_html),
    turbo_stream_tag("replace", "calendar-summary",              summary_html),
    turbo_stream_tag("append",  "client-toast-region",           toast_html)
  ].join

  admin_stream = turbo_stream_tag("replace", "sidebar-badge", badge_html)

  ClientCalendarChannel.broadcast_to(client, client_streams)
  AdminNotificationsChannel.broadcast_to(admin, admin_stream)
end

def render_partial_html(partial, locals)
  ApplicationController.render(partial: partial, locals: locals, formats: [:html])
end

def turbo_stream_tag(action, target, template_html = "")
  %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
end
```

**Observação crítica:** `dom_id(self)` dentro do model não funciona diretamente — `dom_id` é helper do ActionView. Usar `ActionView::RecordIdentifier.dom_id(self, "calendar_chip")` conforme padrão estabelecido em Phase 18 (`ApprovalResponse` usa `ActionView::RecordIdentifier.dom_id(arte_with_client)`). [VERIFIED: codebase — approval_response.rb linha 54]

O target correto é `ActionView::RecordIdentifier.dom_id(self, "calendar_chip")` → `"arte_42_calendar_chip"`.

### Pattern 3: dom_id com prefix no chip da arte

**What:** O `link_to` em `_month_calendar.html.erb` precisa de um `id` estável para o Turbo Stream `replace`.

```erb
<%# app/views/client/home/_arte_calendar_chip.html.erb — NOVO %>
<%# Locals: arte (Arte), client (Client) %>
<%= link_to client_arte_path(token: client.access_token, id: arte),
      id: dom_id(arte, "calendar_chip"),
      class: "mt-1 flex items-center gap-1 p-1 rounded bg-gray-50 hover:bg-orange-50 transition-colors" do %>
  <%= render "client/shared/platform_icon", arte: arte, size: 14 %>
  <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
<% end %>
```

**Chamada no `_month_calendar.html.erb`:**
```erb
<% artes_do_dia.each do |arte| %>
  <%= render "client/home/arte_calendar_chip", arte: arte, client: client %>
<% end %>
```

### Pattern 4: Faixa de resumo como partial com DOM ID

**What:** A `div` de resumo em `index.html.erb` precisa de `id="calendar-summary"` para receber `replace`.

```erb
<%# app/views/client/home/_calendar_summary.html.erb — NOVO %>
<%# Locals: summary (Hash com :total, :approved, :pending, :change_requested) %>
<% if summary[:total] > 0 %>
  <div id="calendar-summary" role="status" aria-label="Resumo do mês"
       class="flex flex-wrap gap-2 mb-4 justify-center">
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-slate-100 text-slate-700">
      <span class="font-semibold"><%= summary[:total] %></span> total
    </span>
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
      <span class="font-semibold"><%= summary[:approved] %></span> aprovadas
    </span>
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
      <span class="font-semibold"><%= summary[:pending] %></span> pendentes
    </span>
    <span class="px-3 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
      <span class="font-semibold"><%= summary[:change_requested] %></span> pediu alteração
    </span>
  </div>
<% end %>
```

**Observação:** Se `summary[:total] == 0`, o partial renderiza vazio. O Turbo Stream `replace` de `#calendar-summary` tentará substituir o elemento existente — se ele não estiver presente no DOM (porque `@summary[:total]` era 0 antes), o replace falha silenciosamente (padrão D-07). Isso é aceitável.

### Pattern 5: `turbo_stream_from` no layout do cliente

```erb
<%# layouts/client.html.erb — adicionar após <body> %>
<%= turbo_stream_from @client, channel: ClientCalendarChannel if @client %>
<div id="client-toast-region" class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end"></div>
```

**Guard `if @client`:** Defesa em profundidade — mesma convenção do admin (`if Current.user`). Nota: `Client::SessionsController < ClientController`, portanto `@client` é carregado via `load_client_from_token` mesmo na página de login (que é acessada com token na URL). O guard protege contra caminhos futuros inesperados onde `@client` possa ser nil. [VERIFIED: codebase — admin.html.erb linha 24 para padrão; client/sessions_controller.rb herda ClientController]

### Pattern 6: Toast do cliente

```erb
<%# app/views/client/shared/_arte_revised_toast.html.erb — NOVO %>
<%# Locals: arte (Arte), client (Client) %>
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
  <div class="flex-1 min-w-0">
    <p class="text-sm font-semibold text-slate-900">Arte revisada</p>
    <p class="text-xs text-slate-500 truncate">
      <%= arte.title.presence || arte.platform.humanize %>
      &middot;
      <%= l(arte.scheduled_on, format: :short) %>
    </p>
  </div>
  <%= link_to "Ver arte", client_arte_path(token: client.access_token, id: arte),
        class: "text-xs text-[#0F7949] font-medium hover:underline shrink-0" %>
  <button data-action="click->toast#dismiss"
          class="text-slate-400 hover:text-slate-600 shrink-0 leading-none"
          aria-label="Fechar notificação">
    &times;
  </button>
</div>
```

### Anti-Patterns to Avoid

- **`dom_id(self)` no model:** `dom_id` é helper do ActionView. Usar `ActionView::RecordIdentifier.dom_id(self, "calendar_chip")`. [VERIFIED: codebase — approval_response.rb linha 54]
- **Broadcast sem guard de `User.first`:** Se não existir admin, `User.order(:id).first` retorna `nil`. Sempre verificar `return unless admin` antes do broadcast. [VERIFIED: codebase — approval_response.rb linha 25]
- **Recalcular summary via `@artes` stale:** O broadcast do model não tem acesso ao `@artes` em memória da requisição anterior. Sempre recalcular via query fresh de `client.artes.where(scheduled_on: ...)`. [ASSUMED — comportamento padrão de callbacks ActiveRecord]
- **Sumário com `count { |a| ... }` em Ruby:** O controller usa enumeration Ruby para calcular o summary. No model, usar queries SQL (`.where(status: :approved).count`) para evitar carregar todos os registros. [ASSUMED]

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por quê |
|----------|--------------|-------------------|---------|
| Identificador DOM estável para replace | Geração manual de string ID | `ActionView::RecordIdentifier.dom_id(arte, "calendar_chip")` | Turbo convencional, já usado no projeto (Phase 18) |
| Renderização de partial fora de request | Instanciar view context manual | `ApplicationController.render(partial:, locals:, formats:)` | Padrão estabelecido — `ApprovalResponse#render_partial_html` |
| Limite de toasts | Lógica custom no servidor | `toast_controller.js` existente (`_enforceLimit` + `connect`) | Zero JS novo; auto-dismiss e dismiss manual já funcionam |
| Broadcast para canal específico | Envio direto via WebSocket | `ClientCalendarChannel.broadcast_to(client, html)` | Scoping automático por client record |

---

## Common Pitfalls

### Pitfall 1: `toast_controller.js` hardcoda `admin-toast-region`

**What goes wrong:** `_enforceLimit()` chama `document.getElementById("admin-toast-region")`. No layout do cliente, o region tem id `client-toast-region`. O método retorna `null` e faz `return` silenciosamente — o limite de 3 toasts não funciona no cliente.

**Why it happens:** `toast_controller.js` foi escrito para o admin (Phase 17) com id hardcoded.

**How to avoid:** O CONTEXT.md (D-09) instrui "zero JavaScript novo" — aceitar que `_enforceLimit` não se aplica ao cliente. O auto-dismiss de 5s funciona corretamente. Documentar explicitamente no PLAN e no VERIFICATION que "max-3 não testado no cliente".

**Warning signs:** Teste de max-3 toasts no cliente que espera o comportamento de remoção do mais antigo vai falhar.

**Alternativa simples (se aceita):** Mudar `getElementById("admin-toast-region")` para `this.element.closest('[id$="-toast-region"]')` ou `this.element.parentElement` — 1 linha de JS, elimina o hardcode. Mas isso contradiz D-09.

### Pitfall 2: `turbo_stream_from` no layout sem guard `if @client`

**What goes wrong:** A página de login do cliente (`new_client_session_path`) renderiza `layouts/client` mas `@client` é `nil`. Sem guard, `turbo_stream_from nil, channel: ClientCalendarChannel` gera `ArgumentError` ou tag inválida.

**Why it happens:** Boa prática defensiva — `Client::SessionsController < ClientController`, portanto `@client` está disponível na página de login. No entanto, se algum controller futuro usar `layouts/client` sem herdar `ClientController`, o guard previne quebra.

**How to avoid:** `<%= turbo_stream_from @client, channel: ClientCalendarChannel if @client %>` — exatamente como o admin usa `if Current.user`. [VERIFIED: codebase — admin.html.erb linha 24]

### Pitfall 3: Summary partial com `id="calendar-summary"` dentro de condicional

**What goes wrong:** O partial `_calendar_summary.html.erb` renderiza o `<div id="calendar-summary">` somente quando `summary[:total] > 0`. Se o cliente não tem artes no mês, o elemento não existe no DOM. Um Turbo Stream `replace` de `#calendar-summary` falha silenciosamente.

**Why it happens:** A condição `<% if summary[:total] > 0 %>` já existe no `index.html.erb` atual — é intencional.

**How to avoid:** Comportamento aceitável (D-07). Não colocar o `id="calendar-summary"` dentro da condicional no partial — em vez disso, colocar o `id` na `div` externa e deixar o conteúdo ser vazio quando `total == 0`. Isso garante que o elemento existe no DOM e o replace sempre funciona.

**Recomendação:** Renderizar `<div id="calendar-summary" ...>` sempre; controlar visibilidade do conteúdo interno via `if summary[:total] > 0`.

### Pitfall 4: Cálculo do summary no model vs. controller

**What goes wrong:** O controller `Client::HomeController#index` calcula `@summary` usando Ruby enumeration (`artes_do_mes.count { |a| a.status == "approved" }`). O model não tem acesso ao mesmo `@artes` em memória — precisa fazer queries novas. Se usar o mesmo padrão Ruby no model, carregará todos os registros do mês em memória.

**Why it happens:** Contextos diferentes — controller tem `@artes` já carregados; model callback não.

**How to avoid:** No model, usar queries SQL: `client.artes.where(scheduled_on: ...).where(status: :approved).count`. Mais eficiente e correto.

### Pitfall 5: `after_update_commit` vs `after_update`

**What goes wrong:** Usar `after_update` (em vez de `after_update_commit`) causa broadcast antes do commit da transação. Se a transação fizer rollback, o cliente recebeu um estado inválido.

**Why it happens:** Confusão entre callbacks de persistência.

**How to avoid:** Sempre usar `after_update_commit` para broadcasts. [VERIFIED: codebase — `ApprovalResponse` usa `after_create_commit`]

### Pitfall 6: `Arte.change_requested.count` inclui a arte recém-revisada?

**What goes wrong:** O callback `broadcasts_revised_to_all` é executado `after_update_commit`. Neste ponto, `arte.status` já é `:revised`. `Arte.change_requested.count` retorna a contagem sem incluir esta arte — comportamento correto.

**Why it happens:** Dúvida sobre timing do callback vs. estado do banco.

**How to avoid:** `after_update_commit` roda após o commit — o banco já reflete o novo status `:revised`. A query `Arte.change_requested.count` não inclui esta arte. Badge decrementado corretamente. [VERIFIED: Rails docs behavior — after_commit runs post-transaction]

---

## Code Examples

### Turbo Stream tag helper (já no projeto)

```ruby
# Source: app/models/approval_response.rb (Phase 18)
def turbo_stream_tag(action, target, template_html = "")
  %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
end
```

### render_partial_html helper (já no projeto)

```ruby
# Source: app/models/approval_response.rb (Phase 18)
def render_partial_html(partial, locals)
  ApplicationController.render(partial: partial, locals: locals, formats: [:html])
end
```

### dom_id com prefix fora de view context

```ruby
# Source: app/models/approval_response.rb linha 54 (Phase 18)
ActionView::RecordIdentifier.dom_id(arte_with_client)
# Para prefix:
ActionView::RecordIdentifier.dom_id(self, "calendar_chip")  # => "arte_42_calendar_chip"
```

### ClientCalendarChannel broadcast no model

```ruby
# Broadcast para o cliente (3 streams)
ClientCalendarChannel.broadcast_to(client, client_streams)

# Broadcast para o admin (1 stream — badge decremento)
AdminNotificationsChannel.broadcast_to(admin, admin_stream)
```

### Teste do ClientCalendarChannel (padrão da base)

```ruby
# test/channels/client_calendar_channel_test.rb
# Source: test/channels/admin_notifications_channel_test.rb (codebase)
class ClientCalendarChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current client" do
    stub_connection(current_client: clients(:one))
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for clients(:one)
  end

  test "rejects subscription without current client" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert subscription.rejected?
  end
end
```

### Teste do broadcasts_revised_to_all no ArteTest

```ruby
# test/models/arte_test.rb — acrescentar
test "revised! dispara broadcast para ClientCalendarChannel e AdminNotificationsChannel" do
  arte = Arte.create!(client: @client, scheduled_on: Date.current,
                      platform: :instagram, media_type: :image,
                      status: :change_requested,
                      external_url: "https://drive.google.com/file/test")

  client_calls = []
  admin_calls  = []

  ClientCalendarChannel.stub(:broadcast_to,      ->(c, content) { client_calls << content }) do
    AdminNotificationsChannel.stub(:broadcast_to, ->(u, content) { admin_calls  << content }) do
      arte.revised!
    end
  end

  assert_equal 1, client_calls.length
  assert_equal 1, admin_calls.length
  assert_equal 3, client_calls.first.scan(/<turbo-stream/).count,
               "Cliente deve receber 3 turbo streams: chip, summary, toast"
  assert_equal 1, admin_calls.first.scan(/<turbo-stream/).count,
               "Admin deve receber 1 turbo stream: badge decremento"
end

test "revised! nao dispara broadcast quando status nao muda para revised" do
  arte = Arte.create!(client: @client, scheduled_on: Date.current,
                      platform: :instagram, media_type: :image,
                      status: :pending,
                      external_url: "https://drive.google.com/file/test2")

  client_calls = []
  ClientCalendarChannel.stub(:broadcast_to, ->(c, content) { client_calls << content }) do
    arte.update!(title: "Novo título")
  end

  assert_empty client_calls, "Broadcast não deve ocorrer em updates sem mudança de status para revised"
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `after_update` (risco de broadcast antes do commit) | `after_update_commit` | Rails 5+ | Broadcasts só após transação confirmada |
| Broadcast com ActionCable raw | `channel.broadcast_to(record, html)` via `stream_for` | Rails 6+ Hotwire | Scoping automático por record; sem gerenciar nomes de stream manualmente |
| JavaScript manual para UI updates | Turbo Streams (`replace`, `append`) | Hotwire / Rails 7+ | Zero JS para atualizações de DOM |

---

## Runtime State Inventory

> Fase de adição de funcionalidade, não rename/refactor. Sem estado de runtime a migrar.

Nenhum estado de runtime afetado por esta fase.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest (Rails built-in) |
| Config file | `test/test_helper.rb` |
| Quick run command | `rails test test/channels/client_calendar_channel_test.rb test/models/arte_test.rb` |
| Full suite command | `rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RTUP-05 | `Arte#revised!` dispara `ClientCalendarChannel.broadcast_to` com replace do chip | Unit (model) | `rails test test/models/arte_test.rb` | Parcial — arte_test.rb existe, testes desta fase a adicionar |
| RTUP-05 | replace do `#arte_<id>_calendar_chip` gera HTML correto | Unit (model) | `rails test test/models/arte_test.rb` | Parcial |
| RTUP-06 | broadcast inclui replace do `#calendar-summary` com contagens corretas | Unit (model) | `rails test test/models/arte_test.rb` | Parcial |
| RTUP-07 | broadcast inclui append ao `#client-toast-region` | Unit (model) | `rails test test/models/arte_test.rb` | Parcial |
| RTUP-01 (decr) | broadcast inclui replace do `#sidebar-badge` com contagem decrementada | Unit (model) | `rails test test/models/arte_test.rb` | Parcial |
| D-03/D-04 | `ClientCalendarChannel` subscreve e rejeita sem `current_client` | Unit (channel) | `rails test test/channels/client_calendar_channel_test.rb` | NÃO — Wave 0 |

### Sampling Rate

- **Per task commit:** `rails test test/channels/client_calendar_channel_test.rb test/models/arte_test.rb`
- **Per wave merge:** `rails test`
- **Phase gate:** Full suite green antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/channels/client_calendar_channel_test.rb` — cobre D-03, D-04 (subscrição/rejeição)
- [ ] Novos testes em `test/models/arte_test.rb` — cobre RTUP-05, RTUP-06, RTUP-07, RTUP-01 decremento

---

## Environment Availability

> Esta fase é puramente de código/config Rails. Sem dependências externas além das já instaladas.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ActionCable | Canal `ClientCalendarChannel` | ✓ | Rails 8.1.3 built-in | — |
| solid_cable | Produção | ✓ | Instalado (config/cable.yml) | async adapter (dev/test) |
| Turbo Rails | `turbo_stream_from` tag | ✓ | importmap | — |
| Stimulus | `toast_controller.js` | ✓ | importmap | — |

**Missing dependencies with no fallback:** Nenhum.

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Sim | `current_client` via token em `ApplicationCable::Connection` — já implementado (Phase 17) |
| V3 Session Management | Não | Canal sem estado de sessão adicional |
| V4 Access Control | Sim | `reject unless current_client` no `subscribed` — canal rejeita conexões sem cliente válido |
| V5 Input Validation | Não | Nenhum input de usuário nesta fase |
| V6 Cryptography | Não | Token de acesso já existente — sem nova criptografia |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Canal sem autenticação (cliente recebe updates de outro cliente) | Spoofing / Information Disclosure | `stream_for current_client` scope o stream por record — cliente X não recebe broadcasts de cliente Y |
| Broadcast sem verificar admin existente | Denial of Service (crash) | `return unless admin` antes de qualquer broadcast |
| Token de URL exposto em logs do WebSocket | Information Disclosure | Já mitigado na Phase 17 — token é parâmetro de conexão, não de HTTP |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `summary[:pending]` inclui status `:revised` (como no controller atual) | Pattern 4 — cálculo do summary | Visual inconsistente se a definição de "pendente" mudar |
| A2 | RESOLVIDO: `Client::SessionsController < ClientController` — `@client` é definido via `load_client_from_token` em todas as páginas do cliente, incluindo login | Pitfall 2 — guard `if @client` | Guard é defesa em profundidade, não estritamente necessário hoje |
| A3 | `Arte.change_requested` é um scope gerado pelo enum `:status` | Pitfall 6 — badge count | Não é — verificar em `arte.rb`; enum `:status` com `change_requested: 2` gera `.change_requested` automaticamente |

**Nota A3:** Verificado no codebase — `enum :status, { pending: 0, approved: 1, change_requested: 2, revised: 3 }` em `app/models/arte.rb`. O scope `.change_requested` existe. [VERIFIED: codebase]

**Nota A2:** VERIFICADO no codebase — `Client::SessionsController < ClientController` (linha 1 de sessions_controller.rb). `load_client_from_token` é executado em todas as actions exceto `:new` e `:create` onde `require_client_auth` está skipped (mas `load_client_from_token` ainda roda — apenas a verificação de sessão é pulada). Portanto `@client` está disponível em todas as páginas do cliente. O guard `if @client` é defesa em profundidade válida. [VERIFIED: codebase]

---

## Open Questions

1. **Guard `if @client` no layout** — RESOLVIDO
   - What we know: `Client::SessionsController < ClientController`, `@client` é definido via `load_client_from_token` em todas as rotas do cliente.
   - Resolved: O guard `if @client` é defensivo e correto; não há risco de `@client = nil` com a estrutura atual.

2. **`Arte#title` pode ser nil?**
   - What we know: O schema não mostra validação de presença para `title`.
   - What's unclear: Se `arte.title.presence || arte.platform.humanize` é suficiente para o toast.
   - Recommendation: Usar `.presence || arte.platform.humanize` como fallback — defensivo e correto.

---

## Sources

### Primary (HIGH confidence)

- Codebase `app/models/approval_response.rb` — template completo de broadcast: `render_partial_html`, `turbo_stream_tag`, `broadcast_to` pattern [VERIFIED: codebase]
- Codebase `app/channels/admin_notifications_channel.rb` — template exato para `ClientCalendarChannel` [VERIFIED: codebase]
- Codebase `app/channels/application_cable/connection.rb` — `current_client` disponível nos canais [VERIFIED: codebase]
- Codebase `app/javascript/controllers/toast_controller.js` — confirma hardcode de `admin-toast-region` e comportamento de `_enforceLimit` [VERIFIED: codebase]
- Codebase `app/views/layouts/admin.html.erb` — padrão de `turbo_stream_from + guard + toast region` [VERIFIED: codebase]
- Codebase `test/channels/admin_notifications_channel_test.rb` — padrão de testes de canal [VERIFIED: codebase]

### Secondary (MEDIUM confidence)

- Rails docs: `after_update_commit` executa após commit da transação — broadcasts são seguros [ASSUMED — baseado em comportamento padrão do Rails Active Record]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — tudo já instalado, verificado no codebase
- Architecture: HIGH — padrão idêntico à Phase 18, verificado em código funcionando
- Pitfalls: HIGH — descobertos por análise direta do código existente (toast hardcode, guard nil)
- Testes: HIGH — padrão de testes de canal existente, template direto

**Research date:** 2026-06-06
**Valid until:** 2026-07-06 (stack estável; Rails 8.1.x sem mudanças breaking previstas)
