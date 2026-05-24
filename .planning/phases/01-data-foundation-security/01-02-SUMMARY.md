---
phase: 01-data-foundation-security
plan: "02"
subsystem: auth
tags: [rails-auth, authentication, admin, sessions, tailwind, stimulus, ui]
dependency_graph:
  requires: [01-01]
  provides: [admin-auth, session-model, login-form, admin-namespace]
  affects: [01-03, 01-04, 01-05, all-admin-plans]
tech_stack:
  added:
    - Rails 8 authentication generator (User, Session, Current, Authentication concern)
    - bcrypt (has_secure_password via auth generator)
    - Stimulus password_toggle_controller
  patterns:
    - DB-persisted Session model (not session[:user_id])
    - Admin::BaseController with before_action :require_authentication
    - after_authentication_url overridden to redirect to admin_root
    - find_or_create_by! seed pattern for idempotent admin creation
    - ENV.fetch with fallback for seed password (dev default, prod override)
key_files:
  created:
    - app/models/user.rb
    - app/models/session.rb
    - app/models/current.rb
    - app/controllers/concerns/authentication.rb
    - app/controllers/sessions_controller.rb
    - app/controllers/passwords_controller.rb
    - app/controllers/admin/base_controller.rb
    - app/controllers/admin/dashboard_controller.rb
    - app/views/admin/dashboard/index.html.erb
    - app/views/sessions/new.html.erb
    - app/javascript/controllers/password_toggle_controller.js
    - db/migrate/20260524203101_create_users.rb
    - db/migrate/20260524203102_create_sessions.rb
    - db/schema.rb
    - test/controllers/sessions_controller_test.rb
  modified:
    - config/routes.rb
    - db/seeds.rb
    - app/views/layouts/application.html.erb
    - app/controllers/application_controller.rb
decisions:
  - "after_authentication_url overridden in SessionsController to redirect to admin_root_url (not root_url)"
  - "Admin::BaseController inherits ApplicationController + before_action :require_authentication (does not re-include Authentication — ApplicationController already includes it)"
  - "Seeds use ENV.fetch('ADMIN_PASSWORD', 'SenhaSegura123!') for T-02-03 mitigation — dev has default, prod sets ENV var"
  - "Stimulus password_toggle_controller.js added for show/hide password toggle (no inline JS)"
  - "Test fixture uses inline User.find_or_create_by! in setup (not fixtures file) for isolation"
metrics:
  duration: "~20 minutos"
  completed_date: "2026-05-24"
  tasks_completed: 2
  files_created: 17
---

# Phase 01 Plan 02: Admin Auth + Login Form Summary

**One-liner:** Rails 8 auth generator configurado para admin-only com Session DB-persistida, namespace /admin com DashboardController stub, formulário de login UI-SPEC em pt-BR com toggle de senha via Stimulus, e admin semeado via find_or_create_by!.

## Tasks Completed

| Task | Name | Commit | Status |
|------|------|--------|--------|
| 1 | Rails auth generator + admin namespace + seeds | 9640751 | Done |
| 2 | Formulário de login admin com UI-SPEC | c1853a2 | Done |

## Verification Results

- `bin/rails db:migrate` → tabelas users e sessions criadas ✓
- `bin/rails db:seed` → "Seed concluído: 1 admin(s) criado(s)." ✓
- `bin/rails runner "puts User.count"` → `1` ✓
- `bin/rails runner "puts User.first.email_address"` → `admin@ilhacriativa.com.br` ✓
- `bin/rails test test/controllers/sessions_controller_test.rb` → 5 runs, 17 assertions, 0 failures ✓
- `grep -c "aria-label" app/views/sessions/new.html.erb` → `2` ✓
- `grep 'lang="pt-BR"' app/views/layouts/application.html.erb` → encontrado ✓

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] after_authentication_url redirecionava para root_url inexistente**

- **Found during:** Task 1
- **Issue:** O concern Authentication usa `root_url` como fallback em `after_authentication_url`, mas o projeto não tem rota raiz definida (apenas `/admin/` como root). Isso causaria erro ao fazer login bem-sucedido.
- **Fix:** Sobrescrito `after_authentication_url` na SessionsController para retornar `admin_root_url` como fallback, mantendo o comportamento de `session[:return_to_after_authenticating]` intacto.
- **Files modified:** `app/controllers/sessions_controller.rb`
- **Commit:** 9640751

**2. [Rule 2 - Security] Seeds hardcoded mitigado com ENV.fetch**

- **Found during:** Task 1 — T-02-03 do threat model
- **Issue:** O plan especificava senha hardcoded `"SenhaSegura123!"` no seeds.rb. T-02-03 requer mitigação.
- **Fix:** `ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")` — dev tem default, produção deve setar a ENV var.
- **Files modified:** `db/seeds.rb`
- **Commit:** 9640751

**3. [Rule 1 - Bug] Testes gerados pelo auth generator incompatíveis com seed real**

- **Found during:** Task 1
- **Issue:** O `test/controllers/sessions_controller_test.rb` gerado usava `password: "password"` (senha do fixture), mas o projeto usa `"SenhaSegura123!"` e não tem fixture de User com senha pré-definida.
- **Fix:** Reescrito o arquivo de teste com os 5 testes do plan, usando `User.find_or_create_by!` no setup com as credenciais reais.
- **Files modified:** `test/controllers/sessions_controller_test.rb`
- **Commit:** 9640751

**4. [Rule 2 - Missing] Layout application.html.erb tinha container fixo interferindo no login**

- **Found during:** Task 2
- **Issue:** O layout gerado tinha `<main class="container mx-auto mt-28 px-5 flex">` — isso colocaria o card de login dentro de um container pequeno centrado, quebrando o design full-screen da UI-SPEC.
- **Fix:** Removido o `<main>` wrapper do layout; o `<body>` agora renderiza `<%= yield %>` diretamente. Cada view controla seu próprio layout.
- **Files modified:** `app/views/layouts/application.html.erb`
- **Commit:** c1853a2

## Known Stubs

- `app/views/admin/dashboard/index.html.erb` — stub intencional ("Fase 2 implementa este painel"). Será substituído no Plano 02-02 (admin UI).

## Threat Flags

Nenhum novo threat surface além do documentado no PLAN.md threat_model:
- T-02-01 (bcrypt): mitigado via `has_secure_password` + `User.authenticate_by`
- T-02-02 (cookie): mitigado via `cookies.signed` com Session DB-persistida
- T-02-03 (seeds): mitigado via `ENV.fetch("ADMIN_PASSWORD", ...)` — desvio Rule 2
- T-02-04 (admin routes): mitigado via `Admin::BaseController before_action :require_authentication`
- T-02-05 (brute-force): pendente — configurado no Plano 01-04 (Rack::Attack)

## Self-Check: PASSED

- [x] app/models/user.rb existe e contém `has_secure_password`
- [x] app/models/session.rb existe e contém `belongs_to :user`
- [x] app/controllers/concerns/authentication.rb existe e contém `require_authentication`
- [x] app/controllers/admin/base_controller.rb existe e contém `before_action :require_authentication`
- [x] app/controllers/admin/dashboard_controller.rb existe
- [x] config/routes.rb contém `namespace :admin` e NÃO contém `resources :users`
- [x] db/seeds.rb contém `find_or_create_by!`
- [x] app/views/sessions/new.html.erb contém `aria-label="Acesso da equipe"`, `autocomplete="username"`, `autocomplete="current-password"`, `aria-live="polite"`, "Entrar", "Acesso da equipe"
- [x] app/views/layouts/application.html.erb contém `lang="pt-BR"` e Google Fonts Inter
- [x] Commits 9640751 e c1853a2 existem no git log
- [x] 5 testes passando: `5 runs, 17 assertions, 0 failures, 0 errors`
