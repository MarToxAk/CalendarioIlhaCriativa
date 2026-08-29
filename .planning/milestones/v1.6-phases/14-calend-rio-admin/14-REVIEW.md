---
phase: 14-calend-rio-admin
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - test/controllers/admin/calendar_controller_test.rb
  - config/routes.rb
  - app/views/admin/shared/_sidebar.html.erb
  - app/controllers/admin/calendar_controller.rb
  - app/views/admin/calendar/index.html.erb
  - app/views/admin/calendar/_calendar_grid.html.erb
  - app/helpers/application_helper.rb
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-06-04
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Revisão do calendário administrativo implementado na fase 14. O código está funcionalmente correto para os casos normais, mas apresenta três deficiências que afetam corretude em produção: o cabeçalho do mês fica congelado durante navegação via Turbo Frame, o uso de `Date.today` ao invés de `Time.zone.today` introduz um bug de fuso horário silencioso, e um bloco `rescue` com constante de fallback que nunca é ativado constitui dead code enganoso. Os demais achados são informativos.

---

## Warnings

### WR-01: Cabecalho do mes congela durante navegacao por Turbo Frame

**File:** `app/views/admin/calendar/index.html.erb:14-16`

**Issue:** O `<h2>` que exibe `@month_label` está fora do `<turbo-frame id="calendar-content">` (frame inicia na linha 29). Os botões de prev/next usam `data: { turbo_frame: "calendar-content" }`, portanto ao clicar, o Turbo substitui apenas o conteudo dentro do frame — o grid atualiza, mas o titulo do mes permanece exibindo o mes original da carga de pagina. O usuario navega para julho, o grid mostra julho, mas o cabecalho continua mostrando "Junho 2026".

**Fix:** Incluir o cabecalho de navegacao dentro do frame, ou usar `turbo_frame_tag` para envolver tambem o bloco de navegacao:

```erb
<turbo-frame id="calendar-content">
  <div class="flex items-center justify-center gap-4 mb-6">
    <%= link_to admin_calendar_index_path(month: @prev_month),
          aria: { label: "Mes anterior" },
          class: "..." do %>
      <%# seta esquerda %>
    <% end %>

    <h2 class="text-lg font-semibold text-slate-900 min-w-[160px] text-center">
      <%= @month_label %>
    </h2>

    <%= link_to admin_calendar_index_path(month: @next_month),
          aria: { label: "Proximo mes" },
          class: "..." do %>
      <%# seta direita %>
    <% end %>
  </div>

  <%= render "calendar_grid",
        grid_dates: @grid_dates,
        artes_by_date: @artes_by_date,
        current_month: @current_month %>
</turbo-frame>
```

Ao mover o bloco de navegacao para dentro do frame, ele e substituido junto com o grid em cada navegacao. Os links nao precisam mais do atributo `data-turbo-frame` (estao dentro do frame, o comportamento e automatico).

---

### WR-02: Date.today ignora fuso horario da aplicacao (Brasilia)

**File:** `app/controllers/admin/calendar_controller.rb:30,33` e `app/views/admin/calendar/_calendar_grid.html.erb:14`

**Issue:** O app configura `config.time_zone = "Brasilia"` (UTC-3). `Date.today` retorna a data do sistema do servidor (normalmente UTC), enquanto `Time.zone.today` retorna a data no fuso configurado. Na janela entre 00:00 e 03:00 UTC (21:00-00:00 no Brasil), `Date.today` retornaria "amanha" do ponto de vista do usuario brasileiro. Isso afeta dois comportamentos:

1. `parse_month_param` no controller (linhas 30 e 33): ao acessar sem parametro `month`, o calendario pode abrir no mes errado.
2. `_calendar_grid.html.erb` linha 14: `date == Date.today` pode destacar o dia errado com o circulo laranja do "hoje".

**Fix:**

```ruby
# app/controllers/admin/calendar_controller.rb
def parse_month_param
  return Time.zone.today.beginning_of_month unless params[:month].present?
  Date.strptime(params[:month], "%Y-%m").beginning_of_month
rescue Date::Error
  Time.zone.today.beginning_of_month
end
```

```erb
<%# app/views/admin/calendar/_calendar_grid.html.erb:14 %>
<% if date == Time.zone.today %>
```

---

### WR-03: Bloco rescue e constante MONTH_NAMES_PT sao dead code

**File:** `app/controllers/admin/calendar_controller.rb:2,10-14`

**Issue:** O codigo chama `I18n.l(@current_month, format: "%B %Y")` e tenta capturar `I18n::MissingTranslationData` para usar o fallback `MONTH_NAMES_PT`. Porem, quando `format` e uma String (nao um Symbol), a implementacao interna do i18n (`translate_localization_format` em `i18n/backend/base.rb:289`) ja captura internamente qualquer `MissingTranslationData` e retorna a propria mensagem de erro como string — nunca re-lanca a excecao. Portanto `rescue I18n::MissingTranslationData` no controller nunca e executado e `MONTH_NAMES_PT` nunca e utilizado.

Alem disso, como `pt-BR.yml` define corretamente `date.month_names`, o `I18n.l` funciona perfeitamente, tornando o fallback redundante em qualquer cenario realista.

**Fix:** Remover o bloco begin/rescue e a constante, simplificando o metodo:

```ruby
# Remover linha 2:
# MONTH_NAMES_PT = %w[janeiro fevereiro ...].freeze

# Substituir linhas 10-14:
@month_label = I18n.l(@current_month, format: "%B %Y")
```

Se a intencao era um fallback defensivo, a forma correta seria verificar o locale antes ou usar `I18n.l(@current_month, format: :long)` com um formato definido no locale.

---

## Info

### IN-01: Tres testes duplicados no arquivo de teste

**File:** `test/controllers/admin/calendar_controller_test.rb:21-40` vs `44-69`

**Issue:** O arquivo contem seis testes redundantes em pares — tres dos cenarios cobertos nos testes com nomes descritivos em PT-BR (linhas 21-40) sao cobertos de forma identica pelos testes adicionados no plano 14-03 (linhas 44-69). Duplicatas identificadas:

- "GET /admin/calendar retorna 200..." (linha 21) == `test_returns_200_when_authenticated` (linha 44)
- "GET /admin/calendar redireciona..." (linha 26) == `test_redirects_when_unauthenticated` (linha 49)
- "GET /admin/calendar com parametro month invalido..." (linha 37) == `test_invalid_month_param_does_not_crash` (linha 66)

**Fix:** Remover os tres testes duplicados das linhas 44-69 (ou os equivalentes das linhas 21-40), mantendo apenas uma versao de cada.

---

### IN-02: Link placeholder "#" para Configuracoes no sidebar

**File:** `app/views/admin/shared/_sidebar.html.erb:17`

**Issue:** O item "Configuracoes" aponta para `"#"` — ao clicar, nao navega para lugar algum e o `current_page?("#")` nunca sera verdadeiro, impossibilitando o destaque ativo.

**Fix:** Remover o item do sidebar enquanto a pagina nao existir, ou substituir por um link desabilitado visualmente (sem tag `<a>`) para nao gerar interacao vazia.

---

### IN-03: Helper client_color nao possui testes unitarios

**File:** `app/helpers/application_helper.rb:4-16`

**Issue:** O helper `client_color` e utilizado pelo partial `_calendar_grid.html.erb` para colorir os chips de clientes. Nao ha testes unitarios para este helper. Os testes de integracao verificam que chips aparecem, mas nao validam que a cor correta e aplicada para cada cliente nem que o modulo `% 8` nunca retorna nil (o que nunca ocorreria, mas nao esta provado por testes).

**Fix:** Adicionar testes unitarios em `test/helpers/application_helper_test.rb`:

```ruby
test "client_color retorna hash com chaves :bg e :text" do
  client = clients(:one)
  result = client_color(client)
  assert result.key?(:bg)
  assert result.key?(:text)
end

test "client_color e deterministico para o mesmo client" do
  client = clients(:one)
  assert_equal client_color(client), client_color(client)
end

test "client_color cobre todos os 8 slots da paleta" do
  colors = (0..7).map { |i| client_color(double(id: i)) }
  assert_equal 8, colors.uniq.size
end
```

---

_Reviewed: 2026-06-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
