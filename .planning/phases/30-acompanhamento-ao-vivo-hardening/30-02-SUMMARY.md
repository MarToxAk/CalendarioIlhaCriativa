---
phase: 30-acompanhamento-ao-vivo-hardening
plan: 02
subsystem: whatsapp-dispatch
tags: [turbo-streams, button_to, rails-routes, resend, whatsapp, cross-client-isolation]

# Dependency graph
requires:
  - phase: 30-01
    provides: "DivulgacaoGrupo#broadcast_progresso / Divulgacao#broadcast_status (dom_id(dg) and dom_id(divulgacao, :progresso) live-replace targets) — resend.turbo_stream.erb reuses these exact targets"
  - phase: 29-motor-de-envio
    provides: "Whatsapp::SendToGroupJob — atomic claim, revalidation, limits_concurrency, finalize_divulgacao_if_done — re-enqueued verbatim by #resend"
provides:
  - "Admin::DivulgacoesController#resend — scoped row reset + controller-side concluida->em_andamento reopen + Whatsapp::SendToGroupJob.perform_later re-enqueue"
  - "resend_admin_client_divulgacao_divulgacao_grupo_path route (nested member :resend on divulgacao_grupos, routed to the DivulgacoesController)"
  - "app/views/admin/divulgacoes/resend.turbo_stream.erb — in-place row + summary repaint, no full reload"
  - "conditional 'Reenviar' button in _grupo_row.html.erb (falhou/incerto only, suppressed on cancelada parent, group-named turbo_confirm)"
affects: [30-03-historico-por-cliente]

# Actuals (#2632)
actuals:
  tokens: 3752
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "nested resource with controller: override — resources :divulgacao_grupos, only: [], controller: \"divulgacoes\" under resources :divulgacoes — keeps the new action on the existing DivulgacoesController instead of spawning a one-action controller, while still producing a semantically-scoped route/helper name"
    - "local_assigns[:just_resent] optional-local guard on a shared partial — the resend.turbo_stream.erb response passes just_resent: true to trigger a one-time UI note; the normal render and the live model broadcast never pass it, so the partial must tolerate the local being entirely absent"
    - "controller-side status reopen paired with re-enqueue — concluida -> em_andamento lives in #resend, not in the Phase 29 job, so the job's own finalize_divulgacao_if_done stays the single source of truth for re-closing"

key-files:
  created:
    - app/views/admin/divulgacoes/resend.turbo_stream.erb
  modified:
    - config/routes.rb
    - app/controllers/admin/divulgacoes_controller.rb
    - app/views/admin/divulgacoes/_grupo_row.html.erb
    - test/controllers/admin/divulgacoes_controller_test.rb

key-decisions:
  - "Route: resources :divulgacao_grupos, only: [], controller: \"divulgacoes\" nested under :divulgacoes, with member { post :resend } — Rails' default nested-resource controller inference would have generated admin/divulgacao_grupos#resend; the explicit controller: override keeps the action inside Admin::DivulgacoesController as the plan requires while still producing the exact resend_admin_client_divulgacao_divulgacao_grupo_path helper name specified in 30-PATTERNS.md/30-UI-SPEC.md."
  - "#resend does not get a dedicated before_action — it resolves @divulgacao and @dg itself via the two-hop scoped .find chain (the existing before_action :set_client already runs globally), matching the plan's explicit instruction not to reuse set_divulgacao for this action."
  - "No rescue ActiveRecord::RecordNotFound added to #resend — a foreign divulgacao_id or group id propagates to Rails' default 404, deliberately asymmetric with #create's rescue (which re-renders a form). Verified with two separate cross-client 404 assertions: a foreign divulgacao_id, and a foreign group id nested under the admin's own divulgacao (the second hop)."

requirements-completed: [ACOMP-02]

coverage:
  - id: D1
    description: "POST resend re-resolves both ids through @client.divulgacoes.find(params[:divulgacao_id]).divulgacao_grupos.find(params[:id]); a falhou row resets to pendente (error_code/sent_at/evolution_message_id cleared), a concluida parent reopens to em_andamento, and exactly one Whatsapp::SendToGroupJob is enqueued with the row — no synchronous Evolution call."
    requirement: "ACOMP-02"
    verification:
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#POST resend numa linha falhou -- reseta pra pendente, reenfileira o job, reabre concluida->em_andamento"
        status: pass
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#POST resend numa linha incerto com divulgacao ainda em_andamento -- reseta e reenfileira, sem mexer no status da divulgacao"
        status: pass
    human_judgment: false
  - id: D2
    description: "A cancelada parent refuses the resend before any row mutation or job enqueue: flash[:alert] == 'Não é possível reenviar: esta divulgação foi cancelada.', redirected to show, row untouched."
    requirement: "ACOMP-02"
    verification:
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#POST resend numa divulgacao cancelada -- recusa, sem mutacao, sem enqueue, flash alert"
        status: pass
    human_judgment: false
  - id: D3
    description: "A foreign divulgacao_id or a group id belonging to a different divulgacao (both under the client scope or cross-client) 404s via the default RecordNotFound path, with no cross-client data leaking into the response body and no job enqueued."
    requirement: "ACOMP-02"
    verification:
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#POST resend com divulgacao_id ou id de grupo de OUTRO cliente -- 404, nada vaza, sem enqueue"
        status: pass
    human_judgment: false
  - id: D4
    description: "resend.turbo_stream.erb replaces exactly the two 30-01 live-broadcast targets (dom_id(@dg) and dom_id(@divulgacao, :progresso)) with grupo_row (just_resent: true, showing the '· reenfileirado' note) and progresso_resumo — no full-page reload."
    requirement: "ACOMP-02"
    verification:
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#POST resend as turbo_stream -- dois replace nos alvos dom_id(dg)/dom_id(divulgacao,:progresso), com reenfileirado"
        status: pass
    human_judgment: false
  - id: D5
    description: "The 'Reenviar' button renders only for falhou/incerto rows and is suppressed whenever the parent divulgacao is cancelada (even on an otherwise-recoverable falhou row) — zero/one/many coverage across pendente/enviado/falhou/incerto rows in a single #show."
    requirement: "ACOMP-02"
    verification:
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET show com todas as linhas pendente -- nenhum botao Reenviar (zero-one-many: zero)"
        status: pass
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET show com exatamente uma linha falhou -- exatamente um botao Reenviar (zero-one-many: one)"
        status: pass
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET show com status mistos -- Reenviar so em falhou/incerto, nunca pendente/enviado (zero-one-many: many)"
        status: pass
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET show de divulgacao cancelada com linha falhou -- nenhum botao Reenviar mesmo em linha recuperavel"
        status: pass
      - kind: unit
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#_grupo_row renderiza sem o local just_resent (render normal / broadcast ao vivo nao passam)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Operator UAT (SC2): clicking 'Reenviar' on a real falhou row shows a native confirm dialog naming the group, the row flips to Pendente '· reenfileirado' in place with no full reload, then updates to its final state when the re-enqueued job actually runs; no 'Reenviar' button appears on a cancelada divulgação in the real browser."
    verification: []
    human_judgment: true
    rationale: "Requires a human observing a real browser tab through the native turbo_confirm dialog, the in-place DOM swap, and the eventual live-broadcast transition once Whatsapp::SendToGroupJob actually executes — an automated test proves the request/response contract (D1-D5) but not the end-to-end visual/interactive experience. Deferred to operator UAT per plan <verification> human-check."

# Metrics
duration: ~20min
completed: 2026-08-31
status: complete
---

# Phase 30 Plan 02: Reenvio Manual por Grupo (ACOMP-02) Summary

**A scoped `POST resend` re-resolves the group through the client association at every hop, refuses on a `cancelada` parent, resets a `falhou`/`incerto` row to `pendente`, reopens `concluida → em_andamento` in the controller, and re-enqueues the unchanged Phase 29 `Whatsapp::SendToGroupJob` — the response repaints the row and progress summary in place via `resend.turbo_stream.erb`, with no synchronous Evolution call anywhere in the request.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2/2
- **Files modified:** 4 (1 new, 4 modified — see below)

## Accomplishments

- `Admin::DivulgacoesController#resend`: both `params[:divulgacao_id]` and `params[:id]` are re-resolved through `@client.divulgacoes.find(...).divulgacao_grupos.find(...)` — no rescue, so a foreign id falls straight through to Rails' default 404, exactly matching the `set_divulgacao` idiom used elsewhere in this controller (unlike `#create`, which deliberately re-renders on `RecordNotFound`).
- The `status_cancelada?` guard runs before any row mutation or job enqueue, setting the exact `flash[:alert]` copy and redirecting to `#show`.
- The row reset (`status: :pendente`, `error_code`/`sent_at`/`evolution_message_id` all `nil`) and the `concluida → em_andamento` reopen both live in the controller — `Whatsapp::SendToGroupJob` (Phase 29) is untouched and re-enqueued verbatim via `perform_later`.
- New `resend.turbo_stream.erb` targets the identical two DOM ids the 30-01 live broadcast already uses (`dom_id(@dg)`, `dom_id(@divulgacao, :progresso)`), so the resend response and the eventual job-driven broadcast repaint the exact same page real estate — no full reload, no divergent target names to keep in sync.
- `_grupo_row.html.erb` gained a conditional `button_to "Reenviar"` (secondary white style, `turbo_confirm` naming the frozen `group_name`, `turbo_submits_with: "Reenfileirando…"`) rendered only for `falhou`/`incerto` rows on a non-`cancelada` divulgação, plus an optional `· reenfileirado` note gated on `local_assigns[:just_resent]` so the normal render and the live broadcast never show it.
- A nested route (`resources :divulgacao_grupos, only: [], controller: "divulgacoes" { member { post :resend } }`) produces exactly the `resend_admin_client_divulgacao_divulgacao_grupo_path` helper the UI-SPEC/PATTERNS specify, while keeping the action on `Admin::DivulgacoesController` rather than spawning a new controller.

## Task Commits

Each task was committed atomically:

1. **Task 1: Nested resend route + Admin::DivulgacoesController#resend** - `1550a0a` (feat)
2. **Task 2: resend.turbo_stream.erb + conditional Reenviar button in _grupo_row** - `b9dbed3` (feat)

**Plan metadata:** committed alongside this SUMMARY (see final commit below).

## Files Created/Modified

- `config/routes.rb` - nested `resources :divulgacao_grupos, only: [], controller: "divulgacoes"` under `resources :divulgacoes`, with `member { post :resend }`
- `app/controllers/admin/divulgacoes_controller.rb` - new `#resend` action: two-hop scoped `.find` chain, `status_cancelada?` guard, row reset, controller-side reopen, `perform_later`, `respond_to` (turbo_stream + html)
- `app/views/admin/divulgacoes/resend.turbo_stream.erb` - NEW: two `turbo_stream.replace` blocks (`dom_id(@dg)` → `grupo_row` with `just_resent: true`; `dom_id(@divulgacao, :progresso)` → `progresso_resumo`)
- `app/views/admin/divulgacoes/_grupo_row.html.erb` - conditional `button_to "Reenviar"` + the `just_resent`-gated "· reenfileirado" note
- `test/controllers/admin/divulgacoes_controller_test.rb` - 9 new tests: happy path (`falhou`, `incerto`+`em_andamento`), `cancelada` guard, cross-client 404 on both id hops, turbo_stream response shape, zero/one/many button coverage, `cancelada`-suppresses-button, and the `just_resent`-absent tolerance check

## Decisions Made

- **Route controller override** — `resources :divulgacao_grupos, only: [], controller: "divulgacoes"` instead of letting Rails infer `admin/divulgacao_grupos#resend`. Verified empirically with `bin/rails routes -g resend` before writing the action, to lock in the exact helper name the UI-SPEC's `button_to` target expects.
- **No `before_action` added for `#resend`** — it resolves `@divulgacao`/`@dg` itself via the scoped chain; `before_action :set_client` already covers every action including this one.
- **Deliberately asymmetric with `#create`** — `#resend` does not rescue `RecordNotFound`, matching the plan's explicit prohibition ("MUST NOT add a rescue" — it wants the default 404, unlike `#create`'s form re-render for a different failure mode).

## Deviations from Plan

None — plan executed exactly as written. One out-of-scope discovery logged (not fixed, per scope-boundary rule): running the full `bin/rails test` suite (not just this plan's target file) during verification surfaces several pre-existing failures in files this plan never touches (`approval_response_test.rb`'s dom_id-ordering regex — same root cause as the already-documented `arte_test.rb` bug from 30-01 — plus stray-row/shared-cache symptoms in `dashboard_controller_test.rb`, `client/home_controller_test.rb`, and `rack_attack_test.rb`). Confirmed via `git log` that none of the five affected files appear in any 30-01 or 30-02 commit. Logged to `.planning/phases/30-acompanhamento-ao-vivo-hardening/deferred-items.md`.

## Issues Encountered

- **Test assertion double-count (self-corrected):** an early version of the zero-one-many button-count assertions used `response.body.scan("Reenviar")`, which double-counted because the `turbo_confirm` copy also contains the word "Reenviar" ("Reenviar esta arte para o grupo…"). Fixed by scanning for the exact button label `">Reenviar<"` instead. Caught and corrected before the task commit — not a deviation, since it only affected in-progress test authoring, not shipped behavior.
- **HTML-entity escaping in assertions (self-corrected):** `button_to`'s `data-turbo-confirm` attribute HTML-escapes embedded double quotes as `&quot;`; the first draft of the group-name assertions used literal `"` and failed. Fixed to match the escaped form. Same category as above — caught during authoring, before commit.
- `bin/rails test test/controllers/admin/divulgacoes_controller_test.rb` ran successfully in this sandbox (48/48 green) — the `test_db_permission` fallback noted in STATE.md was NOT needed for this plan's target file.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ACOMP-02 fully delivered at the code/test level: scoped resend, cancelada guard, controller-side reopen, verbatim Phase 29 re-enqueue, in-place turbo-stream repaint, conditional button with zero/one/many coverage.
- 30-03 (histórico por cliente) can build on `_grupo_row.html.erb` and the `#index`/`#show` views without any further changes to the resend mechanism — the route, action, and view contract are stable.
- Operator UAT still open for SC2 (visual: native confirm dialog naming the group, in-place repaint with no reload, eventual final state once the job runs) — see coverage D6 above.

---
*Phase: 30-acompanhamento-ao-vivo-hardening*
*Completed: 2026-08-31*

## Self-Check: PASSED

All claimed files found on disk; all claimed commits found in `git log --oneline --all`.
