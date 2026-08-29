# Phase 25: Fundação — Transporte Evolution + Storage Alcançável - Research

**Researched:** 2026-08-29
**Domain:** Rails 8.1.3 monólito — cliente HTTP PORO para uma bridge WhatsApp self-hosted (Evolution API v2.3.7), ActiveStorage sobre S3-compatível (MinIO) alcançável de fora da LAN, solid_queue confiável em development, timezone determinístico, e deploy Docker do app num host público.
**Confidence:** HIGH no lado Rails e no contrato de leitura do Evolution (versão do host verificada empiricamente = `2.3.7`, o mesmo tag da pesquisa); MEDIUM no caminho de escrita do Evolution (send/webhook — PENDENTE de UAT) e no shape final do `docker compose` de produção.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Storage / MinIO (INFRA-01)**
- **D-01:** Object storage = **MinIO self-hosted**, via `aws-sdk-s3` com `endpoint:` custom, rodando **no mesmo host público do Evolution** (`whatsapp.bomcustoilhabela.com.br`), sob subdomínio próprio com TLS (ex: `s3.bomcustoilhabela.com.br`). Alcançabilidade pelo host do Evolution é estrutural — não depende de o app estar público. Reversibility: costly (trocar de provedor exige re-upload de todos os blobs + rotação de `storage.yml`/credentials).
- **D-02:** URLs de mídia **presignadas, bucket privado**; presigned URL gerada **dentro do `perform`** do job de envio, com `expires_in` explícito cobrindo o disparo inteiro (~15 min). Nenhum objeto permanentemente público. *(Discrição de Claude, seguindo a pesquisa.)*
- **D-03:** **Bucket por ambiente** (`bucket-<Rails.env>`), com **bucket de development ativo no MinIO** para exercitar o caminho presignado localmente. `development.rb` passa de `service: :local` para o serviço MinIO. *(Discrição de Claude.)*

**Migração de blobs locais (INFRA-01)**
- **D-04:** **Migrar todos os anexos locais existentes** (~21 MB, 13 arquivos em `storage/`) para o MinIO. Nenhuma arte perde arquivo.
- **D-05:** Entregue como **rake task idempotente** em `lib/tasks/` — itera blobs, pula os já existentes no destino, loga o resultado; rodada manualmente no deploy; reexecutável sem duplicar. *(Discrição de Claude.)*

**Verificação empírica do contrato Evolution (EVO-01)**
- **D-06:** Usuário fornece **base URL + apikey global** (canal seguro / credentials); Claude monta e roda o probe contra o host real durante o research da fase 25. Round-trip que destrava o milestone — nenhum código depende do contrato até ele estar registrado por escrito.
- **D-07:** Contrato verificado registrado em **`.planning/notes/evolution-contract.md`** como fonte canônica (estilo `api-auth-strategy.md`), servindo as fases 25–30. Reversibility: reversible.
- **D-08:** O probe tenta um **`sendText` + `sendMedia` reais a um grupo de teste** e mede o teto de mídia com arquivos de 5/15/20/30 MB, **se** houver instância pareada + grupo de teste. O que não fechar vira **item pendente rastreado em `evolution-contract.md`**, nomeando a fase onde será medido (UAT 26/28). *(Discrição de Claude.)*

**Escopo de produção / deploy (INFRA-01, INFRA-03)**
- **D-09:** **O app Rails é deployado num host público nesta fase** — não só o MinIO. Porção "+ Deploy" do milestone ancorada aqui. Amplia a fase além do enunciado do ROADMAP. Reversibility: costly (estabelece a infra de produção que as fases seguintes assumem).
- **D-10:** Ferramenta de deploy = **Docker** (Dockerfile + `docker compose` no host, deploy por `git pull` + rebuild), com o **worker `bin/jobs` do solid_queue como serviço próprio no compose**, e TLS por reverse proxy no host. *(Interpretação da resposta livre do usuário; **confirmar no início do planning** se a ferramenta pretendida era outra — podman / dokku / Kamal.)*
- **D-11:** App roda no **mesmo servidor** que Evolution + MinIO. Risco de co-locação = **risco aceito conscientemente**; separação app / Evolution anotada como candidato a hardening no backlog. *(Discrição de Claude.)*
- **D-12:** Receiver de webhook permanece na **fase 26**; a fase 25 só confirma **alcance app ↔ Evolution nos dois sentidos** como parte da verificação de deploy. *(Discrição de Claude.)*

### Claude's Discretion

- Valores exatos de open/read/write timeout do `Evolution::Client`. → **Resolvido neste research** (ver Standard Stack + evolution-contract.md): `open 5s / write 10s / read 30s` no geral, `read 15s` nas leituras; teto da Cloudflare ~100 s torna valores altos inúteis.
- Fail-hard (raise no boot) vs. warn para a verificação de `TZ` (INFRA-03). → **Resolvido neste research: fail-hard (raise) em produção, warn em development.** Ver Pattern 4.
- Se a fila `whatsapp` dedicada nasce agora ou só na fase 29 (ROADMAP põe INFRA-06 na 29 — default é seguir o ROADMAP). → **Recomendação: seguir o ROADMAP, fila dedicada só na 29.** A fase 25 só corrige o adapter ausente.
- Split `credentials` vs `ENV` para a apikey global. → **Resolvido: `ENV.fetch(...) { Rails.application.credentials.dig(...) }`**, espelhando `Api::JwtService.secret` (`credentials || ENV.fetch`). Ver Pattern 2.
- Shape das classes da taxonomia de erro — espelhar o módulo aninhado `Api::Errors` de `jwt_service.rb`. → Ver Pattern 3.
- Estratégia da migração para S3 dos blobs (default: rake task idempotente, D-05). → Ver Pattern 6.

### Deferred Ideas (OUT OF SCOPE)

- **Separação de servidores app ↔ Evolution/MinIO** — candidato a hardening no backlog (pós-v1.7 ou fase 30). Hoje: co-locação aceita (D-11).
- **Smoke test de webhook na fase 25** — recusado; o receiver completo (`Webhooks::EvolutionController`, `secure_compare`, Rack::Attack) fica na fase 26 (D-12).
- **Normalização de links Drive/Dropbox** — já é `PROD-04`; no v1.7 esses links são bloqueados na Divulgação (fase 28), não normalizados.
- **Migrar `default_timezone` para `:utc`** — mudança transversal; INFRA-03 resolve o risco fixando `TZ` (REQUIREMENTS.md Out of Scope).
- **Fila `whatsapp` dedicada / retenção de `failed_executions`** — INFRA-06 (fase 29) e INFRA-07 (fase 30).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Descrição | Suporte da pesquisa |
|----|-----------|---------------------|
| **INFRA-01** | ActiveStorage serve arquivos via S3 em produção, com URL alcançável pelo host público do Evolution | Standard Stack (`aws-sdk-s3 ~> 1.229`), Pattern 5 (serviço MinIO em `storage.yml`), Pattern 6 (migração de blobs), Pitfall 3 (URL alcançável), Environment Availability (MinIO). `blob.url(expires_in:)` = presigned S3 direto (verificado `S3Service#private_url`, STACK.md). |
| **INFRA-02** | Jobs agendados sobrevivem a reinício do servidor em development | Pattern 1 (`queue_adapter = :solid_queue` em `development.rb` + carregar `db/queue_schema.rb` no banco de dev + `bin/jobs` no `Procfile.dev`). Defeito verificado: `development.rb` não tem adapter → cai em `:async` (perde jobs no restart). |
| **INFRA-03** | Fuso determinístico entre dev e produção (`TZ` fixado no deploy, verificado no boot) | Pattern 4 (initializer de verificação de `TZ`/`Time.zone`), Pitfall 4 (timezone). `config.active_record.default_timezone = :local` **mantido** (verificado `config/application.rb:25`); `TZ=America/Sao_Paulo` no env do container + raise no boot em produção. |
| **INFRA-05** | `good_job` removido do Gemfile, restando um único adapter de fila | Pattern 7. Verificado: `Gemfile:35` `gem "good_job", "~> 4.0"`; `good_job 4.18.2` no lockfile; zero referências em `config/`/`db/`/`app/`/`lib/` (STACK.md grep). Commit isolado, cedo. |
| **EVO-01** | Contrato do Evolution verificado empiricamente contra o host real antes de qualquer código depender dele | **`.planning/notes/evolution-contract.md`** (criado neste research). Host verificado = **`2.3.7`** (mesmo tag da pesquisa). Read-path VERIFICADO; write-path (send, webhook casing, teto de mídia) PENDENTE → UAT fases 26/28. |
| **EVO-02** | Toda comunicação HTTP com o Evolution passa por um único service PORO, com timeouts explícitos e header `apikey` | Pattern 2 (`Evolution::Client` / `Whatsapp::EvolutionClient`), Standard Stack (`faraday ~> 2.14`). Header `apikey` confirmado empiricamente como único esquema (Bearer → 401). |
| **EVO-03** | Erros classificados em transitório / permanente / incerto / não-conectado, cada classe com tratamento distinto | Pattern 3 (módulo `Errors` aninhado espelhando `Api::Errors`), evolution-contract.md §"Decisões de client". Envelope de erro verificado: `{status, error, response:{message: string\|array}}` — parser não pode assumir string. |
</phase_requirements>

## Summary

Esta fase é **de-risking sem UI**: entrega a costura HTTP única com o Evolution, o storage que o host do Evolution consegue baixar de fora da LAN, jobs de background que sobrevivem a restart em dev, um fuso determinístico, e o deploy Docker do app num host público. Ela **não** cria models, migrations de domínio, controllers ou views — isso começa na fase 26.

A verificação empírica do contrato Evolution (EVO-01) foi executada neste research: um probe HTTP real contra `https://whatsapp.bomcustoilhabela.com.br` confirmou que **o host roda exatamente `2.3.7`** — o mesmo tag em que STACK/FEATURES/ARCHITECTURE leram routers, DTOs e schemas do código-fonte. Isso elimina o maior risco do milestone (drift de versão): os contratos de rota, auth e DTO lidos da pesquisa valem como verificados. O que **não** deu para fechar sem credenciais e instância pareada — casing dos eventos de webhook, teto real de mídia, shape de resposta de `sendMedia`, formato do erro de envio — está marcado PENDENTE em `.planning/notes/evolution-contract.md` com a fase de UAT (26/28) onde fecha.

O trabalho Rails é pequeno em superfície e alto em precisão: **2 gems novas** (`faraday ~> 2.14`, `aws-sdk-s3 ~> 1.229 require: false`), **1 removida** (`good_job`), um PORO `Evolution::Client` com `module Errors` aninhado (espelhando `Api::JwtService`), um serviço `amazon`/MinIO em `storage.yml`, `queue_adapter = :solid_queue` em `development.rb` com o schema de fila carregado, um initializer de verificação de `TZ`, e uma rake task idempotente de migração de blobs. O deploy adiciona um serviço `jobs` (`bin/jobs`) ao `docker-compose.yml` já existente, um reverse proxy com TLS, `force_ssl`/`hosts` em `production.rb`, e `TZ` no env do container.

**Primary recommendation:** implementar em dois blocos paralelos independentes — **(A) transporte Evolution** (`faraday`, `Evolution::Client` + `Errors`, initializer de config, `-good_job`) e **(B) storage + jobs + tz + deploy** (`aws-sdk-s3`, `storage.yml` MinIO, `development.rb` adapter, initializer de `TZ`, rake de migração, `docker-compose.yml` + proxy). Verificação de A = round-trip real de leitura contra o host da agência. Verificação de B = upload real no MinIO baixável por `curl` de fora da LAN + job agendado sobrevivendo a `bin/dev` restart.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fala HTTP com o Evolution | API / Backend (`Evolution::Client` PORO) | — | Única costura; nenhum controller/job fala HTTP direto (precedente `Api::JwtService`). |
| Classificação de erro do Evolution | API / Backend (`Evolution::Errors`) | — | O chamador decide retry/discard a partir da classe, não do status cru. |
| Servir mídia para download externo | Database / Storage (MinIO S3-compat) + CDN/borda (subdomínio TLS) | API / Backend (mint da presigned URL no job) | Quem baixa é o host do Evolution; a URL tem que ser presignada e alcançável da internet. |
| Persistência durável de jobs agendados | Database / Storage (solid_queue tables) | API / Backend (`ActiveJob`/`bin/jobs`) | `:async` perde jobs no restart — precisa das tabelas + worker. |
| Determinismo de fuso | API / Backend (boot check) + Infra (`TZ` no container) | — | `default_timezone = :local` só é seguro se `TZ` for fixo e verificado. |
| Deploy do app | Infra (Docker / `docker compose` + reverse proxy no host) | — | Serviço `web` + serviço `jobs` + proxy TLS, co-locados com Evolution + MinIO (D-11). |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `faraday` | `~> 2.14` (latest `2.14.3` [VERIFIED: `gem list -r -e faraday` → `faraday (2.14.3)`, 2026-08-29]) | Cliente HTTP do `Evolution::Client` | Traz `Faraday::Adapter::Test` (o repo **não tem** WebMock nem VCR — sem isso, testar o client = disparar mensagens reais); centraliza `base_url` + header `apikey` + os 3 timeouts numa única `Faraday::Connection`. Deps: `faraday-net_http`, `json`, `logger`. [CITED: .planning/research/STACK.md §1] |
| `aws-sdk-s3` | `~> 1.229`, `require: false` (latest `1.229.0` [VERIFIED: `gem list -r -e aws-sdk-s3` → `aws-sdk-s3 (1.229.0)`, 2026-08-29]) | ActiveStorage S3/MinIO em produção + development | Rails 8.1.3 declara `gem "aws-sdk-s3", "~> 1.48"` em `activestorage/.../s3_service.rb:3` — `1.229` satisfaz. `require: false` porque o ActiveStorage faz `require` lazy. **`aws-sdk-rails` NÃO é necessário** (é para SES/SQS/parameter-store). [CITED: .planning/research/STACK.md §6] |
| `solid_queue` | `1.4.0` instalado [VERIFIED: Gemfile.lock → `solid_queue (1.4.0)`] · latest `1.7.0` [VERIFIED: `gem list -r -e solid_queue` → `1.7.0`, 2026-08-29] | Jobs agendados duráveis | **Já instalado e já é o único adapter ligado** (`production.rb:53` `queue_adapter = :solid_queue`). `enqueue_at`/`limits_concurrency` confirmados na cópia em `vendor/bundle` (STACK.md §3). **Upgrade para 1.7.0 está fora de escopo** — nada que o v1.7 precisa falta na 1.4.0. |
| ActiveStorage | `8.1.3` (built-in) [VERIFIED: Gemfile.lock → `activestorage (8.1.3)`] | Fonte de mídia; `blob.url(expires_in:)` = presigned S3 direto | `S3Service#private_url` = `object.presigned_url(:get, expires_in:, ...)` (STACK.md §6). Funciona contra MinIO com `endpoint:` + `force_path_style: true`. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `active_storage_validations` | já no Gemfile (`Gemfile:36`) [VERIFIED: `config/../Gemfile:36`] | Validação de byte-size / content-type | Já usado no `Arte`. Não mexer no `Arte` nesta fase (teto de 16 MB da Divulgação é fase 28). |
| `kamal` | `2.11.0` instalado, `require: false`, **unwired-mas-scaffolded** [VERIFIED: Gemfile.lock → `kamal (2.11.0)`; `config/deploy.yml` e `.kamal/secrets` existem] | Deploy alternativo | **Ver "Open Questions" Q1** — o repo tem `config/deploy.yml` (Kamal, esqueleto) **e** `docker-compose.yml` (hand-rolled). D-10 escolheu `docker compose`. Confirmar no início do planning. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `faraday` | `Net::HTTP` (stdlib, zero gems) | Não reduz o número de gems — troca `faraday` por `webmock` para testar o client sem disparar mensagens reais, e re-especifica os 3 timeouts em cada call site. [CITED: STACK.md §1] |
| `faraday` | `httparty` / `httpx` / `http.rb` / `rest-client` / `typhoeus` | HTTParty pior testabilidade; rest-client sem manutenção desde 2019; typhoeus precisa de libcurl no SO; httpx resolve concorrência que o solid_queue já dá. [CITED: STACK.md "What NOT to Use"] |
| `faraday-retry` | ActiveJob `retry_on` (fase 29) | `faraday-retry` faz `sleep` **dentro da worker thread**; `queue.yml` tem só **3 threads**. Retry pertence ao job, não ao middleware. **Não adicionar `faraday-retry` nesta fase.** [CITED: STACK.md §1] |
| `docker compose` hand-rolled | Kamal (já scaffolded no repo) | Kamal já tem `config/deploy.yml` com role `job:` comentada e `SOLID_QUEUE_IN_PUMA`; `docker compose` é mais explícito e é o que o usuário disse usar. Decisão de planning (Q1). |
| Presigned URL | base64 no campo `media` | base64 elimina expiração/alcançabilidade mas +33% de payload; ruim para vídeo. Manter como branch documentado no `MediaResolver` (fase 29), não como padrão. [CITED: STACK.md §6, ARCHITECTURE.md §6] |

**Installation:**
```ruby
# Gemfile — ADD
gem "faraday", "~> 2.14"                       # cliente HTTP do Evolution::Client (EVO-02)
gem "aws-sdk-s3", "~> 1.229", require: false   # ActiveStorage S3/MinIO (INFRA-01)

# Gemfile — REMOVE (linha 35)
# gem "good_job", "~> 4.0"                     # órfão, zero refs — INFRA-05
```
```bash
bundle install
# delta: +faraday +faraday-net_http +aws-sdk-s3 (+aws-sdk-core/aws-sigv4/aws-partitions) ; -good_job -fugit
```

**Version verification (executada neste research, 2026-08-29):**
- `gem list -r -e faraday` → `faraday (2.14.3)` — usar `~> 2.14`
- `gem list -r -e aws-sdk-s3` → `aws-sdk-s3 (1.229.0)` — usar `~> 1.229`
- `gem list -r -e solid_queue` → `solid_queue (1.7.0)` disponível; **manter a `1.4.0` instalada** (upgrade fora de escopo)

## Package Legitimacy Audit

> O seam `gsd-tools query package-legitimacy check` não suporta o ecossistema `rubygems` (só npm/pypi/crates). Verificação feita direto via `gem list -r` (rubygems.org) + constraint declarada pelo próprio Rails 8.1.3 + presença histórica.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `faraday` | rubygems.org | ~13 anos | >1.2 bi total (STACK.md) | github.com/lostisland/faraday | OK | Approved — gem canônica de client HTTP para service objects Rails. Versão confirmada via `gem list -r`. |
| `aws-sdk-s3` | rubygems.org | ~10 anos | dezenas de M/mês | github.com/aws/aws-sdk-ruby | OK | Approved — dependência que o próprio ActiveStorage declara (`~> 1.48`). Versão confirmada via `gem list -r`. |
| `good_job` | rubygems.org | — | — | github.com/bensheldon/good_job | OK (legítima) | **REMOVED do bundle** — não por ser suspeita, mas por ser órfã (INFRA-05). Dois adapters no bundle fazem um typo de `queue_adapter` falhar em silêncio. |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none. `faraday` e `aws-sdk-s3` são gems de primeira linha, verificadas contra o rubygems.org nesta sessão e corroboradas por fonte autoritativa (a constraint que o Rails 8.1.3 declara para `aws-sdk-s3`; o uso ubíquo de `faraday` em service objects). Não é necessário `checkpoint:human-verify` antes de instalar.

## Architecture Patterns

### System Architecture Diagram

```
                       ┌─────────────────────────────────────────────────┐
   admin/jobs do app ─▶│  Evolution::Client  (PORO, app/services/…)       │
   (nada mais fala HTTP)│  • Faraday::Connection única                     │
                       │  • header apikey: <global | token da instância>  │
                       │  • open 5s / write 10s / read 30s (15s leituras) │
                       │  • raise Evolution::Errors::{Transient,Permanent, │
                       │    Unknown,NotConnected} — nunca Faraday::Error   │
                       └───────────────┬─────────────────────────────────┘
                                       │ HTTPS (Cloudflare na frente)
                                       ▼
              ┌────────────────────────────────────────────────┐
              │  whatsapp.bomcustoilhabela.com.br  (Evolution   │
              │  API v2.3.7, Express, atrás de Cloudflare)      │
              └───────────────┬────────────────────────────────┘
                              │ baixa a mídia por URL (server-side)
                              ▼
              ┌────────────────────────────────────────────────┐
              │  s3.bomcustoilhabela.com.br  (MinIO, TLS,       │
              │  bucket privado por ambiente, presigned GET)    │
              └───────────────▲────────────────────────────────┘
                              │ blob.url(expires_in: ~15min)  ← mint no job de envio (fase 29)
              ┌───────────────┴────────────────────────────────┐
              │  App Rails 8.1.3 (Docker no mesmo host)         │
              │  ┌───────────┐   ┌───────────┐   ┌───────────┐  │
              │  │ web (Puma)│   │ jobs      │   │ reverse   │  │
              │  │           │   │ (bin/jobs │   │ proxy TLS │  │
              │  │           │   │  solid_q) │   │           │  │
              │  └─────┬─────┘   └─────┬─────┘   └───────────┘  │
              │        └─────┬─────────┘                        │
              │        Postgres (primary + queue db)            │
              │        TZ=America/Sao_Paulo (verificado no boot)│
              └────────────────────────────────────────────────┘
```

Fluxo de leitura (verificado neste research): `Evolution::Client.connection_state` → `GET /instance/connectionState/{name}` com header `apikey` → `{instance:{state:"open"|"connecting"|"close"}}`. Sem `apikey` ou com `Authorization: Bearer` → `HTTP 401 {"status":401,"error":"Unauthorized","response":{"message":"Unauthorized"}}`.

### Recommended Project Structure

```
app/services/
├── evolution/
│   ├── client.rb          # Evolution::Client — a única costura HTTP (EVO-02)
│   └── errors.rb          # Evolution::Errors::{ConfigurationError,Transient,Permanent,Unknown,NotConnected} (EVO-03)
config/initializers/
├── evolution.rb           # base_url + apikey global + timeouts (ENV || credentials); fail-fast no boot
└── timezone_check.rb      # INFRA-03 — raise em produção / warn em dev se TZ/Time.zone divergirem
lib/tasks/
└── storage_migration.rake # INFRA-01 D-05 — migra os 13 blobs locais para o MinIO, idempotente
config/storage.yml         # + serviço `amazon` (MinIO: endpoint + force_path_style)
config/environments/
├── development.rb          # + queue_adapter = :solid_queue ; service = :amazon
└── production.rb           # service :local→:amazon ; force_ssl ; hosts ; (assume_ssl)
Procfile.dev                # + linha `jobs: bin/jobs`
docker-compose.yml          # + serviço `jobs` ; + reverse proxy ; TZ no env
```

> **Namespace:** ARCHITECTURE.md alterna entre `Evolution::Client` e `Whatsapp::EvolutionClient` (`app/services/whatsapp/`). CONTEXT.md `<canonical_refs>` e o roadmap usam **`Evolution::Client`**. **Recomendação: `Evolution::Client` + `Evolution::Errors` em `app/services/evolution/`** — mais curto, e o namespace `Whatsapp::` fica livre para os serviços de domínio das fases 26–30 (`Whatsapp::InstanceProvisioner` etc.). Decisão do planner; o importante é escolher **um** e as fases seguintes seguirem.

### Pattern 1: Queue adapter explícito em development + schema de fila carregado (INFRA-02)

**What:** `development.rb` hoje **não** define `config.active_job.queue_adapter` → ActiveJob cai no default `:async` (thread pool in-process). `wait_until` funciona, mas **todo job agendado se perde ao reiniciar `bin/dev`**. UAT de "agendei para amanhã às 9h" é impossível.

**When to use:** sempre — é defeito pré-existente que BLOQUEIA o UAT de agendamento de todo o milestone.

**Example:**
```ruby
# config/environments/development.rb  — ADD (perto da linha 32, junto do active_storage)
config.active_job.queue_adapter = :solid_queue
```
```ruby
# config/database.yml — hoje development tem UMA base só (calendario_livia_development),
# SEM bloco `queue:`. production tem primary+cache+queue+cable.
# config.solid_queue.connects_to é production-only (production.rb:54) → em dev o solid_queue
# usa a conexão primária. As tabelas de db/queue_schema.rb precisam existir na base de dev.
```
```bash
# carregar o schema de fila na base de development (uma vez):
bin/rails runner "load Rails.root.join('db/queue_schema.rb')"
#   — ou —
bin/rails db:schema:load:queue   # se o multi-db de dev for configurado; ver Open Questions Q2
```
```procfile
# Procfile.dev — ADD
jobs: bin/jobs
```

**Verificação:** enfileirar `SomeJob.set(wait: 3.minutes).perform_later`, reiniciar `bin/dev`, confirmar que o job ainda dispara. [VERIFIED: `config/environments/development.rb:1-78` — nenhuma linha `queue_adapter`; `config/queue.yml` — `threads: 3, processes: 1, queues: "*"`; `config/database.yml` — bloco `development:` só com `database: calendario_livia_development`]

### Pattern 2: `Evolution::Client` PORO — espelhar `Api::JwtService` (EVO-02)

**What:** PORO com métodos de classe, resolução de segredo `ENV.fetch { credentials }`, uma `Faraday::Connection` memoizada com `base_url` + header `apikey` + 3 timeouts explícitos. Nenhuma `Faraday::Error` escapa — tudo vira `Evolution::Errors::*`.

**When to use:** toda comunicação com o Evolution, nas fases 25–30.

**Example (esqueleto — valores de config/timeouts verificados; adaptar assinaturas na fase 26):**
```ruby
# config/initializers/evolution.rb
module Evolution
  # espelha Api::JwtService.secret: ENV primeiro, credentials como fallback, raise se nenhum
  def self.base_url
    ENV.fetch("EVOLUTION_BASE_URL") { Rails.application.credentials.dig(:evolution, :base_url) } ||
      raise("EVOLUTION_BASE_URL não configurado")
  end

  def self.global_api_key
    ENV.fetch("EVOLUTION_GLOBAL_API_KEY") { Rails.application.credentials.dig(:evolution, :global_api_key) } ||
      raise("EVOLUTION_GLOBAL_API_KEY não configurado")
  end

  OPEN_TIMEOUT  = Integer(ENV.fetch("EVOLUTION_OPEN_TIMEOUT",  "5"))
  WRITE_TIMEOUT = Integer(ENV.fetch("EVOLUTION_WRITE_TIMEOUT", "10"))
  READ_TIMEOUT  = Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT",  "30"))  # sendMedia baixa a URL antes de responder
  READ_TIMEOUT_FAST = 15  # connectionState / fetchAllGroups / fetchInstances
end
```
```ruby
# app/services/evolution/client.rb
module Evolution
  class Client
    def self.connection
      @connection ||= Faraday.new(url: Evolution.base_url) do |f|
        f.request  :json
        f.response :json, content_type: /\bjson$/
        f.headers["apikey"] = Evolution.global_api_key   # NUNCA Authorization: Bearer (verificado → 401)
        f.options.open_timeout  = Evolution::OPEN_TIMEOUT
        f.options.write_timeout = Evolution::WRITE_TIMEOUT
        f.options.read_timeout  = Evolution::READ_TIMEOUT
        f.adapter Faraday.default_adapter
      end
    end

    # leitura: apikey global OU token da instância no path com :instanceName
    def self.connection_state(instance_name, api_key: Evolution.global_api_key)
      resp = request(:get, "/instance/connectionState/#{instance_name}",
                     api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST)
      resp.body.dig("instance", "state")   # "open" | "connecting" | "close"
    end

    def self.request(method, path, api_key:, body: nil, read_timeout: nil)
      resp = connection.public_send(method, path) do |req|
        req.headers["apikey"] = api_key
        req.options.timeout = read_timeout if read_timeout
        req.body = body if body
      end
      raise_for_status!(resp)
      resp
    rescue Faraday::TimeoutError => e
      # OpenTimeout (nada enviado) → Transient ; ReadTimeout (pode ter processado) → Unknown
      raise classify_timeout(e)
    rescue Faraday::ConnectionFailed => e
      raise Evolution::Errors::Transient, e.message
    end

    def self.raise_for_status!(resp)
      return if resp.success?
      # envelope verificado: {status, error, response:{message: String | Array}}
      msg = Array(resp.body.is_a?(Hash) ? resp.body.dig("response", "message") : resp.body).join(" ")
      case resp.status
      when 401, 403 then raise Evolution::Errors::Permanent, "#{resp.status} #{msg}"
      when 400, 404, 422 then raise Evolution::Errors::Permanent, "#{resp.status} #{msg}"
      when 408, 429, 500..599 then raise Evolution::Errors::Transient, "#{resp.status} #{msg}"
      else raise Evolution::Errors::Unknown, "#{resp.status} #{msg}"
      end
    end
  end
end
```

**Verificado empiricamente (2026-08-29, ver evolution-contract.md):** header `apikey` é o único esquema (`Authorization: Bearer` → 401); envelope de erro `{"status":401,"error":"Unauthorized","response":{"message":"Unauthorized"}}` (string) vs `404` `{"...":["Cannot GET /..."]}` (array) — o parser **tem** que aceitar os dois. Cloudflare na frente impõe teto de ~100 s. [VERIFIED: probe curl contra `https://whatsapp.bomcustoilhabela.com.br` — ver `.planning/notes/evolution-contract.md`] · [CITED: `app/services/api/jwt_service.rb:30-34` para o padrão `credentials || ENV.fetch`]

### Pattern 3: Taxonomia de erro — módulo `Errors` aninhado (EVO-03)

**What:** espelhar o `module Api::Errors` de `jwt_service.rb` (`class X < StandardError; end` aninhadas). Quatro classes obrigatórias + uma de config.

**Example:**
```ruby
# app/services/evolution/errors.rb
module Evolution
  module Errors
    class ConfigurationError < StandardError; end   # base_url/apikey ausente — falha no boot
    class Transient    < StandardError; end   # timeout de conexão, 5xx, ECONNREFUSED, corpo 5xx não-JSON da CF → retry seguro (fase 29)
    class Permanent    < StandardError; end   # 401/403 (credencial), 400/404/422 (payload) → retry não conserta
    class Unknown      < StandardError; end   # Net::ReadTimeout / reset no meio da resposta → PODE ter enviado; NUNCA retry automático
    class NotConnected < StandardError; end   # connectionState != "open" → precisa de novo QR (fase 26)
  end
end
```

| Situação | Classe | Tratamento a jusante (fases 26+) |
|----------|--------|--------------------------------|
| Falha de rede / `Net::OpenTimeout` / `ECONNREFUSED` / `SocketError` / 5xx | `Transient` | `retry_on` com backoff (fase 29) |
| Timeout de leitura (`Net::ReadTimeout`) | `Unknown` | `discard_on` + estado `incerto`, revisão humana (fase 29) |
| Credencial inválida (401/403), payload inválido (400/404/422) | `Permanent` | `discard_on`, falha visível |
| Instância não `open` | `NotConnected` | não envia; marca `pendente_reconexao` (fase 29) |

[CITED: `app/services/api/jwt_service.rb:3-7` (`module Errors` aninhado); .planning/research/ARCHITECTURE.md §2, §4]

### Pattern 4: Verificação de `TZ` no boot (INFRA-03)

**What:** `config.active_record.default_timezone = :local` está **mantido** (verificado `config/application.rb:25`; migrar para `:utc` é Out of Scope). Isso só é seguro se o SO tiver `TZ` fixo. Initializer que compara o fuso efetivo com o esperado e **falha alto em produção**, avisa em development.

**Discrição de Claude resolvida:** **fail-hard (raise) em produção, warn em development.** Justificativa: em produção um `TZ` errado publica posts na hora errada de forma irreversível — falhar no boot é infinitamente mais barato que descobrir no disparo. Em dev, o desenvolvedor pode legitimamente estar noutro fuso e não deve ser bloqueado.

**Example:**
```ruby
# config/initializers/timezone_check.rb
expected_tz   = "America/Sao_Paulo"
expected_zone = "Brasilia"   # config.time_zone em application.rb:24

tz_ok   = ENV["TZ"] == expected_tz
zone_ok = Time.zone.name == expected_zone

unless tz_ok && zone_ok
  msg = "Timezone não determinístico: ENV['TZ']=#{ENV['TZ'].inspect} (esperado #{expected_tz.inspect}), " \
        "Time.zone=#{Time.zone.name.inspect} (esperado #{expected_zone.inspect}). " \
        "default_timezone=:local exige TZ fixo — ver INFRA-03."
  if Rails.env.production?
    raise msg
  else
    Rails.logger.warn("[timezone_check] #{msg}")
  end
end
```
```yaml
# docker-compose.yml — serviço web E serviço jobs precisam de:
environment:
  TZ: America/Sao_Paulo
```

**Verificação:** subir o container sem `TZ` → boot falha em produção com mensagem acionável. [VERIFIED: `config/application.rb:24-25` — `config.time_zone = "Brasilia"` / `config.active_record.default_timezone = :local`] · [CITED: .planning/research/PITFALLS.md Pitfall 9]

### Pattern 5: Serviço MinIO em `storage.yml` (INFRA-01)

**What:** a stanza `amazon:` já existe **comentada** em `storage.yml` (`region: us-east-1`, `bucket: your_own_bucket-<%= Rails.env %>`). Descomentar e ajustar para MinIO: `endpoint:` custom + `force_path_style: true` (MinIO não faz virtual-host buckets por default) + `bucket: <algo>-<%= Rails.env %>` (bucket por ambiente, D-03).

**Example:**
```yaml
# config/storage.yml — substitui o bloco comentado
amazon:
  service: S3
  endpoint:          <%= ENV.fetch("S3_ENDPOINT") { Rails.application.credentials.dig(:aws, :endpoint) } %>
  access_key_id:     <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region:            <%= Rails.application.credentials.dig(:aws, :region) || "us-east-1" %>
  bucket:            <%= "calendario-livia-#{Rails.env}" %>
  force_path_style:  true
  # public: false  ← default. NÃO setar true (publicaria toda arte não-divulgada na internet).
```
```ruby
# config/environments/development.rb:32 — :local → :amazon  (D-03: bucket de dev ativo no MinIO)
config.active_storage.service = :amazon
# config/environments/production.rb:25 — :local → :amazon
config.active_storage.service = :amazon
```

**Nota de expiração:** `ActiveStorage.service_urls_expire_in` default = **5 min** (STACK.md §6). **Não** subir o default global. A presigned URL do envio é gerada **dentro do job** com `expires_in: 15.minutes` explícito (D-02) — mas isso é fase 29. Nesta fase, a verificação é só "upload real + `curl -I` da URL presignada de fora da LAN retorna 200". [VERIFIED: `config/storage.yml:9-15` — stanza `amazon` comentada com `region: us-east-1`, `bucket: your_own_bucket-<%= Rails.env %>`; `config/environments/production.rb:25` — `config.active_storage.service = :local`; `config/environments/development.rb:32` — `config.active_storage.service = :local`] · [CITED: .planning/research/STACK.md §6]

### Pattern 6: Rake task idempotente de migração de blobs (INFRA-01, D-04/D-05)

**What:** `storage/` tem **21 MB, 13 arquivos** (blobs de disco local). Iterar `ActiveStorage::Blob`, para cada um: verificar se a key já existe no serviço destino (`ActiveStorage::Blob.services.fetch(:amazon).exist?(blob.key)`), pular se sim, senão `download` do serviço de origem + `upload` no destino, logar. Reexecutável sem duplicar.

**Example:**
```ruby
# lib/tasks/storage_migration.rake
namespace :storage do
  desc "Migra blobs do Disk local para o serviço :amazon (MinIO). Idempotente."
  task migrate_to_s3: :environment do
    source = ActiveStorage::Blob.services.fetch(:local)
    dest   = ActiveStorage::Blob.services.fetch(:amazon)
    ActiveStorage::Blob.find_each do |blob|
      if dest.exist?(blob.key)
        Rails.logger.info("[storage:migrate] skip #{blob.key} (já existe no destino)")
        next
      end
      unless source.exist?(blob.key)
        Rails.logger.warn("[storage:migrate] MISSING na origem: #{blob.key} (blob ##{blob.id})")
        next
      end
      dest.upload(blob.key, StringIO.new(source.download(blob.key)),
                  checksum: blob.checksum, content_type: blob.content_type)
      Rails.logger.info("[storage:migrate] copiado #{blob.key} (#{blob.byte_size} bytes)")
    end
  end
end
```

**Rodada manualmente no deploy**, depois de `config.active_storage.service = :amazon` estar ativo e antes de o app servir tráfego. Verificação: contar blobs no bucket = 13; abrir uma arte antiga no app e confirmar que a mídia carrega. [VERIFIED: `du -sh storage` → `21M`; `find storage -type f | wc -l` → `13`] · [CITED: CONTEXT.md D-04/D-05]

### Pattern 7: Remover `good_job` (INFRA-05)

**What:** `Gemfile:35` tem `gem "good_job", "~> 4.0"`; `good_job 4.18.2` + `fugit` no lockfile. Zero referências em `config/`/`db/`/`app/`/`lib/` (STACK.md grep). O único adapter ligado é `:solid_queue`.

**When:** **commit isolado, cedo na fase, antes de qualquer código de job.** Dois adapters no bundle fazem um typo de `queue_adapter` falhar em silêncio.

**Example:**
```ruby
# Gemfile — remover a linha 35
```
```bash
bundle install   # dropa good_job + fugit
grep -rn "good_job\|GoodJob" config/ db/ app/ lib/   # deve retornar vazio (confirmar antes)
bin/rails zeitwerk:check && bin/rails runner "puts ActiveJob::Base.queue_adapter_name"  # → solid_queue
```
[VERIFIED: `Gemfile:35` — `gem "good_job", "~> 4.0"`; Gemfile.lock — `good_job (4.18.2)`; `config/environments/production.rb:53` — `config.active_job.queue_adapter = :solid_queue`] · [CITED: .planning/research/STACK.md §3]

### Anti-Patterns to Avoid

- **`Authorization: Bearer <apikey>` contra o Evolution** — verificado: retorna 401. Só o header `apikey:`.
- **Subir `ActiveStorage.service_urls_expire_in` global** para resolver expiração — enfraquece toda URL do app. Presigned `expires_in:` explícito, por chamada, dentro do job (fase 29).
- **`public: true` no serviço S3** — publica toda arte não-divulgada na internet permanentemente.
- **`rails_blob_url` como `media`** para o Evolution — roteia tráfego de terceiro pelo Rails, exige o app público, depende de o fetcher seguir redirect. Usar `blob.url(expires_in:)` (presigned direto). [CITED: STACK.md §6]
- **Migrar `default_timezone` para `:utc`** nesta fase — Out of Scope; INFRA-03 resolve fixando `TZ`.
- **Adicionar `faraday-retry`** — retry pertence ao `retry_on` do job (fase 29); `sleep` em worker thread com só 3 threads.
- **Persistir/logar `apikey`, `hash`, QR base64** — `filter_parameters` corrigido é INFRA-04 (fase 26), mas o `Evolution::Client` desta fase **já loga requests**: logar só método, path, status, duração — nunca corpo cru nem headers.
- **`read_timeout` > ~100 s** — a Cloudflare na frente do Evolution corta antes; valor alto é ilusão.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stub de HTTP em teste | Mock manual de `Net::HTTP` / gravar cassettes | `Faraday::Adapter::Test` (vem no `faraday`) | Repo não tem WebMock/VCR; o adapter de teste é in-process e sem arquivos. |
| Presigned URL de S3/MinIO | Assinar SigV4 na mão | `blob.url(expires_in:)` → `S3Service#private_url` | Rails já faz `object.presigned_url(:get, expires_in:, response_content_type:, response_content_disposition:)`. |
| Agendamento durável | Loop com `sleep` / `whenever` / cron / `sidekiq-scheduler` | `solid_queue` + `set(wait_until:)` (já instalado) | `enqueue_at` grava linha durável com `scheduled_at`; sobrevive a deploy/restart. |
| Renderização de QR | `rqrcode` / `chunky_png` | O `qrcode.base64` que o próprio Evolution devolve (data-URI PNG completo) | `image_tag @qr[:base64]` direto (fase 26). |
| Retry de HTTP | `faraday-retry` | `ActiveJob.retry_on` (fase 29) | Backoff durável, não-bloqueante, restart-safe; só 3 worker threads. |
| Config multi-secret | Reinventar precedência ENV/credentials | `ENV.fetch("X") { Rails.application.credentials.dig(...) }` | Precedente do projeto: `Api::JwtService.secret`. |

**Key insight:** quase tudo que esta fase precisa já está no Rails 8.1.3 / solid_queue / ActiveStorage. As únicas peças novas são o transporte HTTP (`faraday`) e o driver S3 (`aws-sdk-s3`). O risco não é de biblioteca — é de **integração**: URL alcançável de fora da LAN, `TZ` fixo, schema de fila carregado em dev, e o contrato real do Evolution.

## Runtime State Inventory

> Fase de infra + deploy com uma migração de dados (blobs). Categorias abaixo respondidas explicitamente.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | **13 blobs do ActiveStorage em `storage/` (21 MB)** ligados a artes existentes. Metadados (`active_storage_blobs.key`, `.service_name`) no Postgres primário. | **Migração de dados** (rake task idempotente, D-05) — copiar os 13 objetos para o bucket MinIO. `active_storage_blobs.service_name` continua resolvendo pelo nome do serviço (`:local`→`:amazon`); Rails resolve o serviço corrente pela config de ambiente, não pela coluna, **exceto** se a coluna estiver populada — verificar: se `service_name` estiver gravado como `"local"` nas linhas antigas, a migração precisa `UPDATE active_storage_blobs SET service_name = 'amazon'` também. (Confirmar na fase — ver Open Questions Q3.) |
| **Live service config** | **Host Evolution `whatsapp.bomcustoilhabela.com.br`** — config vive no manager do Evolution (fora do git). Instâncias/webhooks são criados nas fases 26+, não aqui. **MinIO** — buckets, policy privada, subdomínio TLS: config do host, fora do git. | Provisionar MinIO no host (bucket por ambiente, TLS no subdomínio, policy privada). Documentar no runbook de deploy. Nada de instância Evolution nesta fase (D-12). |
| **OS-registered state** | **`TZ` do SO / container.** Hoje o app roda em `192.168.3.203` com `TZ` implícito do host. Nenhum systemd/cron/Task Scheduler referenciando strings desta fase. | Fixar `TZ=America/Sao_Paulo` no `environment:` dos serviços `web` **e** `jobs` do `docker-compose.yml`. Boot check (Pattern 4) transforma esquecimento em erro visível. |
| **Secrets/env vars** | **Novos:** `EVOLUTION_BASE_URL`, `EVOLUTION_GLOBAL_API_KEY`, `S3_ENDPOINT`, `aws.access_key_id`, `aws.secret_access_key`, `aws.region`, `aws.bucket`/`aws.endpoint` (credentials). `RAILS_MASTER_KEY` já em uso (`.kamal/secrets` → `cat config/master.key`; `docker-compose.yml` → `${RAILS_MASTER_KEY}`). Credentials é **um arquivo único** `config/credentials.yml.enc` (não há `config/credentials/production.yml.enc`). | Adicionar `evolution:` e `aws:` ao `config/credentials.yml.enc` (`bin/rails credentials:edit`). `.env`/`.env.example` (dev/test) ganham `EVOLUTION_*` e `S3_ENDPOINT`. `dotenv-rails` é dev/test only (`Gemfile:55`) — **não mover para produção**. |
| **Build artifacts / installed packages** | `good_job 4.18.2` + `fugit` instalados, ligados a nada. `vendor/bundle` (o repo faz `COPY vendor/* ./vendor/` no Dockerfile). `.bundle/` config. | `bundle install` após editar o Gemfile regenera `Gemfile.lock` (–good_job –fugit, +faraday +aws-sdk-s3 +deps). A imagem Docker rebuilda gems no stage `build`. Nenhum egg-info/binário compilado a limpar. |

**Nada encontrado em:** integrações OS-registradas (systemd/cron/pm2/launchd) referenciando strings desta fase — verificado: não há unidades systemd no repo; `config/recurring.yml` só tem `clear_solid_queue_finished_jobs` em `production:` (não referencia nada renomeado).

## Common Pitfalls

### Pitfall 1: URL de mídia inalcançável pelo host do Evolution (INFRA-01 — o bloqueio real)

**What goes wrong:** o job de envio (fase 29) monta `media: <url>` e o Evolution responde erro ou manda arquivo quebrado, porque **quem baixa a URL é o container do Evolution**, não o Rails. Uma URL de `192.168.3.203`, `localhost`, ou um Disk-service `/rails/active_storage/disk/...` é inalcançável de fora da LAN.
**Why it happens:** `production.rb:25` e `development.rb:32` = `service: :local`; `storage.yml` só define `test` e `local` (Disk). O modelo mental "funcionou no meu teste manual" esconde que o teste foi do laptop, não do host do Evolution.
**How to avoid:** MinIO sob subdomínio TLS próprio, **alcançável da internet pública** (D-01), bucket privado, presigned GET. **Verificação obrigatória desta fase:** upload real → pegar a presigned URL → `curl -I <url>` **de uma máquina fora de `192.168.3.203`** (ou `docker exec` no container do Evolution) → tem que retornar `200` com o `content-type` certo.
**Warning signs:** a URL contém `192.168.`/`localhost`/`:8080`; bucket com policy VPC-only ou IP-allowlist; funciona imediato e falha agendado (URL assinada expira — mas isso é fase 29).

### Pitfall 2: Schema de fila não carregado na base de development (INFRA-02)

**What goes wrong:** setar `queue_adapter = :solid_queue` em `development.rb` **sem** carregar `db/queue_schema.rb` na base de dev → `PG::UndefinedTable: solid_queue_jobs` no primeiro `perform_later`.
**Why it happens:** `config.solid_queue.connects_to` é production-only (`production.rb:54`); em produção há uma base `queue` dedicada (`calendario_livia_production_queue`) com `migrations_paths: db/queue_migrate`. Em development há **uma base só** — as tabelas de fila têm que morar na base primária de dev.
**How to avoid:** rodar `load Rails.root.join('db/queue_schema.rb')` contra `calendario_livia_development` como passo de setup explícito (Pattern 1). Documentar no README/`bin/setup`.
**Warning signs:** `bin/jobs` sobe e morre com erro de tabela; `perform_later` levanta `UndefinedTable`.

### Pitfall 3: `TZ` divergente entre dev e produção com `default_timezone = :local` (INFRA-03)

**What goes wrong:** o mesmo `datetime` no banco significa horas diferentes em máquinas com `TZ` diferente. Containers rodam UTC por default; a Divulgação (fase 28) reintroduz o `datetime` que a v1.0 evitou. Post agendado para 18:00 sai às 21:00.
**Why it happens:** `config.active_record.default_timezone = :local` (`application.rb:25`) faz o AR ler/gravar timestamps no fuso do SO. `solid_queue_scheduled_executions.scheduled_at` herda essa semântica.
**How to avoid:** `TZ=America/Sao_Paulo` no env dos containers `web` e `jobs` + o boot check (Pattern 4) que **raise em produção**. Horário de verão brasileiro está suspenso desde 2019 — isso **mascara** o bug até uma troca de `TZ` do host revelar tudo de uma vez.
**Warning signs:** `Time.parse`/`DateTime.parse` em vez de `Time.zone.parse` (relevante na fase 28); diferença de 3h entre esperado e real.

### Pitfall 4: Contrato do Evolution assumido em vez de verificado (EVO-01)

**What goes wrong:** escrever o client contra os DTOs do `main` (linha 2.4.0-rc) quando o host roda outra versão → 100% dos payloads de envio quebram com 400.
**Why it happens:** a doc pública do Evolution retorna 404; a pesquisa leu o código-fonte no tag `2.3.7` e no `main`.
**How to avoid:** **já mitigado neste research** — probe real confirmou host = `2.3.7`, o mesmo tag da pesquisa. O que resta PENDENTE (send, webhook casing, teto de mídia) está rastreado em `evolution-contract.md` com a fase de UAT. O planner **não** deve deixar código da fase 26+ depender de um item PENDENTE sem o UAT correspondente.
**Warning signs:** um plano da fase 26 que codifica o casing de `QRCODE_UPDATED` como fato; um teste de `sendMedia` que assume o shape da resposta sem UAT.

### Pitfall 5: `docker compose` de produção sem serviço de jobs / sem proxy TLS (D-09/D-10)

**What goes wrong:** o `docker-compose.yml` atual tem só `db` + `web` (porta `5881:3000`, volume `storage:/rails/storage` de Disk local). Sem serviço `jobs`, **nenhum job agendado dispara em produção** (o `SOLID_QUEUE_IN_PUMA` está no `config/deploy.yml` do Kamal, não no compose). Sem proxy TLS, o webhook da fase 26 e o `force_ssl` não têm terminação.
**Why it happens:** o compose foi gerado como skeleton; o deploy real do milestone é escopo novo (D-09).
**How to avoid:** adicionar serviço `jobs` (`build: .`, `command: ./bin/jobs`, mesmo env do `web` incl. `TZ` e `RAILS_MASTER_KEY`, `depends_on: db`), um reverse proxy (Caddy/nginx/Traefik) terminando TLS para o app e para o subdomínio do MinIO, e `config.assume_ssl = true` + `config.force_ssl = true` + `config.hosts` em `production.rb`. Nota: o volume `storage:` do Disk deixa de ser o storage primário (vira MinIO) mas pode ser mantido como fonte da migração.
**Warning signs:** `docker compose ps` sem container de jobs; `curl https://<app>` sem cadeia TLS; `production.rb` com `force_ssl`/`hosts` ainda comentados (linhas 31 e 83).

### Pitfall 6: `service_name` das linhas de blob antigas travado em `"local"` (INFRA-01)

**What goes wrong:** depois de trocar a config para `:amazon`, artes antigas continuam servindo (ou falhando) pelo Disk porque `active_storage_blobs.service_name` foi persistido como `"local"` em linhas antigas — o Rails respeita a coluna quando ela está populada.
**Why it happens:** o ActiveStorage grava `service_name` no blob quando há mais de um serviço configurado; linhas criadas quando só existia `:local` podem ter `NULL` (resolve pela config) **ou** `"local"` (trava no Disk).
**How to avoid:** a rake task de migração (Pattern 6) também faz `ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")` **depois** de copiar os objetos. Verificar o estado atual da coluna na fase (Open Questions Q3).
**Warning signs:** arte antiga com imagem quebrada no app depois da migração, mesmo com o objeto presente no bucket.

## Code Examples

### Round-trip de leitura verificado (o probe deste research)
```bash
# versão do host — sem auth
curl -sS https://whatsapp.bomcustoilhabela.com.br/
# → {"status":200,"message":"Welcome to the Evolution API, it is working!","version":"2.3.7",
#    "clientName":"evolution_exchange","manager":"http://whatsapp.bomcustoilhabela.com.br/manager",
#    "documentation":"https://doc.evolution-api.com","whatsappWebVersion":"2.3000.1046362407"}

# enforcement de auth
curl -sS -o /dev/null -w '%{http_code}\n' https://whatsapp.bomcustoilhabela.com.br/instance/fetchInstances
# → 401   body: {"status":401,"error":"Unauthorized","response":{"message":"Unauthorized"}}

# Bearer NÃO é aceito
curl -sS -w '\n%{http_code}\n' -H 'Authorization: Bearer x' https://whatsapp.bomcustoilhabela.com.br/instance/fetchInstances
# → 401 (mesmo corpo)

# shape de 404 — response.message é ARRAY aqui
curl -sS https://whatsapp.bomcustoilhabela.com.br/rota-inexistente
# → {"status":404,"error":"Not Found","response":{"message":["Cannot GET /rota-inexistente"]}}
```

### Leitura autenticada (a rodar no research/plan com a apikey global fornecida — D-06)
```bash
# lista de instâncias — fonte para "adotar instância existente" (fase 26)
curl -sS -H "apikey: $EVOLUTION_GLOBAL_API_KEY" \
  https://whatsapp.bomcustoilhabela.com.br/instance/fetchInstances | jq .

# estado de uma instância
curl -sS -H "apikey: $EVOLUTION_GLOBAL_API_KEY" \
  "https://whatsapp.bomcustoilhabela.com.br/instance/connectionState/<nome>" | jq .
```

### Verificação de alcançabilidade do storage (verificação-chave da fase)
```bash
# de FORA da LAN (não do laptop na 192.168.3.203):
curl -I "<presigned-url-gerada-pelo-app>"
# esperado: HTTP/2 200 ; content-type: image/jpeg ; content-length correto
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `good_job` como job backend | `solid_queue` (DB-backed, sem Redis) | Rails 8 (default) | `good_job` no Gemfile é órfão — remover (INFRA-05). |
| ActiveStorage Disk local | S3-compat (MinIO) com presigned URL | v1.7 / INFRA-01 | Deixou de ser conveniência: o host do Evolution baixa a mídia de fora da LAN. |
| Evolution API v1 (payloads aninhados) | v2.3.7 (payloads flat `{number, text, delay}` / `{number, mediatype, media, ...}`) | v1 EOL desde 2025-06 | Host verificado = `2.3.7`; uma integração escrita contra v1 falha com 400. |
| `atendai/evolution-api` (imagem Docker) | `evoapicloud/evolution-api` | 2025-06 (atendai parou de publicar) | Irrelevante para o app (não deployamos o Evolution), mas relevante para o runbook do host. |

**Deprecated/outdated:**
- `faraday-retry` para retry de HTTP neste contexto — o layer certo é `ActiveJob.retry_on` (3 worker threads).
- Subir `service_urls_expire_in` global — usar `expires_in:` por chamada.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Casing dos eventos de webhook do Evolution (`QRCODE_UPDATED` vs `qrcode.updated`) — **não verificado** (sem instância pareada) | evolution-contract.md PENDENTE | `WebhookProcessor` da fase 26 quebra se assumir um casing. Mitigação: aceitar os dois. Fecha em UAT fase 26. |
| A2 | `sendMedia`/`sendText` aceitam JID de grupo (`...@g.us`) em `number` neste build | evolution-contract.md PENDENTE | Se não aceitar, o motor de envio (fase 29) precisa de outra rota. `createJid.ts` @ `2.3.7` diz que sim. Fecha em UAT fase 28/29. |
| A3 | Teto real de mídia (imagem/vídeo) ~16 MB é heurística, não medido neste gateway | evolution-contract.md PENDENTE | Validação de tamanho da Divulgação (fase 28) com número errado. Medir 5/15/20/30 MB em UAT fase 28. |
| A4 | O host do Evolution consegue alcançar o app Rails para webhook depois do deploy | Pitfall 5, D-12 | Se não alcançar, o botão "Verificar conexão" (PAIR-05) vira o caminho principal. Testar em UAT fase 26. |
| A5 | A ferramenta de deploy pretendida é `docker compose` e não Kamal (que já tem `config/deploy.yml` scaffolded) ou podman/dokku | Open Questions Q1, D-10 | Retrabalho de todo o bloco de deploy. **Confirmar com o usuário no início do planning.** |
| A6 | MinIO será provisionado no host pelo usuário (bucket por ambiente, TLS no subdomínio, policy privada) antes/durante esta fase | Environment Availability | Sem MinIO acessível, a verificação de alcançabilidade não roda e INFRA-01 não fecha. |
| A7 | `active_storage_blobs.service_name` das 13 linhas antigas é `NULL` ou `"local"` (não outro valor) | Pitfall 6, Q3 | Migração de blobs precisa de `UPDATE` adicional; inspecionar a coluna na fase. |
| A8 | Timeouts `open 5 / write 10 / read 30` (15 nas leituras) são adequados ao host real atrás da Cloudflare | Pattern 2 | Se o host for lento, leituras podem dar `Transient` falso. Ajustável por ENV; medir na primeira leitura autenticada. |
| A9 | `db/queue_schema.rb` carrega limpo na base de development (Rails ≥ 8.1 tem a task `db:schema:load:queue` só se o multi-db de dev existir) | Pattern 1, Q2 | Setup de INFRA-02 precisa do fallback `bin/rails runner "load ..."`. |

## Open Questions

1. **Ferramenta de deploy: `docker compose` vs Kamal vs outra?**
   - What we know: `docker-compose.yml` (hand-rolled, `db`+`web`) **e** `config/deploy.yml` + `.kamal/secrets` (Kamal 2.11.0, esqueleto com role `job:` comentada e `SOLID_QUEUE_IN_PUMA: true`) **ambos existem** no repo. D-10 diz `docker compose` por interpretação de "eu uso docker para rodar aplicação".
   - What's unclear: se o usuário quer manter o compose hand-rolled (e então Kamal vira dead scaffolding a remover) ou se "docker" significava "via Kamal".
   - Recommendation: **primeira pergunta do planning.** Se compose: adicionar serviço `jobs` + proxy, e opcionalmente remover `config/deploy.yml`/`.kamal/`. Se Kamal: descomentar a role `job:`, `proxy.ssl`, `servers.web`, configurar `registry`, e o `docker-compose.yml` vira só dev/acessório.

2. **Como carregar o schema de fila na base de development?**
   - What we know: dev tem base única; `db/queue_schema.rb` existe; `config.solid_queue.connects_to` é production-only.
   - What's unclear: se `bin/rails db:schema:load:queue` funciona sem um bloco `queue:` em `database.yml[development]`, ou se precisa do `bin/rails runner "load Rails.root.join('db/queue_schema.rb')"`.
   - Recommendation: usar o `runner "load ..."` como caminho garantido; documentar em `bin/setup`/README. Testar a task nativa e preferir se funcionar.

3. **Estado atual de `active_storage_blobs.service_name` nas 13 linhas existentes?**
   - What we know: 13 blobs, serviço atual `:local`.
   - What's unclear: se a coluna está `NULL` (resolve pela config) ou `"local"` (trava no Disk).
   - Recommendation: `SELECT service_name, count(*) FROM active_storage_blobs GROUP BY 1` na fase; a rake task de migração faz o `UPDATE` condicional.

4. **`endpoint` do MinIO: um só para todos os ambientes ou um por ambiente?**
   - What we know: D-03 = bucket por ambiente (`calendario-livia-<Rails.env>`). D-01 = subdomínio `s3.bomcustoilhabela.com.br`.
   - What's unclear: se dev e produção usam o **mesmo** endpoint MinIO (buckets diferentes) ou endpoints diferentes.
   - Recommendation: mesmo endpoint, buckets separados — `S3_ENDPOINT` em `.env` (dev) e credentials (prod) apontando para o mesmo host; `bucket` derivado de `Rails.env`.

5. **A apikey global e a base URL já estão em `credentials`/`.env`?**
   - What we know: `.env`/`.env.example` não foram legíveis nesta sessão (permissão negada); `config/credentials.yml.enc` tem só `[:secret_key_base, :jwt_secret, :api]` historicamente (STACK.md).
   - What's unclear: se o usuário já colocou `EVOLUTION_*` em algum lugar.
   - Recommendation: o plano inclui a task de `bin/rails credentials:edit` (adicionar `evolution:` e `aws:`) e a atualização de `.env.example`. A leitura autenticada do contrato (D-06) roda assim que a apikey estiver disponível — se não estiver neste run, os itens de escrita já estão PENDENTE em evolution-contract.md.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Host Evolution `whatsapp.bomcustoilhabela.com.br` | EVO-01/02/03 | ✓ (probe 2026-08-29) | **API `2.3.7`**, WhatsApp Web `2.3000.1046362407`, atrás de Cloudflare | — |
| apikey global do Evolution | Leitura autenticada do contrato (D-06) | ✗ (não disponível neste run) | — | Itens de escrita já PENDENTE em evolution-contract.md → UAT 26/28 |
| Instância Evolution pareada + grupo de teste | `sendText`/`sendMedia` reais, teto de mídia (D-08) | ✗ | — | PENDENTE → UAT fase 28 |
| MinIO (S3-compat) no host, subdomínio TLS | INFRA-01 | ✗ (a provisionar pelo usuário) | — | Sem fallback — bloqueia a verificação de alcançabilidade de INFRA-01 |
| Docker + `docker compose` no host público | INFRA-01/03 deploy (D-09/D-10) | ✓ (assumido — usuário afirma usar; `Dockerfile` + `docker-compose.yml` já no repo) | — | Kamal (já scaffolded) se a premissa mudar |
| Reverse proxy TLS no host | webhook (fase 26), `force_ssl` | ✗ (a configurar) | — | Sem fallback para produção |
| Ruby 3.3.3 | build | ✓ | `.ruby-version` → `ruby-3.3.3`; Dockerfile `ARG RUBY_VERSION=3.3.3` | — |
| Postgres | app + solid_queue | ✓ | `postgres:16-alpine` no compose; `pg ~> 1.1` | — |
| `bin/rails test` (banco de teste) | verificação automatizada | ✗ | banco de teste pertence a outro usuário do SO (MEMORY.md) | Verificação por inspeção + runs pontuais de arquivos de teste isolados |

**Missing dependencies with no fallback:**
- MinIO acessível da internet — sem ele INFRA-01 não é verificável.
- Reverse proxy TLS no host — necessário para o deploy público (D-09) e para a fase 26.

**Missing dependencies with fallback:**
- apikey global / instância pareada — os itens que dependem disso já estão PENDENTE em `evolution-contract.md` apontando para UAT das fases 26/28.
- Ferramenta de deploy — `docker compose` (D-10) com Kamal já scaffolded como alternativa.

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high` (config.json).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | sim | Header `apikey` no `Evolution::Client` (global em credentials/ENV; token por instância vem na fase 26). Nunca `Authorization: Bearer` (verificado inútil). |
| V3 Session Management | não | Sem sessão nova nesta fase. |
| V4 Access Control | parcial | Bucket MinIO **privado** + presigned GET com `expires_in` curto; `public: false` no serviço S3. Nenhum objeto world-readable. |
| V5 Input Validation | parcial | Parser de erro do Evolution normaliza `response.message` string|array; corpo 5xx não-JSON (HTML da Cloudflare) tratado como `Transient`, não propagado como conteúdo. |
| V6 Cryptography | sim (delegado) | TLS fim-a-fim: app↔Evolution (HTTPS via CF), app↔MinIO (subdomínio TLS), browser↔app (reverse proxy + `force_ssl`). SigV4 da presigned URL: feito pelo `aws-sdk-s3`, não hand-rolled. `encrypts` do token por instância é fase 26 (EVO-04). |
| V7 Errors & Logging | sim | `Evolution::Client` loga só método/path/status/duração — **nunca** header `apikey`, corpo cru, `hash`, QR base64. `filter_parameters` para `:apikey`/`:hash` é INFRA-04 (fase 26), mas o log seguro no client desta fase é obrigatório desde já. |
| V14 Configuration | sim | Segredos em credentials/ENV com fail-fast no boot; `dotenv-rails` fica dev/test; `TZ` fixo verificado; `config.hosts` (anti DNS-rebinding) ativado no deploy. |

### Known Threat Patterns for {Rails 8 + Faraday + S3 + Docker}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `apikey` global vazando em log do client HTTP | Information Disclosure | Logar só metadados; `filter_parameters` (fase 26); nunca corpo/headers crus. |
| Bucket público expondo arte não-divulgada | Information Disclosure | `public: false` (default) + presigned `expires_in` curto; policy privada no MinIO. |
| Presigned URL com expiração longa demais / persistida | Information Disclosure | `expires_in: ~15min`, gerada no `perform` (fase 29); nunca serializada em argumento de job. |
| MITM app↔MinIO / app↔Evolution | Tampering / Info Disclosure | TLS obrigatório nos dois hops; `endpoint:` https no `storage.yml`. |
| DNS rebinding / Host header no app público | Spoofing | `config.hosts` com o hostname do app (linha 83 de `production.rb`, hoje comentada). |
| HTTP→HTTPS downgrade | Tampering | `config.assume_ssl = true` + `config.force_ssl = true` (linhas 28/31, comentadas). |
| Co-locação: comprometer o host derruba app+Evolution+MinIO juntos | Elevation / DoS | Risco **aceito** (D-11); separação anotada no backlog. |
| `TZ` errado → job na hora errada (não é "segurança" clássica mas é integridade) | Tampering (integridade temporal) | Boot check com raise em produção (Pattern 4). |
| Corpo de erro 5xx da Cloudflare (HTML) interpretado como resposta do Evolution | — | `raise_for_status!` trata não-JSON de 5xx como `Transient` genérico. |

## Sources

### Primary (HIGH confidence)
- **Probe HTTP real** (`curl`) contra `https://whatsapp.bomcustoilhabela.com.br`, 2026-08-29 — `GET /` (banner `version: 2.3.7`), `GET /instance/fetchInstances` (401 sem/ com Bearer / apikey inválida), `GET /rota-inexistente` (404). Registrado em `.planning/notes/evolution-contract.md`.
- **Este repositório** (inspeção direta, 2026-08-29):
  - `config/application.rb:24-25` — `time_zone = "Brasilia"`, `default_timezone = :local`
  - `config/environments/development.rb:1-78` — sem `queue_adapter`; `active_storage.service = :local` (linha 32)
  - `config/environments/production.rb` — `queue_adapter = :solid_queue` (53), `connects_to queue` (54), `active_storage.service = :local` (25), `assume_ssl`/`force_ssl`/`hosts` comentados (28/31/83)
  - `config/queue.yml` — `threads: 3`, `processes: 1`, `queues: "*"`, dispatcher `polling_interval: 1`
  - `config/database.yml` — dev base única; prod primary+cache+queue+cable
  - `config/storage.yml` — só `test`/`local` (Disk); stanza `amazon` comentada
  - `config/recurring.yml` — só `production:` → `clear_solid_queue_finished_jobs` (limpa `finished`, não `failed`)
  - `config/initializers/filter_parameter_logging.rb` — `[:passw,:email,:secret,:token,:_key,:crypt,:salt,:certificate,:otp,:ssn,:cvv,:cvc]` — **sem** `apikey`/`hash`
  - `config/initializers/rack_attack.rb` — regras para login/portal/`/api/v1/ai/`; nada para rotas novas
  - `app/services/api/jwt_service.rb` — `module Errors` aninhado; `.secret` = `credentials || ENV.fetch`
  - `app/models/arte.rb:35-41` — `validates :media_file, content_type: {...}, size: { less_than: 50.megabytes }`
  - `Gemfile:35` — `gem "good_job", "~> 4.0"`; `Gemfile:36` — `active_storage_validations`; `Gemfile:55` — `dotenv-rails` dev/test
  - `Gemfile.lock` — `solid_queue (1.4.0)`, `solid_cable (4.0.0)`, `solid_cache (1.0.10)`, `good_job (4.18.2)`, `kamal (2.11.0)`, `activestorage (8.1.3)`, `rails (8.1.3)`; sem `faraday`/`aws-sdk-s3`
  - `Dockerfile` — Rails 8 gerado, `RUBY_VERSION=3.3.3`, `BUNDLE_WITHOUT="development"`, non-root, entrypoint `db:prepare` só p/ `./bin/rails server`
  - `docker-compose.yml` — `db` (postgres:16-alpine) + `web` (`5881:3000`, volume `storage:`); **sem `jobs`, sem proxy**
  - `config/deploy.yml` + `.kamal/secrets` — Kamal 2.11.0, role `job:` comentada, `SOLID_QUEUE_IN_PUMA: true`, `proxy.ssl` comentado, `RAILS_MASTER_KEY=$(cat config/master.key)`
  - `bin/jobs` — `SolidQueue::Cli.start(ARGV)`; `Procfile.dev` — só `web` + `css`
  - `du -sh storage` → `21M`; `find storage -type f | wc -l` → `13`
  - `gem list -r -e {faraday,aws-sdk-s3,solid_queue}` → `2.14.3` / `1.229.0` / `1.7.0` (rubygems.org, 2026-08-29)
- `.planning/research/{SUMMARY,STACK,ARCHITECTURE,PITFALLS,FEATURES}.md` — contrato Evolution lido do código-fonte `evolution-foundation/evolution-api` @ tag `2.3.7` (agora casado com a versão do host)
- `.planning/{REQUIREMENTS,STATE}.md`, `.planning/phases/25-*/25-CONTEXT.md`, `.planning/notes/api-auth-strategy.md`

### Secondary (MEDIUM confidence)
- rubygems.org (via `gem list -r`) — versões de `faraday`/`aws-sdk-s3`/`solid_queue`
- [rails/solid_queue README](https://github.com/rails/solid_queue) — `enqueue_at`, `limits_concurrency`, `ProcessPrunedError` (a reconfirmar contra 1.4.0 na fase 29)

### Tertiary (LOW confidence — não planejar em cima)
- Heurísticas anti-ban (faixas de delay, warm-up) — material de vendor, sem metodologia; ver PITFALLS.md §"Qualidade da evidência"

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versões confirmadas via `gem list -r` nesta sessão; constraint do Rails 8.1.3 corrobora `aws-sdk-s3`
- Contrato Evolution (leitura): HIGH — versão do host verificada empiricamente = `2.3.7` = tag da pesquisa; auth/envelope de erro observados diretamente
- Contrato Evolution (escrita): LOW — send/webhook/teto de mídia PENDENTE, rastreado em evolution-contract.md → UAT 26/28
- Arquitetura Rails / integração: HIGH — todos os pontos de integração lidos deste repo
- Deploy (`docker compose` de produção): MEDIUM — Dockerfile/compose existem mas o compose de produção (jobs + proxy) é escopo novo; ferramenta a confirmar (Q1)
- Pitfalls: HIGH para os de codebase (inspeção direta); MEDIUM para os de rede (Cloudflare, alcançabilidade)

**Research date:** 2026-08-29
**Valid until:** 2026-09-28 (30 dias) — reprobe `GET /` do host antes de escrever o client se o planning demorar; a versão pode mudar de `2.3.7`.
