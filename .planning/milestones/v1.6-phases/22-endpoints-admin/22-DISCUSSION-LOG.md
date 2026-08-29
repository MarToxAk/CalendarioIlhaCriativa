# Phase 22: Endpoints Admin - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-11
**Phase:** 22-endpoints-admin
**Areas discussed:** Upload de imagem da arte, Campos do cliente no JSON, Filtros e paginação, Histórico de aprovações

---

## Upload de imagem da arte

### Mecanismo de envio

| Option | Description | Selected |
|--------|-------------|----------|
| multipart/form-data | Arquivo binário direto no campo media_file, igual ao web; reusa Active Storage | ✓ |
| Base64 no JSON | Imagem em base64 no corpo JSON; infla ~33%, mais memória/decodificação | |
| Direct upload (signed_id) | Upload direto ao storage + signed_id no JSON; mais escalável, 2 passos | |

**User's choice:** multipart/form-data

### Fonte de mídia

| Option | Description | Selected |
|--------|-------------|----------|
| Arquivo OU link externo | Paridade web: media_file OU external_url, regra only_one_media_source | ✓ |
| Só upload de arquivo | API só aceita arquivo; perde a opção de link do painel web | |

**User's choice:** Arquivo OU link externo

### Representação da mídia na resposta

| Option | Description | Selected |
|--------|-------------|----------|
| URL absoluta + tipo de fonte | media_url resolvido (blob ou external_url) + campo de fonte | ✓ |
| Campos crus separados | external_url + flag has_media_file; app monta a URL | |
| Você decide | Pesquisa define formato exato (variantes/thumbs) | |

**User's choice:** URL absoluta + tipo de fonte

---

## Campos do cliente no JSON

### Exposição de credenciais sensíveis

| Option | Description | Selected |
|--------|-------------|----------|
| Só no POST de criação | GET nunca retorna senha; POST devolve link+senha uma vez | ✓ |
| Sempre expõe link + senha | Todo GET traz link + password_plain (paridade com painel web) | |
| Nunca expõe senha | API nunca retorna senha; quebra o caso de criar e mandar link+senha | |

**User's choice:** Só no POST de criação

### Origem da senha na criação

| Option | Description | Selected |
|--------|-------------|----------|
| App envia a senha | Payload { name, password }; access_token auto-gerado; paridade web | ✓ |
| API gera senha | App manda só { name }; API gera e retorna senha | |
| Você decide | Pesquisa decide respeitando o fluxo web | |

**User's choice:** App envia a senha

---

## Filtros e paginação

### Formato dos filtros de artes

| Option | Description | Selected |
|--------|-------------|----------|
| Query params nomeados, valores string | client_id, status (string do enum), month=YYYY-MM; opcionais/combináveis | ✓ |
| Valores numéricos do enum | status=0..3 cru; frágil e acoplado à ordem do enum | |
| Você decide | Pesquisa define nomes/valores | |

**User's choice:** Query params nomeados, valores string

### Paginação

| Option | Description | Selected |
|--------|-------------|----------|
| page/per_page + meta completo | ?page&per_page (default 25, teto ~100); meta.pagination completo via Pagy | ✓ |
| Só page (per_page fixo) | Apenas ?page=N, per_page travado em 25 | |
| Cursor-based | Paginação por cursor; complexo demais para 10–30 clientes | |

**User's choice:** page/per_page + meta completo

---

## Histórico de aprovações

### Rota / aninhamento

| Option | Description | Selected |
|--------|-------------|----------|
| Aninhado por arte | GET /admin/artes/:id/approval_responses; mapeia has_many ordenado desc | ✓ |
| Por arte E por cliente | + endpoint agregado por cliente; mais uma rota/serializer | |
| Você decide | Pesquisa escolhe o aninhamento | |

**User's choice:** Aninhado por arte

### Campos de cada resposta

| Option | Description | Selected |
|--------|-------------|----------|
| Decisão + comentário + data | id, decision (string), comment, responded_at + status atual da arte | ✓ |
| Só o essencial | decision + responded_at; perde o comentário do cliente | |
| Você decide | Pesquisa define campos exatos | |

**User's choice:** Decisão + comentário + data

---

## Claude's Discretion

- Biblioteca/estratégia de serialização (herdada como aberta da Phase 21).
- Variantes/thumbnails da imagem além da URL principal.
- Ordenação padrão das listagens, nomes exatos dos campos JSON, teto exato de per_page.

## Deferred Ideas

- Endpoint de histórico agregado por cliente (`/admin/clients/:id/approval_responses`).
- Edição/exclusão de cliente e arte via API (PUT/PATCH/DELETE).
- Direct upload / signed_id e variantes/thumbnails de imagem.
- Rate limiting (Phase 24).
