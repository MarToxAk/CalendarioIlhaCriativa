---
phase: 04-client-calendar-portal
plan: 02
subsystem: ui
tags: [rails, tailwind, calendar-grid, tdd, svg, i18n, security]

# Dependency graph
requires:
  - phase: 04-client-calendar-portal
    plan: 01
    provides: "layouts/client.html.erb, locale pt-BR, client_arte_path route"

provides:
  - Client::HomeController#index com lógica de calendário mensal e parse_month_param
  - Grade CSS grid-cols-7 (Seg–Dom) com dias do mês e artes agrupadas por data
  - Navegação < Mês Ano > via ?month=YYYY-MM sem JavaScript
  - Partial _arte_status_badge reutilizável (pending/approved/change_requested/revised)
  - Partial _platform_icon com SVG inline para Instagram, Facebook e LinkedIn
  - 5 testes automatizados cobrindo CAL-01, CAL-02, CAL-04, CAL-05

affects: [04-03-PLAN.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "parse_month_param com Date.strptime('%Y-%m') + rescue Date::Error para parâmetro inválido"
    - "@client.artes.where(scheduled_on: range).includes(media_file_attachment: :blob) — query escopada + eager loading"
    - "group_by(&:scheduled_on) para lookup O(1) na view"
    - "beginning_of_week..end_of_month.end_of_week para grid completo (Rails default monday)"
    - "SVG inline para ícones de plataforma (sem dependência de biblioteca externa)"
    - "Badge de status com mapeamento status→label PT-BR + classes Tailwind"

key-files:
  created:
    - app/controllers/client/home_controller.rb
    - app/views/client/home/index.html.erb
    - app/views/client/home/_month_calendar.html.erb
    - app/views/client/shared/_arte_status_badge.html.erb
    - app/views/client/shared/_platform_icon.html.erb
    - test/controllers/client/home_controller_test.rb
  modified:
    - config/locales/pt-BR.yml
    - test/models/arte_test.rb
    - test/models/client_test.rb

key-decisions:
  - "Implementação Ruby puro (sem simple_calendar helper) — controller calcula date_range diretamente com beginning_of_week..end_of_month.end_of_week"
  - "Query sempre @client.artes.where(...) — nunca Arte.where(...) — segurança de isolamento cross-client"
  - "rescue Date::Error no parse_month_param — parâmetro inválido fallback para mês corrente sem 500"
  - "SVG inline para ícones de plataforma — sem dependência de biblioteca de ícones externa"
  - "pt-BR locale errors.messages.blank adicionado — model tests atualizados para português"

# Metrics
duration: 20min
completed: 2026-05-25
---

# Phase 4 Plan 02: Monthly Calendar Grid Summary

**Grade mensal CSS 7 colunas com navegação < Mês Ano >, ícones SVG de plataforma e badges de status coloridos no portal do cliente**

## Performance

- **Duration:** 20 min
- **Started:** 2026-05-25
- **Completed:** 2026-05-25
- **Tasks:** 2 (TDD: task 1 RED+GREEN, task 2 views)
- **Files created/modified:** 9

## Accomplishments

- `Client::HomeController#index` implementado com lógica completa de calendário: `parse_month_param` (rescue Date::Error), query `@client.artes.where(scheduled_on: grid_start..grid_end).includes(media_file_attachment: :blob)`, `group_by(&:scheduled_on)`, e array `@grid_dates`
- Grade CSS `grid-cols-7` (Seg–Dom): cabeçalho com 7 colunas, células com número do dia (`text-gray-300` para dias sem artes, `bg-[#EA580C]` para hoje), artes empilhadas verticalmente
- Navegação `< Maio 2026 >` com chevrons SVG linkando para `?month=YYYY-MM` anterior/próximo
- Partial `_arte_status_badge.html.erb` com mapeamento de status → label PT-BR → classes Tailwind (amber/green/red/slate)
- Partial `_platform_icon.html.erb` com SVG inline para Instagram (#E1306C), Facebook (#1877F2), LinkedIn (#0A66C2)
- 5 testes automatizados (TDD): grade mensal, artes na grade, navegação, parâmetro inválido, requer autenticação
- Adicionado `pt-BR.errors.messages.blank` no locale; model tests atualizados de inglês para português

## TDD Gate Compliance

- **RED:** Testes criados e rodados → 1 falha (stub controller retorna `render plain:`) + 1 erro (locale faltando) confirmados
- **GREEN:** Controller implementado + views criadas → 5/5 testes passando
- **REFACTOR:** Não necessário

## Task Commits

1. **Task 1 + Task 2: Controller + Views completos** — `01ea4d4` (feat)

## Files Created/Modified

- `app/controllers/client/home_controller.rb` — Controller com parse_month_param, query escopada, @artes_by_date, @grid_dates
- `app/views/client/home/index.html.erb` — Navegação < Mês Ano > + render month_calendar partial
- `app/views/client/home/_month_calendar.html.erb` — Grade grid-cols-7, células com arte links, platform_icon e arte_status_badge
- `app/views/client/shared/_arte_status_badge.html.erb` — Badge reutilizável com 4 status + modo compact
- `app/views/client/shared/_platform_icon.html.erb` — SVG inline instagram/facebook/linkedin
- `test/controllers/client/home_controller_test.rb` — 5 testes cobrindo CAL-01, CAL-02, CAL-04, CAL-05
- `config/locales/pt-BR.yml` — Adicionado errors.messages.blank e activerecord equivalentes
- `test/models/arte_test.rb` — Atualizado assertion de inglês para português (não pode ficar em branco)
- `test/models/client_test.rb` — Atualizado assertion de inglês para português (não pode ficar em branco)

## Decisions Made

- Ruby puro para calendário (sem simple_calendar helper) — controller calcula o intervalo com Rails Date helpers
- `@client.artes.where(...)` nunca `Arte.where(...)` — isolamento cross-client garantido (T-04-02-01)
- `rescue Date::Error` no `parse_month_param` — parâmetro inválido nunca causa 500 (T-04-02-02)
- `.includes(media_file_attachment: :blob)` — evita N+1 queries na grade (T-04-02-04)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Functionality] Adicionado pt-BR.errors.messages.blank ao locale**
- **Found during:** Fase GREEN — model tests falhando com "Translation missing" para blank message
- **Issue:** `config.i18n.default_locale = :'pt-BR'` (04-01) ativou pt-BR globalmente mas o locale file não tinha `errors.messages.blank`, causando falha em 2 testes de model existentes
- **Fix:** Adicionado `errors.messages.blank`, `activerecord.errors.messages.blank` e chaves relacionadas ao `config/locales/pt-BR.yml`; assertions de "can't be blank" atualizadas para "não pode ficar em branco" em `test/models/arte_test.rb` e `test/models/client_test.rb`
- **Files modified:** `config/locales/pt-BR.yml`, `test/models/arte_test.rb`, `test/models/client_test.rb`
- **Commit:** 01ea4d4

**2. [Rule 1 - Bug] Arte.create! no teste precisava de external_url (não apenas caption)**
- **Found during:** TDD RED phase — test "exibe artes do mês na grade" falhava com RecordInvalid
- **Issue:** Arte com `media_type: :caption_only` ainda requer `external_url` ou `media_file` — a validação `media_source_present` aplica a todos os media_types
- **Fix:** Substituído `caption: "Texto de teste"` por `external_url: "https://drive.google.com/file/exemplo"` no test setup
- **Files modified:** `test/controllers/client/home_controller_test.rb`
- **Commit:** 01ea4d4

## Known Stubs

Nenhum — todas as funcionalidades especificadas estão implementadas e funcionando.

## Threat Flags

Nenhum novo risco de segurança identificado além do threat model do plano.

## Self-Check: PASSED

- `app/controllers/client/home_controller.rb` existe: FOUND
- `app/views/client/home/index.html.erb` existe: FOUND
- `app/views/client/home/_month_calendar.html.erb` existe: FOUND
- `app/views/client/shared/_arte_status_badge.html.erb` existe: FOUND
- `app/views/client/shared/_platform_icon.html.erb` existe: FOUND
- `test/controllers/client/home_controller_test.rb` existe: FOUND
- Commit `01ea4d4`: FOUND
- `grep "@client.artes"` → 1 match: CONFIRMED
- `grep "rescue Date::Error"` → 1 match: CONFIRMED
- `grep "grid-cols-7"` → 1 match: CONFIRMED
- `bundle exec rails test` → 57 testes, 0 falhas: CONFIRMED

---
*Phase: 04-client-calendar-portal*
*Completed: 2026-05-25*
