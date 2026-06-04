---
phase: 13-p-gina-aprova-es
fixed_at: 2026-06-04T00:00:00Z
review_path: .planning/phases/13-p-gina-aprova-es/13-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 13: Code Review Fix Report

**Fixed at:** 2026-06-04T00:00:00Z
**Source review:** .planning/phases/13-p-gina-aprova-es/13-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (1 Critical, 3 Warnings)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: Unescaped output of `pagy_nav` exposes XSS vector

**Files modified:** `app/controllers/admin/approvals_controller.rb`, `app/views/admin/approvals/index.html.erb`
**Commits:** `536e063`, `d09665e`
**Applied fix:**
- Controller: adicionada coerção `params[:client_id].to_i` com guard `client_id > 0` para que o valor numérico (nunca uma string arbitrária) seja refletido nas URLs de paginação.
- View: substituído `<%==` por `<%=` em `pagy_nav(@pagy)` para que o HTML gerado passe pelo escape automático do Rails, eliminando o vetor XSS.

### WR-01: `client_id` filter parameter is not coerced to Integer

**Files modified:** `app/controllers/admin/approvals_controller.rb`
**Commit:** `536e063`
**Applied fix:** Incorporado ao fix do CR-01. O bloco `if params[:client_id].present?` agora faz `.to_i` e só aplica o filtro se `client_id > 0`, evitando resultados silenciosamente vazios para valores não-inteiros ou zero.

### WR-02: Filter state is not preserved when paginating

**Files modified:** `app/controllers/admin/approvals_controller.rb`
**Commit:** `536e063`
**Applied fix:** Adicionado `params: { client_id: params[:client_id], decision: params[:decision] }.compact_blank` à chamada `pagy(scope, ...)`. Os filtros ativos são agora incorporados nos links de paginação, preservando o estado dos filtros ao navegar entre páginas.

### WR-03: `_approval_row` partial accesses `arte.client.name` without nil guard

**Files modified:** `app/views/admin/approvals/_approval_row.html.erb`
**Commit:** `7ccff1a`
**Applied fix:** Substituída a cadeia `approval_response.arte.client.name` por `approval_response.arte&.client&.name || "—"`. Adicionado comentário na primeira linha do partial documentando o invariante de que o caller deve fazer eager-load via `joins(arte: :client)`.

---

## Test Results

Após aplicar todos os fixes, rodado:

```
bundle exec rails test test/controllers/admin/approvals_controller_test.rb
```

Resultado: **8 runs, 20 assertions, 0 failures, 0 errors, 0 skips**

---

_Fixed: 2026-06-04T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
