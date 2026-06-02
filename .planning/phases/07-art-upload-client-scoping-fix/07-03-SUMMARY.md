---
phase: 07-art-upload-client-scoping-fix
plan: "03"
subsystem: admin-artes-controller
tags: [security, cross-client-protection, scoping, gap-closure]
dependency_graph:
  requires: [07-01, 07-02]
  provides: [SC3-cross-client-protection, SC4-index-filtering]
  affects: [app/controllers/admin/artes_controller.rb]
tech_stack:
  added: []
  patterns: [before_action-ordering, conditional-scoping, active-record-association-scoping]
key_files:
  created: []
  modified:
    - app/controllers/admin/artes_controller.rb
decisions:
  - "set_arte usa @client.artes quando @client presente: proteção cross-client via RecordNotFound automático do Active Record"
  - "Fallback irrestrito quando @client nil: admin single-tenant pode acessar qualquer arte por URL direta (D-07)"
  - "before_action :set_client declarado antes de :set_arte para garantir @client disponível no set_arte"
  - "index filtra por Arte.where(client_id:) quando params[:client_id].present?; ramo else preserva comportamento original"
metrics:
  duration: "1m 17s"
  completed_date: "2026-06-02"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 1
requirements_closed: [ARTE-10]
---

# Phase 07 Plan 03: Gap Closure SC3 e SC4 — Cross-Client Protection e Index Filtering Summary

Proteção cross-client em set_arte via escoamento por associação e filtragem por cliente no index, fechando os blockers SC3 e SC4 da verificação de fase.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Proteção cross-client em set_arte e amplia set_client (SC3) | b77a133 | app/controllers/admin/artes_controller.rb |
| 2 | Filtragem por cliente no index e remoção do comentário de dívida (SC4) | 73c5040 | app/controllers/admin/artes_controller.rb |

## What Was Built

### Task 1 — SC3: Proteção Cross-Client em set_arte (ARTE-10)

- `before_action :set_client` ampliado de `%i[new create]` para `%i[new create show edit update destroy mark_revised]`
- Reordenação de before_actions: `set_client` agora precede `set_arte` na declaração, garantindo que `@client` esteja disponível quando `set_arte` executa
- `set_arte` modificado com lógica condicional:
  - Quando `@client` presente: `@client.artes.includes(:approval_responses).find(params[:id])` — Active Record levanta `RecordNotFound` automaticamente para IDs de outras contas
  - Quando `@client` nil (acesso direto por URL sem client_id): fallback irrestrito + `@client = @arte.client`

### Task 2 — SC4: Filtragem por Cliente no Index

- Método `index` modificado com filtragem condicional: quando `params[:client_id].present?`, escopa para `Arte.where(client_id: params[:client_id]).includes(:client).order(scheduled_on: :desc)`
- Ramo `else` preserva o comportamento original (todas as artes ordenadas por `scheduled_on: :desc`)
- Comentário de dívida `# Filtering logic can be added here` removido ao ser substituído pela implementação real

## Verification Results

Todas as verificações passaram:

```
Syntax OK
before_action :set_client inclui: new create show edit update destroy mark_revised
set_client na linha 2, set_arte na linha 3 (ordem correta)
@client.artes.includes — 1 ocorrência em set_arte
@client = @arte.client — 1 ocorrência no ramo else de set_arte
params[:client_id].present? — 1 ocorrência no index
Comentário 'Filtering logic': 0
Marcadores de dívida (TODO/FIXME/can be added/will be): 0
```

## Deviations from Plan

None — plano executado exatamente como escrito. As duas alterações cirúrgicas foram aplicadas sem desvios.

## Known Stubs

None — sem stubs. Toda a lógica de filtragem está implementada.

## Threat Flags

Nenhum novo threat surface introduzido. As mitigações T-07-03-01 e T-07-03-02 do threat register foram implementadas conforme planejado. T-07-03-03 aceito como risco pelo design single-admin (D-07).

## Self-Check: PASSED

- FOUND: app/controllers/admin/artes_controller.rb
- FOUND: .planning/phases/07-art-upload-client-scoping-fix/07-03-SUMMARY.md
- FOUND: b77a133 (Task 1 — feat: proteção cross-client)
- FOUND: 73c5040 (Task 2 — feat: filtragem no index)
