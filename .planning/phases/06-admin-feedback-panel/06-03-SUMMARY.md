---
phase: 06-admin-feedback-panel
plan: "03"
subsystem: admin
tags:
  - rails
  - activerecord
  - joins
  - distinct
  - eager-loading
  - history

dependency_graph:
  requires:
    - "06-01: admin-dashboard (test_show_inclui_historico_de_aprovacoes stub criado)"
    - "05: approval-flow (approval_responses table, ApprovalResponse model)"
    - "02: admin-auth-client-management (Admin::ClientsController, Admin::BaseController)"
  provides:
    - "ClientsController#show com @artes_with_responses (joins + distinct + order)"
    - "Terceiro card 'Histórico de aprovações' em admin/clients/show.html.erb"
    - "Condicional @artes_with_responses.any? — card ausente quando cliente sem respostas"
  affects:
    - "app/controllers/admin/clients_controller.rb"
    - "app/views/admin/clients/show.html.erb"

tech_stack:
  added: []
  patterns:
    - "@client.artes.joins(:approval_responses).includes(:approval_responses).distinct — eager loading sem N+1, sem duplicatas"
    - "sort_by(&:created_at).last em Ruby sobre array já loaded (evita nova query em includes)"
    - "Condicional @artes_with_responses.any? para card vazio invisível"

key_files:
  created: []
  modified:
    - app/controllers/admin/clients_controller.rb
    - app/views/admin/clients/show.html.erb
    - test/controllers/admin/clients_controller_test.rb

key-decisions:
  - "joins + includes + distinct — joins para filtrar (somente artes com respostas), includes para eager load ao renderizar comentários, distinct para evitar duplicatas (Pitfall 5)"
  - "sort_by(&:created_at).last em Ruby em vez de .order() na associação — evita re-query quando includes já carregou os registros"
  - "Card condicional: @artes_with_responses.any? — cliente sem artes respondidas não vê o card, eliminando empty state desnecessário"

patterns-established:
  - "Escopo por associação: @client.artes em vez de Arte.where(client_id: ...) — respeita isolamento por cliente"
  - "TDD: teste com asserção fraca (assert_response :success) reforçado para assert_includes response.body com dados reais"

requirements-completed:
  - CLIE-05

duration: ~10min
completed: "2026-05-27"
---

# Phase 06 Plan 03: Histórico de Aprovações na Página do Cliente Summary

**Card "Histórico de aprovações" em admin/clients/show com query joins+distinct, badge de status e comentários em itálico — CLIE-05 implementado.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-05-27T03:00:00Z
- **Completed:** 2026-05-27T03:08:50Z
- **Tasks:** 2 (implementadas em um commit conjunto pois view era necessária para o teste GREEN)
- **Files modified:** 3

## Accomplishments

- `ClientsController#show` expandido com `@artes_with_responses` via joins + includes + distinct + order(scheduled_on: :desc)
- Terceiro card "Histórico de aprovações" adicionado em `admin/clients/show.html.erb` com condicional `any?`
- Cada item mostra: título da arte, data DD/MM/AAAA, badge de status (partial reutilizada), comentário do último pedido em itálico, link "Ver" para `admin_arte_path`
- Teste `test_show_inclui_historico_de_aprovacoes` reforçado com `assert_includes response.body, "Arte com Resposta"` e `assert_includes response.body, "Histórico de aprovações"`
- 7 testes do clients_controller: 0 failures, 0 errors

## Task Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1+2 | 814e0b5 | feat | ClientsController#show + card histórico + teste reforçado |

## Files Created/Modified

- `app/controllers/admin/clients_controller.rb` — action show expandida com @artes_with_responses (joins + includes + distinct + order)
- `app/views/admin/clients/show.html.erb` — terceiro card "Histórico de aprovações" com iteração, badges, comentários, links
- `test/controllers/admin/clients_controller_test.rb` — teste reforçado com assert_includes para título e card

## Decisions Made

- **joins + includes + distinct combinados:** `joins(:approval_responses)` filtra artes sem nenhuma resposta; `includes(:approval_responses)` garante eager loading para evitar N+1 ao renderizar comentários; `.distinct` evita duplicatas quando a arte tem múltiplas respostas (Pitfall 5 do RESEARCH.md)
- **sort_by em Ruby:** Para pegar o comentário mais recente, usou `arte.approval_responses.sort_by(&:created_at).last` sobre o array já carregado pelo includes — evita nova query SQL que `.order()` na associação causaria
- **Card condicional:** `@artes_with_responses.any?` garante que clientes sem artes respondidas não vejam um card vazio

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] Worktree sem .bundle/config e sem .env**
- **Found during:** Task 1 — ao tentar rodar testes
- **Issue:** Worktree não herdou `.bundle/config` (BUNDLE_PATH: vendor/bundle) nem o arquivo `.env` com credenciais do PostgreSQL — mesmo problema do Plano 01
- **Fix:** Criado `.bundle/config` apontando para `/home/bot/calendario_livia/vendor/bundle`; criado symlink `.env -> /home/bot/calendario_livia/.env`
- **Files modified:** .bundle/config (worktree-local), .env (symlink)
- **Verification:** `bin/rails test` executou com sucesso após a correção

**2. [Rule 1 - Interdependência] Task 1 e Task 2 implementadas em um commit conjunto**
- **Found during:** Task 1 — o teste GREEN exigia que a view renderizasse o card para `assert_includes response.body, "Histórico de aprovações"` passar
- **Issue:** O plano previa dois commits separados (Task 1 = controller, Task 2 = view), mas o teste reforçado da Task 1 verificava o conteúdo da view
- **Fix:** Implementadas controller + view + teste em um único commit, garantindo que o GREEN ficou coeso
- **Files modified:** todos os 3 arquivos no mesmo commit 814e0b5

---

**Total deviations:** 2 auto-fixed (1 blocker de infraestrutura, 1 interdependência de task)
**Impact on plan:** Sem scope creep — todos os critérios de aceitação atendidos exatamente como especificado.

## Issues Encountered

Nenhum além do bloqueador de infraestrutura já documentado (worktree sem .bundle/config — recorrente em todos os agentes da fase 06).

## Known Stubs

Nenhum — todos os dados são carregados de banco real via query; badge de status usa partial existente; comentário é conteúdo real do usuário.

## Threat Flags

Nenhuma superfície nova fora do threat model do plano:
- T-06-06 (auth): Admin::BaseController herda require_authentication — coberto
- T-06-07 (escopo): Query usa `@client.artes` (scoped por associação) — implementado corretamente
- T-06-08 (XSS): Todos os campos renderizados via `<%= %>` (escape automático do Rails) — sem `raw()` ou `html_safe`

## Self-Check: PASSED

- [x] `app/controllers/admin/clients_controller.rb` contém `@artes_with_responses`
- [x] `app/controllers/admin/clients_controller.rb` contém `.joins(:approval_responses)`
- [x] `app/controllers/admin/clients_controller.rb` contém `.distinct`
- [x] `app/controllers/admin/clients_controller.rb` contém `.order(scheduled_on: :desc)`
- [x] `app/views/admin/clients/show.html.erb` contém "Histórico de aprovações"
- [x] `app/views/admin/clients/show.html.erb` contém `@artes_with_responses.any?`
- [x] `app/views/admin/clients/show.html.erb` contém `@artes_with_responses.each do |arte|`
- [x] `app/views/admin/clients/show.html.erb` contém `render "client/shared/arte_status_badge", arte: arte, compact: true`
- [x] `app/views/admin/clients/show.html.erb` contém `admin_arte_path(arte)`
- [x] `app/views/admin/clients/show.html.erb` contém `arte.scheduled_on.strftime`
- [x] Commit 814e0b5 existe no histórico
- [x] 7 testes do clients_controller: 0 failures, 0 errors

## Next Phase Readiness

- CLIE-05 implementado: admin pode ver histórico completo de aprovações de cada cliente
- Fase 06 completa após os planos do wave 2 (06-02 e 06-03) serem integrados
- Não há stubs ou itens pendentes neste plano

---
*Phase: 06-admin-feedback-panel*
*Completed: 2026-05-27*
