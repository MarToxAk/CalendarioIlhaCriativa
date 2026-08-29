---
phase: 13-p-gina-aprova-es
plan: "01"
subsystem: infra
tags: [pagy, rails, routing, sidebar, testing]

# Dependency graph
requires:
  - phase: 12
    provides: Admin controllers e views com Tailwind styling
provides:
  - Pagy::Backend incluído em Admin::BaseController (método pagy disponível em todos os controllers admin)
  - Pagy::Frontend incluído em ApplicationHelper (pagy_nav disponível em todas as views admin)
  - Rota admin_approvals registrada no namespace admin (GET /admin/approvals)
  - Link "Aprovações" no sidebar wired para admin_approvals_path (não mais "#")
  - Arquivo de testes Admin::ApprovalsControllerTest com setup inline pronto para plano 13-02
affects: [13-02, 13-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "include Pagy::Backend em Admin::BaseController para disponibilizar pagy em todos os controllers admin"
    - "include Pagy::Frontend em ApplicationHelper para disponibilizar pagy_nav em todas as views"
    - "Testes de controller admin com setup inline: User, Client, Arte, ApprovalResponse criados diretamente no setup"

key-files:
  created:
    - test/controllers/admin/approvals_controller_test.rb
  modified:
    - app/controllers/admin/base_controller.rb
    - app/helpers/application_helper.rb
    - config/routes.rb
    - app/views/admin/shared/_sidebar.html.erb

key-decisions:
  - "Pagy ativado via include no base controller e helper — não via initializer global — para manter o escopo circunscrito ao namespace admin"
  - "resources :approvals, only: [:index] — apenas :index por ora; demais actions adicionadas quando necessário em planos futuros"
  - "Arquivo de testes criado sem testes ainda — setup inline completo mas testes virão no plano 13-02 (separação de concerns entre infraestrutura e implementação)"

patterns-established:
  - "Pagy backend/frontend: include em base_controller e application_helper respectivamente"
  - "Setup de testes do ApprovalsController: User.create! + sign_in_as + Client + Arte + ApprovalResponse"

requirements-completed: [APRO-03]

# Metrics
duration: 8min
completed: 2026-06-04
---

# Phase 13 Plan 01: Infraestrutura Pagy, Rota e Sidebar para Página Aprovações Summary

**Pagy habilitado (Backend + Frontend), rota admin_approvals registrada e link "Aprovações" no sidebar wired de "#" para admin_approvals_path — infraestrutura bloqueante desbloqueada para o Wave 2**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-04T03:50:00Z
- **Completed:** 2026-06-04T03:58:00Z
- **Tasks:** 2
- **Files modified:** 5 (3 modificados + 1 criado + 1 modificado)

## Accomplishments
- Pagy::Backend incluído em Admin::BaseController: método `pagy` disponível em todos os controllers admin sem configuração adicional
- Pagy::Frontend incluído em ApplicationHelper: helper `pagy_nav` disponível em todas as views admin
- Rota `admin_approvals GET /admin/approvals(.:format) admin/approvals#index` registrada no namespace admin
- Link "Aprovações" no sidebar wired de `"#"` para `admin_approvals_path` — APRO-03 satisfeito
- Arquivo `test/controllers/admin/approvals_controller_test.rb` criado com setup inline completo (User, Client, Arte, ApprovalResponse) e suite verde (0 tests, 0 assertions, 0 failures)

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1: Habilitar Pagy no projeto (Backend + Frontend) e registrar rota** - `c27438d` (feat)
2. **Task 2: Wire link Aprovações no sidebar e criar arquivo de testes** - `96c1426` (feat)

## Files Created/Modified
- `app/controllers/admin/base_controller.rb` - Adicionado `include Pagy::Backend` antes do `end` da classe
- `app/helpers/application_helper.rb` - Adicionado `include Pagy::Frontend` dentro do módulo
- `config/routes.rb` - Adicionado `resources :approvals, only: [ :index ]` no namespace admin
- `app/views/admin/shared/_sidebar.html.erb` - Linha "Aprovações" alterada de `path: "#"` para `path: admin_approvals_path`
- `test/controllers/admin/approvals_controller_test.rb` - Criado com classe Admin::ApprovalsControllerTest e setup inline completo

## Decisions Made
- Pagy habilitado via include direto em base_controller/application_helper (não via initializer) — mantém escopo circunscrito ao namespace admin sem poluir outros controllers
- Rota apenas com `:index` por ora — demais actions adicionadas em planos futuros quando o controller for implementado
- Arquivo de testes criado sem testes ainda — separação intencional de concerns: infraestrutura (13-01) vs. testes funcionais (13-02)

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Issues Encountered
- `bin/rails routes` no worktree usa os gems do sistema (ausentes no PATH do worktree) — resolvido usando `BUNDLE_GEMFILE=/home/bot/calendario_livia/Gemfile bundle exec rails routes` no diretório do worktree, que carrega corretamente o routes.rb modificado do worktree.

## User Setup Required

Nenhum — nenhuma configuração externa necessária.

## Next Phase Readiness
- Infraestrutura pronta: Pagy ativado, rota registrada, sidebar wired
- Plano 13-02 pode prosseguir: criar Admin::ApprovalsController com action index usando pagy, criar view com filtros Turbo Frame, adicionar testes ao arquivo criado neste plano
- Nenhum bloqueante pendente

---
*Phase: 13-p-gina-aprova-es*
*Completed: 2026-06-04*
