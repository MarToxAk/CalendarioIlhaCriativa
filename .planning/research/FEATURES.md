# Feature Research — WhatsApp Auto-Post via Evolution API (v1.7)

**Domain:** Agendamento e disparo de posts em grupos de WhatsApp a partir de um painel de aprovação de artes (agência de social media, 10–30 clientes)
**Researched:** 2026-08-29
**Confidence:** HIGH para contratos de endpoint (lidos do código-fonte upstream no tag `2.3.7`) / LOW para as heurísticas de mercado e anti-ban (web, sem fonte primária)
**Scope:** SOMENTE as features novas do v1.7. Painel admin, portal do cliente, Arte/ApprovalResponse, ActionCable e API v1 já existem e não foram re-pesquisados.

---

## 0. Sourcing & Confidence

Os provedores curados (Context7/Ref) não estavam disponíveis nesta sessão, e `doc.evolution-api.com/v2/...` retornou **404** nas duas URLs testadas (a doc pública mudou de rota). A alternativa escolhida foi **ler o código-fonte upstream num tag fixo**, que é fonte primária e mais forte que a doc.

| Fonte | O que forneceu | Tier |
|---|---|---|
| `github.com/evolution-foundation/evolution-api` **@ tag `2.3.7`** (raw source) | Todos os paths, DTOs, schemas de validação e shapes de resposta | **HIGH** — fonte primária, versão fixada |
| `github.com/evolution-foundation/evolution-api` **@ tag `1.8.2`** | Diferença de payload v1 → v2 | **HIGH** |
| `github.com/WhiskeySockets/Baileys` `src/Types/GroupMetadata.ts` | Semântica de `announce`, `restrict`, `admin`, `addressingMode` | **HIGH** |
| WebSearch (blogs de vendors de bulk-WhatsApp) | Faixas de delay anti-ban, risco de ban | **LOW** — `gsd query classify-confidence --provider websearch` → LOW. Tratar como folclore convergente, não como norma |
| WebSearch (whapi/issues sobre `@lid`) | Formato de JID e migração LID | **LOW/MEDIUM** — corroborado pelo tipo `addressingMode` do Baileys (HIGH) |

> **Nota de versão:** `2.3.7` é o último tag estável da linha v2 no momento da pesquisa (`2.4.0-rc1/rc2` já existem como pré-release). **Tudo abaixo é v2** salvo onde marcado "v1". Fixe a versão do Evolution em produção — a diferença v1→v2 quebra 100% dos payloads de envio.

---

## 1. Contrato dos Endpoints Evolution (v2.3.7)

**Base:** `{EVOLUTION_URL}` · **Auth:** header `apikey: <chave>`
`apikey` aceita **a chave global** (`AUTHENTICATION_API_KEY`) **ou**, em rotas que têm `:instanceName` no path, o **token daquela instância** — `src/api/guards/auth.guard.ts`.
Montagem dos prefixos: `src/api/routes/index.router.ts:218-227` (`/instance`, `/message`, `/group`, `/chat`, `/webhook`).
Forma do path: `RouterBroker#routerPath(action)` → `/<action>/:instanceName` — `src/api/abstract/abstract.router.ts:23-28`. **A única exceção é `POST /instance/create`**, que é `.post('/create', ...)` sem param — `src/api/routes/instance.router.ts:18`.

### 1.1 Criar instância

```
POST /instance/create           → 201
Header: apikey: <GLOBAL_KEY>    (a chave global é obrigatória aqui)
```

Body (campos relevantes; schema completo em `src/validate/instance.schema.ts:24+`):

```json
{
  "instanceName": "cliente-42",
  "integration":  "WHATSAPP-BAILEYS",
  "qrcode":       true,
  "token":        "opcional-token-que-voce-escolhe",
  "number":       "5511999999999",
  "groupsIgnore": false,
  "rejectCall":   true,
  "msgCall":      "Este número não recebe chamadas.",
  "readMessages": false,
  "syncFullHistory": false,
  "webhook": {
    "enabled":  true,
    "url":      "https://app.exemplo.com/webhooks/evolution/cliente-42",
    "byEvents": false,
    "base64":   false,
    "headers":  { "X-Webhook-Token": "..." },
    "events":   ["CONNECTION_UPDATE", "QRCODE_UPDATED", "MESSAGES_UPDATE", "SEND_MESSAGE"]
  }
}
```

- `integration` ∈ `WHATSAPP-BAILEYS` | `WHATSAPP-BUSINESS` | `EVOLUTION` — `src/api/types/wa.types.ts:153-157`. **Use `WHATSAPP-BAILEYS`** (é a única que pareia por QR e a única que enxerga grupos).
- `groupsIgnore: false` é importante — com `true` o Baileys descarta eventos de grupo.
- `number` **não** pareia sozinho; só habilita `pairingCode` (pareamento por código de 8 dígitos em vez de QR).

Resposta (`src/api/controllers/instance.controller.ts:151-175` e `:253-300`):

```json
{
  "instance": { "instanceName": "cliente-42", "instanceId": "<uuid>", "integration": "WHATSAPP-BAILEYS", "status": "connecting" },
  "hash": "A1B2C3D4-....",
  "webhook": { "webhookUrl": "...", "webhookHeaders": {}, "webhookByEvents": false },
  "settings": { "...": "..." },
  "qrcode": { "pairingCode": null, "code": "2@abc...", "base64": "data:image/png;base64,iVBOR...", "count": 1 }
}
```

- **`hash` é o token/apikey da instância.** Se você não mandar `token`, o Evolution gera `uuidv4().toUpperCase()` (`instance.controller.ts:57-60`). **Persista `hash`** — é com ele que você chama os endpoints daquele cliente sem expor a chave global.
- `qrcode` só vem no corpo do create quando `qrcode: true` **e** `integration == WHATSAPP-BAILEYS`; o controller faz `await delay(5000)` antes de ler o QR (`instance.controller.ts:151-157`) — a chamada demora ~5s.

**Nome já em uso → `403 Forbidden`** com `This name "X" is already in use.` — `src/api/guards/instance.guard.ts:42-50`. Este é exatamente o gancho para o requisito "aceitar instância já existente": tratar 403 como "adotar" e seguir para `fetchInstances`/`connectionState`.

### 1.2 QR code / conectar

```
GET /instance/connect/{instanceName}      → 200
```

Comportamento (`instance.controller.ts:309-343`):

| Estado atual | Retorno |
|---|---|
| `open` | `{ "instance": { "instanceName": "...", "state": "open" } }` (delega para `connectionState`) — **sem QR** |
| `connecting` | `instance.qrCode` → `{ pairingCode, code, base64, count }` |
| `close` | reconecta, `await delay(2000)`, devolve `instance.qrCode` |

`wa.QrCode = { count?, pairingCode?, base64?, code? }` — `src/api/types/wa.types.ts:42-47`.
`base64` é um **data-URL PNG** já pronto para `<img src="...">` (gerado por `qrcode.toDataURL`, `whatsapp.baileys.service.ts:381-392`). `code` é o texto bruto do QR, se você preferir renderizar no cliente.

### 1.3 Estado da conexão

```
GET /instance/connectionState/{instanceName}   → 200
{ "instance": { "instanceName": "cliente-42", "state": "open" } }
```

`instance.controller.ts:393-400`. `state` é o `WAConnectionState` do Baileys: **`close` | `connecting` | `open`** (o tipo interno `wa.StateConnection` admite ainda `'refused'`, `wa.types.ts:128-132`).

### 1.4 Listar instâncias (adotar instância existente)

```
GET /instance/fetchInstances
GET /instance/fetchInstances?instanceName=cliente-42
```

Retorna as linhas Prisma do model `Instance` (`prisma/postgresql-schema.prisma`): `id, name, connectionStatus, ownerJid, profileName, profilePicUrl, integration, number, token, clientName, disconnectionReasonCode, disconnectionAt, createdAt, updatedAt` + counts. É a fonte para "esse número já está pareado, qual é o dono".
Com a chave global lista todas; com o token de uma instância lista só aquela (`instance.controller.ts:402-430`).

### 1.5 Logout / delete

```
DELETE /instance/logout/{instanceName}   → 200  { "status":"SUCCESS", "error":false, "response":{ "message":"Instance logged out" } }
DELETE /instance/delete/{instanceName}   → 200  { "status":"SUCCESS", "error":false, "response":{ "message":"Instance deleted" } }
POST   /instance/restart/{instanceName}  → 200  { "instance": { "instanceName":"...", "status":"connecting" } }
```

`instance.router.ts:76-95`, `instance.controller.ts:436-475`. `logout` desconecta o telefone mas **mantém** a instância; `delete` remove a instância (e é bloqueado se ela estiver `open` — o controller faz `connectionState` antes).

### 1.6 Listar grupos

```
GET /group/fetchAllGroups/{instanceName}?getParticipants=false    → 200
GET /group/findGroupInfos/{instanceName}?groupJid=1203...@g.us    → 200
```

⚠️ **`getParticipants` é obrigatório na query.** Sem ele: `400 "The getParticipants needs to be informed in the query"` — `abstract.router.ts` (`getParticipantsValidate`). Aceita a string `"true"`/`"false"`.

Resposta — array de (`whatsapp.baileys.service.ts:4448-4480`):

```json
[{
  "id": "120363000000000000@g.us",
  "subject": "Clientes VIP — Loja X",
  "subjectOwner": "5511999999999@s.whatsapp.net",
  "subjectTime": 1712345678,
  "pictureUrl": "https://pps.whatsapp.net/...",
  "size": 87,
  "creation": 1698765432,
  "owner": "5511999999999@s.whatsapp.net",
  "desc": "Grupo de novidades",
  "descId": "...",
  "restrict": false,
  "announce": true,
  "isCommunity": false,
  "isCommunityAnnounce": false,
  "linkedParent": "120363111111111111@g.us"
}]
```

`participants: [...]` só aparece com `getParticipants=true`.

### 1.7 Enviar texto

```
POST /message/sendText/{instanceName}     → 201
{ "number": "120363000000000000@g.us", "text": "Legenda do post", "delay": 1200, "linkPreview": true }
```

Schema: `required: ["number","text"]` — `src/validate/message.schema.ts` (`textMessageSchema`). Opcionais: `delay` (ms, é o tempo de "digitando…" **antes** do envio, não intervalo entre mensagens), `quoted`, `linkPreview`, `mentionsEveryOne`, `mentioned[]`.

### 1.8 Enviar mídia

```
POST /message/sendMedia/{instanceName}    → 201
{
  "number":    "120363000000000000@g.us",
  "mediatype": "image",
  "media":     "https://bucket.s3.amazonaws.com/arte.jpg",
  "caption":   "Legenda que acompanha a imagem",
  "fileName":  "arte.jpg",
  "mimetype":  "image/jpeg",
  "delay":     1200
}
```

`SendMediaDto` — `src/api/dto/sendMessage.dto.ts:71-82`; schema `required: ["number","mediatype"]`, `mediatype ∈ image|document|video|audio` (o DTO também aceita `ptv`).

### 1.9 Webhook por instância

```
POST /webhook/set/{instanceName}   → 201    { "webhook": { "enabled": true, "url": "...", "headers": {...}, "byEvents": false, "base64": false, "events": [...] } }
GET  /webhook/find/{instanceName}  → 200
```

`src/api/integrations/event/webhook/webhook.router.ts`, `event.dto.ts`.

### 1.10 Diferença v1 → v2 (por que a versão importa)

| | v1.8.2 | v2.3.7 |
|---|---|---|
| sendText body | `{ number, textMessage: { text }, options: { delay, presence } }` | `{ number, text, delay }` |
| sendMedia body | `{ number, mediaMessage: {...}, options: {...} }` | flat `{ number, mediatype, media, caption, ... }` |

Fonte: `src/api/dto/sendMessage.dto.ts` nos dois tags. Os paths (`/message/sendText/{instance}`, `/group/fetchAllGroups/{instance}`) são iguais nas duas — **só o corpo muda**, então uma integração escrita contra v1 falha silenciosamente com 400 em v2. Trave `EVOLUTION_API_VERSION` e valide no boot.

---

## 2. Identidade de grupo — o que a UI "escolha seus grupos" precisa

**Formato do JID:** `<id numérico>@g.us`. Grupos modernos: `120363XXXXXXXXXXXX@g.us`. Grupos legados: `<telefone do criador>-<timestamp de criação>@g.us`. Contatos individuais são `<telefone>@s.whatsapp.net`. *(LOW — websearch; corroborado por `createJid.ts`, que trata `-` + comprimento ≥ 24 como grupo e passa `@g.us` adiante sem tocar — HIGH.)*

> **Guarde o `id` verbatim.** Nunca reconstrua, normalize ou re-formate o JID. `createJid` (`src/utils/createJid.ts`) devolve qualquer string contendo `@g.us` intacta — é por isso que `number` no `sendText`/`sendMedia` aceita um JID de grupo direto, sem endpoint separado de "send to group".

**Campos que importam para a UI (dos 14 retornados):**

| Campo | Uso na UI | Obrigatório? |
|---|---|---|
| `id` | Chave de persistência (`divulgacao_grupos.group_jid`) | **Sim** |
| `subject` | Rótulo do checkbox | **Sim** |
| `size` | "87 membros" — dá noção de alcance e ajuda a diferenciar homônimos | Sim |
| `pictureUrl` | Avatar do grupo; melhora muito o reconhecimento visual | Nice |
| `announce` | **Badge "Só admins podem enviar"** — decide se o envio vai falhar | **Sim** |
| `isCommunity` / `isCommunityAnnounce` | Comunidades e o canal de avisos da comunidade não se comportam como grupo normal — esconder ou marcar | Sim |
| `linkedParent` | Agrupar grupos por comunidade na lista | Nice |
| `restrict` | Só afeta *editar o grupo*, não enviar | Não |
| `owner`, `subjectOwner`, `creation`, `desc`, `descId`, `subjectTime` | Sem uso na seleção | Não |

**Existe flag de "sou admin"? Não diretamente.**
`fetchAllGroups` **não** retorna nenhum campo tipo `isAdmin`/`iAmAdmin` no nível do grupo (`whatsapp.baileys.service.ts:4448-4480` — a lista de campos é fechada). Para descobrir:

1. Chame com `?getParticipants=true`;
2. Cada item de `participants[]` é um `GroupParticipant` do Baileys: `{ id, admin: 'admin' | 'superadmin' | null, isAdmin?, isSuperAdmin? }` — `Baileys/src/Types/GroupMetadata.ts`;
3. Compare `participant.id` com o `ownerJid` da instância (vem de `GET /instance/fetchInstances`).

**Cuidado (LOW→MEDIUM):** com a migração para `@lid`, `participant.id` pode vir como `<lid>@lid` enquanto `ownerJid` vem como `<telefone>@s.whatsapp.net` — a comparação ingênua falha. `GroupMetadata.addressingMode` (`'lid' | 'pn'`) indica qual esquema o grupo usa. **Trate "sou admin" como um sinal best-effort, nunca como bloqueio duro.**

**Posting em grupo com "só admins podem enviar" exige admin? Sim.**
`announce` é documentado no Baileys como *"is set when the group only allows admins to write messages"*. Se `announce == true` e o número conectado não é admin, o servidor do WhatsApp rejeita a mensagem — o Evolution devolve `400 BadRequestException` com o erro do Baileys stringificado (`sendMessageWithTyping` faz `throw new BadRequestException(error.toString())`). Não há pré-checagem: **a única defesa é ler `announce` na hora de listar e avisar na UI.**

Custo de `getParticipants=true`: o serviço já faz uma chamada `profilePicture(group.id)` **por grupo** dentro do loop (linha 4452), então `fetchAllGroups` é lento (segundos, dezenas de grupos). Pedir participantes agrava. → **Cachear.**

---

## 3. Envio de mídia — URL vs base64

**Aceita os dois.** O DTO comenta literalmente `// url or base64` (`sendMessage.dto.ts:81`) e a implementação ramifica com `isURL()` (`whatsapp.baileys.service.ts:2746-2790`).

O comportamento **não é simétrico**:

| `mediatype` | Se `media` é URL | Se `media` é base64 |
|---|---|---|
| `image` | **O host do Evolution baixa via `axios.get(..., {responseType:'arraybuffer'})`**, depois re-codifica com `sharp(...).jpeg()`; `mimetype` é **forçado** para `image/jpeg` e `fileName` default `image.jpg` | `Buffer.from(media,'base64')` → mesmo pipeline sharp → JPEG |
| `video` / `document` / `audio` | Passa `{ url }` para `prepareWAMessageMedia` do Baileys — **o Baileys faz o streaming da URL** | `Buffer.from(media,'base64')` |

**Consequências operacionais (todas HIGH — lidas do código):**

1. **A URL precisa ser alcançável a partir do container do Evolution**, não do Rails. Com ActiveStorage em disco local (estado atual) e Evolution em outro host, o `axios.get` falha. → confirma **INFRA-01 (S3)** como bloqueio real, não conveniência.
2. **PNG com transparência vira JPEG** (fundo preto/branco). Se as artes têm PNG transparente, converta antes com fundo explícito.
3. **`external_url` de Google Drive / Dropbox quebra**: links de compartilhamento devolvem HTML, não bytes. `sharp()` num buffer de HTML lança exceção → `400`. Precisa ou converter para link direto, ou bloquear na UI, ou re-hospedar.
4. **base64 é a saída de emergência** que dispensa URL pública: `Base64.strict_encode64(arte.media_file.download)`. Custo: +33% de payload; com o limite de 50 MB do model isso vira ~67 MB de JSON num POST. Aceitável para imagem, **ruim para vídeo**.

**Payload por tipo — mapeando o `Arte#media_type` existente:**

| `Arte.media_type` | Endpoint | Payload |
|---|---|---|
| `image` (0) | `POST /message/sendMedia/{inst}` | `{ number: jid, mediatype: "image", media: <url\|b64>, caption: arte.caption, fileName: "...jpg" }` |
| `video` (1) | `POST /message/sendMedia/{inst}` | `{ number: jid, mediatype: "video", media: <url\|b64>, caption: arte.caption, fileName: "...mp4", mimetype: "video/mp4" }` |
| `caption_only` (2) | `POST /message/sendText/{inst}` | `{ number: jid, text: arte.caption }` |

**A legenda é o campo `caption`** e vai *dentro do mesmo nó de mídia* (`prepareMedia[mediaType].caption = mediaMessage?.caption` — linha 2872). Ou seja: **uma única mensagem** com imagem + legenda, não duas. `sendText` não tem `caption` — o campo é `text`.

---

## 4. Ciclo de vida da instância e pareamento por QR

**Estados:** `close` → `connecting` → `open` (`WAConnectionState` do Baileys, exposto em `connectionState`).

**Validade do QR.** Não há TTL exposto pela API. O Baileys emite um novo `qr` em `connection.update` a cada poucos segundos (na prática ~20–30s por QR, comportamento do protocolo — MEDIUM); o Evolution regenera `instance.qrcode.base64/code` e incrementa `count` a cada emissão. Quando `count` atinge `QRCODE_LIMIT` (**default 30**, `.env.example:314`), ele dispara `QRCODE_UPDATED` com `{ message: "QR code limit reached, please login again", statusCode: badSession }` e `CONNECTION_UPDATE` com `connectionClosed` (`whatsapp.baileys.service.ts:336-355`). → **A janela de pareamento é finita (~30 QRs). A UI precisa de um botão "gerar novo QR" que chame `/instance/connect` de novo.**

**Como saber que pareou — polling vs webhook. Os dois funcionam; recomendo os dois.**

- **Webhook (preferido):** `CONNECTION_UPDATE` com `data.state == "open"`. É o caminho canônico e chega em ~1s.
- **Polling (fallback obrigatório):** `GET /instance/connectionState/{inst}` a cada 3–5s enquanto a tela do QR estiver aberta. Necessário porque em dev/rede local o Evolution pode não alcançar o host do Rails, e porque webhook perdido = tela travada para sempre.
- A tela de QR já é um caso perfeito para o **ActionCable/Turbo Streams que o projeto tem desde v1.5**: o job de polling ou o controller de webhook faz `broadcast_replace` no frame do QR.

**Quando o número é deslogado no telefone.** `connectionUpdate` recebe `connection: 'close'` com `lastDisconnect.error.output.statusCode`. O Evolution reconecta **automaticamente**, exceto para os códigos `DisconnectReason.loggedOut`, `DisconnectReason.forbidden`, `402`, `406` (`whatsapp.baileys.service.ts:428-430`). Nesses casos ele:

1. dispara webhook `STATUS_INSTANCE` com `{ status: "closed", disconnectionAt, disconnectionReasonCode, disconnectionObject }`;
2. grava `connectionStatus: 'close'` + `disconnectionReasonCode` na tabela `Instance`;
3. emite `logout.instance` e fecha o socket;
4. dispara `CONNECTION_UPDATE`.

→ **Instância deslogada nunca volta sozinha.** É preciso re-parear com QR novo. Um envio agendado para uma instância `close` falha inteiro. **Isso torna "checar `connectionState` antes de enfileirar o job" uma feature table-stakes, não um refinamento.**

---

## 5. Feedback de entrega

**A resposta síncrona do envio** é o `messageRaw` montado por `prepareMessage` (`whatsapp.baileys.service.ts:4652-4703`, retornado em `:2557`):

```json
{
  "key": { "remoteJid": "120363...@g.us", "fromMe": true, "id": "3EB0XXXXXXXXXXXXXXXX" },
  "pushName": "Você",
  "status": "PENDING",
  "message": { "imageMessage": { "caption": "...", "mimetype": "image/jpeg", "...": "..." } },
  "messageType": "imageMessage",
  "messageTimestamp": 1756400000,
  "instanceId": "<uuid>",
  "source": "web"
}
```

**`key.id` é o message id** — é o que você persiste em `divulgacao_grupos.wa_message_id` para correlacionar depois. HTTP `201` + `key.id` presente significa **"aceito e enfileirado pelo WhatsApp"**, não "entregue". Falha vira `400` com `BadRequestException(error.toString())` — mensagem de erro em texto livre, não estruturada.

**Entrega real só via webhook.** A escada de status é `{0:ERROR, 1:PENDING, 2:SERVER_ACK, 3:DELIVERY_ACK, 4:READ, 5:PLAYED}` (`src/utils/renderStatus.ts`, tipo em `wa.types.ts:134`). O evento `MESSAGES_UPDATE` entrega:

```json
{ "keyId": "3EB0...", "remoteJid": "120363...@g.us", "fromMe": true, "participant": "...", "status": "DELIVERY_ACK", "instanceId": "<uuid>" }
```

(`whatsapp.baileys.service.ts:1612-1620`, webhook em `:1702`). Envelope do webhook: `{ event, instance, data, destination, date_time, sender, server_url, apikey }` (`webhook.controller.ts:93-103`).

Eventos relevantes do enum `Events` (`wa.types.ts`): `qrcode.updated`, `connection.update`, `status.instance`, `send.message`, `messages.update`, `groups.upsert`, `groups.update`, `logout.instance`.

**Realidade sobre acks em grupo (MEDIUM):** em grupos o WhatsApp emite receipts por participante e o Baileys agrega; na prática o `DELIVERY_ACK` chega, mas de forma menos confiável e mais tardia que em 1:1, e `READ` raramente é útil. **Recomendação: modele o status por grupo como `pendente → enviado → falhou`, e trate `DELIVERY_ACK` como um enriquecimento opcional (`entregue`), não como a fonte de verdade do histórico.** O requisito do PROJECT.md ("enviado / falhou / pendente") é satisfeito só com a resposta síncrona — o webhook é diferencial.

---

## 6. Feature Landscape

### Table Stakes (sem isso o recurso não funciona / parece quebrado)

| Feature | Por que é esperada | Complexidade | Notas de implementação |
|---|---|---|---|
| Cliente ↔ instância Evolution (1:1) | Requisito explícito: cada cliente divulga pelo próprio número | **LOW** | Nova tabela `whatsapp_instances` (ou colunas em `clients`): `client_id`, `instance_name`, `instance_token` (o `hash`), `owner_jid`, `connection_state`, `last_state_at`. `instance_name` derivado determinístico (`cliente-#{client.id}`) para ser idempotente |
| Criar instância + exibir QR | Requisito explícito | **MEDIUM** | `POST /instance/create` (demora ~5s por causa do `delay(5000)`) → renderizar `qrcode.base64` direto num `<img>`. Botão "gerar novo QR" → `GET /instance/connect/{inst}` |
| Adotar instância já existente | Requisito explícito | **LOW** | Tratar o `403 "already in use"` do create como sucesso-com-adoção; validar via `GET /instance/fetchInstances?instanceName=` e gravar `ownerJid`. Se o token não for conhecido, cair para a chave global |
| Badge de estado da conexão | Sem isso o admin agenda para uma instância morta e só descobre no dia | **LOW** | `GET /instance/connectionState` + cache curto (30–60s). Mapear `open`/`connecting`/`close` → verde/âmbar/vermelho |
| Detecção de pareamento (polling **+** webhook) | Tela de QR sem feedback é inutilizável | **MEDIUM** | Polling a cada 3–5s enquanto a tela está aberta é o caminho obrigatório; webhook `CONNECTION_UPDATE` como fast-path. Broadcast via ActionCable (já existe) |
| Listar grupos com cache | Requisito explícito; a chamada é lenta demais para ser síncrona na request | **MEDIUM** | `GET /group/fetchAllGroups?getParticipants=false`, persistir em `whatsapp_groups` (`instance_id`, `group_jid`, `subject`, `size`, `announce`, `is_community`, `picture_url`, `synced_at`). Botão "Sincronizar grupos" explícito |
| UI de seleção de grupos (multi-select) | É o núcleo da feature | **LOW** | Checkboxes com nome + `size`. Badge vermelho quando `announce == true`. Esconder/desabilitar `isCommunityAnnounce` |
| Entidade `Divulgacao` | Requisito explícito; carrega o `datetime` que `Arte#scheduled_on` (`:date`) deliberadamente não tem | **LOW** | `client_id`, `arte_id`, `send_at` (**`datetime`, `Time.zone`**), `status`, `delay_min_seconds`, `delay_max_seconds` (snapshot do ENV no momento da criação). Validação: `arte.approved?` |
| Histórico por grupo | Requisito explícito | **LOW** | `divulgacao_grupos`: `divulgacao_id`, `group_jid`, `subject_snapshot`, `status` (pendente/enviado/falhou), `wa_message_id`, `error_message`, `sent_at`. `subject_snapshot` porque o nome do grupo muda |
| Job agendado com delay aleatório entre grupos | Requisito explícito | **MEDIUM** | Ver "Dependências" abaixo — a escolha do modelo de job é a decisão de arquitetura mais consequente da milestone |
| Só artes `approved` são selecionáveis | O calendário existe para aprovar; publicar não-aprovado destrói a proposta de valor | **LOW** | `Arte.approved` no scope do select + revalidar **no momento do envio** (o cliente pode pedir alteração depois do agendamento) |
| Pré-check de conexão antes de enviar | Instância `close` faz o disparo inteiro falhar | **LOW** | `connectionState` no início do job; se ≠ `open`, abortar e marcar tudo como falhou com motivo claro |
| Preview do que será enviado | Erro em disparo de WhatsApp é irreversível — não dá para deseditar | **LOW** | Renderizar mídia + legenda + lista de grupos + horário antes de confirmar |
| Cancelar uma Divulgação agendada | Erro de agendamento é inevitável | **LOW** | Flag `cancelled_at` checada **no job**, não só no enqueue (mais confiável que tentar remover job da fila) |
| Credenciais fora do repo | Segurança básica; padrão já estabelecido no projeto | **LOW** | `EVOLUTION_URL`, `EVOLUTION_API_KEY` via `.env` (dev/test) + `credentials` (prod), conforme decisão já registrada no PROJECT.md |

### Differentiators (valem o esforço, nesta ordem)

| Feature | Proposta de valor | Complexidade | Notas |
|---|---|---|---|
| Timeline de envio ao vivo | Um disparo para 15 grupos com delay de 30–90s leva 10–20 min. Sem progresso visível o admin fica no escuro e re-dispara | **LOW** | **ActionCable + Turbo Streams já existem desde v1.5.** Cada grupo enviado faz `broadcast_replace` na linha. É o melhor custo/benefício da milestone |
| Aviso `announce` na seleção | Converte uma falha silenciosa em decisão informada, na hora certa | **LOW** | Só ler o campo que já vem do `fetchAllGroups` |
| Retry manual por grupo | Falha de rede num grupo não deveria obrigar a refazer os 15 | **LOW** | Botão "reenviar" na linha de `divulgacao_grupos` com status `falhou` |
| Sincronização de grupos sob demanda + `synced_at` visível | O admin entende por que um grupo novo não aparece | **LOW** | "Sincronizado há 3 dias · Atualizar" |
| Detecção de logout com alerta | Instância `close` não volta sozinha; descobrir isso no dia do post é caro | **MEDIUM** | Webhook `STATUS_INSTANCE`/`CONNECTION_UPDATE` → marcar instância + toast/badge admin (infra de badge já existe) |
| Enriquecer com `DELIVERY_ACK` | "Entregue" em vez de só "Enviado" | **MEDIUM** | Webhook `MESSAGES_UPDATE` casando `keyId` com `wa_message_id`. **Faça depois** que o básico funcione — é dado opcional |
| Duplicar Divulgação | Mesma arte para outra data ou outro conjunto de grupos | **LOW** | Casa com o item de backlog ADM2-02 já existente |
| Circuit breaker por instância | Após N falhas seguidas, parar e alertar em vez de continuar martelando | **MEDIUM** | Protege contra ban e contra jobs zumbis |

### Anti-Features (NÃO construir)

| Feature | Por que pedem | Por que é problemática | Alternativa |
|---|---|---|---|
| **UI de configuração da faixa de delay** | "Quero controlar a velocidade" | Convida o admin a colocar 1s e queimar o número do cliente. O PROJECT.md já decidiu ENV — **mantenha** | Faixa fixa em ENV, exibida como texto informativo ("intervalo de 30 a 90s entre grupos") |
| **Enviar para "todos os grupos"** | Conveniência | Grupos pessoais, grupos de fornecedor, grupos de outro cliente. Um clique = incidente com o cliente | Seleção sempre explícita. No máximo, salvar/reutilizar um conjunto nomeado ("Divulgação padrão") |
| **Envio recorrente / cron por Divulgação** | "Toda segunda às 9h" | Multiplica o risco de ban por N, e cada arte é um item único aprovado individualmente — recorrência contradiz o fluxo de aprovação do produto | Duplicar Divulgação manualmente |
| **Caixa de entrada / responder mensagens de grupo** | "Já que temos a conexão…" | Vira um produto inteiro (Chatwoot já faz isso). Exige `MESSAGES_UPSERT`, storage de mídia, threading, leitura. Explode o escopo | Fora de escopo. Se um dia precisar, integrar Chatwoot (o Evolution já suporta nativamente) |
| **Cliente escolhe grupos / horário no portal** | "Empoderar o cliente" | O PROJECT.md já decidiu: o portal é **exclusivo para aprovação**. Contradiz a decisão registrada e adiciona superfície de auth | Admin decide (decisão já tomada) |
| **Envio a números individuais / lista de contatos** | "Enquanto isso, marketing direto" | É aí que os bans acontecem de verdade. Grupo = audiência opt-in; contato frio = spam | Só grupos. Não exponha um campo de número livre |
| **Auto-promover o número a admin do grupo** | Contornar `announce` | Não existe API para isso (só um admin promove). Tentar é ruído | Mostrar o badge `announce` e deixar o admin resolver no telefone |
| **Retry automático agressivo** | "Que não falhe" | Retry cego contra `announce`/banido/deslogado repete um erro determinístico e acelera o ban | Retry só para erros transitórios (timeout, 5xx), máx. 2 tentativas com backoff. `400` do WhatsApp é **permanente** — falhe rápido |
| **Editar/apagar mensagem já enviada** | "Errei a legenda" | O Evolution tem endpoints, mas a janela do WhatsApp é curta, os limites mudam, e falha parcial em 15 grupos gera estado inconsistente pior que o erro original | Preview obrigatório antes de confirmar |
| **Encurtador/tracking de link próprio** | Métricas de clique | Links encurtados aumentam classificação de spam no WhatsApp. Constrói infra nova para um sinal fraco | Nenhum. Se precisar de métrica, UTM na URL original |
| **Ler `READ`/`PLAYED` como métrica de engajamento** | "Quantos viram?" | Em grupo esses acks são por participante, incompletos e frequentemente ausentes. Um número errado é pior que nenhum | Parar em `DELIVERY_ACK`, e mesmo assim como enriquecimento |
| **Múltiplas instâncias por cliente / rotação de número** | "Distribuir o volume" | Complexidade de roteamento e de UI para 10–30 clientes que postam poucas vezes por semana. Rotação também é padrão típico de spammer | 1:1 cliente↔instância (decisão já registrada) |

---

## 7. Feature Dependencies

```
INFRA-01 (Active Storage S3, URL pública/presigned)
    └──required by──> Envio de mídia por URL
                          └──alternativa──> Envio por base64 (sem S3, mas limitado a imagem)

Instância por cliente (create / adopt)
    ├──requires──> Credenciais Evolution em ENV/credentials
    ├──required by──> QR / pareamento
    │                     └──required by──> connectionState "open"
    │                                           ├──required by──> Listar grupos (cache)
    │                                           │                     └──required by──> Seleção de grupos
    │                                           └──required by──> Job de envio (pré-check)
    └──required by──> Detecção de logout (webhook STATUS_INSTANCE)

Arte.status == approved ──required by──> Criar Divulgacao
Divulgacao + DivulgacaoGrupo ──required by──> Job de envio agendado
Job de envio ──produces──> wa_message_id ──required by──> Enriquecimento DELIVERY_ACK (webhook MESSAGES_UPDATE)

Webhook receiver (endpoint público + auth)
    ├──enhances──> Detecção de pareamento (fast-path; polling é o fallback obrigatório)
    ├──enhances──> Detecção de logout
    └──required by──> Enriquecimento DELIVERY_ACK

ActionCable/Turbo Streams (JÁ EXISTE, v1.5)
    ├──enhances──> Tela de QR (troca de QR ao vivo, "conectado!")
    └──enhances──> Timeline de envio ao vivo

Delay aleatório entre grupos ──conflicts with──> Job único síncrono por Divulgacao
```

### Notas de dependência

- **INFRA-01 é bloqueante de verdade, não cosmético.** O host do Evolution é quem baixa a URL (`axios.get` para imagem, streaming do Baileys para vídeo). Com ActiveStorage em disco local, `arte.media_file` não tem URL alcançável de fora. **Ou** INFRA-01 entra antes da fase de envio, **ou** a fase de envio usa base64 (e aceita a limitação em vídeo).
- **Delay aleatório vs modelo de job:** um único job que faz `sleep(rand(30..90))` entre 15 grupos ocupa um worker por 10–20 minutos e perde todo o progresso se o processo reiniciar. O padrão correto é **um job por grupo**, cada um auto-agendando o próximo com `set(wait: rand(min..max).seconds)` — ou N jobs pré-agendados com offsets cumulativos. Isso é uma **decisão de arquitetura, não um detalhe**; deve ser resolvida na fase de discussão do envio.
- **`Arte#scheduled_on` continua `:date` e não deve ser tocado.** `Divulgacao#send_at` é o `datetime`, exatamente como já decidido no PROJECT.md. **Elas são independentes**: a data no calendário do cliente ≠ o momento do disparo no WhatsApp. A UI precisa deixar isso explícito, senão o admin assume que agendar a arte já dispara.
- **Revalidar aprovação no job**, não só no formulário: o cliente pode pedir alteração entre o agendamento e o envio (`approved → change_requested`). Enviar uma arte que voltou a ser contestada é o pior modo de falha possível para este produto.
- **`Client#active == false`** já bloqueia o portal; deve bloquear disparo também.
- **`Arte#media_file` (50 MB, `image/jpeg|png|gif`, `video/mp4|quicktime`)** e `Arte#external_url` são fontes mutuamente exclusivas (validação `only_one_media_source` já existe). O serviço de envio precisa de um resolvedor único: `media_file.attached? ? url_do_storage : external_url`, **com validação de que `external_url` é um link direto** — links de share do Drive/Dropbox retornam HTML e quebram o `sharp()`.
- **`Arte#media_type == caption_only`** ⇒ `sendText`, e `caption` passa a ser **obrigatório** (hoje o model não exige `caption`). Validar na criação da Divulgação.
- Webhook receiver é um **endpoint público novo** num app cuja API v1 é toda autenticada. Precisa de shared-secret no path ou em header (`webhook.headers` do Evolution suporta headers customizados) + `Rack::Attack` (já instalado).

---

## 8. MVP Definition

### Launch With (v1.7)

- [ ] Service PORO `Evolution::Client` com timeout, retry só em transitórios e log estruturado — **tudo depende disso**
- [ ] `WhatsappInstance` por cliente: create com QR **e** adoção de instância existente (403 → adopt)
- [ ] Tela de QR com polling de `connectionState` + botão "gerar novo QR"
- [ ] Badge de estado da conexão na tela do cliente
- [ ] Sync + cache de grupos (`fetchAllGroups?getParticipants=false`), com `announce` visível
- [ ] `Divulgacao` + `DivulgacaoGrupo` com `send_at` datetime e status por grupo
- [ ] Seleção de arte **aprovada** + grupos + data/hora, com preview antes de confirmar
- [ ] Job de envio: pré-check `connectionState == open`, revalidação de `approved`, um job por grupo, delay aleatório de ENV
- [ ] `sendText` (caption_only) e `sendMedia` (image/video) com `caption`
- [ ] Histórico por grupo: pendente / enviado / falhou + `wa_message_id` + mensagem de erro
- [ ] Cancelar Divulgação agendada (checado dentro do job)
- [ ] INFRA-01: Active Storage S3 com URL alcançável pelo host do Evolution — **ou** decisão explícita de usar base64 no v1.7

### Add After Validation (v1.7.x)

- [ ] Timeline de envio ao vivo via ActionCable — *gatilho: o primeiro disparo real para >8 grupos*
- [ ] Retry manual por grupo — *gatilho: a primeira falha isolada*
- [ ] Webhook receiver + `CONNECTION_UPDATE`/`STATUS_INSTANCE` (pareamento rápido, alerta de logout) — *gatilho: polling se mostrar frágil ou uma instância cair sem ninguém notar*
- [ ] Marcador "sou admin" via `getParticipants=true` — *gatilho: primeira falha por `announce`*

### Future Consideration (v2+)

- [ ] `MESSAGES_UPDATE` → status "entregue" — *depende do webhook receiver estar maduro; valor marginal sobre "enviado"*
- [ ] Conjuntos de grupos salvos ("Divulgação padrão do Cliente X") — *só faz sentido depois de observar padrões reais de uso*
- [ ] Duplicar Divulgação — *casa com ADM2-02 do backlog*
- [ ] Circuit breaker por instância — *só depois de haver volume que justifique*

---

## 9. Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| `Evolution::Client` (service PORO) | HIGH | MEDIUM | **P1** |
| Instância por cliente (create + adopt) | HIGH | MEDIUM | **P1** |
| QR + polling de pareamento | HIGH | MEDIUM | **P1** |
| Badge de estado da conexão | HIGH | LOW | **P1** |
| Sync/cache de grupos | HIGH | MEDIUM | **P1** |
| Seleção de grupos com aviso `announce` | HIGH | LOW | **P1** |
| `Divulgacao` + `DivulgacaoGrupo` | HIGH | LOW | **P1** |
| Job com delay aleatório (um job por grupo) | HIGH | MEDIUM | **P1** |
| sendText / sendMedia + caption | HIGH | MEDIUM | **P1** |
| Histórico por grupo | HIGH | LOW | **P1** |
| Preview antes de confirmar | HIGH | LOW | **P1** |
| Cancelar agendamento | MEDIUM | LOW | **P1** |
| Pré-check de conexão + revalidação de `approved` no job | HIGH | LOW | **P1** |
| INFRA-01 (S3) | HIGH | MEDIUM | **P1** (bloqueia envio por URL) |
| Timeline ao vivo (ActionCable) | HIGH | LOW | **P2** |
| Retry manual por grupo | MEDIUM | LOW | **P2** |
| Webhook receiver (`CONNECTION_UPDATE`) | MEDIUM | MEDIUM | **P2** |
| Alerta de logout | MEDIUM | MEDIUM | **P2** |
| Flag "sou admin" (`getParticipants=true`) | MEDIUM | MEDIUM | **P2** |
| Status "entregue" (`MESSAGES_UPDATE`) | LOW | MEDIUM | **P3** |
| Conjuntos de grupos salvos | MEDIUM | LOW | **P3** |
| Duplicar Divulgação | LOW | LOW | **P3** |
| Circuit breaker | LOW | MEDIUM | **P3** |

---

## 10. Referência competitiva (como ferramentas do gênero se comportam)

| Comportamento | Padrão do mercado (n8n/Typebot/Chatwoot sobre Evolution; ferramentas de "bulk sender") | Nossa abordagem |
|---|---|---|
| Pareamento | QR embutido no painel + estado com polling | Igual, com ActionCable para o "conectou!" |
| Seleção de destino | Lista de grupos com busca; muitos oferecem "todos" | **Sem "todos"** — seleção explícita sempre |
| Intervalo entre envios | Configurável pelo usuário, default agressivo | **Fixo em ENV**, aleatório, não editável na UI |
| Feedback de entrega | Maioria mostra só "enviado"; poucos consomem `MESSAGES_UPDATE` | Enviado/falhou no v1.7; "entregue" opcional depois |
| Recorrência | Comum (e é a principal causa de ban relatada) | **Não construir** |
| Multi-número / rotação | Comum nos bulk senders | **Não** — 1:1 cliente↔instância |

*(Esta seção é LOW confidence — derivada de material de marketing de vendors, não de uso hands-on.)*

---

## Sources

**Primárias (HIGH) — código-fonte upstream em tag fixo:**

- `evolution-foundation/evolution-api` @ **`2.3.7`**
  - `src/api/routes/index.router.ts:218-227` — prefixos de montagem
  - `src/api/abstract/abstract.router.ts:23-28` — `routerPath` = `/<action>/:instanceName`; `getParticipantsValidate`, `groupValidate`
  - `src/api/routes/instance.router.ts` — create / connect / connectionState / fetchInstances / restart / logout / delete
  - `src/api/controllers/instance.controller.ts:37-175, 253-300, 309-343, 393-400, 402-430, 436-475` — shapes de resposta, `hash`, `delay(5000)`
  - `src/api/guards/auth.guard.ts` — `apikey` global vs token de instância
  - `src/api/guards/instance.guard.ts:42-50` — 403 "already in use"
  - `src/api/routes/group.router.ts` — `fetchAllGroups`, `findGroupInfos`, `participants`
  - `src/api/routes/sendMessage.router.ts:54-95` — `sendText` / `sendMedia` / `sendPtv`
  - `src/api/dto/sendMessage.dto.ts:16-82` — `SendTextDto`, `SendMediaDto` (`// url or base64`)
  - `src/validate/message.schema.ts` — `textMessageSchema` (`required: number,text`), `mediaMessageSchema` (`required: number,mediatype`)
  - `src/validate/instance.schema.ts:24+` — corpo do create e enum de `webhookEvents`
  - `src/api/types/wa.types.ts:42-47` (`QrCode`), `:128-134` (`StateConnection`, `StatusMessage`), `:153-157` (`Integration`), enum `Events`
  - `src/utils/renderStatus.ts` — mapa 0..5 → ERROR/PENDING/SERVER_ACK/DELIVERY_ACK/READ/PLAYED
  - `src/utils/createJid.ts` — `@g.us` passa intacto
  - `src/api/integrations/channel/whatsapp/whatsapp.baileys.service.ts:320-345` (getter `qrCode`), `:336-355` (QRCODE_LIMIT), `:381-400` (geração do QR), `:428-470` (close / loggedOut / STATUS_INSTANCE), `:1612-1620, :1702` (MESSAGES_UPDATE), `:2425, :2557` (retorno do envio), `:2746-2880` (`prepareMediaMessage`, axios+sharp, caption), `:4448-4480` (`fetchAllGroups`)
  - `src/api/integrations/event/webhook/webhook.router.ts`, `event.dto.ts`, `webhook.controller.ts:93-103` (envelope)
  - `prisma/postgresql-schema.prisma` — model `Instance`
  - `.env.example:256-267, 313-316, 360-380` — `WEBHOOK_*`, `QRCODE_LIMIT=30`, `S3_*`
- `evolution-foundation/evolution-api` @ **`1.8.2`** — `src/api/dto/sendMessage.dto.ts:25-70` (payload aninhado v1)
- `WhiskeySockets/Baileys` — `src/Types/GroupMetadata.ts` (`announce` = "only allows admins to write messages", `restrict`, `GroupParticipant.admin`, `addressingMode`)
- Repositório local — `app/models/arte.rb`, `app/models/client.rb`, `db/schema.rb`

**Secundárias (LOW) — WebSearch:**

- [Fetch All Groups — Evolution API Documentation (v1)](https://doc.evolution-api.com/v1/api-reference/group-controller/fetch-all-groups) — corrobora a lista de campos
- [Issue #2124 — fetchAllGroups retorna grupos sem `subject`](https://github.com/evolution-foundation/evolution-api/issues/2124) — bug conhecido; a UI precisa tolerar `subject` nulo
- [Issue #1872 — [META] `@lid` vs `@jid` handling](https://github.com/evolution-foundation/evolution-api/issues/1872) — migração LID em curso
- [What Is `lid` in WhatsApp Groups — Whapi](https://support.whapi.cloud/help-desk/groups/what-is-lid-in-whatsapp-groups)
- [Evolution API v2.2.0–v2.2.1 — Postman Collection](https://www.postman.com/agenciadgcode/evolution-api/documentation/1wphumy/evolution-api-v2-2-0-v2-2-1)
- [WhatsApp Anti-Ban Guide — WASenderApi](https://wasenderapi.com/blog/stop-getting-banned-the-ultimate-whatsapp-anti-ban-strategy-for-unofficial-apis-in-2025) e [YCloud](https://www.ycloud.com/blog/how-to-send-bulk-messages-on-whatsapp) — faixas de delay 15–90s, pausa longa a cada N mensagens (**material de vendor, tratar como heurística**)

---
*Feature research for: WhatsApp group auto-posting via Evolution API (Calendário de Aprovação de Artes v1.7)*
*Researched: 2026-08-29 · Evolution API v2, tag `2.3.7`*
