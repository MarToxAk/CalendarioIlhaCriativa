# Roadmap: Calendário de Aprovação de Artes

## Milestones

- ✅ **v1.0 MVP** — Fases 1–6 + 2.1 + 3.1 (shipped 2026-05-27) → [Archive](.planning/milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Fix Art Upload & Client Association** — Fases 7 + 7.1 (shipped 2026-06-02) → [Archive](.planning/milestones/v1.1-ROADMAP.md)
- ✅ **v1.2 Calendar Summary & Approval Fix** — Fases 8 + 9 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.2-ROADMAP.md)
- ✅ **v1.3 Arte UI Polish** — Fases 10–12 (shipped 2026-06-03) → [Archive](.planning/milestones/v1.3-ROADMAP.md)
- ✅ **v1.4 Admin Pages + Brazilian Calendar** — Fases 13–16 (shipped 2026-06-04) → [Archive](.planning/milestones/v1.4-ROADMAP.md)
- ✅ **v1.5 Real-time & Notifications** — Fases 17–20 (shipped 2026-06-09) → [Archive](.planning/milestones/v1.5-ROADMAP.md)
- 🚧 **v1.6 API JSON** — Fases 21–24 (em progresso, iniciado 2026-06-10)

## Milestone Ativo: v1.6 API JSON

**Goal:** API JSON REST versionada (`/api/v1/`) para app mobile (admin + cliente) e agente IA, com três modos de autenticação (JWT admin, token do portal como Bearer p/ cliente, API key p/ IA).

**20 requisitos** | **4 fases** | Cobertura: 100% ✓

### Phase 21: Fundação da API + Autenticação

**Goal:** API versionada em `/api/v1/` com os três modos de auth funcionando e middleware de autenticação distinguindo cada tipo de consumidor.

**Requirements:** AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, INFAPI-01, INFAPI-02, INFAPI-03

**Plans:** 5/5 plans complete

Plans:

- [x] 21-01-PLAN.md — Gems jwt/rack-cors + CORS middleware + rack-attack JSON responder
- [x] 21-02-PLAN.md — JwtService PORO + Api::V1::BaseController + rotas /api/v1/
- [x] 21-03-PLAN.md — Session controllers (login admin e cliente)
- [x] 21-04-PLAN.md — Auth middleware base controllers (admin, client, ai namespaces)
- [x] 21-05-PLAN.md — Credentials setup (jwt_secret, ai_key) + testes de controller

**Success criteria:**

1. Admin faz POST com e-mail + senha e recebe um JWT válido com expiração configurável (padrão 24h)
2. Cliente autentica com `access_token` + senha e recebe um JWT de cliente curto usado como `Authorization: Bearer`, acessando apenas endpoints do seu escopo
3. IA autentica com API key dedicada (secret de ambiente) via `Authorization: Bearer`
4. Requisição sem credencial válida retorna 401 com corpo JSON estruturado (`errors`)
5. Toda resposta segue envelope consistente (`data` + `meta` + `errors`) sob `/api/v1/`, com código HTTP correto em erros

### Phase 22: Endpoints Admin

**Goal:** Admin mobile consegue listar clientes, criar artes e consultar histórico de aprovações via API.

**Requirements:** APIADM-01, APIADM-02, APIADM-03, APIADM-04, APIADM-05
**Depends on:** Phase 21

**Plans:** 4 plans
Plans:
**Wave 1**

- [x] 22-01-PLAN.md — Base controller infra (Pagy + ActiveStorage host) + PORO serializers + rotas

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 22-02-PLAN.md — ClientsController (index paginado + create com credenciais) + testes
- [ ] 22-03-PLAN.md — ArtesController (index com filtros + create com upload) + testes + fixture
- [ ] 22-04-PLAN.md — ApprovalResponsesController (histórico aninhado por arte) + testes

**Success criteria:**

1. `GET` de clientes retorna lista paginada (metadados de paginação no envelope)
2. `POST` de cliente cria um novo cliente e retorna o recurso criado
3. `GET` de artes aceita filtros por cliente, status e mês
4. `POST` de arte cria arte com upload de imagem (Active Storage) autenticado como admin
5. Histórico de aprovações de uma arte/cliente é retornado com as respostas registradas

### Phase 23: Endpoints Cliente

**Goal:** Cliente mobile consegue ver suas artes pendentes e submeter resposta de aprovação via API.

**Requirements:** APICLI-01, APICLI-02, APICLI-03
**Depends on:** Phase 21

**Success criteria:**

1. Cliente autenticado lista apenas suas artes pendentes de aprovação
2. Cliente vê o detalhe de uma arte (mídia, data, legenda)
3. Cliente submete aprovação (aprovado OU pediu alteração + comentário) e recebe confirmação
4. Cliente não consegue acessar artes de outro cliente (escopo garantido pelo token)

### Phase 24: Endpoints IA + Rate Limiting

**Goal:** IA consegue listar aprovações, inserir artes e ler resumos; a API tem rate limiting por key/token.

**Requirements:** APIAI-01, APIAI-02, APIAI-03, INFAPI-04
**Depends on:** Phase 21, 22

**Success criteria:**

1. IA lista artes aprovadas com filtros de período
2. IA insere nova arte para aprovação (mesmo payload do admin)
3. IA lê resumo do estado das aprovações por cliente (total, aprovadas, pendentes, alteração)
4. Requisições além do limite por key/token recebem 429 (rate limiting aplicado)

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

<details>
<summary>✅ v1.5 Real-time & Notifications (Fases 17–20) — SHIPPED 2026-06-09</summary>

- [x] Phase 17: Cable Foundation + Admin Channel + Badge + Toast (4/4 plans) — completed 2026-06-05
- [x] Phase 18: ApprovalResponse Broadcast + Admin Live Rows (4/4 plans) — completed 2026-06-05
- [x] Phase 19: Client Real-time + Arte Status Broadcast (3/3 plans) — completed 2026-06-06
- [x] Phase 20: Admin Calendar Chips Real-time (2/2 plans) — completed 2026-06-09

Full details: [.planning/milestones/v1.5-ROADMAP.md](.planning/milestones/v1.5-ROADMAP.md)

</details>

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
| 18. ApprovalResponse Broadcast + Admin Live Rows | v1.5 | 4/4 | Complete   | 2026-06-05 |
| 19. Client Real-time + Arte Status Broadcast | v1.5 | 3/3 | Complete    | 2026-06-06 |
| 20. Admin Calendar Chips Real-time | v1.5 | 2/2 | Complete   | 2026-06-09 |
| 21. Fundação da API + Autenticação | v1.6 | 5/5 | Complete    | 2026-06-11 |
| 22. Endpoints Admin | v1.6 | 1/4 | In Progress|  |
| 23. Endpoints Cliente | v1.6 | 0/0 | Planned | — |
| 24. Endpoints IA + Rate Limiting | v1.6 | 0/0 | Planned | — |
