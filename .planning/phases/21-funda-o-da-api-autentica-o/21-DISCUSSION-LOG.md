# Phase 21: Fundação da API + Autenticação - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-11
**Phase:** 21-Fundação da API + Autenticação
**Areas discussed:** Auth do cliente, JWT expiry/refresh, Envelope JSON, Discriminação dos consumidores/namespaces

---

## Auth do cliente na API

| Option | Description | Selected |
|--------|-------------|----------|
| Token + senha → JWT de cliente curto | Login com access_token + senha (igual ao portal) → JWT Bearer. Paridade de segurança; access_token nunca é credencial sozinho. Custo: endpoint de login. | ✓ (via "Você decide") |
| access_token sozinho como Bearer (nota original) | Token do portal direto como Bearer, sem senha. Mais simples, zero infra nova — mas o token está no link (semi-público). | |
| Você decide | Claude analisa trade-offs e recomenda. | ✓ (delegado) |

**User's choice:** "Você decide" → Claude decidiu **Token + senha → JWT de cliente curto**.
**Notes:** A nota `api-auth-strategy.md` dizia "não criar senha para clientes", mas o `Client` já tem `has_secure_password` e o portal já exige senha — premissa inválida. Mutação de aprovação exige auth real, não link encaminhável. Decisão registrada em CONTEXT D-01/D-02.

---

## JWT expiry/refresh

| Option | Description | Selected |
|--------|-------------|----------|
| JWT 24h sem refresh, re-login | JWT único, expiração configurável (padrão 24h). Re-login ao expirar. Sem tabela de refresh. Revogação por expiração. | ✓ |
| JWT curto + refresh token | Access curto + refresh de longa duração no servidor. Melhor UX mobile + revogação explícita. Custo: tabela, rotação, complexidade. | |
| Você decide | Claude avalia UX vs simplicidade. | |

**User's choice:** **JWT 24h sem refresh, re-login** (recomendado).
**Notes:** Alinha com o DNA enxuto do projeto. Trade-off aceito: credencial comprometida válida até expirar. Refresh e token_version deferidos. Registrado em CONTEXT D-04.

---

## Formato do envelope JSON

| Option | Description | Selected |
|--------|-------------|----------|
| Envelope custom leve: data + meta + errors | `{ data, meta, errors }`; errors = lista `{ code, detail, field? }`; status HTTP correto. Casa com INFAPI-02. | ✓ |
| Padrão JSON:API | Spec estabelecida (type/attributes/relationships). Tooling pronto, mas verboso p/ API pequena. | |
| Você decide | Claude avalia padronização vs simplicidade. | |

**User's choice:** **Envelope custom leve** (recomendado).
**Notes:** Lib de serialização concreta fica para a pesquisa. Registrado em CONTEXT D-05.

---

## Discriminação dos consumidores / namespaces

| Option | Description | Selected |
|--------|-------------|----------|
| Namespace por consumidor: /admin, /client, /ai | `/api/v1/admin` (JWT admin), `/api/v1/client` (JWT cliente), `/api/v1/ai` (API key). Espelha estrutura web, isola IA p/ auditoria, habilita rate-limit segmentado. | ✓ |
| Namespace único /api/v1 + autorização por papel | Todos sob /api/v1, controller decide pelo papel. Menos rotas, mas mistura consumidores. | |
| Você decide | Claude avalia isolamento vs nº de rotas. | |

**User's choice:** **Namespace por consumidor** (recomendado).
**Notes:** Cascata da Área 1: admin e cliente usam JWT (distinguidos por claim `scope`), só IA usa API key. Middleware: prefixo `ak_`→IA; senão JWT scope→admin/cliente; senão 401. Registrado em CONTEXT D-06/D-07/D-08.

---

## Claude's Discretion

- Áreas "Auth do cliente" e "JWT expiry" (parcial) foram delegadas via "Você decide" e decididas com raciocínio registrado no CONTEXT.md.
- Escolha da gem JWT (ex. `ruby-jwt`), lib de serialização, prefixo exato da API key e estrutura concreta dos claims do JWT ficam para pesquisa/planejamento.

## Deferred Ideas

- Refresh tokens (se a UX mobile de re-login a cada 24h incomodar).
- Claim `token_version` / denylist para revogação imediata de JWT.
- Swagger/OpenAPI (já fora de escopo — v1.7).
- Rate limiting (Phase 24; infra `rack-attack` já existe).
