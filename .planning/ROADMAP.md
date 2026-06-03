# Roadmap: Calendário de Aprovação de Artes

## Milestones

- ✅ **v1.0 MVP** — Fases 1–6 + 2.1 + 3.1 (shipped 2026-05-27) → [Archive](.planning/milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Fix Art Upload & Client Association** — Fases 7 + 7.1 (shipped 2026-06-02) → [Archive](.planning/milestones/v1.1-ROADMAP.md)
- ✅ **v1.2 Calendar Summary & Approval Fix** — Fases 8 + 9 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.2-ROADMAP.md)
- 🚧 **v1.3 Arte UI Polish** — Fases 10–12 (in progress)

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

### v1.3 Arte UI Polish

- [~] **Phase 10: Arte Form Polish** - Form de artes totalmente estilizado + páginas new/edit com card wrapper (3 plans)
- [x] **Phase 11: Arte Index Polish** - Tabela de artes e botão Nova Arte estilizados (completed 2026-06-03)
- [ ] **Phase 12: Arte Show & Dashboard Fix** - Botões do show estilizados + link "Ver" do dashboard corrigido

## Phase Details

### Phase 8: Approval Bug Fix

**Goal**: O cliente consegue registrar aprovação ou pedido de alteração sem erros no portal
**Depends on**: Phase 7.1 (portal do cliente funcional)
**Requirements**: APRO-01, APRO-02
**Success Criteria** (what must be TRUE):

  1. Cliente clica em "Aprovar" e a resposta é gravada sem exibir "Resposta inválida"
  2. Cliente clica em "Pedir Alteração" (com ou sem comentário) e a resposta é gravada sem exibir "Resposta inválida"
  3. Após registrar resposta, o status da arte muda visivelmente no calendário (ex: badge atualizado)
  4. O admin consegue ver a resposta registrada no painel de feedback

**Plans**: 1 plan
Plans:

- [x] 08-01-PLAN.md — Adicionar scope: :approval_response nos dois form_with e verificação visual

**UI hint**: yes

### Phase 9: Calendar Summary Strip

**Goal**: O cliente vê no topo do calendário um resumo dos status das artes do mês
**Depends on**: Phase 8
**Requirements**: CAL2-01
**Success Criteria** (what must be TRUE):

  1. No topo do calendário aparece uma faixa com contagem de artes por status (total, aprovadas, pendentes, pediu alteração)
  2. Os números correspondem apenas às artes do mês corrente exibido
  3. A faixa é visível sem precisar rolar a página
  4. Ao registrar uma aprovação no mês, o contador da faixa reflete o novo status corretamente

**Plans**: TBD
**UI hint**: yes

### Phase 10: Arte Form Polish

**Goal**: O admin vê o formulário de artes completamente estilizado com Tailwind, sem classes placeholder sem CSS
**Depends on**: Phase 9
**Requirements**: FORM-01, FORM-02, FORM-03, PAGE-01, PAGE-02
**Success Criteria** (what must be TRUE):

  1. Todos os campos do form (text, textarea, date, url, file, select) têm border, focus ring verde, height uniforme e placeholder visível
  2. Os radio buttons de "Tipo de mídia" aparecem em linha horizontal com gap e labels legíveis
  3. Os botões Criar/Atualizar e Cancelar têm estilos distintos (verde para submit, neutro para cancelar)
  4. A página "Nova Arte" exibe o form dentro de um card branco com link de voltar visível
  5. A página "Editar Arte" exibe o form dentro de um card branco com link de voltar mostrando o nome da arte

**Plans**: 3 plans
Plans:

- [x] 10-01-PLAN.md — Estilizar _form.html.erb: campos, labels, radio pills, botões e locals
- [x] 10-02-PLAN.md — Estender media_type_toggle_controller.js com togglePills() e targets de label
- [x] 10-03-PLAN.md — Reescrever new.html.erb e edit.html.erb com card wrapper e back link

**UI hint**: yes

### Phase 11: Arte Index Polish

**Goal**: O admin vê a listagem de artes com tabela formatada e botões de ação visíveis
**Depends on**: Phase 10
**Requirements**: IDX-01, IDX-02
**Success Criteria** (what must be TRUE):

  1. A tabela de artes tem cabeçalhos (thead) estilizados com fundo diferenciado e texto legível
  2. Cada linha da tabela tem padding adequado e destaque visual ao passar o mouse (hover)
  3. O botão "Nova Arte" tem estilo visível e reconhecível como ação primária
  4. O link "Ver" em cada linha da tabela é visível e clicável com estilo consistente

**Plans**: 1 planPlans:

- [x] 11-01-PLAN.md — Reescrever index.html.erb + criar _arte_row.html.erb e _status_badge.html.erb com padrão clients

**UI hint**: yes

### Phase 12: Arte Show & Dashboard Fix

**Goal**: O admin vê botões de ação claros e semânticos no show de artes e no dashboard
**Depends on**: Phase 11
**Requirements**: SHOW-01, DASH-01
**Success Criteria** (what must be TRUE):

  1. Na página de show da arte, os botões Editar, Excluir, Marcar Revisada e Voltar têm estilos visíveis e semânticos
  2. O botão Excluir usa cor vermelha para indicar ação destrutiva
  3. No painel de respostas do dashboard, o link "Ver" tem estilo visível (não aparece como texto puro)

**Plans**: 1 planPlans:

- [ ] 12-01-PLAN.md — Reestruturar barra de ações do show + estilizar link "Ver" do dashboard

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
| 10. Arte Form Polish | v1.3 | 3/3 | Complete    | 2026-06-03 |
| 11. Arte Index Polish | v1.3 | 1/1 | Complete    | 2026-06-03 |
| 12. Arte Show & Dashboard Fix | v1.3 | 0/1 | Not started | - |
