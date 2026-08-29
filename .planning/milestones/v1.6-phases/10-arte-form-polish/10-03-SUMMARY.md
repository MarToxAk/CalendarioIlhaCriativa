---
phase: 10-arte-form-polish
plan: "03"
subsystem: ui
tags: [tailwind, erb, rails-views, page-wrapper, back-link]

# Dependency graph
requires:
  - phase: 10-01
    provides: _form.html.erb com locals button_label e cancel_path prontos para receber valores
provides:
  - new.html.erb com back link para admin_artes_path e card max-w-2xl shadow-card
  - edit.html.erb com back link mostrando @arte.title e card max-w-2xl shadow-card
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Page wrapper com bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl"
    - "Back link com aria label e hover transition-colors (padrão clients)"
    - "Render de partial com locals explícitos: arte:, button_label:, cancel_path:"

key-files:
  created: []
  modified:
    - app/views/admin/artes/new.html.erb
    - app/views/admin/artes/edit.html.erb

key-decisions:
  - "Usar max-w-2xl (não max-w-lg do analog clients) — form de artes tem ~10 campos, precisa de largura maior (D-01)"
  - "edit.html.erb usa admin_arte_path(@arte) para o back link (singular) e @arte.title para o texto — diferença crítica do analog @client.name"

patterns-established:
  - "Estrutura page wrapper de artes: content_for + back link div.mb-6 + div.shadow-card max-w-2xl com render do form"

requirements-completed: [PAGE-01, PAGE-02]

# Metrics
duration: 2min
completed: 2026-06-03
---

# Phase 10 Plan 03: Arte Form Polish — Page Wrappers Summary

**Pages new/edit de artes reescritas com back link e card container (shadow-card max-w-2xl), replicando exatamente o padrão visual das páginas de clients com adaptações de path e locals**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-03T14:26:20Z
- **Completed:** 2026-06-03T14:28:12Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `new.html.erb` reescrita: back link para `admin_artes_path` com aria label "Voltar para lista de artes", card wrapper `shadow-card max-w-2xl`, render do form com `button_label: "Criar arte"` e `cancel_path: admin_artes_path`
- `edit.html.erb` reescrita: back link para `admin_arte_path(@arte)` mostrando `@arte.title`, card wrapper `shadow-card max-w-2xl`, render do form com `button_label: "Salvar alterações"` e `cancel_path: admin_arte_path(@arte)`
- Ambas as páginas eliminam o render nu do form (sem container visual) que existia antes — o formulário agora flutua dentro de um card branco com sombra

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1: new.html.erb com back link e card wrapper (PAGE-01)** - `5c3e99a` (feat)
2. **Task 2: edit.html.erb com back link personalizado e card wrapper (PAGE-02)** - `ccaa04b` (feat)

## Files Created/Modified

- `app/views/admin/artes/new.html.erb` — Substituição completa: era 3 linhas (render sem container), agora 16 linhas com back link e card wrapper; render passa `button_label` e `cancel_path` explicitamente
- `app/views/admin/artes/edit.html.erb` — Substituição completa: era 3 linhas (render sem container), agora 16 linhas com back link personalizado mostrando `@arte.title` e card wrapper; render passa `button_label` e `cancel_path` explicitamente

## Decisions Made

- `max-w-2xl` usado em vez de `max-w-lg` do analog clients — o form de artes tem aproximadamente 10 campos (título, cliente, plataforma, tipo de mídia, data, prazo, legenda, upload/link) contra 3 campos do form de clients; container mais largo evita cramping visual
- `@arte.title` (não `@arte.name`) — model Arte usa o atributo `:title` como identificador principal; o analog `@client.name` não se traduz diretamente

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito. Ambos os arquivos corresponderam precisamente ao resultado esperado documentado no PATTERNS.md.

## Known Stubs

Nenhum — ambas as páginas estão completamente funcionais sem dados hardcoded ou placeholders.

## Threat Flags

Nenhuma nova superfície de segurança introduzida. A interpolação `<%= @arte.title %>` no back link do edit usa o escape padrão do Rails (`<%= %>` sem `html_safe` ou `raw`) — conforme T-10-01 do threat model do plano, a mitigação de XSS está ativa.

## User Setup Required

Nenhum.

## Next Phase Readiness

- Pages new/edit prontas com o mesmo padrão visual das pages de clients
- Plano 10-01 (form partial) e plano 10-03 (page wrappers) completam juntos a experiência visual do fluxo de criação/edição de artes

## Self-Check: PASSED

- app/views/admin/artes/new.html.erb: FOUND
- app/views/admin/artes/edit.html.erb: FOUND
- .planning/phases/10-arte-form-polish/10-03-SUMMARY.md: FOUND
- Commit 5c3e99a: FOUND
- Commit ccaa04b: FOUND
- new.html.erb shadow-card count: 1 (esperado 1)
- new.html.erb max-w-2xl count: 1 (esperado 1)
- new.html.erb admin_artes_path count: 2 (esperado 2)
- new.html.erb button_label count: 1 (esperado 1)
- new.html.erb max-w-lg count: 0 (esperado 0)
- edit.html.erb shadow-card count: 1 (esperado 1)
- edit.html.erb max-w-2xl count: 1 (esperado 1)
- edit.html.erb @arte.title count: 2 (esperado 2)
- edit.html.erb admin_arte_path(@arte) count: 2 (esperado 2)
- edit.html.erb button_label count: 1 (esperado 1)
- edit.html.erb max-w-lg count: 0 (esperado 0)

---
*Phase: 10-arte-form-polish*
*Completed: 2026-06-03*
