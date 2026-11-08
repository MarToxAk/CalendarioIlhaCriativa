# Phase 33: Upload de arquivo pela API de IA - Research

**Researched:** 2026-11-08
**Domain:** Rails 8.1 API controller, multipart upload, Active Storage (S3/MinIO), active_storage_validations
**Confidence:** HIGH (comportamento central verificado rodando protótipos descartáveis contra o banco de teste pessoal; limites de proxy em produção ficam `[ASSUMED]`)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- Upload em base64 em JSON ou a partir de URL buscada pelo servidor: descartados nesta fase.
- Throttle específico para o POST com arquivo: só se aparecer abuso.
- Arte nascer já aprovada pela IA: contraria o fluxo de aprovação do cliente.
</user_constraints>

## Project Constraints (from CLAUDE.md)

Não existe `./CLAUDE.md` no repositório [VERIFIED: `ls` na raiz, sem CLAUDE.md]. Convenções efetivas vindas do repo e da memória do usuário:

- Idioma: português brasileiro em mensagens, docs e comentários (memória `user_language`).
- Estilo: `rubocop-rails-omakase` (`.rubocop.yml`: `inherit_gem: { rubocop-rails-omakase: rubocop.yml }`), `# frozen_string_literal: true` nos controllers de IA, arrays com espaços internos `[ x ]`.
- Gate de CI: `bin/rubocop`, `bin/brakeman`, `bin/bundler-audit`, `bin/rails db:test:prepare test` (`.github/workflows/ci.yml`).
- Memória `test_db_permission`: o banco de teste padrão pertence a outro usuário do SO; ver "Verificação local" abaixo para o caminho que funciona.
- `.planning/config.json`: `"nyquist_validation": false` (sem seção Validation Architecture formal), `"security_enforcement": true`, `"security_asvs_level": 1`, `"commit_docs": true`.

<phase_requirements>
## Phase Requirements

A fase não tem IDs em REQUIREMENTS.md (`**Requirements**: TBD` no ROADMAP). O planner deve usar D-01..D-12 como rastreio.

| ID | Descrição | Research Support |
|----|-----------|------------------|
| D-01/D-07 | multipart `media_file`, 201 com serializer | Padrão 1 (permit + save!), prova de runtime `multipart_ok: 201`, `media_source_type=upload` |
| D-02 | file + external_url juntos = 422 | Prova: `both: 422 "Use arquivo OU link externo, não ambos" field "base"`; NÃO copiar o `external_url = nil` do admin |
| D-04/D-08/D-10 | tipo/tamanho = 422 `field: "media_file"` | Provas: pdf, pdf-com-nome-jpg, 51 MB, todas 422 `field: "media_file"`. Ressalva sobre D-10 em Pitfall 3 |
| D-06 | caption_only sem nada = 422 | Regra existente `media_source_present` (inalterada) |
| D-09 | sem throttle novo | `api/ai_by_key` 60/60s já cobre `/api/v1/ai/` |
| D-11 | docs | Seção "Docs a editar" lista os 6 trechos de `docs/api-ia.md` |
| D-12 | testes | Seção Code Examples + "Verificação local" |
</phase_requirements>

## Summary

A mudança de código é mínima: remover o desvio `if params[:media_file].present?` do `create` e acrescentar `:media_file` ao `params.permit` de `arte_params`. Com isso, um POST `multipart/form-data` com `media_file` real devolve 201 pelo caminho existente (`Arte.new(arte_params)` seguido de `save!`, `ArteSerializer`), porque o model já tem `has_one_attached`, as validações `content_type`/`size` e as regras de fonte única. Tudo isso foi provado rodando um controller temporário contra o banco de teste pessoal (o controller foi revertido; `git status` limpo).

Há dois defeitos reais que a mudança "de uma linha" introduz e que o planner PRECISA cobrir. (1) Se `media_file` chegar como String (JSON `"media_file": "abc"` ou campo de texto no multipart), `params.permit(:media_file)` deixa passar o escalar e o Active Storage o interpreta como signed blob id, levantando `ActiveSupport::MessageVerifier::InvalidSignature` sem tratamento: 500. Provado. A correção é um guard `is_a?(ActionDispatch::Http::UploadedFile)` com 400. (2) O Active Storage faz o upload ao storage em `after_commit`, depois de a linha da arte já estar gravada. Se o S3/MinIO falhar, a requisição levanta exceção (500) mas a arte `pending` e o blob ficam gravados sem arquivo; um retry da IA cria duplicata. Provado com stub de `service.upload`. Recomenda-se um rescue estreito que remove a arte e responde 503.

Dois fatos que contradizem premissas do CONTEXT: D-10 ("identifica pelos bytes") só vale quando o conteúdo tem assinatura mágica reconhecível (PNG/PDF/JPEG reais são identificados corretamente; um arquivo de texto chamado `.jpg` com content type `image/jpeg` é aceito). E o teto de body em produção não está em lugar nenhum do repo: Puma e Rack não limitam, o Caddyfile não é o ingress real (o compose fala em nginx-proxy-manager), e o limite do proxy é `[ASSUMED]`.

**Primary recommendation:** `permit(:media_file)` + guard 400 para valor não-upload + rescue 503 para falha de storage; testes multipart SEM header `Content-Type`; atualizar 6 trechos de `docs/api-ia.md`; verificar localmente com o preload que anula só a chave das credentials.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Receber multipart e autenticar a chave `ak_` | API / Backend (`Api::V1::Ai::ArtesController`) | Rack middleware (`Rack::Attack`, parse multipart do Rack) | Parse de multipart é do Rack; auth e throttle já existem |
| Validar tipo/tamanho do arquivo | API / Backend (model `Arte`, `active_storage_validations`) | — | Regra de negócio já vive no model (D-04); controller não duplica |
| Persistir o arquivo | Database / Storage (Active Storage -> S3/MinIO em prod, Disk em test) | API / Backend (upload síncrono em `after_commit`) | Upload ocorre dentro do request web |
| Montar `media_url` | API / Backend (`ArteSerializer` via `blob.url`) | Storage (presigned GET) | URL presigned expira; ver Pitfall 6 |
| Limite de tamanho de body | CDN / Proxy (nginx-proxy-manager) | Puma/Rack (sem limite) | Nada no app barra 50 MB; o proxy é o único ponto possível |
| Documentação para a IA | API / Backend (`docs/api-ia.md`, servido por `DocsController`) | — | Markdown versionado, servido em `GET /api/v1/ai/docs` |

## Standard Stack

Nenhuma dependência nova. Tudo já está no `Gemfile`/`Gemfile.lock`.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rails / activestorage | 8.1.4.1 | `has_one_attached`, blob, upload em `after_commit` | já em uso [VERIFIED: `bundle exec gem list` -> `rails (8.1.4.1)`, `activestorage (8.1.4.1)`] |
| active_storage_validations | 3.0.5 | validators `content_type:` e `size:` no model | já em uso [VERIFIED: Gemfile.lock `active_storage_validations (3.0.5)`; Gemfile `gem "active_storage_validations"`] |
| marcel | 1.2.1 | identificação do MIME (bytes, depois nome/declarado) | usado pelo Active Storage [VERIFIED: Gemfile.lock `marcel (1.2.1)`] |
| rack | 3.2.8 | parse de multipart (Tempfile) | já em uso [VERIFIED: `bundle exec gem list` -> `rack (3.2.8)`] |
| rack-attack | 6.8.0 | throttle `api/ai_by_key` 60/60s (D-09) | já em uso [VERIFIED: Gemfile.lock `rack-attack (6.8.0)`] |
| aws-sdk-s3 | 1.229.0 | serviço `:amazon` (MinIO) em produção | já em uso [VERIFIED: Gemfile.lock `aws-sdk-s3 (1.229.0)`] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Arte.new(media_file: uploaded)` + `save!` | `ActiveStorage::Blob.create_and_upload!` antes de salvar | Falha de storage ocorreria antes de existir a arte (sem duplicata), mas validação inválida deixaria blob órfão no S3 a purgar. Mais código e foge do padrão do admin; só vale se o rescue 503 do Pattern 2 for recusado |
| guard no controller | `params.permit(media_file: [])`/schema | Strong params não distingue String de UploadedFile; o guard explícito é a forma direta |

**Installation:** nenhuma.

## Package Legitimacy Audit

Esta fase não instala pacotes externos. Todos os gems acima já estão travados no `Gemfile.lock` do projeto, em uso por fases anteriores.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| (nenhum novo) | — | — | — | — | — | N/A |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
IA (agente HTTP)
  | POST /api/v1/ai/artes   multipart/form-data
  |   Authorization: Bearer ak_...   (SEM Content-Type manual; o cliente HTTP define o boundary)
  v
[nginx-proxy-manager]  --(client_max_body_size: [ASSUMED] pode barrar < 50 MB)-->  413 antes de chegar ao app
  v
[Puma 8]  (http_content_length_limit = nil, sem limite)
  v
[Rack::Attack]  throttle api/ai_by_key 60/60s por chave  --> 429 (envelope JSON)
  v
[Rack multipart parser]  -> Tempfile; params[:media_file] = ActionDispatch::Http::UploadedFile
  v
[Api::V1::Ai::BaseController]  authenticate_ai_key! (401) ; set_active_storage_current (url_options)
  v
[ArtesController#create]
  |- media_file presente e NAO UploadedFile (String / Hash)?  --> 400 bad_request
  |- Arte.new(arte_params)  (permit inclui :media_file)
  |- save!
  |     validate: media_source_present / only_one_media_source (base)
  |               content_type + size (field "media_file")      --> RecordInvalid --> 422 envelope
  |     after_save : cria blob + attachment (linhas)
  |     after_commit: UPLOAD ao storage (S3 em prod)            --> falha = arte ja gravada (Pitfall 2)
  |     after_create_commit do attachment: enfileira ActiveStorage::AnalyzeJob
  v
[ArteSerializer.serialize]  media_url = media_file.url (presigned, curta) ; media_source_type = "upload"
  v
201 { data, meta, errors: [] }
```

### Recommended Project Structure

Sem arquivos novos de código. Edições:

```
app/controllers/api/v1/ai/artes_controller.rb      # create + arte_params (+ guard e rescue)
test/controllers/api/v1/ai/artes_controller_test.rb # substituir teste "media_file retorna 400"; novos testes multipart
docs/api-ia.md                                      # 6 trechos (ver abaixo)
```

### Pattern 1: permit + save! (o caminho feliz)

**What:** `media_file` entra em `arte_params`; o `create` perde o desvio de 400. `RecordInvalid` já é tratado por `rescue_from` no `Api::V1::BaseController`, que emite `field: e.attribute.to_s`.
**Quote verbatim do estado atual (base do diff):**

```ruby
  def create
    # D-06: IA usa apenas external_url — upload direto não é suportado
    if params[:media_file].present?
      render_error(code: "bad_request", detail: "Upload de arquivo não é suportado. Use external_url.", status: :bad_request)
      return
    end

    @arte = Arte.new(arte_params)
    @arte.save!
    render_envelope(data: Api::V1::Ai::ArteSerializer.serialize(@arte), status: :created)
  end
```
[VERIFIED: app/controllers/api/v1/ai/artes_controller.rb:40-50]

```ruby
    params.permit(
      :title, :caption, :scheduled_on, :approval_deadline,
      :external_url, :platform, :media_type, :client_id
    )
```
[VERIFIED: app/controllers/api/v1/ai/artes_controller.rb:55-58]

**Envelope de 422 (como o field aparece):**
```ruby
    errors = exception.record.errors.map do |e|
      { code: "validation_error", detail: e.full_message, field: e.attribute.to_s }
    end
```
[VERIFIED: app/controllers/api/v1/base_controller.rb:29-31] e `rescue_from ActiveRecord::RecordInvalid,         with: :unprocessable_entity` [VERIFIED: app/controllers/api/v1/base_controller.rb:5].

**Resultado provado (protótipo temporário, revertido):**
- `multipart_ok`: 201, `media_source_type: "upload"`, `status: "pending"`, `media_url` presente, `external_url` nil no registro.
- `both` (arquivo + external_url): 422, `"Use arquivo OU link externo, não ambos"`, `"field":"base"`.
- `pdf`: 422 `"detail":"Media file deve ser imagem ou vídeo","field":"media_file"`.
- `oversize` (51 MB): 422 `"detail":"Media file deve ter menos de 50MB","field":"media_file"`.
- `empty_media_file` (`media_file=""`): tratado como ausente, 422 `"Precisa de arquivo ou link externo"` (`field: "base"`).

### Pattern 2: guard de valor não-upload (obrigatório) e falha de storage (recomendado)

**What:** antes de `Arte.new`, recusar `media_file` presente que não seja `ActionDispatch::Http::UploadedFile`. Provado: sem o guard, String vira 500 (`InvalidSignature`); com o guard, String (JSON e campo de texto multipart) e Hash (JSON) viram 400 `bad_request`.

```ruby
# Source: protótipo verificado nesta pesquisa (controller temporário, depois revertido)
def create
  raw = params[:media_file]
  if raw.present? && !raw.is_a?(ActionDispatch::Http::UploadedFile)
    return render_error(
      code: "bad_request", status: :bad_request,
      detail: "media_file deve ser enviado como arquivo em multipart/form-data."
    )
  end

  @arte = Arte.new(arte_params)
  @arte.save!
  render_envelope(data: Api::V1::Ai::ArteSerializer.serialize(@arte), status: :created)
rescue ActiveRecord::RecordInvalid
  raise # deixa o rescue_from do base controller montar o 422
rescue StandardError => e
  # Upload ao storage roda em after_commit: a arte JA esta gravada quando ele falha.
  raise unless @arte&.persisted? && @arte.media_file.attached?

  Rails.logger.error("Ai::ArtesController#create: falha ao gravar arquivo da arte##{@arte.id}: #{e.class}: #{e.message}")
  @arte.destroy
  render_error(code: "storage_unavailable", status: :service_unavailable,
               detail: "Não foi possível gravar o arquivo. Nada foi criado; tente novamente.")
end
```

O rescue de storage é recomendação (Claude's Discretion, "organização interna do controller"). `@arte.destroy` apaga a linha; o blob e o attachment ficam sob `dependent: :purge_later` do `has_one_attached` (default) [ASSUMED: comportamento default do Active Storage, não executado]. O planner pode optar por apenas documentar o risco; ver Open Question 1.

### Pattern 3: teste multipart (como o corpo é montado)

**What:** em `ActionDispatch::IntegrationTest`, passar `params:` com um `fixture_file_upload` e NÃO enviar `Content-Type`. O rack-test detecta o `Rack::Test::UploadedFile` e monta o multipart com boundary. Provado: `request.content_type` => `multipart/form-data; boundary=...`.

```ruby
# Source: padrão já usado em test/controllers/api/v1/admin/artes_controller_test.rb:184-205
multipart_headers = { "Authorization" => "Bearer #{AI_API_KEY}" } # SEM "Content-Type"

post "/api/v1/ai/artes",
     params: {
       title: "Arte IA com Upload", scheduled_on: Date.current.to_s, platform: "instagram",
       media_type: "image", client_id: @client.id,
       media_file: fixture_file_upload("sample.jpg", "image/jpeg")
     },
     headers: multipart_headers
```

Observação: provado que mesmo passando `"Content-Type" => "application/json"` junto com um `fixture_file_upload`, o rack-test sobrescreve e envia multipart (201). Ou seja, o `@auth_headers` atual do teste (que inclui Content-Type JSON) não quebra o multipart no teste, mas deixa o teste enganoso; use headers próprios sem Content-Type. Os testes JSON existentes continuam como estão (`params: {...}.to_json` + Content-Type JSON).

Como `params.permit` e JSON x multipart divergem:
- JSON (`Content-Type: application/json`): `media_file` só pode ser String/Hash/etc.; nunca um `UploadedFile`. Qualquer valor presente cai no guard 400.
- multipart: arquivo chega como `ActionDispatch::Http::UploadedFile`; um campo de texto com a mesma chave chega como String (cai no guard 400).
- `permit(:media_file)` aceita escalares permitidos, incluindo String e `UploadedFile`; Hash/Array são descartados em silêncio (provado: JSON `media_file: {io: "x"}` sem guard dava 422 "Precisa de arquivo ou link externo"; com guard dá 400).

### Anti-Patterns to Avoid

- **Copiar `@arte.external_url = nil if params[:media_file].present?` do `Api::V1::Admin::ArtesController#create`** [VERIFIED: app/controllers/api/v1/admin/artes_controller.rb:16]. Isso descarta `external_url` em silêncio e faria D-02 (422) nunca disparar.
- **Confiar em `permit(:media_file)` como validação de tipo.** Ele deixa String passar (Pitfall 1).
- **Validar tipo/tamanho no controller.** O model já valida (D-04, D-10); duplicar quebra "nenhuma regra nova".
- **`assert_no_enqueued_jobs` sem bloco em teste com arquivo.** Ver Pitfall 4.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Validar content type e tamanho | checagem manual de `tempfile.size`/extensão | validators existentes em `Arte` (`content_type:`, `size:`) | já devolvem `field: "media_file"`, mensagens pt-BR, e checam spoof contra o IO |
| Identificar o MIME | leitura de magic bytes própria | Marcel via Active Storage | já roda no `attach` |
| Montar multipart nos testes | boundary/body manual | `fixture_file_upload` + `post params:` | rack-test monta e detecta |
| Throttle do upload | contador próprio | `Rack::Attack` `api/ai_by_key` (D-09) | já cobre `/api/v1/ai/` |
| Gerar `media_url` | presign manual | `arte.media_file.url` no `ArteSerializer` | já existente, com `ActiveStorage::Current.url_options` |

**Key insight:** o model já faz o trabalho; o risco da fase está nas bordas do controller (tipo do valor recebido, falha de storage) e na documentação, não na validação.

## Runtime State Inventory

Não aplicável: a fase é aditiva (nova capacidade), não é rename/refactor/migração. Nenhum dado armazenado, config de serviço, registro de SO, segredo ou artefato de build carrega string a renomear. Verificado: a fase só toca `artes_controller.rb`, um teste e `docs/api-ia.md`.

## Common Pitfalls

### Pitfall 1: `media_file` como String vira 500 (`InvalidSignature`)
**What goes wrong:** Com `:media_file` em `permit` e sem guard, JSON `"media_file": "blob_data_simulado"` ou um campo de texto multipart devolve 500.
**Why it happens:** `ActiveStorage::Attached::Changes::CreateOne` trata `String` como signed blob id: `when String` no `find_or_build_blob` (activestorage-8.1.4.1/lib/active_storage/attached/changes/create_one.rb) e chama `Blob.find_signed!`, que levanta `ActiveSupport::MessageVerifier::InvalidSignature: mismatched digest`. `ActionController::API` + `Api::V1::BaseController` só tratam RecordNotFound/RecordInvalid/ParameterMissing.
**How to avoid:** guard `is_a?(ActionDispatch::Http::UploadedFile)` -> 400 (Pattern 2). Provado nas duas formas (JSON e multipart-texto): erro `InvalidSignature` sem guard, 400 com guard. Isso também impede que uma IA/atacante reaproveite um signed blob id de outro cliente.
**Warning signs:** teste existente `"POST com media_file retorna 400"` (artes_controller_test.rb:159-176) manda `media_file: "blob_data_simulado"` em JSON: ele continua dando 400 com o guard, mas o nome/propósito deve ser reescrito para "string no campo media_file retorna 400".

### Pitfall 2: upload ao storage em `after_commit` deixa arte órfã se o S3 falhar
**What goes wrong:** S3/MinIO indisponível durante o POST: a requisição levanta (500), mas `Arte` (pending) e `ActiveStorage::Blob` já foram gravados, sem arquivo no bucket. A IA tenta de novo e cria duplicata; a arte quebrada aparece para o cliente/admin.
**Why it happens:** `after_save { attachment_changes[name.to_s]&.save }` grava as linhas e `after_commit(on: %i[ create update ]) { attachment_changes.delete(name.to_s).try(:upload) }` faz o upload depois do commit [VERIFIED: activestorage-8.1.4.1/lib/active_storage/attached/model.rb:142,144].
**How to avoid:** rescue estreito no controller (Pattern 2) que apaga a arte e responde 503, ou aceitar o risco e documentar "se receber 5xx, liste as artes do cliente antes de repetir" (padrão já usado na doc para divulgações).
**Prova:** stub de `ActiveStorage::Blob.service.upload` levantando `IOError` => `RAISED IOError: s3 down` e `Arte delta=1 Blob delta=1`.
**Warning signs:** 500 intermitente no POST com arquivo e artes sem imagem no painel.

### Pitfall 3: D-10 vale só em parte ("identifica pelos bytes")
**What goes wrong:** um arquivo de texto chamado `x.jpg` enviado com `image/jpeg` é aceito (201), com blob `image/jpeg`.
**Why it happens:** a identificação por Marcel usa os bytes quando há assinatura mágica; sem assinatura, cai no nome/declarado. Provado: PDF real com nome `.jpg` e `image/jpeg` => 422 (`application/pdf` não é permitido); PNG real com nome `.jpg` => 201 e blob armazenado como `image/png`; texto puro com nome `.jpg` => 201.
**How to avoid:** não há ação obrigatória (D-10 diz "sem validação própria extra"). O planner deve apenas escrever o teste de tipo inválido com um conteúdo identificável (PDF) e NÃO com texto puro, que passaria. Registrar o limite na Assumptions Log para o humano.
**Observação:** `test/fixtures/files/sample.jpg` tem 22 bytes (`ffd8 ffe0 0010 4a46 4946 0001 0100 0001 0001 0000 ffd9`), é identificado como `image/jpeg` e serve para o caminho feliz.

### Pitfall 4: `assert_no_enqueued_jobs` sem bloco com arquivo (lição CR-02 da fase 32)
**What goes wrong:** o POST com arquivo enfileira `ActiveStorage::AnalyzeJob`; asserts "nada enfileirado" sem bloco falham.
**Why it happens:** `after_create_commit` do attachment enfileira a análise; provado `jobs: ["ActiveStorage::AnalyzeJob"]` após o POST multipart. Só o AnalyzeJob foi enfileirado (nenhum mirror).
**How to avoid:** nos testes de erro, usar a forma de bloco (`assert_no_enqueued_jobs do ... end`) ou não afirmar jobs; no caminho feliz, `assert_enqueued_with(job: ActiveStorage::AnalyzeJob)` é opcional. Nos casos 4xx provados, `Arte`, `Blob` e `Attachment` não mudam (`BOTH 422 deltas=[0, 0, 0]`, `BADCLIENT 422 deltas=[0, 0, 0]`), então dá para afirmar `assert_no_difference [ "Arte.count", "ActiveStorage::Blob.count" ]`.

### Pitfall 5: limite de tamanho de body fora do app
**What goes wrong:** 413 do proxy antes de chegar ao Rails para arquivos grandes.
**Findings:**
- Puma: `http_content_length_limit: nil` por padrão [VERIFIED: puma-8.0.2/lib/puma/configuration.rb:146] e `config/puma.rb` não o define [VERIFIED: leitura de config/puma.rb]. Sem limite.
- Rack 3.2.8: só limita contagem de partes (`multipart_file_limit` 128, `multipart_total_part_limit` 4096) [VERIFIED: rack-3.2.8/lib/rack/utils.rb:76,80]; não há limite de bytes. Um único arquivo não encosta nesses limites.
- App: nenhum `client_max_body_size`/limite no repo [VERIFIED: grep em deploy, docker-compose.yml, config, docs, README sem ocorrência].
- Caddy (`deploy/Caddyfile`) é só `reverse_proxy web:3000`, sem `request_body max_size` [VERIFIED: deploy/Caddyfile]; mas o `docker-compose.yml` diz que o ingress é o nginx-proxy-manager ("o nginx-proxy-manager que faz TLS + ingress público"), então o Caddyfile não é o caminho real.
- nginx-proxy-manager: o default de `client_max_body_size` não foi confirmado (a busca web só devolveu o default de 1 MB do nginx puro). [ASSUMED] O upload do admin (50 MB) usa o mesmo caminho; se ele já funciona em produção, a IA também funcionará.
**How to avoid:** item de checagem humana (checkpoint) antes de declarar a fase pronta: enviar um arquivo de ~20 MB real pela URL pública e conferir; se der 413, ajustar o proxy host (Advanced: `client_max_body_size 55m;`). Documentar na seção Limites de `docs/api-ia.md` "arquivo de até 50 MB".

### Pitfall 6: `media_url` é presigned e expira
**What goes wrong:** a IA guarda `media_url` e a usa tarde; o link expirou.
**Why it happens:** em produção o serviço `:amazon` é privado e `blob.url` gera GET presigned [VERIFIED: config/storage.yml comentários "O serviço fica privado (sem a chave de acesso público)"]. `config.active_storage.service_urls_expire_in` não é definido em nenhum arquivo do repo [VERIFIED: grep em config/ e app/ sem ocorrência], logo vale o default do Rails [ASSUMED: 5 minutos, não confirmado nesta sessão].
**How to avoid:** na doc, orientar a não persistir `media_url` (a URL é para consulta imediata; o fluxo de divulgação usa `arte_id`, não a URL). Em teste, `media_url` com Disk é `http://www.example.com/rails/active_storage/disk/...` [VERIFIED: saída do protótipo].
**Nota:** `ArteSerializer.resolve_media_url` engole exceção e devolve `nil` (`rescue => e` com log) [VERIFIED: app/serializers/api/v1/ai/arte_serializer.rb:32-34]; em produção um 201 com `media_url: null` é possível se o presign falhar.

### Pitfall 7: `client_id` inexistente dá 422 com mensagem "Translation missing"
**What goes wrong:** `client_id` inválido devolve 422 com `detail` contendo "Client Translation missing. Options considered were: pt-BR.activerecord.errors.models.arte.attributes.client.required ..." (provado). Comportamento pré-existente, não relacionado ao upload.
**How to avoid:** não é escopo; não asserte o texto desse detalhe nos testes, só o status 422 e a ausência de efeitos (nenhuma arte/blob criado).

### Pitfall 8: upload síncrono ocupa uma thread do Puma
**What goes wrong:** upload de 50 MB ao MinIO ocupa uma das 3 threads por worker durante o request.
**Why it happens:** `threads 3` por padrão (`RAILS_MAX_THREADS` 3) e `WEB_CONCURRENCY: 2` no compose [VERIFIED: config/puma.rb `threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)`; docker-compose.yml `WEB_CONCURRENCY: 2`]; o throttle de 60/min não limita concorrência.
**How to avoid:** sem ação nesta fase (D-09 trava o throttle). Registrar como risco aceito; só vira ação se aparecer abuso (Deferred).

## Code Examples

### Casos de teste a adicionar (esqueleto)

```ruby
# Source: padrões do próprio arquivo (setup com AI_API_KEY, Rack::Attack.cache.store.clear)
# e do teste admin test/controllers/api/v1/admin/artes_controller_test.rb:184-205

setup do
  # ... setup existente ...
  @multipart_headers = { "Authorization" => "Bearer #{AI_API_KEY}" } # sem Content-Type
end

def multipart_params(extra = {})
  {
    title: "Arte IA com Upload", scheduled_on: Date.current.to_s, platform: "instagram",
    media_type: "image", client_id: @client.id
  }.merge(extra)
end

test "POST multipart com media_file retorna 201 upload e media_url" do
  assert_difference "Arte.count", 1 do
    post "/api/v1/ai/artes",
         params: multipart_params(media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
         headers: @multipart_headers
  end
  assert_equal 201, response.status
  data = response.parsed_body["data"]
  assert_equal "upload",  data["media_source_type"]
  assert_equal "pending", data["status"]
  assert data["media_url"].present?
  arte = Arte.find(data["id"])
  assert arte.media_file.attached?
  assert_nil arte.external_url
end

test "POST multipart com arquivo e external_url retorna 422 (D-02)" do
  assert_no_difference [ "Arte.count", "ActiveStorage::Blob.count" ] do
    post "/api/v1/ai/artes",
         params: multipart_params(external_url: "https://example.com/a.jpg",
                                  media_file: fixture_file_upload("sample.jpg", "image/jpeg")),
         headers: @multipart_headers
  end
  assert_equal 422, response.status
  assert_equal "Use arquivo OU link externo, não ambos", response.parsed_body.dig("errors", 0, "detail")
end

test "POST multipart com tipo invalido retorna 422 field media_file (D-08)" do
  pdf = Tempfile.new([ "doc", ".pdf" ]); pdf.write("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"); pdf.rewind
  assert_no_difference [ "Arte.count", "ActiveStorage::Blob.count" ] do
    post "/api/v1/ai/artes",
         params: multipart_params(media_file: Rack::Test::UploadedFile.new(pdf.path, "application/pdf")),
         headers: @multipart_headers
  end
  assert_equal 422, response.status
  assert_equal "media_file", response.parsed_body.dig("errors", 0, "field")
end

test "POST multipart com arquivo acima de 50 MB retorna 422 field media_file (D-04/D-08)" do
  big = Tempfile.new([ "big", ".jpg" ]); big.binmode
  big.write(File.binread(file_fixture("sample.jpg"))); big.write("\0" * (50.megabytes + 1)); big.rewind
  post "/api/v1/ai/artes",
       params: multipart_params(media_file: Rack::Test::UploadedFile.new(big.path, "image/jpeg")),
       headers: @multipart_headers
  assert_equal 422, response.status
  assert_equal "media_file", response.parsed_body.dig("errors", 0, "field")
end

test "POST com media_file em texto (JSON) retorna 400" do
  post "/api/v1/ai/artes",
       params: multipart_params(media_file: "blob_data_simulado").to_json, headers: @auth_headers
  assert_equal 400, response.status
  assert_equal "bad_request", response.parsed_body.dig("errors", 0, "code")
end

test "arte criada por upload so aparece em GET apos aprovada, filtrada por cliente" do
  # cria por upload para @client e para outro cliente; aprova ambas; GET ?client_id=@client.id
  # devolve so a do @client com media_source_type "upload" (isolamento D-12)
end
```

Notas de teste:
- `Rack::Test::UploadedFile.new(path, type)` com `Tempfile` já provado nos protótipos (pdf, 51 MB).
- 50 MB + 1 byte: o teste de 51 MB provado rodou em ~1 s; alocar `"\0" * (50.megabytes + 1)` é aceitável.
- Para o teste de falha de storage (se o planner adotar o rescue 503): `ActiveStorage::Blob.service.stub(:upload, ->(*, **) { raise IOError, "s3 down" })` (`minitest/mock` já carregado em `test_helper`), e afirmar 503 e `assert_no_difference "Arte.count"`.

### Docs a editar em `docs/api-ia.md`

1. Seção 1 regra 5 ("Não há edição nem exclusão"): sem mudança.
2. Seção 2 linha "Envie `Content-Type: application/json` nos POST com corpo": acrescentar a exceção `POST /artes` com arquivo, que usa `multipart/form-data` (não definir o header à mão; o cliente HTTP define o boundary) [VERIFIED: docs/api-ia.md, trecho "Envie `Content-Type: application/json` nos POST com corpo."].
3. Seção 3, linha 400 `bad_request` da tabela: incluir "`media_file` que não seja um arquivo multipart".
4. Seção 4 (fluxo): opcional, adicionar passo 0 "criar a arte com `POST /artes` (arquivo)" e "o cliente aprova pelo link".
5. Seção 5.2 `POST /artes` — REMOVER a frase "Upload de arquivo **não é suportado** (`media_file` devolve 400): use `external_url`..." e o bloco "> **Importante:** uma arte criada pela API tem `external_url`, e **arte com link externo não pode ser divulgada** ... um humano precisa subir o arquivo na arte pelo painel" [VERIFIED: docs/api-ia.md, seção 5.2]. Substituir por: campo `media_file` multipart (tipos `image/jpeg`, `image/png`, `image/gif`, `video/mp4`, `video/quicktime`, menos de 50 MB), exemplo `curl -F`, 422 `field: "media_file"` para tipo/tamanho, file+link juntos = 422, `external_url` sozinho continua aceito mas a arte não é divulgável até um humano subir o arquivo (D-03), arte nasce `pending` e o cliente aprova pelo link, e aviso de que `media_url` é temporária.
6. Seção 6 Limites: acrescentar "Arquivo da arte: até 50 MB; mídia de divulgação: até 16 MB (validado no agendamento)".

Exemplo de curl para a doc (campos simples como `-F`, arquivo como `-F media_file=@arte.jpg`):

```bash
curl -X POST "$BASE/api/v1/ai/artes" \
  -H "Authorization: Bearer ak_..." \
  -F client_id=7 -F scheduled_on=2026-11-20 -F platform=instagram -F media_type=image \
  -F title="Promo de novembro" -F media_file=@arte.jpg
```

O teste `a documentacao cita todas as rotas de IA registradas` [VERIFIED: test/controllers/api/v1/ai/docs_controller_test.rb] procura `"#{verb} #{route}"` (ex.: `POST /artes`) no texto; nenhuma rota nova é criada, então basta não remover os cabeçalhos `#### \`POST /artes\``.

## Verificação local (como rodar os testes da IA aqui)

O banco de teste padrão não é acessível (memória `test_db_permission`) e a chave das credentials (`api.ai_key`) precede o `ENV["AI_API_KEY"]` em `authenticate_ai_key!` [VERIFIED: app/controllers/api/v1/ai/base_controller.rb:21-22: `expected = Rails.application.credentials.dig(:api, :ai_key) || ENV["AI_API_KEY"]`], por isso os testes de IA dão 401 localmente. Receita validada nesta sessão (11 runs, 0 failures em `artes_controller_test.rb`):

1. Banco: existe `calendario_livia_test_bot` pertencente a `bot`, acessível por socket Unix (TCP em `localhost` pede senha). Variáveis: `RAILS_ENV=test TZ=America/Sao_Paulo POSTGRES_HOST=/var/run/postgresql POSTGRES_USER=bot DATABASE_URL="postgres://bot@/calendario_livia_test_bot?host=/var/run/postgresql"` mais os valores dummy do CI para Evolution/S3/encryption (copiar de `.github/workflows/ci.yml`, linhas "Config env-driven": `EVOLUTION_BASE_URL`, `EVOLUTION_GLOBAL_API_KEY`, `EVOLUTION_WEBHOOK_HMAC_KEY`, `EVOLUTION_WEBHOOK_BASE_URL`, `S3_ENDPOINT`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `ACTIVE_RECORD_ENCRYPTION_*`). São dummies públicos do CI, não segredos.
2. Preload que anula só `credentials.dig(:api, :ai_key)` (nunca lê nem imprime o valor, não toca `.env`/master key), salvo fora do repositório:

```ruby
# /tmp/claude-1000/-home-bot-calendario-livia/ad2f17c2-eb98-4065-80ed-269b0cf4577c/scratchpad/preload_no_ai_cred.rb
ENV["RAILS_ENV"] = "test"
require "/home/bot/calendario_livia/test/test_helper"
creds = Rails.application.credentials
creds.define_singleton_method(:dig) { |*a| a == [ :api, :ai_key ] ? nil : super(*a) }
```

3. Execução: `bundle exec ruby -Itest -r <preload> test/controllers/api/v1/ai/artes_controller_test.rb`. A primeira execução desta sessão imprimiu um stack trace de `maintain_test_schema!` e rodou 0 testes; a segunda rodou verde (comportamento de manutenção de schema no primeiro boot; reexecutar).
4. Alternativa sem preload: no próprio teste, `AI_API_KEY` poderia ler a credential, mas isso acopla o teste à credential; preferir o preload local e deixar o CI como autoridade (D-12).
5. Gate completo (CI): `bin/rubocop`, `bin/brakeman`, `bin/rails db:test:prepare test`. Rubocop 1.86.2 roda localmente [VERIFIED: `bundle exec rubocop --version`].

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| IA só com `external_url` (D-06 da fase 24) | IA envia o arquivo multipart | esta fase | arte divulgável sem passo humano de upload; só a aprovação do cliente continua humana |

**Deprecated/outdated:** a frase de `docs/api-ia.md` "arte da API não é divulgável" e a regra 400 de `media_file` (testes e doc) ficam obsoletas.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | O default de `client_max_body_size` do nginx-proxy-manager pode barrar 50 MB (não confirmado; busca web devolveu só o 1 MB do nginx puro) | Pitfall 5 | Upload real da IA recebe 413 em produção mesmo com tudo verde no CI; mitigado por checkpoint humano com arquivo real |
| A2 | `service_urls_expire_in` não definido, vale o default do Rails (5 min) | Pitfall 6 | `media_url` vive mais ou menos que o descrito; só afeta o texto da doc |
| A3 | `@arte.destroy` limpa linhas de blob/attachment (default `dependent: :purge_later` do `has_one_attached`) | Pattern 2 | Resíduo de blob órfão após falha de storage; baixo impacto |
| A4 | D-10 aceita texto puro com extensão `.jpg` (provado em teste); o humano deve saber que "verifica pelos bytes" só vale com assinatura reconhecível | Pitfall 3 | Usuário acredita em checagem mais forte do que existe; impacto baixo (WhatsApp/visualização falharia depois) |
| A5 | Em produção, falha de S3 no `after_commit` se comporta como no stub (exceção propaga, arte persiste) | Pitfall 2 | Não testado contra S3 real; comportamento do Rails confirmado no código-fonte e no stub |

## Open Questions

1. **Tratar falha de storage (Pitfall 2) nesta fase ou só documentar?**
   - What we know: a falha deixa arte `pending` sem arquivo e devolve 500; reproduzida com stub; o rescue do Pattern 2 resolve com 503 e limpeza.
   - What's unclear: se o usuário aceita um novo `code` (`storage_unavailable`) e linha na tabela de status da doc (hoje só há `503 enqueue_failed`).
   - Recommendation: implementar o rescue (é robustez do controller, não regra de negócio), com 503 `storage_unavailable` e linha na tabela da seção 3 da doc, mais um teste com `stub`. Se o planner preferir não adicionar código, registrar o risco na doc.

2. **Limite real do proxy em produção (Pitfall 5).**
   - What we know: nada no app barra 50 MB.
   - What's unclear: `client_max_body_size` efetivo do nginx-proxy-manager.
   - Recommendation: `checkpoint:human-verify` com POST de ~20 MB à URL pública após o deploy.

3. **Validação cruzada `media_type` x tipo do arquivo.**
   - What we know: provado que `media_type: "caption_only"` com arquivo anexado dá 201; `media_type: "image"` com vídeo também não é barrado.
   - What's unclear: se é desejável barrar.
   - Recommendation: fora de escopo ("sem mudar regra de negócio do model"); não alterar.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby / bundler | rodar testes | ✓ | ruby 3.3.3 | — |
| PostgreSQL (banco de teste pessoal, socket Unix) | testes locais | ✓ | `calendario_livia_test_bot` (dono `bot`, 26 tabelas) | CI como autoridade |
| `bin/rails test` padrão | testes locais | ✗ (permissão, memória `test_db_permission`) | — | receita "Verificação local" |
| libvips | análise de imagem em CI/Docker | ✓ no Dockerfile e no CI | — | AnalyzeJob não roda nos testes (só enfileira) |
| MinIO/S3 real | upload em produção | não sondado (credenciais em `.env`/Portainer; não lidos) | — | `Disk` no teste |

**Missing dependencies with no fallback:** nenhuma para o código; o limite do proxy exige checagem humana (Open Question 2).
**Missing dependencies with fallback:** `bin/rails test` padrão -> preload + `DATABASE_URL` por socket.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (inalterado) | `authenticate_ai_key!` com `secure_compare` já existente |
| V3 Session Management | no | API stateless por chave |
| V4 Access Control | yes | chave de agência única (já aceito); `client_id` explícito; sem leitura entre clientes |
| V5 Input Validation | yes | model validators (tipo, tamanho); guard de tipo do valor `media_file` (Pitfall 1) |
| V6 Cryptography | no | sem criptografia nova; signed blob id é rejeitado pelo guard |
| V12 File and Resources | yes | tipo por Marcel + `content_type`/`size` validators; arquivo servido por URL presigned de bucket privado |

### Known Threat Patterns for Rails + Active Storage multipart

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| String em `media_file` interpretada como signed blob id (acesso a blob alheio / 500) | Tampering / Info disclosure | Guard `UploadedFile` -> 400 (Pitfall 1) |
| Content-type spoofing (PDF com nome `.jpg`) | Spoofing | Marcel + validator `content_type` (provado: 422) |
| Exaustão de recurso por arquivo grande | Denial of Service | Validator 50 MB (corpo já foi recebido; teto de proxy `[ASSUMED]`); throttle 60/min inalterado (D-09) |
| Upload de HTML/SVG servido inline | XSS | Lista fechada de tipos (jpeg, png, gif, mp4, quicktime); sem SVG/HTML |
| Nome de arquivo malicioso | Tampering | Active Storage sanitiza o filename; blob key é aleatória |
| Falha de storage deixa registro inconsistente | Integrity | rescue + limpeza (Pattern 2) |
| Brakeman | — | rodar `bin/brakeman` no gate; não há `send_file`/`File.open` com input do usuário |

## Sources

### Primary (HIGH confidence)
- Código do repo lido nesta sessão: `app/controllers/api/v1/ai/artes_controller.rb`, `app/controllers/api/v1/ai/base_controller.rb`, `app/controllers/api/v1/base_controller.rb`, `app/controllers/api/v1/admin/artes_controller.rb`, `app/models/arte.rb`, `app/models/divulgacao.rb`, `app/serializers/api/v1/ai/arte_serializer.rb`, `config/initializers/rack_attack.rb`, `config/storage.yml`, `config/puma.rb`, `deploy/Caddyfile`, `docker-compose.yml`, `docs/api-ia.md`, os testes de IA e admin
- Código de gems instalados (`vendor/bundle`): activestorage-8.1.4.1 (`attached/model.rb`, `attached/changes/create_one.rb`), active_storage_validations-3.0.5 (`content_type_validator.rb`, `size_validator.rb`), rack-3.2.8 (`utils.rb`), puma-8.0.2 (`configuration.rb`, `dsl.rb`)
- Protótipos descartáveis rodados contra `calendario_livia_test_bot` (controller temporário e testes de rascunho em `/tmp/claude-1000/.../scratchpad/`; controller restaurado, `git status` limpo em `app/` e `test/`)
- `.planning/phases/32-divulga-es-na-api-de-ia/32-REVIEW.md` (CR-02, `assert_no_enqueued_jobs`)

### Secondary (MEDIUM confidence)
- Web search sobre `client_max_body_size` (default de 1 MB do nginx puro; nada específico do nginx-proxy-manager)

### Tertiary (LOW confidence)
- Default de `service_urls_expire_in` e `dependent` do `has_one_attached` por conhecimento prévio (A2, A3)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, sem dependência nova; versões lidas do lockfile
- Architecture: HIGH, caminho feliz, 400 do guard, 422 de tipo/tamanho/ambos e falha de storage provados em runtime
- Pitfalls: HIGH para 1-4; MEDIUM para 5-6 (proxy e expiração dependem de infra não observada)

**Research date:** 2026-11-08
**Valid until:** 2026-12-08 (stack estável; revalidar se o Rails/active_storage_validations subir de versão)
