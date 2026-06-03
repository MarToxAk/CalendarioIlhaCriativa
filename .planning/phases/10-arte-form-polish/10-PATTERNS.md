# Phase 10: Arte Form Polish - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 4 (3 views + 1 JS controller)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `app/views/admin/artes/new.html.erb` | view (page wrapper) | request-response | `app/views/admin/clients/new.html.erb` | exact |
| `app/views/admin/artes/edit.html.erb` | view (page wrapper) | request-response | `app/views/admin/clients/edit.html.erb` | exact |
| `app/views/admin/artes/_form.html.erb` | view (form partial) | CRUD | `app/views/admin/clients/_form.html.erb` | role-match |
| `app/javascript/controllers/media_type_toggle_controller.js` | Stimulus controller | event-driven | N/A (extend existing file) | self-analog |

---

## Pattern Assignments

### `app/views/admin/artes/new.html.erb` (view, request-response)

**Analog:** `app/views/admin/clients/new.html.erb`

**Estrutura completa do analog** (linhas 1-16):
```erb
<% content_for(:page_title) { "Novo cliente" } %>

<div class="mb-6">
  <%= link_to admin_clients_path,
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors",
        aria: { label: "Voltar para lista de clientes" } do %>
    &larr; Voltar para Clientes
  <% end %>
</div>

<div class="bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-lg">
  <%= render "form",
        client: @client,
        button_label: "Cadastrar cliente",
        cancel_path: admin_clients_path %>
</div>
```

**Adaptações para artes/new.html.erb** (decisões D-02, D-01):
- Substituir `admin_clients_path` por `admin_artes_path`
- Substituir `aria: { label: "Voltar para lista de clientes" }` por `aria: { label: "Voltar para lista de artes" }`
- Substituir texto do link por `Voltar para Artes`
- Substituir `max-w-lg` por `max-w-2xl` (form de artes tem ~10 campos)
- Substituir `render "form", client: @client, button_label: ..., cancel_path:` por:
  `render "form", arte: @arte, button_label: "Criar arte", cancel_path: admin_artes_path`

**Resultado esperado:**
```erb
<% content_for(:page_title) { "Nova Arte" } %>

<div class="mb-6">
  <%= link_to admin_artes_path,
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors",
        aria: { label: "Voltar para lista de artes" } do %>
    &larr; Voltar para Artes
  <% end %>
</div>

<div class="bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl">
  <%= render "form",
        arte: @arte,
        button_label: "Criar arte",
        cancel_path: admin_artes_path %>
</div>
```

---

### `app/views/admin/artes/edit.html.erb` (view, request-response)

**Analog:** `app/views/admin/clients/edit.html.erb`

**Estrutura completa do analog** (linhas 1-16):
```erb
<% content_for(:page_title) { "Editar cliente" } %>

<div class="mb-6">
  <%= link_to admin_client_path(@client),
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors",
        aria: { label: "Voltar para detalhes de #{@client.name}" } do %>
    &larr; Voltar para <%= @client.name %>
  <% end %>
</div>

<div class="bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-lg">
  <%= render "form",
        client: @client,
        button_label: "Salvar alterações",
        cancel_path: admin_client_path(@client) %>
</div>
```

**Adaptações para artes/edit.html.erb** (decisões D-03, D-01):
- Substituir `admin_client_path(@client)` por `admin_arte_path(@arte)`
- Substituir `@client.name` por `@arte.title`
- Substituir `max-w-lg` por `max-w-2xl`
- Substituir `render "form", client: @client, ...` por `render "form", arte: @arte, ...`
- `button_label` permanece `"Salvar alterações"`

**Resultado esperado:**
```erb
<% content_for(:page_title) { "Editar Arte" } %>

<div class="mb-6">
  <%= link_to admin_arte_path(@arte),
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors",
        aria: { label: "Voltar para detalhes de #{@arte.title}" } do %>
    &larr; Voltar para <%= @arte.title %>
  <% end %>
</div>

<div class="bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl">
  <%= render "form",
        arte: @arte,
        button_label: "Salvar alterações",
        cancel_path: admin_arte_path(@arte) %>
</div>
```

---

### `app/views/admin/artes/_form.html.erb` (form partial, CRUD)

**Analog:** `app/views/admin/clients/_form.html.erb`

**IMPORTANTE:** O `_form.html.erb` de artes precisa aceitar locals `button_label` e `cancel_path` que serão passados pelas pages new/edit. Atualmente usa lógica inline (`arte.persisted? ? "Atualizar" : "Criar"`). O refactor deve substituir essa lógica pelos locals.

**Assinatura do form_with** (linha 2 do arquivo atual — manter sem alterações):
```erb
<%= form_with model: arte, url: arte.persisted? ? admin_arte_path(arte) : admin_artes_path,
      local: true,
      html: { multipart: true, data: { controller: "media-type-toggle" } } do |f| %>
```

---

#### Label pattern (analog: clients/_form.html.erb linha 7-8)

Substituir `class: "block text-sm font-medium mb-1"` por:
```erb
class: "block text-sm font-medium text-slate-900 mb-1.5"
```

---

#### Text field / date field / url field pattern (analog: clients/_form.html.erb linha 9-14)

Substituir `class: "form-input w-full"` por:
```erb
class: "block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm text-slate-900 bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400"
```

Aplica a: `:title`, `:scheduled_on`, `:approval_deadline`, `:external_url`

---

#### Textarea pattern (decisão D-05 — variação do text field)

Substituir `class: "form-input w-full"` do `f.text_area :caption` por:
```erb
class: "block w-full min-h-[80px] resize-y px-3 py-2 border border-gray-200 rounded-lg text-sm text-slate-900 bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400"
```

Diferença do text_field: sem `h-11`, usa `min-h-[80px] resize-y` e adiciona `py-2`.

---

#### Select pattern (decisão D-04 — igual ao text field)

Substituir `class: "form-input w-full"` dos `f.select :platform`, `f.select :media_type`, `f.select :client_id` por:
```erb
class: "block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm text-slate-900 bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10 transition-colors"
```

---

#### File input pattern (decisão D-13)

Substituir `class: "form-input w-full"` do `f.file_field :media_file` por:
```erb
class: "block w-full text-sm text-slate-900 border border-gray-200 rounded-lg cursor-pointer bg-white file:mr-4 file:py-2 file:px-4 file:border-0 file:text-sm file:font-semibold file:bg-green-50 file:text-green-700 hover:file:bg-green-100"
```

---

#### Radio pill pattern (decisões D-09, D-10, D-11, D-12)

Substituir o bloco `<div class="flex gap-4">` atual (linhas 36-39 do arquivo) por pills interativos com targets Stimulus:

```erb
<div class="flex gap-3">
  <label data-media-type-toggle-target="uploadLabel"
         class="cursor-pointer flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium transition-colors">
    <%= f.radio_button :media_source, :upload,
          checked: arte.media_file.attached? || arte.external_url.blank?,
          class: "sr-only",
          data: { action: "media-type-toggle#selectUpload", media_type_toggle_target: "uploadRadio" } %>
    Upload de arquivo
  </label>
  <label data-media-type-toggle-target="linkLabel"
         class="cursor-pointer flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-200 text-sm font-medium transition-colors">
    <%= f.radio_button :media_source, :link,
          checked: arte.external_url.present?,
          class: "sr-only",
          data: { action: "media-type-toggle#selectLink", media_type_toggle_target: "linkRadio" } %>
    Link externo
  </label>
</div>
```

Classes do pill **ativo:** `border-[#0F7949] bg-green-50 text-[#0F7949]`
Classes do pill **inativo:** `border-gray-200 text-slate-700`

O controller aplica/remove essas classes — os labels renderizam com as classes base neutras e o JS faz o toggle inicial via `connect()`.

---

#### Botão submit pattern (analog: clients/_form.html.erb linha 61-62; decisão D-07)

Substituir `class: "btn btn-primary"` do `f.submit` por:
```erb
class: "h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer"
```

Substituir lógica inline `arte.persisted? ? "Atualizar" : "Criar"` pelo local `button_label`.

---

#### Botão Cancelar pattern (analog: clients/_form.html.erb linha 59-60; decisão D-08)

Substituir `class: "btn"` do `link_to "Cancelar"` por:
```erb
class: "inline-flex items-center h-10 px-4 border border-gray-200 rounded-lg text-sm text-slate-600 hover:text-slate-900 hover:bg-gray-50 transition-colors"
```

Substituir path inline `arte.persisted? ? admin_arte_path(arte) : admin_artes_path` pelo local `cancel_path`.

Texto do link: manter `"Voltar sem salvar"` (padrão do analog clients) em vez de `"Cancelar"`.

---

#### Rodapé dos botões (analog: clients/_form.html.erb linha 58)

Substituir `<div class="flex gap-2">` por:
```erb
<div class="flex justify-end gap-3 pt-2">
```

---

### `app/javascript/controllers/media_type_toggle_controller.js` (Stimulus controller, event-driven)

**Analog:** Próprio arquivo — extensão do controller existente.

**Estado atual do arquivo** (linhas 1-29):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["uploadField", "linkField", "uploadRadio", "linkRadio"]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    if (this.uploadRadioTarget.checked) {
      this.uploadFieldTarget.classList.remove("hidden")
      this.linkFieldTarget.classList.add("hidden")
    } else if (this.linkRadioTarget.checked) {
      this.linkFieldTarget.classList.remove("hidden")
      this.uploadFieldTarget.classList.add("hidden")
    }
  }

  selectUpload() {
    this.uploadRadioTarget.checked = true
    this.toggleFields()
  }

  selectLink() {
    this.linkRadioTarget.checked = true
    this.toggleFields()
  }
}
```

**Modificações necessárias** (decisões D-11, D-12):

1. Adicionar `"uploadLabel"` e `"linkLabel"` ao array `static targets`.
2. Criar método `togglePills()` que aplica/remove classes de destaque nos dois label targets.
3. Chamar `togglePills()` dentro de `toggleFields()` (para manter chamada única).

**Classes a aplicar no pill ativo:**
- `border-[#0F7949]`, `bg-green-50`, `text-[#0F7949]`

**Classes a remover do pill ativo / manter no inativo:**
- `border-gray-200`, `text-slate-700`

**Padrão do método togglePills:**
```javascript
togglePills() {
  const activeClasses   = ["border-[#0F7949]", "bg-green-50", "text-[#0F7949]"]
  const inactiveClasses = ["border-gray-200", "text-slate-700"]

  if (this.uploadRadioTarget.checked) {
    this.uploadLabelTarget.classList.add(...activeClasses)
    this.uploadLabelTarget.classList.remove(...inactiveClasses)
    this.linkLabelTarget.classList.remove(...activeClasses)
    this.linkLabelTarget.classList.add(...inactiveClasses)
  } else {
    this.linkLabelTarget.classList.add(...activeClasses)
    this.linkLabelTarget.classList.remove(...inactiveClasses)
    this.uploadLabelTarget.classList.remove(...activeClasses)
    this.uploadLabelTarget.classList.add(...inactiveClasses)
  }
}
```

**Resultado final do controller:**
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["uploadField", "linkField", "uploadRadio", "linkRadio", "uploadLabel", "linkLabel"]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    if (this.uploadRadioTarget.checked) {
      this.uploadFieldTarget.classList.remove("hidden")
      this.linkFieldTarget.classList.add("hidden")
    } else if (this.linkRadioTarget.checked) {
      this.linkFieldTarget.classList.remove("hidden")
      this.uploadFieldTarget.classList.add("hidden")
    }
    this.togglePills()
  }

  togglePills() {
    const activeClasses   = ["border-[#0F7949]", "bg-green-50", "text-[#0F7949]"]
    const inactiveClasses = ["border-gray-200", "text-slate-700"]

    if (this.uploadRadioTarget.checked) {
      this.uploadLabelTarget.classList.add(...activeClasses)
      this.uploadLabelTarget.classList.remove(...inactiveClasses)
      this.linkLabelTarget.classList.remove(...activeClasses)
      this.linkLabelTarget.classList.add(...inactiveClasses)
    } else {
      this.linkLabelTarget.classList.add(...activeClasses)
      this.linkLabelTarget.classList.remove(...inactiveClasses)
      this.uploadLabelTarget.classList.remove(...activeClasses)
      this.uploadLabelTarget.classList.add(...inactiveClasses)
    }
  }

  selectUpload() {
    this.uploadRadioTarget.checked = true
    this.toggleFields()
  }

  selectLink() {
    this.linkRadioTarget.checked = true
    this.toggleFields()
  }
}
```

---

## Shared Patterns

### Card wrapper
**Source:** `app/views/admin/clients/new.html.erb` linhas 11-16
**Apply to:** `artes/new.html.erb`, `artes/edit.html.erb`
```erb
<div class="bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl">
```
Nota: `max-w-2xl` em vez de `max-w-lg` (decisão D-01 — form de artes tem ~10 campos).

### Back link
**Source:** `app/views/admin/clients/new.html.erb` linhas 3-9
**Apply to:** `artes/new.html.erb`, `artes/edit.html.erb`
```erb
<div class="mb-6">
  <%= link_to PATH,
        class: "text-sm text-slate-600 hover:text-slate-900 transition-colors",
        aria: { label: "..." } do %>
    &larr; Voltar para ...
  <% end %>
</div>
```

### Input Tailwind classes
**Source:** `app/views/admin/clients/_form.html.erb` linha 14
**Apply to:** todos os campos de texto, date, url em `artes/_form.html.erb`
```
block w-full h-11 px-3 border border-gray-200 rounded-lg text-sm text-slate-900 bg-white focus:outline-none focus:border-[#0F7949] focus:ring-2 focus:ring-[#0F7949]/10 transition-colors placeholder-slate-400
```

### Label classes
**Source:** `app/views/admin/clients/_form.html.erb` linhas 7-8
**Apply to:** todos os labels em `artes/_form.html.erb`
```
block text-sm font-medium text-slate-900 mb-1.5
```

### Submit button classes
**Source:** `app/views/admin/clients/_form.html.erb` linha 62
**Apply to:** `f.submit` em `artes/_form.html.erb`
```
h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99] text-white text-sm font-semibold rounded-lg transition-colors cursor-pointer
```

### Cancel link classes
**Source:** `app/views/admin/clients/_form.html.erb` linha 59-60
**Apply to:** link Cancelar em `artes/_form.html.erb`
```
inline-flex items-center h-10 px-4 border border-gray-200 rounded-lg text-sm text-slate-600 hover:text-slate-900 hover:bg-gray-50 transition-colors
```

### Form footer alignment
**Source:** `app/views/admin/clients/_form.html.erb` linha 58
**Apply to:** `<div>` wrapper dos botões em `artes/_form.html.erb`
```
flex justify-end gap-3 pt-2
```

---

## No Analog Found

Nenhum arquivo sem analog — todos os 4 arquivos têm referência direta no codebase.

---

## Metadata

**Analog search scope:** `app/views/admin/clients/`, `app/javascript/controllers/`
**Files scanned:** 6 (4 analogs + 2 arquivos a modificar lidos para mapeamento de diffs)
**Pattern extraction date:** 2026-06-03
