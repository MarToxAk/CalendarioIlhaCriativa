---
phase: 29-motor-de-envio
plan: 02
subsystem: jobs
tags: [activejob, solid_queue, evolution-api, whatsapp, disparo, retry, concurrency]

requires:
  - phase: 29-motor-de-envio
    provides: "29-01: Whatsapp::SendToGroupJob (corpo completo do perform: claim atômico, revalidação, send_via_evolution, finalize_divulgacao_if_done como método de classe)"
provides:
  - "Whatsapp::SendToGroupJob — taxonomia de erro Evolution::Errors completa (discard_on/retry_on, catch-all StandardError primeiro)"
  - "limits_concurrency(to: 1, key: divulgacao.client.whatsapp_instance.id) serializando envios por instância (ENVIO-09)"
  - "Fix do retry_on-morto-pelo-claim: revert-then-raise em Evolution::Errors::Transient"
  - "Prova sob condição adversarial de que o claim atômico garante exatamente-uma-vez (ENVIO-04)"
affects: [29-03-fila-dedicada-escalonamento, 30-acompanhamento]

actuals:
  tokens: 3752
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "discard_on(StandardError) catch-all SEMPRE declarado primeiro na classe (rescue_handlers.reverse_each.detect prioriza o último declarado) -- mesmo padrão do Whatsapp::SyncGroupsJob"
    - "mark_falhou/mark_incerto como métodos de CLASSE, truncando error_code via ERROR_CODE_MAX_LENGTH = 500 e sempre chamando finalize_divulgacao_if_done"
    - "group.reload.update!(...) obrigatório para reverter um bulk update_all anterior -- dirty-tracking em memória não sabe do update_all e um update! sem reload vira no-op silencioso"

key-files:
  created: []
  modified:
    - app/jobs/whatsapp/send_to_group_job.rb
    - test/jobs/whatsapp/send_to_group_job_test.rb

key-decisions:
  - "Bug descoberto durante a implementação do Task 1 (Rule 1 — não estava no `<behavior>` do plano, mas é consequência direta dele): `group.update!(status: :pendente, ...)` dentro do rescue de Transient, sem reload, é um NO-OP silencioso — o objeto `group` em memória nunca foi sincronizado com o `update_all` (bulk SQL) do claim, então o dirty-tracking do ActiveRecord vê 'status já é pendente' e pula a coluna no UPDATE gerado. Confirmado via `bin/rails runner` isolado (reproduzido, corrigido, reproduzido de novo passando). Fix: `group.reload.update!(status: :pendente, sent_at: nil, updated_at: Time.current)`. Sem este fix, o retry_on(Transient) reenfileiraria infinitamente sem NUNCA reenviar de fato -- exatamente o defeito que este plano existe para provar que NÃO acontece (T-29-05)."
  - "Task 2 (idempotência) foi commitada separadamente do Task 1 (taxonomia+concorrência), com o app/jobs/whatsapp/send_to_group_job.rb tocado SÓ no commit do Task 1 -- confirma o acceptance criteria 'nenhum arquivo de produção tocado pelo Task 2'."
  - "limits_concurrency.concurrency_on_conflict retorna o SÍMBOLO :block (não a string \"block\") -- API real do solid_queue 1.4.0, teste ajustado para refletir o valor real em vez do texto informal do PLAN.md."

requirements-completed: [ENVIO-04, ENVIO-05, ENVIO-09]

coverage:
  - id: D1
    description: "Taxonomia de erro completa: Transient retries com backoff e realmente reenvia (revert-then-raise); Unknown vira incerto sem reenfileirar; Permanent/NotConnected/ConfigurationError/StandardError viram falhou com error_code truncado"
    requirement: "ENVIO-05"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#discard_on Permanent grava falhou e error_code truncado a partir da mensagem do erro"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#discard_on Unknown grava incerto (nunca falhou), sem reenfileirar"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#discard_on NotConnected grava falhou com instancia_desconectada"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#discard_on ConfigurationError grava falhou com a mensagem truncada"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#discard_on StandardError (catch-all) cobre excecao fora da taxonomia Evolution::Errors e ainda assim finaliza a divulgacao se for o ultimo grupo pendente"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#discard_on StandardError (catch-all) nao rouba Transient do retry_on mais especifico"
        status: pass
      - kind: other
        ref: "grep -n \"discard_on(StandardError)\" (linha 48) < todo retry_on/discard_on(Evolution (linhas 64-85) -- ordem de declaração correta"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fix do bug claim-vs-retry: rescue Evolution::Errors::Transient dentro de perform desfaz o claim (status volta a pendente) ANTES de re-raise, provado que a segunda tentativa REALMENTE reenvia (não vira no-op)"
    requirement: "ENVIO-04"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#retry_on Transient desfaz o claim (status volta a pendente) antes de reenfileirar -- a nova tentativa realmente tenta enviar de novo, nao vira no-op"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#retry_on Transient chama mark_falhou (error_code transient) na tentativa final (exhaustion), sem reenfileirar de novo"
        status: pass
    human_judgment: false
  - id: D3
    description: "limits_concurrency(to: 1, key: divulgacao.client.whatsapp_instance.id) serializa envios por instância WhatsApp -- chave nunca levanta NoMethodError, mesma cadeia do token SEG-03"
    requirement: "ENVIO-09"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#limits_concurrency configurado para 1 por instancia"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#concurrency_key resolve para o whatsapp_instance_id do grupo (regressao do fix da Task 1 do plano 29-01)"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#token nunca entra no argumento serializado, mesmo com limits_concurrency declarado"
        status: pass
    human_judgment: false
  - id: D4
    description: "Idempotência do claim atômico provada sob 4 condições adversariais explícitas: status terminal pré-setado, perform_now duplo, perform_later duplo + drain, e a query SQL isolada"
    requirement: "ENVIO-04"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#claim atomico: update_all condicional retorna 0 quando outro processo/tentativa ja tratou o item"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#perform_now duas vezes seguidas no mesmo grupo pendente so chama Evolution::Client uma unica vez"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#dois SendToGroupJob enfileirados para o MESMO grupo -- o segundo a rodar e sempre um no-op"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#um grupo ja falhou/incerto/enviado nunca e reivindicado de novo pelo claim"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-31
status: complete
---

# Phase 29 Plan 02: Taxonomia de erro completa + concorrência + fix do retry-morto-pelo-claim Summary

**`Whatsapp::SendToGroupJob` ganha a taxonomia `Evolution::Errors` completa (catch-all primeiro), `limits_concurrency` por instância, e um `rescue Evolution::Errors::Transient` que desfaz o claim ANTES de re-raise -- corrigindo um bug real descoberto durante a implementação (dirty-tracking sem reload tornava o revert um no-op silencioso), provado por um teste de 2 chamadas.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-31T06:xx:xx-03:00 (aprox.)
- **Completed:** 2026-08-31T06:02:33-03:00
- **Tasks:** 2
- **Files modified:** 2 (1 produção, 1 teste)

## Accomplishments

- `discard_on(StandardError)` catch-all declarado PRIMEIRO na classe (linha 48, antes de qualquer `retry_on`/`discard_on(Evolution::...)` das linhas 64-85) — mesma ordem mecânica do `Whatsapp::SyncGroupsJob`, verificada via `rescue_handlers.reverse_each.detect`.
- Taxonomia completa: `retry_on(Transient, wait: :polynomially_longer, attempts: 5)` com exhaustion → `falhou`/`transient`; `discard_on(Unknown)` → `incerto` (nunca `falhou`, nunca reenfileira — ENVIO-05); `discard_on(Permanent/NotConnected/ConfigurationError)` → `falhou` com `error_code` truncado; `discard_on(ActiveJob::DeserializationError)` sem efeito colateral.
- `limits_concurrency(to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance.id })` — ENVIO-09, mesma cadeia de resolução que o token SEG-03, `on_conflict` no default `:block` (nunca `:discard`).
- **Fix crítico do claim-vs-retry (T-29-05):** dentro de `perform`, `send_via_evolution` agora está envolvida em `begin/rescue Evolution::Errors::Transient; group.reload.update!(status: :pendente, sent_at: nil, updated_at: Time.current); raise; end`. Durante a implementação, um bug real foi descoberto e corrigido: sem o `.reload`, o `update!(status: :pendente)` é um **no-op silencioso** — o objeto `group` em memória nunca foi sincronizado com o `update_all` (bulk SQL) do claim anterior, então o dirty-tracking do ActiveRecord vê "status já é pendente" (valor pré-claim, nunca atualizado em memória) e pula a coluna no UPDATE gerado. Reproduzido isoladamente via `bin/rails runner`, corrigido, reproduzido de novo passando. Sem este fix, `retry_on(Transient)` reenfileiraria para sempre sem NUNCA reenviar de fato.
- `mark_falhou(job, message)` / `mark_incerto(job, err)` como métodos de classe, truncando `error_code` via `ERROR_CODE_MAX_LENGTH = 500` uniformemente e sempre chamando `finalize_divulgacao_if_done`.
- 16 testes novos (12 no Task 1, 4 no Task 2) cobrindo cada branch da taxonomia, a ordem do catch-all, o revert-then-raise sob 2 chamadas reais, a exhaustion, a config de concorrência, e — sob condição adversarial explícita (status terminal pré-setado, `perform_now` duplo, `perform_later` duplo com drain, query SQL isolada) — que o claim atômico do plano 29-01 garante Evolution chamada no máximo uma vez por `divulgacao_grupo`, independente de ordem ou contagem de execução.

## Task Commits

Each task was committed atomically:

1. **Task 1: Taxonomia de erro completa + limits_concurrency + fix do retry_on-morto-pelo-claim** - `6218955` (feat)
2. **Task 2: Provar idempotência sob execução concorrente/duplicada (ENVIO-04)** - `e033994` (test)

**Plan metadata:** (este commit — ver abaixo)

## Files Created/Modified

- `app/jobs/whatsapp/send_to_group_job.rb` — declarações de classe (`limits_concurrency`, `discard_on`/`retry_on` na ordem correta), `ERROR_CODE_MAX_LENGTH`, `mark_falhou`/`mark_incerto`, `begin/rescue Evolution::Errors::Transient` dentro de `perform`
- `test/jobs/whatsapp/send_to_group_job_test.rb` — 16 testes novos (23 no total, 0 falhas, 0 erros)

## Decisions Made

- **Bug real descoberto e corrigido (não estava explícito no `<behavior>` do plano, mas é consequência mecânica direta dele):** `group.update!(status: :pendente, ...)` sem `.reload` prévio é um no-op silencioso por causa de dirty-tracking obsoleto após o `update_all` do claim. Ver `key-decisions` no frontmatter para o detalhe completo.
- Task 2 commitado separadamente do Task 1, tocando SÓ o arquivo de teste — confirma o acceptance criteria "nenhum arquivo de produção tocado pelo Task 2".
- `concurrency_on_conflict` retorna o símbolo `:block` (API real do solid_queue 1.4.0), não a string `"block"` — teste ajustado para o valor real observado.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `group.update!(status: :pendente, ...)` no rescue de Transient era um no-op silencioso sem `.reload`**
- **Found during:** Task 1, ao rodar o teste "retry_on Transient desfaz o claim... a nova tentativa realmente tenta enviar de novo"
- **Issue:** `group` (o argumento do job) nunca foi recarregado depois do `update_all` (bulk SQL) do claim atômico no início de `perform`. O dirty-tracking do ActiveRecord em memória continuava achando que `status` já era `pendente` (valor anterior ao claim, nunca sincronizado), então `update!(status: :pendente)` não gerava nenhuma mudança real na coluna `status` no UPDATE SQL — `sent_at`/`updated_at` também corriam o mesmo risco. Confirmado isoladamente via `bin/rails runner` com um `puts` de debug temporário: o rescue era executado, mas a coluna `status` no banco permanecia `enviado`.
- **Fix:** `group.reload.update!(status: :pendente, sent_at: nil, updated_at: Time.current)` — o `.reload` força o objeto a refletir o valor real do banco (`enviado`, do claim), tornando a mudança para `pendente` uma mudança REAL que o dirty-tracking detecta e inclui no UPDATE.
- **Files modified:** `app/jobs/whatsapp/send_to_group_job.rb`
- **Verification:** o teste dedicado de 2 chamadas ("retry_on Transient desfaz o claim... a nova tentativa realmente tenta enviar de novo") passa: primeira `perform_now` → `status == "pendente"`; segunda `perform_now` (simulando o retry) → `status == "enviado"` com `evolution_message_id == "MSG2"`, provando que a segunda chamada REALMENTE reivindicou e reenviou.
- **Committed in:** `6218955` (Task 1 commit)

**2. [Rule 1 - Bug] Teste "discard_on StandardError (catch-all) ... finaliza a divulgação" falhava porque `@divulgacao` nunca entrava em `em_andamento`**
- **Found during:** Task 1, primeira rodada do `<verify>`
- **Issue:** o teste chamava `Whatsapp::SendToGroupJob.perform_now` diretamente (bypassando o `Divulgacoes::DispatchJob`, que é quem transiciona `agendada -> em_andamento` no fluxo real). `finalize_divulgacao_if_done` só atualiza para `concluida` quando `divulgacao.status_em_andamento?` é verdadeiro — como o setup padrão cria a Divulgação em `agendada`, o assert `"concluida"` falhava (`"agendada"` observado).
- **Fix:** `@divulgacao.update!(status: :em_andamento)` adicionado no início do teste, reproduzindo o estado real no momento em que o `DispatchJob` enfileira o `SendToGroupJob`.
- **Files modified:** `test/jobs/whatsapp/send_to_group_job_test.rb`
- **Verification:** teste passa; nenhuma mudança de comportamento de produção.
- **Committed in:** `6218955` (Task 1 commit)

**3. [Rule 1 - Bug] `assert_equal "block", Whatsapp::SendToGroupJob.concurrency_on_conflict` falhava -- valor real é o símbolo `:block`**
- **Found during:** Task 1, primeira rodada do `<verify>`
- **Issue:** `concurrency_on_conflict` (API do solid_queue 1.4.0) retorna o símbolo `:block` quando `on_conflict:` não é passado explicitamente (default do gem), não a string `"block"`.
- **Fix:** assertion ajustada para `assert_equal :block, ...`.
- **Files modified:** `test/jobs/whatsapp/send_to_group_job_test.rb`
- **Verification:** teste passa; `limits_concurrency to: 1, key: ...` no código de produção não mudou.
- **Committed in:** `6218955` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (1 bug de produção real -- claim-vs-retry sem reload, 2 correções de teste sem impacto em produção)
**Impact on plan:** O fix do dirty-tracking (#1) é essencial para a correção que este plano existe para garantir -- sem ele, o `<behavior>` descrito no PLAN.md (`group.update!(status: :pendente, ...)`) teria compilado e passado por leitura, mas seria funcionalmente idêntico ao bug que o plano descreve corrigir (T-29-05), só que de um jeito mais sutil (silencioso, sem exceção). Nenhum escopo além do que o plano já previa.

## Issues Encountered

Nenhum bloqueio não resolvido pelas Deviations acima. Ambiente do worktree (bundle/`RAILS_MASTER_KEY`) já estava documentado pelo plano 29-01 e não precisou de reconfiguração — só reforçado nas invocações de comando desta sessão (nenhum segredo novo, nenhum arquivo versionado). `bin/rails test` completo (suíte inteira) continua não rodando neste sandbox (banco de teste pertence a outro usuário do SO); a verificação canônica permanece o runner escopado do `<verify>` do plano, que passou (23 runs, 58 assertions, 0 falhas, 0 erros).

## User Setup Required

None - nenhuma configuração de serviço externo nova.

## Next Phase Readiness

- `Whatsapp::SendToGroupJob` está com a taxonomia de erro E a concorrência completas e testadas -- ENVIO-04, ENVIO-05, ENVIO-09 fechados com evidência (não só inspeção de código).
- O plano 29-03 (fila dedicada, escalonamento com múltiplos grupos) pode assumir que o corpo do job (claim, revalidação, taxonomia, concorrência) está estável -- não precisa reescrever nada deste plano, só adicionar configuração de fila e testes de escalonamento.
- Nenhum bloqueio conhecido para 29-03.

## Known Stubs

Nenhum stub -- toda a taxonomia de erro e a configuração de concorrência são funcionais ponta a ponta (transporte HTTP real stubado apenas nos testes, nunca no código de produção).

## Self-Check: PASSED

- `app/jobs/whatsapp/send_to_group_job.rb` — FOUND
- `test/jobs/whatsapp/send_to_group_job_test.rb` — FOUND
- `.planning/phases/29-motor-de-envio/29-02-SUMMARY.md` — FOUND
- Commit `6218955` (Task 1: feat) — FOUND in git log
- Commit `e033994` (Task 2: test) — FOUND in git log
- Full plan test scope: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/jobs/whatsapp/send_to_group_job_test.rb` — 23 runs, 58 assertions, 0 failures, 0 errors

---
*Phase: 29-motor-de-envio*
*Completed: 2026-08-31*
