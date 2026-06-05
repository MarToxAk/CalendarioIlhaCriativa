# Roadmap: Calendário de Aprovação de Artes

## Milestones

- ✅ **v1.0 MVP** — Fases 1–6 + 2.1 + 3.1 (shipped 2026-05-27) → [Archive](.planning/milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Fix Art Upload & Client Association** — Fases 7 + 7.1 (shipped 2026-06-02) → [Archive](.planning/milestones/v1.1-ROADMAP.md)
- ✅ **v1.2 Calendar Summary & Approval Fix** — Fases 8 + 9 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 Arte UI Polish** — Fases 10–12 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 Admin Pages + Brazilian Calendar** — Fases 13–16 (shipped 2026-06-04) → [Archive](.planning/milestones/v1.4-ROADMAP.md)
- 🔄 **v1.5 Real-time & Notifications** — Fases 17–20 (in progress)

## Phases

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

### v1.5 Real-time & Notifications

- [x] **Phase 17: Cable Foundation + Admin Channel + Badge + Toast** - Estabelece a infraestrutura WebSocket e monta o sistema de badge e toast no painel admin (completed 2026-06-05)
- [ ] **Phase 18: ApprovalResponse Broadcast + Admin Live Rows** - Broadcasts em tempo real das novas respostas de aprovação para o dashboard e página Aprovações do admin
- [ ] **Phase 19: Client Real-time + Arte Status Broadcast** - Canal do cliente e broadcasts quando admin marca arte como revisada
- [ ] **Phase 20: Admin Calendar Chips Real-time** - Chips do calendário admin atualizam em tempo real quando status de arte muda

## Phase Details

### Phase 17: Cable Foundation + Admin Channel + Badge + Toast

**Goal**: Estabelecer a infraestrutura WebSocket funcional, o canal do admin, o badge numérico no sidebar e a infraestrutura de toast para que o painel admin esteja pronto para receber broadcasts em tempo real
**Depends on**: Phase 16 (painel admin completo)
**Requirements**: CABLE-01, CABLE-02
**Success Criteria** (what must be TRUE):

  1. Admin abre o painel e o WebSocket conecta sem erros no console do browser (nenhum reject de connection.rb)
  2. Sidebar do admin exibe badge numérico com a contagem atual de artes com "Pediu Alteração" não revisadas
  3. Badge exibe "0" (ou some) quando não há artes pendentes de revisão
  4. Região de toast `id="admin-toast-region"` existe no layout admin pronta para receber broadcasts
  5. Stimulus toast_controller está registrado e responde ao evento de append de toast no DOM

**Plans**: 4 plansPlans:
**Wave 1**

- [x] 17-00-PLAN.md — Infraestrutura de testes: ApplicationCable::Channel base class, fixtures clients/sessions, stubs RED
- [x] 17-01-PLAN.md — connection.rb: autenticação dual admin (cookie) + cliente (token URL)
- [x] 17-02-PLAN.md — AdminNotificationsChannel: canal per-user com stream_for e defesa em profundidade

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 17-03-PLAN.md — Badge sidebar + toast region no layout + toast_controller.js

**UI hint**: yes

### Phase 18: ApprovalResponse Broadcast + Admin Live Rows

**Goal**: Quando um cliente registra aprovação ou pedido de alteração, o admin recebe toast imediato em qualquer página e as listas do dashboard e da página Aprovações ganham a nova linha sem recarregar
**Depends on**: Phase 17
**Requirements**: RTUP-01 (incremento do badge), RTUP-02, RTUP-03, RTUP-04
**Success Criteria** (what must be TRUE):

  1. Admin logado em qualquer página do painel recebe um toast visível dentro de 2 segundos após cliente submeter resposta
  2. Dashboard admin exibe nova linha de arte no topo da tabela sem recarregar a página quando cliente aprova ou pede alteração
  3. Página Aprovações do admin exibe nova linha no topo da lista em tempo real quando nova resposta chega
  4. Badge do sidebar incrementa em 1 quando nova resposta "Pediu Alteração" chega (sem recarregar)

**Plans**: 3 plans

Plans:
- [ ] 18-00-PLAN.md — RED tests para broadcasts_to_admin (callback, streams, eager-load)
- [ ] 18-01-PLAN.md — Cirurgia nas views: sidebar badge sempre no DOM, toast partial, approvals ids
- [ ] 18-02-PLAN.md — Dashboard partial + model after_create_commit → GREEN

**UI hint**: yes

### Phase 19: Client Real-time + Arte Status Broadcast

**Goal**: Quando o admin marca uma arte como revisada, o calendário do cliente atualiza a célula e o resumo de status em tempo real e exibe um toast de notificação — tudo sem recarregar a página
**Depends on**: Phase 18
**Requirements**: RTUP-05, RTUP-06, RTUP-07, RTUP-01 (decremento do badge)
**Success Criteria** (what must be TRUE):

  1. Cliente com calendário aberto vê o badge de status da arte mudar (de "Pediu Alteração" para "Revisado") dentro de 2 segundos após admin marcar como revisada
  2. Faixa de resumo no topo do calendário do cliente atualiza os contadores em tempo real quando status de arte muda
  3. Cliente recebe toast visível no calendário quando admin marca arte como revisada
  4. Badge do sidebar admin decrementa em 1 quando admin marca arte como revisada (RTUP-01 parcial)
  5. Autenticação do canal do cliente via token de URL funciona sem expor sessão do admin

**Plans**: TBD
**UI hint**: yes

### Phase 20: Admin Calendar Chips Real-time

**Goal**: Chips do calendário admin refletem mudanças de status de artes em tempo real, completando o ciclo de atualizações em tempo real para todas as views do admin
**Depends on**: Phase 19
**Requirements**: RTUP-08, RTUP-01 (finalizado)
**Success Criteria** (what must be TRUE):

  1. Admin com calendário aberto vê o chip de uma arte atualizar visualmente (cor ou texto de status) dentro de 2 segundos após cliente registrar resposta
  2. Badge do sidebar reflete o estado correto após qualquer sequência de eventos (aprovação, pedido de alteração, revisão) — RTUP-01 completo
  3. Nenhum broadcast duplica chips ou cria elementos DOM extras no calendário admin

**Plans**: TBD
**UI hint**: yes

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
| 13. Página Aprovações | v1.4 | 3/3 | Complete    | 2026-06-04 |
| 14. Calendário Admin | v1.4 | 3/3 | Complete    | 2026-06-04 |
| 15. Configurações | v1.4 | 3/3 | Complete    | 2026-06-04 |
| 16. Feriados Brasileiros | v1.4 | 2/2 | Complete    | 2026-06-04 |
| 17. Cable Foundation + Admin Channel + Badge + Toast | v1.5 | 4/4 | Complete    | 2026-06-05 |
| 18. ApprovalResponse Broadcast + Admin Live Rows | v1.5 | 3/3 | Planned | - |
| 19. Client Real-time + Arte Status Broadcast | v1.5 | 0/3 | Not started | - |
| 20. Admin Calendar Chips Real-time | v1.5 | 0/2 | Not started | - |
