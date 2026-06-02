# Phase 7: Art Upload & Client Scoping Fix - Pattern Map

**Mapped:** 2026-06-02
**Files analyzed:** 3 (2 modificados + 1 verificado sem alteração)
**Analogs found:** 3 / 3

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `app/controllers/admin/artes_controller.rb` | controller | request-response | `app/controllers/admin/artes_controller.rb` (self) | exact — modificação pontual em `set_arte` |
| `app/views/admin/artes/_form.html.erb` | component (form partial) | request-response | `app/views/admin/artes/_form.html.erb` (self) | exact — arquivo central da correção |
| `app/views/admin/artes/new.html.erb` | view | request-response | `app/views/admin/artes/edit.html.erb` | exact — mesmo padrão `render "form"` |

---

## Pattern Assignments

### `app/controllers/admin/artes_controller.rb` — modificação em `set_arte`

**Analog:** o próprio arquivo (modificação de método existente)

**Padrão atual de `set_arte`** (linhas 58-60):
```ruby
def set_arte
  @arte = Arte.includes(:approval_responses).find(params[:id])
end
```

**Padrão a adicionar — `@client` derivado da arte** (D-06):
```ruby
def set_arte
  @arte = Arte.includes(:approval_responses).find(params[:id])
  @client = @arte.client
end
```

Nenhuma outra linha do controller muda. O `set_client` (linhas 62-64) não é alterado — continua retornando `nil` quando não há `params[:client_id]`, o que é válido (o selector do form cobre esse caso).

**Padrão de `set_client` (inalterado, linha 62-64):**
```ruby
def set_client
  @client = Client.find_by(id: params[:client_id])
end
```

**Padrão de redirect/flash (referência para manutenção de consistência, linhas 24-28):**
```ruby
if @arte.save
  redirect_to admin_arte_path(@arte), notice: "Arte criada com sucesso."
else
  render :new, status: :unprocessable_entity
end
```

---

### `app/views/admin/artes/_form.html.erb` — adição do selector condicional de cliente

**Analog:** o próprio arquivo + `app/views/admin/artes/_form.html.erb` (selects existentes de `:platform` e `:media_type` como modelo de estilo)

**Padrão de `f.select` existente no form** (linhas 20-26 — usar como modelo de classe e estrutura):
```erb
<div class="mb-4">
  <%= f.label :platform, "Plataforma", class: "block text-sm font-medium mb-1" %>
  <%= f.select :platform, Arte.platforms.keys.map { |k| [k.capitalize, k] }, {}, class: "form-input w-full" %>
</div>
<div class="mb-4">
  <%= f.label :media_type, "Formato", class: "block text-sm font-medium mb-1" %>
  <%= f.select :media_type, Arte.media_types.keys.map { |k| [k.capitalize, k] }, {}, class: "form-input w-full" %>
</div>
```

**Padrão atual do `hidden_field` a substituir por lógica condicional** (linha 43):
```erb
<%= f.hidden_field :client_id %>
```

**Padrão a implementar — `hidden_field` vs `select` condicional** (D-03, D-04, discretion):
```erb
<% if arte.client_id.present? %>
  <%= f.hidden_field :client_id %>
<% else %>
  <div class="mb-4">
    <%= f.label :client_id, "Cliente", class: "block text-sm font-medium mb-1" %>
    <%= f.select :client_id, Client.order(:name).map { |c| [c.name, c.id] }, { prompt: "Selecione o cliente" }, class: "form-input w-full" %>
  </div>
<% end %>
```

Observações:
- `Client.order(:name)` — ordenação alfabética (D-discretion)
- `prompt: "Selecione o cliente"` — PT-BR, consistente com o restante do form (D-discretion)
- Classe `form-input w-full` — igual aos outros selects do form (D-discretion)
- O bloco condicional deve permanecer dentro do `<div class="flex gap-2">` existente (linha 42) para artes já persistidas (edit), mas para new o `hidden_field` sai do flex row — manter a div de ação limpa. O select deve vir **antes** do `<div class="flex gap-2">` com os botões.

**Posição correta no form (referência ao bloco final, linhas 42-46):**
```erb
<%# Selector/hidden_field deve vir ANTES deste bloco %>
<div class="flex gap-2">
  <%= f.submit arte.persisted? ? "Atualizar" : "Criar", class: "btn btn-primary" %>
  <%= link_to "Cancelar", arte.persisted? ? admin_arte_path(arte) : admin_artes_path, class: "btn" %>
</div>
```

---

### `app/views/admin/artes/new.html.erb` — verificação de exibição de erros

**Analog:** `app/views/admin/artes/edit.html.erb` e `app/views/admin/clients/_form.html.erb`

**Padrão atual de `new.html.erb`** (linhas 1-3 — arquivo completo):
```erb
<%# app/views/admin/artes/new.html.erb %>
<% content_for(:page_title) { "Nova Arte" } %>
<%= render "form", arte: @arte %>
```

A view delega completamente ao partial `_form.html.erb`. Não exibe `@arte.errors` diretamente. Verificar se o partial ou o layout admin já renderiza erros globais. Se não houver bloco de erros em `_form.html.erb`, adicionar conforme padrão de `clients/_form.html.erb`:

**Padrão de exibição de erro por campo (de `clients/_form.html.erb`, linhas 15-18):**
```erb
<% if arte.errors[:base].any? %>
  <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
    <% arte.errors[:base].each do |msg| %>
      <p><%= msg %></p>
    <% end %>
  </div>
<% end %>
```

Erros de `:base` são especialmente relevantes aqui pois `media_source_present` e `only_one_media_source` adicionam em `errors.add(:base, ...)` (model, linhas 21-28).

---

## Shared Patterns

### Autenticação / Guard
**Fonte:** `app/controllers/admin/base_controller.rb` (linha 3)
**Aplica a:** todos os controllers admin (já herdado por `Admin::ArtesController`)
```ruby
before_action :require_authentication
```
Nenhuma mudança necessária — a herança já cobre todas as actions modificadas.

### Flash messages
**Fonte:** `app/controllers/admin/artes_controller.rb` (linhas 24-28, 35-39, 43-44, 49-52)
**Aplica a:** todas as actions com redirect
```ruby
redirect_to ..., notice: "Mensagem de sucesso em PT-BR."
redirect_to ..., alert: "Mensagem de erro em PT-BR."
render :new, status: :unprocessable_entity   # para falha de validação
```

### Padrão de `f.select` com classe Tailwind
**Fonte:** `app/views/admin/artes/_form.html.erb` (linhas 20-26)
**Aplica a:** novo select de `client_id` no `_form.html.erb`
```erb
f.select :field, collection, options_hash, class: "form-input w-full"
```

### Padrão condicional `persisted?` em views
**Fonte:** `app/views/admin/artes/_form.html.erb` (linhas 2, 44-45) e `app/views/admin/clients/_form.html.erb` (linha 44)
**Aplica a:** lógica de selector vs hidden_field e labels de submit
```erb
arte.persisted? ? "valor_edit" : "valor_new"
```

---

## No Analog Found

Nenhum arquivo sem analog. Todos os arquivos a modificar são existentes e se modificam pontualmente.

---

## Metadata

**Escopo de busca de analogs:** `app/controllers/admin/`, `app/views/admin/artes/`, `app/views/admin/clients/`, `app/javascript/controllers/`
**Arquivos lidos:** 11
**Data de extração de padrões:** 2026-06-02
