# Phase 25: Fundação — Transporte Evolution + Storage Alcançável - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-29
**Phase:** 25-funda-o-transporte-evolution-storage-alcan-vel
**Areas discussed:** Provedor e topologia do S3, Migração dos blobs locais existentes, Verificação empírica do contrato Evolution, Escopo de "produção" nesta fase

---

## Provedor e topologia do S3

### Provedor

| Option | Description | Selected |
|--------|-------------|----------|
| AWS S3 | Caminho padrão; `aws-sdk-s3` first-class no ActiveStorage; egress pago quando o Evolution baixa a mídia | |
| Cloudflare R2 | S3-compat via `endpoint` custom; egress zero; casos de borda no ActiveStorage | |
| Backblaze B2 / DO Spaces | S3-compat via `endpoint` custom; egress barato / simples se já usa DO | |
| MinIO na infra da agência | Self-hosted S3-compat; sem custo de terceiro; precisa de host público alcançável pelo Evolution | ✓ |

**User's choice:** MinIO na infra da agência

### Alcance do MinIO

| Option | Description | Selected |
|--------|-------------|----------|
| MinIO no mesmo host do Evolution | Subdomínio próprio (ex: `s3.bomcustoilhabela.com.br`) + TLS no host público do Evolution; alcance resolvido de saída | ✓ |
| MinIO em outro host público | Outro servidor com IP/DNS público e TLS | |
| Ainda não definido | Infra do MinIO ainda a provisionar; pendência bloqueante | |

**User's choice:** MinIO no mesmo host do Evolution

### Modo de URL

| Option | Description | Selected |
|--------|-------------|----------|
| Presignada, validade longa no envio | Bucket privado; URL gerada no `perform` com `expires_in` cobrindo o disparo; casa com Pitfall 4 | ✓ (via "você decide") |
| Bucket/prefixo público de leitura | ACL public-read; URL estável sem presign | |
| Você decide | Segue a recomendação da pesquisa | ✓ |

**User's choice:** Você decide → presignada gerada no momento do envio com validade explícita

### Topologia de bucket

| Option | Description | Selected |
|--------|-------------|----------|
| Buckets separados por ambiente | `bucket-<Rails.env>`, padrão da stanza `amazon:` comentada | ✓ (via "você decide") |
| Só produção usa MinIO; dev segue local | `development` continua em disco; caminho S3 nunca exercitado em dev | |
| Você decide | Segue o padrão do storage.yml + bucket de dev no MinIO | ✓ |

**User's choice:** Você decide → bucket por ambiente, com bucket de dev ativo no MinIO
**Notes:** `development.rb` passa de `service: :local` para o serviço MinIO para exercitar o caminho presignado localmente.

---

## Migração dos blobs locais existentes

### O que fazer com os anexos existentes

| Option | Description | Selected |
|--------|-------------|----------|
| Migrar tudo pro MinIO | Rake task / script que sobe todos os anexos (~21 MB, ~13 arquivos); roda em segundos | ✓ |
| Mirror durante transição, migrar depois | `service: :mirror` local primary + MinIO espelho; migra histórico depois | |
| Aceitar perda dos antigos | Só anexos novos vão pro MinIO; os atuais somem quando produção virar | |

**User's choice:** Migrar tudo pro MinIO

### Como entregar/executar a migração

| Option | Description | Selected |
|--------|-------------|----------|
| Rake task idempotente + doc | `lib/tasks/`: itera blobs, pula os que já existem, loga; rodada no deploy; reexecutável | ✓ (via "você decide") |
| Script one-shot documentado | Passo a passo no doc de deploy, sem código permanente | |
| Você decide | Rake task idempotente — alinhado ao DNA do projeto | ✓ |

**User's choice:** Você decide → rake task idempotente em `lib/tasks/`, rodada manualmente no deploy

---

## Verificação empírica do contrato Evolution

### Acesso ao host

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, tenho host + apikey global | Usuário passa base URL + apikey global; Claude roda o probe no research da fase | ✓ |
| Tenho acesso, mas rodo eu mesmo | Claude entrega script de probe; usuário roda via `!`; cola a saída | |
| Ainda não tenho o host pronto | Host Evolution ainda a subir/parear; pendência bloqueante | |

**User's choice:** Sim, tenho host + apikey global

### Onde registrar o contrato verificado

| Option | Description | Selected |
|--------|-------------|----------|
| `.planning/notes/evolution-contract.md` | Documento vivo em `notes/`, estilo `api-auth-strategy.md`; serve fases 25–30 | ✓ (via "você decide") |
| No phase dir (`25-RESEARCH.md`) | Contrato como seção do RESEARCH.md da fase 25 | |
| Você decide | Usa `.planning/notes/evolution-contract.md` como fonte canônica | ✓ |

**User's choice:** Você decide → `.planning/notes/evolution-contract.md`, referenciado no CONTEXT.md e no RESEARCH.md

### Envio real a grupo de teste (JID de grupo, teto de mídia)

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, tem número e grupo de teste | Probe inclui `sendText`/`sendMedia` reais + medição de teto com 5/15/20/30 MB | |
| Só read-only agora; envio fica pra fase 26 | Research da 25 confirma os 6 itens de leitura; JID de grupo e teto viram pendência de UAT 26/28 | |
| Você decide | Tenta envio real se der; o que não fechar vira pendência rastreada | ✓ |

**User's choice:** Você decide → tentar envio real quando possível; itens não fechados viram pendência rastreada no `evolution-contract.md` nomeando a fase de medição

---

## Escopo de "produção" nesta fase

### Deploy do app Rails

| Option | Description | Selected |
|--------|-------------|----------|
| Não — só MinIO público; app segue na LAN | Só o MinIO fica público; app continua em 192.168.3.203; deploy do app fica pra depois | |
| Sim — app deployado num host público nesta fase | Fase 25 inclui subir o app num host público (necessário pro webhook da fase 26) | ✓ |
| Parcial — MinIO agora, app deploy começa mas não fecha | MinIO público + preparação de deploy; cutover na fase 26 | |

**User's choice:** Sim — app deployado num host público nesta fase
**Notes:** Amplia a fase 25 além do enunciado do ROADMAP ("transporte + storage + jobs"); planner / revisão de roadmap devem contabilizar o trabalho de deploy.

### Ferramenta de deploy

| Option | Description | Selected |
|--------|-------------|----------|
| Kamal | Padrão do Rails 8; Docker sobre SSH + Traefik TLS | |
| Docker Compose manual | Dockerfile + compose no host; `git pull` + rebuild; TLS via nginx/caddy | ✓ (interpretado da resposta livre) |
| Capistrano / sem container | Deploy Ruby clássico direto no host | |
| Você decide | Escolhe no research com base no host | |

**User's choice:** Resposta livre — "eu uso [docker] para rodar aplicação" → interpretado como Docker (`docker compose` no host, `bin/jobs` como serviço próprio, TLS por reverse proxy). Confirmar no planning se a ferramenta pretendida era outra.

### Host de produção

**User's choice:** Resposta livre — "mesmo servidor" → o app roda no mesmo servidor que Evolution + MinIO.

### Risco de co-locação

| Option | Description | Selected |
|--------|-------------|----------|
| Aceito o risco, mesmo servidor mesmo | Decisão consciente; escala 10-30 clientes; agência controla o host | |
| Mesmo servidor agora, separar depois | Segue junto na 25; separação vai pro backlog de hardening | |
| Você decide | Risco aceito com nota de separação como hardening candidato ao backlog | ✓ |

**User's choice:** Você decide → risco aceito conscientemente; separação app / Evolution anotada como hardening no backlog, sem bloquear

### Webhook e a fase 25

| Option | Description | Selected |
|--------|-------------|----------|
| Fase 25 só deixa o app alcançável; webhook fica na 26 | 25 entrega deploy + TLS + health check; receiver de webhook fica na 26 | |
| Puxar um smoke test de webhook pra fase 25 | 25 valida um POST do Evolution chegando (endpoint mínimo que loga e responde 200) | |
| Você decide | Receiver na 26; na 25 confirma alcance app ↔ Evolution nos dois sentidos | ✓ |

**User's choice:** Você decide → receiver completo na fase 26; a fase 25 só confirma alcance app ↔ Evolution nos dois sentidos como parte da verificação de deploy

---

## Claude's Discretion

- Modo de URL da mídia (→ presignada gerada no envio, seguindo a pesquisa)
- Topologia de bucket (→ bucket por ambiente + bucket de dev no MinIO)
- Entrega da migração de blobs (→ rake task idempotente)
- Onde registrar o contrato Evolution (→ `.planning/notes/evolution-contract.md`)
- Envio real vs. read-only no probe (→ tentar; o que faltar vira pendência rastreada)
- Tratamento do risco de co-locação (→ risco aceito + nota de hardening no backlog)
- Webhook na fase 25 (→ só confirmação de alcance; receiver fica na 26)
- Valores de timeout do `Evolution::Client`; fail-hard vs. warn na verificação de TZ; fila `whatsapp` agora vs. fase 29; split `credentials` vs `ENV` pra apikey global; shape das classes de erro

## Deferred Ideas

- Separação de servidores app ↔ Evolution/MinIO — hardening no backlog (pós-v1.7 ou fase 30)
- Smoke test de webhook na fase 25 — recusado; receiver fica na fase 26
- Normalização de links Drive/Dropbox — já é `PROD-04`; no v1.7 são bloqueados na fase 28
