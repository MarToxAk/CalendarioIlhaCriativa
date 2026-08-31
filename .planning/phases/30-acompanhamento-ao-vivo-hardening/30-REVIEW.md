---
phase: 30-acompanhamento-ao-vivo-hardening
reviewed: 2026-08-31T14:35:00Z
depth: standard
files_reviewed: 24
files_reviewed_list:
  - app/controllers/admin/clients_controller.rb
  - app/controllers/admin/divulgacoes_controller.rb
  - app/helpers/admin/divulgacoes_helper.rb
  - app/models/divulgacao_grupo.rb
  - app/models/divulgacao.rb
  - app/views/admin/clients/show.html.erb
  - app/views/admin/divulgacoes/_grupo_row.html.erb
  - app/views/admin/divulgacoes/index.html.erb
  - app/views/admin/divulgacoes/_progresso_resumo.html.erb
  - app/views/admin/divulgacoes/resend.turbo_stream.erb
  - app/views/admin/divulgacoes/show.html.erb
  - bin/setup
  - config/cable.yml
  - config/recurring.yml
  - config/routes.rb
  - .env.example
  - test/controllers/admin/divulgacoes_controller_test.rb
  - test/helpers/admin/divulgacoes_helper_test.rb
  - test/integration/cross_client_isolation_test.rb
  - test/models/divulgacao_grupo_test.rb
  - test/models/divulgacao_test.rb
  - config/initializers/solid_queue_retention.rb
  - test/lib/solid_queue_retention_test.rb
  - app/jobs/whatsapp/send_to_group_job.rb
  - test/jobs/whatsapp/send_to_group_job_test.rb
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
---

# Phase 30: Code Review Report (iteration 3 — final re-review)

**Reviewed:** 2026-08-31T14:35:00Z
**Depth:** standard
**Files Reviewed:** 24
**Status:** clean

## Summary

This is the third and final pass of the review→fix→re-review loop. Scope was narrowed per the task to re-deriving whether commit `cb9f823` actually closes the CR-01 residual gap identified in iteration 2, and to checking that scoping four `Divulgacao` validations to `on: :create` doesn't quietly remove a defense that something else still depends on post-create. CR-02, WR-01, WR-02 were already confirmed fixed in iteration 2 and were not re-derived (nothing in `cb9f823` touches their call sites). IN-01/IN-02 remain accepted/deferred and are not re-flagged.

**CR-01 (residual) is now genuinely fixed.** Traced the full mechanism rather than trusting the commit message:

- `app/models/divulgacao.rb:58-61` now declares `arte_deve_estar_aprovada`, `arte_nao_usa_link_externo`, `arquivo_dentro_do_teto_whatsapp`, and `arte_e_grupos_do_mesmo_cliente` with `on: :create`, mirroring the pre-existing `scheduled_for_no_futuro, on: :create` pattern from iteration 1.
- With this scoping, `Whatsapp::SendToGroupJob.finalize_divulgacao_if_done`'s `divulgacao.update!(status: :concluida)` (`app/jobs/whatsapp/send_to_group_job.rb:174-177`) is a pure status-only save with no `:create` context, so `arte_deve_estar_aprovada` no longer re-runs. Confirmed by tracing Rails' validation-context semantics (`on: :create` only fires when `new_record?`) — this is stock ActiveRecord behavior, not something the codebase reimplements, so there is no edge case where the scoping "sometimes" still fires on update.
- Ran the new regression test (`test/jobs/whatsapp/send_to_group_job_test.rb:489-504`, "CR-01 residual: resend com arte ainda reprovada finaliza a divulgacao sem travar em em_andamento e sem perder o error_code") together with the full `send_to_group_job_test.rb` suite (35 tests, 112 assertions) — all green. The test genuinely drives `perform_now` end-to-end (not just `assert_enqueued_with`), reproducing the exact iteration-2 empirical repro (divulgação `em_andamento`, arte flipped to `change_requested`, group resent) and asserting both that `error_code` stays `"arte_nao_aprovada"` (not overwritten by the `unexpected_error` catch-all) and that the divulgação reaches `concluida` (not stuck).
- Manually reasoned through why the old bug is actually gone rather than just re-routed: previously `divulgacao.update!(status: :concluida)` raised `RecordInvalid` inside the job, which fell through to the class's `discard_on(StandardError)` catch-all; that handler's `mark_falhou` call then invoked `finalize_divulgacao_if_done` a second time, raising the same `RecordInvalid` again uncaught. With the validation now scoped off this call path, the first `update!` succeeds outright — the catch-all is never entered for this scenario, so there is no second raise to worry about either.
- Also ran `test/models/divulgacao_test.rb`, `test/models/divulgacao_grupo_test.rb`, `test/jobs/divulgacoes/dispatch_job_test.rb`, `test/controllers/admin/divulgacoes_controller_test.rb`, and `test/integration/cross_client_isolation_test.rb` (99 tests, 525 assertions) — all green, confirming the scoping change didn't regress creation-time enforcement (an unapproved arte, an externally-linked arte, an oversized file, or a cross-client arte/group still correctly blocks `Divulgacao#create` — these are exercised by the existing, unchanged tests in `divulgacao_test.rb`).

**Checked specifically for the "silently defanged defense-in-depth" risk the task asked about, i.e. whether any other code path expects these four validations to still guard a *later* mutation of an existing `Divulgacao`:**

- `arte_e_grupos_do_mesmo_cliente` (SEG-02 backstop): grepped the whole `app/` tree for any place that reassigns `divulgacao.arte`, `arte_id`, `client_id`, or adds to `divulgacao_grupos` outside of the initial `.new(...)`/`.build(...)` calls in `Admin::DivulgacoesController#create` (`app/controllers/admin/divulgacoes_controller.rb:107-117` and the `rescue` branch at `139-150`, both pre-`.save`). No such call exists anywhere else in the codebase — the arte/client/group relationship is immutable after creation by construction, so this check genuinely only ever mattered at create time. No regression.
- `app/jobs/divulgacoes/dispatch_job.rb:18` (`divulgacao.update!(status: :em_andamento) if divulgacao.status_agendada?`) is another status-only `update!` on `Divulgacao` that runs at `scheduled_for` time, previously also exposed to the same unscoped-validation crash pattern (e.g., if an arte were somehow unapproved by dispatch time, this call would have raised `RecordInvalid` uncaught by `Divulgacoes::DispatchJob`, which defines no `discard_on`/`retry_on` at all, permanently stalling the dispatch). This scoping fix incidentally closes that pre-existing latent bug too, at no cost — `SendToGroupJob#perform` already independently re-validates `arte.approved?`/`instance.connected?` per group (ENVIO-06/07) regardless of what `Divulgacao`-level validations do, so no defense is actually lost by not re-checking at the `em_andamento` transition.
- `Divulgacao#cancelar!` (`app/models/divulgacao.rb:68-71`) calls plain `update(status: :cancelada)` (non-bang). Before this fix, if an admin tried to cancel an `agendada` divulgação whose arte had since become unapproved, this call would have silently returned `false` (validation failure swallowed by non-bang `update`), leaving the record forever stuck as `agendada` with a misleading "Só é possível cancelar uma divulgação ainda agendada" flash. This is now also fixed as a side effect of the same scoping change. Not a regression; an incidental additional fix.
- `arquivo_dentro_do_teto_whatsapp` / `arte_nao_usa_link_externo` were never enforced at actual send time even before this commit — `Whatsapp::SendToGroupJob#send_via_evolution` never calls `divulgacao.valid?`, so these two checks only ever fired as a side effect of a status-only `update!` racing with a coincidental live edit to the arte between creation and dispatch/finalize. The admin UI's `check_editable` before_action (`app/controllers/admin/artes_controller.rb:93-96`) already blocks editing an arte's `media_file`/`external_url` while it is `approved`, so this window was already narrow before the fix and remains exactly as narrow after it — no change in exposure.

No new findings. Status is `clean`: this iteration's fix is verified correct, closes the residual gap it targets, and does not regress or defang any other validation-dependent code path found in this codebase.

---

_Reviewed: 2026-08-31T14:35:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
