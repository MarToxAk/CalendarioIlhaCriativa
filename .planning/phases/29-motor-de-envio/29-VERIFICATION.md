---
phase: 29-motor-de-envio
verified: 2026-08-31T00:00:00Z
status: human_needed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
human_verification:
  - test: "Real send round-trip against a live paired Evolution instance + a disposable test group: schedule a Divulgação with (a) an approved image arte with a caption and (b) an approved caption_only arte, let the DispatchJob fire."
    expected: "The image arrives in the group as media WITH the caption (sendMedia), the caption_only arte arrives as a plain text message (sendText). Evolution actually downloads the presigned media URL within its TTL. divulgacao_grupos rows record status=enviado + a non-empty evolution_message_id + sent_at set only after the HTTP 2xx."
    why_human: "The Evolution write-path (POST /message/sendText, /message/sendMedia) is documented as operator UAT — .planning/notes/evolution-contract.md marks it PENDING. No live paired instance is reachable in this environment. Success response shape (key.id vs id) and the free-text 4xx error body are assumptions the code is built to tolerate but that only a real send confirms."
  - test: "Confirm the intended cancellation scope with the product owner: once a Divulgação's scheduled time has passed and DispatchJob has flipped it to em_andamento, the admin cancel button returns 'Só é possível cancelar uma divulgação ainda agendada' and the remaining staggered sends proceed."
    expected: "This is the intended v1.7 behaviour (DIVU-08 is scoped to 'Divulgação agendada'; cancelling an in-flight dispatch is explicitly deferred to phase 30 UI work per 29-03-PLAN.md). The SendToGroupJob-level `return if divulgacao.status_cancelada?` guard is present and tested as defense-in-depth for when phase 30 exposes in-flight cancel."
    why_human: "Roadmap Phase 29 Success Criterion 5 is worded 'Cancelar uma Divulgação em andamento impede os grupos ainda não atendidos de receber' — broader than the DIVU-08 requirement text ('agendada'). The job guards support it, but no code path sets status=cancelada once em_andamento. Needs a human decision on whether SC5's wording requires a follow-up in phase 30 or whether DIVU-08's 'agendada' scope governs."
---

# Phase 29: Motor de Envio Verification Report

**Phase Goal:** Na hora agendada, cada grupo selecionado recebe a arte exatamente uma vez, com intervalo aleatório entre grupos, respeitando aprovação, conexão e cancelamento.
**Verified:** 2026-08-31
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Na hora agendada os grupos recebem a arte um a um, com intervalo aleatório vindo de env var, e o app continua processando outros jobs durante toda a espera | ✓ VERIFIED | `Admin::DivulgacoesController#create:64` enqueues `Divulgacoes::DispatchJob.set(wait_until: @divulgacao.scheduled_for)`. `dispatch_job.rb:20-24` loops pending groups, enqueues `Whatsapp::SendToGroupJob.set(wait: offset.seconds)`, `offset += rand(Divulgacao::SEND_DELAY_MIN..SEND_DELAY_MAX)`. `SEND_DELAY_MIN/MAX` read from `WHATSAPP_SEND_DELAY_MIN/MAX_SECONDS` env (`divulgacao.rb:17-18`). No `sleep` anywhere — waiting jobs sit in solid_queue scheduled executions, not threads. Dedicated `whatsapp_sends` worker + `"*"` worker both present (`config/queue.yml`, runner confirms `["*", "whatsapp_sends"]`). Tests: "offsets crescentes dentro da faixa ENV, primeiro grupo com offset 0", "enfileira N jobs rapidamente sem sleep" pass. |
| 2 | Nenhum grupo recebe a mesma Divulgação duas vezes (retry, worker morto, deploy); timeout de leitura vira `incerto` e nunca re-tentado sozinho | ✓ VERIFIED | Atomic claim `DivulgacaoGrupo.where(id:, status: :pendente).update_all(status: :enviado)` precedes any Evolution call; `return if claimed.zero?` (`send_to_group_job.rb:135-137`). Tested adversarially: double `perform_now` → Evolution called once; double `perform_later` + drain → once; pre-set terminal status → `claimed == 0`. `Evolution::Errors::Unknown` (read timeout) → `discard_on` → `mark_incerto`, never re-enqueued (`send_to_group_job.rb:95`; test "discard_on Unknown grava incerto sem reenfileirar"). `Transient` rescue reverts the claim to `:pendente` before re-raising so `retry_on` actually re-sends (test "retry_on Transient desfaz o claim ... nova tentativa realmente tenta enviar"). Worker-death mid-HTTP residual window is documented + accepted in 29-RESEARCH ("Janela residual"), remedy deferred to phase 30 manual resend. |
| 3 | Aprovação retirada após agendamento, ou instância desconectada no instante do envio → grupo não recebe nada, registra o motivo, nunca `enviado` | ✓ VERIFIED | Inside `perform`, after the claim: `arte = divulgacao.arte.reload; unless arte.approved? → group.update!(status: :falhou, error_code: "arte_nao_aprovada")` (`send_to_group_job.rb:139-144`, ENVIO-06). Then `instance = divulgacao.client.whatsapp_instance; unless instance&.connected? → status: :falhou, error_code: "instancia_desconectada"` (`:146-151`, ENVIO-07). Both revalidated fresh in the job, not once in DispatchJob. CR-01 fix: `sent_at` is written ONLY in `send_via_evolution` after Evolution confirms — a row that fails revalidation carries `sent_at: nil`. Tests: "arte nao aprovada nunca chama Evolution", "instancia desconectada nunca chama Evolution", plus `assert_nil sent_at` on every failure path. |
| 4 | Arte com legenda → mídia com legenda; arte só de texto → mensagem de texto; mídia baixável pelo Evolution do começo ao fim | ✓ VERIFIED (delivery pending UAT) | `send_via_evolution` (`send_to_group_job.rb:236-242`): `if arte.caption_only? → Evolution::Client.send_text(text: arte.caption)` else `send_media(mediatype: arte.media_type, media: media_url, caption: arte.caption.presence)`. `media_url = arte.media_file.url(expires_in: MEDIA_URL_TTL)` with `MEDIA_URL_TTL = 5.minutes`, generated per-send inside `perform`, never in DispatchJob (ENVIO-08). Presigned URL reachability from the public Evolution host was proven in phase 25 (INFRA-01/SC1). Tests cover both send_text and send_media paths. **Actual media download by Evolution requires live UAT — see Human Verification.** |
| 5 | Cancelar Divulgação em andamento impede grupos ainda não atendidos; dois envios do mesmo número nunca em paralelo | ✓ VERIFIED (scope note — see Human Verification) | `return if divulgacao.status_cancelada?` is the first useful line of both `DispatchJob#perform` (`:16`) and `SendToGroupJob#perform` (`:125`), before the atomic claim. A cancelled item stays `:pendente`, never `:falhou` (DIVU-08). Tests: "cancelamento mid-dispatch vira no-op, Evolution nunca chamado", "grupo já enviado antes do cancel permanece enviado; os não-rodados viram no-op". `limits_concurrency to: 1, key: ->(group){ group.divulgacao.client.whatsapp_instance&.id \|\| sentinel }` serializes per instance (ENVIO-09); runner confirms `concurrency_limit == 1`, `on_conflict` default `:block`. Note: `Divulgacao#cancelar!` only flips from `agendada`; cancelling an already-`em_andamento` dispatch via the UI is explicitly deferred (29-03-PLAN.md) — the job guards are defense-in-depth for that phase-30 work. DIVU-08 as written ("agendada") is satisfied. |

**Score:** 5/5 roadmap success criteria verified in code and by 112 passing tests. 2 items routed to human verification (live Evolution write-path UAT; roadmap SC5 vs DIVU-08 cancellation-scope confirmation).

### Plan Must-Have Truths (16 total across 29-01/02/03)

All 16 plan-frontmatter truths map to verified code + passing tests:

| Plan | Truths verified | Evidence |
|------|-----------------|----------|
| 29-01 | 5/5 | DispatchJob via `wait_until:` not periodic scan; claim-before-HTTP + in-perform revalidation of `arte.approved?`/`instance.connected?`; `caption_only? → send_text` else `send_media` with media URL generated in `perform`; token always via `divulgacao.client.whatsapp_instance.token`; success writes `enviado`/`sent_at`/`evolution_message_id` |
| 29-02 | 6/6 | Double `perform_now` → 0 rows claimed on 2nd, no Evolution call; `Unknown` → `incerto`, no retry; `Transient` → revert claim then re-raise so retry actually re-sends; `Permanent`/`NotConnected`/`ConfigurationError`/`StandardError` → `falhou` with `error_code` truncated ≤500 + URL redaction; `limits_concurrency` key resolves to real `WhatsappInstance#id` (no `NoMethodError`); `discard_on(StandardError)` declared first, never steals `Transient` from `retry_on` |
| 29-03 | 5/5 | Accumulating random offset from env bounds, no `sleep`; cancel-before-dispatch → no enqueue, stays `cancelada`; cancel-after-enqueue → `SendToGroupJob` no-op, item stays `pendente`; `agendada → em_andamento → concluida` transition on last pending item leaving (success/falhou/incerto); `config/queue.yml` adds dedicated `whatsapp_sends` worker alongside `"*"` |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/jobs/divulgacoes/dispatch_job.rb` | Scheduled dispatch, staggered enqueue | ✓ VERIFIED | 26 lines; wired from controller#create; enqueues SendToGroupJob |
| `app/jobs/whatsapp/send_to_group_job.rb` | Atomic claim, revalidation, send, error taxonomy, concurrency | ✓ VERIFIED | 258 lines; full `perform` + 7 `discard_on`/`retry_on` handlers + `limits_concurrency` + class helpers |
| `app/services/evolution/client.rb` | `send_text` / `send_media` | ✓ VERIFIED | Both added in `class << self` (`:142`, `:157`); WR-07 non-Hash guard; error classification 100% by HTTP status via existing `raise_for_status!` |
| `config/queue.yml` | Dedicated `whatsapp_sends` worker | ✓ VERIFIED | Second worker `{ queues: whatsapp_sends, threads: 2 }` in `default: &default`; `"*"` worker untouched; runner shows `["*", "whatsapp_sends"]` |
| `app/controllers/admin/divulgacoes_controller.rb` | Enqueue DispatchJob on save | ✓ VERIFIED | `:64` inside `if @divulgacao.save`, before `redirect_to` |
| `test/jobs/divulgacoes/dispatch_job_test.rb` | Scheduling/stagger/status tests | ✓ VERIFIED | 125 lines, 7 tests |
| `test/jobs/whatsapp/send_to_group_job_test.rb` | Happy path, taxonomy, idempotency, cancellation | ✓ VERIFIED | 477 lines, 34 tests |
| `test/services/evolution/client_test.rb` | send_text/send_media contract | ✓ VERIFIED | 470 lines, 33 tests (incl. 5 send-path tests) |
| `test/controllers/admin/divulgacoes_controller_test.rb` | Enqueue-on-create test | ✓ VERIFIED | 654 lines |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `Admin::DivulgacoesController#create` | `Divulgacoes::DispatchJob` | `.set(wait_until: scheduled_for).perform_later` on save success | ✓ WIRED (`:64`) |
| `Divulgacoes::DispatchJob#perform` | `Whatsapp::SendToGroupJob` | `.set(wait: offset.seconds).perform_later(group)` in pending-groups loop | ✓ WIRED (`dispatch_job.rb:22`) |
| `Whatsapp::SendToGroupJob#send_via_evolution` | `Evolution::Client.send_text/send_media` | `api_key: instance.token` where `instance = divulgacao.client.whatsapp_instance` | ✓ WIRED (`send_to_group_job.rb:234-241`) |
| `limits_concurrency` key | `WhatsappInstance#id` | `group.divulgacao.client.whatsapp_instance&.id` — same chain as SEG-03 token | ✓ WIRED (`:57-61`); runner confirms `concurrency_limit == 1` |
| `DispatchJob#perform` offset loop | `Divulgacao::SEND_DELAY_MIN/MAX` | `rand(MIN..MAX)`, env-driven | ✓ WIRED (`dispatch_job.rb:23`, `divulgacao.rb:17-18`) |
| `SendToGroupJob` / `DispatchJob` `queue_as` | `config/queue.yml` `whatsapp_sends` worker | `queue_as :whatsapp_sends` | ✓ WIRED (runner: both jobs `queue_name == "whatsapp_sends"`) |

### Data-Flow Trace (Level 4)

| Value | Source | Real data | Status |
|-------|--------|-----------|--------|
| `evolution_message_id` | `resp["key"]["id"] \|\| resp["id"]` from live Evolution POST response | Yes (from HTTP response; shape tolerant) | ✓ FLOWING (shape pending UAT) |
| `sent_at` | `Time.current` written only in `send_via_evolution` after 2xx | Yes | ✓ FLOWING |
| `media_url` | `arte.media_file.url(expires_in: 5.minutes)` — ActiveStorage presigned S3/MinIO | Yes (phase 25 proved outside-LAN reachability) | ✓ FLOWING |
| `error_code` | `Evolution::Client` normalized `err.message`, URL-redacted, truncated ≤500 | Yes | ✓ FLOWING |
| `status` transitions | `update_all` claim + `finalize_divulgacao_if_done` | Yes (DB-backed) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Both jobs on dedicated queue | `bin/rails runner 'p ...queue_name'` | `"whatsapp_sends"` x2 | ✓ PASS |
| Evolution write methods exist | `bin/rails runner 'p Evolution::Client.respond_to?(:send_text/:send_media)'` | `true` x2 | ✓ PASS |
| Concurrency limit configured | `bin/rails runner 'p Whatsapp::SendToGroupJob.concurrency_limit'` | `1` | ✓ PASS |
| queue.yml has both workers | `bin/rails runner 'p config_for(:queue)[:workers].map{...}'` | `["*", "whatsapp_sends"]` | ✓ PASS |
| Full phase-29 test scope | `bin/rails test <4 phase-29 files>` | 112 runs, 475 assertions, 0 failures, 0 errors | ✓ PASS |

### Probe Execution

No project probes declared for this phase (not a migration/tooling phase). Step 7c: N/A.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ENVIO-01 | 29-01 | Envio na hora agendada com intervalo aleatório entre grupos | ✓ SATISFIED | `DispatchJob.set(wait_until:)` in controller; staggered enqueue loop |
| ENVIO-02 | 29-03 | Faixa min/max do intervalo vem de env var, não UI/DB | ✓ SATISFIED | `SEND_DELAY_MIN/MAX = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN/MAX_SECONDS", ...))` |
| ENVIO-03 | 29-03 | Disparo longo não ocupa capacidade de background durante a espera | ✓ SATISFIED | No `sleep`; `wait:` offsets → jobs in scheduled_executions; dedicated worker |
| ENVIO-04 | 29-02 | Grupo nunca recebe a mesma Divulgação duas vezes (retry/worker morto/deploy) | ✓ SATISFIED | Atomic conditional `update_all` claim before any HTTP; proven under 4 adversarial scenarios |
| ENVIO-05 | 29-02 | Timeout de leitura → resultado incerto, nunca re-tentado sozinho | ✓ SATISFIED | `discard_on(Evolution::Errors::Unknown) → mark_incerto`; `classify_timeout` maps `Net::ReadTimeout → Unknown` |
| ENVIO-06 | 29-01 | Aprovação da arte revalidada no momento do envio | ✓ SATISFIED | `arte = divulgacao.arte.reload; unless arte.approved? → falhou/arte_nao_aprovada` inside `perform` |
| ENVIO-07 | 29-01 | Estado da conexão verificado imediatamente antes de cada envio | ✓ SATISFIED | `instance&.connected?` check inside `perform` after claim, before Evolution call |
| ENVIO-08 | 29-01 | URL da mídia gerada no momento do envio, validade suficiente | ✓ SATISFIED | `arte.media_file.url(expires_in: MEDIA_URL_TTL=5.minutes)` inside `send_via_evolution`, never in DispatchJob |
| ENVIO-09 | 29-02 | Envios da mesma instância serializados, nunca em paralelo | ✓ SATISFIED | `limits_concurrency to: 1, key: whatsapp_instance.id`; `on_conflict: :block` (gem default) |
| ENVIO-10 | 29-01 | Arte com legenda → mídia com legenda; arte só de texto → mensagem de texto | ✓ SATISFIED | `arte.caption_only? ? send_text : send_media(caption: arte.caption.presence)` |
| DIVU-08 | 29-03 | Admin cancela Divulgação agendada, cancelamento respeitado pelos envios não realizados | ✓ SATISFIED | `return if divulgacao.status_cancelada?` in both `DispatchJob#perform` and `SendToGroupJob#perform`; cancelled item stays `:pendente`. (Cancel while `em_andamento` deferred — see Human Verification #2) |
| SEG-03 | 29-01 | Envio usa o token da instância daquele cliente | ✓ SATISFIED | `api_key = instance.token` where `instance = divulgacao.client.whatsapp_instance` — single resolution chain, also used by concurrency key |
| INFRA-06 | 29-03 | Disparos rodam em fila dedicada, sem atrasar broadcasts do v1.5 | ✓ SATISFIED | `config/queue.yml` adds `{ queues: whatsapp_sends, threads: 2 }` alongside `"*"`; ActionCable broadcasts are synchronous today (29-RESEARCH) so no current contention |

No orphaned requirements — all 13 IDs in REQUIREMENTS.md (line 203: "ENVIO-01..10, DIVU-08, SEG-03, INFRA-06 | 13") are claimed by a phase-29 plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | Two `grep` hits for "TODO" in `send_to_group_job.rb` (`:13` "méTODO", `:48` "TODO job" = Portuguese "every job") | ℹ️ Info | False positives — no debt markers. No `FIXME`/`XXX`/`TBD`/`HACK`/`PLACEHOLDER` in any modified file. |

Code review history: 29-REVIEW (iter 1) — 1 Critical (`sent_at` on failed sends, CR-01) + 5 Warnings all fixed; 29-REVIEW.iter2 — 3 Warnings all fixed, 4 Info deferred (IN-01 enqueue-failure-after-save reconciliation gap — comparable to accepted RESEARCH "Janela residual"; IN-02 `SEND_DELAY_MIN=0` config footgun). Both Info items are non-blocking config/operational notes.

### Human Verification Required

**1. Live Evolution write-path round-trip (sendText + sendMedia)**
- **Test:** Against a live paired Evolution instance + disposable test group, schedule a Divulgação with an approved image arte (with caption) and a separate caption_only arte; let DispatchJob fire.
- **Expected:** Image arrives as media WITH caption; caption_only arrives as plain text; Evolution downloads the presigned media URL within the 5-min TTL; rows record `enviado` + non-empty `evolution_message_id` + `sent_at` only after the 2xx.
- **Why human:** Evolution write-path is documented operator UAT (`.planning/notes/evolution-contract.md`, PENDING); no live instance reachable here. Success response shape and 4xx error text are tolerated-but-unconfirmed assumptions.

**2. Cancellation scope confirmation (roadmap SC5 vs DIVU-08)**
- **Test:** After a Divulgação's scheduled time passes and DispatchJob flips it to `em_andamento`, click the admin cancel button.
- **Expected:** Returns "Só é possível cancelar uma divulgação ainda agendada"; remaining staggered sends proceed. This is the intended v1.7 behaviour per 29-03-PLAN.md (in-flight cancel deferred to phase 30 UI).
- **Why human:** Roadmap Phase 29 SC5 says "Cancelar uma Divulgação **em andamento**" — broader than DIVU-08's "**agendada**". The `SendToGroupJob` cancel guard supports in-flight cancel but nothing sets `status: cancelada` once `em_andamento`. Needs a decision: does SC5's wording require a phase-30 follow-up, or does DIVU-08's "agendada" scope govern the milestone contract?

### Gaps Summary

No blocking gaps. All 13 requirements are satisfied in code and proven by 112 passing tests (0 failures). The atomic-claim-before-HTTP ordering, the full `Evolution::Errors` taxonomy, per-instance serialization, in-perform revalidation of approval and connection, the CR-01 `sent_at`-only-on-confirmation invariant, and the dedicated queue are all present and behaviorally tested. Two items require human sign-off: the live Evolution send/media-download UAT (inherent to an external integration with a PENDING write-path contract), and confirmation that cancelling an already-in-flight dispatch is intentionally out of scope for phase 29 (aligned with DIVU-08's "agendada" wording).

Regression: per verifier notes, phases 25-28 test files pass 130/131; the single failure (`rack_attack_test.rb` AI-namespace throttle) is pre-existing and unrelated, already documented in phase 27/28 verification. Not a phase-29 regression.

---

_Verified: 2026-08-31_
_Verifier: Claude (gsd-verifier)_
