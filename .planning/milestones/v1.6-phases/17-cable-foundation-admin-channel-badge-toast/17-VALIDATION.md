---
phase: 17
slug: cable-foundation-admin-channel-badge-toast
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-05
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | minitest (Rails built-in) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `bundle exec rails test test/channels/ test/models/` |
| **Full suite command** | `bundle exec rails test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bundle exec rails test test/channels/ test/models/`
- **After every plan wave:** Run `bundle exec rails test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 0 | CABLE-01 | T-17-01 | Conexão rejeitada sem auth válida | unit | `bundle exec rails test test/channels/application_cable/connection_test.rb` | ❌ W0 | ⬜ pending |
| 17-01-02 | 01 | 1 | CABLE-01 | T-17-01 | Admin autentica via cookie de sessão | unit | `bundle exec rails test test/channels/application_cable/connection_test.rb` | ❌ W0 | ⬜ pending |
| 17-01-03 | 01 | 1 | CABLE-01 | T-17-02 | Cliente autentica via token URL | unit | `bundle exec rails test test/channels/application_cable/connection_test.rb` | ❌ W0 | ⬜ pending |
| 17-02-01 | 02 | 1 | CABLE-01 | — | Canal aceita subscription de admin autenticado | unit | `bundle exec rails test test/channels/admin_notifications_channel_test.rb` | ❌ W0 | ⬜ pending |
| 17-02-02 | 02 | 1 | CABLE-01 | T-17-01 | Canal rejeita subscription sem current_user | unit | `bundle exec rails test test/channels/admin_notifications_channel_test.rb` | ❌ W0 | ⬜ pending |
| 17-03-01 | 03 | 1 | CABLE-02 | — | Badge exibe count > 0 quando há artes change_requested | unit | `bundle exec rails test test/models/arte_test.rb` | ✅ | ⬜ pending |
| 17-04-01 | 04 | 1 | CABLE-02 | — | Stimulus toast_controller está registrado | manual | Abre console browser, verifica `Stimulus.controllers` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/channels/application_cable/connection_test.rb` — stubs para CABLE-01 autenticação
- [ ] `test/channels/admin_notifications_channel_test.rb` — stubs para CABLE-01 canal
- [ ] `app/channels/application_cable/channel.rb` — base class ausente no projeto (NameError sem ela)

*`app/channels/application_cable/channel.rb` é requisito de Wave 0 crítico — sem ele nenhum canal compila.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| WebSocket conecta no browser sem erros | CABLE-01 | Requer browser real com console aberto | 1. Login admin, 2. Abrir DevTools > Network > WS, 3. Verificar handshake `/cable` com status 101 |
| toast_controller responde a append DOM | CABLE-02 | Stimulus no browser — não testável via minitest | 1. Abrir console, 2. `document.getElementById('admin-toast-region').dispatchEvent(new CustomEvent('toast:show', {detail: {message: 'test'}}))` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
