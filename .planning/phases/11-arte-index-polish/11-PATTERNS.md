# Phase 11: Arte Index Polish - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 2 (1 modified + 1 optional new partial)
**Analogs found:** 2 / 2

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/views/admin/artes/index.html.erb` | view/template | request-response | `app/views/admin/clients/index.html.erb` | exact |
| `app/views/admin/artes/_arte_row.html.erb` (optional partial) | view/partial | request-response | `app/views/admin/clients/_client_row.html.erb` | exact |

---

## Pattern Assignments

### `app/views/admin/artes/index.html.erb` (view, request-response)

**Analog:** `app/views/admin/clients/index.html.erb`

**Estado atual do arquivo** (`app/views/admin/artes/index.html.erb`, linhas 1-30):
```erb
<%# app/views/admin/artes/index.html.erb %>
<% content_for(:page_title) { "Artes" } %>

<div class="flex items-center justify-between mb-6">
  <h1 class="text-2xl font-bold">Artes</h1>
  <%= link_to "Nova Arte", new_admin_arte_path, class: "btn btn-primary" %>
</div>

<table class="min-w-full bg-white border border-gray-200 rounded-xl shadow-card">
  <thead>
    <tr>
      <th>Cliente</th>
      <th>Data</th>
      <th>Plataforma</th>
      <th>Status</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <% @artes.each do |arte| %>
      <tr>
        <td><%= arte.client.name %></td>
        <td><%= arte.scheduled_on.strftime("%d/%m/%Y") %></td>
        <td><%= arte.platform.capitalize %></td>
        <td><%= arte.status.capitalize %></td>
        <td><%= link_to "Ver", admin_arte_path(arte), class: "btn btn-sm" %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

**Problemas identificados:**
- `btn btn-primary` e `btn btn-sm` — classes Bootstrap legadas, sem correspondência no CSS atual
- `h1` usa `font-bold` em vez de `font-semibold` (padrão clients)
- `<thead>` sem classes de styling
- `<th>` sem classes
- `<tr>` do tbody sem classes hover/border
- `<td>` sem classes de padding/tipografia
- `.capitalize` em enums com underscore produz `Caption_only`, `Change_requested` — usar `.humanize`
- Sem empty state
- Sem versão mobile cards
- `<table>` tem `shadow-card` no wrapper direto — clientes envolvem a tabela em um `<div>` com `overflow-hidden hidden sm:block`

---

**Padrão do header com botão primário** (`app/views/admin/clients/index.html.erb`, linhas 3-9):
```erb
<div class="flex items-center justify-between mb-6">
  <h1 class="text-2xl font-semibold text-slate-900">Clientes</h1>
  <%= link_to new_admin_client_path,
        class: "h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99] text-white text-sm font-semibold rounded-lg transition-colors inline-flex items-center" do %>
    + Novo cliente
  <% end %>
</div>
```

**Adaptar para artes:**
- Trocar `new_admin_client_path` por `new_admin_arte_path`
- Trocar `"Clientes"` por `"Artes"` e `"+ Novo cliente"` por `"+ Nova arte"`
- `font-bold` -> `font-semibold text-slate-900` (D-01 confirma padrão idêntico ao clients)

---

**Padrão empty state** (`app/views/admin/clients/index.html.erb`, linhas 11-22):
```erb
<% if @clients.empty? %>
  <div class="py-16 text-center">
    <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto text-slate-300 mb-4" width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    <h2 class="text-lg font-semibold text-slate-900 mb-1">Nenhum cliente cadastrado</h2>
    <p class="text-sm text-slate-500 mb-6">Cadastre o primeiro cliente para começar.</p>
    <%= link_to new_admin_client_path,
          class: "h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99] text-white text-sm font-semibold rounded-lg transition-colors inline-flex items-center" do %>
      + Cadastrar primeiro cliente
    <% end %>
  </div>
<% else %>
```

**Adaptar para artes (D-07):**
- Condição: `<% if @artes.empty? %>`
- Título: `"Nenhuma arte cadastrada"`
- Texto: adaptar conforme contexto (ex: `"Cadastre a primeira arte para começar."`)
- Link: `new_admin_arte_path` / `"+ Cadastrar primeira arte"`
- SVG: pode reusar o ícone de pessoas (clientes) ou substituir por ícone de imagem/arte

---

**Padrão wrapper de tabela desktop** (`app/views/admin/clients/index.html.erb`, linhas 25-42):
```erb
<div class="bg-white rounded-xl border border-gray-200 shadow-card overflow-hidden hidden sm:block">
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

**Adaptar para artes (D-03, D-04):**
- Colunas: `Cliente`, `Data`, `Plataforma`, `Status`, `Ações (sr-only)`
- `aria-label="Lista de artes"`
- `caption` atualizado para artes
- Manter `hidden sm:block` no wrapper div
- Nota: o `<table>` atual tem `shadow-card` diretamente nele — mover o shadow para o `<div>` wrapper e retirar da tag `<table>` (que recebe apenas `w-full`)
- Tbody: `<% @artes.each do |arte| %>` + `<%= render "arte_row", arte: arte %>` (ou inline)

---

**Padrão cards mobile** (`app/views/admin/clients/index.html.erb`, linhas 44-60):
```erb
<div class="block sm:hidden space-y-3">
  <% @clients.each do |client| %>
    <%= link_to admin_client_path(client), class: "block bg-white rounded-xl border border-gray-200 shadow-card px-4 py-3 #{client.active ? '' : 'opacity-60'}" do %>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <span class="text-sm font-semibold text-slate-900"><%= client.name %></span>
          <%= render "status_badge", client: client %>
        </div>
        <svg xmlns="http://www.w3.org/2000/svg" class="text-slate-400" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </div>
      <p class="text-xs text-slate-500 mt-1">Criado em <%= client.created_at.strftime("%d/%m/%y") %></p>
    <% end %>
  <% end %>
</div>
```

**Adaptar para artes (D-08):**
- Link: `admin_arte_path(arte)`
- Linha principal: `arte.title` (ou `arte.client.name` se não houver título) + badge de status
- Linha secundária: `arte.scheduled_on.strftime("%d/%m/%y")` e/ou plataforma
- Não há `opacity-60` por inatividade em artes (status varia entre pending/approved/etc.)
- Status badge: inline ou partial `_status_badge` específico para artes (ver Shared Patterns abaixo)

---

### `app/views/admin/artes/_arte_row.html.erb` (view/partial, request-response)

**Analog:** `app/views/admin/clients/_client_row.html.erb`

**Padrão do partial de row** (`app/views/admin/clients/_client_row.html.erb`, linhas 1-15):
```erb
<tr class="border-b border-gray-100 last:border-0 hover:bg-gray-50 transition-colors <%= client.active ? '' : 'opacity-60' %>">
  <td class="px-4 py-0 h-12">
    <%= link_to client.name, admin_client_path(client),
          class: "text-sm font-medium text-slate-900 hover:text-[#0a5c37]" %>
  </td>
  <td class="px-4 py-0 h-12 text-center">
    <%= render "status_badge", client: client %>
  </td>
  <td class="px-4 py-0 h-12">
    <span class="text-sm text-slate-500"><%= client.created_at.strftime("%d/%m/%y") %></span>
  </td>
  <td class="px-4 py-0 h-12 text-center">
    <%= render "actions_menu", client: client %>
  </td>
</tr>
```

**Adaptar para artes (D-05, D-06):**
- `<tr class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">` — sem opacity por status
- `<td class="py-3 px-4 text-sm text-slate-900">` (D-06 especifica `py-3` em vez do `py-0 h-12` dos clients; manter consistência com a decisão)
- Colunas: cliente (`arte.client.name`), data (`arte.scheduled_on.strftime`), plataforma (`arte.platform.humanize`), status (`arte.status.humanize`), ação (link "Ver")
- Botão "Ver" (D-02): `class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors"`

**Nota crítica sobre `.humanize` (D-06, WR-02 da Fase 10):**
```ruby
# ERRADO — produz "Caption_only", "Change_requested"
arte.platform.capitalize
arte.status.capitalize

# CORRETO — produz "Caption only", "Change requested"
arte.platform.humanize
arte.status.humanize
```

---

## Shared Patterns

### Botão primário verde
**Source:** `app/views/admin/clients/index.html.erb` (linhas 5-8 e 18-21) e `app/views/admin/artes/_form.html.erb` (linha 77)
**Apply to:** Botão "Nova Arte" (index) e botão do empty state
```erb
class: "h-10 px-4 bg-[#0F7949] hover:bg-[#0a5c37] active:scale-[0.99] text-white text-sm font-semibold rounded-lg transition-colors inline-flex items-center"
```

### Botão outline secundário (link "Ver")
**Source:** Decisão D-02 — padrão derivado do `link_to "Voltar sem salvar"` em `app/views/admin/artes/_form.html.erb` (linha 75)
**Apply to:** Coluna de ação na tabela
```erb
class: "h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors"
```

### shadow-card
**Source:** `app/assets/tailwind/application.css` (linha 68)
**Definição:** `--shadow-card: 0 1px 3px 0 rgba(0,0,0,0.08), 0 1px 2px -1px rgba(0,0,0,0.05);`
**Apply to:** `<div>` wrapper da tabela desktop e cada card mobile
```html
class="... shadow-card ..."
```

### Status badge para artes
**Source:** Não existe ainda — clients usa `_status_badge.html.erb` com lógica booleana `active/inactive`.
**Para artes:** Implementar inline no index ou criar `app/views/admin/artes/_status_badge.html.erb` seguindo o mesmo padrão visual.

**Padrão visual de badge** (`app/views/admin/clients/_status_badge.html.erb`, linhas 1-9):
```erb
<span class="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20">
  <span aria-hidden="true">●</span> Ativo
</span>
```

**Mapeamento de cores por status de arte:**
- `pending` → amarelo/warning: `bg-[#FFFBEB] text-amber-800 border-[#F59E0B]/20`
- `approved` → verde/success: `bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20`
- `change_requested` → coral/error: `bg-[#FEF2F2] text-[#EE3537] border-[#EE3537]/20`
- `revised` → slate/neutral: `bg-gray-50 text-slate-600 border-gray-200`

---

## No Analog Found

Nenhum arquivo sem analog — todos os padrões necessários existem em `app/views/admin/clients/`.

---

## Metadata

**Analog search scope:** `app/views/admin/clients/`, `app/views/admin/artes/`, `app/assets/tailwind/`
**Files scanned:** 6 (index, _client_row, _status_badge, _form arte, application.css, arte model)
**Pattern extraction date:** 2026-06-03
