---
phase: 19
slug: client-real-time-arte-status-broadcast
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-06
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Minitest (Rails built-in) |
| **Config file** | `test/test_helper.rb` |
| **Quick run command** | `rails test test/channels/client_calendar_channel_test.rb test/models/arte_test.rb` |
| **Full suite command** | `rails test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `rails test test/channels/client_calendar_channel_test.rb test/models/arte_test.rb`
- **After every plan wave:** Run `rails test`
- **Before `/gsd-verify-work`:** Full suite must be green

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-00-01 | 00 | 0 | D-03, D-04 | T-19-01 | Canal rejeita conexão sem `current_client` | unit (channel) | `rails test test/channels/client_calendar_channel_test.rb` | ❌ W0 | ⬜ pending |
| 19-00-02 | 00 | 0 | RTUP-05, RTUP-06, RTUP-07, RTUP-01 | — | N/A | unit (model) | `rails test test/models/arte_test.rb` | ✅ (parcial) | ⬜ pending |
| 19-01-01 | 01 | 1 | D-03, D-04 | T-19-01 | `stream_for current_client` scoped ao record | unit (channel) | `rails test test/channels/client_calendar_channel_test.rb` | ❌ W0 | ⬜ pending |
| 19-02-01 | 02 | 1 | D-01, D-02, RTUP-05, RTUP-06, RTUP-07, RTUP-01 | T-19-02 | `return unless admin` previne crash | unit (model) | `rails test test/models/arte_test.rb` | ✅ (parcial) | ⬜ pending |
| 19-03-01 | 03 | 2 | D-05, D-06, D-08, D-09 | — | guard `if @client` no layout | integration | `rails test test/models/arte_test.rb` | ✅ (parcial) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/channels/client_calendar_channel_test.rb` — stubs RED para D-03 (subscribe + stream_for) e D-04 (reject sem current_client)
- [ ] Novos testes em `test/models/arte_test.rb` — stubs RED para RTUP-05 (3 turbo streams para cliente), RTUP-06 (summary replace), RTUP-07 (toast append), RTUP-01 decremento (badge replace)

*Infraestrutura existente cobre o restante — Minitest + fixtures já operacionais.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cliente vê badge mudar de "Pediu Alteração" para "Revisado" em < 2s | RTUP-05 | UI real-time — requer browser + WebSocket ativo | 1. Abrir calendário do cliente em browser; 2. Admin clica "Marcar como Revisada"; 3. Verificar que chip atualiza sem reload |
| Faixa de resumo atualiza contadores em tempo real | RTUP-06 | UI real-time — requer browser | 1. Abrir calendário do cliente; 2. Admin marca como revisada; 3. Verificar contagem "Pediu Alteração" decrementou |
| Cliente recebe toast visível | RTUP-07 | UI real-time — requer browser | 1. Abrir calendário; 2. Admin marca como revisada; 3. Verificar toast aparece bottom-right com "Arte revisada" |
| Badge do sidebar admin decrementa em 1 | RTUP-01 (decr) | UI real-time — requer browser | 1. Admin com badge > 0; 2. Marcar arte como revisada; 3. Verificar badge decrementou |
| `_enforceLimit` não aplica max-3 no cliente | D-09 pitfall | Comportamento aceito por D-09 (zero JS novo) | Documentar explicitamente que limite de 3 toasts não é testado no cliente |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
