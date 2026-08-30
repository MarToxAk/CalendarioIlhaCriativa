# Phase 26: Instância de WhatsApp por Cliente + Pareamento - Context

**Gathered:** 2026-08-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Cada cliente ganha sua própria instância Evolution, criada e pareada pelo painel admin.
Entrega: modelo `whatsapp_instance` (1:1 com `client`), fluxo de criação com QR Code rotativo
na tela, adoção de instância já existente no manager (403 "already in use" → adotar +
reapontar webhook), receiver de webhook autenticado, estado de conexão visível por cliente
com verificação manual, e os avisos de banimento / idade do número.

**Fora do escopo desta fase:** listar/selecionar grupos (fase 27), montar Divulgação (fase 28),
enviar mensagem de verdade (fase 29). O `Evolution::Client` (costura HTTP) já existe da fase 25 —
esta fase adiciona os métodos de instância (`create_instance`, `connect`/QR, `connection_state`
já existe, `set_webhook`) e o modelo/UI ao redor.

**Ordem obrigatória (do ROADMAP):** as chaves de `active_record_encryption`, o `encrypts` do
token e a correção do `filter_parameter_logging.rb` (`apikey`/`hash`) vêm ANTES do primeiro
token ser gravado.

</domain>

<decisions>
## Implementation Decisions

### Modelo de dados da instância

- Nova tabela `whatsapp_instances` — `Client has_one :whatsapp_instance`. Campos e lifecycle
  próprios: `client_id`, `instance_name`, `token` (encrypted), `connection_state`,
  `paired_at`, `last_checked_at`, timestamps. Não usar colunas em `clients` nem tabela polimórfica.
- Nome da instância no Evolution: determinístico e estável — `livia_client_<client.id>`.
  Namespaced porque o manager Evolution é compartilhado com outras apps da agência; `id`
  não rotaciona (ao contrário de `access_token`). A adoção de instância existente depende
  desse nome ser previsível.
- `connection_state` é enum Rails: `unpaired` / `awaiting_qr` / `connected` / `disconnected`
  (mapeando `close` / `connecting` / `open` do Evolution) + coluna `last_checked_at`.
- Segredo do webhook: derivado, não persistido. `HMAC-SHA256(instance_name, chave)` onde a
  chave global vive em `Rails.application.credentials.evolution.webhook_hmac_key` (dev/test:
  `.env`). O receiver recalcula o HMAC e faz `secure_compare` ANTES de qualquer consulta ao
  banco (PAIR-06 literal). Revogação individual = rotacionar a chave global (aceitável no
  perfil de 10-30 clientes) ou incluir um nonce por instância numa iteração futura.

### Fluxo de pareamento (QR) na UI

- Transporte do QR: Stimulus controller faz `fetch` a um endpoint `refresh_qr` do cliente a
  cada ~20s e para quando o estado vira `connected`. Não usar ActionCable aqui (existe no
  projeto para notificações, mas o QR é admin-only, efêmero e o polling é mais simples/robusto).
- Render do QR: `<img src="data:image/png;base64,…">` inline — o Evolution retorna o QR como
  base64. O base64 NUNCA é logado (INFRA-04).
- Timeout da tela: ~2 min de rotação automática (~6 QRs), depois um botão explícito
  "gerar novo QR". QR do WhatsApp expira rápido.
- Após "already in use" (adoção): buscar `connection_state` na hora. Se `open` → tela
  "conectada (adotada)". Se não → mostrar QR para reparear. Em ambos os casos o webhook é
  reapontado para este app no ato da adoção (decisão travada v1.7).

### Webhook receiver

- Rota: `POST /webhooks/evolution` top-level (fora do namespace admin), controller dedicado
  sem CSRF nem sessão — estilo `ActionController::API`, espelhando `Api::V1::BaseController`.
- Autenticação: header `X-Webhook-Secret` comparado por `secure_compare` contra o HMAC
  recalculado (ver acima) ANTES de tocar o banco. Sem o segredo correto → `401` imediato,
  sem query.
- Eventos tratados nesta fase: `connection.update` (atualiza `connection_state` +
  `last_checked_at`, grava `paired_at` no primeiro `open`) e `qrcode.updated`. `messages.*`
  fica para a fase 29.
- Segredo válido mas instância inexistente, ou evento não tratado: `204 No Content`
  silencioso, log em nível info SEM o segredo (não vazar existência de instância).

### Estado de conexão, verificação manual e avisos

- "Forçar verificação" (PAIR-05): chamada SÍNCRONA a `Evolution::Client.connection_state`
  dentro do request (leitura rápida — `READ_TIMEOUT_FAST=15s` já existe na 25), atualiza
  `connection_state` + `last_checked_at` e dá feedback imediato na tela. Não enfileirar job.
- Onde o estado aparece: seção dedicada na página do cliente
  (`admin/clients#show`) com o estado, `last_checked_at`, botão de verificação e ações de
  instância; mais um indicador compacto (bolinha colorida) na coluna do `admin/clients#index`.
- Aviso de banimento (PAIR-07): banner amber destacado ACIMA do QR, sempre visível, SEM
  checkbox obrigatório — decisão travada: "sem bloquear nada".
- Idade do número (PAIR-08): coluna `paired_at` local, gravada quando este app vê o primeiro
  `open`. UI mostra "pareado há X dias"; se `< 7 dias`, texto de cautela em amber. A UI
  deixa EXPLÍCITO que a contagem é desde o pareamento neste sistema, não a idade real do
  número no WhatsApp (o Evolution não expõe isso).

### Claude's Discretion

- Forma exata dos métodos novos em `Evolution::Client` (`create_instance`, `connect`,
  `set_webhook`) — espelhar o estilo de `fetch_instances` / `connection_state` já existentes.
- Nome/estrutura do Stimulus controller do QR e do endpoint `refresh_qr`.
- Se a lógica de instância vive num `WhatsappInstanceService` PORO ou em métodos gordos do
  model — seguir o precedente do projeto (services em `app/services/` para integração externa).
- Textos exatos dos avisos (pt-BR), cores Tailwind dos estados, layout da seção no show.
- Migração: uma migração para `whatsapp_instances` + config de `active_record_encryption`
  (chaves via credentials/`.env`, geradas com `bin/rails db:encryption:init`).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Evolution::Client` (app/services/evolution/client.rb, fase 25) — costura HTTP única com
  header `apikey`, timeouts (`READ_TIMEOUT_FAST=15s`), taxonomia `Evolution::Errors`
  (Transient/Permanent/Unknown/NotConnected). Já tem `fetch_instances` e `connection_state`.
- `config/initializers/evolution.rb` — base_url + apikey global (credentials || ENV).
- `config/initializers/filter_parameter_logging.rb` — PRECISA de fix para casar `apikey`/`hash`
  (defeito pré-existente que bloqueia a 1ª gravação de token — nota do ROADMAP).
- `Client` model — `has_secure_token :access_token`, `has_secure_password`, `has_many :artes`.
  Adicionar `has_one :whatsapp_instance`.
- `admin/clients_controller` + views (`index`, `show`, `new`, `edit`) — Tailwind v4 puro,
  já tem `rotate_token` como member POST (precedente de ação custom).
- ActionCable/solid_cable disponível (v1.5) — mas a decisão foi polling para o QR.
- `Api::V1::BaseController` — precedente de controller sem CSRF/sessão para o webhook.
- `.planning/notes/evolution-contract.md` — contrato empírico do host real (fase 25).
- `.planning/research/` (ARCHITECTURE/FEATURES/PITFALLS/STACK/SUMMARY) — pesquisa de 4
  agentes sobre Evolution API; consultar, não reconstruir.

### Established Patterns
- Services PORO em `app/services/` para integração externa (ex: `Evolution::Client`,
  `Api::JwtService`) com módulo de erros aninhado.
- Segredos: `credentials || ENV.fetch` (precedente `jwt_service.rb`); `.env*` já no gitignore,
  `dotenv-rails` só em dev/test.
- `secure_compare` em toda comparação de segredo (precedente v1.6 API auth).
- Stimulus + Turbo para interatividade; Tailwind v4 `@theme`; sem build JS além do importmap.
- Queries sempre escopadas por cliente (previne cross-client leak).
- Ações custom em resources admin via `member do post :x end` (ex: `rotate_token`).

### Integration Points
- `config/routes.rb` — `namespace :admin` para as telas de instância; rota top-level nova
  `post "/webhooks/evolution"`.
- `admin/clients#show` — nova seção "WhatsApp".
- `admin/clients#index` — nova coluna/indicador.
- Sidebar admin — sem item novo (estado vive na página do cliente).
- `config/initializers/` — `active_record_encryption` (chaves), fix do `filter_parameter_logging`.
- Docker/deploy (fase 25) — o webhook precisa do app alcançável em
  `ilhacriativa.autopyweb.com.br`; a URL do webhook registrada no Evolution aponta para lá.

</code_context>

<specifics>
## Specific Ideas

- O `instance_name` `livia_client_<id>` deve ser gerado por um único método (ex:
  `WhatsappInstance#evolution_name` ou no service) e reutilizado em todas as chamadas —
  criar, conectar, set_webhook, adotar.
- A adoção (PAIR-02) dispara quando `create_instance` retorna o erro de nome em uso
  (403/409 "already in use" conforme o contrato registrado em `evolution-contract.md` —
  o executor deve confirmar o status/shape exato lá antes de codar o `rescue`).
- Gravar `paired_at` uma única vez (primeiro `open`), nunca sobrescrever em reconexões.
- O endpoint `refresh_qr` retorna `{ state, qr_base64 | null }` e o Stimulus para o polling
  quando `state == "connected"`.

</specifics>

<deferred>
## Deferred Ideas

- Nonce/segredo por instância no webhook (em vez de só a chave global HMAC) — se a
  rotação individual virar necessidade real.
- Página "WhatsApp" dedicada no sidebar agregando todas as instâncias — só se a página do
  cliente ficar apertada.
- Tratar `messages.*` no webhook — fase 29 (Motor de Envio).
- Gate de warm-up que BLOQUEIA disparos em número novo (PROD-03) — no v1.7 é só aviso (PAIR-08).

</deferred>
