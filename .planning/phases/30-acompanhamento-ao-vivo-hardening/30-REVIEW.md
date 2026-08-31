---
phase: 30-acompanhamento-ao-vivo-hardening
reviewed: 2026-08-31T13:47:32Z
depth: standard
files_reviewed: 20
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
findings:
  critical: 2
  warning: 2
  info: 2
  total: 6
status: issues_found
---

# Phase 30: Code Review Report

**Reviewed:** 2026-08-31T13:47:32Z
**Depth:** standard
**Files Reviewed:** 20
**Status:** issues_found

## Summary

Cross-client scoping in `Admin::DivulgacoesController` (`create`, `show`/`cancel` via `set_divulgacao`, and the new `resend`) is done correctly throughout — every id is re-resolved through `@client`'s association chain, never a bare `.find`, and this is proven by mutation-sensitive tests in `cross_client_isolation_test.rb` and the controller test suite. The broadcast callbacks on `Divulgacao`/`DivulgacaoGrupo` are correctly guarded by `saved_change_to_status?` and target only the specific `<li>`/summary nodes, never the whole list. `error_code` rendering in the helper correctly passes the already-sanitized string through verbatim with no re-`gsub`. The `recurring.yml` retention command was verified against the vendored `solid_queue-1.4.0` source: `discard_all_in_batches` called on a scoped relation honors that scope for `count`, the batched `pluck(:job_id)`, and the final `delete_all`, so only rows older than the retention window are pruned and the parent `solid_queue_jobs` row is removed with them (no orphans, no argument logging).

The one area that did not hold up under adversarial tracing is `Admin::DivulgacoesController#resend`: it has no server-side guard on the *current* status of the row being resent, and reopening a `concluida` divulgação calls `@divulgacao.update!(status: :em_andamento)`, which re-runs the *entire* validation suite on the model — including a validation that can legitimately be false at that exact moment (`arte_deve_estar_aprovada`), turning a normal recovery action into an unhandled 500. Both issues below are exercised by control flow the codebase itself documents as reachable (the `arte_nao_aprovada` sentinel, and the "resend" button rendered only in the view, not enforced in the controller).

## Critical Issues

### CR-01: `resend` can raise `ActiveRecord::RecordInvalid` (500) when reopening a `concluida` divulgação whose arte lost approval

**File:** `app/controllers/admin/divulgacoes_controller.rb:38-43`
**Issue:**
```ruby
@dg.update!(status: :pendente, error_code: nil, sent_at: nil, evolution_message_id: nil)
@divulgacao.update!(status: :em_andamento) if @divulgacao.status_concluida?
Whatsapp::SendToGroupJob.perform_later(@dg)
```
`Divulgacao#update!` re-runs *all* of the model's validations (only `scheduled_for_no_futuro` is scoped `on: :create` — see `app/models/divulgacao.rb:36-47`). `arte_deve_estar_aprovada` (`app/models/divulgacao.rb:84-87`), `arte_nao_usa_link_externo`, `arquivo_dentro_do_teto_whatsapp`, and `arte_e_grupos_do_mesmo_cliente` all run unconditionally on every save.

This is directly reachable through the exact recovery flow this feature exists for: `Whatsapp::SendToGroupJob` (fase 29, `app/jobs/whatsapp/send_to_group_job.rb:139-144`) sets a group to `falhou` with `error_code: "arte_nao_aprovada"` when the arte's approval was revoked between scheduling and send time, then calls `finalize_divulgacao_if_done`, which can flip the divulgação to `concluida`. `divulgacao_grupo_error_label` (`app/helpers/admin/divulgacoes_helper.rb:34`) even has a dedicated pt-BR label for this sentinel, confirming it's an expected, user-facing scenario. If the admin clicks "Reenviar" on that failed row while the arte is *still* unapproved (the normal case — nothing in this flow re-approves the arte), `@divulgacao.update!(status: :em_andamento)` re-validates `arte_deve_estar_aprovada`, which fails, and `update!` raises `ActiveRecord::RecordInvalid`. Neither `Admin::BaseController` nor `ApplicationController` has a `rescue_from` for this, so the request 500s. Neither the controller test suite nor the model test suite exercises this path — every `resend` test resets `error_code` to `"instancia_desconectada"` or `"Unknown: timeout"`, never `"arte_nao_aprovada"` on a `concluida` divulgação.

Secondary effect: because `@dg.update!` (which is *not* validated against this) already ran before the raise, a real request would leave `@dg` reset to `pendente` while `@divulgacao` stays stuck on `concluida` — an inconsistent, half-applied state (the enqueued job would still run and send, but `finalize_divulgacao_if_done`'s `if divulgacao.status_em_andamento?` guard would then never flip it back).

**Fix:** Don't let the reopen crash the whole action; either revalidate only what's needed or skip validations entirely for this state-only transition, and guard the case where the arte truly isn't resendable:
```ruby
if @divulgacao.status_cancelada?
  redirect_to admin_client_divulgacao_path(@client, @divulgacao),
              alert: "Não é possível reenviar: esta divulgação foi cancelada."
  return
end

if @divulgacao.status_concluida?
  @divulgacao.update_column(:status, Divulgacao.statuses[:em_andamento]) # bypass validations for pure status reopen
end

@dg.update!(status: :pendente, error_code: nil, sent_at: nil, evolution_message_id: nil)
Whatsapp::SendToGroupJob.perform_later(@dg)
```
(or add a `rescue ActiveRecord::RecordInvalid` around the reopen specifically and surface an actionable alert, e.g. "Não é possível reabrir: a arte não está mais aprovada."). Either way, this needs an explicit test with `error_code: "arte_nao_aprovada"` on a `concluida` divulgação whose arte is currently unapproved.

### CR-02: `resend` has no server-side guard on `@dg.status` — can re-send to a group that already received the message

**File:** `app/controllers/admin/divulgacoes_controller.rb:28-43`
**Issue:** The only state check in `resend` is `@divulgacao.status_cancelada?`. Nothing checks `@dg.status.in?(%w[falhou incerto])` before resetting the row and re-enqueueing. That check exists only client-side, as a rendering condition in the view:
```erb
<% if dg.status.in?(%w[falhou incerto]) && !dg.divulgacao.status_cancelada? %>
  <%= button_to "Reenviar", resend_admin_client_divulgacao_divulgacao_grupo_path(...) %>
<% end %>
```
(`app/views/admin/divulgacoes/_grupo_row.html.erb:35-45`). A direct POST to the `resend` route (stale tab with an old render, curl, replayed request, or simply an admin re-clicking a page that hasn't received its live-update yet) with the `id` of an `enviado` row will:
1. Wipe the audit trail (`sent_at`, `evolution_message_id` set back to `nil`) of a message that was already confirmed delivered.
2. Flip status back to `pendente`.
3. Re-enqueue `Whatsapp::SendToGroupJob`, whose atomic claim (`app/jobs/whatsapp/send_to_group_job.rb:135-137`) only protects against *concurrent* re-processing of the same still-`pendente` row — it does **not** know the row was previously `enviado`. The claim succeeds (status is `pendente` again) and the job proceeds to call `send_via_evolution`, sending a second, duplicate message to the WhatsApp group.

This directly contradicts the "must never call Evolution synchronously and must re-enqueue verbatim" guarantee's implicit precondition — the resend contract only makes sense for `falhou`/`incerto` rows; nothing stops it from firing on `enviado` (or even `pendente`, which would race a job that's already claimed/in-flight, though that case at least self-resolves via the atomic claim).

**Fix:**
```ruby
def resend
  @divulgacao = @client.divulgacoes.find(params[:divulgacao_id])
  @dg = @divulgacao.divulgacao_grupos.find(params[:id])

  if @divulgacao.status_cancelada?
    redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                alert: "Não é possível reenviar: esta divulgação foi cancelada."
    return
  end

  unless @dg.status.in?(%w[falhou incerto])
    redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                alert: "Só é possível reenviar um grupo que falhou ou ficou incerto."
    return
  end
  # ... existing update!/perform_later
end
```
Add a controller test posting `resend` against a `dg` with `status: :enviado` and asserting `assert_no_enqueued_jobs` + no mutation, mirroring the existing "divulgacao cancelada" guard test.

## Warnings

### WR-01: `Divulgacao::SEND_DELAY_MIN/MAX`-style `Integer(ENV.fetch(...))` pattern reused in a scheduled command with no failure isolation

**File:** `config/recurring.yml:25,32`
**Issue:** `Integer(ENV.fetch("SOLID_QUEUE_FAILED_RETENTION_DAYS", "14"))` raises `ArgumentError` if the env var is ever set to a non-integer value (e.g. `"14d"`, `""`, a stray whitespace from a `.env` copy/paste). Unlike `Divulgacao::SEND_DELAY_MIN/MAX` (`app/models/divulgacao.rb:17-18`), which fails fast once at boot and is caught immediately by any smoke test, this expression is re-evaluated by solid_queue's recurring-task runner on every scheduled invocation (daily, both `production:` and `development:`). A bad value silently breaks the retention job every day going forward — `solid_queue_failed_executions` (which the code itself documents as holding job arguments "em texto claro") would then never get pruned, quietly defeating the exact hardening goal INFRA-07 exists for, with no visible failure short of digging through solid_queue's own failed-execution records for the recurring task's own job.
**Fix:** Validate the env var once during initialization the same way `Divulgacao::SEND_DELAY_MIN/MAX` do (fail fast at boot instead of daily at 3am in prod), e.g. an initializer that reads/validates `SOLID_QUEUE_FAILED_RETENTION_DAYS` and exposes a small constant/method that `recurring.yml`'s `command:` calls into, so a misconfiguration surfaces immediately instead of silently disabling the retention job.

### WR-02: Misleading comment on `divulgacao_placar`

**File:** `app/helpers/admin/divulgacoes_helper.rb:42-45`
**Issue:** The comment above `divulgacao_placar` says `"para {n} grupos" / singular NAO e pluralizado (copy travada na fase 28, ver divulgacao_duration_estimate acima)` — but `divulgacao_placar`'s actual output format (`"N enviados · N falhou · N pendente · N incerto"`) never contains the string `"para {n} grupos"` at all; that phrase belongs only to `divulgacao_duration_estimate` just above it. The comment appears to have been copy-pasted from the wrong helper and misdescribes what's being guarded here (the real non-pluralization is `"1 pendente"` vs `"1 pendentes"`, tested at `test/helpers/admin/divulgacoes_helper_test.rb:133-136`, which is itself a slightly odd contract — `"pendentes"` is used for the "all rows pending" branch but singular `"pendente"` in the mixed-status join).
**Fix:** Correct the comment to describe `divulgacao_placar`'s own pluralization behavior, or remove the cross-reference if it's not needed.

## Info

### IN-01: `bin/setup`'s solid_cable block duplicates the solid_queue block verbatim (structure, not values)

**File:** `bin/setup:47-62`
**Issue:** The newly added solid_cable schema-load block is a line-for-line structural duplicate of the solid_queue block immediately above it (`bin/setup:28-45`) — same `system(...) || system!("bin/rails", "runner", <<~RUBY)` shape, same idempotency check pattern. This is consistent with the existing style (the comment even says "Mesmo tratamento idempotente do bloco solid_queue acima"), so it's a deliberate consistency choice rather than an oversight, but it's still worth flagging as a candidate for extraction into a small helper (`load_schema_if_missing(table:, task:, schema_file:)`) if a third schema (or a change to the retry logic) is ever added.
**Fix:** Optional: extract a shared local method/lambda inside the `FileUtils.chdir` block taking `table:`, `task:`, `schema_file:` to remove the duplication.

### IN-02: `_progresso_resumo.html.erb` recomputes counts via a live SQL query while `divulgacao_placar` reads the same data from an already-preloaded Ruby array

**File:** `app/views/admin/divulgacoes/_progresso_resumo.html.erb:5` vs `app/helpers/admin/divulgacoes_helper.rb:46-63`
**Issue:** `_progresso_resumo` does `divulgacao.divulgacao_grupos.group(:status).count`, issuing a fresh `GROUP BY` query, while `divulgacao_placar` (used on `index`/`clients#show`) does `divulgacao.divulgacao_grupos.to_a` and counts in Ruby to leverage the already-`includes`d association and stay N+1-safe. Both partial usages here are single-record contexts (broadcast callbacks, `show.html.erb`) so this isn't an N+1 in practice today, but the two helpers compute the same four-way breakdown two different ways with no shared source of truth — a future call site that renders `_progresso_resumo` inside a list (the natural next step for this UI) would silently reintroduce the N+1 that `divulgacao_placar` was specifically hardened against (see `T-30-11` test at `test/controllers/admin/divulgacoes_controller_test.rb:567-583`).
**Fix:** Consider having `_progresso_resumo` use `divulgacao.divulgacao_grupos.to_a.group_by(&:status)`-style counting (matching `divulgacao_placar`'s approach) so both partials share one N+1-safe counting strategy, or extract a shared `divulgacao_status_counts(divulgacao)` helper used by both.

---

_Reviewed: 2026-08-31T13:47:32Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
