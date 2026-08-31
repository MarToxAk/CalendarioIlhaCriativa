# Phase 29: Motor de Envio - Research

**Researched:** 2026-08-31
**Domain:** ActiveJob scheduling + solid_queue 1.4.0 concurrency controls + Evolution API write-path (sendText/sendMedia) + exactly-once delivery under worker failure
**Confidence:** HIGH (solid_queue mechanics, Rails/ActiveStorage/ActiveRecord mechanics — all read directly from the installed gem source this session) / MEDIUM (Evolution sendMedia error format — free text, contract still PENDENT per `evolution-contract.md`, robust-by-design not fully verifiable without a real UAT send)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Arquitetura de disparo**
- 1 job por grupo (`Whatsapp::SendToGroupJob`), não 1 job monolítico por Divulgação — ENVIO-03 exige que o worker não fique ocupado esperando entre grupos.
- Mecanismo de espaçamento: `perform_later(wait: cumulative_delay)` — cada `SendToGroupJob` agendado com um offset crescente (soma de delays aleatórios vindos de `Divulgacao::SEND_DELAY_MIN`/`SEND_DELAY_MAX`, já estabelecidos na fase 28), calculado no momento do disparo.
- Trigger: um `Divulgacoes::DispatchJob` agendado para `scheduled_for` que lê os `divulgacao_grupos` pendentes daquela Divulgação e enfileira os `SendToGroupJob` individuais com os offsets calculados.
- Concorrência por instância (ENVIO-09): `limits_concurrency(to: 1, key: ->(group) { group.divulgacao.client.whatsapp_instance_id })` no `SendToGroupJob` — API confirmada disponível no solid_queue 1.4.0 instalado (`lib/active_job/concurrency_controls.rb`). Nunca dois envios da mesma instância em paralelo.

**Idempotência e taxonomia de erro (mirror do padrão `Whatsapp::SyncGroupsJob` da fase 27)**
- Claim atômico antes do envio: `update_all(status: :enviado)` condicionado em `where(status: :pendente)` — se retornar 0 linhas, outro worker/retry já processou; o job vira no-op. Mesma defesa contra double-send que a fase 27 provou com `upsert_all`.
- `Net::ReadTimeout` → resultado `incerto`, `discard_on` (**nunca** retry automático) — herda a taxonomia já registrada em `.planning/notes/evolution-contract.md`.
- Erro de rede antes do envio (`Net::OpenTimeout`/`ECONNREFUSED`/`SocketError`, taxonomia `Transient`) → `retry_on` com backoff.
- Erro 4xx do `sendMedia` (texto livre) → `discard_on` → `falhou`, grava o texto bruto **truncado** em `divulgacao_grupos.error_code`. Formato exato PENDENTE de UAT real.
- `Divulgacao#cancelar!` (fase 28) e o débito pré-existente de `application_job.rb` (`retry_on`/`discard_on` comentados) ficam explicitamente fechados por esta taxonomia.

**Revalidação no momento do envio + cancelamento**
- `SendToGroupJob#perform` recarrega `arte.reload` e checa `arte.approved?` **antes** de qualquer chamada Evolution (ENVIO-06) — se não aprovada, `falhou`, **nunca** `enviado`.
- Mesma lógica para conexão (ENVIO-07): `instance.connected?` checado dentro do job, imediatamente antes do `Evolution::Client` call.
- Cancelamento em andamento (DIVU-08): `SendToGroupJob#perform` recarrega `divulgacao.reload` e checa se ainda está `agendada`/`em_andamento` antes de enviar — se `cancelada`, no-op silencioso, **o item permanece `pendente`**. Checagem no `perform`, não via `Job.discard`.
- Transições de `divulgacoes.status`: `Divulgacoes::DispatchJob` seta `em_andamento` no início; o último `SendToGroupJob` do lote (ou um job de fechamento) seta `concluida` quando todos os itens saem de `pendente`.

**Mídia, texto e o teto de tamanho**
- URL de mídia (ENVIO-08) gerada **dentro** do `SendToGroupJob#perform`, não pré-gerada no `DispatchJob`.
- Texto vs mídia (ENVIO-10): `arte.caption_only?` → `sendText` com `text: arte.caption`; senão → `sendMedia` com `media: <url>`, `mediatype: arte.media_type` (`image`/`video`), `caption: arte.caption.presence`. `number` = JID do grupo (`...@g.us`).
- Token da instância (SEG-03): `Evolution::Client` chamado com `api_key: divulgacao.client.whatsapp_instance.token` — sempre resolvido a partir do `client` da Divulgação.
- Teto de tamanho: reusa `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES` (16MB heurística). **Não re-valida no job.**

### Claude's Discretion
- Nome exato dos métodos/classes além dos já nomeados (`Divulgacoes::DispatchJob`, `Whatsapp::SendToGroupJob`) — seguir o namespace `Whatsapp::` estabelecido nas fases 26/27.
- Se o `DispatchJob` é agendado via `perform_later(wait_until: divulgacao.scheduled_for)` no `#create` do controller (fase 28) ou via um scan periódico — pesquisado abaixo (resolvido: `wait_until:` no `#create`).
- Comportamento exato de `ProcessPrunedError` — pesquisado abaixo contra a gem 1.4.0 instalada.
- Estrutura exata da fila dedicada (INFRA-06): nome da fila, `queue_as`, e ajuste de `config/queue.yml` — resolvido abaixo.
- Retenção de `failed_executions` (INFRA-07) é explicitamente fase 30 — não implementar aqui, só não piorar o problema.

### Deferred Ideas (OUT OF SCOPE)
- Progresso ao vivo na tela (ACOMP-01), reenvio manual por grupo (ACOMP-02), histórico consolidado por cliente (ACOMP-03) — fase 30.
- Retenção de `failed_executions` do solid_queue (INFRA-07) — fase 30.
- Teste negativo cross-client de ponta a ponta usando o motor real (SEG-04) — fase 30.
- Camada anti-ban além do delay aleatório (warm-up, volume seguro) — não fecha nunca; postura é conservadorismo via ENV.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ENVIO-01 | Envio na hora agendada, intervalo aleatório entre grupos | Pattern 1 (DispatchJob + `wait_until:`), Pattern 2 (staggered `wait:` offsets), `Divulgacao::SEND_DELAY_MIN/MAX` já existente |
| ENVIO-02 | Faixa min/max vem de ENV, não UI/banco | Já implementado na fase 28 (`Divulgacao::SEND_DELAY_MIN`/`MAX`) — este job só consome |
| ENVIO-03 | Disparo longo não ocupa capacidade de background esperando | Pattern 1/2 — 1 job por grupo com `wait:`, nunca `sleep` |
| ENVIO-04 | Nunca duplo envio (retry, worker morto, deploy) | Pitfall 1 (claim atômico + ordem claim-antes-do-HTTP), source-verified solid_queue failure semantics (`ProcessPrunedError`, `ClaimedExecution#failed_with`) |
| ENVIO-05 | Timeout de leitura = incerto, nunca retry automático | Taxonomia herdada de `evolution-contract.md` + Pattern 4 (`discard_on Evolution::Errors::Unknown`) |
| ENVIO-06 | Aprovação revalidada no envio | Pattern 5 (`arte.reload` + `approved?` check antes do HTTP) |
| ENVIO-07 | Conexão verificada imediatamente antes de cada envio | Pattern 5 (`instance.connected?` check) |
| ENVIO-08 | URL de mídia gerada no momento do envio | Pitfall 2 resolvido: `ActiveStorage::Blob#url` não depende de contexto de request (source-verified) |
| ENVIO-09 | Envios de uma instância serializados | Pattern 3 (`limits_concurrency`, API source-verified) |
| ENVIO-10 | Caption-only via texto, resto via mídia com legenda | Pattern 6 (`Evolution::Client#send_text`/`#send_media`) |
| DIVU-08 | Cancelamento respeitado pelos envios não realizados | Pattern 5 (`divulgacao.reload` + `status_cancelada?` check) |
| SEG-03 | Token da instância do cliente correto | Pattern 6 (`api_key:` sempre resolvido via `divulgacao.client.whatsapp_instance.token`) |
| INFRA-06 | Fila dedicada, sem atrasar ActionCable | Pattern 7 (`config/queue.yml` segundo worker, README-documented pattern) |
</phase_requirements>

## Summary

Esta fase tem duas incógnitas técnicas reais, ambas fechadas por leitura direta do código-fonte instalado nesta sessão (não da documentação/README, e não de conhecimento de treinamento):

1. **solid_queue 1.4.0 concorrência.** `limits_concurrency(key:, to: 1, group:, duration:, on_conflict: :block)` é a assinatura exata (`vendor/bundle/.../solid_queue-1.4.0/lib/active_job/concurrency_controls.rb`). O `key:` proc é `instance_exec`'d com os argumentos do job — `->(group) { ... }` funciona exatamente como a CONTEXT.md já assumiu. O default `on_conflict: :block` (não `:discard`) é o comportamento correto para ENVIO-09: um job que não consegue o slot fica em `solid_queue_blocked_executions`, não é descartado — ele roda depois, quando o slot libera. `ProcessPrunedError` **existe** e seu efeito real é: quando um worker morre (heartbeat expira), a manutenção do supervisor marca TODAS as `claimed_executions` daquele processo como `failed_with(ProcessPrunedError)` — grava em `solid_queue_failed_executions` e **NÃO reenfileira automaticamente**. Isso significa que o motor de envio **não pode confiar em nenhum mecanismo de auto-retry do solid_queue para recuperar um job morto no meio da execução** — a única defesa real contra double-send é o claim atômico da aplicação, e ele precisa acontecer **antes** de qualquer I/O de rede (ver Pitfall 1 para a análise da janela de risco residual que isso ainda deixa).

2. **Evolution sendMedia — formato de erro.** Confirmado (herdado de `evolution-contract.md`, fonte primária): o Evolution 2.3.7 faz `throw new BadRequestException(error.toString())` para erros de `sendMedia` — texto livre, não um código estruturado. O client já tem o parser genérico (`Evolution::Client#raise_for_status!`) que normaliza `response.message` (string ou array) e mapeia por status HTTP para `Evolution::Errors::{Permanent,Transient,Unknown}` — isso já é robusto a texto livre porque a decisão de retry/discard é feita pelo **status HTTP e pela classe da exceção**, nunca por parsing do conteúdo da mensagem. O job só precisa truncar o texto antes de gravar em `error_code`.

**Primary recommendation:** siga exatamente as decisões já travadas em CONTEXT.md — elas batem com o comportamento real da gem instalada, verificado linha a linha nesta sessão. O único ponto que precisa de atenção extra do planner é a ordem exata `claim (update_all → :enviado) → HTTP call` dentro do mesmo `perform`, porque essa é a única defesa de fato contra um envio duplicado quando o processo morre depois do claim mas antes (ou durante) a chamada HTTP — o solid_queue não vai reexecutar esse job automaticamente, mas também não garante que o `update_all` e o HTTP call sejam atômicos entre si (não há transação distribuída possível com uma API HTTP externa). Ver Pitfall 1.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Agendamento do disparo (hora + espaçamento) | API/Backend (ActiveJob/solid_queue) | — | `wait_until`/`wait:` são mecanismos de enfileiramento, resolvidos inteiramente no backend, sem UI envolvida |
| Claim atômico / idempotência | Database / Storage | API/Backend | O `update_all` condicional é a fonte de verdade; o job (backend) só interpreta o count retornado |
| Serialização por instância WhatsApp | API/Backend (solid_queue concurrency) | Database / Storage | `limits_concurrency` grava estado em `solid_queue_semaphores` (DB), mas a decisão de bloquear/prosseguir é do worker |
| Revalidação de aprovação/conexão | API/Backend | Database / Storage | `arte.reload`/`instance.reload` lê o estado mais recente do DB imediatamente antes do I/O externo |
| Geração de URL presignada | API/Backend (ActiveStorage) | CDN / Static (S3/MinIO) | `Blob#url` computa a assinatura no backend; o download real acontece no MinIO, fora do Rails |
| Chamada HTTP ao Evolution (sendText/sendMedia) | API/Backend | External Service (Evolution) | `Evolution::Client` é a única costura de saída; Evolution é responsabilidade externa |
| Fila dedicada / isolamento de capacidade | API/Backend (solid_queue worker config) | — | Configuração de processo (`config/queue.yml`), não código de domínio |

## Standard Stack

Nenhuma gem nova. Todos os componentes já estão instalados e usados em fases anteriores.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| solid_queue | 1.4.0 (installed, confirmed `Gemfile.lock`) | Scheduling, concorrência, retry/discard | Já em uso desde fase 25/27; `ActiveJob::ConcurrencyControls` é a única forma nativa de serializar por chave neste stack |
| faraday | (já em uso via `Evolution::Client`) | Transporte HTTP para Evolution | Já estabelecido nas fases 25/26/27 — `send_text`/`send_media` estendem o mesmo client |
| activestorage | 8.1.3 (installed, `Gemfile.lock`) | URL presignada de mídia | Já em uso desde fase 25 (S3/MinIO) |
| activerecord | 8.1.3 (installed) | `update_all` para claim atômico | Mesmo padrão de `update_all` já usado em `Whatsapp::GroupSynchronizer` (fase 27) |

### Supporting
Nenhuma. Todos os blocos de construção (client HTTP, taxonomia de erro, ActiveJob) já existem no repo.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `limits_concurrency` (solid_queue nativo) | Lock de aplicação via `Rails.cache`/advisory lock Postgres | Descartado — `limits_concurrency` já é a ferramenta nativa da gem instalada, testada, com semântica de bloqueio (não descarte) documentada no código-fonte; reimplementar seria hand-rolling do que a gem já resolve |
| `update_all` condicional para claim | Optimistic locking (`lock_version`) | Descartado pelo próprio CONTEXT.md — `update_all(status: :enviado).where(status: :pendente)` já é o padrão espelhado de `Whatsapp::GroupSynchronizer`; introduzir `lock_version` seria uma segunda forma de fazer a mesma coisa no mesmo repo |

**Installation:** Nenhuma — zero gems novas.

## Package Legitimacy Audit

**N/A — nenhum pacote novo é instalado nesta fase.** `solid_queue`, `faraday`, `activestorage`, `activerecord` já estão no `Gemfile.lock` e foram usados/verificados em fases anteriores (25, 26, 27). Nenhuma linha nova em `Gemfile`.

## Architecture Patterns

### System Architecture Diagram

```
[Admin cria Divulgacao]  (fase 28, já existe)
        |
        v
  Divulgacao#create bem-sucedido
        |
        v (NOVO nesta fase)
  Divulgacoes::DispatchJob.set(wait_until: divulgacao.scheduled_for).perform_later(divulgacao)
        |
        | (solid_queue: ready se scheduled_at <= agora, senão scheduled_executions
        |  até o dispatcher mover para ready — Schedulable#due?)
        v
  [DispatchJob#perform roda na hora agendada]
        |
        |-- divulgacao.reload; guarda status_cancelada? -> no-op se já cancelada
        |-- seta divulgacao.status = :em_andamento
        |-- calcula offset acumulado (SEND_DELAY_MIN..SEND_DELAY_MAX) por grupo pendente
        |-- para cada divulgacao_grupo pendente:
        |     Whatsapp::SendToGroupJob.set(wait: offset).perform_later(divulgacao_grupo)
        v
  [SendToGroupJob#perform roda no offset, serializado por instância via limits_concurrency]
        |
        |-- divulgacao.reload -> se cancelada: no-op, item continua pendente
        |-- claim atômico: DivulgacaoGrupo.where(id:, status: :pendente)
        |                    .update_all(status: :enviado, updated_at: Time.current)
        |     -> 0 linhas afetadas => outro worker já tratou, RETURN (no-op)
        |-- arte.reload; se !approved? -> reverte para :falhou (motivo: arte não aprovada)
        |-- instance.reload; se !connected? -> reverte para :falhou (motivo: instância desconectada)
        |-- gera media_file.url(expires_in: curto) SE não for caption_only
        |-- Evolution::Client.send_text OU .send_media (api_key: instance.token)
        |     -- sucesso: grava evolution_message_id, sent_at (já setado no claim)
        |     -- Net::ReadTimeout / Evolution::Errors::Unknown -> discard_on -> :incerto
        |     -- Evolution::Errors::Transient -> retry_on (nada foi enviado ainda)
        |     -- Evolution::Errors::Permanent -> discard_on -> :falhou, error_code truncado
        |-- checa se restam divulgacao_grupos pendentes na Divulgacao
        |     -> se não: divulgacao.status = :concluida (guardado por status_em_andamento?)
        v
  [Evolution API] -> grupo do WhatsApp
```

### Recommended Project Structure
```
app/jobs/
├── divulgacoes/
│   └── dispatch_job.rb        # Divulgacoes::DispatchJob — 1 por Divulgação, agendado em #create
└── whatsapp/
    ├── sync_groups_job.rb     # já existe (fase 27)
    └── send_to_group_job.rb   # Whatsapp::SendToGroupJob — 1 por divulgacao_grupo
app/services/evolution/
└── client.rb                  # + send_text, + send_media (estende, não substitui)
config/
├── queue.yml                  # + segundo worker dedicado a whatsapp_sends
```

### Pattern 1: DispatchJob agendado com `wait_until:` — não scan periódico

**O que a gem faz com um `scheduled_at` no passado:** `SolidQueue::Job::Schedulable#due?` —

```ruby
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/job/schedulable.rb:29-31
def due?
  scheduled_at.nil? || scheduled_at <= Time.current
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/job/schedulable.rb:29-31]` — `due?` trata `scheduled_at` no passado como imediatamente executável (`<=`, não `<`), e `Job#prepare_for_execution` (`executable.rb:58-62`) chama `dispatch` (via `ready_execution`) quando `due?` é true, ou `schedule` (via `scheduled_execution`) quando não. Isso resolve a pergunta aberta do CONTEXT.md: **não existe gotcha** de `wait_until:` no passado — o job vai direto para a fila `ready`, sem passar pelo scheduler de scan periódico. `Divulgacao` já valida `scheduled_for_no_futuro` em `on: :create` (`app/models/divulgacao.rb`), então na prática o `DispatchJob` é sempre enfileirado com um `scheduled_at` futuro — mas mesmo que não fosse, o comportamento é seguro.

**Padrão recomendado — enfileirar no `#create` do controller, não via `config/recurring.yml`:**

```ruby
# app/controllers/admin/divulgacoes_controller.rb#create, após @divulgacao.save
if @divulgacao.save
  Divulgacoes::DispatchJob.set(wait_until: @divulgacao.scheduled_for).perform_later(@divulgacao)
  redirect_to ...
end
```

`config/recurring.yml` é para tarefas **recorrentes** (cron-like, ex.: `clear_solid_queue_finished_jobs` já configurado em produção — `[CITED: config/recurring.yml]`). Uma Divulgação é um evento único com um timestamp próprio; `set(wait_until:)` é o idioma correto do ActiveJob para "rode isto uma vez, nesta hora exata" — não há API dedicada diferente no solid_queue 1.4.0 para esse caso (confirmado por leitura de `SolidQueue::Job.enqueue(active_job, scheduled_at:)`, que é exatamente o que `ActiveJob::Enqueuing` popula a partir de `set(wait_until:)`/`set(wait:)`).

### Pattern 2: Espaçamento entre grupos via offset acumulado, não `sleep`

```ruby
# app/jobs/divulgacoes/dispatch_job.rb
class Divulgacoes::DispatchJob < ApplicationJob
  queue_as :whatsapp_sends

  def perform(divulgacao)
    divulgacao.reload
    return if divulgacao.status_cancelada?

    divulgacao.update!(status: :em_andamento) if divulgacao.status_agendada?

    offset = 0
    divulgacao.divulgacao_grupos.pendente.find_each do |group|
      Whatsapp::SendToGroupJob.set(wait: offset.seconds).perform_later(group)
      offset += rand(Divulgacao::SEND_DELAY_MIN..Divulgacao::SEND_DELAY_MAX)
    end
  end
end
```

**Por que isso satisfaz ENVIO-03:** `wait:` é resolvido pelo solid_queue via `scheduled_executions` — o worker thread que executou `DispatchJob#perform` **não fica bloqueado** esperando; ele termina o `perform` imediatamente após enfileirar todos os `SendToGroupJob` (rápido, é só N inserts). O espaçamento real acontece porque cada `SendToGroupJob` individual só fica `due?` no seu offset — o dispatcher do solid_queue (processo separado, `polling_interval: 1` em `config/queue.yml`) move cada um para `ready` na hora certa. Nenhuma thread de worker fica "esperando" — ela processa outros jobs entre um envio e outro.

### Pattern 3: `limits_concurrency` — API exata + comportamento de conflito

```ruby
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb:20-26
def limits_concurrency(key:, to: 1, group: DEFAULT_CONCURRENCY_GROUP, duration: SolidQueue.default_concurrency_control_period, on_conflict: :block)
  self.concurrency_key = key
  self.concurrency_limit = to
  self.concurrency_group = group
  self.concurrency_duration = duration
  self.concurrency_on_conflict = on_conflict.presence_in(CONCURRENCY_ON_CONFLICT_BEHAVIOUR) || :block
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb:20-26]`

O `key:` aceita `String`, `Symbol` ou `Proc`:

```ruby
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb:44-51
def compute_concurrency_parameter(option)
  case option
  when String, Symbol
    option.to_s
  when Proc
    instance_exec(*arguments, &option)
  end
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb:44-51]` — o Proc é `instance_exec`'d com `*arguments` (os argumentos passados a `perform_later`, no momento do enfileiramento, quando o objeto Ruby já está carregado — não uma reidratação via GlobalID). O uso `key: ->(group) { group.divulgacao.client.whatsapp_instance_id }` do CONTEXT.md é exatamente compatível com `perform(group)`/`perform_later(group)`.

**`on_conflict:` — o default é `:block`, não `:discard`:**

```ruby
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/job/concurrency_controls.rb:49-55
def handle_concurrency_conflict
  if concurrency_on_conflict.discard?
    destroy
  else
    block
  end
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/job/concurrency_controls.rb:49-55]` — CONTEXT.md não especifica `on_conflict:`, então o default `:block` se aplica: um `SendToGroupJob` que não consegue o slot da instância vai para `solid_queue_blocked_executions` (não é descartado, não perde o envio) e é liberado automaticamente quando o job que segura o slot termina (`unblock_next_blocked_job`, chamado tanto em `ClaimedExecution#failed_with` quanto em `#finished`/destroy normal). **Isto é o comportamento correto para ENVIO-09** — um grupo bloqueado por concorrência ainda vai ser enviado, só mais tarde; `:discard` teria descartado o envio silenciosamente, o que seria um bug grave (grupo nunca recebe a arte).

**`duration:` (TTL do semáforo) — default 3 minutos, mecanismo de auto-recuperação:**

```ruby
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/solid_queue.rb:42
mattr_accessor :default_concurrency_control_period, default: 3.minutes
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/solid_queue.rb:42]` — o semáforo (`solid_queue_semaphores.expires_at`) é recalculado a cada `wait`/`signal` como `duration.from_now`. Se um `SendToGroupJob` morre (crash) enquanto segura o slot, o semáforo fica "travado" (`value: 0`) até `expires_at` passar — no máximo `duration` (3 min, não sobrescrito por CONTEXT.md) **mais** o intervalo do dispatcher (`Dispatcher::ConcurrencyMaintenance`, que roda `expire_semaphores`/`unblock_blocked_executions` a cada `concurrency_maintenance_interval`, default 600s/10min, não sobrescrito em `config/queue.yml` atual). **Pior caso: até ~13 minutos** antes que o próximo `SendToGroupJob` da mesma instância seja liberado, se o processo morrer segurando o lock. Como cada `SendToGroupJob` já é uma chamada HTTP rápida (não um processo de longa duração), isso é um caso raro — mas vale considerar reduzir `concurrency_maintenance_interval` do dispatcher em `config/queue.yml` para, por exemplo, 60s, para apertar essa janela sem custo perceptível (o maintenance task é uma query leve).

### Pattern 4: `ProcessPrunedError` — o que realmente acontece quando um worker morre

```ruby
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/solid_queue/processes/process_pruned_error.rb
module SolidQueue
  module Processes
    class ProcessPrunedError < RuntimeError
      def initialize(last_heartbeat_at)
        super("Process was found dead and pruned (last heartbeat at: #{last_heartbeat_at})")
      end
    end
  end
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/solid_queue/processes/process_pruned_error.rb]` — a classe existe (confirma a menção em `evolution-contract.md` item 8 do caminho PENDENTE). O fluxo completo, verificado através de três arquivos:

```ruby
# .../app/models/solid_queue/process/prunable.rb:19-24
def prune
  error = Processes::ProcessPrunedError.new(last_heartbeat_at)
  fail_all_claimed_executions_with(error)
  deregister(pruned: true)
end
```

```ruby
# .../app/models/solid_queue/process/executor.rb:14-18
def fail_all_claimed_executions_with(error)
  if claims_executions?
    claimed_executions.fail_all_with(error)
  end
end
```

```ruby
# .../app/models/solid_queue/claimed_execution.rb:83-88
def failed_with(error)
  transaction do
    job.failed_with(error)
    destroy!
  end
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/process/prunable.rb:19-24, .../process/executor.rb:14-18, .../claimed_execution.rb:83-88]`

**Conclusão fechada:** quando um worker morre (heartbeat expira além de `SolidQueue.process_alive_threshold`), a manutenção do supervisor marca a execução como **`failed`** (grava em `solid_queue_failed_executions`) e destrói a `claimed_execution` — **não há reenfileiramento automático**. Isso é diferente de um `retry_on`/`discard_on` do próprio job (que SÃO tratados dentro de `ActiveJob::Base.execute`, dentro do mesmo processo, e portanto nunca chegam a este caminho — ver Pitfall 3). O job fica **parado** em `failed_executions`, exigindo intervenção manual (retomada via `SolidQueue::FailedExecution#retry` ou via console) — isso é exatamente o motivo de INFRA-07 (retenção/higiene de `failed_executions`) existir como item de fase 30, mas o comportamento sem retenção já é seguro no sentido de "nunca reenvia sozinho".

**Consequência para ENVIO-04:** a aplicação não pode contar com o solid_queue para "tentar de novo depois que o worker volta" — um job morto fica morto até alguém olhar `failed_executions` manualmente. A garantia de exactly-once não depende disso; ela depende só do claim atômico (Pitfall 1) acontecer antes do envio real.

### Pattern 5: Revalidação (ENVIO-06/07) + cancelamento (DIVU-08) + claim atômico

```ruby
# app/jobs/whatsapp/send_to_group_job.rb (esqueleto)
class Whatsapp::SendToGroupJob < ApplicationJob
  queue_as :whatsapp_sends

  limits_concurrency(
    to: 1,
    key: ->(group) { group.divulgacao.client.whatsapp_instance_id }
  )

  discard_on(StandardError) { |job, err| ... } # catch-all, DECLARADO PRIMEIRO (ver Pitfall 3)

  retry_on(Evolution::Errors::Transient, wait: :polynomially_longer, attempts: 5) { |job, err| ... }
  discard_on(Evolution::Errors::Unknown)    { |job, err| mark_incerto(job, err) }
  discard_on(Evolution::Errors::Permanent)  { |job, err| mark_falhou(job, err) }
  discard_on(Evolution::Errors::NotConnected) { |job, err| mark_falhou(job, "instância desconectada") }
  discard_on(ActiveJob::DeserializationError) # registro apagado mid-flight

  def perform(group)
    group.reload
    divulgacao = group.divulgacao.reload
    return if divulgacao.status_cancelada?

    claimed = DivulgacaoGrupo.where(id: group.id, status: :pendente)
                              .update_all(status: :enviado, sent_at: Time.current, updated_at: Time.current)
    return if claimed.zero? # outro worker/retry já tratou

    arte = divulgacao.arte.reload
    unless arte.approved?
      group.update!(status: :falhou, error_code: "arte_nao_aprovada")
      finalize_divulgacao_if_done(divulgacao)
      return
    end

    instance = divulgacao.client.whatsapp_instance
    unless instance&.connected?
      group.update!(status: :falhou, error_code: "instancia_desconectada")
      finalize_divulgacao_if_done(divulgacao)
      return
    end

    send_via_evolution(group, arte, instance) # levanta Evolution::Errors::* em falha

    finalize_divulgacao_if_done(divulgacao)
  end
end
```

**Nota crítica de ordem (não está em código acima, ver Pitfall 1):** o claim (`update_all(status: :enviado, ...)`) roda **antes** da chamada Evolution, exatamente como CONTEXT.md decidiu. Isso significa que o status `:enviado` é otimista: ele é corrigido para `:falhou`/`:incerto` pelos handlers de erro **quando o job consegue capturar a falha**. A única lacuna real é morte do processo entre o claim e a chamada HTTP (ou durante ela) — ver Pitfall 1.

`arte.reload`/`instance.reload`/`divulgacao.reload` funcionam normalmente dentro de um job (não precisam de contexto de request) — são simples SELECTs.

### Pattern 6: `Evolution::Client#send_text` / `#send_media` — extensão do client existente

O client atual (`app/services/evolution/client.rb`) já tem o `#request` privado genérico com taxonomia de erro completa (`raise_for_status!`, `classify_timeout`). Os dois métodos novos seguem o mesmo formato dos existentes (`fetch_groups`, `create_instance`):

```ruby
# Adição a app/services/evolution/client.rb (dentro de `class << self`)

# POST /message/sendText/{instance} — contrato verificado em evolution-contract.md
# (tag 2.3.7): { number, text, delay? }. `number` = JID de grupo (...@g.us).
def send_text(instance_name, number:, text:, api_key:)
  request(:post, "/message/sendText/#{instance_name}",
          api_key: api_key, body: { number: number, text: text }).body
end

# POST /message/sendMedia/{instance} — { number, mediatype, media, caption?, fileName?, mimetype?, delay? }.
# mediatype ∈ image|video|document|audio — só image/video são usados por esta fase (ENVIO-10).
def send_media(instance_name, number:, mediatype:, media:, api_key:, caption: nil)
  body = { number: number, mediatype: mediatype, media: media }
  body[:caption] = caption if caption.present?
  request(:post, "/message/sendMedia/#{instance_name}", api_key: api_key, body: body).body
end
```

`[CITED: .planning/notes/evolution-contract.md — "Rotas confirmadas por leitura do código-fonte no tag 2.3.7"]` — o shape do request já está VERIFICADO no contrato (não PENDENTE); o que fica PENDENTE é (a) o shape exato da resposta de sucesso (`key.id`, `status: "PENDING"` — lido do código-fonte mas não confirmado por envio real) e (b) o formato do erro 4xx (texto livre, já tratado pelo parser genérico existente).

**Mapeamento `arte.media_type` → `mediatype` (ENVIO-10):** `[VERIFIED: app/models/arte.rb — enum :media_type, { image: 0, video: 1, caption_only: 2 }]` — os valores do enum Rails (`"image"`, `"video"`, `"caption_only"`) já batem literalmente com os valores aceitos por `mediatype` no Evolution (`image`/`video`/`document`/`audio`) para os dois primeiros; `caption_only` nunca é passado como `mediatype` — ele desvia inteiramente para `send_text`. Nenhuma tabela de tradução é necessária: `arte.media_type` (quando não `caption_only`) é usado literalmente como valor de `mediatype`.

**Por que nenhum parser de erro estruturado é necessário:** o parser existente (`raise_for_status!`, já lido nesta sessão) decide a classe de erro pelo **status HTTP**, não pelo conteúdo da mensagem — um 400 do `sendMedia` (`BadRequestException`) já cai em `Evolution::Errors::Permanent` pelo `when 400, 401, 403, 404, 422` existente. O único trabalho novo é: o handler `discard_on(Evolution::Errors::Permanent)` do `SendToGroupJob` grava `err.message` (já normalizado como string pelo parser) truncado em `error_code`, nunca a exceção crua.

### Pattern 7: Fila dedicada (INFRA-06) — segundo worker em `config/queue.yml`, padrão documentado da própria gem

`config/queue.yml` atual:

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
```

`[VERIFIED: config/queue.yml]` (conteúdo lido integralmente nesta sessão).

**Restrição confirmada por leitura de `SolidQueue::QueueSelector`:** esta versão (1.4.0) **não tem sintaxe de exclusão** (`-queue`) — só nomes exatos, prefixo com `*` no final, ou `"*"` literal (todas as filas). `[VERIFIED: vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/queue_selector.rb]` (arquivo inteiro lido). Isso significa que **não é possível** fazer o worker `"*"` existente parar de pegar jobs de uma fila nova sem reescrevê-lo com uma lista explícita de filas.

**Padrão recomendado — sobreposição intencional, o mesmo padrão do README oficial da gem** (README lido nesta sessão, mas o mecanismo por trás já está VERIFIED acima via `QueueSelector`/`Worker#initialize`):

```yaml
# vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/README.md:220-232 (exemplo oficial idêntico ao padrão recomendado abaixo)
workers:
  - queues: "*"
    threads: 3
    polling_interval: 2
  - queues: [ real_time, background ]
    threads: 5
    polling_interval: 0.1
    processes: 3
```

Aplicado a este repo:

```yaml
# config/queue.yml — ADIÇÃO, sem tocar no worker existente
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 0.1
    - queues: whatsapp_sends
      threads: 2
      polling_interval: 0.1
```

`Divulgacoes::DispatchJob` e `Whatsapp::SendToGroupJob` usam `queue_as :whatsapp_sends`. O worker `"*"` continua existindo e **também** pode processar `whatsapp_sends` (não há como impedir sem reescrever para uma lista explícita `[default, mailers]`) — mas isso não é um bug: é exatamente o padrão documentado pela própria gem, e o efeito líquido é que `whatsapp_sends` sempre tem **capacidade garantida e reservada** (2 threads dedicadas) além da capacidade compartilhada do worker geral, o que já resolve o objetivo real de INFRA-06 ("sem atrasar" — não "isolamento perfeito"). Nenhuma mudança em `docker-compose.yml` é necessária: `bin/jobs` já sobe todos os processos definidos em `config/queue.yml` dentro do único serviço `jobs` existente (`[VERIFIED: docker-compose.yml]`, lido integralmente — comentário confirma "Sem este serviço NENHUM job agendado dispara em produção").

**Achado sobre o motivo real de INFRA-06:** hoje, `ApprovalResponse#broadcasts_to_admin` (a única lógica de ActionCable do v1.5) chama `AdminNotificationsChannel.broadcast_to` **diretamente, de forma síncrona, dentro do ciclo de request** (`after_create_commit`) — não passa por nenhum job solid_queue. `[VERIFIED: app/models/approval_response.rb:11,63]`. Ou seja, **não há contenção real hoje** entre broadcasts e jobs de fila. A fila dedicada é, portanto, uma proteção preventiva/arquitetural (a fase 30 pode introduzir broadcasts via job), não uma correção de um problema observável agora — mas a implementação continua sendo o requisito explícito de INFRA-06.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Serialização por instância WhatsApp | Lock manual via `Rails.cache`/coluna de mutex | `limits_concurrency` (solid_queue nativo) | Já resolve enfileiramento (`:block`), TTL de recuperação automática (`duration:`) e limpeza periódica (`Dispatcher::ConcurrencyMaintenance`) — reimplementar reintroduz os mesmos bugs que a gem já corrigiu |
| Espaçamento entre grupos | `sleep` dentro do job, ou um scheduler cron externo | `wait:`/`wait_until:` do ActiveJob | `wait:` não ocupa thread; um scheduler externo duplicaria o solid_queue já instalado |
| Parsing de erro do Evolution | Regex/parsing do texto de erro do `sendMedia` | Classificação por status HTTP (`raise_for_status!` já existente) | O texto é livre e não confiável (`BadRequestException(error.toString())`) — a única informação estruturada e estável é o código HTTP |
| URL assinada de mídia | Gerar manualmente com AWS SDK / rails_blob_url com host manual | `ActiveStorage::Blob#url(expires_in:)` | Já delega para `service.url` (S3 presign) sem dependência de contexto de request — ver Pitfall 2 |

**Key insight:** todo bloco de construção necessário para esta fase (agendamento, concorrência, taxonomia de erro, presign de mídia) já existe nativamente no stack instalado — o trabalho da fase é **composição correta**, não construção de infraestrutura nova.

## Common Pitfalls

### Pitfall 1: Janela de risco residual entre o claim atômico e a chamada HTTP (ENVIO-04)

**What goes wrong:** CONTEXT.md decide `update_all(status: :enviado)` como o claim atômico, executado **antes** da chamada Evolution. Se o processo do worker morre (OOM, `docker stop`/deploy sem graceful shutdown, `kill -9`) depois que o `update_all` já commitou mas antes (ou durante) da chamada HTTP ao Evolution, o registro fica marcado `:enviado` no banco **mas a mensagem pode nunca ter sido enviada** (ou o envio pode ter ocorrido e a confirmação nunca ter chegado ao processo morto — indistinguível).

**Why it happens:** não existe transação distribuída possível entre um `UPDATE` no Postgres e uma chamada HTTP a um serviço externo. O claim precisa acontecer antes do envio (para não enviar duas vezes se o job rodar 2x), mas isso significa que ele não pode esperar a confirmação do envio para "commitar" o estado de sucesso. Confirmado nesta sessão (Pattern 4): quando o worker morre, o solid_queue marca a execução como `failed` (`ProcessPrunedError`) e **não reenfileira** — não há uma segunda tentativa automática que poderia "corrigir" o estado.

**How to avoid:** Este é o trade-off que a própria CONTEXT.md já aceitou implicitamente (é uma decisão travada, não uma lacuna de pesquisa) — a mitigação possível, dentro do escopo desta fase, é:
1. Fazer o claim o mais próximo possível da chamada HTTP (não no início do método, logo antes do `send_text`/`send_media`) — mas isso não elimina a janela, só a encurta.
2. Documentar explicitamente (comentário no código, como o padrão já estabelecido em `Whatsapp::SyncGroupsJob`) que um registro `:enviado` sem `evolution_message_id` preenchido é um sinal de possível falha nesta janela — útil para a fase 30 (ACOMP-03, histórico consolidado) auditar.
3. **Não é escopo desta fase resolver isso com um outbox pattern ou coluna de estado intermediário** (`:enviando`) — o enum `divulgacao_grupos.status` já está travado em 4 valores pelo DIVU-09 da fase 28 (`pendente/enviado/falhou/incerto`), e introduzir um 5º valor seria uma mudança de schema fora do escopo decidido. Se o planner achar isso inaceitável, é uma decisão para levar de volta ao usuário — não uma correção silenciosa do research.

**Warning signs:** um `divulgacao_grupo` com `status: enviado` e `evolution_message_id: nil` — indica claim bem-sucedido sem confirmação de envio.

### Pitfall 2: `ActiveStorage::Blob#url` FORA de contexto de request — resolvido, não é um risco real

**What goes wrong (hipótese original em CONTEXT.md):** gerar a URL presignada dentro de um job (sem request/controller) poderia falhar por falta de `default_url_options`/host configurado.

**Why isso NÃO acontece aqui:** `Blob#url` delega diretamente para `service.url` — verificado no código-fonte instalado:

```ruby
# vendor/bundle/ruby/3.3.0/gems/activestorage-8.1.3/app/models/active_storage/blob.rb:235-238
def url(expires_in: ActiveStorage.service_urls_expire_in, disposition: :inline, filename: nil, **options)
  service.url key, expires_in: expires_in, filename: ActiveStorage::Filename.wrap(filename || self.filename),
    content_type: content_type_for_serving, disposition: forced_disposition_for_serving || disposition, **options
end
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/activestorage-8.1.3/app/models/active_storage/blob.rb:235-238]` — isto **nunca** passa por `Rails.application.routes.url_helpers` (que é o caminho que exigiria `default_url_options[:host]`). Para o serviço `:amazon` (S3, `config/storage.yml`, lido nesta sessão: `service: S3`, `force_path_style: true`), `service.url` é o AWS SDK assinando a URL diretamente (presigned GET), sem nenhuma dependência de request/controller. Isso já era conhecido do research da fase 25 (`[CITED: 25-RESEARCH.md — "blob.url(expires_in:) = presigned S3 direto (verificado S3Service#private_url, STACK.md)"]`) e confirmado de novo aqui na fonte real.

**How to avoid:** simplesmente chamar `arte.media_file.url(expires_in: 5.minutes)` (ou similar) dentro de `SendToGroupJob#perform` — nenhuma configuração adicional necessária. Escolher `expires_in:` curto o bastante para cobrir só o tempo do download pelo Evolution (não a Divulgação inteira), como CONTEXT.md já decidiu.

**Warning signs:** nenhum — este pitfall é hipotético e foi descartado pela verificação de código-fonte.

### Pitfall 3: Ordem de declaração de `discard_on`/`retry_on` — verificado na fonte da ActiveSupport, não só por convenção herdada

**What goes wrong:** um `discard_on(StandardError)` catch-all declarado **depois** dos handlers específicos (`Evolution::Errors::Transient`, etc.) engoliria todos eles, porque `StandardError` é superclasse de todas as exceções da taxonomia.

**Why it happens — verificado nesta sessão, não só por precedente do código do repo:**

```ruby
# vendor/bundle/ruby/3.3.0/gems/activesupport-8.1.3/lib/active_support/rescuable.rb:129
_, handler = rescue_handlers.reverse_each.detect do |class_or_name, _|
```

`[VERIFIED: vendor/bundle/ruby/3.3.0/gems/activesupport-8.1.3/lib/active_support/rescuable.rb:129]` — `rescue_handlers` é um array que cresce por `+=` (append) a cada `rescue_from`/`retry_on`/`discard_on` declarado; `reverse_each.detect` percorre do **mais recentemente declarado** para o mais antigo e usa o **primeiro match**. Ou seja: o handler declarado **por último** no arquivo tem prioridade mais alta. Um catch-all `discard_on(StandardError)` precisa ser declarado **primeiro** na classe para ter a prioridade mais baixa (só roda quando nada mais específico, declarado depois, responde).

**How to avoid:** replicar exatamente a ordem de `Whatsapp::SyncGroupsJob` (`app/jobs/whatsapp/sync_groups_job.rb`, já lido nesta sessão): `discard_on(StandardError)` catch-all **primeiro**, depois `retry_on`/`discard_on` específicos, na ordem de especificidade crescente não importa entre si (só o catch-all precisa vir antes de todos).

**Warning signs:** um teste que espera `retry_on Evolution::Errors::Transient` reenfileirar, mas o job é descartado direto — sintoma de handler na ordem errada.

### Pitfall 4: Fila `whatsapp_sends` sem worker dedicado — job nunca roda em dev/UAT

**What goes wrong:** se `config/queue.yml` não for atualizado com o segundo worker (Pattern 7) mas os jobs já usam `queue_as :whatsapp_sends`, os jobs ficam parados em `ready_executions` para sempre em qualquer ambiente que rode com uma config de `queue.yml` diferente da produção — MAS como o worker `"*"` continua presente e (confirmado) também pega `whatsapp_sends`, isso na prática **não trava** o dev/test, só produção-sem-o-segundo-worker ficaria sem a capacidade dedicada (mas ainda funcional via o worker `"*"`). O risco real é esquecer de aplicar a mudança de `queue.yml` em todos os 3 ambientes (`development`/`test`/`production` — todos herdam de `&default` no arquivo atual, então uma única edição no bloco `default: &default` já propaga).

**How to avoid:** editar só o bloco `default: &default` (todos os 3 ambientes herdam via YAML anchor `<<: *default`) — não duplicar a config por ambiente.

**Warning signs:** `bin/rails runner 'SolidQueue::Job.where(queue_name: "whatsapp_sends").count'` crescendo sem nunca ser processado (não deve acontecer aqui, dado o worker `"*"` de fallback, mas é o teste a rodar se algo parecer travado).

### Pitfall 5: `update_all` não seta `updated_at` automaticamente — convenção já estabelecida no repo

**What goes wrong:** `update_all(status: :enviado)` sem `updated_at:` explícito deixa a coluna `updated_at` desatualizada — inconsistente com o resto do registro.

**Why it happens — verificado no próprio código do repo, não é uma regra geral do Rails sem fonte:**

```ruby
# app/services/whatsapp/group_synchronizer.rb (comentário + código, já no repo)
# GRUPO-05: escopado pela associação (nunca toca outra instância), "<"
# estrito, updated_at explícito (update_all não auto-toca). Roda MESMO
# com rows vazio ...
@instance.whatsapp_groups
         .where(active: true)
         .where("synced_at < ?", batch_started_at)
         .update_all(active: false, updated_at: Time.current)
```

`[VERIFIED: app/services/whatsapp/group_synchronizer.rb — comentário e chamada `update_all(active: false, updated_at: Time.current)` lidos integralmente nesta sessão]` — este é o precedente direto e a convenção já estabelecida no repo para todo `update_all`.

**How to avoid:** sempre incluir `updated_at: Time.current` explicitamente em qualquer `update_all` desta fase (o claim atômico e qualquer flip de status subsequente).

**Warning signs:** `divulgacao_grupo.updated_at` idêntico a `created_at` mesmo depois de um envio processado.

### Pitfall 6: `error_code` sem teto de tamanho explícito na coluna — truncar na aplicação

**What goes wrong:** a coluna `error_code` é `t.string` sem `limit:` (`[VERIFIED: db/migrate/20260830190002_create_divulgacao_grupos.rb — "t.string :error_code"]`, lido integralmente nesta sessão) — Postgres aceita texto de qualquer tamanho numa `varchar` sem limite. Sem truncamento explícito na aplicação, um erro verboso do Evolution (ou uma stack trace acidental) pode gravar um blob grande, potencialmente incluindo fragmentos de URL presignada ou outro dado sensível se o texto de erro os ecoar.

**How to avoid:** truncar explicitamente (ex.: `err.message.to_s.first(500)`) antes de gravar em `error_code` — CONTEXT.md já exige isso ("grava o texto bruto **truncado**") e também exige nunca incluir token/URL completa (seção `<specifics>`). Como o parser do `Evolution::Client` já normaliza a mensagem de erro a partir de `response.message` do envelope JSON (nunca ecoa headers/apikey/URL), o risco residual é baixo, mas o truncamento em si ainda precisa ser código explícito no handler do job.

**Warning signs:** `error_code` com centenas de caracteres no banco.

## Code Examples

### Teste de `limits_concurrency` — não simular concorrência real, testar a config declarada

Não há um jeito direto de testar o comportamento real de bloqueio do solid_queue num teste unitário rápido (exigiria dois workers reais competindo). O padrão recomendado é confiar na gem (já lida/verificada nesta sessão) e testar só a **configuração declarada**:

```ruby
test "limits_concurrency configurado para 1 por instância" do
  assert_equal 1, Whatsapp::SendToGroupJob.concurrency_limit
end

test "concurrency_key resolve para o whatsapp_instance_id do grupo" do
  job = Whatsapp::SendToGroupJob.new(@divulgacao_grupo)
  # concurrency_key é privado na instância do job; chamar via send como o
  # client_test.rb já faz para métodos privados (padrão estabelecido no repo)
  assert_includes job.concurrency_key, @instance.id.to_s
end
```

### Teste de retry/discard — mesmo padrão de `sync_groups_job_test.rb` (já lido nesta sessão)

```ruby
test "discard_on Evolution::Errors::Permanent grava status falhou e error_code truncado" do
  fake_client = ->(*) { raise Evolution::Errors::Permanent, "x" * 1000 }
  Evolution::Client.stub(:send_media, fake_client) do
    assert_no_enqueued_jobs do
      Whatsapp::SendToGroupJob.perform_now(@divulgacao_grupo)
    end
  end
  @divulgacao_grupo.reload
  assert_equal "falhou", @divulgacao_grupo.status
  assert_operator @divulgacao_grupo.error_code.length, :<=, 500
end
```

`assert_enqueued_with`/`assert_no_enqueued_jobs`/`job.exception_executions = {...}` (para testar exaustão de `retry_on` sem esperar o `wait:` real) — todos já usados em `test/jobs/whatsapp/sync_groups_job_test.rb`, mesmo padrão a replicar.

### Teste do claim atômico — corrida simulada sem concorrência real

```ruby
test "claim atomico: update_all condicional retorna 0 quando outro processo ja tratou" do
  @group.update!(status: :enviado) # simula outro worker já ter processado
  claimed = DivulgacaoGrupo.where(id: @group.id, status: :pendente).update_all(status: :enviado)
  assert_equal 0, claimed
end
```

## State of the Art

Não aplicável — solid_queue 1.4.0 é a versão instalada e atual; nenhuma mudança de API entre esta versão e o que o repo já usa desde a fase 25/27.

**Deprecated/outdated:** nenhum.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Shape exato da resposta de sucesso de `sendMedia`/`sendText` (`key.id`, `status: "PENDING"`) — lido do código-fonte do Evolution 2.3.7 em `evolution-contract.md`, não confirmado por um envio real | Pattern 6 | Se o shape divergir, `evolution_message_id` pode ficar `nil` mesmo em envios bem-sucedidos — não quebra a taxonomia de erro (que é por status HTTP), só o campo informativo. UAT fase 29 fecha isso (já rastreado em `evolution-contract.md`) |
| A2 | Formato exato do texto de erro 4xx do `sendMedia` (mensagens reais de grupo `announce`, número não-admin, arquivo inválido) | Pattern 6, Pitfall 6 | Baixo risco — o design já é robusto a texto livre por construção (decisão por status HTTP, não por parsing de conteúdo); só a qualidade da mensagha exibida ao admin pode ser menos específica que o ideal até o UAT confirmar exemplos reais |
| A3 | `SolidQueue.process_alive_threshold` (usado no cálculo do pior caso do Pitfall/Pattern 3 de ~13 min) não foi lido diretamente nesta sessão — só `default_concurrency_control_period` (3 min) e `concurrency_maintenance_interval` (600s, do `DISPATCHER_DEFAULTS` já lido) foram confirmados por leitura direta | Pattern 3 | Risco baixo — não afeta nenhuma decisão de código, só a estimativa de tempo no comentário; se o planner quiser o valor exato, `grep process_alive_threshold vendor/bundle/.../solid_queue-1.4.0/lib/solid_queue.rb` resolve em segundos |

## Open Questions (RESOLVED)

1. **A janela de risco do Pitfall 1 (claim antes do envio) é aceitável para este milestone?**
   - What we know: é uma decisão já travada em CONTEXT.md; o comportamento do solid_queue quando o processo morre (Pattern 4) está totalmente verificado.
   - What's unclear: se o operador vai monitorar `divulgacao_grupos` com `status: enviado` e `evolution_message_id: nil` como sinal de falha nesta janela — não há UI/alerta para isso nesta fase (ACOMP-03 é fase 30).
   - Recommendation: planner documenta o padrão de detecção (Pitfall 1) num comentário no job, e considera se vale adicionar um teste de regressão explícito provando que o claim SEMPRE acontece antes da chamada HTTP no código (ex.: grep estático ou teste de ordem de chamadas com um double).
   - **RESOLVIDO** em `29-CONTEXT.md` § "Pergunta em aberto da pesquisa — RESOLVIDA": aceito como risco documentado (nenhum outbox pattern viável sem reescrever a arquitetura travada), remédio operacional é o reenvio manual da fase 30 (ACOMP-02). O teste de ordem claim-antes-de-HTTP recomendado foi entregue em `29-02-PLAN.md` Task 2 (testes adversariais de idempotência).

2. **`concurrency_maintenance_interval` do dispatcher — vale reduzir de 600s (default) para encurtar a janela de recuperação de semáforo?**
   - What we know: default 600s, não sobrescrito em `config/queue.yml` atual; reduzir para 60s encurtaria o pior caso de "instância travada por lock órfão" de ~13min para ~4min.
   - What's unclear: se esse ajuste vale o custo (query leve, rodando mais frequentemente) para um caso considerado raro (worker morrendo no meio de uma chamada HTTP rápida).
   - Recommendation: Claude's Discretion do planner — não é um requisito explícito, é uma otimização de robustez opcional.
   - **RESOLVIDO** em `29-CONTEXT.md`: manter o default (600s) — ajuste fino de performance fora do escopo funcional desta fase, não implementado nos planos.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| solid_queue (gem) | Todo o motor de envio | ✓ | 1.4.0 (`vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0`) | — |
| Worker `bin/jobs` rodando | Execução real dos jobs agendados | ✓ (produção, via `docker-compose.yml` serviço `jobs`) / requer `bin/jobs` manual em dev | — | Em dev, `bin/jobs` precisa ser iniciado manualmente (item de operação, não desta fase) |
| Evolution host (`whatsapp.bomcustoilhabela.com.br`) | Envio real (sendText/sendMedia) | ✓ leitura verificada (fase 25); escrita real ainda não exercitada nesta sessão | 2.3.7 | UAT fase 29 fecha o caminho de escrita |
| MinIO / ActiveStorage S3 | Geração de URL presignada de mídia | ✓ verificado em dev (fase 25, download externo provado) | — | — |
| Instância WhatsApp pareada com grupo de teste | UAT de envio real | Não disponível nesta sessão de pesquisa | — | Sem fallback — item de UAT do operador |

**Missing dependencies with no fallback:**
- Instância WhatsApp pareada + grupo de teste para exercitar `sendMedia`/`sendText` reais — bloqueia só o UAT, não o desenvolvimento/planejamento desta fase (o design já é robusto às incertezas documentadas em `evolution-contract.md`).

**Missing dependencies with fallback:**
- `bin/jobs` não rodando automaticamente em dev — precisa ser iniciado manualmente para testar o fluxo ponta a ponta fora de testes automatizados (não bloqueia testes unitários, que usam `perform_now`/`assert_enqueued_with`).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | não | Esta fase não introduz autenticação nova (herda sessão admin já existente) |
| V3 Session Management | não | — |
| V4 Access Control | sim | `divulgacao.client.whatsapp_instance` sempre resolvido pela associação (nunca por ID solto) — mesmo padrão SEG-01/SEG-02 já estabelecido nas fases 27/28; garante SEG-03 (token do cliente certo) |
| V5 Input Validation | parcial | Nenhum input de usuário novo nesta fase (todo o fluxo é server-driven, sem params externos no job) — a única "entrada" é o corpo de resposta do Evolution, já tratado por `raise_for_status!` existente |
| V6 Cryptography | não (herdado) | `WhatsappInstance#token` já é `encrypts :token` (fase 26) — esta fase só lê, não grava |
| V9 Communications | sim | Todo tráfego ao Evolution já é HTTPS (`Evolution.base_url` validado no boot, fase 25) |
| V13 API and Web Service | sim | `error_code` nunca deve conter token/URL completa (CONTEXT.md `<specifics>`) — truncamento + fonte da mensagem já normalizada pelo parser (nunca ecoa headers) |

### Known Threat Patterns for este stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Vazamento de token/URL presignada em `error_code` (log/DB) | Information Disclosure | Truncamento + mensagem de erro já normalizada pelo `Evolution::Client` (nunca inclui headers/apikey/corpo bruto de request) — ver Pitfall 6 |
| Cross-client leak (arte do cliente A alcançar grupo do cliente B) | Information Disclosure / Tampering | `divulgacao.client.whatsapp_instance.token` sempre resolvido via a cadeia de associação da própria Divulgação — nunca um `WhatsappInstance.find`/`.token` solto. Um erro de escopo já falharia com 401 do próprio Evolution (SEG-03) — mas o teste dedicado que PROVA isso é SEG-04, fase 30 |
| Envio duplicado por corrida (dois workers, mesmo grupo) | Tampering (efeito no mundo real: mensagem duplicada no WhatsApp) | Claim atômico via `update_all` condicional (Pattern 5) — mesma técnica já usada e testada em `Whatsapp::GroupSynchronizer` |
| Job argument leak (token do WhatsApp nos argumentos serializados do job) | Information Disclosure | Passar objetos ActiveRecord (`group`, não IDs crus com token embutido) — ActiveJob serializa via GlobalID, nunca com atributos sensíveis inline. Mesmo padrão testado em `sync_groups_job_test.rb` ("token nunca entra nos argumentos do job") |

## Sources

### Primary (HIGH confidence — lido diretamente nesta sessão)
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb` — API de `limits_concurrency`
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/job/concurrency_controls.rb` — `on_conflict`/`block`/`discard`
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/solid_queue/processes/process_pruned_error.rb`, `app/models/solid_queue/process/prunable.rb`, `.../process/executor.rb`, `.../claimed_execution.rb` — comportamento de `ProcessPrunedError`
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/job/schedulable.rb`, `.../job/executable.rb`, `app/models/solid_queue/job.rb` — `due?`, `wait_until:` no passado, `enqueue`
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/queue_selector.rb`, `lib/solid_queue/worker.rb`, `lib/solid_queue/configuration.rb` — sintaxe de `queues:`
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/semaphore.rb`, `lib/solid_queue/dispatcher/concurrency_maintenance.rb`, `lib/solid_queue.rb` — TTL de semáforo, maintenance
- `vendor/bundle/ruby/3.3.0/gems/activestorage-8.1.3/app/models/active_storage/blob.rb:235-238` — `Blob#url` não depende de request
- `vendor/bundle/ruby/3.3.0/gems/activesupport-8.1.3/lib/active_support/rescuable.rb:129` — ordem de `rescue_handlers`
- `vendor/bundle/ruby/3.3.0/gems/activerecord-8.1.3/lib/active_record/relation.rb:598-638` — `update_all` retorna row count
- `app/jobs/whatsapp/sync_groups_job.rb`, `test/jobs/whatsapp/sync_groups_job_test.rb` — padrão de taxonomia de erro/teste a replicar
- `app/services/evolution/client.rb`, `app/services/evolution/errors.rb` — client/taxonomia existentes a estender
- `app/services/whatsapp/group_synchronizer.rb` — precedente de `update_all` com `updated_at:` explícito
- `app/models/divulgacao.rb`, `app/models/divulgacao_grupo.rb`, `db/migrate/20260830190002_create_divulgacao_grupos.rb`, `db/schema.rb` — schema/enum/validações existentes
- `app/models/whatsapp_instance.rb`, `app/models/client.rb`, `app/models/arte.rb` — associações e enums consumidos pelo job
- `app/controllers/admin/divulgacoes_controller.rb` — ponto de integração do `DispatchJob`
- `config/queue.yml`, `config/storage.yml`, `docker-compose.yml`, `config/environments/*.rb` — configuração de deploy/worker
- `app/models/approval_response.rb:11,27-63` — confirma que broadcasts ActionCable hoje são síncronos, não via job

### Secondary (MEDIUM confidence)
- `.planning/notes/evolution-contract.md` — contrato Evolution 2.3.7, seções VERIFICADO (lidas e citadas) e PENDENTE (citadas como tal, não tratadas como fato)
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/README.md:220-270` — padrão de configuração multi-worker (usado só como confirmação do padrão já verificado via `QueueSelector`, não como fonte primária isolada)

### Tertiary (LOW confidence)
- Nenhuma — todas as claims técnicas centrais desta fase foram verificadas por leitura direta do código-fonte instalado.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero gems novas, todas já verificadas em fases anteriores
- Architecture (solid_queue mechanics): HIGH — toda a mecânica de concorrência/agendamento/falha de processo foi lida diretamente do código-fonte da gem instalada nesta sessão
- Evolution write-path (sendMedia/sendText): MEDIUM — request shape VERIFICADO (herdado de `evolution-contract.md`, fonte primária do código Evolution 2.3.7); response shape de sucesso e texto exato de erro 4xx permanecem PENDENTE de UAT real (já rastreado, não uma lacuna desta pesquisa)
- Pitfalls: HIGH — todos os 6 pitfalls documentados têm base em leitura de código-fonte real (gem instalada ou arquivos deste repo), não em suposição

**Research date:** 2026-08-31
**Valid until:** Enquanto `solid_queue` permanecer em 1.4.0 e `evolution-contract.md` não for atualizado por um UAT real de envio — sem prazo fixo (stack interno estável); revalidar se `bundle update solid_queue` ou `bundle update activestorage` acontecer antes da execução desta fase.
