# Phase 25: Fundação — Transporte Evolution + Storage Alcançável - Context

**Gathered:** 2026-08-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Esta fase entrega a **costura de fundação** do milestone v1.7:

1. **`Evolution::Client`** — PORO como única costura HTTP com o host Evolution real da agência, com timeouts explícitos, header `apikey` e taxonomia de erro em 4 classes (transitório / permanente / incerto / não-conectado). Nenhuma exceção crua de HTTP escapa dele.
2. **Storage alcançável** — ActiveStorage servido por MinIO (S3-compatível) numa URL que o host público do Evolution baixa de fora da LAN.
3. **Jobs confiáveis em development** — queue adapter explícito + `db/queue_schema.rb` carregado + worker rodando, para viabilizar UAT de agendamento.
4. **Timezone determinístico** — `TZ` travado no deploy + verificação no boot.
5. **Um único adapter de fila** — `good_job` removido do Gemfile.
6. **Verificação empírica do contrato Evolution** contra o host real (`whatsapp.bomcustoilhabela.com.br`) — os 8 itens ASSUMIDOS em `SUMMARY.md`. Isto é `--research-phase`, não implementação.

**Ampliação de escopo decidida nesta discussão:** a parte "+ Deploy" do milestone
foi ancorada aqui — o app Rails **é deployado num host público nesta fase** (ver
D-09..D-12). Isso vai além do enunciado original da fase 25 no ROADMAP
("transporte + storage + jobs"). O planner e uma eventual revisão do roadmap
precisam contabilizar esse trabalho adicional de deploy.

</domain>

<decisions>
## Implementation Decisions

### Storage / MinIO (INFRA-01)

- **D-01:** Provedor de object storage = **MinIO self-hosted**, acessado via `aws-sdk-s3` com `endpoint:` custom, rodando **no mesmo host público do Evolution** (`whatsapp.bomcustoilhabela.com.br`), exposto sob subdomínio próprio (ex: `s3.bomcustoilhabela.com.br`) com TLS. A alcançabilidade pelo host do Evolution passa a ser estrutural — não depende de o app estar público. — **Reversibility:** costly — trocar de provedor depois exige re-upload de todos os blobs e rotação de `storage.yml` + credentials; ActiveStorage abstrai os call sites, mas a migração de dados é manual.
- **D-02:** URLs de mídia servidas **presignadas, bucket privado**; a URL presignada é gerada **dentro do `perform` do job de envio**, com `expires_in` explícito cobrindo o disparo inteiro (pesquisa sugere ~15 min por chamada). Nenhum objeto permanentemente público. Endereça `PITFALLS.md` Pitfall 4 (URL expirada / inalcançável). — *Discrição de Claude — usuário disse "você decide", seguindo a recomendação da pesquisa.*
- **D-03:** **Bucket por ambiente** (`bucket-<Rails.env>`, o padrão da stanza `amazon:` comentada em `storage.yml`), com **bucket de development ativo no MinIO** para exercitar o caminho presignado localmente. `development.rb` passa de `service: :local` para o serviço MinIO. — *Discrição de Claude.*

### Migração de blobs locais (INFRA-01)

- **D-04:** **Migrar todos os anexos locais existentes** (~21 MB, ~13 arquivos em `storage/`) para o MinIO. Nenhuma arte perde arquivo.
- **D-05:** Entregue como **rake task idempotente** em `lib/tasks/` — itera os blobs, pula os que já existem no destino, loga o resultado; rodada manualmente no deploy; reexecutável sem duplicar. — *Discrição de Claude.*

### Verificação empírica do contrato Evolution (EVO-01)

- **D-06:** O usuário fornece **base URL + apikey global** (canal seguro / credentials); Claude monta e roda o probe contra o **host real da agência** durante o research da fase 25. Este round-trip é a tarefa que destrava o milestone — nenhum código depende do contrato até ele estar registrado por escrito.
- **D-07:** O contrato verificado é registrado em **`.planning/notes/evolution-contract.md`** como fonte canônica (no estilo de `.planning/notes/api-auth-strategy.md`), servindo as fases 25–30; referenciado no CONTEXT.md e no `25-RESEARCH.md`. — *Discrição de Claude.* — **Reversibility:** reversible.
- **D-08:** O probe tenta um **`sendText` + `sendMedia` reais a um grupo de teste** e mede o teto de mídia com arquivos de 5/15/20/30 MB, se houver instância pareada + grupo de teste disponível. O que não fechar vira **item pendente rastreado em `evolution-contract.md`**, nomeando a fase onde será medido (UAT da 26/28). — *Discrição de Claude.*

### Escopo de produção / deploy (INFRA-01, INFRA-03)

- **D-09:** **O app Rails é deployado num host público nesta fase** — não só o MinIO. É a porção "+ Deploy" do milestone ancorada na fase 25. Amplia a fase além do enunciado do ROADMAP; ver nota em `<domain>`. — **Reversibility:** costly — estabelece a infra de produção que as fases seguintes vão assumir (webhook na 26, envio real na 29).
- **D-10:** Ferramenta de deploy = **Docker** (Dockerfile + `docker compose` no host, deploy por `git pull` + rebuild), com o **worker `bin/jobs` do solid_queue como serviço próprio no compose**, e TLS por reverse proxy no host. — *Interpretação da resposta livre do usuário ("eu uso [docker] para rodar aplicação"); confirmar no início do planning se a ferramenta pretendida era outra (podman / dokku).*
- **D-11:** O app roda no **mesmo servidor** que Evolution + MinIO. O risco de co-locação (ban de cliente ou queda do host derruba tudo junto) é **risco aceito conscientemente**, com a separação app / Evolution anotada como candidato a hardening no backlog — sem bloquear nada. — *Discrição de Claude.*
- **D-12:** O receiver de webhook permanece na **fase 26** como o ROADMAP prevê; a fase 25 apenas confirma **alcance app ↔ Evolution nos dois sentidos** como parte da verificação de deploy. — *Discrição de Claude.*

### Claude's Discretion

Além dos itens marcados acima, o usuário deixou explicitamente a critério de Claude / do researcher:

- Valores exatos de open/read/write timeout do `Evolution::Client`.
- Fail-hard (raise no boot) vs. warn para a verificação de `TZ` (INFRA-03).
- Se a fila `whatsapp` dedicada nasce agora ou só na fase 29 (o ROADMAP coloca INFRA-06 na 29 — default é seguir o ROADMAP).
- Split `credentials` vs `ENV` para a apikey global (precedente do projeto: `credentials || ENV.fetch`, ver `app/services/api/jwt_service.rb`).
- Shape das classes da taxonomia de erro — espelhar o módulo aninhado `Api::Errors` de `jwt_service.rb`.
- Estratégia da migração para S3 dos blobs (default: rake task idempotente, D-05).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pesquisa do milestone (fonte primária de contrato e armadilhas)
- `.planning/research/SUMMARY.md` — ordem de build reconciliada (passos A–G, restrição dura 25→30), seção "VERIFICADO vs. ASSUMIDO" com os 8 itens a confirmar no passo A, tabela de defeitos pré-existentes do codebase.
- `.planning/research/STACK.md` — versões de gem (`faraday ~> 2.14`, `aws-sdk-s3 ~> 1.229 require: false`), contrato do Evolution lido no tag `2.3.7` (auth por header `apikey`, forma das rotas, semântica do campo `delay`, QR como data-URI base64), justificativa faraday-sobre-Net::HTTP.
- `.planning/research/ARCHITECTURE.md` — desenho dos componentes (`Evolution::Client` / `Whatsapp::EvolutionClient`, classes de erro `Transient/Permanent/Unknown/NotConnected`, `app/services/whatsapp/`), modelagem (tabelas separadas, denormalização de `group_jid`/`group_subject`).
- `.planning/research/PITFALLS.md` — top 5 pitfalls (duplicar envio em `Net::ReadTimeout`, vazamento cross-client, burst anti-spam, URL de mídia inalcançável, instância despareada), tabela de defeitos pré-existentes com veredicto BLOQUEIA/oportunista.
- `.planning/research/FEATURES.md` — contratos de endpoint (`sendText`, `sendMedia`, `fetchAllGroups` com `getParticipants` obrigatório), lista must-have.

### Requisitos e projeto
- `.planning/REQUIREMENTS.md` — INFRA-01, INFRA-02, INFRA-03, INFRA-05, EVO-01, EVO-02, EVO-03 (escopo da fase 25); seção "Out of Scope" (UI de delay, `default_timezone` para `:utc`, etc.).
- `.planning/ROADMAP.md` §"Phase 25" — Goal, Success Criteria (5), nota de `--research-phase`, "Defeitos pré-existentes fechados aqui".
- `.planning/PROJECT.md` §"Key Decisions" — linhas WhatsApp (instância por cliente, `Divulgacao` separada, delay em ENV, credenciais `.env` + credentials).

### A produzir nesta fase (canônico para fases 26–30)
- `.planning/notes/evolution-contract.md` — **a criar no research da fase 25.** Contrato Evolution verificado empiricamente: versão real do host, shape dos DTOs, casing dos eventos de webhook, resultado de cada um dos 8 itens ASSUMIDOS, itens pendentes com a fase onde serão medidos.
- `.planning/notes/api-auth-strategy.md` — precedente de estilo para a nota acima (nota de design fora do phase dir servindo um milestone inteiro).

### Código (padrões e pontos de integração)
- `app/services/api/jwt_service.rb` — padrão do PORO service: módulo `Errors` aninhado, métodos de classe, `Rails.application.credentials.x || ENV.fetch("X")`. `Evolution::Client` + erros devem espelhar isto.
- `config/application.rb` — `config.time_zone = "Brasilia"`, `config.active_record.default_timezone = :local` (linha a manter, INFRA-03), locale `pt-BR`, precedente de comentário citando pesquisa (CORS / "RESEARCH.md Pitfall 6").
- `config/storage.yml` — stanza `amazon:` comentada pronta (padrão `bucket: your_own_bucket-<%= Rails.env %>`, credenciais via `credentials.dig(:aws, ...)`).
- `config/environments/development.rb` — **sem** `config.active_job.queue_adapter` (cai em `:async` — defeito a corrigir); `config.active_storage.service = :local` (linha 32, a trocar).
- `config/environments/production.rb` — já tem `config.active_job.queue_adapter = :solid_queue` (linha 53); `config.active_storage.service = :local` (linha 25, a trocar para o serviço MinIO); `config.force_ssl` e `config.hosts` comentados (relevantes para o deploy de D-09).
- `config/queue.yml` — fila única `"*"`, 3 threads, 1 processo (`JOB_CONCURRENCY`). Fila `whatsapp` dedicada é INFRA-06 (fase 29).
- `config/recurring.yml` — só limpa `finished`, não `failed` (INFRA-07, fase 30).
- `config/initializers/filter_parameter_logging.rb` — tem `:token, :_key, :secret, :crypt` mas **não** casa `apikey` nem `hash` (defeito a corrigir na fase 26, antes do primeiro token gravado — mas o `Evolution::Client` da fase 25 já loga requests: adicionar `:apikey` aqui é candidato à fase 25).
- `app/models/arte.rb` — `validates :media_file, size: { less_than: 50.megabytes }` (linha 40). Teto WhatsApp ~16 MB validado na `Divulgacao` na fase 28, não aqui.
- `Gemfile:35` — `gem "good_job", "~> 4.0"` (órfão, remover, INFRA-05).
- `Procfile.dev` — roda só `web` + `css`; precisa de linha `jobs:` (ou terminal separado) para UAT de agendamento.
- `bin/dev` — `foreman start -f Procfile.dev`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`app/services/api/jwt_service.rb`**: template exato do `Evolution::Client` — PORO com `module Errors` aninhado, métodos de classe, resolução de segredo `credentials || ENV.fetch`.
- **`config/storage.yml` stanza `amazon:` comentada**: base pronta para o serviço MinIO — só descomentar e ajustar `endpoint:` + `force_path_style: true`.
- **`solid_queue` (1.4.0) e `solid_cable` já instalados**: `enqueue_at` / `limits_concurrency` confirmados na cópia em `vendor/bundle`. Nenhuma gem nova de agendamento.
- **`production.rb` já com `queue_adapter = :solid_queue`**: só falta replicar em `development.rb` + carregar o schema de fila.

### Established Patterns
- Services em `app/services/<namespace>/`, controllers finos, segredos por `credentials.x || ENV.fetch("X")`.
- Comentários de código citam a pesquisa por nome quando uma decisão não-óbvia vem dela (precedente `config/application.rb`).
- `dotenv-rails` só nos grupos `[:development, :test]` — `.env` para dev/test, `credentials` para produção (decisão já registrada).

### Integration Points
- `config/environments/development.rb` + `production.rb` — queue adapter e `active_storage.service`.
- `config/storage.yml` — serviço MinIO (S3-compat com `endpoint`).
- `Gemfile` — `+faraday`, `+aws-sdk-s3` (`require: false`), `-good_job`.
- Novo `config/initializers/whatsapp.rb` (ou `evolution.rb`) — base URL, apikey global, timeouts do client.
- `Procfile.dev` — processo de jobs para dev.
- Deploy Docker no host público — Dockerfile, `docker compose` (web + jobs + reverse proxy), `production.rb` (`force_ssl`, `hosts`), `TZ` no ambiente do container.

</code_context>

<specifics>
## Specific Ideas

- MinIO no **mesmo servidor** que Evolution + app, sob subdomínio próprio com TLS (ex: `s3.bomcustoilhabela.com.br`).
- Host Evolution real da agência: `whatsapp.bomcustoilhabela.com.br` (base para o probe do contrato).
- App em produção rodando via **Docker / `docker compose`** no mesmo servidor, com `bin/jobs` como serviço separado no compose.
- O contrato Evolution verificado vive em `.planning/notes/evolution-contract.md`, modelado em `.planning/notes/api-auth-strategy.md`.
- Migração de blobs = rake task idempotente em `lib/tasks/`, rodada no deploy.

</specifics>

<deferred>
## Deferred Ideas

- **Separação de servidores app ↔ Evolution/MinIO** — candidato a hardening no backlog (pós-v1.7 ou fase 30). Hoje: risco de co-locação aceito conscientemente (D-11).
- **Smoke test de webhook na fase 25** — considerado e recusado; o receiver completo (`Webhooks::EvolutionController`, `secure_compare`, Rack::Attack) fica na fase 26 como o ROADMAP prevê (D-12).
- **Normalização de links Drive/Dropbox** — já é `PROD-04` em Future Requirements; no v1.7 esses links são bloqueados na Divulgação (fase 28), não normalizados.

</deferred>

---

*Phase: 25-funda-o-transporte-evolution-storage-alcan-vel*
*Context gathered: 2026-08-29*
