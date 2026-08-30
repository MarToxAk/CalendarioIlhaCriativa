# Phase 27: Grupos do Cliente — Sync, Cache e Seleção Escopada - Context

**Gathered:** 2026-08-30
**Status:** Ready for planning

<domain>
## Phase Boundary

O admin sincroniza e enxerga os grupos reais do número de cada cliente, servidos de cache
local (a chamada `fetchAllGroups` é lenta demais para o request), e o modelo de escopo que
impede vazamento cross-client entre grupos fica estabelecido aqui.

Entrega: tabela `whatsapp_groups` (por instância), `Evolution::Client.fetch_groups`,
`Whatsapp::GroupSynchronizer` (PORO) + `SyncGroupsJob`, página
`admin/clients/:client_id/whatsapp_groups` com badge `announce`, marcador de inativo e
fallback de nome, e um componente de picker reutilizável escopado por instância que a
fase 28 (`Divulgacao`) vai embutir.

**Fora do escopo desta fase:** persistir a seleção de grupos (não existe `Divulgacao` ainda —
fase 28), enviar qualquer mensagem (fase 29), job recorrente de sync (fica pra fase 30 /
hardening — o ROADMAP só pede o sync manual aqui). A costura HTTP (`Evolution::Client`) e o
modelo `whatsapp_instance` já existem da fase 26.

</domain>

<decisions>
## Implementation Decisions

### Modelo de dados dos grupos

- `whatsapp_groups` `belongs_to :whatsapp_instance` (o grupo pertence ao número, não ao
  cliente diretamente). `Client has_many :whatsapp_groups, through: :whatsapp_instance`.
- Colunas: `whatsapp_instance_id`, `remote_jid` (`…@g.us`), `subject` (nullable), `announce`
  (boolean, default false), `active` (boolean, default true), `synced_at` (datetime),
  timestamps.
- `groups_synced_at` (datetime) adicionado ao `whatsapp_instances` — um carimbo por lote de
  sync, mostrado na tela ("sincronizado pela última vez em …"). `synced_at` por linha serve
  para detectar quais grupos NÃO vieram no último lote.
- Índice único `[whatsapp_instance_id, remote_jid]` — o upsert do synchronizer casa por
  esse par. `remote_jid` sozinho colidiria entre instâncias.

### Sincronização (trigger, job, robustez)

- Disparo: botão "Sincronizar grupos" no painel WhatsApp do cliente → enfileira
  `SyncGroupsJob` (solid_queue). `fetchAllGroups` é lento demais para rodar no request.
  Feedback via reload / polling de `groups_synced_at`.
- SEM job recorrente nesta fase — só o botão manual. Recorrência staggered fica pra fase 30 /
  hardening; o ROADMAP não pede aqui.
- Grupo sumido do WhatsApp: após o upsert do lote, os grupos da instância cujo `synced_at` é
  anterior ao início do lote viram `active: false` (`update_all`, nunca `delete`) — GRUPO-05.
  A linha e o histórico são preservados.
- Instância não conectada no momento do sync: `SyncGroupsJob` / o synchronizer aborta cedo
  com mensagem "instância não conectada — pareie antes de sincronizar", NÃO chama o Evolution.

### Tela de grupos e seleção escopada

- Nova página `admin/clients/:client_id/whatsapp_groups` (index): lista os grupos do cache
  com `groups_synced_at`, badge `announce` ("só admins enviam"), marcador visual de inativo,
  fallback de nome. Link a partir do painel WhatsApp do `clients#show`.
- Esta fase entrega a tela COM checkboxes + um partial/componente de picker reutilizável
  escopado por `whatsapp_instance`, que a fase 28 embute na `Divulgacao`. Esta fase NÃO
  persiste a seleção (não há `Divulgacao` ainda) — só prova que o escopo funciona.
- Enforcement do escopo (GRUPO-03 / SC5): SEMPRE server-side. O controller / finder parte de
  `@client.whatsapp_instance.whatsapp_groups`; um `group_id` de outro cliente levanta
  `ActiveRecord::RecordNotFound` (404) — nunca oferecido, nunca aceito. Mesmo padrão de
  `@client.artes.find` já usado no projeto.
- Grupos inativos: MOSTRADOS na tela, visualmente distintos ("inativo"), ao fim da lista, NÃO
  selecionáveis. Legíveis para o histórico (SC4), fora da escolha.

### Evolution::Client + contrato de dados

- Novo método: `Evolution::Client.fetch_groups(instance_name, api_key:)` →
  `GET /group/fetchAllGroups/{instance}?getParticipants=false` (a query `getParticipants` é
  OBRIGATÓRIA como string `"true"`/`"false"`, senão HTTP 400 — contrato verificado, tag
  2.3.7). `READ_TIMEOUT_FAST=15s`, mesma taxonomia `Evolution::Errors`. Espelha
  `fetch_instances` / `connection_state`.
- Chave usada: o token da INSTÂNCIA (`whatsapp_instance.token`), não a apikey global. Leitura
  de grupos é operação da instância pareada (contrato: token por instância para envio E
  leitura de grupo; a apikey global é só para ciclo de vida de instância).
- `subject` nulo / grupo sem nome: fallback no model —
  `display_name = subject.presence || "Grupo sem nome (#{remote_jid.first(12)}…)"`. Nunca um
  checkbox em branco (Pitfall documentado — Evolution issue #2124, `fetchAllGroups` retorna
  entradas com `subject` nulo de forma intermitente).
- `announce` ausente / `nil` no payload: tratar como `false` (grupo aberto). O sinal é
  aditivo ("só admins podem enviar"); a ausência não deve travar nem sinalizar.

### Claude's Discretion

- Forma exata do `SyncGroupsJob` (retry/backoff — seguir o precedente do solid_queue no
  projeto), e se ele usa `perform_later` direto do controller ou via um service.
- Como o feedback de "sync concluído" chega à tela (reload simples vs Turbo Stream vs polling
  do `groups_synced_at`) — seguir o que o UI-SPEC decidir.
- Nome/estrutura do partial de picker reutilizável e como a fase 28 vai referenciá-lo.
- Textos exatos (pt-BR), cores Tailwind dos estados (ativo/inativo/announce).
- Se `whatsapp_groups` ganha um `scope :selectable` (active + …) agora ou na fase 28.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Evolution::Client` (fase 25/26) — `request` privado já suporta query params via o bloco
  do Faraday; taxonomia `Evolution::Errors`; `READ_TIMEOUT_FAST=15s`. Adicionar
  `fetch_groups` espelhando `fetch_instances`.
- `WhatsappInstance` (fase 26) — `belongs_to :client`, `encrypts :token`, enum
  `connection_state`, `known_evolution_state?`. Adicionar `has_many :whatsapp_groups`,
  coluna `groups_synced_at`.
- `Admin::WhatsappInstancesController` + painel `_panel.html.erb` (fase 26) — o botão
  "Sincronizar grupos" e o link para a tela de grupos entram aqui.
- solid_queue já é o adapter (dev via bin/setup, prod via connects_to) — `SyncGroupsJob <
  ApplicationJob`.
- Padrão de escopo por associação: `@client.artes.find(...)` levanta `RecordNotFound` para
  cross-client — replicar com `@client.whatsapp_instance.whatsapp_groups.find(...)`.
- `.planning/research/ARCHITECTURE.md` §"Whatsapp::GroupSynchronizer" + §"subject nullable" +
  §"stagger SyncGroupsJob" — pesquisa de 4 agentes, consultar não reconstruir.
- `.planning/notes/evolution-contract.md` linha 38 — `fetchAllGroups` com `getParticipants`
  obrigatório; linha 67 — timeouts.
- Tailwind v4 puro, Stimulus/Turbo, Pagy para listas longas (precedente admin/approvals).

### Established Patterns
- Services PORO em `app/services/` para integração externa; `app/services/evolution/` já é o
  namespace (Client, InstanceProvisioner) — `Whatsapp::GroupSynchronizer` pode ir em
  `app/services/whatsapp/` (ARCHITECTURE.md propõe) ou `app/services/evolution/` — discrição.
- Segredos: token da instância vem de `whatsapp_instance.token` (já `encrypts`).
- Queries sempre escopadas por cliente / associação.
- Ações custom em resources admin via nested routes.
- `filter_parameter_logging.rb` já cobre `token`/`apikey`/`hash` (fase 26) — o synchronizer
  não deve logar o token nem o payload cru.

### Integration Points
- `config/routes.rb` — `resources :clients do resources :whatsapp_groups, only: [:index] ... end`
  no namespace admin (+ member/collection para o botão de sync).
- `admin/clients/_panel.html.erb` (WhatsApp) — botão "Sincronizar grupos" + link "Ver grupos".
- `app/models/whatsapp_instance.rb` — `has_many :whatsapp_groups`, `groups_synced_at`.
- Migração: `create_whatsapp_groups` + `add_column :whatsapp_instances, :groups_synced_at`.
- Fase 28 (`Divulgacao`) vai consumir o partial de picker e o escopo `@client...whatsapp_groups`.

</code_context>

<specifics>
## Specific Ideas

- O `synced_at` por linha DEVE ser gravado no upsert com o timestamp do início do lote (ou
  `Time.current` no momento do upsert), e a passada de desativação usa `where("synced_at < ?",
  batch_started_at)` — nunca comparar conjuntos de JID em memória (frágil com lotes grandes).
- O picker escopado é a peça que "prova o modelo de escopo cross-client" do goal — o teste
  canônico da fase é: um POST/GET de seleção com um `whatsapp_group.id` que pertence a OUTRO
  cliente → 404, sem vazar existência.
- `fetch_groups` deve passar `getParticipants=false` SEMPRE (não precisamos de participantes
  nesta fase; `getParticipants=true` é muito mais lento e some risco de timeout).

</specifics>

<deferred>
## Deferred Ideas

- Job recorrente staggered de sync de grupos — fase 30 / hardening.
- `getParticipants=true` / contagem de participantes / lista de admins do grupo — só se uma
  fase futura precisar (ex: validar que a instância é admin antes de enviar).
- Persistir a seleção de grupos numa tabela — fase 28 (`Divulgacao`).
- Cache com TTL / invalidação automática — não; o cache é a tabela, atualizada só pelo sync
  manual nesta fase.

</deferred>
