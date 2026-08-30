---
title: Contrato Evolution API — verificação empírica
date: 2026-08-29
context: Produzido no research da fase 25 (v1.7). Fonte canônica do contrato Evolution para as fases 25–30.
host_probed: https://whatsapp.bomcustoilhabela.com.br
status: read-path VERIFICADO contra o host real · write-path PENDENTE (UAT fases 26/28)
---

# Contrato Evolution API — o que o host da agência realmente responde

Este documento registra o resultado da verificação empírica exigida por **EVO-01 / CONTEXT.md D-06..D-08**.
Nenhum código das fases 25–30 deve assumir um shape que não esteja marcado **VERIFICADO** aqui.
Itens **PENDENTE** têm a fase de UAT onde serão fechados nomeada explicitamente.

## Como foi verificado

Probe HTTP real contra `https://whatsapp.bomcustoilhabela.com.br` em **2026-08-29**, sem credenciais
(só o caminho de leitura não-autenticado + verificação de enforcement de auth). Credenciais reais
(base URL + apikey global) e uma instância pareada com grupo de teste **não estavam disponíveis** nesta
sessão de research — por isso o caminho de envio fica PENDENTE.

## VERIFICADO — caminho de leitura (contra o host real, 2026-08-29)

| # (ASSUMIDO em SUMMARY) | Item | Resultado empírico | Impacto |
|---|---|---|---|
| **1. Versão do host** | `GET /` (sem auth) | `{"status":200,"message":"Welcome to the Evolution API, it is working!","version":"2.3.7","clientName":"evolution_exchange","manager":"http://whatsapp.bomcustoilhabela.com.br/manager","documentation":"https://doc.evolution-api.com","whatsappWebVersion":"2.3000.1046362407"}` | **O host roda exatamente `2.3.7`** — o mesmo tag em que STACK.md/FEATURES.md leram routers, DTOs e schemas. **Não há drift 2.4.x.** Os contratos lidos do código-fonte no tag `2.3.7` valem como verificados. |
| **2. `main` vs tag `2.3.7`** | idem | Moot — o host **é** `2.3.7`, não `main`. | O diff `auth.guard.ts` / `group.schema.ts` / `sendMessage.dto.ts` entre `main` e `2.3.7` deixa de ser risco: use o que está no tag `2.3.7`. |
| **Auth — header** | `GET /instance/fetchInstances` sem header | `HTTP 401` · `{"status":401,"error":"Unauthorized","response":{"message":"Unauthorized"}}` | Auth é enforced. |
| **Auth — `Authorization: Bearer`** | `GET /instance/fetchInstances` com `Authorization: Bearer <x>` | `HTTP 401` (mesmo corpo) | **`Authorization: Bearer` NÃO é aceito.** O único esquema é o header `apikey:` — confirma STACK.md §2. |
| **Auth — apikey inválida** | `GET /instance/fetchInstances` com `apikey: <inválida>` | `HTTP 401` (mesmo corpo) | Credencial inválida → `401` limpo, corpo JSON estruturado. Mapeia para `Permanent` na taxonomia EVO-03. |
| **Envelope de erro** | 401 e 404 observados | `{ "status": <int>, "error": <string>, "response": { "message": <string \| string[]> } }` — no `401` `message` é **string**; no `404` (`GET /rota/inexistente`) é **array**: `{"status":404,"error":"Not Found","response":{"message":["Cannot GET /nonexistent/route"]}}` | O parser de erro do `Evolution::Client` **não pode assumir que `response.message` é string.** Normalizar `Array(body.dig("response","message")).join(" ")`. |
| **Borda de rede** | headers de `GET /` | `server: cloudflare`, `cf-ray`, `x-powered-by: Express`, `alt-svc: h3`, `x-served-by: whatsapp.bomcustoilhabela.com.br` | **Há um Cloudflare na frente do Evolution.** Consequências para o client: (a) TLS é terminado na CF; (b) a CF impõe seu próprio teto de ~100 s em requests HTTP — um `read_timeout` > 100 s no client é inútil; (c) uploads/downloads grandes de mídia passam pela CF; (d) erros 5xx podem ser da CF (`cf-*` headers, HTML) e não do Evolution — o client deve tratar corpo não-JSON de 5xx como `Transient`. |

**Rotas confirmadas por leitura do código-fonte no tag `2.3.7` (FEATURES.md §1, HIGH), agora com a versão do host casada:**

- Auth: header `apikey: <chave>` — global (`AUTHENTICATION_API_KEY`) em qualquer rota; token da instância (`hash`) só em rotas com `:instanceName` no path.
- Forma do path: `{BASE}/{recurso}/{ação}/{instanceName}`. Única exceção: `POST /instance/create` (sem path param; `instanceName` no corpo).
- Leitura: `GET /instance/fetchInstances`, `GET /instance/connectionState/{instance}`, `GET /instance/connect/{instance}`, `GET /group/fetchAllGroups/{instance}?getParticipants=false` (**`getParticipants` obrigatório**, string `"true"`/`"false"`, senão `400`).
- Envio: `POST /message/sendText/{instance}` `{number, text, delay?}` · `POST /message/sendMedia/{instance}` `{number, mediatype, media, caption?, fileName?, mimetype?, delay?}`. `mediatype ∈ image|video|document|audio` (`ptv` também aceito pelo DTO). Para grupo, `number` = JID `...@g.us`.
- `delay` (ms) = simulação de "digitando", **bloqueia a request HTTP** — não é espaçamento entre grupos.
- QR: `qrcode.base64` é data-URI PNG completo (`data:image/png;base64,...`); `qrcode.count` incrementa; `QRCODE_LIMIT` default 30.
- Webhook: `POST /webhook/set/{instance}`; envelope `{ event, instance, data, destination, date_time, sender, server_url, apikey }`.

### Delta da fase 25-01 — round-trip autenticado pelo cliente do app (2026-08-29)

| Data | Item | Resultado | Impacto |
|---|---|---|---|
| 2026-08-29 | `Evolution::Client.fetch_instances` autenticado (`apikey` global) contra o host da agência | **NÃO EXECUTADO — credenciais indisponíveis.** `EVOLUTION_BASE_URL` / `EVOLUTION_GLOBAL_API_KEY` não resolveram em nenhuma fonte (ENV nem `credentials.evolution.*`) no momento da execução do plano 25-01. Caminho DEGRADADO do `<precondition>` acionado: os artefatos de código (`Gemfile +faraday`, `app/services/evolution.rb`, `app/services/evolution/errors.rb`, `app/services/evolution/client.rb`, `config/initializers/evolution.rb`) foram entregues e commitados; a verificação empírica do round-trip autenticado fica **DEFERIDA**. | SC2 / EVO-01 (fechamento do contrato de leitura autenticado + latência medida) **deferido** até a agência fornecer base URL + apikey global (D-06, `user_setup` do 25-01). Escalado ao desenvolvedor como lacuna de `user_setup` — não é falha de código nem de teste. Nenhum secret, token ou telefone foi escrito aqui. |

## PENDENTE — caminho de escrita (fechar em UAT, com credenciais + instância pareada)

| Item | Por que não fechou agora | Onde fecha |
|---|---|---|
| **3. Casing dos eventos de webhook** (`QRCODE_UPDATED` vs `qrcode.updated`; `CONNECTION_UPDATE` vs `connection.update`) | Sem instância pareada não há webhook emitido para observar | **UAT fase 26** (pareamento). Até lá, `WebhookProcessor` deve aceitar **as duas grafias** (`event.to_s.upcase.tr(".","_")`). |
| **4. O host do Evolution alcança este app Rails para webhook** | O app ainda não está deployado publicamente; hoje `192.168.3.203` | **UAT fase 26**, depois do deploy desta fase. Se não alcançar, o botão "Verificar conexão" (PAIR-05) é o caminho principal em dev. |
| **5. Teto real de mídia** (imagem e vídeo) através deste gateway | Precisa de `sendMedia` real para um grupo de teste com arquivos de 5/15/20/30 MB | **UAT fase 28** (Divulgação — validação de tamanho). Codificar o valor **medido**, não ~16 MB de heurística. |
| **6. `sendMedia`/`sendText` aceitam JID de grupo (`...@g.us`) em `number` neste build** | `createJid.ts` no tag `2.3.7` diz que sim (passa `@g.us` intacto), mas não há envio real confirmado | **UAT fase 28/29** (primeiro envio real a grupo de teste). |
| **Shape exato da resposta de `sendMedia` de sucesso** (`key.id`, `status: "PENDING"`) | Idem — precisa de envio real | **UAT fase 29.** FEATURES.md §5 tem o shape lido do código; confirmar `key.id` presente no `201`. |
| **Formato do erro de `sendMedia`** (retry vs discard) | O código faz `throw new BadRequestException(error.toString())` — texto livre. Precisa de casos reais (grupo `announce`, número não-admin, arquivo inválido) | **UAT fase 29** (taxonomia de retry do motor de envio). |
| **7. Camada anti-ban** (faixa de delay, warm-up, volume seguro) | Anedótica por natureza; nenhuma fonte tem metodologia | Nunca "fecha" — postura é conservadorismo (delay generoso via ENV, poucos grupos, warm-up). Ver PITFALLS.md §"Qualidade da evidência". |
| **8. `ProcessPrunedError` do solid_queue** (pruned → failed, sem retry) | Afirmação de README, não verificada contra a gem 1.4.0 instalada | **Research/plan da fase 29** (motor de envio). |
| **`GET /` de produção usa `http://` no `manager` e `documentation`** | O banner devolve `manager: http://...` (não https) apesar de a request ter sido https via CF | Cosmético para o app (ele não usa esses campos), mas indica que a config `SERVER_URL` do host pode estar como `http://` — irrelevante para o client, que usa a base URL que **nós** configuramos. |

## Decisões de client derivadas desta verificação (entram no `Evolution::Client` da fase 25)

- **Base URL:** `https://whatsapp.bomcustoilhabela.com.br` (sem porta; CF na frente).
- **Timeouts** (Claude's Discretion, resolvido aqui): `open_timeout: 5s`, `write_timeout: 10s`, `read_timeout: 30s` no caminho geral; **`read_timeout: 15s` nas leituras** (`connectionState`, `fetchAllGroups`, `fetchInstances`) via `req.options.timeout`. Teto da CF (~100 s) torna qualquer valor acima disso inútil — não passar de 60 s em nenhum caso.
- **Parser de erro:** normalizar `response.message` que pode ser string **ou** array; tratar corpo 5xx **não-JSON** (HTML da Cloudflare) como `Transient`.
- **Sem `Authorization` header** em nenhuma circunstância — só `apikey`.
- **`Net::OpenTimeout` / `ECONNREFUSED` / `SocketError` → `Transient`** (nada foi enviado). **`Net::ReadTimeout` → `Unknown`** (pode ter sido processado; nunca retry automático). **401/403 → `Permanent`**. **`connectionState != "open"` → `NotConnected`**.

## Fontes

- Probe HTTP real (`curl`) contra `https://whatsapp.bomcustoilhabela.com.br`, 2026-08-29 — `GET /`, `GET /instance/fetchInstances` (sem auth / Bearer / apikey inválida), `GET /rota-inexistente`.
- `.planning/research/STACK.md`, `FEATURES.md`, `ARCHITECTURE.md` — contrato lido do código-fonte `evolution-foundation/evolution-api` @ tag `2.3.7` (agora casado com a versão do host).

## Deploy reachability (phase 25) — 2026-08-29

Registrado pelo plano **25-04** (INFRA-01 / EVO-01 / CONTEXT.md D-12). Sem segredos,
tokens, assinaturas de URL presignada ou telefones nesta seção.

| Direção | Verificação | Resultado | Status |
|---|---|---|---|
| **Outbound — app → Evolution** | `Evolution::Client.fetch_instances` com a `apikey` global de `credentials.yml.enc`, contra `whatsapp.bomcustoilhabela.com.br` | `Array` com **6** instâncias, HTTP 200, latência ~**654 ms** (medido em `RAILS_ENV=development` a partir da máquina de build) | **VERIFICADO** — fecha o round-trip autenticado de leitura de EVO-01 que ficou DEFERIDO no 25-01 (credenciais agora presentes). Parser de erro / caminho de escrita permanecem PENDENTE (D-08, UAT 26/28/29). |
| **Inbound — Evolution host → app `/up`** | `curl -sS -I https://<app-hostname>/up` rodado **do host do Evolution / container** | **NÃO EXECUTADO** — o app ainda não está deployado num hostname público alcançável pelo host do Evolution; exige input out-of-band do operador | **PENDENTE (operador)** — se falhar, a fase 26 deve liderar com o botão manual "Verificar conexão" (PAIR-05) em vez do webhook (A4 / D-12). Não bloqueia a fase 25. |
| **Mídia — download de fora da LAN** | `curl -sS -I "<presigned-url>"` de um host **fora de `192.168.3.203`** (ou `docker exec` no container do Evolution) → esperado `HTTP/2 200` + `content-type` da arte | **NÃO EXECUTADO / BLOQUEADO** — o endpoint S3 configurado (`aws.endpoint` em `credentials.yml.enc`) responde `400 InvalidArgument: "S3 API Requests must be made to API port."` — o hostname aponta hoje para o **console do MinIO** (porta 9001), não para a **porta da API S3** (9000). `head_bucket` → `400 BadRequest`; `list_objects_v2` → o XML `InvalidArgument` acima. Endpoint TCP/TLS alcançável (`GET /` → 200, mas devolve o HTML do console, não XML S3). | **PENDENTE (operador)** — ver "Ações de operador" abaixo. Sem a API S3 alcançável, a rake `storage:migrate_to_s3` não copia nada e SC1 / INFRA-01 **não fecha** (flagged assumption A6). |

### Ações de operador para destravar INFRA-01 (SC1)

1. **Expor a porta da API S3 do MinIO** sob um hostname TLS (ex.: rotear `s3.bomcustoilhabela.com.br` para a porta **9000** da API, ou publicar um subdomínio dedicado à API). Hoje o hostname serve o console (porta 9001).
2. **Atualizar `aws.endpoint`** em `config/credentials.yml.enc` para esse hostname da API S3 (se mudar).
3. **Criar os buckets** `calendario-livia-production` (e `calendario-livia-development` para exercitar em dev), privados, `force_path_style`.
4. Rodar no host deployado: `bin/rails storage:migrate_to_s3` — conferir o resumo `copied: N skipped: N missing: 0 service_name_backfilled: N`.
5. Mintar uma URL presignada (`bin/rails runner "puts ActiveStorage::Blob.order(:id).last.url(expires_in: 15.minutes)"`) e rodar, **de fora de `192.168.3.203`**:
   `curl -sS -I "<presigned-url>"` → colar aqui a linha de status + `content-type` + `content-length` (sem a query string).
6. **Inbound**, do host do Evolution: `curl -sS -I https://<app-hostname>/up` → colar a linha de status.

> Recomendação de segurança (não bloqueia): as chaves `aws.*` gravadas são as credenciais ROOT do MinIO — emitir uma access key com escopo dos buckets `calendario-livia-*` e rotacionar antes/logo após o go-live.
