# Phase 17: Cable Foundation + Admin Channel + Badge + Toast - Pattern Map

**Mapped:** 2026-06-05
**Files analyzed:** 10 (7 novos + 3 modificados)
**Analogs found:** 9 / 10

---

## File Classification

| Novo/Modificado | Role | Data Flow | Analog mais próximo | Qualidade |
|-----------------|------|-----------|---------------------|-----------|
| `app/channels/application_cable/connection.rb` | middleware | request-response | `app/channels/application_cable/connection.rb` (o próprio) | exact (modificar) |
| `app/channels/application_cable/channel.rb` | middleware | — | nenhum (arquivo ausente no projeto) | sem analog |
| `app/channels/admin_notifications_channel.rb` | channel | event-driven | `app/channels/application_cable/connection.rb` | role-partial |
| `app/javascript/controllers/toast_controller.js` | controller (Stimulus) | event-driven | `app/javascript/controllers/modal_controller.js` | role-match |
| `app/views/layouts/admin.html.erb` | layout | request-response | `app/views/layouts/admin.html.erb` (o próprio) | exact (modificar) |
| `app/views/admin/shared/_sidebar.html.erb` | component (partial) | request-response | `app/views/admin/shared/_sidebar.html.erb` (o próprio) | exact (modificar) |
| `test/channels/application_cable/connection_test.rb` | test | request-response | `test/controllers/admin/approvals_controller_test.rb` | role-partial |
| `test/channels/admin_notifications_channel_test.rb` | test | event-driven | `test/controllers/admin/approvals_controller_test.rb` | role-partial |
| `test/fixtures/clients.yml` | fixture | — | `test/fixtures/users.yml` | role-match |
| `test/fixtures/sessions.yml` | fixture | — | `test/fixtures/users.yml` | role-match |

---

## Pattern Assignments

### `app/channels/application_cable/connection.rb` (middleware, request-response)

**Acao:** MODIFICAR o arquivo existente — expandir para suportar dual authentication.

**Analog:** `app/channels/application_cable/connection.rb` (estado atual)

**Estado atual** (linhas 1-16):
```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end
  end
end
```

**Padrao auth expandido (target state):**
- Adicionar `:current_client` ao `identified_by`
- Manter `set_current_user` identico (linhas 10-13 existentes)
- Adicionar `set_current_client` privado apos `set_current_user`
- `connect` passa a ser: `set_current_user || set_current_client || reject_unauthorized_connection`

**Core pattern a adicionar:**
```ruby
def set_current_client
  token = request.params[:token]
  return unless token.present?
  client = Client.find_by(access_token: token, active: true)
  self.current_client = client if client
end
```

**Nota de segurança:** `Client.find_by(access_token: token, active: true)` — a condicao `active: true` rejeita clientes inativos na connection (D-03). O `request.params[:token]` e parametro de URL do handshake WebSocket (`/cable?token=abc123`).

---

### `app/channels/application_cable/channel.rb` (middleware, sem data flow)

**Acao:** CRIAR — arquivo base ausente no projeto (confirmado via `find`).

**Analog:** nenhum no projeto. Conteudo e o padrao Rails gerado automaticamente em novos apps.

**Conteudo completo (trivial — 4 linhas):**
```ruby
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
```

**Critico:** Sem este arquivo, `AdminNotificationsChannel < ApplicationCable::Channel` levanta `NameError: uninitialized constant ApplicationCable::Channel`. Deve ser Wave 0, antes de qualquer implementacao de canal.

---

### `app/channels/admin_notifications_channel.rb` (channel, event-driven)

**Acao:** CRIAR novo arquivo.

**Analog:** `app/channels/application_cable/connection.rb` (estrutura modular Ruby, padrao de verificacao de autenticacao)

**Padrao de estrutura** — herda de ApplicationCable::Channel (padrao Rails):
```ruby
class AdminNotificationsChannel < ApplicationCable::Channel
  def subscribed
    reject unless current_user          # D-17: defesa em profundidade
    stream_for current_user             # D-15: per-user stream via GlobalID
  end
end
```

**Por que `stream_for` e nao `stream_from`:** `stream_for(model)` deriva o nome do stream do GlobalID do model — nome opaco e seguro. Broadcasts de Phase 18+ devem usar `AdminNotificationsChannel.broadcast_to(user, data)` que usa o mesmo mecanismo internamente.

**Nota D-16:** `subscribed` NAO envia badge count — badge ja esta renderizado server-side no page load. Canal so transporta deltas (Phase 18+).

---

### `app/javascript/controllers/toast_controller.js` (Stimulus controller, event-driven)

**Acao:** CRIAR novo arquivo.

**Analog:** `app/javascript/controllers/modal_controller.js`

**Padrao de imports** (modal_controller.js linha 1):
```javascript
import { Controller } from "@hotwired/stimulus"
```

**Padrao de lifecycle hooks** (modal_controller.js linhas 6-10 e 65-68):
```javascript
connect() {
  this.boundKeydown = (e) => {
    if (e.key === "Escape") this.close()
  }
  // ... setup
}

disconnect() {
  document.removeEventListener("keydown", this.boundKeydown)
}
```
Mesmo padrao para toast: `connect()` inicia timer, `disconnect()` limpa timer via `clearTimeout`.

**Padrao de cleanup de event listeners** (dropdown_controller.js linhas 21-27):
```javascript
connect() {
  this.outsideClickHandler = this.hide.bind(this)
  document.addEventListener("click", this.outsideClickHandler)
}

disconnect() {
  document.removeEventListener("click", this.outsideClickHandler)
}
```
Toast usa `this._timerId` como identificador do timer — mesmo padrao de armazenar referencia na instancia.

**Core pattern do toast_controller (target state):**
```javascript
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
      toasts[0].remove()   // Remove o mais antigo (primeiro filho)
    }
  }
}
```

**Padrao de registro em index.js** — o arquivo usa `eagerLoadControllersFrom("controllers", application)` (index.js linha 3), entao `toast_controller.js` e detectado automaticamente pelo nome do arquivo — nenhuma linha extra em index.js e necessaria.

**Toast HTML esperado** (para referencia do planner — gerado por Phase 18 via Turbo Stream):
```html
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3"
     role="alert" aria-live="polite">
  <span class="text-sm text-slate-700 flex-1">Mensagem do toast</span>
  <button data-action="toast#dismiss"
          class="text-gray-400 hover:text-gray-600 text-lg leading-none"
          aria-label="Fechar">×</button>
</div>
```

---

### `app/views/layouts/admin.html.erb` (layout, request-response)

**Acao:** MODIFICAR — adicionar `turbo_stream_from` e regiao de toast.

**Analog:** `app/views/layouts/admin.html.erb` (o proprio arquivo)

**Estado atual do `<body>`** (linhas 23-46):
```erb
<body class="min-h-screen bg-gray-50 flex">
  <%= render "admin/shared/sidebar" %>
  <div class="flex-1 flex flex-col min-w-0">
    ...flash messages...
    <main class="flex-1 px-6 py-8">
      <%= yield %>
    </main>
  </div>
</body>
```

**Padrao de flash existente** (linhas 32-40) — referencia para acessibilidade do toast:
```erb
<div class="mx-6 mt-4 px-4 py-3 bg-green-50 border border-green-200 rounded-lg"
     role="alert" aria-live="assertive">
  <span class="text-green-700 text-sm"><%= notice %></span>
</div>
```
Toast usa `role="alert"` e `aria-live="polite"` (polite = nao interrompe; assertive = interrompe — D-10/D-11 nao exigem interrupcao).

**Dois itens a inserir no `<body>` — ANTES de `render "admin/shared/sidebar"` (linha 24):**

Item 1 — turbo_stream_from (D-15, com guard defensivo conforme Pitfall 3 do RESEARCH):
```erb
<%= turbo_stream_from current_user, channel: AdminNotificationsChannel if current_user %>
```

Item 2 — Toast region (D-14, D-10):
```erb
<div id="admin-toast-region"
     class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end">
</div>
```

---

### `app/views/admin/shared/_sidebar.html.erb` (component partial, request-response)

**Acao:** MODIFICAR — adicionar badge inline no link "Aprovacoes".

**Analog:** `app/views/admin/shared/_sidebar.html.erb` (o proprio arquivo)

**Estrutura atual do link nav** (linhas 23-31):
```erb
<%= link_to item[:path],
      class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{
        current_page?(item[:path]) ?
        'bg-white/20 text-white' :
        'text-white/70 hover:bg-white/10 hover:text-white'
      }" do %>
  <%= item[:label] %>
<% end %>
```

**Posicao do badge:** Calcular `badge_count` ANTES do loop `nav_items.each` (ou diretamente antes do bloco `do`). Badge e inserido DENTRO do bloco `link_to`, apos `item[:label]`, apenas quando `item[:path] == admin_approvals_path`.

**Pattern do badge** (D-05 a D-09):
```erb
<% badge_count = Arte.where(status: :change_requested).count %>
```
Dentro do bloco do link, apos `<%= item[:label] %>`:
```erb
<% if item[:path] == admin_approvals_path && badge_count > 0 %>
  <span id="sidebar-badge"
        class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full">
    <%= badge_count %>
  </span>
<% end %>
```

**Classes Tailwind consistentes com o projeto:** `bg-red-500 text-white` — identico ao badge de "Pediu Alteracao" na pagina Aprovacoes. `rounded-full` e o padrao de badge circular. `ml-auto` empurra o badge para a direita dentro do `flex items-center gap-3` existente do link.

**Performance:** `Arte.where(status: :change_requested).count` e 1 query COUNT com indice `index_artes_on_status` (verificado no schema). Executada 1x por page load — aceitavel.

---

### `test/channels/application_cable/connection_test.rb` (test, request-response)

**Acao:** CRIAR — diretorio `test/channels/application_cable/` sera criado junto.

**Analog:** `test/controllers/admin/approvals_controller_test.rb` (padrao de setup com User.create! e Client.create!)

**Padrao de setup** (approvals_controller_test.rb linhas 3-19):
```ruby
require "test_helper"

class Admin::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "admin@example.com", ...)
    sign_in_as(@user)
    @client = Client.create!(name: "Test Client", ...)
  end
```

**Heranca para testes de connection:** `ActionCable::Connection::TestCase` (nao `ActionDispatch::IntegrationTest`).

**Padrao completo do connection test:**
```ruby
require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  setup do
    @user = users(:one)
    @session = @user.sessions.create!
  end

  test "connects admin via session cookie" do
    cookies.signed[:session_id] = @session.id
    connect
    assert_equal @user, connection.current_user
    assert_nil connection.current_client
  end

  test "connects client via valid active token" do
    @client = clients(:one)
    connect params: { token: @client.access_token }
    assert_equal @client, connection.current_client
    assert_nil connection.current_user
  end

  test "rejects connection without credentials" do
    assert_reject_connection { connect }
  end

  test "rejects inactive client" do
    @client = clients(:inactive)
    assert_reject_connection { connect params: { token: @client.access_token } }
  end
end
```

**Nota:** Usa fixtures `users(:one)`, `clients(:one)`, `clients(:inactive)` — depende de `test/fixtures/clients.yml` (Wave 0 gap).

---

### `test/channels/admin_notifications_channel_test.rb` (test, event-driven)

**Acao:** CRIAR.

**Analog:** `test/controllers/admin/approvals_controller_test.rb` (padrao de require + setup)

**Heranca para testes de canal:** `ActionCable::Channel::TestCase`.

**Padrao completo do channel test:**
```ruby
require "test_helper"

class AdminNotificationsChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current user" do
    user = users(:one)
    stub_connection(current_user: user)
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for user
  end

  test "rejects subscription without current_user" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert subscription.rejected?
  end
end
```

**Nota sobre `assert_reject_subscription`:** Usar `assert subscription.rejected?` — mais explícito e confirmado compatível (Open Question 2 do RESEARCH).

---

### `test/fixtures/clients.yml` (fixture)

**Acao:** CRIAR.

**Analog:** `test/fixtures/users.yml` (padrao de fixture com ERB para digest)

**Estado do analog** (users.yml linhas 1-9):
```yaml
<% password_digest = BCrypt::Password.create("password") %>

one:
  email_address: one@example.com
  password_digest: <%= password_digest %>

two:
  email_address: two@example.com
  password_digest: <%= password_digest %>
```

**Pattern para clients.yml** — `has_secure_token :access_token` gera token automaticamente se nil; `has_secure_password` precisa de `password_digest`:
```yaml
<% password_digest = BCrypt::Password.create("password") %>

one:
  name: Client One
  password_digest: <%= password_digest %>
  active: true

two:
  name: Client Two
  password_digest: <%= password_digest %>
  active: true

inactive:
  name: Inactive Client
  password_digest: <%= password_digest %>
  active: false
```

**Nota:** `access_token` e gerado automaticamente pelo `has_secure_token` callback do model — nao precisa ser definido na fixture. O Rails chama o callback antes de inserir o registro de fixture.

---

### `test/fixtures/sessions.yml` (fixture)

**Acao:** CRIAR.

**Analog:** `test/fixtures/users.yml`

**Inspecao do model Session** — sessions pertencem a users via `belongs_to :user`. Fixture precisa apenas referenciar o user:
```yaml
one:
  user: one
```

**Nota:** Fixtures de session podem ser necessarias para o connection test ou podem ser criadas inline com `@user.sessions.create!` no `setup` do teste. A abordagem inline (como usado em `approvals_controller_test.rb` linha 8 com `sign_in_as(@user)`) e mais flexivel para testes de connection. Criar `sessions.yml` minimo garante que `fixtures :all` no `test_helper.rb` nao falhe se a tabela existir.

---

## Shared Patterns

### Padrao de autenticacao no layout admin
**Fonte:** `app/views/layouts/admin.html.erb`
**Aplica a:** `admin.html.erb` (modificacao), e qualquer partial que precise de `current_user`
**Padrao:** O layout admin ja garante autenticacao via `Authentication` concern no controller — `current_user` e sempre presente quando o layout renderiza. Guard defensivo `if current_user` no `turbo_stream_from` e adicional (Pitfall 3 do RESEARCH).

### Padrao de Stimulus controller lifecycle
**Fonte:** `app/javascript/controllers/modal_controller.js` (linhas 6-10, 65-68) e `app/javascript/controllers/dropdown_controller.js` (linhas 21-27)
**Aplica a:** `toast_controller.js`
**Padrao:** Sempre armazenar referencia de callback/timer na instancia (`this._timerId`, `this.boundKeydown`, `this.outsideClickHandler`). Sempre limpar no `disconnect()`. Usar arrow functions `() => this.method()` para preservar contexto.

### Padrao de registro automatico de Stimulus controllers
**Fonte:** `app/javascript/controllers/index.js` (linha 3)
**Aplica a:** `toast_controller.js`
**Padrao:** `eagerLoadControllersFrom("controllers", application)` detecta todos os arquivos `*_controller.js` automaticamente. Nenhuma linha extra em `index.js` e necessaria — apenas criar o arquivo com o nome correto.

### Padrao de teste com fixtures vs inline create
**Fonte:** `test/controllers/admin/approvals_controller_test.rb` (linhas 6-18)
**Aplica a:** `connection_test.rb`, `admin_notifications_channel_test.rb`
**Padrao atual do projeto:** `User.create!`, `Client.create!` inline no `setup` (sem fixtures). Para testes de canal, `stub_connection` requer o objeto em si — tanto fixtures quanto inline funcionam. Usar fixtures quando o objeto tem atributos fixos relevantes para o teste (ex: `active: false`).

### Padrao de acessibilidade para alertas
**Fonte:** `app/views/layouts/admin.html.erb` (linhas 32-40)
**Aplica a:** HTML dos toasts individuais (gerados nas phases seguintes)
**Padrao:** `role="alert"` + `aria-live="polite"` (toasts) ou `aria-live="assertive"` (flash critico). Flash atual usa `assertive` — toasts usam `polite` (nao interrompe leitores de tela).

---

## No Analog Found

| Arquivo | Role | Data Flow | Razao |
|---------|------|-----------|-------|
| `app/channels/application_cable/channel.rb` | base class | — | Nenhum canal existe no projeto. Arquivo e o boilerplate padrao do Rails — gerado automaticamente em `rails new` mas ausente aqui. Conteudo e trivial (classe vazia que herda de `ActionCable::Channel::Base`). |

---

## Metadata

**Scope de busca de analogs:** `app/channels/`, `app/javascript/controllers/`, `app/views/layouts/`, `app/views/admin/shared/`, `test/controllers/`, `test/fixtures/`
**Arquivos escaneados:** 14 arquivos lidos diretamente
**Data de extracao de padroes:** 2026-06-05
