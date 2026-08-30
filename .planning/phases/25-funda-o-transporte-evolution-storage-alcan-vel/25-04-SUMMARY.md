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
  - "lib/tasks/storage_migration.rake — `storage:migrate_to_s3`: cópia idempotente copy-only Disk(:local) -> MinIO(:amazon) sobre ActiveStorage::Blob.find_each; pula keys já no destino; warn (sem raise) em key ausente na origem; backfill de active_storage_blobs.service_name para linhas NULL/\"local\" depois da cópia (Pitfall 6); loga key + byte size + status; resumo de uma linha machine-greppable; reexecutável (segunda rodada -> copied: 0). PROVADA ponta a ponta contra o DB de development: copied 12 / service_name_backfilled 12 / segunda rodada só-skip."
  - "evolution-contract.md §\"Deploy reachability (phase 25)\" — outbound app -> Evolution VERIFICADO (fetch_instances -> Array[6], 200, ~654ms); download de mídia de fora da LAN VERIFICADO em development (presigned GET externo -> HTTP/2 200 + content-type correto via DNS público -> Cloudflare -> MinIO); inbound /up carregado adiante (operador / fase 26 — app ainda não deployado)"
  - "Correção do endpoint MinIO: `aws.endpoint` movido de `s3.bomcustoilhabela.com.br` (console MinIO, porta 9001, devolve HTML) para `minio.bomcustoilhabela.com.br` (API S3, devolve XML `<Error><Code>AccessDenied</Code>` + `x-amz-request-id`). Commitado em 947413f. Buckets `calendario-livia-{development,production}` criados privados."
affects: [26-instancia-whatsapp-pareamento, 28-divulgacao-agendar, 29-motor-de-envio, 30-acompanhamento-hardening]

actuals:
  tokens: 8000
  tasks: 2
  commits: 5

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
    - ".planning/notes/evolution-contract.md — §\"Deploy reachability (phase 25)\" reescrita com os resultados empíricos: correção do endpoint, buckets, presigned externo 200, resumo da migração em dev, EVO-01 outbound fechado, inbound /up carregado adiante"
    - "config/credentials.yml.enc — aws.endpoint corrigido para o host da API S3 (commit 947413f, pelo orquestrador)"

key-decisions:
  - "Rake task entregue verbatim conforme 25-RESEARCH.md Pattern 6 + Pitfall 6 — sem exception handling em volta de dest.exist?/dest.upload: quando o destino está mal configurado a task ABORTA alto (correto), não engole o erro e finge sucesso (violaria a verdade 'nenhuma arte perde arquivo')."
  - "Resumo emitido por `puts` E `Rails.logger.info` (helper say) — Rails.logger em rake dev vai para log/development.log, não stdout; a verificação greppa a saída do comando, então o resumo precisa ir para stdout."
  - "EVO-01 outbound FECHADO: as credenciais evolution.* (gravadas no 25-03) resolvem e Evolution::Client.fetch_instances retorna Array[6] / 200 / ~654ms contra whatsapp.bomcustoilhabela.com.br. Encerra o blocker de round-trip autenticado de leitura que vinha do 25-01."
  - "Endpoint S3: o hostname do operador `s3.bomcustoilhabela.com.br` serve o CONSOLE do MinIO (porta 9001, HTML). A API S3 é `minio.bomcustoilhabela.com.br` (XML AccessDenied + x-amz-request-id). `aws.endpoint` em credentials.yml.enc corrigido para o host da API (947413f, orquestrador)."
  - "Buckets `calendario-livia-development` e `calendario-livia-production` criados via create_bucket com as credenciais root + force_path_style — privados, sem bucket policy (default privado do MinIO). Buckets pré-existentes não relacionados no host (boxpersonalizado, orcamento) intactos."
  - "INFRA-01 / SC1 provado em DEVELOPMENT: create_and_upload! -> blob.url -> fetch externo da presigned URL (DNS público -> Cloudflare -> MinIO, saiu pela internet pública, não pela LAN) -> HTTP/2 200, content-type text/plain, content-length 28, corpo confere. É a definição de INFRA-01 done. Rodar a migração contra o DB de PRODUÇÃO no host deployado permanece passo de operador de go-live — não é gate da fase 25 (task provada, config+prova empírica satisfeitas em dev)."
  - "Inbound /up do host do Evolution: NÃO EXECUTADO — o app ainda não está deployado em ilhacriativa.autopyweb.com.br. Per D-12 / A4 NÃO é blocker da fase 25 — a fase 26 lidera com o botão PAIR-05. Registrado como item de operador / fase 26, não como lacuna."

patterns-established:
  - "storage:migrate_to_s3 é o mecanismo canônico de migração de blob para o milestone — reexecutável no deploy após service = :amazon ativo"

requirements-completed: [INFRA-01, EVO-01]

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
        ref: "bin/rails storage:migrate_to_s3 (rodada real, DB de development, endpoint corrigido para minio.bomcustoilhabela.com.br + buckets criados) -> `[storage:migrate] done — copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12`. Os 2 missing = linhas órfãs de probe.txt (#13/#14, sem arquivo na origem nem no destino, lixo pré-fase); a task reportou alto e não quebrou; órfãos removidos depois. Pós: 12 linhas em service_name=amazon, cada uma baixa OK por presigned URL nova."
        status: pass
      - kind: e2e
        ref: "segunda rodada da task = só-skip / copied: 0 (idempotência confirmada após a 1ª cópia real)"
        status: pass
    human_judgment: true
    rationale: "Artefato completo + verificado por forma/registro/inspeção E provado ponta a ponta contra o DB de development (endpoint corrigido, buckets criados, 12 blobs copiados, backfill aplicado, 2ª rodada no-op, download presignado externo OK). Rodar a mesma task contra o DB de PRODUÇÃO no host deployado (bucket calendario-livia-production) é passo de operador de go-live, não gate da fase 25."
  - id: D2
    description: "evolution-contract.md §Deploy reachability (phase 25) — app <-> Evolution nos dois sentidos + download de mídia de fora da LAN"
    requirement: "EVO-01"
    verification:
      - kind: e2e
        ref: "bin/rails runner Evolution::Client.fetch_instances -> Array, count=6, HTTP 200, latency ~654ms (RAILS_ENV=development, apikey global de credentials.yml.enc)"
        status: pass
      - kind: e2e
        ref: "fetch EXTERNO de uma presigned URL (create_and_upload! -> blob.url(expires_in: 10.minutes)) via host minio.bomcustoilhabela.com.br -> DNS público -> edge Cloudflare -> MinIO (request saiu pela internet pública, não pela LAN 192.168.x): HTTP/2 200, content-type text/plain, content-length 28, server cloudflare, content-disposition attachment; filename=\"probe25.txt\", corpo confere. Assinatura / query string omitidas."
        status: pass
      - kind: manual_procedural
        ref: "curl -sS -I https://<app-hostname>/up do host do Evolution -> NÃO EXECUTADO (app não deployado em ilhacriativa.autopyweb.com.br). Carregado adiante para operador / fase 26; NÃO é blocker da fase 25 (D-12 / A4 — fase 26 lidera com PAIR-05)."
        status: deferred
    human_judgment: true
    rationale: "Outbound fechado com round-trip real (fetch_instances 200). O eixo de mídia — o ponto da SC1 do INFRA-01 — está PROVADO: uma presigned GET URL resolve em DNS público e devolve o objeto com content-type correto a partir de fora da LAN. O inbound /up depende de um app deployado publicamente; registrado com comando copy-paste para o operador e como item de abertura da fase 26. Uma falha do /up é registrada, não bloqueante."

# Metrics
duration: ~40min (inclui a retomada / finalização)
completed: 2026-08-29
status: complete
---

# Phase 25 Plan 04: Fundação — Reachable Media + app ↔ Evolution reachability Summary

**A rake `storage:migrate_to_s3` (idempotente, copy-only, com backfill de `service_name` para as linhas antigas travadas em `"local"`) está entregue e PROVADA ponta a ponta contra o DB de development: `copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12`, segunda rodada só-skip, e os 12 blobs baixam OK por URL presignada nova. INFRA-01 / SC1 está PROVADO: a causa raiz do endpoint foi corrigida (`s3.bomcustoilhabela.com.br` era o console do MinIO; a API S3 é `minio.bomcustoilhabela.com.br` — `aws.endpoint` corrigido em `947413f`), os buckets `calendario-livia-{development,production}` foram criados privados, e um `GET` de uma presigned URL buscado de FORA da LAN (DNS público → Cloudflare → MinIO) retornou `HTTP/2 200` com o `content-type` certo. EVO-01 outbound FECHADO — `Evolution::Client.fetch_instances` → `Array[6]` / HTTP 200 / ~654 ms. O `curl -I /up` do host do Evolution fica CARREGADO ADIANTE para o operador / fase 26 (o app ainda não está deployado publicamente) — não é blocker da fase 25 (D-12 / A4: a fase 26 lidera com o botão PAIR-05). Rodar a migração contra o DB de produção no host deployado é passo de operador de go-live, não gate da fase 25.**

## Performance

- **Duration:** ~40 min (execução inicial + retomada / finalização)
- **Tasks:** 2 de 2 completas
- **Files modified:** 3 (1 criado: `lib/tasks/storage_migration.rake`; 2 modificados: `.planning/notes/evolution-contract.md`, `config/credentials.yml.enc` — este último pelo orquestrador em `947413f`)
- **Commits:** 4 de tarefa (`8e5a3e0`, `5cd027b`, `947413f`, `e0a7a9e`) + 1 de pausa histórico (`9752f39`) + 1 de metadados (docs, a seguir)

## Accomplishments

- **`lib/tasks/storage_migration.rake` entregue e PROVADA ponta a ponta** — `storage:migrate_to_s3`:
  - `source = ActiveStorage::Blob.services.fetch(:local)` / `dest = ...fetch(:amazon)`.
  - Loga o inventário da origem antes de iterar: `ActiveStorage::Blob.count` + histograma `group(:service_name).count`.
  - `ActiveStorage::Blob.find_each`: `dest.exist?(blob.key)` → skip + next; `!source.exist?(blob.key)` → `warn` (sem raise) + next; senão `dest.upload(blob.key, StringIO.new(source.download(blob.key)), checksum:, content_type:)` + log `copied ... (N bytes)`.
  - Depois do loop: `ActiveStorage::Blob.where(service_name: [nil, "local"]).update_all(service_name: "amazon")` + log de linhas atualizadas (Pitfall 6).
  - Resumo final na forma exata: `[storage:migrate] done — copied: N skipped: N missing: N service_name_backfilled: N`.
  - Copy-only: a origem Disk nunca é apagada/sobrescrita. Idempotente: segunda rodada só faz skip.
  - Loga key + byte size + status apenas — nunca conteúdo de blob, nunca URL.
  - **Rodada real (DB de development, endpoint corrigido + buckets criados):** pré — histograma `{"local"=>12, "amazon"=>2}`, 14 linhas de blob; resumo — `[storage:migrate] done — copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12`. Os 2 `missing` eram linhas órfãs de `probe.txt` (blob #13/#14, `service_name="amazon"`, sem arquivo na origem nem no destino — lixo de sessões de probe anteriores, anteriores a esta fase). A task **reportou alto e não quebrou** — comportamento correto. As 2 linhas órfãs foram então removidas (`ActiveStorage::Blob.where(id:[13,14]).delete_all`). Pós — 12 linhas, histograma `{"amazon"=>12}`, e **cada um dos 12** blobs baixou OK por uma URL presignada nova. Nenhuma arte perdeu o arquivo (copy-only; os arquivos Disk locais ficaram no lugar).
- **Endpoint S3 — causa raiz corrigida** — o hostname do operador `s3.bomcustoilhabela.com.br` serve o **console** do MinIO (porta 9001) — `GET /` devolve o HTML `"MinIO Console"`. A **API S3** é `minio.bomcustoilhabela.com.br` — `GET /` ali devolve `<?xml ...><Error><Code>AccessDenied</Code>...` com header `x-amz-request-id`. `config/credentials.yml.enc` `aws.endpoint` foi corrigido para `https://minio.bomcustoilhabela.com.br` e commitado (`947413f`, pelo orquestrador). Os dois hostnames ficam atrás do Cloudflare.
- **Buckets criados** — `calendario-livia-development` e `calendario-livia-production` via `create_bucket` com as credenciais root + `force_path_style: true` — privados, sem bucket policy (default privado do MinIO). Buckets pré-existentes não relacionados (`boxpersonalizado`, `orcamento`) intactos.
- **INFRA-01 / SC1 PROVADO em development** — `ActiveStorage::Blob.create_and_upload!` → `blob.url(expires_in: 10.minutes)` → fetch **externo** dessa URL presignada (host `minio.bomcustoilhabela.com.br` → DNS público → edge Cloudflare → MinIO; a request saiu pela internet pública, **não** pela LAN `192.168.x`): `HTTP/2 200`, `content-type: text/plain`, `content-length: 28`, `server: cloudflare`, `content-disposition: attachment; filename="probe25.txt"`; bytes do corpo conferem com o objeto enviado. É a prova de "o host do Evolution consegue baixar a mídia de fora da LAN": uma presigned GET URL que resolve em DNS público e devolve o objeto com o `content-type` certo. Assinatura / query string omitidas de todos os artefatos escritos.
- **EVO-01 outbound FECHADO** — `Evolution::Client.fetch_instances` (apikey global de `credentials.yml.enc`, contra `whatsapp.bomcustoilhabela.com.br`) retornou `Array` com **6** instâncias, HTTP **200**, latência ~**654 ms** (medido em `RAILS_ENV=development`). Encerra o blocker "round-trip autenticado de leitura não executado" que vinha do 25-01.
- **`evolution-contract.md` §"Deploy reachability (phase 25)"** reescrita com os resultados empíricos: correção do endpoint, buckets, presigned externo 200, resumo da migração em dev, EVO-01 outbound fechado, inbound `/up` carregado adiante para o operador / fase 26. Sem segredos, assinaturas de URL ou telefones.
- **A7 confirmado** — no DB de development, `active_storage_blobs.service_name` das linhas antigas está gravado como a string `"local"` (12 linhas), com 2 linhas já em `"amazon"`. O `update_all` condicional do backfill é necessário (não é só NULL).

## Empirical results (recorded verbatim-faithful, redacted)

1. **Correção da causa raiz do endpoint.** `s3.bomcustoilhabela.com.br` serve o **console** do MinIO (porta 9001, HTML `"MinIO Console"`). A **API S3** é `minio.bomcustoilhabela.com.br` (retorna `<?xml><Error><Code>AccessDenied</Code>` + header `x-amz-request-id`). `config/credentials.yml.enc` `aws.endpoint` atualizado para `https://minio.bomcustoilhabela.com.br` e commitado (`947413f`). Ambos os hosts atrás do Cloudflare (`server: cloudflare`).

2. **Buckets criados** (privados, sem bucket policy — default privado do MinIO): `calendario-livia-development` e `calendario-livia-production`, via `create_bucket` com as credenciais root gravadas + `force_path_style: true`. Buckets pré-existentes não relacionados no host: `boxpersonalizado`, `orcamento` (intactos).

3. **INFRA-01 / SC1 — round-trip presignado PROVADO** (development, bucket `calendario-livia-development`):
   - `ActiveStorage::Blob.create_and_upload!` → `blob.url(expires_in: 10.minutes)` → GET via SDK devolveu os bytes exatos.
   - Fetch **EXTERNO** dessa presigned URL (host `minio.bomcustoilhabela.com.br` → DNS público → edge Cloudflare → MinIO; a request saiu pela internet pública, não pela LAN `192.168.x`): `HTTP/2 200`, `content-type: text/plain`, `content-length: 28`, `server: cloudflare`, `content-disposition: attachment; filename="probe25.txt"`, bytes do corpo conferem com `phase25-external-media-probe`.
   - É a prova de "o host do Evolution consegue baixar a mídia de fora da LAN": uma presigned GET URL que resolve em DNS público e devolve o objeto com o `content-type` certo. Assinatura / query string omitidas de todos os artefatos escritos.

4. **Migração de blob rodada (DB de development)** — `bin/rails storage:migrate_to_s3`:
   - Pré: histograma `service_name` `{"local"=>12, "amazon"=>2}`, 14 linhas de blob.
   - Linha de resumo da task: `done — copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12`.
   - Os 2 `missing` eram linhas órfãs de `probe.txt` (blob #13, #14, `service_name="amazon"`, sem arquivo na origem nem no destino — lixo de sessões de probe anteriores, anteriores a esta fase). A rake reportou alto e não quebrou. O orquestrador então removeu essas 2 linhas órfãs (`ActiveStorage::Blob.where(id:[13,14]).delete_all`).
   - Pós: 12 linhas de blob, histograma `{"amazon"=>12}`, e cada um dos 12 baixou OK por uma presigned URL nova. Nenhuma arte perdeu o arquivo (copy-only; arquivos Disk locais no lugar).
   - **NOTA:** essa migração rodou contra o DB de **development** para provar a task ponta a ponta. O DB de **produção** não é alcançável a partir daqui — rodar `bin/rails storage:migrate_to_s3` no host deployado (contra `calendario-livia-production`) permanece passo de operador para o go-live; registrado como tal (não é gate da fase 25 — a task está provada e a config + prova empírica de INFRA-01 estão satisfeitas em dev).

5. **EVO-01 — FECHADO (outbound).** `Evolution::Client.fetch_instances` → `Array[6]`, HTTP 200, ~654 ms contra `whatsapp.bomcustoilhabela.com.br` com as credenciais gravadas no 25-03.

6. **Inbound `/up` do host do Evolution** — ainda não rodado: o app não está deployado em `ilhacriativa.autopyweb.com.br`. Per a nota do executor anterior (D-12 / A4) NÃO é blocker da fase 25 — a fase 26 lidera com o botão de pareamento PAIR-05. Registrado como item carregado adiante para operador / fase 26, não como lacuna.

7. **Segurança — carregado adiante (não bloqueia):** `aws.access_key_id` / `aws.secret_access_key` são as credenciais ROOT do MinIO. Emitir uma access key com escopo dos buckets `calendario-livia-*` e rotacionar o bloco `aws:` antes / logo após o go-live. Já anotado no 25-03; mantido no 25-04 SUMMARY + STATE.

## Task Commits

1. **Task 1: rake task de migração idempotente de blobs** — `8e5a3e0` (feat) — `lib/tasks/storage_migration.rake`
2. **Task 2: registro de reachability de deploy** — `5cd027b` (docs) — `.planning/notes/evolution-contract.md` §"Deploy reachability (phase 25)" (registro inicial)
3. **Task 2: correção do endpoint S3** — `947413f` (fix, orquestrador) — `config/credentials.yml.enc` `aws.endpoint` → host da API S3 `minio.bomcustoilhabela.com.br`
4. **Task 2: resultados empíricos** — `e0a7a9e` (docs) — `.planning/notes/evolution-contract.md` §"Deploy reachability (phase 25)" reescrita com endpoint corrigido, buckets, presigned externo 200, resumo da migração em dev

**Histórico:** `9752f39` (docs) pausou o plano no gate blocking-human; superado por esta finalização.

**Plan metadata:** _(docs commit a seguir — inclui esta SUMMARY, STATE.md, ROADMAP.md, REQUIREMENTS.md)_

## Verification method per check

`bin/rails test` não roda aqui (o banco de teste pertence a outro usuário do SO). Verificação por inspeção + execução direta de `bin/rails runner` / `bin/rails storage:migrate_to_s3` / fetch HTTP real.

| Check | Método | Status |
|---|---|---|
| `test -f lib/tasks/storage_migration.rake` | executado | PASS (present) |
| `bin/rails -T storage` lista `storage:migrate_to_s3` c/ descrição | executado | PASS |
| shape: `dest.exist?` + `update_all(service_name` presentes, não loga `download(...).inspect/.to_s` | `ruby -e` | PASS (task shape OK) |
| histograma `service_name` da origem | `bin/rails runner` (dev DB) | PASS — `{"local"=>12, "amazon"=>2}` |
| `aws.endpoint` aponta para a API S3 (XML AccessDenied + x-amz-request-id), não o console (HTML) | probe HTTP + `curl` | PASS após `947413f` (`minio.bomcustoilhabela.com.br`) |
| buckets `calendario-livia-{development,production}` existem e são privados | `create_bucket` + `head_bucket` | PASS |
| rodar `storage:migrate_to_s3` (rodada real, dev DB) | executado | PASS — `copied: 12 skipped: 0 missing: 2 service_name_backfilled: 12`; 2 missing = órfãos de probe.txt (reportado alto, não quebrou; órfãos removidos depois) |
| rodar `storage:migrate_to_s3` 2x → segunda reporta `copied: 0` | executado | PASS (idempotente — só-skip na 2ª) |
| `ActiveStorage::Blob.where(service_name: [nil,'local']).count == 0` pós-run | `bin/rails runner` | PASS — histograma `{"amazon"=>12}` |
| os 12 blobs baixam OK por presigned URL nova pós-migração | fetch via SDK | PASS |
| outbound `Evolution::Client.fetch_instances` → Array/200 | `bin/rails runner` (dev, credentials) | PASS — `Array` count=6, 200, ~654ms |
| `curl -I` presigned URL de **fora de `192.168.3.203`** (DNS público → Cloudflare → MinIO) | fetch HTTP externo real | PASS — `HTTP/2 200`, `content-type: text/plain`, `content-length: 28`, `content-disposition: attachment; filename="probe25.txt"`, corpo confere |
| `curl -I https://<app-hostname>/up` do host do Evolution | não executado — app não deployado | CARREGADO ADIANTE (operador / fase 26) — não é blocker (D-12 / A4) |

## Deviations from Plan

**Nenhum desvio de código.** A rake task foi entregue exatamente como `25-RESEARCH.md` Pattern 6 + Pitfall 6 e o `<action>` do plano mandam. Deliberadamente **não** foi adicionado exception handling em volta de `dest.exist?` / `dest.upload`: quando o destino está mal configurado a task deve abortar alto (comportamento correto), não engolir o erro e reportar sucesso.

Desvios de processo / infraestrutura (não são defeitos de código):

1. **[Rule 3 - blocking issue] Endpoint MinIO apontava para o console, não para a API S3.**
   - **Achado em:** Task 1 (rodada real da migração em dev) e Task 2 (diagnóstico `head_bucket` / `list_objects_v2`).
   - **Sintoma inicial:** `head_bucket` → `400 BadRequest`; `list_objects_v2` → `400 InvalidArgument` `"S3 API Requests must be made to API port."`; `GET /` em `s3.bomcustoilhabela.com.br` → `200` mas `content-type: text/html` (é o console do MinIO na porta 9001).
   - **Causa raiz:** o hostname `s3.bomcustoilhabela.com.br` do operador serve o console; a API S3 fica em `minio.bomcustoilhabela.com.br` (`GET /` → XML `<Error><Code>AccessDenied</Code>` + `x-amz-request-id`).
   - **Fix:** `config/credentials.yml.enc` `aws.endpoint` → `https://minio.bomcustoilhabela.com.br`. **Commit:** `947413f` (pelo orquestrador). Buckets `calendario-livia-{development,production}` criados privados.
   - **Resultado:** a migração e o round-trip presignado então passaram ponta a ponta em development.

2. **[Rule 1 - data hygiene] Duas linhas órfãs de `probe.txt` no DB de development.**
   - **Achado em:** rodada real da migração (`missing: 2`).
   - **Issue:** blob #13 / #14, `service_name="amazon"`, sem arquivo na origem nem no destino — lixo de sessões de probe anteriores, anteriores a esta fase. A rake reportou alto e não quebrou (comportamento correto).
   - **Fix:** `ActiveStorage::Blob.where(id:[13,14]).delete_all` (pelo orquestrador). Pós: 12 linhas limpas, todas em `service_name=amazon`.

## Carried forward (operador / fase 26 — não bloqueia a fase 25)

| Item | Requisito | O que falta | Onde fecha |
|---|---|---|---|
| Migração real dos blobs no host deployado (DB de produção, bucket `calendario-livia-production`) | INFRA-01 (go-live) | Operador roda `bin/rails storage:migrate_to_s3` no host deployado | Passo de go-live — a task está provada em dev |
| `curl -sS -I https://<app-hostname>/up` do host do Evolution → status | EVO-01 / D-12 | App deployado publicamente em `ilhacriativa.autopyweb.com.br`; colar status (falha = registrada, não bloqueia) | Abertura da fase 26 (ou operador) |
| Emitir access key com escopo dos buckets `calendario-livia-*` + rotacionar o bloco `aws:` | segurança (não bloqueia) | Operador cria a chave escopada no MinIO e regrava `credentials.yml.enc` | Antes / logo após o go-live |

**Fechado neste plano:** EVO-01 outbound (round-trip autenticado de leitura, `fetch_instances` → 200); INFRA-01 / SC1 (download presignado externo de fora da LAN → HTTP 200 + content-type correto, em development); migração de blob provada ponta a ponta (dev DB).

## Requirements

- **INFRA-01** — **COMPLETO.** Artefato de migração (`storage_migration.rake`) entregue + verificado por forma + **provado ponta a ponta** contra o DB de development (endpoint corrigido, buckets criados, 12 blobs copiados, `service_name` backfilled, 2ª rodada no-op). SC1 satisfeito: um `GET` de presigned URL buscado de **fora de `192.168.3.203`** (DNS público → Cloudflare → MinIO) retornou `HTTP/2 200` com o `content-type` correto. Rodar a migração contra o DB de produção no host deployado é passo de operador de go-live, não gate da fase 25.
- **EVO-01** — **COMPLETO** (para o escopo da fase 25). Outbound (contrato de leitura autenticado contra o host real) **VERIFICADO** — `fetch_instances` → `Array[6]` / 200 / ~654 ms; registrado em `evolution-contract.md`. Inbound `/up` do host do Evolution: carregado adiante para operador / fase 26 (app não deployado) — não bloqueia a fase 25 (D-12 / A4). Caminho de escrita (`sendText`/`sendMedia`, teto de mídia, casing de webhook): PENDENTE por D-08, dono = fases 26/28/29.

## Threat Flags

Nenhuma superfície de segurança nova além do `<threat_model>` do plano.

- **T-25-16** (log de conteúdo / URL assinada na migração) — mitigado: a task loga só key + byte size + status; `ruby -e` shape check confirma que não há `download(...).inspect/.to_s`; nenhuma chamada de `.url` na task.
- **T-25-17** (presigned URL vazando / sobrevivendo ao uso) — mitigado: `expires_in: 10.minutes`, mintada ad hoc para o check, nunca commitada; os artefatos registram só status + content-type + content-length, nunca a URL nem a query string.
- **T-25-18** (migração parcial deixando blobs split entre serviços) — mitigado: task idempotente e copy-only; a rodada real completou (`copied: 12`, `missing: 2` = órfãos removidos); `service_name` backfill rodou depois da cópia.
- **T-25-19** (bucket público "consertando" 404) — respeitado: nenhuma mudança de ACL; os buckets `calendario-livia-*` são privados (default do MinIO, sem bucket policy). O erro anterior era config de endpoint (console vs API S3), corrigido em `947413f` — não "consertado" com política de bucket.
- **T-25-20** (`/up` expondo internals) — accept: `/up` é o health endpoint do Rails por design; retorna só up/down.
- **Recomendação (não bloqueia):** `aws.access_key_id` / `aws.secret_access_key` gravados são as credenciais ROOT do MinIO — emitir access key com escopo dos buckets `calendario-livia-*` e rotacionar antes / logo após o go-live (repetido de 25-03).

## Self-Check: PASSED

**Arquivos — existência confirmada:**
- `lib/tasks/storage_migration.rake` — FOUND (`git show 8e5a3e0 --stat`)
- `.planning/notes/evolution-contract.md` — FOUND (modificado, `git show e0a7a9e --stat`)

**Commits — existência confirmada em `git log`:**
- `8e5a3e0` feat(25-04): idempotent storage:migrate_to_s3 blob migration rake task — FOUND
- `5cd027b` docs(25-04): record phase-25 deploy reachability results — FOUND
- `947413f` fix(25-04): correct aws.endpoint to the MinIO S3 API host — FOUND
- `e0a7a9e` docs(25-04): record phase-25 deploy reachability empirical results — FOUND

**Sem segredos em arquivos rastreados** — `evolution-contract.md` e esta SUMMARY não contêm apikey, secret, assinatura de URL presignada, query string ou telefone (só hostnames já presentes no corpus `.planning/`, contagens, latência, e headers HTTP não-sensíveis).

---
*Phase: 25-funda-o-transporte-evolution-storage-alcan-vel*
*Completed: 2026-08-29 — INFRA-01 + EVO-01 fechados (SC1 provado em development; inbound /up carregado adiante para a fase 26)*
