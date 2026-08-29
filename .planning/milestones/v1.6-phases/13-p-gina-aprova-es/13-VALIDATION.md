---
phase: 13
slug: p-gina-aprova-es
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-04
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rails built-in Minitest + ActionDispatch::IntegrationTest |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bin/rails test test/controllers/admin/approvals_controller_test.rb` |
| **Full suite command** | `bin/rails test` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bin/rails test test/controllers/admin/approvals_controller_test.rb`
- **After every plan wave:** Run `bin/rails test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 0 | APRO-03..07 | T-13-01 | Cria stub de testes e fixtures inline | unit | `bin/rails test test/controllers/admin/approvals_controller_test.rb` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | APRO-03 | — | GET `/admin/approvals` retorna 200 | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_should_get_index` | ❌ W0 | ⬜ pending |
| 13-01-03 | 01 | 1 | APRO-04 | — | Lista ordenada por `responded_at DESC`, 25/pág | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_pagination` | ❌ W0 | ⬜ pending |
| 13-01-04 | 01 | 1 | APRO-05 | — | Exibe nome cliente, arte, decision, data, comentário | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_displays_all_fields` | ❌ W0 | ⬜ pending |
| 13-01-05 | 01 | 1 | APRO-06 | T-13-02 | Filtro `client_id` scope correto | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_filter_by_client` | ❌ W0 | ⬜ pending |
| 13-01-06 | 01 | 1 | APRO-06 | T-13-02 | Filtro `decision` scope correto | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_filter_by_decision` | ❌ W0 | ⬜ pending |
| 13-01-07 | 01 | 1 | APRO-06 | T-13-02 | `decision` inválido ignorado — sem erro 500 | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_filter_by_invalid_decision` | ❌ W0 | ⬜ pending |
| 13-01-08 | 01 | 1 | APRO-07 | — | Página contém link para `admin_arte_path` | integration | `bin/rails test test/controllers/admin/approvals_controller_test.rb -n test_contains_link_to_arte` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/controllers/admin/approvals_controller_test.rb` — stubs para APRO-03, APRO-04, APRO-05, APRO-06, APRO-07
- [ ] Dados de teste criados via `setup` inline (padrão do projeto — sem fixtures YAML extras)

*Padrão de referência: `test/controllers/admin/dashboard_controller_test.rb`*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Link "Aprovações" no sidebar aponta para `admin_approvals_path` | APRO-03 | Verificação visual de layout | Acessar painel admin, verificar que link sidebar não aponta para `#` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
