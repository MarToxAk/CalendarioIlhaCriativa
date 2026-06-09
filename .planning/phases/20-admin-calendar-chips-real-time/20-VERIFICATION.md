---
phase: 20-admin-calendar-chips-real-time
verified: 2026-06-09T00:00:00Z
status: passed
score: 7/7 must-haves verified
overrides_applied: 0
human_uat: passed 2026-06-09 — todos os 3 itens abaixo confirmados pelo usuário em 20-HUMAN-UAT.md (5/5 testes passaram, 0 issues)
human_verification:
  - test: "Abrir o calendário admin em uma aba; em outra aba (ou dispositivo do cliente), registrar uma aprovação ou pedido de alteração via ApprovalResponse. Observar o chip da arte correspondente no calendário admin."
    expected: "O chip atualiza visualmente (anel colorido aparece/muda) dentro de aproximadamente 2 segundos, sem recarregar a página."
    why_human: "Requer ActionCable ativo, dois agentes (admin + cliente) e cronômetro — não verificável via grep nem bin/rails runner."
  - test: "Com o calendário admin aberto, marcar uma arte como 'Revisada'. Observar o chip daquela arte."
    expected: "O chip exibe anel cinza (#475569) em tempo real via turbo-stream replace, sem recarregar."
    why_human: "Comportamento de UI ao vivo; canal WebSocket precisa estar ativo."
  - test: "Disparar broadcasts múltiplos seguidos para a mesma arte (ex.: change_requested seguido de approved) e inspecionar o DOM do calendário admin com DevTools."
    expected: "Exatamente um elemento com id arte_N_admin_calendar_chip presente após cada replace — sem chips duplicados nem elementos DOM extras."
    why_human: "Verificação de integridade DOM requer inspeção ao vivo no browser após múltiplos replaces."
---

# Phase 20: Admin Calendar Chips Real-Time — Verification Report

**Phase Goal:** Chips do calendário admin refletem mudanças de status de artes em tempo real, completando o ciclo de atualizações em tempo real para todas as views do admin.
**Verified:** 2026-06-09
**Status:** passed (checks automatizados + 3 itens de UAT visual confirmados pelo usuário em 20-HUMAN-UAT.md — 5/5 testes, 0 issues)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | `_admin_calendar_chip.html.erb` existe com `id: dom_id(arte, "admin_calendar_chip")` | VERIFIED | `app/views/admin/calendar/_admin_calendar_chip.html.erb` linha 25: `id: dom_id(arte, "admin_calendar_chip")` |
| 2 | O chip preserva fundo de cor do cliente e exibe anel de status para approved/change_requested/revised; pending sem anel | VERIFIED | `ApplicationHelper#arte_status_ring_class` retorna strings Tailwind corretas (linhas 22-30); anel interpolado na `class:` do `link_to` (linha 38 da partial) |
| 3 | `_calendar_grid.html.erb` renderiza o partial e não contém mais o bloco inline `link_to admin_arte_path` com o chip | VERIFIED | Arquivo tem apenas `render "admin/calendar/admin_calendar_chip", arte: arte"` (linha 34); `grep link_to admin_arte_path` retorna 0 |
| 4 | `ApplicationHelper#arte_status_ring_class(arte)` definido com 4 casos e hex idênticos ao STATUS_MAP JS | VERIFIED | `application_helper.rb` linhas 21-31: `#14A958`, `#EE3537`, `#475569` — idênticos a `arte_preview_controller.js` linhas 5-7 |
| 5 | `ApprovalResponse#broadcasts_to_admin` gera 5 turbo-streams (toast + badge + dashboard + approvals + chip replace) | VERIFIED | `approval_response.rb` linhas 55-61: array `content` com 5 `turbo_stream_tag` calls; quinto usa `dom_id(arte_with_client, "admin_calendar_chip")` como target |
| 6 | `Arte#broadcasts_revised_to_all` gera 2 turbo-streams para o admin: badge replace + chip replace | VERIFIED | `arte.rb` linhas 69-72: `admin_stream = [badge, chip].join`; `AdminNotificationsChannel.broadcast_to(admin, admin_stream)` na linha 75 |
| 7 | Badge do sidebar não foi alterado — RTUP-01 streams preservados em ambos os broadcasts | VERIFIED | `approval_response.rb` linha 57: `turbo_stream_tag("replace", "sidebar-badge", badge_html)` inalterado; `arte.rb` linha 70: id. Nenhum dos 4 streams originais da Phase 18 foi removido |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/views/admin/calendar/_admin_calendar_chip.html.erb` | Chip com dom_id estável, anel de status e 9 data-attributes | VERIFIED | 41 linhas; dom_id, todos os 9 `data:` attributes, arte_status_ring_class interpolado, client_color computado internamente |
| `app/views/admin/calendar/_calendar_grid.html.erb` | Renderiza o partial; sem chip inline | VERIFIED | 43 linhas; apenas `render "admin/calendar/admin_calendar_chip"` no loop; zero ocorrências de `link_to admin_arte_path` |
| `app/helpers/application_helper.rb` | `arte_status_ring_class(arte)` com 4 casos | VERIFIED | Método definido nas linhas 21-31; hex exatos; `pending` retorna `""` |
| `app/models/approval_response.rb` | `broadcasts_to_admin` com 5 streams | VERIFIED | Array `content` com 5 elementos; quinto é `replace` com target `arte_N_admin_calendar_chip`; `arte_with_client` carregado via `includes(:client)` — sem N+1 |
| `app/models/arte.rb` | `broadcasts_revised_to_all` com `admin_stream` de 2 streams | VERIFIED | `admin_stream` é array de 2 elementos com `.join`; segundo stream faz `replace` com target via `dom_id(self, "admin_calendar_chip")` |
| `test/models/approval_response_test.rb` | Tests E e F com `assert_equal 5`; Test H com `assert_match` para target | VERIFIED | Linhas 119/131: nomes atualizados para "gera 5 turbo streams"; linhas 126/146: `assert_equal 5`; linhas 158-159: `assert_match(/target="arte_\d+_admin_calendar_chip"/, content)` |
| `test/models/arte_test.rb` | `assert_equal 2` para admin_calls; novo teste `assert_match` para chip target | VERIFIED | Linha 69: `assert_equal 2, admin_calls.first.scan(/<turbo-stream/).count`; linha 94: `assert_match(/target="arte_\d+_admin_calendar_chip"/, admin_calls.first)` |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_calendar_grid.html.erb` | `_admin_calendar_chip.html.erb` | `render "admin/calendar/admin_calendar_chip", arte: arte` | WIRED | Linha 34 do grid; confirmado por grep (`grep -c 'render.*admin_calendar_chip'` = 1) |
| `_admin_calendar_chip.html.erb` | `app/helpers/application_helper.rb` | `arte_status_ring_class(arte)` na `class:` string | WIRED | Linha 38 da partial; helper definido no módulo ApplicationHelper |
| `approval_response.rb` | `_admin_calendar_chip.html.erb` | `render_partial_html(partial: "admin/calendar/admin_calendar_chip", locals: { arte: arte_with_client })` | WIRED | Linhas 50-53; target = `ActionView::RecordIdentifier.dom_id(arte_with_client, "admin_calendar_chip")` |
| `arte.rb` | `_admin_calendar_chip.html.erb` | `render_partial_html(partial: "admin/calendar/admin_calendar_chip", locals: { arte: self })` | WIRED | Linhas 56-59; target = `ActionView::RecordIdentifier.dom_id(self, "admin_calendar_chip")` |
| `admin.html.erb` | `AdminNotificationsChannel` | `turbo_stream_from Current.user, channel: AdminNotificationsChannel` | WIRED | Linha 24 do layout — o admin já recebe todos os broadcasts em qualquer página, inclusive o calendário |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `_admin_calendar_chip.html.erb` (broadcast) | `arte` (locals) | `Arte.includes(:client).find(arte_id)` em `ApprovalResponse#broadcasts_to_admin` | Sim — query ao banco com eager-load | FLOWING |
| `_admin_calendar_chip.html.erb` (broadcast revised) | `arte` (locals = `self`) | `Arte` instance do callback `after_update_commit` em `arte.rb` | Sim — objeto persistido com `client` via `belongs_to` | FLOWING (com ressalva: ver WR-02 abaixo) |
| `_calendar_grid.html.erb` (page render) | `artes_by_date`, `arte` (loop) | `Admin::CalendarController` — query ao banco no controller action | Sim | FLOWING |

**Ressalva WR-02 (latent N+1):** `Arte#broadcasts_revised_to_all` passa `arte: self` para o partial sem re-fetch via `includes(:client)`. No fluxo normal via `Admin::ArtesController#mark_revised`, o `client` já está carregado no AR object cache. Porém, chamadas fora deste controller (console, jobs, testes futuros) podem gerar N+1 queries para `arte.client` (3 acessos no partial: `client_color`, `data-arte-client`, iniciais). O `ApprovalResponse` não tem este problema pois usa `Arte.includes(:client).find(arte_id)`. A classificação é WARNING, não BLOCKER: o comportamento funcional é correto no fluxo de produção atual.

---

### Behavioral Spot-Checks

Step 7b: Comportamento em tempo real (live WebSocket replace) não é verificável via comando único sem servidor ativo. Os checks estruturais cobrem os dois caminhos de código relevantes:

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| Partial existe com dom_id | `grep -c 'dom_id.*admin_calendar_chip' _admin_calendar_chip.html.erb` | 1 | PASS |
| Grid renderiza partial | `grep -c 'render.*admin_calendar_chip' _calendar_grid.html.erb` | 1 | PASS |
| Chip inline removido do grid | `grep -c 'link_to admin_arte_path' _calendar_grid.html.erb` | 0 | PASS |
| Helper definido | `grep -c 'arte_status_ring_class' application_helper.rb` | 1 | PASS |
| ApprovalResponse tem chip stream | `grep -c 'admin_calendar_chip' approval_response.rb` | 2 | PASS |
| Arte tem chip stream | `grep -c 'admin_calendar_chip' arte.rb` | 2 | PASS |
| Tests E/F assertam 5 streams | `grep -c 'assert_equal 5' approval_response_test.rb` | 2 | PASS |
| Arte test asserta 2 admin streams | `grep -n 'assert_equal 2.*admin'` | linha 69 — presente | PASS |
| Hex values sincronizados JS/Ruby | `#14A958 #EE3537 #475569` em ambos os arquivos | Idênticos | PASS |
| turbo_stream_from no layout | `grep 'turbo_stream_from.*AdminNotificationsChannel' admin.html.erb` | linha 24 | PASS |
| Commits documentados existem | `git log b010a6a 030a11c d9e874a 9df77cd 01d4b08` | Todos presentes | PASS |

---

### Probe Execution

Nenhum arquivo `probe-*.sh` declarado ou convencional encontrado para esta fase. Step 7c: SKIPPED (sem probes).

---

### Requirements Coverage

| Requirement | Plano | Descrição | Status | Evidence |
|-------------|-------|-----------|--------|---------|
| RTUP-08 | 20-00, 20-01 | Chips do calendário admin atualizam em tempo real quando status de arte muda | SATISFIED (automated) + NEEDS HUMAN (visual runtime) | Partial com dom_id estável criada; broadcasts em `ApprovalResponse` e `Arte` estendidos com chip replace; teste de target `arte_N_admin_calendar_chip` presente em ambos os test files |
| RTUP-01 | 20-01 (finalização) | Badge no sidebar do admin atualiza corretamente após qualquer sequência de eventos | SATISFIED (structure) | `sidebar-badge` stream preservado inalterado em ambos os models; Phase 20 adicionou apenas o quinto stream sem remover nenhum dos anteriores; verifcação de runtime delegada a UAT existente das Phases 18/19 |

---

### Anti-Patterns Found

Nenhum `TBD`, `FIXME`, `XXX`, `TODO`, `placeholder`, `return null`, `return {}`, ou `return []` encontrado nos 7 arquivos modificados nesta fase.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/models/approval_response_test.rb` | 72 (header comment) | Comentário desatualizado: "Atualizados no Plan 03: stub posicional (user, content) + 4 streams em ambos os casos" | INFO | O comentário refere-se à história da atualização (Phase 18 Plan 03 = 4 streams); agora são 5. Não afeta comportamento dos testes. Cosmético. |

---

### Human Verification Required

#### 1. Atualização visual do chip em tempo real (Success Criterion 1)

**Test:** Abrir o calendário admin em uma aba do browser. Em outra sessão (cliente), registrar uma `ApprovalResponse` de `change_requested` ou `approved` para uma arte visível no calendário do mês atual.
**Expected:** O chip da arte alvo muda visualmente (aparece anel vermelho para `change_requested`, anel verde para `approved`) dentro de aproximadamente 2 segundos, sem recarregar a página.
**Why human:** Requer ActionCable ativo, dois agentes simultâneos e observação de tempo real — não verificável via grep nem `bin/rails runner`.

#### 2. Atualização via ação do admin (revised)

**Test:** Com o calendário admin aberto, clicar em "Revisada" para uma arte visível. Observar o chip imediatamente.
**Expected:** O chip recebe anel cinza (`#475569`) via turbo-stream replace sem reload; o badge do sidebar decrementa conforme comportamento das Phases 18/19.
**Why human:** Envolve WebSocket ativo e percepção visual da atualização ao vivo.

#### 3. Ausência de duplicação de chips (Success Criterion 3)

**Test:** Com o DevTools aberto no painel de Elements, disparar dois broadcasts seguidos para a mesma arte (ex.: `change_requested` depois `approved`). Inspecionar o DOM da célula correspondente no calendário.
**Expected:** Exatamente um elemento com `id="arte_N_admin_calendar_chip"` presente após cada replace — sem chips duplicados nem elementos DOM extras acumulados.
**Why human:** Inspeção de integridade DOM requer browser com DevTools após múltiplos replaces ao vivo.

---

### Code Review Findings Status

| Finding | Severity | Status | Notes |
|---------|----------|--------|-------|
| WR-01: Nomes dos testes E e F diziam "4 turbo streams" | WARNING | **FIXED** | Nomes agora são "change_requested broadcast gera 5 turbo streams" e "approved broadcast gera 5 turbo streams com badge" (linhas 119 e 131) |
| WR-02: N+1 latente em `Arte#broadcasts_revised_to_all` (arte: self sem includes) | WARNING | **OPEN** | `arte.rb` ainda usa `arte: self` sem re-fetch. Funcional no fluxo de produção atual (client já no cache do controller). Latente para chamadas fora do controller. Não bloqueia o objetivo da fase. |
| IN-01: `turbo_stream_tag`/`render_partial_html` duplicados em dois models | INFO | OPEN (refactoring) | Duplicação advisory; nenhum comportamento incorreto. |

---

### Gaps Summary

Nenhum gap bloqueador identificado. Todos os 7 truths verificados passam na análise estática do código-fonte. A fase entrega o objetivo declarado: chips do calendário admin têm dom_id estável, broadcasts de ambos os models foram estendidos com o stream de replace do chip, e os testes refletem os novos counts.

O status `human_needed` deve-se exclusivamente aos 3 itens de UAT visual acima — comportamento de WebSocket em tempo real, percepção visual da atualização e integridade DOM após replaces múltiplos.

WR-02 (N+1 latente) é um WARNING que o time pode optar por resolver como hardening, mas não bloqueia a conclusão desta fase nem o objetivo de tempo real.

---

_Verified: 2026-06-09T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
