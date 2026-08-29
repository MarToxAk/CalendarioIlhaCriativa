---
phase: 13-p-gina-aprova-es
plan: "03"
subsystem: ui
tags: [rails, erb, tailwind, turbo-frames, pagy, accessibility, responsive]

# Dependency graph
requires:
  - phase: 13-02
    provides: Admin::ApprovalsController com index paginado e filtrável, view mínima base, 8 testes passando
  - phase: 13-01
    provides: Pagy::Backend/Frontend habilitados, rota admin_approvals registrada

provides:
  - View index.html.erb completa com filtros FORA do turbo-frame e tabela/paginação DENTRO
  - Partial _decision_badge.html.erb com hash config (approved=verde, change_requested=vermelho)
  - Partial _approval_row.html.erb com 6 colunas (CLIENTE, ARTE, DECISÃO, DATA, COMENTÁRIO, AÇÕES)
  - Tabela desktop (hidden sm:block) com aria-label e caption sr-only
  - Cards mobile (block sm:hidden) com cliente, badge, título, data e comentário
  - Estado vazio com heading "Nenhuma aprovação encontrada" e copy condicional
  - pagy_nav dentro do turbo-frame para paginação funcional

affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hash config para badge (não case/when) — mais conciso para 2 casos: {'approved' => {classes:, label:}, 'change_requested' => {classes:, label:}}"
    - "Filtro FORA do turbo-frame + conteúdo DENTRO: form data: { turbo_frame: 'approvals-content' } + <turbo-frame id='approvals-content'>"
    - "pagy_nav com <%== (raw output) pois retorna HTML já montado"
    - "Comentário condicional via ERB: classe diferente quando nil (text-slate-400 italic) vs presente (text-slate-500)"

key-files:
  created:
    - app/views/admin/approvals/_decision_badge.html.erb
    - app/views/admin/approvals/_approval_row.html.erb
  modified:
    - app/views/admin/approvals/index.html.erb

key-decisions:
  - "Badge usa hash config (não case/when) para melhor legibilidade com apenas 2 casos — conforme UI-SPEC"
  - "Classe CSS condicional na coluna Comentário: text-slate-400 italic quando vazio vs text-slate-500 quando presente"
  - "pagy_nav sempre renderizado dentro do turbo-frame mesmo com 1 página — simplifica código sem impacto funcional"

patterns-established:
  - "Decision badge: hash config com chaves string mapeando para {classes:, label:} com fallback safe"
  - "View index Turbo Frame: form fora + turbo-frame envolvendo tabela + estado vazio + pagy_nav"
  - "Cards mobile: link_to wrapping card inteiro — toda a área clicável navega para admin_arte_path"

requirements-completed: [APRO-05, APRO-06, APRO-07]

# Metrics
duration: 20min
completed: 2026-06-04
---

# Phase 13 Plan 03: Views da Página Aprovações Summary

**View index.html.erb com filtros Turbo Frame, tabela desktop acessível (aria-label + caption sr-only), cards mobile responsivos, badges de decisão (verde/vermelho) e paginação pagy — interface completa da Página Aprovações**

## Performance

- **Duration:** 20 min
- **Started:** 2026-06-04T04:10:00Z
- **Completed:** 2026-06-04T04:30:00Z
- **Tasks:** 2
- **Files modified:** 3 (2 criados + 1 substituído)

## Accomplishments
- `_decision_badge.html.erb` criado com hash config de 2 entradas (approved/change_requested) e fallback; span com `aria-hidden="true">●</span>` antes do label
- `_approval_row.html.erb` criado com 6 colunas exatas do UI-SPEC: CLIENTE, ARTE, DECISÃO, DATA (safe navigation), COMENTÁRIO (truncate 80 + fallback —), AÇÕES (link Ver arte → admin_arte_path)
- `index.html.erb` substituído com: filtros fora do turbo-frame, turbo-frame id="approvals-content", tabela desktop hidden sm:block, cards mobile block sm:hidden, estado vazio com copy condicional, pagy_nav dentro do frame
- Suite completa 112 testes, 322 assertions, 0 failures — sem regressões

## Task Commits

Cada task commitada atomicamente:

1. **Task 1: Criar _decision_badge e _approval_row (partials de linha)** - `d3b0692` (feat)
2. **Task 2: Criar view index.html.erb (filtros + turbo-frame + tabela + mobile + paginação)** - `09ebfa4` (feat)

## Files Created/Modified
- `app/views/admin/approvals/_decision_badge.html.erb` — Badge de decisão com hash config, 2 entradas (approved=verde, change_requested=vermelho) e fallback
- `app/views/admin/approvals/_approval_row.html.erb` — Linha de tabela com 6 colunas: cliente, arte, decisão (badge), data (safe nav), comentário (truncate + fallback), ações (Ver arte)
- `app/views/admin/approvals/index.html.erb` — View completa: h1 Aprovações, form filtros fora do turbo-frame, turbo-frame envolvendo tabela desktop + cards mobile + pagy_nav, estado vazio com heading correto

## Decisions Made
- Badge usa hash config (não case/when) — mais conciso para apenas 2 casos, conforme UI-SPEC e PATTERNS.md
- Classe CSS condicional no comentário: `text-slate-400 italic` quando vazio/nil vs `text-slate-500` quando presente — diferencia visualmente dado ausente de dado presente
- `pagy_nav` sempre renderizado (sem guard `if @pagy.pages > 1`) — simplifica o template; pagy não exibe nav com 1 página por padrão

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Issues Encountered
- Nenhum. Testes rodados do diretório principal (`cd /home/bot/calendario_livia && bin/rails test`) conforme padrão estabelecido no plano 13-02.

## Known Stubs
Nenhum — view renderiza dados reais de @approval_responses, sem valores hardcoded ou placeholders. Badge exibe labels "Aprovado" / "Pediu Alteração" com cores corretas do design system.

## Threat Flags
Nenhum — nenhum endpoint novo, path de auth ou boundary de trust adicionado. T-13-07 (XSS via approval_response.comment) mitigado: todos os campos de dado do usuário usam `<%= %>` (html_escape automático do Rails ERB). `truncate()` também escapa HTML. `<%==` usado apenas em `pagy_nav(@pagy)` que retorna HTML interno do framework — sem dado de usuário.

## User Setup Required
Nenhum — nenhuma configuração externa necessária.

## Next Phase Readiness
- Página Aprovações completa: infraestrutura (13-01) + controller (13-02) + views (13-03)
- Todos os requisitos APRO-03..07 satisfeitos ao final desta wave
- 112 testes passando — base sólida para próximas fases

---
*Phase: 13-p-gina-aprova-es*
*Completed: 2026-06-04*
