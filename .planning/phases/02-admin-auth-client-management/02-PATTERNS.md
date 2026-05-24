# Phase 2: Admin Auth + Client Management - Pattern Map

**Mapped:** 2026-05-24
**Files analyzed:** 10
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `app/views/layouts/admin.html.erb` | layout | request-response | `app/views/layouts/application.html.erb` | exact |
| `app/controllers/admin/base_controller.rb` | controller (base) | request-response | `app/controllers/admin/base_controller.rb` (modify) | exact |
| `app/controllers/admin/clients_controller.rb` | controller | CRUD | `app/controllers/passwords_controller.rb` | role-match |
| `app/views/admin/clients/index.html.erb` | view | CRUD | `app/views/admin/dashboard/index.html.erb` | partial |
| `app/views/admin/clients/show.html.erb` | view | request-response | `app/views/sessions/new.html.erb` | partial |
| `app/views/admin/clients/new.html.erb` | view | CRUD | `app/views/sessions/new.html.erb` | role-match |
| `app/views/admin/clients/edit.html.erb` | view | CRUD | `app/views/sessions/new.html.erb` | role-match |
| `app/views/admin/clients/_*.html.erb` (partials) | view/component | request-response | `app/views/sessions/new.html.erb` | partial |
| `app/views/admin/shared/_sidebar.html.erb` | view/partial | request-response | `app/views/sessions/new.html.erb` | partial |
| `db/migrate/XXXXXX_add_password_plain_to_clients.rb` | migration | CRUD | `db/migrate/20260524215205_create_clients.rb` | exact |
| `app/javascript/controllers/copy_controller.js` | Stimulus controller | event-driven | `app/javascript/controllers/password_toggle_controller.js` | exact |
| `app/javascript/controllers/dropdown_controller.js` | Stimulus controller | event-driven | `app/javascript/controllers/password_toggle_controller.js` | exact |
| `app/javascript/controllers/modal_controller.js` | Stimulus controller | event-driven | `app/javascript/controllers/password_toggle_controller.js` | exact |
| `app/javascript/controllers/password_toggle_controller.js` | Stimulus controller | event-driven | already exists — **do not recreate** | — |

---

## Pattern Assignments

### `app/views/layouts/admin.html.erb` (layout, request-response)

**Analog:** `app/views/layouts/application.html.erb`

**Full file to copy and adapt** (lines 1–26):
```erb
<!DOCTYPE html>
<html lang="pt-BR">
  <head>
    <title><%= content_for(:title) || "Ilha Criativa" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Ilha Criativa">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <%= yield %>
  </body>
</html>
```

**Adaptation required — replace `<body>` block with sidebar + topbar layout:**
```erb
<body class="min-h-screen bg-gray-50 flex">
  <%= render "admin/shared/sidebar" %>
  <div class="flex-1 flex flex-col min-w-0">
    <%# Topbar %>
    <header class="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6">
      <h1 class="text-base font-semibold text-slate-900"><%= content_for(:page_title) || "Admin" %></h1>
      <%# Avatar + Sair %>
    </header>
    <%# Flash messages %>
    <% if notice = flash[:notice] %>
      <div class="mx-6 mt-4 px-4 py-3 bg-green-50 border border-green-200 rounded-lg" role="alert" aria-live="assertive">
        <span class="text-green-700 text-sm"><%= notice %></span>
      </div>
    <% end %>
    <% if alert = flash[:alert] %>
      <div class="mx-6 mt-4 px-4 py-3 bg-red-50 border border-red-200 rounded-lg" role="alert" aria-live="assertive">
        <span class="text-red-600 text-sm font-medium"><%= alert %></span>
      </div>
    <% end %>
    <main class="flex-1 px-6 py-8">
      <%= yield %>
    </main>
  </div>
</body>
```

**Key decisions:**
- `stylesheet_link_tag :app` — same as `application.html.erb`; Tailwind tokens in `app/assets/tailwind/application.css` are available globally
- `lang="pt-BR"` — project standard
- Flash messages: mirror pattern from `app/views/sessions/new.html.erb` lines 14–25 (green/red banners with `role="alert"`)

---

### `app/controllers/admin/base_controller.rb` (modification)

**Analog:** `app/controllers/admin/base_controller.rb` (current file, lines 1–3)

**Current state:**
```ruby
class Admin::BaseController < ApplicationController
  before_action :require_authentication
end
```

**Add `layout 'admin'`:**
```ruby
class Admin::BaseController < ApplicationController
  layout 'admin'
  before_action :require_authentication
end
```

**Auth pattern source:** `app/controllers/concerns/authentication.rb` lines 20–23 — `require_authentication` calls `resume_session || request_authentication`. This is already wired; no change needed.

---

### `app/controllers/admin/clients_controller.rb` (controller, CRUD)

**Analog:** `app/controllers/passwords_controller.rb`

**Class skeleton pattern** (from passwords_controller.rb lines 1–5):
```ruby
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end
```

**Adaptation — clients controller:**
```ruby
class Admin::ClientsController < Admin::BaseController
  before_action :set_client, only: %i[ show edit update rotate_token ]

  def index
    @clients = Client.order(created_at: :desc)
  end

  def show
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      redirect_to admin_client_path(@client), notice: "Cliente cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    filtered = client_params.reject { |k, v| k.in?(['password', 'password_plain']) && v.blank? }
    if @client.update(filtered)
      redirect_to admin_client_path(@client), notice: "Dados do cliente atualizados."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def rotate_token
    @client.regenerate_access_token
    redirect_to admin_client_path(@client),
      notice: "Token rotacionado. O link anterior não funciona mais. Envie o novo link para o cliente."
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :password, :password_plain, :active)
  end
end
```

**Error handling pattern** (from passwords_controller.rb lines 18–24):
```ruby
# render :edit on failure, redirect on success — same pattern as update
if @user.update(params.permit(:password, :password_confirmation))
  redirect_to new_session_path, notice: "..."
else
  redirect_to edit_password_path(params[:token]), alert: "..."
end
```
Use `render :new/edit, status: :unprocessable_entity` for ActiveRecord validation failures (standard Rails 7/8 scaffold pattern). Use `redirect_to` on success.

**Password blank-on-edit guard** (Decision D-10):
```ruby
filtered = client_params.reject { |k, v| k.in?(['password', 'password_plain']) && v.blank? }
@client.update(filtered)
```

---

### `app/views/admin/clients/index.html.erb` (view, CRUD list)

**Analog:** `app/views/admin/dashboard/index.html.erb` (stub) + sessions/new.html.erb for flash/markup conventions

**Page heading pattern** (from dashboard/index.html.erb line 1):
```erb
<h1 class="text-2xl font-semibold text-slate-900">Clientes</h1>
```

**Table wrapper pattern** (UI-SPEC Screen 1):
```erb
<div class="bg-white rounded-xl border border-gray-200 shadow-card overflow-hidden">
  <table aria-label="Lista de clientes" class="w-full">
    <caption class="sr-only">Clientes cadastrados — clique no nome para ver os detalhes</caption>
    <thead class="bg-gray-50 border-b border-gray-200">
      <tr>
        <th scope="col" class="py-3 px-4 text-xs font-medium text-slate-500 uppercase tracking-wide text-left">Nome</th>
        <th scope="col" class="py-3 px-4 text-xs font-medium text-slate-500 uppercase tracking-wide text-center w-[100px]">Status</th>
        <th scope="col" class="py-3 px-4 text-xs font-medium text-slate-500 uppercase tracking-wide text-left w-[120px]">Criado em</th>
        <th scope="col" class="py-3 px-4 w-[48px]"><span class="sr-only">Ações</span></th>
      </tr>
    </thead>
    <tbody>
      <% @clients.each do |client| %>
        <%= render "client_row", client: client %>
      <% end %>
    </tbody>
  </table>
</div>
```

**Active sidebar link pattern** (Decision D-04 — no Stimulus, plain CSS):
```erb
<%# Used inside _sidebar.html.erb %>
<a href="<%= admin_clients_path %>"
   class="nav-item <%= 'active' if current_page?(admin_clients_path) %>">
  Clientes
</a>
```

---

### `app/views/admin/clients/new.html.erb` and `edit.html.erb` (views, CRUD form)

**Analog:** `app/views/sessions/new.html.erb` — form_with, flash, field structure

**form_with pattern** (sessions/new.html.erb lines 27–83):
```erb
<%= form_with model: [:admin, @client], class: "space-y-5",
              aria: { label: "Formulário de cliente" } do |form| %>

  <%# Nome do cliente %>
  <div>
    <%= form.label :name, "Nome do cliente",
          class: "block text-sm font-medium text-slate-900 mb-1.5" %>
    <%= form.text_field :name,
          required: true,
          autofocus: true,
          placeholder: "Ex: Loja da Maria",
          class: "block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm
                  text-slate-900 bg-white focus:outline-none focus:border-[#0F7949]
                  focus:ring-2 focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400" %>
    <%# Inline validation errors %>
    <% if @client.errors[:name].any? %>
      <span role="alert" class="text-xs text-red-600 mt-1 block">
        <%= @client.errors[:name].first %>
      </span>
    <% end %>
  </div>

  <%# Senha do portal com toggle — data-controller="password-toggle" %>
  <div data-controller="password-toggle">
    <%= form.label :password, "Senha do portal",
          class: "block text-sm font-medium text-slate-900 mb-1.5" %>
    <div class="relative">
      <%= form.password_field :password,
            placeholder: "Mínimo 4 caracteres",
            data: { "password-toggle-target": "field" },
            class: "block w-full h-11 px-3 pr-11 border border-gray-200 rounded-lg text-sm
                    text-slate-900 bg-white focus:outline-none focus:border-[#0F7949]
                    focus:ring-2 focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400" %>
      <button type="button"
              aria-label="Mostrar senha"
              aria-pressed="false"
              data-action="click->password-toggle#toggle"
              data-password-toggle-target="toggle"
              class="absolute inset-y-0 right-0 flex items-center px-3
                     text-slate-400 hover:text-slate-600 transition-colors">
        <%# Heroicon eye (inline SVG) %>
      </button>
    </div>
  </div>
<% end %>
```

**Key:** The `password_toggle_controller.js` already exists — reuse `data-controller="password-toggle"` exactly as used in `sessions/new.html.erb` lines 53–73.

**Input CSS class** (copy verbatim from sessions/new.html.erb line 41):
```
block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm text-slate-900
bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2
focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400
```

**Submit button pattern** (sessions/new.html.erb line 79):
```erb
<%= form.submit "Cadastrar cliente",
      class: "h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99]
              text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer" %>
```

---

### `app/views/admin/shared/_sidebar.html.erb` (partial, navigation)

**Analog:** `app/views/sessions/new.html.erb` for markup conventions, `app/views/admin/dashboard/index.html.erb` for scope

**Active link pattern** (Decision D-04):
```erb
<nav>
  <%
    nav_items = [
      { label: "Dashboard",      path: admin_root_path },
      { label: "Aprovações",     path: "#" },
      { label: "Clientes",       path: admin_clients_path },
      { label: "Calendário",     path: "#" },
      { label: "Configurações",  path: "#" },
    ]
  %>
  <% nav_items.each do |item| %>
    <%= link_to item[:path],
          class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium
                  transition-colors #{ current_page?(item[:path]) ?
                  'bg-white/20 text-white' : 'text-white/70 hover:bg-white/10 hover:text-white' }" do %>
      <%= item[:label] %>
    <% end %>
  <% end %>
</nav>
```

**Color:** sidebar bg `#0F7949` (brand green — confirmed in UI-SPEC Screen 1 and sessions/new.html.erb line 6: `bg-[#0F7949]`)

**Avatar + Sair section at bottom:**
```erb
<div class="mt-auto px-3 py-4 border-t border-white/20">
  <span class="text-white/80 text-sm">Admin</span>
  <%= button_to "Sair", session_path, method: :delete,
        class: "text-white/70 hover:text-white text-sm transition-colors" %>
</div>
```
Route for logout: `session_path` with `method: :delete` — from `config/routes.rb` line 3: `resource :session, only: [:new, :create, :destroy]`.

---

### `app/views/admin/clients/show.html.erb` (view, detail)

**Analog:** `app/views/sessions/new.html.erb` for readonly field + copy button markup

**Readonly input pattern** (UI-SPEC C6 — ReadonlyField):
```erb
<input id="client-link"
       type="text"
       readonly
       value="<%= client_portal_url(@client.access_token) %>"
       aria-label="Link de acesso do portal"
       aria-readonly="true"
       class="flex-1 h-11 px-3 bg-gray-50 border border-gray-200 rounded-lg
              text-sm font-mono text-slate-700 select-all cursor-text" />
```

**Password field visible by default** (Decision D-11, UI-SPEC Screen 4):
```erb
<%# type="text" — visible by default. Toggle uses existing password_toggle_controller %>
<div data-controller="password-toggle">
  <input id="client-password"
         type="text"
         readonly
         value="<%= @client.password_plain %>"
         aria-label="Senha do portal"
         aria-readonly="true"
         data-password-toggle-target="field"
         class="flex-1 h-11 px-3 bg-gray-50 border border-gray-200 rounded-lg
                text-sm text-slate-700 select-all cursor-text" />
  <button type="button"
          aria-label="Ocultar senha"
          aria-pressed="true"
          data-action="click->password-toggle#toggle"
          data-password-toggle-target="toggle">
    <%# Heroicon eye-slash %>
  </button>
</div>
```

Note: `aria-pressed="true"` (not false) because the field starts visible — mirrors `password_toggle_controller.js` logic where `isPassword = (field.type === "password")`.

**Deactivate/Reactivate via update** (Decision D-06):
```erb
<%# Deactivate — opens modal (Stimulus modal controller) %>
<button type="button"
        data-action="click->modal#open"
        data-modal-id="deactivate-modal"
        class="h-9 px-3 text-sm font-medium text-white bg-[#EE3537] rounded-lg hover:bg-red-700">
  Desativar cliente
</button>

<%# Inside modal — form submits PATCH with active: false %>
<%= form_with url: admin_client_path(@client), method: :patch do |f| %>
  <%= f.hidden_field :active, value: false %>
  <%= f.submit "Desativar cliente" %>
<% end %>
```

**Rotate token** (Decision D-07):
```erb
<%= button_to "Rotacionar token de acesso",
      rotate_token_admin_client_path(@client),
      method: :post,
      data: { turbo_confirm: false },
      class: "..." %>
<%# Actually: trigger modal first, modal's form POSTs to rotate_token_admin_client_path %>
```

---

### `db/migrate/XXXXXX_add_password_plain_to_clients.rb` (migration)

**Analog:** `db/migrate/20260524215205_create_clients.rb`

**Pattern** (create_clients.rb lines 1–13):
```ruby
class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :password_digest, null: false
      # ...
    end
  end
end
```

**New migration — add_column pattern:**
```ruby
class AddPasswordPlainToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :password_plain, :string
  end
end
```

Key decisions:
- `ActiveRecord::Migration[8.1]` — all existing migrations use `[8.1]`, copy exactly
- No `null: false` constraint — existing clients have no `password_plain` value; column must allow NULL initially
- No default value — `password_plain` is set explicitly on create/update

---

### `app/javascript/controllers/copy_controller.js` (Stimulus, event-driven)

**Analog:** `app/javascript/controllers/password_toggle_controller.js` (lines 1–15)

**Base structure to copy:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "toggle"]

  toggle() {
    const field = this.fieldTarget
    // ...
  }
}
```

**New controller pattern:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { value: String }

  execute() {
    const text = this.valueValue
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).then(() => this.#showCopied())
    } else {
      // Fallback
      this.element.textContent = "Selecione e copie"
      setTimeout(() => this.#resetLabel(), 3000)
    }
  }

  #showCopied() {
    // Swap classes: text-slate-600 → text-[#14A958], border-gray-200 → border-[#14A958]/30, bg-white → bg-[#F0FDF4]
    // Reset after 2000ms
  }
  #resetLabel() { /* restore original classes */ }
}
```

**Registration:** Automatic via `eagerLoadControllersFrom("controllers", application)` in `app/javascript/controllers/index.js` line 4. No manual registration needed — file name `copy_controller.js` auto-registers as `copy`.

---

### `app/javascript/controllers/dropdown_controller.js` (Stimulus, event-driven)

**Analog:** `app/javascript/controllers/password_toggle_controller.js`

**Pattern:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    const expanded = !this.menuTarget.classList.contains("hidden")
    this.element.querySelector("[aria-expanded]").setAttribute("aria-expanded", expanded)
  }

  // Close on outside click
  hide(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
      this.element.querySelector("[aria-expanded]")?.setAttribute("aria-expanded", false)
    }
  }

  connect() {
    this.outsideClickHandler = this.hide.bind(this)
    document.addEventListener("click", this.outsideClickHandler)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }
}
```

**Auto-registered** as `dropdown` via `eagerLoadControllersFrom`.

---

### `app/javascript/controllers/modal_controller.js` (Stimulus, event-driven)

**Analog:** `app/javascript/controllers/password_toggle_controller.js`

**Pattern:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  open() {
    this.overlayTarget.classList.remove("hidden")
    // Focus initial element (cancel button — UI-SPEC accessibility requirement)
    const cancelBtn = this.overlayTarget.querySelector("[data-modal-cancel]")
    cancelBtn?.focus()
    document.addEventListener("keydown", this.boundKeydown)
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.boundKeydown)
  }

  connect() {
    this.boundKeydown = (e) => { if (e.key === "Escape") this.close() }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
```

**Focus trap** (UI-SPEC accessibility, Padrão 4): implement inside `open()` — listen `keydown Tab`, cycle focus within `this.overlayTarget`.

**Auto-registered** as `modal` via `eagerLoadControllersFrom`.

---

## Shared Patterns

### Authentication (admin area)

**Source:** `app/controllers/concerns/authentication.rb` lines 20–35
**Apply to:** `Admin::BaseController` (and transitively all controllers inheriting it)

```ruby
def require_authentication
  resume_session || request_authentication
end

def request_authentication
  session[:return_to_after_authenticating] = request.url
  redirect_to new_session_path
end
```

No changes needed — `Admin::BaseController` already has `before_action :require_authentication`. Adding `layout 'admin'` is the only modification in Phase 2.

---

### Flash Messages

**Source:** `app/views/sessions/new.html.erb` lines 14–25
**Apply to:** `app/views/layouts/admin.html.erb`

```erb
<% if notice = flash[:notice] %>
  <div class="mb-6 px-4 py-3 bg-green-50 border border-green-200 rounded-lg" role="alert" aria-live="assertive">
    <span class="text-green-700 text-sm"><%= notice %></span>
  </div>
<% end %>
<% if alert = flash[:alert] %>
  <div class="mb-6 px-4 py-3 bg-red-50 border border-red-200 rounded-lg flex items-center gap-2" role="alert" aria-live="assertive">
    <span class="text-red-600 text-sm font-medium"><%= alert %></span>
  </div>
<% end %>
```

Flash messages render **in the layout** (not individual views), placed between topbar and main content.

---

### Form Field CSS Class (inputs)

**Source:** `app/views/sessions/new.html.erb` line 41
**Apply to:** All form inputs in `new.html.erb`, `edit.html.erb`

```
block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm text-slate-900
bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2
focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400
```

Password fields add `pr-11` for the toggle button clearance.

---

### Primary Admin Button

**Source:** `app/views/sessions/new.html.erb` line 81
**Apply to:** All primary CTA buttons in admin views

```
h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99]
text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer
```

Use `h-9` variant for secondary action buttons in detail page toolbar.

---

### Password Toggle (reuse, not recreate)

**Source:** `app/javascript/controllers/password_toggle_controller.js` lines 1–15 — **already exists**
**Apply to:** `new.html.erb`, `edit.html.erb`, `show.html.erb`

Exact `data-*` attributes used in production code (`sessions/new.html.erb` lines 53–73):
```html
data-controller="password-toggle"
data-password-toggle-target="field"      <!-- on the input -->
data-action="click->password-toggle#toggle"
data-password-toggle-target="toggle"     <!-- on the button -->
```

For show.html.erb (visible by default): set `type="text"` on initial render and `aria-pressed="true"` on toggle button, as the controller reads `field.type === "password"` to determine state.

---

### Stimulus Controller Auto-Registration

**Source:** `app/javascript/controllers/index.js` lines 3–4
**Apply to:** All new Stimulus controllers (`copy_controller.js`, `dropdown_controller.js`, `modal_controller.js`)

```javascript
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
```

No manual imports needed. File naming convention: `<name>_controller.js` → registered as `<name>` identifier. Verified by `password_toggle_controller.js` → `data-controller="password-toggle"`.

---

### Migration Versioning

**Source:** All migrations in `db/migrate/` (lines 1 in each file)
**Apply to:** `XXXXXX_add_password_plain_to_clients.rb`

```ruby
class AddPasswordPlainToClients < ActiveRecord::Migration[8.1]
```

All existing migrations use `[8.1]`. Use same version.

---

### Routes — namespace + member action

**Source:** `config/routes.rb` lines 7–10
**Apply to:** `config/routes.rb` (modification)

```ruby
namespace :admin do
  root to: "dashboard#index"
  resources :clients, only: [:index]  # expand this
end
```

Expand to:
```ruby
namespace :admin do
  root to: "dashboard#index"
  resources :clients, only: [:index, :show, :new, :create, :edit, :update] do
    member do
      post :rotate_token
    end
  end
end
```

This generates `rotate_token_admin_client_path(@client)` used in UI-SPEC and Decision D-07.

---

## No Analog Found

All files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `app/controllers/`, `app/views/`, `app/javascript/controllers/`, `db/migrate/`, `config/routes.rb`
**Files scanned:** 15
**Pattern extraction date:** 2026-05-24
