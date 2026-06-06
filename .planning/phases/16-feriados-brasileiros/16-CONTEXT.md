# Phase 16: Feriados Brasileiros - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Implementar destaque visual de feriados nacionais e comemorativos de marketing nos dois calendários (admin + cliente), usando lista hardcoded em module Ruby puro, sem banco de dados e sem API externa. A lista cobre feriados nacionais brasileiros e os principais comemorativos do varejo para os anos 2025, 2026 e 2027.

</domain>

<decisions>
## Implementation Decisions

### D-01: Estrutura de armazenamento
- **Módulo Ruby puro** em `app/lib/brazilian_holidays.rb` com método público `BrazilianHolidays.for(year)` retornando um hash `{ Date => "Nome do Feriado" }`.
- Feriados **hardcoded por ano** — hash com chave anual: `{ 2025 => { Date.new(2025,1,1) => "Ano Novo", ... }, 2026 => {...}, 2027 => {...} }`.
- Feriados móveis (Páscoa, Carnaval = 47 dias antes, Corpus Christi = 60 dias depois) hardcoded por ano — sem algoritmo, sem gem extra.
- `for(year)` retorna hash vazio se o ano não estiver na lista (não lança exceção).

### D-02: Visual nas células
- **Texto abaixo do número do dia** — nome do feriado em `text-xs` logo após o span do número do dia.
- Cor: **vermelho/rosa discreto** — `text-red-400` (remete ao calendário físico com dias vermelhos).
- Sem alterar o fundo da célula; sem badge extra. Layout: número → [nome feriado em vermelho] → chips de artes.
- Comportamento em ambos os calendários é idêntico — mesma lógica de helper.

### D-03: Escopo da lista
- **Feriados nacionais** (12 oficiais): Ano Novo (1/jan), Carnaval (móvel), Sexta-feira Santa (móvel), Tiradentes (21/abr), Dia do Trabalho (1/mai), Corpus Christi (móvel), Independência (7/set), Nossa Sra. Aparecida (12/out), Finados (2/nov), Proclamação da República (15/nov), Natal (25/dez).
- **Comemorativos de marketing** adicionais: Páscoa (domingo móvel), Dia das Mães (2º domingo de maio), Dia dos Namorados (12/jun), Dia dos Pais (2º domingo de agosto), Dia das Crianças (12/out — coincide com Aparecida), Black Friday (4ª sexta de novembro).
- Total: ~15–20 datas por ano.
- Feriados estaduais/municipais: **fora de escopo**.

### Claude's Discretion
- Nome do helper de acesso na view: `brazilian_holiday_for(date)` em `ApplicationHelper` — chama `BrazilianHolidays.for(date.year)[date]`.
- Truncamento do nome na célula: se > 15 chars, truncar com `…` via `truncate(name, length: 15)` para não quebrar o layout.
- Testes: cobertura unitária do module `BrazilianHolidays` (datas fixas + anos sem cobertura).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Calendário do cliente (referência principal — FERI-02)
- `app/views/client/home/_month_calendar.html.erb` — grade de células; adicionar nome do feriado após o span do número do dia
- `app/controllers/client/home_controller.rb` — parse_month_param, grid_dates, artes_by_date; não requer alteração, apenas leitura para entender o contexto

### Calendário do admin (referência principal — FERI-03)
- `app/views/admin/calendar/_calendar_grid.html.erb` — grade de células com chips por cliente; mesma posição para o nome do feriado
- `app/controllers/admin/calendar_controller.rb` — contexto das variáveis disponíveis na view

### Helper e padrões
- `app/helpers/application_helper.rb` — adicionar `brazilian_holiday_for(date)` aqui (já tem `client_color`)

### Requirements
- `.planning/REQUIREMENTS.md` §Feriados Brasileiros — FERI-01, FERI-02, FERI-03 com critérios de aceite

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/helpers/application_helper.rb`: já tem `client_color(client)` — `brazilian_holiday_for(date)` segue o mesmo padrão de helper simples
- `_month_calendar.html.erb` e `_calendar_grid.html.erb`: ambos iteram `grid_dates.each do |date|` — o ponto de inserção é dentro desse bloco, após o span do número

### Established Patterns
- Tailwind hex inline (`bg-[#HEX]`, `text-[#HEX]`) é o padrão do projeto — usar `text-red-400` é compatível (classe utilitária padrão)
- `text-xs font-medium` para elementos pequenos dentro das células (padrão do número do dia)
- `truncate` helper Rails já disponível nas views ERB

### Integration Points
- `app/lib/` — diretório para modules Ruby puros; Rails autoloads `app/lib` desde Rails 7+ (`config.autoload_paths`)
- Ambas as views precisam apenas chamar `brazilian_holiday_for(date)` — se retornar nil, não renderiza nada

</code_context>

<specifics>
## Specific Ideas

- Estrutura visual na célula (cliente):
  ```
  <span class="text-xs font-medium text-slate-700">21</span>
  <% if (holiday = brazilian_holiday_for(date)) %>
    <span class="text-xs text-red-400 block truncate"><%= holiday %></span>
  <% end %>
  ```
- Mesmo padrão no calendário admin, antes dos chips.
- Dia das Mães (2º domingo de maio) e Dia dos Pais (2º domingo de agosto) precisam de lógica de cálculo no module (ou hardcoded explicitamente por ano).

</specifics>

<deferred>
## Deferred Ideas

- Feriados estaduais/municipais — nova fase se necessário
- Destaque de fundo na célula (toda a célula colorida) — possível refinamento visual futuro
- Gerenciamento de feriados via interface admin (CRUD) — complexidade sem benefício agora
- Feriados para anos além de 2027 — adicionar quando necessário

</deferred>

---

*Phase: 16-Feriados Brasileiros*
*Context gathered: 2026-06-04*
