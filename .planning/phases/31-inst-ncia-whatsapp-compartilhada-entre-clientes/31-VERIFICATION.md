---
phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes
verified: 2026-08-31T22:00:00Z
status: human_needed
score: 13/13 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "No painel WhatsApp (admin/clients#show) de um cliente sem instância, clicar entre os rótulos 'Novo número (QR)' e 'Reutilizar conexão existente' (radios sr-only via Stimulus whatsapp-provision-toggle)."
    expected: "O pill clicado assume a classe ativa (borda/fundo/texto verde #0F7949), o outro volta ao estilo inativo (borda cinza); o campo correspondente (botão 'Criar instância' vs formulário de seleção de conexão) aparece/some; o botão 'Reutilizar conexão' começa desabilitado e só habilita depois de escolher uma opção no <select>; ao submeter 'Reutilizar', o turbo_confirm com o aviso pt-BR de blast-radius aparece antes do POST."
    why_human: "Comportamento de clique/estado do Stimulus controller (classList toggling, disabled-until-selected, diálogo turbo_confirm) só é observável rodando JS real no browser — não é exercitado por testes de controller Rails (sem driver JS no ambiente de teste desta fase, 31-RESEARCH.md Pitfall 7); o próprio SUMMARY.md da 31-01 marca este item como human_judgment explicitamente."
---

# Phase 31: Instância WhatsApp Compartilhada entre Clientes Verification Report

**Phase Goal:** Permitir que uma instância Evolution já conectada (um número de WhatsApp da
agência) seja reutilizada para atender múltiplos clientes, sem exigir o pareamento de um número
novo por cliente, redesenhando o limite de isolamento de segurança para operar por conexão
física (não mais por instância/linha), sem reabrir a possibilidade de uma arte do Cliente A
alcançar um grupo do Cliente B.

**Verified:** 2026-08-31T22:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Method Note

Contrary to the phase's own SUMMARY.md/COVERAGE.md claims ("banco de teste indisponível
localmente"), the test database **was** available in this verification session
(`bin/rails db:migrate:status` and `bin/rails test` both ran cleanly). All behavioral claims
below were re-proven by **actually running the Minitest suite in this session**, not by trusting
the executor's smoke-script output or REVIEW.md's narration of its own test runs. This upgrades
every truth that was ⚠️ human_judgment in the SUMMARYs (D1-D5 kind: unit tests, status:
`unknown`) to ✓ VERIFIED here, since the tests themselves were run and observed to pass directly.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Admin, on a client WITHOUT an instance, can pick an already-connected sibling connection and link the client to it with zero QR / zero Evolution calls (D-01/D-03/D-06) | ✓ VERIFIED | `Admin::WhatsappInstancesController#reuse` (app/controllers/admin/whatsapp_instances_controller.rb:96-112) resolves via `WhatsappInstance.connected.where.not(client_id:).find_by(instance_name:)` then calls `InstanceProvisioner#reuse` which is 100% local (no `@api.*` calls). `test/controllers/admin/whatsapp_instances_controller_test.rb` and `test/services/evolution/instance_provisioner_test.rb` — both run in this session, 0 failures. |
| 2 | Reused row copies instance_name/token/connection_state/paired_at/remote_instance_id from the sibling, `origin: :reused_sibling` (D-03) | ✓ VERIFIED | `Evolution::InstanceProvisioner#reuse` (app/services/evolution/instance_provisioner.rb:49-61) — field-for-field copy, `origin: :reused_sibling` (enum value added, `app/models/whatsapp_instance.rb:19`). Test run: `instance_provisioner_test.rb` passes. |
| 3 | Two clients sharing the same physical connection resolve the SAME `concurrency_key` in `SendToGroupJob`, serialized by `instance_name` (D-04, preserves ENVIO-09) | ✓ VERIFIED | `app/jobs/whatsapp/send_to_group_job.rb:64-68` — `key: ->(group) { group.divulgacao.client.whatsapp_instance&.instance_name \|\| sentinel }`. `send_to_group_job_test.rb` run in this session (sibling-pair case), 0 failures. |
| 4 | `instance_name` index is no longer UNIQUE; `client_id` UNIQUE index remains — a client never has two instances (D-03) | ✓ VERIFIED | `db/schema.rb:293-294` — `index_whatsapp_instances_on_client_id` still `unique: true`; `index_whatsapp_instances_on_instance_name` has no unique option. `bin/rails db:migrate:status` shows migration `20260831185638` applied. Controller `rescue ActiveRecord::RecordNotUnique` present and tested. |
| 5 | "Novo número (QR)" flow (PAIR-01/02) remains available, byte-identical in the `_panel` else branch (D-07) | ✓ VERIFIED | `git diff` of `_panel.html.erb`'s `else` branch adds only the `shared?` badge line; QR partial render, banner, actions untouched. `create`/`adopt`/`verify`/`reconnect`/`refresh_qr` actions in the controller are unmodified except the new `#reuse` action added alongside. |
| 6 | Group selection per Divulgação is unchanged — nothing added to the GRUPO-03 flow (D-02) | ✓ VERIFIED | No files touched under `app/controllers/admin/divulgacoes_controller.rb` or the group-picker view; `WhatsappGroup`/`GroupSynchronizer` public contract (`SyncGroupsJob#perform(instance)` signature) unchanged — confirmed via `git diff app/jobs/whatsapp/sync_groups_job.rb` (empty). |
| 7 | `connection.update` for a shared `instance_name` updates ALL sibling rows, not just one — ENVIO-07 guard never reads stale sibling state (Pitfall 1) | ✓ VERIFIED | `Webhooks::EvolutionController#create` (app/controllers/webhooks/evolution_controller.rb:22-35) — `WhatsappInstance.where(instance_name:).find_each { apply_event_safely(instance) }`, `valid_signature?` still runs first. `evolution_controller_test.rb` run in this session (fan-out to 2 siblings), 0 failures. |
| 8 | Syncing a client sharing the physical connection makes ONE `fetchAllGroups` call and populates all siblings' caches with the same `batch_started_at` (D-05) | ✓ VERIFIED | `Whatsapp::GroupSynchronizer#call` (app/services/whatsapp/group_synchronizer.rb:37-62) — single `@api.fetch_groups` call outside the `find_each` loop over siblings. `group_synchronizer_test.rb` run in this session (fan-out case (i): `fake.calls == 1`, both siblings populated, equal `groups_synced_at`), 0 failures. |
| 9 | An instance WITHOUT siblings behaves byte-identically to pre-phase-31 GroupSynchronizer (D-05 mandatory regression) | ✓ VERIFIED | `group_synchronizer_test.rb` case (h) regression + pre-existing cases (a)-(g) unedited, all passing in this session's run. |
| 10 | `cross_client_isolation_test.rb` keeps the 3 pre-existing tests passing unchanged, even with a sibling pair sharing `instance_name` (D-02, SEG-04) | ✓ VERIFIED | `git diff fb3ea70..HEAD -- test/integration/cross_client_isolation_test.rb` shows ONLY additions (1 new test method + optional `instance_name:` param on the helper, default unchanged) — the 3 original test bodies are byte-identical. Ran `bin/rails test test/integration/cross_client_isolation_test.rb` directly in this session: 4 runs, 28 assertions, 0 failures, 0 errors. |
| 11 | `COVERAGE.md` documents zero new Evolution endpoints and the two topology changes | ✓ VERIFIED | `.planning/phases/31-.../COVERAGE.md` explicitly states "Phase 31 adds no Evolution endpoint" and documents both the GroupSynchronizer and webhook fan-out as topology-only changes; matches the actual code (no new `@api.*` methods called anywhere in the diff). |
| 12 | No secret (`token`) leaks in logs/params/job args (INFRA-04) | ✓ VERIFIED | `#reuse` action logs only `client=#{@client.id}` + exception class (app/controllers/admin/whatsapp_instances_controller.rb:108-111), matching the pattern of `#create`/`#adopt`/`#verify`/`#reconnect`. `limits_concurrency key:` resolves `instance_name` (non-secret string), not `token`. |
| 13 | Requirement traceability: no real REQ-ID was silently dropped by declaring "TBD" | ✓ VERIFIED | ROADMAP.md Phase 31 section explicitly states "fase aditiva — sem REQ-ID novo"; REQUIREMENTS.md's "Cobertura de Requisitos — v1.7" table sums to 50/50 across phases 25-30 and does not list phase 31 (correctly, since it's a post-v1.7 addition). PAIR-01..08, GRUPO-01..05, SEG-01/02/04 remain `[x]` complete in REQUIREMENTS.md and are functionally unbroken (see regression run below). |

**Score:** 13/13 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/20260831185638_deuniqueify_whatsapp_instance_name.rb` | drops unique index on `instance_name`, keeps `client_id` unique | ✓ VERIFIED | Applied (`db:migrate:status` up); `db/schema.rb` matches |
| `app/models/whatsapp_instance.rb` | `origin` enum += `reused_sibling`, `scope :connected`, `#siblings`, `#shared?`, `self.shareable_targets` | ✓ VERIFIED | All present, code-only enum addition, no migration needed |
| `app/services/evolution/instance_provisioner.rb` | `#reuse(existing:)`, zero I/O | ✓ VERIFIED | Present, `#call`/`#adopt`/`#persist_new` byte-unmodified (only `#reuse` added) |
| `app/controllers/admin/whatsapp_instances_controller.rb` | `#reuse` action, scoped resolution | ✓ VERIFIED | Present, `WhatsappInstance.find(params` never used (git grep empty) |
| `config/routes.rb` | `post :reuse` route | ✓ VERIFIED | `resource :whatsapp_instance` block has `post :reuse` |
| `app/controllers/admin/clients_controller.rb` | `@reusable_targets` in `#show` | ✓ VERIFIED | Present, gated on `@whatsapp_instance.nil?` |
| `app/views/admin/whatsapp_instances/_panel.html.erb` | toggle + reuse form + badge | ✓ VERIFIED | Present, `else` branch preserved except badge line |
| `app/javascript/controllers/whatsapp_provision_toggle_controller.js` | Stimulus controller, dedicated | ✓ VERIFIED | `node --check` clean; 8 targets incl. `reuseSelect`/`reuseSubmit` (extra vs plan's 6, added for submit-disable behavior — improvement, not a deviation of intent) |
| `app/jobs/whatsapp/send_to_group_job.rb` | `limits_concurrency` key by `instance_name` | ✓ VERIFIED | Present, sentinel fallback intact |
| `app/controllers/webhooks/evolution_controller.rb` | fan-out via `where(instance_name:).find_each` | ✓ VERIFIED | Present, `apply_event_safely` wraps each sibling (WR-01 fix) |
| `app/services/whatsapp/group_synchronizer.rb` | 1 fetch, N upserts, `row_for` takes sibling | ✓ VERIFIED | Present, single `fetch_groups` call before the `find_each` |
| `app/controllers/admin/whatsapp_groups_controller.rb` | sync guard scoped to siblings (WR-02 fix) | ✓ VERIFIED | `@instance.siblings.groups_sync_syncing.exists?` + cache key by `instance_name` |
| `.planning/phases/31-.../COVERAGE.md` | zero new endpoints + 2 topology changes | ✓ VERIFIED | Present, matches implementation |
| `test/integration/cross_client_isolation_test.rb` | 3 unchanged + 1 new test | ✓ VERIFIED | `git diff` confirms additions-only |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `#reuse` action | sibling resolution | `WhatsappInstance.connected.where.not(client_id:).find_by(instance_name: params.require(...))` | ✓ WIRED | Never a raw `params[:id]`/`find(params`; git grep confirms |
| `SendToGroupJob.limits_concurrency key:` | `divulgacao.client.whatsapp_instance.token` | Same resolution chain (SEG-03 belt) | ✓ WIRED | Doc-comment explicitly ties the two chains; test asserts token never serialized |
| `Webhooks::EvolutionController#create` | `valid_signature?` | Runs before any `WhatsappInstance` query | ✓ WIRED | `return head(:unauthorized) unless valid_signature?` is literally line 1 of `#create`, before the `where(instance_name:)` |
| `GroupSynchronizer#call` | `@api.fetch_groups` | Called once, OUTSIDE `find_each` of siblings | ✓ WIRED | Confirmed by source line order and by test asserting `fake.calls == 1` with 2 siblings |
| `admin/clients_controller#show` | `@reusable_targets` | `WhatsappInstance.shareable_targets(excluding_client_id:)` → `_panel.html.erb` `<select>` | ✓ WIRED | `show.html.erb:137` passes `reusable_targets: @reusable_targets` to the partial; rendered `<option>` labels contain "usado por:" (asserted by `clients_controller_test.rb`) |
| `cross_client_isolation_test.rb` (SEG-04) | isolation anchor | `whatsapp_instance_id` (row), NOT `instance_name` | ✓ WIRED | New Test 4 explicitly proves `RecordNotFound` survives a shared-`instance_name` sibling pair |

### Behavioral Spot-Checks / Test Execution (run directly in this session, not from SUMMARY narration)

| Suite | Command | Result | Status |
|-------|---------|--------|--------|
| `cross_client_isolation_test.rb` | `bin/rails test test/integration/cross_client_isolation_test.rb` | 4 runs, 28 assertions, 0 failures, 0 errors | ✓ PASS |
| 8 phase-31 test files (webhooks, whatsapp_groups_controller, clients_controller, whatsapp_instances_controller, whatsapp_instance model, send_to_group_job, group_synchronizer, instance_provisioner) | `bin/rails test <8 files>` | 128 runs, 499 assertions, 0 failures, 0 errors | ✓ PASS |
| Full regression: `test/models test/services test/controllers test/jobs test/integration` | `bin/rails test <dirs>` | 489 runs, 1832 assertions, 19 failures, 0 errors | ✓ PASS (with pre-existing unrelated failures, see below) |
| JS syntax | `node --check whatsapp_provision_toggle_controller.js` | clean | ✓ PASS |

**19 full-suite failures analysis:** none touch WhatsApp/phase-31 files. All 19 are in `test/controllers/api/v1/ai/artes_controller_test.rb`, `test/controllers/api/v1/ai/clients_controller_test.rb`, `test/integration/rack_attack_test.rb`, `test/models/arte_test.rb`, `test/models/approval_response_test.rb`, `test/controllers/admin/dashboard_controller_test.rb`, `test/controllers/client/home_controller_test.rb`. Reproduced `artes_controller_test.rb` and `rack_attack_test.rb` failures in isolation (single-file run) — they fail identically outside the full-suite parallel run, confirming pre-existing environment flakiness (shared `Rack::Attack` `MemoryStore` cache bleeding across test runs / turbo-stream fixture drift), not a phase-31 regression. `config/initializers/rack_attack.rb` was last touched in phase 27 (`df1c286`), confirmed via `git log`; phase 31 touches none of the failing files.

### Requirements Coverage

| Requirement | Source | Status | Evidence |
|-------------|--------|--------|----------|
| TBD (phase 31 declared, no new REQ-ID) | 31-01/31-02 PLAN frontmatter | ✓ SATISFIED | Confirmed intentional — ROADMAP.md and 31-CONTEXT.md both state this is an additive phase beyond v1.7's 50/50 requirement table |
| PAIR-01..08 | REQUIREMENTS.md | ✓ SATISFIED (unbroken) | `[x]` in REQUIREMENTS.md; QR flow untouched, verified by test run |
| GRUPO-01..05 | REQUIREMENTS.md | ✓ SATISFIED (unbroken) | `[x]` in REQUIREMENTS.md; `SyncGroupsJob#perform` signature unchanged, GRUPO-05 deactivation pass runs per-sibling with shared batch timestamp |
| SEG-01, SEG-02, SEG-04 | REQUIREMENTS.md | ✓ SATISFIED (unbroken) | `[x]` in REQUIREMENTS.md; SEG-04 test suite (3 original + 1 new) passes; SEG-01 pattern (never raw id from params) followed in new `#reuse` action |
| SEG-03 | REQUIREMENTS.md (owned by phase 29, `[ ]`) | ✓ SATISFIED (unbroken) | Token resolution chain (`divulgacao.client.whatsapp_instance.token`) unchanged, doc-commented as the SEG-03 belt companion to the D-04 concurrency-key chain |
| ENVIO-07, ENVIO-09 | REQUIREMENTS.md (owned by phase 29) | ✓ SATISFIED (unbroken) | ENVIO-09 (serialize same-instance sends) now extended to same-*connection* sends via `instance_name` key (strictly stronger, not weaker); ENVIO-07 (connection state checked before send) preserved via webhook fan-out keeping all sibling rows' `connection_state` fresh |

No orphaned requirements found — REQUIREMENTS.md's phase-mapping table intentionally excludes Phase 31 (post-v1.7 addition), consistent with the "TBD" declaration in both PLAN files.

### Anti-Patterns Found

None. Grep for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` across all phase-31-touched files returned only false positives (the Portuguese word "todos"/"TODOS" matching the `TODO` regex substring, not actual debt markers). No empty-return stubs, no hardcoded empty data flowing to render, no console.log-only handlers.

### Code Review Status

`31-REVIEW.md`: `status: clean` after 1 fix iteration. All 3 Warning findings (webhook fan-out exception isolation, group-sync guard keyed by instance_name, reconnect-modal blast-radius warning) independently re-verified as fixed in the codebase during this verification (source inspection of `evolution_controller.rb`, `whatsapp_groups_controller.rb`, `_panel.html.erb` — all three fixes present and match the REVIEW-FIX.md description). 3 Info findings remain (migration reversibility comment, blank-string `params.require` edge case, `shareable_targets` not filtering deactivated clients) — accepted as non-blocking per the review, and independently assessed here as genuinely low-severity (none affect the isolation boundary or data integrity).

### Human Verification Required

1. **Stimulus toggle visual/interactive behavior** — click between "Novo número (QR)" and "Reutilizar conexão existente" pills on a client without a WhatsApp instance.
   - Expected: active pill gets green highlight (`border-[#0F7949]`/`bg-green-50`/`text-[#0F7949]`), inactive pill goes gray; the corresponding field (create button vs. reuse form) shows/hides; the "Reutilizar conexão" submit button stays disabled until a `<select>` option is chosen; submitting shows the `turbo_confirm` dialog with the shared-connection warning text before the POST fires.
   - Why human: pure client-side JS interaction (classList toggling, disabled-state binding, confirm dialog) — not exercised by any Rails controller test in this codebase (no JS-driving test harness present); the phase's own SUMMARY.md flags this exact item as `human_judgment: true`.

### Gaps Summary

None. All 13 must-have truths across both plans (31-01, 31-02) are verified against the actual codebase — not just SUMMARY claims — via direct code inspection, `git diff` scoping checks (proving byte-identical preservation of PAIR-*/GRUPO-*/SEG-* code paths), and by independently running the full relevant Minitest suite in this session (a capability the executor believed unavailable but which worked cleanly here): 0 failures across 8 phase-31 test files (128 tests) and across the full model/service/controller/job/integration regression sweep (489 tests, 19 pre-existing unrelated failures isolated and explained). The isolation boundary redesign (D-03/D-04/D-05: anchored on `whatsapp_instance_id`/row identity rather than `instance_name`) genuinely survives the introduction of shared physical connections — proven by the new SEG-04 sibling-pair test, which was run directly and passed. The only outstanding item is a standard end-of-phase visual/interactive UI check that requires a human clicking through the browser.

---

*Verified: 2026-08-31T22:00:00Z*
*Verifier: Claude (gsd-verifier)*
