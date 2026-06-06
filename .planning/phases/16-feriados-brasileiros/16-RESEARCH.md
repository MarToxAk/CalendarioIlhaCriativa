# Phase 16: Feriados Brasileiros — Research

**Researched:** 2026-06-04
**Domain:** Ruby module puro + ApplicationHelper + ERB views (Rails 8.1)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01: Estrutura de armazenamento**
- Módulo Ruby puro em `app/lib/brazilian_holidays.rb` com método público `BrazilianHolidays.for(year)` retornando um hash `{ Date => "Nome do Feriado" }`.
- Feriados hardcoded por ano — hash com chave anual: `{ 2025 => { Date.new(2025,1,1) => "Ano Novo", ... }, 2026 => {...}, 2027 => {...} }`.
- Feriados móveis (Páscoa, Carnaval = 47 dias antes, Corpus Christi = 60 dias depois) hardcoded por ano — sem algoritmo, sem gem extra.
- `for(year)` retorna hash vazio se o ano não estiver na lista (não lança exceção).

**D-02: Visual nas células**
- Texto abaixo do número do dia — nome do feriado em `text-xs` logo após o span do número do dia.
- Cor: vermelho/rosa discreto — `text-red-400` (remete ao calendário físico com dias vermelhos).
- Sem alterar o fundo da célula; sem badge extra. Layout: número → [nome feriado em vermelho] → chips de artes.
- Comportamento em ambos os calendários é idêntico — mesma lógica de helper.

**D-03: Escopo da lista**
- Feriados nacionais (12 oficiais): Ano Novo (1/jan), Carnaval (móvel), Sexta-feira Santa (móvel), Tiradentes (21/abr), Dia do Trabalho (1/mai), Corpus Christi (móvel), Independência (7/set), Nossa Sra. Aparecida (12/out), Finados (2/nov), Proclamação da República (15/nov), Natal (25/dez).
- Comemorativos de marketing adicionais: Páscoa (domingo móvel), Dia das Mães (2º domingo de maio), Dia dos Namorados (12/jun), Dia dos Pais (2º domingo de agosto), Dia das Crianças (12/out — coincide com Aparecida), Black Friday (4ª sexta de novembro).
- Total: ~15–20 datas por ano.
- Feriados estaduais/municipais: fora de escopo.

### Claude's Discretion

- Nome do helper de acesso na view: `brazilian_holiday_for(date)` em `ApplicationHelper` — chama `BrazilianHolidays.for(date.year)[date]`.
- Truncamento do nome na célula: se > 15 chars, truncar com `…` via `truncate(name, length: 15)` para não quebrar o layout.
- Testes: cobertura unitária do module `BrazilianHolidays` (datas fixas + anos sem cobertura).

### Deferred Ideas (OUT OF SCOPE)

- Feriados estaduais/municipais — nova fase se necessário
- Destaque de fundo na célula (toda a célula colorida) — possível refinamento visual futuro
- Gerenciamento de feriados via interface admin (CRUD) — complexidade sem benefício agora
- Feriados para anos além de 2027 — adicionar quando necessário
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FERI-01 | Sistema contém lista hardcoded dos feriados nacionais brasileiros e dias comemorativos de marketing para os anos correntes | `BrazilianHolidays.for(year)` em `app/lib/brazilian_holidays.rb` — autoloaded por Rails Engine (todos os subdiretórios de `app/` são autoloaded) |
| FERI-02 | Calendário do cliente exibe dias de feriado/comemorativo com destaque e nome visível na célula | Inserir span `text-xs text-red-400 block truncate leading-snug mt-0.5` após o span do número em `_month_calendar.html.erb` |
| FERI-03 | Calendário do admin exibe dias de feriado/comemorativo com destaque e nome visível na célula | Inserir mesmo span após o span do número em `_calendar_grid.html.erb`, antes dos chips de artes |
</phase_requirements>

---

## Summary

Esta fase é cirúrgica e bem delimitada: criar um módulo Ruby puro com dados hardcoded, adicionar um helper de uma linha ao `ApplicationHelper` existente, e inserir um trecho ERB em duas views de calendário. Não há banco de dados, sem gems novas, sem rotas, sem controllers. O risco técnico é mínimo.

O único ponto de atenção descoberto durante a pesquisa é o diretório de destino do módulo: o CONTEXT.md especifica `app/lib/brazilian_holidays.rb`, e confirmei que **todos os subdiretórios de `app/` são autoloaded pelo Rails Engine automaticamente** (documentado em `railties-8.1.3/lib/rails/engine.rb` linha 110: "all folders under app are automatically added to the load path"). O diretório `app/lib/` ainda não existe no projeto e deve ser criado. O `config.autoload_lib` presente em `config/application.rb` autoloads o `lib/` da raiz do projeto — são caminhos distintos; `app/lib/` é coberto pela convenção padrão do Rails Engine.

As datas móveis para 2025, 2026 e 2027 foram calculadas e verificadas via script Ruby na máquina do projeto, eliminando a necessidade de hardcoding com base apenas em treinamento.

**Primary recommendation:** Criar `app/lib/brazilian_holidays.rb` com hash explícito de datas calculadas, adicionar `brazilian_holiday_for(date)` ao `ApplicationHelper`, e inserir o span de feriado nas duas views ERB exatamente nos pontos de inserção identificados.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Lista de feriados | Ruby module (`app/lib`) | — | Dados estáticos puros, sem persistência, sem camada de rede |
| Lookup por data | ApplicationHelper | — | Helper de view; chama o module; não pertence ao controller (sem impacto em assigns) |
| Renderização visual — calendário cliente | View ERB (`client/home/_month_calendar`) | — | Apresentação; dados chegam via `grid_dates` já calculado no controller |
| Renderização visual — calendário admin | View ERB (`admin/calendar/_calendar_grid`) | — | Mesma responsabilidade que acima |
| Truncamento do nome | View ERB (helper Rails `truncate`) | — | Preocupação puramente de apresentação |

---

## Standard Stack

### Core

| Componente | Versão | Propósito | Por que padrão |
|-----------|--------|-----------|---------------|
| Ruby stdlib `Date` | 3.3.3 (ruby) | `Date.new(year, month, day)` para chaves do hash | Já disponível; sem gem extra |
| Rails ApplicationHelper | 8.1.3 | `brazilian_holiday_for(date)` helper de view | Padrão estabelecido pelo `client_color` existente |
| ActionView `truncate` | 8.1.3 | Truncar nome > 15 chars com `…` | Já usado em `admin/approvals/` — padrão verificado no código |
| Tailwind CSS `text-red-400` | 4.x (tailwindcss-rails) | Cor canônica de feriado | Classe utilitária padrão; sem customização necessária |

[VERIFIED: código-fonte do projeto] Confirmado `ruby 3.3.3`, `rails 8.1.3`, `tailwindcss-rails` via Gemfile.lock.

### Sem gems novas

Esta fase não instala nenhuma dependência nova. Toda a implementação usa o stdlib Ruby e helpers Rails existentes.

---

## Package Legitimacy Audit

> Não aplicável. Esta fase não instala gems ou pacotes externos.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Request (browser)
      |
      v
[Controller] (home_controller / calendar_controller)
  - grid_dates: Array<Date>  (range de datas da grade)
  - artes_by_date: Hash<Date, Array<Arte>>
      |
      v
[View ERB] (_month_calendar / _calendar_grid)
  grid_dates.each do |date|
      |
      +---> span: número do dia  (existente)
      |
      +---> brazilian_holiday_for(date)   <-- NOVO
      |          |
      |          v
      |     [ApplicationHelper#brazilian_holiday_for]
      |          |
      |          v
      |     [BrazilianHolidays.for(date.year)]  (app/lib)
      |          |
      |          +-- Hash{Date => String} lookup
      |          |
      |          +-- returns: String | nil
      |
      +---> se String: renderiza span text-red-400 truncado
      |
      +---> chips de artes  (existente)
```

### Recommended Project Structure

```
app/
├── lib/                          # NOVO diretório (autoloaded pelo Rails Engine)
│   └── brazilian_holidays.rb    # NOVO: module BrazilianHolidays
├── helpers/
│   └── application_helper.rb    # MODIFICAR: adicionar brazilian_holiday_for(date)
└── views/
    ├── client/home/
    │   └── _month_calendar.html.erb   # MODIFICAR: inserir span feriado
    └── admin/calendar/
        └── _calendar_grid.html.erb    # MODIFICAR: inserir span feriado

test/
├── lib/                          # NOVO diretório
│   └── brazilian_holidays_test.rb   # NOVO: testes unitários do module
└── helpers/                      # já existe (vazio)
    └── application_helper_test.rb   # NOVO: testes do helper
```

### Pattern 1: Module Ruby puro como repositório de dados estáticos

**What:** Módulo com método de classe que retorna um hash imutável indexado por `Date`. Sem estado de instância, sem banco de dados.
**When to use:** Dados que mudam raramente, volume pequeno (< 100 itens/ano), sem necessidade de consulta por múltiplos critérios.

```ruby
# Source: decisão D-01 de 16-CONTEXT.md + padrão Ruby stdlib
module BrazilianHolidays
  HOLIDAYS = {
    2025 => {
      Date.new(2025, 1, 1)  => "Ano Novo",
      Date.new(2025, 3, 3)  => "Carnaval",
      Date.new(2025, 3, 4)  => "Carnaval",
      Date.new(2025, 4, 18) => "Sexta-feira Santa",
      Date.new(2025, 4, 20) => "Páscoa",
      Date.new(2025, 4, 21) => "Tiradentes",
      Date.new(2025, 5, 1)  => "Dia do Trabalho",
      Date.new(2025, 5, 11) => "Dia das Mães",
      Date.new(2025, 6, 12) => "Dia dos Namorados",
      Date.new(2025, 6, 19) => "Corpus Christi",
      Date.new(2025, 8, 10) => "Dia dos Pais",
      Date.new(2025, 9, 7)  => "Independência",
      Date.new(2025, 10, 12) => "Ap. / Crianças",
      Date.new(2025, 11, 2)  => "Finados",
      Date.new(2025, 11, 15) => "Rep. da República",
      Date.new(2025, 11, 28) => "Black Friday",
      Date.new(2025, 12, 25) => "Natal",
    }.freeze,
    2026 => {
      Date.new(2026, 1, 1)  => "Ano Novo",
      Date.new(2026, 2, 16) => "Carnaval",
      Date.new(2026, 2, 17) => "Carnaval",
      Date.new(2026, 4, 3)  => "Sexta-feira Santa",
      Date.new(2026, 4, 5)  => "Páscoa",
      Date.new(2026, 4, 21) => "Tiradentes",
      Date.new(2026, 5, 1)  => "Dia do Trabalho",
      Date.new(2026, 5, 10) => "Dia das Mães",
      Date.new(2026, 6, 4)  => "Corpus Christi",
      Date.new(2026, 6, 12) => "Dia dos Namorados",
      Date.new(2026, 8, 9)  => "Dia dos Pais",
      Date.new(2026, 9, 7)  => "Independência",
      Date.new(2026, 10, 12) => "Ap. / Crianças",
      Date.new(2026, 11, 2)  => "Finados",
      Date.new(2026, 11, 15) => "Rep. da República",
      Date.new(2026, 11, 27) => "Black Friday",
      Date.new(2026, 12, 25) => "Natal",
    }.freeze,
    2027 => {
      Date.new(2027, 1, 1)  => "Ano Novo",
      Date.new(2027, 2, 8)  => "Carnaval",
      Date.new(2027, 2, 9)  => "Carnaval",
      Date.new(2027, 3, 26) => "Sexta-feira Santa",
      Date.new(2027, 3, 28) => "Páscoa",
      Date.new(2027, 4, 21) => "Tiradentes",
      Date.new(2027, 5, 1)  => "Dia do Trabalho",
      Date.new(2027, 5, 9)  => "Dia das Mães",
      Date.new(2027, 5, 27) => "Corpus Christi",
      Date.new(2027, 6, 12) => "Dia dos Namorados",
      Date.new(2027, 8, 8)  => "Dia dos Pais",
      Date.new(2027, 9, 7)  => "Independência",
      Date.new(2027, 10, 12) => "Ap. / Crianças",
      Date.new(2027, 11, 2)  => "Finados",
      Date.new(2027, 11, 15) => "Rep. da República",
      Date.new(2027, 11, 26) => "Black Friday",
      Date.new(2027, 12, 25) => "Natal",
    }.freeze,
  }.freeze

  def self.for(year)
    HOLIDAYS.fetch(year, {})
  end
end
```

[VERIFIED: script Ruby executado em ruby 3.3.3 na máquina do projeto] Todas as datas móveis calculadas com o algoritmo Gregoriano anônimo para Páscoa; Carnaval = Páscoa - 48 (segunda) e Páscoa - 47 (terça); Sexta Santa = Páscoa - 2; Corpus Christi = Páscoa + 60; Dia das Mães = 2º domingo de maio; Dia dos Pais = 2º domingo de agosto; Black Friday = 4ª sexta de novembro.

**Nota sobre "Ap. / Crianças":** 12/out é feriado nacional (N. Sra. Aparecida) e Dia das Crianças simultaneamente. A string `"Ap. / Crianças"` tem 14 chars — cabe sem truncamento com `length: 15`. [VERIFIED: CONTEXT.md + UI-SPEC.md]

### Pattern 2: Helper de view como proxy fino

**What:** Método no `ApplicationHelper` que delega ao module e retorna `nil` quando não há feriado. A view usa a convenção `if (holiday = ...)` para zero overhead quando nil.

```ruby
# Source: decisão Claude's Discretion de 16-CONTEXT.md
# em app/helpers/application_helper.rb
def brazilian_holiday_for(date)
  BrazilianHolidays.for(date.year)[date]
end
```

### Pattern 3: Inserção ERB no loop da grade — ponto de inserção preciso

**What:** Inserir o span de feriado imediatamente após o bloco condicional do número do dia (o `<% if date == Date.today %>...<% else %>...<% end %>`), antes dos elementos de artes.

```erb
<%# Source: 16-UI-SPEC.md — Anatomy Holiday Cell %>
<% if (holiday = brazilian_holiday_for(date)) %>
  <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
    <%= truncate(holiday, length: 15) %>
  </span>
<% end %>
```

O mesmo snippet é inserido em ambas as views, na mesma posição relativa.

### Anti-Patterns to Avoid

- **Colocar o module em `lib/` da raiz:** `config.autoload_lib` autoloads `lib/` mas com Zeitwerk, `lib/brazilian_holidays.rb` ficaria sem namespace e pode conflitar com gems. Usar `app/lib/` segue a convenção correta para código da aplicação.
- **Chamar `BrazilianHolidays.for(year)` no controller:** Não é necessário — o helper é chamado na view diretamente para cada date. Carregar no controller introduziria assign desnecessário e acoplamento.
- **Hash sem `.freeze`:** Sem `freeze`, o hash é mutável em runtime. Usar `.freeze` em cada sub-hash e no hash externo.
- **Usar `defined?` ou `respond_to?` no helper:** Desnecessário — `BrazilianHolidays.for` sempre retorna hash (nunca nil), então `[]` sobre ele retorna nil limpo.

---

## Don't Hand-Roll

| Problema | Não construir | Usar em vez disso | Por que |
|---------|-------------|------------------|---------|
| Truncamento de texto com ellipsis | lógica Ruby manual com `[0..14] + "…"` | `truncate(name, length: 15)` (ActionView) | Lida com multibyte UTF-8 corretamente; já em uso no projeto |
| Algoritmo de Páscoa em produção | algoritmo inline no module | Datas hardcoded por ano | Algoritmo Gregoriano tem borda para anos extremos; para 3 anos fixos, hardcode é mais seguro e legível |
| CSS de overflow para nome longo | `style="overflow: hidden"` inline | `truncate` Tailwind class no span | Consistente com padrão do projeto (`admin/calendar/index.html.erb` já usa `truncate` classe) |

---

## Datas Móveis Verificadas (2025–2027)

[VERIFIED: script Ruby executado em ruby 3.3.3 na máquina do projeto — 2026-06-04]

| Feriado | 2025 | 2026 | 2027 |
|---------|------|------|------|
| Carnaval (segunda) | 03/03 | 16/02 | 08/02 |
| Carnaval (terça) | 04/03 | 17/02 | 09/02 |
| Sexta-feira Santa | 18/04 | 03/04 | 26/03 |
| Páscoa | 20/04 | 05/04 | 28/03 |
| Corpus Christi | 19/06 | 04/06 | 27/05 |
| Dia das Mães | 11/05 | 10/05 | 09/05 |
| Dia dos Pais | 10/08 | 09/08 | 08/08 |
| Black Friday | 28/11 | 27/11 | 26/11 |

Feriados fixos (mesma data todo ano): Ano Novo (1/jan), Tiradentes (21/abr), Dia do Trabalho (1/mai), Dia dos Namorados (12/jun), Independência (7/set), Ap./Crianças (12/out), Finados (2/nov), Proclamação da República (15/nov), Natal (25/dez).

---

## Common Pitfalls

### Pitfall 1: `app/lib/` não existe — Rails não autoloada um diretório inexistente

**What goes wrong:** Criar o arquivo `app/lib/brazilian_holidays.rb` sem criar o diretório `app/lib/` explicitamente resulta em `NameError: uninitialized constant BrazilianHolidays` em runtime.
**Why it happens:** O Rails Engine adiciona todos os subdiretórios de `app/` ao autoload path, mas apenas os que existem quando a aplicação inicializa.
**How to avoid:** `mkdir -p app/lib` antes de criar o arquivo. [VERIFIED: railties-8.1.3 engine.rb linha 110]
**Warning signs:** `NameError: uninitialized constant BrazilianHolidays` ao subir o servidor.

### Pitfall 2: Truncate Rails vs. truncate classe Tailwind — dois usos do mesmo nome

**What goes wrong:** Confundir `truncate(holiday, length: 15)` (helper Ruby que retorna string encurtada) com a classe CSS `truncate` (overflow: hidden; text-overflow: ellipsis). São coisas distintas.
**Why it happens:** O span usa `class="... truncate ..."` (CSS) E `truncate(holiday, length: 15)` (helper) simultaneamente — a CSS garante overflow visual, o helper garante que o DOM não cresce excessivamente.
**How to avoid:** O padrão do UI-SPEC.md aplica ambos: helper no ERB, classe Tailwind no elemento. [VERIFIED: UI-SPEC.md Anatomy Holiday Cell]

### Pitfall 3: Feriado em dia hoje (círculo laranja) — verificar que o span de feriado aparece no branch correto

**What goes wrong:** O número do dia tem um `if date == Date.today` / `else` com dois spans diferentes. O span de feriado deve aparecer em AMBOS os branches.
**Why it happens:** Ao inserir o span de feriado apenas no branch `else`, dias de feriado que coincidem com hoje não exibem o nome.
**How to avoid:** Inserir o bloco `if (holiday = brazilian_holiday_for(date))` FORA e APÓS o `if/else/end` do número do dia.
**Warning signs:** Testar com uma data de hoje que seja feriado (ou simular com stub).

### Pitfall 4: Dia 12/out com string > 15 chars em raw

**What goes wrong:** "Nossa Sra. Aparecida" tem 20 chars — com `truncate(..., length: 15)` fica "Nossa Sra. Apa…", que não é descritivo.
**How to avoid:** Usar a string canônica do UI-SPEC.md diretamente no hash: `"Ap. / Crianças"` (14 chars) — cabe sem truncamento.
**Warning signs:** Ver "Nossa Sra. Apa…" no calendário.

### Pitfall 5: Teste de module em diretório errado

**What goes wrong:** Colocar o teste em `test/models/brazilian_holidays_test.rb` — não é um model ActiveRecord, então o namespace fica conceitualmente errado e `fixtures :all` pode causar overhead desnecessário.
**How to avoid:** Criar `test/lib/brazilian_holidays_test.rb` — reflete a estrutura `app/lib/`. [ASSUMED] O Rails test runner (`bin/rails test`) descobre arquivos em qualquer subdiretório de `test/`.

---

## Code Examples

### Ponto de inserção exato — `_month_calendar.html.erb`

```erb
<%# Source: app/views/client/home/_month_calendar.html.erb — código existente %>
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

  <%# NOVO: inserir aqui, após o if/else/end do número do dia %>
  <% if (holiday = brazilian_holiday_for(date)) %>
    <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
      <%= truncate(holiday, length: 15) %>
    </span>
  <% end %>

  <% artes_do_dia.each do |arte| %>
    <%# ... chips existentes — não alterar %>
  <% end %>
</div>
```

### Ponto de inserção exato — `_calendar_grid.html.erb`

```erb
<%# Source: app/views/admin/calendar/_calendar_grid.html.erb — código existente %>
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

  <%# NOVO: inserir aqui, após o if/else/end do número do dia %>
  <% if (holiday = brazilian_holiday_for(date)) %>
    <span class="text-xs text-red-400 block truncate leading-snug mt-0.5">
      <%= truncate(holiday, length: 15) %>
    </span>
  <% end %>

  <% visible = artes_do_dia.first(3) %>
  <%# ... chips existentes — não alterar %>
</div>
```

### Testes unitários do module (padrão do projeto)

```ruby
# Source: padrão ActiveSupport::TestCase estabelecido em test/models/arte_test.rb
require "test_helper"

class BrazilianHolidaysTest < ActiveSupport::TestCase
  test "retorna hash para ano coberto 2026" do
    result = BrazilianHolidays.for(2026)
    assert_instance_of Hash, result
    assert result.any?
  end

  test "retorna hash vazio para ano sem cobertura" do
    result = BrazilianHolidays.for(2030)
    assert_equal({}, result)
  end

  test "Ano Novo 2026 está presente" do
    holidays = BrazilianHolidays.for(2026)
    assert_equal "Ano Novo", holidays[Date.new(2026, 1, 1)]
  end

  test "Corpus Christi 2026 está em 04/06" do
    holidays = BrazilianHolidays.for(2026)
    assert_equal "Corpus Christi", holidays[Date.new(2026, 6, 4)]
  end

  test "Black Friday 2026 está em 27/11" do
    holidays = BrazilianHolidays.for(2026)
    assert_equal "Black Friday", holidays[Date.new(2026, 11, 27)]
  end

  test "Dia das Mães 2025 está em 11/05" do
    holidays = BrazilianHolidays.for(2025)
    assert_equal "Dia das Mães", holidays[Date.new(2025, 5, 11)]
  end

  test "data sem feriado retorna nil" do
    holidays = BrazilianHolidays.for(2026)
    assert_nil holidays[Date.new(2026, 3, 10)]
  end

  test "cobre os três anos configurados" do
    [2025, 2026, 2027].each do |year|
      assert BrazilianHolidays.for(year).any?, "Ano #{year} deve ter feriados"
    end
  end
end
```

---

## Autoloading: Confirmação de `app/lib/`

[VERIFIED: railties-8.1.3/lib/rails/engine.rb linha 110]

A documentação do Rails Engine confirma: "all folders under app are automatically added to the load path." Isso significa que criar o diretório `app/lib/` e o arquivo `app/lib/brazilian_holidays.rb` é suficiente — sem nenhuma configuração adicional em `config/application.rb`.

**Distinção importante:** O `config.autoload_lib(ignore: %w[assets tasks])` presente em `config/application.rb` autoloads o diretório `lib/` da **raiz do projeto** (não `app/lib/`). São caminhos independentes:
- `lib/` (raiz) → autoloaded via `config.autoload_lib`
- `app/lib/` → autoloaded via convenção Rails Engine (automático)

O module `BrazilianHolidays` em `app/lib/` será acessível em helpers, views e testes sem configuração extra.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Minitest via ActiveSupport::TestCase |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/lib/brazilian_holidays_test.rb` |
| Full suite command | `bin/rails test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FERI-01 | `BrazilianHolidays.for(year)` retorna hash com datas corretas | unit | `bin/rails test test/lib/brazilian_holidays_test.rb` | Criar em Wave 0 |
| FERI-01 | `BrazilianHolidays.for(ano_sem_cobertura)` retorna `{}` | unit | `bin/rails test test/lib/brazilian_holidays_test.rb` | Criar em Wave 0 |
| FERI-02 | Calendário cliente renderiza nome do feriado para data com feriado | integration | `bin/rails test test/controllers/client/home_controller_test.rb` | Existente — adicionar caso |
| FERI-03 | Calendário admin renderiza nome do feriado para data com feriado | integration | `bin/rails test test/controllers/admin/calendar_controller_test.rb` | Existente — adicionar caso |

### Sampling Rate

- **Por task commit:** `bin/rails test test/lib/brazilian_holidays_test.rb`
- **Por wave merge:** `bin/rails test`
- **Phase gate:** `bin/rails test` verde antes de `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lib/` — diretório novo; criar com `mkdir -p test/lib`
- [ ] `test/lib/brazilian_holidays_test.rb` — cobre FERI-01 (module unit tests)
- [ ] `app/lib/` — diretório novo; criar com `mkdir -p app/lib`

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1` — avaliação obrigatória.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Fase não introduz endpoints nem sessões |
| V3 Session Management | no | Sem sessão nova |
| V4 Access Control | no | Dados estáticos, sem ação do usuário |
| V5 Input Validation | no | O module não recebe input do usuário; `date.year` é Integer da grade |
| V6 Cryptography | no | Sem dados sensíveis |

### Known Threat Patterns

Esta fase não introduz vetores de ataque conhecidos:
- O module `BrazilianHolidays` não recebe input externo — os argumentos `date` vêm de `grid_dates`, que é um range de `Date` calculado internamente pelo controller.
- A view usa `truncate(holiday, length: 15)` sobre uma string hardcoded — sem XSS possível (string vem do hash compilado no módulo, não de params do usuário).
- Sem queries SQL novas, sem entrada de rede.

**Brakeman:** Fase não deve introduzir novas advertências. O `truncate` sobre string literal de hash é seguro. Rails automaticamente escapa output ERB via `<%= %>`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby stdlib `Date` | `BrazilianHolidays.for(year)` | yes | 3.3.3 | — |
| Rails ApplicationHelper | `brazilian_holiday_for(date)` | yes | 8.1.3 | — |
| ActionView `truncate` | span de feriado na view | yes | 8.1.3 | — |
| Tailwind `text-red-400` | span de feriado na view | yes | 4.x | — |

**Missing dependencies with no fallback:** nenhuma.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `bin/rails test` descobre `test/lib/*.rb` automaticamente sem configuração adicional | Validation Architecture | Baixo — se falhar, adicionar `test/lib/**/*_test.rb` ao require explicitamente em test_helper |

**Todos os outros claims foram verificados via código-fonte do projeto ou via script Ruby executado na máquina.**

---

## Open Questions

1. **Teste de integração para FERI-02 e FERI-03**
   - What we know: Os testes de controller existentes (`home_controller_test.rb`, `calendar_controller_test.rb`) fazem GET e verificam `assert_response :success` e presença de strings no `response.body`.
   - What's unclear: Para testar que o nome do feriado aparece, o teste precisa navegar para um mês que contenha um feriado conhecido. Isso é determinístico (datas hardcoded), mas o teste pode ser frágil se o mês atual não tiver feriados no grid.
   - Recommendation: Parametrizar o mês do teste para `?month=2026-04` (contém Páscoa em 05/04 e Tiradentes em 21/04) — sempre funciona independente da data do sistema.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| gem `holidays` ou API externa | Module Ruby puro hardcoded | Decisão D-01 | Sem dependência externa; lista curada para contexto brasileiro |

---

## Sources

### Primary (HIGH confidence)
- `railties-8.1.3/lib/rails/engine.rb` linha 110 — autoloading de subdiretórios de `app/`
- `railties-8.1.3/lib/rails/application/configuration.rb` — implementação de `autoload_lib`
- `actionview-8.1.3/lib/action_view/helpers/text_helper.rb` — implementação de `truncate`
- `.planning/phases/16-feriados-brasileiros/16-CONTEXT.md` — decisões locked
- `.planning/phases/16-feriados-brasileiros/16-UI-SPEC.md` — contrato visual
- `app/views/client/home/_month_calendar.html.erb` — código atual da view do cliente
- `app/views/admin/calendar/_calendar_grid.html.erb` — código atual da view do admin
- `app/helpers/application_helper.rb` — helper existente com `client_color`
- `config/application.rb` — confirma Rails 8.1, `config.autoload_lib`, timezone Brasilia
- Script Ruby executado em ruby 3.3.3 — cálculo de todas as datas móveis 2025–2027

### Secondary (MEDIUM confidence)
- `test/models/arte_test.rb`, `test/controllers/admin/calendar_controller_test.rb` — padrões de teste do projeto

### Tertiary (LOW confidence)
- A1 (ver Assumptions Log): descoberta automática de `test/lib/` pelo runner

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — sem gems novas; tudo verificado no Gemfile.lock e código do projeto
- Architecture: HIGH — módulo + helper + view; padrões verificados no código existente
- Datas dos feriados: HIGH — calculadas via script Ruby na máquina do projeto
- Pitfalls: HIGH — verificados diretamente no código (ponto de inserção, autoloading)
- Testes: HIGH (unit module) / MEDIUM (integração — A1)

**Research date:** 2026-06-04
**Valid until:** 2027-01-01 (dados de feriados válidos até 2027; stack estável)
