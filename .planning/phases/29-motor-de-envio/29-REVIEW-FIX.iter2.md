---
phase: 29-motor-de-envio
fixed_at: 2026-08-31T00:00:00Z
review_path: .planning/phases/29-motor-de-envio/29-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 29: Motor de Envio - Code Review Fix Report

**Fixed at:** 2026-08-31
**Source review:** .planning/phases/29-motor-de-envio/29-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (1 Critical + 5 Warning; the 2 Info findings were out of scope)
- Fixed: 6
- Skipped: 0

**Verification:** full phase-29 test scope run inside the isolated review-fix
worktree (`POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test
test/jobs/divulgacoes/dispatch_job_test.rb test/jobs/whatsapp/send_to_group_job_test.rb
test/services/evolution/client_test.rb test/controllers/admin/divulgacoes_controller_test.rb`).
Result after all fixes: **108 runs, 449 assertions, 0 failures, 0 errors, 0 skips.**
Per-fix Ruby syntax checks (`ruby -c`) all passed.

## Fixed Issues

### CR-01: `sent_at` populated by the atomic claim and never cleared on non-`Transient` failure paths

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commits:** `0ae33d0` (initial approach), `ca6f885` (final approach — supersedes the first)
**Status:** fixed — requires human verification of one judgment call (see note)

**Applied fix:** Took the review's "arguably cleaner" alternative rather than
the scatter-`sent_at: nil`-everywhere approach. The atomic claim no longer
writes `sent_at` at all (it only needs `status: :enviado` to do its locking
job): `update_all(status: :enviado, updated_at: Time.current)`. `sent_at` is
now written in exactly one place — `send_via_evolution`, after Evolution
confirms acceptance (`group.reload.update!(status: :enviado,
evolution_message_id:, sent_at: Time.current)`). Resulting invariant:
`sent_at != nil` iff the send is confirmed. The two inline revalidation guards
(`arte_nao_aprovada`, `instancia_desconectada`) and
`mark_falhou`/`mark_incerto` therefore no longer need to touch `sent_at`;
`mark_falhou`/`mark_incerto` still pass `sent_at: nil` explicitly (with
`group.reload`) as defense in depth. The `Transient` rescue keeps
`sent_at: nil` for the same reason.

Why the first commit (`0ae33d0`) was superseded: it added `sent_at: nil` to
each failure branch, but `group.update!(sent_at: nil)` is a no-op when the
in-memory record still has `sent_at == nil` (ActiveRecord dirty-tracking —
the same trap the `Transient` rescue comment already documents). That made 6
of the new failure-path assertions fail. `ca6f885` removes the source of the
problem instead of patching each branch.

**Tests added:** `assert_nil @group_row.sent_at` on every non-success path
(`arte_nao_aprovada`, `instancia_desconectada`, `discard_on` Permanent /
NotConnected / ConfigurationError / StandardError catch-all, `retry_on`
Transient exhaustion) and `assert_nil` on the `incerto` path.

**Human-verification note:** the review flagged as a CONTEXT decision whether
an `incerto` (read-timeout) row should retain a `sent_at`. This fix gives
`incerto` a **nil** `sent_at` (Evolution's `Unknown` is raised from inside
`send_via_evolution` before the line that sets `sent_at`, so populating it
would require extra code). Rationale: `sent_at` should mean "confirmed sent";
the `incerto` *status* itself is the "attempted, needs manual check" signal.
Confirm this matches the intended audit semantics for phase 30's history
screens.

### WR-01: `limits_concurrency` key unguarded against nil `whatsapp_instance`

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`
**Commit:** `5431fc2`
**Applied fix:** `key: ->(group) { group.divulgacao.client.whatsapp_instance&.id }`
(added safe navigation). A nil key means ActiveJob treats the job as
not-concurrency-limited, which is safe here — the first line of `perform`
(`instance&.connected?`) fails the job to `:falhou` without ever calling
Evolution. Added an explanatory comment tying it to the existing
`instance&.connected?` guard three lines away.

### WR-02: `discard_on(ActiveJob::DeserializationError)` never called `finalize_divulgacao_if_done`

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`
**Commit:** `361c2f7`
**Applied fix:** Gave the handler a block that resolves `job.arguments.first`
and calls `finalize_divulgacao_if_done(group.divulgacao.reload)`, wrapped in
`rescue ActiveRecord::RecordNotFound, ActiveJob::DeserializationError` (the
latter because re-reading `job.arguments` re-triggers deserialization of the
already-missing record). If both sides are gone it is a genuine no-op; if only
the group is gone but the divulgação survives, the still-resolvable side gets
finalized so it cannot be stranded in `em_andamento`.

### WR-03: raw Evolution error text (may echo presigned media URL) flows into `error_code`

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** `a84c85d`
**Applied fix:** Added `self.sanitize_error_code(message)` which runs
`gsub(%r{https?://[^\s"'<>)\]]+}i, "[url-redigida]")` before truncating to
`ERROR_CODE_MAX_LENGTH`. Both `mark_falhou` and `mark_incerto` now route their
error text through it, so any http(s) URL Evolution echoes back in its
free-text 4xx body (e.g. "failed to download resource: <presigned-url>") is
redacted before it is persisted to `divulgacao_grupos.error_code` (durable
storage rendered to admins in phase 30). Added a test with a signed S3 URL
inside an `Evolution::Errors::Permanent` message asserting `https://` and
`X-Amz-Signature` do not survive into `error_code`.

### WR-04: DIVU-08 "cancel mid-dispatch" tests bypass `Divulgacao#cancelar!`'s guard

**Files modified:** `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** `61788fc`
**Applied fix:** Test-only, matching the plan's explicit scope (no production
change). Renamed the main test to make the bypass explicit
("...mid-dispatch simulado via `update!` direto -- fase 30 ainda precisa expor
isso na UI") and added `# WR-04` comments at both `update!(status: :cancelada)`
call sites explaining that `Divulgacao#cancelar!` has a
`return false unless status_agendada?` guard and that `DispatchJob#perform`
flips `agendada -> em_andamento` synchronously, so the direct `update!` is a
deliberate simulation of a cancel mechanism phase 30 still needs to expose —
not the current `cancelar!` path, which no operator can reach in that window.

### WR-05: `resp["key"]&.dig("id") || resp["id"]` not type-safe against a non-Hash `resp["key"]`

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** `13563cc`
**Applied fix:**
```ruby
key = resp["key"]
message_id = (key.is_a?(Hash) ? key["id"] : nil) || resp["id"]
```
so a present-but-not-a-Hash `"key"` (string/bool in an as-yet-unverified
success shape) falls through to `resp["id"]` instead of raising `NoMethodError`
*after* the message was already delivered (which the `discard_on(StandardError)`
catch-all would otherwise turn into a false `:falhou`). Added a test with
`{ "key" => "MSG-FLAT", "id" => "MSGX" }` asserting the row ends `:enviado`
with `evolution_message_id == "MSGX"`. (This line also now carries the CR-01
`sent_at: Time.current` write.)

## Skipped Issues

None.

## Out of Scope (Info — not addressed, per `fix_scope: critical_warning`)

- **IN-01:** no reconciliation if `DispatchJob.perform_later` raises right after `@divulgacao.save`.
- **IN-02:** `rand(SEND_DELAY_MIN..SEND_DELAY_MAX)` can yield `0` if `SEND_DELAY_MIN` is misconfigured.

---

_Fixed: 2026-08-31_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
