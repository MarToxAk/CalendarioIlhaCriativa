---
phase: 06
slug: admin-feedback-panel
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-26
---

# Phase 06 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest (Rails built-in) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bin/rails test test/controllers/admin/` |
| **Full suite command** | `bin/rails test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bin/rails test test/controllers/admin/`
- **After every plan wave:** Run `bin/rails test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | PAIN-01 | T-06-01 | Dashboard só acessível com admin autenticado | controller | `bin/rails test test/controllers/admin/dashboard_controller_test.rb -n test_should_get_index` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | PAIN-02 | T-06-02 | Filtro `client_id` escopa por associação, não por ID direto | controller | `bin/rails test test/controllers/admin/dashboard_controller_test.rb -n test_filter_by_client` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | PAIN-03 | — | Filtro status retorna artes com status correto | controller | `bin/rails test test/controllers/admin/dashboard_controller_test.rb -n test_filter_by_status` | ❌ W0 | ⬜ pending |
| 06-02-01 | 02 | 2 | PAIN-04 | — | Mark revised disponível via admin_arte_path | controller | `bin/rails test test/controllers/admin/artes_controller_test.rb -n test_mark_revised_muda_status` | ✅ | ⬜ pending |
| 06-02-02 | 02 | 2 | PAIN-05 | T-06-03 | admin_reply em arte_params, campo persiste | controller | `bin/rails test test/controllers/admin/artes_controller_test.rb -n test_update_admin_reply` | ❌ W0 | ⬜ pending |
| 06-03-01 | 03 | 3 | CLIE-05 | — | Show do cliente inclui artes com respostas | controller | `bin/rails test test/controllers/admin/clients_controller_test.rb -n test_show_inclui_historico` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/controllers/admin/dashboard_controller_test.rb` — stubs para PAIN-01, PAIN-02, PAIN-03
- [ ] `test/controllers/admin/artes_controller_test.rb` — adicionar `test_update_admin_reply` para PAIN-05
- [ ] `test/controllers/admin/clients_controller_test.rb` — adicionar `test_show_inclui_historico` para CLIE-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Turbo Frame atualiza dashboard sem reload | PAIN-02, PAIN-03 | Browser behavior, não testável com Minitest puro | Abrir /admin, selecionar filtro, confirmar que só o conteúdo do frame muda (sem full reload) |
| Badge de status usa cores corretas | PAIN-01 | Visual regression | Confirmar verde/laranja/cinza/índigo para cada status no dashboard |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
