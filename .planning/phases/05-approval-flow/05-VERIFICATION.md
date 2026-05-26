---
phase: 05-approval-flow
verified: 2026-05-26T12:00:00Z
status: human_needed
score: 13/13 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Abrir portal do cliente em uma arte pendente e clicar em Aprovar"
    expected: "Página recarrega com flash 'Arte aprovada!' e badge de status muda para Aprovado; botões Aprovar e Pedir Alteração desaparecem"
    why_human: "Comportamento visual e Turbo redirect não são verificáveis com grep"
  - test: "Abrir portal do cliente em arte pendente, clicar em Pedir Alteração e verificar toggle do formulário"
    expected: "Formulário de textarea expande inline sem reload da página (Stimulus toggle CSS hidden)"
    why_human: "Comportamento JavaScript/Stimulus não é verificável estaticamente"
  - test: "Abrir admin show de uma arte com status change_requested"
    expected: "Botão 'Marcar como Revisada' aparece; para arte pending/approved/revised o botão não aparece"
    why_human: "Renderização condicional da view depende de estado de banco em ambiente real"
  - test: "Admin clica 'Marcar como Revisada' em arte change_requested, depois cliente aprova"
    expected: "Arte vai para revised, cliente vê botões novamente e pode aprovar — ciclo APRO-03 completo no browser"
    why_human: "Ciclo completo multi-actor requer interação real entre admin e cliente"
  - test: "Verificar seção 'Histórico de respostas' em arte com respostas múltiplas"
    expected: "Respostas aparecem em ordem cronológica reversa com ícone correto (verde para aprovado, vermelho para pediu alteração) e comentário quando presente"
    why_human: "Renderização visual da lista não é verificável estaticamente"
---

# Phase 05: Approval Flow — Verification Report

**Phase Goal:** Implementar o fluxo completo de aprovação de artes — o cliente aprova ou pede alteração via portal, o admin marca como revisada, e o histórico de decisões é preservado.
**Verified:** 2026-05-26T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Uma arte pode ter múltiplas ApprovalResponses sem erro de unicidade | VERIFIED | `db/schema.rb` linha 52: índice `index_approval_responses_on_arte_id` sem `unique: true`; migração `20260526000001` executada |
| 2 | ApprovalResponse.create! aceita arte com status pending OU revised | VERIFIED | `app/models/approval_response.rb` linha 14: `unless arte.pending? \|\| arte.revised?`; 5 testes TDD verdes |
| 3 | Arte.first.approval_responses responde sem NoMethodError | VERIFIED | `app/models/arte.rb` linha 3: `has_many :approval_responses, -> { order(created_at: :desc) }, dependent: :destroy`; Test 3 do approval_response_test.rb confirma CollectionProxy |
| 4 | Admin::ArtesController#check_deletable usa approval_responses.none? | VERIFIED | `app/controllers/admin/artes_controller.rb` linha 77: `@arte.approval_responses.none?` |
| 5 | Rota PATCH /admin/artes/:id/mark_revised existe sem duplicação | VERIFIED | `bin/rails routes` mostra `mark_revised_admin_arte PATCH /admin/artes/:id/mark_revised` — uma única entrada |
| 6 | Cliente clica Aprovar em arte pendente e é redirecionado com flash 'Arte aprovada!' e status Aprovado | VERIFIED (code) | `Client::ResponsesController#create` com `flash_notice_for`; Test 1 do responses_controller_test.rb passa |
| 7 | Cliente clica Pedir Alteração, textarea expande inline sem reload, submit salva comentário e redireciona com flash | VERIFIED (code) | `approval_controller.js` com `toggleComment`; Test 2 e 3 do responses_controller_test.rb passam; toggle visual requer human check |
| 8 | Botões Aprovar e Pedir Alteração ficam OCULTOS para artes approved ou change_requested | VERIFIED | `show.html.erb` linha 106: `<% if @arte.pending? \|\| @arte.revised? %>` envolve toda a seção de botões |
| 9 | Histórico de respostas aparece abaixo dos botões em ordem cronológica reversa | VERIFIED (code) | `show.html.erb` linhas 143-165: seção histórico fora do guard de botões; scope `order(created_at: :desc)` no model |
| 10 | POST /c/:token/artes/:arte_id/responses de cliente não autenticado redireciona para login | VERIFIED | Test 6 do responses_controller_test.rb: `assert_redirected_to new_client_session_path` |
| 11 | POST com arte de outro cliente retorna 302 para o calendário (IDOR bloqueado) | VERIFIED | `set_arte` usa `@client.artes.find(params[:arte_id])` com rescue `RecordNotFound`; Test 5 passa |
| 12 | Admin vê botão 'Marcar como Revisada' condicional a change_requested? | VERIFIED | `admin/artes/show.html.erb` linhas 19-25: `<% if @arte.change_requested? %>` envolve `button_to mark_revised_admin_arte_path` |
| 13 | Após mark_revised, cliente consegue aprovar a arte novamente (validator aceita revised?) | VERIFIED | Test `ciclo completo APRO-03` no admin controller test confirma o ciclo; suite 75 testes verdes |

**Score:** 13/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/20260526000001_allow_multiple_approval_responses.rb` | Remove unique index em approval_responses.arte_id | VERIFIED | Arquivo existe; db/schema.rb mostra índice sem `unique: true` |
| `app/models/arte.rb` | has_many :approval_responses | VERIFIED | Linha 3: `has_many :approval_responses, -> { order(created_at: :desc) }, dependent: :destroy` |
| `app/models/approval_response.rb` | Validator aceita pending? \|\| revised? | VERIFIED | Linha 14: `unless arte.pending? \|\| arte.revised?` |
| `app/controllers/admin/artes_controller.rb` | check_deletable usa approval_responses.none? + mark_revised action | VERIFIED | Linha 77: `approval_responses.none?`; linhas 47-54: action `mark_revised` completa |
| `config/routes.rb` | Único bloco admin artes com member mark_revised + rota client responses | VERIFIED | Um único `namespace :admin` com `resources :artes` + `member { patch :mark_revised }` |
| `app/controllers/client/responses_controller.rb` | Client::ResponsesController#create com escopo @client.artes.find | VERIFIED | Linha 18: `@client.artes.find(params[:arte_id])` — nunca Arte.find direto |
| `app/views/client/artes/show.html.erb` | Botões condicionais + formulário inline + seção histórico | VERIFIED | Guard `pending? \|\| revised?` para botões (linha 106); histórico sempre visível (linha 143) |
| `app/javascript/controllers/approval_controller.js` | Stimulus toggle para formulário de comentário | VERIFIED | `static targets = ["commentForm"]`; `toggleComment()` e `hideComment()` implementados |
| `app/views/admin/artes/show.html.erb` | Botão mark_revised condicional ao status change_requested | VERIFIED | Linha 19: `if @arte.change_requested?`; linha 21: `mark_revised_admin_arte_path(@arte)` |
| `test/models/approval_response_test.rb` | 5 testes TDD para has_many + validator | VERIFIED | Arquivo existe com 5 testes cobrindo todos os behaviors do plano |
| `test/controllers/client/responses_controller_test.rb` | 6 testes de integração incluindo IDOR | VERIFIED | 6 testes cobrindo APRO-01, APRO-02, APRO-05, IDOR, sem auth |
| `test/controllers/admin/artes_controller_test.rb` | Testes mark_revised + ciclo APRO-03 | VERIFIED | 10 testes incluindo `mark_revised muda status`, `mark_revised rejeita`, e `ciclo completo APRO-03` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/models/approval_response.rb` | `app/models/arte.rb` | `arte_must_be_pending` validator | WIRED | `arte.pending? \|\| arte.revised?` na linha 14 |
| `config/routes.rb` | `Admin::ArtesController#mark_revised` | `member { patch :mark_revised }` | WIRED | Rota confirmada via `bin/rails routes` |
| `app/views/client/artes/show.html.erb` | `client_arte_responses_path` | `form_with url:` | WIRED | Linhas 110 e 123 usam `client_arte_responses_path(token:, arte_id:)` |
| `app/javascript/controllers/approval_controller.js` | `show.html.erb` | `data-controller='approval' + data-approval-target='commentForm'` | WIRED | JS define `commentFormTarget`; view usa `data-controller="approval"` e `data-approval-target="commentForm"` |
| `app/views/admin/artes/show.html.erb` | `Admin::ArtesController#mark_revised` | `button_to mark_revised_admin_arte_path` | WIRED | Linha 21: `mark_revised_admin_arte_path(@arte)` com `method: :patch` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `app/views/client/artes/show.html.erb` (histórico) | `@arte.approval_responses` | `has_many` com scope DB query | Sim — `select * from approval_responses where arte_id = ? order by created_at desc` | FLOWING |
| `app/controllers/client/responses_controller.rb` | `response` (ApprovalResponse) | `@arte.approval_responses.build` + `response.save` persiste no banco | Sim — INSERT real em approval_responses | FLOWING |
| `app/controllers/admin/artes_controller.rb#mark_revised` | `@arte` | `Arte.find(params[:id])` via `set_arte` | Sim — UPDATE em artes.status | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Suite completa de testes | `bin/rails test` | 75 runs, 228 assertions, 0 failures, 0 errors, 0 skips | PASS |
| Rota mark_revised existe sem duplicação | `bin/rails routes \| grep mark_revised` | 1 entrada: `mark_revised_admin_arte PATCH /admin/artes/:id/mark_revised` | PASS |
| Rota client responses existe | `bin/rails routes \| grep client_arte_response` | `client_arte_responses POST /c/:token/artes/:arte_id/responses client/responses#create` | PASS |
| Nenhum uso singular de approval_response em controllers/views | `grep -r "approval_response\b" app/controllers app/views \| grep -v "approval_responses"` | 1 linha: `params.require(:approval_response)` — uso legítimo de nome de parâmetro Rails, não associação singular | PASS |
| Índice unique removido | `grep "index_approval_responses_on_arte_id" db/schema.rb` | Índice existe sem `unique: true` | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| APRO-01 | 05-01, 05-02 | Cliente pode aprovar uma arte com um clique | SATISFIED | `Client::ResponsesController#create` com `decision: approved`; Test 1 verde; arte muda para `approved` |
| APRO-02 | 05-01, 05-02 | Cliente pode pedir alteração e escrever comentário | SATISFIED | `response_params` permite `:comment`; Test 2 verifica comentário salvo; Test 3 verifica comentário opcional |
| APRO-03 | 05-01, 05-02, 05-03 | Admin revisada → arte volta para aprovação do cliente | SATISFIED | `mark_revised` action + validator aceita `revised?`; test `ciclo completo APRO-03` cobre o ciclo inteiro |
| APRO-04 | 05-01, 05-02 | Cliente vê histórico de decisões de cada arte | SATISFIED | Seção histórico em `show.html.erb` (linhas 143-165) com `has_many :approval_responses` ordered by `created_at desc` |
| APRO-05 | 05-01, 05-02 | Somente artes pendentes (ou revisadas) recebem ação | SATISFIED | `arte_must_be_pending` validator bloqueia approved/change_requested; Test 4 confirma rejeição de duplo-envio |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `show.html.erb` | 126 | `placeholder:` | INFO | Atributo HTML de textarea — texto de dica ao usuário, não stub de implementação |

Nenhum anti-padrão bloqueador encontrado. O `placeholder` na linha 126 é um atributo HTML `placeholder` do elemento `<textarea>`, não um indicador de implementação incompleta.

### Human Verification Required

#### 1. Fluxo de aprovação do cliente — Aprovar

**Test:** Acessar o portal do cliente em uma arte com status `pending`, clicar no botão "Aprovar"
**Expected:** A página recarrega com flash verde "Arte aprovada!" e o badge de status muda para "Aprovado"; os botões Aprovar e Pedir Alteração desaparecem da página
**Why human:** Comportamento visual com Turbo redirect e renderização de flash não são verificáveis via grep

#### 2. Fluxo de aprovação do cliente — Toggle do formulário de pedido de alteração

**Test:** Em uma arte pendente, clicar em "Pedir Alteração"
**Expected:** O formulário de textarea expande inline sem recarregar a página (Stimulus controller toggling CSS class `hidden`); clicar "Cancelar" fecha o formulário
**Why human:** Comportamento JavaScript/Stimulus requer execução real no browser

#### 3. Botão admin mark_revised — visibilidade condicional

**Test:** Acessar o admin show de uma arte com status `change_requested`; repetir para artes com status `pending`, `approved` e `revised`
**Expected:** Botão "Marcar como Revisada" aparece apenas para `change_requested`; ausente nos demais status
**Why human:** Renderização condicional com estado de banco em ambiente real

#### 4. Ciclo completo APRO-03 via browser

**Test:** (1) Cliente pede alteração em arte pendente; (2) Admin abre admin show e clica "Marcar como Revisada"; (3) Cliente acessa arte novamente e aprova
**Expected:** Cada etapa produz os flashes corretos; no final arte está `approved`; histórico mostra ambas as respostas em ordem cronológica reversa
**Why human:** Ciclo multi-actor que requer interação real de dois perfis de usuário

#### 5. Seção histórico de respostas — renderização visual

**Test:** Em uma arte com múltiplas ApprovalResponses (uma `change_requested` e uma `approved`), visualizar o histórico
**Expected:** Respostas em ordem cronológica reversa; ícone verde ✓ para approved, vermelho ✕ para change_requested; comentário exibido quando presente; data no formato `dd/mm/yyyy HH:MM`
**Why human:** Renderização visual e ordenação perceptível ao usuário requerem verificação no browser

### Gaps Summary

Nenhum gap encontrado. Todos os 13 must-haves foram verificados no codebase. Os 5 itens listados em "Human Verification Required" são verificações de comportamento visual e interação real no browser — não podem ser confirmados por análise estática mas o código que os sustenta está correto e completo.

---

_Verified: 2026-05-26T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
