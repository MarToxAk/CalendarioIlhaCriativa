---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 2
total_count: 7
last_updated: 2026-08-30T22:16:05.660Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 25 | unrun-verify | config/storage.yml |  | INFRA-01/SC1: round-trip presignado real contra o MinIO dev não executado — MinIO não provisionado, sem S3_ENDPOINT/aws.* (user_setup); config entregue em 6ce3a06 | fixed |  | 2026-08-29T20:44:17.232Z | 2026-08-30T02:20:08.792Z |
| 2 | 25 | deviation | config/initializers/timezone_check.rb |  | Rule 1: ramo de warn em dev também emite para $stderr (Kernel#warn) além de Rails.logger.warn — Rails.logger em dev via bin/rails runner só grava em log/development.log | open |  | 2026-08-29T20:44:17.416Z |  |
| 3 | 25 | deviation | docker-compose.yml |  | 25-03 Rule 2: s3. reverse_proxy block left commented in deploy/Caddyfile — MinIO is external/TLS-terminated, not co-located; revisit if MinIO moves onto the app host | open |  | 2026-08-30T01:56:18.056Z |  |
| 4 | 25 | unrun-verify | lib/tasks |  | 25-03: presigned round-trip against real MinIO from outside the LAN not executed — owed by 25-04 (needs MinIO reachable) | fixed |  | 2026-08-30T01:56:18.244Z | 2026-08-30T02:20:08.971Z |
| 5 | 25 | unrun-verify | config/environments/production.rb |  | 25-04: inbound curl -I https://<app-hostname>/up do host do Evolution nao executado — app ainda nao deployado em ilhacriativa.autopyweb.com.br; fecha na abertura da fase 26 (D-12 / A4, nao bloqueia a fase 25) | open |  | 2026-08-30T02:20:09.157Z |  |
| 6 | 27 | stub | app/views/admin/whatsapp_groups/index.html.erb |  | Estados vazio/erro/bloqueado e seção de inativos não implementados neste plano (deferido a 27-03 por design — TODO no código); index atual renderiza card em branco sem @instance ou sem grupos ativos | open |  | 2026-08-30T18:57:24.624Z |  |
| 7 | 28 | todo | app/controllers/admin/divulgacoes_controller.rb |  | show/cancel actions deferred to plan 04 — route contract exists, #create redirects to unimplemented #show | open |  | 2026-08-30T22:16:05.660Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "25",
    "file": "config/storage.yml",
    "line": null,
    "description": "INFRA-01/SC1: round-trip presignado real contra o MinIO dev não executado — MinIO não provisionado, sem S3_ENDPOINT/aws.* (user_setup); config entregue em 6ce3a06",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-29T20:44:17.232Z",
    "resolved_at": "2026-08-30T02:20:08.792Z"
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "25",
    "file": "config/initializers/timezone_check.rb",
    "line": null,
    "description": "Rule 1: ramo de warn em dev também emite para $stderr (Kernel#warn) além de Rails.logger.warn — Rails.logger em dev via bin/rails runner só grava em log/development.log",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-29T20:44:17.416Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "25",
    "file": "docker-compose.yml",
    "line": null,
    "description": "25-03 Rule 2: s3. reverse_proxy block left commented in deploy/Caddyfile — MinIO is external/TLS-terminated, not co-located; revisit if MinIO moves onto the app host",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-30T01:56:18.056Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unrun-verify",
    "phase": "25",
    "file": "lib/tasks",
    "line": null,
    "description": "25-03: presigned round-trip against real MinIO from outside the LAN not executed — owed by 25-04 (needs MinIO reachable)",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-08-30T01:56:18.244Z",
    "resolved_at": "2026-08-30T02:20:08.971Z"
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "25",
    "file": "config/environments/production.rb",
    "line": null,
    "description": "25-04: inbound curl -I https://<app-hostname>/up do host do Evolution nao executado — app ainda nao deployado em ilhacriativa.autopyweb.com.br; fecha na abertura da fase 26 (D-12 / A4, nao bloqueia a fase 25)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-30T02:20:09.157Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "stub",
    "phase": "27",
    "file": "app/views/admin/whatsapp_groups/index.html.erb",
    "line": null,
    "description": "Estados vazio/erro/bloqueado e seção de inativos não implementados neste plano (deferido a 27-03 por design — TODO no código); index atual renderiza card em branco sem @instance ou sem grupos ativos",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-30T18:57:24.624Z",
    "resolved_at": null
  },
  {
    "id": 7,
    "kind": "todo",
    "phase": "28",
    "file": "app/controllers/admin/divulgacoes_controller.rb",
    "line": null,
    "description": "show/cancel actions deferred to plan 04 — route contract exists, #create redirects to unimplemented #show",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-30T22:16:05.660Z",
    "resolved_at": null
  }
]
````
