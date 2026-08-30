# Phase 26: Instância de WhatsApp por Cliente + Pareamento - Research

**Researched:** 2026-08-30
**Domain:** Rails 8.1.3 — provisionamento/adoção de instância Evolution API por cliente, pareamento por QR, webhook autenticado, criptografia de token em repouso
**Confidence:** HIGH (Rails-side + contratos Evolution lidos da fonte no tag exato do host `2.3.7`); MEDIUM nos itens que só fecham em UAT (casing real do webhook emitido pelo host, alcançabilidade inbound, `token` de instância adotada)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Modelo de dados da instância**
- Nova tabela `whatsapp_instances` — `Client has_one :whatsapp_instance`. Campos e lifecycle próprios: `client_id`, `instance_name`, `token` (encrypted), `connection_state`, `paired_at`, `last_checked_at`, timestamps. Não usar colunas em `clients` nem tabela polimórfica.
- Nome da instância no Evolution: determinístico e estável — `livia_client_<client.id>`. Namespaced porque o manager Evolution é compartilhado com outras apps da agência; `id` não rotaciona (ao contrário de `access_token`). A adoção de instância existente depende desse nome ser previsível.
- `connection_state` é enum Rails: `unpaired` / `awaiting_qr` / `connected` / `disconnected` (mapeando `close` / `connecting` / `open` do Evolution) + coluna `last_checked_at`.
- Segredo do webhook: derivado, não persistido. `HMAC-SHA256(instance_name, chave)` onde a chave global vive em `Rails.application.credentials.evolution.webhook_hmac_key` (dev/test: `.env`). O receiver recalcula o HMAC e faz `secure_compare` ANTES de qualquer consulta ao banco (PAIR-06 literal). Revogação individual = rotacionar a chave global (aceitável no perfil de 10-30 clientes) ou incluir um nonce por instância numa iteração futura.

**Fluxo de pareamento (QR) na UI**
- Transporte do QR: Stimulus controller faz `fetch` a um endpoint `refresh_qr` do cliente a cada ~20s e para quando o estado vira `connected`. Não usar ActionCable aqui (existe no projeto para notificações, mas o QR é admin-only, efêmero e o polling é mais simples/robusto).
- Render do QR: `<img src="data:image/png;base64,…">` inline — o Evolution retorna o QR como base64. O base64 NUNCA é logado (INFRA-04).
- Timeout da tela: ~2 min de rotação automática (~6 QRs), depois um botão explícito "gerar novo QR". QR do WhatsApp expira rápido.
- Após "already in use" (adoção): buscar `connection_state` na hora. Se `open` → tela "conectada (adotada)". Se não → mostrar QR para reparear. Em ambos os casos o webhook é reapontado para este app no ato da adoção (decisão travada v1.7).

**Webhook receiver**
- Rota: `POST /webhooks/evolution` top-level (fora do namespace admin), controller dedicado sem CSRF nem sessão — estilo `ActionController::API`, espelhando `Api::V1::BaseController`.
- Autenticação: header `X-Webhook-Secret` comparado por `secure_compare` contra o HMAC recalculado ANTES de tocar o banco. Sem o segredo correto → `401` imediato, sem query.
- Eventos tratados nesta fase: `connection.update` (atualiza `connection_state` + `last_checked_at`, grava `paired_at` no primeiro `open`) e `qrcode.updated`. `messages.*` fica para a fase 29.
- Segredo válido mas instância inexistente, ou evento não tratado: `204 No Content` silencioso, log em nível info SEM o segredo (não vazar existência de instância).

**Estado de conexão, verificação manual e avisos**
- "Forçar verificação" (PAIR-05): chamada SÍNCRONA a `Evolution::Client.connection_state` dentro do request (leitura rápida — `READ_TIMEOUT_FAST=15s` já existe na 25), atualiza `connection_state` + `last_checked_at` e dá feedback imediato na tela. Não enfileirar job.
- Onde o estado aparece: seção dedicada na página do cliente (`admin/clients#show`) com o estado, `last_checked_at`, botão de verificação e ações de instância; mais um indicador compacto (bolinha colorida) na coluna do `admin/clients#index`.
- Aviso de banimento (PAIR-07): banner amber destacado ACIMA do QR, sempre visível, SEM checkbox obrigatório — decisão travada: "sem bloquear nada".
- Idade do número (PAIR-08): coluna `paired_at` local, gravada quando este app vê o primeiro `open`. UI mostra "pareado há X dias"; se `< 7 dias`, texto de cautela em amber. A UI deixa EXPLÍCITO que a contagem é desde o pareamento neste sistema, não a idade real do número no WhatsApp (o Evolution não expõe isso).

**Ordem obrigatória (ROADMAP):** as chaves de `active_record_encryption`, o `encrypts` do token e a correção do `filter_parameter_logging.rb` (`apikey`/`hash`) vêm ANTES do primeiro token ser gravado.

### Claude's Discretion

- Forma exata dos métodos novos em `Evolution::Client` (`create_instance`, `connect`, `set_webhook`) — espelhar o estilo de `fetch_instances` / `connection_state` já existentes.
- Nome/estrutura do Stimulus controller do QR e do endpoint `refresh_qr`.
- Se a lógica de instância vive num `WhatsappInstanceService` PORO ou em métodos gordos do model — seguir o precedente do projeto (services em `app/services/` para integração externa).
- Textos exatos dos avisos (pt-BR), cores Tailwind dos estados, layout da seção no show.
- Migração: uma migração para `whatsapp_instances` + config de `active_record_encryption` (chaves via credentials/`.env`, geradas com `bin/rails db:encryption:init`).

### Deferred Ideas (OUT OF SCOPE)

- Nonce/segredo por instância no webhook (em vez de só a chave global HMAC) — se a rotação individual virar necessidade real.
- Página "WhatsApp" dedicada no sidebar agregando todas as instâncias — só se a página do cliente ficar apertada.
- Tratar `messages.*` no webhook — fase 29 (Motor de Envio).
- Gate de warm-up que BLOQUEIA disparos em número novo (PROD-03) — no v1.7 é só aviso (PAIR-08).
- Listar/selecionar grupos (fase 27), montar Divulgação (fase 28), enviar mensagem de verdade (fase 29).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EVO-04 | O token de cada instância é persistido criptografado no banco (`encrypts`), com as chaves de `active_record_encryption` configuradas antes da primeira gravação | §"Rails 8.1 Active Record Encryption" — `bin/rails db:encryption:init`, 3 chaves em credentials + `.env`, `encrypts :token` não-determinístico (token nunca é consultado por valor). Ordem: chaves → `filter_parameters` → migração+`encrypts` → 1ª gravação. |
| INFRA-04 | Segredos do Evolution (`apikey`, `hash`, `token`, QR) nunca aparecem em log — `filter_parameters` corrigido, e nenhum segredo trafega como argumento de job | §"filter_parameter_logging — fechar INFRA-04"; §"Pitfall 7/8" (body do webhook carrega `apikey` + base64; job leva `whatsapp_instance_id`, nunca o token). `Evolution::Client` já loga só `método path status ms`. |
| PAIR-01 | Admin cria uma instância de WhatsApp para um cliente que ainda não tem uma | §"POST /instance/create" (contrato de request/response verificado no tag 2.3.7); `Evolution::Client.create_instance`; `Evolution::InstanceProvisioner` (modo create). |
| PAIR-02 | Admin registra uma instância que já existe no Evolution, em vez de falhar quando o nome está em uso | §"Fluxo de adoção (PAIR-02)" — 403 `This name "<x>" is already in use.` → `Evolution::Errors::Permanent` → `rescue` casando `/already in use/i` → `fetch_instances` + `set_webhook` (sempre) + `connection_state` → branch. |
| PAIR-03 | Admin vê o QR Code na tela do app e o código se mantém escaneável enquanto ele rotaciona (~25s) | §"Stimulus polling + `refresh_qr`" — `{ state, qr_base64 | null }`; base64 já é data-URI completo; webhook `qrcode.updated` popula `last_qr_base64`. |
| PAIR-04 | Admin vê o estado de conexão da instância de cada cliente (conectada / desconectada / aguardando pareamento) | §"Modelo `whatsapp_instances`" + tabela de mapeamento `open/connecting/close/refused` → enum; badge no show + bolinha no index (contrato em 26-UI-SPEC). |
| PAIR-05 | Admin consegue verificar a conexão manualmente, sem depender do webhook | §"`verify` action" — chamada síncrona a `Evolution::Client.connection_state` (já existe, `READ_TIMEOUT_FAST=15s`), atualiza `connection_state` + `last_checked_at`. |
| PAIR-06 | O app recebe eventos do Evolution por webhook autenticado, com o segredo comparado por `secure_compare` antes de qualquer consulta ao banco | §"Webhook receiver" — `Webhooks::EvolutionController < ActionController::API`; HMAC-SHA256(instance_name, key) recalculado, `secure_compare` (com guard de comprimento) ANTES do `find_by`; 401 sem query. |
| PAIR-07 | A tela de pareamento avisa, no momento de escanear o QR, que o número está sujeito a banimento pelo WhatsApp | Banner amber acima do QR, sempre visível, sem checkbox (26-UI-SPEC "Ban-risk banner"); nada é bloqueado. |
| PAIR-08 | A UI informa há quanto tempo o número foi pareado e recomenda cautela em números recentes — sem bloquear o envio | Coluna `paired_at` gravada UMA vez no primeiro `open` (webhook `connection.update` state=open); UI "pareado há N dias neste sistema", cautela amber se `< 7 dias` (26-UI-SPEC). |
</phase_requirements>

## Summary

Esta fase acopla a `whatsapp_instances` (1:1 com `Client`) ao redor do `Evolution::Client` já entregue na fase 25. O trabalho técnico se divide em quatro blocos com uma ordem obrigatória: (1) infra de segredo — chaves de `active_record_encryption` em credentials/`.env`, correção final do `filter_parameter_logging.rb`, ambos ANTES do primeiro `encrypts :token` subir; (2) três métodos novos no `Evolution::Client` (`create_instance`, `connect`, `set_webhook`) espelhando o estilo class-method já existente; (3) um serviço PORO de provisão (create-ou-adota, sempre reaponta o webhook, persiste a linha); (4) a superfície web — receiver de webhook autenticado por HMAC, endpoint `refresh_qr` para o polling Stimulus, ação síncrona "Forçar verificação", e a seção "WhatsApp" no `admin/clients#show` + bolinha no `#index` (contrato visual já fechado em 26-UI-SPEC).

Os contratos do Evolution foram lidos diretamente do código-fonte no commit `cd800f29` (tag `2.3.7` — exatamente a versão que o host da agência roda, confirmado em `evolution-contract.md`). Os shapes de `/instance/create`, `/instance/connect`, `/webhook/set` e dos eventos `connection.update` / `qrcode.updated` estão abaixo verbatim da fonte. O erro de nome-em-uso é `ForbiddenException` → **HTTP 403** com mensagem `This name "<instanceName>" is already in use.` — que o `raise_for_status!` atual já mapeia para `Evolution::Errors::Permanent`, então a adoção é um `rescue` casando `/already in use/i`.

**Primary recommendation:** Migração + chaves de encryption + fix do filter primeiro (um plano). Depois `Evolution::Client` (+3 métodos) e `Evolution::InstanceProvisioner`. Depois controllers/rotas/webhook/UI. O webhook do Evolution emite `event` em **dotcase** (`connection.update`), não `UPPER_SNAKE` — o receiver normaliza com `event.to_s.tr(".-","__").upcase` e aceita as duas grafias (item PENDENTE em `evolution-contract.md`).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Criar / adotar instância, setar webhook | API / Backend (`Evolution::Client` + `Evolution::InstanceProvisioner`) | Serviço externo (host Evolution) | Toda HTTP + persistência de segredo é server-side; controller nunca fala HTTP |
| Token da instância em repouso | Database / Storage (Active Record Encryption) | Backend | Chaves só no servidor; coluna fora de qualquer serializer; nunca no browser |
| QR na tela + rotação | Browser (Stimulus `fetch` polling) lê o `refresh_qr` do Backend | Backend serve o QR já em cache (`last_qr_base64` do DB, populado pelo webhook) | QR é admin-only, efêmero; polling é mais simples/robusto que ActionCable (decisão travada) |
| Fonte de verdade do estado de conexão | Database (`whatsapp_instances.connection_state`) | Backend: receiver de webhook + `verify` síncrono | Webhook é um *hint*; "Forçar verificação" reconcilia sob demanda (PAIR-05) |
| Autenticação do webhook | Backend (`Webhooks::EvolutionController`) | — | HMAC recalculado + `secure_compare` antes de qualquer query (PAIR-06) |
| Avisos de ban / recência | Browser (ERB server-rendered) | Backend (`paired_at`) | Puramente informativo — nada é bloqueado (PAIR-07 / PAIR-08) |

## Standard Stack

### Core (tudo já no bundle — esta fase NÃO adiciona gem)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `faraday` | 2.14.3 (`~> 2.14`) | HTTP do `Evolution::Client` | Já instalado e em uso (fase 25) `[VERIFIED: Gemfile:38]` |
| Active Record Encryption | built-in Rails 8.1.3 | `encrypts :token` na `whatsapp_instances` (EVO-04) | Nativo desde Rails 7; substitui `attr_encrypted`/`lockbox`. Zero gem `[CITED: guides.rubyonrails.org/active_record_encryption.html]` |
| `OpenSSL::HMAC` / `Digest::SHA256` | stdlib Ruby 3.3.3 | segredo do webhook = `HMAC-SHA256(instance_name, key)` | stdlib; nada a instalar |
| `ActiveSupport::SecurityUtils` | built-in | `secure_compare` / `fixed_length_secure_compare` do segredo (PAIR-06) | Precedente do projeto: "`secure_compare` em toda comparação de segredo (v1.6)" `[VERIFIED: CONTEXT.md code_context]` |
| Stimulus + importmap | já configurado | `qr_pairing_controller.js` (polling) | "Stimulus + Turbo; sem build JS além do importmap" `[VERIFIED: CONTEXT.md]` |
| Tailwind v4 (`tailwindcss-rails`) | já configurado | seção WhatsApp / badge / banner | contrato visual fechado em 26-UI-SPEC |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `Evolution::Client` (fase 25) | única costura HTTP; header `apikey`, timeouts, taxonomia `Evolution::Errors` | Todos os 3 métodos novos entram aqui como class methods `[VERIFIED: app/services/evolution/client.rb:20-67]` |
| `Evolution::Errors::{Transient,Permanent,Unknown,NotConnected,ConfigurationError}` | classificação de erro | 403 já vira `Permanent`; adoção casa `/already in use/i` `[VERIFIED: app/services/evolution/client.rb:111-118]` |
| `Evolution.base_url` / `Evolution.global_api_key` | resolvem ENV-first, fallback credentials | reusados sem mudança `[VERIFIED: app/services/evolution.rb:16-33]` |
| `Api::V1::BaseController` | precedente de `< ActionController::API` sem CSRF/sessão | modelo para `Webhooks::EvolutionController` `[VERIFIED: app/controllers/api/v1/base_controller.rb:3]` |
| `Admin::BaseController` | `layout 'admin'` + `before_action :require_authentication` | pai de `Admin::WhatsappInstancesController` `[VERIFIED: app/controllers/admin/base_controller.rb:1-5]` |
| `admin/clients/_confirm_modal.html.erb` + `modal_controller.js` | modal de confirmação (`confirm_variant: "warning"`) | "Parear novamente" `[VERIFIED: app/views/admin/clients/_confirm_modal.html.erb:2]` |
| `admin/clients/_status_badge.html.erb` | shape do pill (`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium border` + `●`) | base do `_connection_badge` `[VERIFIED: app/views/admin/clients/_status_badge.html.erb:2]` |
| `toast_controller.js` + `#admin-toast-region` | feedback efêmero | ver "Toast sem ActionCable" abaixo `[VERIFIED: app/javascript/controllers/toast_controller.js:3-4]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Stimulus polling do QR | Webhook `qrcode.updated` → ActionCable (recomendação da ARCHITECTURE.md) | **Rejeitado por decisão travada.** Polling é admin-only, efêmero, imune ao webhook não alcançar o app em dev. Mantido: webhook popula `last_qr_base64`; o poll só lê o DB. |
| `encrypts :token` não-determinístico | `encrypts :token, deterministic: true` | Determinístico permitiria `find_by(token:)` mas o token nunca é consultado por valor (busca via `client.whatsapp_instance.token`). Não-determinístico (default) é mais seguro e suficiente. `[CITED: guides.rubyonrails.org/active_record_encryption.html]` |
| `instance_name` = `livia_client_<id>` (determinístico) | `cli-<id>-<SecureRandom.hex(6)>` (ARCHITECTURE.md Pitfall 10) | **Rejeitado por decisão travada.** A adoção (PAIR-02) exige nome previsível. O prefixo `livia_` namespaceia no manager compartilhado. |
| `whatsapp_instances` tabela separada | colunas em `clients` | **Rejeitado por decisão travada** (e ARCHITECTURE.md §1.1): `clients` está no caminho quente de auth/ActionCable; o QR é blob multi-KB que rotaciona. |

**Installation:** nenhuma. `bin/bundle` inalterado. A única "instalação" é `bin/rails db:encryption:init` (gera chaves, não instala nada).

## Package Legitimacy Audit

> Esta fase **não instala nenhum pacote externo**. `faraday` e `aws-sdk-s3` foram adicionados na fase 25; Active Record Encryption, `OpenSSL`, `Digest` e `ActiveSupport::SecurityUtils` são built-in.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| — | — | — | N/A — zero novos pacotes |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌───────────────────────── ADMIN BROWSER (Turbo + Stimulus) ─────────────────────────┐
│  admin/clients#show  ──[GET refresh_qr a cada ~20s]──▶  {state, qr_base64|null}     │
│  qr_pairing_controller.js: setInterval(fetch) → troca <img> → para em "connected"  │
│  ou após ~6 ciclos → revela "Gerar novo QR"                                        │
│  botões: Criar instância | Forçar verificação | Adotar existente | Parear novamente│
└───────┬───────────────────────────────────────────────────────┬────────────────────┘
        │ POST create / verify / adopt / reconnect              │ GET refresh_qr
        ▼                                                       ▼
┌──────────────────────────── RAILS 8.1.3 (este app) ───────────────────────────────┐
│  Admin::WhatsappInstancesController  (< Admin::BaseController, require_auth)       │
│     └─▶ Evolution::InstanceProvisioner.new(client, mode:).call   (PORO)           │
│              ├─▶ Evolution::Client.create_instance / connect / set_webhook        │
│              │        (única costura HTTP — header apikey, timeouts, Errors::*)   │
│              └─▶ WhatsappInstance.create!/update!  (encrypts :token)              │
│                                                                                  │
│  Webhooks::EvolutionController  (< ActionController::API, sem CSRF/sessão)        │
│     1. header X-Webhook-Secret  vs  HMAC-SHA256(params[:instance], key)          │
│        secure_compare  ── ANTES de qualquer query ──▶  mismatch → head :401      │
│     2. WhatsappInstance.find_by(instance_name: params[:instance])               │
│        nil → head :204 (não vaza existência)                                     │
│     3. normaliza params[:event] → CONNECTION_UPDATE | QRCODE_UPDATED             │
│           connection.update → connection_state + last_checked_at;               │
│                               paired_at ⇐ Time.current no 1º "open" (nunca 2x)  │
│           qrcode.updated    → last_qr_base64 = data.dig("qrcode","base64")      │
│     4. head :ok / :204  (rápido — Evolution re-tenta em não-2xx)               │
│                                                                                  │
│  MODELS:  Client ─has_one─▶ WhatsappInstance (client_id unique)                  │
└───────┬──────────────────────────────────────────────────────────────────────────┘
        │ HTTPS + header apikey (global)                    ▲ POST /webhooks/evolution
        ▼                                                   │ (QRCODE_UPDATED, CONNECTION_UPDATE)
┌────────────────────────────────────────────────┐         │
│  EVOLUTION API HOST  (whatsapp.bomcustoilha…)  │─────────┘
│  v2.3.7 atrás de Cloudflare · manager comum    │
│  instância: livia_client_<client.id>           │
└────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
app/services/evolution/
├── client.rb                 # + create_instance, connect, set_webhook  (MODIFICAR)
├── errors.rb                 # inalterado
└── instance_provisioner.rb   # NOVO — create-ou-adota, reaponta webhook, persiste
app/services/evolution/webhook_processor.rb   # NOVO — corpo não-confiável → update de estado (opcional; pode ficar no controller p/ 2 eventos)

app/models/whatsapp_instance.rb               # NOVO
app/controllers/admin/whatsapp_instances_controller.rb   # NOVO
app/controllers/webhooks/evolution_controller.rb          # NOVO

app/views/admin/whatsapp_instances/_panel.html.erb            # NOVO (seção no show)
app/views/admin/whatsapp_instances/_qr.html.erb               # NOVO
app/views/admin/whatsapp_instances/_connection_badge.html.erb # NOVO
app/javascript/controllers/qr_pairing_controller.js           # NOVO (+ registrar em index.js)

db/migrate/XXXX_create_whatsapp_instances.rb   # NOVO

MODIFICAR:
config/routes.rb                              # nested whatsapp_instance + POST /webhooks/evolution
config/initializers/filter_parameter_logging.rb   # + :api_key, :instance_token, :qrcode, :base64, :pairing_code, :pairingCode
config/initializers/rack_attack.rb            # throttle p/ /webhooks/evolution
config/credentials.yml.enc                    # active_record_encryption: {...} + evolution.webhook_hmac_key
.env / .env.example                           # ACTIVE_RECORD_ENCRYPTION_* + EVOLUTION_WEBHOOK_HMAC_KEY + EVOLUTION_WEBHOOK_BASE_URL
app/models/client.rb                          # has_one :whatsapp_instance, dependent: :destroy
app/views/admin/clients/show.html.erb         # render "admin/whatsapp_instances/panel", instance: ...
app/views/admin/clients/_client_row.html.erb  # coluna "Conexão" (bolinha)
app/controllers/admin/clients_controller.rb   # #show carrega @whatsapp_instance; #index inclui :whatsapp_instance
config/environments/production.rb             # host público em config.hosts (webhook inbound)
```

### Pattern 1: Métodos novos no `Evolution::Client` (espelhar o estilo existente)

**What:** três class methods, mesmo shape de `fetch_instances` / `connection_state` — `request(...)` privado, kwarg `api_key:`, `read_timeout:` opcional, nada de `Faraday::Error` cru escapando.
**When to use:** toda chamada de ciclo de vida de instância nesta fase.

```ruby
# app/services/evolution/client.rb  (dentro de class << self)

# POST /instance/create — instanceName vai no CORPO, sem path param (única exceção de rota).
# Retorna o Hash do corpo. 403 "already in use" sobe como Evolution::Errors::Permanent
# (raise_for_status! já mapeia 403 → Permanent) — o chamador rescue + casa /already in use/i.
def create_instance(instance_name:, webhook_url:, webhook_headers:, events: %w[QRCODE_UPDATED CONNECTION_UPDATE], number: nil, api_key: Evolution.global_api_key)
  body = {
    instanceName: instance_name,
    integration:  "WHATSAPP-BAILEYS",
    qrcode:       true,
    webhook: {
      enabled: true,
      url:     webhook_url,
      byEvents: false,
      base64:   true,
      events:   events,
      headers:  webhook_headers            # { "X-Webhook-Secret" => hmac, "Content-Type" => "application/json" }
    }
  }
  body[:number] = number if number.present?
  resp = request(:post, "/instance/create", api_key: api_key, body: body)
  raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless resp.body.is_a?(Hash)
  resp.body
end

# GET /instance/connect/{name} — devolve o QR corrente. ATENÇÃO: em alguns builds
# devolve HTTP 200 com { "error": true, "message": "..." } OU { "count": 0 } sem base64.
def connect(instance_name, api_key: Evolution.global_api_key)
  resp = request(:get, "/instance/connect/#{instance_name}",
                 api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST)
  body = resp.body
  raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Hash)
  raise Evolution::Errors::Transient, "connect retornou error=true" if body["error"]
  # normaliza: o base64 já vem como data-URI PNG completo quando presente
  { base64: body["base64"] || body.dig("qrcode", "base64"),
    code:   body["code"]   || body.dig("qrcode", "code"),
    pairing_code: body["pairingCode"] || body.dig("qrcode", "pairingCode"),
    count:  body["count"]  || body.dig("qrcode", "count") }
end

# POST /webhook/set/{name} — reaponta o webhook (usado na adoção; SEMPRE). Retorna 201.
def set_webhook(instance_name, url:, headers:, events: %w[QRCODE_UPDATED CONNECTION_UPDATE], api_key: Evolution.global_api_key)
  body = { webhook: { enabled: true, url: url, byEvents: false, base64: true, events: events, headers: headers } }
  request(:post, "/webhook/set/#{instance_name}", api_key: api_key, body: body).body
end
```

> `request` privado já aceita `body:` e faz `req.body = body` `[VERIFIED: app/services/evolution/client.rb:70-80]`. `raise_for_status!` já trata 400/401/403/404/422 → `Permanent`; 408/429/5xx → `Transient` `[VERIFIED: app/services/evolution/client.rb:111-118]`.

### Pattern 2: `Evolution::InstanceProvisioner` — create-ou-adota

**What:** PORO em `app/services/evolution/` (mesma pasta do `Client`, precedente da fase 25). Orquestra a chamada, decide create vs adopt, SEMPRE reaponta o webhook, persiste a linha.
**When to use:** `Admin::WhatsappInstancesController#create` e `#adopt`.

```ruby
# app/services/evolution/instance_provisioner.rb
module Evolution
  class InstanceProvisioner
    Result = Struct.new(:instance, :adopted, :qr_base64, keyword_init: true)

    def initialize(client, client_api: Evolution::Client)
      @client, @api = client, client_api
    end

    def call
      name    = WhatsappInstance.evolution_name_for(@client)   # "livia_client_#{@client.id}"
      headers = { "X-Webhook-Secret" => WhatsappInstance.webhook_secret_for(name),
                  "Content-Type" => "application/json" }
      resp = @api.create_instance(instance_name: name, webhook_url: webhook_url, webhook_headers: headers)
      persist_new(name, resp)
    rescue Evolution::Errors::Permanent => e
      raise unless e.message =~ /already in use/i
      adopt(name, headers)
    end

    private

    def adopt(name, headers)
      existing = @api.fetch_instances.find { |i| (i["name"] || i["instanceName"]) == name }
      raise Evolution::Errors::Permanent, "instância #{name} não encontrada no manager para adoção" unless existing
      @api.set_webhook(name, url: webhook_url, headers: headers)   # SEMPRE reaponta
      state = @api.connection_state(name)                          # "open" | "connecting" | "close"
      row = WhatsappInstance.find_or_initialize_by(client: @client)
      row.assign_attributes(
        instance_name: name,
        token: existing["token"] || existing["hash"] || existing.dig("Auth", "token"),  # ver A1
        remote_instance_id: existing["id"] || existing["instanceId"],
        origin: :adopted_existing,
        connection_state: map_state(state),
        last_checked_at: Time.current
      )
      row.paired_at ||= Time.current if state == "open"
      row.save!
      Result.new(instance: row, adopted: true,
                 qr_base64: state == "open" ? nil : @api.connect(name)[:base64])
    end

    def persist_new(name, resp)
      row = WhatsappInstance.create!(
        client: @client, instance_name: name,
        token: resp["hash"].is_a?(Hash) ? resp.dig("hash", "apikey") : resp["hash"],  # ver A5
        remote_instance_id: resp.dig("instance", "instanceId"),
        origin: :created_by_app,
        connection_state: :awaiting_qr,
        last_checked_at: Time.current
      )
      Result.new(instance: row, adopted: false, qr_base64: resp.dig("qrcode", "base64"))
    end

    def map_state(s) = { "open" => :connected, "connecting" => :awaiting_qr, "close" => :disconnected, "refused" => :disconnected }.fetch(s, :awaiting_qr)
    def webhook_url = File.join(ENV.fetch("EVOLUTION_WEBHOOK_BASE_URL") { Rails.application.credentials.dig(:evolution, :webhook_base_url) }, "webhooks/evolution")
  end
end
```

### Pattern 3: Webhook receiver — segredo antes do banco (PAIR-06 literal)

```ruby
# app/controllers/webhooks/evolution_controller.rb
class Webhooks::EvolutionController < ActionController::API
  def create
    return head(:unauthorized) unless valid_signature?          # 1. ANTES de qualquer query
    instance = WhatsappInstance.find_by(instance_name: params[:instance].to_s)   # 2.
    return head(:no_content) if instance.nil?                    # não vaza existência
    apply_event(instance)                                        # 3.
    head :ok                                                     # 4. rápido
  end

  private

  # HMAC-SHA256(instance_name, key). O instance_name vem do CORPO (params[:instance]);
  # ele é só entrada do HMAC — se for forjado, o digest não bate sem a chave.
  def valid_signature?
    presented = request.headers["X-Webhook-Secret"].to_s
    return false if presented.blank?
    key = Rails.application.credentials.dig(:evolution, :webhook_hmac_key) || ENV.fetch("EVOLUTION_WEBHOOK_HMAC_KEY")
    expected = OpenSSL::HMAC.hexdigest("SHA256", key, params[:instance].to_s)
    # secure_compare levanta se os comprimentos diferem → hash os dois lados
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(presented), Digest::SHA256.hexdigest(expected)
    )
  end

  def apply_event(instance)
    case params[:event].to_s.tr(".-", "__").upcase       # "connection.update" → "CONNECTION_UPDATE"
    when "CONNECTION_UPDATE"
      state = params.dig(:data, :state)                  # open | close | connecting | refused
      mapped = { "open" => :connected, "connecting" => :awaiting_qr,
                 "close" => :disconnected, "refused" => :disconnected }[state]
      return unless mapped
      instance.connection_state = mapped
      instance.last_checked_at  = Time.current
      instance.paired_at      ||= Time.current if state == "open"
      instance.last_qr_base64   = nil          if state == "open"
      instance.save!
    when "QRCODE_UPDATED"
      b64 = params.dig(:data, :qrcode, :base64)          # pode faltar (limite de QR atingido)
      return if b64.blank?
      instance.update!(last_qr_base64: b64, connection_state: :awaiting_qr)
    end
    # qualquer outro evento: no-op → head :ok (Evolution não re-tenta)
  end
end
```

> **Nunca** `Rails.logger.info(request.raw_post)` nem `params.inspect` aqui: o corpo carrega `apikey` (o token da instância) e, no `qrcode.updated`, um PNG base64 inteiro. Logar só `params[:event]` + `params[:instance]` + resultado. `config.filter_parameters` cobre o log automático de params, **não** um `logger.info` manual.

### Pattern 4: Stimulus polling do QR

```javascript
// app/javascript/controllers/qr_pairing_controller.js
import { Controller } from "@hotwired/stimulus"
const INTERVAL_MS = 20000, MAX_CYCLES = 6   // ~2 min

export default class extends Controller {
  static targets = ["image", "regenerate"]
  static values  = { url: String }

  connect() { this.cycles = 0; this.poll(); this.timer = setInterval(() => this.poll(), INTERVAL_MS) }
  disconnect() { clearInterval(this.timer) }          // teardown obrigatório (Turbo nav)

  async poll() {
    this.cycles++
    try {
      const res  = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      const data = await res.json()                   // { state, qr_base64 }
      if (data.state === "connected") { clearInterval(this.timer); Turbo.visit(window.location.href, { action: "replace" }); return }
      if (data.qr_base64) this.imageTarget.src = data.qr_base64   // já é data:image/png;base64,...
    } catch (_) { /* inline error state; não loga o payload */ }
    if (this.cycles >= MAX_CYCLES) { clearInterval(this.timer); this.regenerateTarget.hidden = false }
  }
}
```

`refresh_qr` (member GET, JSON):

```ruby
def refresh_qr
  inst = @client.whatsapp_instance
  render json: { state: inst&.connection_state || "unpaired",
                 qr_base64: inst&.awaiting_qr? ? inst.last_qr_base64 : nil }
end
```

> O `refresh_qr` lê `last_qr_base64` do DB (populado pelo webhook `qrcode.updated`). **Fallback dev** (webhook não alcança o LAN): se `last_qr_base64` estiver velho/nulo e o estado for `awaiting_qr`, chamar `Evolution::Client.connect(name)` de forma throttled (ex.: no máx. 1×/15s) para puxar um QR fresco. Custa 1 request Evolution por poll por aba aberta — aceitável no perfil admin-only/efêmero.

### Anti-Patterns to Avoid

- **Adotar sem reapontar o webhook.** Instância criada noutro app tem outro webhook (ou nenhum). Sem `set_webhook` no ato da adoção, `connection.update`/`qrcode.updated` nunca chegam e o painel trava eternamente em "aguardando pareamento". `InstanceProvisioner#adopt` chama `set_webhook` **sempre**.
- **`encrypts :token` antes das chaves existirem.** Carregar o model sem `active_record_encryption.*` configurado → `ActiveRecord::Encryption::Errors::Configuration` na primeira gravação. Ordem: chaves → filter → migração+model → 1ª provisão.
- **Passar o token como argumento de job.** `SyncGroupsJob` (fase 27) será enfileirado no `open`; ele recebe `whatsapp_instance_id` e lê `instance.token` dentro do `perform`. solid_queue grava argumentos em JSON texto claro.
- **`WhatsappInstance.find(params[:id])` no controller.** Sempre `@client.whatsapp_instance` (escopo por cliente). O `instance_name` deriva de `client.id`, nunca de `params`.
- **Prefixar `data:image/png;base64,` no `<img>`.** O `qrcode.base64` do Evolution **já é** o data-URI completo. Interpolar de novo quebra a imagem.
- **`secure_compare` direto com o header cru.** Levanta `ArgumentError` se o comprimento diferir e vaza o tamanho do segredo. Hash os dois lados (`Digest::SHA256.hexdigest`) ou use `fixed_length_secure_compare`.
- **Tratar `state: "refused"` como um estado desconhecido.** É `close` disfarçado (limite de QR atingido) — mapear para `disconnected` e mostrar "gerar novo QR".
- **`connect` sem checar `{ error: true }`.** Esse build devolve erro com HTTP **200**; sem o check o app acha que tem QR.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Criptografia do token em repouso | AES manual / gem `attr_encrypted` | `encrypts :token` (Active Record Encryption) | Nativo Rails 8; envelope AES-GCM, IV aleatório, rotação de chave suportada `[CITED: guides.rubyonrails.org/active_record_encryption.html]` |
| Comparação do segredo do webhook | `presented == expected` | `ActiveSupport::SecurityUtils.secure_compare` sobre digests SHA256 | Timing-safe; precedente do projeto (v1.6) |
| HMAC do webhook | concat + `Digest` caseiro | `OpenSSL::HMAC.hexdigest("SHA256", key, instance_name)` | stdlib, correto por construção |
| Geração/rotação do QR | `rqrcode` / desenhar QR | o `base64` que o próprio Evolution devolve (data-URI PNG) | O Evolution já rotaciona e entrega pronto `[VERIFIED: baileys.service.ts:388-393]` |
| Transporte HTTP ao Evolution | `Net::HTTP` novo / `HTTParty` | `Evolution::Client` (fase 25) — 1 costura, timeouts, `Errors::*` | EVO-02; toda a taxonomia de retry depende dela |
| Filtro de segredo no log | regex custom no logger | lista de símbolos em `config.filter_parameters` (match por substring) | Já é o estilo do arquivo; regex convida a buraco `[VERIFIED: config/initializers/filter_parameter_logging.rb:13-16]` |
| "Instância pareada = canal permanente" | assumir e seguir | consultar `connection_state` sob demanda (PAIR-05) + webhook como hint | 401/403/402/406 não auto-reconectam `[VERIFIED: baileys.service.ts:424]` |

**Key insight:** o Evolution já faz o trabalho difícil (gera QR, rotaciona, emite webhook com o base64 pronto). O app só precisa: guardar o token cifrado, autenticar o webhook, e refletir o estado. Tudo que parece "precisar construir" (cripto, QR, HMAC) tem primitiva pronta.

## Runtime State Inventory

> Não é fase de rename/refactor, mas introduz **segredos persistidos** e **estado externo registrado no host Evolution** — inventário curto abaixo.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Nova tabela `whatsapp_instances`; coluna `token` cifrada em repouso (Active Record Encryption). `last_qr_base64` é volátil (nulo no `open`). | Migração + `encrypts :token`. Toda env que lê a linha precisa das 3 chaves `active_record_encryption.*`. |
| Live service config | O host Evolution guarda, POR INSTÂNCIA, a config de webhook: `url` + `headers["X-Webhook-Secret"]` + `events`. Vive na API/DB do Evolution, **não no git**. Setada via `/instance/create` (inline) e `/webhook/set` (adoção). | Se o hostname público do app mudar, rodar `set_webhook` de novo em TODAS as instâncias. Documentar como passo de operador. O manager Evolution é **compartilhado** com outras apps da agência — pode existir um webhook GLOBAL que também entrega eventos de outras instâncias a este app (receiver responde 204 para `instance` desconhecida). |
| OS-registered state | Nenhum — verificado (sem cron, sem task scheduler, sem pm2 nesta fase). |
| Secrets/env vars | **Novos:** `active_record_encryption.primary_key` / `deterministic_key` / `key_derivation_salt` (credentials + `.env` via `ACTIVE_RECORD_ENCRYPTION_*`); `evolution.webhook_hmac_key` (credentials + `.env` `EVOLUTION_WEBHOOK_HMAC_KEY`); `evolution.webhook_base_url` / `EVOLUTION_WEBHOOK_BASE_URL` (hostname público do app). `EVOLUTION_BASE_URL` / `EVOLUTION_GLOBAL_API_KEY` já existem (fase 25). | `bin/rails db:encryption:init` → colar em `credentials:edit`; espelhar as 3 chaves + a hmac key no `.env`/`.env.example`. |
| Build artifacts | Nenhum. |

**Canonical question — "depois de tudo no repo mudar, que estado runtime ainda tem o valor antigo?"** Resposta aqui: o **host Evolution** guarda o webhook por instância. Uma mudança de hostname do app exige re-`set_webhook`. Nada mais.

## Common Pitfalls

### Pitfall 1: Chaves de encryption ausentes na 1ª gravação (ordem obrigatória do ROADMAP)
**What goes wrong:** `encrypts :token` sobe, alguém roda `InstanceProvisioner`, `ActiveRecord::Encryption::Errors::Configuration` no `create!`.
**Why:** as 3 chaves não estão em credentials/ENV.
**How to avoid:** plano 1 = SÓ infra: `bin/rails db:encryption:init` → `credentials:edit` (`active_record_encryption:` bloco) + `.env`/`.env.example` (`ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` etc.) + fix do `filter_parameter_logging.rb`. Migração + model `encrypts` num plano seguinte. Nenhuma linha de `whatsapp_instances` gravada antes disso.
**Warning signs:** `grep -rn "encrypts" app/models` retorna algo mas `credentials` não tem `active_record_encryption`.

### Pitfall 2: `filter_parameters` não cobre `apikey`/`hash` (defeito pré-existente — fechar aqui)
**What goes wrong:** `Evolution::Client` já loga requests; o corpo do webhook carrega `apikey` (token) e QR base64; nada disso é filtrado.
**Why:** o filtro `:_key` casa `instance_key` mas **não** `apikey`; `:token` não casa `hash`. `:apikey` e `:hash` foram adicionados na fase 25 `[VERIFIED: config/initializers/filter_parameter_logging.rb:13-16]`; falta o resto para INFRA-04.
**How to avoid:** adicionar `:api_key, :instance_token, :qrcode, :base64, :pairing_code, :pairingCode` à lista (match por substring, case-insensitive, mesmo estilo de símbolos). NÃO trocar por regex.
**Also:** `filter_parameters` **não** filtra argumentos de ActiveJob nem `logger.info` manual — daí a regra "job leva `whatsapp_instance_id`, nunca o token" e "receiver nunca loga o corpo cru".
**Warning signs:** `grep -i "apikey\|base64" log/development.log` retorna string longa.

### Pitfall 3: Webhook emite `event` em dotcase, não UPPER_SNAKE
**What goes wrong:** receiver compara `params[:event] == "CONNECTION_UPDATE"` e nunca casa; estado nunca atualiza.
**Why:** o array que você **configura** em `events:` usa `CONNECTION_UPDATE`; o corpo emitido usa o **valor do enum** `connection.update` `[VERIFIED: wa.types.ts:5-38 (Events enum) + webhook.controller.ts (webhookData.event = event)]`. `evolution-contract.md` marca a grafia real do host como PENDENTE (UAT fase 26).
**How to avoid:** normalizar sempre: `params[:event].to_s.tr(".-", "__").upcase`. Aceita `connection.update`, `CONNECTION_UPDATE`, `connection-update`.
**Warning signs:** webhook chega (200 no log do Evolution) mas `connection_state` não muda; "Forçar verificação" corrige.

### Pitfall 4: Instância adotada sem webhook reapontado
**What goes wrong:** adoção grava a linha, mas o painel fica preso em "aguardando pareamento" — nenhum `connection.update` chega.
**Why:** a instância pré-existente aponta para outro webhook (ou nenhum).
**How to avoid:** `InstanceProvisioner#adopt` chama `Evolution::Client.set_webhook` **incondicionalmente**, antes de ler `connection_state`. (Decisão travada v1.7 + ARCHITECTURE.md Anti-Pattern 6.)
**Warning signs:** `origin == adopted_existing` e `last_checked_at` só muda quando o admin clica "Forçar verificação".

### Pitfall 5: `secure_compare` com comprimentos diferentes levanta exceção
**What goes wrong:** header ausente ou de tamanho diferente → `ArgumentError` → 500 em vez de 401; também vaza o tamanho do segredo.
**How to avoid:** `secure_compare(Digest::SHA256.hexdigest(presented), Digest::SHA256.hexdigest(expected))` (ambos viram 64 hex chars) ou `fixed_length_secure_compare`. Guardar `presented.blank? → return false`.
**Warning signs:** 500 no `POST /webhooks/evolution` com header vazio; `curl` sem header derruba o worker.

### Pitfall 6: `connect` devolve erro com HTTP 200
**What goes wrong:** `GET /instance/connect/{name}` retorna `{ "error": true, "message": "The \"x\" instance does not exist" }` com status 200 `[VERIFIED: instance.controller.ts connectToWhatsapp — catch retorna { error: true, message }]`.
**How to avoid:** `Evolution::Client.connect` checa `body["error"]` e levanta `Transient`/`Permanent` conforme a mensagem, em vez de assumir QR.

### Pitfall 7: `qrcode.updated` sem `base64` (limite de QR atingido)
**What goes wrong:** `data.dig("qrcode","base64")` é `nil` → `<img src="">` quebrado, ou `NoMethodError`.
**Why:** ao atingir `QRCODE_LIMIT` (default 30) o Evolution emite `qrcode.updated` com `{ message: "QR code limit reached, please login again", statusCode: ... }` (sem `qrcode`) e um `connection.update` `state: "refused"` `[VERIFIED: baileys.service.ts:336-360]`.
**How to avoid:** `return if b64.blank?` no handler; `state: "refused"` → `disconnected` + UI "gerar novo QR".

### Pitfall 8: `paired_at` sobrescrito em reconexão
**What goes wrong:** o número reconecta (novo `connection.update state=open`), `paired_at` é regravado, "pareado há N dias" zera — PAIR-08 mente.
**How to avoid:** `instance.paired_at ||= Time.current` (só grava se nil). Tanto no webhook quanto no `verify` quanto na adoção.

### Pitfall 9: Enumeração de instância via 404 vs 204
**What goes wrong:** segredo válido + instância inexistente respondendo 404 revela que aquele `instance_name` não existe.
**How to avoid:** decisão travada — 401 para segredo errado (checado ANTES do banco, não revela nada), 204 silencioso para segredo válido + instância desconhecida. Log info sem o segredo.

### Pitfall 10: `setInterval` do polling sobrevivendo à navegação Turbo
**What goes wrong:** admin sai da página, o `setInterval` continua batendo em `refresh_qr` (e, no fallback dev, no Evolution) para sempre.
**How to avoid:** `disconnect() { clearInterval(this.timer) }` no controller Stimulus. Também `clearInterval` ao atingir `connected` ou `MAX_CYCLES`.

### Pitfall 11: `config.hosts` bloqueando o webhook em produção
**What goes wrong:** Evolution faz `POST` para `https://ilhacriativa.autopyweb.com.br/webhooks/evolution` e o Rails responde 403 "Blocked host".
**How to avoid:** adicionar o hostname público a `config.hosts` em `config/environments/production.rb` (hoje comentado). Carregado adiante da fase 25 (D-12 / A4).

### Pitfall 12: QR base64 é credencial de pareamento visual
**What goes wrong:** quem vê o QR pareia o WhatsApp do cliente no próprio aparelho.
**How to avoid:** telas admin-only (`require_authentication` herdado); `last_qr_base64` nulo no `open`; nunca logado; `refresh_qr` só serve o base64 quando `awaiting_qr`.

## Code Examples

### `POST /instance/create` — request mínimo e response (tag `2.3.7`)

Request `[VERIFIED: src/api/dto/instance.dto.ts (InstanceDto.webhook) + src/api/integrations/event/event.manager.ts (setInstance→webhook.set) @ cd800f29]`:
```json
{
  "instanceName": "livia_client_5",
  "integration": "WHATSAPP-BAILEYS",
  "qrcode": true,
  "webhook": {
    "enabled": true,
    "url": "https://ilhacriativa.autopyweb.com.br/webhooks/evolution",
    "byEvents": false,
    "base64": true,
    "events": ["QRCODE_UPDATED", "CONNECTION_UPDATE"],
    "headers": { "X-Webhook-Secret": "<hex hmac-sha256(instance_name, key)>", "Content-Type": "application/json" }
  }
}
```

Response `[VERIFIED: src/api/controllers/instance.controller.ts createInstance() result literal @ cd800f29]`:
```json
{
  "instance": {
    "instanceName": "livia_client_5",
    "instanceId": "<uuid v4>",
    "integration": "WHATSAPP-BAILEYS",
    "webhookWaBusiness": null,
    "accessTokenWaBusiness": "",
    "status": "connecting"
  },
  "hash": "<UUID-V4-EM-CAIXA-ALTA>",
  "webhook": { "webhookUrl": "...", "webhookHeaders": {...}, "webhookByEvents": false, "webhookBase64": true },
  "websocket": {}, "rabbitmq": {}, "nats": {}, "sqs": {},
  "settings": { "rejectCall": false, "msgCall": "", "groupsIgnore": false, "alwaysOnline": false, "readMessages": false, "readStatus": false, "syncFullHistory": false, "wavoipToken": "" },
  "qrcode": { "pairingCode": null, "code": "2@<...>", "base64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg...", "count": 1 }
}
```
- `hash` é uma **string top-level** (`hash = v4().toUpperCase()` quando `token` não é passado) `[VERIFIED: instance.controller.ts:112-114 @ cd800f29]`. Alguns docs/versões mostram `hash: { apikey: "..." }` — o parser trata os dois casos (ver A5).
- `qrcode.base64` é o **data-URI PNG completo** (`qrcode.toDataURL`) `[VERIFIED: baileys.service.ts:381-389 @ cd800f29 + evolution-contract.md]`.

### Erro "nome já em uso" (PAIR-02 — o gatilho da adoção)

`[VERIFIED: src/api/guards/instance.guard.ts instanceLoggedGuard() @ cd800f29]`:
```ts
if (await getInstance(instance.instanceName)) {
  throw new ForbiddenException(`This name "${instance.instanceName}" is already in use.`);
}
```
`ForbiddenException` → **HTTP 403**. Envelope (formato verificado em `evolution-contract.md`):
```json
{ "status": 403, "error": "Forbidden", "response": { "message": "This name \"livia_client_5\" is already in use." } }
```
`Evolution::Client.raise_for_status!` já mapeia `403` → `Evolution::Errors::Permanent` com `"403 This name \"livia_client_5\" is already in use."` `[VERIFIED: app/services/evolution/client.rb:111-113]`. Adoção = `rescue Evolution::Errors::Permanent => e; next unless e.message =~ /already in use/i`.

### `POST /webhook/set/{instance}` — request e retorno

`[VERIFIED: src/api/integrations/event/webhook/webhook.router.ts + webhook.controller.ts set() @ cd800f29]`:
```json
{ "webhook": { "enabled": true, "url": "https://.../webhooks/evolution", "byEvents": false, "base64": true,
               "events": ["QRCODE_UPDATED", "CONNECTION_UPDATE"],
               "headers": { "X-Webhook-Secret": "<hmac>" } } }
```
- Retorna **HTTP 201** com a linha `webhook` persistida.
- ⚠️ se `enabled: true` **e** `events: []` → o Evolution seta `events` para **todos** `[VERIFIED: webhook.controller.ts set() @ cd800f29]`. Sempre passar a lista explícita.
- `headers` é `JsonValue` livre e é repassado pelo Evolution em TODA requisição de webhook `[VERIFIED: webhook.controller.ts emit() — webhookHeaders = {...instance?.headers}]`. É assim que o `X-Webhook-Secret` chega ao app.
- `GET /webhook/find/{instance}` devolve a config atual (útil para conferir a adoção).

### Envelope do webhook (todo evento)

`[VERIFIED: src/api/integrations/event/webhook/webhook.controller.ts emit() — objeto webhookData @ cd800f29]`:
```json
{
  "event": "connection.update",
  "instance": "livia_client_5",
  "data": { "...": "..." },
  "destination": "https://ilhacriativa.autopyweb.com.br/webhooks/evolution",
  "date_time": "2026-08-30T12:00:00.000Z",
  "sender": "<...>",
  "server_url": "https://whatsapp.bomcustoilhabela.com.br",
  "apikey": "<TOKEN HASH DA INSTÂNCIA>"
}
```
`event` = valor do enum em **dotcase**. O `instance` no corpo é o `instance_name`. O `apikey` no corpo é o token da instância → **não logar o corpo cru**.

### `data` de `qrcode.updated`

Normal `[VERIFIED: baileys.service.ts:391-393 @ cd800f29]`:
```json
{ "qrcode": { "instance": "livia_client_5", "pairingCode": null, "code": "2@<...>", "base64": "data:image/png;base64,<...>" } }
```
Limite atingido `[VERIFIED: baileys.service.ts:337-340 @ cd800f29]`:
```json
{ "message": "QR code limit reached, please login again", "statusCode": 500 }
```

### `data` de `connection.update`

`[VERIFIED: baileys.service.ts:432-519 @ cd800f29]`:
```json
// connecting
{ "instance": "livia_client_5", "state": "connecting", "statusReason": 200 }
// open
{ "instance": "livia_client_5", "wuid": "5511999999999@s.whatsapp.net", "profileName": "Fulano",
  "profilePictureUrl": "https://...", "state": "open", "statusReason": 200 }
// close
{ "instance": "livia_client_5", "state": "close", "statusReason": 401 }
// refused (limite de QR)
{ "instance": "livia_client_5", "state": "refused", "statusReason": 428, "wuid": null,
  "profileName": null, "profilePictureUrl": null }
```
`state` ∈ `open | close | connecting | refused`. Mapeamento local:

| Evolution `state` | `whatsapp_instances.connection_state` |
|-------------------|---------------------------------------|
| `open` | `connected` |
| `connecting` | `awaiting_qr` |
| `close` | `disconnected` |
| `refused` | `disconnected` |
| (sem linha / nunca conectou) | `unpaired` |

`statusReason` que **NÃO** auto-reconectam (exigem QR novo): `401` (loggedOut), `403` (forbidden), `402`, `406` `[VERIFIED: baileys.service.ts:424 — codesToNotReconnect = [DisconnectReason.loggedOut, DisconnectReason.forbidden, 402, 406]]`. Os demais (`408, 428, 500, 515`) auto-reconectam.

### `bin/rails db:encryption:init` — saída e onde vai

`[CITED: guides.rubyonrails.org/active_record_encryption.html]`:
```yaml
# cole em `bin/rails credentials:edit`
active_record_encryption:
  primary_key: <32 chars>
  deterministic_key: <32 chars>
  key_derivation_salt: <32 chars>
```
- Rails lê `credentials.active_record_encryption` **automaticamente** — sem initializer.
- Dev/test (o repo tem 1 credentials só, `config/credentials.yml.enc` `[VERIFIED: config/ listing]`): as mesmas 3 chaves servem; alternativa é `.env` com `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` / `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` / `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` (Rails também faz esse fallback nativo) `[CITED: guides.rubyonrails.org/active_record_encryption.html]`.
- `encrypts :token` **sem** `deterministic: true` → não-determinístico (AES-GCM, IV aleatório). Não pode ser usado em `WHERE token = ?` — irrelevante aqui `[CITED: same]`.
- Sem dados legados → **não** precisa de `config.active_record.encryption.support_unencrypted_data`.

### `whatsapp_instances` — migração e model

```ruby
create_table :whatsapp_instances do |t|
  t.references :client, null: false, foreign_key: true, index: { unique: true }
  t.string   :instance_name,     null: false
  t.string   :remote_instance_id                        # Evolution instanceId (UUID) — debug
  t.text     :token                                     # encrypts :token → ciphertext maior que a string
  t.integer  :connection_state,  null: false, default: 0
  t.integer  :origin,            null: false, default: 0
  t.text     :last_qr_base64                            # volátil; nulo no "open"; filtrado do log
  t.datetime :qr_expires_at
  t.datetime :paired_at                                 # 1x no 1º "open" (PAIR-08)
  t.datetime :last_checked_at                           # webhook OU "Forçar verificação"
  t.text     :last_error
  t.timestamps
end
add_index :whatsapp_instances, :instance_name, unique: true
```

```ruby
class WhatsappInstance < ApplicationRecord
  belongs_to :client
  encrypts :token   # não-determinístico

  enum :connection_state, { unpaired: 0, awaiting_qr: 1, connected: 2, disconnected: 3 }
  enum :origin,           { created_by_app: 0, adopted_existing: 1 }, prefix: :origin

  def self.evolution_name_for(client) = "livia_client_#{client.id}"

  def self.webhook_secret_for(instance_name)
    key = Rails.application.credentials.dig(:evolution, :webhook_hmac_key) || ENV.fetch("EVOLUTION_WEBHOOK_HMAC_KEY")
    OpenSSL::HMAC.hexdigest("SHA256", key, instance_name)
  end

  def paired_days = paired_at && ((Time.current - paired_at) / 1.day).floor
  def recently_paired? = paired_days && paired_days < 7
end
```
> `token` como `text` (não `string`): o ciphertext do AR Encryption + metadados JSON pode passar de 255 chars.

### Rotas

```ruby
# config/routes.rb  (dentro de namespace :admin, resources :clients ... do)
resource :whatsapp_instance, only: [:create, :destroy], controller: "whatsapp_instances" do
  get  :refresh_qr
  post :verify        # "Forçar verificação" (PAIR-05) — síncrono
  post :adopt         # oferecido inline após 403 "already in use"
  post :reconnect     # "Parear novamente"
end

# fora de todo namespace, acima do health check (linha 64):
post "/webhooks/evolution", to: "webhooks/evolution#create"
```
> Precedente de ação custom em resource admin: `member do post :rotate_token end` `[VERIFIED: config/routes.rb:9-13]`.

### Rack::Attack — throttle do webhook

```ruby
# config/initializers/rack_attack.rb  (mesmo estilo dos blocos existentes [VERIFIED: :4-8])
throttle("webhooks/evolution_by_ip", limit: 120, period: 60) do |req|
  req.ip if req.path == "/webhooks/evolution" && req.post?
end
```

### Toast sem ActionCable (feedback do `verify` / `create`)

Duas opções, ambas válidas com o `toast_controller.js` atual `[VERIFIED: app/javascript/controllers/toast_controller.js]`:
1. **MVP:** `redirect_to admin_client_path(@client), notice: "..."` → a layout admin já renderiza o flash banner. Simples, cobre PAIR-05.
2. **Fiel ao 26-UI-SPEC (toast):** a ação responde `format.turbo_stream` com `turbo_stream.append("admin-toast-region", partial: "admin/shared/toast", locals: {...})`. O `toast_controller.js` monta no `connect` e auto-dismissa. Sem cable — a resposta do próprio POST carrega o stream.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `attr_encrypted` / `lockbox` gem | Active Record Encryption nativo (`encrypts`) | Rails 7.0 | Zero gem; `bin/rails db:encryption:init` + 3 chaves em credentials |
| Evolution v1 (payload diferente) | Evolution v2.3.7 (host da agência, confirmado) | — | Rotas iguais, só o corpo muda; sem drift 2.4 `[VERIFIED: evolution-contract.md]` |
| `hash: { apikey }` em respostas antigas do `/instance/create` | `hash` string top-level no 2.3.7 | tag 2.3.7 | Parser defensivo cobre os dois (A5) |
| Polling de QR via `GET /instance/connect` a cada tick | Webhook `qrcode.updated` empurra o base64 fresco; poll só lê o DB | Evolution v2 | Menos carga no host; poll continua como fallback dev |

**Deprecated/outdated:**
- Não usar `Authorization: Bearer` com o Evolution — só header `apikey` (401 verificado no host) `[VERIFIED: evolution-contract.md]`.
- Não usar `config.active_record.encryption` via initializer custom — credentials/ENV nativo.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `GET /instance/fetchInstances` expõe o `token`/`hash` por instância para uma instância **não criada por nós** (necessário para a adoção capturar o token de envio da fase 29) | Fluxo de adoção / `InstanceProvisioner#adopt` | Se o token não vier, a instância adotada não consegue enviar na fase 29. Mitigação: fase 26 não envia; marcar como item de UAT e, se faltar, pedir o token ao operador ou recriar com `token:` controlado por nós. |
| A2 | O host emite `event` do webhook em dotcase (`connection.update`) — verificado na FONTE do tag 2.3.7, mas a grafia real emitida pelo host é PENDENTE em `evolution-contract.md` (#3) | Pitfall 3 / webhook receiver | Baixo — o receiver normaliza `tr(".-","__").upcase` e aceita as duas grafias. |
| A3 | O host Evolution alcança `https://ilhacriativa.autopyweb.com.br/webhooks/evolution` (app ainda não deployado lá) | Environment Availability | Médio — se não alcançar, o polling do `refresh_qr` + "Forçar verificação" (PAIR-05) carregam o fluxo (fallback já projetado). Não bloqueia. Carregado da fase 25 (A4/D-12). |
| A4 | `POST /instance/create` responde HTTP 200 (a fonte devolve o objeto; o status não aparece explícito no trecho) | Code Examples | Baixo — `Evolution::Client` trata qualquer 2xx como sucesso; `raise_for_status!` só age em não-2xx. |
| A5 | `hash` na resposta do create é string top-level (fonte 2.3.7 confirma; docs de outras versões mostram `hash.apikey`) | `InstanceProvisioner#persist_new` | Baixo — parser defensivo: `resp["hash"].is_a?(Hash) ? resp.dig("hash","apikey") : resp["hash"]`. |
| A6 | O `X-Webhook-Secret` em `webhook.headers` é entregue pelo Evolution em todo evento (verificado na fonte `emit()`; não observado no host real) | Webhook receiver | Médio — se o host não repassar headers custom, a auth do webhook não funciona e só o fallback síncrono resta. UAT: inspecionar os headers de um webhook real. |
| A7 | Intervalo de rotação do QR do WhatsApp ~20–30s; `QRCODE_LIMIT` default 30 | Stimulus polling | Baixo — poll a 20s cobre; timeout de tela em ~6 ciclos com botão manual. |
| A8 | `fetchInstances` retorna objetos com chave `name` (ou `instanceName`) para casar o `instance_name` na adoção | `InstanceProvisioner#adopt` | Baixo — código tenta as duas chaves. `evolution-contract.md` confirma que `fetch_instances` retornou Array[6] no host. |

## Open Questions

1. **Token de instância adotada (A1).**
   - What we know: `create` sem `token:` gera `hash = v4().toUpperCase()`; `fetchInstances` retorna um array de instâncias.
   - What's unclear: se cada item traz o `token`/`hash` para instâncias que não criamos.
   - Recommendation: tratar como item de UAT da fase 26. Fase 26 não envia, então não bloqueia. Se faltar, a fase 29 (envio) resolve pedindo o token ao operador ou recriando.

2. **Alcançabilidade inbound do webhook (A3/A6).**
   - What we know: outbound app→Evolution verificado (fase 25, ~654ms). Inbound não testado (app não deployado no hostname público).
   - What's unclear: se o host Evolution alcança o app e se repassa `X-Webhook-Secret`.
   - Recommendation: o design já tem fallback (polling + PAIR-05). UAT após deploy: `curl` do host Evolution para `/webhooks/evolution` e inspeção dos headers de um evento real. Se falhar, PAIR-05 é o caminho principal em dev/prod até o deploy fechar.

3. **`Evolution::InstanceProvisioner` vs métodos gordos no model (Claude's discretion).**
   - What we know: precedente do projeto é service PORO em `app/services/` para integração externa; a fase 25 criou `app/services/evolution/`.
   - Recommendation: PORO `Evolution::InstanceProvisioner` na mesma pasta do `Client` (descoberta/consistência). A ARCHITECTURE.md propôs `app/services/whatsapp/` — divergência só de nomenclatura; ficar com `evolution/` evita uma segunda pasta para 1 arquivo.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Host Evolution (outbound) `whatsapp.bomcustoilhabela.com.br` | create/connect/set_webhook/connection_state | ✓ | API `2.3.7` (atrás de Cloudflare) | — (verificado fase 25: `fetch_instances` → Array[6], ~654ms) |
| Inbound: host Evolution → app `/webhooks/evolution` | PAIR-06 (webhook ao vivo) | ✗ (app não deployado em `ilhacriativa.autopyweb.com.br`) | — | Polling do `refresh_qr` + "Forçar verificação" (PAIR-05) — **já projetado como caminho principal em dev** |
| `bin/rails db:encryption:init` | EVO-04 (gerar as 3 chaves) | ✓ | Rails 8.1.3 | — |
| `bin/rails` (migração, runner) | migração `whatsapp_instances` | ✓ | — | — |
| `bin/rails test` | testes automatizados | ✗ | — | `PG::InsufficientPrivilege` (banco de teste de outro usuário do SO — conhecido). Verificar por inspeção + `bin/rails runner` com Faraday stub, como na fase 25 `[VERIFIED: STATE.md decisions 25-05]` |
| `config.hosts` (produção) | webhook inbound não ser bloqueado | ✗ (comentado) | — | Adicionar o hostname público em `production.rb` (passo desta fase / operador) |

**Missing dependencies with no fallback:** nenhuma que bloqueie a fase.
**Missing dependencies with fallback:** webhook inbound → polling + PAIR-05 (fallback é parte do design travado, não um degradê).

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high` `[VERIFIED: .planning/config.json]`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim (webhook) | Segredo compartilhado `HMAC-SHA256(instance_name, key)` + `secure_compare`. Telas admin herdam `require_authentication` `[VERIFIED: app/controllers/admin/base_controller.rb:3]` |
| V3 Session Management | sim | `Webhooks::EvolutionController < ActionController::API` — sem sessão, sem CSRF (correto para máquina→máquina) `[VERIFIED: app/controllers/api/v1/base_controller.rb:3]` |
| V4 Access Control | sim | Instância escopada por `@client.whatsapp_instance`; `instance_name` derivado de `client.id`, nunca de `params`. Webhook: 401 (segredo) antes do `find_by`; 204 para instância desconhecida (não vaza) |
| V5 Input Validation | sim | Corpo do webhook é não-confiável: `params[:instance]` só entra no HMAC e num `find_by` parametrizado; `params[:event]` normalizado contra whitelist de 2 valores; `data.dig(...)` com guarda de `nil`. **base64 do webhook:** validar prefixo `data:image/png;base64,` (ou regex `\A[A-Za-z0-9+/=]+\z` no corpo) antes de renderizar em `<img>` — impede data-URI `text/html`/SVG com script. Renderizar server-side. |
| V6 Cryptography | sim | `encrypts :token` (AES-GCM, AR Encryption — nunca à mão); `OpenSSL::HMAC` (stdlib); `SecurityUtils.secure_compare` (timing-safe). Chaves em credentials/ENV, nunca no repo. |
| V7 Errors & Logging | sim | `Evolution::Client` loga só `método path status ms` `[VERIFIED: app/services/evolution/client.rb:91]`. Receiver **nunca** loga `request.raw_post`/`params.inspect` (corpo tem `apikey` + QR base64). `filter_parameters` estendido (INFRA-04). |
| V9 Communications | sim | `EVOLUTION_BASE_URL` deve ser `https://` — já falha no boot em produção `[VERIFIED: config/initializers/evolution.rb:16-20]`. A `webhook_url` passada ao Evolution deve ser `https://`. |

### Known Threat Patterns for {Rails webhook + shared Evolution manager}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Webhook forjado `connection.update state=close` → DoS do estado da instância | Spoofing / DoS | `secure_compare` do HMAC **antes** de qualquer query (PAIR-06) + `throttle` Rack::Attack 120/60s |
| Enumeração de `instance_name` via resposta 404 vs 204 | Information Disclosure | 401 para segredo errado (checado 1º, sem query); 204 silencioso para segredo válido + instância desconhecida |
| `apikey`/token da instância + QR base64 vazando em log (corpo do webhook, resposta do `/instance/create`) | Information Disclosure | `filter_parameters` + regra "nunca logar corpo cru" + `Evolution::Client` já loga só metadados |
| Token da instância em `solid_queue_jobs.arguments` (texto claro) | Information Disclosure | Jobs recebem `whatsapp_instance_id`; token lido dentro do `perform` |
| Dump do Postgres entrega o WhatsApp de todos os clientes | Information Disclosure | `encrypts :token` (EVO-04) |
| Sequestro de instância no manager compartilhado (nome adivinhável) | Spoofing / Elevation | Prefixo `livia_`; adoção só via 403 + `fetch_instances` confirmando existência; webhook sempre reapontado |
| Data-URI malicioso no `<img>` do QR (XSS via `qrcode.base64` do webhook) | Tampering / XSS | Validar prefixo `data:image/png;base64,` / charset base64 antes de renderizar; render server-side |
| `secure_compare` com comprimento divergente → 500 + leak de tamanho | Information Disclosure | Comparar `Digest::SHA256.hexdigest` dos dois lados (comprimento fixo) |
| Timezone do host divergente afetando `paired_at`/`last_checked_at` | — (correção) | `TZ=America/Sao_Paulo` já fixado no deploy + boot check (fase 25) `[VERIFIED: STATE.md 25-03]`; usar `Time.current`, nunca `Time.now` |

## Sources

### Primary (HIGH confidence)
- **Evolution API @ commit `cd800f2976e1e5b682fbf86a01ee4d85ae61f370` (tag `2.3.7` — versão exata do host da agência):**
  - `src/api/controllers/instance.controller.ts` — `createInstance()` (result literal, `hash` string, `qrcode` object), `connectToWhatsapp()` (GET /instance/connect, `{error:true}` com HTTP 200)
  - `src/api/guards/instance.guard.ts` — `instanceLoggedGuard()`: `ForbiddenException('This name "<x>" is already in use.')` (→ 403)
  - `src/api/dto/instance.dto.ts` — `InstanceDto.webhook { enabled, events, headers, url, byEvents, base64 }`
  - `src/api/integrations/event/event.manager.ts` — `setInstance()` encaminha `webhook` inline para `webhook.set`
  - `src/api/integrations/event/webhook/webhook.controller.ts` — `set()` (força todos os eventos se lista vazia), `emit()` (envelope `{event,instance,data,destination,date_time,sender,server_url,apikey}`, headers custom repassados)
  - `src/api/integrations/event/webhook/webhook.router.ts` — `POST /webhook/set/{instance}` → 201; `GET /webhook/find/{instance}`
  - `src/api/integrations/channel/whatsapp/whatsapp.baileys.service.ts` — `connectionUpdate()`: payloads de `qrcode.updated` (normal + limite) e `connection.update` (connecting/open/close/refused), `codesToNotReconnect = [401,403,402,406]`
  - `src/api/routes/instance.router.ts` — `POST /instance/create` (body), `GET /instance/connect|connectionState/{instance}`
  - `src/api/types/wa.types.ts` — `Events` enum (dotcase: `connection.update`, `qrcode.updated`), `Integration.WHATSAPP_BAILEYS = 'WHATSAPP-BAILEYS'`
  - `src/validate/instance.schema.ts` — lista de eventos válidos (UPPER_SNAKE na config)
- **Este repositório (fatos internos, HIGH):** `app/services/evolution/client.rb`, `app/services/evolution.rb`, `app/services/evolution/errors.rb`, `config/initializers/evolution.rb`, `config/initializers/filter_parameter_logging.rb`, `config/initializers/rack_attack.rb`, `config/routes.rb`, `app/models/client.rb`, `app/models/arte.rb`, `app/controllers/admin/clients_controller.rb`, `app/controllers/admin/base_controller.rb`, `app/controllers/api/v1/base_controller.rb`, `app/channels/application_cable/connection.rb`, `app/channels/admin_notifications_channel.rb`, `app/views/admin/clients/{show.html.erb,_confirm_modal.html.erb,_status_badge.html.erb}`, `app/javascript/controllers/toast_controller.js`, `Gemfile`, `.planning/config.json`
- `.planning/notes/evolution-contract.md` — contrato empírico canônico (host = 2.3.7 atrás de Cloudflare; envelope de erro `{status,error,response.message}`; `message` string OU array)
- `.planning/phases/26-.../26-CONTEXT.md` e `26-UI-SPEC.md` — decisões travadas + contrato visual aprovado

### Secondary (MEDIUM confidence)
- [guides.rubyonrails.org/active_record_encryption.html](https://guides.rubyonrails.org/active_record_encryption.html) — `db:encryption:init`, 3 chaves, credentials vs `ACTIVE_RECORD_ENCRYPTION_*`, não-determinístico é o default, sem rotação para determinístico
- `.planning/research/{SUMMARY,ARCHITECTURE,PITFALLS}.md` — pesquisa de 4 agentes da milestone (consultada, não reconstruída); ARCHITECTURE §1.1/§5 e Anti-Pattern 6, PITFALLS §4/§6/§12

### Tertiary (LOW confidence — não planejar em cima)
- Postman "Evolution API v2.2" e docs de comunidade — corroboração do shape do webhook; superados pela leitura da fonte no tag
- Números de rotação de QR (~20–30s) e `QRCODE_LIMIT` — heurística/config default

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero gem nova; tudo built-in ou já no bundle; verificado no `Gemfile`
- Contratos Evolution (endpoints, payloads, erro de nome-em-uso): HIGH — lidos da fonte no commit exato do tag que o host roda; a única incerteza é grafia do `event` emitido pelo host real (mitigada por normalização) e token de instância adotada (A1)
- Active Record Encryption: HIGH — guia oficial + padrão estabelecido do Rails 8
- Webhook auth / arquitetura: HIGH no lado Rails (precedentes v1.6 lidos); MEDIUM na entrega do header custom pelo host (A6)
- Pitfalls: HIGH — combinação de leitura de fonte + defeitos pré-existentes já confirmados por inspeção nas fases 25 e na pesquisa da milestone

**Research date:** 2026-08-30
**Valid until:** ~2026-09-30 para o lado Rails; o contrato Evolution é estável enquanto o host permanecer em `2.3.7` (sem drift 2.4 — `evolution-contract.md`). Itens A1/A3/A6 fecham em UAT da fase 26.
