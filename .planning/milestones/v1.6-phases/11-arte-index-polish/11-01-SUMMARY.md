---
phase: 11-arte-index-polish
plan: 1
subsystem: ui
tags: [tailwind, erb, rails-views, responsive, status-badge]

# Dependency graph
requires:
  - phase: 10-arte-form-polish
    provides: botão verde #0F7949 estabelecido, padrão de classes Tailwind de formulários
  - phase: 07-art-upload-client-scoping-fix
    provides: "@artes collection no controller, admin/artes routes"
provides:
  - arte index.html.erb com thead estilizado, empty state, tabela desktop e cards mobile
  - partial _arte_row.html.erb com hover, padding, link Ver outline
  - partial _status_badge.html.erb com badges coloridos por status
affects: [12-arte-show-dashboard-polish, qualquer fase que toque admin/artes/index]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Status badge ERB via case/when com badge_classes + badge_label locais antes do span"
    - "Tabela desktop wrapper div hidden sm:block + cards mobile block sm:hidden (padrão clients)"
    - "Empty state com SVG + h2 + p + botão verde — padrão clients replicado para artes"

key-files:
  created:
    - app/views/admin/artes/_arte_row.html.erb
    - app/views/admin/artes/_status_badge.html.erb
  modified:
    - app/views/admin/artes/index.html.erb

key-decisions:
  - "D-01: Botão Nova Arte usa h-10 px-4 bg-[#0F7949] — padrão idêntico ao clients/index"
  - "D-02: Link Ver usa h-8 px-3 border border-gray-200 rounded-lg — outline discreto"
  - "D-03/04: thead com bg-gray-50 border-b; th com scope/uppercase/tracking-wide/text-slate-500"
  - "D-05/06: tr com hover:bg-gray-50; td com py-3 px-4 text-sm text-slate-900; .humanize nos enums"
  - "D-07: Empty state com SVG de imagem, título, texto e botão verde"
  - "D-08: hidden sm:block para tabela desktop; block sm:hidden para cards mobile"

patterns-established:
  - "Status badge para artes: case arte.status com badge_classes/badge_label antes do span — reutilizável"
  - "Index de recursos admin: div wrapper hidden sm:block para tabela + div block sm:hidden para cards"
  - "Enums Rails em views: sempre .humanize (não .capitalize) para evitar underscore visível"

requirements-completed: [IDX-01, IDX-02]

# Metrics
duration: 8min
completed: 2026-06-03
---

# Phase 11 Plan 1: Arte Index Polish Summary

**Tabela de artes reescrita com Tailwind puro: thead bg-gray-50, hover nas rows, botão verde #0F7949, link Ver outline h-8, empty state com SVG e cards responsivos para mobile**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-03T15:15:00Z
- **Completed:** 2026-06-03T15:23:38Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments

- Eliminou todas as classes Bootstrap legadas (`btn`, `btn-primary`, `btn-sm`) do index de artes
- Criou `_arte_row.html.erb` com hover, border, padding correto e link Ver outline discreto
- Criou `_status_badge.html.erb` com mapeamento de cores por status (pending/approved/change_requested/revised)
- Adicionou empty state funcional com SVG de imagem, título e botão de cadastro
- Implementou responsividade: tabela `hidden sm:block` + cards `block sm:hidden` para mobile

## Task Commits

1. **Task 1: Reescrever index.html.erb com header, empty state, tabela desktop e cards mobile** - `d241146` (feat)

**Plan metadata:** (SUMMARY commit — ver abaixo)

## Files Created/Modified

- `app/views/admin/artes/index.html.erb` — Reescrito: header com h1 font-semibold, botão Nova Arte verde, empty state, tabela desktop com thead/caption, cards mobile com status badge e data
- `app/views/admin/artes/_arte_row.html.erb` — Criado: tr hover:bg-gray-50, td py-3 px-4 text-sm, link Ver outline h-8, render status_badge, .humanize nos enums
- `app/views/admin/artes/_status_badge.html.erb` — Criado: badges coloridos por status via case/when — amarelo (pending), verde (approved), coral (change_requested), slate (revised)

## Decisions Made

- Honrou D-01 a D-08 do 11-CONTEXT.md sem desvios
- SVG do empty state usa ícone de imagem/fotografia (M4 16l4.586-4.586...) em vez do ícone de pessoas dos clients — mais adequado ao contexto de artes
- `_status_badge.html.erb` inclui cláusula `else` com `arte.status.humanize` como fallback para status não mapeados — prevenção defensiva

## Deviations from Plan

None — plano executado exatamente como especificado. Todos os critérios de aceitação (IDX-01, IDX-02) atendidos sem necessidade de auto-fixes.

## Issues Encountered

None.

## User Setup Required

None — nenhuma configuração externa necessária. Mudanças são de styling puro em views ERB.

## Next Phase Readiness

- Arte index visualmente consistente com clients index — pronto para uso
- Padrão `_status_badge.html.erb` estabelecido — pode ser reutilizado na fase 12 (arte show)
- Phase 12 (arte show + dashboard polish) pode prosseguir sem dependências desta fase

---
*Phase: 11-arte-index-polish*
*Completed: 2026-06-03*
