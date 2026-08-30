---
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
plan: 03
subsystem: infra
tags: [docker-compose, solid_queue, bin-jobs, caddy, tls, reverse-proxy, timezone, force_ssl, dns-rebinding, activestorage, minio, credentials, deploy-topology]

# Dependency graph
requires:
  - phase: 25-funda-o-transporte-evolution-storage-alcan-vel
    provides: "25-02 — config/storage.yml stanza `amazon` (S3/MinIO, force_path_style, bucket por env, privado) e config/initializers/timezone_check.rb (boot check TZ raise-prod/warn-dev). Este plano aponta production.rb para `:amazon` e fixa TZ nos containers, fechando a metade prod dos dois."
provides:
  - "docker-compose.yml — serviço `jobs` (./bin/jobs, env web-parity + TZ, depends_on db healthy, storage volume, restart unless-stopped): sem ele NENHUM job agendado dispara em produção"
  - "docker-compose.yml — `TZ: America/Sao_Paulo` em web E jobs (INFRA-03 metade deploy — timezone_check.rb aborta o boot de quem faltar)"
  - "docker-compose.yml — serviço `proxy` (caddy:2-alpine, portas 80/443, volumes caddy_data/caddy_config, bind-mount deploy/Caddyfile)"
  - "deploy/Caddyfile — TLS termination para ilhacriativa.autopyweb.com.br -> reverse_proxy web:3000 (Let's Encrypt automático)"
  - "config/environments/production.rb — active_storage.service = :amazon, assume_ssl, force_ssl, ssl_options (/up exclude), config.hosts allow-list, host_authorization (/up exclude), action_mailer host real"
  - ".env.example — EVOLUTION_BASE_URL, EVOLUTION_GLOBAL_API_KEY, EVOLUTION_OPEN/WRITE/READ_TIMEOUT, S3_ENDPOINT, TZ (nomes + comentários, sem valores)"
  - "config/credentials.yml.enc — blocos evolution: (base_url, global_api_key) e aws: (access_key_id, secret_access_key, region, endpoint) com os valores do operador"
affects: [25-04-reachable-media, 26-instancia-whatsapp-pareamento, 29-motor-de-envio, 30-acompanhamento-hardening]

actuals:
  tokens: 2200
  tasks: 3
  commits: 3

tech-stack:
  added: ["caddy:2-alpine (imagem Docker do reverse proxy; não é gem — official image, tag major fixa)"]
  patterns:
    - "solid_queue worker como serviço próprio no compose reusando a imagem do web com command sobrescrito (./bin/jobs), sem db:prepare (web é dono das migrações via bin/docker-entrypoint)"
    - "TZ fixado no environment de TODO serviço que roda código Rails (web + jobs) — o boot check do 25-02 transforma esquecimento em erro visível"
    - "reverse proxy TLS-terminante no compose (Caddy) com config.assume_ssl + config.force_ssl no Rails atrás dele; o proxy encaminha o Host original e config.hosts valida"
    - "serviço externo (MinIO) alcançado por endpoint HTTPS em credentials — não co-locado, não proxied pelo Caddy do app (topologia real difere da premissa do plano)"

key-files:
  created:
    - "deploy/Caddyfile — site block ilhacriativa.autopyweb.com.br -> reverse_proxy web:3000; bloco s3. comentado (forward-compat)"
  modified:
    - "docker-compose.yml — + serviço jobs, + serviço proxy, + TZ em web, + volumes caddy_data/caddy_config"
    - "config/environments/production.rb — :amazon + assume_ssl + force_ssl + ssl_options + config.hosts + host_authorization + action_mailer host"
    - ".env.example — + 7 chaves novas (nomes + comentários, sem valores)"
    - "config/credentials.yml.enc — + blocos evolution: e aws:"

key-decisions:
  - "Task 1 (checkpoint:decision, gate=blocking): ferramenta de deploy = docker compose (estender o docker-compose.yml hand-rolled), NÃO o esqueleto Kamal. Casa com D-10 (\"eu uso docker para rodar aplicação\"); deploy = git pull + docker compose up -d --build. config/deploy.yml + .kamal/ ficam como scaffolding morto — podem ser removidos num plano futuro, não deletados aqui (o <action> do plano não mandou)."
  - "Topologia real (Deviation Rule 2): MinIO e Evolution já estão live e TLS-terminados na infra bomcustoilhabela.com.br; o app deploya em OUTRO domínio (ilhacriativa.autopyweb.com.br). O Caddy do app tem UM site block (o app); o app alcança o MinIO como serviço HTTPS externo via aws.endpoint. Sem container MinIO co-locado, sem bloco s3. proxied ativo — o bloco s3. fica comentado no Caddyfile para forward-compat."
  - "config.hosts = allow-list de UM host exato (ilhacriativa.autopyweb.com.br), sem regex de subdomínio — nenhum outro subdomínio é usado; allow-list mais estreita = menor superfície anti DNS-rebinding (T-25-11 / Security V14)."
  - "Segredos Evolution + aws.* escritos APENAS em config/credentials.yml.enc (fornecidos pelo operador via canal seguro). .env.example recebe só nomes de chave + comentários. base_url/endpoint tratados como valor sensível — não ecoados em nenhum arquivo rastreado novo."
  - "action_mailer.default_url_options.host trocado de example.com para o host real + protocol https (Deviation Rule 2) — o link de reset de senha do PasswordsMailer sairia quebrado em produção."

patterns-established:
  - "Worker de fila = serviço compose dedicado reusando a imagem do web, command ./bin/jobs, mesmo env + TZ, depends_on db healthy, storage volume, restart unless-stopped; migrações continuam com o web"
  - "TZ no environment de web E jobs; qualquer serviço Rails sem TZ correto aborta no boot (timezone_check.rb do 25-02)"
  - "Reverse proxy TLS no compose (Caddy) + assume_ssl/force_ssl no Rails; serviços externos (MinIO) por endpoint em credentials, não proxied pelo app"

requirements-completed: [INFRA-03]

coverage:
  - id: D1
    description: "docker-compose.yml roda web + worker jobs dedicado (./bin/jobs) + proxy TLS, todos TZ-pinados; jobs tem depends_on db healthy, storage volume, restart unless-stopped"
    requirement: "INFRA-03"
    verification:
      - kind: integration
        ref: "docker compose config -q (exit 0); docker compose config | ruby YAML: services.jobs.command inclui ./bin/jobs, services.web+jobs environment inclui America/Sao_Paulo, jobs.depends_on={db:service_healthy}, jobs.volumes=[storage:/rails/storage], jobs.restart=unless-stopped — todos PASS"
        status: pass
      - kind: integration
        ref: "grep 'reverse_proxy' deploy/Caddyfile — site block ilhacriativa.autopyweb.com.br -> reverse_proxy web:3000 presente"
        status: pass
    human_judgment: false
  - id: D2
    description: "config/environments/production.rb: active_storage.service = :amazon; assume_ssl + force_ssl + ssl_options + config.hosts (host real, não example.com) + host_authorization todos ativos"
    requirement: "INFRA-01"
    verification:
      - kind: integration
        ref: "grep 'active_storage.service = :amazon' production.rb; ruby: linhas assume_ssl/force_ssl/config.hosts/host_authorization não comentadas — PASS"
        status: pass
      - kind: e2e
        ref: "CORS_ORIGINS=... RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 TZ=America/Sao_Paulo bin/rails runner — boot completo OK: config.active_storage.service=:amazon, force_ssl=true, assume_ssl=true, config.hosts=[\"ilhacriativa.autopyweb.com.br\"], action_mailer host correto"
        status: pass
    human_judgment: false
  - id: D3
    description: "config.hosts + host_authorization travam Host header no host público do app (anti DNS-rebinding, T-25-11)"
    requirement: "INFRA-01"
    verification:
      - kind: e2e
        ref: "boot de produção: Rails.application.config.hosts => [\"ilhacriativa.autopyweb.com.br\"] (allow-list exata, sem example.com, sem regex ampla); host_authorization exclui /up"
        status: pass
    human_judgment: false
  - id: D4
    description: ".env.example documenta as 7 chaves novas (nomes + comentários, sem valores); chaves pré-existentes intactas"
    requirement: "INFRA-01"
    verification:
      - kind: integration
        ref: "grep EVOLUTION_BASE_URL/EVOLUTION_GLOBAL_API_KEY/S3_ENDPOINT/TZ em .env.example — presentes; git diff mostra RAILS_MASTER_KEY + POSTGRES_PASSWORD inalterados; git grep dos valores secretos em arquivos rastreados (exceto credentials.yml.enc) — CLEAN"
        status: pass
    human_judgment: false
  - id: D5
    description: "config/credentials.yml.enc tem blocos evolution: (base_url, global_api_key) e aws: (access_key_id, secret_access_key, region, endpoint) não-nil com os valores do operador"
    requirement: "INFRA-01"
    verification:
      - kind: integration
        ref: "bin/rails runner: credentials.dig(:evolution) e dig(:aws) não-nil; base_url/global_api_key/access_key_id/secret_access_key/region/endpoint todos não-branco; base_url começa com https:// — PASS"
        status: pass
    human_judgment: true
    rationale: "Os blocos estão gravados e não-nil (verificado por runner sem ecoar valores). O fechamento empírico de INFRA-01/SC1 — round-trip presignado real contra o MinIO originado de fora da LAN — é do plano 25-04 e exige o serviço MinIO acessível; um humano/operador confirma esse round-trip lá. Aqui é só a metade config."

# Metrics
duration: ~15min (sessão de continuação; Task 1 resolvido pelo operador após pausa de ~5h no checkpoint:decision)
completed: 2026-08-29
status: complete
---

# Phase 25 Plan 03: Fundação — Deploy Topology (Docker Compose) Summary

**Topologia de produção D-09 no lugar via `docker compose`: `docker-compose.yml` ganha um worker `jobs` dedicado (`./bin/jobs`), `TZ: America/Sao_Paulo` em `web` + `jobs`, e um proxy Caddy TLS-terminante (`deploy/Caddyfile` -> `reverse_proxy web:3000` para `ilhacriativa.autopyweb.com.br`); `production.rb` passa a `:amazon` + `assume_ssl`/`force_ssl`/`ssl_options` + `config.hosts` travado no host real + `host_authorization`; os segredos Evolution e `aws.*` do operador entram em `config/credentials.yml.enc` e as 7 chaves novas são documentadas (sem valores) em `.env.example`. INFRA-03 agora fecha (TZ pinado nos containers + boot check do 25-02). O MinIO é externo e já TLS-terminado — sem container co-locado, sem bloco `s3.` proxied (desvio de topologia documentado abaixo).**

## Performance

- **Duration:** ~15 min de execução (Task 2 commit 22:49:26-03:00, Task 3 commit 22:51:50-03:00). Task 1 (checkpoint:decision, gate=blocking) ficou pausado ~5h (17:49 -> ~22:47) aguardando a decisão humana da ferramenta de deploy.
- **Tasks:** 3 (Task 1 = decisão do operador registrada; Task 2 + Task 3 executadas neste agente de continuação)
- **Files modified:** 4 (1 criado: `deploy/Caddyfile`; 3 modificados: `docker-compose.yml`, `config/environments/production.rb`, `.env.example`, `config/credentials.yml.enc`)
- **Commits:** 2 de tarefa (`4557abb`, `af30186`) + 1 de metadados (docs, a seguir)

## Task 1 — Decisão do checkpoint (gate=blocking)

**Decisão do operador: ferramenta de deploy = `docker compose`.** Estende o `docker-compose.yml` hand-rolled (`db` + `web`); o esqueleto Kamal (`config/deploy.yml` + `.kamal/`) **não** é adotado.

**Rationale:** casa com CONTEXT.md D-10 (interpretação de "eu uso docker para rodar aplicação"); o deploy inteiro é `git pull` + `docker compose up -d --build`, um arquivo para raciocinar, já com `db` + `web` + volumes nomeados. Kamal exigiria registry, `servers.web` real, roles `job:`/`proxy:` descomentadas e configuradas — mais superfície para um single-box.

**Efeito nas Tasks 2 e 3:** Task 2 edita `docker-compose.yml` e **cria** `deploy/Caddyfile`; Task 3 procede como escrita. `config/deploy.yml` + `.kamal/` ficam como **scaffolding morto** — podem ser removidos num plano futuro de limpeza; **não** foram deletados aqui porque o `<action>` do plano não mandou.

## Accomplishments

### Task 2 — jobs worker + TZ + Caddy proxy (commit `4557abb`)

- **Serviço `jobs`** no `docker-compose.yml`: `build: .`, `command: ["./bin/jobs"]`, bloco `environment:` idêntico ao do `web` (`RAILS_ENV`, `RAILS_MASTER_KEY`, `POSTGRES_HOST/USER/PASSWORD`, `CALENDARIO_LIVIA_DATABASE_PASSWORD`, `RAILS_LOG_TO_STDOUT`) **+ `TZ: America/Sao_Paulo`**, `depends_on: { db: { condition: service_healthy } }`, `volumes: - storage:/rails/storage`, `restart: unless-stopped`. **Sem `db:prepare`** — o `bin/docker-entrypoint` só roda `db:prepare` quando o comando termina em `./bin/rails server`, então o `web` continua dono das migrações. Sem este serviço, nenhum job agendado dispara em produção (o `SOLID_QUEUE_IN_PUMA` fica no `config/deploy.yml` do Kamal, que não é o caminho de deploy).
- **`TZ: America/Sao_Paulo`** adicionado ao `environment:` do `web` também (INFRA-03 — `timezone_check.rb` do 25-02 aborta o boot de qualquer serviço Rails sem o TZ correto).
- **Serviço `proxy`**: `image: caddy:2-alpine`, `ports: ["80:80", "443:443"]`, `volumes: ./deploy/Caddyfile:/etc/caddy/Caddyfile:ro` + `caddy_data:/data` + `caddy_config:/config`, `depends_on: - web`, `restart: unless-stopped`. Volumes nomeados `caddy_data` e `caddy_config` adicionados. Comentário no arquivo cita `25-RESEARCH.md Pitfall 5` e CONTEXT D-09/D-11 (risco de co-locação aceito, threat T-25-13).
- **`deploy/Caddyfile`** criado: site block `ilhacriativa.autopyweb.com.br { reverse_proxy web:3000 }` (Caddy auto-provisiona Let's Encrypt quando 80/443 estão acessíveis). Bloco `s3.autopyweb.com.br` deixado **comentado** para forward-compat, com explicação (ver desvio de topologia abaixo).
- **Verificação:** `docker compose config -q` exit 0; `docker compose config` parseado por Ruby confirma `services.jobs.command` inclui `./bin/jobs`, `services.web` e `services.jobs` `environment` incluem `America/Sao_Paulo`, `jobs.depends_on = {db: service_healthy}`, `jobs.volumes = [storage:/rails/storage]`, `jobs.restart = unless-stopped`; `grep reverse_proxy deploy/Caddyfile` OK.

### Task 3 — production.rb SSL + Host allow-list + :amazon; segredos (commit `af30186`)

- **`config/environments/production.rb`:**
  - linha 25: `config.active_storage.service = :local` -> `:amazon` (INFRA-01 / D-01 — mídia servida pelo MinIO, presigned)
  - `config.assume_ssl = true` e `config.force_ssl = true` descomentados (o Caddy termina o TLS — D-09)
  - `config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }` descomentado (o health check `/up` não é force-redirecionado)
  - `config.hosts = ["ilhacriativa.autopyweb.com.br"]` descomentado e travado no host real (allow-list exata, **sem** regex de subdomínio ampla — menor superfície anti DNS-rebinding, T-25-11 / Security V14). `config.host_authorization = { exclude: ->(request) { request.path == "/up" } }` descomentado. Comentário cita D-09 e Security V14.
  - **[Deviation Rule 2]** `config.action_mailer.default_url_options` de `{ host: "example.com" }` para `{ host: "ilhacriativa.autopyweb.com.br", protocol: "https" }` — o `PasswordsMailer.reset` gera link de reset de senha; em produção sairia apontando para `example.com`.
- **`.env.example`:** anexadas (sem tocar nas chaves existentes `RAILS_MASTER_KEY`, `POSTGRES_PASSWORD`) as 7 chaves novas com comentários curtos e **sem valores**: `EVOLUTION_BASE_URL=`, `EVOLUTION_GLOBAL_API_KEY=`, `EVOLUTION_OPEN_TIMEOUT=5`, `EVOLUTION_WRITE_TIMEOUT=10`, `EVOLUTION_READ_TIMEOUT=30`, `S3_ENDPOINT=`, `TZ=America/Sao_Paulo`. Estilo de comentário (pt-BR, `# ...` acima da chave) casa com o arquivo.
- **`config/credentials.yml.enc`:** via `EDITOR="cp <tmpfile>" bin/rails credentials:edit`, adicionados os blocos:
  - `evolution:` -> `base_url`, `global_api_key`
  - `aws:` -> `access_key_id`, `secret_access_key`, `region`, `endpoint`
  - Valores **fornecidos pelo operador via canal seguro** e escritos apenas neste arquivo criptografado. Nunca em cleartext em nenhum arquivo rastreado, mensagem de commit, STATE.md, ROADMAP.md ou nesta SUMMARY. O `config/master.key` está presente; o merge preservou `secret_key_base`, `jwt_secret`, `api.ai_key`. O tmpfile foi apagado (`shred`/`rm`) logo após.
- **Verificação:** `grep active_storage.service = :amazon` OK; Ruby confirma `assume_ssl`/`force_ssl`/`config.hosts`/`host_authorization` não comentados; 7 chaves em `.env.example`; `bin/rails runner` confirma `credentials.dig(:evolution)` e `dig(:aws)` não-nil, todas as sub-chaves não-branco, `base_url` começa com `https://` (sem ecoar valores). **Boot real de produção** (`CORS_ORIGINS=... RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 TZ=America/Sao_Paulo bin/rails runner`) completou OK e reportou `service=:amazon`, `force_ssl=true`, `assume_ssl=true`, `hosts=["ilhacriativa.autopyweb.com.br"]`, `action_mailer host` correto.

## Task Commits

1. **Task 1: Confirm the deploy tool (D-10)** — decisão do operador (`docker compose`), sem commit de código (Task 1 é `checkpoint:decision`). Pausa registrada em `4b757d6` (docs).
2. **Task 2: docker-compose jobs service + TZ + reverse-proxy TLS** — `4557abb` (feat)
3. **Task 3: production.rb SSL + Host allow-list + :amazon; document + store secrets** — `af30186` (feat)

**Plan metadata:** _(docs commit a seguir — inclui esta SUMMARY, STATE.md, ROADMAP.md, REQUIREMENTS.md)_

## Files Created/Modified

- `deploy/Caddyfile` (novo) — site block `ilhacriativa.autopyweb.com.br` -> `reverse_proxy web:3000`; TLS Let's Encrypt automático; bloco `s3.` comentado (forward-compat, MinIO é externo).
- `docker-compose.yml` — `+ jobs` (worker solid_queue dedicado), `+ proxy` (caddy:2-alpine), `+ TZ: America/Sao_Paulo` em `web`, `+ caddy_data` / `caddy_config` nos volumes nomeados.
- `config/environments/production.rb` — `active_storage.service = :amazon`; `assume_ssl` + `force_ssl` + `ssl_options` descomentados; `config.hosts` (host real) + `host_authorization` descomentados; `action_mailer.default_url_options` host real + https.
- `.env.example` — `+ 7` chaves novas (nomes + comentários, sem valores); chaves pré-existentes intactas.
- `config/credentials.yml.enc` — `+` blocos `evolution:` e `aws:` com os valores do operador (criptografado).

## Decisions Made

- **Ferramenta de deploy = `docker compose`** (Task 1 checkpoint). Estende o `docker-compose.yml` hand-rolled; Kamal não adotado. `config/deploy.yml` + `.kamal/` ficam como scaffolding morto (remoção futura, não neste plano).
- **`config.hosts` = allow-list de um host exato**, sem regex `/.*\.autopyweb\.com\.br/`. Nenhum outro subdomínio de `autopyweb.com.br` é usado pelo app; a allow-list mais estreita reduz a superfície anti DNS-rebinding (T-25-11). O template do plano oferecia a regex "se um subdomínio é usado" — como só `ilhacriativa.` é usado, a string exata basta e é mais segura.
- **Segredos apenas em `credentials.yml.enc`.** `base_url` e `endpoint` tratados como valor sensível (per instrução do operador) — não ecoados em nenhum arquivo rastreado novo. `.env.example` recebe só nomes + comentários. Os hostnames `whatsapp.bomcustoilhabela.com.br` / `s3.bomcustoilhabela.com.br` já constavam do corpus `.planning/` desde os planos 25-01/25-02; **nada** foi adicionado em novo local.
- **`caddy:2-alpine` pinado na tag major** — imagem oficial do Caddy, não é `package-manager install` (sem gate de legitimidade). Alternativa seria o proxy embutido do Kamal (não escolhido).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Topologia real: MinIO é externo e já TLS-terminado — sem container co-locado, sem bloco `s3.` proxied**
- **Found during:** Task 2 (docker-compose + Caddyfile).
- **Issue:** O plano (Task 2 `<action>`) assume que o Caddy **do app** precisa fazer `reverse_proxy` de um site block `s3.<domain>` para um **MinIO co-locado no mesmo host**. Na topologia real deste ambiente (confirmada pelos inputs do operador): MinIO e Evolution já estão **live e TLS-terminados** na infra `bomcustoilhabela.com.br` — `https://s3.bomcustoilhabela.com.br` é um endpoint S3 externo funcional (é exatamente o `aws.endpoint` em credentials). O app Rails deploya num domínio **diferente** (`ilhacriativa.autopyweb.com.br`). Não há container MinIO co-locado para fazer proxy.
- **Fix:** O `deploy/Caddyfile` tem **um** site block ativo — `ilhacriativa.autopyweb.com.br` -> `reverse_proxy web:3000`. O bloco `s3.autopyweb.com.br` fica **comentado** com explicação (forward-compat: se algum dia o MinIO rodar neste host, descomentar e ajustar o upstream). O app alcança o MinIO como serviço HTTPS externo via `aws.endpoint`. O `docker-compose.yml` traz um comentário explicando por que o MinIO não é proxied aqui.
- **O que permaneceu exatamente como o plano manda:** serviço `jobs`, `TZ` em `web` + `jobs`, `restart: unless-stopped`, volume `storage`, serviço `proxy` Caddy + volumes `caddy_data`/`caddy_config`.
- **Files modified:** `docker-compose.yml`, `deploy/Caddyfile`
- **Verification:** `docker compose config -q` exit 0; `grep reverse_proxy deploy/Caddyfile` OK (um site block ativo).
- **Committed in:** `4557abb` (Task 2 commit)

**2. [Rule 2 - Missing Critical] `action_mailer.default_url_options` host = `example.com` em produção**
- **Found during:** Task 3 (production.rb).
- **Issue:** `config/environments/production.rb:64` tinha `config.action_mailer.default_url_options = { host: "example.com" }`. Existe `app/mailers/passwords_mailer.rb` e `PasswordsMailer.reset(user).deliver_later` é chamado no `PasswordsController` — o link de reset de senha sairia apontando para `example.com` em produção. O plano Task 3 `<action>` enumera as linhas 25/28/31/34/83-86/89 mas omite a linha do mailer.
- **Fix:** `{ host: "ilhacriativa.autopyweb.com.br", protocol: "https" }`, casado com `config.hosts` e com `force_ssl`. Comentário explicando.
- **Files modified:** `config/environments/production.rb`
- **Verification:** boot de produção reporta `action_mailer.default_url_options => {host: "ilhacriativa.autopyweb.com.br", protocol: "https"}`.
- **Committed in:** `af30186` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 missing-critical / Rule 2).
**Impact on plan:** A #1 é o alinhamento da topologia à realidade do ambiente (MinIO externo, não co-locado) — o operador pediu explicitamente esta interpretação; todos os artefatos exigidos (`jobs`, `TZ`, `proxy`, volumes) foram entregues, só o bloco `s3.` proxied virou comentário. A #2 corrige um link de e-mail quebrado em produção que o novo hostname real tornou corrigível. Nenhum scope creep.

## Issues Encountered

- **`bin/rails test` não roda neste ambiente** — banco de teste pertence a outro usuário do SO (constraint conhecida). Toda verificação foi `docker compose config` / `bin/rails runner` / `grep` / `ruby -e`, que rodam e passam.
- **Boot completo de produção agora É executável aqui** (diferente do 25-02) desde que `CORS_ORIGINS`, `SECRET_KEY_BASE_DUMMY=1` e `TZ=America/Sao_Paulo` sejam passados — o boot de produção completou OK e todos os valores de config foram confirmados em runtime. O `timezone_check.rb` **não** abortou porque o `TZ` correto foi passado, provando que o boot check passa quando o `TZ` está certo (o que o pin no `docker-compose.yml` garante em produção).
- **`config/deploy.yml` + `.kamal/` continuam no repo** como scaffolding morto (decisão Task 1 — não deletar neste plano). Candidato a um plano de limpeza futuro.

## Verification method per check

| Check | Método | Status |
|---|---|---|
| `docker compose config -q` | executado (`Docker Compose v5.0.0`) | PASS (exit 0) |
| jobs runs `./bin/jobs` + web/jobs TZ | `docker compose config` parseado por Ruby YAML | PASS |
| jobs depends_on/volume/restart | `docker compose config` parseado por Ruby YAML | PASS |
| Caddyfile `reverse_proxy web:3000` | `grep` | PASS |
| production.rb `:amazon` + SSL/hosts descomentados | `grep` + `ruby -e` + **boot real de produção** | PASS |
| `.env.example` 7 chaves, pré-existentes intactas | `grep` + `git diff` | PASS |
| nenhum valor secreto em arquivo rastreado (exceto credentials.yml.enc) | `git grep` dos valores literais | PASS (CLEAN) |
| credentials `evolution:` + `aws:` não-nil | `bin/rails runner` (sem ecoar valores) | PASS |
| round-trip presignado real contra o MinIO de fora da LAN | **não executado** — é o plano 25-04 (exige MinIO acessível) | deferido |
| deploy real no host + DNS + provisão de TLS | **não executado** — out-of-band (operador / 25-04) | deferido |

## Recommendations (não bloqueiam)

- **Chave S3 com escopo de bucket antes/logo após o go-live.** Os valores `aws.access_key_id` / `aws.secret_access_key` gravados são as credenciais **ROOT** do MinIO. Emitir uma access key com escopo restrito aos buckets `calendario-livia-*` (via console/`mc` do MinIO) e rotacionar o bloco `aws:` em `credentials.yml.enc` para ela. Registrado também como recomendação para o runbook de deploy.
- **Remover `config/deploy.yml` + `.kamal/`** num plano de limpeza futuro (scaffolding morto desde a decisão Task 1 = docker compose).
- **Console do MinIO** (`minio.bomcustoilhabela.com.br`, porta 9001) — informado pelo operador; não requer ação neste plano, útil para o runbook.

## Requirements

- **INFRA-03** — **MARCADO COMPLETO.** As duas metades entregues: boot check `config/initializers/timezone_check.rb` (25-02, commit `7f319a1`, raise prod / warn dev) **+** `TZ=America/Sao_Paulo` no `environment:` dos serviços `web` **e** `jobs` do `docker-compose.yml` (este plano, `4557abb`). O boot real de produção com `TZ` correto passou sem aviso; sem o `TZ` o `timezone_check.rb` abortaria o boot. SC5 (metade TZ) MET.
- **INFRA-01** — **AINDA PENDENTE.** Metade config entregue: `production.rb` -> `:amazon` + `assume_ssl`/`force_ssl` + `config.hosts`; `storage.yml` `amazon` (25-02); blocos `evolution:`/`aws:` em `credentials.yml.enc`. O que falta para SC1: round-trip presignado real originado de fora de `192.168.3.203` — é o plano **25-04** e exige o MinIO acessível. Não marcado completo aqui.
- **INFRA-05 / EVO-02 / EVO-03** — fechados no 25-01. **INFRA-02** — fechado no 25-02. **EVO-01** — deferido (round-trip autenticado real, aguarda uso das credenciais Evolution agora em `credentials.yml.enc` — pode ser exercitado no 25-04 ou na fase 26).

## Threat Flags

Nenhuma superfície de segurança nova além do `<threat_model>` do plano.

- **T-25-11** (DNS rebinding / Host header) — mitigado: `config.hosts` allow-list exata (`ilhacriativa.autopyweb.com.br`, não `example.com`, sem regex ampla); `host_authorization` exclui `/up`. Verificado no boot de produção.
- **T-25-12** (downgrade HTTP->HTTPS) — mitigado: `assume_ssl` + `force_ssl` ativos; Caddy termina o TLS (auto-cert Let's Encrypt); `ssl_options` mantém `/up` alcançável.
- **T-25-13** (co-locação app + Evolution + MinIO) — **na prática menor que o previsto:** MinIO e Evolution rodam em infra separada (`bomcustoilhabela.com.br`); o app roda sozinho em `ilhacriativa.autopyweb.com.br`. O risco de "um host derruba tudo" de D-11 fica reduzido a app-only. Disposição `accept` mantida; separação continua backlog.
- **T-25-14** (segredos no compose env) — mitigado: `${RAILS_MASTER_KEY}` e `${POSTGRES_PASSWORD}` vêm do env do host, não do arquivo; `aws.*` e `evolution.*` só em `credentials.yml.enc`; `jobs` reusa a mesma injeção do `web`.
- **T-25-15** (pull da imagem `caddy:2-alpine`) — mitigado: imagem oficial, tag major fixa.

## Next Phase Readiness

- **Plano 25-04** (reachable media) pode prosseguir assim que o operador provisionar/confirmar o MinIO acessível: `production.rb` já aponta `:amazon`, as credenciais `aws:` estão em `credentials.yml.enc`, o `S3_ENDPOINT` está documentado. O 25-04 entrega a rake de migração de blobs idempotente + a prova de download de fora da LAN + a alcançabilidade app<->Evolution nos dois sentidos.
- **Fase 26** (instância/pareamento + webhook): a topologia de produção (web + jobs + proxy TLS) que ela assume está no lugar; o webhook receiver continua fase 26 (D-12). As credenciais Evolution agora em `credentials.yml.enc` destravam o round-trip autenticado real (EVO-01) quando alguém rodar o probe.
- **Deploy real** (host + DNS A/AAAA para `ilhacriativa.autopyweb.com.br` + firewall 80/443 + provisão de TLS) é out-of-band, do operador / coberto pelo 25-04.

## Self-Check: PASSED

**Arquivos criados/modificados — existência confirmada:**
- `deploy/Caddyfile` — FOUND
- `docker-compose.yml` — FOUND (modificado)
- `config/environments/production.rb` — FOUND (modificado)
- `.env.example` — FOUND (modificado, via `git diff`)
- `config/credentials.yml.enc` — FOUND (modificado; `git show af30186 --stat` mostra a alteração)

**Commits — existência confirmada em `git log`:**
- `4557abb` feat(25-03): docker-compose jobs worker + TZ pin + Caddy TLS proxy — FOUND
- `af30186` feat(25-03): production SSL + Host allow-list + :amazon storage; document + store secrets — FOUND

**Sem valores secretos em arquivos rastreados** (exceto `config/credentials.yml.enc` criptografado) — confirmado por `git grep` dos valores literais: CLEAN.

---
*Phase: 25-funda-o-transporte-evolution-storage-alcan-vel*
*Completed: 2026-08-29*
