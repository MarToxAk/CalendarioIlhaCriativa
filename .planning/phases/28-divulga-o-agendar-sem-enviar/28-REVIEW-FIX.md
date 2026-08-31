---
phase: 28-divulga-o-agendar-sem-enviar
fixed_at: 2026-08-31T00:20:00Z
review_path: .planning/phases/28-divulga-o-agendar-sem-enviar/28-REVIEW.md
iteration: 2
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

**Fixed at:** 2026-08-31T00:20:00Z
**Source review:** .planning/phases/28-divulga-o-agendar-sem-enviar/28-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 1 (fix_scope: critical_warning — 0 Critical, 1 Warning; the 3 Info findings were carried-over/unchanged from iteration 1 and out of scope for this pass)
- Fixed: 1
- Skipped: 0

## Fixed Issues

### WR-01 (residual): the arte selection is still lost on re-render when only the group id(s) fail to resolve

**Files modified:** `app/controllers/admin/divulgacoes_controller.rb`, `test/controllers/admin/divulgacoes_controller_test.rb`
**Commit:** `6756bca`
**Applied fix:** In `Admin::DivulgacoesController#create`'s `rescue ActiveRecord::RecordNotFound` block, the already-resolved `arte` local variable (set at line 46, before the group-resolution call that raises) is now passed into the rebuilt `@divulgacao`:

```ruby
@divulgacao ||= @client.divulgacoes.new(
  arte:          arte,
  scheduled_for: divulgacao_params[:scheduled_for]
)
```

Ruby's method-level rescue shares local variable scope, so `arte` holds the successfully-resolved `Arte` record when the exception originates from the group-resolution line; if the exception instead originates from the `arte` resolution itself, `arte` is `nil` (Ruby local-variable pre-declaration), which is a harmless no-op pass-through. This mirrors the same pattern already used for `scheduled_for` and resolvable groups in the prior (iteration-1) fix.

Added a regression test, `"WR-01 (residual): rescue RecordNotFound preserva a arte selecionada quando so o grupo falha em resolver"`, that posts a valid `arte_id` with a non-existent group id and asserts (via `assert_select`) that the re-rendered `<select name="divulgacao[arte_id]">` has `<option value="#{@arte.id}" selected>` — not just that the option is listed, which is what the prior iteration's test failed to assert (the gap the re-review caught).

**Verification:**
- Tier 1: re-read the modified controller and test sections — fix text present, surrounding rescue/group-reattachment logic intact.
- Tier 2: `ruby -c` syntax check passed on both files.
- Full test run (executed inside the isolated review-fix worktree, using `BUNDLE_PATH` pointed at the main checkout's `vendor/bundle` since the worktree doesn't carry the gitignored gem cache):
  - `test/controllers/admin/divulgacoes_controller_test.rb`: 37 runs, 278 assertions, 0 failures, 0 errors, 0 skips (36 pre-existing + 1 new).
  - Full phase-28 scope (`test/models/divulgacao_test.rb`, `test/models/divulgacao_grupo_test.rb`, `test/helpers/admin/divulgacoes_helper_test.rb`, `test/controllers/admin/divulgacoes_controller_test.rb`, `test/controllers/admin/clients_controller_test.rb`): 82 runs, 410 assertions, 0 failures, 0 errors, 0 skips.

This fix is a straightforward data-plumbing addition (pass an already-resolved local variable into a `.new(...)` call) with no branching or algorithmic logic change, and is covered by a targeted regression test asserting the exact `selected` state the review flagged as missing — no human-verification flag required.

## Skipped Issues

None — the single in-scope finding (WR-01 residual) was fixed.

---

_Fixed: 2026-08-31T00:20:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
