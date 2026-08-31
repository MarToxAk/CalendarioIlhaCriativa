---
phase: 28-divulga-o-agendar-sem-enviar
fixed_at: 2026-08-31T00:10:18Z
review_path: .planning/phases/28-divulga-o-agendar-sem-enviar/28-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

**Fixed at:** 2026-08-31T00:10:18Z
**Source review:** .planning/phases/28-divulga-o-agendar-sem-enviar/28-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (2 Critical + 2 Warning; Info findings out of scope for this run)
- Fixed: 4
- Skipped: 0

**Verification environment:** All fixes were edited and verified inside an isolated git
worktree (`.claude/worktrees/rf-28-*`, gem path shared from the main checkout's
`vendor/bundle` via `BUNDLE_PATH`), then fast-forwarded onto `main`. Test results below are
reproducible from `main` after the fast-forward.

## Fixed Issues

### CR-01: `Divulgacao#cancelar!` fails once `scheduled_for` is in the past

**Files modified:** `app/models/divulgacao.rb`, `test/models/divulgacao_test.rb`
**Commit:** `da02339`
**Applied fix:** Adopted the review's preferred Option A — scoped the
`scheduled_for_no_futuro` validation to `on: :create` (`validate
:scheduled_for_no_futuro, on: :create`), so the update triggered by
`cancelar!` (and any future status-transition update in phase 29) no longer
re-runs a creation-only business rule. Added a regression test that creates a
divulgação 2 seconds in the future, travels 3 seconds forward (past
`scheduled_for`), and asserts `cancelar!` still returns `true` and flips
status to `cancelada`. Verified: 23/23 tests pass in
`test/models/divulgacao_test.rb`.

### CR-02: Malformed `whatsapp_group_ids` / `arte_id` param shapes crash `#create` with an unhandled 500

**Files modified:** `app/controllers/admin/divulgacoes_controller.rb`,
`test/controllers/admin/divulgacoes_controller_test.rb`
**Commit:** `137e2d9` (shipped together with WR-02, since WR-02's strong-params
change is what closes CR-02 for the Hash-shaped case and for the Array-shaped
case — see WR-02 below for the fix mechanics)
**Applied fix:** Added regression tests reproducing both malformed shapes
from the review's repro (`whatsapp_group_ids` as a Hash, `arte_id` as an
Array) against a real `post` request. Empirically verified via a standalone
`ActionController::Parameters#permit` check that:
- a Hash-shaped `whatsapp_group_ids` submission is stripped to `nil` by
  `permit(whatsapp_group_ids: [])` (Rails only accepts real Arrays for
  array-typed permits) — `Array(nil)` then safely yields `[]`, and the
  request falls through to the *existing* `ao_menos_um_grupo` validation
  message rather than crashing.
- an Array-shaped `arte_id` submission is stripped to `nil` by the scalar
  `permit(:arte_id)` (Rails only accepts scalar types for scalar permits) —
  `@client.artes.find(nil)` then raises `ActiveRecord::RecordNotFound`, which
  is already rescued by the existing `rescue ActiveRecord::RecordNotFound`
  clause.
Both cases now resolve to a clean `:unprocessable_entity` re-render, never a
500. Verified: 35/35 tests pass in
`test/controllers/admin/divulgacoes_controller_test.rb`.

### WR-01: Form values wiped on the `RecordNotFound` rescue path

**Files modified:** `app/controllers/admin/divulgacoes_controller.rb`,
`test/controllers/admin/divulgacoes_controller_test.rb`
**Commit:** `9aaed39`
**Applied fix:** In the `rescue ActiveRecord::RecordNotFound` branch,
`@divulgacao` is now built with the raw `scheduled_for` from
`divulgacao_params` instead of a fully blank record, and the groups that
still resolve via `scoped_active_groups.where(id: resolved_gids)` are
re-attached as `divulgacao_grupos` before re-rendering — so a single
foreign/deactivated id no longer forces the admin to redo the entire form.
Added a regression test: submits a valid group (`@g1`) alongside a foreign
group (`group_b`, triggering the rescue) and a fixed `scheduled_for` string,
then asserts the re-rendered form still shows `@g1`'s checkbox `checked` and
the raw `scheduled_for` string in the response body, while confirming
`group_b`'s data never leaks (SEG-01/SEG-02 invariant preserved). Verified:
36/36 tests pass in `test/controllers/admin/divulgacoes_controller_test.rb`.

### WR-02: `arte_id` / `whatsapp_group_ids` read via ad-hoc `params.dig` instead of strong params

**Files modified:** `app/controllers/admin/divulgacoes_controller.rb`,
`test/controllers/admin/divulgacoes_controller_test.rb`
**Commit:** `137e2d9`
**Applied fix:** Added a `divulgacao_params` private method:
`params.require(:divulgacao).permit(:arte_id, :scheduled_for,
whatsapp_group_ids: [])`, matching the plan's documented threat model
(T-28-03). Replaced all three `params.dig(:divulgacao, ...)` call sites in
`#create` with `divulgacao_params[...]`. As noted in the review, this closes
CR-02's Hash-shaped case "for free" via Rails' built-in coercion/stripping
behavior for array-typed permits, and additionally closes the Array-shaped
`arte_id` case via the scalar-permit stripping behavior (confirmed
empirically, not just by inspection — see CR-02 above). Verified: 35/35
tests pass in `test/controllers/admin/divulgacoes_controller_test.rb`.

## Phase-Wide Verification

Full phase test scope run after all 3 commits (from inside the worktree,
gems resolved against the main checkout's `vendor/bundle`):

```
bin/rails test test/models/divulgacao_test.rb test/models/divulgacao_grupo_test.rb \
  test/helpers/admin/divulgacoes_helper_test.rb \
  test/controllers/admin/divulgacoes_controller_test.rb \
  test/controllers/admin/clients_controller_test.rb
```

Result: **81 runs, 403 assertions, 0 failures, 0 errors, 0 skips.**

## Skipped Issues

None — all 4 in-scope findings (CR-01, CR-02, WR-01, WR-02) were fixed.

## Out of Scope (not attempted this run — `fix_scope: critical_warning`)

- **IN-01:** `new.html.erb` re-queries `@client.whatsapp_instance` instead of
  reusing `@instance`.
- **IN-02:** N+1 on `divulgacao_grupos.size` in `index.html.erb` and the
  `clients#show` mirror card.
- **IN-03:** `_status_badge.html.erb` / `_grupo_row.html.erb` `case`
  statements have no defensive `else` branch.

---

_Fixed: 2026-08-31T00:10:18Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
