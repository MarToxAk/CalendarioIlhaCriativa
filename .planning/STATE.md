---
gsd_state_version: 1.0
milestone: v1.7
milestone_name: WhatsApp Auto-Post + Deploy
current_phase: 25
current_phase_name: Fundação — Transporte Evolution + Storage Alcançável
status: executing
stopped_at: "Completed 25-03-PLAN.md (deploy topology: docker compose + jobs worker + TZ pin + Caddy TLS; production.rb SSL/hosts/:amazon; evolution+aws credentials). INFRA-03 fechado. Próximo: 25-04."
last_updated: "2026-08-30T01:55:06.302Z"
last_activity: 2026-08-29
last_activity_desc: "Plano 25-03 executado — deploy topology docker compose (jobs worker + TZ pin + Caddy proxy), production.rb SSL/hosts/:amazon, evolution+aws em credentials.yml.enc. INFRA-03 fechado."
state_head: af3018684a630f268ad287ef3b0f81c25280c67a
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 4
  completed_plans: 3
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.
**Current focus:** Phase 25 — Fundação — Transporte Evolution + Storage Alcançável

## Current Position

Phase: 25 (Fundação — Transporte Evolution + Storage Alcançável) — EXECUTING
Plan: 4 of 4
Status: Planos 25-01, 25-02 e 25-03 completos. 25-03: ferramenta de deploy = docker compose (Task 1 checkpoint resolvido pelo operador); docker-compose.yml ganha worker `jobs` + `TZ` em web+jobs + proxy Caddy; production.rb -> :amazon + assume_ssl/force_ssl/ssl_options + config.hosts (ilhacriativa.autopyweb.com.br) + host_authorization; blocos evolution: e aws: em credentials.yml.enc (valores do operador). INFRA-03 FECHADO (TZ nos containers + boot check). INFRA-01 parcial: config + credentials prontos; round-trip presignado real de fora da LAN é o 25-04. Topologia real: MinIO externo já TLS-terminado (sem s3. proxy no Caddyfile do app — desvio Rule 2 documentado). Próximo: 25-04 (reachable media: rake de migração de blobs + prova de download externo).
Last activity: 2026-08-29 — Plano 25-03 executado (deploy topology docker compose + production SSL/hosts/:amazon + credentials Evolution/aws)

## Progress Bar

```
v1.7: [███░░░░░░░░░░░░░░░░░] 13% (0/6 phases · 3/4 planos da fase 25)
Phase 25: Fundação — Transporte Evolution + Storage Alcançável — In progress (3/4 planos)
Phase 26: Instância de WhatsApp por Cliente + Pareamento — Not started
Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada — Not started
Phase 28: Divulgação — Agendar sem Enviar — Not started
Phase 29: Motor de Envio — Not started
Phase 30: Acompanhamento ao Vivo + Hardening — Not started
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

## Milestone v1.5 — Shipped

- **Shipped:** 2026-06-09
- **Archived:** 2026-06-09
- **Phases:** 4 (Phase 17–20)
- **Plans:** 13/13 complete
- **Requirements:** 10/10 (CABLE-01, CABLE-02, RTUP-01..08)

## Milestone v1.6 — Shipped

- **Shipped:** 2026-06-13
- **Archived:** 2026-06-13
- **Phases:** 4 (Phase 21–24)
- **Plans:** 16/16 complete
- **Requirements:** 20/20 (AUTH-01..05, APIADM-01..05, APICLI-01..03, APIAI-01..03, INFAPI-01..04)

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
| uat | Phase 17: 17-HUMAN-UAT.md [partial] — 2 cenários (badge/toast, validação visual) | deferred | v1.5 close 2026-06-09 |
| verification | Phase 17: 17-VERIFICATION.md [human_needed] — badge/toast, validação visual | deferred | v1.5 close 2026-06-09 |
| uat | Phase 18: 18-HUMAN-UAT.md [partial] — linhas ao vivo dashboard/aprovações (validação visual) | deferred | v1.5 close 2026-06-09 |
| verification | Phase 18: 18-VERIFICATION.md [human_needed] — broadcasts admin, validação visual | deferred | v1.5 close 2026-06-09 |
| uat | Phase 23: 23-HUMAN-UAT.md [partial] — 2 cenários pendentes (execução de testes automatizados de integração) | deferred | v1.6 close 2026-06-13 |
| verification | Phase 23: 23-VERIFICATION.md [human_needed] — endpoints cliente, aguarda execução de testes | deferred | v1.6 close 2026-06-13 |

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

- `/gsd-new-milestone` — iniciar v1.7 (Swagger/OpenAPI, deploy S3, ou notificações por e-mail)

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 19 P00 | 30min | 3 tasks | 7 files |
| Phase 19 P01 | 20min | 2 tasks | 1 file |
| Phase 20 P00 | 7 | 2 tasks | 3 files |
| Phase 20 P01 | 15 | 3 tasks | 4 files |
| Phase 21 P01 | 15 | 2 tasks | 4 files |
| Phase 21 P02 | 15 | 2 tasks | 3 files |
| Phase 21-funda-o-da-api-autentica-o P03 | 142 | 2 tasks | 2 files |
| Phase 21 P04 | 10 minutes | 2 tasks | 3 files |
| Phase 21 P05 | 20 minutes | 2 tasks | 4 files |
| Phase 22-endpoints-admin P01 | 10 minutes | 2 tasks | 5 files |
| Phase 22-endpoints-admin P03 | 2 minutes | 2 tasks | 4 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 25 P01 | 11min | 3 tasks | 9 files |
| Phase 25 P02 | 35min | 3 tasks | 7 files |
| Phase 25 P03 | 15min | 3 tasks | 5 files |

## Decisions

- [Phase 19]: Arte#broadcasts_revised_to_all callback — after_update_commit condicional, guard saved_change_to_status? && revised?
- [Phase 19]: Broadcast duplo por transação: ClientCalendarChannel (3 streams) + AdminNotificationsChannel (1 stream)
- [Phase 19]: ActionView::RecordIdentifier.dom_id() para geração segura de IDs no model
- [Phase 20 P00]: ring-inset em arte_status_ring_class — evita expansão do layout no chip compacto (px-1 py-0.5 text-xs)
- [Phase 20 P00]: Hex values copiados literalmente do STATUS_MAP JS — approved #14A958, change_requested #EE3537, revised #475569
- [Phase 20 P01]: broadcasts_to_admin gera 5 turbo-streams (chip replace adicionado após approvals) — RTUP-08 closed for approved+change_requested
- [Phase 20 P01]: admin_stream em Arte transformado em array de 2 elementos (badge + chip replace) via .join — RTUP-08 closed for revised
- [Phase ?]: anti-enumeration for inactive clients
- [Phase 21-05]: Admin login API field is `email` (maps to User#email_address) — downstream phases 22/23 must send field `email`, not `email_address`
- [Phase 21-05]: jwt_secret and api.ai_key provisioned via Rails encrypted credentials (not ENV) — production-safe, encrypted at rest
- [Phase ?]: Phase 22-03: ArtesController usa params.permit flat (sem .require(:arte)) e apply_filters com Arte.statuses.key? + Date.strptime guards; validates :media_file ASVS L1 adicionado ao model
- [Phase 25]: [Phase 25-01]: Evolution:: config vive em app/services/evolution.rb (namespace explícito) — module Evolution num initializer quebra o autoload do Zeitwerk para Evolution::Errors
- [Phase 25]: [Phase 25-01]: EVO-01 (round-trip autenticado real contra o host da agência) DEFERIDO — EVOLUTION_BASE_URL/EVOLUTION_GLOBAL_API_KEY indisponíveis; artefatos de código entregues, fechamento aguarda credenciais (user_setup, D-06)
- [Phase 25]: [Phase 25-01]: fugit permanece no lockfile — dep transitiva de solid_queue (~> 1.11), não exclusiva do good_job
- [Phase 25]: [Phase 25-02]: storage.yml serviço amazon = S3 driver contra endpoint MinIO, force_path_style: true, bucket calendario-livia-#{Rails.env}, privado (sem chave public — toda mídia é presigned); endpoint ENV-first (S3_ENDPOINT) e chaves credentials-only
- [Phase 25]: [Phase 25-02]: development.rb usa solid_queue como queue_adapter SEM connects_to — dev tem base única; tabelas solid_queue_* vivem na base primária, carregadas por bin/setup (db:schema:load:queue com fallback runner idempotente)
- [Phase 25]: [Phase 25-02]: timezone_check.rb — raise em produção / warn (Rails.logger + $stderr) em development quando ENV['TZ'] != America/Sao_Paulo ou Time.zone != Brasilia; default_timezone = :local mantido (Out of Scope migrar p/ :utc)
- [Phase 25]: [Phase 25-02]: INFRA-01/SC1 (round-trip presignado real MinIO) deferido como user_setup — MinIO não provisionado; config entregue (6ce3a06). Consistente com EVO-01 no 25-01
- [Phase 25]: [Phase 25-03]: ferramenta de deploy = docker compose (estende docker-compose.yml hand-rolled; Kamal não adotado — config/deploy.yml + .kamal/ ficam como scaffolding morto). Task 1 checkpoint:decision resolvido pelo operador.
- [Phase 25]: [Phase 25-03]: topologia real (Deviation Rule 2) — MinIO/Evolution já live e TLS-terminados em infra separada (bomcustoilhabela.com.br); app deploya em ilhacriativa.autopyweb.com.br. Caddyfile do app tem 1 site block (web:3000); MinIO alcançado via aws.endpoint externo, sem bloco s3. proxied (deixado comentado p/ forward-compat).
- [Phase 25]: [Phase 25-03]: INFRA-03 COMPLETO — TZ=America/Sao_Paulo em web+jobs no docker-compose.yml + boot check timezone_check.rb (25-02). Boot real de produção com TZ correto passou. INFRA-01 continua parcial: config+credentials prontos, round-trip presignado real é 25-04.

## Quick Tasks Completed

| Date | Slug | Description | Status |
|------|------|-------------|--------|
| 2026-06-08 | fix-client-media-display | Corrigir visualização de media (vídeo e imagem) no portal do cliente, tratando mismatch de enums e melhorando proxying. | complete ✓ |

## Session

**Last session:** 2026-08-30T01:55:05.579Z
**Stopped at:** Completed 25-03-PLAN.md (deploy topology: docker compose + jobs worker + TZ pin + Caddy TLS; production.rb SSL/hosts/:amazon; evolution+aws credentials). INFRA-03 fechado. Próximo: 25-04.
**Resume file:** None

### Blockers

- EVO-01 / SC2: round-trip autenticado do Evolution::Client contra whatsapp.bomcustoilhabela.com.br ainda não executado. As credenciais (EVOLUTION_BASE_URL + EVOLUTION_GLOBAL_API_KEY) foram fornecidas pelo operador e escritas em config/credentials.yml.enc no 25-03 — o probe pode ser rodado agora (25-04 ou fase 26). Só falta executá-lo.
- INFRA-01 / SC1: round-trip presignado real contra o MinIO originado de fora de 192.168.3.203 ainda não executado — é o plano 25-04 e exige o serviço MinIO acessível. Metade config pronta: storage.yml `amazon` (25-02), production.rb -> :amazon + blocos aws: em credentials.yml.enc com os valores do operador (25-03, `af30186`). S3_ENDPOINT externo (`s3.bomcustoilhabela.com.br`) já está no aws.endpoint. Requisito não marcado completo até o 25-04.
- RECOMENDAÇÃO (não bloqueia): aws.access_key_id/secret_access_key gravados são as credenciais ROOT do MinIO. Emitir uma access key com escopo dos buckets calendario-livia-* e rotacionar o bloco aws: antes/logo após o go-live.

**Resolvido nesta sessão (25-03):**

- ~~INFRA-03 / SC5 (metade deploy)~~: RESOLVIDO. `TZ: America/Sao_Paulo` no `environment:` dos serviços `web` E `jobs` do docker-compose.yml (`4557abb`), somado ao boot check `config/initializers/timezone_check.rb` do 25-02 (`7f319a1`). Boot real de produção com TZ correto completou sem aviso; sem o TZ o timezone_check.rb abortaria o boot. INFRA-03 marcado COMPLETO em REQUIREMENTS.md.

**Resolvido em sessão anterior (25-02):**

- ~~INFRA-02 / SC4~~: RESOLVIDO. Gate de restart executado pelo orquestrador com probe job em disco contra worker bin/jobs real — job enfileirado 17:35:34-03:00, worker parado 17:35:49, reiniciado 17:36:43, job disparou 17:37:04 (21s após o restart), zero falhas. Linha durável sobreviveu em solid_queue_scheduled_executions. Timeline verbatim no 25-02-SUMMARY.md. INFRA-02 marcado completo em REQUIREMENTS.md.
