---
phase: 17-cable-foundation-admin-channel-badge-toast
plan: "00"
subsystem: testing
tags: [actioncable, rails, fixtures, minitest, bcrypt]

requires: []
provides:
  - ApplicationCable::Channel base class (ausente no projeto antes desta fase)
  - test/fixtures/clients.yml com fixtures one, two, inactive
  - test/fixtures/sessions.yml com fixture one referenciando users(:one)
  - test/channels/application_cable/connection_test.rb (4 testes RED)
  - test/channels/admin_notifications_channel_test.rb (2 testes RED)
affects:
  - 17-01 (connection.rb expansion — usa os 4 testes RED de connection_test.rb)
  - 17-02 (AdminNotificationsChannel — usa os 2 testes RED de admin_notifications_channel_test.rb)
  - todas as plans que criam canais ActionCable (dependem de ApplicationCable::Channel)

tech-stack:
  added: []
  patterns:
    - "Fixtures de Client com BCrypt ERB (igual ao padrão de users.yml): senha hardcoded 'password' em test fixtures"
    - "Test stubs RED: arquivos de teste existem e têm sintaxe válida mas falham nos asserts por design"
    - "ApplicationCable::Channel base class: módulo ApplicationCable, classe vazia herda de ActionCable::Channel::Base"

key-files:
  created:
    - app/channels/application_cable/channel.rb
    - test/fixtures/clients.yml
    - test/fixtures/sessions.yml
    - test/channels/application_cable/connection_test.rb
    - test/channels/admin_notifications_channel_test.rb
  modified: []

key-decisions:
  - "access_token não declarado em clients.yml — has_secure_token callback preenche automaticamente; declarar causaria conflito"
  - "sessions.yml mínima (apenas user: one) — sessão completa criada inline com @user.sessions.create! nos testes"
  - "Verificação de sintaxe via RubyVM::InstructionSequence em vez de rails test — banco de teste não acessível no ambiente CI do worktree"

patterns-established:
  - "Fixtures de modelo com has_secure_token: não declarar o token na fixture (callback do model popula automaticamente)"
  - "TDD RED state: arquivos de teste criados com sintaxe válida e falhas de assert esperadas antes da implementação"

requirements-completed:
  - CABLE-01

duration: 8min
completed: 2026-06-05
---

# Phase 17 Plan 00: Cable Foundation — Base Class e Test Stubs Summary

**ApplicationCable::Channel base class criada, fixtures clients.yml e sessions.yml adicionadas, e 6 testes RED (4 connection + 2 channel) prontos para as Plans 01 e 02 implementarem**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-05T11:10:16Z
- **Completed:** 2026-06-05T11:18:46Z
- **Tasks:** 2
- **Files modified:** 5 criados + 1 symlink (.env)

## Accomplishments

- Resolveu o bloqueador crítico: `app/channels/application_cable/channel.rb` estava ausente no projeto; qualquer canal levantaria `NameError: uninitialized constant ApplicationCable::Channel` sem este arquivo
- Criou `test/fixtures/clients.yml` com 3 fixtures (one, two, inactive) usando o mesmo padrão BCrypt ERB de `users.yml`, permitindo `clients(:one)` e `clients(:inactive)` nos connection tests
- Criou `test/fixtures/sessions.yml` mínima e 6 stubs de teste RED que compilam sem LoadError/SyntaxError — Plans 01 e 02 têm alvos claros para fazer passar

## Task Commits

1. **Task 1: ApplicationCable::Channel base class e fixtures** - `7b65683` (feat)
2. **Task 2: Stubs de teste RED para connection e canal admin** - `7cc780d` (test)

**Plan metadata:** (ver commit de docs abaixo)

## Files Created/Modified

- `app/channels/application_cable/channel.rb` — módulo ApplicationCable, classe Channel vazia herdando de ActionCable::Channel::Base
- `test/fixtures/clients.yml` — 3 fixtures: one (active:true), two (active:true), inactive (active:false); BCrypt digest via ERB; sem access_token (has_secure_token callback)
- `test/fixtures/sessions.yml` — fixture one com `user: one` — mínima para tabela sessions
- `test/channels/application_cable/connection_test.rb` — 4 testes RED: admin via cookie, cliente via token, rejeita sem credenciais, rejeita cliente inactive
- `test/channels/admin_notifications_channel_test.rb` — 2 testes RED: subscribe + stream, reject sem current_user

## Decisions Made

- `access_token` não declarado em `clients.yml`: o model tem `has_secure_token :access_token` que gera o token automaticamente no callback before_create. Declarar na fixture causaria conflito de unicidade ou sobrescrita.
- `sessions.yml` mínima com apenas `user: one`: testes de canal criam a session inline com `@user.sessions.create!` — a fixture só existe para satisfazer `fixtures :all` no test_helper sem erro na tabela sessions.
- Verificação alternativa de sintaxe: o banco de teste (`calendario_livia_test`) não está acessível no ambiente de CI do worktree (banco em servidor remoto, sem credenciais configuradas para acesso direto). Sintaxe verificada via `RubyVM::InstructionSequence.compile` e carregamento de classes via `rails runner` (que não requer DB). Critério do plano satisfeito: sem LoadError/SyntaxError.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Configuração de .bundle/config e symlink de .env no worktree**

- **Found during:** Task 1 (verificação do ApplicationCable::Channel)
- **Issue:** O worktree não herdou o `.bundle/config` do repositório principal (que aponta para `vendor/bundle`) nem o `.env` (que contém POSTGRES_PASSWORD). Sem isso, `bundle exec` falhava com `Bundler::GemNotFound` e o dotenv-rails não carregava as credenciais.
- **Fix:** Criado `.bundle/config` apontando para `/home/bot/calendario_livia/vendor/bundle` e symlink `.env -> /home/bot/calendario_livia/.env`.
- **Files modified:** `.bundle/config` (novo), `.env` (symlink)
- **Verification:** `bundle exec rails runner "puts ApplicationCable::Channel.ancestors.include?(ActionCable::Channel::Base)"` retornou `true`
- **Committed in:** não commitado (arquivos de configuração de ambiente, fora do controle de versão)

---

**Total deviations:** 1 auto-fixed (1 bloqueador de ambiente)
**Impact on plan:** Fix necessário para funcionar no worktree. Sem impacto no código da aplicação.

## Issues Encountered

- **Banco de teste inacessível no worktree:** O `calendario_livia_test` não está configurado localmente (banco em 192.168.3.203, credenciais locais divergem). `bundle exec rails test` falha com `DatabaseConnectionError` antes de executar qualquer teste. Este é um problema de ambiente de CI, não de código. A verificação de sintaxe e carregamento de classes foi feita via alternativas sem DB. O banco de testes estará disponível no ambiente de produção onde os testes serão executados normalmente após o merge.

## Known Stubs

Os arquivos de teste são **intencionalmente** stubs RED:
- `test/channels/application_cable/connection_test.rb`: 4 testes que falham porque `connection.rb` ainda não tem `identified_by :current_client` (Plan 01 resolve)
- `test/channels/admin_notifications_channel_test.rb`: 2 testes que falham porque `AdminNotificationsChannel` não existe ainda (Plan 02 resolve)

Estes stubs são o output esperado desta plan. Não são bugs — são o estado RED do ciclo TDD que as Plans 01 e 02 irão resolver ao GREEN.

## Threat Flags

Nenhum novo surface de segurança introduzido. Threat model do plano contempla:
- T-17-00-01: Fixtures com senha hardcoded "password" — aceitável em test, nunca em produção
- T-17-SC: Nenhum pacote externo instalado

## Next Phase Readiness

- Plan 01 pode expandir `connection.rb` para `identified_by :current_user, :current_client` — os 4 testes RED em `connection_test.rb` são os alvos
- Plan 02 pode criar `AdminNotificationsChannel` — os 2 testes RED em `admin_notifications_channel_test.rb` são os alvos
- `ApplicationCable::Channel` disponível como base class para todos os canais da fase 17

## Self-Check: PASSED

- FOUND: app/channels/application_cable/channel.rb
- FOUND: test/fixtures/clients.yml
- FOUND: test/fixtures/sessions.yml
- FOUND: test/channels/application_cable/connection_test.rb
- FOUND: test/channels/admin_notifications_channel_test.rb
- FOUND: .planning/phases/17-cable-foundation-admin-channel-badge-toast/17-00-SUMMARY.md
- COMMIT 7b65683: feat(17-00): criar ApplicationCable::Channel base class e fixtures de teste
- COMMIT 7cc780d: test(17-00): criar stubs RED para connection e admin_notifications channel

---
*Phase: 17-cable-foundation-admin-channel-badge-toast*
*Completed: 2026-06-05*
