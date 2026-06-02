# Roadmap: Calendário de Aprovação de Artes

## Milestones

- ✅ **v1.0 MVP** — Fases 1–6 (shipped 2026-05-27) → [Archive](.planning/milestones/v1.0-ROADMAP.md)
- 🚧 **v1.1 Fix Art Upload & Client Association** — Fase 7 (in progress)

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

### 🚧 v1.1 Fix Art Upload & Client Association (In Progress)

**Milestone Goal:** Corrigir o upload de arquivos no model Art e garantir que cada arte seja criada com associação correta e segura ao `@client` do admin logado.

- [x] **Phase 7: Art Upload & Client Scoping Fix** — Upload via ActiveStorage funcional e associação/escopo de cliente corrigidos (completed 2026-06-02)

## Phase Details

### Phase 7: Art Upload & Client Scoping Fix

**Goal**: Upload de arquivos de artes funciona via ActiveStorage e o client_id é sempre derivado do contexto correto, com proteção contra acesso cross-client
**Depends on**: Phase 6 (v1.0 complete)
**Requirements**: ARTE-08, ARTE-09, ARTE-10
**Success Criteria** (what must be TRUE):

  1. Admin pode fazer upload de um arquivo ao criar uma arte e o arquivo fica salvo e acessível (preview visível no portal do cliente)
  2. Arte criada sem informar client_id via form nunca resulta em arte orphan — o sistema deriva o client_id do contexto do admin logado
  3. Admin não consegue acessar, editar ou excluir arte de outro cliente mesmo manipulando a URL
  4. Artes listadas no painel do admin são sempre escopadas ao cliente selecionado, sem vazamento cross-client

**Plans**: 3 plans
Plans:

Wave 1 *(completo)*:

- [x] 07-01-PLAN.md — Adicionar @client = @arte.client em set_arte (ARTE-10)
- [x] 07-02-PLAN.md — Selector condicional de cliente + erros de :base no form (ARTE-08, ARTE-09)

Wave 2 *(blocked on Wave 1 completion)* — Gap Closure:

- [x] 07-03-PLAN.md — Proteção cross-client em set_arte + filtragem index por client_id (SC3, SC4) [gap_closure]

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
| 7. Art Upload & Client Scoping Fix | v1.1 | 3/3 | Complete   | 2026-06-02 |
