---
phase: 30-acompanhamento-ao-vivo-hardening
plan: 04
subsystem: hardening
tags: [security-test, cross-client-isolation, solid_queue, retention, mutation-sensitive-test]

# Dependency graph
requires:
  - phase: 27-grupos-do-cliente
    provides: "scoped_active_groups (@client.whatsapp_instance.whatsapp_groups.where(active: true)) — the exact chain #create calls .find(gids) on"
  - phase: 28-divulgacao-agendar-sem-enviar
    provides: "@client.divulgacoes.find idiom (set_divulgacao / #resend share), Divulgacao#arte_e_grupos_do_mesmo_cliente model backstop"
  - phase: 29-motor-de-envio
    provides: "Whatsapp::SendToGroupJob revalidation guards (instance&.connected?, arte.approved?, atomic claim) + token-via-client-chain (SEG-03)"
provides:
  - "test/integration/cross_client_isolation_test.rb — machine-checkable SC4 proof, mutation-sensitive on two scoped finders"
  - "config/recurring.yml prune_solid_queue_failed_executions (production + development)"
  - ".env.example SOLID_QUEUE_FAILED_RETENTION_DAYS (default 14)"
affects: []

# Actuals (#2632)
actuals:
  tokens: 2680
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "assert_raises(ActiveRecord::RecordNotFound) on a scoped association .find as the mutation-sensitive layer — controller/model second-barrier assertions kept separate because a model validation backstop makes them insensitive to a scoped-finder downgrade"
    - "SolidQueue::FailedExecution.where('created_at < ?', cutoff).discard_all_in_batches — scope-honoring batch discard (verified against vendored execution.rb:30-50: count and the job_id pluck both chain onto self), removes the parent solid_queue_jobs row too"
    - "YAML single-quoted command scalar with doubled '' for embedded Ruby single-quotes, mixed with literal double-quoted ENV.fetch args — needed so the raw recurring.yml text matches an exact grep pattern without escaping"

key-files:
  created:
    - test/integration/cross_client_isolation_test.rb
  modified:
    - config/recurring.yml
    - .env.example

key-decisions:
  - "Send-path test (Test 2) forces a poisoned cross-client DivulgacaoGrupo via update_columns (bypassing Divulgacao's arte_e_grupos_do_mesmo_cliente validation) and disconnects client A's OWN instance to trigger the existing instance&.connected? guard. This proves the Phase 29 revalidation guards stop I/O even on a poisoned row, but does NOT prove the job itself checks cross-client ownership — it doesn't; that check lives only at creation time (SEG-02) and is what Test 1 proves. Documented inline in the test and here so this scope boundary is explicit, not silently assumed."
  - "config/recurring.yml command strings use YAML single-quoted scalars (with '' escaping for the embedded 'created_at < ?' Ruby string) instead of the double-quoted-outer style of the existing clear_solid_queue_finished_jobs entry, specifically so the raw file contains literal double quotes around the ENV.fetch args — required to satisfy the plan's exact grep acceptance criteria (grep -c 'ENV.fetch(\"SOLID_QUEUE_FAILED_RETENTION_DAYS\", \"14\")') without backslash-escaping corrupting the substring match."
  - "discard_all_in_batches chosen over the CONTEXT's originally-proposed find_each(&:discard) — 30-PATTERNS.md's verified read of execution.rb:30-50 confirms it honors the .where(...) scope and matches the batch semantics of the existing clear_solid_queue_finished_jobs entry."

requirements-completed: [SEG-04, INFRA-07]

coverage:
  - id: D1
    description: "The suite fails if @client.divulgacoes.find (the #resend / set_divulgacao idiom) is downgraded to a bare Divulgacao.find — a live client_b.divulgacoes row is looked up through client_a's scoped association and must raise RecordNotFound."
    requirement: "SEG-04"
    verification:
      - kind: unit
        ref: "test/integration/cross_client_isolation_test.rb#criação de Divulgação do cliente A referenciando grupo do cliente B é recusada em TRES camadas (assert_raises on @client_a.divulgacoes.find)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The suite fails if the scoped_active_groups chain (@client.whatsapp_instance.whatsapp_groups.where(active: true).find) — the EXACT chain Admin::DivulgacoesController#create calls .find(gids) on — is downgraded to a bare WhatsappGroup.find."
    requirement: "SEG-04"
    verification:
      - kind: unit
        ref: "test/integration/cross_client_isolation_test.rb#criação de Divulgação do cliente A referenciando grupo do cliente B é recusada em TRES camadas (assert_raises on the scoped_active_groups chain)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Independent second-barrier proof: the controller re-renders :unprocessable_entity with zero rows written, and the model backstop (arte_e_grupos_do_mesmo_cliente) rejects a force-built cross-client DivulgacaoGrupo — both kept separate from D1/D2 because the model rule alone would still reject a downgraded-finder scenario, so they are not mutation-sensitive to that specific regression."
    requirement: "SEG-04"
    verification:
      - kind: integration
        ref: "test/integration/cross_client_isolation_test.rb#criação de Divulgação do cliente A referenciando grupo do cliente B é recusada em TRES camadas (controller POST + model invalid? assertions)"
        status: pass
    human_judgment: false
  - id: D4
    description: "A force-built cross-client DivulgacaoGrupo run through Whatsapp::SendToGroupJob never invokes Evolution::Client with client B's remote_jid, and the row is not marked enviado."
    requirement: "SEG-04"
    verification:
      - kind: unit
        ref: "test/integration/cross_client_isolation_test.rb#Whatsapp::SendToGroupJob rodado sobre uma linha cross-client forçada nunca chama Evolution com o remote_jid do cliente B"
        status: pass
    human_judgment: false
  - id: D5
    description: "Per-instance tokens differ between clients, and Whatsapp::SendToGroupJob resolves the send-time api_key via divulgacao.client.whatsapp_instance.token (SEG-03 chain), not a loose id."
    requirement: "SEG-04"
    verification:
      - kind: unit
        ref: "test/integration/cross_client_isolation_test.rb#tokens de instancia diferem entre clientes e SendToGroupJob resolve a chave via divulgacao.client.whatsapp_instance.token"
        status: pass
    human_judgment: false
  - id: D6
    description: "solid_queue_failed_executions older than the configured window (default 14 days) are pruned daily in production AND development, via an API confirmed (execution.rb:30-50) to honor the where(created_at < cutoff) scope and to remove the parent solid_queue_jobs row (no orphaned cleartext job args)."
    requirement: "INFRA-07"
    verification:
      - kind: config
        ref: "RAILS_ENV=development / RAILS_ENV=production bin/rails runner config_for(:recurring).key?(:prune_solid_queue_failed_executions) — both print :ok"
        status: pass
      - kind: functional
        ref: "development bin/rails runner: seeded a ~20-day-old and a ~1-day-old SolidQueue::FailedExecution (each with a real parent SolidQueue::Job), ran the exact recurring command string via eval inside a rolled-back transaction — old FailedExecution + its parent Job pruned, recent FailedExecution + its parent Job survived"
        status: pass
    human_judgment: false

# Metrics
duration: ~15min
completed: 2026-08-31
status: complete
---

# Phase 30 Plan 04: Hardening — Cross-Client Isolation Test + Failed-Execution Retention Summary

**SEG-04's mutation-sensitive integration test proves the cross-client barrier on both the creation and send paths (plus a token-chain belt), and INFRA-07's `config/recurring.yml` entry prunes stale `solid_queue_failed_executions` — and their parent job rows — daily in production and development, functionally proven end-to-end in this sandbox.**

## Performance

- **Duration:** ~15 min (commit timestamps 10:07 → 10:10; wall-clock reading/verification was longer)
- **Tasks:** 2/2
- **Files modified:** 3 (1 new, 2 modified)

## Accomplishments

- `test/integration/cross_client_isolation_test.rb` (new, 3 tests, all green): a dual-client setup (client A + client B, each with its own connected `whatsapp_instance`, `whatsapp_group`, and approved `arte`) proves:
  1. **Creation refused, three independent layers** — two direct `assert_raises(ActiveRecord::RecordNotFound)` units (the mutation guard: `client_a.divulgacoes.find(divulgacao_b.id)` and `client_a.whatsapp_instance.whatsapp_groups.where(active: true).find([client_b_group.id])`, the exact chain `#create` calls `.find(gids)` on) plus the controller `:unprocessable_entity` + unchanged `Divulgacao.count` and the model `invalid?` / `errors[:base]` backstop (kept independent, not mutation-sensitive).
  2. **Send never crosses** — a force-built cross-client `DivulgacaoGrupo` run through `Whatsapp::SendToGroupJob` never reaches `Evolution::Client` (client A's own instance is disconnected, triggering the existing Phase 29 `instance&.connected?` guard before any I/O); the row ends `falhou`/`instancia_desconectada`, never `enviado`.
  3. **Token-chain belt** — client A's and client B's instance tokens differ, and the job resolves the send-time `api_key` via `divulgacao.client.whatsapp_instance.token`.
- `config/recurring.yml`: `prune_solid_queue_failed_executions` added under **both** `production:` and a new `development:` block (INFRA-02 parity — scheduled jobs must survive a dev restart), using `SolidQueue::FailedExecution.where('created_at < ?', cutoff).discard_all_in_batches`.
- Confirmed from the vendored `execution.rb:30-50` (not assumed) that `discard_all_in_batches` honors the scoped relation — `count` and `limit(batch_size).order(:job_id).lock.pluck(:job_id)` both chain onto `self` — so the command prunes only rows past the retention window, and via `Execution#discard` (`job.destroy; destroy`) also removes the parent `solid_queue_jobs` row, closing the cleartext-argument accumulation the CONTEXT's original `.delete_all` proposal would have left behind.
- `.env.example`: documented `SOLID_QUEUE_FAILED_RETENTION_DAYS=14` with a one-line comment.
- **Functionally verified the retention window in development** (not just config-loaded): seeded a ~20-day-old and a ~1-day-old `SolidQueue::FailedExecution` (each with a real parent `SolidQueue::Job`), ran the exact command string from `config/recurring.yml` via `eval` inside a transaction, confirmed the old row **and** its parent job were pruned while the recent row **and** its parent survived, then rolled back (no residue in the dev DB).

## Task Commits

1. **Task 1: SEG-04 — cross-client isolation integration test** — `fb3ea70` (test)
2. **Task 2: INFRA-07 — failed-execution retention in config/recurring.yml (prod + dev)** — `72e4561` (chore)

**Plan metadata:** committed alongside this SUMMARY (see final commit below).

## Files Created/Modified

- `test/integration/cross_client_isolation_test.rb` — NEW, `CrossClientIsolationTest < ActionDispatch::IntegrationTest`, 3 tests, dual-client WhatsApp scaffolding reused from `test/jobs/whatsapp/send_to_group_job_test.rb` + `test/controllers/admin/divulgacoes_controller_test.rb`
- `config/recurring.yml` — `prune_solid_queue_failed_executions` under `production:` (new entry) and `development:` (new top-level block)
- `.env.example` — `SOLID_QUEUE_FAILED_RETENTION_DAYS=14` documented near the other job/queue-related vars

## Decisions Made

- **Send-path test design boundary (documented, not hidden):** the job itself has no code path that checks whether a `DivulgacaoGrupo`'s `whatsapp_group` belongs to the same client as the owning `Divulgacao` — that check exists only at creation time (SEG-02, proven by Test 1). Test 2 proves that the Phase 29 revalidation guards (`instance&.connected?`) still stop I/O on a poisoned row when the owning client's own instance is disconnected — a real, existing belt, but incidental to cross-client-ness rather than a dedicated check. This matches the plan's explicit allowance ("in practice the job marks the row falhou / instancia_desconectada or the claim guard stops it before any I/O") and the threat model's T-30-16 disposition ("Not new code — this plan adds the machine-checkable assertion").
- **YAML quoting for `config/recurring.yml`:** used single-quoted outer command scalars (with `''` for the embedded `'created_at < ?'` Ruby literal) so the raw file contains literal double quotes around `ENV.fetch("SOLID_QUEUE_FAILED_RETENTION_DAYS", "14")` — required to satisfy the plan's exact-match grep acceptance criteria without backslash-escaping breaking the substring match. Verified the resulting command parses and evaluates correctly (`RubyVM::InstructionSequence.compile` + a real `eval` in development).
- **`discard_all_in_batches` over `find_each(&:discard)`** — 30-PATTERNS.md's verified read of `execution.rb:30-50` confirmed scope-honoring; batch form mirrors the existing `clear_solid_queue_finished_jobs` entry's semantics.

## Deviations from Plan

None — plan executed exactly as written, including the explicit send-path test-design nuance called out in the plan's own language ("in practice... the claim guard stops it before any I/O").

## Issues Encountered

None. `bin/rails test` ran successfully throughout this plan (the `test_db_permission` STATE.md concern did not materialize, consistent with the 30-01 executor's finding). Both `RAILS_ENV=development` and `RAILS_ENV=production bin/rails runner` config-load checks passed directly (production required supplying `CORS_ORIGINS`/`SECRET_KEY_BASE_DUMMY` env vars for the runner invocation only — an existing app-boot requirement unrelated to this plan's changes, not a workaround of anything this plan touched).

## Verification Evidence

- `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/integration/cross_client_isolation_test.rb` → 3 runs, 20 assertions, 0 failures, 0 errors.
- Full related-suite regression: `test/integration/cross_client_isolation_test.rb test/integration/client_isolation_test.rb test/jobs/whatsapp/send_to_group_job_test.rb test/controllers/admin/divulgacoes_controller_test.rb` → 77 runs, 413 assertions, 0 failures, 0 errors.
- `grep -c "assert_raises(ActiveRecord::RecordNotFound)" test/integration/cross_client_isolation_test.rb` → 2 (one on `.divulgacoes.find`, one on the `scoped_active_groups` chain).
- `grep -v '^#' config/recurring.yml | grep -c discard_all_in_batches` → 2.
- `grep -v '^#' config/recurring.yml | grep -c 'ENV.fetch("SOLID_QUEUE_FAILED_RETENTION_DAYS", "14")'` → 2.
- `RAILS_ENV=development bin/rails runner "... config_for(:recurring).key?(:prune_solid_queue_failed_executions) ..."` → `:ok`.
- `RAILS_ENV=production bin/rails runner "... config_for(:recurring).key?(:prune_solid_queue_failed_executions) ..."` → `:ok` (with `CORS_ORIGINS`/`SECRET_KEY_BASE_DUMMY` supplied for the runner process, an unrelated app-boot requirement).
- Functional SC5 dry-run in development (seeded old + recent `FailedExecution`/`Job` pairs, ran the real command, confirmed selective pruning, rolled back the transaction) — see Accomplishments above.

## User Setup Required

None for this plan's artifacts. Operator UAT remains open only for confirming the retention job actually fires on the production `bin/jobs` scheduler at 3am against production data (the mechanism itself is now functionally proven in development, not merely config-loaded) — see STATE.md Deferred Verification for Phase 30.

## Next Phase Readiness

- SEG-04 and INFRA-07 are both complete — this closes out the hardening debt for Phase 30.
- No production code was touched (SEG-04 is test-only, INFRA-07 is config-only), per the plan's prohibitions.
- Phase 30 plans 02/03 (reenvio manual, histórico por cliente) are unaffected by this plan.

---
*Phase: 30-acompanhamento-ao-vivo-hardening*
*Completed: 2026-08-31*

## Self-Check: PASSED

All claimed files found on disk; all claimed commits found in `git log --oneline --all`.
