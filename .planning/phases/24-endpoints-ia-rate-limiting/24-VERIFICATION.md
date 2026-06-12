---
phase: 24-endpoints-ia-rate-limiting
verified: 2026-06-12T22:00:00Z
status: gaps_found
score: 6/10 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Throttle api/ai_by_key aplicado somente a requests para /api/v1/ai/*"
    status: failed
    reason: "Rack::Attack NÃO está registrado no middleware stack. O initializer configura regras mas config.middleware.use Rack::Attack nunca é chamado em application.rb, production.rb, development.rb ou qualquer initializer. As regras de throttle são completamente inativas em produção."
    artifacts:
      - path: "config/initializers/rack_attack.rb"
        issue: "Configura throttle api/ai_by_key mas o middleware não está no stack"
      - path: "config/application.rb"
        issue: "Sem config.middleware.use Rack::Attack — ausência confirmada por grep exaustivo"
    missing:
      - "Adicionar config.middleware.use Rack::Attack em config/application.rb (dentro do bloco class Application)"

  - truth: "GET /api/v1/ai/clients/:id/summary retorna {total, approved_count, pending_count, change_requested_count, revised_count}"
    status: failed
    reason: "Bug lógico: Arte.group(:status).count retorna chaves inteiras (0,1,2,3) pois a coluna status é integer no schema. O controller acessa o hash com chaves string counts['approved'], counts['pending'] etc., que sempre retornam nil. Todos os campos individuais retornam sempre 0. Apenas total está correto (counts.values.sum soma inteiros). Confirmado: schema.rb mostra t.integer 'status'; enum { pending: 0, approved: 1, change_requested: 2, revised: 3 }."
    artifacts:
      - path: "app/controllers/api/v1/ai/clients_controller.rb"
        issue: "Linhas 11-14: counts['approved'].to_i, counts['pending'].to_i, etc. acessam hash com chaves inteiras usando chaves string — sempre retornam 0"
    missing:
      - "Usar Arte.statuses['approved'] como chave: counts[Arte.statuses['approved']].to_i"
      - "Ou substituir por escopos separados: base.approved.count, base.pending.count, etc."

  - truth: "Throttle AI: 60 requests passam, 61ª retorna 429 JSON estruturado com code: too_many_requests"
    status: failed
    reason: "Derivado do gap CR-02: sem config.middleware.use Rack::Attack o throttle nunca é ativado. Os testes que verificam 429 passariam (ou falhariam) em função do estado do middleware stack no ambiente de teste, mas o comportamento em produção é ausente de proteção."
    artifacts:
      - path: "test/integration/rack_attack_test.rb"
        issue: "Testes dependem do middleware estar registrado — sem o registro, os testes de throttle podem não refletir comportamento de produção"
    missing:
      - "Registrar Rack::Attack no middleware stack (bloqueia este e o gap anterior)"

  - truth: "GET /summary counts são corretos (assert total=3, approved_count=2, pending_count=1)"
    status: failed
    reason: "O teste clients_controller_test.rb:106-108 asserta approved_count=2 e pending_count=1, mas a implementação retorna 0 para ambos devido ao bug de chave inteira/string (CR-01). O teste falha silenciosamente se o banco de teste não for executado (conforme nota do executor: bin/rails test não roda por restrição de usuário do SO). Sem execução real dos testes, o bug não foi detectado."
    artifacts:
      - path: "test/controllers/api/v1/ai/clients_controller_test.rb"
        issue: "Linhas 106-108: assertions que falham na implementação atual (approved_count seria 0, não 2)"
    missing:
      - "Corrigir ClientsController#summary (fix do CR-01) — este gap se fecha junto"
---

# Phase 24: Endpoints IA + Rate Limiting — Relatório de Verificação

**Phase Goal:** Criar endpoints REST para o agente de IA consumir artes aprovadas e sumário de clientes, com rate limiting por API key.
**Verified:** 2026-06-12T22:00:00Z
**Status:** GAPS_FOUND
**Re-verification:** Não — verificação inicial

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Ai::BaseController inclui Pagy::Backend, set_active_storage_current e pagination_meta | VERIFIED | base_controller.rb linhas 4-6, 41-57: include Pagy::Backend, before_action :set_active_storage_current, rescue_from Pagy::OverflowError, métodos privados pagination_meta/per_page_param/page_overflow presentes |
| 2 | Api::V1::Ai::ArteSerializer.serialize(arte) retorna hash com chave media_url | VERIFIED | arte_serializer.rb linha 15: media_url: resolve_media_url(arte); serialize e serialize_collection definidos; private_class_method resolve_media_url presente |
| 3 | Throttle api/ai_by_key aplicado somente a requests para /api/v1/ai/* | FAILED | rack_attack.rb configura o throttle (linha 30-34) mas config.middleware.use Rack::Attack AUSENTE em application.rb e todos os arquivos de ambiente — throttle completamente inativo em produção (CR-02) |
| 4 | Rotas GET /api/v1/ai/artes, POST /api/v1/ai/artes e GET /api/v1/ai/clients/:id/summary existem | VERIFIED | routes.rb linhas 54-59: namespace :ai com resources :artes only: [:index, :create] e resources :clients com get :summary on: :member |
| 5 | GET /api/v1/ai/artes?from=&to= retorna somente artes approved ordenadas por scheduled_on asc | VERIFIED | artes_controller.rb linha 8: Arte.approved.order(scheduled_on: :asc); scope confirmed |
| 6 | GET /api/v1/ai/artes sem from ou to retorna 400 estruturado | VERIFIED | artes_controller.rb linha 6: raise ActionController::ParameterMissing.new("from e to são obrigatórios") quando params ausentes; rescue_from herdado de BaseController retorna 400 |
| 7 | POST /api/v1/ai/artes com media_file retorna 400; com external_url retorna 201 | VERIFIED | artes_controller.rb linhas 32-35: guard media_file → render_error 400; linhas 37-39: Arte.new(arte_params).save! → render_envelope status: :created |
| 8 | GET /api/v1/ai/clients/:id/summary retorna {total, approved_count, pending_count, change_requested_count, revised_count} | FAILED | Bug CR-01: group(:status).count retorna chaves inteiras ({0=>N, 1=>N}); controller acessa com chaves string ("approved", "pending") que retornam nil → .to_i → 0. Todos os campos individuais sempre zero. Schema confirma: t.integer "status". |
| 9 | GET /api/v1/ai/clients/0/summary retorna 404 estruturado | VERIFIED | clients_controller.rb linha 6: Client.find(params[:id]) levanta RecordNotFound; rescue_from herdado retorna 404 com code: not_found |
| 10 | Throttle AI: 60 requests passam, 61ª retorna 429 JSON estruturado com code: too_many_requests | FAILED | Derivado de CR-02: sem middleware registrado o throttle não está ativo. Testes escritos corretamente mas não podem confirmar comportamento de produção. |

**Score: 6/10 truths verified**

---

### Deferred Items

Nenhum item identificado como endereçado em fases posteriores.

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/controllers/api/v1/ai/base_controller.rb` | Base controller com Pagy e helpers | VERIFIED | 57 linhas; include Pagy::Backend, set_active_storage_current, pagination_meta, per_page_param, page_overflow — todos presentes |
| `app/serializers/api/v1/ai/arte_serializer.rb` | Serializer PORO com serialize e serialize_collection | VERIFIED | 33 linhas; module Api::V1::Ai::ArteSerializer; self.serialize retorna 14 campos incluindo media_url; serialize_collection e resolve_media_url presentes |
| `config/initializers/rack_attack.rb` | Throttle 60 req/min por API key no namespace AI | STUB/PARTIAL | Throttle configurado mas middleware NÃO registrado no stack — regras ativas em testes (MemoryStore) mas ausentes em produção |
| `config/routes.rb` | Rotas do namespace :ai com resources :artes e summary de clients | VERIFIED | Linhas 54-59: namespace :ai completo com 3 rotas corretas |
| `app/controllers/api/v1/ai/artes_controller.rb` | index (APIAI-01) e create (APIAI-02) | VERIFIED | 50 linhas; Arte.approved, período obrigatório, guard media_file, arte_params sem :media_file/:status |
| `app/controllers/api/v1/ai/clients_controller.rb` | summary (APIAI-03) | STUB | Arquivo existe e estrutura correta, mas implementação retorna contadores incorretos (bug chave inteira/string em group(:status).count) |
| `test/controllers/api/v1/ai/artes_controller_test.rb` | Testes para APIAI-01 e APIAI-02 | VERIFIED (estrutura) | 209 linhas, 11 testes cobrindo casos especificados; NÃO executados por restrição de banco de testes |
| `test/controllers/api/v1/ai/clients_controller_test.rb` | Testes para APIAI-03 | PARTIAL | 143 linhas, 5 testes; o teste "counts são corretos" falha em execução real devido ao bug CR-01 |
| `test/integration/rack_attack_test.rb` | Testes de throttle para INFAPI-04 | PARTIAL | 4 testes AI adicionados corretamente; NÃO confirmam proteção em produção pois o middleware não está registrado |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| artes_controller.rb | arte_serializer.rb | Api::V1::Ai::ArteSerializer.serialize_collection | WIRED | Linha 25: Api::V1::Ai::ArteSerializer.serialize_collection(@artes) — importação por namespace, não require |
| artes_controller.rb | arte.rb | Arte.approved scope + scheduled_on range | WIRED | Linha 8: Arte.approved.order(scheduled_on: :asc) |
| clients_controller.rb | arte.rb | Arte.where(client_id:).group(:status).count | PARTIAL | Query existe (linha 8) mas resultado mal interpretado — chaves inteiras acessadas como strings |
| Rack::Attack middleware | rack_attack.rb | throttle("api/ai_by_key") | NOT_WIRED | config/application.rb não contém config.middleware.use Rack::Attack; grep exaustivo em config/ confirma ausência total |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| artes_controller.rb#index | @artes | Arte.approved.order(...).where(scheduled_on:) + pagy | Sim — query ActiveRecord real | FLOWING |
| artes_controller.rb#create | @arte | Arte.new(arte_params).save! | Sim — inserção real no banco | FLOWING |
| clients_controller.rb#summary | counts | Arte.group(:status).count | Query real mas resultado interpretado incorretamente — chaves inteiras vs string | HOLLOW — total correto, contadores individuais sempre 0 |

---

### Behavioral Spot-Checks

Testes não podem ser executados via bin/rails test (banco de teste pertence a outro usuário do SO — restrição documentada no projeto). Verificação feita por inspeção estática.

| Behavior | Método de Verificação | Resultado | Status |
|----------|-----------------------|-----------|--------|
| Rota GET /api/v1/ai/artes existe | Leitura config/routes.rb linhas 54-59 | 3 rotas confirmadas | PASS |
| Throttle registrado no middleware | grep config/ para Rack::Attack | AUSENTE em todos os arquivos de config | FAIL |
| group(:status).count retorna inteiros | Comparação arte.rb enum + schema.rb t.integer "status" | enum { pending: 0, approved: 1, ... } + coluna integer = chaves inteiras | FAIL (bug CR-01) |

---

### Requirements Coverage

| Requisito | Plano | Descrição | Status | Evidência |
|-----------|-------|-----------|--------|-----------|
| APIAI-01 | 24-01, 24-02, 24-03 | IA lista artes aprovadas com filtros de período | SATISFIED | ArtesController#index com Arte.approved, período obrigatório, paginação, serialização — implementado e testado |
| APIAI-02 | 24-01, 24-02, 24-03 | IA insere nova arte para aprovação | SATISFIED | ArtesController#create com guard media_file, arte_params sem :status, retorna 201 — implementado e testado |
| APIAI-03 | 24-01, 24-02, 24-03 | IA lê resumo do estado por cliente | BLOCKED | ClientsController#summary existe mas contadores individuais sempre retornam 0 (bug CR-01 — chaves inteiras vs string) |
| INFAPI-04 | 24-01, 24-03 | Rate limiting por API key/token | BLOCKED | Throttle configurado mas Rack::Attack não registrado no middleware stack — rate limiting completamente inativo em produção (CR-02) |

---

### Anti-Patterns Found

| Arquivo | Linha | Padrão | Severidade | Impacto |
|---------|-------|--------|------------|---------|
| app/controllers/api/v1/ai/clients_controller.rb | 11-14 | counts["approved"].to_i com hash de chaves inteiras | BLOCKER | Todos os contadores individuais retornam 0 — APIAI-03 falha silenciosamente |
| config/application.rb | (ausência) | config.middleware.use Rack::Attack ausente | BLOCKER | Rate limiting completamente inativo — INFAPI-04 não entregue |
| config/application.rb | 32 | CORS origins com default wildcard "*" | WARNING | Pré-existente (não introduzido nesta fase); relevante em produção se CORS_ORIGINS não for definido |
| test/integration/rack_attack_test.rb | 1 | Ausência de # frozen_string_literal: true | INFO | Inconsistência estética; sem impacto funcional |

---

### Human Verification Required

Nenhum item requer verificação humana — os dois blockers são verificáveis por inspeção estática e foram confirmados por grep direto no código.

---

## Gaps Summary

Dois blockers impedem o atingimento do objetivo da fase:

**BLOCKER 1 — INFAPI-04 não entregue (CR-02):** `config.middleware.use Rack::Attack` está ausente em toda a árvore de configuração. O initializer `config/initializers/rack_attack.rb` configura corretamente as regras de throttle, mas o Rails não carrega gems de middleware automaticamente — é necessário registro explícito. Sem o registro, nenhuma das regras de throttle (incluindo a nova `api/ai_by_key`) intercepta qualquer requisição em produção. Fix: adicionar `config.middleware.use Rack::Attack` dentro do bloco `class Application` em `config/application.rb`.

**BLOCKER 2 — APIAI-03 com contadores zerados (CR-01):** `Arte.group(:status).count` com coluna de tipo `integer` no banco retorna hash com chaves inteiras (`{0=>N, 1=>N, 2=>N, 3=>N}`). O controller acessa com chaves string (`counts["approved"]` etc.) que retornam `nil`, e `.to_i` converte para `0`. O campo `total` é correto (`.values.sum` funciona independentemente do tipo de chave), mas todos os quatro campos de contagem individual são sempre `0`. Fix: usar `counts[Arte.statuses["approved"]].to_i` (chave inteira do enum), ou substituir por escopos separados (`base.approved.count`, `base.pending.count`, etc.).

Os dois problemas foram identificados no code review (24-REVIEW.md como CR-01 e CR-02) mas não foram corrigidos antes da submissão para verificação.

**Truths verificadas:** APIAI-01 (listagem de artes aprovadas), APIAI-02 (criação de arte), rotas, BaseController expandido, ArteSerializer PORO — todos corretos e bem implementados.

---

_Verificado: 2026-06-12T22:00:00Z_
_Verificador: Claude (gsd-verifier)_
