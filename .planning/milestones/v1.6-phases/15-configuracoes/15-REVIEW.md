---
phase: 15-configuracoes
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - app/controllers/admin/settings_controller.rb
  - app/models/user.rb
  - app/views/admin/settings/show.html.erb
  - app/views/admin/shared/_sidebar.html.erb
  - config/routes.rb
  - db/migrate/20260604121724_add_agency_name_to_users.rb
  - db/schema.rb
  - test/controllers/admin/settings_controller_test.rb
findings:
  critical: 1
  warning: 3
  info: 1
  total: 5
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-06-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

A feature que implementa a tela de Configurações do admin (alteração de senha e nome da agência) foi revisada. A implementação é funcional e segue padrões Rails, mas apresenta uma falha de segurança crítica — ausência de comprimento mínimo para a nova senha — e três problemas de qualidade/segurança que devem ser corrigidos antes de ir para produção.

---

## Critical Issues

### CR-01: Ausência de validação de comprimento mínimo de senha

**File:** `app/controllers/admin/settings_controller.rb:10` e `app/models/user.rb:2`

**Issue:** O controller verifica apenas se a nova senha é `.blank?` (linha 10), mas não valida comprimento mínimo. O `has_secure_password` do Rails 8.1 valida somente presença e comprimento máximo (72 bytes BCrypt) — confirmado via leitura do fonte em `activemodel-8.1.3/lib/active_model/secure_password.rb`. Não há nenhum `validates :password, length: { minimum: N }` no model. Resultado: a senha `"a"` (1 caractere) é aceita com sucesso pela aplicação.

**Fix:** Adicionar validação de comprimento mínimo no `User` model. Oito caracteres é o mínimo recomendável; doze é mais seguro:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :agency_name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
```

O `allow_nil: true` é necessário para que o model continue válido quando a senha não está sendo alterada (o `password` virtual é `nil` nesses casos).

---

## Warnings

### WR-01: Outras sessões ativas não são invalidadas após troca de senha

**File:** `app/controllers/admin/settings_controller.rb:18-22`

**Issue:** Ao alterar a senha com sucesso, somente a sessão atual permanece ativa — nenhuma outra sessão é destruída. O fluxo de reset de senha (`PasswordsController#update`, linha 22) já faz `@user.sessions.destroy_all` corretamente. A inconsistência significa que, se uma sessão foi comprometida, o atacante continua com acesso válido mesmo após o admin trocar a senha pela interface de configurações.

**Fix:**

```ruby
# app/controllers/admin/settings_controller.rb
def update_password
  unless Current.user.authenticate(params[:password_current])
    return redirect_to admin_settings_path, alert: "Senha atual incorreta."
  end

  if params[:password].blank?
    return redirect_to admin_settings_path, alert: "A nova senha não pode ficar em branco."
  end

  if params[:password] != params[:password_confirmation]
    return redirect_to admin_settings_path, alert: "A nova senha e a confirmação não coincidem."
  end

  if Current.user.update(password: params[:password], password_confirmation: params[:password_confirmation])
    # Invalidar todas as outras sessões, mantendo apenas a atual
    Current.user.sessions.where.not(id: Current.session.id).destroy_all
    redirect_to admin_settings_path, notice: "Senha alterada com sucesso."
  else
    redirect_to admin_settings_path, alert: Current.user.errors.full_messages.to_sentence
  end
end
```

---

### WR-02: Endpoints PATCH não têm cobertura de teste para acesso não autenticado

**File:** `test/controllers/admin/settings_controller_test.rb:27-31`

**Issue:** Apenas o `GET /admin/settings` tem um teste de acesso não autenticado (linha 27). Os endpoints `PATCH update_password` e `PATCH update_agency` não possuem testes verificando que o `before_action :require_authentication` os protege corretamente. Se a herança for quebrada por acidente, os endpoints ficariam expostos sem alarme de teste.

**Fix:** Adicionar dois testes ao arquivo de teste:

```ruby
test "PATCH update_password — não autenticado: redireciona para login" do
  delete session_path
  patch update_password_admin_settings_path, params: {
    password_current: "senha_original",
    password: "nova_senha_123",
    password_confirmation: "nova_senha_123"
  }
  assert_redirected_to new_session_path
end

test "PATCH update_agency — não autenticado: redireciona para login" do
  delete session_path
  patch update_agency_admin_settings_path, params: { agency_name: "Outra Agência" }
  assert_redirected_to new_session_path
end
```

---

### WR-03: Parâmetros recebidos via `params[:x]` direto, sem `permit` — padrão inconsistente

**File:** `app/controllers/admin/settings_controller.rb:6,10,14,18,26`

**Issue:** Todos os outros controllers do namespace admin (`clients_controller.rb`, `artes_controller.rb`) utilizam `params.require(...).permit(...)` (strong parameters). O `settings_controller` acessa `params[:password_current]`, `params[:password]`, `params[:password_confirmation]`, e `params[:agency_name]` diretamente, sem passar por `permit`. Embora não seja uma vulnerabilidade de mass assignment aqui (os valores são passados individualmente para `update()`), o padrão inconsistente é um risco de manutenção: uma refatoração futura que altere o código para usar um hash de parâmetros poderia introduzir mass assignment.

**Fix:** Extrair métodos private com `permit`, seguindo o padrão do projeto:

```ruby
private

def password_params
  params.permit(:password, :password_confirmation)
end

def agency_params
  params.permit(:agency_name)
end
```

E usar no controller:

```ruby
# em update_password
if Current.user.update(password_params)

# em update_agency
if Current.user.update(agency_params)
```

O `params[:password_current]` (usado apenas para autenticação, não para update) pode permanecer como acesso direto.

---

## Info

### IN-01: Rota usa `on: :member` em recurso singular — padrão incomum mas funcional

**File:** `config/routes.rb:22-23`

**Issue:** Para um `resource :settings` (recurso singular), o padrão convencional de rotas customizadas é `on: :collection`. O uso de `on: :member` em recurso singular gera as mesmas URLs e funciona corretamente (confirmado: `PATCH /admin/settings/update_password`), mas é um padrão menos documentado que pode confundir revisores futuros. Não há impacto funcional.

**Fix:** Avaliar trocar para `on: :collection` na próxima oportunidade de refatoração de rotas, apenas para maior clareza semântica:

```ruby
resource :settings, only: [ :show ] do
  patch :update_password, on: :collection
  patch :update_agency,   on: :collection
end
```

---

_Reviewed: 2026-06-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
