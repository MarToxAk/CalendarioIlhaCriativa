---
title: Estratégia de Autenticação da API JSON
date: 2026-06-06
context: Decisão tomada durante exploração do milestone v1.5 API JSON
---

# Estratégia de Autenticação da API JSON

A API terá três modos de autenticação distintos, um para cada tipo de consumidor.

## Modos

| Consumidor | Mecanismo | Justificativa |
|------------|-----------|---------------|
| Admin mobile | JWT (email + senha → token) | Mesma lógica do login web, mas stateless para mobile |
| Cliente mobile | Token existente do portal como Bearer | Reaproveita o token único por cliente já existente; sem nova infraestrutura de auth |
| IA | API key dedicada | Independente de usuário; fácil rotação; escopo separado do admin |

## Decisões

- **Não** criar senha para clientes — o token do portal já é o segredo de autenticação
- **Não** usar OAuth/social login neste milestone — complexidade desnecessária
- API key da IA deve ser armazenada como secret de ambiente, não no banco
- JWT admin: expiração curta (ex: 24h) + refresh token para mobile

## Impacto no design da API

- Header `Authorization: Bearer <token>` para os três modos
- Middleware de autenticação distingue o tipo pelo formato/prefixo do token
- Endpoints de IA ficam num escopo separado (ex: `/api/v1/ai/`) para facilitar auditoria
