---
phase: 29-motor-de-envio
reviewed: 2026-08-31T00:00:00Z
depth: deep
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
  critical: 1
  warning: 5
  info: 2
  total: 8
status: issues_found
---

# Phase 29: Motor de Envio - Code Review Report

**Reviewed:** 2026-08-31
**Depth:** deep (cross-file call-chain + race-condition analysis, per ROADMAP flag on this phase)
**Files Reviewed:** 9
**Status:** issues_found

## Summary

This review traced `Divulgacoes::DispatchJob` → `Whatsapp::SendToGroupJob` →
`Evolution::Client#send_text/#send_media` line by line, against the solid_queue
1.4.0 gem source (`ActiveJob::ConcurrencyControls`, `SolidQueue::Job.enqueue`)
and the verified Evolution contract, plus every test that claims to prove
ENVIO-04/05/06/07/09 and DIVU-08.

**The core exactly-once claim is sound.** The atomic `update_all(status:
:pendente -> :enviado)` genuinely runs before any HTTP I/O, the
`retry_on(Transient)` revert-then-raise fix (`group.reload.update!(status:
:pendente, ...)`) is correct — the `.reload` really is load-bearing, confirmed
by tracing ActiveRecord dirty-tracking, not just trusting the SUMMARY's claim
— and `limits_concurrency(to: 1, key: divulgacao.client.whatsapp_instance.id)`
happens to make the "two `SendToGroupJob`s for the same divulgação racing on
`finalize_divulgacao_if_done`" scenario structurally impossible (a client has
exactly one `WhatsappInstance`, so every group in one divulgação shares the
same concurrency key and can never execute in parallel with a sibling).

However, this review found **one data-correctness bug that ships wrong audit
data for the majority of failure paths** (CR-01), plus several robustness gaps
where the code's own "defense in depth" pattern (safe navigation, always
calling `finalize_divulgacao_if_done`) is applied inconsistently across
branches that are otherwise structurally identical.

## Critical Issues

### CR-01: `sent_at` is populated by the atomic claim and never cleared on any failure path except `Transient`

**File:** `app/jobs/whatsapp/send_to_group_job.rb:94-95, 99-103, 105-110, 136-140, 142-146`

**Issue:** The atomic claim sets `sent_at: Time.current` unconditionally as
part of flipping the row to `:enviado`:

```ruby
claimed = DivulgacaoGrupo.where(id: group.id, status: :pendente)
                          .update_all(status: :enviado, sent_at: Time.current, updated_at: Time.current)
```

The *only* place that reverts `sent_at` is the `rescue
Evolution::Errors::Transient` block inside `perform` (line 125: `group.reload.update!(status:
:pendente, sent_at: nil, ...)`). Every other exit path leaves `sent_at`
populated with the claim's timestamp even though the row's final `status` is
NOT `enviado`:

- `arte_nao_aprovada` (line 100) — Evolution is **never called** (the guard
  returns before `send_via_evolution`), yet the row ends up `status: falhou`
  with a non-null `sent_at`.
- `instancia_desconectada` (line 107) — same: Evolution is never called, but
  `sent_at` is populated.
- `mark_falhou` (lines 136-140, used by `discard_on(Permanent)`,
  `discard_on(NotConnected)`, `discard_on(ConfigurationError)`, and the
  `discard_on(StandardError)` catch-all) — none of these reset `sent_at`.
- `mark_incerto` (lines 142-146, used by `discard_on(Unknown)`) — same.

Traced through `ActiveRecord` dirty-tracking: in every one of these branches
`group.update!(status: :falhou, error_code: ...)` (or `:incerto`) only
assigns `status`/`error_code`, so only those two columns appear in the
generated `UPDATE` — `sent_at` is left exactly as the earlier `update_all` set
it (a real timestamp, "now"), regardless of whether the message was ever
actually attempted.

**Impact:** For every failure that is not `Transient` — which is the
*majority* of failure modes, including the two that never even reach the
network (`arte_nao_aprovada`, `instancia_desconectada`) — the persisted row
says "sent at 14:32, status: falhou". This is a directly misleading audit
trail for the exact data phase 30's live-progress/history screens are built
on top of (`divulgacao_grupos.sent_at`). An operator reading `sent_at:
<timestamp>` on a `falhou`/`incerto` row has no way to tell "we tried and
Evolution rejected it" from "we never even attempted this, sent_at is a stale
artifact of the claim." No test in this phase's suite asserts `sent_at` on
any of the failure-path tests (`test/jobs/whatsapp/send_to_group_job_test.rb`
lines 77-99, 130-166), so this is provably untested, not just undertested.

**Fix:** The cleanest fix mirrors the already-established `Transient` revert
pattern — reset `sent_at: nil` on every path that does *not* end in
`enviado`. Simplest single-point fix: do it inside `mark_falhou`/`mark_incerto`
and the two inline `unless` guards:

```ruby
def self.mark_falhou(job, message)
  group = job.arguments.first
  group.update!(status: :falhou, sent_at: nil, error_code: message.to_s.first(ERROR_CODE_MAX_LENGTH))
  finalize_divulgacao_if_done(group.divulgacao.reload)
end

def self.mark_incerto(job, err)
  group = job.arguments.first
  group.update!(status: :incerto, sent_at: nil, error_code: err.message.to_s.first(ERROR_CODE_MAX_LENGTH))
  finalize_divulgacao_if_done(group.divulgacao.reload)
end
```

and in `perform`:

```ruby
unless arte.approved?
  group.update!(status: :falhou, sent_at: nil, error_code: "arte_nao_aprovada")
  ...
unless instance&.connected?
  group.update!(status: :falhou, sent_at: nil, error_code: "instancia_desconectada")
```

(Alternatively, and arguably cleaner: stop setting `sent_at` in the atomic
claim at all — the claim only needs `status: :enviado` to do its
locking job — and set `sent_at: Time.current` inside `send_via_evolution`
alongside `evolution_message_id` on confirmed success. That removes the need
to remember to revert it on every failure branch. `incerto` is arguably
correct to leave `sent_at` populated since a read-timeout genuinely may have
been delivered — this is a judgment call worth confirming with the CONTEXT
decision-maker, but `falhou` must never carry a `sent_at`.)

## Warnings

### WR-01: `limits_concurrency` key is unguarded against a nil `whatsapp_instance`, unlike every other resolution of the same chain

**File:** `app/jobs/whatsapp/send_to_group_job.rb:38`

**Issue:**

```ruby
limits_concurrency to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance.id }
```

Traced against the solid_queue 1.4.0 source
(`vendor/bundle/.../solid_queue-1.4.0/app/models/solid_queue/job.rb:56-65` and
`lib/active_job/concurrency_controls.rb`): this lambda is invoked at
**enqueue time**, inside `SolidQueue::Job.enqueue -> create_from_active_job ->
attributes_from_active_job -> active_job.concurrency_key`, i.e. synchronously
inside `Whatsapp::SendToGroupJob.set(wait: ...).perform_later(group)` — which
is called from inside `Divulgacoes::DispatchJob#perform`'s loop
(`app/jobs/divulgacoes/dispatch_job.rb:22`).

Every other resolution of `client.whatsapp_instance` in this phase uses safe
navigation (`instance&.connected?`, line 106 of the same file) specifically
because `has_one :whatsapp_instance` can be `nil`. The concurrency key
expression does not: `.whatsapp_instance.id` will raise `NoMethodError` on a
nil instance.

**Impact:** `Divulgacoes::DispatchJob` has no `rescue`/`discard_on`/`retry_on`
of its own (`ApplicationJob`'s defaults are commented out). If this ever
raises for one group, the exception propagates out of the `find_each` loop
and aborts **the entire dispatch for that divulgação** — not just the one
group. Every group after the failing one in iteration order is never
enqueued and never will be (no periodic reconciliation exists), leaving the
divulgação stuck in `em_andamento` with pendente rows forever, and the
`DispatchJob` itself lands in solid_queue's failed executions with no retry.
Today no code path in the app destroys a `WhatsappInstance` independently of
its `Client` (`has_one ..., dependent: :destroy` only cascades when the
`Client` itself is destroyed, which also cascades-destroys the `Divulgacao`
via `has_many :divulgacoes, dependent: :destroy`), so the trigger condition
is currently unreachable through the UI — but the inconsistency with the
`instance&.connected?` guard three lines away is a real landmine for the next
person who touches instance lifecycle (e.g. a future "re-pair by destroying
and recreating the instance" flow).

**Fix:**

```ruby
limits_concurrency to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance&.id }
```

and treat a `nil` concurrency key explicitly (per `ActiveJob::ConcurrencyControls#concurrency_limited?`,
a blank/nil key means "not limited" — i.e. the job runs unserialized in that
edge case, which is safe here since the very next line in `perform`
(`instance&.connected?`) will already fail it out to `falhou` without ever
reaching Evolution).

### WR-02: `discard_on(ActiveJob::DeserializationError)` is the one exit path that never calls `finalize_divulgacao_if_done`

**File:** `app/jobs/whatsapp/send_to_group_job.rb:87`

**Issue:** Every other terminal branch of this job — the two inline
revalidation guards, the success path, and every `mark_falhou`/`mark_incerto`
call — ends by calling `self.class.finalize_divulgacao_if_done(divulgacao)`.
The bare `discard_on(ActiveJob::DeserializationError)` (no block) does not.
The 29-02-SUMMARY.md explicitly claims "`finalize_divulgacao_if_done` is
called from every exit path of `SendToGroupJob#perform`" — this branch
contradicts that claim.

**Impact:** If a `DivulgacaoGrupo` (or its `Divulgacao`) is deleted between
enqueue and execution (e.g. a `Client` destroyed mid-flight, cascading via
`dependent: :destroy`) — this is a narrow but real window, since nothing in
this phase locks against a `Client`/`Divulgacao` destroy while jobs are
queued — the deserialization failure discards silently with **no**
finalize call. If this was the last pendente group of that divulgação, the
divulgação is left stuck in `em_andamento` forever (same failure mode the
plan's own threat model T-29-11 says is "always mitigated" — it is not, for
this one branch). Low likelihood, but the omission is unintentional relative
to the documented invariant, not a deliberate design choice like the
DIVU-08 `em_andamento` cancel restriction (which the plan explicitly
documents as deferred).

**Fix:** Give the handler a block that at least attempts to finalize the
still-resolvable side of the relationship:

```ruby
discard_on(ActiveJob::DeserializationError) do |job, _err|
  group = job.arguments.first
  begin
    Whatsapp::SendToGroupJob.finalize_divulgacao_if_done(group.divulgacao.reload)
  rescue ActiveRecord::RecordNotFound
    # both sides gone — nothing left to finalize, genuinely a no-op
  end
end
```

### WR-03: Threat model T-29-02 overstates the guarantee against media-URL leakage into `error_code`

**File:** `app/jobs/whatsapp/send_to_group_job.rb:150-159`, `app/services/evolution/client.rb:157-164`

**Issue:** The presigned `media_url` is passed as the `media:` field of the
`sendMedia` payload. `evolution-contract.md` documents that the exact 4xx
error text of `sendMedia` is **free text** (`BadRequestException(error.toString())`)
and is explicitly PENDENTE — not yet observed against a real failure. If
Evolution ever fails to fetch/download the presigned URL it was given (e.g.
malformed URL, expired mid-flight, network egress issue on the Evolution
side) and echoes that URL back in its free-text error message — a common
pattern for "failed to download resource: <url>" style errors — that URL
would flow straight through `raise_for_status!` into `err.message`, then
into `mark_falhou(job, err.message)` (`discard_on(Evolution::Errors::Permanent)`,
line 76), and be persisted (truncated to 500 chars) into
`divulgacao_grupos.error_code`.

The plan's own threat model (T-29-02, 29-01-PLAN.md) asserts the media URL
"never persisted anywhere (not written to `divulgacao_grupos`, only
`evolution_message_id` is)" — this is only true of the *code this phase
writes*; it does not account for the URL being echoed back inside Evolution's
own free-text error response and stored via the generic error-message path.
`MEDIA_URL_TTL` is short (5 minutes), which limits the exposure window, but
`error_code` is durable storage that phase 30 will render to admins — a
working (if soon-to-expire) presigned GET URL sitting in a visible error
field is a real, if narrow, information-disclosure surface.

**Fix:** Scrub the persisted `error_code` for anything that looks like the
presigned host/query pattern before truncation, or at minimum flag this as an
open question to close once the real 4xx text is observed (per
`evolution-contract.md`'s own "PENDENTE de UAT" tracking) rather than
asserting the guarantee is already closed.

### WR-04: DIVU-08 "cancel mid-dispatch" tests exercise a divulgação state that the real admin UI can never reach

**File:** `test/jobs/whatsapp/send_to_group_job_test.rb:280-291` (cf.
`app/models/divulgacao.rb:48-51`, `app/jobs/divulgacoes/dispatch_job.rb:18`,
`app/controllers/admin/divulgacoes_controller.rb:16-23`)

**Issue:** `Divulgacoes::DispatchJob#perform` flips `divulgacao.status` from
`agendada` to `em_andamento` **synchronously, at the very top of its own
`perform`** — i.e. the instant `scheduled_for` arrives, before any single
`Whatsapp::SendToGroupJob` has actually run (they are merely enqueued with a
`wait:` offset that can span many minutes for a large group list, per
CONTEXT.md's own "≈8–15 min for 20 grupos" example). `Divulgacao#cancelar!`
(unmodified by this phase) is guarded by `return false unless
status_agendada?` — so from the instant dispatch starts, `cancelar!` always
returns `false`, and `Admin::DivulgacoesController#cancel` shows "Só é
possível cancelar uma divulgação ainda agendada."

The test at line 280 that claims to prove "cancelamento DEPOIS do DispatchJob
já ter enfileirado" reaches the cancelled state via
`divulgacao.update!(status: :cancelada)` directly — **bypassing
`cancelar!`'s guard entirely**. This proves the job-level guard
(`return if divulgacao.status_cancelada?`) works correctly *given* a
cancelled row, but it does not prove DIVU-08 is reachable in production: no
button in the actual admin UI can ever produce a `cancelada` divulgação once
`DispatchJob` has run, because `cancelar!` refuses to transition anything
that isn't still `agendada`.

29-03-PLAN.md's own `<read_first>` acknowledges this exact limitation
("Uma Divulgação em_andamento... NÃO pode ser cancelada por este método hoje
— isso é INTENCIONAL... não implementar aqui") and defers it to phase 30.
That deferral is a legitimate scope decision — but the test suite currently
gives false confidence that "cancel mid-dispatch" is an end-to-end proven,
user-reachable guarantee, when it is only proven at the unit level against a
DB state the app itself cannot produce yet. This is worth flagging loudly for
phase 30, since the staggered send window (up to ~15 min) is exactly the
window during which an operator would most want to hit "cancel" upon
realizing a mistake, and today they structurally cannot.

**Fix:** No production code change required in this phase (matches the
plan's explicit scope). Recommend: (a) rename the test to make the bypass
explicit ("...simulando um mecanismo de cancelamento mid-dispatch que a fase
30 ainda precisa expor, não o `cancelar!` atual") so a future reader doesn't
mistake it for an end-to-end guarantee, and (b) carry this forward as an
explicit phase 30 requirement rather than an implicit one, since the current
UI-level gap means DIVU-08 is currently unreachable by any human operator
during the highest-value window.

### WR-05: `resp["key"]&.dig("id") || resp["id"]` can turn a successfully delivered message into a false `falhou`

**File:** `app/jobs/whatsapp/send_to_group_job.rb:162`

**Issue:** The success-shape parsing is explicitly written to be robust to
two possible shapes (RESEARCH Assumption A1, still PENDENTE per
`evolution-contract.md`), but only guards against `resp["key"]` being `nil`
(via `&.`), not against it being present-but-not-a-Hash. If a future/observed
success shape ever returns `"key"` as e.g. a string or boolean, `.dig("id")`
raises `NoMethodError`. Because this happens *after* `Evolution::Client.send_media`
has already returned successfully (the message was actually delivered to
WhatsApp), this exception is caught by the `discard_on(StandardError)`
catch-all (line 48) — which then marks the row `falhou`/`unexpected_error`
and never retries, for a message that was, in fact, sent. This is precisely
the class of bug ("misdirected/incorrect send status") this phase's review
is meant to catch, even though the trigger condition (an unverified response
shape) is speculative until UAT closes it.

**Fix:**

```ruby
key = resp["key"]
message_id = (key.is_a?(Hash) ? key["id"] : nil) || resp["id"]
group.update!(evolution_message_id: message_id)
```

## Info

### IN-01: No reconciliation if `DispatchJob.perform_later` raises right after `@divulgacao.save` succeeds

**File:** `app/controllers/admin/divulgacoes_controller.rb:62-66`

**Issue:** `Divulgacoes::DispatchJob.set(wait_until: @divulgacao.scheduled_for).perform_later(@divulgacao)`
runs after `@divulgacao.save` inside the same `if`, but is not itself
guarded. If the enqueue call raises (e.g. a transient DB error while
`solid_queue_jobs` is inserted), the divulgação record is already persisted
as `agendada` but no `DispatchJob` was ever scheduled to fire at
`scheduled_for` — and nothing else in the app will ever dispatch it. The
controller action would 500, so the admin would likely notice and could
retry the form submit (creating a duplicate divulgação, harmless), but there
is no automated safety net. Given `RESEARCH.md`'s "Janela residual" already
accepts a comparable residual risk for the claim-vs-crash window and defers
the operational remedy to phase 30's manual resend, the same reasoning
likely applies here — but this specific window (enqueue failure right after
save) is not explicitly named in either the RESEARCH or the threat model, so
it's worth confirming it's an intentionally accepted gap rather than an
oversight.

### IN-02: `rand(SEND_DELAY_MIN..SEND_DELAY_MAX)` can produce a repeated (non-strictly-increasing) offset if `SEND_DELAY_MIN` is misconfigured to `0`

**File:** `app/jobs/divulgacoes/dispatch_job.rb:23`

**Issue:** `offset += rand(Divulgacao::SEND_DELAY_MIN..Divulgacao::SEND_DELAY_MAX)`
— if an operator sets `WHATSAPP_SEND_DELAY_MIN_SECONDS=0`, `rand(0..MAX)` can
return `0`, so two consecutive groups could be scheduled at the exact same
`wait:` offset. This does not break correctness (the atomic claim still
prevents any double-send, and `limits_concurrency` still serializes the
actual sends), but it silently defeats the "staggered, anti-ban" intent the
whole feature exists for. Purely an ENV-configuration footgun, not a code
defect — worth a comment or a `SEND_DELAY_MIN` floor validation if this is a
realistic operator mistake to guard against.

---

_Reviewed: 2026-08-31_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
