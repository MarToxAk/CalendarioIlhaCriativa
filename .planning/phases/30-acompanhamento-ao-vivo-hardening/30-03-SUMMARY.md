---
phase: 30-acompanhamento-ao-vivo-hardening
plan: 03
subsystem: ui
tags: [rails, erb, whatsapp, admin, divulgacoes]

# Dependency graph
requires:
  - phase: 30-01
    provides: "divulgacoes#show layout (Detalhes/Grupos/Prévia), _grupo_row partial, status pills"
  - phase: 30-02
    provides: "resend action + button, _grupo_row items-start layout with the div.flex.flex-col name block"
provides:
  - "Admin::DivulgacoesHelper::SENTINEL_ERROR_LABELS / #divulgacao_grupo_error_label / #divulgacao_placar"
  - "N+1-safe per-group score line on divulgacoes#index and its admin/clients#show mirror"
  - "_grupo_row error_code / sent_at detail sub-lines"
  - "SC3 frozen-name regression test"
affects: [acompanhamento, divulgacoes, whatsapp]

actuals:
  tokens: 4777
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "copy-map helper (hash lookup + string-interpolation fallback) instead of re-running write-time sanitization at render time"
    - "group_by(&:status) over an includes-preloaded association to build an aggregate score with zero extra queries"

key-files:
  created: []
  modified:
    - app/helpers/admin/divulgacoes_helper.rb
    - app/controllers/admin/divulgacoes_controller.rb
    - app/controllers/admin/clients_controller.rb
    - app/views/admin/divulgacoes/index.html.erb
    - app/views/admin/clients/show.html.erb
    - app/views/admin/divulgacoes/_grupo_row.html.erb
    - test/helpers/admin/divulgacoes_helper_test.rb
    - test/controllers/admin/divulgacoes_controller_test.rb

key-decisions:
  - "divulgacao_grupo_error_label is a pure copy-map (sentinel hash lookup or a 'Motivo: ' prefix) — it never re-runs Phase 29's sanitize_error_code, never truncates/gsubs, and never re-fetches the model, per the plan's prohibitions."
  - "divulgacao_placar reads divulgacao.divulgacao_grupos.to_a and group_by(&:status) — no .count/.where — so it only ever touches the association already loaded by the controller's includes(:arte, :divulgacao_grupos)."
  - "admin/clients#show's 'Ver todas' link was already admin_client_divulgacoes_path(@client) before this plan — confirmed, not changed."

patterns-established:
  - "Any future per-group aggregate/label helper on Divulgacao should follow divulgacao_placar's group_by-on-preloaded-association shape rather than adding scopes/counts that would reintroduce N+1."

requirements-completed: [ACOMP-03]

coverage:
  - id: D1
    description: "Admin::DivulgacoesHelper gains SENTINEL_ERROR_LABELS, divulgacao_grupo_error_label, and divulgacao_placar, each covered by a per-branch assertion (both sentinels, unknown-code fallback, verbatim [url-redigida] passthrough, 0/all-pendente/mixed placar branches, no-pluralize single-group case)."
    requirement: "ACOMP-03"
    verification:
      - kind: unit
        ref: "test/helpers/admin/divulgacoes_helper_test.rb (17 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "divulgacoes#index and admin/clients#show both includes(:arte, :divulgacao_grupos) and render divulgacao_placar per row, with a test proving the page issues exactly one divulgacao_grupos query (no N+1, T-30-11)."
    requirement: "ACOMP-03"
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET_index_mostra_o_placar_por_grupo_de_cada_divulgacao_(ACOMP-03)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET_index_nao_dispara_query_extra_por_linha_pra_montar_o_placar_(T-30-11,_sem_N+1)"
        status: pass
    human_judgment: false
  - id: D3
    description: "_grupo_row shows an 'Enviado em ... (BRT)' sub-line on enviado rows and a divulgacao_grupo_error_label reason sub-line on falhou/incerto rows (never on pendente rows); the error text renders verbatim through ERB escaping with no re-sanitization, including an already-redacted [url-redigida] value with no raw http/X-Amz alongside it (T-30-10)."
    requirement: "ACOMP-03"
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET_show_de_linha_enviado_mostra_'Enviado_em_...(BRT)'"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET_show_de_linha_falhou_com_error_code_sentinela_mostra_o_texto_pt-BR_mapeado"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET_show_de_linha_falhou_com_error_code_ja_redigido_--_[url-redigida]_verbatim,_sem_http/X-Amz_cru_(T-30-10)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET_show/index_com_linhas_mistas"
        status: pass
    human_judgment: false
  - id: D4
    description: "SC3: renaming and deactivating the source WhatsappGroup does not change the frozen divulgacao_grupos.group_name shown on #show, nor break the index page / its placar."
    requirement: "ACOMP-03"
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#SC3:_renomear/desativar_o_WhatsappGroup_de_origem_nao_muda_o_group_name_congelado_no_show;_index/placar_seguem_intactos"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-31
status: complete
---

# Phase 30 Plan 03: Acompanhamento ao Vivo — Placar por Grupo na Historia + Sub-linhas de Detalhe Summary

**Per-client Divulgações history now shows a compact "X enviados · Y falhou" score per row (N+1-safe), and `#show` reveals per-group send time / failure reason, with the group name frozen at send time proven by a regression test (SC3).**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-31 (session start)
- **Completed:** 2026-08-31T13:33:11Z
- **Tasks:** 3/3 completed
- **Files modified:** 8

## Accomplishments
- Added `Admin::DivulgacoesHelper::SENTINEL_ERROR_LABELS`, `#divulgacao_grupo_error_label`, and `#divulgacao_placar` — the placar collapses a divulgação's per-group statuses into "3 enviados · 1 falhou · 1 incerto · 2 pendente" (or "—" / "N pendentes" at the edges), with the Phase 28 no-pluralize copy lock preserved.
- `divulgacoes#index` and the `admin/clients#show` mirror both `includes(:arte, :divulgacao_grupos)` and render the placar per row — proven by a test that counts exactly one `divulgacao_grupos` query for the whole page, not one per row.
- `_grupo_row` now shows "Enviado em {sent_at} (BRT)" on `enviado` rows and the mapped/verbatim `error_code` reason on `falhou`/`incerto` rows; `pendente` rows are unchanged.
- Added the SC3 regression test: renaming + deactivating the source `WhatsappGroup` does not alter the frozen `group_name` already shown on `#show`, nor break the index page.

## Task Commits

Each task was committed atomically:

1. **Task 1: Helpers — SENTINEL_ERROR_LABELS, divulgacao_grupo_error_label, divulgacao_placar** - `4531060` (feat)
2. **Task 2: Per-group score on divulgacoes#index + admin/clients#show mirror, no N+1** - `6e9de03` (feat)
3. **Task 3: _grupo_row error_code / sent_at detail sub-lines + SC3 frozen-name test** - `8034521` (feat)

## Files Created/Modified
- `app/helpers/admin/divulgacoes_helper.rb` - adds the frozen `SENTINEL_ERROR_LABELS` hash and the `divulgacao_grupo_error_label` / `divulgacao_placar` helpers
- `app/controllers/admin/divulgacoes_controller.rb` - `#index` relation now `includes(:arte, :divulgacao_grupos)`
- `app/controllers/admin/clients_controller.rb` - `#show`'s `@divulgacoes` relation now `includes(:arte, :divulgacao_grupos)`
- `app/views/admin/divulgacoes/index.html.erb` - desktop `Grupos` cell gets a placar sub-line; mobile card sub-line appends it
- `app/views/admin/clients/show.html.erb` - recent-divulgação rows append the placar under the datetime
- `app/views/admin/divulgacoes/_grupo_row.html.erb` - adds the `sent_at` / `error_code` conditional sub-line inside the existing name block
- `test/helpers/admin/divulgacoes_helper_test.rb` - 9 new tests covering every helper branch
- `test/controllers/admin/divulgacoes_controller_test.rb` - 8 new tests: placar rendering, N+1 assertion, sub-line rendering (enviado/falhou/incerto/mixed), redacted-URL passthrough, and SC3

## Decisions Made
- `divulgacao_grupo_error_label` is intentionally a two-branch copy-map only — sentinel hash lookup or a `"Motivo: "` prefix — with no truncation, gsub, or model re-fetch, per the plan's prohibitions and the T-30-10 threat mitigation (Phase 29 already redacted/truncated at write time).
- `divulgacao_placar` reads `divulgacao.divulgacao_grupos.to_a` (not `.count`/`.where`) so it always operates on the association already loaded by the controller's `includes`, never issuing a query of its own.
- Confirmed (not changed) that `admin/clients#show`'s "Ver todas" link already pointed at `admin_client_divulgacoes_path(@client)` before this plan.

## Deviations from Plan

None — plan executed exactly as written. Test helper setup methods (`build_dg`, `build_divulgacao_com_status`, `build_divulgacao_agendada`) had to route every `Divulgacao.create!` through the `ao_menos_um_grupo` validation (build the group rows inline, then `update!` their status afterward) rather than attaching a `DivulgacaoGrupo` to an already-persisted parent — this is a test-authoring detail consistent with existing test idioms in the same files (`test/models/divulgacao_grupo_test.rb`), not a plan deviation.

## Issues Encountered
- Initial draft of the T-30-10 "no raw http/X-Amz" test used a whole-page regex (`refute_match(/https?:\/\//, response.body)`), which false-failed against unrelated `<link href="https://fonts.googleapis.com/...">` markup already in the admin layout. Narrowed the assertion to the specific "Motivo: ..." string instead of a page-wide regex.
- Initial draft of the SC3 test asserted the frozen `group_name` appears literally on the `divulgacoes#index` page; `index.html.erb` does not render individual group names (only the count + placar), so the index-side assertion was corrected to check the placar text and page success instead, while the `#show`-side assertion (where `_grupo_row` does render `group_name`) stayed as originally planned.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 30 (Acompanhamento ao Vivo + Hardening) is now fully implemented across all 4 plans (30-01, 30-04, 30-02, 30-03). ACOMP-03 is satisfied: the per-client Divulgações history shows the per-group result, `#show` shows per-group reason/timestamp detail, and the frozen `group_name` snapshot survives a source-group rename/deactivation. No blockers for the next phase.

Full `bin/rails test` run confirms this plan's files are clean; the 19 failures observed in the full-suite run are all pre-existing and unrelated to this plan's files (`arte_test.rb`, `approval_response_test.rb`, `dashboard_controller_test.rb`, `client/home_controller_test.rb`, `rack_attack_test.rb`, and `api/v1/ai/clients_controller_test.rb` — the last is a new observation this session, same class of shared-Postgres-test-DB symptom already documented in `.planning/phases/30-acompanhamento-ao-vivo-hardening/deferred-items.md`; none of the six failing files were touched by any 30-01/30-02/30-03 commit).

---
*Phase: 30-acompanhamento-ao-vivo-hardening*
*Completed: 2026-08-31*

## Self-Check: PASSED

- FOUND: `.planning/phases/30-acompanhamento-ao-vivo-hardening/30-03-SUMMARY.md`
- FOUND: `4531060` (Task 1 commit)
- FOUND: `6e9de03` (Task 2 commit)
- FOUND: `8034521` (Task 3 commit)
