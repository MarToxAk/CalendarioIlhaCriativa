# Phase 33: Upload de arquivo pela API de IA - Context

**Gathered:** 2026-11-08
**Status:** Ready for planning

<domain>
## Phase Boundary

A IA envia o arquivo da arte em `POST /api/v1/ai/artes` (multipart), e a arte entra em aprovação com o arquivo
anexado, já elegível a divulgação depois de aprovada. Hoje o endpoint recusa `media_file` com 400 (decisão D-06 da
fase 24) e só aceita `external_url`; uma arte com link externo é recusada no agendamento da divulgação. A fase
reverte D-06 apenas para o upload, sem mudar regra de negócio do model, aprovação ou divulgação.

</domain>

<decisions>
## Implementation Decisions

### Contrato do upload
- D-01: O arquivo chega como `multipart/form-data` no campo `media_file`, a mesma chave do admin. O 400 atual
  ("Upload de arquivo não é suportado") deixa de existir para esse campo.
- D-02: `external_url` e `media_file` juntos caem na regra existente do model ("Use arquivo OU link externo, não
  ambos") e viram 422. Nenhuma regra nova.
- D-03: `external_url` sozinho continua aceito (compatibilidade). A documentação avisa que uma arte assim não é
  divulgável até um humano subir o arquivo.
- D-04: Tipos e tamanho são os do model: image/jpeg, image/png, image/gif, video/mp4, video/quicktime, abaixo de
  50 MB. O teto de 16 MB do WhatsApp continua sendo validado só no agendamento da divulgação.

### Aprovação e divulgação
- D-05: A arte nasce `pending` e segue o fluxo normal: o cliente aprova pelo link. Nenhum atalho para a IA.
- D-06: Arte `caption_only` sem arquivo nem link continua 422 pela regra existente (`media_source_present`).
- D-07: A resposta do POST é a de hoje: 201 com o `ArteSerializer`; `media_url` aponta para o arquivo enviado e
  `media_source_type` vem `"upload"`.
- D-08: Arquivo inválido (tipo ou tamanho) vira 422 `validation_error` com `field: "media_file"`, no mesmo envelope
  dos outros erros.

### Limites, testes e documentação
- D-09: Sem throttle novo: continuam os 60 pedidos por minuto por chave do `Rack::Attack`.
- D-10: O tipo do arquivo é verificado pelo Active Storage (identifica pelos bytes). Sem validação própria extra.
- D-11: A mesma fase atualiza `docs/api-ia.md`: seção de upload e remoção do aviso "arte da API não é divulgável".
  O teste de sincronia entre rotas e documentação continua valendo.
- D-12: Testes de integração multipart com `test/fixtures/files/sample.jpg` e casos de erro, mais isolamento por
  cliente. A suíte roda no CI (o ambiente local tem a chave das credenciais que precede o `ENV`).

### Claude's Discretion
Nome do helper e organização interna do controller; formato exato das mensagens de erro além do envelope; como
montar o corpo multipart nos testes.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Arte` já tem `has_one_attached :media_file` com validação de tipo (jpeg, png, gif, mp4, quicktime) e tamanho
  (menos de 50 MB), mais `media_source_present` e `only_one_media_source`.
- `Api::V1::Ai::ArteSerializer` já resolve `media_url` e `media_source_type` para arquivo anexado.
- O `Admin::ArtesController` já permite `:media_file` e trata o anexo; serve de referência.
- O base controller da IA define `set_active_storage_current` (url_options), necessário para gerar `media_url`.
- Produção usa Active Storage em S3 (`config.active_storage.service = :amazon`).

### Established Patterns
- Envelope `{ data, meta, errors }` via `render_envelope` e `render_error`; `RecordInvalid` vira 422 com `field`.
- Testes de controller de IA setam `ENV["AI_API_KEY"]`, limpam o store do `Rack::Attack` e usam fixtures de arquivo.

### Integration Points
- `app/controllers/api/v1/ai/artes_controller.rb`: `create` (remove a recusa de `media_file`) e `arte_params`
  (permite `:media_file`).
- `docs/api-ia.md` (seção de `POST /artes` e a nota de divulgação) e `test/controllers/api/v1/ai/artes_controller_test.rb`.

</code_context>

<specifics>
## Specific Ideas

Sem requisitos específicos além do objetivo: a IA deve conseguir levar uma arte do zero até a divulgação sem que um
humano precise subir o arquivo depois (só a aprovação do cliente continua humana).

</specifics>

<deferred>
## Deferred Ideas

- Upload em base64 em JSON ou a partir de URL buscada pelo servidor: descartados nesta fase.
- Throttle específico para o POST com arquivo: só se aparecer abuso.
- Arte nascer já aprovada pela IA: contraria o fluxo de aprovação do cliente.

</deferred>
