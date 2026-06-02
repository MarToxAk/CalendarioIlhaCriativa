---
phase: 07-art-upload-client-scoping-fix
plan: "02"
subsystem: ui
tags: [rails, erb, tailwind, activerecord, form]

# Dependency graph
requires:
  - phase: 07-art-upload-client-scoping-fix
    provides: contexto do bug D-01 a D-06; plan 01 corrige controller set_arte

provides:
  - "selector condicional de cliente em _form.html.erb (hidden_field quando client_id presente, f.select quando ausente)"
  - "bloco de exibicao de arte.errors[:base] no topo do form"

affects:
  - 07-art-upload-client-scoping-fix

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "selector condicional ERB: if arte.client_id.present? ? hidden_field : f.select com prompt PT-BR"
    - "bloco de erros :base com bg-red-50 no topo do form_with"

key-files:
  created: []
  modified:
    - app/views/admin/artes/_form.html.erb

key-decisions:
  - "O bloco condicional e inserido imediatamente antes da div flex gap-2 (botoes), nao dentro dela — form action buttons ficam limpos"
  - "Bloco de erros :base e inserido logo apos a abertura do form_with, antes do primeiro campo :title — erros sempre visiveis no topo"
  - "Client.order(:name) com prompt PT-BR 'Selecione o cliente' — consistente com restante do form"

patterns-established:
  - "Selector condicional de associacao: if objeto.attr.present? hidden_field else f.select end"
  - "Erros de :base em bg-red-50/border-red-200 no topo do form antes dos campos"

requirements-completed:
  - ARTE-08
  - ARTE-09

# Metrics
duration: 6min
completed: "2026-06-02"
---

# Phase 7 Plan 02: Form de Arte com Selector Condicional de Cliente e Exibicao de Erros

**Selector condicional de cliente (hidden_field vs f.select) e bloco de erros :base no _form.html.erb, habilitando criacao de artes sem client_id pre-definido e depuracao de erros de upload**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-02T16:20:00Z
- **Completed:** 2026-06-02T16:26:47Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Substitui `f.hidden_field :client_id` incondicional por bloco condicional: hidden_field quando `arte.client_id.present?`, `f.select` com `Client.order(:name)` quando ausente — ARTE-09 satisfeito
- Remove `f.hidden_field :client_id` da `div.flex.gap-2` (botoes), mantendo a div de acoes limpa
- Adiciona bloco de exibicao de `arte.errors[:base]` no topo do form com estilo `bg-red-50` — erros "Precisa de arquivo ou link externo" e "Use arquivo OU link externo, nao ambos" agora visiveis — ARTE-08 satisfeito

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1: Selector condicional de cliente no _form.html.erb** - `96f7846` (feat)
2. **Task 2: Exibir erros de :base no form de arte** - `7edcfa7` (feat)

## Files Created/Modified

- `app/views/admin/artes/_form.html.erb` — selector condicional de client_id + bloco de erros :base

## Decisions Made

- O bloco condicional `if arte.client_id.present?` fica imediatamente antes da `div.flex.gap-2` dos botoes, nao dentro dela — botoes de acao permanecem isolados de logica de campo
- Bloco de erros `:base` inserido antes do primeiro `<div class="mb-4">` (campo :title) para garantir visibilidade imediata ao topo da pagina
- Nao foi adicionado bloco separado para `errors[:client]` — o selector de client_id resolve o problema na fonte (D-03/D-04), tornando erros de associacao desnecessarios

## Deviations from Plan

Nenhuma — plano executado exatamente como especificado.

## Issues Encountered

Nenhum.

## User Setup Required

Nenhum — alteracoes sao apenas em ERB/view, sem dependencias externas ou configuracao de ambiente.

## Next Phase Readiness

- `_form.html.erb` corrigido e pronto: admin pode criar artes navegando direto para `/admin/artes/new` (selector exibido) ou via pagina do cliente (hidden_field com valor pre-preenchido)
- Erros de validacao de media (`:base`) agora visiveis ao re-renderizar o form apos falha
- Plans 01 e 02 do Phase 07 completos — verificacao manual de fluxo de upload pode ser realizada

---
*Phase: 07-art-upload-client-scoping-fix*
*Completed: 2026-06-02*
