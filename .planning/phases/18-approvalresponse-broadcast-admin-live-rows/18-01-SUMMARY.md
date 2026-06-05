---
phase: 18-approvalresponse-broadcast-admin-live-rows
plan: "01"
subsystem: views-dom-preparation
tags: [turbo-streams, hotwire, sidebar-badge, toast, partial, dom-ids]
dependency_graph:
  requires: []
  provides:
    - partial:admin/shared/sidebar_badge
    - partial:admin/shared/approval_toast
    - dom-id:sidebar-badge-always-present
    - dom-id:approvals-tbody
    - dom-id:approval_response_N-on-tr
  affects:
    - app/views/admin/shared/_sidebar.html.erb
    - app/views/admin/approvals/index.html.erb
    - app/views/admin/approvals/_approval_row.html.erb
tech_stack:
  added: []
  patterns:
    - Turbo Stream replace target — span#sidebar-badge sempre no DOM com hidden class
    - Turbo Stream prepend target — tbody#approvals-tbody na tabela desktop
    - dom_id(record) para IDs de rows em partials de tabela
    - Partial isolado para broadcast replace (sidebar_badge)
key_files:
  created:
    - app/views/admin/shared/_sidebar_badge.html.erb
    - app/views/admin/shared/_approval_toast.html.erb
  modified:
    - app/views/admin/shared/_sidebar.html.erb
    - app/views/admin/approvals/_approval_row.html.erb
    - app/views/admin/approvals/index.html.erb
decisions:
  - "Partial _sidebar_badge.html.erb isolado para permitir Turbo Stream replace de #sidebar-badge sem elemento ausente na DOM"
  - "Badge span sempre renderizado com toggle de classe hidden (não conditional render) — padrão D-10"
  - "id=approvals-tbody apenas no tbody desktop; mobile cards não são alvo de broadcast (D-13)"
  - "dom_id(approval_response) adicionado ao <tr> para prevenir duplicatas no prepend (D-14)"
metrics:
  duration: "~3 minutes"
  completed: "2026-06-05T17:02:33Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 18 Plan 01: Preparação de Views para Turbo Stream Broadcasts — Summary

**One-liner:** Estrutura DOM preparada para broadcasts: sidebar badge sempre no DOM via partial isolado, toast partial pronto, approvals tbody e rows identificáveis por dom_id.

## O que foi feito

Este plano prepara todas as views que o Plan 02 precisará para fazer Turbo Stream replace/prepend/append funcionar sem elementos ausentes na DOM. Nenhuma funcionalidade real-time foi ativada — apenas infraestrutura DOM.

## Tarefas Completadas

| # | Nome | Commit | Arquivos |
|---|------|--------|---------|
| 1 | Sidebar badge sempre no DOM + partial _sidebar_badge | `748a7c1` | `_sidebar.html.erb`, `_sidebar_badge.html.erb` (NOVO) |
| 2 | Toast partial + dom_id em _approval_row + id="approvals-tbody" | `00db6e9` | `_approval_toast.html.erb` (NOVO), `_approval_row.html.erb`, `approvals/index.html.erb` |

## Arquivos Criados / Modificados

### Novos arquivos

**`app/views/admin/shared/_sidebar_badge.html.erb`**
- Partial isolado contendo somente o `<span id="sidebar-badge">`
- Classes: `ml-auto bg-red-500 text-white text-xs font-bold px-1.5 py-0.5 rounded-full`
- Toggle de visibilidade via `'hidden' if badge_count == 0` — elemento sempre presente na DOM
- Espera local `badge_count` (Integer)

**`app/views/admin/shared/_approval_toast.html.erb`**
- Toast de notificação para append em `#admin-toast-region`
- Integra com `toast_controller.js` via `data-controller="toast"` e `data-action="click->toast#dismiss"`
- Exibe: `arte.client.name`, `_decision_badge` (partial reutilizado), link "Ver arte" com `admin_arte_path`
- Locals: `approval_response` (ApprovalResponse), `arte` (Arte com `:client` eager-loaded)

### Arquivos modificados

**`app/views/admin/shared/_sidebar.html.erb`**
- Removido condicional `&& badge_count > 0` do bloco `if item[:path] == admin_approvals_path`
- `<span>` inline substituído por `render "admin/shared/sidebar_badge", badge_count: badge_count`
- `badge_count` já calculado via `Arte.where(status: :change_requested).count` — não duplicado

**`app/views/admin/approvals/_approval_row.html.erb`**
- Adicionado `id="<%= dom_id(approval_response) %>"` ao `<tr>` (gera `approval_response_N`)
- Previne duplicação quando broadcast prepend ocorre e admin recarrega a página

**`app/views/admin/approvals/index.html.erb`**
- Adicionado `id="approvals-tbody"` ao `<tbody>` da tabela **desktop** (dentro de `hidden sm:block`)
- Mobile cards (`block sm:hidden`) não modificados — não são alvo de broadcast (D-13)

## Deviations from Plan

None — plano executado exatamente conforme especificado.

## Observações de Ambiente

O teste `bin/rails test test/controllers/admin/dashboard_controller_test.rb` não pôde ser executado por ausência de conexão com banco de dados no ambiente CI. As verificações estáticas (grep) confirmam que todos os critérios de aceite foram atendidos.

## Known Stubs

Nenhum. Todos os partials criados têm fontes de dados bem definidas (locals explícitos).

## Threat Flags

Nenhuma nova superfície de segurança introduzida. Os partials recebem dados via locals (não via input de usuário direto). Rails ERB auto-escapa output — `arte.client.name` é protegido contra XSS (T-18-01-02).

## Self-Check: PASSED

- [x] `app/views/admin/shared/_sidebar_badge.html.erb` — existe, contém `sidebar-badge` e `'hidden' if badge_count == 0`
- [x] `app/views/admin/shared/_approval_toast.html.erb` — existe, contém `data-controller="toast"`, `click->toast#dismiss`, `admin_arte_path`, `decision_badge`, `arte.client.name`
- [x] `app/views/admin/shared/_sidebar.html.erb` — NÃO contém `badge_count > 0`, contém `render "admin/shared/sidebar_badge"`
- [x] `app/views/admin/approvals/_approval_row.html.erb` — contém `dom_id(approval_response)` no `<tr>`
- [x] `app/views/admin/approvals/index.html.erb` — contém `id="approvals-tbody"` no tbody desktop (não no mobile)
- [x] Commits `748a7c1` e `00db6e9` existem no `git log`
