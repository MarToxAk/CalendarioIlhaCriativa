# Phase 17: Cable Foundation + Admin Channel + Badge + Toast - Research

**Researched:** 2026-06-05
**Domain:** ActionCable (Rails 8.1), Stimulus JS, Turbo Streams, sidebar badge, toast infrastructure
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**connection.rb — Autenticação multi-tipo**
- D-01: Expandir `connection.rb` para suportar ambos os tipos: admin via session cookie (`cookies.signed[:session_id]`) e cliente via URL token (`params[:token]`). Usar `identified_by :current_user, :current_client`.
- D-02: Token do cliente chega via `params[:token]` no handshake WebSocket (URL query param: `/cable?token=abc123`). `set_current_client` faz `Client.find_by(access_token: request.params[:token], active: true)`.
- D-03: Cliente com `active: false` é rejeitado na connection (não chega ao canal).
- D-04: Quando nem sessão admin nem token cliente são válidos, a conexão é rejeitada (`reject_unauthorized_connection`). Sem conexões anônimas.

**Badge no sidebar**
- D-05: Badge some completamente quando count = 0 (não mostra "0").
- D-06: Badge fica junto ao item "Aprovações" no sidebar (inline no link, à direita do label).
- D-07: Cor vermelha `bg-red-500 text-white`.
- D-08: Badge calculado server-side no render da sidebar: `Arte.where(status: :change_requested).count`. Phase 17 só renderiza — updates em tempo real chegam na Phase 18.
- D-09: ID do elemento badge: `id="sidebar-badge"`.

**Toast — Stimulus controller**
- D-10: Posição: canto inferior direito (`fixed bottom-4 right-4` via Tailwind), z-index alto.
- D-11: Auto-dismiss: 5 segundos.
- D-12: Botão de fechar manual × em cada toast (além do auto-dismiss).
- D-13: Stack de múltiplos toasts, máximo 3 visíveis. Toasts mais antigos somem primeiro. Cada toast tem timer de 5s independente.
- D-14: Região no layout admin: `id="admin-toast-region"`.

**AdminNotificationsChannel — escopo do stream**
- D-15: Stream por-usuário: `stream_for current_user`.
- D-16: Canal não envia badge count no subscribe. Badge já renderizado server-side.
- D-17: Canal verifica `current_user` presente como defesa em profundidade.

### Claude's Discretion
- Nome do arquivo do canal: `app/channels/admin_notifications_channel.rb`
- Stimulus controller: `app/javascript/controllers/toast_controller.js`
- `turbo_stream_from` no layout admin para assinar `AdminNotificationsChannel` (tag no `<body>` do admin layout, antes do sidebar)
- Badge HTML: `<span id="sidebar-badge" class="...">N</span>` dentro do link "Aprovações" — condicional `<% if count > 0 %>`
- Tamanho do badge: `text-xs font-bold`, padding pequeno (`px-1.5 py-0.5`), `rounded-full`
- Toast visual: `bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3`

### Deferred Ideas (OUT OF SCOPE)
- Broadcasts reais (toast payload, badge increment/decrement) — Phase 18
- Canal do cliente (`ClientCalendarChannel`) — Phase 19
- Chips do calendário admin em tempo real — Phase 20
- Push notifications do browser (Web Push API) — out of scope v1.5
- Contador de "não lidas" persistente no banco
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CABLE-01 | ActionCable WebSocket conecta para admin (via sessão Rails) e para cliente (via token de URL) sem erro de conexão | connection.rb expandido com `identified_by :current_user, :current_client`; `set_current_client` via `request.params[:token]`; `reject_unauthorized_connection` quando ambos nulos |
| CABLE-02 | Sidebar do admin exibe badge numérico com contagem de artes com "Pediu Alteração" não revisadas | `Arte.where(status: :change_requested).count` em `_sidebar.html.erb`; condicional `if count > 0`; `id="sidebar-badge"` para target de Turbo Stream futuro |
</phase_requirements>

---

## Summary

A Phase 17 estabelece a infraestrutura WebSocket que as phases 18–20 irão usar para broadcasts reais. O escopo é puramente fundacional: nenhum broadcast acontece nesta fase — apenas a infraestrutura deve estar corretamente wired e pronta.

O projeto já tem o ActionCable configurado com o adapter `async` (desenvolvimento) e `solid_cable` (produção via PostgreSQL). Não há Redis nem gems adicionais necessárias. A `connection.rb` existente autentica apenas admin via cookie de sessão; a Phase 17 a expande para suportar também clientes via token de URL — uma mudança cirúrgica de ~10 linhas.

O badge no sidebar é server-side puro: `Arte.where(status: :change_requested).count` executado no render do partial `_sidebar.html.erb`. O `AdminNotificationsChannel` usa `stream_for current_user` (per-user stream) para que broadcasts futuros sejam direcionados ao admin correto. O `toast_controller.js` é um novo Stimulus controller com auto-dismiss de 5s, stack de até 3 toasts e botão × — construído sobre os padrões já estabelecidos por `modal_controller.js` e `dropdown_controller.js`.

**Primary recommendation:** Começar pela `connection.rb` (foundation real), depois criar `AdminNotificationsChannel`, depois badge no sidebar, depois `toast_controller.js` + região no layout admin. Wave 0 deve criar `app/channels/application_cable/channel.rb` (ausente no projeto) e fixtures `clients.yml`/`sessions.yml` para os testes de canal.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| WebSocket authentication (admin) | API/Backend (connection.rb) | — | Cookie de sessão só é acessível server-side; validação deve ser na connection |
| WebSocket authentication (client) | API/Backend (connection.rb) | — | Token de URL lido via `request.params` no handshake; client-side nunca deve decidir autenticação |
| AdminNotificationsChannel subscription | API/Backend (channel) | — | Canal verifica `current_user` e chama `stream_for` — responsabilidade do servidor |
| Badge count calculation | API/Backend (view partial) | — | `Arte.where(status: :change_requested).count` executado server-side no render do sidebar |
| Badge DOM target | Frontend (ERB layout) | — | `id="sidebar-badge"` renderizado no HTML para Turbo Stream replace futuro |
| Toast region | Frontend (ERB layout) | — | `id="admin-toast-region"` como container fixo no layout admin |
| Toast lifecycle (show/dismiss/stack) | Frontend (Stimulus controller) | — | JavaScript DOM manipulation puro; sem round-trip ao servidor |
| turbo_stream_from subscription tag | Frontend (ERB layout) | API/Backend (channel) | Helper renderiza `<turbo-cable-stream-source>` que o JS usa para se conectar ao canal |

---

## Standard Stack

### Core (já instalado — nenhuma gem nova necessária)

| Library | Version | Purpose | Status no Projeto |
|---------|---------|---------|-------------------|
| Rails ActionCable | 8.1.3 | WebSocket server, connection, channels | Embutido no Rails — `gem "rails"` [VERIFIED: Gemfile] |
| turbo-rails | 2.0.23 | `turbo_stream_from` helper, Turbo::StreamsChannel | Instalado [VERIFIED: `bundle exec gem list`] |
| stimulus-rails | (bundled) | Stimulus JS framework, eagerLoadControllersFrom | Instalado [VERIFIED: Gemfile] |
| solid_cable | (bundled) | PostgreSQL adapter para ActionCable em produção | Instalado [VERIFIED: Gemfile + cable_schema.rb] |
| importmap-rails | (bundled) | Pin de JS modules sem bundler | Instalado [VERIFIED: Gemfile + importmap.rb] |

**Nenhum pacote novo a instalar nesta fase.** Todo o stack necessário já está presente.

---

## Package Legitimacy Audit

> Esta fase não instala nenhum pacote externo novo. Toda a stack (ActionCable, turbo-rails, stimulus-rails, solid_cable) já está instalada e verificada no Gemfile existente.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Browser (Admin)
    |
    |  HTTP Request (com cookie session_id)
    v
Admin Layout (admin.html.erb)
    |-- turbo_stream_from current_user, channel: AdminNotificationsChannel
    |     --> <turbo-cable-stream-source> element no DOM
    |-- id="admin-toast-region" (container fixo bottom-right)
    |-- render "admin/shared/_sidebar"
          |-- Arte.where(status: :change_requested).count
          |-- <span id="sidebar-badge">N</span> (se count > 0)
    |
    | WebSocket Handshake: GET /cable?... (com cookie session_id)
    v
ApplicationCable::Connection (connection.rb)
    |-- set_current_user: Session.find_by(id: cookies.signed[:session_id]).user
    |-- set_current_client: Client.find_by(access_token: params[:token], active: true)
    |-- reject_unauthorized_connection se ambos nil
    |
    v
AdminNotificationsChannel#subscribed
    |-- reject se current_user nil (defesa em profundidade)
    |-- stream_for current_user
          --> stream name: "admin_notifications_user_<id>"
    |
    v
Stream pronto para receber broadcasts (Phase 18+)
    |
    | (futuro) broadcast Turbo Stream HTML
    v
Browser: turbo-cable-stream-source executa ação
    |-- replace/append #sidebar-badge
    |-- append #admin-toast-region -> toast_controller conecta
          |-- setTimeout(5s) auto-dismiss
          |-- botão × dismiss manual
          |-- stack máx 3 (remove o mais antigo)
```

### Recommended Project Structure

```
app/
├── channels/
│   ├── application_cable/
│   │   ├── channel.rb             # CRIAR — ApplicationCable::Channel base (ausente!)
│   │   └── connection.rb          # MODIFICAR — adicionar identified_by :current_client
│   └── admin_notifications_channel.rb  # CRIAR — canal per-user
├── javascript/controllers/
│   └── toast_controller.js        # CRIAR — auto-dismiss, stack, botão ×
├── views/
│   ├── layouts/
│   │   └── admin.html.erb         # MODIFICAR — turbo_stream_from + toast-region
│   └── admin/shared/
│       └── _sidebar.html.erb      # MODIFICAR — badge inline no link "Aprovações"
test/
├── channels/                      # CRIAR — diretório
│   ├── application_cable/
│   │   └── connection_test.rb     # CRIAR — testa connect/reject
│   └── admin_notifications_channel_test.rb  # CRIAR
└── fixtures/
    ├── clients.yml                # CRIAR — ausente, necessário para testes de canal
    └── sessions.yml               # CRIAR — ausente, necessário para testes de canal
```

---

### Pattern 1: connection.rb com múltiplos identificadores

**What:** `identified_by` aceita múltiplos símbolos na mesma declaração. O método `connect` tenta cada estratégia e rejeita se ambas retornam nil.

**When to use:** Quando o mesmo servidor WebSocket precisa autenticar tipos diferentes de usuário (admin via sessão, cliente via token).

**Example:**
```ruby
# Source: Rails API — api.rubyonrails.org/classes/ActionCable/Connection/Base.html
# Source: Official Rails Guides — guides.rubyonrails.org/action_cable_overview.html
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_client

    def connect
      set_current_user || set_current_client || reject_unauthorized_connection
    end

    private

      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end

      def set_current_client
        token = request.params[:token]
        return unless token.present?
        client = Client.find_by(access_token: token, active: true)
        self.current_client = client if client
      end
  end
end
```

**Nota crítica:** `identified_by :a, :b` faz Rails criar dois `attr_accessor`s. Ambos começam como `nil`. O `connect` retorna `self.current_user` (o User encontrado ou nil); `||` garante que tenta `set_current_client` apenas se o primeiro falhou. `reject_unauthorized_connection` é chamado apenas se ambos retornam nil/falsey. [CITED: guides.rubyonrails.org/action_cable_overview.html]

---

### Pattern 2: AdminNotificationsChannel com stream per-user

**What:** Canal que herda de `ApplicationCable::Channel` e usa `stream_for` para criar um stream com nome derivado do model via GlobalID.

**When to use:** Quando broadcasts são direcionados a um usuário específico (não ao topic global). `stream_for user` gera internamente `"admin_notifications:Z2lkOi8v..."` — opaco e seguro.

**Example:**
```ruby
# Source: Rails Guides — guides.rubyonrails.org/action_cable_overview.html
# app/channels/admin_notifications_channel.rb
class AdminNotificationsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user
    stream_for current_user
  end
end
```

**Nota:** `stream_for` vs `stream_from` — use `stream_for(model)` quando broadcasts virão via `AdminNotificationsChannel.broadcast_to(user, ...)`. Use `stream_from("nome_manual")` quando o nome do stream é uma string fixa. A decisão D-15 usa `stream_for`. [CITED: guides.rubyonrails.org/action_cable_overview.html]

---

### Pattern 3: turbo_stream_from com canal customizado

**What:** Helper do turbo-rails que renderiza um `<turbo-cable-stream-source>` element que o JavaScript usa para se conectar ao canal especificado.

**When to use:** Quando se usa um canal customizado em vez do `Turbo::StreamsChannel` default.

**Example:**
```erb
<%# Source: turbo-rails gem docs — rubydoc.info/gems/turbo-rails/Turbo/StreamsHelper %>
<%# Colocar no <body> do admin layout, ANTES do render sidebar %>
<%= turbo_stream_from current_user, channel: AdminNotificationsChannel %>
```

**Como funciona:** O helper gera um stream name assinado com `Turbo.signed_stream_verifier` baseado no `current_user.to_gid_param`. O elemento DOM tem esse nome assinado como atributo. O canal recebe esse nome assinado nos params e deve verificá-lo — ou, como no caso do `AdminNotificationsChannel`, simplesmente usar `stream_for current_user` que gera o mesmo nome internamente. [CITED: guides.rubyonrails.org — turbo-rails docs]

---

### Pattern 4: Badge condicional no sidebar

**What:** ERB condicional que calcula a contagem server-side e exibe o badge apenas quando > 0.

**When to use:** Counter badge com target DOM para substituição futura via Turbo Stream.

**Example:**
```erb
<%# Source: CONTEXT.md D-08, D-09 — padrão de badge existente no projeto %>
<%# Dentro do link "Aprovações" em _sidebar.html.erb, após item[:label] %>
<% badge_count = Arte.where(status: :change_requested).count %>
<%= item[:label] %>
<% if badge_count > 0 %>
  <span id="sidebar-badge"
        class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full">
    <%= badge_count %>
  </span>
<% end %>
```

**Cuidado de performance:** A query `Arte.where(status: :change_requested).count` é executada em cada render do sidebar (toda page load no admin). Com o volume atual (dezenas de artes) é trivial — apenas 1 COUNT query com índice em `status`. O índice `index_artes_on_status` já existe no schema. [VERIFIED: schema.rb]

---

### Pattern 5: Stimulus toast_controller com múltiplos timers

**What:** Stimulus controller que gerencia um stack de toasts com auto-dismiss independente por toast.

**When to use:** Sistema de notificação em-page com dismiss automático e manual.

**Example:**
```javascript
// Source: Stimulus Reference — stimulus.hotwired.dev/reference/controllers
// Source: discuss.hotwired.dev/t/settimeout-in-stimulus/500
// app/javascript/controllers/toast_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    this._timerId = setTimeout(() => this.dismiss(), this.durationValue)
  }

  dismiss() {
    clearTimeout(this._timerId)
    this.element.remove()
  }

  disconnect() {
    clearTimeout(this._timerId)
  }
}
```

**Como o stack funciona:** Cada toast é um elemento DOM filho de `#admin-toast-region`. O container usa `flex flex-col gap-2 items-end`. Quando um novo toast é appended (Phase 18 via Turbo Stream), o `toast_controller` conecta automaticamente e inicia o timer de 5s. Para o limite de 3, a lógica de controle pode ser feita no callback do Turbo Stream ou com um `MutationObserver` no controller pai — mas a decisão D-13 (máx 3) pode ser implementada verificando `this.element.closest('#admin-toast-region').children.length` no `connect()`. [ASSUMED — lógica de limite máximo; padrão específico não encontrado em docs oficiais]

**Padrão do projeto:** O `toast_controller` segue o mesmo padrão de `modal_controller.js` (targets + lifecycle hooks `connect`/`disconnect`) e `dropdown_controller.js` (event listener cleanup). [VERIFIED: codebase]

---

### Pattern 6: Região de toast no layout admin

```erb
<%# Source: CONTEXT.md D-14 %>
<%# Em admin.html.erb, DENTRO do <body>, ANTES do render sidebar %>
<div id="admin-toast-region"
     class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end">
</div>
```

---

### Anti-Patterns to Avoid

- **Conexões anônimas no WebSocket:** Nunca deixar `connect` completar sem `current_user` ou `current_client` definido. O `reject_unauthorized_connection` deve ser a última instrução do método `connect`. [CITED: Rails Guides]
- **Verificar autenticação apenas na connection:** O canal deve ter sua própria verificação (`reject unless current_user`) como defesa em profundidade — D-17 é obrigatório, não opcional. [ASSUMED — boa prática de segurança em profundidade]
- **Usar `stream_from` com string manual quando `stream_for` é possível:** `stream_for model` é mais seguro porque o nome é derivado do GlobalID e não pode ser adivinhado por um cliente malicioso. [CITED: Rails Guides]
- **`setTimeout(this.dismiss(), 5000)` sem parênteses corretos:** Errado — executa imediatamente. Correto: `setTimeout(() => this.dismiss(), 5000)`. [CITED: discuss.hotwired.dev/t/settimeout-in-stimulus/500]
- **Não limpar timers no `disconnect()`:** Se o elemento é removido antes do timer disparar (dismiss manual), o timer continua rodando. Sempre `clearTimeout(this._timerId)` no `disconnect()`. [ASSUMED — boa prática Stimulus]
- **Colocar `turbo_stream_from` dentro do `<head>`:** O helper gera um elemento DOM customizado que precisa estar no `<body>`. [ASSUMED — comportamento esperado de custom elements HTML]
- **Calcular badge_count no controller e passar via helper:** Não necessário. A sidebar é um partial renderizado no layout — calcular inline é o padrão Rails. Extração para helper só se reutilizado em múltiplos locais.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WebSocket authentication | Custom handshake / token validation fora do connection.rb | `ActionCable::Connection::Base` + `cookies.signed` + `request.params` | Rails gerencia o upgrade HTTP→WebSocket, CSRF e cookies automaticamente |
| Per-user stream naming | String manual `"admin_notifications_#{user.id}"` | `stream_for current_user` | GlobalID garante unicidade e opacidade; `broadcast_to` usa o mesmo nome automaticamente |
| Canal do Turbo Stream | Reimplementar `Turbo::StreamsChannel` do zero | Herdar de `ApplicationCable::Channel` e usar `turbo_stream_from ... channel: AdminNotificationsChannel` | turbo-rails já fornece o elemento DOM JS e a assinatura de stream |
| Timer de dismiss | `setInterval` polling | `setTimeout` com cleanup no `disconnect()` | Mais simples, sem polling, Stimulus lifecycle garante cleanup |
| Badge counter real-time | WebSocket polling periódico | Server-side render na page load + Turbo Stream replace (Phase 18) | O badge já é correto no page load; apenas delta precisa de real-time |

**Key insight:** O ActionCable + turbo-rails já fornecem 90% da infraestrutura. Esta phase é quase toda config e wiring — não implementação de novo protocolo.

---

## Runtime State Inventory

> Esta fase não é de renomear/refatorar. Não há runtime state a migrar.

---

## Common Pitfalls

### Pitfall 1: `ApplicationCable::Channel` ausente no projeto

**What goes wrong:** `AdminNotificationsChannel < ApplicationCable::Channel` falha com `NameError: uninitialized constant ApplicationCable::Channel`.

**Why it happens:** O arquivo `app/channels/application_cable/channel.rb` não existe neste projeto — foi verificado via `find` no codebase. A Rails gera esse arquivo em apps novos, mas pode ter sido omitido aqui.

**How to avoid:** Wave 0 deve criar `app/channels/application_cable/channel.rb` com o conteúdo padrão:
```ruby
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

**Warning signs:** Erro `NameError: uninitialized constant ApplicationCable::Channel` em qualquer `rails console` ou teste que carregue o canal. [VERIFIED: codebase — arquivo ausente confirmado]

---

### Pitfall 2: Async adapter em desenvolvimento não persiste entre processos

**What goes wrong:** `Arte.change_requested!` no console não dispara broadcasts visíveis no browser em desenvolvimento.

**Why it happens:** O adapter `async` (usado em desenvolvimento) só funciona dentro do mesmo processo web. Broadcasts de `rails console` (processo separado) não chegam ao browser.

**How to avoid:** Para testar broadcasts em desenvolvimento, usar o web console (acessível via `<% console %>` em qualquer view) — ele roda dentro do processo web. Para Phase 17 especificamente isso não é problema (nenhum broadcast acontece). [CITED: cable.yml comentário no projeto]

---

### Pitfall 3: `turbo_stream_from` requer `current_user` disponível no layout

**What goes wrong:** `NoMethodError: undefined method 'to_gid_param' for nil` se `current_user` for nil quando o admin layout renderiza.

**Why it happens:** O helper chama `current_user.to_gid_param` para gerar o nome do stream assinado. Se o layout admin renderizar sem um usuário logado (ex: após logout sem redirect correto), o helper explode.

**How to avoid:** O admin layout só deve renderizar para usuários autenticados — a concern `Authentication` já faz esse redirect. Mas adicionar um guard condicional como precaução:
```erb
<%= turbo_stream_from current_user, channel: AdminNotificationsChannel if current_user %>
```
[ASSUMED — boa prática defensiva]

---

### Pitfall 4: `identified_by :current_user, :current_client` — ambos começam como nil

**What goes wrong:** `current_user` e `current_client` são nil por padrão. Código de canal que acessa `current_user.id` sem verificação levanta `NoMethodError`.

**Why it happens:** `identified_by` cria `attr_accessor`s — valores começam nil. Um admin conectado tem `current_user` definido e `current_client = nil`. Um cliente tem `current_client` definido e `current_user = nil`.

**How to avoid:** Sempre verificar antes de usar: `reject unless current_user` no início do `subscribed` do `AdminNotificationsChannel`. [CITED: Rails Guides — Action Cable Overview]

---

### Pitfall 5: `stream_for` vs `broadcast_to` devem usar o mesmo modelo

**What goes wrong:** Phase 18 chama `AdminNotificationsChannel.broadcast_to(@user, ...)` mas o canal usa `stream_for current_user` — isso funciona porque `stream_for` e `broadcast_to` usam o mesmo mecanismo GlobalID.

**Why it happens:** Não é um bug — é o comportamento correto. `stream_for(model)` e `broadcast_to(model, data)` geram o mesmo nome de stream internamente. Apenas documentar para evitar confusão.

**How to avoid:** Sempre usar `stream_for model` no canal e `broadcast_to model, data` no broadcast. Não misturar com `stream_from("nome_manual")`. [CITED: Rails Guides]

---

### Pitfall 6: Fixtures ausentes para testes de canal

**What goes wrong:** `ActionCable::Channel::TestCase` e `ActionCable::Connection::TestCase` usam `stub_connection(user: users(:admin))` que requer fixture `users.yml`. Mas `clients.yml` e `sessions.yml` não existem — `Client.create!` inline funciona mas é mais lento e inconsistente.

**Why it happens:** O projeto atual só tem `test/fixtures/users.yml`. Nunca houve testes de canal antes.

**How to avoid:** Wave 0 cria `test/fixtures/clients.yml` e `test/fixtures/sessions.yml` mínimos para os testes de canal. [VERIFIED: codebase — fixtures ausentes confirmadas]

---

## Code Examples

### connection.rb expandido (final)

```ruby
# Source: api.rubyonrails.org/classes/ActionCable/Connection/Base.html
# Source: guides.rubyonrails.org/action_cable_overview.html
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_client

    def connect
      set_current_user || set_current_client || reject_unauthorized_connection
    end

    private

      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end

      def set_current_client
        token = request.params[:token]
        return unless token.present?
        client = Client.find_by(access_token: token, active: true)
        self.current_client = client if client
      end
  end
end
```

### AdminNotificationsChannel

```ruby
# Source: guides.rubyonrails.org/action_cable_overview.html
# app/channels/admin_notifications_channel.rb
class AdminNotificationsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user
    stream_for current_user
  end
end
```

### Connection test (padrão Rails)

```ruby
# Source: api.rubyonrails.org/classes/ActionCable/Connection/TestCase.html
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "connects admin via session cookie" do
    user = users(:one)
    session = user.sessions.create!
    cookies.signed[:session_id] = session.id
    connect
    assert_equal user, connection.current_user
    assert_nil connection.current_client
  end

  test "connects client via token" do
    client = Client.create!(name: "T", password: "p", password_confirmation: "p")
    connect params: { token: client.access_token }
    assert_equal client, connection.current_client
    assert_nil connection.current_user
  end

  test "rejects connection without credentials" do
    assert_reject_connection { connect }
  end

  test "rejects inactive client" do
    client = Client.create!(name: "T", password: "p", password_confirmation: "p", active: false)
    assert_reject_connection { connect params: { token: client.access_token } }
  end
end
```

### Channel test (padrão Rails)

```ruby
# Source: api.rubyonrails.org/classes/ActionCable/Channel/TestCase.html
class AdminNotificationsChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current user" do
    user = users(:one)
    stub_connection(current_user: user)
    subscribe
    assert_has_stream_for user
  end

  test "rejects subscription without current_user" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert_reject_subscription  # ou: assert subscription.rejected?
  end
end
```

### toast_controller.js

```javascript
// Source: Stimulus Reference — stimulus.hotwired.dev/reference/controllers
// Source: discuss.hotwired.dev/t/settimeout-in-stimulus/500
import { Controller } from "@hotwired/stimulus"

const MAX_TOASTS = 3
const DISMISS_DELAY = 5000

export default class extends Controller {
  connect() {
    this._enforceLimit()
    this._timerId = setTimeout(() => this.dismiss(), DISMISS_DELAY)
  }

  dismiss() {
    clearTimeout(this._timerId)
    this.element.remove()
  }

  disconnect() {
    clearTimeout(this._timerId)
  }

  // Private
  _enforceLimit() {
    const region = document.getElementById("admin-toast-region")
    if (!region) return
    const toasts = Array.from(region.children)
    if (toasts.length > MAX_TOASTS) {
      // Remove o mais antigo (primeiro filho)
      toasts[0].remove()
    }
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Redis obrigatório para ActionCable em produção | solid_cable usa PostgreSQL (Rails 8) | Sem Redis neste projeto — já está correto |
| `stream_from "admin_#{user.id}"` (string manual) | `stream_for user` (GlobalID) | Nome opaco, mais seguro, `broadcast_to` automático |
| Devise para autenticação ActionCable | `cookies.signed[:session_id]` nativo do Rails 8 | Consistente com o auth do projeto (sem Devise) |
| `ActionCable.createConsumer()` manual no JS | `<turbo-cable-stream-source>` via `turbo_stream_from` | Declarativo no HTML; sem JS manual para se conectar ao canal |

**Não há estado deprecado a remover nesta fase.**

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Lógica de limite de máximo 3 toasts via `_enforceLimit()` no `connect()` do toast_controller | Code Examples — toast_controller.js | Pode precisar de abordagem diferente (ex: event handler no container); baixo risco — é código novo |
| A2 | Adicionar guard `if current_user` no `turbo_stream_from` no layout é boa prática | Pitfall 3 | Se omitido e o layout renderizar sem user logado, NoMethodError; baixo risco dada a concern Authentication existente |
| A3 | `clearTimeout` no `disconnect()` evita memory leaks de timers pendentes | Pattern 5 | Se não implementado, timers podem disparar em elementos já removidos; comportamento inofensivo mas desnecessário |

---

## Open Questions

1. **`turbo_stream_from` com canal customizado — signed stream name**
   - O que sabemos: `turbo_stream_from current_user, channel: AdminNotificationsChannel` gera um nome de stream assinado baseado no GlobalID do `current_user`.
   - O que é incerto: O `AdminNotificationsChannel#subscribed` usa `stream_for current_user` diretamente (não usa o `signed_stream_name` dos params). O Turbo JS conecta ao canal, mas o canal decide independentemente em qual stream subscrever. Esses dois nomes devem coincidir para que broadcasts cheguem ao cliente.
   - Recomendação: Verificar em Phase 18 que `AdminNotificationsChannel.broadcast_to(user, data)` de fato chega ao browser. Se não chegar, o canal pode precisar usar `stream_from Turbo::StreamsChannel.signed_stream_name(current_user)` em vez de `stream_for current_user`. **Teste de integração na Phase 18 resolverá isso.**

2. **`assert_reject_subscription` vs `subscription.rejected?` no channel test**
   - O que sabemos: `ActionCable::Channel::TestCase` provê `assert_has_stream`, `assert_has_stream_for`, `assert_no_streams`.
   - O que é incerto: A assertion exata para "subscribed chamou reject" pode ser `assert subscription.rejected?` ou `assert_reject_subscription` dependendo da versão Rails.
   - Recomendação: Usar `assert subscription.rejected?` — mais explícito e compatível. [MEDIUM confidence]

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | ActionCable test (adapter test), solid_cable produção | ✓ | (verificado via schema.rb / database.yml) | — |
| Rails ActionCable | connection.rb, channel | ✓ | Rails 8.1.3 (embutido) | — |
| turbo-rails | turbo_stream_from helper | ✓ | 2.0.23 | — |
| stimulus-rails | toast_controller.js | ✓ | (bundled) | — |
| solid_cable | Cable adapter produção | ✓ | (instalado via Gemfile) | — |
| `app/channels/application_cable/channel.rb` | AdminNotificationsChannel base class | **AUSENTE** | — | **CRIAR no Wave 0** |

**Missing dependencies with no fallback:**
- `app/channels/application_cable/channel.rb` — arquivo padrão Rails ausente; bloqueia `AdminNotificationsChannel`. Deve ser criado no Wave 0 antes de qualquer implementação de canal.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest (Rails padrão) |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/channels/ test/models/arte_test.rb` |
| Full suite command | `bin/rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CABLE-01 | Connection aceita admin via cookie de sessão | unit | `bin/rails test test/channels/application_cable/connection_test.rb` | ❌ Wave 0 |
| CABLE-01 | Connection aceita cliente via token válido | unit | `bin/rails test test/channels/application_cable/connection_test.rb` | ❌ Wave 0 |
| CABLE-01 | Connection rejeita sem credenciais | unit | `bin/rails test test/channels/application_cable/connection_test.rb` | ❌ Wave 0 |
| CABLE-01 | Connection rejeita cliente `active: false` | unit | `bin/rails test test/channels/application_cable/connection_test.rb` | ❌ Wave 0 |
| CABLE-01 | AdminNotificationsChannel subscreve e cria stream para current_user | unit | `bin/rails test test/channels/admin_notifications_channel_test.rb` | ❌ Wave 0 |
| CABLE-01 | AdminNotificationsChannel rejeita subscrição sem current_user | unit | `bin/rails test test/channels/admin_notifications_channel_test.rb` | ❌ Wave 0 |
| CABLE-02 | Badge renderiza com count > 0 no sidebar | integration | `bin/rails test test/controllers/admin/dashboard_controller_test.rb` | ✅ (testar `assert_select "#sidebar-badge"`) |
| CABLE-02 | Badge não renderiza quando count = 0 | integration | `bin/rails test test/controllers/admin/dashboard_controller_test.rb` | ✅ (testar ausência do elemento) |

### Sampling Rate

- **Per task commit:** `bin/rails test test/channels/`
- **Per wave merge:** `bin/rails test`
- **Phase gate:** Full suite green antes do `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `app/channels/application_cable/channel.rb` — base class ausente; bloqueia todos os canais
- [ ] `test/channels/application_cable/connection_test.rb` — cobre CABLE-01 (connection auth)
- [ ] `test/channels/admin_notifications_channel_test.rb` — cobre CABLE-01 (channel subscription)
- [ ] `test/fixtures/clients.yml` — necessário para `stub_connection(current_client:)`
- [ ] `test/fixtures/sessions.yml` — necessário para `stub_connection(current_user:)` via session

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim | `Session.find_by(id: cookies.signed[:session_id])` — autenticação existente do projeto; WebSocket herda o mesmo mecanismo |
| V3 Session Management | sim | Cookie assinado (`cookies.signed`) — Rails native; token de URL para cliente usa `Client.access_token` (has_secure_token) |
| V4 Access Control | sim | `reject_unauthorized_connection` na connection; `reject unless current_user` no canal; sem conexões anônimas |
| V5 Input Validation | sim | `request.params[:token]` — usado apenas para lookup; não inserido em queries sem sanitização (ActiveRecord parameteriza automaticamente) |
| V6 Cryptography | não | Sem crypto nova nesta fase; `has_secure_token` já usa SecureRandom no model |

### Known Threat Patterns for ActionCable + Hotwire

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| WebSocket connection sem autenticação (conexão anônima) | Elevation of Privilege | `reject_unauthorized_connection` quando ambos os identifiers são nil — D-04 |
| Token de cliente brute-force via `/cable?token=...` | Information Disclosure | `Client.find_by(access_token: ..., active: true)` — token de 24 chars via `has_secure_token` (SecureRandom); rate limiting via Rack::Attack já instalado |
| Substituição de stream name no `turbo_stream_from` | Tampering | Stream names são assinados por `Turbo.signed_stream_verifier` — cliente não consegue assinar stream de outro usuário |
| Canal subscrito por usuário não admin | Elevation of Privilege | `reject unless current_user` no `AdminNotificationsChannel#subscribed` (D-17) |
| XSS via conteúdo de toast injetado | Tampering | Toasts nesta fase são estrutura estática; Phase 18 deve fazer escape de conteúdo broadcast via `html_escape` ou Turbo Stream template server-side |

---

## Sources

### Primary (HIGH confidence)
- [Action Cable Overview — Rails Guides](https://guides.rubyonrails.org/action_cable_overview.html) — `identified_by`, `stream_for`, `reject_unauthorized_connection`, `request.params`, cookies
- [ActionCable::Connection::Base — Rails API](https://api.rubyonrails.org/classes/ActionCable/Connection/Base.html) — request object, cookies, connect method
- [ActionCable::Connection::TestCase — Rails API](https://api.rubyonrails.org/classes/ActionCable/Connection/TestCase.html) — `connect`, `assert_reject_connection`, params/cookies em testes
- [ActionCable::Channel::TestCase — Rails API](https://api.rubyonrails.org/classes/ActionCable/Channel/TestCase.html) — `stub_connection`, `subscribe`, `assert_has_stream_for`, `assert_broadcast_on`
- Codebase verificado via `find`, `grep`, `Read` — estrutura atual de arquivos, Gemfile, schema, fixtures existentes

### Secondary (MEDIUM confidence)
- [turbo-rails Turbo::StreamsChannel — GitHub](https://github.com/hotwired/turbo-rails/blob/main/app/channels/turbo/streams_channel.rb) — como `turbo_stream_from` com `:channel` option funciona
- [Turbo Streams — Hotwire Handbook](https://turbo.hotwired.dev/handbook/streams) — padrão de turbo stream broadcasting
- [setTimeout em Stimulus — Hotwire Discussion](https://discuss.hotwired.dev/t/settimeout-in-stimulus/500) — padrão correto de timer em Stimulus

### Tertiary (LOW confidence)
- WebSearch sobre múltiplos identificadores em ActionCable — confirmado pelo padrão da Rails API mas sem docs explícitos para a sintaxe `identified_by :a, :b` em uma única linha

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verificado via Gemfile, schema, gem list
- Architecture: HIGH — código existente lido, padrões Rails documentados oficialmente
- Pitfalls: MEDIUM/HIGH — pitfall 1 (ApplicationCable::Channel ausente) verificado; outros baseados em docs oficiais e comportamento conhecido do framework
- Test patterns: MEDIUM — API docs lidos, mas `assert_reject_subscription` vs `subscription.rejected?` não verificado contra a versão exata do Rails em uso

**Research date:** 2026-06-05
**Valid until:** 2026-07-05 (stack estável — Rails 8.1, turbo-rails 2.x)
