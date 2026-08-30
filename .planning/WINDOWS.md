---
schema_version: 1
open_count: 3
waived_count: 0
fixed_count: 2
total_count: 5
last_updated: 2026-08-30T02:20:09.157Z
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
  }
]
````
