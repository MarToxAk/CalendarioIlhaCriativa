# Phase 16: Feriados Brasileiros - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 5 (1 novo, 2 modificados, 2 novos de teste)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `app/lib/brazilian_holidays.rb` | utility (data module) | transform | `app/helpers/application_helper.rb` (módulo de lookup puro) | partial-match |
| `app/helpers/application_helper.rb` | helper | request-response | `app/helpers/application_helper.rb` (método `client_color` existente) | exact |
| `app/views/client/home/_month_calendar.html.erb` | view (partial ERB) | request-response | `app/views/admin/calendar/_calendar_grid.html.erb` | exact |
| `app/views/admin/calendar/_calendar_grid.html.erb` | view (partial ERB) | request-response | `app/views/client/home/_month_calendar.html.erb` | exact |
| `test/lib/brazilian_holidays_test.rb` | test (unit) | — | `test/models/arte_test.rb` | role-match |

---

## Pattern Assignments

### `app/lib/brazilian_holidays.rb` (utility, transform) — NOVO

**Analog:** `app/helpers/application_helper.rb` — padrão de módulo Ruby sem estado de instância.

Não há módulo `app/lib/` existente no projeto. O padrão de módulo Ruby puro está documentado integralmente no RESEARCH.md (Pattern 1). Usar o esqueleto abaixo, que segue as convenções Ruby do projeto (freeze, método de classe, sem `require` explícito pois Rails autoloads `app/lib/`).

**Padrão de estrutura do módulo** (extraído de RESEARCH.md Pattern 1):
```ruby
# app/lib/brazilian_holidays.rb
module BrazilianHolidays
  HOLIDAYS = {
    2025 => {
      Date.new(2025, 1, 1) => "Ano Novo",
      # ... demais datas ...
    }.freeze,
    2026 => { ... }.freeze,
    2027 => { ... }.freeze,
  }.freeze

  def self.for(year)
    HOLIDAYS.fetch(year, {})
  end
end
```

**Convenções observadas no projeto:**
- Sem `require` para `Date` — Rails/bundler já provê o stdlib
- Sem `autoload` manual — `app/lib/` é coberto pela convenção Rails Engine
- `.freeze` em cada sub-hash e no hash externo (imutabilidade em runtime)
- `HOLIDAYS.fetch(year, {})` em vez de `HOLIDAYS[year] || {}` — idioma explícito

---

### `app/helpers/application_helper.rb` (helper, request-response) — MODIFICAR

**Analog:** `app/helpers/application_helper.rb` linhas 4–16 — método `client_color(client)` existente.

**Padrão de helper existente** (`app/helpers/application_helper.rb`, linhas 4–16):
```ruby
module ApplicationHelper
  include Pagy::Frontend

  def client_color(client)
    palette = [...]
    palette[client.id % palette.size]
  end
end
```

**Padrão a copiar — estrutura do método:** método público de instância, sem `private`, recebe um objeto e retorna valor derivado ou `nil`. Adicionar `brazilian_holiday_for` seguindo o mesmo idioma:

```ruby
# Inserir após client_color, dentro do module ApplicationHelper
def brazilian_holiday_for(date)
  BrazilianHolidays.for(date.year)[date]
end
```

**Regras observadas no helper existente:**
- Sem `rescue` inline — o método não lança exceção em uso normal
- Retorno simples e direto (sem variável intermediária)
- Sem comentário de documentação (padrão do projeto)

---

### `app/views/client/home/_month_calendar.html.erb` (view partial, request-response) — MODIFICAR

**Analog:** arquivo em si (lido acima); ponto de inserção identificado nas linhas 24–26.

**Estrutura existente relevante** (`_month_calendar.html.erb`, linhas 10–33):
```erb
<% grid_dates.each do |date| %>
  <%
    artes_do_dia = artes_by_date[date] || []
    is_current_month = date.month == current_month.month
  %>
  <div class="<%= is_current_month ? 'bg-white' : 'bg-gray-50' %> min-h-[100px] p-1.5">
    <% if date == Date.today %>
      <span class="text-xs font-medium bg-[#EA580C] text-white rounded-full w-5 h-5 inline-flex items-center justify-center">
        <%= date.day %>
      </span>
    <% else %>
      <span class="text-xs font-medium <%= artes_do_dia.any? ? 'text-slate-700' : 'text-gray-300' %>">
        <%= date.day %>
      </span>
    <% end %>

    <%# INSERIR AQUI — após o end do if/else do número do dia, antes do each de artes %>

    <% artes_do_dia.each do |arte| %>
```

**Snippet a inserir** (após a linha 24, antes do bloco `artes_do_dia.each`):
```erb
<% if (holiday = brazilian_holiday_for(date)) %>
  <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
    <%= truncate(holiday, length: 15) %>
  </span>
<% end %>
```

**Convenções de classe Tailwind observadas no arquivo existente:**
- `text-xs font-medium` para elementos de texto dentro das células
- `bg-[#EA580C]` — hex inline é o padrão; `text-red-400` é classe utilitária padrão (compatível)
- `min-h-[100px] p-1.5` — cell wrapper existente; não alterar

**Alerta de inserção (Pitfall 3 do RESEARCH.md):** o span de feriado deve ficar **fora e após** o bloco `if date == Date.today ... else ... end` — não dentro de nenhum dos dois branches. Caso contrário, dias de hoje que sejam feriado não exibirão o nome.

---

### `app/views/admin/calendar/_calendar_grid.html.erb` (view partial, request-response) — MODIFICAR

**Analog:** arquivo em si; ponto de inserção identificado nas linhas 23–24.

**Diferença-chave em relação ao calendário do cliente** (`_calendar_grid.html.erb`, linha 14):
```erb
<% if date == Time.zone.today %>   <%# usa Time.zone.today, não Date.today %>
```

**Estrutura existente relevante** (`_calendar_grid.html.erb`, linhas 8–26):
```erb
<% grid_dates.each do |date| %>
  <%
    artes_do_dia = artes_by_date[date] || []
    is_current_month = date.month == current_month.month
  %>
  <div class="<%= is_current_month ? 'bg-white' : 'bg-gray-50' %> min-h-[80px] p-1.5">
    <% if date == Time.zone.today %>
      <span class="text-xs font-medium bg-[#EA580C] text-white rounded-full w-5 h-5 inline-flex items-center justify-center">
        <%= date.day %>
      </span>
    <% else %>
      <span class="text-xs font-medium <%= artes_do_dia.any? ? 'text-slate-700' : 'text-gray-300' %>">
        <%= date.day %>
      </span>
    <% end %>

    <%# INSERIR AQUI — após o end do if/else do número do dia, antes do visible = artes_do_dia.first(3) %>

    <% visible = artes_do_dia.first(3) %>
```

**Snippet a inserir** (idêntico ao do calendário cliente):
```erb
<% if (holiday = brazilian_holiday_for(date)) %>
  <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
    <%= truncate(holiday, length: 15) %>
  </span>
<% end %>
```

**Diferença de altura da célula:** `min-h-[80px]` vs `min-h-[100px]` no cliente. Não alterar — o span de feriado empurra o conteúdo para baixo naturalmente; a célula expande via `min-h`.

---

### `test/lib/brazilian_holidays_test.rb` (test unit) — NOVO

**Analog:** `test/models/arte_test.rb` (linhas 1–40) — padrão `ActiveSupport::TestCase` com `require "test_helper"` e blocos `test "..." do`.

**Padrão de teste do projeto** (`test/models/arte_test.rb`, linhas 1–15):
```ruby
require "test_helper"

class ArteTest < ActiveSupport::TestCase
  def setup
    # criação de objetos necessários
  end

  test "descrição do comportamento esperado" do
    # arrange + act + assert
    assert_equal valor_esperado, valor_real
  end
end
```

**Convenções do framework** (`test/test_helper.rb`, linhas 1–16):
```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all
  end
end
```

**Padrão de assertions usado no projeto:**
- `assert_equal expected, actual` — padrão principal
- `assert_instance_of Klass, obj` — para verificar tipo
- `assert_nil obj` — para verificar ausência
- `assert obj.any?` — para coleções não vazias
- Sem `expect`/`describe` (não é RSpec — é Minitest puro)

**Ponto de atenção:** `fixtures :all` no `test_helper.rb` carrega todos os fixtures. O module `BrazilianHolidays` não usa ActiveRecord, portanto fixtures não interferem. Não incluir `def setup` se não houver estado de instância necessário.

---

## Shared Patterns

### Tailwind CSS inline nas views ERB
**Source:** `app/views/client/home/_month_calendar.html.erb` e `app/views/admin/calendar/_calendar_grid.html.erb`
**Apply to:** Span de feriado em ambas as views
```erb
class="text-xs text-red-400 block truncate leading-snug mt-0.5"
```
- `text-xs` — tamanho canônico para elementos secundários nas células (igual ao número do dia)
- `block` — necessário para o span ocupar linha própria abaixo do número
- `truncate` — classe CSS Tailwind (overflow: hidden; text-overflow: ellipsis) como segurança visual
- `leading-snug` e `mt-0.5` — espaçamento compacto, consistente com densidade das células

### Padrão de helper nil-safe
**Source:** `app/helpers/application_helper.rb`
**Apply to:** `brazilian_holiday_for(date)` no helper e nas views
```erb
<%# Na view — idioma nil-safe sem if/unless separado %>
<% if (holiday = brazilian_holiday_for(date)) %>
  <%= holiday %>
<% end %>
```
O método retorna `nil` quando não há feriado (via `Hash#[]` sobre hash que não contém a chave). A view usa o padrão de atribuição inline no condicional — idioma estabelecido em ERB no projeto.

### Padrão de testes de controller para integração (FERI-02 / FERI-03)
**Source:** `test/controllers/client/home_controller_test.rb` linhas 16–35 e `test/controllers/admin/calendar_controller_test.rb` linhas 21–30
**Apply to:** Testes de integração que verificam renderização de feriados nos dois controllers
```ruby
# Padrão: GET com month param específico + assert_includes response.body
test "exibe nome do feriado na célula para mês com feriado" do
  sign_in_as_client(@client)                      # ou sign_in_as(@user) no admin
  get client_root_path(token: @client.access_token, month: "2026-04")
  assert_response :success
  assert_includes response.body, "Tiradentes"     # feriado conhecido em 21/04
end
```
Usar `month: "2026-04"` (contém Tiradentes em 21/04 e Páscoa em 05/04) — datas determinísticas independentes da data do sistema.

---

## No Analog Found

Nenhum arquivo sem análogo nesta fase. Todos os padrões têm referência direta no código existente ou no RESEARCH.md com dados verificados.

---

## Metadata

**Analog search scope:** `app/helpers/`, `app/views/client/home/`, `app/views/admin/calendar/`, `test/models/`, `test/controllers/`
**Files scanned:** 8 (application_helper.rb, _month_calendar.html.erb, _calendar_grid.html.erb, arte_test.rb, home_controller_test.rb, calendar_controller_test.rb, test_helper.rb, home_controller.rb)
**Pattern extraction date:** 2026-06-04
