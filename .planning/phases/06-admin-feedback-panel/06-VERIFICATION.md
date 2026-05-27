---
phase: 06-admin-feedback-panel
verified: 2026-05-27T05:00:00Z
status: gaps_found
score: 7/9 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Admin abre uma arte com status change_requested, vê o card 'Resposta interna ao comentário' e pode preencher e salvar uma nota"
    status: failed
    reason: "O formulário de admin_reply é exibido para artes change_requested, mas o before_action check_editable (linha 71 do artes_controller.rb) rejeita o PATCH para artes neste status — permite apenas pending? || revised?. A arte com status change_requested exibe o form mas ao submeter recebe 'Edição bloqueada'. O fluxo principal do PAIN-05 está quebrado."
    artifacts:
      - path: "app/controllers/admin/artes_controller.rb"
        issue: "check_editable permite only: %i[edit update] mas testa unless @arte.pending? || @arte.revised? — exclui change_requested da lista de status permitidos para update"
      - path: "app/views/admin/artes/show.html.erb"
        issue: "Formulário renderizado quando @arte.change_requested? || @arte.revised? — inclui change_requested na exibição, mas o controller bloqueia o PATCH para esse status"
      - path: "test/controllers/admin/artes_controller_test.rb"
        issue: "test_update_admin_reply usa @arte com status :pending — passa no check_editable, mas pending nunca exibe o formulário na view. O teste não cobre o caso de uso real (change_requested)"
    missing:
      - "Adicionar change_requested? à guarda check_editable: unless @arte.pending? || @arte.revised? || @arte.change_requested?"
      - "Ou criar rota + action dedicadas (update_reply) sem check_editable para salvar apenas admin_reply"
      - "Corrigir o teste update_admin_reply para usar arte com status change_requested (o único status em que o formulário aparece na UI)"

  - truth: "GET /admin?status=ARBITRARY_STRING não causa crash 500"
    status: failed
    reason: "O dashboard_controller.rb passa params[:status] direto para where(status:) sem whitelist. No Rails 8.1, strings inválidas são silenciosamente convertidas para NULL (resultam em lista vazia sem mensagem de erro ao usuário), em vez do ArgumentError documentado no REVIEW. Não é crash, mas produz resultado silencioso/enganoso sem feedback ao admin. Comportamento diferente do documentado no REVIEW, mas ainda incorreto: admin não recebe feedback que o filtro foi ignorado."
    artifacts:
      - path: "app/controllers/admin/dashboard_controller.rb"
        issue: "scope.where(status: params[:status]) sem validação — valor inválido resulta em WHERE status IS NULL em vez de filtrar pelo status digitado ou mostrar erro"
    missing:
      - "Adicionar whitelist: allowed = Arte.statuses.keys; scope = scope.where(status: params[:status]) if params[:status].present? && allowed.include?(params[:status])"
      - "Ou flash de alerta quando status não está na lista válida"
---

# Phase 06: Admin Feedback Panel — Relatório de Verificação

**Phase Goal:** Admin consegue ver todas as artes de todos os clientes num painel central com filtros, escrever resposta interna a artes com change_requested, e ver histórico de aprovações por cliente.
**Verificado:** 2026-05-27T05:00:00Z
**Status:** gaps_found
**Re-verificação:** Não — verificação inicial

---

## Verificação de Objetivo

### Truths Observáveis

| # | Truth | Status | Evidência |
|---|-------|--------|-----------|
| 1 | Admin acessa /admin e vê todas as artes de todos os clientes agrupadas por cliente, com badge de status colorido | VERIFIED | `dashboard_controller.rb` lines 3-11: `Arte.includes(:approval_responses).joins(:client).order("clients.name ASC").group_by(&:client)`; `index.html.erb` lines 34-64: iteração por cliente com tabela e `render "client/shared/arte_status_badge"` |
| 2 | Admin seleciona cliente no filtro e vê apenas artes daquele cliente via Turbo Frame sem reload | VERIFIED | `index.html.erb` line 6: `form_with ... data: { turbo_frame: "dashboard-content" }` fora do frame; `<turbo-frame id="dashboard-content">` line 30; `dashboard_controller.rb` line 7: `scope.where(client_id: params[:client_id])` |
| 3 | Admin seleciona status no filtro e vê apenas artes com aquele status | VERIFIED (com ressalva) | `dashboard_controller.rb` line 8 filtra por status, mas não valida o valor antes de passar ao enum — string inválida resulta em lista vazia sem feedback. Filtro funciona para valores válidos. |
| 4 | Cada arte no dashboard tem link "Ver" para admin_arte_path | VERIFIED | `index.html.erb` line 57: `link_to "Ver", admin_arte_path(arte), class: "btn btn-sm"` |
| 5 | GET /admin sem autenticação redireciona para login | VERIFIED | `admin/base_controller.rb` line 3: `before_action :require_authentication`; `Admin::DashboardController < Admin::BaseController` — herança garantida |
| 6 | Admin abre arte com status change_requested, vê o card de resposta interna e PODE SALVAR a nota | FAILED | View exibe o formulário (`show.html.erb` line 30: `if @arte.change_requested? || @arte.revised?`), mas `check_editable` (linha 71) bloqueia PATCH para `change_requested?` — permite apenas `pending?` ou `revised?`. A resposta é descartada silenciosamente |
| 7 | A nota admin_reply persiste e é exibida novamente ao recarregar | VERIFIED (apenas para revised?) | Campo `:admin_reply` no `arte_params` (linha 67) e `f.text_area :admin_reply, value: @arte.admin_reply` na view. Funciona para `revised?` (check_editable passa). Não funciona para `change_requested?` (bloqueado) |
| 8 | O card de resposta interna NÃO aparece para artes pending ou approved | VERIFIED | `show.html.erb` line 30: condição `@arte.change_requested? || @arte.revised?` — somente esses dois status exibem o card |
| 9 | Admin acessa página de cliente e vê card "Histórico de aprovações" com artes respondidas | VERIFIED | `clients_controller.rb` lines 9-13: `@artes_with_responses = @client.artes.joins(:approval_responses).includes(:approval_responses).distinct.order(scheduled_on: :desc)`; `clients/show.html.erb` lines 134-167: card "Histórico de aprovações" condicional com `@artes_with_responses.any?` |

**Score:** 7/9 truths verificadas

---

## Artefatos Obrigatórios

### Plano 01 (PAIN-01, PAIN-02, PAIN-03, PAIN-04)

| Artefato | Esperado | Status | Detalhes |
|----------|----------|--------|---------|
| `db/migrate/20260527025238_add_admin_reply_to_artes.rb` | Migração add_column :artes, :admin_reply, :text | VERIFIED | Arquivo existe; `add_column :artes, :admin_reply, :text` sem null constraint; `db/schema.rb` line 57 confirma `t.text "admin_reply"` |
| `app/controllers/admin/dashboard_controller.rb` | index com query filtrada e group_by | VERIFIED | 13 linhas, não stub; `group_by(&:client)`, `@clients = Client.order(:name)`, filtros por `client_id` e `status` |
| `app/views/admin/dashboard/index.html.erb` | View com filtros fora do Turbo Frame e lista agrupada dentro | VERIFIED | `turbo-frame id="dashboard-content"` line 30; form de filtros lines 6-28 fora do frame; `render "client/shared/arte_status_badge"` line 54 |
| `test/controllers/admin/dashboard_controller_test.rb` | Testes PAIN-01/02/03 com min_lines: 30 | VERIFIED | 35 linhas; 3 testes: `should get index`, `filter by client_id`, `filter by status`; todos passam |

### Plano 02 (PAIN-05)

| Artefato | Esperado | Status | Detalhes |
|----------|----------|--------|---------|
| `app/controllers/admin/artes_controller.rb` | arte_params com :admin_reply | VERIFIED | Linha 67: `:admin_reply` presente no `permit` |
| `app/views/admin/artes/show.html.erb` | Card condicional com textarea admin_reply | VERIFIED (parcialmente wired) | Existe e contém `form_with model: [:admin, @arte], method: :patch`, `f.text_area :admin_reply`, "Resposta interna ao comentário" — mas wiring quebrado para `change_requested?` (ver Truth 6) |

### Plano 03 (CLIE-05)

| Artefato | Esperado | Status | Detalhes |
|----------|----------|--------|---------|
| `app/controllers/admin/clients_controller.rb` | show com @artes_with_responses via joins+distinct | VERIFIED | Lines 9-13: `@client.artes.joins(:approval_responses).includes(:approval_responses).distinct.order(scheduled_on: :desc)` |
| `app/views/admin/clients/show.html.erb` | Terceiro card "Histórico de aprovações" | VERIFIED | Lines 134-167: card condicional com `any?`, iteração, `arte.scheduled_on.strftime`, badge de status, `admin_arte_path(arte)`, comentário em itálico |

---

## Verificação de Key Links

| De | Para | Via | Status | Detalhes |
|----|------|-----|--------|---------|
| `dashboard/index.html.erb` | `dashboard_controller.rb` | form GET com data-turbo-frame targeting dashboard-content | VERIFIED | `form_with url: admin_root_path, method: :get, data: { turbo_frame: "dashboard-content" }` (line 6) FORA da turbo-frame |
| `dashboard_controller.rb` | tabela artes via joins(:client) | `Arte.joins(:client).group_by(&:client)` | VERIFIED | Line 4: `joins(:client)`; line 10: `group_by(&:client)` |
| `artes/show.html.erb` | `artes_controller.rb#update` | `form_with model: [:admin, @arte], method: :patch` | PARTIAL — WIRED mas BLOQUEADO | Form existe e aponta para update, mas `check_editable` rejeita PATCH quando arte está `change_requested?` — o caso de uso principal do PAIN-05 |
| `clients/show.html.erb` | `clients_controller.rb` | `@artes_with_responses` renderizado no card | VERIFIED | `@artes_with_responses.any?` (line 135) e `.each do |arte|` (line 142) — controller e view conectados |
| `clients_controller.rb` | tabela approval_responses via joins | `joins(:approval_responses).distinct` | VERIFIED | Lines 10-13: joins, includes, distinct, order |

---

## Data-Flow Trace (Level 4)

| Artefato | Variável | Fonte | Produz dados reais | Status |
|----------|----------|-------|-------------------|--------|
| `dashboard/index.html.erb` | `@artes_by_client` | `Arte.joins(:client)...group_by(&:client)` no dashboard_controller | Sim — query real ao banco | FLOWING |
| `artes/show.html.erb` | `@arte.admin_reply` | `Arte.includes(:approval_responses).find(params[:id])` no set_arte | Sim — leitura real do campo; escrita bloqueada para change_requested | PARTIAL |
| `clients/show.html.erb` | `@artes_with_responses` | `@client.artes.joins(:approval_responses).includes(:approval_responses).distinct` | Sim — query real ao banco | FLOWING |

---

## Behavioral Spot-Checks

| Comportamento | Comando | Resultado | Status |
|---------------|---------|-----------|--------|
| 21 testes admin passam | `bin/rails test test/controllers/admin/` | 21 runs, 63 assertions, 0 failures, 0 errors, 0 skips | PASS |
| Dashboard controller existe e filtra | `bin/rails test test/controllers/admin/dashboard_controller_test.rb` | 3 runs, 0 failures | PASS |
| admin_reply persiste (via pending, não change_requested) | `bin/rails test test/controllers/admin/artes_controller_test.rb -n /update_admin_reply/` | 1 run, 0 failures (status pending — não o caso real de uso) | PASS (enganoso) |
| Histórico de aprovações exibe card | `bin/rails test test/controllers/admin/clients_controller_test.rb` | 7 runs, 0 failures | PASS |
| Status inválido no filtro causa crash | `bin/rails runner "Arte.where(status: 'xyz').to_sql"` | SQL OK — retorna WHERE status IS NULL (sem crash) | INFO — CR-03 do REVIEW é impreciso no Rails 8.1, mas comportamento silencioso persiste |

---

## Cobertura de Requirements

| Requirement | Plano | Descrição | Status | Evidência |
|-------------|-------|-----------|--------|-----------|
| PAIN-01 | 06-01 | Admin vê dashboard com todas as respostas de todos os clientes | SATISFIED | `dashboard_controller.rb` + `dashboard/index.html.erb` entregam painel agrupado por cliente |
| PAIN-02 | 06-01 | Admin pode filtrar o dashboard por cliente | SATISFIED | `scope.where(client_id: params[:client_id])` + select com `@clients`; Turbo Frame atualiza parcialmente |
| PAIN-03 | 06-01 | Admin pode filtrar o dashboard por status | SATISFIED (parcial) | Filtro funcional para valores válidos; strings inválidas produzem lista vazia sem feedback ao admin |
| PAIN-04 | 06-01 | Admin pode marcar arte como "Revisada" | SATISFIED | `mark_revised` action existe, rota `patch :mark_revised` no routes.rb, botão na view show condicionado a `change_requested?` |
| PAIN-05 | 06-02 | Admin pode responder ao comentário do cliente | BLOCKED | Formulário exibido para `change_requested?` mas PATCH bloqueado por `check_editable`. Só funciona para `revised?` (caso menos comum). O fluxo primário de PAIN-05 está inoperante. |
| CLIE-05 | 06-03 | Admin pode ver histórico de aprovações de um cliente específico | SATISFIED | `@artes_with_responses` com joins+distinct+order em `clients_controller#show`; card "Histórico de aprovações" renderiza título, data, badge, comentário, link "Ver" |

---

## Anti-Patterns Encontrados

| Arquivo | Linha | Padrão | Severidade | Impacto |
|---------|-------|--------|-----------|---------|
| `app/controllers/admin/artes_controller.rb` | 71 | `check_editable` não inclui `change_requested?` mas formulário admin_reply é exibido para esse status | BLOCKER | PAIN-05 quebrado para o caso de uso principal (arte com pedido de alteração do cliente) |
| `app/controllers/admin/dashboard_controller.rb` | 8 | `scope.where(status: params[:status])` sem whitelist | WARNING | Status inválido produz lista vazia silenciosa — admin não sabe que o filtro foi ignorado |
| `app/views/admin/clients/show.html.erb` | 25, 104 | `body: "...#{@client.name}..."` passado para `raw(body)` no partial `_confirm_modal.html.erb` | WARNING | XSS: se admin criar cliente com nome contendo HTML/JS, o script executa para qualquer admin que abrir os modais de desativar ou rotacionar token. Superfície interna (admin-only), mas vulnerabilidade real |
| `test/controllers/admin/artes_controller_test.rb` | 90-94 | `update_admin_reply` testa arte com status `:pending` — status que nunca exibe o formulário na UI | WARNING | Teste dá falsa confiança: passa, mas não cobre o caso de uso real (`change_requested`). Mascara o CR-02. |
| `app/controllers/admin/artes_controller.rb` | 10-12 | `@status_options` e `@platform_options` não usados em nenhuma view | INFO | Dead code — variáveis de instância sem uso na view (confirmado pelo REVIEW WR-04) |

---

## Human Verification Required

### 1. Filtro Turbo Frame — Comportamento Visual

**Test:** Abrir `/admin`, selecionar um cliente e clicar "Filtrar". Verificar que apenas o conteúdo dentro do `turbo-frame id="dashboard-content"` é substituído sem reload completo da página.
**Expected:** Barra de filtros permanece visível; lista agrupada por cliente é atualizada parcialmente.
**Why human:** Comportamento do Turbo Drive não é verificável via `bin/rails test` sem driver de browser JS.

### 2. Formulário admin_reply para arte change_requested — Bloqueio visível ao admin

**Test:** Criar uma arte, fazer uma ApprovalResponse com `decision: :change_requested`, acessar `/admin/artes/:id`, preencher o campo "Resposta interna ao comentário" e clicar "Salvar resposta".
**Expected:** Resposta salva com sucesso (se CR-02 for corrigido) OU admin vê mensagem clara de "Edição bloqueada" (comportamento atual).
**Why human:** Confirmar que o bloqueio atual do PAIN-05 é perceptível pelo admin e não é descartado silenciosamente.

---

## Resumo dos Gaps

**2 gaps bloqueando o objetivo da fase:**

**Gap 1 (BLOCKER — PAIN-05):** O formulário de resposta interna é exibido na view para artes com status `change_requested`, mas o PATCH é interceptado por `check_editable` que rejeita esse status (`unless @arte.pending? || @arte.revised?`). O caso de uso primário de PAIN-05 — admin responder ao pedido de alteração do cliente — é silenciosamente bloqueado. O teste `update_admin_reply` mascara o problema por usar arte com status `:pending` (que nunca exibe o formulário na UI real). Fix: adicionar `|| @arte.change_requested?` ao `check_editable`, ou criar route/action dedicada para `update_reply`.

**Gap 2 (WARNING — PAIN-03 parcial):** O filtro de status no dashboard não valida o valor antes de passar ao enum. No Rails 8.1, strings inválidas são silenciosamente convertidas para `WHERE status IS NULL`, retornando lista vazia sem feedback ao admin. O filtro funciona corretamente para os quatro valores válidos; o problema é a ausência de validação e feedback para valores inválidos (possível via bookmarks antigos, URL manipulada, etc).

**Nota sobre CR-01 (XSS via raw() no confirm_modal):** O `_confirm_modal.html.erb` usa `raw(body)` e o chamador em `clients/show.html.erb` interpola `@client.name` sem escapamento (`h()`). Embora a superfície seja admin-only, é uma vulnerabilidade XSS real que requer correção. Este artefato (`_confirm_modal.html.erb`) é de fase anterior (Phase 02), não desta fase — não é gap desta fase, mas deve ser corrigido.

**Nota sobre CR-03 (crash de status inválido):** O REVIEW documenta um `ArgumentError` que não ocorre no Rails 8.1.3 — o comportamento real é lista vazia silenciosa. O issue persiste como UX problem (sem feedback), mas não é crash.

---

**Commits verificados:** 9308fe2, ce9dc51, 9dc7532, 1e143de, 814e0b5 — todos existem no histórico git.
**Testes executados:** `bin/rails test test/controllers/admin/` — 21 runs, 63 assertions, 0 failures, 0 errors, 0 skips.

---

_Verified: 2026-05-27T05:00:00Z_
_Verifier: Claude (gsd-verifier)_
