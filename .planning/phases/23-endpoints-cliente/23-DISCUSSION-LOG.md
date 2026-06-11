# Phase 23: Endpoints Cliente - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-11
**Phase:** 23-endpoints-cliente
**Areas discussed:** O que é "pendente" na listagem, Campos do detalhe da arte, Submissão da aprovação, Erros e escopo de borda

---

## O que é "pendente" na listagem (APICLI-01)

### Quais artes

| Option | Description | Selected |
|--------|-------------|----------|
| pending + revised | Inclui ambos (paridade com a web %w[pending revised]) | ✓ |
| Só pending | Apenas status pending estrito | |
| Você decide | Pesquisa decide | |

**User's choice:** pending + revised

### Escopo / ordenação / paginação

| Option | Description | Selected |
|--------|-------------|----------|
| Todas, por data, paginadas | Todas pendentes, scheduled_on asc, page/per_page default 25 | ✓ |
| Filtrar por mês (web) | ?month=YYYY-MM espelhando calendário | |
| Todas, sem paginação | Todas por data, sem paginar | |

**User's choice:** Todas pendentes, ordenadas por data, paginadas

---

## Campos do detalhe da arte (APICLI-02)

### Campos expostos

| Option | Description | Selected |
|--------|-------------|----------|
| Visualização + contexto de ação | id, title, caption, scheduled_on, approval_deadline, platform, media_type, media_url, status | ✓ |
| Só o mínimo | id, title, caption, scheduled_on, media_url, status | |
| Você decide | Pesquisa define | |

**User's choice:** Visualização + contexto de ação

### Histórico / admin_reply

| Option | Description | Selected |
|--------|-------------|----------|
| Respostas anteriores + admin_reply quando houver | Histórico das próprias respostas + admin_reply presente | ✓ |
| Só a arte | Sem histórico nem admin_reply | |
| Respostas anteriores, sem admin_reply | Histórico sim, admin_reply não | |

**User's choice:** Inclui respostas anteriores; admin_reply só quando houver

---

## Submissão da aprovação (APICLI-03)

### Rota / payload

| Option | Description | Selected |
|--------|-------------|----------|
| POST aninhado, payload flat | /client/artes/:arte_id/approval_responses, { decision, comment }, lock de linha | ✓ |
| POST ação dedicada | /client/artes/:id/approve | |
| Você decide | Pesquisa define | |

**User's choice:** POST aninhado, payload flat

### Comentário obrigatório?

| Option | Description | Selected |
|--------|-------------|----------|
| Opcional em ambos | Paridade com a web (APRO-02) | ✓ |
| Obrigatório em change_requested | Regra nova, diverge da web | |

**User's choice:** Opcional em ambos

### Corpo da resposta

| Option | Description | Selected |
|--------|-------------|----------|
| 201 com resposta criada + novo status da arte | Atualiza UI sem re-buscar; re-aprovar revised permitido | ✓ |
| 201 confirmação simples | { status: 'ok' } | |
| Você decide | Pesquisa define | |

**User's choice:** 201 com a resposta criada + novo status da arte

---

## Erros e escopo de borda

### Cross-client

| Option | Description | Selected |
|--------|-------------|----------|
| 404 via escopo | RecordNotFound → 404, sem enumeração | ✓ |
| 403 explícito | Revela existência (enumeração) | |

**User's choice:** 404 via escopo

### Submissão inválida

| Option | Description | Selected |
|--------|-------------|----------|
| 422 estruturado | arte_must_be_pending → 422; decision inválido → 400/422; nunca 500 | ✓ |
| Você decide | Pesquisa define | |

**User's choice:** 422 estruturado

---

## Claude's Discretion

- Reusar ArteSerializer admin vs criar serializer de cliente dedicado (provavelmente dedicado dado campos diferentes + histórico).
- Código HTTP exato para decision inválido (400 vs 422) e nomes exatos dos campos JSON.

## Deferred Ideas

- Filtro por mês na listagem do cliente.
- Comentário obrigatório em "pediu alteração".
- Endpoint de histórico completo (artes já respondidas).
- Rate limiting (Phase 24).
