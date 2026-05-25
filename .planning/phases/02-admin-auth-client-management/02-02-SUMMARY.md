---
phase: 02-admin-auth-client-management
plan: "02"
subsystem: admin-clients-forms
tags: [rails, tailwind, stimulus, admin, forms, tdd, password-toggle]

dependency_graph:
  requires:
    - phase: 02-01
      provides: [admin-layout, clients-controller, password-plain-column]
  provides:
    - clients-new-view
    - clients-edit-view
    - clients-form-partial
    - clients-show-view
    - clients-controller-tests
  affects:
    - app/views/admin/clients/new.html.erb
    - app/views/admin/clients/edit.html.erb
    - app/views/admin/clients/_form.html.erb
    - app/views/admin/clients/show.html.erb
    - test/controllers/admin/clients_controller_test.rb

tech-stack:
  added: []
  patterns:
    - Form partial com client.persisted? para comportamento new vs edit diferenciado
    - password_plain sincronizado no controller create via merge() antes de Client.new
    - Erros inline via ActiveRecord errors com role=alert
    - password-toggle Stimulus reutilizado do sessions/new.html.erb

key-files:
  created:
    - app/views/admin/clients/_form.html.erb
    - app/views/admin/clients/new.html.erb
    - app/views/admin/clients/edit.html.erb
    - app/views/admin/clients/show.html.erb
    - test/controllers/admin/clients_controller_test.rb
  modified:
    - app/controllers/admin/clients_controller.rb

key-decisions:
  - "client.persisted? no _form para distinguir new vs edit (placeholder de senha e hint dinâmicos)"
  - "password_plain sincronizado no create via merge(password_plain: params[:password]) — T-02-06 mitigado"
  - "show.html.erb criada como parte desta task (bloqueio Rule 3: testes redirecionavam para show inexistente)"

patterns-established:
  - "Partial _form recebe locals: client (objeto), button_label, cancel_path"
  - "Erros inline: if client.errors[:field].any? com span role=alert text-xs text-red-600"
  - "password-toggle reutiliza data-controller=password-toggle com targets field e toggle"

requirements-completed:
  - CLIE-01
  - CLIE-02

duration: ~12min
completed: 2026-05-25
---

# Phase 02 Plan 02: Formulários de Cliente (new/edit) Summary

**Partial _form compartilhada com toggle senha Stimulus, hint dinâmico via client.persisted?, erros inline PT-BR e 4 testes de controller cobrindo create e update (incluindo blank-password guard D-10).**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-05-25
- **Tasks:** 2
- **Files created:** 5
- **Files modified:** 1

## Accomplishments

- 4 testes de controller passando (0 failures, 0 errors) cobrindo create válido, create inválido, update blank password (D-10) e update inválido
- _form.html.erb com toggle de senha reutilizando password_toggle_controller existente, placeholder dinâmico e erros inline com role=alert
- new.html.erb e edit.html.erb com card max-w-lg shadow-card, link de voltar, labels e botões PT-BR conforme UI-SPEC
- show.html.erb criada (bloqueador Rule 3) com dados de acesso readonly, toggle de senha e rotação de token
- Sincronização password_plain no create (T-02-06 mitigado): controller faz merge antes de Client.new

## Task Commits

1. **Task 1: Testes de controller** - `a4a42f5` (test)
2. **Task 2: Views new, edit, _form e show** - `b60bc64` (feat)

## Files Created/Modified

- `test/controllers/admin/clients_controller_test.rb` — 4 testes (create válido, create inválido, update blank password, update inválido)
- `app/views/admin/clients/_form.html.erb` — Partial compartilhada com toggle senha, erros inline, hint dinâmico
- `app/views/admin/clients/new.html.erb` — Formulário de criação com card max-w-lg
- `app/views/admin/clients/edit.html.erb` — Formulário de edição com campos pré-preenchidos
- `app/views/admin/clients/show.html.erb` — Detalhe do cliente com link readonly, toggle senha, rotacionar token
- `app/controllers/admin/clients_controller.rb` — Sincronização password_plain no create

## Decisions Made

- `client.persisted?` usado na _form para distinguir new vs edit — detecta se o objeto é novo ou persiste sem dependência de variáveis extras
- `show.html.erb` criada neste plano (não estava no escopo original) para desbloqueio dos testes de redirecionamento
- password_plain sincronizado no controller (não no form) — mantém o form simples com um único campo de senha

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Tampering/T-02-06] Sincronização password_plain no create ausente**
- **Found during:** Task 1 (escrita dos testes — teste assert_equal "abcd1234", novo_cliente.password_plain)
- **Issue:** Controller não sincronizava password_plain automaticamente; o form não tem campo password_plain separado, então o campo ficaria nil após create
- **Fix:** Adicionado `params_with_plain = client_params.merge(password_plain: client_params[:password])` antes de `Client.new()` na action create
- **Files modified:** `app/controllers/admin/clients_controller.rb`
- **Verification:** Teste `assert_equal "abcd1234", novo_cliente.password_plain` passa
- **Committed in:** `a4a42f5` (task 1 commit)

**2. [Rule 3 - Blocking] show.html.erb ausente bloqueava testes de redirecionamento**
- **Found during:** Task 1 (execução dos testes antes das views — ActionView::MissingTemplate para show)
- **Issue:** create e update redirecionam para admin_client_path(@client), que precisa renderizar show.html.erb. Sem a view, os testes que seguem o redirecionamento falhariam.
- **Fix:** Criada show.html.erb com card de dados de acesso (link readonly + toggle senha) e card de informações, alinhado à UI-SPEC Screen 4
- **Files modified:** `app/views/admin/clients/show.html.erb` (criado)
- **Verification:** Testes passam; view renderiza sem erros
- **Committed in:** `b60bc64` (task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 Rule 2 — funcionalidade crítica, 1 Rule 3 — bloqueador)
**Impact on plan:** Ambas as correções necessárias para corretude e segurança. Sem scope creep — show.html.erb estava implícita no escopo (controller show já existia em 02-01).

## Issues Encountered

Nenhum além das deviações documentadas acima.

## Known Stubs

Nenhum — todos os campos exibem dados reais.

## Threat Flags

Nenhum novo — todos os trust boundaries cobertos:
- T-02-06: password_plain sincronizado no create via merge() no controller
- T-02-07: blank password guard D-10 continua implementado no update
- T-02-08: erros inline exibem apenas mensagens genéricas de campo

## Next Phase Readiness

- CLIE-01 e CLIE-02 completos: admin pode criar e editar clientes com a experiência visual completa
- Plan 03 pode implementar: show.html.erb completo com copy_controller, modal Stimulus para desativar e rotacionar token
- Dependência: show.html.erb criada aqui é stub funcional — Plan 03 deve adicionar CopyButton, ConfirmModal e copy_controller

## Self-Check: PASSED

Arquivos criados:
- test/controllers/admin/clients_controller_test.rb — FOUND (a4a42f5)
- app/views/admin/clients/_form.html.erb — FOUND (b60bc64)
- app/views/admin/clients/new.html.erb — FOUND (b60bc64)
- app/views/admin/clients/edit.html.erb — FOUND (b60bc64)
- app/views/admin/clients/show.html.erb — FOUND (b60bc64)

Commits:
- a4a42f5: test(02-02): testes de controller para create e update de clientes — FOUND
- b60bc64: feat(02-02): views new, edit, _form partial e show com design UI-SPEC — FOUND

Testes: 4 runs, 18 assertions, 0 failures, 0 errors
