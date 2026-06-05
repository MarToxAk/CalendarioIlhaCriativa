---
gsd_state_version: 1.0
milestone: v1.5
milestone_name: Real-time & Notifications
status: executing
last_updated: "2026-06-05T17:15:00.000Z"
last_activity: 2026-06-05 -- Phase 18 all plans executed (awaiting verification)
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 7
  completed_plans: 7
  percent: 57
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-05)

**Core value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.
**Current focus:** Phase 18 — approvalresponse-broadcast-admin-live-rows

## Current Position

Phase: 18 (approvalresponse-broadcast-admin-live-rows) — EXECUTING
Plan: 1 of 3
Status: Executing Phase 18
Last activity: 2026-06-05 -- Phase 18 execution started

## Progress Bar

```
v1.5: [░░░░░░░░░░░░░░░░░░░░] 0% (0/4 phases)
Phase 17: Cable Foundation + Admin Channel + Badge + Toast — Not started
Phase 18: ApprovalResponse Broadcast + Admin Live Rows — Not started
Phase 19: Client Real-time + Arte Status Broadcast — Not started
Phase 20: Admin Calendar Chips Real-time — Not started
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

## Milestone v1.4 — Shipped

- **Shipped:** 2026-06-04
- **Archived:** 2026-06-04
- **Phases:** 4 (Phase 13–16)
- **Plans:** 11/11 complete
- **Requirements:** 16/16 (APRO-03..07, CADM-01..05, CONF-01..03, FERI-01..03)

## Milestone v1.5 — In Progress

- **Started:** 2026-06-05
- **Goal:** Real-time & Notifications via ActionCable/Turbo Streams
- **Phases:** 4 (Phase 17–20)
- **Plans:** 0/11 complete
- **Requirements:** 0/10 (CABLE-01, CABLE-02, RTUP-01..08)

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
- v1.5 roadmap defined 2026-06-05: Phase 17 (cable foundation + badge + toast) + Phase 18 (approval broadcasts) + Phase 19 (client real-time) + Phase 20 (admin calendar chips)

### v1.5 Context

- ActionCable disponível no Rails 8.1.3 — sem gem adicional necessária
- Adapter PostgreSQL para ActionCable (sem Redis) — config: `config/cable.yml`
- Autenticação ActionCable: admin usa Session (cookie), cliente usa token de URL via params[:token]
- connection.rb deve permitir admin e cliente; canais individuais fazem reject se não autorizado
- Turbo Streams via cable_ready: broadcast direto do model callback
- Toast system: Stimulus controller global (toast_controller.js) montado no layout admin e no layout do cliente
- Badge sidebar: counter calculado via ApprovalResponse com decision :change_requested onde arte.status != :revised
- solid_cable já instalado — usa PostgreSQL sem Redis
- _approval_row.html.erb já existe (Phase 13) — reutilizar
- id="sidebar-badge", id="admin-toast-region", id="client-toast-region" — IDs de target para broadcasts
- turbo_stream_from "admin_notifications" vai no layout admin (Phase 17)
- ClientCalendarChannel subscribing a "client_calendar_#{client.access_token}"

### v1.4 Context (SHIPPED 2026-06-04)

- Sidebar "Aprovações" e "Calendário" wired (fases 13 e 14)
- Cor por cliente derivada deterministicamente via `client.id % 8` — não requer coluna de cor no model
- agency_name adicionado à tabela users (migração 20260604121724) com default "Ilha Criativa"
- Rack::Attack rate-limit interferia em testes de controller com múltiplos `post session_path` — fix: `Rack::Attack.cache.store.clear` no setup de testes
- BrazilianHolidays module em app/lib/ (autoloaded) com 17+ feriados/comemorativos 2025-2027

## Operator Next Steps

- Roadmap v1.5 pronto — run `/gsd-plan-phase 17`
