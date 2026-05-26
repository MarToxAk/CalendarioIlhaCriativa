---
phase: 5
slug: approval-flow
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-26
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rails Minitest (ActionDispatch::IntegrationTest) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bundle exec rails test test/controllers/client/responses_controller_test.rb` |
| **Full suite command** | `bundle exec rails test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bundle exec rails test test/controllers/client/`
- **After every plan wave:** Run `bundle exec rails test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | APRO-01 | — | N/A | integration | `bundle exec rails test test/models/approval_response_test.rb` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | APRO-03 | — | N/A | integration | `bundle exec rails test test/models/arte_test.rb` | ✅ | ⬜ pending |
| 05-02-01 | 02 | 2 | APRO-01 | T-05-01 | Arte de outro cliente retorna 404 | integration | `bundle exec rails test test/controllers/client/responses_controller_test.rb` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 2 | APRO-02 | T-05-01 | Sem auth redireciona para login | integration | `bundle exec rails test test/controllers/client/responses_controller_test.rb` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 2 | APRO-05 | T-05-02 | Arte approved? não aceita nova resposta | integration | `bundle exec rails test test/controllers/client/responses_controller_test.rb` | ❌ W0 | ⬜ pending |
| 05-02-04 | 02 | 2 | APRO-04 | — | N/A | integration | `bundle exec rails test test/controllers/client/responses_controller_test.rb` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 3 | APRO-03 | — | N/A | integration | `bundle exec rails test test/controllers/admin/artes_controller_test.rb` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/controllers/client/responses_controller_test.rb` — stubs para APRO-01, APRO-02, APRO-04, APRO-05 + isolamento cross-client
- [ ] `test/models/approval_response_test.rb` — stubs para validação `arte_must_be_pending` com estados `pending` e `revised`

*Infra existente cobre: `test/controllers/client/artes_controller_test.rb` (padrão de auth), `test/models/arte_test.rb` (status enum)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Formulário de comentário expande inline ao clicar "Pedir Alteração" | APRO-02 | Comportamento Stimulus (DOM toggle) | Abrir `/c/:token/artes/:id`, clicar "Pedir Alteração", verificar textarea expande sem reload |
| Botões ocultos para arte approved | APRO-05 | Renderização condicional | Abrir arte com status `approved`, verificar ausência dos botões no HTML |
| Histórico exibido após segunda resposta | APRO-04 | Requer ciclo completo de re-aprovação | Criar arte, aprovar, pedir revisão, marcar revisada, aprovar novamente, verificar 2 entradas no histórico |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
