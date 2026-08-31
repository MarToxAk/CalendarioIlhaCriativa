---
phase: 29-motor-de-envio
plan: 03
subsystem: jobs
tags: [activejob, solid_queue, whatsapp, disparo, escalonamento, cancelamento]

requires:
  - phase: 29-motor-de-envio
    provides: "29-01: Divulgacoes::DispatchJob + Whatsapp::SendToGroupJob (corpo completo do perform); 29-02: taxonomia de erro completa + limits_concurrency"
provides:
  - "config/queue.yml — worker dedicado whatsapp_sends (2 threads), adicionado ao worker \"*\" existente (INFRA-06)"
  - "Prova, sob cenário de N grupos, que DispatchJob escalona ofertas de espera corretamente e não bloqueia o worker (ENVIO-02, ENVIO-03)"
  - "Prova, sob cenário adversarial de timing, que o cancelamento é respeitado antes e depois do enfileiramento, e que um item já enviado sobrevive a um cancel posterior (DIVU-08)"
  - "Prova que divulgacoes.status sempre alcança concluida exatamente quando o último item sai de pendente, nunca antes, nunca travado (T-29-11)"
affects: [30-acompanhamento]

actuals:
  tokens: 2294
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "const_set/ensure para stubar constantes de classe em teste quando stub_const (gem) não está disponível — silence_warnings suprime o \"already initialized constant\" esperado, restauração garantida no ensure"
    - "build_divulgacao_with_groups(n) — helper de teste que gera remote_jid único por SecureRandom.hex para não colidir com o índice único whatsapp_instance_id+remote_jid ao criar múltiplos grupos na mesma instância dentro de um mesmo teste"

key-files:
  created: []
  modified:
    - config/queue.yml
    - test/jobs/divulgacoes/dispatch_job_test.rb
    - test/jobs/whatsapp/send_to_group_job_test.rb

key-decisions:
  - "Nenhum código de produção Ruby foi tocado neste plano — DispatchJob#perform e SendToGroupJob#perform já estavam completos desde os planos 29-01/29-02; este plano só adiciona config/queue.yml (fila dedicada) e testes que provam, sob N grupos e timing adversarial, que o comportamento já implementado é correto."
  - "`wait: 0.seconds` (offset do primeiro grupo) NÃO produz scheduled_at nulo — produz um scheduled_at igual a 'agora' (ActiveJob's `set` trata Duration truthy independente do valor numérico). O teste de escalonamento foi ajustado para `assert_in_delta` contra o horário de início do teste em vez de `assert_nil`, refletindo o comportamento real da API em vez do texto informal do PLAN.md."
  - "stub_const (Minitest) não está disponível neste projeto (só minitest 5.x puro, sem minitest-stub_const) — usado const_set/ensure com silence_warnings como substituto funcionalmente equivalente para sobrescrever Divulgacao::SEND_DELAY_MIN/MAX durante o teste de escalonamento, sem editar o ENV do processo de teste inteiro."

requirements-completed: [ENVIO-02, ENVIO-03, DIVU-08, INFRA-06]

coverage:
  - id: D1
    description: "config/queue.yml ganha um segundo worker dedicado à fila whatsapp_sends (2 threads), adicionado ao worker \"*\" existente sem removê-lo — sobreposição intencional documentada em RESEARCH Pattern 7"
    requirement: INFRA-06
    verification:
      - kind: other
        ref: "grep -n \"whatsapp_sends\" config/queue.yml (dentro do bloco default: &default) + bin/rails runner 'Rails.application.config_for(:queue)[:workers].map { |w| w[:queues] }' => [\"*\", \"whatsapp_sends\"]"
        status: pass
    human_judgment: false
  - id: D2
    description: "DispatchJob enfileira todos os grupos pendentes de uma Divulgação com N grupos, offsets estritamente crescentes dentro da faixa ENV-configurada, primeiro grupo com offset ~0"
    requirement: "ENVIO-02"
    verification:
      - kind: unit
        ref: "test/jobs/divulgacoes/dispatch_job_test.rb#perform enfileira todos os grupos pendentes com offsets crescentes dentro da faixa ENV, primeiro grupo com offset 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "DispatchJob#perform não bloqueia o worker esperando entre grupos (enfileirar 4 registros é operação de milissegundos, nunca segundos) e divulgacoes.status vai para em_andamento imediatamente, antes de qualquer SendToGroupJob rodar"
    requirement: "ENVIO-03"
    verification:
      - kind: unit
        ref: "test/jobs/divulgacoes/dispatch_job_test.rb#perform enfileira N jobs rapidamente sem sleep -- dispatch nao ocupa o worker esperando entre grupos"
        status: pass
      - kind: unit
        ref: "test/jobs/divulgacoes/dispatch_job_test.rb#divulgacoes.status vai para em_andamento assim que o perform roda, ANTES de qualquer SendToGroupJob ter sido executado"
        status: pass
      - kind: other
        ref: "grep -n sleep app/jobs/divulgacoes/dispatch_job.rb (regressão explícita, deve retornar vazio)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Cancelamento respeitado em ambos os momentos possíveis: antes do DispatchJob rodar (via perform_now direto no SendToGroupJob) e depois de já enfileirado (zero chamadas Evolution::Client, todos os itens continuam pendente)"
    requirement: DIVU-08
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#cancelamento ANTES do DispatchJob rodar: perform_now direto numa divulgacao cancelada e no-op, item continua pendente, Evolution nunca chamado"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#cancelamento DEPOIS do DispatchJob ja ter enfileirado -- o SendToGroupJob cujo offset ainda nao decorreu vira no-op quando roda"
        status: pass
    human_judgment: false
  - id: D5
    description: "Cancelamento no meio de um lote nunca desfaz um envio já concluído — o grupo já enviado antes do cancel permanece enviado; os que ainda não rodaram viram no-op"
    requirement: DIVU-08
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#cancelamento no meio de um lote -- o grupo JA enviado antes do cancel permanece enviado; os que ainda nao rodaram viram no-op"
        status: pass
    human_judgment: false
  - id: D6
    description: "divulgacoes.status sempre alcança concluida exatamente quando o último divulgacao_grupo sai de pendente (por sucesso ou falha), nunca antes com pendentes restantes"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#fechamento de divulgacoes.status: o ULTIMO grupo pendente saindo (por qualquer caminho) marca a divulgacao concluida"
        status: pass
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb#uma divulgacao com pendentes restantes NUNCA vira concluida antes da hora"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-31
status: complete
---

# Phase 29 Plan 03: Fila dedicada + escalonamento e cancelamento sob N grupos Summary

**`config/queue.yml` ganha o worker dedicado `whatsapp_sends` (INFRA-06); `DispatchJob` e `SendToGroupJob` — já completos desde 29-01/29-02 — são provados sob cenário de múltiplos grupos: offsets estritamente crescentes, dispatch não-bloqueante, cancelamento respeitado antes e durante o disparo, e `divulgacoes.status` sempre fecha em `concluida` exatamente quando o último item sai de `pendente`.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-31T06:00:00-03:00 (aprox.)
- **Completed:** 2026-08-31T06:25:00-03:00 (aprox.)
- **Tasks:** 2
- **Files modified:** 3 (1 config, 2 teste)

## Accomplishments

- `config/queue.yml` — segundo worker `{ queues: whatsapp_sends, threads: 2, polling_interval: 0.1 }` acrescentado dentro do bloco único `default: &default`, propagando via YAML anchor aos 3 ambientes (`development`/`test`/`production`) sem tocar no worker `"*"` existente — sobreposição intencional, o mesmo padrão documentado pelo README da própria gem `solid_queue` (RESEARCH Pattern 7, confirmado contra `SolidQueue::QueueSelector`: esta versão não tem sintaxe de exclusão).
- `test/jobs/divulgacoes/dispatch_job_test.rb` — 4 testes novos com um setup dedicado de 4 grupos pendentes: offsets estritamente crescentes dentro da faixa `ENV`-configurada (primeiro grupo com offset ~0, cada subsequente estritamente maior), dispatch não-bloqueante (medido por `Process.clock_gettime`, < 1s para enfileirar 4 registros), transição `em_andamento` imediata (antes de qualquer `SendToGroupJob` rodar), e regressão explícita do grep `sleep` em `dispatch_job.rb`.
- `test/jobs/whatsapp/send_to_group_job_test.rb` — 5 testes novos provando DIVU-08 sob os dois momentos possíveis de cancelamento (antes do `DispatchJob` rodar; depois de já enfileirado, com zero chamadas ao `Evolution::Client`), a não-destrutividade do cancelamento (grupo já enviado sobrevive a um cancel posterior), e o fechamento de `divulgacoes.status` (último grupo pendente saindo — por sucesso OU falha — marca `concluida`; uma divulgação com pendentes restantes nunca fecha antes da hora).
- Nenhum código de produção Ruby alterado — `Divulgacoes::DispatchJob#perform` e `Whatsapp::SendToGroupJob#perform` já estavam com o corpo completo desde os planos 29-01/29-02; este plano só adiciona configuração de fila e testes que provam, sob N grupos e timing adversarial, que o comportamento já implementado é correto.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fila dedicada (INFRA-06) + escalonamento e status-transition sob N grupos (ENVIO-02, ENVIO-03)** - `6bf8317` (feat)
2. **Task 2: Cancelamento respeitado mid-dispatch + fechamento de divulgacoes.status (DIVU-08)** - `709d482` (test)

**Plan metadata:** (este commit — ver abaixo)

## Files Created/Modified

- `config/queue.yml` — segundo worker `whatsapp_sends` (2 threads), adicionado ao worker `"*"` existente dentro do bloco `default: &default`
- `test/jobs/divulgacoes/dispatch_job_test.rb` — 4 testes novos (setup com 4 grupos), 7 testes no total no arquivo
- `test/jobs/whatsapp/send_to_group_job_test.rb` — 5 testes novos (setup com 2-3 grupos por teste), 28 testes no total no arquivo

## Decisions Made

- Nenhuma mudança de código de produção — DIVU-08/ENVIO-02/ENVIO-03/INFRA-06 são fechados inteiramente por configuração (`queue.yml`) e testes que provam comportamento já implementado nos planos anteriores.
- Ajuste na expectativa do teste de escalonamento: `wait: 0.seconds` produz `scheduled_at` igual a "agora" (não `nil`) — o `set` do ActiveJob trata qualquer `Duration` como truthy independente do valor numérico. O teste usa `assert_in_delta` contra o horário de início do teste, com folga de 2s, em vez de `assert_nil` (que teria falhado incorretamente).
- `stub_const` (usado em outros ecossistemas de teste) não está disponível neste projeto (minitest 5.x puro). Substituído por `const_set`/`ensure` com `silence_warnings` para sobrescrever `Divulgacao::SEND_DELAY_MIN`/`MAX` durante o teste, com restauração garantida — comportamento funcionalmente idêntico ao pedido no PLAN.md ("não editar o ENV do processo de teste inteiro").

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `stub_const` não existe neste projeto — teste de escalonamento reescrito com `const_set`/`ensure`**
- **Found during:** Task 1, ao escrever o teste de offsets crescentes
- **Issue:** O `<action>` do PLAN.md sugeria `stub_const` como uma opção (`stub_const/atribuição direta`), mas `stub_const` é um método de gem externa (`minitest-stub_const`) não instalada neste projeto (só `minitest ~> 5.25` puro, confirmado em `Gemfile`/`Gemfile.lock`) — teria levantado `NoMethodError`.
- **Fix:** usado o caminho alternativo já previsto no próprio PLAN.md ("atribuição direta... dentro do teste") via `Divulgacao.const_set(:SEND_DELAY_MIN, ...)`/`const_set(:SEND_DELAY_MAX, ...)`, envolto em `silence_warnings` (suprime o warning esperado "already initialized constant") e restaurado no `ensure` do helper `with_send_delay_range`.
- **Files modified:** `test/jobs/divulgacoes/dispatch_job_test.rb`
- **Verification:** teste passa; a faixa ENV real (`Divulgacao::SEND_DELAY_MIN/MAX`) é restaurada ao valor original após o bloco, confirmado por rodar a suíte completa do arquivo em seguida sem efeitos colaterais entre testes.
- **Committed in:** `6bf8317` (Task 1)

**2. [Rule 1 - Bug] Assertiva `assert_nil` no primeiro `scheduled_at` estava incorreta — `wait: 0.seconds` não produz `nil`**
- **Found during:** Task 1, primeira rodada do teste de escalonamento
- **Issue:** `Divulgacoes::DispatchJob#perform` chama `.set(wait: offset.seconds)` mesmo quando `offset == 0`; `ActiveJob::Core#set` faz `self.scheduled_at = options[:wait].seconds.from_now if options[:wait]` — como `0.seconds` é um objeto `ActiveSupport::Duration` (truthy independente do valor numérico), `scheduled_at` é sempre setado para um horário real (~"agora"), nunca `nil`. Verificado isoladamente via `bin/rails runner`.
- **Fix:** assertiva trocada de `assert_nil` para `assert_in_delta(started_at.to_f, scheduled_times.first.to_f, 2.0, ...)`, comparando contra o horário de início do teste com folga de 2 segundos.
- **Files modified:** `test/jobs/divulgacoes/dispatch_job_test.rb`
- **Verification:** teste passa de forma estável (rodado múltiplas vezes).
- **Committed in:** `6bf8317` (Task 1)

---

**Total deviations:** 2 auto-fixed (ambos correções de teste sem impacto em código de produção — a API real do ActiveJob/minitest diverge de detalhes informais do `<action>` do PLAN.md, mas o comportamento provado é exatamente o pedido)
**Impact on plan:** Nenhuma mudança na lógica de negócio de `DispatchJob`/`SendToGroupJob`. Zero scope creep — ambos os ajustes são correções de expectativa de teste para refletir a API real (ActiveJob `set`, ausência de `stub_const`), não mudanças de comportamento.

## Issues Encountered

Nenhum bloqueio não resolvido pelas Deviations acima. `.bundle/config` (gitignored) e `RAILS_MASTER_KEY` precisaram ser fornecidos manualmente neste worktree (mesmo comportamento documentado nos planos 29-01/29-02 — não é um segredo novo, apenas não propagado automaticamente para o worktree). `bin/rails test` completo (suíte inteira) continua não rodando neste sandbox (banco de teste pertence a outro usuário do SO, conforme memória do projeto); a verificação canônica permanece o runner escopado do `<verify>` do plano, que passou (35 runs, 80 assertions, 0 falhas, 0 erros, cobrindo ambos os arquivos de teste do plano).

## User Setup Required

None - nenhuma configuração de serviço externo nova. `config/queue.yml` é configuração de processo, não requer nenhuma variável de ambiente nova; `docker-compose.yml` não precisou de mudança (o serviço `jobs` já sobe todo processo definido em `config/queue.yml`, confirmado em RESEARCH).

## Next Phase Readiness

- Fase 29 (Motor de Envio) está completa: `DispatchJob`/`SendToGroupJob` provados ponta a ponta (29-01), com taxonomia de erro completa e concorrência por instância (29-02), e agora provados sob escalonamento de múltiplos grupos, cancelamento adversarial, e fechamento de status (29-03).
- `ENVIO-01` a `ENVIO-10`, `DIVU-08`, `SEG-03`, `INFRA-06` fechados com evidência de teste, não só inspeção de código.
- Fase 30 (Acompanhamento) pode assumir que o motor de envio é estável: progresso ao vivo na tela (ACOMP-01), reenvio manual por grupo (ACOMP-02), histórico consolidado por cliente (ACOMP-03), e retenção de `failed_executions` (INFRA-07) são os itens explicitamente deferidos para lá.
- Nenhum bloqueio conhecido para a fase 30.

## Known Stubs

Nenhum stub — todo o comportamento provado neste plano é o código de produção já funcional dos planos 29-01/29-02 (transporte HTTP real stubado apenas nos testes, nunca no código de produção).

## Self-Check: PASSED

- `config/queue.yml` — FOUND, contém `whatsapp_sends` dentro do bloco `default: &default`
- `test/jobs/divulgacoes/dispatch_job_test.rb` — FOUND, 7 testes (3 originais 29-01 + 4 novos)
- `test/jobs/whatsapp/send_to_group_job_test.rb` — FOUND, 28 testes (23 originais 29-01/29-02 + 5 novos)
- `.planning/phases/29-motor-de-envio/29-03-SUMMARY.md` — FOUND
- Commit `6bf8317` (Task 1: feat) — FOUND in git log
- Commit `709d482` (Task 2: test) — FOUND in git log
- Commit `67b56ff` (docs: SUMMARY) — FOUND in git log
- Full plan test scope: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/jobs/divulgacoes/dispatch_job_test.rb test/jobs/whatsapp/send_to_group_job_test.rb` — 35 runs, 80 assertions, 0 failures, 0 errors
- `grep -n sleep app/jobs/divulgacoes/dispatch_job.rb app/jobs/whatsapp/send_to_group_job.rb` — empty (no matches, regression guard holds)

---
*Phase: 29-motor-de-envio*
*Completed: 2026-08-31*
