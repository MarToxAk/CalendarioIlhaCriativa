---
phase: 15-configuracoes
type: context
---

# Phase 15: Configurações — Context

## Goal
Admin consegue alterar sua senha e o nome da agência através de uma página de configurações acessível pelo sidebar.

## Requirements
- CONF-01: Página acessível pelo sidebar (link "Configurações" wired)
- CONF-02: Formulário de troca de senha (senha atual + nova + confirmação)
- CONF-03: Formulário de edição do nome da agência, refletido no sidebar

## Key Decisions

### agency_name no model User
O nome da agência (`agency_name`) será adicionado como coluna na tabela `users`. O sistema tem um único admin, então faz sentido armazenar junto ao usuário. Default: `"Ilha Criativa"` (valor atual hardcoded no sidebar).

### Dois forms separados, um controller
`Admin::SettingsController` com:
- `show` — GET /admin/settings
- `update_password` — PATCH /admin/settings/update_password
- `update_agency` — PATCH /admin/settings/update_agency

Dois actions separados evitam mistura de erros entre os formulários e permitem redirects de volta com contexto limpo.

### Verificação de senha atual
Para trocar a senha, usamos `Current.user.authenticate(params[:password_current])` — método de `has_secure_password`. Se não bater, retorna `false` e exibimos flash alert sem atualizar.

### Flash messages
O layout `admin.html.erb` já renderiza `flash[:notice]` (verde) e `flash[:alert]` (vermelho). Nenhuma mudança de layout necessária.

### Sidebar dinâmico
`Current.user` é acessível nas views via `CurrentAttributes`. O sidebar passará a renderizar `Current.user&.agency_name` no lugar do texto hardcoded "Ilha Criativa".

## Files Expected
- `db/migrate/*_add_agency_name_to_users.rb`
- `app/models/user.rb` (validação agency_name)
- `config/routes.rb` (resource :settings)
- `app/controllers/admin/settings_controller.rb`
- `app/views/admin/settings/show.html.erb`
- `app/views/admin/shared/_sidebar.html.erb` (agency_name dinâmico + link wired)
- `test/controllers/admin/settings_controller_test.rb`
