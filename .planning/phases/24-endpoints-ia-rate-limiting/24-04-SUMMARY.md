---
phase: 24-endpoints-ia-rate-limiting
plan: "04"
subsystem: middleware,api
tags: [rack-attack, rate-limiting, enum, status-counters, gap-closure]
dependency_graph:
  requires: []
  provides: [INFAPI-04, APIAI-03]
  affects: [config/application.rb, app/controllers/api/v1/ai/clients_controller.rb]
tech_stack:
  added: []
  patterns: [Rack::Attack middleware registration, Arte.statuses integer key lookup]
key_files:
  created: []
  modified:
    - config/application.rb
    - app/controllers/api/v1/ai/clients_controller.rb
decisions:
  - "Rack::Attack registrado com config.middleware.use (não insert_before) para processar após preflight CORS"
  - "Contadores usam Arte.statuses[\"status\"] como chave inteira em vez de chave string — compatível com group(:status).count que retorna inteiros"
metrics:
  duration: "~5 min"
  completed: "2026-06-13"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 24 Plan 04: Gap Closure — Rack::Attack Middleware + Status Counters Summary

Fecha dois blockers da Phase 24: registro do middleware Rack::Attack no stack do Rails e correção dos contadores de status no endpoint GET /api/v1/ai/clients/:id/summary.

## Tasks Executadas

| Task | Nome | Commit | Arquivos |
|------|------|--------|----------|
| 1 | Registrar Rack::Attack no middleware stack (INFAPI-04) | 56b2341 | config/application.rb |
| 2 | Corrigir contadores de status em ClientsController#summary (APIAI-03) | f78a155 | app/controllers/api/v1/ai/clients_controller.rb |

## O Que Foi Feito

### Task 1 — INFAPI-04: Rack::Attack no middleware stack

O initializer `config/initializers/rack_attack.rb` definia as regras de throttle (incluindo `api/ai_by_key`, 60 req/min por Bearer token) mas o middleware nunca estava registrado no stack do Rails — zero regra era executada em produção.

Adicionada em `config/application.rb`, após o bloco `Rack::Cors` (que permanece com `insert_before 0`) e antes do comentário `eager_load_paths`:

```ruby
config.middleware.use Rack::Attack
```

O `Rack::Cors` mantém `insert_before 0` para responder ao OPTIONS preflight antes de qualquer autenticação. O `Rack::Attack` entra depois, via `use`, processando os requests que passaram pelo preflight — comportamento correto para rate limiting.

### Task 2 — APIAI-03: Contadores de status com chave inteira

`Arte.group(:status).count` retorna `{0=>N, 1=>N, 2=>N, 3=>N}` porque a coluna `status` é `t.integer` no schema. O controller acessava o hash com chaves string (`counts["approved"]`), que sempre retornavam `nil` → `.to_i` → `0`. Apenas `total = counts.values.sum` estava correto.

Substituídas as quatro linhas de acesso ao hash para usar `Arte.statuses` como mapeamento string→inteiro:

```ruby
approved_count         = counts[Arte.statuses["approved"]].to_i
pending_count          = counts[Arte.statuses["pending"]].to_i
change_requested_count = counts[Arte.statuses["change_requested"]].to_i
revised_count          = counts[Arte.statuses["revised"]].to_i
```

`Arte.statuses` retorna `{"pending"=>0, "approved"=>1, "change_requested"=>2, "revised"=>3}`, portanto `Arte.statuses["approved"]` == `1`, que é a chave inteira correta no hash retornado pelo `group(:status).count`. A query SQL continua sendo única (sem escopos separados).

## Verificação Final

| Verificação | Resultado |
|-------------|-----------|
| `grep -c "config.middleware.use Rack::Attack" config/application.rb` | 1 |
| `grep -c 'Arte\.statuses' app/controllers/api/v1/ai/clients_controller.rb` | 4 |
| `grep -c 'counts\["approved"\]' app/controllers/api/v1/ai/clients_controller.rb` | 0 |
| `ruby -c config/application.rb` | Syntax OK |
| `ruby -c app/controllers/api/v1/ai/clients_controller.rb` | Syntax OK |
| `grep "insert_before 0, Rack::Cors" config/application.rb` | inalterado |

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito.

## Known Stubs

Nenhum stub identificado. Os dois arquivos modificados não contêm valores hardcoded, placeholders ou TODOs relacionados às alterações deste plano.

## Threat Flags

Nenhuma nova superfície de segurança introduzida. O registro do Rack::Attack fecha a ameaça T-24-GAP-01 (DoS) documentada no threat model. A correção dos contadores fecha T-24-GAP-02 (Information Disclosure — dados incorretos retornados).

## Self-Check: PASSED

| Item | Status |
|------|--------|
| config/application.rb | FOUND |
| app/controllers/api/v1/ai/clients_controller.rb | FOUND |
| 24-04-SUMMARY.md | FOUND |
| Commit 56b2341 (Task 1) | FOUND |
| Commit f78a155 (Task 2) | FOUND |
