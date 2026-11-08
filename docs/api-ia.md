# API de IA — Calendário de Aprovação de Artes

Documentação para agentes de IA que operam o sistema. Base: `/api/v1/ai`.
Este texto também é servido por `GET /api/v1/ai/docs` (exige a mesma chave).

## 1. Regras que você precisa seguir

1. **Confirme com o humano antes de agendar.** `POST /divulgacoes` agenda de verdade e dispara mensagens
   em grupos reais de WhatsApp no horário combinado. Não existe rascunho, simulação nem campo de confirmação.
2. **O POST de divulgação não é idempotente.** Se uma chamada deu timeout, **não repita às cegas**:
   isso criaria uma segunda divulgação e cada grupo receberia duas mensagens. Primeiro liste as
   divulgações do cliente com `status=agendada` (seção 5.1) e veja se a sua já existe.
3. **Nunca invente ids.** Use sempre ids devolvidos pela API (`client_id`, `arte_id`, ids de grupo).
4. **Um cliente por vez.** Arte e grupos são resolvidos pelo cliente informado. Um id de outro cliente
   responde 404, sem revelar de quem é.
5. **Não há edição nem exclusão.** Só dá para criar, consultar e cancelar.

## 2. Autenticação

Todo pedido leva o header:

```
Authorization: Bearer ak_...
```

- A chave começa com `ak_` e é única para a agência toda (enxerga todos os clientes).
- Sem chave, chave sem o prefixo `ak_` ou chave errada: `401 unauthorized`.
- Envie `Content-Type: application/json` nos POST com corpo. A única exceção é o `POST /artes` com arquivo,
  que usa `multipart/form-data` (seção 5.2): não defina esse header à mão, porque o cliente HTTP escolhe
  o boundary sozinho.

## 3. Formato das respostas

Todas as respostas JSON usam o mesmo envelope:

```json
{ "data": { }, "meta": { }, "errors": [ ] }
```

Em erro, `data` é `null` e `errors` traz objetos `{ "code", "detail", "field" }` (`field` só em 422).

| Status | `code` | Quando |
|---|---|---|
| 400 | `bad_request` | Parâmetro ausente, malformado ou filtro inválido; também `media_file` que não seja um arquivo enviado em multipart |
| 401 | `unauthorized` | Chave ausente ou inválida |
| 404 | `not_found` | Recurso inexistente, ou id de outro cliente |
| 404 | `page_out_of_range` | `page` maior que o total de páginas |
| 422 | `validation_error` | Regra de negócio falhou (ver `detail` e `field`) |
| 429 | `too_many_requests` | Limite de 60 pedidos por minuto por chave. Aguarde e tente de novo |
| 503 | `enqueue_failed` | O disparo não pôde ser enfileirado; a divulgação foi cancelada |
| 503 | `storage_unavailable` | O arquivo da arte não pôde ser gravado. Em geral nada foi criado e é seguro tentar de novo; se o `detail` disser que a arte pode ter ficado criada, não repita às cegas: avise o humano |

**Paginação:** `?page=1&per_page=25` (padrão 25, máximo 100). A resposta traz em `meta.pagination`:
`page`, `per_page`, `total_count`, `total_pages`. `page` inválido (`abc`, `0`, `-1`) é 400.

**Datas:** `YYYY-MM-DD` nos filtros. Horários de agendamento em ISO 8601 **com offset**, por exemplo
`2026-11-20T14:00:00-03:00`.

## 4. Fluxo recomendado para divulgar uma arte

Se a arte ainda não existe, crie-a com `POST /artes` enviando o arquivo (seção 5.2). Ela nasce `pending` e o
cliente precisa aprová-la pelo link antes de aparecer no passo 1; não há atalho de aprovação para a IA.

1. `GET /artes?from=...&to=...&client_id=...` — encontre a arte aprovada (só aprovadas aparecem).
2. `GET /clients/:id/whatsapp_groups` — descubra os ids dos grupos do cliente.
3. **Confirme com o humano**: qual arte, quais grupos, que dia e hora.
4. `POST /divulgacoes` — agende.
5. `GET /divulgacoes/:id` — acompanhe o disparo (polling) até `concluida`.
6. Se precisar desistir antes do horário: `POST /divulgacoes/:id/cancel`.

## 5. Endpoints

### 5.1 Divulgações

#### `GET /divulgacoes` — listar as divulgações de UM cliente

| Parâmetro | Obrigatório | Descrição |
|---|---|---|
| `client_id` | **sim** | Cliente. Ausente ou malformado: 400. Inexistente: 404 |
| `status` | não | `agendada`, `em_andamento`, `concluida` ou `cancelada`. Outro valor: 400 |
| `from`, `to` | não | Intervalo inclusivo sobre `scheduled_for`, `YYYY-MM-DD`. Aceita só um extremo. O dia inteiro de `to` entra. `from` depois de `to`: 400 |
| `page`, `per_page` | não | Paginação |

Ordenação: `scheduled_for` crescente (as próximas primeiro). Resposta 200:

```json
{
  "data": [
    {
      "id": 41,
      "client_id": 7,
      "arte_id": 112,
      "status": "agendada",
      "scheduled_for": "2026-11-20T14:00:00.000-03:00",
      "created_at": "2026-11-07T10:02:11.000-03:00",
      "updated_at": "2026-11-07T10:02:11.000-03:00",
      "grupos": [
        {
          "group_name": "Clientes VIP",
          "remote_jid": "120363000000000001@g.us",
          "status": "pendente",
          "sent_at": null,
          "error_code": null
        }
      ]
    }
  ],
  "meta": { "pagination": { "page": 1, "per_page": 25, "total_count": 1, "total_pages": 1 } },
  "errors": []
}
```

Status do grupo (`grupos[].status`): `pendente`, `enviado`, `falhou`, `incerto`.
`incerto` significa que o envio pode ou não ter chegado: avise o humano, não reenvie por conta própria.

#### `GET /divulgacoes/:id` — consultar uma divulgação

Devolve o mesmo objeto da listagem (um só, em `data`). É por aqui que você acompanha o progresso.
Id inexistente: 404.

#### `POST /divulgacoes` — agendar (cria e enfileira o disparo)

Corpo JSON:

```json
{
  "client_id": 7,
  "arte_id": 112,
  "scheduled_for": "2026-11-20T14:00:00-03:00",
  "whatsapp_group_ids": [3, 9]
}
```

| Campo | Regra |
|---|---|
| `client_id` | Obrigatório. Nunca é inferido da arte |
| `arte_id` | Obrigatório. A arte precisa ser do cliente informado |
| `scheduled_for` | Obrigatório, ISO 8601 com offset, **no futuro** |
| `whatsapp_group_ids` | Lista de ids numéricos obtidos em `/clients/:id/whatsapp_groups`. Pelo menos um. Id não numérico: 400. Grupo inexistente, inativo ou de outro cliente: 404 |

Resposta 201 com a divulgação criada (`status: "agendada"`, um item de `grupos` por grupo, todos `pendente`).
O campo `status` não pode ser enviado: a divulgação nasce sempre agendada.

Erros 422 mais comuns (leia `errors[].detail`, em português):

- *Informe a data e hora do envio.* / *A data e hora do envio precisam estar no futuro.*
- *A arte selecionada não está aprovada.* Só artes aprovadas podem ser divulgadas.
- *Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar.* Veja a nota da seção 5.2.
- *O arquivo tem X, acima do limite de 16 MB que o WhatsApp aceita para mídia.*
- *Selecione ao menos um grupo para a divulgação.*

503 `enqueue_failed`: nada ficou agendado, e é seguro tentar de novo.

#### `POST /divulgacoes/:id/cancel` — cancelar

Sem corpo. Idempotente e sempre 200 com o estado atual:

- divulgação `agendada` passa para `cancelada`;
- qualquer outro status (`em_andamento`, `concluida`, já `cancelada`) não muda nada.

Confira o `status` da resposta: se vier `em_andamento` ou `concluida`, **o cancelamento não valeu**
e as mensagens seguem (ou já foram) enviadas.

### 5.2 Artes

#### `GET /artes` — listar artes aprovadas

| Parâmetro | Obrigatório | Descrição |
|---|---|---|
| `from`, `to` | **sim** | Intervalo de `scheduled_on`, `YYYY-MM-DD`. Falta de qualquer um: 400. `from` depois de `to`: 400 |
| `client_id` | não | Filtra por cliente |
| `page`, `per_page` | não | Paginação |

Só devolve artes com status `approved`, em ordem crescente de `scheduled_on`. Cada item:

```json
{
  "id": 112, "title": "Promo de novembro", "caption": "Texto da legenda",
  "scheduled_on": "2026-11-20", "approval_deadline": null,
  "platform": "instagram", "media_type": "image", "status": "approved",
  "client_id": 7, "media_url": "https://...", "media_source_type": "upload",
  "created_at": "...", "updated_at": "..."
}
```

`platform`: `instagram`, `facebook`, `linkedin`, `whatsapp`. `media_type`: `image`, `video`, `caption_only`.
`status`: `pending`, `approved`, `change_requested`, `revised`. `media_source_type`: `upload`, `link` ou `null`.

#### `POST /artes` — criar uma arte

| Parâmetro | Obrigatório | Descrição |
|---|---|---|
| `client_id` | **sim** | Cliente dono da arte |
| `scheduled_on` | **sim** | Data da postagem, `YYYY-MM-DD` |
| `platform` | **sim** | `instagram`, `facebook`, `linkedin` ou `whatsapp` |
| `media_type` | **sim** | `image`, `video` ou `caption_only` |
| `media_file` | **um dos dois** | O arquivo da arte, em `multipart/form-data` |
| `external_url` | **um dos dois** | Link da mídia (começa com `http://` ou `https://`) |
| `title`, `caption`, `approval_deadline` | não | Texto e prazo de aprovação |

Envie **exatamente um** entre `media_file` e `external_url`. Sem nenhum dos dois, inclusive para `caption_only`,
a resposta é 422.

**Regras do upload:**

- Corpo `multipart/form-data`, com o arquivo no campo `media_file`.
- Tipos aceitos: `image/jpeg`, `image/png`, `image/gif`, `video/mp4` e `video/quicktime`. O tipo é identificado
  pelo conteúdo do arquivo, não só pela extensão.
- Tamanho: menos de 50 MB.
- Arquivo e `external_url` juntos: 422 *Use arquivo OU link externo, não ambos*.

Exemplo:

```bash
curl -X POST "$BASE/api/v1/ai/artes" \
  -H "Authorization: Bearer ak_..." \
  -F client_id=7 -F scheduled_on=2026-11-20 -F platform=instagram -F media_type=image \
  -F title="Promo de novembro" -F media_file=@arte.jpg
```

**Resposta 201:** a arte criada, com `status: "pending"`, `media_source_type: "upload"` e `media_url`. A `media_url`
é um link assinado de curta duração: serve para conferir o arquivo agora e **não deve ser guardada** (o fluxo de
divulgação usa o `arte_id`). O cliente aprova a arte pelo link; só depois ela aparece em `GET /artes` e pode ser
divulgada.

**Erros:**

- 422 `validation_error` com `field: "media_file"`: tipo ou tamanho inválido.
- 400 `bad_request`: `media_file` que não é um arquivo (por exemplo, um texto dentro de um JSON). Envie o arquivo em
  `multipart/form-data`.
- 503 `storage_unavailable`: o arquivo não pôde ser gravado. Quando o `detail` diz "nada foi criado", é seguro tentar
  de novo. Se o `detail` disser que a arte (com o id) pode ter ficado criada sem arquivo, a limpeza falhou: não repita
  às cegas, avise o humano para conferir (e remover) essa arte, senão um novo POST duplica.

> **Importante:** `external_url` sozinho continua aceito por compatibilidade, mas **arte com link externo não pode
> ser divulgada** (422 no `POST /divulgacoes`, seção 5.1) até um humano subir o arquivo na arte pelo painel. Sempre que
> possível, envie o arquivo. Se criar uma arte só com link, avise o humano disso.

> **Timeout:** o `POST /artes` não é idempotente. Se der timeout, não repita às cegas: a arte pode ter sido criada e,
> enquanto estiver `pending`, ela não aparece em `GET /artes` (que só lista aprovadas). Avise o humano.

### 5.3 Clientes

#### `GET /clients/:id/summary` — contagem de artes por status

```json
{ "data": { "client_id": 7, "total": 40, "approved_count": 25, "pending_count": 8,
            "change_requested_count": 4, "revised_count": 3 }, "meta": {}, "errors": [] }
```

#### `GET /clients/:id/whatsapp_groups` — grupos de WhatsApp do cliente

Lista só os grupos **ativos** do cliente, lidos do cache local (não consulta o WhatsApp na hora).
Ordem: nome crescente, grupos sem nome por último. Paginado. Cada item:

```json
{ "id": 3, "remote_jid": "120363000000000001@g.us", "display_name": "Clientes VIP" }
```

O `id` é o valor a enviar em `whatsapp_group_ids`. Cliente sem WhatsApp conectado: 200 com lista vazia
(avise o humano que o cliente precisa parear o WhatsApp no painel antes).

## 6. Limites

- 60 pedidos por minuto por chave (`429` além disso).
- `per_page` máximo 100.
- Arquivo da arte (`POST /artes`): menos de 50 MB, nos tipos `image/jpeg`, `image/png`, `image/gif`, `video/mp4` e
  `video/quicktime`.
- Mídia de divulgação: até 16 MB. Um arquivo entre 16 e 50 MB é aceito no upload da arte, mas recusado no
  agendamento da divulgação (422).
- Um limite de tamanho de corpo no caminho até o app pode devolver 413 antes de a API responder. Se a resposta não
  trouxer o envelope JSON, avise o humano.
