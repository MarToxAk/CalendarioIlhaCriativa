---
gsd_state_version: 1.0
milestone: v1.7
milestone_name: WhatsApp Auto-Post + Deploy
current_phase: 30
current_phase_name: Acompanhamento ao Vivo + Hardening
status: planning
stopped_at: "Fase 30 executada (4/4 planos), code review convergiu em 3 iterações (2 Critical + 2 Warning corrigidos), verificação 3/5 (human_needed) — persistida em 30-UAT.md. Milestone v1.7 com todas as 6 fases executadas/code-verificadas, 4 aguardando UAT do operador (25, 26, 29, 30)."
last_updated: "2026-08-31T14:35:00.000Z"
last_activity: 2026-08-31
last_activity_desc: "Phase 30 execution + code review (converged) + verification complete; deferred to operator UAT (30-UAT.md, 3 items)"
state_head: e91a7ac
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 28
  completed_plans: 28
  percent: 33
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-29)

**Core value:** O cliente consegue aprovar ou pedir alteração em cada arte sem precisar de conta — só com o link — e o admin vê tudo num só lugar.
**Current focus:** Phase 30 — Acompanhamento ao Vivo + Hardening

## Deferred Verification

| Phase | State | Resume |
|-------|-------|--------|
| 25 | verification_deferred_human | /gsd-verify-work 25 |
| 26 | verification_deferred_human | /gsd-verify-work 26 |
| 29 | verification_deferred_human | /gsd-verify-work 29 |
| 30 | verification_deferred_human | /gsd-verify-work 30 |

## Current Position

Phase: 30 (Acompanhamento ao Vivo + Hardening) — EXECUTED, aguardando UAT do operador
Plans complete: 01, 02, 03, 04 of 4 (all plans executed — 04 ran out of sequence, wave 1, no dependencies)
Status: Code review convergiu (3 iterações, clean); verificação 3/5 (human_needed) — 30-UAT.md com 3 itens
  pendentes (SC1 progresso ao vivo cross-processo, SC2 confirmação visual do reenvio, SC5 retenção
  seletiva). ACOMP-02, ACOMP-03 e SEG-04 totalmente satisfeitos e comprovados por teste.
  Milestone v1.7 (6 fases) 100% executada; lifecycle (audit → complete → cleanup) aguarda o operador
  rodar /gsd-verify-work em 25, 26, 29 e 30.
Last activity: 2026-08-31 - Completed quick task 260831-hhw: Corrigir URL pública do MinIO/S3 quebrada (NoSuchKey)

## Progress Bar

```
v1.7: [███░░░░░░░░░░░░░░░░░] 15% (0/6 phases · 5/5 planos da fase 25 — orquestrador no tail da fase)
Phase 25: Fundação — Transporte Evolution + Storage Alcançável — 5/5 planos executados (aguardando o tail da fase: aggregate / code-review / verify)
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
| Phase 25 P04 | ~40min | 2 tasks | 3 files |
| Phase 25 P05 | ~12 min | 8 tasks | 6 files |
| Phase 26 P01 | ~45min | 2 tasks | 18 files |
| Phase 26 P02 | 12min | 2 tasks | 5 files |
| Phase 26 P03 | ~25min | 2 tasks | 4 files |
| Phase 26 P04 | ~10min | 2 tasks | 4 files |
| Phase 26-inst-ncia-de-whatsapp-por-cliente-pareamento P05 | ~15min | 3 tasks | 9 files |
| Phase 30 P01 | ~25min | 3 tasks | 9 files |
| Phase 30 P04 | ~15min | 2 tasks | 3 files |
| Phase 30 P02 | ~20min | 2 tasks | 5 files |
| Phase 30 P03 | ~15min | 3 tasks | 8 files |

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
- [Phase 25]: [Phase 25-04]: storage:migrate_to_s3 entregue verbatim (RESEARCH Pattern 6 + Pitfall 6) — copy-only, idempotente, backfill service_name where(nil,'local'); sem exception-swallow em volta de dest.exist?/upload (abortar alto é o comportamento correto).
- [Phase 25]: [Phase 25-04]: EVO-01 outbound FECHADO — Evolution::Client.fetch_instances -> Array[6]/200/~654ms com as credenciais do 25-03. Encerra o blocker de round-trip autenticado de leitura do 25-01.
- [Phase 25]: [Phase 25-04]: INFRA-01 COMPLETO — causa raiz do endpoint corrigida: s3.bomcustoilhabela.com.br era o CONSOLE do MinIO; a API S3 e minio.bomcustoilhabela.com.br (aws.endpoint em credentials.yml.enc atualizado, commit 947413f). Buckets calendario-livia-{development,production} criados privados. storage:migrate_to_s3 provada ponta a ponta contra o DB de dev (copied 12, backfill 12, 2a rodada no-op; 2 orfaos de probe.txt removidos). SC1 provado: presigned GET buscado de FORA de 192.168.3.203 (DNS publico -> Cloudflare -> MinIO) -> HTTP/2 200 + content-type correto. Rodar a migracao no host de producao = passo de operador de go-live, nao gate da fase.
- [Phase 25]: [Phase 25-04]: Inbound /up do host do Evolution carregado adiante para operador / fase 26 (app nao deployado em ilhacriativa.autopyweb.com.br) — nao bloqueia a fase 25 (D-12 / A4: fase 26 lidera com PAIR-05).
- [Phase 25]: 25-04: aws.endpoint corrigido — s3.bomcustoilhabela.com.br era o console do MinIO; a API S3 e minio.bomcustoilhabela.com.br (947413f)
- [Phase 25]: 25-04: buckets calendario-livia-{development,production} criados privados (sem bucket policy, default MinIO)
- [Phase 25]: 25-04: INFRA-01 SC1 provado em development — presigned GET buscado de fora da LAN (DNS publico -> Cloudflare -> MinIO) -> HTTP/2 200 + content-type correto; storage:migrate_to_s3 provada ponta a ponta (copied 12, backfill 12, 2a rodada no-op)
- [Phase 25]: [25-05]: CR-02 fechado SEM fallback de CORS_ORIGINS em config/application.rb — a KeyError visivel em producao continua sendo o contrato; fix = prover a var no compose (web+jobs) + documentar no .env.example
- [Phase 25]: [25-05]: guards de build usam ENV[SECRET_KEY_BASE_DUMMY] (setada so pelo Rails em assets:precompile) em timezone_check.rb + evolution.rb — verificado que boot de runtime real sem essa var e sem TZ correto AINDA aborta (CR-01)
- [Phase 25]: [25-05]: WR-07 endurece so o caminho de erro (2xx nao-JSON -> Evolution::Errors::Unknown com msg estatica); connection_state segue retornando a string de estado crua no caminho feliz — COVERAGE.md nao muda
- [Phase 25]: [25-05]: suite bin/rails test nao executavel (PG::InsufficientPrivilege — banco de teste de outro usuario do SO); WR-01/WR-07 verificados por inspecao + bin/rails runner com conexao Faraday stub
- [Phase 26]: [Phase 26-01]: removida config/credentials/development.yml.enc órfã (não rastreada, vazia) que sombreava config/credentials.yml.enc em RAILS_ENV=development — Rails.application.credentials resolve por-env antes do arquivo único; sem essa remoção Evolution.base_url/global_api_key e as novas chaves de active_record_encryption ficariam invisíveis em dev
- [Phase 26]: [Phase 26-01]: chaves active_record_encryption + evolution.webhook_hmac_key/webhook_base_url gravadas via Rails.application.credentials.write (API programática, sem EDITOR interativo) mesclando com o conteúdo existente — evolution.base_url/global_api_key/aws/jwt_secret/api preservados
- [Phase 26]: [Phase 26-01]: InstanceProvisioner nesta task cobre SOMENTE o caminho de criação (create_instance -> persist_new) — adoção (403 already in use -> adopt) fica para 26-02, sem rescue prematuro
- [Phase 26]: [Phase 26-02]: InstanceProvisioner#call rescue Evolution::Errors::Permanent seletivo (/already in use/i) -> desvia para #adopt; qualquer outro Permanent continua subindo cru para o controller
- [Phase 26]: [Phase 26-02]: adopt() chama set_webhook SEMPRE antes de ler connection_state (Pitfall 4) -- sem essa ordem o painel trava em 'aguardando pareamento'
- [Phase 26]: [Phase 26-02]: Admin::WhatsappInstancesController#create e #adopt convergem no mesmo InstanceProvisioner#call -- adocao acontece automaticamente dentro de #create quando o Evolution devolve 'already in use', sem exigir clique extra do admin
- [Phase 26]: [Phase 26]: [Phase 26-03]: Webhooks::EvolutionController hashea os dois lados (SHA256) antes de secure_compare — nunca compara os valores crus, que podem ter comprimentos diferentes e levantar ArgumentError vazando o tamanho do segredo
- [Phase 26]: [Phase 26]: [Phase 26-03]: throttle webhooks/evolution_by_ip (120/60s) cai no ramo HTML de throttled_responder (path não começa com /api/) — aceitável, o chamador é uma máquina que ignora o corpo
- [Phase 26]: 26-04: verify — falha de TRANSPORTE em connection_state nunca toca o banco (connection_state/last_checked_at ficam com o último valor conhecido); um estado close/refused lido COM SUCESSO atualiza o banco normalmente, é resultado válido, não falha.
- [Phase 26]: 26-04: refresh_qr é a única ação JSON do controller — sempre render json:, mesmo quando pull_fresh_qr falha silenciosamente. Rails.cache.write(key, true, unless_exist:true, expires_in:15.seconds) throttla a 1 chamada Evolution::Client.connect por instância a cada 15s.
- [Phase 30]: [Phase 30-01]: dev ActionCable adapter async -> solid_cable (planner-surfaced) — bin/jobs is the first process to originate a broadcast; async is in-process only, would never reach the web process browser
- [Phase 30]: [Phase 30-01]: broadcast_replace_to (turbo-rails high-level helper) used for DivulgacaoGrupo/Divulgacao live broadcasts instead of arte.rb's manual turbo_stream_tag assembly
- [Phase 30]: [Phase 30]: [Phase 30-04]: SEG-04 send-path test disconnects client A's OWN instance to trigger the existing instance&.connected? guard on a force-built poisoned cross-client row -- the job has no dedicated cross-client check of its own; that barrier lives only at creation time (SEG-02), proven separately by the two mutation-sensitive assert_raises(RecordNotFound) units.
- [Phase 30]: [Phase 30]: [Phase 30-04]: INFRA-07 recurring.yml commands use YAML single-quoted scalars (doubled '' for the embedded Ruby 'created_at < ?' literal) so the raw file contains literal double-quoted ENV.fetch args, matching the plan's exact grep acceptance criteria; discard_all_in_batches confirmed scope-honoring against vendored execution.rb:30-50 and functionally proven in development (seeded old+recent FailedExecution/Job pairs, ran the real command, rolled back).
- [Phase 30]: [Phase 30-02]: resend route uses controller: "divulgacoes" override on the nested divulgacao_grupos resource to keep #resend on Admin::DivulgacoesController
- [Phase 30]: [Phase 30-03]: divulgacao_grupo_error_label is a pure copy-map (sentinel hash lookup or a "Motivo: " prefix) — never re-runs Phase 29's sanitize_error_code, never truncates/gsubs, never re-fetches the model (T-30-10); divulgacao_placar reads divulgacao.divulgacao_grupos.to_a (the includes-preloaded association) so it never issues its own query (T-30-11)

## Quick Tasks Completed

| Date | Slug | Description | Status |
|------|------|-------------|--------|
| 2026-06-08 | fix-client-media-display | Corrigir visualização de media (vídeo e imagem) no portal do cliente, tratando mismatch de enums e melhorando proxying. | complete ✓ |
| 2026-08-31 | 260831-gai-preciso-corrigir-a-quest-o-de-grupos-do- | Corrigir sincronização de grupos do WhatsApp (Evolution::Client.fetch_groups estourava timeout de 15s em instâncias reais; timeout dedicado de 60s criado). | complete ✓ |
| 2026-08-31 | 260831-hh4-corrigir-tags-de-pagina-o-pagy-nav-escap | Corrigir pagy_nav aparecendo como HTML escapado (texto cru) no rodapé das telas de grupos do WhatsApp e aprovações — trocado <%= por <%== nos dois call-sites. | complete ✓ |
| 2026-08-31 | 260831-hhw-gostaria-de-arrumar-o-s3-uso-o-minio-upl | Corrigir URL pública do MinIO/S3 quebrada (NoSuchKey) — storage:migrate_to_s3 marcava blobs "MISSING at source" como service_name amazon sem o arquivo existir no bucket; backfill agora escopado aos blobs confirmados no destino. | complete ✓ |

## Session

**Last session:** 2026-08-31T13:36:52.000Z
**Stopped at:** Completed 30-03-PLAN.md
**Resume file:** None

### Blockers

**Nenhum blocker aberto na fase 25.** O gate blocking-human do 25-04 foi resolvido: o orquestrador rodou todos os passos empiricos e o executor dobrou os resultados nos artefatos.

**Resolvido nesta sessão (25-04):**

- ~~INFRA-01 / SC1 — endpoint MinIO mal configurado~~: RESOLVIDO. Causa raiz: `s3.bomcustoilhabela.com.br` serve o CONSOLE do MinIO (porta 9001, HTML); a API S3 e `minio.bomcustoilhabela.com.br` (`GET /` -> XML `<Error><Code>AccessDenied</Code>` + `x-amz-request-id`). `aws.endpoint` em `config/credentials.yml.enc` corrigido para `https://minio.bomcustoilhabela.com.br` (commit `947413f`). Buckets `calendario-livia-{development,production}` criados privados (sem bucket policy).
- ~~INFRA-01 / SC1 — download presignado de fora da LAN~~: RESOLVIDO em development. `create_and_upload!` -> `blob.url(expires_in: 10.minutes)` -> fetch EXTERNO da presigned URL (host `minio.bomcustoilhabela.com.br` -> DNS publico -> edge Cloudflare -> MinIO; request saiu pela internet publica, nao pela LAN): `HTTP/2 200`, `content-type: text/plain`, `content-length: 28`, `content-disposition: attachment; filename="probe25.txt"`, corpo confere. `bin/rails storage:migrate_to_s3` rodada real (dev DB): `copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12` (os 2 missing eram orfaos de probe.txt #13/#14 sem arquivo, removidos depois); 2a rodada so-skip; os 12 blobs baixam OK por presigned URL nova. INFRA-01 marcado COMPLETO em REQUIREMENTS.md.
- ~~EVO-01 / SC2 (outbound) — round-trip autenticado de leitura~~: RESOLVIDO. `Evolution::Client.fetch_instances` (apikey global de credentials.yml.enc, contra `whatsapp.bomcustoilhabela.com.br`) retornou `Array` com 6 instancias, HTTP 200, latencia ~654ms (medido em RAILS_ENV=development). Registrado em `evolution-contract.md` §"Deploy reachability (phase 25)". EVO-01 marcado COMPLETO em REQUIREMENTS.md. Caminho de escrita (`sendText`/`sendMedia`, teto de midia, casing de webhook) permanece PENDENTE por D-08 (fases 26/28/29).

**Carregado adiante (operador / fase 26 — NAO bloqueia a fase 25):**

- **Migração no host deployado (DB de produção, bucket `calendario-livia-production`).** `bin/rails storage:migrate_to_s3` rodou contra o DB de development para provar a task ponta a ponta; o DB de produção nao e alcançavel daqui. Rodar a mesma task no host deployado e passo de operador de go-live, nao gate da fase 25.
- **Inbound `/up` do host do Evolution.** `curl -sS -I https://<app-hostname>/up` do host do Evolution -> colar linha de status. O app ainda nao esta deployado em `ilhacriativa.autopyweb.com.br`. Falha = registrada, NAO bloqueia a fase 25 (D-12 / A4 — a fase 26 lidera com o botao PAIR-05).
- **RECOMENDAÇÃO de segurança (não bloqueia):** `aws.access_key_id`/`secret_access_key` gravados sao as credenciais ROOT do MinIO. Emitir uma access key com escopo dos buckets `calendario-livia-*` e rotacionar o bloco `aws:` antes/logo apos o go-live (repetido de 25-03).

**Resolvido nesta sessão (25-03):**

- ~~INFRA-03 / SC5 (metade deploy)~~: RESOLVIDO. `TZ: America/Sao_Paulo` no `environment:` dos serviços `web` E `jobs` do docker-compose.yml (`4557abb`), somado ao boot check `config/initializers/timezone_check.rb` do 25-02 (`7f319a1`). Boot real de produção com TZ correto completou sem aviso; sem o TZ o timezone_check.rb abortaria o boot. INFRA-03 marcado COMPLETO em REQUIREMENTS.md.

**Resolvido em sessão anterior (25-02):**

- ~~INFRA-02 / SC4~~: RESOLVIDO. Gate de restart executado pelo orquestrador com probe job em disco contra worker bin/jobs real — job enfileirado 17:35:34-03:00, worker parado 17:35:49, reiniciado 17:36:43, job disparou 17:37:04 (21s após o restart), zero falhas. Linha durável sobreviveu em solid_queue_scheduled_executions. Timeline verbatim no 25-02-SUMMARY.md. INFRA-02 marcado completo em REQUIREMENTS.md.
