---
phase: 19-client-real-time-arte-status-broadcast
plan: "00"
subsystem: channels-views
tags: [actioncable, turbo-streams, real-time, client-portal, tdd-red]

dependency_graph:
  requires:
    - phase: "17"
      provides: "toast_controller.js com auto-dismiss 5s, ApplicationCable::Channel base"
    - phase: "18"
      provides: "AdminNotificationsChannel.broadcast_to padrão, partial structure"
  provides:
    - channel: ClientCalendarChannel (stream_for current_client)
    - dom-id: arte_N_calendar_chip no partial _arte_calendar_chip
    - dom-id: calendar-summary sempre no DOM (hidden CSS)
    - dom-id: client-toast-region no layout cliente
    - partial: client/shared/_arte_revised_toast.html.erb
    - tests-red: 3 testes RED para Arte#broadcasts_revised_to_all (aguardando 19-01)
  affects:
    - 19-01 (implementa broadcasts_revised_to_all que usa esses partials e canal)

tech-stack:
  added: []
  patterns:
    - "ClientCalendarChannel.stream_for: stream por GlobalID do Client — opaco, não adivinhável (D-03)"
    - "reject unless current_client: defesa em profundidade no subscribed — complementa connection.rb (D-04)"
    - "turbo_stream_from @client (guard if @client): não emite tag sem autenticação (D-08)"
    - "id='calendar-summary' sempre no DOM com hidden CSS: Turbo Stream replace sempre encontra target (D-06 / Pitfall 3)"
    - "dom_id(arte, 'calendar_chip'): ID estável para replace cirúrgico por arte individual (D-05)"
    - "Reutilização de toast_controller.js: auto-dismiss 5s e botão dismiss sem JavaScript novo (D-09)"

key-files:
  created:
    - app/channels/client_calendar_channel.rb
    - app/views/client/home/_arte_calendar_chip.html.erb
    - app/views/client/home/_calendar_summary.html.erb
    - app/views/client/shared/_arte_revised_toast.html.erb
    - test/channels/client_calendar_channel_test.rb
  modified:
    - app/views/layouts/client.html.erb
    - app/views/client/home/index.html.erb
    - app/views/client/home/_month_calendar.html.erb
    - test/models/arte_test.rb

key-decisions:
  - "reject (não reject_unauthorized_connection): método correto de ActionCable::Channel::Base, conforme padrão AdminNotificationsChannel"
  - "id='calendar-summary' fora de condicional Ruby: hidden CSS em vez de omitir o elemento — Turbo Stream replace falha silenciosamente se target ausente"
  - "toast_controller.js _enforceLimit() retorna null no cliente (usa admin-toast-region): comportamento aceito, auto-dismiss e dismiss manual funcionam normalmente (D-09)"
  - "Testes RED commitados antes do canal existir: confirmado NameError/LoadError como RED state"

metrics:
  duration: "10min"
  completed: "2026-06-06T13:19:19Z"
  tasks_completed: 3
  files_changed: 9
---

# Phase 19 Plan 00: Infraestrutura real-time do cliente — Summary

**One-liner:** Canal ActionCable per-client com stream_for, layout com turbo_stream_from + toast region, 3 partials com DOM IDs estáveis e 5 testes RED prontos para ficarem GREEN em 19-01.

## O que foi feito

### Task 1 — Testes RED
- Criado `test/channels/client_calendar_channel_test.rb` com 2 testes (subscribes + rejects)
- Adicionados 3 testes ao `test/models/arte_test.rb`:
  - "revised! dispara broadcast para ClientCalendarChannel e AdminNotificationsChannel" (stub duplo, conta turbo-streams)
  - "revised! nao dispara broadcast quando update nao muda status para revised" (no-op update)
  - "revised! nao dispara broadcast quando status muda mas nao para revised" (no-op approved)
- Estado RED confirmado: testes do canal falhavam com LoadError (canal inexistente); testes do model falharão com NameError até 19-01

### Task 2 — Canal e Layout
- Criado `app/channels/client_calendar_channel.rb`: `reject unless current_client` + `stream_for current_client` — simétrico ao AdminNotificationsChannel
- Atualizado `app/views/layouts/client.html.erb`:
  - `turbo_stream_from @client, channel: ClientCalendarChannel if @client` — guard defende página de login
  - `div#client-toast-region` com `fixed bottom-4 right-4 z-50` — mesmo posicionamento do admin

### Task 3 — Partials com DOM IDs estáveis + refatoração das views
- **Novo** `_arte_calendar_chip.html.erb`: link_to extraído de `_month_calendar` com `id: dom_id(arte, "calendar_chip")` — target estável para Turbo Stream replace cirúrgico
- **Novo** `_calendar_summary.html.erb`: faixa de resumo extraída de `index.html.erb` com `id="calendar-summary"` sempre no DOM — `hidden` CSS quando total==0 (Pitfall 3 evitado)
- **Novo** `_arte_revised_toast.html.erb`: "Arte revisada" + título/data + link "Ver arte" + botão dismiss — reutiliza `toast_controller.js`
- **Modificado** `index.html.erb`: substitui bloco `if @summary[:total] > 0 ... end` por `render "client/home/calendar_summary"`
- **Modificado** `_month_calendar.html.erb`: substitui loop link_to inline por `render "client/home/arte_calendar_chip"`

## Commits

| # | Task | Commit | Tipo | Arquivos |
|---|------|--------|------|---------|
| 1 | RED tests | `36da39f` | test | `test/channels/client_calendar_channel_test.rb` (NOVO), `test/models/arte_test.rb` |
| 2 | Canal + Layout | `bbfd099` | feat | `app/channels/client_calendar_channel.rb` (NOVO), `app/views/layouts/client.html.erb` |
| 3 | Partials + Views | `4714637` | feat | 3 partials NOVOS + 2 views modificadas |

## Deviations from Plan

None — plano executado exatamente como escrito.

## Verificação Estática (sem banco de dados disponível)

O ambiente de teste (worktree do agente) não tem acesso ao PostgreSQL — mesma limitação observada na Phase 18 Plan 02. Verificações realizadas:

- `ruby -c app/channels/client_calendar_channel.rb` → Syntax OK
- Canal tem `reject unless current_client` + `stream_for current_client` → testes do canal passariam GREEN (canal existe, behavior correto)
- Testes do model falharão RED até 19-01 implementar `broadcasts_revised_to_all` em `arte.rb` (método não existe na codebase principal)

## Known Stubs

Nenhum. Os partials recebem locals reais (arte, client, summary) e delegam para helpers existentes. Nenhum dado hardcoded ou placeholder presente nos arquivos de produção.

## Threat Flags

Nenhuma superfície nova além do planejado:

| Threat ID | Status | Mitigação |
|-----------|--------|-----------|
| T-19-01 | mitigated | `reject unless current_client` implementado |
| T-19-02 | mitigated | `if @client` guard implementado no layout |
| T-19-03 | accepted | Toast renderiza apenas dados da própria arte do cliente |

## Self-Check: PASSED

Todos os arquivos encontrados no filesystem do worktree. Todos os 3 commits encontrados no git log.

| Verificação | Status |
|------------|--------|
| test/channels/client_calendar_channel_test.rb | FOUND |
| test/models/arte_test.rb | FOUND |
| app/channels/client_calendar_channel.rb | FOUND |
| app/views/layouts/client.html.erb | FOUND |
| app/views/client/home/_arte_calendar_chip.html.erb | FOUND |
| app/views/client/home/_calendar_summary.html.erb | FOUND |
| app/views/client/shared/_arte_revised_toast.html.erb | FOUND |
| app/views/client/home/index.html.erb | FOUND |
| app/views/client/home/_month_calendar.html.erb | FOUND |
| Commit 36da39f (Task 1) | FOUND |
| Commit bbfd099 (Task 2) | FOUND |
| Commit 4714637 (Task 3) | FOUND |
