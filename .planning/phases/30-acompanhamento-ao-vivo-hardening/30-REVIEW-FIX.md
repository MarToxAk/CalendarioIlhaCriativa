---
phase: 30-acompanhamento-ao-vivo-hardening
fixed_at: 2026-08-31T14:11:37Z
review_path: .planning/phases/30-acompanhamento-ao-vivo-hardening/30-REVIEW.md
iteration: 2
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 30: Code Review Fix Report

**Fixed at:** 2026-08-31T14:11:37Z
**Source review:** .planning/phases/30-acompanhamento-ao-vivo-hardening/30-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 1
- Fixed: 1
- Skipped: 0

## Fixed Issues

### CR-01 (residual): fix stops the synchronous 500 but the reopened `em_andamento` divulgação can still get permanently stuck when `finalize_divulgacao_if_done` re-validates `arte_deve_estar_aprovada`

**Files modified:** `app/models/divulgacao.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** cb9f823
**Applied fix:** Chose the root-cause direction the review recommended first (and for which the phase already had a precedent — `scheduled_for_no_futuro` is `on: :create` for the identical reason): scoped `arte_deve_estar_aprovada`, `arte_nao_usa_link_externo`, `arquivo_dentro_do_teto_whatsapp`, and `arte_e_grupos_do_mesmo_cliente` to `on: :create` in `app/models/divulgacao.rb`. These four are create-time defenses against a form/API stale-read, not lifetime invariants — with the scoping, neither the controller's `resend` reopen (`concluida -> em_andamento`) nor `Whatsapp::SendToGroupJob.finalize_divulgacao_if_done`'s `em_andamento -> concluida` `update!` re-runs them, so `finalize_divulgacao_if_done` can no longer raise `ActiveRecord::RecordInvalid` when a resent row's arte is still unapproved. This closes the actual crash site the reviewer traced into (`app/jobs/whatsapp/send_to_group_job.rb:174-177`), not just the one call site (`app/controllers/admin/divulgacoes_controller.rb`'s `save!(validate: false)`) patched in the prior iteration. Left the controller's `save!(validate: false)` untouched — REVIEW.md's Fix section does not call for simplifying it back to a plain `save!`, and it is now redundant-but-harmless rather than load-bearing.

Added a new job-level regression test (`test/jobs/whatsapp/send_to_group_job_test.rb`, "CR-01 residual: resend com arte ainda reprovada finaliza a divulgacao sem travar em em_andamento e sem perder o error_code") that reproduces the reviewer's empirical repro exactly: sets the divulgação to `em_andamento` and the arte to `change_requested`, then calls `Whatsapp::SendToGroupJob.perform_now` directly (not just `assert_enqueued_with`) — proving end-to-end that the group ends `falhou`/`error_code: "arte_nao_aprovada"` (not overwritten to `"unexpected_error"`) and the divulgação reaches `concluida` (not stuck in `em_andamento`).

Verification: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/jobs/whatsapp/send_to_group_job_test.rb test/models/divulgacao_test.rb test/controllers/admin/divulgacoes_controller_test.rb` — 118 runs, 575 assertions, 0 failures, 0 errors. Also ran the full suite (498 runs) to check for wider regressions from un-scoping the validations: 19 pre-existing failures remain, all in files unrelated to `Divulgacao`/`SendToGroupJob` (`test/controllers/api/v1/ai/artes_controller_test.rb` — 401 vs expected 400/422; `test/models/approval_response_test.rb` and `test/models/arte_test.rb` — turbo-stream `admin_calendar_chip` target assertions), confirmed pre-existing and untouched by this change. Ran with `workflow.use_worktrees: false` — edited and committed directly in the main checkout (no isolated worktree was created).

## Skipped Issues

None — the single in-scope finding was fixed.

---

_Fixed: 2026-08-31T14:11:37Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
