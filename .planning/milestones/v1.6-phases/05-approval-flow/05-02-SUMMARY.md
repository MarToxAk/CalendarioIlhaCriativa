---
phase: 05-approval-flow
plan: "02"
subsystem: approval-client-ui
tags:
  - approval-flow
  - stimulus
  - client-portal
  - idor-protection
dependency_graph:
  requires:
    - 05-01
  provides:
    - client-approval-create-action
    - approval-inline-form
    - approval-history-section
  affects:
    - app/controllers/client/responses_controller.rb
    - app/views/client/artes/show.html.erb
    - app/javascript/controllers/approval_controller.js
tech_stack:
  added: []
  patterns:
    - Client::ResponsesController herdando ClientController (skip admin auth)
    - @client.artes.find para escopo IDOR (nunca Arte.find direto)
    - Stimulus Controller com static targets e toggle de classe CSS "hidden"
    - form_with method: :post com hidden_field para decision enum
    - Guard if pending? || revised? para visibilidade de botões (ocultos, não desabilitados)
key_files:
  created:
    - app/controllers/client/responses_controller.rb
    - app/javascript/controllers/approval_controller.js
    - test/controllers/client/responses_controller_test.rb
  modified:
    - app/views/client/artes/show.html.erb
    - app/views/sessions/new.html.erb
decisions:
  - "flash_notice_for: string de flash extraído em método privado para legibilidade"
  - "Guard if pending?||revised? envolve APENAS os botões, não o histórico (D-07)"
  - "approval_controller.js não altera index.js: eagerLoadControllersFrom carrega automaticamente"
  - "strftime direto em vez de I18n.l format: :short (locale pt-BR não define datetime :short)"
metrics:
  duration: "6 minutes"
  completed_date: "2026-05-26"
  tasks_completed: 2
  files_changed: 5
---

# Phase 05 Plan 02: Client Approval UI — Fatia Vertical Completa Summary

**One-liner:** Client::ResponsesController com escopo IDOR + approval_controller.js Stimulus + show.html.erb com botões condicionais e histórico de respostas.

## What Was Built

### Task 1: Client::ResponsesController + Testes de Integração (TDD)

**Controller `app/controllers/client/responses_controller.rb`:**
- Herda `ClientController` (skip admin auth, load_client_from_token, require_client_auth)
- `before_action :set_arte` — usa `@client.artes.find(params[:arte_id])` com rescue RecordNotFound → redirect calendário (T-05-02-01: IDOR bloqueado)
- `create`: `@arte.approval_responses.build(response_params)`, save → redirect com flash notice; falha → redirect com alert (validator rejeita re-aprovação)
- `flash_notice_for(decision)`: "Arte aprovada!" ou "Pedido de alteração enviado."
- `response_params`: `permit(:decision, :comment)` estritamente (T-05-02-03)

**Testes `test/controllers/client/responses_controller_test.rb` (6 testes):**
- Test 1 (APRO-01): POST approved → arte aprovada, flash "Arte aprovada!", redirect
- Test 2 (APRO-02): POST change_requested com comment → comment salvo, flash correto
- Test 3 (APRO-02 opcional): POST change_requested sem comment → válido, comment nil
- Test 4 (APRO-05): POST para arte já approved → reject pelo validator, sem nova ApprovalResponse
- Test 5 (IDOR): POST com arte_id de outro cliente → redirect calendário, sem criar resposta
- Test 6 (sem auth): POST sem sessão → redirect login

### Task 2: approval_controller.js + show.html.erb (botões + histórico)

**Stimulus controller `app/javascript/controllers/approval_controller.js`:**
- `static targets = ["commentForm"]`
- `toggleComment()`: `classList.toggle("hidden")`
- `hideComment()`: `classList.add("hidden")`
- Carregado automaticamente via `eagerLoadControllersFrom` em index.js

**View atualizada `app/views/client/artes/show.html.erb`:**

Seção A — Botões (guarded por `if @arte.pending? || @arte.revised?`):
- Botão Aprovar: `form_with` + `hidden_field :decision, "approved"` + submit (D-05)
- Botão Pedir Alteração: `data-action="approval#toggleComment"` (D-03)
- Formulário inline oculto: `data-approval-target="commentForm" class="hidden"`, textarea opcional, botão Enviar e Cancelar com `approval#hideComment`

Seção B — Histórico de respostas (sempre visível quando há respostas — D-07):
- Guard `if @arte.approval_responses.any?`
- Listagem em ordem `created_at desc` (scope definido no model em 05-01)
- Ícone verde ✓ para approved, vermelho ✕ para change_requested
- Data em `strftime("%d/%m/%Y %H:%M")`
- Comentário exibido quando `present?`

## Verification Results

```
67 runs, 209 assertions, 0 failures, 0 errors, 0 skips
```

Verificações adicionais:
- `bin/rails routes | grep client_arte_response` → `POST /c/:token/artes/:arte_id/responses client/responses#create`
- `grep "Arte.find" responses_controller.rb` → retorna 0 (nunca Arte.find direto)
- `grep -c "approval_responses" show.html.erb` → 2

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Bloqueio] Model client.rb e initializer rack_attack.rb ausentes no worktree**
- **Found during:** Task 1 (RED phase)
- **Issue:** O worktree não tinha `app/models/client.rb` nem `config/initializers/rack_attack.rb` — arquivos do repo principal não-commitados, mesma situação documentada em 05-01.
- **Fix:** Copiados do repo principal para o worktree.
- **Files modified:** `app/models/client.rb`, `config/initializers/rack_attack.rb`
- **Commit:** b1bf4f5

**2. [Rule 3 - Bloqueio] sessions/new.html.erb sem banner flash causava falhas em PasswordsControllerTest**
- **Found during:** Task 2 (verificação de suite completa)
- **Issue:** `app/views/sessions/new.html.erb` no worktree não tinha o bloco de flash notice (banner verde), presente no repo principal. 3 testes de PasswordsControllerTest falhavam porque seguem redirect para new_session_path e verificam o flash.
- **Fix:** Copiado `sessions/new.html.erb` atualizado do repo principal.
- **Files modified:** `app/views/sessions/new.html.erb`
- **Commit:** c99bd2a

## Known Stubs

Nenhum — todos os dados são persistidos via ApprovalResponse real, flash vem do controller, histórico lê do banco.

## Threat Flags

Nenhum — todas as superfícies cobertas pelo threat_model do plano:
- T-05-02-01: `@client.artes.find` — IDOR bloqueado, redirect sem vazar info
- T-05-02-02: Validator `arte_must_be_pending` rejeita re-aprovação server-side
- T-05-02-03: `permit(:decision, :comment)` — sem mass assignment
- T-05-02-04: `form_with` inclui authenticity_token (CSRF)
- T-05-02-05: Enum validation no model bloqueia decision inválido

## Self-Check: PASSED

- [x] `app/controllers/client/responses_controller.rb` — EXISTS, herda ClientController
- [x] `@client.artes.find` em set_arte — CONFIRMED (grep "Arte.find" retorna 0)
- [x] `test/controllers/client/responses_controller_test.rb` — 6 testes, todos VERDES
- [x] `app/javascript/controllers/approval_controller.js` — EXISTS, targets=["commentForm"]
- [x] `app/views/client/artes/show.html.erb` — guard pending?||revised? para botões
- [x] `approval_responses` em show.html.erb — 2 ocorrências (histórico + build)
- [x] Suite completa: 67 testes verdes — CONFIRMED
- [x] Commits: b1bf4f5 (Task 1), c99bd2a (Task 2) — VERIFIED
