# Phase 18: ApprovalResponse Broadcast + Admin Live Rows — Research

**Pesquisado:** 2026-06-05
**Domínio:** ActionCable · Turbo Streams · Rails 8.1 · Stimulus
**Confiança:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Decisões Bloqueadas

- **D-01:** Broadcast acionado por `after_create_commit` no model `ApprovalResponse`.
- **D-02:** Um único broadcast com múltiplos Turbo Streams (toast + badge + row) via `AdminNotificationsChannel.broadcast_to(user, ...)`.
- **D-03:** Lógica de broadcast em método privado direto no model (`broadcasts_to_admin`). Sem concern separado.
- **D-04:** RTUP-03 = **replace in-place** da linha existente da arte no dashboard (não prepend — evita duplicata).
- **D-05:** Criar partial `app/views/admin/dashboard/_arte_dashboard_row.html.erb` com `id: dom_id(arte)`. Dashboard refatora iteração para usar o partial.
- **D-06:** Falha silenciosa se arte não estiver na DOM (filtro ativo) — aceitável.
- **D-07:** Toast: nome do cliente + badge de decisão + botão "Ver arte" com `admin_arte_path(arte)`.
- **D-08:** Toast visual branco (`bg-white border border-gray-200 shadow-lg rounded-lg`). Badge interno: vermelho para "Pediu Alteração", verde para "Aprovado".
- **D-09:** Toast aparece em qualquer página — sem supressão condicional.
- **D-10:** Remover `if badge_count > 0` do sidebar. `<span id="sidebar-badge">` sempre presente — `hidden` quando count = 0.
- **D-11:** Badge count recalculado do banco via `Arte.change_requested.count` a cada broadcast.
- **D-12:** Badge atualizado **somente** quando `decision == "change_requested"`.
- **D-13:** Approvals page: adicionar `id="approvals-tbody"` ao `<tbody>` da tabela **desktop**. Mobile cards não são alvo de broadcast.
- **D-14:** Adicionar `id: dom_id(approval_response)` ao `<tr>` em `_approval_row.html.erb`.
- **D-15:** Em `broadcasts_to_admin`, usar `Arte.includes(:client).find(arte_id)` para evitar N+1.

### Discretion do Agente

- Nome/localização do partial do toast: `app/views/admin/shared/_approval_toast.html.erb`
- Ordem dos Turbo Streams: (1) append toast → (2) replace sidebar-badge → (3) replace arte row no dashboard → (4) prepend row na página Aprovações
- RTUP-04: `prepend` na `<tbody id="approvals-tbody">` reutilizando `_approval_row.html.erb`

### Deferred Ideas (FORA DO ESCOPO)

- Broadcasts para `ClientCalendarChannel` — Phase 19
- Decremento do badge — Phase 19
- Chips do calendário admin em real-time — Phase 20
- Supressão de toast quando admin está na página destino
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Descrição | Suporte da Pesquisa |
|----|-----------|----------------------|
| RTUP-01 | Badge no sidebar incrementa quando nova resposta "Pediu Alteração" chega (sem recarregar) | D-10, D-11, D-12: sidebar sempre renderiza `span#sidebar-badge`; Turbo Stream `replace` atualiza count via `Arte.change_requested.count` |
| RTUP-02 | Admin recebe toast em qualquer página do painel quando nova resposta chega | D-07, D-08, D-09: `after_create_commit` → broadcast → append em `#admin-toast-region` (infra Phase 17 já presente) |
| RTUP-03 | Dashboard admin recebe nova linha de arte em tempo real (replace in-place) | D-04, D-05: novo partial `_arte_dashboard_row.html.erb` com `id: dom_id(arte)`; Turbo Stream `replace` |
| RTUP-04 | Página Aprovações recebe nova linha no topo em tempo real | D-13, D-14: `id="approvals-tbody"` + `id: dom_id(approval_response)` no `<tr>`; Turbo Stream `prepend` |
</phase_requirements>

---

## Summary

A Fase 18 é inteiramente uma fase de **wiring** sobre a infraestrutura entregue pela Fase 17. Não há novas gems, novos canais ActionCable ou novos Stimulus controllers — o `AdminNotificationsChannel`, o `toast_controller.js`, o `#admin-toast-region` e o `turbo_stream_from` no layout já estão todos implementados e funcionando.

O trabalho central é: (1) adicionar um `after_create_commit :broadcasts_to_admin` ao model `ApprovalResponse` com um método privado que monta quatro Turbo Streams em uma única transmissão; (2) criar dois novos partials ERB (`_approval_toast.html.erb` e `_arte_dashboard_row.html.erb`); (3) fazer cirurgia mínima em três views existentes (sidebar, dashboard index, approvals index) e em um partial existente (`_approval_row.html.erb`).

O risco técnico principal está no **turbo-frame wrapping**: tanto o dashboard quanto a página Aprovações envolvem seu conteúdo em `<turbo-frame>`. Turbo Streams **ignoram** frames e substituem/acrescentam diretamente pelo ID, o que é o comportamento correto — mas o agente deve entender essa distinção para não buscar um wrapper de frame desnecessário. A segunda armadilha é usar `after_create` em vez de `after_create_commit`, que dispararia o broadcast dentro da transação aberta e poderia transmitir dados que ainda não estão visíveis para outras conexões de banco.

**Recomendação principal:** Implementar na ordem: sidebar fix → model callback + método privado → partial do toast → partial do dashboard row → refatorar dashboard view → adicionar IDs na página Aprovações e no partial _approval_row. Cada etapa é isolada e testável independentemente.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Disparar broadcast | Model (`ApprovalResponse`) | — | `after_create_commit` é o hook correto no ORM; o model encapsula o side-effect de persistência |
| Transmitir Turbo Streams | `AdminNotificationsChannel` (já existe) | — | Canal já estabelecido na Phase 17 com `broadcast_to` |
| Renderizar toast | `app/views/admin/shared/_approval_toast.html.erb` | `toast_controller.js` (Stimulus) | Partial ERB renderiza HTML; Stimulus gerencia auto-dismiss |
| Atualizar sidebar badge | `app/views/admin/shared/_sidebar.html.erb` | — | DOM target `#sidebar-badge` sempre presente após fix D-10 |
| Replace row no dashboard | `app/views/admin/dashboard/_arte_dashboard_row.html.erb` | — | Partial com `id: dom_id(arte)` é o target do Turbo Stream replace |
| Prepend row em Aprovações | `app/views/admin/approvals/_approval_row.html.erb` (existente) | — | Partial reutilizado; tbody com ID fixo é o target do prepend |

---

## Standard Stack

### Core (sem mudanças — tudo já instalado)

| Biblioteca | Versão | Propósito | Status |
|-----------|--------|-----------|--------|
| `turbo-rails` | Rails 8.1 bundle | Turbo Streams via ActionCable | ✅ Instalado |
| `stimulus-rails` | Rails 8.1 bundle | `toast_controller` auto-dismiss | ✅ Instalado |
| `solid_cable` | Rails 8.1 bundle | Adapter ActionCable via PostgreSQL (sem Redis) | ✅ Instalado |
| `actioncable` | Rails 8.1.3 | WebSocket server | ✅ Instalado |

**Nenhum novo pacote a instalar nesta fase.**

---

## Package Legitimacy Audit

> Nenhum novo pacote externo instalado nesta fase. Auditoria não aplicável.

---

## Architecture Patterns

### Fluxo de Dados — Fase 18

```
[Cliente] POST /client/responses
    │
    ▼
Client::ResponsesController#create
    │  locked_arte.approval_responses.build(response_params).save!
    ▼
ApprovalResponse (model)
    │  after_create_commit :broadcasts_to_admin
    │  after_create        :sync_arte_status  (já existente)
    ▼
broadcasts_to_admin (método privado)
    │  Arte.includes(:client).find(arte_id)   ← eager load (D-15)
    │  Arte.change_requested.count            ← server-authoritative badge count
    ▼
AdminNotificationsChannel.broadcast_to(admin, turbo_stream: [...])
    │
    ├─ turbo_stream.append("admin-toast-region", ...)    → toast em qualquer página
    ├─ turbo_stream.replace("sidebar-badge", ...)        → somente se change_requested
    ├─ turbo_stream.replace(dom_id(arte), ...)           → replace row no dashboard
    └─ turbo_stream.prepend("approvals-tbody", ...)      → prepend em Aprovações
           │
           ▼
    WebSocket → Admin browser (AdminNotificationsChannel subscriber)
           │
           ▼
    Turbo processa cada stream → DOM update instantâneo
           │
           ├─ #admin-toast-region: novo toast appended → toast_controller#connect auto-dismiss
           ├─ #sidebar-badge: innerHTML substituído com novo count
           ├─ #arte_42: <tr> do dashboard substituída com status atualizado
           └─ #approvals-tbody: nova <tr> prepended no topo (se admin na página Aprovações)
```

### Estrutura de Arquivos

```
app/
├── models/
│   └── approval_response.rb          # ADD: after_create_commit + broadcasts_to_admin
├── views/
│   └── admin/
│       ├── shared/
│       │   ├── _sidebar.html.erb     # MODIFY: fix badge condicional (D-10)
│       │   └── _approval_toast.html.erb  # CREATE: novo partial de toast
│       ├── dashboard/
│       │   ├── index.html.erb        # MODIFY: refatorar <tr> para usar partial
│       │   └── _arte_dashboard_row.html.erb  # CREATE: novo partial com id: dom_id(arte)
│       └── approvals/
│           ├── index.html.erb        # MODIFY: adicionar id="approvals-tbody" ao <tbody>
│           └── _approval_row.html.erb  # MODIFY: adicionar id: dom_id(approval_response) ao <tr>
```

### Padrão 1: `after_create_commit` para broadcasts ActionCable

**O que é:** Callback que dispara APÓS o commit da transação — essencial para broadcasts.
**Quando usar:** Qualquer broadcast via ActionCable que precisa de dados já persistidos e visíveis para outras conexões DB.

```ruby
# app/models/approval_response.rb
# [VERIFIED: codebase — padrão Rails 8 + turbo-rails]
class ApprovalResponse < ApplicationRecord
  # ... callbacks existentes ...
  after_create_commit :broadcasts_to_admin

  private

  def broadcasts_to_admin
    admin = User.first  # single-admin
    return unless admin

    arte_with_client = Arte.includes(:client).find(arte_id)
    badge_count = Arte.change_requested.count

    streams = [
      turbo_stream.append(
        "admin-toast-region",
        partial: "admin/shared/approval_toast",
        locals: { approval_response: self, arte: arte_with_client }
      ),
      (turbo_stream.replace(
        "sidebar-badge",
        partial: "admin/shared/sidebar_badge",
        locals: { badge_count: badge_count }
      ) if decision == "change_requested"),
      turbo_stream.replace(
        dom_id(arte_with_client),
        partial: "admin/dashboard/arte_dashboard_row",
        locals: { arte: arte_with_client }
      ),
      turbo_stream.prepend(
        "approvals-tbody",
        partial: "admin/approvals/approval_row",
        locals: { approval_response: self }
      )
    ].compact

    AdminNotificationsChannel.broadcast_to(admin, turbo_stream: streams)
  end
end
```

> **Nota crítica:** `broadcast_to(admin, turbo_stream: streams)` onde `streams` é um Array de objetos Turbo Stream. A chave `:turbo_stream` serializa o array para múltiplas tags `<turbo-stream>` no payload. [ASSUMED — padrão confirmado indiretamente pelo toast_controller e canal existentes, mas API do broadcast_to com array não verificada via Context7]

### Padrão 2: Sidebar badge sempre presente (D-10)

**O que é:** Remover condicional `if badge_count > 0` e usar toggle de classe `hidden`.

```erb
<%# app/views/admin/shared/_sidebar.html.erb — ANTES %>
<% if item[:path] == admin_approvals_path && badge_count > 0 %>
  <span id="sidebar-badge" ...><%= badge_count %></span>
<% end %>

<%# DEPOIS — elemento sempre presente na DOM %>
<% if item[:path] == admin_approvals_path %>
  <span id="sidebar-badge"
        class="ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full <%= 'hidden' if badge_count == 0 %>">
    <%= badge_count %>
  </span>
<% end %>
```

[VERIFIED: codebase — sidebar atual tem o condicional que precisa ser removido]

### Padrão 3: Dashboard row partial com `dom_id`

**O que é:** Extrair cada `<tr>` de arte para um partial com ID gerado por `dom_id`.

```erb
<%# app/views/admin/dashboard/_arte_dashboard_row.html.erb — CRIAR %>
<tr id="<%= dom_id(arte) %>" class="hover:bg-slate-50">
  <td class="px-4 py-3 text-sm text-slate-900"><%= arte.title.presence || "Sem título" %></td>
  <td class="px-4 py-3 text-sm text-slate-600"><%= arte.scheduled_on.strftime("%d/%m/%Y") %></td>
  <td class="px-4 py-3">
    <%= render "client/shared/arte_status_badge", arte: arte, compact: true %>
  </td>
  <td class="px-4 py-3">
    <%= link_to "Ver", admin_arte_path(arte),
          class: "inline-flex items-center h-8 px-3 border border-gray-200 rounded-lg text-xs text-slate-600 hover:bg-gray-50 transition-colors",
          data: { turbo_frame: "_top" } %>
  </td>
</tr>
```

[VERIFIED: codebase — padrão `dom_id` já em uso; `_arte_status_badge` aceita `compact: true`]

### Padrão 4: Toast partial com `data-controller="toast"`

```erb
<%# app/views/admin/shared/_approval_toast.html.erb — CRIAR %>
<div data-controller="toast"
     class="bg-white border border-gray-200 shadow-lg rounded-lg px-4 py-3 flex items-start gap-3 w-80">
  <div class="flex-1 min-w-0">
    <p class="text-sm font-semibold text-slate-900"><%= arte.client.name %></p>
    <%= render "admin/approvals/decision_badge", approval_response: approval_response %>
  </div>
  <%= link_to "Ver arte", admin_arte_path(arte),
        class: "text-xs text-[#0F7949] font-medium hover:underline shrink-0" %>
  <button data-action="click->toast#dismiss"
          class="text-slate-400 hover:text-slate-600 shrink-0" aria-label="Fechar">×</button>
</div>
```

> **Nota:** O partial recebe `arte` (já eager-loaded com client) e `approval_response`. Usa `arte.client.name` diretamente — sem query extra porque `Arte.includes(:client)` foi chamado em `broadcasts_to_admin` (D-15). [VERIFIED: codebase — toast_controller.js existe com connect/dismiss/\_enforceLimit]

### Anti-Patterns a Evitar

- **`after_create` em vez de `after_create_commit`:** Dispara dentro da transação aberta. O broadcast alcança o browser ANTES do commit — em caso de rollback, o admin veria dados fantasma.
- **Não usar `.compact` no array de streams:** Se `change_requested?` for falso, o condicional retorna `nil`; sem `.compact`, o nil seria serializado com erro.
- **`turbo_stream.replace` em elemento ausente da DOM:** Turbo ignora silenciosamente (falha silenciosa). Não gera erro JS — apenas nada acontece. Isso é o comportamento esperado quando filtro ativo oculta a arte (D-06).
- **Testar a DOM target `approvals-tbody` dentro do turbo-frame:** Turbo Streams são processados **globalmente** — não estão confinados ao turbo-frame `approvals-content`. O `prepend` em `#approvals-tbody` funciona mesmo o tbody estando dentro de `<turbo-frame>`.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por quê |
|----------|---------------|-------------------|---------|
| Auto-dismiss de toast | Timer JS manual | `toast_controller.js` (já existe) | Já implementado na Phase 17 com `DISMISS_DELAY = 5000` e `_enforceLimit` |
| Geração de DOM IDs | Strings manuais `"arte_#{id}"` | `dom_id(record)` helper Rails | Padrão Turbo; consistente com GlobalID |
| Eager loading no broadcast | `self.arte.client` (N+1) | `Arte.includes(:client).find(arte_id)` | Previne N+1 em cada broadcast (D-15) |
| Badge count de client-side | Incremento via JS puro | `Arte.change_requested.count` no broadcast | Server-authoritative; sem dessincronismo |
| Badge condicional via JS | Adicionar/remover elemento | Classe `hidden` + `replace` do Turbo Stream | Elemento sempre presente para Turbo Stream target |

---

## Common Pitfalls

### Pitfall 1: `after_create` vs `after_create_commit`

**O que dá errado:** Broadcast disparado enquanto a transação ainda está aberta. Se outra operação falhar e causar rollback, o admin já recebeu o toast para um registro que não existe.
**Por que acontece:** `after_create` é chamado dentro do bloco de transação. `after_create_commit` aguarda o `COMMIT`.
**Como evitar:** Usar **sempre** `after_create_commit` para efeitos colaterais que dependem de persistência final (broadcasts, emails, jobs).
**Sinais de alerta:** Toasts aparecendo para artes que depois somem do dashboard.

### Pitfall 2: Turbo Stream `replace` em elemento ausente

**O que dá errado:** Admin com filtro de status ativo — a `<tr id="arte_42">` não está na DOM. O `replace` é silenciosamente ignorado.
**Por que acontece:** Turbo Streams não lançam erro quando o target não existe.
**Como evitar:** D-06 — comportamento aceitável. Nenhuma ação necessária. Admin verá a atualização na próxima visita sem filtro.
**Sinais de alerta:** Nenhum (falha silenciosa esperada).

### Pitfall 3: Duplicata na página Aprovações

**O que dá errado:** Admin está na página Aprovações quando cliente envia resposta. O broadcast faz `prepend` de nova linha. Se o admin recarregar, o servidor renderiza a lista novamente — mas o `dom_id(approval_response)` único previne duplicata visual.
**Por que acontece:** Sem `id` no `<tr>`, dois elementos idênticos aparecem.
**Como evitar:** D-14 — `id: dom_id(approval_response)` no `<tr>` de `_approval_row.html.erb`.
**Sinais de alerta:** Linhas duplicadas na página Aprovações após reload.

### Pitfall 4: Badge `hidden` não togglado em zero

**O que dá errado:** Quando `badge_count` é 0, o Turbo Stream `replace` do `#sidebar-badge` substitui o span — mas se o template do partial não incluir a classe `hidden`, o badge exibe "0" visualmente.
**Por que acontece:** O partial de replace deve ser consistente com a lógica inicial do sidebar (classe `hidden` quando count = 0).
**Como evitar:** O partial `_sidebar_badge.html.erb` (ou inline no broadcast) deve aplicar `hidden` quando `badge_count == 0`.

### Pitfall 5: Toast sem `data-controller="toast"`

**O que dá errado:** Toast aparece mas não auto-dismisss após 5 segundos e não tem botão funcional de fechar.
**Por que acontece:** Stimulus conecta via `data-controller` attribute. Sem ele, o controller não é instanciado.
**Como evitar:** Garantir `data-controller="toast"` no elemento raiz do partial `_approval_toast.html.erb`.

### Pitfall 6: `broadcast_to` com `nil` em User.first

**O que dá errado:** Se não existe `User` no banco (ambiente de teste sem fixtures), `User.first` retorna `nil` e `AdminNotificationsChannel.broadcast_to(nil, ...)` lança `NoMethodError` ou broadcast sem target.
**Por que acontece:** Modelo single-admin assume sempre um user presente.
**Como evitar:** D-15 inclui `return unless admin` — guard clause já previsto.

---

## Code Examples

### Approvals index — adicionar `id="approvals-tbody"`

```erb
<%# app/views/admin/approvals/index.html.erb — ANTES %>
<tbody>
  <% @approval_responses.each do |ar| %>
    <%= render "approval_row", approval_response: ar %>
  <% end %>
</tbody>

<%# DEPOIS %>
<tbody id="approvals-tbody">
  <% @approval_responses.each do |ar| %>
    <%= render "approval_row", approval_response: ar %>
  <% end %>
</tbody>
```

[VERIFIED: codebase — tbody atual não tem ID]

### `_approval_row.html.erb` — adicionar `id: dom_id(approval_response)`

```erb
<%# ANTES %>
<tr class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">

<%# DEPOIS %>
<tr id="<%= dom_id(approval_response) %>"
    class="hover:bg-gray-50 transition-colors border-b border-gray-100 last:border-0">
```

[VERIFIED: codebase — `<tr>` atual não tem id]

### Dashboard index — refatorar iteração para usar partial

```erb
<%# app/views/admin/dashboard/index.html.erb — ANTES %>
<% artes.each do |arte| %>
  <tr class="hover:bg-slate-50">
    <td ...><%= arte.title.presence || "Sem título" %></td>
    <%# ... outras células ... %>
  </tr>
<% end %>

<%# DEPOIS %>
<% artes.each do |arte| %>
  <%= render "admin/dashboard/arte_dashboard_row", arte: arte %>
<% end %>
```

---

## Validation Architecture

### Test Framework

| Propriedade | Valor |
|-------------|-------|
| Framework | Minitest (Rails default) |
| Config | `test/test_helper.rb` |
| Comando rápido | `bundle exec ruby -Itest test/models/approval_response_test.rb` |
| Suite completa | `bundle exec rake test` |

### Phase Requirements → Test Map

| Req ID | Comportamento | Tipo de Teste | Arquivo | Existe? |
|--------|--------------|---------------|---------|---------|
| RTUP-01 | Badge count recalculado server-side, somente para change_requested | Unit (model) | `test/models/approval_response_test.rb` | ❌ Wave 0 — adicionar |
| RTUP-02 | `broadcasts_to_admin` é chamado no after_create_commit | Unit (model) | `test/models/approval_response_test.rb` | ❌ Wave 0 — adicionar |
| RTUP-03 | Broadcast inclui turbo_stream replace para `dom_id(arte)` | Unit (model) | `test/models/approval_response_test.rb` | ❌ Wave 0 — adicionar |
| RTUP-04 | Broadcast inclui turbo_stream prepend para "approvals-tbody" | Unit (model) | `test/models/approval_response_test.rb` | ❌ Wave 0 — adicionar |

### Padrão de teste para broadcasts ActionCable (Rails)

```ruby
# test/models/approval_response_test.rb — ADICIONAR
test "broadcasts_to_admin é chamado ao criar approval_response change_requested" do
  admin = users(:one)
  arte  = artes(:pending_one)  # fixture com client eager-loadable

  assert_broadcasts(AdminNotificationsChannel.broadcasting_for(admin), 1) do
    ApprovalResponse.create!(arte: arte, decision: :change_requested)
  end
end

test "broadcast nao ocorre se nao existir admin" do
  # User.first retorna nil — guard clause deve impedir broadcast
  User.delete_all
  arte = artes(:pending_one)
  assert_no_broadcasts(AdminNotificationsChannel.broadcasting_for(nil)) do
    ApprovalResponse.create!(arte: arte, decision: :approved)
  end
end
```

> `assert_broadcasts` requer `include ActionCable::TestHelper` no test case ou no `test_helper.rb`. [ASSUMED — API padrão do Rails, não verificada via Context7 nesta sessão]

### Sampling Rate

- **Por task commit:** `bundle exec ruby -Itest test/models/approval_response_test.rb`
- **Por wave merge:** `bundle exec rake test`
- **Phase gate:** Suite completa verde antes do `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/models/approval_response_test.rb` — adicionar testes de broadcast (RTUP-01 a 04)
- [ ] Fixtures: `test/fixtures/artes.yml` deve ter ao menos uma arte com client associado para testes de broadcast

---

## Security Domain

### ASVS Level 1 — Categorias Aplicáveis

| Categoria ASVS | Aplica | Controle |
|----------------|--------|---------|
| V2 Authentication | Não | — |
| V3 Session Management | Sim (parcial) | `AdminNotificationsChannel` rejeita sem `current_user` — já implementado na Phase 17 |
| V4 Access Control | Sim | Broadcast usa `User.first` — single-admin; canal já rejeita conexões sem sessão válida |
| V5 Input Validation | Não | Nenhuma entrada nova de usuário nesta fase; dados vêm de registros já validados |
| V6 Cryptography | Não | — |

### Ameaças Conhecidas para este Stack

| Padrão | STRIDE | Mitigação |
|--------|--------|-----------|
| Admin fake via WebSocket direto | Spoofing | `connection.rb` autentica via `session_id` cookie signed — já implementado |
| Broadcast vaza dados de outro admin | Information Disclosure | `stream_for current_user` — stream é per-user; `User.first` = single-admin, sem cross-user leak |
| XSS via `arte.client.name` no toast | Tampering | ERB auto-escapa (`<%= %>`) — seguro por padrão |

---

## State of the Art

| Abordagem Antiga | Abordagem Atual | Quando Mudou | Impacto |
|-----------------|-----------------|--------------|---------|
| `after_commit` genérico | `after_create_commit` específico | Rails 5.2+ | Mais semântico; não dispara em updates |
| `ActionCable.server.broadcast` manual | `Channel.broadcast_to(record, ...)` | Rails 6+ com turbo-rails | Abstração que usa GlobalID como stream name |
| Múltiplos broadcasts separados | Array de Turbo Streams em um broadcast | Turbo 1.x | Atomicidade: UI recebe todas as mudanças juntas |

---

## Assumptions Log

| # | Claim | Seção | Risco se Errado |
|---|-------|-------|-----------------|
| A1 | `AdminNotificationsChannel.broadcast_to(admin, turbo_stream: [array])` aceita array de streams diretamente | Padrão 1 (model callback) | Se a API exige string ou tag única, implementação quebra — ajustar para `turbo_stream.join` ou loops |
| A2 | `assert_broadcasts` com `ActionCable::TestHelper` funciona para channel broadcasts no Minitest | Validation Architecture | Se a API diferir, testes devem usar `assert_no_enqueued_jobs` ou mock direto |

---

## Open Questions

1. **API do `broadcast_to` com array de streams**
   - O que sabemos: O canal usa `broadcast_to(user, turbo_stream: ...)`. O toast_controller e layout existentes confirmam que a infraestrutura funciona.
   - O que está incerto: Se `turbo_stream:` aceita Array ou precisa ser string concatenada.
   - Recomendação: No Wave 0, verificar via `bundle exec rails console` em dev: `AdminNotificationsChannel.broadcast_to(User.first, turbo_stream: [Turbo::Streams::TagBuilder.new(view_context).append("test", html: "<p>ok</p>")])` — ou alternativamente usar `ApplicationController.renderer` para renderizar os streams como string.

---

## Environment Availability

| Dependência | Requerida Por | Disponível | Versão | Fallback |
|------------|--------------|------------|--------|----------|
| PostgreSQL | `solid_cable` + testes | ✓ (em dev) | — | — |
| Ruby 3.3.x | Runtime | ✓ | 3.3.3 | — |
| Rails 8.1.x | Framework | ✓ | 8.1.3 | — |
| `turbo-rails` | Turbo Streams | ✓ | bundled | — |
| `solid_cable` | ActionCable adapter | ✓ | bundled | — |

**Dependências faltando:** Nenhuma que bloqueie execução.

---

## Sources

### Primary (HIGH — verificado no codebase)

- `app/channels/admin_notifications_channel.rb` — canal pronto com `stream_for current_user`
- `app/javascript/controllers/toast_controller.js` — controller Stimulus com MAX_TOASTS=3, DISMISS_DELAY=5000
- `app/views/layouts/admin.html.erb` — `turbo_stream_from`, `#admin-toast-region`
- `app/views/admin/shared/_sidebar.html.erb` — badge com condicional a remover
- `app/views/admin/approvals/index.html.erb` — tbody sem ID (a adicionar)
- `app/views/admin/approvals/_approval_row.html.erb` — `<tr>` sem ID (a adicionar)
- `app/views/admin/dashboard/index.html.erb` — rows inline a extrair para partial
- `app/models/approval_response.rb` — callbacks existentes; `after_create_commit` a adicionar
- `app/models/arte.rb` — enum `status`, scope `change_requested` confirmado

### Secondary (MEDIUM — documentação oficial Rails + convenção turbo-rails)

- Turbo Handbook: `after_create_commit` → broadcast pattern — padrão estabelecido Rails 8
- Rails Guides ActionCable — `broadcast_to` API

### Tertiary (LOW — assumido por training)

- API exata de `broadcast_to(record, turbo_stream: [array])` — marcado como [ASSUMED] acima

---

## Metadata

**Breakdown de Confiança:**
- Stack padrão: HIGH — nenhum pacote novo; toda infra verificada no codebase
- Arquitetura: HIGH — fluxo completo rastreável no código existente
- Pitfalls: HIGH — identificados diretamente da leitura do código (sidebar condicional, `<tr>` sem ID, `<tbody>` sem ID)
- API de broadcast array: LOW — assumida pela convenção, não verificada via Context7

**Data da pesquisa:** 2026-06-05
**Válido até:** 2026-07-05 (stack estável)
