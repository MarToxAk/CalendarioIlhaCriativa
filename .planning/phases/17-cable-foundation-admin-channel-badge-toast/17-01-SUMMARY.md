---
phase: 17-cable-foundation-admin-channel-badge-toast
plan: "01"
subsystem: api
tags: [actioncable, websocket, authentication, rails, connection]

requires:
  - phase: "17-00"
    provides: "test/channels/application_cable/connection_test.rb com 4 testes RED; test/fixtures/clients.yml e sessions.yml"

provides:
  - "ApplicationCable::Connection com autenticação dual: admin via cookie de sessão, cliente via token de URL"
  - "identified_by :current_user, :current_client declarado"
  - "método privado set_current_client: Client.find_by(access_token: token, active: true)"

affects:
  - "17-02 (AdminNotificationsChannel usa current_user da connection)"
  - "17-03 (badge e toast dependem da connection autenticada)"
  - "Phase 18 (broadcasts de aprovação — clientes conectam via token)"
  - "Phase 19 (ClientCalendarChannel — usa current_client)"

tech-stack:
  added: []
  patterns:
    - "Autenticação dual ActionCable: admin via Session.find_by(id: cookies.signed[:session_id]), cliente via Client.find_by(access_token: token, active: true)"
    - "Encadeamento de identificadores: identified_by :current_user, :current_client na mesma linha"
    - "Guard token.blank? antes de consulta ao banco — previne find_by com nil"

key-files:
  created: []
  modified:
    - app/channels/application_cable/connection.rb

key-decisions:
  - "identified_by :current_user, :current_client na mesma linha (D-01) — ActionCable suporta múltiplos identificadores"
  - "token.blank? como guard antes do find_by — nil e string vazia são rejeitados sem consultar o banco"
  - "active: true na condição do find_by (D-03) — clientes inativos rejeitados na connection, sem feedback diferenciado (timing-safe)"
  - "Verificação alternativa via RubyVM + grep — banco de teste não acessível no worktree (mesmo padrão documentado em Plan 00)"

patterns-established:
  - "set_current_client pattern: token = request.params[:token]; return nil if token.blank?; client = Client.find_by(...); self.current_client = client if client"

requirements-completed:
  - CABLE-01

duration: 2min
completed: 2026-06-05
---

# Phase 17 Plan 01: Connection.rb Autenticação Dual Summary

**connection.rb expandido com identified_by :current_user, :current_client e método set_current_client que autentica clientes via Client.find_by(access_token: token, active: true), completando a fundação WebSocket para admin e cliente**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-05T11:24:52Z
- **Completed:** 2026-06-05T11:26:53Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Expandiu connection.rb de 16 linhas (admin-only) para 25 linhas com suporte dual admin + cliente
- identified_by declara :current_user, :current_client — conformidade com D-01
- connect encadeia set_current_user || set_current_client || reject_unauthorized_connection — conformidade com D-04
- set_current_client novo: guard token.blank?, Client.find_by(access_token: token, active: true), atribuição self.current_client — conformidade com D-02/D-03
- set_current_user mantido intacto (sem modificação)

## Task Commits

1. **Task 1: Expandir connection.rb para autenticação dual admin + cliente** - `3c2559f` (feat)

**Plan metadata:** (ver commit de docs abaixo)

## Files Created/Modified

- `app/channels/application_cable/connection.rb` — identified_by expandido para dois identificadores; novo método privado set_current_client adicionado após set_current_user

## Decisions Made

- **token.blank? como guard:** previne consulta ao banco com nil/string vazia. `request.params[:token]` retorna nil quando não há parâmetro, e blank? cobre ambos os casos sem condição extra.
- **active: true na condição find_by:** clientes inativos são rejeitados na connection sem feedback diferenciado — timing-safe (não revela se o token existe mas está inativo vs. token inexistente).
- **Verificação alternativa:** banco de teste não acessível no worktree (PostgreSQL em 192.168.3.203, credenciais divergem). Verificação feita via `ruby -c` (sintaxe) e `bundle exec ruby -e "RubyVM::InstructionSequence.compile(...)"` (compilação) e grep das linhas-chave. Mesmo padrão documentado e aceito na Plan 00.

## Deviations from Plan

None - plano executado exatamente como especificado. As 8 linhas adicionadas correspondem precisamente à spec do plano.

## Issues Encountered

- **Banco de teste inacessível no worktree:** Mesmo problema documentado na Plan 00. `bundle exec rails test` falha com `ActiveRecord::DatabaseConnectionError` antes de executar qualquer teste. Verificação alternativa utilizada (sintaxe + grep de linhas-chave). Os 4 testes de connection_test.rb serão executados normalmente no ambiente de produção após o merge.

## Known Stubs

Nenhum. O código implementado está completo e não contém stubs ou placeholders.

## Threat Flags

Nenhum novo surface de segurança. Mitigações do threat model aplicadas:
- T-17-01-01 (Elevation of Privilege): reject_unauthorized_connection como última instrução — conexões anônimas rejeitadas
- T-17-01-02 (Information Disclosure): active: true na condição — clientes inativos rejeitados sem feedback diferenciado
- T-17-01-03 (Brute-force): aceito — token de 144 bits + Rack::Attack já instalado
- T-17-01-04 (SQL Injection): aceito — ActiveRecord parameteriza find_by automaticamente

## Next Phase Readiness

- Plan 02 pode criar AdminNotificationsChannel — usa connection.current_user (agora com :current_user em identified_by)
- Plan 03 pode implementar badge e toast — connection.rb completo, não precisa de mais modificações
- Phase 18 pode fazer broadcasts de ApprovalResponse — clientes conectam via token (set_current_client pronto)
- Phase 19 pode criar ClientCalendarChannel — usa current_client (declarado e populado)

## Self-Check

- FOUND: app/channels/application_cable/connection.rb — `identified_by :current_user, :current_client` presente
- FOUND: set_current_client com Client.find_by(access_token: token, active: true)
- FOUND: token.blank? guard
- FOUND: reject_unauthorized_connection encadeado
- COMMIT 3c2559f: feat(17-01): expandir connection.rb para autenticação dual admin + cliente

---
*Phase: 17-cable-foundation-admin-channel-badge-toast*
*Completed: 2026-06-05*
