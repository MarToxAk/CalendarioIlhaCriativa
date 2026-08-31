# Phase 30: Acompanhamento ao Vivo + Hardening - Context

**Gathered:** 2026-08-31
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous) — 4 grey areas, todas aceitas verbatim

<domain>
## Phase Boundary

O admin acompanha e conserta o disparo de uma Divulgação sem sair da tela — progresso ao
vivo por grupo, reenvio manual por grupo que falhou, e histórico por cliente — e o
isolamento entre clientes ganha um teste dedicado que falha se a arte do cliente A alcançar
um grupo do cliente B. Fecha também o débito de hardening INFRA-07 (retenção de
`failed_executions` do solid_queue).

Entrega: broadcast ao vivo da `divulgacoes#show` (stream dedicado por Divulgação, callbacks
`after_update_commit` em `DivulgacaoGrupo`/`Divulgacao` espelhando `arte.rb`), linha-resumo
agregada + badge ao vivo, botão "Reenviar" por linha (`falhou`/`incerto`) com action
`POST resend` escopada que re-enfileira o `Whatsapp::SendToGroupJob` da fase 29, enriquecimento
do `divulgacoes#index` (placar por grupo) e do `#show` (`error_code` sanitizado + `sent_at`),
teste de integração SEG-04, e entrada de retenção no `config/recurring.yml`.

**Fora do escopo desta fase:**
- Motor de envio, jobs de disparo, taxonomia de erro, idempotência — tudo fase 29 (feito).
- Job recorrente *staggered* de sync de grupos — deferido pelas fases 27/29 como "fase 30 /
  hardening", mas o ROADMAP da fase 30 NÃO atribui nenhum requisito GRUPO-* aqui e o goal não
  o menciona. Fica deferido (ver `<deferred>`).
- Status "entregue" real via webhook `MESSAGES_UPDATE`/`DELIVERY_ACK` — DELIV-01, future.
- Circuit breaker por instância — DELIV-02, future.
- Variação de legenda anti-spam — fora do v1.7 (fase 28 travou: legenda verbatim).

</domain>

<decisions>
## Implementation Decisions

### Progresso ao vivo (ACOMP-01 / SC1)

- **Canal:** stream dedicado por Divulgação — `turbo_stream_from [@client, @divulgacao]` na
  `divulgacoes/show.html.erb` (usa `Turbo::StreamsChannel`, auth de admin já coberta pela
  sessão / `Admin::BaseController`). NÃO reusar o `AdminNotificationsChannel` do v1.5: ele é
  global por-usuário (toasts em qualquer página); progresso de grupo é "esta página, este
  registro". O `AdminNotificationsChannel` continua intocado para o fluxo de aprovação.
- **Gatilho:** `after_update_commit` no `DivulgacaoGrupo` guardado por `saved_change_to_status?`
  → `broadcast_replace_to` no `dom_id(dg)` com o partial `_grupo_row`. `after_update_commit`
  na `Divulgacao` guardado por `saved_change_to_status?` → replace do `_status_badge` + da
  linha-resumo. Mesmo padrão de `arte.rb:27` (`after_update_commit :broadcasts_… , if: -> { saved_change_to_status? && … }`).
- **Granularidade:** replace granular — troca só a linha mudada (`dom_id(dg)`), o badge de
  status e o contador. Nunca re-render do card inteiro de grupos.
- **Agregado ao vivo:** uma linha-resumo "enviados X · falhou Y · pendente Z · incerto W"
  acima ou abaixo da lista de grupos, num alvo com `dom_id` próprio, trocada no mesmo commit
  que muda uma linha. SC1 só exige status por-grupo ao vivo; o contador é barato e torna
  "acabou?" legível. A transição da Divulgação para `concluida` (feita pelo
  `finalize_divulgacao_if_done` da fase 29) dispara o `after_update_commit` da `Divulgacao` e
  atualiza o badge sozinha.
- `_grupo_row.html.erb` precisa de um `id="#{dom_id(dg)}"` no `<li>` (hoje não tem) para o
  `broadcast_replace_to` casar o alvo. O `_status_badge` já é um partial isolado.

### Reenvio manual por grupo (ACOMP-02 / SC2)

- **Controle:** `button_to "Reenviar"` dentro de `_grupo_row`, renderizado SOMENTE quando
  `dg.status` é `falhou` ou `incerto`. Nunca em `pendente`/`enviado`. `data: { turbo_confirm:
  "Reenviar esta arte para o grupo <nome>?" }` (confirmação explícita — SC2).
- **Status reenviáveis:** `falhou` + `incerto`. `incerto` = "talvez enviou, precisa decisão
  humana" — o reenvio é a decisão. `enviado` NÃO ganha botão (a janela claim/crash do
  29-CONTEXT é rara; expor reenvio em `enviado` convida a duplicar mensagem entregue).
- **Rota/action:** action dedicada em `divulgacao_grupos` — `POST resend`, aninhada:
  `resources :divulgacoes { resources :divulgacao_grupos, only: [] do member { post :resend } end }`
  (ou member na própria `divulgacoes` recebendo `group_id` — discrição, mas o id do grupo
  SEMPRE re-resolvido pela associação). Escopo:
  `@client.divulgacoes.find(params[:divulgacao_id]).divulgacao_grupos.find(params[:id])` —
  um id forasteiro cai em `RecordNotFound` → 404, mesmo padrão de `@client.artes.find`.
- **Execução:** reseta a linha para `status: :pendente` (limpa `error_code`, `sent_at`,
  `evolution_message_id`) e `Whatsapp::SendToGroupJob.perform_later(dg)`. Reusa TODO o caminho
  da fase 29: claim atômico, `arte.reload.approved?`, `instance.connected?`, `divulgacao.reload`
  cancelada?, `limits_concurrency` por instância, taxonomia de erro. NENHUM envio síncrono no
  controller.
- **Guarda:** só permite reenvio se a `Divulgacao` não estiver `cancelada`. Se `concluida`,
  o reenvio de uma linha `falhou`/`incerto` é legítimo (conserto pós-disparo) — a linha volta
  a `pendente` e o `finalize_divulgacao_if_done` da fase 29 re-resolve `concluida` quando ela
  sair de `pendente` de novo. Confirmar se `finalize_divulgacao_if_done` precisa também
  reabrir `concluida → em_andamento` no resend (provável: sim, senão o badge fica "Concluída"
  com uma linha `pendente`). Decisão: o `resend` seta `divulgacao.update!(status: :em_andamento)`
  se ela estava `concluida`, antes de enfileirar.
- **Feedback imediato:** a resposta do `POST resend` (Turbo Stream ou redirect_back) troca a
  linha para o estado `pendente` ("reenfileirado") NO MESMO LUGAR; o broadcast ao vivo
  (mecanismo do ACOMP-01) atualiza para `enviado`/`falhou`/`incerto` quando o job roda. Sem
  reload de página inteira (SC2: "resultado aparece no mesmo lugar").

### Histórico por cliente (ACOMP-03 / SC3)

- **Onde:** o `admin/divulgacoes#index` existente JÁ É o histórico — é por-cliente, paginado
  (Pagy, 25), ordenado `scheduled_for: :desc`. A fase 30 enriquece cada linha do `index` com
  o placar por grupo agregado (ex. "18 enviados · 2 falhou · 0 incerto"), calculado sem N+1
  (`includes(:divulgacao_grupos)` ou um `group(:status).count` por divulgação). Link de
  entrada a partir do `admin/clients#show` (o botão/seção já existe da fase 28) — garantir que
  aponta para `admin_client_divulgacoes_path(@client)`.
- **Detalhe por grupo:** no `divulgacoes#show`, `_grupo_row` ganha:
  - motivo (`dg.error_code`, já sanitizado pela fase 29 — sem URL presignada, truncado 500)
    exibido nas linhas `falhou` e `incerto`;
  - `dg.sent_at` (formatado com o helper de fuso pt-BR `divulgacao_datetime_label`) nas
    linhas `enviado`.
- **Nome congelado (SC3 explícito):** JÁ resolvido pela fase 28 — `divulgacao_grupos.group_name`
  e `remote_jid` são snapshots gravados na criação; `_grupo_row` renderiza `dg.group_name`,
  nunca uma lookup viva no `WhatsappGroup`. A fase 30 só ADICIONA um teste: renomear/desativar
  o `WhatsappGroup` de origem depois da Divulgação criada e assertar que o `#show`/`index`
  ainda mostram o nome antigo.
- **Sem filtro** no histórico — a lista paginada `scheduled_for: :desc` basta (10–30 clientes,
  volume baixo). Não adicionar chips de status estilo `admin/approvals`.

### Hardening — teste cross-client (SEG-04 / SC4) + retenção (INFRA-07 / SC5)

- **Teste SEG-04:** teste de integração (`test/integration/` ou `test/jobs/`) que:
  1. monta `client_a` com `arte` aprovada + `whatsapp_instance` + grupos; `client_b` com
     `whatsapp_instance` + grupos próprios;
  2. tenta criar uma `Divulgacao` de `client_a` referenciando um `whatsapp_group` de
     `client_b` → assert que a criação é RECUSADA (o `.find` escopado do controller levanta
     `RecordNotFound` / a validação `arte_e_grupos_do_mesmo_cliente` adiciona erro);
  3. constrói (à força, no nível de model, driblando o controller) um `DivulgacaoGrupo` de
     `client_a` apontando pra grupo de `client_b`, roda `Whatsapp::SendToGroupJob` e assert
     que `Evolution::Client` NUNCA é chamado com o `remote_jid` de `client_b`
     (`Evolution::Client` stubado; `assert_not` que recebeu send_text/send_media com aquele
     JID — ou que o job marca `falhou` "instancia_desconectada"/escopo antes de qualquer I/O).
  - Belt de model: teste que `divulgacao.client.whatsapp_instance.token` de `client_a` nunca
    é igual ao de `client_b` — a cadeia de resolução do token (SEG-03) é a barreira real.
  - `bin/rails test` roda com `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo`
    (workaround de socket do sandbox — `.env` bloqueado para agentes). Ver nota da
    `test_db_permission` — o banco de teste pode pertencer a outro usuário do SO; se
    `bin/rails test` não rodar, o planner deve prever verificação por inspeção + deixar o
    teste escrito e pronto para o operador rodar na UAT.
- **Retenção `failed_executions` (INFRA-07 / SC5):** entrada nova no `config/recurring.yml`,
  espelhando o `clear_solid_queue_finished_jobs` de produção que já existe:
  ```yaml
  prune_solid_queue_failed_executions:
    command: "SolidQueue::FailedExecution.where('created_at < ?', Integer(ENV.fetch('SOLID_QUEUE_FAILED_RETENTION_DAYS', '14')).days.ago).delete_all"
    schedule: every day at 3am
  ```
  Adicionar em `production` E `development` (INFRA-02: jobs agendados precisam sobreviver a
  restart em dev para a UAT de agendamento; a retenção também deve rodar em dev). Confirmar a
  classe/relação correta contra `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0`
  (`SolidQueue::FailedExecution`, tem `created_at`; `delete_all` é suficiente — a associação
  `dependent`/FK cascateia a linha de `solid_queue_jobs`? verificar: pode ser necessário
  `job.destroy` em lote via `FailedExecution.includes(:job).find_each`).
- **Janela:** 14 dias, configurável via `ENV["SOLID_QUEUE_FAILED_RETENTION_DAYS"]` (default
  14). Suficiente para o operador notar e agir sobre um disparo falho; args em texto claro
  não devem ficar mais que isso.
- **Descarte é seguro:** o trilho de auditoria durável é `divulgacao_grupos` (status +
  `error_code` sanitizado + `sent_at` + `evolution_message_id`), que a fase 29 já popula e a
  fase 30 renderiza. `failed_executions` é plumbing cru com os argumentos do job em texto
  claro — exatamente o que o INFRA-07 quer podar. Nenhuma cópia de resumo pré-delete.

### Claude's Discretion

- Forma exata da rota de `resend` (member em `divulgacoes` com `group_id` vs `resources
  :divulgacao_grupos` aninhado com member `resend`) — desde que o id do grupo seja SEMPRE
  re-resolvido pela associação do cliente.
- Se o `resend` responde com `turbo_stream` inline (troca a linha na hora) ou `redirect_back`
  (deixa o broadcast fazer o trabalho) — o UI-SPEC decide; ambos satisfazem "mesmo lugar".
- Posição visual da linha-resumo agregada (topo do card de grupos vs sticky vs abaixo do
  badge) e se ela é um partial próprio (`_progresso_resumo`) — provável que sim.
- Nome do partial/parcial do placar por grupo no `index` (`_placar` / inline helper).
- Se `finalize_divulgacao_if_done` (fase 29) ganha a lógica de reabrir `concluida →
  em_andamento` ou se isso vive no controller de `resend` — preferência: no `resend`, para
  não mexer no job da fase de maior risco.
- Layout/arquivo do teste SEG-04 (`test/integration/cross_client_isolation_test.rb` vs
  `test/jobs/whatsapp/send_to_group_job_test.rb` estendido) e o mecanismo de stub
  (`Minitest::Mock` vs um fake `Evolution::Client`).
- Classe exata da relação de `solid_queue` para a poda e se precisa `destroy` em vez de
  `delete_all` para cascatear.
- Textos pt-BR exatos, classes Tailwind dos estados, ícones.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/models/arte.rb:27` — `after_update_commit :broadcasts_revised_to_all, if: -> {
  saved_change_to_status? && revised? }` — PADRÃO CANÔNICO de broadcast por callback de
  status. `broadcasts_revised_to_all` monta turbo-stream tags e chama
  `ClientCalendarChannel.broadcast_to` / `AdminNotificationsChannel.broadcast_to`.
- `app/models/approval_response.rb` — `after_create_commit :broadcasts_to_admin`, helpers
  `render_partial_html` (`ApplicationController.render(partial:, locals:, formats: [:html])`)
  e `turbo_stream_tag(action, target, html)`. A fase 30 pode usar `broadcast_replace_to`
  (Turbo helper de alto nível) em vez desse padrão manual — mais simples para stream por
  registro.
- `app/views/layouts/admin.html.erb:24` — `turbo_stream_from Current.user, channel:
  AdminNotificationsChannel if Current.user`. Padrão de assinatura de stream no layout; a
  fase 30 coloca o `turbo_stream_from [@client, @divulgacao]` na `divulgacoes/show.html.erb`,
  não no layout (é por-página).
- `app/jobs/whatsapp/send_to_group_job.rb` (fase 29) — `perform(group)` com claim atômico
  (`DivulgacaoGrupo.where(id:, status: :pendente).update_all(status: :enviado)`), revalidação
  `arte.approved?` / `instance&.connected?` / `divulgacao.status_cancelada?`, taxonomia de
  erro completa, `limits_concurrency to: 1, key: instance_id`, `self.finalize_divulgacao_if_done`.
  O `resend` da fase 30 reusa este job VERBATIM — só reseta a linha pra `pendente` antes.
- `app/jobs/divulgacoes/dispatch_job.rb` (fase 29) — não é tocado pela fase 30.
- `app/controllers/admin/divulgacoes_controller.rb` — `set_client` (`Client.find`),
  `set_divulgacao` (`@client.divulgacoes.find(params[:id])` → 404 cross-client),
  `#index` já paginado, `#show`, `#cancel` (member `patch :cancel`). A fase 30 adiciona a
  action `resend` (e o placar no `#index`).
- `app/views/admin/divulgacoes/_grupo_row.html.erb` — `<li>` com `case dg.status` e pills
  para `pendente/enviado/falhou/incerto` (paleta 28-UI-SPEC). Precisa: `id` no `<li>`, o
  `button_to "Reenviar"` condicional, `error_code`/`sent_at`.
- `app/views/admin/divulgacoes/_status_badge.html.erb` — pill por `divulgacao.status`
  (`agendada/em_andamento/concluida/cancelada`). Alvo de replace ao vivo.
- `app/views/admin/divulgacoes/show.html.erb` / `index.html.erb` / `_preview.html.erb` —
  telas da fase 28.
- Helper `divulgacao_datetime_label` (fase 28, pt-BR, fuso explícito "(BRT)") — usar para
  `sent_at`.
- `DivulgacaoGrupo` (`app/models/divulgacao_grupo.rb`) — `enum :status { pendente, enviado,
  falhou, incerto }`, `belongs_to :divulgacao, :whatsapp_group`, colunas `sent_at`,
  `error_code`, `evolution_message_id` (nullable, da fase 28).
- `Divulcagao` — `enum :status ..., prefix: :status`, `has_many :divulgacao_grupos, dependent:
  :destroy`, `cancelar!`.
- `config/recurring.yml` — já tem `production: clear_solid_queue_finished_jobs: { command:
  "SolidQueue::Job.clear_finished_in_batches(...)", schedule: every hour at minute 12 }`.
  A entrada de retenção de `failed_executions` segue essa forma, em prod + dev.
- `config/queue.yml` — worker dedicado `queues: whatsapp_sends` já existe (fase 29, INFRA-06).
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0` — fonte para confirmar
  `SolidQueue::FailedExecution` (tem `created_at`, `belongs_to :job`).

### Established Patterns
- Broadcast por `after_*_commit` no model, guardado por `saved_change_to_*?`.
- Turbo Streams sobre `solid_cable` (PostgreSQL, sem Redis) — v1.5.
- Escopo por associação: `@client.artes.find` / `@client.divulgacoes.find` →
  `RecordNotFound` → 404 para cross-client. Replicar em `resend`.
- `button_to` + `data: { turbo_confirm:, turbo_submits_with: }` para ações POST que mutam.
- `turbo_confirm` para ações perigosas (v1.3+).
- Controllers admin aninhados sob `resources :clients` com `before_action :set_client`.
- Pagy para listas (`Admin::BaseController` inclui `Pagy::Backend`).
- Testes: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test`
  (workaround de socket). Banco de teste pode pertencer a outro usuário do SO — verificar
  por inspeção quando `bin/rails test` não roda (ver memória `test_db_permission`).
- pt-BR em toda UI e prosa.
- Namespace `Whatsapp::` para jobs/serviços de WhatsApp.

### Integration Points
- `config/routes.rb` — nova member/nested `resend` sob `resources :divulgacoes` no
  `namespace :admin { resources :clients }`.
- `app/models/divulgacao_grupo.rb` — `after_update_commit` de broadcast por linha.
- `app/models/divulgacao.rb` — `after_update_commit` de broadcast de badge + resumo.
- `app/views/admin/divulgacoes/show.html.erb` — `turbo_stream_from [@client, @divulgacao]`,
  alvo `dom_id` da linha-resumo, `id` nas linhas.
- `app/views/admin/divulgacoes/_grupo_row.html.erb` — `id`, botão Reenviar, error_code, sent_at.
- `app/views/admin/divulgacoes/index.html.erb` — placar agregado por linha.
- `app/controllers/admin/divulgacoes_controller.rb` — action `resend`, `includes` no `#index`.
- `config/recurring.yml` — `prune_solid_queue_failed_executions` em prod + dev.
- `test/` — `cross_client_isolation_test.rb` (SEG-04) + teste de nome congelado (SC3).
- `.env.example` — documentar `SOLID_QUEUE_FAILED_RETENTION_DAYS` (se o repo mantém um).

</code_context>

<specifics>
## Specific Ideas

- O vocabulário dos rótulos é verbatim do DIVU-09: `Pendente`, `Enviado`, `Falhou`,
  `Incerto` — já nas pills do `_grupo_row`. `incerto` DEVE continuar visualmente distinto de
  `falhou` (amber vs vermelho, já é assim).
- O `error_code` mostrado no `#show` já vem sanitizado da fase 29 (`sanitize_error_code` —
  redige URL presignada / params de assinatura, trunca em 500). A fase 30 renderiza como está,
  NÃO re-sanitiza, NÃO expande.
- O teste SEG-04 é o "isolamento provado por teste" do goal — a suíte tem que FALHAR se a
  barreira quebrar. Não basta um teste que passa; ele tem que ser um teste que quebraria se
  alguém trocasse `@client.divulgacoes.find` por `Divulgacao.find`.
- A retenção (INFRA-07) existe porque `failed_executions` guarda os ARGUMENTOS do job em
  texto claro — e um `SendToGroupJob` falho carrega referência ao grupo/divulgação. Podar é
  a mitigação; não logar nada sensível na poda.
- Reenvio: a confirmação (`turbo_confirm`) tem que citar o NOME do grupo, não um id.
- Progresso ao vivo: "sem recarregar a página" (SC1) — se o admin deixar a `#show` aberta
  durante o disparo agendado, as linhas mudam sozinhas. Testável com um teste de sistema ou
  assertando o broadcast (`assert_broadcast_on`).

</specifics>

<deferred>
## Deferred Ideas

- Job recorrente *staggered* de sync de grupos de WhatsApp — mencionado pelas fases 27/29
  como "fase 30 / hardening", mas o ROADMAP da fase 30 não atribui GRUPO-* e o goal não pede.
  Fica para um milestone/fase futura de manutenção.
- Status "entregue" real via webhook `MESSAGES_UPDATE`/`DELIVERY_ACK` (DELIV-01) — future.
- Circuit breaker por instância após N falhas consecutivas (DELIV-02) — future.
- Reenvio em massa ("reenviar todos os que falharam de uma vez") — o v1.7 entrega reenvio
  por-grupo deliberado (a fricção protege o número). Reconsiderar só se a operação provar dor.
- Filtro/busca no histórico de Divulgações — volume baixo não justifica.
- Notificação (toast/e-mail) ao admin quando um disparo termina com falhas — backlog NOTF-*.
- Migrar o broadcast para `AdminNotificationsChannel` global se um dia o admin quiser ver
  progresso de disparo sem abrir a `#show` — hoje é por-página de propósito.

</deferred>
