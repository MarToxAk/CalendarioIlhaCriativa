---
phase: 02-admin-auth-client-management
verified: 2026-05-25T12:00:00Z
status: human_needed
score: 16/16 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 6/8
  gaps_closed:
    - "Admin clica 'Desativar cliente', um modal de confirmação abre, ao confirmar o cliente fica inativo e o portal bloqueia acesso — FIXED: _confirm_modal suporta hidden_fields: local; show.html.erb passa hidden_fields: { client: { active: false } }"
    - "Portal não bloqueava clientes inativos — FIXED: client_controller.rb e client/sessions_controller.rb têm guard unless active? com return 403/422"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Clicar 'Copiar link' e 'Copiar senha' na tela /admin/clients/:id"
    expected: "Botão muda para 'Copiado!' verde por 2 segundos, conteúdo vai para a área de transferência"
    why_human: "navigator.clipboard requer contexto de browser HTTPS/localhost com permissão"
  - test: "Abrir modal de desativação, pressionar Tab repetidamente"
    expected: "Foco cicla apenas entre os elementos internos do modal (focus trap funcional)"
    why_human: "Comportamento de foco no DOM requer browser em runtime"
  - test: "Abrir modal de desativação ou rotação de token e pressionar Escape"
    expected: "Modal fecha sem executar nenhuma ação"
    why_human: "Listener de teclado em Stimulus controller requer browser"
  - test: "Clicar 'Desativar cliente', confirmar no modal, e tentar acessar o portal do cliente desativado"
    expected: "Portal retorna mensagem 'Acesso bloqueado' (403) — cliente não consegue acessar nem autenticar"
    why_human: "Fluxo completo end-to-end admin-desativa → portal-bloqueia requer browser e sessão real"
---

# Phase 02: Admin Auth + Client Management — Relatório de Verificação

**Phase Goal:** O admin consegue fazer login, criar e gerenciar clientes, e copiar o link + senha de acesso de cada cliente. Inclui o layout completo do admin (sidebar + topbar) e CRUD de clientes com desativação e rotação de token.
**Verificado:** 2026-05-25T12:00:00Z
**Status:** HUMAN NEEDED
**Re-verificação:** Sim — após fechamento dos 2 gaps da verificação inicial

---

## Resultado da Re-Verificação

| Gap anterior | Status |
|---|---|
| Modal de desativação sem payload (ParameterMissing) | FECHADO |
| Portal não bloqueava clientes inativos | FECHADO |
| Regressões nos testes existentes | NENHUMA — 25 runs, 0 failures, 0 errors |

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidência |
|---|-------|--------|-----------|
| 1 | Admin autenticado acessa /admin/clients e vê a tabela de clientes com layout sidebar + topbar | ✓ VERIFIED | `admin.html.erb` renderiza sidebar + topbar. `index.html.erb` tem tabela com `@clients.each` e estado vazio. `Admin::BaseController` tem `layout 'admin'`. |
| 2 | Layout admin usa sidebar verde #0F7949 com link ativo via current_page? | ✓ VERIFIED | `_sidebar.html.erb` linha 1: `bg-[#0F7949]`. Active: `current_page?(item[:path]) ? 'bg-white/20 text-white' : 'text-white/70 ...'`. |
| 3 | A coluna password_plain existe na tabela clients no banco | ✓ VERIFIED | `db/schema.rb` linha 51: `t.string "password_plain"`. Runner confirma `true`. |
| 4 | Admin::BaseController declara layout 'admin' e views admin herdam esse layout | ✓ VERIFIED | `base_controller.rb` linha 2: `layout 'admin'`. |
| 5 | Dropdown de ações '...' abre/fecha via Stimulus dropdown controller | ✓ VERIFIED | `_actions_menu.html.erb` tem `data-controller="dropdown"`. `dropdown_controller.js` tem `toggle()`, `hide()`, `connect()`/`disconnect()` com `outsideClickHandler`. |
| 6 | Admin acessa /admin/clients/new, preenche nome e senha, é redirecionado para show com flash de sucesso | ✓ VERIFIED | `create` action: `redirect_to admin_client_path(@client), notice: "Cliente cadastrado com sucesso."`. Teste "create com dados válidos" passa. |
| 7 | Admin edita cliente com senha em branco, salva, e a senha anterior é mantida | ✓ VERIFIED | Guard D-10 no `update`. Teste "update com senha em branco mantém senha original" passa (6 runs, 0 failures). |
| 8 | Erros de validação são exibidos inline abaixo do campo com mensagens PT-BR | ✓ VERIFIED | `_form.html.erb`: `span[role="alert"]`. Teste com `assert_select "span[role='alert']"` passa. |
| 9 | Campo senha usa password_toggle_controller para mostrar/ocultar | ✓ VERIFIED | `_form.html.erb`: `data-controller="password-toggle"` com targets `field` e `toggle`. |
| 10 | password_plain é salvo no create com o mesmo valor que password | ✓ VERIFIED | `create` action: `merge(password_plain: params_with_plain[:password])`. Teste `assert_equal "abcd1234", novo_cliente.password_plain` passa. |
| 11 | Admin acessa /admin/clients/:id e vê link de acesso e senha em texto puro com botões de cópia | ✓ VERIFIED | `show.html.erb`: `_readonly_field` com `client_root_url(token: @client.access_token)`, `type="text"` com `@client.password_plain`, `_copy_button` para ambos. |
| 12 | Admin clica 'Copiar link' e o botão muda para 'Copiado!' por 2 segundos | ? NEEDS HUMAN | `#showCopied()` com `setTimeout(2000ms)` e troca de classes implementado em `copy_controller.js`. Requer browser. |
| 13 | Admin clica 'Desativar cliente', confirma no modal e o cliente fica inativo e o portal bloqueia acesso | ✓ VERIFIED (código) / ? NEEDS HUMAN (E2E) | `_confirm_modal` suporta `hidden_fields:`. `show.html.erb` passa `hidden_fields: { client: { active: false } }`. `client_controller.rb` retorna 403 para clientes inativos. `client/sessions_controller.rb` retorna 422 (redirecionado para 403 pelo before_action). 6 testes admin + 7 testes sessions passam cobrindo ativação/desativação. |
| 14 | Admin clica 'Rotacionar token', um modal de aviso abre, ao confirmar o link muda | ✓ VERIFIED | `show.html.erb` tem `div[data-controller="modal"]` + `_confirm_modal` com `rotate_token_admin_client_path`. `rotate_token` action chama `@client.regenerate_access_token`. |
| 15 | Senha visível por padrão (type=text) com toggle para ocultar | ✓ VERIFIED | `show.html.erb` linha 62: `<input type="text" readonly`. `aria-pressed="true"` no toggle. |
| 16 | Modal tem focus trap: Tab cicla dentro do modal, Escape fecha, foco inicial no cancelar | ? NEEDS HUMAN | `modal_controller.js` implementa: getter `boundFocusTrap`, `boundKeydown` para Escape, foco em `[data-modal-cancel]`. Verificação requer browser. |

**Score:** 16/16 truths verificadas (14 VERIFIED, 2 NEEDS HUMAN / comportamental)

---

## Required Artifacts

| Artefato | Status | Detalhes |
|---------|--------|---------|
| `app/views/layouts/admin.html.erb` | ✓ VERIFIED | Sidebar + topbar + flash `role="alert" aria-live="assertive"` |
| `app/views/admin/shared/_sidebar.html.erb` | ✓ VERIFIED | `bg-[#0F7949]`, active links, button_to "Sair" |
| `app/controllers/admin/base_controller.rb` | ✓ VERIFIED | `layout 'admin'` linha 2 |
| `app/controllers/admin/clients_controller.rb` | ✓ VERIFIED | 7 actions: `[:create, :edit, :index, :new, :rotate_token, :show, :update]`. Guard D-10. Flash diferenciada para ativar/desativar. |
| `app/views/admin/clients/index.html.erb` | ✓ VERIFIED | Tabela + estado vazio "Nenhum cliente cadastrado" + mobile cards |
| `app/views/admin/clients/_client_row.html.erb` | ✓ VERIFIED | `opacity-60` para clientes inativos |
| `app/views/admin/clients/_status_badge.html.erb` | ✓ VERIFIED | `text-amber-800` no badge inativo (contraste AA) |
| `app/views/admin/clients/_actions_menu.html.erb` | ✓ VERIFIED | `data-controller="dropdown"`, `aria-expanded="false"`, dropdown ul com role="menu" |
| `app/javascript/controllers/dropdown_controller.js` | ✓ VERIFIED | `toggle()`, `hide()`, `outsideClickHandler` com `connect()`/`disconnect()` |
| `app/views/admin/clients/new.html.erb` | ✓ VERIFIED | Card `shadow-card`, renderiza `_form` |
| `app/views/admin/clients/edit.html.erb` | ✓ VERIFIED | Pré-preenchido, renderiza `_form` |
| `app/views/admin/clients/_form.html.erb` | ✓ VERIFIED | `client.persisted?`, password toggle, erros inline, "Deixe em branco para manter" |
| `test/controllers/admin/clients_controller_test.rb` | ✓ VERIFIED | 6 runs, 26 assertions, 0 failures, 0 errors |
| `app/views/admin/clients/show.html.erb` | ✓ VERIFIED | Link readonly + senha `type="text"` + modais desativar/rotacionar com data-controller="modal" |
| `app/views/admin/clients/_copy_button.html.erb` | ✓ VERIFIED | `data-controller="copy"`, `aria-live="polite"`, `[data-copy-label]`, `[data-copy-icon]` |
| `app/views/admin/clients/_confirm_modal.html.erb` | ✓ VERIFIED | `aria-modal="true"`, `data-modal-cancel`, `hidden_fields:` local com iteração dois níveis |
| `app/views/admin/clients/_readonly_field.html.erb` | ✓ VERIFIED | `select-all`, `font_mono`, `show_external_link`, renderiza `_copy_button` |
| `app/javascript/controllers/copy_controller.js` | ✓ VERIFIED | `navigator.clipboard.writeText()`, `#showCopied()` com setTimeout 2000ms, fallback |
| `app/javascript/controllers/modal_controller.js` | ✓ VERIFIED | Focus trap getter lazy, Escape, foco em `[data-modal-cancel]`, `removeEventListener` em `disconnect()` |
| `app/controllers/client_controller.rb` | ✓ VERIFIED | Guard `unless @client.active?` retorna 403 em `load_client_from_token` |
| `app/controllers/client/sessions_controller.rb` | ✓ VERIFIED | Guard `unless @client.active?` com `return` explícito antes de `authenticate` |
| `test/controllers/client/sessions_controller_test.rb` | ✓ VERIFIED | 7 runs, 22 assertions, 0 failures, 0 errors |

---

## Key Link Verification

| From | To | Via | Status | Detalhes |
|------|----|-----|--------|---------|
| `Admin::BaseController` | `admin.html.erb` | `layout 'admin'` | ✓ WIRED | Linha 2: `layout 'admin'` |
| `admin.html.erb` | `_sidebar.html.erb` | `render "admin/shared/sidebar"` | ✓ WIRED | Linha 24: `<%= render "admin/shared/sidebar" %>` |
| `_actions_menu.html.erb` | `dropdown_controller.js` | `data-controller="dropdown"` | ✓ WIRED | Linha 1: `data-controller="dropdown"` |
| `_copy_button.html.erb` | `copy_controller.js` | `data-controller="copy"` | ✓ WIRED | Linha 2: `data-controller="copy"` |
| `show.html.erb` | `modal_controller.js` | `data-controller="modal"` | ✓ WIRED | Linhas 16 e 92: dois `div[data-controller="modal"]` independentes |
| `_confirm_modal.html.erb` (desativar) | `clients_controller.rb#update` | `hidden_field_tag "client[active]" + PATCH` | ✓ WIRED | `hidden_fields: { client: { active: false } }` no render; partial itera e emite `hidden_field_tag "client[active]", false` |
| `client_controller.rb` | `Client#active?` | `guard unless @client.active?` | ✓ WIRED | Linha 11: `unless @client.active?` retorna 403 |
| `client/sessions_controller.rb` | `Client#active?` | `guard before authenticate` | ✓ WIRED | Linha 8: `unless @client.active?` com return explícito |

---

## Data-Flow Trace (Level 4)

| Artefato | Variável de dados | Fonte | Produz dados reais | Status |
|---------|-----------------|-------|-------------------|--------|
| `show.html.erb` — link de acesso | `@client.access_token` | `Client.find(params[:id])` em `set_client` | Sim — DB query real | ✓ FLOWING |
| `show.html.erb` — senha | `@client.password_plain` | `Client.find(params[:id])` em `set_client` | Sim — DB query real | ✓ FLOWING |
| `index.html.erb` — tabela | `@clients` | `Client.order(created_at: :desc)` em `index` | Sim — DB query real | ✓ FLOWING |
| `_confirm_modal` — desativar | `hidden_field client[active]` | `hidden_fields: { client: { active: false } }` no render | Sim — valor fixo intencional `false` | ✓ FLOWING |

---

## Behavioral Spot-Checks

| Comportamento | Comando | Resultado | Status |
|--------------|---------|-----------|--------|
| password_plain existe no DB | `bin/rails runner "puts Client.column_names.include?('password_plain')"` | `true` | ✓ PASS |
| 7 actions no ClientsController | `bin/rails runner "puts Admin::ClientsController.instance_methods(false).sort.inspect"` | `[:create, :edit, :index, :new, :rotate_token, :show, :update]` | ✓ PASS |
| Rota rotate_token existe | `bin/rails routes \| grep rotate_token_admin_client` | `POST /admin/clients/:id/rotate_token` | ✓ PASS |
| Rotas CRUD admin/clients | `bin/rails routes \| grep admin_client` | GET, POST, PATCH, GET/:id, GET/:id/edit, GET/new | ✓ PASS |
| Testes admin/clients passam | `bin/rails test test/controllers/admin/clients_controller_test.rb` | `6 runs, 26 assertions, 0 failures, 0 errors` | ✓ PASS |
| Testes client/sessions passam | `bin/rails test test/controllers/client/sessions_controller_test.rb` | `7 runs, 22 assertions, 0 failures, 0 errors` | ✓ PASS |
| Todos os controller tests | `bin/rails test test/controllers/` | `25 runs, 98 assertions, 0 failures, 0 errors` | ✓ PASS |
| active? guard em client_controller | `grep -c "active?" app/controllers/client_controller.rb` | `1` | ✓ PASS |
| active? guard em sessions create | `grep -c "active?" app/controllers/client/sessions_controller.rb` | `1` | ✓ PASS |
| hidden_fields no confirm_modal | `grep -c "hidden_fields" app/views/admin/clients/_confirm_modal.html.erb` | `4` | ✓ PASS |
| active:false no render de desativação | `grep "active: false" app/views/admin/clients/show.html.erb` | match na linha 31 | ✓ PASS |

---

## Requirements Coverage

| Requirement | Plano(s) | Descrição | Status | Evidência |
|-------------|---------|-----------|--------|-----------|
| CLIE-01 | 02-01, 02-02 | Admin pode criar um novo cliente com nome e senha do portal | ✓ SATISFIED | `create` action + `new.html.erb` + `_form` + `password_plain` sincronizado + teste passando |
| CLIE-02 | 02-01, 02-02 | Admin pode editar os dados de um cliente (nome, senha) | ✓ SATISFIED | `update` action + `edit.html.erb` + guard D-10 blank-password + teste passando |
| CLIE-03 | 02-01, 02-03, 02-05 | Admin pode desativar um cliente (bloqueia acesso ao portal) | ✓ SATISFIED | Admin-side: modal + PATCH com `client[active]=false` funcional. Portal-side: guard `active?` em `client_controller.rb` + `sessions_controller.rb`. Testes: 2 testes admin (desativar/reativar) + 2 testes portal (403 para inativo) passando. |
| CLIE-04 | 02-03 | Admin pode ver o link de acesso e a senha do portal de cada cliente para copiar e enviar | ✓ SATISFIED | `show.html.erb` com `_readonly_field` (link com font-mono + external link) + campo `type="text"` (senha visível por padrão) + `_copy_button` para ambos com `copy_controller.js` |

---

## Anti-Patterns Found

| Arquivo | Linha | Padrão | Severidade | Impacto |
|---------|-------|--------|-----------|---------|
| `_actions_menu.html.erb` | 29 | `link_to "#"` para "Desativar cliente" no dropdown | ⚠ WARNING | Stub documentado em 02-01-SUMMARY "Known Stubs". O fluxo de desativação real está em `show.html.erb` com modal completo. Usuário clicando no dropdown apenas fecha o dropdown sem executar a ação — comportamento aceitável como atalho que redireciona para show. |

Nenhum marcador de dívida técnica bloqueador (TBD, FIXME, XXX) encontrado nos arquivos modificados por esta fase.

---

## Human Verification Required

### 1. Funcionalidade de Copiar Link e Senha

**Test:** Acessar `/admin/clients/:id` de um cliente existente. Clicar "Copiar link" e depois "Copiar senha".
**Expected:** Botão muda para "Copiado!" com fundo verde e ícone check por 2 segundos, depois retorna ao estado original. Conteúdo correspondente está na área de transferência do sistema operacional.
**Why human:** `navigator.clipboard.writeText()` requer contexto HTTPS/localhost com permissão explícita de browser — não verificável via grep ou runner Rails.

### 2. Focus Trap do Modal

**Test:** Abrir o modal de desativação clicando "Desativar cliente". Pressionar Tab repetidamente.
**Expected:** O foco cicla apenas entre os elementos internos do modal: botão cancelar → botão confirmar → botão fechar (✕) → volta para cancelar. O foco não escapa para o conteúdo por trás do modal.
**Why human:** Comportamento de foco no DOM requer browser em runtime. `modal_controller.js` implementa a lógica mas não é verificável estaticamente.

### 3. Tecla Escape fecha o modal

**Test:** Abrir modal de desativação ou rotação de token. Pressionar Escape.
**Expected:** Modal fecha sem executar nenhuma ação. Foco retorna ao contexto anterior.
**Why human:** Listener de teclado no Stimulus controller requer browser.

### 4. Fluxo E2E de desativação + bloqueio do portal

**Test:** Criar um cliente com nome e senha via `/admin/clients/new`. Ir para `/admin/clients/:id`. Clicar "Desativar cliente", confirmar no modal. Em seguida, tentar acessar o portal do cliente pelo link gerado `/c/:token`.
**Expected:** Após desativação, o badge muda para "Inativo", flash de confirmação aparece. O portal responde com "Acesso bloqueado". O cliente não consegue nem chegar na tela de login.
**Why human:** Fluxo completo admin→portal requer browser com duas sessões (ou abas) e verificação visual do comportamento.

---

*Verificado: 2026-05-25T12:00:00Z*
*Verificador: Claude (gsd-verifier)*
*Re-verificação após planos 02-04 (supersedido) e 02-05*
