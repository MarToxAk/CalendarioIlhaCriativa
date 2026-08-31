# Phase 31: Instância WhatsApp Compartilhada entre Clientes — Research

**Researched:** 2026-08-31
**Domain:** Rails 8.1 / Evolution API (Baileys) / SolidQueue 1.4.0 concurrency controls / Stimulus toggle UI / redesenho de fronteira de isolamento por-instância → por-conexão-física
**Confidence:** HIGH (todo o código relevante foi lido nesta sessão; nenhum pacote novo; nenhuma API externa nova)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** É um número de WhatsApp de marketing da agência, reutilizado por mais de um cliente ao mesmo tempo — modo de operação normal e esperado, não exceção de recuperação.
- **D-02:** A seleção de grupos por Divulgação continua EXATAMENTE como hoje (GRUPO-03). Não existe etapa nova de "atribuir este grupo ao Cliente X". Reversível (decisão de escopo).
- **D-03:** Mantém `Client has_one :whatsapp_instance` (SEM redesenho para N-para-N). "Reutilizar" = ao provisionar WhatsApp para um NOVO cliente, criar uma NOVA linha `WhatsappInstance` cujo `instance_name`/`token` são CÓPIAS de uma instância-irmã já conectada, com `connection_state`/`paired_at` copiados como já conectados (sem QR, sem `create_instance`). Cada cliente continua com sua própria linha, próprio cache `whatsapp_groups`, próprio `groups_synced_at`. Reversível para desfazer a feature (aditiva); **costly** para migrar depois para N-para-N de verdade (32 arquivos usam a cadeia `client.whatsapp_instance`).
- **D-04 (delegada a Claude):** `Whatsapp::SendToGroupJob.limits_concurrency` muda a chave de `whatsapp_instance.id` para `whatsapp_instance.instance_name`. Serializa TODOS os clientes que compartilham a mesma conexão física (intenção do ENVIO-09). Reversível — troca de string na `key:`, sem migração.
- **D-05 (decorre de D-03):** `Whatsapp::GroupSynchronizer`, ao sincronizar UMA instância, resolve todas as `WhatsappInstance` irmãs (mesmo `instance_name`) e faz upsert dos grupos retornados escopado a CADA UMA (uma chamada Evolution `fetchAllGroups`, N upserts locais). O gate GRUPO-05 (grupo sumido → `active: false`) roda por irmã com o MESMO `batch_started_at`. **Costly de reverter** — muda o contrato interno do `GroupSynchronizer`; planner DEVE isolar numa task própria com teste de regressão explícito comparando o comportamento single-instance (não-compartilhada) antes/depois.
- **D-06:** Na seção "WhatsApp" do `admin/clients#show`, adicionar toggle "Novo número (QR)" vs "Reutilizar conexão existente" — mesmo padrão visual/Stimulus do toggle `media_source` de `admin/artes/_form.html.erb`. "Reutilizar" mostra um `<select>` com os `instance_name` distintos já conectados (rótulo indicando quais clientes já usam cada um). Escolher + confirmar cria a `WhatsappInstance` do cliente novo copiando `instance_name`/`token`/`connection_state`/`paired_at` da irmã escolhida. Reversível.
- **D-07:** O fluxo "Novo número (QR)" (PAIR-01/02, fase 26) permanece disponível e inalterado — a nova opção é aditiva, nunca substitui.

### Claude's Discretion

- Nome exato do Stimulus controller/toggle de D-06 (reaproveitar `media-type-toggle` ou criar análogo dedicado).
- Texto exato pt-BR do rótulo/aviso explicando que "reutilizar" = MESMO número físico, MESMA sessão, compartilhada com outro(s) cliente(s).
- Exigir confirmação explícita (`turbo_confirm`) ao escolher reutilizar.
- Onde marcar "é uma cópia compartilhada" na `WhatsappInstance` (coluna `shared: boolean` vs inferir por `instance_name` duplicado).
- Se `admin/clients#show` deve mostrar badge "compartilhada com N clientes".

### Deferred Ideas (OUT OF SCOPE)

- Revogação/rotação de token por cliente individual dentro de uma instância compartilhada (rotacionar o token físico afeta TODOS os irmãos — aceito implicitamente).
- Badge/indicador "compartilhada com N clientes" na `admin/clients#index` (pode virar polish próprio).
- Consolidar o modelo para N-para-N de verdade (uma única linha `WhatsappInstance` para múltiplos clientes) — descartado nesta fase.
- Qualquer UI de curadoria "este grupo pertence ao Cliente X".
</user_constraints>

---

<phase_requirements>
## Phase Requirements

Requirements da fase: **TBD / nenhum requisito novo mapeado**. Esta fase é ADITIVA e não fecha requisito v1.7 novo. O que ela precisa **preservar intacto** (todos já `[x]` em REQUIREMENTS.md ou pendentes na fase 29):

| ID | Descrição | Como esta fase o afeta / suporte de research |
|----|-----------|----------------------------------------------|
| PAIR-01/02 | Admin cria / adota instância | `[VERIFIED: app/services/evolution/instance_provisioner.rb]` — fluxo `#call`/`#adopt` **não é modificado**; a reutilização é um método novo `.reuse` ao lado (D-07). |
| PAIR-03/04/07/08 | QR, estado de conexão, avisos de banimento | `[VERIFIED: app/views/admin/whatsapp_instances/_panel.html.erb]` — toda a UI de QR fica no branch `whatsapp_instance.present?`; o toggle novo entra só no branch `nil?` (empty-state). |
| PAIR-06 | Webhook autenticado por `secure_compare` | `[VERIFIED: app/controllers/webhooks/evolution_controller.rb:15]` — `find_by(instance_name:)` retorna UMA irmã; ver Pitfall 1 (fan-out do webhook). |
| GRUPO-01..05 | Sync, cache local, seleção escopada, `announce`, desativação | `[VERIFIED: app/services/whatsapp/group_synchronizer.rb]` — D-05 fan-out; GRUPO-05 roda por irmã com o mesmo `batch_started_at`. |
| ENVIO-09 | Envios de uma mesma instância serializados | `[VERIFIED: app/jobs/whatsapp/send_to_group_job.rb:57-61]` — D-04 troca a chave para `instance_name`. |
| ENVIO-07 | Estado da conexão verificado antes de cada envio; desconectada nunca registrada como enviada | `[VERIFIED: send_to_group_job.rb:146-151]` — guard `instance&.connected?` lê a linha do cliente; ver Pitfall 1 (rows-irmãs desatualizadas). |
| SEG-01..04 | Isolamento cross-client (arte de A nunca alcança grupo de B) | `[VERIFIED: test/integration/cross_client_isolation_test.rb]` — todas as asserções continuam verdes com D-03 (linhas distintas, `id` distinto, `has_one` por cliente preservado). Ver Focus Area 3. |
</phase_requirements>

---

## Summary

Esta fase **não introduz nenhuma dependência nova, nenhum endpoint Evolution novo e nenhuma capacidade de IA**. É um redesenho cirúrgico de fronteira: hoje `instance_name` é único (1 linha `WhatsappInstance` ⇔ 1 conexão física ⇔ 1 cliente); depois desta fase, N linhas podem apontar para a mesma conexão física (`instance_name`/`token` idênticos), **mantendo** `Client has_one :whatsapp_instance` (cada cliente ainda tem exatamente uma linha, com `id` próprio e cache de grupos próprio). O isolamento cross-client (SEG-04) continua ancorado no `id` da linha e nas associações escopadas por cliente — **não** no `instance_name` — então ele sobrevive sem mudança de teste.

Três pontos de código mudam de "por linha" para "por conexão física": (1) a chave do `limits_concurrency` do `SendToGroupJob` (D-04, troca de string, um teste de regressão a ajustar); (2) o `GroupSynchronizer` faz fan-out de uma chamada `fetchAllGroups` para N upserts locais (D-05, contrato interno, task isolada + teste antes/depois); (3) um método novo `Evolution::InstanceProvisioner#reuse` que copia campos de uma irmã sem tocar a Evolution. A UI ganha um toggle Stimulus no empty-state do painel de WhatsApp do cliente.

**O único bloqueio técnico real:** o índice UNIQUE em `whatsapp_instances.instance_name` (`db/schema.rb:284`) impede uma segunda linha com o mesmo nome. Uma migração para trocar esse índice por não-único é **obrigatória** — a nota do CONTEXT "nenhuma mudança de coluna obrigatória" está incorreta nesse detalhe (é mudança de índice, não de coluna; migração de baixo risco, sem alteração de dados).

**Primary recommendation:** 4 tasks — (T1) migração drop+recreate índice `instance_name` como não-único + `origin` enum ganha `reused_sibling` + `WhatsappInstance` scopes/helpers de resolução de irmãs; (T2) `InstanceProvisioner#reuse` + action `reuse` no controller + toggle Stimulus no `_panel`; (T3, isolada) fan-out do `GroupSynchronizer` para irmãs + teste de regressão single-instance; (T4) `SendToGroupJob` chave `instance_name` + ajuste do teste + fan-out do webhook `connection.update` para irmãs (preserva ENVIO-07). COVERAGE.md re-decide a superfície Evolution (zero endpoints novos) e registra o delta de suposição singular→plural.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Provisionar WhatsApp reutilizando conexão | API / Backend (`Evolution::InstanceProvisioner#reuse`, PORO) | — | Cópia de linha local; nenhuma chamada externa. Mesmo tier do `#call`/`#adopt` atual. |
| Toggle "Novo número" vs "Reutilizar" | Browser / Client (Stimulus controller) | Frontend Server (ERB `_panel` + `ClientsController#show` monta a coleção) | Idêntico ao toggle `media_source` de arte — comportamento puramente client-side de mostrar/ocultar campos; o servidor só resolve a lista de alvos e processa o POST. |
| Serialização de envio por conexão física | Background jobs (SolidQueue semáforo) | Database (`solid_queue_semaphores`, runtime, sem schema) | `limits_concurrency` é avaliado no enqueue/execução; a chave nova é `instance_name`. |
| Fan-out de sincronização de grupos | API / Backend (`Whatsapp::GroupSynchronizer`, PORO em background job) | Database (N `upsert_all` locais) | Uma leitura Evolution cara (~40s), N escritas locais baratas — a orquestração fica no PORO, não no job. |
| Coerência de estado de conexão entre irmãs | API / Backend (`Webhooks::EvolutionController`) | — | Um webhook `connection.update` do Evolution descreve a conexão física; deve refletir em todas as linhas-irmãs. |
| Fronteira de isolamento cross-client | Database + Model (associações escopadas por `client_id` / `whatsapp_instance_id`) | Controller (`.find` escopado) | **Inalterada** — ancorada no `id` da linha, não no `instance_name`. |

---

## Standard Stack

### Core (tudo já no projeto — nenhuma instalação)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails | 8.1.3 | Framework, ActiveRecord `encrypts`, ActiveJob, enums | Base do projeto. `[VERIFIED: Gemfile.lock]` (STATE.md refs "Rails 8.1.3"). |
| solid_queue | 1.4.0 | Fila + `limits_concurrency` (ENVIO-09) | `[VERIFIED: Gemfile.lock:384]` `solid_queue (1.4.0)`. Semáforos via `solid_queue_semaphores`. |
| @hotwired/stimulus + stimulus-loading | (importmap) | Toggle client-side (D-06) | `[VERIFIED: app/javascript/controllers/index.js]` — `eagerLoadControllersFrom("controllers", application)`; um `*_controller.js` novo é auto-registrado por convenção de nome, sem editar `index.js`. |
| faraday | (existente) | `Evolution::Client` transporte HTTP | `[VERIFIED: app/services/evolution/client.rb:24]` — conexão memoizada, timeouts explícitos. Nenhuma rota nova nesta fase. |
| turbo-rails | (existente) | `turbo_confirm` / `turbo_submits_with` no botão de reutilizar | `[VERIFIED: app/views/admin/whatsapp_instances/_panel.html.erb:59-61,68-69]` — `data: { turbo_submits_with: ... }` já em uso. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Rails `encrypts` (active_record_encryption) | Rails 8.1 | `token` cifrado em repouso | Já configurado desde a fase 26. Copiar `existing.token` para a linha nova é transparente (lê decifrado, grava re-cifrado). `[VERIFIED: app/models/whatsapp_instance.rb:12]` `encrypts :token`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| N linhas com `token` duplicado (D-03) | Uma linha `WhatsappInstance` N-para-N | Resolveria D-04/D-05 "de graça", mas exige reescrever a cadeia `client.whatsapp_instance` em ~18 arquivos / ~62 call-sites `[VERIFIED: grep app/ lib/]` e os testes SEG-02/03/04. **Descartado por D-03/D-04.** |
| Novo Stimulus controller dedicado | Reusar `media_type_toggle_controller.js` | Ver "Common Pitfalls / Discretion" abaixo — recomendação: **controller novo dedicado**. |
| Coluna `shared:boolean` | Inferir por `instance_name` duplicado | Ver "Open Questions Q3" — recomendação: **nem uma nem outra como flag**; usar `origin: :reused_sibling` (enum já existe, valor novo é code-only) + um scope `WhatsappInstance.where(instance_name: x)` para "quem usa". |

**Installation:** nenhuma. `Package Legitimacy Audit`: **N/A — esta fase não instala nenhum pacote.**

---

## Architecture Patterns

### System Architecture Diagram — fluxo de reutilização (D-03/D-06)

```
Admin em /admin/clients/:id (cliente SEM instância)
        │
        ▼
 _panel.html.erb (branch whatsapp_instance.nil?)
   ┌─ radio "Novo número (QR)"  ──► POST .../whatsapp_instance  ──► WhatsappInstancesController#create
   │                                                                    └─► InstanceProvisioner#call  ──► Evolution POST /instance/create ──► QR
   │
   └─ radio "Reutilizar conexão existente"
         │  <select> de instance_name distintos CONECTADOS (rótulo = clientes que já usam)
         │  [data-controller="whatsapp-provision-toggle"]  (mostra/oculta <select>, habilita submit)
         ▼
      POST .../whatsapp_instance/reuse  { source_instance_name }  [turbo_confirm]
         │
         ▼
   WhatsappInstancesController#reuse
      set_client → Client.find(params[:client_id])
      alvo = WhatsappInstance.where(connection_state: :connected)
                             .where.not(client_id: @client.id)
                             .find_by(instance_name: params[:source_instance_name])   # NUNCA .find(id) cru
         │
         ▼
   Evolution::InstanceProvisioner.new(@client).reuse(existing: alvo)
      WhatsappInstance.create!(
        client:            @client,
        instance_name:     alvo.instance_name,     # CÓPIA — aponta pra mesma conexão física
        token:             alvo.token,             # CÓPIA — encrypts transparente
        connection_state:  alvo.connection_state,  # :connected
        paired_at:         alvo.paired_at,
        remote_instance_id: alvo.remote_instance_id,
        origin:            :reused_sibling,
        last_checked_at:   Time.current)
      # SEM create_instance, SEM connect, SEM QR, SEM set_webhook (webhook físico já aponta pra cá)
         │
         ▼
   redirect_to admin_client_path(@client), notice: "Conexão reutilizada. Sincronize os grupos deste cliente."
```

### System Architecture Diagram — fan-out de sync de grupos (D-05)

```
Admin clica "Sincronizar grupos" em /admin/clients/A/whatsapp_groups
        │
        ▼
 WhatsappGroupsController#sync  (guards: connected? / groups_sync_syncing? / cache 15s)
   A.whatsapp_instance.update!(groups_sync_state: :syncing)
   Whatsapp::SyncGroupsJob.perform_later(A.whatsapp_instance)      # assinatura INALTERADA
        │
        ▼
 SyncGroupsJob#perform(instance_A)  ──►  Whatsapp::GroupSynchronizer.new(instance_A).call
        │
        ▼
 GroupSynchronizer#call
   guard instance_A.connected?
   batch_started_at = Time.current
   raw = Evolution::Client.fetch_groups(instance_A.instance_name, api_key: instance_A.token)   # 1 chamada, READ_TIMEOUT_GROUPS=60s, ~40s
   irmas = WhatsappInstance.where(instance_name: instance_A.instance_name)   # inclui instance_A; hoje = [instance_A]
        │
        ├── para instance_A:  rows(whatsapp_instance_id: A.id) → upsert_all → GRUPO-05(synced_at < batch_started_at → active:false) → A.update!(groups_synced_at: batch_started_at, idle)
        ├── para instance_B:  rows(whatsapp_instance_id: B.id) → upsert_all → GRUPO-05 (mesmo batch_started_at) → B.update!(...)
        └── para instance_C:  idem
   Result(ok: true, count: rows.size)
```

### Recommended Project Structure (arquivos tocados — nenhum diretório novo)

```
db/migrate/               # 1 migração: índice instance_name unique → não-único
app/models/whatsapp_instance.rb       # enum origin += :reused_sibling ; scopes de resolução de irmãs
app/services/evolution/instance_provisioner.rb   # + método #reuse(existing:)
app/services/whatsapp/group_synchronizer.rb      # #call: loop sobre irmãs (D-05) — TASK ISOLADA
app/jobs/whatsapp/send_to_group_job.rb           # key: instance_name (D-04)
app/controllers/webhooks/evolution_controller.rb # fan-out connection.update p/ irmãs
app/controllers/admin/whatsapp_instances_controller.rb  # + action #reuse
app/controllers/admin/clients_controller.rb      # #show: monta @reusable_targets
config/routes.rb          # + post :reuse no resource :whatsapp_instance
app/views/admin/whatsapp_instances/_panel.html.erb     # toggle no branch nil?
app/javascript/controllers/whatsapp_provision_toggle_controller.js   # NOVO
test/... (ver Validation abaixo)
```

### Pattern 1: Chave de concorrência resolvida no enqueue/execução (D-04)

**What:** `limits_concurrency key:` é um proc avaliado por `instance_exec(*arguments, &proc)` — os `arguments` do job são `[group]` (um `DivulgacaoGrupo`).
**When to use:** Trocar `&.id` por `&.instance_name` na cadeia.
**Example:**
```ruby
# Source: app/jobs/whatsapp/send_to_group_job.rb:57-61 (ATUAL) — [VERIFIED]
limits_concurrency to: 1,
  key: ->(group) {
    group.divulgacao.client.whatsapp_instance&.id ||
      "send_to_group:no_instance:#{group.id}"
  }

# DEPOIS (D-04) — instance_name é t.string null:false, sempre presente [VERIFIED: db/schema.rb:274]
limits_concurrency to: 1,
  key: ->(group) {
    group.divulgacao.client.whatsapp_instance&.instance_name ||
      "send_to_group:no_instance:#{group.id}"   # fallback INALTERADO — ainda inalcançável, ainda correto
  }
```
```ruby
# Source: vendor/bundle/.../solid_queue-1.4.0/lib/active_job/concurrency_controls.rb:29-40 — [VERIFIED]
# param é String (instance_name), não ActiveRecord::Base → cai no ramo:
#   [concurrency_group, param].compact.join("/")  →  "Whatsapp::SendToGroupJob/livia_client_5"
# A chave só vive em solid_queue_semaphores.key (índice único, runtime) e
# solid_queue_blocked_executions.concurrency_key — NENHUM schema, NENHUMA migração.
# concurrency_duration = SolidQueue.default_concurrency_control_period (3 min) →
# semáforos com a chave antiga (id inteiro) expiram e são varridos pelo
# Dispatcher::ConcurrencyMaintenance. Sem estado de fila a migrar.
```

### Pattern 2: Fan-out resolvido DENTRO do PORO, não no job (D-05)

**What:** O `GroupSynchronizer` resolve as irmãs sozinho via `WhatsappInstance.where(instance_name: @instance.instance_name)` (inclui `@instance`). O job `SyncGroupsJob#perform(instance)` **não muda de assinatura**.
**When to use:** Preferir a resolução interna à passagem de lista pelo job — mantém a mudança de contrato num arquivo só, um teste de regressão só.
**Example:**
```ruby
# Source: app/services/whatsapp/group_synchronizer.rb:21-49 (ATUAL, escopo único @instance) — [VERIFIED]
# 4 pontos hoje acoplados a @instance:
#   row_for → whatsapp_instance_id: @instance.id
#   WhatsappGroup.upsert_all(rows, unique_by: %i[whatsapp_instance_id remote_jid])
#   @instance.whatsapp_groups.where(active: true).where("synced_at < ?", batch_started_at).update_all(active: false, ...)  # GRUPO-05
#   @instance.update!(groups_synced_at: batch_started_at, groups_sync_state: :idle, groups_sync_error: nil)
#
# DEPOIS (D-05): uma chamada @api.fetch_groups(@instance.instance_name, api_key: @instance.token),
# depois `WhatsappInstance.where(instance_name: @instance.instance_name).find_each do |sib|`
# repetindo os 4 pontos com `sib` no lugar de `@instance`, TODOS com o mesmo `batch_started_at`.
```
**Regressão exigida por D-05 (task isolada):** para uma instância SEM irmãs, `WhatsappInstance.where(instance_name: x)` devolve `[self]` → exatamente 1 upsert, 1 passada GRUPO-05, 1 `update!` — idêntico a hoje. Teste: montar instância sem irmã, `assert_no_difference`/contagem de queries, comparar `Result` e efeitos com o baseline atual.

### Pattern 3: Toggle Stimulus radio + campos condicionais (D-06)

**What:** `data-controller` no wrapper; dois `<label data-*-target="xLabel">` embrulhando `f.radio_button ..., class: "sr-only", data: { action: "ctrl#selectX", *_target: "xRadio" }`; dois `<div data-*-target="xField" class="... hidden">`. `connect()` → `toggleFields()`; `togglePills()` troca classes Tailwind ativas (`border-[#0F7949] bg-green-50 text-[#0F7949]`).
**Example:**
```erb
<%# Source: app/views/admin/artes/_form.html.erb:36-58 — [VERIFIED] padrão a espelhar %>
<div class="flex gap-3" data-controller="whatsapp-provision-toggle">
  <label data-whatsapp-provision-toggle-target="newLabel" class="cursor-pointer ...">
    <%= radio_button_tag "provision_mode", "new", true, class: "sr-only",
          data: { action: "whatsapp-provision-toggle#selectNew", "whatsapp-provision-toggle-target": "newRadio" } %>
    Novo número (QR)
  </label>
  <label data-whatsapp-provision-toggle-target="reuseLabel" class="cursor-pointer ...">
    <%= radio_button_tag "provision_mode", "reuse", false, class: "sr-only",
          data: { action: "whatsapp-provision-toggle#selectReuse", "whatsapp-provision-toggle-target": "reuseRadio" } %>
    Reutilizar conexão existente
  </label>
</div>
```
```js
// Source: app/javascript/controllers/media_type_toggle_controller.js — [VERIFIED] análogo direto
// index.js usa eagerLoadControllersFrom("controllers", application) → arquivo novo é auto-registrado
```

### Anti-Patterns to Avoid

- **Resolver a irmã escolhida no `#reuse` via `WhatsappInstance.find(params[:id])` cru** — viola SEG-01 ("identificador nunca vem cru do formulário"). Sempre `where(connection_state: :connected).where.not(client_id: @client.id).find_by(instance_name: ...)`.
- **Chamar `set_webhook`/`connect`/`create_instance` no fluxo de reutilização** — a conexão física já está pareada e o webhook já aponta pra este sistema; qualquer chamada é no mínimo latência inútil e no pior caso reinicia a sessão de OUTRO cliente.
- **Passar a lista de irmãs pelo `SyncGroupsJob`** — espalha o contrato D-05 por 2 arquivos; resolver dentro do `GroupSynchronizer#call`.
- **Logar `token` ou o par `instance_name`+`token`** no `#reuse`. `instance_name` sozinho não é segredo (aparece em paths/URLs); `token` nunca.
- **Consolidar numa linha compartilhada** — quebra os `id` distintos que sustentam SEG-04 sem mudança de teste.
- **Deixar o webhook `connection.update` atualizar só uma irmã** — as demais ficam com `connected` obsoleto e o guard ENVIO-07 do `SendToGroupJob` lê estado errado. Ver Pitfall 1.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Serializar envios da mesma conexão física | Lock manual / coluna `sending:boolean` / advisory lock ad-hoc | `limits_concurrency key: instance_name` (SolidQueue 1.4.0) | Já resolvido, com semáforo transacional + expiração + varredura. `[VERIFIED: solid_queue-1.4.0/app/models/solid_queue/semaphore.rb]` |
| "Quem já usa esta conexão" | `GROUP BY instance_name` inline na view toda request | Scope `WhatsappInstance.where(instance_name: x).includes(:client)` + método de classe que projeta `[{instance_name, client_names}]` | Uma query, testável, fora do ERB. |
| Cópia de `token` cifrado | Ler coluna crua / re-cifrar à mão | Atribuição direta `new.token = existing.token` | `encrypts` é transparente na leitura e na escrita. `[VERIFIED: whatsapp_instance.rb:12]` |
| Normalizar grafia de evento de webhook | Novo parser | `params[:event].to_s.tr(".-", "__").upcase` (já existe) | `[VERIFIED: app/controllers/webhooks/evolution_controller.rb:41]` |
| Marcar "instância compartilhada" | Migração de coluna `shared:boolean` + backfill + manter sincronizada | `origin` enum `+= :reused_sibling` (valor inteiro novo, code-only) | Enum já existe `{created_by_app: 0, adopted_existing: 1}` `[VERIFIED: whatsapp_instance.rb:16]`; adicionar `reused_sibling: 2` não precisa de migração. |

**Key insight:** quase tudo que a fase precisa já existe no repo em forma testada; o trabalho é *reapontar* chaves/escopos de "linha" para "conexão física", não construir mecanismo novo.

---

## Runtime State Inventory

> Fase de redesenho de fronteira / refactor. Inventário obrigatório.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | `whatsapp_instances.instance_name` tem **índice UNIQUE** (`index_whatsapp_instances_on_instance_name`, `unique: true`) `[VERIFIED: db/schema.rb:284]`. Uma segunda linha com o mesmo nome levanta `ActiveRecord::RecordNotUnique` no INSERT (`Semaphore.create_unique_by` idioma análogo confirma o comportamento de índice único no stack). | **Migração obrigatória**: `remove_index :whatsapp_instances, :instance_name` + `add_index :whatsapp_instances, :instance_name` (não-único — a coluna continua indexada; `where(instance_name:)` e o webhook `find_by` dependem disso). Sem alteração de dados. |
| **Stored data** | `whatsapp_instances` **não tem** `validates :instance_name, uniqueness` no model — só o índice de banco `[VERIFIED: app/models/whatsapp_instance.rb:1-72, lido inteiro]`. | Nenhuma — só a migração acima. |
| **Stored data** | `whatsapp_groups.whatsapp_instance_id` FK + índice único `[whatsapp_instance_id, remote_jid]` `[VERIFIED: db/schema.rb:262]`. Cada irmã tem seu próprio conjunto de linhas de grupo (escopo por `id`, não por `instance_name`). | Nenhuma — D-05 faz upsert por `whatsapp_instance_id` de cada irmã; o índice já suporta. |
| **Stored data** | `token` cifrado (AES-GCM não-determinístico) `[VERIFIED: whatsapp_instance.rb:12]`. Copiar entre irmãs gera ciphertexts diferentes para o mesmo plaintext — esperado, sem impacto. | Nenhuma. |
| **Live service config** | Evolution API: 1 config de webhook por `instance_name` físico (`POST /webhook/set/{instance}`) `[VERIFIED: evolution-contract.md + client.rb:83]`. Já aponta pra este sistema para a conexão reutilizada. | Nenhuma — **não** re-setar o webhook no `#reuse`. |
| **Live service config** | `WhatsappInstance.webhook_secret_for(instance_name)` = `HMAC-SHA256(instance_name, chave global)` `[VERIFIED: whatsapp_instance.rb:33-35]`. Para uma linha reutilizada o segredo é o da irmã (mesmo `instance_name`) — que é exatamente o que o Evolware envia. | Nenhuma — coerente por construção. |
| **OS-registered state** | SolidQueue: `solid_queue_semaphores` / `solid_queue_blocked_executions` guardam a `concurrency_key` como string em runtime `[VERIFIED: solid_queue-1.4.0/app/models/solid_queue/semaphore.rb, concurrency_controls.rb]`. | Nenhuma migração. No deploy de D-04, jobs já enfileirados com a chave antiga (`.../123`) e jobs novos com a chave nova (`.../livia_client_5`) usam semáforos diferentes por ~3 min (expiração). Volume baixo → aceitável. Documentar em Pitfalls. |
| **OS-registered state** | `config/recurring.yml` — **nenhuma** task recorrente de sync de grupos ou de envio `[VERIFIED: config/recurring.yml, lido inteiro]` (só poda de `solid_queue_failed_executions`). | Nenhuma. |
| **Secrets/env vars** | `EVOLUTION_READ_TIMEOUT_GROUPS` (default 60) — reaproveitado pela chamada única de D-05 `[VERIFIED: app/services/evolution.rb:71]`. Comentário no arquivo já cita `livia_client_31` (64 grupos, ~40s). | Nenhuma — sem env var nova. |
| **Build artifacts** | Stimulus via importmap + `eagerLoadControllersFrom` `[VERIFIED: app/javascript/controllers/index.js]` — controller novo é carregado por convenção de nome de arquivo. | Nenhuma — sem passo de build; sem editar `index.js`. |
| **Runtime lookup** | `Webhooks::EvolutionController#create` faz `WhatsappInstance.find_by(instance_name: params[:instance])` → **UMA** linha `[VERIFIED: app/controllers/webhooks/evolution_controller.rb:15]`. | **Mudar para fan-out** `WhatsappInstance.where(instance_name: ...)` em `apply_connection_update`/`apply_qrcode_updated` — senão irmãs ficam com estado obsoleto (viola ENVIO-07 indiretamente). Ver Pitfall 1. |
| **Runtime invariant** | Hoje `instance.instance_name == WhatsappInstance.evolution_name_for(instance.client)` ("livia_client_#{client.id}") `[VERIFIED: whatsapp_instance.rb:28]`. Para uma linha reutilizada, `instance_name` = `livia_client_<id_da_irmã>`, **não** do cliente dono da linha. | Documentar a quebra do invariante (assumption-delta). `evolution_name_for` só é usado no caminho de *criação* (`InstanceProvisioner#call`) e no helper de teste — o `#reuse` não o chama. Sem código quebrado, mas o plano deve registrar. |

**Nada encontrado em:** Windows Task Scheduler / pm2 / launchd / cron do SO (o projeto usa SolidQueue puro, sem processos registrados no SO — verificado por ausência em `config/recurring.yml` e STATE.md).

---

## Common Pitfalls

### Pitfall 1: Webhook `connection.update` atualiza só uma irmã → ENVIO-07 lê estado obsoleto
**What goes wrong:** Evolution manda um `connection.update` (número caiu) para `instance_name` "livia_client_5". `WhatsappInstance.find_by(instance_name: ...)` `[VERIFIED: evolution_controller.rb:15]` atualiza **uma** das N linhas-irmãs. As outras continuam `connection_state: :connected`. O `SendToGroupJob` faz `divulgacao.client.whatsapp_instance` (a linha do OUTRO cliente, ainda `connected`) `[VERIFIED: send_to_group_job.rb:146-151]` → passa o guard `instance&.connected?` → tenta enviar por uma sessão morta → item vira `:incerto`/`:falhou` tarde demais.
**Why it happens:** `find_by` foi escrito quando `instance_name` era único.
**How to avoid:** No `apply_connection_update` e `apply_qrcode_updated`, iterar `WhatsappInstance.where(instance_name: params[:instance].to_s)`. Mesmo padrão de fan-out do D-05, zero chamadas Evolution extras. Manter os guards `known_evolution_state?` / `blank?` por linha.
**Warning signs:** Um cliente mostra "Conectada" e outro "Desconectada" para o mesmo número físico; `SendToGroupJob` marca `instancia_desconectada` logo após um `connection.update` bem-sucedido.

### Pitfall 2: Índice UNIQUE em `instance_name` derruba o `#reuse` no primeiro teste
**What goes wrong:** `WhatsappInstance.create!(instance_name: alvo.instance_name, ...)` → `ActiveRecord::RecordNotUnique`.
**Why it happens:** `db/schema.rb:284` `unique: true`.
**How to avoid:** Migração drop+recreate como não-único **na primeira task**, antes de qualquer código de `#reuse`. Confirmar que nenhum teste existente depende da unicidade (busca: `test/` não tem `assert_raises(ActiveRecord::RecordNotUnique)` para `instance_name` — verificado por ausência).
**Warning signs:** Testes de `InstanceProvisioner#reuse` falham no `create!`.

### Pitfall 3: Teste de regressão da chave de concorrência quebra com D-04
**What goes wrong:** `test/jobs/whatsapp/send_to_group_job_test.rb:316-319` — `assert_includes job.concurrency_key, @instance.id.to_s` `[VERIFIED]`. Com a chave em `instance_name`, `job.concurrency_key` = `"Whatsapp::SendToGroupJob/livia_client_<n>"` e não contém mais o `id` numérico da linha (a menos que o `id` coincida com um dígito do nome — frágil).
**Why it happens:** O teste foi escrito para pinar o fix do plano 29-01.
**How to avoid:** Ajustar a asserção para `assert_includes job.concurrency_key, @instance.instance_name` na MESMA task do D-04, com um comentário apontando para esta fase. Os testes vizinhos continuam verdes sem mudança: `:311-314` (`concurrency_limit == 1`, `on_conflict == :block`) `[VERIFIED]`; `:321-331` (sentinel `send_to_group:no_instance:<id>` — usa `group.id`, não a instância) `[VERIFIED]`; `:333-338` (token nunca serializado) `[VERIFIED]`.
**Warning signs:** Só esse 1 teste vermelho após a troca.

### Pitfall 4: Deploy de D-04 com jobs em voo
**What goes wrong:** Durante o rollout, jobs enfileirados com a chave velha (`.../123`) e jobs novos (`.../livia_client_5`) tomam semáforos distintos → por até `concurrency_duration` (3 min, default `SolidQueue.default_concurrency_control_period`) `[VERIFIED: concurrency_controls.rb:15]` dois envios da mesma conexão física poderiam correr em paralelo.
**Why it happens:** A chave é resolvida no enqueue.
**How to avoid:** Aceitável dado o volume (poucos grupos, delay generoso entre envios por ENVIO-01/02). Se quiser zero-risco: drenar a fila `whatsapp_sends` antes do deploy dessa task, ou desabilitar `Divulgacoes::DispatchJob` na janela. Documentar no PLAN como nota de rollout, não como task.
**Warning signs:** Nenhum em dev; em prod, dois `[evolution] POST /message/send*` para o mesmo `instance_name` com timestamps sobrepostos logo após o deploy.

### Pitfall 5: `groups_synced_at` de uma irmã avança sem o cliente ter clicado "Sincronizar"
**What goes wrong:** Com D-05, sincronizar a instância de A também faz `update!(groups_synced_at: batch_started_at)` em B e C. Um admin olhando o cliente B vê "sincronizado agora há pouco" sem ter feito nada.
**Why it happens:** É o comportamento **pretendido** por D-05 (caches irmãos coerentes). Só precisa não surpreender.
**How to avoid:** Não é bug — mas o `WhatsappGroupsController#sync` seta `groups_sync_state: :syncing` **só** na linha em que foi chamado `[VERIFIED: whatsapp_groups_controller.rb:42]`; as irmãs nunca entram em `:syncing`, então nunca ficam presas nesse estado se o job morrer. Se D-05 também fizer fan-out do `mark_error` no caminho de falha, garantir que ele só toca linhas que estavam `:syncing` (ou nenhuma das irmãs — elas não estavam). Recomendação: no fan-out, **não** propagar `:syncing`/`:sync_error` para irmãs; só `groups_synced_at`/`idle` no caminho de sucesso. Uma falha da chamada única já deixa a linha chamadora em `:sync_error` pelo `SyncGroupsJob.mark_error` atual.
**Warning signs:** Irmã presa em `:syncing`; `groups_sync_syncing?` bloqueando re-sync de um cliente que nunca sincronizou.

### Pitfall 6: `fetchAllGroups` lento multiplicado por engano
**What goes wrong:** Implementar D-05 como "para cada irmã, chamar `GroupSynchronizer`" repetiria a chamada de ~40s N vezes — exatamente o que D-05 existe para evitar.
**Why it happens:** Caminho de menor esforço.
**How to avoid:** UMA `@api.fetch_groups(@instance.instance_name, api_key: @instance.token)` fora do loop; o loop só faz `upsert_all` + GRUPO-05 + `update!` locais. Token e nome são idênticos entre irmãs (copiados no `#reuse`), então qualquer irmã serve de fonte.
**Warning signs:** Log com N linhas `[evolution] GET /group/fetchAllGroups/...` por clique de sync.

### Pitfall 7: `bin/rails test` não roda neste ambiente
**What goes wrong:** O banco de teste pertence a outro usuário do SO (`PG::InsufficientPrivilege`) `[VERIFIED: MEMORY.md / test_db_permission.md, STATE.md:258]`. `bin/rails test` falha antes de rodar.
**How to avoid:** Verificação por inspeção + `bin/rails runner` com stubs de `Evolution::Client`, como as fases 25–30 fizeram. O planner deve marcar os critérios de teste como "verificados por inspeção / runner" e deixar a execução real da suíte como item de UAT do operador. `nyquist_validation` está `false` em `.planning/config.json` — sem gate de validação automatizada nesta fase.

### Pitfall 8: Reutilizar `media_type_toggle_controller.js` engessa nomes de target
**What goes wrong:** Os targets são `uploadField`/`linkField`/`uploadRadio`/`linkRadio`/`uploadLabel`/`linkLabel` `[VERIFIED: media_type_toggle_controller.js:4]` — semanticamente presos a mídia de arte. Reusar força nomes enganosos na view de WhatsApp, e o branch "reutilizar" precisa de comportamento extra (habilitar submit só quando um `<select>` tem opção escolhida; opcionalmente `turbo_confirm`) que o toggle de arte não tem.
**How to avoid:** Controller novo dedicado `whatsapp_provision_toggle_controller.js` (~40 linhas), copiando **verbatim** os valores de pill ativo/inativo (`border-[#0F7949] bg-green-50 text-[#0F7949]` / `border-gray-200 text-slate-700`). É auto-registrado pelo `eagerLoadControllersFrom`.

---

## Code Examples

### `InstanceProvisioner#reuse` — encaixe no PORO existente
```ruby
# Source: app/services/evolution/instance_provisioner.rb — [VERIFIED] estrutura atual:
#   Result = Struct.new(:instance, :adopted, :qr_base64, keyword_init: true)
#   def initialize(client, client_api: Evolution::Client)
#   def call ... rescue Evolution::Errors::Permanent => e; adopt(...)
#   private def adopt / persist_new / webhook_url
#
# Novo método público, SEM I/O de rede, ao lado de #call (D-07 — não toca #call/#adopt):
def reuse(existing:)
  row = WhatsappInstance.create!(
    client:             @client,
    instance_name:      existing.instance_name,
    token:              existing.token,               # encrypts transparente [VERIFIED: whatsapp_instance.rb:12]
    remote_instance_id: existing.remote_instance_id,
    origin:             :reused_sibling,              # enum novo (code-only)
    connection_state:   existing.connection_state,    # espera-se :connected
    paired_at:          existing.paired_at,
    last_checked_at:    Time.current
  )
  Result.new(instance: row, adopted: true, qr_base64: nil)
end
```

### Resolução da coleção de alvos (fora do ERB)
```ruby
# Source: app/models/whatsapp_instance.rb — [VERIFIED] sem scopes hoje; adicionar:
scope :connected, -> { where(connection_state: :connected) }

# método de classe para o <select> de D-06 — evita GROUP BY no ERB (Claude's Discretion):
def self.shareable_targets(excluding_client_id:)
  connected.where.not(client_id: excluding_client_id)
           .includes(:client)
           .group_by(&:instance_name)
           .map { |name, rows| { instance_name: name, client_names: rows.map { |r| r.client.name } } }
end
```
```ruby
# Source: app/controllers/admin/clients_controller.rb:8 (#show) — [VERIFIED] hoje: @whatsapp_instance = @client.whatsapp_instance
# adicionar quando @whatsapp_instance.nil?:
@reusable_targets = WhatsappInstance.shareable_targets(excluding_client_id: @client.id)
```

### Action `#reuse` no controller — escopo seguro (SEG-01)
```ruby
# Source: app/controllers/admin/whatsapp_instances_controller.rb — [VERIFIED] padrão das actions atuais
#   (before_action :set_client → Client.find(params[:client_id]); rescue Evolution::Errors::* → redirect com alert)
def reuse
  target = WhatsappInstance.connected
                           .where.not(client_id: @client.id)
                           .find_by(instance_name: params.require(:source_instance_name))
  return redirect_to(admin_client_path(@client),
    alert: "Conexão indisponível para reutilização. Atualize a página e tente de novo.") if target.nil?

  Evolution::InstanceProvisioner.new(@client).reuse(existing: target)
  redirect_to admin_client_path(@client),
    notice: "Conexão reutilizada. Sincronize os grupos deste cliente para popular a lista."
rescue ActiveRecord::RecordNotUnique
  redirect_to admin_client_path(@client), alert: "Este cliente já possui uma instância de WhatsApp."
end
```
```ruby
# Source: config/routes.rb:13-18 — [VERIFIED] adicionar:
resource :whatsapp_instance, only: [ :create ], controller: "whatsapp_instances" do
  post :refresh_qr
  post :verify
  post :adopt
  post :reconnect
  post :reuse            # NOVO
end
```

### Fan-out do webhook (Pitfall 1)
```ruby
# Source: app/controllers/webhooks/evolution_controller.rb:15,53-66 — [VERIFIED]
# ANTES: instance = WhatsappInstance.find_by(instance_name: params[:instance].to_s); return head(:no_content) if instance.nil?
#        apply_event(instance)
# DEPOIS:
siblings = WhatsappInstance.where(instance_name: params[:instance].to_s)
return head(:no_content) if siblings.empty?
siblings.find_each { |instance| apply_event(instance) }   # apply_connection_update/apply_qrcode_updated já são idempotentes por linha
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `instance_name` único: 1 linha ⇔ 1 conexão física ⇔ 1 cliente | N linhas podem compartilhar `instance_name`/`token`; `Client has_one` preservado (1 linha por cliente) | Esta fase (31) | Índice único → não-único; webhook e chave de concorrência passam a operar por conexão física. |
| `GroupSynchronizer` escopado a `@instance` único | Fan-out: 1 `fetchAllGroups`, N upserts locais por irmã | Esta fase (31), D-05 | Contrato interno do PORO muda; task isolada + regressão. |
| `SendToGroupJob` chave `whatsapp_instance.id` | chave `whatsapp_instance.instance_name` | Esta fase (31), D-04 | Só runtime (semáforos); 1 teste ajustado. |

**Deprecated/outdated:** nada. Nenhuma gem removida, nenhuma API Evolution nova. O `origin: :adopted_existing` continua para o fluxo PAIR-02; o novo `:reused_sibling` é distinto (adoção = reaponta webhook de um número já no manager; reutilização = cópia local de uma irmã já conectada neste sistema).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | O índice `index_whatsapp_instances_on_instance_name` precisa virar **não-único** (não apenas ser removido) porque `WhatsappInstance.where(instance_name:)` (fan-out D-05, webhook) e `find_by(instance_name:)` se beneficiam do índice. | Runtime State Inventory / Pitfall 2 | Se removido sem recriar: fan-out e webhook fazem full scan (tabela pequena, impacto baixo). Baixo risco. |
| A2 | `connection_state` da irmã escolhida é `:connected` no momento do `#reuse` (o `<select>` só lista `connected`). Copiar o estado literal é suficiente; não é preciso um `verify` síncrono contra a Evolution no `#reuse`. | Code Examples / Pattern 1 do fluxo | Se a irmã caiu entre o carregamento da página e o submit, a linha nova nasce `connected` mas morta até o próximo `connection.update` ou clique em "Forçar verificação". Mitigação barata: `verify` opcional pós-`#reuse`. Confirmar com o usuário se quer esse round-trip. |
| A3 | Adicionar `reused_sibling: 2` ao enum `origin` **não** precisa de migração (enum inteiro do Rails, valor novo é só mapeamento em código). | Don't Hand-Roll | Se o usuário preferir uma coluna `shared:boolean` explícita, vira +1 migração. Decisão de discrição — ver Q3. |
| A4 | Nenhum teste existente depende da unicidade de `instance_name` nem do `origin` ter só 2 valores. | Validation / Pitfall 2 | Verificado por leitura de `cross_client_isolation_test.rb` e por ausência de `assert_raises(RecordNotUnique)` em `test/`. Se algum teste de controller/model checar `origin` exaustivamente, ajustar. |
| A5 | O `SendToGroupJob` deve **manter** o ramo de fallback `"send_to_group:no_instance:#{group.id}"` mesmo após D-04. | Pattern 1 | Continua inalcançável (nenhum caminho destrói `WhatsappInstance` sem destruir o `Client`); removê-lo reintroduziria o risco de slot global. Baixo risco de manter. |
| A6 | Fan-out do webhook `connection.update` para todas as irmãs é desejável (preserva ENVIO-07). | Pitfall 1 / Open Questions Q1 | Se o usuário considerar "cada cliente gerencia seu próprio estado via botão Verificar", o fan-out é opcional — mas aí ENVIO-07 fica frágil para irmãs. Recomendação forte: fan-out. |
| A7 | `fetchAllGroups` pode ser chamado com o `token`/`instance_name` de **qualquer** irmã (são cópias idênticas). | Pattern 2 / Pitfall 6 | Se o `token` de uma irmã divergir (ex.: rotação futura por-cliente — item deferido), a fonte da chamada precisaria ser determinística (ex.: a linha mais antiga). Fora de escopo agora. |

**Se esta tabela estiver vazia:** não está — os 7 itens acima precisam de confirmação do usuário no `/gsd-discuss-phase` ou de decisão explícita do planner antes de virarem decisão travada. A1, A3, A6 são as de maior impacto no shape do plano.

---

## Open Questions (RESOLVED)

1. **Fan-out do webhook `connection.update` para irmãs — dentro do escopo desta fase?**
   - What we know: `find_by(instance_name:)` atualiza 1 linha `[VERIFIED: evolution_controller.rb:15]`. As irmãs ficam com estado obsoleto; ENVIO-07 lê a linha do cliente dono da divulgação.
   - What's unclear: o CONTEXT não menciona o webhook explicitamente (foca em concorrência + sync + UI).
   - Recommendation: **incluir** — é parte de "redesenhar o limite para operar por conexão física". Fan-out barato (`where(instance_name:).find_each`), zero chamadas Evolution. Task 4, junto do D-04.
   - **(RESOLVED)** Incorporado como recomendado: fan-out implementado em `31-02-PLAN.md`
     Task 1 (`Webhooks::EvolutionController#create` itera `WhatsappInstance.where(instance_name:
     ...)` em vez de `find_by`).

2. **`#reuse` faz um `verify` síncrono pós-cópia?**
   - What we know: `#verify` já existe e é síncrono `[VERIFIED: whatsapp_instances_controller.rb:35-59]`. Copiar `connection_state` da irmã é o caminho de menor latência.
   - What's unclear: tolerância a uma linha nova nascer `connected` mas com a conexão física caída no intervalo página→submit.
   - Recommendation: copiar o estado literal (sem round-trip). Se o usuário quiser robustez, um `Evolution::Client.connection_state` opcional após o `create!`, com rescue silencioso (mesma postura do `adopt_qr`).
   - **(RESOLVED)** Incorporado como recomendado: `31-01-PLAN.md` Task 1a —
     `Evolution::InstanceProvisioner#reuse(existing:)` copia `connection_state`/`paired_at`
     literalmente, ZERO I/O de rede, sem `verify` síncrono.

3. **Como marcar "compartilhada" na `WhatsappInstance` (Claude's Discretion)?**
   - What we know: `origin` enum tem 2 valores `[VERIFIED: whatsapp_instance.rb:16]`; adicionar `reused_sibling: 2` é code-only. Uma coluna `shared:boolean` exigiria migração + backfill + manter coerente quando a última irmã sai.
   - Recommendation: **`origin: :reused_sibling`** para a linha criada por reutilização + o badge "compartilhada com N" derivado de `WhatsappInstance.where(instance_name: x).where.not(id: self.id).count` (ou `.includes(:client)` para listar nomes). Sem coluna nova. O badge fica no `_panel` (branch `present?`), quando esse count > 0.
   - **(RESOLVED)** Incorporado como recomendado: `31-01-PLAN.md` Task 1a adiciona
     `origin: :reused_sibling` (enum code-only) + `#siblings`/`#shared?` no model; Task 3
     renderiza o badge "Conexão compartilhada com N cliente(s)." no branch `else` quando
     `whatsapp_instance.shared?`.

4. **`turbo_confirm` no botão "Reutilizar" (Claude's Discretion)?**
   - Recommendation: **sim** — `data: { turbo_confirm: "Isto vincula ESTE cliente ao MESMO número físico já usado por: <nomes>. A mesma sessão de WhatsApp e o mesmo limite de envio passam a ser compartilhados. Confirmar?" }`. Precedente: `turbo_submits_with` já usado no `_panel` `[VERIFIED: _panel.html.erb:59-61,68-69]`; `confirm_modal` usado em ações destrutivas do `show.html.erb`. `turbo_confirm` é suficiente para uma ação de 1 clique com `<select>`.
   - **(RESOLVED)** Incorporado como recomendado: `31-01-PLAN.md` Task 3 — o submit do
     `form_with` para `reuse_admin_client_whatsapp_instance_path` carrega
     `data: { turbo_confirm: ... }`.

5. **O `<select>` lista `instance_name` distintos ou uma linha por irmã?**
   - What we know: D-06 diz "instance_name distintos ... rótulo indicando quais clientes já usam cada um".
   - Recommendation: `WhatsappInstance.shareable_targets(excluding_client_id:)` agrupado por `instance_name`, `value` = `instance_name`, label = `"<instance_name> — usado por: A, B"`. Um nome amigável opcional (a agência pode querer "Marketing Principal" em vez de `livia_client_3`) fica como polish deferível — o `instance_name` cru serve.
   - **(RESOLVED)** Incorporado como recomendado: `31-01-PLAN.md` Task 1a adiciona
     `WhatsappInstance.shareable_targets(excluding_client_id:)` (agrupado por `instance_name`);
     Task 1b monta `@reusable_targets` no `#show`; Task 3 renderiza o `<select>` com label
     "usado por:" e carrega um teste de renderização que assevera essa `<option>`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL (dev) | Migração do índice, `where(instance_name:)` | ✓ (projeto roda em dev) | — | — |
| Banco de **teste** PG | `bin/rails test` | ✗ (`PG::InsufficientPrivilege` — outro usuário do SO) `[VERIFIED: STATE.md:258, MEMORY.md]` | — | Verificação por inspeção + `bin/rails runner` com stubs de `Evolution::Client` (padrão das fases 25–30) |
| Evolution API host | Nada nesta fase (nenhum endpoint novo; `#reuse` é local) | ✓ (leitura provada na fase 25) | 2.3.7 | Fan-out de sync usa o timeout `READ_TIMEOUT_GROUPS` já existente |
| SolidQueue worker (`bin/jobs`) | Executar `SyncGroupsJob`/`SendToGroupJob` para UAT | ✓ | solid_queue 1.4.0 | — |
| Instância Evolution real pareada + com irmã | UAT ponta a ponta de D-05 (fan-out) e do fluxo `#reuse` | ✗ (pareamento deferido ao operador desde a fase 26) | — | Build + testes com fake `Evolution::Client`; UAT do operador |
| Node/importmap build | Stimulus controller novo | ✓ (importmap, sem bundler JS) | — | `eagerLoadControllersFrom` carrega por convenção |

**Missing dependencies with no fallback:** nenhuma que bloqueie o desenvolvimento.
**Missing dependencies with fallback:** banco de teste (→ inspeção/runner); instância Evolware pareada com irmã (→ fakes + UAT do operador).

---

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high` `[VERIFIED: .planning/config.json]`.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | não (sem mudança em auth admin/cliente) | — |
| V3 Session Management | não | — |
| V4 Access Control | **sim** | `#reuse` escopa por `set_client` (`Client.find(params[:client_id])`) e resolve a irmã por `where(connection_state: :connected).where.not(client_id: @client.id).find_by(instance_name:)` — nunca `WhatsappInstance.find(params[:id])` cru. Mantém o padrão SEG-01 das fases 26–30. |
| V5 Input Validation | **sim** | `params.require(:source_instance_name)`; a existência/estado da irmã é revalidada no servidor (não confiar no `<select>`); `rescue ActiveRecord::RecordNotUnique` para submit duplicado / corrida. |
| V6 Cryptography | **sim (herdado)** | `token` continua `encrypts` (AES-GCM não-determinístico); cópia entre linhas é transparente, nenhum manuseio de chave novo. Nada de token em log/arg de job `[VERIFIED: send_to_group_job.rb comentário + test:333-338]`. |
| V7 Error Handling & Logging | **sim** | `#reuse` não loga `token`. Log opcional só com `client_id` + `instance_name` (não-segredo). `Evolution::Client#request` já loga só `method path -> status (ms)` `[VERIFIED: client.rb:202]`. |
| V13 API / Webhook | **sim** | Fan-out do webhook mantém `valid_signature?` (HMAC-SHA256 + `secure_compare` com os dois lados hasheados) ANTES de qualquer query `[VERIFIED: evolution_controller.rb:25-37]`. O `HMAC` sobre `instance_name` continua válido para irmãs (mesmo nome). |

### Known Threat Patterns for {Rails admin + Evolution + fila}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Admin aponta cliente A para a conexão de B via `id` forjado no form | Elevation of Privilege / Tampering | Resolver a irmã por `instance_name` dentro de `connected.where.not(client_id: @client.id)`; `find_by` → `nil` → alert genérico (sem vazar de quem é a instância). |
| Cross-client: arte de A alcança grupo de B após o redesenho | Information Disclosure | Isolamento ancorado em `whatsapp_instance_id` (id da linha) e `client_id`, **não** em `instance_name`. `cross_client_isolation_test.rb` continua verde sem mudança (Focus Area 3). |
| Token compartilhado vaza em log durante a cópia | Information Disclosure | Não logar `token`; `filter_parameters` já cobre (INFRA-04). Teste: `refute_includes serialized, "<token>"` para o novo caminho. |
| Replay de webhook `connection.update` derruba N irmãs | Denial of Service | `valid_signature?` antes de tudo; `known_evolution_state?` ignora states fora do conjunto; fan-out só troca `find_by`→`where`, mesma superfície de assinatura. |
| Submit duplicado de `#reuse` (aba velha, corrida) cria 2ª instância para o mesmo cliente | Tampering | Índice `unique: true` em `client_id` **permanece** `[VERIFIED: db/schema.rb:283]` → `RecordNotUnique` → alert "cliente já possui instância". |
| Concorrência: dois clientes-irmãos disparam em paralelo pela mesma sessão Baileys → rate-limit/ban | (risco de negócio, ENVIO-09) | `limits_concurrency key: instance_name` serializa TODOS os irmãos (D-04). |

**Block-on-high:** nenhum item acima é `high` não-mitigado. O controle-chave é a resolução escopada da irmã no `#reuse` (V4/V5) — o planner deve incluir um teste de controller que force um `source_instance_name` de uma instância **não conectada** e de uma instância **do próprio cliente** e assevere o redirect com alert (sem criação de linha).

---

## API Coverage (capability: api-coverage) — nota para o planner

O planner deve produzir `COVERAGE.md` (padrão das fases 26/27/29 `[VERIFIED: .planning/phases/27-.../COVERAGE.md]`) registrando:

- **Endpoints Evolution novos nesta fase: ZERO.** A fase muda a *topologia de chamada*, não a superfície:
  - O fluxo de reutilização **deliberadamente NÃO chama** `POST /instance/create`, `GET /instance/connect/{instance}` (QR) nem `POST /webhook/set/{instance}` — é um caminho de provisionamento 100% local.
  - `GET /group/fetchAllGroups/{instance}?getParticipants=false` passa a ser chamado **uma vez por `instance_name` físico** e fanned-out para N `upsert_all` locais (D-05), em vez de uma vez por linha/cliente.
  - Auth inalterada: `fetchAllGroups` usa o token da instância (agora idêntico entre irmãs); envio usa o token da instância.
- **Carregar adiante** a tabela de decisão de superfície das fases 27/29 (send/instance/group), re-decidida, marcando as duas mudanças de topologia acima.

## Assumption-Delta (transição singular → plural) — nota para o planner

Registrar o delta de suposição que dispara o checkpoint:

| Suposição antes | Depois desta fase |
|-----------------|-------------------|
| `whatsapp_instances.instance_name` é único | não-único (migração); `Client has_one :whatsapp_instance` **inalterado** (1 linha por cliente) |
| `WhatsappInstance.find_by(instance_name:)` devolve a linha canônica | devolve uma irmã arbitrária → webhook deve fan-out |
| `instance.instance_name == WhatsappInstance.evolution_name_for(instance.client)` | falso para linhas `origin: :reused_sibling` |
| chave de concorrência = "por linha `WhatsappInstance`" | "por conexão física (`instance_name`)" |
| `token` de A ≠ `token` de B sempre | irmãs compartilham `token` por design (o teste SEG-04 usa fixtures próprias com tokens distintos, não exercita reutilização — continua válido) |
| ~62 call-sites de `whatsapp_instance` em 18 arquivos `[VERIFIED: grep]` | quase todos usam `client.whatsapp_instance` (has_one, ainda 1:1) → **não afetados**; afetados = só os que dependem da unicidade de `instance_name` (webhook `find_by`; nenhum outro encontrado) |

---

## Validation Architecture

> `workflow.nyquist_validation: false` `[VERIFIED: .planning/config.json]` — **sem gate de validação automatizada obrigatório**. Seção incluída só como mapa de testes para o planner.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Minitest (Rails default) — `test/` com `ActiveSupport::TestCase` / `ActionDispatch::IntegrationTest` |
| Config file | `test/test_helper.rb` |
| Quick run command | `bin/rails test test/<arquivo>` — **indisponível neste ambiente** (Pitfall 7); usar `bin/rails runner` + stubs |
| Full suite command | `bin/rails test` — deferido a UAT do operador |

### Phase Requirements → Test Map
| Área | Comportamento | Test Type | Arquivo / abordagem | Existe? |
|------|---------------|-----------|---------------------|---------|
| D-04 | `concurrency_key` resolve para `instance_name` | unit | `test/jobs/whatsapp/send_to_group_job_test.rb` — **ajustar** o teste `:316-319` (era `@instance.id.to_s`) | ✅ (ajuste) |
| D-04 | `concurrency_limit == 1`, `on_conflict == :block` | unit | mesmo arquivo `:311-314` — deve continuar verde sem mudança | ✅ |
| D-04 | irmãs (mesmo `instance_name`, `id` diferente) produzem a MESMA `concurrency_key` | unit | **novo** no mesmo arquivo | ❌ novo |
| D-05 | fan-out: 1 `fetch_groups`, N upserts, GRUPO-05 por irmã com mesmo `batch_started_at` | unit (service) | `test/services/whatsapp/group_synchronizer_test.rb` — **novos** casos | ❌ novo |
| D-05 | **regressão**: instância SEM irmã → comportamento idêntico ao baseline (1 upsert, 1 GRUPO-05, 1 `update!`) | unit (service) | mesmo arquivo — task isolada exige (CONTEXT D-05) | ❌ novo |
| D-05 | `SyncGroupsJob#perform(instance)` — assinatura inalterada | unit (job) | `test/jobs/whatsapp/sync_groups_job_test.rb` — deve continuar verde | ✅ |
| D-03 | índice `instance_name` não-único permite 2ª linha; `client_id` único ainda bloqueia 2ª instância por cliente | unit (model) / migração | `test/models/whatsapp_instance_test.rb` (criar se ausente) | ❌ novo |
| D-03 | `InstanceProvisioner#reuse` copia `instance_name`/`token`/`connection_state`/`paired_at`/`remote_instance_id`, seta `origin: :reused_sibling`, NÃO chama Evolution | unit (service) | `test/services/evolution/instance_provisioner_test.rb` (ver se existe) + stub que falha se `Evolution::Client` for tocado | parcial |
| D-06 | action `#reuse`: alvo não-conectado / do próprio cliente / inexistente → redirect + alert, zero linhas criadas | controller | `test/controllers/admin/whatsapp_instances_controller_test.rb` | ✅ (novos casos) |
| D-06 | `#show` monta `@reusable_targets` só quando `@whatsapp_instance.nil?` | controller | `test/controllers/admin/clients_controller_test.rb` | ✅ (novo caso) |
| SEG-04 | isolamento cross-client permanece verde COM irmãs compartilhando `instance_name` | integration | `test/integration/cross_client_isolation_test.rb` — **sem mudança**; adicionar teste NOVO com par de clientes-irmãos | ✅ + novo |
| Pitfall 1 | webhook `connection.update` atualiza TODAS as irmãs | controller | `test/controllers/webhooks/evolution_controller_test.rb` | ✅ (novo caso) |
| V6 | `token` da linha reutilizada nunca aparece em arg serializado / log | unit | `test/jobs/whatsapp/send_to_group_job_test.rb:333-338` (padrão) aplicado ao novo caminho | ✅ (novo) |

### Wave 0 Gaps
- [ ] `test/models/whatsapp_instance_test.rb` — cobre índice não-único + `origin: :reused_sibling` (criar se ausente)
- [ ] Casos novos em `test/services/whatsapp/group_synchronizer_test.rb` — fan-out + **regressão single-instance** (bloqueante por D-05)
- [ ] Casos novos em `test/services/evolution/instance_provisioner_test.rb` — `#reuse` sem I/O de rede
- [ ] Casos novos em `test/controllers/admin/whatsapp_instances_controller_test.rb` — `#reuse` escopo/validação (V4/V5)
- [ ] Caso novo em `test/controllers/webhooks/evolution_controller_test.rb` — fan-out
- [ ] Ajuste em `test/jobs/whatsapp/send_to_group_job_test.rb:316-319` — `instance_name` no lugar de `id`
- [ ] Teste novo em `test/integration/cross_client_isolation_test.rb` — par de clientes-irmãos (aditivo; o teste existente NÃO muda)
- [ ] Execução real da suíte: **item de UAT do operador** (banco de teste indisponível localmente)

---

## Sources

### Primary (HIGH confidence) — código lido nesta sessão
- `app/jobs/whatsapp/send_to_group_job.rb` — `limits_concurrency` :57-61, guards ENVIO-06/07 :140-151, taxonomia de erro
- `app/services/whatsapp/group_synchronizer.rb` — `#call` :21-49, `row_for` :64-78, GRUPO-05 :39-42
- `app/jobs/whatsapp/sync_groups_job.rb` — `#perform` :65-67, `mark_error` :69-72
- `app/services/evolution/instance_provisioner.rb` — `Result`, `#call`, `#adopt`, `#persist_new`
- `app/services/evolution/client.rb` — `fetch_groups` :128-136, `request` :170-203, `raise_for_status!` :209-230
- `app/services/evolution.rb` — timeouts :57-71 (`READ_TIMEOUT_GROUPS` 60s, comentário cita `livia_client_31` 64 grupos ~40s)
- `app/models/whatsapp_instance.rb` — `encrypts :token` :12, enums :15-22, `evolution_name_for` :28, `webhook_secret_for` :33-35
- `app/models/client.rb` — `has_one :whatsapp_instance` :7, `has_many :whatsapp_groups, through:` :8
- `app/models/whatsapp_group.rb` — `belongs_to :whatsapp_instance` :8
- `app/models/divulgacao.rb` — `arte_e_grupos_do_mesmo_cliente` :130-138
- `app/controllers/admin/whatsapp_instances_controller.rb` — actions `create`/`adopt`/`verify`/`refresh_qr`/`reconnect`, `set_client` :95-97
- `app/controllers/admin/whatsapp_groups_controller.rb` — `#sync` :29-46, guards
- `app/controllers/admin/divulgacoes_controller.rb` — `scoped_active_groups` :178-180, `#create` :88-154
- `app/controllers/admin/clients_controller.rb` — `#show` :8-16
- `app/controllers/webhooks/evolution_controller.rb` — `#create` :12-20 (`find_by`), `valid_signature?` :25-37, `apply_*` :53-79
- `app/views/admin/clients/show.html.erb` — render `_panel` :137
- `app/views/admin/whatsapp_instances/_panel.html.erb` — branch `nil?` :9-19, ações :57-94
- `app/views/admin/artes/_form.html.erb` — toggle `media_source` :36-58
- `app/javascript/controllers/media_type_toggle_controller.js` — padrão de toggle
- `app/javascript/controllers/index.js` — `eagerLoadControllersFrom`
- `config/routes.rb` — `resource :whatsapp_instance` :13-18
- `config/recurring.yml` — sem task de sync/envio
- `db/schema.rb` — `whatsapp_instances` :266-285 (índice `instance_name` unique :284, `client_id` unique :283), `whatsapp_groups` :252-264
- `test/integration/cross_client_isolation_test.rb` — 3 testes, helper `build_client_with_whatsapp!`
- `test/jobs/whatsapp/send_to_group_job_test.rb` — :311-338 (concurrency)
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/lib/active_job/concurrency_controls.rb` — `concurrency_key` :29-40, `limits_concurrency` :20-26
- `vendor/bundle/ruby/3.3.0/gems/solid_queue-1.4.0/app/models/solid_queue/semaphore.rb` — semáforo transacional
- `.planning/notes/evolution-contract.md` — contrato Evolution 2.3.7 (read-path VERIFICADO)
- `.planning/phases/27-.../COVERAGE.md` — padrão de `COVERAGE.md`
- `.planning/config.json`, `.planning/STATE.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`

### Secondary (MEDIUM confidence)
- SolidQueue `default_concurrency_control_period` = 3 min — comportamento padrão da gem 1.4.0 (`class_attribute :concurrency_duration, default: SolidQueue.default_concurrency_control_period` `[VERIFIED: concurrency_controls.rb:15]`; o valor "3 min" é o default histórico da gem `[ASSUMED]` — confirmar em `SolidQueue.default_concurrency_control_period` se o número exato importar para a nota de rollout).

### Tertiary (LOW confidence)
- Nenhuma. Nada nesta pesquisa dependeu de WebSearch — todo o material é código do repo + gem vendorada.

---

## Metadata

**Confidence breakdown:**
- User Constraints: HIGH — copiados verbatim de `31-CONTEXT.md`.
- Standard Stack: HIGH — nenhum pacote novo; versões lidas de `Gemfile.lock` e do código.
- Architecture / call-flow: HIGH — todos os arquivos do caminho crítico lidos nesta sessão.
- Pitfalls: HIGH — cada um ancorado em linha de código específica.
- SolidQueue internals: HIGH (mecânica de `concurrency_key`) / MEDIUM (valor numérico exato de `concurrency_duration`).
- Migração do índice: HIGH — schema lido diretamente (`unique: true` explícito).

**Research date:** 2026-08-31
**Valid until:** ~2026-10-01 (estável — depende só de código interno e de solid_queue 1.4.0; nada de ecossistema em movimento). Reavaliar se `solid_queue` for atualizado ou se a rotação de token por-cliente (item deferido) entrar em escopo.
