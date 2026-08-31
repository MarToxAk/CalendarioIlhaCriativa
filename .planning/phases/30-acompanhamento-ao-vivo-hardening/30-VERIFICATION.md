---
phase: 30-acompanhamento-ao-vivo-hardening
verified: 2026-08-31T14:24:53Z
status: human_needed
score: 3/5 must-haves verified
behavior_unverified: 2
overrides_applied: 0
behavior_unverified_items:
  - truth: "SC1 — with a Divulgação #show open, the admin sees each group's status change live, without reloading, INCLUDING when the broadcast originates from a different OS process (bin/jobs) than the one serving the browser (bin/rails server)."
    test: "Run `bin/dev` (web + jobs + css), open a Divulgação #show in a browser tab, then flip a DivulgacaoGrupo's status from a separate console/process (or let a real scheduled dispatch run) while the tab stays open."
    expected: "The group's status pill and the aggregate progress line update in place, with no page reload/navigation, driven by the solid_cable-backed ActionCable broadcast crossing from the jobs process to the web process."
    why_human: "Unit tests (test/models/divulgacao_grupo_test.rb, test/models/divulgacao_test.rb) prove the guarded after_update_commit callbacks fire and target the correct dom_id()s within a single test process — they cannot exercise real cross-process ActionCable pub/sub delivery to an actual browser tab connected to a separate `bin/rails server` process, which is the specific new risk this phase introduced (dev adapter async → solid_cable)."
  - truth: "SC5 — solid_queue_failed_executions older than the configured retention window are pruned daily, while rows inside the window survive (a selective cleanup/ordering invariant, not a whole-table clear)."
    test: "Seed a SolidQueue::FailedExecution row with created_at ~20 days ago and one with created_at ~1 day ago (each with a real parent SolidQueue::Job), then run (or wait for) the config/recurring.yml prune_solid_queue_failed_executions command in a real environment."
    expected: "The ~20-day-old FailedExecution row AND its parent SolidQueue::Job row are gone; the ~1-day-old row and its parent SURVIVE."
    why_human: "No committed automated test exercises SolidQueue::FailedExecution.where(...).discard_all_in_batches against seeded old+new rows. The 30-04 SUMMARY documents a one-time manual `eval`-inside-a-rolled-back-transaction check performed during execution, but that check is not reproducible as a regression test in the current test suite (test/lib/solid_queue_retention_test.rb only covers the ENV-parsing helper, not the discard behavior itself) — presence of the config key and a passing boot-time validation are confirmed programmatically, but the actual selective-pruning behavior is unproven by any test a verifier can re-run."
human_verification:
  - test: "SC1 (ACOMP-01): with `bin/dev` running, open a Divulgação #show, then trigger a status flip on one of its groups from a separate process (console, or a real scheduled dispatch) while the tab is open."
    expected: "The row's status pill and the aggregate progress line (_progresso_resumo) update live, no reload, no full-list re-render."
    why_human: "Cross-process ActionCable delivery to a real browser tab cannot be proven by a same-process unit test."
  - test: "SC2 (ACOMP-02): on a Divulgação #show with a falhou row, click 'Reenviar'."
    expected: "A native browser confirm dialog names the specific group; on confirm, the row flips to 'Pendente · reenfileirado' in place (no full reload); when the re-enqueued job actually runs, the row updates to its final state live. No 'Reenviar' button appears on a cancelada divulgação."
    why_human: "The functional mechanism (row reset, job re-enqueue, turbo-stream replace targets, exact confirm copy) is proven by 9 passing controller tests (test/controllers/admin/divulgacoes_controller_test.rb), but the actual native-dialog interaction and the visual in-place DOM swap require a human observing a real browser tab."
  - test: "SC5 (INFRA-07): in development with `bin/dev` running, seed a ~20-day-old and a ~1-day-old SolidQueue::FailedExecution (each with a real parent SolidQueue::Job), then run the prune_solid_queue_failed_executions recurring task."
    expected: "The ~20-day-old row and its parent job are gone; the ~1-day-old row and its parent job survive."
    why_human: "See behavior_unverified_items above — no committed regression test exercises the actual selective-discard behavior; only a one-time, non-reproduced-by-verifier manual check is documented."
---

# Phase 30: Acompanhamento ao Vivo + Hardening Verification Report

**Phase Goal:** O admin acompanha e conserta o disparo sem sair da tela — progresso ao vivo, reenvio por grupo e histórico por cliente — com o isolamento entre clientes provado por teste.
**Verified:** 2026-08-31T14:24:53Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: Com a página de uma Divulgação aberta, o admin vê o status de cada grupo mudar ao vivo, sem recarregar. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Guarded `after_update_commit` broadcasts on `DivulgacaoGrupo`/`Divulgacao` (`app/models/divulgacao_grupo.rb`, `app/models/divulgacao.rb`), granular `broadcast_replace_to` targets, single `turbo_stream_from [@client, @divulgacao]` (`show.html.erb`) — all proven by 5 passing unit tests. Cross-process delivery (bin/jobs → browser, via the new `solid_cable` dev adapter in `config/cable.yml`) is the one piece no test exercises — see behavior_unverified_items. |
| 2 | SC2: Admin reenvia para um grupo específico que falhou, com confirmação explícita, e o resultado aparece no mesmo lugar. | ✓ VERIFIED | `Admin::DivulgacoesController#resend` (scoped 2-hop `.find`, `cancelada` guard, CR-02 already-sent guard, row reset, controller-side `concluida→em_andamento` reopen, verbatim `Whatsapp::SendToGroupJob.perform_later`), `resend.turbo_stream.erb` (replaces `dom_id(@dg)` + `dom_id(@divulgacao, :progresso)`), conditional "Reenviar" `button_to` with group-named `turbo_confirm`. All exercised by real controller tests (state-transition assertions, turbo-stream target assertions, zero/one/many button coverage, cross-client 404, `cancelada` guard, CR-01/CR-02 regressions) — 67 tests green, run directly by this verifier. |
| 3 | SC3: Admin abre um cliente e vê o histórico de Divulgações com o resultado por grupo, com o nome que o grupo tinha no momento do envio. | ✓ VERIFIED | `divulgacao_placar` / `divulgacao_grupo_error_label` / `SENTINEL_ERROR_LABELS` helpers (`app/helpers/admin/divulgacoes_helper.rb`), N+1-safe (`includes(:arte, :divulgacao_grupos)` on both `#index` and `clients#show`, proven by a `sql.active_record` subscription test asserting exactly 1 `divulgacao_grupos` query), `_grupo_row` `sent_at`/`error_code` sub-lines, and the explicit SC3 frozen-name regression test (renames + deactivates the source `WhatsappGroup`, asserts the old `group_name` still renders). All run and green by this verifier. |
| 4 | SC4: A suíte de testes falha se uma arte do cliente A conseguir alcançar um grupo do cliente B. | ✓ VERIFIED | `test/integration/cross_client_isolation_test.rb` — 3 tests, run directly by this verifier (3 runs, 20 assertions, 0 failures). Two direct `assert_raises(ActiveRecord::RecordNotFound)` units target the exact scoped finders (`@client.divulgacoes.find`, the `scoped_active_groups` chain `#create` calls `.find(gids)` on) — genuinely mutation-sensitive, independent of the `arte_e_grupos_do_mesmo_cliente` model backstop. Send-path test proves a poisoned cross-client row never reaches `Evolution::Client` with client B's `remote_jid`. Token-chain belt test confirms per-instance token resolution. |
| 5 | SC5: Jobs falhados — e os argumentos que eles carregam — não se acumulam indefinidamente no banco: existe política de retenção rodando. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `config/recurring.yml` has `prune_solid_queue_failed_executions` under both `production:` and `development:`, using `SolidQueue::FailedExecution.where('created_at < ?', SolidQueueRetention.failed_execution_days.days.ago).discard_all_in_batches` (confirmed to remove the parent `solid_queue_jobs` row too, per `execution.rb:30-50`). `SolidQueueRetention.failed_execution_days` fail-fasts on an invalid ENV value (WR-01 fix), covered by 4 passing unit tests I ran (`test/lib/solid_queue_retention_test.rb`). Config-key presence confirmed live in both `development` and `production` environments by this verifier. The actual selective-discard behavior (old rows pruned, recent rows retained) has no committed regression test — see behavior_unverified_items. |

**Score:** 3/5 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/models/divulgacao_grupo.rb` — `broadcast_progresso` | Guarded `after_update_commit`, 2 `broadcast_replace_to` targets | ✓ VERIFIED | `if: -> { saved_change_to_status? }`; targets `dom_id(self)` + `dom_id(divulgacao, :progresso)` |
| `app/models/divulgacao.rb` — `broadcast_status` | Guarded `after_update_commit`, 2 `broadcast_replace_to` targets | ✓ VERIFIED | Same guard shape; targets `dom_id(self, :status_badge)` + `dom_id(self, :progresso)` |
| `app/views/admin/divulgacoes/_progresso_resumo.html.erb` | All 4 counts, zeros included | ✓ VERIFIED | `divulgacao.divulgacao_grupos.group(:status).count`, `.to_i` on each key (zero-safe) |
| `config/cable.yml` | dev adapter `solid_cable`, prod byte-identical, test untouched | ✓ VERIFIED | Confirmed by reading; `bin/setup` idempotent schema-load step present |
| `Admin::DivulgacoesController#resend` | Scoped 2-hop find, `cancelada` guard, reset, reopen, re-enqueue | ✓ VERIFIED | Lines 28-79; also carries the CR-02 already-sent guard (post-SUMMARY fix, confirmed in current code) |
| `resend_admin_client_divulgacao_divulgacao_grupo_path` route | Nested member `:resend` | ✓ VERIFIED | `config/routes.rb:27-28` |
| `app/views/admin/divulgacoes/resend.turbo_stream.erb` | 2 `turbo_stream.replace` blocks | ✓ VERIFIED | Targets `dom_id(@dg)` and `dom_id(@divulgacao, :progresso)`, matching the 30-01 broadcast targets byte-for-byte |
| `_grupo_row.html.erb` — "Reenviar" button | Conditional, group-named `turbo_confirm`, secondary style | ✓ VERIFIED | `dg.status.in?(%w[falhou incerto]) && !dg.divulgacao.status_cancelada?`; white/secondary classes, not `#EE3537` |
| `Admin::DivulgacoesHelper::SENTINEL_ERROR_LABELS` / `#divulgacao_grupo_error_label` / `#divulgacao_placar` | Copy-map, no re-sanitization; N+1-safe placar | ✓ VERIFIED | Read in full; matches spec exactly, including the WR-02-fixed comment on the singular-vs-plural contract |
| `Admin::DivulgacoesController#index` / `Admin::ClientsController#show` | `includes(:arte, :divulgacao_grupos)` | ✓ VERIFIED | Confirmed in both files |
| `test/integration/cross_client_isolation_test.rb` | Mutation-sensitive SEG-04 proof | ✓ VERIFIED | Exists, 3 tests, run green by this verifier |
| `config/recurring.yml` — `prune_solid_queue_failed_executions` | prod + dev, scope-honoring batch discard | ✓ VERIFIED (config) / ⚠️ behavior unproven | Present under both blocks; `discard_all_in_batches` applied to a `.where(...)` relation, not a bare table clear |
| `.env.example` — `SOLID_QUEUE_FAILED_RETENTION_DAYS` | Documented, default 14 | ✓ VERIFIED | `git show HEAD:.env.example` line 48 |
| `config/initializers/solid_queue_retention.rb` (post-SUMMARY, WR-01 fix) | Fail-fast boot validation | ✓ VERIFIED | Exists, `SolidQueueRetention.failed_execution_days`, 4 passing tests |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `DivulgacaoGrupo#broadcast_progresso` | `_grupo_row` / `_progresso_resumo` partials | `broadcast_replace_to` + `dom_id()` | ✓ WIRED | Targets match `show.html.erb`'s rendered `id=` attributes exactly |
| `resend.turbo_stream.erb` | 30-01 live-broadcast targets | Identical `dom_id(@dg)` / `dom_id(@divulgacao, :progresso)` | ✓ WIRED | Confirmed byte-for-byte match between the two view files |
| `_grupo_row` "Reenviar" button | `Admin::DivulgacoesController#resend` | `resend_admin_client_divulgacao_divulgacao_grupo_path(dg.divulgacao.client, dg.divulgacao, dg)` | ✓ WIRED | Resolves through the association chain, never a bare id |
| `divulgacoes#index` / `clients#show` | `divulgacao_placar` helper | `includes(:arte, :divulgacao_grupos)` preload → `group_by(&:status)` | ✓ WIRED, no N+1 | Proven by the `sql.active_record` subscription test (exactly 1 `divulgacao_grupos` query for the whole page) |
| `config/recurring.yml` command | `SolidQueueRetention.failed_execution_days` | Ruby method call inside the YAML `command:` string | ✓ WIRED | Confirmed by `test/lib/solid_queue_retention_test.rb`'s config-parsing test (`assert_includes command, "SolidQueueRetention.failed_execution_days"`) |
| `test/integration/cross_client_isolation_test.rb` | `@client.divulgacoes.find` / `scoped_active_groups` chain | Two direct `assert_raises(ActiveRecord::RecordNotFound)` | ✓ WIRED, mutation-sensitive | Confirmed by reading; a bare-`.find` downgrade of either finder breaks the suite independent of the model backstop |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `_progresso_resumo` | `counts` | `divulgacao.divulgacao_grupos.group(:status).count` | Yes | ✓ FLOWING |
| `divulgacao_placar` | `grupos` | `divulgacao.divulgacao_grupos.to_a` (preloaded via controller `includes`) | Yes | ✓ FLOWING |
| `_grupo_row` name/status/sub-lines | `dg.group_name`, `dg.error_code`, `dg.sent_at` | `DivulgacaoGrupo` row (frozen snapshot at creation, never a live `WhatsappGroup` lookup) | Yes | ✓ FLOWING |
| `resend.turbo_stream.erb` | `@dg`, `@divulgacao` | Controller-resolved via scoped `.find` chain, post-mutation | Yes | ✓ FLOWING |

### Behavioral Spot-Checks (run directly by this verifier)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ACOMP-01 broadcast guards | `bin/rails test test/models/divulgacao_grupo_test.rb test/models/divulgacao_test.rb` | 53 combined w/ helper+retention tests, 132 assertions, 0 failures | ✓ PASS |
| ACOMP-02/03 controller + N+1 | `bin/rails test test/controllers/admin/divulgacoes_controller_test.rb test/controllers/admin/clients_controller_test.rb` | 67 runs, 440 assertions, 0 failures | ✓ PASS |
| SEG-04 cross-client isolation | `bin/rails test test/integration/cross_client_isolation_test.rb` | 3 runs, 20 assertions, 0 failures | ✓ PASS |
| CR-01 residual regression (resend on still-unapproved arte) | `bin/rails test test/jobs/whatsapp/send_to_group_job_test.rb` | 35 runs, 112 assertions, 0 failures | ✓ PASS |
| INFRA-07 config key present, both environments | `RAILS_ENV=development / production bin/rails runner "...config_for(:recurring).key?(:prune_solid_queue_failed_executions)..."` | Both print `:ok` | ✓ PASS |
| INFRA-07 fail-fast retention validation | `bin/rails test test/lib/solid_queue_retention_test.rb` | 4 runs, 0 failures | ✓ PASS |
| INFRA-07 selective-discard behavior (old pruned, recent retained) | — no committed test to run — | N/A | ? SKIP (routed to human — see behavior_unverified_items) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ACOMP-01 | 30-01 | Admin acompanha o progresso do disparo ao vivo, sem recarregar | ⚠️ human_needed | Mechanism verified; cross-process delivery unproven by test |
| ACOMP-02 | 30-02 | Admin reenvia manualmente para um grupo que falhou, com confirmação explícita | ✓ SATISFIED | Controller + view + tests, all green |
| ACOMP-03 | 30-03 | Admin vê o histórico com resultado por grupo | ✓ SATISFIED | Helpers + N+1-safe includes + SC3 frozen-name test, all green |
| SEG-04 | 30-04 | Testes provam isolamento entre clientes | ✓ SATISFIED | `test/integration/cross_client_isolation_test.rb`, run and green |
| INFRA-07 | 30-04 | Política de retenção de failed_executions rodando | ⚠️ human_needed | Config + boot validation verified; selective-discard behavior unproven by test |

No orphaned requirements: all 5 phase-30 requirement IDs (ACOMP-01/02/03, SEG-04, INFRA-07) appear in exactly one plan's `requirements:` frontmatter, matching REQUIREMENTS.md's Phase 30 mapping.

### Anti-Patterns Found

None. Scanned all 17 files modified across the phase's 4 plans plus the 2 review-fix additions (`config/initializers/solid_queue_retention.rb`, `test/lib/solid_queue_retention_test.rb`) for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`/empty-implementation patterns — zero matches.

### Post-SUMMARY Changes (code review → fix → re-review, verified against current code, not SUMMARY narrative)

The 30-REVIEW.md → 30-REVIEW-FIX.md → 30-REVIEW.md (iteration 3, clean) loop applied 5 fixes on top of what the 4 plan SUMMARYs describe. Verified each is actually present in the current codebase (not just claimed):
- **CR-01 (both iterations):** `app/models/divulgacao.rb` scopes `arte_deve_estar_aprovada`, `arte_nao_usa_link_externo`, `arquivo_dentro_do_teto_whatsapp`, `arte_e_grupos_do_mesmo_cliente` to `on: :create` — confirmed present (lines 58-61); `Whatsapp::SendToGroupJob.finalize_divulgacao_if_done`'s status-only `update!` no longer risks `RecordInvalid`. Regression test in `send_to_group_job_test.rb` passes (run directly).
- **CR-02:** `#resend` now refuses a non-`falhou`/`incerto` row (`app/controllers/admin/divulgacoes_controller.rb:46-50`) — confirmed present, with its own passing controller test.
- **WR-01:** `config/initializers/solid_queue_retention.rb` fail-fasts on an invalid `SOLID_QUEUE_FAILED_RETENTION_DAYS` at boot — confirmed present, 4 passing tests.
- **WR-02:** `divulgacao_placar`'s comment corrected to document the actual plural/singular contract — confirmed present.

### Human Verification Required

#### 1. SC1 — Live cross-process progress update
**Test:** With `bin/dev` running (web + jobs + css), open a Divulgação `#show`, then flip a group's status from a separate console/process (or let a real scheduled dispatch fire) while the tab stays open.
**Expected:** The row's status pill and the aggregate progress line update live, with no page reload.
**Why human:** Cross-process ActionCable delivery (bin/jobs → browser) via the new `solid_cable` dev adapter cannot be proven by a same-process unit test.

#### 2. SC2 — Resend visual confirmation flow
**Test:** On a Divulgação `#show` with a `falhou` row, click "Reenviar".
**Expected:** A native browser confirm dialog names the group; on confirm, the row flips to "Pendente · reenfileirado" in place with no reload, then updates to its final state once the job runs. No "Reenviar" button on a `cancelada` divulgação.
**Why human:** The request/response contract is fully test-proven; the native-dialog interaction and visual DOM swap need a human observing a real browser.

#### 3. SC5 — Retention window selective pruning
**Test:** Seed a ~20-day-old and a ~1-day-old `SolidQueue::FailedExecution` (each with a real parent `SolidQueue::Job`), run the `prune_solid_queue_failed_executions` recurring task.
**Expected:** The old row and its parent job are gone; the recent row and its parent job survive.
**Why human:** No committed automated test exercises the actual selective-discard behavior; the only evidence is a one-time manual check documented in the 30-04 SUMMARY, not reproducible as a regression test.

### Gaps Summary

No gaps. All artifacts exist, are substantive, are wired, and (where testable) are covered by passing automated tests that this verifier ran directly (not merely trusted from SUMMARY.md). The phase is blocked from a clean `passed` status only by three items that the plans themselves correctly flagged as requiring human/operator observation (cross-process live delivery, native-dialog visual UX, and a real-environment retention seed-and-run) — none of these are missing functionality, they are inherently unverifiable by a same-process automated test. The regression gate's one pre-existing failure (`RackAttackTest#test_60_primeiras_requisições...`) is confirmed unrelated to any Phase 30 file (documented in `deferred-items.md`) and does not affect this verdict.

---

_Verified: 2026-08-31T14:24:53Z_
_Verifier: Claude (gsd-verifier)_
