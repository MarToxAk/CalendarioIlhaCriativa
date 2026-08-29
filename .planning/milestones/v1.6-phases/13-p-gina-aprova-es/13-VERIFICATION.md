---
phase: 13-p-gina-aprova-es
verified: 2026-06-04T04:09:22Z
status: human_needed
score: 15/15
overrides_applied: 0
human_verification:
  - test: "Acessar /admin/approvals com dados reais no banco e verificar filtros via Turbo Frame"
    expected: "Ao selecionar um cliente no dropdown e clicar Filtrar, apenas a tabela atualiza sem recarregar o sidebar (comportamento Turbo Frame). O link Aprovações no sidebar fica destacado (current_page? true)."
    why_human: "Comportamento de Turbo Frame (substituição parcial de DOM) e highlight do sidebar não são verificáveis via grep ou rails test — requerem browser"
  - test: "Verificar que o badge _decision_badge exibe as cores corretas visualmente (verde para Aprovado, vermelho para Pediu Alteração)"
    expected: "Badge 'Aprovado' exibe fundo verde (#F0FDF4), texto verde (#14A958). Badge 'Pediu Alteração' exibe fundo vermelho (#FEF2F2), texto vermelho (#EE3537)."
    why_human: "Fidelidade visual de cores CSS só pode ser confirmada em browser — grep confirma as classes mas não garante que o CSS está sendo compilado/aplicado corretamente pelo Tailwind"
  - test: "Verificar aparência dos cards mobile em viewport estreito (< 640px)"
    expected: "Em viewport mobile, cards aparecem (block sm:hidden) com cliente, badge de decisão, título da arte, data e comentário truncado. Tabela desktop some (hidden sm:block)."
    why_human: "Responsividade requer inspeção visual em viewport < 640px — classes Tailwind sm:hidden/sm:block não são verificáveis por grep de forma funcional"
---

# Phase 13: Página Aprovações — Relatório de Verificação

**Phase Goal:** Página Aprovações — tela administrativa que lista todas as ApprovalResponses com filtros por cliente e decisão, paginação, e visual consistente com o design system.
**Verified:** 2026-06-04T04:09:22Z
**Status:** human_needed
**Re-verification:** Não — verificação inicial

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | GET /admin/approvals retorna 200 (rota existe) | VERIFIED | `bin/rails routes` mostra `admin_approvals GET /admin/approvals(.:format) admin/approvals#index`; 8 testes passam incluindo `test_should_get_index` |
| 2 | Link "Aprovações" no sidebar aponta para admin_approvals_path, não mais "#" | VERIFIED | `_sidebar.html.erb` linha 13: `{ label: "Aprovações", path: admin_approvals_path }` — não mais `"#"` |
| 3 | Arquivo de testes do ApprovalsController existe e tem setup com dados reais | VERIFIED | `test/controllers/admin/approvals_controller_test.rb` — 8 testes com setup: User, Client, Arte, ApprovalResponse.create! reais |
| 4 | GET /admin/approvals retorna 200 com admin autenticado | VERIFIED | `test_should_get_index` — 8 runs, 0 failures, 0 errors |
| 5 | Lista ordenada por responded_at DESC | VERIFIED | `approvals_controller.rb` linha 5: `.order(responded_at: :desc)` |
| 6 | Paginação pagy retorna no máximo 25 itens por página | VERIFIED | `approvals_controller.rb` linha 13: `pagy(scope, limit: 25)` |
| 7 | Filtro por client_id retorna apenas respostas do cliente | VERIFIED | `.where(artes: { client_id: params[:client_id] })` — tabela qualificada; `test_filter_by_client_id` passa |
| 8 | Filtro por decision retorna respostas com aquela decisão | VERIFIED | `.where(decision: params[:decision])` com guarda `decisions.key?()`; `test_filter_by_decision_approved` passa |
| 9 | Filtro com decision inválida ignorado sem erro | VERIFIED | `ApprovalResponse.decisions.key?(params[:decision])` previne ArgumentError; `test_filter_by_invalid_decision` passa |
| 10 | Link para admin_arte_path disponível via @approval_responses | VERIFIED | `_approval_row.html.erb` linha 13: `link_to "Ver arte", admin_arte_path(approval_response.arte)` — `test_link_to_arte_present` passa |
| 11 | Query usa joins(arte: :client) + includes(arte: :client) sem N+1 | VERIFIED | `approvals_controller.rb` linhas 3-4: `joins(arte: :client).includes(arte: :client)` |
| 12 | Tabela exibe 6 colunas: CLIENTE, ARTE, DECISÃO, DATA DA RESPOSTA, COMENTÁRIO, AÇÕES | VERIFIED | `index.html.erb` linhas 41-46: 6 `<th>` com labels exatos; `_approval_row.html.erb` com 6 `<td>` correspondentes |
| 13 | Badge de decisão exibe "Aprovado" (verde) e "Pediu Alteração" (vermelho) | VERIFIED | `_decision_badge.html.erb`: hash config com `"approved" => {label: "Aprovado", classes: "bg-[#F0FDF4] text-[#14A958]..."}` e `"change_requested" => {label: "Pediu Alteração", classes: "bg-[#FEF2F2] text-[#EE3537]..."}` |
| 14 | Filtros FORA do turbo-frame; tabela DENTRO do turbo-frame id="approvals-content" | VERIFIED | `index.html.erb` linha 6: `form_with ... data: { turbo_frame: "approvals-content" }` (fora); linha 21: `<turbo-frame id="approvals-content">` (dentro) |
| 15 | Estado vazio exibe "Nenhuma aprovação encontrada" | VERIFIED | `index.html.erb` linha 27: `<h2>Nenhuma aprovação encontrada</h2>` com copy condicional conforme filtros ativos |

**Score:** 15/15 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `config/routes.rb` | Rota resources :approvals, only: [:index] no namespace admin | VERIFIED | Linha 19: `resources :approvals, only: [ :index ]` |
| `app/controllers/admin/base_controller.rb` | include Pagy::Backend disponível para todos os controllers admin | VERIFIED | Linha 4: `include Pagy::Backend` |
| `app/helpers/application_helper.rb` | include Pagy::Frontend disponível em todas as views | VERIFIED | Linha 2: `include Pagy::Frontend` |
| `app/views/admin/shared/_sidebar.html.erb` | Link Aprovações wired para admin_approvals_path | VERIFIED | Linha 13: `path: admin_approvals_path` |
| `test/controllers/admin/approvals_controller_test.rb` | Arquivo de testes com setup inline | VERIFIED | 8 testes; 8 runs, 20 assertions, 0 failures, 0 errors, 0 skips |
| `app/controllers/admin/approvals_controller.rb` | Admin::ApprovalsController com index paginada e filtrável | VERIFIED | 16 linhas; scope em etapas com joins+includes+order+filtros+pagy; herda de Admin::BaseController |
| `app/views/admin/approvals/index.html.erb` | View index com filtros fora do frame e tabela dentro do turbo-frame | VERIFIED | 89 linhas; turbo-frame id="approvals-content" na linha 21; form fora na linha 6 |
| `app/views/admin/approvals/_approval_row.html.erb` | Partial de linha com 6 colunas | VERIFIED | 16 linhas; 6 `<td>`: cliente, arte, badge, data (safe nav), comentário (truncate), Ver arte |
| `app/views/admin/approvals/_decision_badge.html.erb` | Badge de decisão approved=verde, change_requested=vermelho | VERIFIED | 13 linhas; hash config com 2 entradas + fallback |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_sidebar.html.erb` | `admin_approvals_path` | nav_items hash | VERIFIED | Linha 13 confirmada; `grep admin_approvals_path` retorna resultado |
| `Admin::BaseController` | `Pagy::Backend` | include | VERIFIED | Linha 4: `include Pagy::Backend` |
| `Admin::ApprovalsController#index` | `ApprovalResponse.joins(arte: :client).includes(arte: :client)` | ActiveRecord query | VERIFIED | Linhas 3-4 do controller |
| `Admin::ApprovalsController#index` | `pagy(scope, limit: 25)` | Pagy::Backend (herdado) | VERIFIED | Linha 13: `@pagy, @approval_responses = pagy(scope, limit: 25)` |
| `index.html.erb` | `turbo-frame id="approvals-content"` | form data: { turbo_frame: 'approvals-content' } | VERIFIED | Linha 6 (form fora) + linha 21 (frame dentro) — ids idênticos |
| `_approval_row.html.erb` | `admin_arte_path(approval_response.arte)` | link_to "Ver arte" | VERIFIED | Linha 13 da partial |
| `_approval_row.html.erb` | `_decision_badge.html.erb` | render "decision_badge" | VERIFIED | Linha 5: `render "decision_badge", approval_response: approval_response` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produz Dados Reais | Status |
|----------|---------------|--------|--------------------|--------|
| `index.html.erb` | `@approval_responses` | `ApprovalResponse.joins(arte: :client).includes(arte: :client).order(...).where(...)` + pagy | Query ActiveRecord real com joins | FLOWING |
| `index.html.erb` | `@clients` | `Client.order(:name)` | Query real — todos os clientes do banco | FLOWING |
| `_approval_row.html.erb` | `approval_response` | loop `@approval_responses.each` | Prop populada via ActiveRecord | FLOWING |
| `_decision_badge.html.erb` | `approval_response.decision` | campo enum do ActiveRecord | Hash config lê `decision.to_s` — não hardcoded | FLOWING |

---

### Behavioral Spot-Checks

| Comportamento | Comando | Resultado | Status |
|---------------|---------|-----------|--------|
| Suite ApprovalsController (8 testes) | `bin/rails test test/controllers/admin/approvals_controller_test.rb` | 8 runs, 20 assertions, 0 failures, 0 errors | PASS |
| Suite completa sem regressões por Fase 13 | `bin/rails test` — falhas em arquivos da Fase 13 | 0 falhas em arquivos da Fase 13 | PASS |
| Rota registrada | `bin/rails routes \| grep approvals` | `admin_approvals GET /admin/approvals(.:format) admin/approvals#index` | PASS |

**Nota sobre suite completa:** `bin/rails test` reportou 6 falhas, todas em arquivos pré-existentes não tocados pela Fase 13:
- `SessionsControllerTest` — rate-limiting 429 (pré-existente)
- `Client::SessionsControllerTest` — token nil e rate-limiting 429 (pré-existente)
- `Client::ArtesControllerTest` — redirect de sessão (pré-existente)

Nenhuma falha em arquivos criados ou modificados pela Fase 13.

---

### Requirements Coverage

| Requirement | Plano | Descrição | Status | Evidência |
|-------------|-------|-----------|--------|-----------|
| APRO-03 | 13-01 | Admin acessa "Aprovações" pelo link do sidebar (wired, não mais `#`) | SATISFIED | `_sidebar.html.erb`: `path: admin_approvals_path`; rota registrada |
| APRO-04 | 13-02 | Admin vê lista paginada de todas as respostas, ordenada pela mais recente | SATISFIED | `pagy(scope, limit: 25)` + `.order(responded_at: :desc)`; `test_should_get_index` passa |
| APRO-05 | 13-03 | Cada item exibe: cliente, arte, status, data da resposta e comentário | SATISFIED | `_approval_row.html.erb`: 6 colunas (CLIENTE, ARTE, DECISÃO, DATA, COMENTÁRIO, AÇÕES) |
| APRO-06 | 13-02 / 13-03 | Admin filtra por cliente e por status via Turbo Frame | SATISFIED (código) | Controller: `.where(artes: { client_id: })` + `.where(decision: )`; form com `data: { turbo_frame: "approvals-content" }`; comportamento Turbo Frame requer verificação humana |
| APRO-07 | 13-02 / 13-03 | Admin acessa a arte a partir de um item da lista | SATISFIED | `link_to "Ver arte", admin_arte_path(approval_response.arte)`; `test_link_to_arte_present` passa |

---

### Anti-Patterns Found

Nenhum. Varredura realizada em todos os arquivos criados/modificados pela Fase 13:
- Sem `TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`
- Sem `return null`, `return {}`, `return []`
- Sem props hardcoded com valores vazios
- Sem `console.log` (Ruby/ERB — equivalente `puts` ausente)
- View mínima do Wave 2 foi substituída completamente no Wave 3 — sem remanescentes de stub

---

### Human Verification Required

#### 1. Filtros via Turbo Frame atualizam apenas o conteúdo sem recarregar a página

**Test:** Acessar `/admin/approvals` autenticado como admin, selecionar um cliente no dropdown e clicar em "Filtrar".
**Expected:** Apenas o conteúdo da tabela (dentro do `turbo-frame id="approvals-content"`) é substituído. O sidebar, o header e a barra de filtros permanecem intactos — sem full page reload.
**Why human:** Comportamento de substituição parcial de DOM pelo Turbo Frame não é verificável via grep ou testes de integração Rails — requer browser com JavaScript habilitado.

#### 2. Highlight do link "Aprovações" no sidebar

**Test:** Acessar `/admin/approvals` autenticado como admin.
**Expected:** O link "Aprovações" no sidebar exibe o estado ativo (`bg-white/20 text-white`) porque `current_page?(admin_approvals_path)` retorna true.
**Why human:** `current_page?` em ActionView é avaliado em runtime com base no request atual — comportamento visual confirmado apenas no browser.

#### 3. Fidelidade visual dos badges de decisão

**Test:** Acessar `/admin/approvals` com registros aprovados e com pedido de alteração. Inspecionar visualmente os badges.
**Expected:** "Aprovado" exibe fundo verde claro (bg-[#F0FDF4]) com texto verde (#14A958). "Pediu Alteração" exibe fundo vermelho claro (bg-[#FEF2F2]) com texto vermelho (#EE3537).
**Why human:** Classes Tailwind com valores arbitrários (sintaxe `bg-[#hex]`) precisam estar na safelist ou referenciadas diretamente para serem incluídas no bundle CSS — verificação visual confirma compilação correta.

#### 4. Responsividade mobile (cards vs. tabela)

**Test:** Acessar `/admin/approvals` em viewport com largura < 640px (ex: DevTools mobile).
**Expected:** Cards mobile visíveis (`block sm:hidden`), tabela desktop oculta (`hidden sm:block`). Cada card mostra nome do cliente, badge, título da arte, data e comentário truncado (se houver).
**Why human:** Classes responsivas Tailwind (breakpoints `sm:`) só podem ser confirmadas visualmente em viewport correto.

---

### Gaps Summary

Nenhum gap identificado. Todos os 15 must-haves verificados com evidência direta no código.

Os 3 itens de verificação humana são sobre comportamento em browser (Turbo Frame, CSS compilado, responsividade) — não são ausências de implementação. O código necessário está completo e correto.

---

_Verified: 2026-06-04T04:09:22Z_
_Verifier: Claude (gsd-verifier)_
