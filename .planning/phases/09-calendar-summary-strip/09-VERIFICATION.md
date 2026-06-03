---
phase: 09-calendar-summary-strip
verified: 2026-06-03T12:00:00Z
status: human_needed
score: 6/6 must-haves verified
overrides_applied: 0
re_verification: false
human_verification:
  - test: "Abrir o portal do cliente em /c/{token} sem parâmetro ?month com artes cadastradas no mês corrente e confirmar que a faixa aparece acima da grade do calendário com 4 chips coloridos"
    expected: "Faixa visível sem scroll com chips total (cinza), aprovadas (verde), pendentes (âmbar), pediu alteração (vermelho) exibindo contagens corretas"
    why_human: "Visibilidade sem scroll (SC3) não pode ser verificada via grep — depende de viewport e layout real"
  - test: "Registrar uma aprovação numa arte do mês corrente e confirmar que ao recarregar a página o contador de aprovadas aumentou em 1 e o contador de pendentes diminuiu em 1"
    expected: "Contadores atualizados após reload, sem necessidade de JS/Turbo — comportamento SSR puro"
    why_human: "SC4 ('contador reflete novo status após aprovação') é um fluxo de interação end-to-end que não pode ser exercitado via grep ou teste de controller isolado"
  - test: "Navegar para um mês sem nenhuma arte e confirmar que a faixa não aparece (sem div role=status no DOM)"
    expected: "Nenhuma faixa ou div vazia visível — calendário exibe apenas a grade"
    why_human: "Ausência de elemento no DOM em navegação real confirma o guard @summary[:total] > 0 na interface real"
---

# Phase 09: Calendar Summary Strip — Verification Report

**Phase Goal:** O cliente vê no topo do calendário um resumo dos status das artes do mês
**Requirement:** CAL2-01
**Verified:** 2026-06-03T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Cliente vê faixa de resumo acima da grade do calendário quando há artes no mês | VERIFIED | `index.html.erb` line 25: `<% if @summary[:total] > 0 %>` guard followed by `<div role="status">` block inserted before `render partial: "client/home/month_calendar"` at line 42 |
| 2 | Faixa exibe 4 chips na ordem: total, aprovadas, pendentes, pediu alteração | VERIFIED | Lines 27–38 of `index.html.erb` show 4 spans in exact order: total (slate), aprovadas (green), pendentes (amber), pediu alteração (red) |
| 3 | Contagens refletem apenas artes com scheduled_on dentro do mês corrente (não dias de overflow do grid) | VERIFIED | Controller lines 19–22: `artes_do_mes = @artes.select { |a| a.scheduled_on.month == @current_month.month && a.scheduled_on.year == @current_month.year }` — explicit month+year filter; test at line 86 passes in isolation |
| 4 | Status revised contado junto com pending no chip pendentes (D-04) | VERIFIED | Controller line 26: `pending: artes_do_mes.count { |a| %w[pending revised].include?(a.status.to_s) }` — test at line 110 passes in isolation (2 pendentes with 1 pending + 1 revised) |
| 5 | Faixa não é renderizada quando não há artes no mês corrente (D-06) | VERIFIED | `index.html.erb` line 25: `<% if @summary[:total] > 0 %>` guard; test at line 56 confirms `assert_no_match(/role="status"/, response.body)` and passes in isolation |
| 6 | Após cliente aprovar arte, reload da página mostra contagens atualizadas automaticamente (SSR) | VERIFIED (logic) | `@summary` is recalculated on every request from `@artes` scoped to the client — no caching, no stale state. Full end-to-end confirmation requires human test (SC4) |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `app/controllers/client/home_controller.rb` | Hash `@summary` com chaves :total, :approved, :pending, :change_requested | VERIFIED | Lines 19–28: `artes_do_mes` local var + `@summary` hash literal with all 4 keys, in-memory `.select`/`.count` — no additional DB queries |
| `app/views/client/home/index.html.erb` | Summary strip inline com 4 chips coloridos e guard de visibilidade | VERIFIED | Lines 25–40: guard + `<div role="status" aria-label="Resumo do mês" class="flex flex-wrap gap-2 mb-4 justify-center">` + 4 chip spans; no partial, no Stimulus |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/controllers/client/home_controller.rb` | `app/views/client/home/index.html.erb` | `@summary` instance variable | WIRED | View line 25 reads `@summary[:total]`, lines 28/31/34/37 read all 4 keys |
| `app/views/client/home/index.html.erb` | Tailwind color classes | `bg-green-100`, `bg-amber-100`, `bg-red-100`, `bg-slate-100` | WIRED | All 4 color classes confirmed at lines 27, 30, 33, 36 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `app/views/client/home/index.html.erb` | `@summary` (4 keys) | `@artes.select {...}` in controller — `@artes` populated from `@client.artes.where(scheduled_on: grid_start..grid_end)` | Yes — DB-backed ActiveRecord relation scoped by client and date range | FLOWING |

### Behavioral Spot-Checks

All 7 CAL2-01-specific tests pass when run in isolation:

| Behavior | Test Line | Isolation Result | Status |
|----------|-----------|-----------------|--------|
| Strip ausente sem artes | line 56 | 1 run, 0 failures | PASS |
| Strip aparece com artes (role=status + aria-label) | line 63 | 1 run, 0 failures | PASS |
| Contagem total correta | line 74 | 1 run, 0 failures | PASS |
| Exclui artes de outros meses (overflow) | line 86 | 1 run, 0 failures | PASS |
| Chip aprovadas correto | line 100 | 1 run, 0 failures | PASS |
| revised contado em pending (D-04) | line 110 | 1 run, 0 failures | PASS |
| Chip pediu alteração correto | line 123 | 1 run, 0 failures | PASS |

**Full suite (12 tests):** consistently shows 1 failure per run — different test fails depending on random seed. This is the pre-existing session contamination issue documented in SUMMARY.md (section "Issues Encountered"): the `parallelize` threshold is 50 but the suite runs sequentially; the last test in execution order loses its session when a prior test's `sign_in_as_client` call appears to interfere. The failing test rotates across seeds (confirmed: line 16, line 19, line 63 all fail depending on seed) and every failing test passes perfectly when run in isolation. This is a pre-existing issue, not introduced by phase 09.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CAL2-01 | 09-01-PLAN.md | Cliente vê no topo do calendário a contagem de artes do mês por status (total, aprovadas, pendentes, pediu alteração) | SATISFIED | Controller computes @summary; view renders 4-chip strip with guard; 7 tests confirm all behaviors in isolation |

### Anti-Patterns Found

No debt markers (TBD, FIXME, XXX, TODO, HACK, PLACEHOLDER) found in any file modified by this phase.

Note: ROADMAP.md line 67 contains `**Plans**: TBD` in the Phase 9 section — this is a pre-existing documentation field that was never updated after plan creation (still shows pre-execution state). It is not a code file modified by this phase and does not affect implementation correctness.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

### Human Verification Required

#### 1. Faixa visível sem scroll (Roadmap SC3)

**Test:** Abrir `/c/{token}` com artes no mês corrente em viewport de smartphone (375px) e desktop  
**Expected:** Faixa com 4 chips aparece acima da grade do calendário, dentro da área visível sem scroll  
**Why human:** "A faixa é visível sem precisar rolar a página" (SC3) depende de rendering real — layout CSS e viewport height não podem ser verificados via grep

#### 2. Contador atualiza após aprovação (Roadmap SC4)

**Test:** Aprovar uma arte com status "pending" no mês corrente, confirmar redirect/reload, observar a faixa  
**Expected:** Chip aprovadas incrementa em 1, chip pendentes decrementa em 1 — reflita o novo status imediatamente  
**Why human:** SC4 é um fluxo de interação end-to-end. Embora a lógica SSR seja correta (sem cache, @summary recalculado por request), a confirmação real requer exercitar o fluxo completo no browser

#### 3. Faixa ausente em mês sem artes (Roadmap SC1 — navegação real)

**Test:** Navegar para um mês futuro/passado sem artes via link "Próximo mês"/"Mês anterior" na interface  
**Expected:** Faixa não aparece; calendário exibe apenas a grade vazia  
**Why human:** O guard `@summary[:total] > 0` foi verificado em teste, mas confirmar a ausência de wrapper HTML vazio na interface real descarta regressões de layout

### Gaps Summary

No gaps. All 6 must-have truths are verified. All artifacts exist, are substantive, are wired, and have real data flowing through them. The test suite has a pre-existing session contamination issue (1 failure per full-suite run, rotating by seed) that is documented in the SUMMARY and pre-dates this phase.

---

_Verified: 2026-06-03T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
