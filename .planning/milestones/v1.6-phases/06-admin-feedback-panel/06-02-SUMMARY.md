---
phase: 06-admin-feedback-panel
plan: "02"
subsystem: admin-feedback
tags:
  - strong-parameters
  - form
  - admin_reply
  - tdd
dependency_graph:
  requires:
    - "06-01: admin_reply:text column migrated, test_update_admin_reply stub created"
    - "02: Admin::ArtesController with update action"
  provides:
    - "arte_params with :admin_reply permitted"
    - "Internal reply card in admin artes show for change_requested/revised artes"
  affects:
    - "app/controllers/admin/artes_controller.rb"
    - "app/views/admin/artes/show.html.erb"
tech_stack:
  added: []
  patterns:
    - "form_with model: [:admin, @arte] as a separate form outside action buttons (avoids nested forms)"
    - "Conditional rendering based on arte status (change_requested? || revised?) for reply card"
    - "value: @arte.admin_reply on f.text_area to display persisted value on reload"
key_files:
  created: []
  modified:
    - app/controllers/admin/artes_controller.rb
    - app/views/admin/artes/show.html.erb
decisions:
  - "Separate form card for admin_reply — not nested inside main card or action buttons div (avoids dual-PATCH nesting pitfall from RESEARCH.md)"
  - "Conditional on change_requested? || revised? — pending and approved artes do not show the reply card (D-10)"
  - "f.text_area with value: @arte.admin_reply — Rails form helper escapes HTML automatically (T-06-03 mitigated)"
metrics:
  duration: "~10 min"
  completed_date: "2026-05-27"
  tasks_completed: 2
  files_changed: 2
requirements:
  - PAIN-05
---

# Phase 06 Plan 02: Admin Reply Card (PAIN-05) Summary

**One-liner:** :admin_reply added to arte_params strong parameters and dedicated internal reply card added to admin artes show, rendered conditionally for change_requested/revised artes only.

## What Was Built

Este plano entrega a fatia vertical completa do campo de resposta interna do admin (PAIN-05): strong parameters expandidos + card de formulário na view show.

### Task 1: Expandir arte_params com :admin_reply (TDD GREEN)

- Adicionado `:admin_reply` ao `params.require(:arte).permit(...)` em `Admin::ArtesController#arte_params`
- Teste `test_update_admin_reply` (stub criado no Plano 01 em RED) passa agora: 1 run, 0 failures
- PATCH /admin/artes/:id com `params: { arte: { admin_reply: "Nota" } }` persiste o valor no banco
- Nenhuma outra alteração no controller — action `update` existente já usa `arte_params` e já redireciona com notice

### Task 2: Card de resposta interna na show da arte

- Adicionado bloco condicional `<% if @arte.change_requested? || @arte.revised? %>` ao final de `show.html.erb`
- Card com classes `bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl mt-6`
- Título `h3`: "Resposta interna ao comentário"
- Formulário separado: `form_with model: [:admin, @arte], method: :patch` — fora do card principal e do div.flex.gap-2
- `f.text_area :admin_reply` com `value: @arte.admin_reply` para exibir valor salvo ao recarregar
- Botão "Salvar resposta" com classes de cor brand `bg-[#0F7949]`
- Artes com status pending ou approved NÃO exibem o card (D-10 enforcement)

## Verification Results

```
bundle exec rails test test/controllers/admin/artes_controller_test.rb
11 runs, 29 assertions, 0 failures, 0 errors, 0 skips

grep -rn "admin_reply" app/views/client/
(sem resultados — CLEAN: admin_reply not in client views)
```

## Success Criteria Assessment

- [x] Admin preenche "Resposta interna ao comentário" em arte com pedido de alteração e clica "Salvar resposta" — a resposta é salva e exibida ao recarregar (PAIN-05)
- [x] Artes pending/approved não exibem o card de resposta interna (verificado por condição change_requested? || revised?)
- [x] O portal do cliente não exibe admin_reply em nenhuma circunstância (D-10 — grep retorna 0 resultados em app/views/client/)
- [x] bin/rails test test/controllers/admin/artes_controller_test.rb: 11 runs, 0 failures, 0 errors
- [x] arte_params contém :admin_reply no permit
- [x] show.html.erb contém form_with model: [:admin, @arte], method: :patch
- [x] show.html.erb contém f.text_area :admin_reply

## Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1 (GREEN) | 9dc7532 | feat | add :admin_reply to arte_params strong parameters |
| Task 2 | 1e143de | feat | add internal reply card to admin artes show (PAIN-05) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Worktree sem .bundle/config e sem .env**
- **Found during:** Task 1 — ao executar bin/rails test
- **Issue:** Worktree não herdou `.bundle/config` nem `.env`, causando `Bundler::GemNotFound` (mesmo cenário do Plano 01)
- **Fix:** Criado `.bundle/config` com `BUNDLE_PATH: /home/bot/calendario_livia/vendor/bundle`; criado symlink `.env -> /home/bot/calendario_livia/.env`
- **Files modified:** .bundle/config (worktree-local, não rastreado no git), .env (symlink)

### Known Stubs

Nenhum stub remanescente neste plano. O stub `test_update_admin_reply` criado em Plano 01 (RED) foi resolvido neste plano (GREEN).

## Threat Surface

- **T-06-03 (XSS):** `f.text_area :admin_reply` com `value: @arte.admin_reply` usa escape automático do Rails form helper — `raw()` e `html_safe` não usados em lugar nenhum
- **T-06-04 (Mass assignment):** Apenas `:admin_reply` adicionado ao permit — nenhum outro campo novo
- **T-06-05 (Information Disclosure):** `grep -rn "admin_reply" app/views/client/` retorna 0 resultados — campo não exposto ao cliente

## Self-Check: PASSED

- [x] `app/controllers/admin/artes_controller.rb` contém `:admin_reply` no permit (linha 67)
- [x] `app/views/admin/artes/show.html.erb` contém `change_requested? || @arte.revised?`
- [x] `app/views/admin/artes/show.html.erb` contém `form_with model: [:admin, @arte], method: :patch`
- [x] `app/views/admin/artes/show.html.erb` contém `f.text_area :admin_reply`
- [x] `app/views/admin/artes/show.html.erb` contém "Resposta interna ao comentário"
- [x] Commits 9dc7532 e 1e143de existem no histórico
- [x] 11 testes do artes_controller passando, 0 failures
- [x] admin_reply ausente em todas as views do portal do cliente
