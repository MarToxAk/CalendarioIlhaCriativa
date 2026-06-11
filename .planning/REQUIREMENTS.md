# Requirements — v1.6 API JSON

**Status:** 🟡 Em planejamento
**Criado:** 2026-06-06

---

## Contexto

Expor uma API JSON para dois consumidores principais:
- **App mobile** (admin e cliente) — substitui/complementa o portal web
- **IA** — lê aprovações, insere artes, envia notificações/resumos

A autenticação usa três modos distintos (ver nota `api-auth-strategy.md`).

---

## Requisitos

### Autenticação (AUTH)

- [ ] **AUTH-01**: Admin autentica na API com e-mail e senha e recebe JWT
- [ ] **AUTH-02**: JWT de admin tem expiração configurável (padrão 24h)
- [ ] **AUTH-03**: Cliente autentica na API usando o token existente do portal como Bearer
- [ ] **AUTH-04**: IA autentica com API key dedicada via header `Authorization: Bearer <api_key>`
- [x] **AUTH-05**: Requisições sem autenticação válida retornam 401 com mensagem estruturada

### Endpoints Admin (APIADM)

- [ ] **APIADM-01**: Admin lista clientes (paginado)
- [ ] **APIADM-02**: Admin cria novo cliente
- [ ] **APIADM-03**: Admin lista artes (filtros por cliente, status, mês)
- [ ] **APIADM-04**: Admin cria nova arte (upload de imagem incluído)
- [ ] **APIADM-05**: Admin vê histórico de aprovações

### Endpoints Cliente (APICLI)

- [ ] **APICLI-01**: Cliente lista suas artes pendentes de aprovação
- [ ] **APICLI-02**: Cliente vê detalhe de uma arte (imagem, data, legenda)
- [ ] **APICLI-03**: Cliente submete resposta de aprovação (aprovado / pediu alteração + comentário)

### Endpoints IA (APIAI)

- [ ] **APIAI-01**: IA lista artes aprovadas (com filtros de período)
- [ ] **APIAI-02**: IA insere nova arte para aprovação (mesmo payload do admin)
- [ ] **APIAI-03**: IA lê resumo do estado das aprovações por cliente (total, aprovadas, pendentes, alteração)

### Infraestrutura (INFAPI)

- [x] **INFAPI-01**: API versionada em `/api/v1/`
- [ ] **INFAPI-02**: Respostas em JSON com formato consistente (data + meta + errors)
- [ ] **INFAPI-03**: Erros retornam código HTTP correto e corpo estruturado
- [ ] **INFAPI-04**: Rate limiting por API key/token

---

## Out of Scope (v1.6)

- WebSockets / push notifications nativas mobile — cobre a IA via polling
- GraphQL — REST é suficiente para os casos de uso identificados
- OAuth / social login — token do portal basta para o cliente
- Documentação interativa (Swagger/OpenAPI) — pode ser adicionada em v1.7
- SDK cliente — consumidores implementam diretamente contra REST

---

## Rastreabilidade (Requisito → Fase)

20 requisitos, todos mapeados para exatamente uma fase (cobertura 100%).

| Requisito | Fase |
|-----------|------|
| AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05 | Phase 21 |
| INFAPI-01, INFAPI-02, INFAPI-03 | Phase 21 |
| APIADM-01, APIADM-02, APIADM-03, APIADM-04, APIADM-05 | Phase 22 |
| APICLI-01, APICLI-02, APICLI-03 | Phase 23 |
| APIAI-01, APIAI-02, APIAI-03 | Phase 24 |
| INFAPI-04 | Phase 24 |
