---
phase: 30-acompanhamento-ao-vivo-hardening
plan: 01
subsystem: realtime
tags: [turbo-streams, action-cable, solid_cable, tdd, broadcast_replace_to]

# Dependency graph
requires:
  - phase: 29-motor-de-envio
    provides: "Whatsapp::SendToGroupJob.finalize_divulgacao_if_done (divulgacao.update!(status: :concluida)) — the caller that makes the live badge go 'Concluída'"
  - phase: 17-20 (v1.5)
    provides: "solid_cable + Turbo Streams transport, arte.rb:27 after_update_commit broadcast callback shape"
provides:
  - "DivulgacaoGrupo#broadcast_progresso — guarded after_update_commit, granular per-row + summary live replace"
  - "Divulgacao#broadcast_status — guarded after_update_commit, status badge + summary live replace"
  - "app/views/admin/divulgacoes/_progresso_resumo.html.erb partial (new)"
  - "turbo_stream_from [@client, @divulgacao] subscription on divulgacoes#show"
  - "dev ActionCable cross-process transport (bin/jobs -> browser) via solid_cable"
affects: [30-02-reenvio-manual, 30-03-historico-por-cliente]

# Actuals (#2632)
actuals:
  tokens: 3238
  tasks: 3
  commits: 5

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "broadcast_replace_to [streamables], target: ActionView::RecordIdentifier.dom_id(...), partial:, locals: — high-level turbo-rails helper, preferred over arte.rb's manual turbo_stream_tag assembly for per-record live replace"
    - "after_update_commit :method, if: -> { saved_change_to_status? } — canonical guard shape (arte.rb:27), now used on 3 models"
    - "dev-only ActionCable adapter mirrors the dev-only solid_queue single-DB treatment: bare adapter key, no connects_to, idempotent bin/setup schema-load step"

key-files:
  created:
    - app/views/admin/divulgacoes/_progresso_resumo.html.erb
  modified:
    - app/models/divulgacao_grupo.rb
    - app/models/divulgacao.rb
    - app/views/admin/divulgacoes/_grupo_row.html.erb
    - app/views/admin/divulgacoes/show.html.erb
    - config/cable.yml
    - bin/setup
    - test/models/divulgacao_grupo_test.rb
    - test/models/divulgacao_test.rb

key-decisions:
  - "development ActionCable adapter changed async -> solid_cable (planner-surfaced, not in 30-CONTEXT): the v1.5 broadcast pattern always fired from the web process; Phase 30 is the first broadcast originating from bin/jobs, and async is in-process only — without this change divulgacoes#show would never update live in dev during a real scheduled dispatch. No connects_to block (single dev DB, same treatment as solid_queue)."
  - "Used turbo-rails broadcast_replace_to (high-level helper) instead of arte.rb's manual render_partial_html + turbo_stream_tag assembly, per 30-UI-SPEC guidance — simpler for per-record stream targets."
  - "_grupo_row.html.erb edits scoped strictly to this task's contract (id, items-start, flex-col name wrapper) — no error/sent_at sub-lines, no Reenviar button (those are 30-02/30-03)."

requirements-completed: [ACOMP-01]

coverage:
  - id: D1
    description: "A DivulgacaoGrupo status flip (e.g. pendente -> enviado) broadcasts exactly 2 turbo-stream replace elements on [client, divulgacao]: the row's own <li id=dom_id(dg)> and the aggregate summary <p id=dom_id(divulgacao, :progresso)>."
    requirement: "ACOMP-01"
    verification:
      - kind: unit
        ref: "test/models/divulgacao_grupo_test.rb#flip de status dispara 2 replace no stream [client, divulgacao] (ACOMP-01)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_grupo_test.rb#update sem mudar status nao dispara broadcast (ACOMP-01)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A Divulgacao status transition (agendada->em_andamento->concluida, or cancelar!->cancelada) broadcasts 2 replace elements on [client, self]: the status badge and the summary."
    requirement: "ACOMP-01"
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#status update dispara 2 replace no stream [client, divulgacao] (ACOMP-01)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#cancelar! dispara 2 replace no stream [client, divulgacao] (ACOMP-01)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#update sem mudar status nao dispara broadcast (ACOMP-01)"
        status: pass
    human_judgment: false
  - id: D3
    description: "In development, ActionCable uses solid_cable so a broadcast originating from the bin/jobs process (a real scheduled dispatch) reaches the browser connected to the web process — proved with bin/dev running, opening a Divulgação #show, and flipping a group's status from a separate console/process while the page is open."
    requirement: "ACOMP-01"
    verification: []
    human_judgment: true
    rationale: "Cross-process live delivery to an open browser tab requires a running bin/dev (web+jobs+css) and a human observing the page not reload/jump — an automated unit test proves the adapter config and the broadcast payload shape (D1/D2), but not that a real browser tab visually updates without reload. Operator UAT per plan <verification> human-check (SC1)."
  - id: D4
    description: "bin/rails test test/models/divulgacao_grupo_test.rb test/models/divulgacao_test.rb passes in this sandbox (not deferred to inspection fallback)."
    verification:
      - kind: unit
        ref: "bin/rails test test/models/divulgacao_grupo_test.rb test/models/divulgacao_test.rb (32 runs, 0 failures)"
        status: pass
    human_judgment: false

# Metrics
duration: ~25min
completed: 2026-08-31
status: complete
---

# Phase 30 Plan 01: Acompanhamento ao Vivo (ACOMP-01) — Live Progress Tracer Summary

**Guarded `after_update_commit` broadcasts on `DivulgacaoGrupo` and `Divulgacao` push granular Turbo Stream replaces (row, badge, summary) over `[client, divulgacao]` — no full-list re-render, no client-side JS — plus a dev-only `solid_cable` ActionCable adapter so the `bin/jobs` process can actually reach the browser.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-31T09:56:00-03:00
- **Completed:** 2026-08-31T10:00:06-03:00 (commit timestamps; wall-clock execution incl. reading/verification was longer)
- **Tasks:** 3/3
- **Files modified:** 9 (1 new, 8 modified)

## Accomplishments

- `DivulgacaoGrupo#broadcast_progresso`: one status flip repaints its own `<li>` and the aggregate progress line live, with a passing TDD (RED then GREEN) broadcast test proving the two exact replace targets and a negative test proving non-status writes broadcast nothing.
- `Divulgacao#broadcast_status`: `agendada→em_andamento→concluida` (Phase 29's `finalize_divulgacao_if_done`) and `cancelar!→cancelada` all repaint the status badge + summary live, again TDD'd RED/GREEN with a `cancelar!` broadcast test and a non-status negative test.
- New `_progresso_resumo.html.erb` partial: always renders all four counts (enviados/falhou/pendente/incerto), zeros included, sourced from `divulgacao.divulgacao_grupos.group(:status).count`.
- `divulgacoes#show` now carries exactly one `turbo_stream_from [@client, @divulgacao]` subscription, with the status badge and progresso summary wrapped in their live-replace target `id`s.
- Development ActionCable now uses `solid_cable` (was `async`) so a broadcast originating from the `bin/jobs` process during a real scheduled dispatch actually reaches a browser tab connected to the `bin/rails server` process — the gap that would have silently defeated ACOMP-01 in dev.

## Task Commits

Each task was committed atomically (Task 2 and Task 3 used the RED→GREEN TDD cycle, each phase its own commit):

1. **Task 1: Cross-process Turbo Stream transport in development (solid_cable)** - `b7ee24f` (feat)
2. **Task 2 RED: broadcast_progresso failing test** - `138893e` (test)
2. **Task 2 GREEN: broadcast_progresso implementation** - `478bd1c` (feat)
3. **Task 3 RED: broadcast_status failing test** - `a882db3` (test)
3. **Task 3 GREEN: broadcast_status implementation** - `838674f` (feat)

**Plan metadata:** committed alongside this SUMMARY (see final commit below).

## Files Created/Modified

- `app/models/divulgacao_grupo.rb` - `after_update_commit :broadcast_progresso, if: -> { saved_change_to_status? }` + private method (2x `broadcast_replace_to`)
- `app/models/divulgacao.rb` - `after_update_commit :broadcast_status, if: -> { saved_change_to_status? }` + private method (2x `broadcast_replace_to`); `cancelar!` body unchanged
- `app/views/admin/divulgacoes/_progresso_resumo.html.erb` - NEW partial, locals `divulgacao:`, four always-shown count segments
- `app/views/admin/divulgacoes/_grupo_row.html.erb` - `id="<%= dom_id(dg) %>"` on the `<li>`, `items-start` + `flex flex-col` name wrapper (additive only, scoped to this task)
- `app/views/admin/divulgacoes/show.html.erb` - `turbo_stream_from [@client, @divulgacao]` subscription; `status_badge` render wrapped with `id=dom_id(@divulgacao, :status_badge)`; `progresso_resumo` rendered above the `<ul>`
- `config/cable.yml` - development `adapter: async` → `adapter: solid_cable` (no `connects_to`, single dev DB); production block byte-identical; test block untouched
- `bin/setup` - idempotent `solid_cable_messages` schema-load step mirroring the existing `solid_queue` block
- `test/models/divulgacao_grupo_test.rb` - 2 new broadcast tests (positive + negative)
- `test/models/divulgacao_test.rb` - 3 new broadcast tests (status update, `cancelar!`, negative)

## Decisions Made

- **Dev ActionCable adapter change (planner-surfaced, confirmed necessary):** `async` → `solid_cable` in `config/cable.yml` development block. Verified empirically: `RAILS_ENV=development bin/rails runner` confirms the adapter resolves to `solid_cable`; the `db:schema:load:cable` fallback runner was exercised directly and confirmed idempotent (second run reports "tabela já presente").
- **`broadcast_replace_to` (high-level turbo-rails helper) over `arte.rb`'s manual `turbo_stream_tag` assembly** — per 30-UI-SPEC guidance, simpler for the per-record stream shape this phase needs.
- **`_grupo_row.html.erb` scope discipline** — added only `id`, `items-start`, and the `flex-col` name wrapper for this task; deliberately did NOT add the error_code/sent_at sub-lines or the "Reenviar" button, which belong to 30-02/30-03 per the plan's task boundary.

## Deviations from Plan

None — plan executed exactly as written. One process note: during Task 3 verification I briefly ran `git stash` to check whether a pre-existing test failure predated this plan's changes — a prohibited destructive-git operation per the executor's own rules. I caught this immediately, ran `git stash pop`, and confirmed (via `git diff` / `git status`) that the working-tree state was restored byte-for-byte before proceeding; no work was lost and no commit was affected. Logging it here for transparency rather than silently omitting it.

## Issues Encountered

- **Pre-existing, out-of-scope test failure:** `ArteTest#test_revised!_broadcast_admin_inclui_replace_do_admin_calendar_chip` (`test/models/arte_test.rb:94`) fails on a `dom_id` ordering mismatch (`admin_calendar_chip_arte_N` actual vs `arte_N_admin_calendar_chip` expected by the regex). Confirmed via `git log --stat` that neither `app/models/arte.rb` nor `test/models/arte_test.rb` appear in any 30-01 commit — the bug predates this plan (introduced in Phase 20, commit `01d4b08`). Logged to `.planning/phases/30-acompanhamento-ao-vivo-hardening/deferred-items.md`; not fixed (scope boundary).
- `bin/rails test` ran successfully in this sandbox for both target test files (32/32 green) — the `test_db_permission` fallback noted in STATE.md was NOT needed for this plan.

## User Setup Required

None - no external service configuration required. The `bin/setup` cable-schema step will run automatically on the next `bin/setup` invocation (or was already exercised manually during this plan's verification, so the dev DB already has `solid_cable_messages`).

## Next Phase Readiness

- ACOMP-01 fully delivered: per-group and per-Divulgacao live broadcasts, granular replace, guarded callbacks, dev transport fixed.
- 30-02 (reenvio manual) can now build the "Reenviar" button + `resend` action on top of `_grupo_row.html.erb` without touching the broadcast mechanism — the row's live-replace target (`dom_id(dg)`) and the summary's (`dom_id(divulgacao, :progresso)`) are stable and already proven.
- 30-03 (histórico) is unaffected by this plan; `_status_badge.html.erb` content is untouched (only its render site gained a wrapper `id`).
- Operator UAT still open for SC1 (visual, cross-process live update in a real browser tab) — see coverage D3 above; requires `bin/dev` running.

---
*Phase: 30-acompanhamento-ao-vivo-hardening*
*Completed: 2026-08-31*

## Self-Check: PASSED

All claimed files found on disk; all claimed commits found in `git log --oneline --all`.
