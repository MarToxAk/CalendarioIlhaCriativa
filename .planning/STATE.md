---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Real-time & Notifications
status: planning
last_updated: "2026-06-05T00:00:00.000Z"
last_activity: 2026-06-05
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-05)

**Core value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.
**Current focus:** v1.5 Real-time & Notifications — defining requirements

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-06-05 — Milestone v1.5 started

## Progress Bar

```
v1.5: (phases TBD — roadmap em construção)
```

## Milestone v1.0 — Shipped

- **Shipped:** 2026-05-27
- **Archived:** 2026-06-02
- **Phases:** 8 (1, 2, 2.1, 3, 3.1, 4, 5, 6)
- **Plans:** 23/23 complete
- **Requirements:** 35/35 v1 requirements implemented

## Milestone v1.1 — Shipped

- **Shipped:** 2026-06-02
- **Archived:** 2026-06-02
- **Phases:** 2 (Phase 7 + Phase 7.1)
- **Plans:** 5/5 complete
- **Requirements:** 3/3 (ARTE-08, ARTE-09, ARTE-10)

## Milestone v1.2 — Shipped

- **Shipped:** 2026-06-03
- **Archived:** 2026-06-03
- **Phases:** 2 (Phase 8 + Phase 9)
- **Plans:** 2/2 complete
- **Requirements:** 3/3 (APRO-01, APRO-02, CAL2-01)

## Milestone v1.3 — Shipped

- **Shipped:** 2026-06-03
- **Archived:** 2026-06-03
- **Phases:** 3 (Phase 10, 11, 12)
- **Plans:** 5/5 complete
- **Requirements:** 6/6 (FORM-01..03, PAGE-01..02, IDX-01..02, SHOW-01, DASH-01)

## Milestone v1.5 — In Progress

- **Started:** 2026-06-05
- **Goal:** Real-time & Notifications via ActionCable/Turbo Streams

## Milestone v1.4 — Shipped

- **Shipped:** 2026-06-04
- **Archived:** 2026-06-04
- **Phases:** 4 (Phase 13–16)
- **Plans:** 11/11 complete
- **Requirements:** 16/16 (APRO-03..07, CADM-01..05, CONF-01..03, FERI-01..03)

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| tech-debt | Sidebar links "Aprovações" e "Calendário" apontam para `#` | deferred (resolvido em v1.4 fase 13+14) | v1.0 close |
| tech-debt | Nyquist validation ausente em fases 1, 2, 3 | deferred | v1.0 close |
| tech-debt | Active Storage S3 para produção | deferred | v1.0 close |
| uat | Phase 02: 02-HUMAN-UAT.md [partial] — 4 cenários pendentes (fases v1.0 já arquivadas) | deferred | v1.1 close 2026-06-02 |
| uat | Phase 03.1: 03.1-HUMAN-UAT.md [partial] — 3 cenários pendentes (fases v1.0 já arquivadas) | deferred | v1.1 close 2026-06-02 |
| uat | Phase 05: 05-HUMAN-UAT.md [partial] — 5 cenários pendentes (fases v1.0 já arquivadas) | deferred | v1.1 close 2026-06-02 |
| verification | Phase 02: 02-VERIFICATION.md [human_needed] (fase v1.0 já arquivada) | deferred | v1.1 close 2026-06-02 |
| verification | Phase 03.1: 03.1-01-VERIFICATION.md [human_needed] (fase v1.0 já arquivada) | deferred | v1.1 close 2026-06-02 |
| verification | Phase 05: 05-VERIFICATION.md [human_needed] (fase v1.0 já arquivada) | deferred | v1.1 close 2026-06-02 |
| uat | Phase 08: 08-HUMAN-UAT.md — SC3 badge calendário (validação visual) | deferred | v1.2 close 2026-06-03 |
| uat | Phase 09: 09-HUMAN-UAT.md — SC3 mobile, SC4 pós-aprovação, mês vazio (validação visual) | deferred | v1.2 close 2026-06-03 |
| code-quality | Phase 09: CR-01 parse_month_param não faz rescue TypeError (array param → 500) | deferred | v1.2 close 2026-06-03 |
| verification | Phase 08: 08-VERIFICATION.md [human_needed] — bug aprovação, validação visual | deferred | v1.3 close 2026-06-03 |
| verification | Phase 09: 09-VERIFICATION.md [human_needed] — faixa resumo, validação visual | deferred | v1.3 close 2026-06-03 |
| uat | Phase 10: 10-HUMAN-UAT.md [partial] — 3 cenários form polish (validação visual) | deferred | v1.3 close 2026-06-03 |
| verification | Phase 10: 10-VERIFICATION.md [human_needed] — arte form polish, validação visual | deferred | v1.3 close 2026-06-03 |
| uat | Phase 11: 11-HUMAN-UAT.md [partial] — 4 cenários index polish (validação visual) | deferred | v1.3 close 2026-06-03 |
| verification | Phase 11: 11-01-VERIFICATION.md [human_needed] — arte index polish, validação visual | deferred | v1.3 close 2026-06-03 |
| uat | Phase 12: 12-HUMAN-UAT.md [partial] — 3 cenários show+dashboard (validação visual, turbo_confirm) | deferred | v1.3 close 2026-06-03 |
| verification | Phase 12: 12-01-VERIFICATION.md [human_needed] — arte show+dashboard, validação visual | deferred | v1.3 close 2026-06-03 |
| uat | Phase 13: 13-HUMAN-UAT.md [human_needed] — validação visual da página Aprovações (score 15/15) | deferred | v1.4 close 2026-06-04 |
| verification | Phase 13: 13-VERIFICATION.md [human_needed] — validação visual da página Aprovações (score 15/15) | deferred | v1.4 close 2026-06-04 |
| uat | Phase 14: 14-HUMAN-UAT.md [human_needed] — validação visual do calendário admin (score 9/9) | deferred | v1.4 close 2026-06-04 |
| verification | Phase 14: 14-VERIFICATION.md [human_needed] — validação visual do calendário admin (score 9/9) | deferred | v1.4 close 2026-06-04 |

## Accumulated Context

### Roadmap Evolution

- Phase 07.1 inserted after Phase 7: Fix: media_source params + destroy feedback + SC3 UI (URGENT)
- v1.2 roadmap defined 2026-06-02: Phase 8 (bug aprovação) + Phase 9 (faixa de resumo)
- v1.3 roadmap defined 2026-06-03: Phase 10 (form polish) + Phase 11 (index polish) + Phase 12 (show + dashboard)
- v1.4 roadmap defined 2026-06-04: Phase 13 (aprovações) + Phase 14 (calendário admin) + Phase 15 (configurações) + Phase 16 (feriados brasileiros)

### v1.5 Context

- ActionCable disponível no Rails 8.1.3 — sem gem adicional necessária
- Adapter PostgreSQL para ActionCable (sem Redis) — config: `config/cable.yml`
- Autenticação ActionCable: admin usa Session (cookie), cliente usa token de URL
- Turbo Streams via cable_ready: broadcast direto do model callback
- Toast system: Stimulus controller global montado no layout admin e no layout do cliente
- Badge sidebar: counter calculado via Arte.where(decision: :change_requested, status: not :revised)

### v1.4 Context (SHIPPED 2026-06-04)

- Sidebar "Aprovações" e "Calendário" wired (fases 13 e 14)
- Cor por cliente derivada deterministicamente via `client.id % 8` — não requer coluna de cor no model
- agency_name adicionado à tabela users (migração 20260604121724) com default "Ilha Criativa"
- Rack::Attack rate-limit interferia em testes de controller com múltiplos `post session_path` — fix: `Rack::Attack.cache.store.clear` no setup de testes
- BrazilianHolidays module em app/lib/ (autoloaded) com 17+ feriados/comemorativos 2025-2027

## Operator Next Steps

- Roadmap em construção — run `/gsd-plan-phase 17` quando roadmap estiver pronto
