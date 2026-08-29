---
phase: 18
slug: approvalresponse-broadcast-admin-live-rows
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-05
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Rails Minitest (ActionDispatch::IntegrationTest) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bin/rails test test/models/approval_response_test.rb` |
| **Full suite command** | `bin/rails db:test:prepare test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bin/rails test test/models/approval_response_test.rb`
- **After every plan wave:** Run `bin/rails db:test:prepare test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | RTUP-01 | — | Badge sempre renderizado no DOM (sem if badge_count>0) | integration | `bin/rails test test/system/admin_realtime_test.rb` | ❌ W0 | ⬜ pending |
| 18-01-02 | 01 | 1 | RTUP-02 | — | Toast renderiza cliente + decisão + link arte | integration | `bin/rails test test/models/approval_response_test.rb` | ✅ | ⬜ pending |
| 18-01-03 | 01 | 1 | RTUP-03 | — | after_create_commit dispara broadcast | unit | `bin/rails test test/models/approval_response_test.rb` | ✅ | ⬜ pending |
| 18-01-04 | 01 | 1 | RTUP-04 | — | Partial _approval_row tem id: dom_id(approval_response) | integration | `bin/rails test test/system/admin_realtime_test.rb` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/models/approval_response_test.rb` — verificar que after_create_commit dispara broadcast e não N+1 (stubs para RTUP-02, RTUP-03)
- [ ] Confirm `test/test_helper.rb` e `ApplicationCable::TestCase` disponíveis

*Se framework já existir: aproveitar ActionCable channel test helpers do Rails.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Toast aparece em <2s no browser admin | RTUP-02 | ActionCable em real-time requer browser real | Abrir admin, cliente submeter resposta, verificar toast |
| Dashboard row atualiza sem reload | RTUP-03 | Turbo Streams real-time requer browser real | Admin no dashboard, cliente aprovar, ver row atualizar |
| Approvals page prepend funciona | RTUP-04 | Turbo Streams real-time requer browser real | Admin na página Aprovações, cliente submeter, ver linha aparecer |
| Badge incrementa para change_requested | RTUP-01 | Requer browser + WebSocket real | Admin em qualquer página, cliente pedir alteração, badge +1 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
