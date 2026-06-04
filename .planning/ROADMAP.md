# Roadmap: Calendário de Aprovação de Artes

## Milestones

- ✅ **v1.0 MVP** — Fases 1–6 + 2.1 + 3.1 (shipped 2026-05-27) → [Archive](.planning/milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Fix Art Upload & Client Association** — Fases 7 + 7.1 (shipped 2026-06-02) → [Archive](.planning/milestones/v1.1-ROADMAP.md)
- ✅ **v1.2 Calendar Summary & Approval Fix** — Fases 8 + 9 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 Arte UI Polish** — Fases 10–12 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.3-ROADMAP.md)
- 🔄 **v1.4 Admin Pages + Brazilian Calendar** — Fases 13–16 (in progress)

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

### v1.4 Admin Pages + Brazilian Calendar

- [x] **Phase 13: Página Aprovações** — Histórico completo de respostas com filtros por cliente e status (completed 2026-06-04)
- [x] **Phase 14: Calendário Admin** — Calendário unificado com artes de todos os clientes, cor por cliente, navegação e links (completed 2026-06-04)
- [x] **Phase 15: Configurações** — Página de configurações com alteração de senha e dados da agência (completed 2026-06-04)
- [ ] **Phase 16: Feriados Brasileiros** — Lista hardcoded de feriados e comemorativos visível nos calendários do admin e do cliente

## Phase Details

### Phase 13: Página Aprovações

**Goal**: Admin consegue consultar o histórico completo de todas as respostas de aprovação num único lugar, com filtros e link direto para cada arte
**Depends on**: Phase 12 (painel admin estilizado)
**Requirements**: APRO-03, APRO-04, APRO-05, APRO-06, APRO-07
**Success Criteria** (what must be TRUE):

  1. Admin clica em "Aprovações" no sidebar e é levado à página (link não aponta mais para `#`)
  2. Admin vê lista paginada de respostas ordenada da mais recente para a mais antiga
  3. Cada item da lista exibe: nome do cliente, título/identificação da arte, status da resposta, data e comentário quando presente
  4. Admin seleciona um cliente ou um status no filtro e a lista atualiza mostrando apenas os itens correspondentes
  5. Admin clica num item da lista e acessa a página da arte correspondente diretamente

**Plans**: 3 plans
**Wave 1**

- [x] 13-01-PLAN.md — Infraestrutura Pagy + rota + sidebar wired + arquivo de testes

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 13-02-PLAN.md — Controller ApprovalsController + testes de integração

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 13-03-PLAN.md — Views: index, _approval_row, _decision_badge

**UI hint**: yes

### Phase 14: Calendário Admin

**Goal**: Admin visualiza num único calendário mensal as artes de todos os clientes, diferenciadas por cor e nome de cliente, e navega entre meses e acessa artes diretamente
**Depends on**: Phase 13
**Requirements**: CADM-01, CADM-02, CADM-03, CADM-04, CADM-05
**Success Criteria** (what must be TRUE):

  1. Admin clica em "Calendário" no sidebar e é levado à página do calendário admin (link não aponta mais para `#`)
  2. Admin vê calendário mensal com todas as artes de todos os clientes distribuídas nos dias corretos
  3. Cada arte exibe cor de fundo distinta por cliente e o nome ou iniciais do cliente visível na célula do dia
  4. Admin clica nas setas de navegação (mês anterior / próximo) e o calendário atualiza sem recarregar a página completa
  5. Admin clica numa arte do calendário e é levado à página de show da arte correspondente

**Plans**: TBD
**UI hint**: yes

### Phase 15: Configurações

**Goal**: Admin consegue alterar sua senha e o nome da agência através de uma página de configurações acessível pelo sidebar
**Depends on**: Phase 14
**Requirements**: CONF-01, CONF-02, CONF-03
**Success Criteria** (what must be TRUE):

  1. Admin clica em "Configurações" no sidebar e é levado à página de configurações (link não aponta mais para `#`)
  2. Admin preenche formulário de troca de senha (senha atual + nova + confirmação) e a senha é atualizada com feedback de sucesso ou erro
  3. Admin edita o nome da agência e salva, o novo nome aparece refletido no painel

**Plans**: 3 plans

**Wave 1**

- [x] 15-01-PLAN.md — Migração agency_name + rota settings + sidebar wired + scaffold testes

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 15-02-PLAN.md — Controller Admin::SettingsController + testes de integração

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 15-03-PLAN.md — View: show com cards de senha e dados da agência

**UI hint**: yes

### Phase 16: Feriados Brasileiros

**Goal**: Feriados nacionais e dias comemorativos de marketing brasileiros ficam visualmente destacados nos calendários do admin e do cliente, sem depender de API externa
**Depends on**: Phase 15
**Requirements**: FERI-01, FERI-02, FERI-03
**Success Criteria** (what must be TRUE):

  1. O sistema possui lista hardcoded com feriados nacionais e comemorativos de marketing (Dia das Mães, Namorados, Pais, etc.) para os anos em uso
  2. No calendário do cliente, dias com feriado ou comemorativo exibem o nome do evento em texto vermelho legível na célula
  3. No calendário do admin, dias com feriado ou comemorativo exibem o nome do evento em texto vermelho legível na célula

**Plans**: 2 plans

**Wave 1**

- [ ] 16-01-PLAN.md — Módulo BrazilianHolidays + helper brazilian_holiday_for + testes unitários

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 16-02-PLAN.md — Views ERB dos dois calendários + testes de integração + checkpoint visual

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
| 16. Feriados Brasileiros | v1.4 | 0/2 | Not started | - |
