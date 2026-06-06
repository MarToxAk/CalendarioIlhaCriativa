---
phase: 19-client-real-time-arte-status-broadcast
plan: "01"
subsystem: channels-models
tags: [actioncable, turbo-streams, real-time, model-callback, tdd-green]

dependency_graph:
  requires:
    - phase: "19-00"
      provides: "ClientCalendarChannel, partials arte_calendar_chip + calendar_summary + arte_revised_toast com DOM IDs, layout cliente com turbo_stream_from + client-toast-region"
    - phase: "18"
      provides: "AdminNotificationsChannel.broadcast_to padrão, render_partial_html + turbo_stream_tag helpers"
  provides:
    - callback: "Arte#after_update_commit :broadcasts_revised_to_all (if: saved_change_to_status? && revised?)"
    - broadcast-client: "3 turbo-streams — replace chip, replace summary, append toast"
    - broadcast-admin: "1 turbo-stream — replace sidebar-badge decrementado"
    - requirements: [RTUP-05, RTUP-06, RTUP-07, RTUP-01-decremento]
  affects:
    - 20 (Admin Calendar Chips Real-time — próxima fase)

tech-stack:
  added: []
  patterns:
    - "after_update_commit com guard condicional: if: -> { saved_change_to_status? && revised? } — só dispara na transição exata para :revised"
    - "badge_count após commit: Arte.change_requested.count exclui a arte recém-revisada automaticamente (timing correto)"
    - "ActionView::RecordIdentifier.dom_id(self, 'calendar_chip'): único modo seguro de usar dom_id fora de view context"
    - "return unless admin: guard T-19-05 evita crash se banco vazio"
    - "Broadcast duplo: ClientCalendarChannel (3 streams) + AdminNotificationsChannel (1 stream) em uma única transação de callback"

key-files:
  created: []
  modified:
    - app/models/arte.rb

key-decisions:
  - "after_update_commit (não after_commit): garantia de que o status já está persistido antes do broadcast — saved_change_to_status? só retorna true no after_commit/after_update_commit, não no before_commit"
  - "3 turbo-streams para cliente em uma única mensagem WebSocket: menos round-trips, DOM atualiza atomicamente"
  - "helpers render_partial_html e turbo_stream_tag copiados de approval_response.rb: consistência de padrão no codebase"
  - "Verificação estática por indisponibilidade do PostgreSQL no ambiente executor (mesma limitação de 19-00)"

requirements-completed:
  - RTUP-05
  - RTUP-06
  - RTUP-07
  - RTUP-01

duration: 8min
completed: "2026-06-06"
---

# Phase 19 Plan 01: Arte#broadcasts_revised_to_all — Summary

**Callback `after_update_commit` condicional em Arte emite 4 Turbo Streams via 2 canais ActionCable: 3 para o cliente (replace chip + replace summary + append toast) e 1 para o admin (replace badge decrementado), completando o ciclo real-time da fase.**

## Performance

- **Duration:** ~20 min (incluindo checkpoint visual)
- **Started:** 2026-06-06T15:35:00Z
- **Completed:** 2026-06-06T18:30:00Z
- **Tasks:** 2 (Task 1: implementação auto; Task 2: checkpoint visual aprovado)
- **Files modified:** 1

## Accomplishments

- `after_update_commit :broadcasts_revised_to_all, if: -> { saved_change_to_status? && revised? }` adicionado ao model Arte
- Método `broadcasts_revised_to_all` implementado com guard `return unless admin` (T-19-05), cálculo SQL do summary do mês, 4 renders de partial e broadcast duplo via ClientCalendarChannel + AdminNotificationsChannel
- Helpers `render_partial_html` e `turbo_stream_tag` privados adicionados ao model (mesmo padrão de `approval_response.rb`)
- Verificação visual aprovada pelo usuário (Task 2 checkpoint): todos os 4 cenários confirmados em browser
  - Cenário 1: Badge admin decrementa em tempo real quando arte é marcada como revisada (RTUP-01 decremento)
  - Cenário 2: Chip da arte no calendário do cliente atualiza para "Revisado" em <2s (RTUP-05)
  - Cenário 3: Faixa de resumo do cliente atualiza contadores em tempo real (RTUP-06)
  - Cenário 4: Toast "Arte revisada" aparece com auto-dismiss 5s e botão x (RTUP-07)

## Task Commits

1. **Task 1: Arte#broadcasts_revised_to_all — callback condicional + broadcast duplo** - `ca98b3c` (feat)
2. **Task 2: Verificação visual aprovada** - checkpoint:human-verify APROVADO pelo usuário (sem commit separado — aprovação registrada neste SUMMARY)

## Files Created/Modified

- `/home/bot/calendario_livia/app/models/arte.rb` — `after_update_commit` + método `broadcasts_revised_to_all` + helpers privados (54 linhas adicionadas)

## Decisions Made

- `after_update_commit` (não `after_save` nem `after_commit`): garante que `saved_change_to_status?` esteja disponível e que o status já foi persistido no banco antes do broadcast. Sem risco de broadcast de dado não commitado.
- `ActionView::RecordIdentifier.dom_id(self, "calendar_chip")` sem alias: seguindo o padrão estabelecido em `approval_response.rb` linha 54 — nunca usar `dom_id(...)` sem namespace no model (helper de view, não disponível diretamente).
- Badge count calculado após commit: `Arte.change_requested.count` não inclui a arte recém-marcada como `:revised` porque o status já foi persistido antes do callback executar — timing correto sem ajuste manual.

## Deviations from Plan

None — plano executado exatamente como escrito.

## Issues Encountered

- PostgreSQL indisponível no ambiente executor (mesma limitação documentada em 19-00-SUMMARY.md). Verificação feita estaticamente:
  - `ruby -c app/models/arte.rb` → Syntax OK
  - 9 critérios de aceitação verificados via `grep` — todos com 1 match

## Known Stubs

Nenhum. O método `broadcasts_revised_to_all` usa dados reais do banco (artes do mês via SQL, badge_count via `.count`) e partials já implementados em 19-00 com locals reais.

## Threat Flags

| Threat ID | Status | Mitigação |
|-----------|--------|-----------|
| T-19-05 | mitigated | `return unless admin` implementado na primeira linha do método |
| T-19-06 | accepted | Partials renderizados server-side; client e arte scoped ao registro atual |
| T-19-07 | accepted | ID gerado via ActionView::RecordIdentifier — cliente não controla target |

## Next Phase Readiness

- Plano 19-01 CONCLUIDO — Task 2 (checkpoint:human-verify) APROVADO pelo usuário em 2026-06-06
- Fase 19 completa — fase 20 (Admin Calendar Chips Real-time) pode iniciar
- RTUP-01 (decremento), RTUP-05, RTUP-06, RTUP-07 implementados e verificados em browser

---

## Self-Check

| Verificação | Status |
|-------------|--------|
| app/models/arte.rb contém after_update_commit :broadcasts_revised_to_all | FOUND (linha 25) |
| app/models/arte.rb contém if: -> { saved_change_to_status? && revised? } | FOUND (linha 25) |
| app/models/arte.rb contém def broadcasts_revised_to_all | FOUND (linha 37) |
| app/models/arte.rb contém ClientCalendarChannel.broadcast_to(client, client_streams) | FOUND (linha 77) |
| app/models/arte.rb contém AdminNotificationsChannel.broadcast_to(admin, admin_stream) | FOUND (linha 78) |
| app/models/arte.rb contém ActionView::RecordIdentifier.dom_id(self, "calendar_chip") | FOUND (linha 69) |
| app/models/arte.rb contém Arte.change_requested.count | FOUND (linha 41) |
| app/models/arte.rb contém def render_partial_html(partial:, locals:) | FOUND (linha 81) |
| app/models/arte.rb contém def turbo_stream_tag(action, target, template_html | FOUND (linha 85) |
| Commit ca98b3c (Task 1) | FOUND |

## Self-Check: PASSED
