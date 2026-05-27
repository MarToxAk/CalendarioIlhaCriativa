---
plan: 01-05
status: completed
completed_at: 2026-05-24
---

# Summary: Portal do Cliente — Auth + Isolamento

## O que foi feito

ClientController base, Client::SessionsController, Client::HomeController (placeholder), formulário de senha com UI-SPEC, e rotas `/c/:token/*`. Suite completa: 37 testes, 0 falhas.

## Arquivos criados

- `app/controllers/client_controller.rb` — base com load_client_from_token + require_client_auth
- `app/controllers/client/sessions_controller.rb` — new/create/destroy
- `app/controllers/client/home_controller.rb` — placeholder protegido para testes de isolamento
- `app/views/client/sessions/new.html.erb` — formulário de senha (UI-SPEC 4.2)
- `config/routes.rb` — adicionado `scope '/c/:token', as: :client`
- `test/controllers/client/sessions_controller_test.rb` — 5 testes (AUTH-04, AUTH-05, AUTH-06)
- `test/integration/client_isolation_test.rb` — 2 testes de isolamento cross-client

## Desvios / Decisões

**redirect após login:** O RESEARCH.md usa `client_calendar_path` que não existe na fase 1. Redireciona para `client_root_path` (home placeholder) — será atualizado nas fases de calendário.

**assert_notice ausente na view admin:** Os testes do auth generator (`PasswordsControllerTest`) esperavam `flash[:notice]` na view de login admin, mas a view customizada (fase 01-02) só tinha `flash[:alert]`. Adicionado banner verde de notice à view `sessions/new.html.erb`.

**isolamento cross-client retorna 302 (não 404):** O plano descreve "→ 404" mas a implementação correta redireciona via `require_client_auth` quando `session[:client_id] != @client.id`. Teste escrito para verificar redirect + limpeza de sessão.

## Verificações

- `bin/rails test` → 37 testes, 0 falhas
- `client_token_version` aparece 2x em client_controller.rb (setter verificador)
- `token_version.length` retorna 8 (primeiros 8 chars do access_token)
- Rotas `/c/:token` geradas corretamente

## Requisitos cobertos

- AUTH-03: token no URL → lookup do cliente
- AUTH-04: senha do cliente via has_secure_password
- AUTH-05: rotação de token invalida sessão via session[:client_token_version]
- AUTH-06: logout limpa session[:client_id] e session[:client_token_version]
