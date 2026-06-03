# Phase 9: Calendar Summary Strip - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Adicionar uma faixa de resumo acima da grade do calendário no portal do cliente, mostrando a contagem de artes do mês corrente por status: total, aprovadas, pendentes e pediu alteração (CAL2-01).

Requer mudança no controller (`Client::HomeController#index`) para calcular `@summary` e na view (`client/home/index.html.erb`) para renderizar os chips inline. Nenhuma mudança em models, rotas, outras views ou partials.

**Fora do escopo desta fase:** Notificações (NOTF-01/02), exportação de relatórios (ADM2-01), duplicar artes (ADM2-02), deploy S3 (INFRA-01).

</domain>

<decisions>
## Implementation Decisions

### Escopo das contagens

- **D-01:** Contar apenas artes com `scheduled_on` dentro do mês corrente (`@current_month.beginning_of_month..@current_month.end_of_month`). Dias de overflow de outros meses que aparecem no grid não entram na contagem.
- **D-02:** Calcular no controller — nova instância `@summary` no `Client::HomeController#index`, usando `@artes.select { |a| a.scheduled_on.month == @current_month.month && a.scheduled_on.year == @current_month.year }` como base.

### Status exibidos na faixa

- **D-03:** Exibir apenas 3 statuses + total: **total**, **aprovadas** (`approved`), **pendentes** (`pending` + `revised`), **pediu alteração** (`change_requested`). Status "revisado" não aparece como contador separado.
- **D-04:** Artes com status `revised` são contadas junto com `pending` no contador "Pendentes". Lógica: `pending_count = artes_do_mes.count { |a| %w[pending revised].include?(a.status.to_s) }`.

### Layout visual da faixa

- **D-05:** Chips coloridos inline entre o header de navegação de mês e a grade do calendário. A faixa é um bloco novo em `index.html.erb`, inserido após o `</div>` do header (linha 23) e antes do `<%= render partial: "client/home/month_calendar" %>` (linha 25).
- **D-06:** Faixa oculta quando `total = 0` — não renderizar a faixa se não há artes no mês corrente.
- **D-07:** Cores dos chips seguem o padrão do badge de status existente: total=slate-100/slate-700, aprovadas=green-100/green-800, pendentes=amber-100/amber-800, pediu alteração=red-100/red-800.
- **D-08:** Faixa usa `flex-wrap: wrap` — chips que não cabem em uma linha vão para a próxima. Labels intactos (sem abreviar "pediu alteração" em mobile).

### Atualização após aprovação

- **D-09:** SC4 satisfeito via redirect SSR — `@summary` é recalculado a cada request no controller. Após o cliente aprovar ou pedir alteração, o fluxo existente redireciona de volta ao calendário e a faixa atualiza automaticamente. Sem Turbo Stream nem JS extra.

### Estrutura de código

- **D-10:** Faixa implementada inline no `index.html.erb` — sem partial separado. A faixa tem ~10 linhas de HTML; inline mantém tudo legível num lugar só.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### View principal (ponto de inserção da faixa)

- `app/views/client/home/index.html.erb` — **ARQUIVO CENTRAL**: a faixa é inserida entre o `</div>` do header de navegação de mês (linha 23) e o `<%= render partial: "client/home/month_calendar" %>` (linha 25). Adicionar bloco de chips inline aqui.

### Controller (ponto de cálculo do @summary)

- `app/controllers/client/home_controller.rb` — `index` action: adicionar cálculo de `@summary` após `@artes_by_date`. `@artes` já está disponível (query existente). Não alterar a query existente.

### Referência visual (padrão de cores e estilo dos chips)

- `app/views/client/shared/_arte_status_badge.html.erb` — cores de status (green-100/green-800, amber-100/amber-800, red-100/red-800, slate-100/slate-700). Chips da faixa devem seguir o mesmo esquema de cores. Nota: badge tem modos `compact` e normal; chips da faixa seguem estilo próprio (não usam o partial diretamente).

### Calendário (contexto do layout)

- `app/views/client/home/_month_calendar.html.erb` — grade do calendário renderizada após a faixa. Sem mudanças neste arquivo.

### Requisitos

- `.planning/REQUIREMENTS.md` — CAL2-01: "Cliente vê no topo do calendário a contagem de artes do mês por status (total, aprovadas, pendentes, pediu alteração)"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `app/views/client/shared/_arte_status_badge.html.erb` — esquema de cores por status já definido; reusar as mesmas classes Tailwind nos chips da faixa para consistência visual
- `@artes` (instância já carregada no controller) — base para calcular `@summary`; usar `.select` in-memory para filtrar pelo mês corrente (evita query extra)

### Established Patterns

- Tailwind v4 CSS-native, acento laranja `#EA580C` — não modificar; faixa usa cores de status existentes (green/amber/red/slate)
- SSR-first — a faixa é renderizada estaticamente; sem Stimulus, sem Turbo Stream
- `@current_month.beginning_of_month` / `end_of_month` — helper Rails disponível no controller; usar para comparação de escopo

### Integration Points

- `app/views/client/home/index.html.erb` linha 23→25 — inserir bloco da faixa entre o `</div>` do header e o `<%= render partial: "client/home/month_calendar" %>`
- `app/controllers/client/home_controller.rb` linha ~17 (após `@artes_by_date =`) — adicionar `@summary = { ... }` calculado a partir de `@artes`

</code_context>

<specifics>
## Specific Ideas

- Formato visual: chips horizontais com separador `·` (ponto médio) entre eles
- Exemplo de output esperado: `12 total · 5 aprovadas · 4 pendentes · 3 pediu alteração`
- Cores: total sem cor de status (slate-100/slate-700), demais com cor do status correspondente
- Faixa usa `flex flex-wrap gap-2` ou similar para mobile responsivo
- Labels exatos: "total", "aprovadas", "pendentes", "pediu alteração"

</specifics>

<deferred>
## Deferred Ideas

None — discussão ficou dentro do escopo da fase.

</deferred>

---

*Phase: 9-calendar-summary-strip*
*Context gathered: 2026-06-03*
