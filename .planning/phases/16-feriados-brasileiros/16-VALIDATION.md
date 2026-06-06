---
phase: 16
slug: feriados-brasileiros
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest via ActiveSupport::TestCase |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bin/rails test test/lib/brazilian_holidays_test.rb` |
| **Full suite command** | `bin/rails test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bin/rails test test/lib/brazilian_holidays_test.rb`
- **After every plan wave:** Run `bin/rails test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-01 | 01 | 0 | FERI-01 | — | N/A — static data | unit | `bin/rails test test/lib/brazilian_holidays_test.rb` | ❌ W0 | ⬜ pending |
| 16-01-02 | 01 | 1 | FERI-01 | — | String hardcoded, sem input externo | unit | `bin/rails test test/lib/brazilian_holidays_test.rb` | ❌ W0 | ⬜ pending |
| 16-02-01 | 02 | 1 | FERI-02 | — | `truncate` sobre string literal — sem XSS | integration | `bin/rails test test/controllers/client/home_controller_test.rb` | ✅ | ⬜ pending |
| 16-03-01 | 03 | 2 | FERI-03 | — | `truncate` sobre string literal — sem XSS | integration | `bin/rails test test/controllers/admin/calendar_controller_test.rb` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lib/` — diretório novo; criar com `mkdir -p test/lib`
- [ ] `test/lib/brazilian_holidays_test.rb` — stubs para FERI-01 (cobre: for(year) retorna hash, for(ano_sem_cobertura) retorna {}, datas corretas para 2025/2026/2027)
- [ ] `app/lib/` — diretório novo; criar com `mkdir -p app/lib`

*Infraestrutura existente cobre FERI-02 e FERI-03 via testes de controller existentes.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Nome do feriado exibido visualmente com `text-red-400` na célula do calendário | FERI-02, FERI-03 | Cor e layout visual não são verificáveis por teste automatizado | Navegar para `?month=2026-04` (Páscoa 05/04, Tiradentes 21/04) nos dois calendários; confirmar texto vermelho abaixo do número do dia |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
