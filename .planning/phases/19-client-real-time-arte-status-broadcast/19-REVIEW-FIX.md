---
phase: 19-client-real-time-arte-status-broadcast
fixed_at: 2026-06-06T00:00:00Z
review_path: .planning/phases/19-client-real-time-arte-status-broadcast/19-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 19: Code Review Fix Report

**Fixed at:** 2026-06-06
**Source review:** .planning/phases/19-client-real-time-arte-status-broadcast/19-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (2 Critical + 2 Warning)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: Broadcast substitui `#calendar-summary` com dados do mês errado

**Files modified:** `app/models/arte.rb`, `test/models/arte_test.rb`
**Commit:** 6c90dc0
**Applied fix:** Removido o turbo_stream `replace` de `#calendar-summary` e o
bloco de cálculo do summary mensal do método `broadcasts_revised_to_all`. O
broadcast ao cliente agora envia apenas 2 streams: chip (`replace`) e toast
(`append`). O resumo mensal não é atualizado em tempo real via broadcast —
permanece responsabilidade da navegação normal, evitando a sobrescrita com dados
do mês errado. Adicionado comentário inline explicando a decisão. A assertion do
teste em `arte_test.rb` foi atualizada de 3 para 2 turbo-streams para refletir
o comportamento correto. Também aproveitado para adicionar o comentário de IN-02
(`badge_count` global) inline no código.

### CR-02: `toast_controller.js` — `_enforceLimit` usa ID hardcoded

**Files modified:** `app/javascript/controllers/toast_controller.js`
**Commit:** d78befa
**Applied fix:** Substituído `document.getElementById("admin-toast-region")` por
`this.element.parentElement`. O método agora localiza a região de toasts a partir
do elemento pai do toast atual, funcionando corretamente tanto em páginas de admin
(`admin-toast-region`) quanto de cliente (`client-toast-region`) sem depender de
nenhum ID específico. Atualizado o comentário do método para documentar a intenção.

### WR-01: `AdminNotificationsChannel#subscribed` sem `return reject`

**Files modified:** `app/channels/admin_notifications_channel.rb`
**Commit:** 5bcad0c
**Applied fix:** Adicionado `return` antes de `reject` no guard de autenticação.
`reject unless current_user` foi substituído por `return reject unless current_user`,
impedindo que `stream_for(nil)` seja chamado quando `current_user` é nil. Padrão
agora consistente com `ClientCalendarChannel`.

### WR-02: Teste de broadcast depende implicitamente de fixture de `User`

**Files modified:** `test/models/arte_test.rb`
**Commit:** db46125
**Applied fix:** Adicionada asserção explícita `assert User.exists?` com mensagem
descritiva no início do teste `"revised! dispara broadcast..."`. Se os fixtures de
`User` forem removidos, a falha agora indica diretamente a causa em vez de exibir
uma mensagem enganosa sobre `admin_calls.length`.

## Skipped Issues

Nenhum — todos os findings em escopo foram corrigidos.

---

_Fixed: 2026-06-06_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
