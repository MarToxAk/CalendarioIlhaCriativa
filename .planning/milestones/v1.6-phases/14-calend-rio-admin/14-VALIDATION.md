---
phase: 14
slug: calend-rio-admin
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest (Rails padrão) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `rails test test/controllers/admin/calendar_controller_test.rb` |
| **Full suite command** | `rails test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `rails test test/controllers/admin/calendar_controller_test.rb`
- **After every plan wave:** Run `rails test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | CADM-01 | — | GET /admin/calendar retorna 200 para admin autenticado | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-01-02 | 01 | 1 | CADM-01 | — | Unauthenticated redirect para login | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-02-01 | 02 | 2 | CADM-02 | — | Artes de todos os clientes aparecem nas células corretas | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-02-02 | 02 | 2 | CADM-03 | — | Chip contém iniciais do cliente no HTML | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-02-03 | 02 | 2 | CADM-04 | — | Navegação com ?month= retorna mês correto | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-02-04 | 02 | 2 | CADM-04 | — | Parâmetro month inválido não causa 500 | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-02-05 | 02 | 2 | CADM-05 | — | Chip é link para admin_arte_path | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |
| 14-02-06 | 02 | 2 | D-04 | — | Máximo 3 chips visíveis + "+N" quando há mais de 3 | integration | `rails test test/controllers/admin/calendar_controller_test.rb` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/controllers/admin/calendar_controller_test.rb` — stubs para CADM-01 a CADM-05 e D-04

*Nenhuma lacuna de infraestrutura — Minitest, fixtures e SessionTestHelper já existem no projeto.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Turbo Frame atualiza grade sem recarregar página | CADM-04 | Requer browser para verificar comportamento Turbo | Clicar nas setas de navegação e confirmar que só a grade muda |
| Cores distintas por cliente visíveis | CADM-03 | Inspeção visual | Verificar que clientes diferentes têm chips de cores diferentes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
