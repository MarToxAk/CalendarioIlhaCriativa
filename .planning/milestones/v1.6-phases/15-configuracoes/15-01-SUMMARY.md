---
phase: 15-configuracoes
plan: "01"
subsystem: admin-settings-foundation
tags: [migration, routes, sidebar, agency-name, test-scaffold]
dependency_graph:
  requires: []
  provides: [agency_name column, resource :settings routes, dynamic sidebar, test scaffold]
  affects:
    - db/migrate/20260604121724_add_agency_name_to_users.rb
    - db/schema.rb
    - app/models/user.rb
    - config/routes.rb
    - app/views/admin/shared/_sidebar.html.erb
    - test/controllers/admin/settings_controller_test.rb
tech_stack:
  added: []
  patterns: [Rails migration, resource routing, ERB dynamic rendering, has_secure_password]
key_files:
  created:
    - db/migrate/20260604121724_add_agency_name_to_users.rb
    - test/controllers/admin/settings_controller_test.rb
  modified:
    - db/schema.rb
    - app/models/user.rb
    - config/routes.rb
    - app/views/admin/shared/_sidebar.html.erb
decisions:
  - "default: 'Ilha Criativa' na migração — existente rows recebem valor sem quebrar NOT NULL"
  - "Removida linha hardcoded 'by Bom Custo' do sidebar — não tem coluna correspondente no modelo"
  - "current_page? funciona para /admin/settings singular resource — sem workaround necessário"
metrics:
  duration: "~5min"
  completed: "2026-06-04"
  tasks_completed: 5
  files_changed: 6
---

# Phase 15 Plan 01: Foundation — Migration, Routes, Sidebar Summary

**One-liner:** Migração `agency_name` na tabela `users`, rota `resource :settings` com member routes, sidebar com link wired e nome de agência dinâmico, scaffold de testes pronto para Wave 2.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Criar migração add_agency_name_to_users | 203febf |
| 2 | User model: validação presence + length | 203febf |
| 3 | Routes: resource :settings com update_password e update_agency | 203febf |
| 4 | Sidebar: link wired + agency_name dinâmico + remover "by Bom Custo" | 203febf |
| 5 | Scaffold de testes com setup inline completo | 203febf |

## What Was Built

### Migration (`db/migrate/20260604121724_add_agency_name_to_users.rb`)

Adiciona coluna `agency_name :string, null: false, default: "Ilha Criativa"` à tabela `users`. Schema.rb confirmado com a coluna.

### User model (`app/models/user.rb`)

Validação adicionada: `validates :agency_name, presence: true, length: { maximum: 100 }`.

### Routes (`config/routes.rb`)

```ruby
resource :settings, only: [:show] do
  patch :update_password, on: :member
  patch :update_agency,   on: :member
end
```

Gera: `admin_settings_path`, `update_password_admin_settings_path`, `update_agency_admin_settings_path`.

### Sidebar (`app/views/admin/shared/_sidebar.html.erb`)

- "Configurações" agora aponta para `admin_settings_path` (não mais `#`)
- Branding mostra `Current.user.agency_name` dinamicamente
- Linha hardcoded "by Bom Custo" removida

### Test Scaffold (`test/controllers/admin/settings_controller_test.rb`)

Setup com `User.create!` inline incluindo `agency_name:` e autenticação via `post session_path`. Pronto para Wave 2 adicionar testes reais.

## Deviations from Plan

Nenhum desvio — todos os 5 tasks executados conforme especificado.

## Self-Check: PASSED

- [x] `db/migrate/20260604121724_add_agency_name_to_users.rb` — file exists
- [x] `db/schema.rb` contém `agency_name` — confirmado
- [x] `app/models/user.rb` contém validação `agency_name` — confirmado
- [x] `config/routes.rb` contém `resource :settings` — confirmado
- [x] `app/views/admin/shared/_sidebar.html.erb` contém `admin_settings_path` — confirmado
- [x] `test/controllers/admin/settings_controller_test.rb` — file exists
- [x] Commit 203febf existe no git log
