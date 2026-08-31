# Phase 31: Instância WhatsApp Compartilhada entre Clientes - Context

**Gathered:** 2026-08-31
**Status:** Ready for planning
**Mode:** Discussão direta (usuário respondeu em prosa, sem menu estruturado) + 1 decisão técnica delegada explicitamente a Claude ("Oque achar melhor")

<domain>
## Phase Boundary

Hoje "uma instância Evolution por cliente" é uma decisão TRAVADA e já implementada do
v1.7 (PROJECT.md, REQUIREMENTS.md PAIR-01/02) — cada cliente cria/pareia seu próprio
número. Esta fase ADICIONA uma segunda forma de provisionar: apontar um cliente para
uma instância Evolution **já conectada**, reaproveitada por **mais de um cliente**
simultaneamente (caso de uso real do usuário: um número de WhatsApp de **marketing da
agência**, usado para vários clientes ao mesmo tempo). O fluxo de "criar + parear com
QR" (PAIR-01/02) continua existindo e disponível — a instância compartilhada é uma
OPÇÃO adicional, não uma substituição.

Entrega: opção "reutilizar conexão existente" no fluxo de provisionamento de WhatsApp
do cliente, ajuste da trava de concorrência de envio para não permitir disparos
paralelos na MESMA conexão física quando compartilhada entre clientes, e ajuste da
sincronização de grupos para não repetir a mesma chamada lenta ao Evolution uma vez
por cliente quando eles compartilham a mesma instância física.

**Fora do escopo desta fase:** qualquer UI de curadoria "este grupo pertence ao
Cliente X" — decisão do usuário (ver `<decisions>`) é que isso NÃO é necessário; a
seleção de grupos continua acontecendo do jeito que já funciona hoje (admin escolhe
grupos na hora de criar cada Divulgação, GRUPO-03, inalterado). Também fora de escopo:
revogação/rotação de token por cliente individual dentro de uma instância
compartilhada (ver `<deferred>`).

</domain>

<decisions>
## Implementation Decisions

### Caso de uso e escopo real

- **D-01:** É um número de WhatsApp de marketing da agência, reutilizado por mais de
  um cliente ao mesmo tempo — não é um caso raro de "recuperar depois de erro", é um
  modo de operação normal e esperado.
- **D-02:** A seleção de grupos por Divulgação continua EXATAMENTE como hoje (GRUPO-03:
  admin escolhe grupos na hora de criar a Divulgação, a partir do cache local do
  cliente). Não existe etapa nova de "atribuir este grupo ao Cliente X" — o usuário
  confirmou isso explicitamente ("Seleciona os grupos na hora que nem faz hoje").
  — **Reversibility:** reversible — é uma decisão de escopo, não de schema.

### Modelo de dados — instância compartilhada

- **D-03:** Mantém `Client has_one :whatsapp_instance` (SEM redesenho de relação para
  N-para-N). "Reutilizar" significa: ao provisionar WhatsApp para um NOVO cliente, o
  admin pode apontar para o `instance_name` (e `token`) de uma instância JÁ conectada
  em vez de sempre chamar `Evolution::Client.create_instance` para um número novo. Isso
  cria uma NOVA linha `WhatsappInstance` (o cliente novo continua tendo "a sua"
  instância, própria linha, próprio `whatsapp_groups` cache, próprio `groups_synced_at`)
  cujo `instance_name`/`token` são CÓPIAS dos valores de uma instância irmã já
  conectada, e `connection_state`/`paired_at` são copiados como já conectados (sem
  necessidade de QR).
  — **Reversibility:** reversible para desfazer a feature em si (é aditivo); **costly**
  se um dia for preciso migrar de "N linhas com token duplicado" para uma relação
  N-para-N de verdade — precisaria de uma migração de dados + reescrever toda leitura
  que hoje assume `client.whatsapp_instance` como uma linha só (32 arquivos usam essa
  cadeia).
- **D-04 (decisão técnica delegada — "Oque achar melhor"):** A trava de concorrência de
  envio (`Whatsapp::SendToGroupJob.limits_concurrency`, hoje `key: ->(group) {
  group.divulgacao.client.whatsapp_instance&.id || ... }`) muda a chave de
  `whatsapp_instance.id` para `whatsapp_instance.instance_name`. Motivo: com instância
  compartilhada, dois clientes diferentes têm LINHAS diferentes (`id` diferente) mas a
  MESMA conexão física (`instance_name` igual) — travar por `id` deixaria dois envios
  simultâneos passarem pela mesma sessão Evolution/Baileys ao mesmo tempo, exatamente o
  que ENVIO-09 foi desenhado para impedir (risco de rate-limit/ban). Travar por
  `instance_name` serializa corretamente TODOS os clientes que compartilham a mesma
  conexão física, sem exigir redesenho de schema. Alternativa descartada: consolidar
  numa única linha `WhatsappInstance` compartilhada (N-para-N de verdade) — resolveria
  o mesmo problema "de graça", mas exigiria reescrever a relação usada em 32 arquivos e
  os testes de isolamento (SEG-02/03/04); desproporcional ao pedido do usuário.
  — **Reversibility:** reversible — é uma troca de string na `key:` do
  `limits_concurrency`, sem migração.
- **D-05 (decorre de D-03, decisão técnica de Claude):** `Whatsapp::GroupSynchronizer`
  hoje sincroniza escopado por UMA `@instance` (`app/services/whatsapp/group_synchronizer.rb`).
  Com instância física compartilhada, sincronizar independentemente para cada cliente
  repetiria a MESMA chamada lenta `fetchAllGroups` (confirmado empiricamente nesta sessão:
  ~40s para uma conta com 64 grupos, timeout dedicado de 60s) uma vez por cliente que
  compartilha o número — desperdício de tempo/carga no Evolution, e os caches dos
  clientes-irmãos podem ficar dessincronizados entre si (grupo aparece pra um, não pro
  outro, mesma conta física). Decisão: ao sincronizar UMA instância, o
  `GroupSynchronizer` busca todas as `WhatsappInstance` que compartilham o mesmo
  `instance_name` (irmãs) e faz upsert dos grupos retornados em `whatsapp_groups`
  escopado a CADA UMA delas (uma chamada Evolution, N upserts locais — um por
  instância-irmã, cada um com seu próprio `whatsapp_instance_id`). O gate GRUPO-05
  (grupo sumido → `active: false`) roda por instância-irmã, com o MESMO batch/timestamp
  de referência para todas.
  — **Reversibility:** costly de reverter — muda o contrato interno do
  `GroupSynchronizer` (hoje 1 instância por chamada); planner deve isolar essa mudança
  numa task própria com teste de regressão explícito comparando o comportamento
  single-instance (não-compartilhada) antes/depois.

### Fluxo de UI

- **D-06:** Na seção "WhatsApp" do `admin/clients#show` (onde hoje vive o fluxo QR da
  fase 26), adicionar um toggle "Novo número (QR)" vs "Reutilizar conexão existente" —
  mesmo padrão visual/Stimulus já usado no toggle `media_source` de
  `admin/artes/_form.html.erb` (`data-controller="media-type-toggle"`, radio com `sr-only`
  + label clicável). Ao escolher "Reutilizar", mostrar um `<select>` com os
  `instance_name` distintos já conectados na agência (rótulo indicando quais clientes já
  usam cada um, ex.: "Marketing Principal — usado por: Cliente A, Cliente B"). Escolher
  um e confirmar cria a `WhatsappInstance` do cliente novo copiando
  `instance_name`/`token`/`connection_state`/`paired_at` da instância-irmã escolhida —
  SEM chamar `create_instance` nem mostrar QR (já está conectada).
  — **Reversibility:** reversible.
- **D-07:** O fluxo "Novo número (QR)" (PAIR-01/02, fase 26) permanece disponível e
  inalterado — a nova opção é aditiva, nunca substitui o fluxo existente.

### Claude's Discretion

- Nome exato do Stimulus controller/toggle da UI de D-06 (reaproveitar
  `media-type-toggle` ou criar um análogo dedicado).
- Texto exato pt-BR do rótulo/aviso explicando que "reutilizar" significa MESMO número
  físico, MESMA sessão WhatsApp, compartilhada com outro(s) cliente(s) — deixar isso
  visualmente claro pro admin evitar engano.
- Exigir confirmação explícita (`turbo_confirm`) ao escolher reutilizar, dado que é uma
  ação que expõe o número a mais tráfego/risco de rate-limit compartilhado.
- Onde exatamente na `WhatsappInstance` marcar "é uma cópia compartilhada" (coluna nova
  tipo `shared: boolean` vs apenas inferir por `instance_name` duplicado entre linhas)
  — útil para a UI de D-06 listar "quem já usa" sem um `GROUP BY instance_name` toda
  hora, mas não é uma decisão que o usuário precisa tomar.
- Se o `admin/clients#show` deve avisar visualmente (badge "compartilhada com N
  clientes") quando a instância do cliente atual não é exclusiva dele.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Decisões travadas do milestone v1.7 (não reabrir)
- `.planning/PROJECT.md` (linha ~29-33, ~201-206) — Goal do milestone v1.7 e decisões
  travadas; "uma instância Evolution por cliente" era a linha-base ANTES desta fase —
  esta fase estende, não contradiz (D-03 mantém `has_one`).
- `.planning/REQUIREMENTS.md` (PAIR-01..08, GRUPO-01..05, SEG-01..04) — requisitos já
  implementados que esta fase precisa preservar intocados.

### Fases anteriores diretamente relevantes
- `.planning/phases/26-inst-ncia-de-whatsapp-por-cliente-pareamento/26-CONTEXT.md` —
  modelo de dados original da `WhatsappInstance` (`instance_name = livia_client_<id>`,
  token encrypted, fluxo de adoção "already in use", webhook por instância).
- `.planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/27-CONTEXT.md` —
  `whatsapp_groups belongs_to :whatsapp_instance`, `Client has_many :whatsapp_groups,
  through: :whatsapp_instance`, contrato do `GroupSynchronizer`/`SyncGroupsJob` que a
  D-05 desta fase precisa estender sem quebrar.
- `.planning/phases/29-motor-de-envio/` (SUMMARY/PLAN) — `Whatsapp::SendToGroupJob`,
  `limits_concurrency` (ENVIO-09), taxonomia de erro, `finalize_divulgacao_if_done`.
- `.planning/phases/30-acompanhamento-ao-vivo-hardening/30-CONTEXT.md` — teste SEG-04
  de isolamento cross-client (`test/integration/cross_client_isolation_test.rb`) —
  DEVE continuar passando sem alteração após esta fase (D-03 preserva a cadeia de
  resolução `@client.whatsapp_instance.whatsapp_groups` que o teste verifica).

### Contrato empírico Evolution API
- `.planning/notes/evolution-contract.md` — timeouts, shape de resposta, comportamento
  real do host verificado empiricamente.
- `app/services/evolution.rb` / `app/services/evolution/client.rb` — inclui
  `READ_TIMEOUT_GROUPS` (60s, corrigido nesta mesma sessão, quick/260831-gai) — D-05
  reaproveita esse timeout para a chamada única de sync compartilhado.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/services/evolution/instance_provisioner.rb` — fluxo de criação/adoção de
  instância (fase 26). D-06 adiciona um MÉTODO NOVO (algo como `.reuse(existing:,
  client:)`) ao lado de `#call`/`#adopt`, não modifica os existentes.
- `app/services/whatsapp/group_synchronizer.rb` — hoje `initialize(instance, client_api:)`
  + `#call` escopado a UMA instância. D-05 precisa expandir o escopo para "instância +
  suas irmãs" — decisão de design: o synchronizer passa a receber a lista de instâncias
  irmãs, ou resolve sozinho via `WhatsappInstance.where(instance_name: instance.instance_name)`.
- `app/jobs/whatsapp/send_to_group_job.rb` — `limits_concurrency to: 1, key: ->(group) {...}`
  (linhas ~57-61) — D-04 troca a resolução da chave para `instance_name`.
- `app/views/admin/artes/_form.html.erb` (`data-controller="media-type-toggle"`) —
  padrão de toggle radio + campos condicionais que D-06 replica para "Novo número" vs
  "Reutilizar conexão".
- `app/controllers/admin/whatsapp_instances_controller.rb` (ou equivalente da fase 26,
  confirmar nome exato) — fluxo de criação/adoção atual, ponto de entrada pra nova
  action/branch de "reutilizar".

### Established Patterns
- Services PORO em `app/services/` para integração externa, módulo de erros aninhado
  (`Evolution::Errors::*`).
- `secure_compare` / dados sensíveis nunca logados (token, apikey).
- Queries sempre escopadas por cliente — D-03/D-04 preservam esse padrão (cada cliente
  continua com sua própria linha e cadeia `client.whatsapp_instance`).
- `after_update_commit` + `saved_change_to_status?` para broadcasts ao vivo (fase 30) —
  não afetado por esta fase.

### Integration Points
- `app/services/evolution/instance_provisioner.rb` — novo método de reuso.
- `app/services/whatsapp/group_synchronizer.rb` — escopo expandido pra instâncias-irmãs.
- `app/jobs/whatsapp/sync_groups_job.rb` — nenhuma mudança de assinatura esperada, só o
  que o synchronizer faz por dentro.
- `app/jobs/whatsapp/send_to_group_job.rb` — chave do `limits_concurrency`.
- `app/views/admin/clients/show.html.erb` (seção WhatsApp) — novo toggle + select de
  instâncias existentes.
- `app/models/whatsapp_instance.rb` — nenhuma mudança de enum/coluna obrigatória por
  esta fase (D-03 não pede migração), mas ver "Claude's Discretion" sobre um possível
  campo auxiliar.

</code_context>

<specifics>
## Specific Ideas

- "Vai ser um numero de whatsapp de markting para mais de um cliente" — caso de uso
  real e concreto do usuário, não hipotético; a fase deve ser desenhada pensando nisso
  como uso NORMAL, não como exceção.
- "Seleciona os grupos na hora que nem faz hoje" — reafirma GRUPO-03 como está; a fase
  30-CONTEXT já documentou esse fluxo (picker escopado por instância) como estável.
- "mais gostaria da opção de conectar uma conta ainda" — confirma que o fluxo QR
  (PAIR-01/02) precisa continuar existindo lado a lado com a opção nova.

</specifics>

<deferred>
## Deferred Ideas

- Revogação/rotação de token por cliente individual dentro de uma instância
  compartilhada (hoje: rotacionar о token da instância física afeta TODOS os clientes
  que a compartilham — comportamento aceito implicitamente, mas não foi discutido a
  fundo). Reconsiderar se a agência precisar revogar acesso de UM cliente sem afetar
  os outros que compartilham o mesmo número.
- Badge/indicador visual "esta instância é compartilhada com N clientes" na
  `admin/clients#index` ou `#show` — mencionado em Claude's Discretion, pode virar seu
  próprio polish se o planner achar que não cabe no orçamento desta fase.
- Consolidar o modelo de dados para N-para-N de verdade (uma única linha
  `WhatsappInstance` para múltiplos clientes) — descartado nesta fase (D-03/D-04
  escolhem a alternativa de menor blast radius), mas fica registrado como opção futura
  se a duplicação de token entre linhas-irmãs se provar operacionalmente dolorosa.

### Reviewed Todos (not folded)
None — discussion stayed within phase scope (nenhum todo pendente encontrado para a
fase 31 via `gsd_run query todo.match-phase`).

</deferred>

---

*Phase: 31-Instância WhatsApp Compartilhada entre Clientes*
*Context gathered: 2026-08-31*
