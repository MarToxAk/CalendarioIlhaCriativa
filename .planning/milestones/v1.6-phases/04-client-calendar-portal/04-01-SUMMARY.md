---
phase: 04-client-calendar-portal
plan: 01
subsystem: ui
tags: [rails, i18n, tailwind, stimulus, layout, routes, pt-BR]

# Dependency graph
requires:
  - phase: 01-data-foundation-security
    provides: ClientController com autenticação por token (load_client_from_token, require_client_auth)
  - phase: 03-art-management
    provides: admin.html.erb como referência de layout

provides:
  - Layout dedicado app/views/layouts/client.html.erb com header (brand, nome do cliente, botão Sair)
  - ClientController declara layout 'client' — herdado por todos os controllers filhos
  - Locale pt-BR com nomes de meses em português (Janeiro...Dezembro)
  - I18n.default_locale configurado como pt-BR
  - Rota client_arte_path (GET /c/:token/artes/:id) para planos 02 e 03
  - sessions/new.html.erb refatorado sem HTML inline duplicado, com Stimulus password-toggle

affects: [04-02-PLAN.md, 04-03-PLAN.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Layout client.html.erb segue estrutura de admin.html.erb mas com bg-white e header simplificado"
    - "safe navigation @client&.name e @client&.access_token no layout (client pode ser nil antes de load_client_from_token)"
    - "Locale pt-BR manual em config/locales/pt-BR.yml (sem gem rails-i18n)"
    - "Stimulus password_toggle_controller reutilizado no login — sem onclick inline"

key-files:
  created:
    - app/views/layouts/client.html.erb
    - config/locales/pt-BR.yml
  modified:
    - app/controllers/client_controller.rb
    - app/views/client/sessions/new.html.erb
    - config/routes.rb
    - config/application.rb

key-decisions:
  - "Layout client.html.erb com bg-white (diferente do bg-gray-50 do admin) — fundo visualmente distinto para o portal do cliente"
  - "Locale pt-BR manual em config/locales/pt-BR.yml (rails-i18n não está no Gemfile)"
  - "safe navigation @client&.name no layout — client pode ser nil em respostas de erro antes de load_client_from_token"
  - "button_to Sair com method: :delete para client_session_path — forma Rails idiomática para DELETE"
  - "Stimulus password_toggle_controller reutilizado — remove onclick inline e bloco <script> do sessions/new.html.erb"

patterns-established:
  - "Pattern: Layout Rails dedicado para área de cliente — equivalente ao admin.html.erb"
  - "Pattern: I18n.l() com locale pt-BR para nomes de meses em português"
  - "Pattern: client_arte_path(token: @client.access_token, id: arte) — helper de rota para arts no portal"

requirements-completed: [CAL-01, CAL-02]

# Metrics
duration: 15min
completed: 2026-05-25
---

# Phase 4 Plan 01: Client Portal Foundation Summary

**Layout dedicado client.html.erb com header de navegação, locale pt-BR para I18n de datas, e rota client_arte_path para previews de arte no portal do cliente**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-25T00:00:00Z
- **Completed:** 2026-05-25T00:15:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Layout `app/views/layouts/client.html.erb` criado com header (brand Ilha Criativa, nome do cliente via `@client&.name`, botão Sair via `button_to` com `method: :delete`)
- `ClientController` agora declara `layout 'client'` — todos os controllers filhos (`Client::HomeController`, `Client::SessionsController`, `Client::ArtesController`) herdam automaticamente
- Locale pt-BR configurado manualmente em `config/locales/pt-BR.yml` — `I18n.l(Date.new(2026, 5, 1), format: '%B %Y')` retorna "Maio 2026"
- `sessions/new.html.erb` refatorado: removidos DOCTYPE, html, head, body e bloco `<script>` — apenas o card de login permanece; toggle de senha migrado para Stimulus `data-controller="password-toggle"` sem onclick inline
- Rota `resources :artes, only: [:show], controller: "client/artes"` adicionada no scope `/c/:token` — gera `client_arte_path(token:, id:)` para os planos 02 e 03

## Task Commits

1. **Task 1: Layout client.html.erb + ClientController layout + locale pt-BR** - `42c4e58` (feat)
2. **Task 2: Refatorar sessions/new + adicionar rota client_arte_path** - `3165f22` (feat)

## Files Created/Modified

- `app/views/layouts/client.html.erb` — Layout dedicado do portal do cliente com header sticky, flash messages, main yield
- `app/controllers/client_controller.rb` — Adicionada linha `layout 'client'` (única alteração)
- `config/locales/pt-BR.yml` — Locale pt-BR com month_names, abbr_month_names, day_names, abbr_day_names e simple_calendar keys
- `config/application.rb` — `config.i18n.default_locale = :'pt-BR'` adicionado
- `app/views/client/sessions/new.html.erb` — Refatorado para conter apenas o card de login; usa Stimulus password-toggle
- `config/routes.rb` — Adicionado `resources :artes, only: [:show], controller: "client/artes"` no scope do cliente

## Decisions Made

- Layout usa `bg-white` no body (não `bg-gray-50` como admin) — diferença visual que distingue o portal do cliente do admin
- `@client&.name` e `@client&.access_token` usados com safe navigation no layout porque `@client` pode ser `nil` em erros antes de `load_client_from_token` completar
- Locale pt-BR criado manualmente (sem `rails-i18n`) — abordagem mais leve, cobre apenas as chaves necessárias para o calendário
- Botão "Sair" usa `button_to` com `method: :delete` em vez de `link_to` com `data: {turbo_method: :delete}` — forma mais idiomática Rails 8

## Deviations from Plan

None — plano executado exatamente como especificado.

## Issues Encountered

None.

## User Setup Required

None — nenhuma configuração externa necessária.

## Next Phase Readiness

- Layout `client.html.erb` disponível para herança por todos os controllers filhos do portal
- `client_arte_path` disponível nas routes para o Plano 02 (calendário grid) e Plano 03 (preview de arte)
- Locale pt-BR ativo — `I18n.l()` com `format: '%B %Y'` retorna meses em português
- Todos os 7 testes de `Client::SessionsController` continuam passando após a refatoração

---
*Phase: 04-client-calendar-portal*
*Completed: 2026-05-25*
