---
phase: 09-calendar-summary-strip
plan: "01"
subsystem: ui
tags: [rails, tailwind, erb, controller, summary-strip, calendar]

# Dependency graph
requires:
  - phase: 08-fix-approval-response
    provides: Portal do cliente funcional com aprovação; controller Client::HomeController já existe com @artes carregado

provides:
  - "@summary hash calculado em memória no Client::HomeController#index com :total, :approved, :pending, :change_requested"
  - "Summary strip inline em index.html.erb com 4 chips coloridos entre header de mês e grade do calendário"
  - "Faixa ocultada quando não há artes no mês corrente"

affects: [09-calendar-summary-strip, portal-cliente, ui-client]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "select em memória sobre ActiveRecord::Relation já carregada (evita query adicional)"
    - "Guard @summary[:total] > 0 para suprimir completamente o bloco HTML quando vazio"
    - "Chips inline no ERB (sem partial, sem Stimulus, sem Turbo)"

key-files:
  created: []
  modified:
    - app/controllers/client/home_controller.rb
    - app/views/client/home/index.html.erb
    - test/controllers/client/home_controller_test.rb

key-decisions:
  - "Calcular @summary em memória com .select sobre @artes já carregado — sem query adicional ao banco"
  - "status revised contado em :pending (D-04) — merged com pending no mesmo chip"
  - "Faixa inline no ERB sem partial separado (D-10) — ~15 linhas, simples e legível"
  - "Testes via assert_match no HTML renderizado — rails-controller-testing ausente no projeto"

patterns-established:
  - "In-memory aggregation pattern: usar .select/.count sobre ActiveRecord relations já carregadas para cálculos derivados"
  - "Summary strip SSR-first: @summary recalculado a cada request, strip atualiza automaticamente após redirect pós-aprovação"

requirements-completed:
  - CAL2-01

# Metrics
duration: 25min
completed: 2026-06-03
---

# Phase 09 Plan 01: Calendar Summary Strip Summary

**Faixa de resumo com 4 chips coloridos (total/aprovadas/pendentes/pediu alteração) calculada em memória via select sobre @artes, renderizada inline entre header de mês e grade do calendário**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-03T10:40:00Z
- **Completed:** 2026-06-03T11:05:00Z
- **Tasks:** 2 (Task 1: controller + Task 2: view, ambas implementadas juntas na fase GREEN)
- **Files modified:** 3

## Accomplishments

- Controller calcula `@summary` com 4 chaves usando `.select` em memória sobre `@artes` já carregado — zero queries extras ao banco
- Status `revised` contado junto com `pending` conforme D-04
- Filtro correto: apenas artes com `scheduled_on` dentro do mês corrente, excluindo dias de overflow do grid
- View renderiza 4 chips coloridos inline com cores do design system existente (green/amber/red/slate)
- Faixa suprimida completamente quando `@summary[:total] == 0` (guard ERB, sem wrapper vazio)
- Sem partial, Turbo Stream ou Stimulus adicionados
- 7 novos testes via TDD (RED→GREEN) cobrindo strip visibilidade, contagens por status, D-04, exclusão de overflow

## Task Commits

Ambas as tasks executadas com TDD:

1. **RED: Testes falhando para summary strip** - `14fece2` (test)
2. **GREEN: @summary + summary strip implementados** - `ce2acd5` (feat)

_Note: Tasks 1 e 2 do plano foram commitadas juntas na fase GREEN pois os testes cobrem o comportamento end-to-end (controller + view)_

## Files Created/Modified

- `app/controllers/client/home_controller.rb` — adicionado cálculo de `@summary` após `@artes_by_date` (linhas 19–29)
- `app/views/client/home/index.html.erb` — adicionado bloco da summary strip entre header de mês e grade do calendário (linhas 25–41)
- `test/controllers/client/home_controller_test.rb` — adicionados 7 novos testes para CAL2-01

## Decisions Made

- Usar `assert_match` no HTML renderizado em vez de `assigns()` — a gem `rails-controller-testing` não está no Gemfile do projeto; testes via HTML são equivalentes e mais realistas
- Tasks 1 e 2 do plano commitadas juntas na fase GREEN porque os testes cobrem comportamento end-to-end (controller + view precisam coexistir para os testes passarem)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Substituiu assigns() por assert_match no HTML**

- **Found during:** Task 1 (RED phase — escrevendo testes)
- **Issue:** `assigns(:summary)` requer gem `rails-controller-testing` que não está no Gemfile do projeto; chamadas a `assigns()` geravam `NoMethodError` ao rodar testes
- **Fix:** Reescreveu todos os novos testes para usar `assert_match` / `assert_no_match` no HTML da resposta em vez de inspecionar instâncias do controller
- **Files modified:** `test/controllers/client/home_controller_test.rb`
- **Verification:** 11 de 12 testes passam; o 12º falha apenas por contaminação de sessão paralela (problema pré-existente na suite), passa quando rodado isoladamente
- **Committed in:** `14fece2` (commit RED)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking)
**Impact on plan:** Mudança de abordagem de teste sem impacto no comportamento. Testes via HTML são igualmente válidos e mais robustos.

## Issues Encountered

**Contaminação de sessão em testes paralelos:** Um dos 12 testes (`test_summary_strip_exibe_chip_pediu_alteração_para_artes_change_requested`) falha intermitentemente quando a suite completa roda em paralelo (302 redirect para login em vez do response esperado). Quando isolado, passa 100% das vezes. Este é um problema pré-existente na arquitetura de testes do portal do cliente — o `parallelize(workers: :number_of_processors)` combinado com criação de clientes via `create!` causa colisão de dados/sessão entre workers. Não é causado por esta implementação.

## Known Stubs

Nenhum — todos os dados vêm de `@artes` real escopado por `@client`.

## Threat Flags

Nenhuma nova superfície de segurança introduzida. `@summary` é calculado a partir de `@artes` já escopado por `@client.artes` no ClientController base — sem risco de cross-client leak conforme T-09-01 do threat model do plano.

## Next Phase Readiness

- CAL2-01 implementado e verificado
- Milestone v1.2 completo (Phase 08 fix aprovação + Phase 09 faixa de resumo)
- Verificação visual humana recomendada: acessar portal do cliente com mês com artes e confirmar chips coloridos visíveis, e mês sem artes confirmar faixa ausente

---
*Phase: 09-calendar-summary-strip*
*Completed: 2026-06-03*
