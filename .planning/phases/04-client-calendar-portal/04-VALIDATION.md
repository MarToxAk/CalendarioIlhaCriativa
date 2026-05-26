---
phase: 4
slug: client-calendar-portal
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rails Minitest (ActionDispatch::IntegrationTest) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bundle exec rails test test/controllers/client/` |
| **Full suite command** | `bundle exec rails test` |
| **Estimated runtime** | ~10 seconds |

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
| 04-01-01 | 01 | 1 | CAL-01 | — | N/A | integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | CAL-02 | — | N/A | integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | CAL-04 | — | N/A | integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ W0 | ⬜ pending |
| 04-01-04 | 01 | 1 | CAL-05 | — | N/A | integration | `bundle exec rails test test/controllers/client/home_controller_test.rb` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | CAL-03 | T-04-01 | Arte de outro cliente retorna 404 | integration | `bundle exec rails test test/controllers/client/artes_controller_test.rb` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | CAL-03 | T-04-01 | Sem auth redireciona para login | integration | `bundle exec rails test test/controllers/client/artes_controller_test.rb` | ❌ W0 | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `test/controllers/client/home_controller_test.rb` — stubs para CAL-01, CAL-02, CAL-04, CAL-05
- [ ] `test/controllers/client/artes_controller_test.rb` — stubs para CAL-03, cross-client isolation

*Infra existente cobre: `test/integration/client_isolation_test.rb` (SEC), `test/test_helper.rb`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Grade CSS 7 colunas renderizada corretamente no browser | CAL-01 | Layout visual | Abrir `/c/:token` no browser, verificar grid Seg–Dom |
| Player de vídeo funciona | CAL-03 | Media playback | Abrir arte com vídeo, verificar `<video controls>` reproduz |
| Botão "Abrir arquivo" abre em nova aba | CAL-03 | Link externo | Abrir arte com external_url, clicar botão |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
