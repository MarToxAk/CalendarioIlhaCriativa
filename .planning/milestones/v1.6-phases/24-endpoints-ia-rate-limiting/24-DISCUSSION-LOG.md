# Phase 24: Endpoints IA + Rate Limiting - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-12
**Phase:** 24-endpoints-ia-rate-limiting
**Areas discussed:** Filtros APIAI-01, Resumo APIAI-03, Upload pela IA, Rate limiting

---

## Filtros APIAI-01

| Option | Description | Selected |
|--------|-------------|----------|
| `from` + `to` ISO | Formato ISO 8601 — flexível para janelas arbitrárias | ✓ |
| `month` YYYY-MM | Mesmo padrão admin — mais simples mas limita a meses calendrais | |
| Ambos suportados | Atalho `month` + granularidade `from`/`to` | |

**User's choice:** `from` + `to` ISO (recomendado)

| Option | Description | Selected |
|--------|-------------|----------|
| Obrigatório | Sem `from`/`to` retorna 400 — evita buscar volume total | ✓ |
| Opcional com padrão (últimos 30 dias) | Sem filtro assume janela padrão | |
| Opcional sem padrão | Retorna tudo paginado | |

**User's choice:** Obrigatório (recomendado)

**Notes:** Usuário aplicou "todos os recomendados" após as duas primeiras perguntas. Filtro `client_id` opcional por padrão (consistência com Phase 22).

---

## Resumo APIAI-03

**User's choice:** Recomendado — rota por cliente específico `GET /ai/clients/:id/summary`, sem filtro de período, campos `{ total, approved_count, pending_count, change_requested_count }`.

**Notes:** Aplicado por "todos os recomendados". A IA pode chamar N vezes, uma por cliente relevante.

---

## Upload pela IA

| Option | Description | Selected |
|--------|-------------|----------|
| Só `external_url` | IAs não enviam binários facilmente — link Drive/Dropbox | ✓ |
| multipart/form-data | Mesmo que o admin — mais completo mas incomum em agentes | |

**User's choice:** Só `external_url` (recomendado)

**Notes:** Receber `media_file` retorna 400. Paridade com o admin exceto o campo de upload.

---

## Rate limiting

| Option | Description | Selected |
|--------|-------------|----------|
| Só `/api/v1/ai/*` — 60 req/min | Escopo cirúrgico, não impacta admin/client | ✓ |
| Toda `/api/v1/` | Throttle global | |
| Burst allowance | Limite maior em rajada | |

**User's choice:** 60 req/min por API key, só namespace IA (recomendado)

**Notes:** Reutiliza `Rack::Attack.throttled_responder` já configurado. Sem burst especial.

---

## Claude's Discretion

- Nome exato do throttle no Rack::Attack
- Se usar serializer dedicado `Api::V1::Ai::ArteSerializer` ou reusar admin
- Se incluir `revised_count` no resumo APIAI-03
- Forma exata de agregar dados do resumo (group_by vs counter)

## Deferred Ideas

- Rate limiting para namespaces admin/client
- Upload multipart pela IA
- Filtro de período no resumo APIAI-03
- Burst allowance para a IA
- Documentação OpenAPI/Swagger (v1.7)
