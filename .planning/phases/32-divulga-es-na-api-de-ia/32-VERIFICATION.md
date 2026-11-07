---
phase: 32-divulga-es-na-api-de-ia
verified: 2026-11-07T00:00:00Z
status: human_needed
score: 9/9 must-haves verified
covered_files:
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-01-PLAN.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-01-SUMMARY.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-02-PLAN.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-02-SUMMARY.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-03-PLAN.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-03-SUMMARY.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-04-PLAN.md"
  - ".planning/phases/32-divulga-es-na-api-de-ia/32-04-SUMMARY.md"
  - "app/controllers/api/v1/ai/clients_controller.rb"
  - "app/controllers/api/v1/ai/divulgacoes_controller.rb"
  - "app/serializers/api/v1/ai/divulgacao_serializer.rb"
  - "app/serializers/api/v1/ai/whatsapp_group_serializer.rb"
  - "config/routes.rb"
  - "test/controllers/api/v1/ai/clients_controller_test.rb"
  - "test/controllers/api/v1/ai/divulgacoes_controller_test.rb"
  - "test/integration/cross_client_isolation_test.rb"
covered_digest: "v4:sha256:81e78be491a306222ee0c313deff3015297a7ea94a200e97b06d4141554881cd"
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Run the Minitest suite in CI (bin/rails test, at least test/controllers/api/v1/ai/divulgacoes_controller_test.rb, test/controllers/api/v1/ai/clients_controller_test.rb, test/integration/cross_client_isolation_test.rb)"
    expected: "All 46 + 16 + 8 test cases green, including the cases added or changed by the review fixes (WR-01 malformed ids -> 400, WR-02 page=abc|0 -> 400, WR-04 enqueue failure -> 503 + row cancelada, CR-01 index_day offsets, CR-02 block-form assert_no_enqueued_jobs)"
    why_human: "bin/rails test cannot run locally (test DB owned by another OS user). The tests were never executed; behavior was only proven by temporary runtime harnesses that were deleted afterwards."
known_followups:
  - id: WR-03
    summary: "DispatchJob#perform does reload / return if cancelada? / update!(em_andamento) without a lock, so a cancel committing between reload and update! can be overwritten and sends proceed after the API answered 200 cancelada. Fix lives in app/jobs/divulgacoes/dispatch_job.rb (out of phase scope: additive only)."
    blocks_goal: false
---

# Phase 32: Divulgações na API de IA Verification Report

**Phase Goal:** Preencher o namespace `/api/v1/ai/*` com acesso a Divulgações: a IA lista, consulta, cria e cancela Divulgações (e descobre os ids de grupo antes de criar) pela API key `ak_`, reusando o model `Divulgacao`, suas validações e o `DispatchJob` real como estão, sem regra de negócio nova, isolamento SEG-01..04 preservado.
**Verified:** 2026-11-07
**Status:** human_needed
**Re-verification:** No, initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | IA lista divulgações de UM cliente: `client_id` obrigatório (400 se ausente), filtros `status` (enum validado, 400 se inválido), `from`/`to` opcionais, Pagy 25/100 (D-03, D-11..D-13) | VERIFIED | `divulgacoes_controller.rb#index`: `params.permit(:client_id).require(:client_id)`, `status_filter` com `Divulgacao.statuses.key?`, `period_range` com limites de dia no fuso do app, `pagy(scope, limit: per_page_param)`, `pagination_meta`. Sem ramo cross-client. |
| 2 | Sem N+1 na listagem e serializer D-10 com `grupos` por divulgação | VERIFIED | `includes(:divulgacao_grupos)` + `sort_by(&:id)` em Ruby no serializer; allowlist de chaves exatamente `id, client_id, arte_id, status, scheduled_for, created_at, updated_at, grupos[group_name, remote_jid, status, sent_at, error_code]` (sem `evolution_message_id`). |
| 3 | IA consulta uma divulgação (`show`) com resumo por grupo (D-01, D-10) | VERIFIED | `show` -> `find_divulgacao` (`Divulgacao.includes(:divulgacao_grupos).find`), 404 herdado para id inexistente. Busca global é decisão consciente (chave ak_ agency-wide, `show`/`cancel` só recebem `:id`). |
| 4 | IA cria divulgação real: `client_id`+`arte_id` explícitos, `whatsapp_group_ids`, `scheduled_for` ISO com offset, mesmas 7 validações, sem campo de confirmação (D-02, D-05, D-07, D-08) | VERIFIED | `create`: `attrs.require(:client_id/:arte_id)`, `client.divulgacoes.new(arte:, scheduled_for:)`, `divulgacao.save!` -> RecordInvalid -> 422 pelo base. Nenhum campo `confirm`; `create_params` não permite `status`. Model não alterado. |
| 5 | O POST enfileira o MESMO `Divulgacoes::DispatchJob` real, só após persistir (D-08, ENVIO-01) | VERIFIED | `Divulgacoes::DispatchJob.set(wait_until: divulgacao.scheduled_for).perform_later(divulgacao)` após `save!`; job não modificado (`git diff d0e7b10..HEAD -- app/jobs` vazio). Falha de enqueue (WR-04) -> `cancelar!` + 503 `enqueue_failed`. |
| 6 | Resolução escopada por cliente: arte/grupos forasteiros ou inativos -> 404 genérico (D-09, SEG-01..04) | VERIFIED | `client.artes.find(arte_id)`; `client.whatsapp_instance&.whatsapp_groups&.where(active: true) \|\| WhatsappGroup.none` `.find(gids)`; nenhum `Arte.find`/`WhatsappGroup.find` cru. Ids malformados -> 400 (WR-01), nunca descartados em silêncio. Testes cross-client em `cross_client_isolation_test.rb` (arte, grupo, listagem, grupos com cliente-irmão). |
| 7 | `cancel` idempotente espelhando `cancelar!`: 200 com estado atual, só muda se `agendada`, sem job (D-04) | VERIFIED | `divulgacao.with_lock { divulgacao.cancelar! }` ignorando o retorno; `Divulgacao#cancelar!` inalterado (`return false unless status_agendada?`). Sempre `render_envelope`, nunca 422. |
| 8 | IA descobre ids de grupo: `GET /api/v1/ai/clients/:id/whatsapp_groups` (ativos do cliente, paginado, `{id, remote_jid, display_name}`) (D-06, D-13) | VERIFIED | `clients_controller.rb#whatsapp_groups`: mesma fonte do admin, `order(subject ASC NULLS LAST).order(:remote_jid)`, Pagy, `WhatsappGroupSerializer` (allowlist de 3 chaves). Cliente sem instância -> 200 lista vazia. |
| 9 | Escopo aditivo: nenhuma regra de negócio nova; sem mudança em model, jobs, rack_attack; auth `ak_` e throttle herdados; Pagy inválido não vira 500 | VERIFIED | `git diff --stat d0e7b10..HEAD` fora de `.planning`: só 2 controllers, 2 serializers, `routes.rb` (+4) e 3 arquivos de teste. Controllers herdam `Api::V1::Ai::BaseController` (`authenticate_ai_key!`, constant-time compare); throttle `api/ai_by_key` cobre por prefixo. `Pagy::VariableError` (existe, supertipo de `OverflowError`) tratado com 400 e delega overflow para 404. |

**Score:** 9/9 truths verified (0 present-behavior-unverified; ver item humano sobre execução da suíte).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/controllers/api/v1/ai/divulgacoes_controller.rb` | index/show/create/cancel | VERIFIED | 218 linhas, substantivo, sem marcadores de dívida. |
| `app/controllers/api/v1/ai/clients_controller.rb` | `whatsapp_groups` action | VERIFIED | Wired por rota. |
| `app/serializers/api/v1/ai/divulgacao_serializer.rb` | serializer PORO D-10 | VERIFIED | Usado por index/show/create/cancel. |
| `app/serializers/api/v1/ai/whatsapp_group_serializer.rb` | serializer D-06 | VERIFIED | Usado por `whatsapp_groups`. |
| `config/routes.rb` | 8 rotas da fase | VERIFIED | `bin/rails routes` lista index, create, show, cancel (divulgacoes) e summary + whatsapp_groups (clients), formato json. |
| Testes (3 arquivos) | cobertura Minitest | PRESENT, NOT EXECUTED | 46 + 16 + 8 casos; `ruby -c` OK; CR-01/CR-02 corrigidos (`index_day(offset)`, `assert_no_enqueued_jobs do`). |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `routes.rb` | `Ai::DivulgacoesController` / `Ai::ClientsController#whatsapp_groups` | `resources :divulgacoes` + `post :cancel, on: :member`; `get :whatsapp_groups, on: :member` | WIRED (routes output confirmado) |
| `DivulgacoesController#create` | `Divulgacoes::DispatchJob` | `.set(wait_until:).perform_later` após `save!` | WIRED |
| `DivulgacoesController#cancel` | `Divulgacao#cancelar!` | `with_lock { cancelar! }` | WIRED |
| Controllers | `Api::V1::Ai::BaseController` (auth, envelope, paginação) | herança | WIRED |
| Serializers | controllers | `Api::V1::Ai::*Serializer.serialize(_collection)` | WIRED |

### Data-Flow Trace (Level 4)

| Artifact | Data | Source | Real Data | Status |
|----------|------|--------|-----------|--------|
| `index` | `@divulgacoes` | `client.divulgacoes` query com filtros + Pagy | Sim | FLOWING |
| `show`/`cancel` | divulgação | `Divulgacao.includes(...).find` | Sim | FLOWING |
| `whatsapp_groups` | `@groups` | `whatsapp_instance.whatsapp_groups.where(active: true)` | Sim | FLOWING |
| `create` | divulgacao | `client.divulgacoes.new` + `save!` | Sim | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| 8 rotas da fase registradas | `bin/rails routes \| grep ai/(divulg\|clients)` | 4 divulgacoes + 2 clients | PASS |
| Rubocop nos arquivos da fase | `bin/rubocop` (12 arquivos) | no offenses | PASS |
| Sintaxe dos testes | `ruby -c` nos 3 arquivos | Syntax OK | PASS |
| `Pagy::VariableError` existe e é supertipo de `OverflowError` | `bundle exec ruby -e ...` | confirmado | PASS |
| Minitest suite | `bin/rails test` | SKIP: banco de teste pertence a outro usuário do SO | SKIP (human item) |

Observação: a chamada de `bin/brakeman` (0 warnings) e os harnesses runtime foram reportados pelos planos/orquestrador; não reexecutados aqui.

### Probe Execution

Nenhum probe declarado pela fase. SKIPPED.

### Requirements Coverage

Fase aditiva, sem REQ-ID (ROADMAP: TBD). Mapeada via decisões D-01..D-13 do 32-CONTEXT.md: D-01 a D-13 todas SATISFIED (ver verdades 1-9). Sem requisitos órfãos mapeados para a fase 32 em REQUIREMENTS.md.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (nenhum) | - | grep por TBD/FIXME/XXX/TODO nos arquivos da fase: vazio | - | - |

Notas informativas do review (não bloqueiam): IN-01 `scheduled_for` sem offset é aceito e lido no fuso do app; IN-02 `Date.iso8601` aceita formatos além de `YYYY-MM-DD`; IN-03 sem teto para `whatsapp_group_ids`; IN-04 fragilidade de ENV no teste cross-client.

### Human Verification Required

#### 1. Executar a suíte Minitest em CI

**Test:** Rodar `bin/rails test` no CI (mínimo: `test/controllers/api/v1/ai/divulgacoes_controller_test.rb`, `test/controllers/api/v1/ai/clients_controller_test.rb`, `test/integration/cross_client_isolation_test.rb`).
**Expected:** Tudo verde, incluindo os casos adicionados/alterados nos fixes do review (WR-01, WR-02, WR-04, CR-01, CR-02).
**Why human:** O banco de teste local pertence a outro usuário do SO, então os casos Minitest nunca foram executados; a prova de comportamento veio de harnesses temporários já removidos.

### Known Follow-ups (não são gaps contra o goal)

- **WR-03 (cancel vs `DispatchJob` race):** `DispatchJob#perform` faz `reload`, `return if cancelada?`, `update!(em_andamento)` sem lock; um cancel que comite entre o `reload` e o `update!` pode ser sobrescrito e os envios seguem após a API responder 200 "cancelada". Correção: `divulgacao.with_lock { return if status_cancelada?; update!(status: :em_andamento) if status_agendada? }` em `app/jobs/divulgacoes/dispatch_job.rb`. Nenhuma decisão travada (D-04 exige apenas espelhar `cancelar!` como está, idempotente, 200) exige isso, e a fase é aditiva, então não é gap. Recomenda-se plano de follow-up, pois afeta a garantia prática do cancel.
- Residuais fora de escopo: `artes#index` ainda levanta 500 para `page=abc`; o admin controller tem a mesma sequência save/enqueue sem compensação.

### Gaps Summary

Nenhum gap. Todas as verdades derivadas do goal e das decisões D-01..D-13 estão implementadas, ligadas e com dados reais fluindo, o escopo é estritamente aditivo (model, jobs e rack_attack intocados) e o isolamento por cliente é feito por associação. A única pendência é executar a suíte Minitest em CI, o que não pode ser feito localmente; por isso o status é `human_needed`.

---

_Verified: 2026-11-07_
_Verifier: Claude (gsd-verifier)_
