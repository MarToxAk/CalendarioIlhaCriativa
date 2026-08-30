# Roadmap: Calendário de Aprovação de Artes

## Milestones

- ✅ **v1.0 MVP** — Fases 1–6 + 2.1 + 3.1 (shipped 2026-05-27) → [Archive](.planning/milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Fix Art Upload & Client Association** — Fases 7 + 7.1 (shipped 2026-06-02) → [Archive](.planning/milestones/v1.1-ROADMAP.md)
- ✅ **v1.2 Calendar Summary & Approval Fix** — Fases 8 + 9 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 Arte UI Polish** — Fases 10–12 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 Admin Pages + Brazilian Calendar** — Fases 13–16 (shipped 2026-06-04) → [Archive](.planning/milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 Real-time & Notifications** — Fases 17–20 (shipped 2026-06-09) → [Archive](.planning/milestones/v1.5-ROADMAP.md)
- ✅ **v1.6 API JSON** — Fases 21–24 (shipped 2026-06-13) → [Archive](.planning/milestones/v1.6-ROADMAP.md)
- 🚧 **v1.7 WhatsApp Auto-Post + Deploy** — Fases 25–30 (em andamento)

---

## Phases

### v1.7 WhatsApp Auto-Post + Deploy (ativo)

- [ ] **Phase 25: Fundação — Transporte Evolution + Storage Alcançável** - Contrato do Evolution verificado no host real da agência, `Evolution::Client` com timeouts e taxonomia de erros, mídia servida por S3 alcançável de fora e fila confiável em development
- [ ] **Phase 26: Instância de WhatsApp por Cliente + Pareamento** - Criação ou adoção da instância, QR Code na tela, estado de conexão visível, webhook autenticado e token guardado criptografado
- [ ] **Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada** - Sincronização e cache dos grupos da instância, sinalização de grupos só-admin, grupos sumidos inativos e seleção que nunca cruza clientes
- [ ] **Phase 28: Divulgação — Agendar sem Enviar** - Divulgação com item por grupo, validações cruzadas de cliente, bloqueio de link externo e de arquivo grande, preview e estimativa de duração — deliberadamente sem disparo
- [ ] **Phase 29: Motor de Envio** - Disparo agendado grupo a grupo com intervalo aleatório, idempotência à prova de retry/deploy, revalidação de aprovação e conexão, e cancelamento respeitado
- [ ] **Phase 30: Acompanhamento ao Vivo + Hardening** - Progresso do disparo ao vivo, reenvio manual por grupo, histórico por cliente, testes negativos cross-client e retenção de jobs falhados

<details>
<summary>✅ v1.0 MVP (Fases 1–6 + 2.1 + 3.1) — SHIPPED 2026-05-27</summary>

- [x] Phase 1: Data Foundation + Security (5/5 plans) — completed 2026-05-27
- [x] Phase 2: Admin Auth + Client Management (5/5 plans) — completed 2026-05-25
- [x] Phase 2.1: Gap — password_plain sync (1/1 plan) — completed 2026-05-27
- [x] Phase 3: Art Management (1/1 plan) — completed 2026-05-25
- [x] Phase 3.1: Gap — Arte create flow (1/1 plan) — completed 2026-05-27
- [x] Phase 4: Client Calendar Portal (3/3 plans) — completed 2026-05-26
- [x] Phase 5: Approval Flow (3/3 plans) — completed 2026-05-26
- [x] Phase 6: Admin Feedback Panel (4/4 plans) — completed 2026-05-27

Full details: [.planning/milestones/v1.0-ROADMAP.md](.planning/milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Fix Art Upload & Client Association (Fases 7 + 7.1) — SHIPPED 2026-06-02</summary>

- [x] Phase 7: Art Upload & Client Scoping Fix (3/3 plans) — completed 2026-06-02
- [x] Phase 7.1: Fix: media_source params + destroy feedback + SC3 UI (2/2 plans) — completed 2026-06-02

Full details: [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 Calendar Summary & Approval Fix (Fases 8 + 9) — SHIPPED 2026-06-03</summary>

- [x] Phase 8: Approval Bug Fix (1/1 plans) — completed 2026-06-03
- [x] Phase 9: Calendar Summary Strip (1/1 plans) — completed 2026-06-03

Full details: [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)

</details>

<details>
<summary>✅ v1.3 Arte UI Polish (Fases 10–12) — SHIPPED 2026-06-03</summary>

- [x] Phase 10: Arte Form Polish (3/3 plans) — completed 2026-06-03
- [x] Phase 11: Arte Index Polish (1/1 plans) — completed 2026-06-03
- [x] Phase 12: Arte Show & Dashboard Fix (1/1 plans) — completed 2026-06-03

Full details: [.planning/milestones/v1.3-ROADMAP.md](.planning/milestones/v1.3-ROADMAP.md)

</details>

<details>
<summary>✅ v1.4 Admin Pages + Brazilian Calendar (Fases 13–16) — SHIPPED 2026-06-04</summary>

- [x] Phase 13: Página Aprovações (3/3 plans) — completed 2026-06-04
- [x] Phase 14: Calendário Admin (3/3 plans) — completed 2026-06-04
- [x] Phase 15: Configurações (3/3 plans) — completed 2026-06-04
- [x] Phase 16: Feriados Brasileiros (2/2 plans) — completed 2026-06-04

Full details: [.planning/milestones/v1.4-ROADMAP.md](.planning/milestones/v1.4-ROADMAP.md)

</details>

<details>
<summary>✅ v1.5 Real-time & Notifications (Fases 17–20) — SHIPPED 2026-06-09</summary>

- [x] Phase 17: Cable Foundation + Admin Channel + Badge + Toast (4/4 plans) — completed 2026-06-05
- [x] Phase 18: ApprovalResponse Broadcast + Admin Live Rows (4/4 plans) — completed 2026-06-05
- [x] Phase 19: Client Real-time + Arte Status Broadcast (3/3 plans) — completed 2026-06-06
- [x] Phase 20: Admin Calendar Chips Real-time (2/2 plans) — completed 2026-06-09

Full details: [.planning/milestones/v1.5-ROADMAP.md](.planning/milestones/v1.5-ROADMAP.md)

</details>

<details>
<summary>✅ v1.6 API JSON (Fases 21–24) — SHIPPED 2026-06-13</summary>

- [x] Phase 21: Fundação da API + Autenticação (5/5 plans) — completed 2026-06-11
- [x] Phase 22: Endpoints Admin (4/4 plans) — completed 2026-06-11
- [x] Phase 23: Endpoints Cliente (3/3 plans) — completed 2026-06-12
- [x] Phase 24: Endpoints IA + Rate Limiting (4/4 plans) — completed 2026-06-13

Full details: [.planning/milestones/v1.6-ROADMAP.md](.planning/milestones/v1.6-ROADMAP.md)

</details>

---

## Phase Details

> **Restrição de ordem (dura):** 25 → 26 → 27 → 28 → 29 → 30. Nenhum par pode ser invertido.
> Origem: `.planning/research/SUMMARY.md` → "Ordem de build reconciliada" (passos A–G).
> Os únicos paralelismos legítimos são *dentro* da Phase 25 (S3 e transporte Evolution não se tocam) e, parcialmente, entre a UI da Phase 30 e o final da Phase 29.

### Phase 25: Fundação — Transporte Evolution + Storage Alcançável

**Goal**: O app conversa com o host Evolution real da agência por uma única costura HTTP, e serve mídia por uma URL que esse host consegue baixar de fora da LAN — com jobs agendados sobrevivendo a reinício em development.
**Depends on**: Nada (primeira fase do milestone; roda sobre a base do v1.6)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-05, EVO-01, EVO-02, EVO-03
**Success Criteria** (o que precisa ser VERDADE):

  1. Uma arte com upload é servida por uma URL de S3 que o host público do Evolution baixa com sucesso — verificado por download real originado de fora de `192.168.3.203`.
  2. Uma chamada de leitura ao Evolution feita pelo client do app (header `apikey`, timeouts explícitos) retorna 200 contra o host da agência, e a versão/shape reais do host estão registrados por escrito antes de qualquer código depender deles.
  3. Falha de rede, timeout, credencial inválida e instância não conectada chegam ao chamador classificadas em transitório / permanente / incerto / não-conectado — nenhuma exceção crua de HTTP escapa do client.
  4. Um job agendado para daqui a alguns minutos continua executando depois de reiniciar o servidor de desenvolvimento.
  5. O horário do app é o mesmo em development e em produção (TZ fixado e verificado no boot), e o bundle tem um único adapter de fila.

**Plans**: 5 plans (4 executed + 1 gap-closure após verificação `gaps_found`)
**Wave 1**

- [x] 25-01-PLAN.md — Evolution transport seam: `Evolution::Client` + `Errors` + initializer, `+faraday` / `-good_job`, `:apikey`/`:hash` log filter, authenticated read round-trip (EVO-01/02/03, INFRA-05)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 25-02-PLAN.md — Storage seam + reliable dev jobs + deterministic TZ: `+aws-sdk-s3`, `storage.yml` MinIO, `development.rb` (`:amazon` + `queue_adapter`), `queue_schema` load, `Procfile.dev` jobs, `timezone_check.rb` (INFRA-01/02/03)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 25-03-PLAN.md — Production deploy topology: D-10 deploy-tool checkpoint, `docker-compose.yml` jobs service + `TZ` + reverse-proxy TLS, `production.rb` SSL + hosts + `:amazon`, `.env.example` + credentials keys (INFRA-01/03)

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 25-04-PLAN.md — Reachable media: idempotent blob migration rake task + outside-LAN download proof + app↔Evolution both-directions reachability (INFRA-01, EVO-01) — **COMPLETO**: `lib/tasks/storage_migration.rake` (8e5a3e0) provada ponta a ponta contra o DB de dev (copied 12 / backfill 12 / 2ª rodada no-op). Endpoint S3 corrigido — `s3.bomcustoilhabela.com.br` era o console do MinIO; a API S3 é `minio.bomcustoilhabela.com.br` (`aws.endpoint` atualizado, 947413f); buckets `calendario-livia-{development,production}` criados. INFRA-01 / SC1 provado: presigned GET buscado de fora da LAN (DNS público→Cloudflare→MinIO) → HTTP/2 200 + content-type correto. EVO-01 outbound fechado (fetch_instances→Array[6]/200/~654ms). Inbound `/up` carregado adiante para operador / fase 26 (app não deployado) — não bloqueia a fase 25 (D-12 / A4).

**Gap closure** *(após `25-VERIFICATION.md` = `gaps_found` 4/5)*

- [ ] 25-05-PLAN.md — CR-01 (guard `SECRET_KEY_BASE_DUMMY` em `timezone_check.rb` + `evolution.rb` → o `docker compose build` volta a passar) + CR-02 (`CORS_ORIGINS` no compose `web`/`jobs` + `.env.example` → `docker compose up` sem crash-loop) + hardening dobrado (WR-01 read_timeout, WR-07 body type-guard, WR-02 bind loopback, WR-03/IN-07 healthcheck + depends_on, WR-06 ordem do queue_schema em `bin/setup`, IN-05 `TZ` no `db`) (INFRA-01, INFRA-03, EVO-02, EVO-03)

**Scope note**: the "+ Deploy" of the milestone is anchored here (CONTEXT.md D-09) — the app is deployed to the public host this phase, beyond the original ROADMAP statement of "transporte + storage + jobs".
**Research**: `--research-phase` — a verificação empírica do contrato Evolution contra `whatsapp.bomcustoilhabela.com.br` é *a* tarefa mais importante do milestone e é pesquisa, não implementação. Os 8 itens a confirmar estão em SUMMARY.md → "ASSUMIDO (precisa de verificação empírica no passo A)". Decidir aqui também: migração dos blobs locais já existentes para o S3.
**Defeitos pré-existentes fechados aqui**: queue adapter ausente em `development.rb` (BLOQUEIA UAT de agendamento), `good_job` órfão no Gemfile, `default_timezone = :local` mitigado por `TZ` travado no deploy.

---

### Phase 26: Instância de WhatsApp por Cliente + Pareamento

**Goal**: Cada cliente tem sua própria instância Evolution pareada pelo painel admin, com o token guardado criptografado desde a primeira gravação e o estado de conexão sempre visível.
**Depends on**: Phase 25
**Requirements**: EVO-04, INFRA-04, PAIR-01, PAIR-02, PAIR-03, PAIR-04, PAIR-05, PAIR-06, PAIR-07, PAIR-08
**Success Criteria** (o que precisa ser VERDADE):

  1. Admin cria a instância de um cliente que ainda não tem uma e vê o QR Code na tela; o código continua escaneável enquanto rotaciona (~25s) até o pareamento concluir.
  2. Quando o nome da instância já existe no Evolution, o admin adota a instância existente em vez de receber erro — e o webhook é reapontado para este app no ato da adoção.
  3. Admin vê, por cliente, o estado da conexão (conectada / desconectada / aguardando pareamento) e consegue forçar a verificação por um botão, sem depender do webhook chegar.
  4. A tela de pareamento avisa do risco de banimento antes do escaneamento e, depois de pareado, informa há quanto tempo o número está ativo, recomendando cautela em números recentes — sem bloquear nada.
  5. O token da instância está criptografado no banco, não aparece em nenhum log nem como argumento de job, e um POST ao webhook sem o segredo correto é recusado antes de qualquer consulta ao banco.

**Plans**: TBD
**UI hint**: yes
**Ordem interna obrigatória**: as chaves de `active_record_encryption`, o `encrypts` do token e a correção do `filter_parameters` vêm ANTES do primeiro token ser gravado. Adicionar `encrypts` depois significaria migrar segredos já persistidos.
**Defeitos pré-existentes fechados aqui**: `filter_parameter_logging.rb` não casa com `apikey` nem `hash` (BLOQUEIA a primeira gravação de token).

---

### Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada

**Goal**: O admin enxerga os grupos reais do número de cada cliente, servidos de cache local, e o modelo de escopo que impede o vazamento entre clientes fica estabelecido aqui.
**Depends on**: Phase 26
**Requirements**: GRUPO-01, GRUPO-02, GRUPO-03, GRUPO-04, GRUPO-05
**Success Criteria** (o que precisa ser VERDADE):

  1. Admin dispara a sincronização de um cliente e vê, ao final, a lista dos grupos daquele número — inclusive os que voltam sem nome, com fallback legível.
  2. Abrir a tela de grupos não chama o Evolution: a lista vem do cache local e mostra quando foi sincronizada pela última vez.
  3. Grupos em que só administradores podem enviar aparecem sinalizados na seleção, antes de o admin escolher.
  4. Um grupo que sumiu do WhatsApp aparece como inativo e continua legível — nenhum registro de grupo é apagado.
  5. A seleção de grupos de um cliente nunca oferece, nem aceita, grupos de outro cliente.

**Plans**: TBD
**UI hint**: yes

---

### Phase 28: Divulgação — Agendar sem Enviar

**Goal**: O admin monta e agenda uma Divulgação completa — cliente, arte aprovada, grupos e data/hora — com todas as validações e o preview, parando deliberadamente antes de qualquer envio.
**Depends on**: Phase 27
**Requirements**: DIVU-01, DIVU-02, DIVU-03, DIVU-04, DIVU-05, DIVU-06, DIVU-07, DIVU-09, SEG-01, SEG-02
**Success Criteria** (o que precisa ser VERDADE):

  1. Admin cria uma Divulgação escolhendo cliente, arte, grupos e data/hora — e só artes aprovadas daquele cliente aparecem para seleção.
  2. Arte cujo arquivo é link externo (Drive/Dropbox), ou cujo arquivo passa do teto que o WhatsApp aceita, é recusada na criação com mensagem dizendo o que fazer — sem alterar a validação da Arte.
  3. Antes de confirmar, o admin vê o preview do que será postado (mídia e legenda) e a estimativa de duração do disparo para aquele número de grupos.
  4. A data e hora da Divulgação aparecem com o fuso explícito, e `Arte#scheduled_on` continua sendo uma data sem hora.
  5. Uma Divulgação criada mostra um registro por grupo com status `pendente` e o nome do grupo congelado como estava; uma tentativa de combinar arte de um cliente com grupos de outro é recusada, e o formulário nunca aceita o identificador do grupo cru.

**Plans**: TBD
**UI hint**: yes
**Nota de escopo**: parar antes do envio é intencional — torna o schema (a parte mais cara de errar) verificável isoladamente e permite fazer rollback do motor de envio sem levar o CRUD junto.
**Decisão pendente a resolver aqui**: se houver variação de legenda anti-spam, ela precisa aparecer no preview — senão vai ao ar conteúdo que o cliente não aprovou.

---

### Phase 29: Motor de Envio

**Goal**: Na hora agendada, cada grupo selecionado recebe a arte exatamente uma vez, com intervalo aleatório entre grupos, respeitando aprovação, conexão e cancelamento.
**Depends on**: Phase 25, Phase 28
**Requirements**: ENVIO-01, ENVIO-02, ENVIO-03, ENVIO-04, ENVIO-05, ENVIO-06, ENVIO-07, ENVIO-08, ENVIO-09, ENVIO-10, DIVU-08, SEG-03, INFRA-06
**Success Criteria** (o que precisa ser VERDADE):

  1. Na hora agendada os grupos recebem a arte um a um, com intervalo aleatório vindo de variável de ambiente, e o app continua processando outros jobs (inclusive os broadcasts do v1.5) durante toda a espera.
  2. Nenhum grupo recebe a mesma Divulgação duas vezes — nem com re-tentativa de job, worker morto ou deploy no meio do disparo; timeout de leitura vira resultado `incerto` para revisão humana e nunca é re-tentado sozinho.
  3. Se a aprovação da arte foi retirada depois do agendamento, ou se a instância não está conectada no instante do envio, o grupo não recebe nada e o item registra o motivo — nunca `enviado`.
  4. Arte com legenda chega ao grupo como mídia com legenda e arte só de texto chega como mensagem de texto, com a mídia baixável pelo Evolution do começo ao fim do disparo.
  5. Cancelar uma Divulgação em andamento impede os grupos ainda não atendidos de receber, e dois envios do mesmo número nunca acontecem em paralelo.

**Plans**: TBD
**Research**: `--research-phase` — a API exata de concurrency controls no solid_queue 1.4.0 instalado (e o comportamento de `ProcessPrunedError`), mais o formato exato do erro de `sendMedia` para mapear retry vs. discard (o Evolution devolve `BadRequestException(error.toString())`, texto livre, não código estruturado).
**Fase de maior densidade de risco do milestone** — merece code review dedicado. Cobre os pitfalls 1, 4 e 5 da pesquisa.
**Defeitos pré-existentes fechados aqui**: `application_job.rb` com `retry_on`/`discard_on` comentados (a taxonomia precisa ser explícita no job de envio); `queue.yml` com fila única `"*"` e 3 threads.

---

### Phase 30: Acompanhamento ao Vivo + Hardening

**Goal**: O admin acompanha e conserta o disparo sem sair da tela — progresso ao vivo, reenvio por grupo e histórico por cliente — com o isolamento entre clientes provado por teste.
**Depends on**: Phase 29
**Requirements**: ACOMP-01, ACOMP-02, ACOMP-03, SEG-04, INFRA-07
**Success Criteria** (o que precisa ser VERDADE):

  1. Com a página de uma Divulgação aberta, o admin vê o status de cada grupo mudar ao vivo, sem recarregar.
  2. Admin reenvia para um grupo específico que falhou, com confirmação explícita, e o resultado aparece no mesmo lugar.
  3. Admin abre um cliente e vê o histórico de Divulgações com o resultado por grupo, com o nome que o grupo tinha no momento do envio.
  4. A suíte de testes falha se uma arte do cliente A conseguir alcançar um grupo do cliente B.
  5. Jobs falhados — e os argumentos que eles carregam — não se acumulam indefinidamente no banco: existe política de retenção rodando.

**Plans**: TBD
**UI hint**: yes
**Nota**: reusa integralmente o padrão de broadcast construído e validado no v1.5 (solid_cable + Turbo Streams). Não precisa de research.

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Data Foundation + Security | v1.0 | 5/5 | Complete | 2026-05-27 |
| 2. Admin Auth + Client Management | v1.0 | 5/5 | Complete | 2026-05-25 |
| 2.1. Gap — password_plain sync | v1.0 | 1/1 | Complete | 2026-05-27 |
| 3. Art Management | v1.0 | 1/1 | Complete | 2026-05-25 |
| 3.1. Gap — Arte create flow | v1.0 | 1/1 | Complete | 2026-05-27 |
| 4. Client Calendar Portal | v1.0 | 3/3 | Complete | 2026-05-26 |
| 5. Approval Flow | v1.0 | 3/3 | Complete | 2026-05-26 |
| 6. Admin Feedback Panel | v1.0 | 4/4 | Complete | 2026-05-27 |
| 7. Art Upload & Client Scoping Fix | v1.1 | 3/3 | Complete | 2026-06-02 |
| 7.1. Fix: media_source + destroy + SC3 UI | v1.1 | 2/2 | Complete | 2026-06-02 |
| 8. Approval Bug Fix | v1.2 | 1/1 | Complete | 2026-06-03 |
| 9. Calendar Summary Strip | v1.2 | 1/1 | Complete | 2026-06-03 |
| 10. Arte Form Polish | v1.3 | 3/3 | Complete | 2026-06-03 |
| 11. Arte Index Polish | v1.3 | 1/1 | Complete | 2026-06-03 |
| 12. Arte Show & Dashboard Fix | v1.3 | 1/1 | Complete | 2026-06-03 |
| 13. Página Aprovações | v1.4 | 3/3 | Complete | 2026-06-04 |
| 14. Calendário Admin | v1.4 | 3/3 | Complete | 2026-06-04 |
| 15. Configurações | v1.4 | 3/3 | Complete | 2026-06-04 |
| 16. Feriados Brasileiros | v1.4 | 2/2 | Complete | 2026-06-04 |
| 17. Cable Foundation + Admin Channel + Badge + Toast | v1.5 | 4/4 | Complete | 2026-06-05 |
| 18. ApprovalResponse Broadcast + Admin Live Rows | v1.5 | 4/4 | Complete | 2026-06-05 |
| 19. Client Real-time + Arte Status Broadcast | v1.5 | 3/3 | Complete | 2026-06-06 |
| 20. Admin Calendar Chips Real-time | v1.5 | 2/2 | Complete | 2026-06-09 |
| 21. Fundação da API + Autenticação | v1.6 | 5/5 | Complete ✅ | 2026-06-11 |
| 22. Endpoints Admin | v1.6 | 4/4 | Complete ✅ | 2026-06-11 |
| 23. Endpoints Cliente | v1.6 | 3/3 | Complete ✅ | 2026-06-12 |
| 24. Endpoints IA + Rate Limiting | v1.6 | 4/4 | Complete ✅ | 2026-06-13 |
| 25. Fundação — Transporte Evolution + Storage | v1.7 | 4/4 + gap 25-05 | Gaps Found |  |
| 26. Instância de WhatsApp + Pareamento | v1.7 | 0/? | Not started | - |
| 27. Grupos do Cliente | v1.7 | 0/? | Not started | - |
| 28. Divulgação — Agendar sem Enviar | v1.7 | 0/? | Not started | - |
| 29. Motor de Envio | v1.7 | 0/? | Not started | - |
| 30. Acompanhamento ao Vivo + Hardening | v1.7 | 0/? | Not started | - |

---

## Cobertura de Requisitos — v1.7

| Phase | Requisitos | Qtd |
|-------|-----------|-----|
| 25 | INFRA-01, INFRA-02, INFRA-03, INFRA-05, EVO-01, EVO-02, EVO-03 | 7 |
| 26 | EVO-04, INFRA-04, PAIR-01..08 | 10 |
| 27 | GRUPO-01..05 | 5 |
| 28 | DIVU-01..07, DIVU-09, SEG-01, SEG-02 | 10 |
| 29 | ENVIO-01..10, DIVU-08, SEG-03, INFRA-06 | 13 |
| 30 | ACOMP-01..03, SEG-04, INFRA-07 | 5 |
| **Total** | | **50 / 50** ✅ |

Nenhum requisito órfão; nenhum requisito em duas fases.
