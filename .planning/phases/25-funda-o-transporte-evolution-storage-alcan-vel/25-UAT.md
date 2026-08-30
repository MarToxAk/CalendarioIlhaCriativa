---
status: testing
phase: 25-funda-o-transporte-evolution-storage-alcan-vel
source: [25-VERIFICATION.md]
started: "2026-08-30T09:59:24Z"
updated: "2026-08-30T09:59:24Z"
---

## Current Test

number: 1
name: "docker compose build conclui sem abortar em assets:precompile (prova final de CR-01)"
expected: |
  No host de deploy (com Docker): `docker compose build 2>&1 | tail -20`
  Conclui sem abortar em `assets:precompile`. O equivalente local
  (`env -u TZ SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production CORS_ORIGINS=... bin/rails runner`)
  já passa neste ambiente; falta a construção real da imagem.
awaiting: user response

## Tests

### 1. docker compose build (prova final de CR-01)
expected: |
  No host de deploy (com Docker): `docker compose build 2>&1 | tail -20`
  Conclui sem abortar em `assets:precompile`. Guard `SECRET_KEY_BASE_DUMMY` em
  config/initializers/timezone_check.rb:19 + config/initializers/evolution.rb:14
  faz os initializers fail-fast pularem durante o build; o boot de runtime real
  (sem a var) sem TZ correto AINDA aborta.
result: [pending]

### 2. docker compose up — web + jobs running/healthy sem KeyError (prova final de CR-02)
expected: |
  No host de deploy: `docker compose --env-file .env up -d && sleep 40 && docker compose ps`
  e `docker compose logs web jobs | grep -iE 'KeyError|key not found|timezone' || echo sem-erros`
  `web` e `jobs` em `running`/`healthy`, nunca `restarting`; nenhum
  `KeyError: key not found: "CORS_ORIGINS"` nos logs.
  ATENÇÃO WR-C: no primeiro deploy a frio, `db:prepare` pode exceder o
  `start_period: 40s` do healthcheck do `web`; se `up` falhar com
  `container is unhealthy`, rodar `docker compose up` de novo depois que `web`
  convergir (ou subir `start_period`).
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
