# Phase 29: Motor de Envio - Context

**Gathered:** 2026-08-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Na hora agendada, cada grupo selecionado de uma Divulgação recebe a arte exatamente uma vez,
com intervalo aleatório entre grupos, respeitando aprovação, conexão e cancelamento. Esta é
a **fase de maior densidade de risco do milestone** — merece code review dedicado e cobre os
pitfalls 1, 4 e 5 da pesquisa da fase 25. Entrega: o `DispatchJob` + `SendToGroupJob`, a
taxonomia de erro explícita (fecha o débito pré-existente de `application_job.rb`), a
serialização por instância, a revalidação de aprovação/conexão no momento do envio, o
respeito ao cancelamento, e a fila dedicada (INFRA-06). **Fora de escopo:** progresso ao vivo
na tela, reenvio manual por grupo, histórico consolidado por cliente (tudo fase 30).

</domain>

<decisions>
## Implementation Decisions

### Arquitetura de disparo

- **1 job por grupo** (`Whatsapp::SendToGroupJob`), não 1 job monolítico por Divulgação —
  ENVIO-03 exige que o worker não fique ocupado esperando entre grupos.
- Mecanismo de espaçamento: `perform_later(wait: cumulative_delay)` — cada `SendToGroupJob`
  agendado com um offset crescente (soma de delays aleatórios vindos de
  `Divulgacao::SEND_DELAY_MIN`/`SEND_DELAY_MAX`, já estabelecidos na fase 28), calculado no
  momento do disparo.
- Trigger: um `Divulgacoes::DispatchJob` agendado para `scheduled_for` que lê os
  `divulgacao_grupos` pendentes daquela Divulgação e enfileira os `SendToGroupJob`
  individuais com os offsets calculados.
- Concorrência por instância (ENVIO-09): `limits_concurrency(to: 1, key: ->(group) {
  group.divulgacao.client.whatsapp_instance_id })` no `SendToGroupJob` — API confirmada
  disponível no solid_queue 1.4.0 instalado (`lib/active_job/concurrency_controls.rb`).
  Nunca dois envios da mesma instância em paralelo.

### Idempotência e taxonomia de erro (mirror do padrão `Whatsapp::SyncGroupsJob` da fase 27)

- Claim atômico antes do envio: `update_all(status: :enviado)` condicionado em
  `where(status: :pendente)` — se retornar 0 linhas, outro worker/retry já processou; o job
  vira no-op. Mesma defesa contra double-send que a fase 27 provou com `upsert_all`.
- `Net::ReadTimeout` → resultado `incerto`, `discard_on` (**nunca** retry automático) — herda
  a taxonomia já registrada em `.planning/notes/evolution-contract.md`: pode ter sido
  processado do lado do WhatsApp, então nunca é seguro re-tentar sozinho, mas também não é
  claramente `falhou`.
- Erro de rede antes do envio (`Net::OpenTimeout`/`ECONNREFUSED`/`SocketError`,
  taxonomia `Transient`) → `retry_on` com backoff — nada foi enviado, seguro re-tentar.
- Erro 4xx do `sendMedia` (texto livre — o Evolution 2.3.7 faz `throw new
  BadRequestException(error.toString())`, sem código estruturado) → `discard_on` → `falhou`,
  grava o texto bruto **truncado** em `divulgacao_grupos.error_code`. **O formato exato do
  erro fica PENDENTE de UAT real** (`.planning/notes/evolution-contract.md` já documenta
  isso) — a fase não pode assumir um shape estruturado que não existe; o job é escrito para
  ser robusto a texto livre desde o início.
- `Divulgacao#cancelar!` (fase 28) e o débito pré-existente de `application_job.rb`
  (`retry_on`/`discard_on` comentados) ficam explicitamente fechados por esta taxonomia.

### Revalidação no momento do envio + cancelamento

- `SendToGroupJob#perform` recarrega `arte.reload` e checa `arte.approved?` **antes** de
  qualquer chamada Evolution (ENVIO-06) — se não aprovada, `falhou` com motivo "arte não está
  mais aprovada", **nunca** `enviado`. A janela entre o agendamento e o envio individual é
  exatamente o que ENVIO-06 quer fechar; checar só uma vez no `DispatchJob` não cobriria
  artes com aprovação retirada durante o disparo.
- Mesma lógica para conexão (ENVIO-07): `instance.connected?` checado dentro do job,
  imediatamente antes do `Evolution::Client` call.
- Cancelamento em andamento (DIVU-08): `SendToGroupJob#perform` recarrega `divulgacao.reload`
  e checa se ainda está `agendada`/`em_andamento` antes de enviar — se `cancelada`, no-op
  silencioso, **o item permanece `pendente`** (não vira `falhou` — cancelamento não é uma
  falha de envio). Checagem no `perform`, não via `Job.discard` nos jobs já enfileirados
  (jobs que já passaram do `wait:` não seriam mais canceláveis dessa forma).
- Transições de `divulgacoes.status`: `Divulgacoes::DispatchJob` seta `em_andamento` no
  início; o último `SendToGroupJob` do lote (ou um job de fechamento) seta `concluida` quando
  todos os itens saem de `pendente`. `ACOMP-01` (fase 30) precisa distinguir "ainda não
  começou" de "em andamento" — `divulgacoes.status` não pode ficar travado em `agendada`.

### Mídia, texto e o teto de tamanho

- URL de mídia (ENVIO-08) gerada **dentro** do `SendToGroupJob#perform`, não pré-gerada no
  `DispatchJob` — validade calculada para cobrir só o envio individual, evitando que a URL do
  último grupo de uma Divulgação grande expire antes de ser baixada pelo Evolution.
- Texto vs mídia (ENVIO-10): `arte.caption_only?` → `sendText` com `text: arte.caption`;
  senão → `sendMedia` com `media: <url>`, `mediatype: arte.media_type` (`image`/`video`),
  `caption: arte.caption.presence`. `number` = JID do grupo (`...@g.us`).
- Token da instância (SEG-03): `Evolution::Client` chamado com `api_key:
  divulgacao.client.whatsapp_instance.token` — sempre resolvido a partir do `client` da
  Divulgação, nunca de um ID solto. Um erro de escopo já falharia com 401 do próprio
  Evolution (a instância errada não teria o grupo).
- Teto de tamanho: reusa `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES` (16MB, heurística — valor
  real fica PENDENTE de UAT segundo `.planning/notes/evolution-contract.md`). **Não
  re-valida no job** — a Divulgação não pode ter sido criada com arquivo acima do teto
  (validação já roda na criação, fase 28). Se o UAT revelar um teto diferente, só a
  constante muda, não a lógica.

### Claude's Discretion

- Nome exato dos métodos/classes além dos já nomeados acima (`Divulgacoes::DispatchJob`,
  `Whatsapp::SendToGroupJob`) — seguir o namespace `Whatsapp::` estabelecido nas fases 26/27.
- Se o `DispatchJob` é agendado via `perform_later(wait_until: divulgacao.scheduled_for)` no
  `#create` do controller (fase 28) ou via um scan periódico — pesquisar o padrão idiomático
  do solid_queue 1.4.0 antes de decidir (research explícito no ROADMAP).
- Comportamento exato de `ProcessPrunedError` (worker morto mid-dispatch) — pesquisar contra
  a gem 1.4.0 instalada antes de codificar qualquer suposição (README não verificado).
- Estrutura exata da fila dedicada (INFRA-06 — disparos não atrasam os broadcasts de
  ActionCable do v1.5): nome da fila, `queue_as`, e ajuste de `config/queue.yml`.
- Retenção de `failed_executions` (INFRA-07) é explicitamente fase 30 — não implementar aqui,
  só não piorar o problema.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Divulgacao::SEND_DELAY_MIN`/`SEND_DELAY_MAX` (fase 28) — já lêem
  `WHATSAPP_SEND_DELAY_MIN_SECONDS`/`_MAX_SECONDS` com fallback 25/45. Esta fase é a dona
  canônica do contrato — usa essas constantes, não reimplementa a leitura de ENV.
- `divulgacao_grupos` já tem as colunas nullable de staging desta fase: `sent_at` (datetime),
  `error_code` (string), `evolution_message_id` (string) — criadas na fase 28 exatamente para
  esta fase preencher, sem migração nova.
- `Divulgacao#cancelar!` (fase 28) — `agendada → cancelada`, guardado por
  `status_agendada?`, validação `scheduled_for_no_futuro` escopada a `on: :create` (fix do
  code review da fase 28 — não bloqueia `cancelar!` depois que o horário passou).
- `Whatsapp::SyncGroupsJob` (fase 27) — padrão de referência para taxonomia de erro:
  `discard_on(StandardError)` catch-all DECLARADO PRIMEIRO (ActiveJob busca do handler mais
  recentemente declarado), `retry_on`/`discard_on` específicos depois, `mark_error` grava
  código curto — não a mensagem crua do Evolution.
- `Evolution::Client` (fase 25) já tem `request(method, path, api_key:, body:, read_timeout:,
  query:)` genérico + `Evolution::Errors::{Transient,Unknown,Permanent,NotConnected,
  ConfigurationError}`. Precisa de dois métodos novos: `send_text` e `send_media`.
- `.planning/notes/evolution-contract.md` — contrato Evolution 2.3.7 VERIFICADO
  (`sendText`/`sendMedia` request shape, envelope de erro, headers) e PENDENTE (formato exato
  do erro 4xx, teto real de mídia, shape de sucesso) — fonte canônica, ler antes de planejar.
- `WhatsappInstance#connected?`, `#token` (encrypted) — fase 26.

### Established Patterns
- Taxonomia de erro Evolution: `Net::OpenTimeout`/`ECONNREFUSED`/`SocketError` →
  `Transient`; `Net::ReadTimeout` → `Unknown`; `401`/`403` → `Permanent`;
  `connectionState != "open"` → `NotConnected`. Corpo 5xx não-JSON (HTML da Cloudflare) →
  tratado como `Transient`.
- `apikey` (não `Authorization: Bearer`) é o único esquema de auth aceito pelo host.
- `number` = JID de grupo `...@g.us`.
- `delay` (ms) no payload do Evolution = simulação de "digitando", BLOQUEIA a request HTTP —
  **não é** o espaçamento entre grupos (isso é `wait:` do ActiveJob).
- Migrations rodam contra dev DB local; testes via
  `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test`.
- Namespace `Whatsapp::` para jobs/serviços relacionados a WhatsApp (`SyncGroupsJob` já
  estabelece o padrão).

### Integration Points
- `Admin::DivulgacoesController#create` (fase 28) — precisa enfileirar/agendar o
  `DispatchJob` após salvar a Divulgação (hoje não faz nada além de salvar).
- `config/queue.yml` — fila dedicada nova para disparos WhatsApp (INFRA-06).
- `app/jobs/application_job.rb` — débito pré-existente, `retry_on`/`discard_on` comentados;
  esta fase estabelece a taxonomia explícita nos jobs concretos (não precisa necessariamente
  mexer no `ApplicationJob` base, mas o ROADMAP cita isso como "fechado aqui").

</code_context>

<specifics>
## Specific Ideas

- O texto de erro truncado gravado em `error_code` nunca deve incluir dados sensíveis (token,
  URL presignada completa) — só a mensagem de erro do Evolution.
- `incerto` é um estado que precisa aparecer distinto de `falhou` em qualquer lugar que a fase
  30 vá renderizar (vocabulário já travado no DIVU-09/enum de `divulgacao_grupos`).
- Nenhuma chamada ao Evolution pode acontecer para um item que não é mais `pendente` no
  momento do claim atômico — isso é o coração de ENVIO-04.

</specifics>

<deferred>
## Deferred Ideas

- Progresso ao vivo na tela (ACOMP-01), reenvio manual por grupo (ACOMP-02), histórico
  consolidado por cliente (ACOMP-03) — fase 30.
- Retenção de `failed_executions` do solid_queue (INFRA-07) — fase 30.
- Teste negativo cross-client de ponta a ponta usando o motor real (SEG-04) — fase 30 (esta
  fase preserva o escopo via `divulgacao.client.whatsapp_instance`, mas o teste dedicado
  "suíte falha se arte de A alcançar grupo de B" é da fase 30).
- Camada anti-ban além do delay aleatório (warm-up, volume seguro) — não fecha nunca
  (anedótica por natureza, ver `evolution-contract.md` §"Qualidade da evidência"); postura é
  conservadorismo via ENV, não uma feature desta fase.

</deferred>
