---
phase: 29-motor-de-envio
fixed_at: 2026-08-31T00:00:00Z
review_path: .planning/phases/29-motor-de-envio/29-REVIEW.md
iteration: 2
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 29: Motor de Envio - Code Review Fix Report

**Fixed at:** 2026-08-31
**Source review:** .planning/phases/29-motor-de-envio/29-REVIEW.md
**Iteration:** 2

**Summary:**
- Findings in scope: 3 (0 Critical, 3 Warning; 4 Info out of scope for `critical_warning`)
- Fixed: 3
- Skipped: 0

All fixes were applied in an isolated git worktree
(`.claude/worktrees/rf-29-...`) and each committed atomically. The phase-29
test scope was run **inside that worktree** (with the main checkout's
`vendor/bundle`, `.bundle/config`, `config/master.key`, and `.env` linked/
copied in so bundler and ActiveRecord encryption could boot) and then
fast-forwarded onto `main`.

**Test run (worktree env):**
`POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test
test/jobs/divulgacoes/dispatch_job_test.rb
test/jobs/whatsapp/send_to_group_job_test.rb
test/services/evolution/client_test.rb
test/controllers/admin/divulgacoes_controller_test.rb`
-> **112 runs, 475 assertions, 0 failures, 0 errors, 0 skips**
(108 -> 112: 4 new regression tests added, one per gap plus the two WR-03
shapes).

## Fixed Issues

### WR-01: `limits_concurrency` fix comment documents the wrong mechanism; a nil key collapses to a single global slot

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** 3047a3c
**Applied fix:**
- (a) Rewrote the comment above `limits_concurrency` to describe the real
  solid_queue 1.4.0 behavior: a `key:` that returns nil is `.compact`ed away
  and the key collapses to the bare class string `"Whatsapp::SendToGroupJob"`,
  so `concurrency_limited?` stays `true` and every instance-less job across
  all clients would share one global `to: 1` slot. The comment no longer
  claims "não limitado / roda sem serialização".
- (b) The nil branch of the key lambda now returns a per-group unique
  sentinel `"send_to_group:no_instance:#{group.id}"` so an instance-less job
  gets its own slot instead of the shared global one. Still latent/unreachable
  today (no path destroys a `WhatsappInstance` without its `Client` and the
  `Client`'s divulgações), but the fallback is now safe if it ever becomes
  reachable.
- Added test `WR-01: sem whatsapp_instance a concurrency_key usa sentinel
  unico por grupo...` — stubs `client.whatsapp_instance` to nil and asserts
  the key contains the per-group sentinel and is not the bare class string.
- Existing `concurrency_key resolve para o whatsapp_instance_id do grupo`
  regression test still passes (instance present path unchanged).

### WR-02: `discard_on(ActiveJob::DeserializationError)` block is unreachable dead code

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** d852c5c
**Applied fix:**
- Reverted the block form to a bare `discard_on(ActiveJob::DeserializationError)`.
  The block called `job.arguments.first`, which re-raises the same
  `DeserializationError` (activejob 8.1 never clears `@serialized_arguments`
  on failure), so `finalize_divulgacao_if_done` was never reached — identical
  behavior to the bare handler it replaced.
- Added a one-line-intent comment explaining why finalize cannot and need
  not run here: `divulgacao_grupos` only cascade-delete via
  `Divulgacao#destroy` (through `Client#destroy`), which destroys the
  `Divulgacao` itself, so there is never an orphan divulgação left to
  finalize.
- Added test `WR-02: DivulgacaoGrupo apagado entre enqueue e execucao --
  job e descartado sem levantar...` — serializes a job, destroys the row,
  revives via `deserialize`, and asserts `perform_now` neither raises nor
  re-enqueues.

### WR-03: `sanitize_error_code` misses scheme-less URLs and bare presigned-query fragments

**Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`, `test/jobs/whatsapp/send_to_group_job_test.rb`
**Commit:** 8714909
**Applied fix:**
- Added two conservative `gsub` passes after the existing `URL_IN_TEXT` pass:
  - `SCHEMELESS_SIGNED_URL` — `[\w.-]+\.(amazonaws.com|cloudfront.net|
    googleapis.com|r2.cloudflarestorage.com|digitaloceanspaces.com|
    backblazeb2.com)/<path>?<query>` catches host+path+query echoed without a
    leading `https://`.
  - `SIGNED_QUERY_PARAM` — `\b(X-Amz-[A-Za-z-]+|X-Goog-[A-Za-z-]+|Signature|
    AWSAccessKeyId)=<value>` catches a loose signature fragment on its own.
  - Both redact only the matched fragment to `[url-redigida]` (the marker the
    existing test already asserts), never the whole string; truncation to
    `ERROR_CODE_MAX_LENGTH` still runs last.
- Confirmed both durable-write paths route through `sanitize_error_code`:
  `self.mark_falhou` (line ~172) and `self.mark_incerto` (line ~183). The
  `discard_on(StandardError)` catch-all only ever stores the static literal
  `"unexpected_error"`, so it is already safe.
- Added two tests: one for the scheme-less `bucket.s3.amazonaws.com/...?
  X-Amz-Signature=...` shape, one for a bare `X-Amz-Signature=...&
  X-Amz-Credential=...` fragment. Existing WR-03 (full `https://` presigned
  URL) test still passes.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-08-31_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 2_
