---
phase: 14-calend-rio-admin
fixed_at: 2026-06-04T00:00:00Z
review_path: .planning/phases/14-calend-rio-admin/14-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-06-04
**Source review:** .planning/phases/14-calend-rio-admin/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### WR-01: Cabecalho do mes congela durante navegacao por Turbo Frame

**Files modified:** `app/views/admin/calendar/index.html.erb`
**Commit:** d710863
**Applied fix:** Moveu o bloco de navegação completo (div com links prev/next e h2 com @month_label) para dentro do `<turbo-frame id="calendar-content">`. Removeu o atributo `data: { turbo_frame: "calendar-content" }` dos dois links, pois links dentro de um frame já direcionam para o mesmo frame automaticamente. O cabeçalho do mês agora é substituído junto com o grid a cada navegação.

---

### WR-02: Date.today ignora fuso horario da aplicacao (Brasilia)

**Files modified:** `app/controllers/admin/calendar_controller.rb`, `app/views/admin/calendar/_calendar_grid.html.erb`
**Commit:** 5f966a8
**Applied fix:** Substituiu `Date.today` por `Time.zone.today` nas duas ocorrências do controller (linhas 30 e 33 — fallback padrão e fallback do rescue) e na linha 14 do partial `_calendar_grid.html.erb` (comparação para destacar o dia atual). Corrige o bug de fuso horário que afetava usuários brasileiros entre 21:00 e 00:00.

---

### WR-03: Bloco rescue e constante MONTH_NAMES_PT sao dead code

**Files modified:** `app/controllers/admin/calendar_controller.rb`
**Commit:** a255514
**Applied fix:** Removeu a constante `MONTH_NAMES_PT` (linha 2) e substituiu o bloco `begin/rescue I18n::MissingTranslationData` por atribuição direta `@month_label = I18n.l(@current_month, format: "%B %Y")`. O bloco rescue nunca era ativado porque `I18n.l` com format String captura `MissingTranslationData` internamente sem re-lançar a exceção.

---

**Testes executados após todas as correções:**
`bundle exec rails test test/controllers/admin/calendar_controller_test.rb`
Resultado: 12 runs, 20 assertions, 0 failures, 0 errors, 0 skips.

---

_Fixed: 2026-06-04_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
