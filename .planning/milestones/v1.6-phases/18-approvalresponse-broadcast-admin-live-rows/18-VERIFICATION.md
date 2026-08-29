---
phase: 18-approvalresponse-broadcast-admin-live-rows
verified: 2026-06-05T20:00:00Z
status: human_needed
score: 3/4 must-haves verified
overrides_applied: 0
gaps:
  - truth: "approvals-tbody existe na DOM quando admin está na página Aprovações com zero registros"
    status: partial
    reason: "approvals-tbody está dentro do bloco else de @approval_responses.empty? — se admin está na página com estado vazio, o tbody não existe no DOM e o turbo_stream.prepend falha silenciosamente"
    artifacts:
      - path: "app/views/admin/approvals/index.html.erb"
        issue: "tbody#approvals-tbody só renderizado quando @approval_responses.present?; estado vazio não inclui o tbody como alvo"
    missing:
      - "Renderizar tbody#approvals-tbody também no estado vazio (possivelmente vazio mas presente) para que o prepend funcione na primeira resposta ever"
human_verification:
  - test: "Verificar que turbo_stream.append/replace/prepend funciona em contexto de model"
    expected: "ApprovalResponse.create! com User existente dispara o broadcast sem NoMethodError — o método turbo_stream deve estar disponível no contexto do model via Turbo::Broadcastable"
    why_human: "turbo_stream é definido apenas em controllers (Turbo::Streams::TurboStreamsTagBuilder) e helpers (Turbo::StreamsHelper). Turbo::Broadcastable incluído em AR não fornece o método turbo_stream. A verificação estática não pode confirmar disponibilidade em runtime sem executar bin/rails test test/models/approval_response_test.rb. Se NoMethodError for gerado, todos os SCs (1-4) falham."
  - test: "Verificar SC1: admin em qualquer página recebe toast em < 2 segundos após cliente submeter resposta"
    expected: "Toast aparece com nome do cliente, badge de decisão e link Ver arte"
    why_human: "Comportamento visual e timing real-time requerem execução manual"
  - test: "Verificar SC3 com estado vazio: admin na página Aprovações sem respostas existentes recebe nova linha quando primeira resposta chega"
    expected: "Nova linha aparece no topo da lista (ou estado vazio transiciona para tabela com linha)"
    why_human: "approvals-tbody não existe no DOM quando estado vazio — o prepend falha silenciosamente; requer teste manual com estado inicial de zero respostas"
  - test: "Verificar SC4: badge do sidebar incrementa quando nova resposta change_requested chega"
    expected: "Badge muda de N para N+1 sem recarregar a página"
    why_human: "Comportamento visual real-time"
---

# Phase 18: ApprovalResponse Broadcast + Admin Live Rows — Verification Report

**Phase Goal:** Quando um cliente registra aprovação ou pedido de alteração, o admin recebe toast imediato em qualquer página e as listas do dashboard e da página Aprovações ganham a nova linha sem recarregar
**Verified:** 2026-06-05T20:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Success Criteria from ROADMAP.md)

| #   | Truth                                                                                                       | Status      | Evidence                                                                                                                         |
|-----|-------------------------------------------------------------------------------------------------------------|-------------|----------------------------------------------------------------------------------------------------------------------------------|
| SC1 | Admin logado em qualquer página recebe toast visível dentro de 2 segundos após cliente submeter resposta    | ? UNCERTAIN | `turbo_stream_from Current.user, channel: AdminNotificationsChannel` no layout; `#admin-toast-region` sempre presente; callback `after_create_commit :broadcasts_to_admin` wired — mas turbo_stream disponibilidade em model é incerta (ver WARNING-01) |
| SC2 | Dashboard admin exibe atualização da linha da arte sem recarregar quando cliente aprova ou pede alteração  | ✓ VERIFIED  | `turbo_stream.replace(dom_id(arte_with_client), partial: "admin/dashboard/arte_dashboard_row")` — partial existe com `id="<%= dom_id(arte) %>"`, dashboard refatorado com `render "admin/dashboard/arte_dashboard_row"`. Design intencional: replace in-place (não nova linha no topo — D-04 do CONTEXT). |
| SC3 | Página Aprovações exibe nova linha no topo da lista em tempo real quando nova resposta chega               | ? PARTIAL   | `turbo_stream.prepend("approvals-tbody", ...)` — tbody#approvals-tbody existe, dom_id(approval_response) no tr. PORÉM: tbody só renderizado quando `@approval_responses.present?` — estado vazio não tem o target, prepend falha silenciosamente para primeira resposta ever |
| SC4 | Badge do sidebar incrementa em 1 quando nova resposta "Pediu Alteração" chega (sem recarregar)             | ✓ VERIFIED  | Badge stream condicional: `(turbo_stream.replace("sidebar-badge", partial: "admin/shared/sidebar_badge", locals: { badge_count: badge_count }) if decision == "change_requested")` — `Arte.change_requested.count` server-authoritative. Increment scope = Phase 18 (per REQUIREMENTS traceability). |

**Score:** 3/4 truths verified (SC2 e SC4 verified; SC1 uncertain por WARNING-01; SC3 partial por gap)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Badge não atualiza quando decision == approved (arte sai do change_requested scope) | Phase 19 | REQUIREMENTS traceability: "RTUP-01: Phase 18 (incremento), Phase 19 (decremento), Phase 20 (finalizado)" |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/models/approval_response.rb` | after_create_commit + broadcasts_to_admin privado | ✓ VERIFIED | `after_create_commit :broadcasts_to_admin` (linha 11), método privado completo com guard, eager-load, badge_count, 4 streams compact, broadcast_to |
| `app/views/admin/shared/_sidebar_badge.html.erb` | span#sidebar-badge sempre no DOM com hidden quando count=0 | ✓ VERIFIED | `id="sidebar-badge"`, `<%= 'hidden' if badge_count == 0 %>` presentes |
| `app/views/admin/shared/_approval_toast.html.erb` | Toast com cliente, decisão, link Ver arte | ✓ VERIFIED | `data-controller="toast"`, `click->toast#dismiss`, `arte.client.name`, `render "admin/approvals/decision_badge"`, `admin_arte_path(arte)` |
| `app/views/admin/shared/_sidebar.html.erb` | sem conditional badge_count > 0, usa partial sidebar_badge | ✓ VERIFIED | `badge_count > 0` removido; `render "admin/shared/sidebar_badge", badge_count: badge_count` presente |
| `app/views/admin/approvals/_approval_row.html.erb` | dom_id(approval_response) no tr | ✓ VERIFIED | `id="<%= dom_id(approval_response) %>"` na linha 2 |
| `app/views/admin/approvals/index.html.erb` | id="approvals-tbody" no tbody desktop | ✓ VERIFIED | `<tbody id="approvals-tbody">` linha 49, dentro da seção desktop; mobile não modificado |
| `app/views/admin/dashboard/_arte_dashboard_row.html.erb` | tr com id=dom_id(arte) | ✓ VERIFIED | `<tr id="<%= dom_id(arte) %>" class="hover:bg-slate-50">`, 4 colunas conforme spec |
| `app/views/admin/dashboard/index.html.erb` | usa partial arte_dashboard_row | ✓ VERIFIED | `render "admin/dashboard/arte_dashboard_row", arte: arte`; sem tr inline |
| `test/models/approval_response_test.rb` | 7 testes RED (A-G) para broadcasts_to_admin | ✓ VERIFIED | Todos os 7 testes presentes (linhas 75-163); Tests A-G com asserções corretas |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/models/approval_response.rb` | `app/channels/admin_notifications_channel.rb` | `AdminNotificationsChannel.broadcast_to(admin, turbo_stream: streams)` | ✓ WIRED | Linha 56 do model; canal com `stream_for current_user` em Phase 17 |
| `app/models/approval_response.rb` | `app/views/admin/shared/_approval_toast.html.erb` | `turbo_stream.append("admin-toast-region", partial: "admin/shared/approval_toast", ...)` | ? UNCERTAIN | Código wired na linha 34-38; porém turbo_stream como método no model não verificado (WARNING-01) |
| `app/models/approval_response.rb` | `app/views/admin/dashboard/_arte_dashboard_row.html.erb` | `turbo_stream.replace(dom_id(arte_with_client), partial: "admin/dashboard/arte_dashboard_row", ...)` | ? UNCERTAIN | Código wired linha 44-48; mesma dependência de turbo_stream em model (WARNING-01) |
| `app/models/approval_response.rb` | `app/views/admin/approvals/_approval_row.html.erb` | `turbo_stream.prepend("approvals-tbody", partial: "admin/approvals/approval_row", ...)` | ? UNCERTAIN | Código wired linha 49-53; mesma dependência + gap do tbody vazio |
| `app/views/admin/shared/_sidebar.html.erb` | `app/views/admin/shared/_sidebar_badge.html.erb` | `render "admin/shared/sidebar_badge", badge_count: badge_count` | ✓ WIRED | Linha 32 do sidebar |
| `app/views/admin/shared/_approval_toast.html.erb` | `app/views/admin/approvals/_decision_badge.html.erb` | `render "admin/approvals/decision_badge", approval_response: approval_response` | ✓ WIRED | Linha 10 do toast; partial existe |
| `app/views/admin/approvals/_approval_row.html.erb` | dom_id | `id="<%= dom_id(approval_response) %>"` no tr | ✓ WIRED | Linha 2 do partial |
| `app/views/admin/dashboard/index.html.erb` | `app/views/admin/dashboard/_arte_dashboard_row.html.erb` | `render "admin/dashboard/arte_dashboard_row", arte: arte` | ✓ WIRED | Linha 50 do index |
| `app/views/layouts/admin.html.erb` | `AdminNotificationsChannel` | `turbo_stream_from Current.user, channel: AdminNotificationsChannel` | ✓ WIRED | Linha 24 do layout — subscription presente em todas as páginas admin |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `_approval_toast.html.erb` | `arte.client.name`, `approval_response` | `Arte.includes(:client).find(arte_id)` em broadcasts_to_admin | ✓ Sim (eager-load) | ✓ FLOWING |
| `_sidebar_badge.html.erb` | `badge_count` | `Arte.change_requested.count` em broadcasts_to_admin | ✓ Sim (DB query) | ✓ FLOWING |
| `_arte_dashboard_row.html.erb` | `arte` | `arte_with_client` de broadcasts_to_admin | ✓ Sim (eager-load) | ✓ FLOWING |
| `_approval_row.html.erb` (via broadcast) | `approval_response` | `self` em broadcasts_to_admin | ⚠ Parcial — `self.arte.client` não eager-loaded (WR-01 do REVIEW) | ⚠ N+1 RISK |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Model syntax OK | `ruby -c app/models/approval_response.rb` | "Syntax OK" | ✓ PASS |
| after_create_commit registrado | `grep -c "after_create_commit :broadcasts_to_admin" app/models/approval_response.rb` | 1 | ✓ PASS |
| Arte.includes(:client).find presente | `grep -c "Arte.includes(:client).find" app/models/approval_response.rb` | 1 | ✓ PASS |
| Arte.change_requested.count presente | `grep -c "Arte.change_requested.count" app/models/approval_response.rb` | 1 | ✓ PASS |
| .compact presente no array de streams | `grep -c "\.compact" app/models/approval_response.rb` | 1 | ✓ PASS |
| badge condicional para change_requested | `grep -c 'if decision == "change_requested"' app/models/approval_response.rb` | 1 | ✓ PASS |
| approvals-tbody só no bloco else | Estado vazio (`@approval_responses.empty?`) não renderiza tbody | Confirmado linha 22/49 | ✗ GAP |
| Commits existem no git log | `git log --oneline` | 521948e, e80b844, 748a7c1, 00db6e9, b111710, 0cb9fa5 | ✓ PASS |
| 7 testes RED presentes no arquivo | Métodos test A-G em test/models/approval_response_test.rb | Confirmado linhas 75-163 | ✓ PASS |
| bin/rails test (execução real) | Requer DB | SKIPPED — DB não acessível no ambiente | ? SKIP |

### Probe Execution

Step 7c: SKIPPED — DB não acessível (PostgreSQL não disponível no ambiente de verificação). Os testes RED/GREEN não podem ser executados.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| RTUP-01 (incremento) | 18-00, 18-02 | Badge sidebar incrementa quando nova resposta change_requested chega | ✓ SATISFIED | badge_count = Arte.change_requested.count; badge stream condicional para change_requested; span#sidebar-badge sempre no DOM |
| RTUP-02 | 18-00, 18-01, 18-02 | Admin recebe toast em qualquer página quando nova resposta chega | ? UNCERTAIN | Toast partial pronto, append para admin-toast-region em layout, turbo_stream_from no layout; bloqueado por WARNING-01 (turbo_stream em model) |
| RTUP-03 | 18-00, 18-02 | Dashboard recebe linha de arte em tempo real | ✓ SATISFIED | replace via dom_id(arte), partial _arte_dashboard_row com id=dom_id(arte); design intencional in-place per D-04 |
| RTUP-04 | 18-00, 18-01, 18-02 | Página Aprovações recebe nova linha em tempo real | ✗ PARTIAL | prepend para approvals-tbody wired; tbody não existe em estado vazio — falha silenciosa para primeira resposta ever |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/models/approval_response.rb` | 15-17 | `arte_must_be_pending` sem guard de nil (`arte.pending?` pode crashar se arte=nil) | ⚠ Warning | Issue pré-existente (desde Phase 5 commit 18af5a7); não introduzido por Phase 18; CR-01 do code review |
| `app/models/approval_response.rb` | 27 | `User.first` não-determinístico para multi-admin | ℹ Info | Design aceito para single-admin atual; WR-02 do code review |
| `app/views/admin/approvals/_approval_row.html.erb` | 3-4 | `approval_response.arte&.client&.name` (nil-safe) mas `approval_response.arte.title` (não nil-safe) na linha 4 | ⚠ Warning | Inconsistência de nil-safety; WR-03 do code review; pré-existente |
| `app/views/admin/shared/_sidebar.html.erb` | 21 | `Arte.where(status: :change_requested).count` inline na view (raw DB query em partial de layout) | ℹ Info | Executa em cada page load admin; IN-01 do code review; pré-existente |

### Human Verification Required

#### 1. CRITICAL — turbo_stream Disponível em Contexto de Model?

**Test:** Executar `bin/rails test test/models/approval_response_test.rb` em ambiente com DB funcional. Observar se os Tests C-G passam ou falham com NoMethodError.

**Expected:** Todos os 7 testes (A-G) passam. Se Tests C-G falharem com `NoMethodError: undefined method 'turbo_stream'`, a implementação core está quebrada e todos os SCs falham em runtime.

**Why human:** O método `turbo_stream` está disponível em controllers (`Turbo::Streams::TurboStreamsTagBuilder`) e views (`Turbo::StreamsHelper`). A verificação estática do turbo-rails engine confirma que AR models recebem apenas `Turbo::Broadcastable`, que NÃO define o método `turbo_stream`. Sem execução real, não é possível confirmar se há algum outro mecanismo que torne `turbo_stream` disponível no model. **Se este item falhar, o broadcast inteiro está quebrado e nenhum SC da fase está funcional.**

**Fix alternativo se NoMethodError:** Substituir `turbo_stream.append/replace/prepend` pelo padrão correto de Broadcastable (`Turbo::StreamsChannel.broadcast_append_to`, etc.) ou construir as action tags diretamente via `Turbo::StreamsChannel.broadcast_action_to`.

---

#### 2. WARNING — SC3: Primeira Resposta com Página Aprovações Vazia

**Test:** Limpar todas as ApprovalResponses do banco. Abrir a página Aprovações no admin. Submeter uma resposta de aprovação como cliente. Observar se a nova linha aparece na página Aprovações sem reload.

**Expected:** Nova linha aparece no topo da lista em tempo real.

**Why human:** `approvals-tbody` só é renderizado quando `@approval_responses.present?` (bloco else). No estado vazio, o tbody não existe no DOM, e `turbo_stream.prepend("approvals-tbody", ...)` falha silenciosamente. A nova linha não apareceria. O toast ainda apareceria (admin-toast-region está sempre no DOM).

---

#### 3. SC1: Admin em Qualquer Página Recebe Toast em < 2s

**Test:** Admin logado em Dashboard. Cliente submete resposta. Confirmar que toast aparece com cliente, badge de decisão e link "Ver arte" dentro de 2 segundos.

**Expected:** Toast visível imediatamente após submissão do cliente.

**Why human:** Comportamento visual e timing real-time requerem execução manual.

---

#### 4. SC4: Badge do Sidebar Incrementa em Tempo Real

**Test:** Admin com badge mostrando N artes com "Pediu Alteração". Cliente em arte diferente submete "Pediu Alteração". Badge deve mudar para N+1 sem reload.

**Expected:** Badge atualiza de N para N+1 sem recarregar a página.

**Why human:** Comportamento visual real-time via WebSocket.

### Gaps Summary

**Gap principal (SC3/RTUP-04):** `approvals-tbody` é condicional na view — só renderizado quando há registros existentes. Quando admin está na página Aprovações com estado vazio (zero respostas), o `turbo_stream.prepend("approvals-tbody", ...)` não encontra o target e falha silenciosamente. A primeira resposta ever não aparece em tempo real na página Aprovações.

**Fix:** Renderizar o `<tbody id="approvals-tbody">` também no branch de estado vazio (pode estar vazio mas deve estar presente no DOM):

```erb
<%# No estado vazio, renderizar tbody vazio para que o broadcast prepend funcione %>
<% if @approval_responses.empty? %>
  <% # ... empty state div ... %>
  <%# Tbody vazio para target de Turbo Stream broadcasts %>
  <table class="hidden"><tbody id="approvals-tbody"></tbody></table>
<% else %>
  <%# ... tabela normal ... %>
```

Ou, mais elegantemente, mover o `<tbody id="approvals-tbody">` para fora do bloco condicional.

**Warning principal (WARNING-01):** A disponibilidade de `turbo_stream` como método de instância em `ApprovalResponse` (AR model) não foi confirmada. O método só é definido em controllers e helpers via turbo-rails. Se este for NoMethodError em runtime, todos os broadcasts falham e nenhum SC é entregue.

---

_Verified: 2026-06-05T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
