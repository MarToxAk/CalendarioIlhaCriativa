---
phase: 14-calend-rio-admin
verified: 2026-06-04T00:00:00Z
status: human_needed
score: 9/9 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Abrir /admin/calendar no navegador e clicar nas setas de navegação (mês anterior / próximo)"
    expected: "Apenas a grade do calendário atualiza dentro do turbo-frame 'calendar-content' — a barra de navegação e o sidebar permanecem estáticos (sem full page reload)"
    why_human: "O wiring data-turbo-frame é verificável estaticamente, mas o comportamento de partial update requer browser com Hotwire/Turbo carregado; grep não pode confirmar que o JS do Turbo está sendo carregado e interceptando os cliques"
  - test: "Abrir /admin/calendar no navegador e verificar visualmente os chips coloridos"
    expected: "Chips de clientes distintos devem exibir cores de fundo diferentes (paleta de 8 cores por client.id % 8); iniciais de 2 caracteres visíveis dentro do chip; tooltip com nome completo ao hover"
    why_human: "Tailwind JIT pode não ter purgado as classes hex literais se o build de CSS não foi executado; a aparência visual não é verificável por grep"
---

# Phase 14: Calendário Admin — Verification Report

**Phase Goal:** Admin visualiza num único calendário mensal as artes de todos os clientes, diferenciadas por cor e nome de cliente, e navega entre meses e acessa artes diretamente
**Verified:** 2026-06-04
**Status:** human_needed
**Re-verification:** No — verificação inicial

---

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Admin clica em "Calendário" no sidebar e é levado à página do calendário admin (link não aponta mais para `#`) | VERIFIED | `_sidebar.html.erb` linha 16: `{ label: "Calendário", path: admin_calendar_index_path }` — sem `"#"`. Rota `resources :calendar, only: [:index]` registrada no namespace admin em `config/routes.rb` linha 20. |
| 2 | Admin vê calendário mensal com todas as artes de todos os clientes distribuídas nos dias corretos | VERIFIED | Controller executa `Arte.where(scheduled_on: grid_start..grid_end).includes(:client).order(:id)` sem filtro por client_id — busca artes de todos os clientes. `@artes_by_date = @artes.group_by(&:scheduled_on)` distribui por dia. View `_calendar_grid.html.erb` itera `grid_dates.each` e renderiza `artes_by_date[date]` para cada célula. |
| 3 | Cada arte exibe cor de fundo distinta por cliente e o nome ou iniciais do cliente visível na célula do dia | VERIFIED | `client_color(arte.client)` retorna hash `{bg:, text:}` com paleta de 8 cores por `client.id % 8`. Chip exibe `arte.client.name.split.map(&:first).first(2).join.upcase` (iniciais 2 chars). Atributo `title: arte.client.name` garante nome completo acessível. |
| 4 | Admin clica nas setas de navegação (mês anterior / próximo) e o calendário atualiza sem recarregar a página completa | VERIFIED (wiring) / UNCERTAIN (behavior) | Setas usam `data: { turbo_frame: "calendar-content" }` e ficam FORA do `<turbo-frame id="calendar-content">` (linhas 3-27 vs linha 29 em `index.html.erb`). Wiring estático correto. Comportamento de partial update requer verificação humana no browser. |
| 5 | Admin clica numa arte do calendário e é levado à página de show da arte correspondente | VERIFIED | `_calendar_grid.html.erb` linha 29: `link_to admin_arte_path(arte)` — cada chip é link para o show da arte. Confirmado pelo teste `test_chip_links_to_arte` que valida presença de `admin_arte_path(@arte)` no body. |

**Score:** 9/9 truths verified (5 ROADMAP SCs + 4 must-haves de planos verificados abaixo)

---

### Must-Haves por Plano (além dos ROADMAP SCs)

#### Plano 01 (CADM-01 infra)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | `GET /admin/calendar` retorna rota reconhecida (helper `admin_calendar_index_path` disponível) | VERIFIED | `config/routes.rb` linha 20: `resources :calendar, only: [:index]` dentro de `namespace :admin do`. |
| 2 | Link "Calendário" no sidebar aponta para `admin_calendar_index_path`, não mais `"#"` | VERIFIED | `_sidebar.html.erb` linha 16: confirmado — sem `"#"`. |
| 3 | Arquivo de testes existe com setup inline completo | VERIFIED | `test/controllers/admin/calendar_controller_test.rb` existe com `Admin::CalendarControllerTest < ActionDispatch::IntegrationTest` e setup completo com `User.create!`, `sign_in_as`, `Client.create!`, `Arte.create!`. |

#### Plano 02 (CADM-02, CADM-03, CADM-04)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | `GET /admin/calendar` retorna 200 (controller existe e herda `Admin::BaseController`) | VERIFIED | `calendar_controller.rb` linha 1: `class Admin::CalendarController < Admin::BaseController`. Herança garante `before_action :require_authentication` e layout admin sem re-declaração. |
| 2 | Controller calcula `@artes_by_date` com artes de todos os clientes sem N+1 | VERIFIED | `Arte.where(...).includes(:client).order(:id)` — `.includes(:client)` previne N+1 ao acessar `arte.client` na view. |
| 3 | Helper `client_color(client)` retorna hash `{bg:, text:}` com classes Tailwind literais | VERIFIED | `application_helper.rb` linhas 4-16: paleta de 8 hashes com strings literais completas (ex: `"bg-[#F0FDF4]"`), sem interpolação. Retorna `palette[client.id % palette.size]`. |
| 4 | `parse_month_param` faz `rescue Date::Error` — param inválido retorna `Date.today.beginning_of_month` | VERIFIED | `calendar_controller.rb` linhas 29-34: `rescue Date::Error` presente. Coberto pelo teste `test_invalid_month_param_does_not_crash`. |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `config/routes.rb` | Rota `resources :calendar, only: [:index]` no namespace admin | VERIFIED | Linha 20: `resources :calendar, only: [:index]` dentro de `namespace :admin do`. |
| `app/views/admin/shared/_sidebar.html.erb` | Link Calendário wired para `admin_calendar_index_path` | VERIFIED | Linha 16: `{ label: "Calendário", path: admin_calendar_index_path }`. |
| `test/controllers/admin/calendar_controller_test.rb` | Scaffold com `Admin::CalendarControllerTest` e 12 testes | VERIFIED | 12 métodos de teste confirmados. Scaffold com setup completo. |
| `app/controllers/admin/calendar_controller.rb` | `Admin::CalendarController < Admin::BaseController` com action `index` completa | VERIFIED | Herança, query com `includes(:client)`, `parse_month_param` com `rescue Date::Error`, todos os assigns necessários. |
| `app/helpers/application_helper.rb` | Helper `client_color(client)` com paleta de 8 cores | VERIFIED | 8 entradas com strings literais Tailwind hex, retorno por `client.id % palette.size`. |
| `app/views/admin/calendar/index.html.erb` | View principal com `turbo-frame id="calendar-content"` e setas fora do frame | VERIFIED | Setas de nav nas linhas 3-27, `<turbo-frame id="calendar-content">` linha 29. |
| `app/views/admin/calendar/_calendar_grid.html.erb` | Grade 7 colunas com chips coloridos, `client_color`, `admin_arte_path`, overflow `+N` | VERIFIED | `grid-cols-7`, `client_color`, `admin_arte_path`, `overflow` calculado, `+<%= overflow %>` renderizado. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `_sidebar.html.erb` | `admin_calendar_index_path` | nav_items hash | WIRED | Linha 16 confirmada — não mais `"#"`. |
| `config/routes.rb` | `admin/calendar#index` | `resources :calendar` namespace `:admin` | WIRED | Linha 20 dentro do bloco `namespace :admin do`. |
| `app/controllers/admin/calendar_controller.rb` | `Arte.where(...).includes(:client).order(:id)` | ActiveRecord query | WIRED | Linha 19-21: query sem filtro de client, com `includes(:client)`. |
| `app/helpers/application_helper.rb` | paleta de 8 cores, `palette[client.id % palette.size]` | cálculo modular | WIRED | Linha 15: `palette[client.id % palette.size]`. |
| `app/views/admin/calendar/index.html.erb` | `_calendar_grid.html.erb` | `render "calendar_grid"` | WIRED | Linha 30: `<%= render "calendar_grid", grid_dates: @grid_dates, ...`. |
| `_calendar_grid.html.erb` | `admin_arte_path(arte)` | `link_to` no chip | WIRED | Linha 29: `link_to admin_arte_path(arte)`. |
| `_calendar_grid.html.erb` | `client_color(arte.client)` | helper call | WIRED | Linha 28: `color = client_color(arte.client)`. |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `_calendar_grid.html.erb` | `artes_by_date[date]` | `Arte.where(scheduled_on: ...).includes(:client).order(:id)` no controller | Sim — query ActiveRecord ao banco, sem return estático | FLOWING |
| `index.html.erb` | `@month_label`, `@prev_month`, `@next_month` | Calculados no controller a partir de `@current_month` | Sim — computados a cada request | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Evidência | Status |
|----------|-----------|--------|
| Controller existe e herda BaseController | `class Admin::CalendarController < Admin::BaseController` — verificado por leitura direta | PASS |
| Query sem filtro de cliente (todos os clientes) | `Arte.where(scheduled_on: grid_start..grid_end)` — sem cláusula `client_id:` | PASS |
| `rescue Date::Error` em `parse_month_param` | Linhas 29-34 do controller | PASS |
| Setas de navegação FORA do turbo-frame | Nav div (linhas 3-27) precede `<turbo-frame>` (linha 29) | PASS |
| Overflow `+N` implementado | `overflow = artes_do_dia.size - 3` + `if overflow > 0` renderiza `+<%= overflow %>` | PASS |
| 12 testes no arquivo de testes | Confirmado por `grep -c` | PASS |
| Todos os commits documentados existem | `8ecd77b`, `f29af36`, `69e7bb8`, `b8a1ccf`, `538a833`, `a5d0078` — todos no histórico git | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Descrição | Status | Evidência |
|-------------|------------|-----------|--------|-----------|
| CADM-01 | 14-01, 14-03 | Admin acessa "Calendário" pelo link do sidebar (wired, não mais `#`) | SATISFIED | Sidebar linha 16: `admin_calendar_index_path`. Rota registrada em routes.rb. |
| CADM-02 | 14-02, 14-03 | Admin vê calendário mensal com artes de todos os clientes agrupadas por dia | SATISFIED | Query sem filtro de client, `group_by(&:scheduled_on)`, grid renderiza por data. |
| CADM-03 | 14-02, 14-03 | Cada arte exibe cor de fundo única por cliente e nome/iniciais visível | SATISFIED | `client_color` com 8 cores por `client.id % 8`; iniciais 2 chars + `title=client.name`. |
| CADM-04 | 14-02, 14-03 | Admin navega entre meses no calendário admin | SATISFIED | `parse_month_param` com `rescue Date::Error`; setas com `data: { turbo_frame: "calendar-content" }`; teste `test_navigates_to_specific_month` e `test_invalid_month_param_does_not_crash`. |
| CADM-05 | 14-03 | Admin clica numa arte e acessa a página da arte diretamente | SATISFIED | `link_to admin_arte_path(arte)` em cada chip; teste `test_chip_links_to_arte`. |

Nenhum requirement ID da fase está sem cobertura. Nenhum ID órfão.

---

### Anti-Patterns Found

| File | Padrão | Severidade | Impacto |
|------|--------|-----------|---------|
| `test/controllers/admin/calendar_controller_test.rb` | 4 testes do Plano 02 + 8 testes do Plano 03 = 12 testes, com duplicação funcional (ex: "retorna 200 quando autenticado" aparece duas vezes com nomes distintos) | INFO | Duplicação não prejudica cobertura nem corretude — apenas aumenta tempo de execução marginalmente. Não é bloqueante. |

Nenhum `TBD`, `FIXME`, `XXX` não referenciado encontrado nos arquivos da fase. O comentário `# Testes adicionados no plano 14-03` no arquivo de testes foi substituído pelos testes reais e não persiste no código final.

**Nota sobre o `test_displays_all_client_artes`:** O Plano 03 declarou como artifact must-have `contains: "test_displays_all_client_artes"`, mas o teste implementado chama-se `test_displays_client_name`. O comportamento testado é equivalente (`assert_includes response.body, @client.name`). Discrepância de nome somente — não afeta corretude.

---

### Human Verification Required

#### 1. Navegação por turbo-frame sem full page reload

**Test:** Autenticar como admin em `/admin/calendar`. Clicar na seta "Mês anterior" ou "Próximo mês".
**Expected:** Apenas o conteúdo da grade do calendário (dentro do `turbo-frame id="calendar-content"`) atualiza. O sidebar, o header e a barra de navegação de meses permanecem sem piscar ou recarregar. A URL na barra de endereço atualiza para `?month=YYYY-MM`.
**Why human:** O wiring `data-turbo-frame: "calendar-content"` é verificável estaticamente e está correto. No entanto, o comportamento de partial update requer o JS do Hotwire/Turbo carregado e ativo no browser — não é verificável via grep. Um JS bloqueado, um asset não compilado ou um CSP restritivo poderia silenciosamente degradar para full page reload sem afetar os testes de integração.

#### 2. Renderização visual dos chips coloridos

**Test:** Abrir `/admin/calendar` no browser com artes de múltiplos clientes cadastradas. Navegar até um mês com artes de pelo menos 2 clientes distintos.
**Expected:** Chips de clientes diferentes devem exibir cores de fundo distintas (paleta de 8 cores). As iniciais de 2 chars devem estar legíveis dentro do chip com contraste adequado. Tooltip com nome completo deve aparecer ao hover.
**Why human:** O Tailwind JIT pode não ter purgado as classes hex literais (`bg-[#F0FDF4]`, etc.) se o build de CSS não foi reexecutado após a adição do helper. As classes são literais no arquivo Ruby (correto para detecção JIT), mas a confirmação visual é necessária para garantir que o CSS compilado as inclui.

---

### Gaps Summary

Nenhum gap bloqueante identificado. Todos os 9 must-haves verificados. Os 5 CADM-0X requirements de Phase 14 estão todos satisfeitos com evidência no código.

Os 2 itens de verificação humana são relacionados ao comportamento dinâmico no browser (turbo-frame JS e CSS compilado) — não indicam código faltante ou defeituoso, mas requerem confirmação visual.

---

_Verified: 2026-06-04_
_Verifier: Claude (gsd-verifier)_
