---
phase: 19-client-real-time-arte-status-broadcast
plan: "02"
subsystem: layout-channels
tags: [actioncable, websocket, auth-token, security, gap-closure]

dependency_graph:
  requires:
    - phase: "19-01"
      provides: "Arte#broadcasts_revised_to_all, ClientCalendarChannel, partials com DOM IDs estáveis"
    - phase: "19-00"
      provides: "layout cliente com turbo_stream_from, Connection#set_current_client via params[:token]"
  provides:
    - fix: "Meta tag action-cable-url com token na query string — WebSocket autentica via /cable?token=ACCESS_TOKEN"
    - fix: "return reject antes de stream_for — stream parasita global eliminada"
    - unblocks: [RTUP-05, RTUP-06, RTUP-07]
  affects:
    - 19-03 (checkpoint de verificação humana)

tech-stack:
  added: []
  patterns:
    - "meta[name='action-cable-url'] antes de javascript_importmap_tags: ActionCable JS lê a meta durante inicialização do consumer"
    - "Guard if @client em ERB para meta tag: evita NoMethodError em pages sem autenticação"
    - "action_cable.url || '/cable': fallback para desenvolvimento onde a config é nil"
    - "return reject unless current_client: halt explícito — stream_for(nil) nunca chamado"

key-files:
  created: []
  modified:
    - app/views/layouts/client.html.erb
    - app/channels/client_calendar_channel.rb

key-decisions:
  - "Meta tag posicionada ANTES de javascript_importmap_tags porque ActionCable JS lê getConfig('url') na inicialização — se o script carrega antes da meta existir, usa /cable sem token"
  - "Guard if @client na meta tag: layout é compartilhado com páginas de login onde @client é nil"
  - "return reject (não apenas reject): ActionCable#reject seta flag mas não interrompe execução — stream_for(nil) criava stream parasita 'client_calendar_channel'"
  - "Verificação estática: PostgreSQL indisponível no ambiente executor — verificação funcional delegada ao checkpoint humano (Task 3)"

requirements-completed:
  - RTUP-05
  - RTUP-06
  - RTUP-07

duration: 10min
completed: "2026-06-06"
---

# Phase 19 Plan 02: Gap Closure — Meta Tag ActionCable URL + Return Reject — Summary

**Meta tag `action-cable-url` com token inserida no layout do cliente antes de `javascript_importmap_tags`, e `return reject` adicionado ao `ClientCalendarChannel#subscribed` — dois fixes de 1 linha cada que desbloqueiam a autenticação WebSocket real e eliminam a stream parasita.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-06-06T18:30:00Z
- **Completed:** 2026-06-06T18:40:00Z
- **Tasks:** 3 completas (2 auto + 1 checkpoint humano aprovado)
- **Commits:** 2 (1 por task)

## What Was Built

### Task 1 — CR-01: Meta tag action-cable-url no layout cliente

Adicionadas 3 linhas ao `app/views/layouts/client.html.erb`:

```erb
<% if @client %>
  <meta name="action-cable-url" content="<%= "#{Rails.application.config.action_cable.url || '/cable'}?token=#{@client.access_token}" %>">
<% end %>
```

**Posição:** após `yield :head` (linha 9) e ANTES de `javascript_importmap_tags` (linha 15). O ActionCable JS lê `meta[name='action-cable-url']` via `getConfig("url")` durante a inicialização do consumer — se o script carrega antes da meta existir, usa `/cable` sem token, causando falha de autenticação.

**Guard `if @client`:** o layout é compartilhado por pages de login onde `@client` é nil. Sem o guard, `@client.access_token` levantaria `NoMethodError`.

### Task 2 — CR-02: return reject no ClientCalendarChannel

Mudança de 1 caractere em `app/channels/client_calendar_channel.rb`:

```ruby
# ANTES
reject unless current_client
stream_for current_client

# DEPOIS
return reject unless current_client
stream_for current_client
```

**Por que importa:** `ActionCable::Channel::Base#reject` seta `@reject_subscription = true` mas não interrompe a execução. Sem `return`, `stream_for(nil)` era chamado, criando um broadcasting com nome `"client_calendar_channel"` (stream global não-scoped). Toda conexão rejeitada ficava inscrita nessa stream parasita.

## Commits

| Task | Commit | Descrição |
|------|--------|-----------|
| Task 1 — CR-01 layout | `f448e59` | fix(19-02): CR-01 — meta tag action-cable-url com token no layout cliente |
| Task 2 — CR-02 channel | `a6c32d4` | fix(19-02): CR-02 — return reject para halt em ClientCalendarChannel |

## Verification

| Check | Status | Evidence |
|-------|--------|----------|
| meta tag presente | PASS | `grep -n "action-cable-url" client.html.erb` → linha 11 |
| posição correta (< importmap) | PASS | linha 11 < linha 15 |
| guard if @client | PASS | linha 10 `<% if @client %>` |
| fallback \|\| '/cable' | PASS | presente no content da meta tag |
| return reject | PASS | `grep "return reject unless current_client"` → 1 match |
| pattern antigo removido | PASS | `reject unless` sem return → 0 matches |
| 6 linhas no channel | PASS | `wc -l` → 6 |
| rails test 0 failures | N/A | PostgreSQL indisponível no ambiente executor — verificação delegada ao checkpoint humano |

## Task 3 — Checkpoint Humano: APROVADO

Verificação funcional aprovada pelo usuário em 2026-06-06:
- Cenário 0: Handshake WebSocket `/cable?token=ACCESS_TOKEN` com status 101 — PASS
- Cenário 2 (RTUP-05): Chip da arte atualiza para "Revisado" dentro de 2s — PASS
- Cenário 3 (RTUP-06): Faixa `#calendar-summary` atualiza contadores em tempo real — PASS
- Cenário 4 (RTUP-07): Toast "Arte revisada" com auto-dismiss e botão × — PASS

## Deviations from Plan

Nenhuma — plano executado exatamente como escrito. Dois fixes de 1 linha cada, sem alterações arquiteturais.

## Known Stubs

Nenhum.

## Threat Flags

Nenhum. A meta tag não introduz nova superfície de ataque — `access_token` já está disponível na URL HTTP da página (`?token=ACCESS_TOKEN`). O threat model T-19-09 cobre este caso com disposition `accept`.

## Self-Check

- [x] `app/views/layouts/client.html.erb` — FOUND (linha 11 com meta tag, linha 10 com guard)
- [x] `app/channels/client_calendar_channel.rb` — FOUND (linha 3 com return reject)
- [x] Commit `f448e59` — FOUND (`git log --oneline | grep f448e59`)
- [x] Commit `a6c32d4` — FOUND (`git log --oneline | grep a6c32d4`)
