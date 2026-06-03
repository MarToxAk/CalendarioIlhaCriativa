---
plan: 08-01
phase: 08-approval-bug-fix
status: complete
completed: 2026-06-02
key-files:
  created: []
  modified:
    - app/views/client/artes/show.html.erb
---

## Summary

Corrigido o bug "Resposta inválida" nos botões Aprovar e Pedir Alteração do portal do cliente. A causa raiz era a ausência de `scope: :approval_response` nos dois `form_with` da view de detalhe da arte, fazendo os campos chegarem como `params[:decision]` em vez de `params[:approval_response][:decision]`. O controller usa `params.dig(:approval_response, :decision)` → retornava `nil` → disparava o guard "Resposta inválida" antes de qualquer gravação.

## What Was Built

Fix de 2 linhas em `app/views/client/artes/show.html.erb`:
- Linha 110 (formulário "Aprovar"): adicionado `scope: :approval_response` no `form_with`
- Linha 123 (formulário "Pedir Alteração"): adicionado `scope: :approval_response` no `form_with`

Com `scope: :approval_response`, o Rails envolve todos os campos `f.hidden_field` e `f.text_area` no wrapper `approval_response[...]`, fazendo `params[:approval_response][:decision]` existir conforme esperado pelo controller.

## Verification

- `grep -c "scope: :approval_response" app/views/client/artes/show.html.erb` → 2 ✓
- `rails test test/controllers/client/responses_controller_test.rb` → 6 runs, 37 assertions, 0 failures, 0 errors ✓
- `git diff app/controllers/client/responses_controller.rb` → sem alterações ✓
- Verificação visual aprovada pelo usuário: botões Aprovar e Pedir Alteração funcionam sem exibir "Resposta inválida" ✓
- (SC3) Badge da arte no calendário do cliente reflete estado atualizado ✓
- (SC4) Painel admin de feedback exibe respostas registradas ✓

## Deviations

Nenhum desvio. Fix aplicado exatamente conforme planejado.

## Self-Check: PASSED
