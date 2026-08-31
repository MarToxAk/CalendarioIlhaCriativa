---
phase: quick/260831-gai-preciso-corrigir-a-quest-o-de-grupos-do-
plan: 1
subsystem: infra
tags: [evolution-api, faraday, timeout, whatsapp, groups]

# Dependency graph
requires:
  - phase: 27-grupos-do-cliente
    provides: "Evolution::Client.fetch_groups, Whatsapp::GroupSynchronizer, retry_on em Whatsapp::SyncGroupsJob"
provides:
  - "Evolution::READ_TIMEOUT_GROUPS (60s, ENV-first) — timeout dedicado para fetchAllGroups"
  - "fetch_groups usando o novo timeout em vez de READ_TIMEOUT_FAST (15s)"
affects: [whatsapp-groups, evolution-client, sync-groups-job]

actuals:
  tokens: 950
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - app/services/evolution.rb
    - app/services/evolution/client.rb
    - test/services/evolution/client_test.rb

key-decisions:
  - "READ_TIMEOUT_GROUPS = 60s (ENV EVOLUTION_READ_TIMEOUT_GROUPS), separado de READ_TIMEOUT_FAST (15s), porque fetchAllGroups faz uma chamada profilePicture por grupo no servidor Evolution e escala com o número de grupos da instância — confirmado empiricamente contra a instância real de produção livia_client_31 (64 grupos, ~40s de resposta real)."
  - "connect/fetch_instances/connection_state permanecem com READ_TIMEOUT_FAST (15s) — latência real medida ~654ms, sem regressão."
  - "retry_on/discard_on de Whatsapp::SyncGroupsJob não foram alterados — a política de retry já era adequada; o problema era o timeout por-tentativa, não o número de tentativas."

requirements-completed: [GRUPO-01, GRUPO-02]

coverage:
  - id: D1
    description: "Evolution::Client.fetch_groups usa um timeout dedicado de 60s (READ_TIMEOUT_GROUPS), distinto do timeout rápido de 15s usado por connect/fetch_instances/connection_state"
    requirement: "GRUPO-01"
    verification:
      - kind: unit
        ref: "test/services/evolution/client_test.rb#fetch_groups uses Evolution::READ_TIMEOUT_GROUPS, not READ_TIMEOUT_FAST"
        status: pass
      - kind: other
        ref: "bin/rails runner constant check (READ_TIMEOUT_GROUPS == 60, distinto de READ_TIMEOUT_FAST)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Suíte completa de fetch_groups (7 testes pré-existentes + 1 novo) e suíte completa do client_test.rb passam sem regressão"
    requirement: "GRUPO-02"
    verification:
      - kind: unit
        ref: "bin/rails test test/services/evolution/client_test.rb -n \"/fetch_groups/\" (8 runs, 13 assertions, 0 failures)"
        status: pass
      - kind: unit
        ref: "bin/rails test test/services/evolution/client_test.rb (34 runs, 74 assertions, 0 failures)"
        status: pass
    human_judgment: true
    rationale: "A correção resolve um timeout de configuração medido empiricamente nesta sessão contra a instância real de produção, mas o teste automatizado usa Faraday::Adapter::Test (stub) — não bate de novo contra o host Evolution real com 64 grupos. Confirmação final de que o timeout de 60s resolve o problema em produção (clique real em 'Sincronizar grupos' numa instância ocupada) requer validação do operador em ambiente real, listada como nota operacional no PLAN."

duration: ~10min
completed: 2026-08-31
status: complete
---

# Quick Task 260831-gai: fetchAllGroups timeout dedicado Summary

**`Evolution::Client.fetch_groups` passou a usar `Evolution::READ_TIMEOUT_GROUPS` (60s, configurável via `EVOLUTION_READ_TIMEOUT_GROUPS`) em vez do timeout rápido de 15s compartilhado com `connectionState`/`fetchInstances`, corrigindo o `Net::ReadTimeout` que travava a sincronização de grupos em instâncias de produção com dezenas de grupos.**

## Performance

- **Duration:** ~10min
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments
- Nova constante `Evolution::READ_TIMEOUT_GROUPS` (default 60s, ENV-first via `EVOLUTION_READ_TIMEOUT_GROUPS`, mesmo padrão das constantes irmãs `OPEN_TIMEOUT`/`WRITE_TIMEOUT`/`READ_TIMEOUT`)
- `Evolution::Client.fetch_groups` agora usa `READ_TIMEOUT_GROUPS` em vez de `READ_TIMEOUT_FAST`
- `connect`/`fetch_instances`/`connection_state` permanecem inalterados, ainda com `READ_TIMEOUT_FAST` (15s)
- Novo teste trava o comportamento inspecionando `env.request.read_timeout` no stub Faraday; os 7 testes pré-existentes de `fetch_groups` continuam passando sem alteração

## Task Commits

Each task was committed atomically:

1. **Task 1: Dar a fetchAllGroups um timeout próprio (fix da causa raiz)** - `2215784` (fix)
2. **Task 2: Travar o timeout novo com teste + regressão dos existentes** - `a36787b` (test)

_Note: Task 2 (tdd="true") followed the plan's explicit two-task split — Task 1 implemented the fix, Task 2 added the locking test. Since the fix was already correctly implemented in Task 1's commit, the new test passed on first run (no RED phase possible without reverting Task 1); this matches the plan's intent of "test travando o valor" rather than a classic RED→GREEN cycle within Task 2 alone._

## Files Created/Modified
- `app/services/evolution.rb` - nova constante `READ_TIMEOUT_GROUPS` (60s, ENV-first) com comentário explicando a causa raiz (profilePicture por grupo no servidor Evolution)
- `app/services/evolution/client.rb` - `fetch_groups` usa `READ_TIMEOUT_GROUPS` em vez de `READ_TIMEOUT_FAST`; comentário do método atualizado
- `test/services/evolution/client_test.rb` - novo teste que inspeciona `env.request.read_timeout` do stub Faraday e trava o valor via `assert_equal`/`refute_equal`

## Decisions Made
- `READ_TIMEOUT_GROUPS = 60s` — generoso o bastante para instâncias reais (64 grupos ~40s medido), sem se aproximar do teto de ~100s do Cloudflare já documentado
- Não foi necessário tocar em `retry_on`/`discard_on` do `Whatsapp::SyncGroupsJob` — o problema era o timeout por-tentativa, não o número de tentativas
- `.env.example` não pôde ser editado (arquivo bloqueado por permissão do ambiente de execução) — item best-effort do plano, não bloqueante; adicionar `EVOLUTION_READ_TIMEOUT_GROUPS=60` manualmente é recomendado como follow-up de baixo risco

## Deviations from Plan

None - plan executado exatamente como escrito, exceto pelo item best-effort do `.env.example` (ver Decisions Made acima), que o próprio plano já classificava como não-bloqueante.

## Issues Encountered
- `.env.example` estava fora do escopo de permissão de leitura/escrita do agente nesta sessão (Read e Bash/grep negados). Como o próprio plano marcava esse passo como "best-effort, não bloqueia a task se o arquivo não for acessível", a task prosseguiu sem alteração nesse arquivo.

## User Setup Required

None - nenhuma configuração de serviço externo necessária. `EVOLUTION_READ_TIMEOUT_GROUPS` é opcional (default 60s já cobre o caso medido); só precisa ser setado via ENV se o operador quiser um valor diferente do default.

## Next Phase Readiness
- Fix pronto para validação em produção: próximo clique em "Sincronizar grupos" na instância real `livia_client_31` (WhatsappInstance id 20, atualmente com `groups_sync_state: sync_error`) deve resolver o estado sozinho, já que o synchronizer sempre sobrescreve `groups_sync_state`/`groups_sync_error` a cada tentativa.
- Nenhum blocker.

---
*Phase: quick/260831-gai-preciso-corrigir-a-quest-o-de-grupos-do-*
*Completed: 2026-08-31*

## Self-Check: PASSED

All created/modified files confirmed present on disk; both task commit hashes (`2215784`, `a36787b`) confirmed present in git log.
