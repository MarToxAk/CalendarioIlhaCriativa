---
phase: 16-feriados-brasileiros
verified: 2026-06-04T21:30:00Z
status: passed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Verificar visualmente que o nome do feriado aparece em vermelho abaixo do número do dia no calendário do cliente para abril de 2026 (Páscoa dia 5, Tiradentes dia 21)"
    expected: "Texto vermelho (text-red-400) visível abaixo do número, sem quebra de layout, chips de artes abaixo do texto de feriado"
    why_human: "Renderização visual e posicionamento CSS não verificáveis por grep — requer browser"
  - test: "Verificar visualmente que o mesmo comportamento ocorre no calendário do admin (/admin/calendar?month=2026-04)"
    expected: "Páscoa (dia 5) e Tiradentes (dia 21) em texto vermelho, layout preservado, chips abaixo do nome"
    why_human: "Renderização visual e posicionamento CSS não verificáveis por grep — requer browser"
---

# Phase 16: Feriados Brasileiros — Verification Report

**Phase Goal:** Feriados nacionais e dias comemorativos de marketing brasileiros ficam visualmente destacados nos calendários do admin e do cliente, sem depender de API externa
**Verified:** 2026-06-04T21:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                  | Status     | Evidence                                                                                              |
|----|----------------------------------------------------------------------------------------|------------|-------------------------------------------------------------------------------------------------------|
| 1  | O sistema possui lista hardcoded com feriados nacionais e comemorativos para anos em uso | VERIFIED   | `app/lib/brazilian_holidays.rb`: HOLIDAYS hash com 17 datas/ano para 2025, 2026 e 2027, frozen |
| 2  | No calendário do cliente, dias com feriado exibem nome em texto vermelho legível        | VERIFIED   | View `_month_calendar.html.erb` linha 26: bloco `brazilian_holiday_for` com span `text-red-400`; teste de integração linha 134 passa (Tiradentes + Páscoa para 2026-04) |
| 3  | No calendário do admin, dias com feriado exibem nome em texto vermelho legível          | VERIFIED   | View `_calendar_grid.html.erb` linha 24: mesmo bloco; teste de integração linha 103 passa (Tiradentes + Páscoa para 2026-04) |
| 4  | BrazilianHolidays.for(year) retorna Hash para anos cobertos e {} para anos não cobertos | VERIFIED   | 8 testes unitários verdes; `HOLIDAYS.fetch(year, {})` implementado; BrazilianHolidays.for(9999) = {} confirmado |
| 5  | Dias sem feriado não introduzem elementos vazios ou erros de template                   | VERIFIED   | Padrão `<% if (holiday = brazilian_holiday_for(date)) %>` garante renderização condicional; testes de regressão (linha 142 e 110) passam sem `brazilianholiday` ou `undefined method` no body |

**Score:** 5/5 truths verified

### Deferred Items

Nenhum item identificado como diferido para fase posterior.

---

## Required Artifacts

| Artifact                                                | Expected                                              | Status     | Details                                                                              |
|---------------------------------------------------------|-------------------------------------------------------|------------|--------------------------------------------------------------------------------------|
| `app/lib/brazilian_holidays.rb`                         | Module BrazilianHolidays com HOLIDAYS e `.for(year)`  | VERIFIED   | Existe, substantivo (65 linhas, 17 datas/ano x 3 anos), autoloaded via `config.autoload_lib` |
| `app/helpers/application_helper.rb`                     | Helper `brazilian_holiday_for(date)`                  | VERIFIED   | Linha 18: `def brazilian_holiday_for(date)` presente e delegando para BrazilianHolidays |
| `test/lib/brazilian_holidays_test.rb`                   | Testes unitários do module                            | VERIFIED   | 8 testes, 11 assertions, 0 failures — todos os comportamentos do PLAN cobertos       |
| `app/views/client/home/_month_calendar.html.erb`        | Span de feriado após bloco if/else do número do dia   | VERIFIED   | Linha 26: `if (holiday = brazilian_holiday_for(date))` APÓS `<% end %>` do bloco número (linha 24) e ANTES do `artes_do_dia.each` (linha 32) |
| `app/views/admin/calendar/_calendar_grid.html.erb`      | Span de feriado após bloco if/else do número do dia   | VERIFIED   | Linha 24: mesmo padrão, APÓS `<% end %>` do bloco número (linha 22) e ANTES de `visible = artes_do_dia.first(3)` (linha 30) |
| `test/controllers/client/home_controller_test.rb`       | Testes FERI-02 com assert_includes "Tiradentes"       | VERIFIED   | Linhas 134–148: 2 testes adicionados; linha 134 (Tiradentes + Páscoa) passa; linha 142 (regressão) passa |
| `test/controllers/admin/calendar_controller_test.rb`    | Testes FERI-03 com assert_includes "Tiradentes"       | VERIFIED   | Linhas 103–115: 2 testes adicionados; linha 103 (Tiradentes + Páscoa) passa; linha 110 (regressão) passa |

---

## Key Link Verification

| From                                        | To                                  | Via                                   | Status   | Details                                                                             |
|---------------------------------------------|-------------------------------------|---------------------------------------|----------|-------------------------------------------------------------------------------------|
| `app/helpers/application_helper.rb`         | `app/lib/brazilian_holidays.rb`     | `BrazilianHolidays.for(date.year)[date]` | WIRED | Linha 19 do helper: `BrazilianHolidays.for(date.year)[date]` — call direto ao module |
| `app/views/client/home/_month_calendar.html.erb` | `app/helpers/application_helper.rb` | `brazilian_holiday_for(date)`        | WIRED    | Linha 26 da view: `if (holiday = brazilian_holiday_for(date))` — helper invocado por cada data do grid |
| `app/views/admin/calendar/_calendar_grid.html.erb` | `app/helpers/application_helper.rb` | `brazilian_holiday_for(date)`      | WIRED    | Linha 24 da view: mesmo padrão — helper invocado por cada data do grid admin         |

---

## Data-Flow Trace (Level 4)

| Artifact                                      | Data Variable | Source                          | Produces Real Data | Status    |
|-----------------------------------------------|---------------|---------------------------------|--------------------|-----------|
| `_month_calendar.html.erb` (span feriado)     | `holiday`     | `BrazilianHolidays::HOLIDAYS` (constante frozen) | Sim — hash com 17 datas reais por ano, verificadas pelo executor com script Ruby 3.3.3 | FLOWING  |
| `_calendar_grid.html.erb` (span feriado)      | `holiday`     | `BrazilianHolidays::HOLIDAYS` (constante frozen) | Sim — mesma fonte | FLOWING  |

Nota: A fonte de dados é uma constante Ruby hardcoded (não banco de dados), o que é intencional e especificado pelo requisito FERI-01 ("sem API externa"). A constante está frozen em todos os níveis (cada sub-hash de ano + hash externo) — 4 chamadas `.freeze` confirmadas por grep.

---

## Behavioral Spot-Checks

| Behavior                                                          | Command                                                          | Result                         | Status |
|-------------------------------------------------------------------|------------------------------------------------------------------|--------------------------------|--------|
| `BrazilianHolidays.for(2026)` retorna hash com entradas           | `bin/rails test test/lib/brazilian_holidays_test.rb`            | 8 runs, 11 assertions, 0 failures | PASS   |
| `BrazilianHolidays.for(9999)` retorna `{}`                        | Teste unitário linha 10–13                                       | PASS (incluído nos 8 tests)    | PASS   |
| Calendário cliente renderiza "Tiradentes" para month=2026-04      | `bin/rails test test/controllers/client/home_controller_test.rb:134` | 1 run, 5 assertions, 0 failures | PASS  |
| Calendário admin renderiza "Tiradentes" para month=2026-04        | `bin/rails test test/controllers/admin/calendar_controller_test.rb:103` | 1 run, 5 assertions, 0 failures | PASS |
| Sem erros de template (regressão) — cliente                       | `bin/rails test test/controllers/client/home_controller_test.rb:142` | 1 run, 5 assertions, 0 failures | PASS  |
| Sem erros de template (regressão) — admin                         | `bin/rails test test/controllers/admin/calendar_controller_test.rb:110` | 1 run, 5 assertions, 0 failures | PASS  |

---

## Probe Execution

Nenhuma probe convencional (`scripts/*/tests/probe-*.sh`) declarada nesta fase. Step 7c: SKIPPED (fase não é migração/tooling).

---

## Requirements Coverage

| Requirement | Source Plan | Description                                                                                        | Status     | Evidence                                                          |
|-------------|-------------|----------------------------------------------------------------------------------------------------|------------|-------------------------------------------------------------------|
| FERI-01     | 16-01-PLAN  | Sistema contém lista hardcoded de feriados nacionais e comemorativos para os anos correntes        | SATISFIED  | `app/lib/brazilian_holidays.rb`: 17 feriados/comemorativos por ano para 2025–2027, autoloaded pelo Rails |
| FERI-02     | 16-02-PLAN  | Calendário do cliente exibe dias de feriado com destaque e nome visível na célula                  | SATISFIED  | `_month_calendar.html.erb` linha 26: span `text-red-400`; teste integração linha 134 verde |
| FERI-03     | 16-02-PLAN  | Calendário do admin exibe dias de feriado com destaque e nome visível na célula                    | SATISFIED  | `_calendar_grid.html.erb` linha 24: span `text-red-400`; teste integração linha 103 verde |

Nota sobre REQUIREMENTS.md: O arquivo ainda marca FERI-01/02/03 como `[ ]` Pending e "Pending" na tabela de rastreabilidade. Isso é drift de documentação — o ROADMAP.md está correto (Phase 16 marcada como "completed 2026-06-04"). Os requisitos estão satisfeitos no código.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | Nenhum encontrado |

Scan realizado em todos os 5 arquivos modificados pela fase 16. Nenhum marcador TBD/FIXME/XXX, nenhum retorno vazio/null/placeholder encontrado. O módulo contém dados reais verificados.

---

## Observação sobre Falhas Pré-Existentes

Durante a execução da suite completa foram encontradas **4 falhas pré-existentes**, nenhuma causada pela fase 16:

1. **`SessionsControllerTest#test_login_com_senha_errada_retorna_erro`** (fase 01-02, 2026-05-27) — rate-limiter retorna 429 em vez de 302 quando os testes rodam em sequência.
2. **`Client::HomeControllerTest#test_parâmetro_month_inválido_não_causa_erro_500`** — sessão não propaga entre testes (acesso_token diferente por Client.create! em setup); presente antes da fase 16 (commit `14fece2`).
3. **`Client::HomeControllerTest#test_summary_strip_conta_status_revised_junto_com_pending_(D-04)`** — mesma causa (sessão/isolamento).
4. **`Client::HomeControllerTest#test_summary_strip_exibe_chip_pediu_alteração_para_artes_change_requested`** — mesma causa.

Confirmado por git: estas falhas existiam no commit `14fece2` (fase 09), anterior à fase 16. A fase 16 adicionou apenas 2 novos testes ao arquivo (linhas 134–148), ambos passando individualmente. O SUMMARY-02 documenta esse comportamento pré-existente.

---

## Human Verification Required

### 1. Visual do Feriado no Calendário do Cliente

**Test:** Iniciar o servidor (`bin/rails server`), acessar o calendário de um cliente com `?month=2026-04`. Confirmar:
- Célula do dia 5 exibe "Páscoa" em texto vermelho (#F87171 / text-red-400) abaixo do número
- Célula do dia 21 exibe "Tiradentes" em texto vermelho abaixo do número
- Células sem feriado não têm texto extra
- Chips de artes (se houver) aparecem abaixo do nome do feriado, não acima
- Número do dia ainda aparece corretamente (sem sobreposição)

**Expected:** Texto vermelho legível, hierarquia vertical preservada (número → feriado → chips), sem quebra de layout
**Why human:** Renderização visual, posicionamento CSS e hierarquia visual não são verificáveis por grep ou testes automatizados de integração (que apenas verificam presença no HTML, não aparência)

### 2. Visual do Feriado no Calendário do Admin

**Test:** Acessar `/admin/calendar?month=2026-04` autenticado como admin. Confirmar os mesmos pontos acima para Páscoa e Tiradentes.

**Expected:** Mesmo comportamento visual do calendário do cliente
**Why human:** Mesmo motivo acima

**Nota:** O SUMMARY-02 registra que este checkpoint já foi aprovado visualmente pelo usuário em 2026-06-04. Se confirmado, o status pode ser atualizado para `passed`.

---

## Gaps Summary

Nenhum gap encontrado. Todos os artefatos existem, são substantivos, estão corretamente conectados e os dados fluem das constantes reais do módulo para as views. Os 3 requisitos FERI-01/02/03 estão satisfeitos no código.

O status `human_needed` reflete exclusivamente a pendência de confirmação visual no browser — verificação que o SUMMARY-02 indica como já realizada e aprovada pelo usuário em 2026-06-04.

---

_Verified: 2026-06-04T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
