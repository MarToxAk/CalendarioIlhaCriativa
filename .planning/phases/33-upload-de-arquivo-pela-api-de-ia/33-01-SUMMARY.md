---
phase: 33-upload-de-arquivo-pela-api-de-ia
plan: 01
subsystem: api
tags: [rails, active-storage, multipart, api-ai, minitest]

requires:
  - phase: 24-api-de-ia
    provides: POST /api/v1/ai/artes que recusava media_file (D-06 da fase 24)
  - phase: 32-divulga-es-na-api-de-ia
    provides: precedente de compensacao WR-04 e licao CR-02 (assert_no_enqueued_jobs em bloco)
provides:
  - POST /api/v1/ai/artes aceita o arquivo em multipart/form-data (campo media_file) e responde 201 com media_source_type "upload"
  - guard 400 bad_request para media_file que nao e upload (texto, Hash, signed blob id)
  - compensacao 503 storage_unavailable com remocao da arte orfa quando o storage falha
  - suite de integracao multipart (23 testes) com matriz de erros e isolamento por cliente
affects: [33-02 documentacao da API de IA, divulgacao de artes criadas pela IA]

actuals:
  tokens: 5061
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "rescue confinado a save! com compensacao best-effort, sem transacao (Active Storage envia em after_commit)"
    - "guard de tipo antes de Arte.new para nunca deixar o Active Storage interpretar String como signed id"

key-files:
  created: []
  modified:
    - app/controllers/api/v1/ai/artes_controller.rb
    - test/controllers/api/v1/ai/artes_controller_test.rb

key-decisions:
  - "Compensacao de falha de storage (503) entra nesta fase, no espirito do WR-04 da fase 32"
  - "Guard de media_file que nao e upload entra (T-33-01); validacao cruzada media_type x tipo do arquivo fica fora"
  - "Controller nao toca em external_url: a D-02 (arquivo + link = 422) depende da regra do model"

patterns-established:
  - "assert_rejected_without_effects: prova zero Arte/Blob/Attachment/job em toda rejeicao, sempre em forma de bloco"
  - "Multipart nos testes sem header Content-Type: o rack-test monta o boundary"

requirements-completed: []  # o plano declara requirements: [TBD]; nao ha ID real a marcar

coverage:
  - id: D1
    description: "POST multipart com arquivo real responde 201: arte pending, media_source_type upload, media_url presente, external_url nulo"
    verification:
      - kind: integration
        ref: "test/controllers/api/v1/ai/artes_controller_test.rb#POST multipart com media_file retorna 201 com upload e media_url (D-01, D-05, D-07)"
        status: pass
    human_judgment: false
  - id: D2
    description: "media_file que nao e upload (texto no JSON, Hash, campo de texto, signed id) responde 400 e nunca anexa blob existente"
    verification:
      - kind: integration
        ref: "test/controllers/api/v1/ai/artes_controller_test.rb#POST com signed id de blob existente retorna 400 e nao anexa o blob (T-33-01)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Falha de storage responde 503 storage_unavailable, remove a arte e o retry cria exatamente uma arte"
    verification:
      - kind: integration
        ref: "test/controllers/api/v1/ai/artes_controller_test.rb#POST multipart com falha de storage responde 503 e nao deixa arte orfa (T-33-05)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Arquivo+link, PDF disfarcado, 50MB+1 e caption_only sem midia respondem 422 sem nenhum efeito persistido"
    verification:
      - kind: integration
        ref: "test/controllers/api/v1/ai/artes_controller_test.rb (D-02, D-06, D-08, D-10, D-04)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Artes criadas por upload e aprovadas aparecem em GET /artes somente sob o client_id do proprio cliente"
    verification:
      - kind: integration
        ref: "test/controllers/api/v1/ai/artes_controller_test.rb#GET lista artes criadas por upload somente sob o client_id do proprio cliente (D-12)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-11-08
status: complete
commits: 4
plan_head_before: 2dc8057b30f94e4dac494c706a2451639e5ad517
plan_head_after: 1dce352bbb6887f6890decbe8b2cc4c7213c6b29
---

# Phase 33 Plan 01: Upload de arquivo pela API de IA Summary

**POST /api/v1/ai/artes aceita media_file em multipart (201 upload), recusa com 400 qualquer valor que nao seja arquivo e compensa falha de storage com 503 sem arte orfa, sem mudar model, serializer nem dependencias.**

## Performance

- **Duration:** 25 min
- **Completed:** 2026-11-08
- **Tasks:** 3 (1 tracer, 1 TDD, 1 auto)
- **Files modified:** 2 (nenhum model, serializer, initializer, migracao ou gem)

## Accomplishments

- Removida a recusa de upload (reversao da D-06 da fase 24 so para o arquivo); `:media_file` entrou no `permit` e a arte nasce `pending`, com `media_url` e `media_source_type` "upload" vindos do serializer existente.
- Guard `media_file_param_invalid?` (T-33-01): so `ActionDispatch::Http::UploadedFile` passa; String, Hash e signed id viram 400 `bad_request` antes de `Arte.new`, entao o Active Storage nunca trata uma String como signed blob id. Valor em branco segue como ausente.
- Compensacao T-33-05: `rescue` confinado a `@arte.save!`; `RecordInvalid` e relancado ao 422 do base controller; qualquer outro erro com arte persistida e anexo apaga a arte (best-effort, log `[ai/artes#create]`) e responde 503 `storage_unavailable`. Erros sem essa assinatura sao relancados.
- Comentario de contrato no topo do controller (D-01, D-02, D-03, D-05, D-08, 400 e 503).
- 12 testes novos (de 11 para 23): caminho feliz, guard (JSON, Hash, formulario, signed id), 503 + retry, arquivo+link, PDF disfarcado, 50MB+1, caption_only, 401, client inexistente e isolamento D-12.

## Task Commits

1. **Task 1: tracer multipart 201 + guard 400** - `5cbfe85` (feat)
2. **Task 2: compensacao 503 (TDD)** - RED `c871149` (test), GREEN `debafc7` (feat)
3. **Task 3: matriz de erros e isolamento** - `1dce352` (test)

Tracer feedback gate: verify automatizado re-executado ao fim da Task 1 (12 runs, 0 falhas) e expansao liberada.

## Verification

Receita local do plano (`bash tmp/ai_upload_test.sh ...`; `bin/rails test` nao roda aqui, o CI e a autoridade):

- `artes_controller_test.rb`: baseline em HEAD 11 runs, 0 falhas; final **23 runs, 125 assertions, 0 failures, 0 errors, 0 skips** (piso 22).
- Suites adjacentes (divulgacoes de IA, admin artes, model arte): 65 runs, 327 assertions, 0 failures, 0 errors.
- `bin/rubocop` nos dois arquivos: sem ofensas.
- `git diff --name-only 3184e92 -- app config db lib Gemfile Gemfile.lock` lista so `app/controllers/api/v1/ai/artes_controller.rb`.
- Gates grep: recusa "nao e suportado" = 0 fora de comentario; `UploadedFile` >= 1; `storage_unavailable` = 2; `service_unavailable` = 1; 6 testes com `(D-NN`; `awk` do `assert_no_enqueued_jobs` em bloco passa.
- Nao executado localmente: a suite completa (so o CI).

## Deviations from Plan

None - plan executed exactly as written.

A Task 2 foi commitada em dois passos (RED e GREEN) por seguir o fluxo TDD, em vez de um commit unico; nao muda o resultado.

## Issues Encountered

None. `requirements: [TBD]` no frontmatter do plano nao e um ID de requisito real; `requirements mark-complete` foi ignorado por isso.

## Known Stubs

None.

## Threat Flags

None - nenhuma superficie nova alem das mapeadas em T-33-01 a T-33-08.

## Next Phase Readiness

Pronto para o 33-02 (documentacao D-11). Pontos para a documentacao: `media_url` e presigned e expira (T-33-07), teto de body do proxy e human-check (T-33-03), `external_url` sozinho continua aceito mas nao e divulgavel (D-03).

## Self-Check: PASSED

- Arquivos modificados existem; commits `5cbfe85`, `c871149`, `debafc7`, `1dce352` sao ancestrais de HEAD; criterios de aceitacao das 3 tasks re-executados e verdes.
