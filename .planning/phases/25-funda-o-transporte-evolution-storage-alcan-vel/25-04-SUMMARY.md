---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
plan: 04
subsystem: infra
tags: [activestorage, minio, s3, blob-migration, rake, idempotent, service_name, evolution-api, reachability, presigned-url]

# Dependency graph
requires:
  - phase: 25-funda-o-transporte-evolution-storage-alcan-vel
    provides: "25-02 — storage.yml `amazon` (S3/MinIO, force_path_style, bucket por env, privado) + `local` como origem da migração; 25-03 — production.rb -> :amazon + blocos evolution:/aws: em credentials.yml.enc + topologia docker compose"
provides:
  - "lib/tasks/storage_migration.rake — `storage:migrate_to_s3`: cópia idempotente copy-only Disk(:local) -> MinIO(:amazon) sobre ActiveStorage::Blob.find_each; pula keys já no destino; warn (sem raise) em key ausente na origem; backfill de active_storage_blobs.service_name para linhas NULL/\"local\" depois da cópia (Pitfall 6); loga key + byte size + status; resumo de uma linha machine-greppable; reexecutável (segunda rodada -> copied: 0)"
  - "evolution-contract.md §\"Deploy reachability (phase 25)\" — outbound app -> Evolution VERIFICADO (fetch_instances -> Array[6], 200, ~654ms); inbound /up + download de mídia de fora da LAN registrados como PENDENTE (operador) com comandos copy-paste"
  - "Diagnóstico do endpoint MinIO: aws.endpoint (s3.bomcustoilhabela.com.br) responde pelo console do MinIO (porta 9001), NÃO pela porta da API S3 — 400 InvalidArgument \"S3 API Requests must be made to API port.\""
affects: [26-instancia-whatsapp-pareamento, 28-divulgacao-agendar, 29-motor-de-envio, 30-acompanhamento-hardening]

actuals:
  tokens: 3200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Rake task de migração de dados standalone em lib/tasks/ (não autoloaded; config.autoload_lib ignora tasks) — namespace + task :environment, counters explícitos, resumo de uma linha greppável"
    - "Migração de blob copy-only: origem Disk nunca mutada/apagada, fica como fallback; idempotência via dest.exist?(blob.key) antes de cada upload"
    - "service_name backfill DEPOIS da cópia (where(service_name: [nil, 'local']).update_all) — nunca aponta uma linha para um objeto ainda não copiado"

key-files:
  created:
    - "lib/tasks/storage_migration.rake — storage:migrate_to_s3 (idempotente, guarded, copy-only, backfill service_name)"
  modified:
    - ".planning/notes/evolution-contract.md — + §\"Deploy reachability (phase 25)\" (3 direções: outbound VERIFICADO, inbound PENDENTE, mídia BLOQUEADO) + ações de operador"

key-decisions:
  - "Rake task entregue verbatim conforme 25-RESEARCH.md Pattern 6 + Pitfall 6 — sem exception handling em volta de dest.exist?/dest.upload: quando o destino está mal configurado a task ABORTA alto (correto), não engole o erro e finge sucesso (violaria a verdade 'nenhuma arte perde arquivo')."
  - "Resumo emitido por `puts` E `Rails.logger.info` (helper say) — Rails.logger em rake dev vai para log/development.log, não stdout; a verificação greppa a saída do comando, então o resumo precisa ir para stdout."
  - "EVO-01 outbound FECHADO nesta sessão: as credenciais evolution.* (gravadas no 25-03) agora resolvem e Evolution::Client.fetch_instances retorna Array[6] / 200 / ~654ms contra whatsapp.bomcustoilhabela.com.br. Encerra o blocker de round-trip autenticado de leitura que vinha do 25-01."
  - "INFRA-01 empírico (SC1) NÃO fecha — gate blocking-human: (a) aws.endpoint aponta para o console do MinIO, não para a API S3 (400 InvalidArgument); (b) o download da presigned URL de fora de 192.168.3.203 precisa de vantage point out-of-band. Deferido como user_setup (flagged assumption A6), não é defeito de código."

patterns-established:
  - "storage:migrate_to_s3 é o mecanismo canônico de migração de blob para o milestone — reexecutável no deploy após service = :amazon ativo"

requirements-completed: []

coverage:
  - id: D1
    description: "lib/tasks/storage_migration.rake — storage:migrate_to_s3: cópia idempotente copy-only Disk -> MinIO + backfill de service_name (NULL/local), loga key/byte/status, resumo greppável, segunda rodada = no-op"
    requirement: "INFRA-01"
    verification:
      - kind: integration
        ref: "test -f lib/tasks/storage_migration.rake -> present"
        status: pass
      - kind: integration
        ref: "bin/rails -T storage | grep storage:migrate_to_s3 -> registrada com descrição"
        status: pass
      - kind: integration
        ref: "ruby -e shape check: inclui dest.exist?, update_all(service_name, NÃO loga download(...).inspect/.to_s -> task shape OK"
        status: pass
      - kind: integration
        ref: "bin/rails runner ActiveStorage::Blob.group(:service_name).count -> {\"local\"=>12, \"amazon\"=>2} (dev DB; A7 confirmado: linhas antigas gravadas como \"local\", não NULL)"
        status: pass
      - kind: e2e
        ref: "bin/rails storage:migrate_to_s3 (rodada real dev) -> ABORTA em dest.exist? com Aws::S3::Errors::BadRequest 400 — MinIO endpoint serve o console, não a API S3 (InvalidArgument: 'S3 API Requests must be made to API port.')"
        status: fail
    human_judgment: true
    rationale: "O artefato (rake task) está completo e verificado por forma/registro/inspeção. O fechamento empírico — cópia real dos blobs + segunda rodada no-op — depende de o operador expor a porta da API S3 do MinIO e criar os buckets (A6). Um humano confirma essa rodada no host deployado."
  - id: D2
    description: "evolution-contract.md §Deploy reachability (phase 25) — app <-> Evolution nos dois sentidos + download de mídia de fora da LAN"
    requirement: "EVO-01"
    verification:
      - kind: e2e
        ref: "bin/rails runner Evolution::Client.fetch_instances -> Array, count=6, HTTP 200, latency ~654ms (RAILS_ENV=development, apikey global de credentials.yml.enc)"
        status: pass
      - kind: manual_procedural
        ref: "curl -sS -I https://<app-hostname>/up do host do Evolution -> PENDENTE (app não deployado publicamente; input do operador)"
        status: unknown
      - kind: manual_procedural
        ref: "curl -sS -I '<presigned-url>' de fora de 192.168.3.203 -> BLOQUEADO (endpoint S3 mal configurado + vantage point out-of-band)"
        status: unknown
    human_judgment: true
    rationale: "Outbound fechado com round-trip real. Inbound /up e o download de mídia de fora da LAN exigem, respectivamente, um app deployado e um host fora da LAN da agência — nenhum dos dois é auto-executável aqui. Registrados em evolution-contract.md com comandos copy-paste para o operador colar o resultado."

# Metrics
duration: ~20min
completed: 2026-08-29
status: paused
---

# Phase 25 Plan 04: Fundação — Reachable Media + app ↔ Evolution reachability Summary

**A rake `storage:migrate_to_s3` (idempotente, copy-only, com backfill de `service_name` para as linhas antigas travadas em `"local"`) está entregue e verificada por forma/registro/inspeção. O round-trip autenticado de leitura do Evolution FECHOU nesta sessão — `Evolution::Client.fetch_instances` retorna `Array[6]` / HTTP 200 / ~654 ms com as credenciais gravadas no 25-03. O fechamento empírico de INFRA-01 (SC1) está PAUSADO num gate blocking-human: o `aws.endpoint` gravado (`s3.bomcustoilhabela.com.br`) responde hoje pelo **console** do MinIO e não pela **API S3** (`400 InvalidArgument: "S3 API Requests must be made to API port."`), então a migração real não copia nada; e o `curl -I` da presigned URL de fora de `192.168.3.203` mais o `curl -I /up` do host do Evolution exigem vantage points out-of-band. Comandos copy-paste para o operador registrados em `evolution-contract.md`.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T02:01:13Z
- **Paused:** 2026-08-30T02:04:21Z
- **Tasks:** 1 de 2 entregue por completo (Task 1); Task 2 parcial (outbound feito, 2 human-checks pendentes)
- **Files modified:** 2 (1 criado: `lib/tasks/storage_migration.rake`; 1 modificado: `.planning/notes/evolution-contract.md`)
- **Commits:** 2 de tarefa (`8e5a3e0`, `5cd027b`) + 1 de metadados (docs, a seguir)

## Accomplishments

- **`lib/tasks/storage_migration.rake` entregue** — `storage:migrate_to_s3`:
  - `source = ActiveStorage::Blob.services.fetch(:local)` / `dest = ...fetch(:amazon)`.
  - Loga o inventário da origem antes de iterar: `ActiveStorage::Blob.count` + histograma `group(:service_name).count`.
  - `ActiveStorage::Blob.find_each`: `dest.exist?(blob.key)` → skip + next; `!source.exist?(blob.key)` → `warn` (sem raise) + next; senão `dest.upload(blob.key, StringIO.new(source.download(blob.key)), checksum:, content_type:)` + log `copied ... (N bytes)`.
  - Depois do loop: `ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")` + log de linhas atualizadas (Pitfall 6).
  - Resumo final na forma exata: `[storage:migrate] done — copied: N skipped: N missing: N service_name_backfilled: N`.
  - Copy-only: a origem Disk nunca é apagada/sobrescrita. Idempotente: segunda rodada só faz skip.
  - Loga key + byte size + status apenas — nunca conteúdo de blob, nunca URL.
- **EVO-01 outbound FECHADO** — `Evolution::Client.fetch_instances` (apikey global de `credentials.yml.enc`, contra `whatsapp.bomcustoilhabela.com.br`) retornou `Array` com **6** instâncias, HTTP **200**, latência ~**654 ms** (medido em `RAILS_ENV=development` a partir da máquina de build). Encerra o blocker "round-trip autenticado de leitura não executado" que vinha do 25-01 (as credenciais, gravadas no 25-03, agora resolvem).
- **`evolution-contract.md` §"Deploy reachability (phase 25)"** — tabela das 3 direções (outbound VERIFICADO / inbound PENDENTE / mídia BLOQUEADO) + 6 ações de operador para destravar INFRA-01. Sem segredos, assinaturas de URL ou telefones.
- **A7 confirmado** — no DB de development, `active_storage_blobs.service_name` das linhas antigas está gravado como a string `"local"` (12 linhas), com 2 linhas já em `"amazon"` (criadas depois do switch do 25-02). O `update_all` condicional do backfill é necessário (não é só NULL).

## Task Commits

1. **Task 1: rake task de migração idempotente de blobs** — `8e5a3e0` (feat) — `lib/tasks/storage_migration.rake`
2. **Task 2 (parcial): registro de reachability de deploy** — `5cd027b` (docs) — `.planning/notes/evolution-contract.md` §"Deploy reachability (phase 25)"

**Plan metadata:** _(docs commit a seguir — inclui esta SUMMARY, STATE.md, ROADMAP.md)_

## Verification method per check

| Check | Método | Status |
|---|---|---|
| `test -f lib/tasks/storage_migration.rake` | executado | PASS (present) |
| `bin/rails -T storage` lista `storage:migrate_to_s3` c/ descrição | executado | PASS |
| shape: `dest.exist?` + `update_all(service_name` presentes, não loga `download(...).inspect/.to_s` | `ruby -e` | PASS (task shape OK) |
| histograma `service_name` da origem | `bin/rails runner` (dev DB) | PASS — `{"local"=>12, "amazon"=>2}` |
| rodar `storage:migrate_to_s3` 2x → segunda reporta `copied: 0` | **executado — ABORTOU na 1ª** | **FAIL (infra)** — `Aws::S3::Errors::BadRequest` 400; endpoint serve o console do MinIO, não a API S3 |
| outbound `Evolution::Client.fetch_instances` → Array/200 | `bin/rails runner` (dev, credentials) | PASS — `Array` count=6, 200, ~654ms |
| mintar presigned URL (`blob.url(expires_in: 15.minutes)`) | `bin/rails runner` | PASS (string monta) — mas aponta para o endpoint mal configurado, logo não-funcional até o operador corrigir |
| `curl -I` da presigned URL de fora de `192.168.3.203` | **não executado** — human-check (gate) | **PENDENTE (operador)** |
| `curl -I https://<app-hostname>/up` do host do Evolution | **não executado** — human-check (gate) | **PENDENTE (operador)** |

## Deviations from Plan

**Nenhum desvio de código.** A rake task foi entregue exatamente como `25-RESEARCH.md` Pattern 6 + Pitfall 6 e o `<action>` do plano mandam. Deliberadamente **não** foi adicionado exception handling em volta de `dest.exist?` / `dest.upload`: quando o destino está mal configurado a task deve abortar alto (comportamento correto), não engolir o erro e reportar sucesso — isso violaria a verdade "nenhuma arte perde arquivo" e a proibição contra gate em contagem hardcoded.

As duas metades não-fechadas são **lacunas de `user_setup` (flagged assumption A6)**, não defeitos:

1. **[user_setup / A6] Endpoint MinIO aponta para o console, não para a API S3.**
   - **Achado em:** Task 1 (rodada real da migração em dev) e Task 2 (diagnóstico `head_bucket` / `list_objects_v2`).
   - **Sintoma:** `head_bucket` → `400 BadRequest`; `list_objects_v2` → `400 InvalidArgument` com corpo XML `"S3 API Requests must be made to API port."`. `GET /` no endpoint retorna `200` mas com `content-type: text/html` + CSP de UI (é o console do MinIO na porta 9001, não a API S3 na 9000).
   - **Efeito:** `storage:migrate_to_s3` não copia nada; nenhuma presigned URL funcional pode ser mintada; **INFRA-01 / SC1 não fecha**.
   - **Remediação (operador):** expor a porta da API S3 do MinIO sob TLS, ajustar `aws.endpoint` em `credentials.yml.enc` se o hostname mudar, criar os buckets `calendario-livia-{production,development}` privados, rodar a rake no host deployado, e então fazer o `curl -I` da presigned URL de fora da LAN. Passos completos em `evolution-contract.md` §"Deploy reachability (phase 25)".

2. **[gate blocking-human] Provas de reachability que exigem vantage point out-of-band.**
   - `curl -I` da presigned URL **de fora de `192.168.3.203`** (ou `docker exec` no container do Evolution) — o executor não tem esse ponto de rede.
   - `curl -I https://<app-hostname>/up` **do host do Evolution** — o app ainda não está deployado num hostname público; inbound depende do operador.
   - Ambos registrados com comando copy-paste; o operador cola o resultado. Uma falha do inbound `/up` é **registrada, não bloqueante** para a fase 25 (D-12 / A4 — a fase 26 lidera com o botão PAIR-05).

## Deferred / Outstanding (gate blocking-human)

| Item | Requisito | O que falta | Onde fecha |
|---|---|---|---|
| Migração real dos blobs no host deployado + 2ª rodada no-op | INFRA-01 / SC1 | Operador expõe a API S3 do MinIO + cria buckets; então `bin/rails storage:migrate_to_s3` | Retomada do 25-04 (host deployado) |
| `curl -I` presigned URL de **fora de `192.168.3.203`** → 200 + content-type | INFRA-01 / SC1 | MinIO API S3 alcançável + vantage point externo; colar status + content-type | Retomada do 25-04 (human-check) |
| `curl -I https://<app-hostname>/up` do **host do Evolution** → status | EVO-01 / D-12 | App deployado publicamente; colar status (falha = registrada, não bloqueia) | Retomada do 25-04 (human-check) ou fase 26 |

**Já fechado nesta sessão:** EVO-01 outbound (round-trip autenticado de leitura, `fetch_instances` → 200).

## Requirements

- **INFRA-01** — **AINDA PENDENTE.** Artefato de migração (`storage_migration.rake`) entregue + verificado por forma. O fechamento empírico (SC1: download real da presigned URL de fora de `192.168.3.203`) está num gate blocking-human — bloqueado pelo endpoint MinIO mal configurado (console em vez da API S3) e pela falta de vantage point externo. Não marcado completo.
- **EVO-01** — **PARCIAL.** Outbound (contrato de leitura autenticado contra o host real) **VERIFICADO** nesta sessão — `fetch_instances` → `Array[6]` / 200 / ~654ms; registrado em `evolution-contract.md`. Inbound `/up` do host do Evolution: PENDENTE (operador). Caminho de escrita (`sendText`/`sendMedia`, teto de mídia): PENDENTE por D-08, dono = fases 26/28/29. Não marcado completo até o inbound `/up` ser registrado.

## Threat Flags

Nenhuma superfície de segurança nova além do `<threat_model>` do plano.

- **T-25-16** (log de conteúdo / URL assinada na migração) — mitigado: a task loga só key + byte size + status; `ruby -e` shape check confirma que não há `download(...).inspect/.to_s`; nenhuma chamada de `.url` na task.
- **T-25-17** (presigned URL vazando / sobrevivendo ao uso) — nenhuma URL escrita em disco; `evolution-contract.md` registra só status + content-type (placeholder). A URL mintada no diagnóstico teve a query string redigida no log.
- **T-25-19** (bucket público "consertando" 404) — respeitado: nenhuma mudança de ACL; o serviço `amazon` continua privado. O erro atual é `400 InvalidArgument` (porta errada), diagnosticado como config de endpoint — não "consertado" com política de bucket.
- **Recomendação (não bloqueia):** `aws.access_key_id`/`secret_access_key` gravados são as credenciais ROOT do MinIO — emitir access key com escopo dos buckets `calendario-livia-*` e rotacionar antes/logo após o go-live (repetido de 25-03).

## Self-Check: PASSED

**Arquivos — existência confirmada:**
- `lib/tasks/storage_migration.rake` — FOUND (`git show 8e5a3e0 --stat`)
- `.planning/notes/evolution-contract.md` — FOUND (modificado, `git show 5cd027b --stat`)

**Commits — existência confirmada em `git log`:**
- `8e5a3e0` feat(25-04): idempotent storage:migrate_to_s3 blob migration rake task — FOUND
- `5cd027b` docs(25-04): record phase-25 deploy reachability results — FOUND

**Sem segredos em arquivos rastreados** — `evolution-contract.md` não contém apikey, secret, assinatura de URL ou telefone (só hostnames já presentes no corpus `.planning/` e contagens/latência).

---
*Phase: 25-funda-o-transporte-evolution-storage-alcan-vel*
*Paused: 2026-08-29 — gate blocking-human (INFRA-01 SC1 empírico + inbound /up)*
