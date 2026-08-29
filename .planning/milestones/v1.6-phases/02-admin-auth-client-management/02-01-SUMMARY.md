---
phase: 02-admin-auth-client-management
plan: "01"
subsystem: admin-layout-clients
tags: [rails, tailwind, stimulus, admin, layout, clients]
dependency_graph:
  requires: []
  provides:
    - admin-layout
    - sidebar-navigation
    - clients-index-view
    - dropdown-controller
    - password-plain-column
  affects:
    - app/views/layouts/admin.html.erb
    - app/controllers/admin/base_controller.rb
    - app/controllers/admin/clients_controller.rb
    - app/views/admin/clients/
    - app/javascript/controllers/dropdown_controller.js
tech_stack:
  added: []
  patterns:
    - Admin layout separado do application layout
    - Sidebar com active link detection via current_page?
    - Stimulus dropdown controller com outsideClickHandler cleanup
    - Strong params com blank-password guard (D-10)
key_files:
  created:
    - db/migrate/20260525052827_add_password_plain_to_clients.rb
    - app/views/layouts/admin.html.erb
    - app/views/admin/shared/_sidebar.html.erb
    - app/controllers/admin/clients_controller.rb
    - app/views/admin/clients/index.html.erb
    - app/views/admin/clients/_client_row.html.erb
    - app/views/admin/clients/_status_badge.html.erb
    - app/views/admin/clients/_actions_menu.html.erb
    - app/javascript/controllers/dropdown_controller.js
  modified:
    - app/controllers/admin/base_controller.rb
    - config/routes.rb
    - db/schema.rb
decisions:
  - "Layout admin.html.erb separado do application.html.erb com sidebar #0F7949 + topbar 64px"
  - "Active link na sidebar via current_page? sem Stimulus (D-04)"
  - "password_plain sem null:false para compatibilidade com clientes existentes"
  - "Dropdown com outsideClickHandler bound no connect() e removido no disconnect() para evitar memory leak"
  - "text-amber-800 no badge Inativo para cumprir contraste AA (ratio 7.3:1 vs text-amber-500 ratio 2.4:1)"
metrics:
  duration: "~6 min"
  completed_date: "2026-05-25"
  tasks_completed: 2
  files_created: 9
  files_modified: 3
---

# Phase 02 Plan 01: Admin Layout + Clients Index Summary

**One-liner:** Layout admin com sidebar verde #0F7949, topbar e flash, ClientsController com 7 actions (incluindo rotate_token), view index com tabela + estado vazio + dropdown Stimulus por linha.

## What Was Built

### Task 1: Migração password_plain + Admin layout + rotas + controller skeleton

**Migração:** `AddPasswordPlainToClients` adicionou coluna `password_plain :string` nullable na tabela `clients`. Versão `ActiveRecord::Migration[8.1]`, sem `null: false` para compatibilidade com clientes existentes.

**Admin::BaseController:** Adicionado `layout 'admin'` antes do `before_action :require_authentication`, fazendo todos os controllers do namespace admin herdar automaticamente o layout admin.

**app/views/layouts/admin.html.erb:** Layout completo baseado no `application.html.erb`. Body com `min-h-screen bg-gray-50 flex`, sidebar renderizada via partial, topbar (h-16, bg-white, border-b) com `content_for(:page_title)`, flash messages (notice verde, alert vermelho) com `role="alert" aria-live="assertive"`, e `<main class="flex-1 px-6 py-8">`.

**app/views/admin/shared/_sidebar.html.erb:** Sidebar `w-60 bg-[#0F7949]` com branding "Ilha Criativa / by Bom Custo", nav items via array Ruby com active link detection via `current_page?` (classe `bg-white/20 text-white` para ativo, `text-white/70 hover:bg-white/10` para inativo), footer com `button_to "Sair", session_path, method: :delete`.

**Admin::ClientsController:** 7 actions (index, show, new, create, edit, update, rotate_token). Guard D-10 no update: `client_params.reject { |k, v| [...].include?(k) && v.blank? }`. Flash messages PT-BR incluindo detecção de mudança no campo `active` para mensagens diferenciadas de desativar/reativar.

**config/routes.rb:** `resources :clients` expandido para `only: [:index, :show, :new, :create, :edit, :update]` com `member do post :rotate_token end`.

### Task 2: View index de clientes + partials + dropdown_controller.js

**app/views/admin/clients/index.html.erb:** `content_for :page_title, "Clientes"`. Heading + botão "+ Novo cliente". Estado vazio com ícone SVG heroicons, texto "Nenhum cliente cadastrado" e botão CTA. Tabela desktop (`hidden sm:block`) com `aria-label`, `caption sr-only`, thead bg-gray-50, tbody iterando partials. Cards mobile (`block sm:hidden`) com link para show.

**_client_row.html.erb:** `<tr>` com `opacity-60` condicional para clientes inativos (h-12, border-b, hover:bg-gray-50). 4 colunas: nome (link), status badge, data criação, menu de ações.

**_status_badge.html.erb:** Badge Ativo com `bg-[#F0FDF4] text-[#14A958]`; badge Inativo com `text-amber-800` (ratio contraste 7.3:1 — AA aprovado per UI-SPEC nota de contraste).

**_actions_menu.html.erb:** Div `data-controller="dropdown"` com botão trigger (aria-label dinâmico, aria-haspopup="true", aria-expanded="false"), dropdown `ul role="menu"` com itens "Ver detalhes", "Editar cliente", e condicional "Desativar cliente" (placeholder link para modal plano 03) / "Reativar cliente" (button_to PATCH).

**dropdown_controller.js:** `static targets = ["menu"]`. `toggle()` com `classList.toggle("hidden")` e `setAttribute("aria-expanded", expanded)`. `hide(event)` para fechar ao clicar fora. `connect()`/`disconnect()` com `outsideClickHandler` bound para evitar memory leak.

## Verification Results

```
bin/rails runner "puts Client.column_names.include?('password_plain')"
→ true

bin/rails routes | grep rotate_token_admin_client
→ rotate_token_admin_client POST /admin/clients/:id/rotate_token(.:format)

grep "layout 'admin'" app/controllers/admin/base_controller.rb
→ layout 'admin'

grep 'bg-\[#0F7949\]' app/views/admin/shared/_sidebar.html.erb
→ <nav class="w-60 bg-[#0F7949] ...">

bin/rails runner "puts Admin::ClientsController.instance_methods(false).sort.inspect"
→ [:create, :edit, :index, :new, :rotate_token, :show, :update]

grep "removeEventListener" app/javascript/controllers/dropdown_controller.js
→ document.removeEventListener("click", this.outsideClickHandler)
```

## Deviations from Plan

### Auto-fixed Issues

Nenhum — plano executado exatamente como escrito.

### Adjustments Made

**1. [Rule 2 - Segurança] Flash messages diferenciadas para desativar/reativar**
- O plan especificava os flashes de desativar/reativar no controller, mas não especificava a detecção de mudança em `active`
- Implementado: `was_active = @client.active` antes do update e condicional após para gerar a flash correta
- Arquivos modificados: `app/controllers/admin/clients_controller.rb`

**2. [Fidelidade UI-SPEC] aria-label no ul do dropdown**
- Adicionado `aria-label="Opções de <%= client.name %>"` no `<ul role="menu">` conforme UI-SPEC seção ARIA para botões de ações da linha
- Arquivos modificados: `app/views/admin/clients/_actions_menu.html.erb`

## Known Stubs

**1. "Desativar cliente" no dropdown — placeholder para Plan 03**
- **Arquivo:** `app/views/admin/clients/_actions_menu.html.erb`
- **Linha:** link_to "#" com data-action="click->dropdown#toggle"
- **Razão:** O modal de confirmação de desativação (Stimulus `modal` controller) será implementado no Plan 03. Por enquanto o link apenas fecha o dropdown sem executar a ação de desativação. A ação de reativação via button_to PATCH está funcional.

## Threat Flags

Nenhum — todos os trust boundaries do plano estão cobertos:
- T-02-01: `before_action :require_authentication` herdado via Admin::BaseController
- T-02-02: `client_params` com strong params `permit(:name, :password, :password_plain, :active)`
- T-02-03: `rotate_token` via rota POST member com CSRF obrigatório

## Self-Check: PASSED

Arquivos criados:
- db/migrate/20260525052827_add_password_plain_to_clients.rb — FOUND
- app/views/layouts/admin.html.erb — FOUND
- app/views/admin/shared/_sidebar.html.erb — FOUND
- app/controllers/admin/clients_controller.rb — FOUND
- app/views/admin/clients/index.html.erb — FOUND
- app/views/admin/clients/_client_row.html.erb — FOUND
- app/views/admin/clients/_status_badge.html.erb — FOUND
- app/views/admin/clients/_actions_menu.html.erb — FOUND
- app/javascript/controllers/dropdown_controller.js — FOUND

Commits:
- e67679c: feat(02-01): migração password_plain, layout admin, sidebar, controller clients e rotas — FOUND
- 874cf69: feat(02-01): view index de clientes, partials client_row/status_badge/actions_menu e dropdown_controller — FOUND
