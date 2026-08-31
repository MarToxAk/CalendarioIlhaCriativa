---
phase: 29-motor-de-envio
reviewed: 2026-08-31T18:00:00Z
depth: standard
review_type: re-review (post fix-pass 9d707ff..ca6f885)
files_reviewed: 9
files_reviewed_list:
  - app/jobs/divulgacoes/dispatch_job.rb
  - app/jobs/whatsapp/send_to_group_job.rb
  - app/services/evolution/client.rb
  - app/controllers/admin/divulgacoes_controller.rb
  - config/queue.yml
  - test/jobs/divulgacoes/dispatch_job_test.rb
  - test/jobs/whatsapp/send_to_group_job_test.rb
  - test/services/evolution/client_test.rb
  - test/controllers/admin/divulgacoes_controller_test.rb
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 29: Motor de Envio - Code Review Report (Re-review)

**Reviewed:** 2026-08-31
**Depth:** standard (fix-pass verification + targeted cross-file trace against solid_queue 1.4.0 / activejob 8.1.3)
**Files Reviewed:** 9
**Status:** issues_found (no blockers; 3 warnings remain)
**Test run:** `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test <9 files>` -> 108 runs, 449 assertions, 0 failures, 0 errors.

## Summary

This re-review verifies the 7-commit fix pass (`9d707ff..ca6f885`) against the
prior REVIEW.md (1 Critical + 5 Warnings + 2 Info).

**Fix verdicts:**

| Prior finding | Verdict | Notes |
|---|---|---|
| CR-01 (`sent_at` polluted audit trail) | **RESOLVED** | `sent_at` is now written only in `send_via_evolution` after Evolution confirms; claim sets `status: :enviado` only. Failure-path tests now assert `assert_nil sent_at`. Invariant `sent_at != nil <=> confirmed send` holds on every traced path. One downstream consequence for phase 30 — see IN-02. |
| WR-01 (nil `whatsapp_instance` in concurrency key) | **PARTIALLY RESOLVED** | The real bug (`NoMethodError` at enqueue aborting the whole dispatch loop) is fixed by `&.id`. But the fix's own code comment states the wrong mechanism, and a nil key does NOT mean "unserialized" — see WR-01 below. |
| WR-02 (`DeserializationError` skips `finalize_divulgacao_if_done`) | **NOT EFFECTIVELY RESOLVED** | The added block is unreachable dead code: `job.arguments.first` re-raises `DeserializationError` in exactly the scenario the handler exists for — see WR-02 below. Real-world impact is negligible (scenario is unreachable in this codebase), but the finding is not actually closed. |
| WR-03 (media URL leak into `error_code`) | **RESOLVED for the tested surface** | `sanitize_error_code` strips `https?://…` runs and is on every path where Evolution free-text reaches `error_code` (`mark_falhou`/`mark_incerto`); the `discard_on(StandardError)` catch-all persists only the static literal `"unexpected_error"`. Residual under-redaction gap — see WR-03 below. |
| WR-04 (DIVU-08 test bypasses `cancelar!` guard) | **RESOLVED** | Doc-only fix as planned: explicit `# WR-04` / "BYPASS DELIBERADO" comments and a renamed test make the simulated mid-dispatch cancel unmistakable. Adequate for a deferred-scope item. |
| WR-05 (`resp["key"]&.dig` crashes on non-Hash `key`) | **RESOLVED** | `key.is_a?(Hash) ? key["id"] : nil` guards the non-Hash shape; regression test (`{ "key" => "MSG-FLAT", "id" => "MSGX" }`) asserts `enviado` + fallback id. |

**Net:** CR-01 (the only blocker) is genuinely fixed. Three warnings survive
the fix pass — two because a prior warning was resolved in name only (WR-01
rationale, WR-02 dead code), one because the WR-03 redaction has a narrow
under-coverage gap. None is ship-blocking; the scenarios behind WR-01 and
WR-02 are currently unreachable through any code path in this app.

## Warnings

### WR-01: `limits_concurrency` fix comment documents the wrong mechanism; a nil key collapses to a single global slot, not "unserialized"

**File:** `app/jobs/whatsapp/send_to_group_job.rb:38-46`

**Issue:** The fix (`5431fc2`) correctly changed
`whatsapp_instance.id` -> `whatsapp_instance&.id`, which removes the
`NoMethodError`-at-enqueue that would abort the entire `DispatchJob#perform`
loop. That part is good.

But the accompanying comment claims:

> Com `&.id` a chave vira nil -> ActiveJob trata como "não limitado" (roda sem serialização)

This is factually wrong. Traced against
`vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb:31-43`:

```ruby
def concurrency_key
  if self.class.concurrency_key                       # the Proc — truthy
    param = compute_concurrency_parameter(...)        # => nil
    case param
    when ActiveRecord::Base ; [...]
    else ; [ concurrency_group, param ]               # => ["Whatsapp::SendToGroupJob", nil]
    end.compact.join("/")                             # => "Whatsapp::SendToGroupJob"
  end
end

def concurrency_limited? = concurrency_key.present?   # => "Whatsapp::SendToGroupJob".present? => true
```

With a nil parameter the key does **not** become nil — `.compact` drops the
nil and the key collapses to the bare concurrency-group string
`"Whatsapp::SendToGroupJob"`. `concurrency_limited?` is therefore still
`true`, and **every** instance-less send job across **all** clients now
contends for one single global slot (`to: 1`, `on_conflict: :block`). That is
the opposite of "runs without serialization." A single stuck instance-less
job would block every other instance-less job process-wide, and
`solid_queue_blocked_executions` keyed on a nonsensical shared semaphore is a
known stranding hazard.

**Impact:** Currently unreachable — there is no code path in the app that
destroys a `WhatsappInstance` independently of its `Client` (`has_one …,
dependent: :destroy` only cascades on `Client#destroy`, which also cascades
`has_many :divulgacoes, dependent: :destroy`), so `whatsapp_instance` is never
nil at enqueue time for a live divulgação. The danger is latent: the fix
comment tells the next maintainer (e.g. someone building a "re-pair by
destroying and recreating the instance" flow — the exact scenario the
original WR-01 raised) that the nil-key path is a safe no-limit fallback,
when it is actually a global chokepoint.

**Fix:** Either correct the comment to describe the real behavior, or make
the intent explicit by disabling the limit when the instance is missing:

```ruby
limits_concurrency to: 1,
  key: ->(group) { group.divulgacao.client.whatsapp_instance&.id },
  group: ->(group) { group.divulgacao.client.whatsapp_instance&.id ? "Whatsapp::SendToGroupJob" : "Whatsapp::SendToGroupJob/unlimited-#{group.id}" }
```

or simpler: accept the global-slot behavior deliberately and document it —
the job fails fast anyway (`instance&.connected?` on the first line of
`perform` drops it to `:falhou` without touching Evolution), so the slot
churns quickly. The concrete ask is: the comment must not claim "não
limitado."

### WR-02: `discard_on(ActiveJob::DeserializationError)` fix is unreachable dead code — the finalize call never runs

**File:** `app/jobs/whatsapp/send_to_group_job.rb:100-107`

**Issue:** The fix (`361c2f7`) added:

```ruby
discard_on(ActiveJob::DeserializationError) do |job, _err|
  begin
    group = job.arguments.first
    finalize_divulgacao_if_done(group.divulgacao.reload)
  rescue ActiveRecord::RecordNotFound, ActiveJob::DeserializationError
    # grupo e/ou divulgação já não existem -- nada a finalizar
  end
end
```

`ActiveJob::DeserializationError` means the job's arguments could not be
deserialized. Traced against
`activejob-8.1.3/lib/active_job/core.rb:193-197`:

```ruby
def deserialize_arguments_if_needed
  if arguments_serialized?
    @arguments = deserialize_arguments(@serialized_arguments)  # raises here
    @serialized_arguments = nil                                # never reached
  end
end
```

When deserialization raises, `@serialized_arguments` is left populated. So
calling `job.arguments` **again** inside the discard block re-invokes
`deserialize_arguments_if_needed`, which re-raises the same
`ActiveJob::DeserializationError`. The fixer clearly anticipated this — they
put `ActiveJob::DeserializationError` in the inner `rescue`. The result:
`group` is never assigned, `finalize_divulgacao_if_done` is never called, and
the block is a no-op — identical behavior to the bare
`discard_on(ActiveJob::DeserializationError)` it replaced.

The job has exactly one argument (the `DivulgacaoGrupo`). A
`DeserializationError` here can only mean that group's GlobalID no longer
resolves, so `job.arguments.first` will always re-raise. There is no partial
success.

**Impact:** Low in practice. The only way to get here is a
`DivulgacaoGrupo` row vanishing between enqueue and execution.
`WhatsappGroup` is never hard-deleted (`app/models/whatsapp_group.rb:9-11` —
"nunca apagado", sync only flips `active: false`); `divulgacao_grupos` only
cascade-delete on `Divulgacao#destroy`, which only fires on `Client#destroy`,
which also destroys the `Divulgacao` itself — so "group gone, divulgação
still needs finalizing" cannot occur. The finding is thus not a live bug, but
WR-02 is **not resolved**: the original concern (this branch skips
`finalize_divulgacao_if_done`) is still true, and there is now 6 lines of
dead code plus a comment ("Tenta finalizar o lado ainda resolvível") that
describes behavior the code cannot perform.

**Fix:** To actually finalize without re-triggering deserialization, resolve
the divulgação from the raw serialized GlobalID instead of `job.arguments`:

```ruby
discard_on(ActiveJob::DeserializationError) do |job, _err|
  gid = job.serialized_arguments&.first&.dig("_aj_globalid")
  next unless gid
  group_id = GlobalID.parse(gid)&.model_id
  divulgacao = DivulgacaoGrupo.where(id: group_id).first&.divulgacao ||
               Divulgacao.joins(:divulgacao_grupos).where(divulgacao_grupos: { id: group_id }).first
  finalize_divulgacao_if_done(divulgacao) if divulgacao
rescue StandardError
  # both sides genuinely gone
end
```

Alternatively, since the scenario is unreachable, revert to the plain
one-line `discard_on(ActiveJob::DeserializationError)` and drop the WR-02
claim — the dead block is worse than an honest no-op because it reads as
working mitigation.

### WR-03: `sanitize_error_code` misses scheme-less URLs and bare presigned-query fragments

**File:** `app/jobs/whatsapp/send_to_group_job.rb:195-198`

**Issue:** `URL_IN_TEXT = %r{https?://[^\s"'<>)\]]+}i` requires an explicit
`http://`/`https://` scheme. It correctly redacts a full presigned URL (the
tested case) and stops at whitespace/newline (no multi-line over-redaction —
`\s` includes `\n`). Two gaps remain:

1. **Scheme-less host+path**: if Evolution's free-text 4xx echoes
   `bucket.s3.amazonaws.com/artes/1.jpg?X-Amz-Signature=deadbeef&X-Amz-Expires=300`
   without a leading `https://` (some downloader libraries log the host and
   path separately from the scheme), the signature survives into durable
   `error_code`.
2. **Bare query fragment**: `…?X-Amz-Signature=deadbeef&X-Amz-Credential=…`
   echoed on its own is not touched.

The exact 4xx text of `sendMedia` is still `PENDENTE de UAT`
(`evolution-contract.md`), so whether Evolution echoes the URL with or
without scheme is unverified. The fix closes the most likely shape; these two
are residual.

**Impact:** Narrow information-disclosure surface (a short-lived presigned
GET, `MEDIA_URL_TTL = 5.minutes`) that phase 30 renders to admins. Contingent
on unverified Evolution behavior.

**Fix:** Broaden to also catch signature parameters and scheme-less S3/GCS
hosts, e.g. add a second pass:

```ruby
SIGNED_PARAM = /\b(X-Amz-Signature|X-Amz-Credential|X-Goog-Signature|Signature|AWSAccessKeyId)=[^\s&"'<>)\]]+/i
def self.sanitize_error_code(message)
  message.to_s
         .gsub(URL_IN_TEXT, "[url-redigida]")
         .gsub(SIGNED_PARAM, '\1=[redigido]')
         .first(ERROR_CODE_MAX_LENGTH)
end
```

or close the `evolution-contract.md` "PENDENTE de UAT" item first and tune
the regex to the observed shape.

## Info

### IN-01: `mark_falhou` / `mark_incerto` now call `.reload`, converting a silent no-op on a deleted row into a raised `RecordNotFound`

**File:** `app/jobs/whatsapp/send_to_group_job.rb:172, 183`

**Issue:** The CR-01 fix changed `group.update!(...)` to
`group.reload.update!(...)` in both helpers. If the `DivulgacaoGrupo` row is
gone, `reload` raises `ActiveRecord::RecordNotFound`; the old `update!`
(no reload) issued `UPDATE … WHERE id = X` affecting 0 rows and returned
without error. The exception now escapes the `discard_on` block and lands the
job in `solid_queue_failed_executions` instead of being discarded, and
`finalize_divulgacao_if_done` is skipped.

**Impact:** Effectively unreachable (same cascade analysis as WR-02 — group
rows don't vanish independently). Noting because it is a real behavior change
on a failure path in the milestone's highest-risk job. If defensiveness is
wanted, wrap the reload: `group = job.arguments.first; group.reload rescue
return`.

### IN-02: phase 30 must treat `status = :enviado AND sent_at IS NULL` as the crash-window signature, not as a renderable "sent" row

**File:** `app/jobs/whatsapp/send_to_group_job.rb:122-125` (claim) vs `225` (confirm)

**Issue:** With CR-01 fixed, a hard crash (SIGKILL / host loss — no Ruby
exception) between the atomic claim (`status: :enviado`) and the confirming
`update!` in `send_via_evolution` leaves a row `status = :enviado, sent_at =
NULL, evolution_message_id = NULL`. On worker restart solid_queue re-runs the
job; `perform` re-issues the conditional claim, gets 0 rows (already
`:enviado`), and returns — the message is never sent and the row is stuck.

This is the pre-existing "janela residual" (RESEARCH, deferred to phase 30
manual resend) — CR-01 does **not** worsen it and arguably improves
detectability: `status = :enviado AND sent_at IS NULL` is now a clean,
queryable "claimed but never confirmed" predicate (before, `sent_at` was
always populated by the claim, so the only tell was `evolution_message_id IS
NULL`). Two carry-forwards for phase 30:

1. Reconciliation should sweep `enviado + sent_at IS NULL` rows back to
   `:pendente` (or `:incerto`) after a safety interval.
2. Any phase-30 UI that formats `sent_at` for `:enviado` rows must
   null-guard — `enviado` no longer implies `sent_at` present.

### IN-03: (re-noted, original IN-01 — untouched, in scope) enqueue-after-save is unguarded

**File:** `app/controllers/admin/divulgacoes_controller.rb:62-66`

`Divulgacoes::DispatchJob.set(wait_until:).perform_later(@divulgacao)` runs
after `@divulgacao.save` with no rescue. If the enqueue raises, the divulgação
persists as `:agendada` with no `DispatchJob` scheduled and nothing to
reconcile it. Left as-is by the fix pass (expected). Confirm this is an
accepted gap alongside RESEARCH's "janela residual," or guard it in phase 30.

### IN-04: (re-noted, original IN-02 — untouched, in scope) `rand(SEND_DELAY_MIN..MAX)` can yield 0 if min is misconfigured

**File:** `app/jobs/divulgacoes/dispatch_job.rb:23`

If `WHATSAPP_SEND_DELAY_MIN_SECONDS=0`, two consecutive groups can share the
same `wait:` offset. Correctness is unaffected (atomic claim +
`limits_concurrency` still prevent double-send / parallel send), but it
silently defeats the anti-ban stagger. ENV footgun, not a code defect. Left
as-is by the fix pass (expected).

---

_Reviewed: 2026-08-31_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard (re-review)_
