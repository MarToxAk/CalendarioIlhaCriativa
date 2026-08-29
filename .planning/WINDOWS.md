---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-08-29T20:44:17.416Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 25 | unrun-verify | config/storage.yml |  | INFRA-01/SC1: round-trip presignado real contra o MinIO dev não executado — MinIO não provisionado, sem S3_ENDPOINT/aws.* (user_setup); config entregue em 6ce3a06 | open |  | 2026-08-29T20:44:17.232Z |  |
| 2 | 25 | deviation | config/initializers/timezone_check.rb |  | Rule 1: ramo de warn em dev também emite para $stderr (Kernel#warn) além de Rails.logger.warn — Rails.logger em dev via bin/rails runner só grava em log/development.log | open |  | 2026-08-29T20:44:17.416Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "25",
    "file": "config/storage.yml",
    "line": null,
    "description": "INFRA-01/SC1: round-trip presignado real contra o MinIO dev não executado — MinIO não provisionado, sem S3_ENDPOINT/aws.* (user_setup); config entregue em 6ce3a06",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-29T20:44:17.232Z",
    "resolved_at": null
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
  }
]
````
