---
phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes
plan: 01
subsystem: whatsapp
tags: [rails, activerecord, solid_queue, stimulus, evolution-api, encryption]

# Dependency graph
requires:
  - phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
    provides: WhatsappInstance model, Evolution::InstanceProvisioner#call/#adopt, painel _panel.html.erb, webhook receiver
  - phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
    provides: whatsapp_groups belongs_to :whatsapp_instance, GroupSynchronizer
  - phase: 29-motor-de-envio
    provides: Whatsapp::SendToGroupJob, limits_concurrency (ENVIO-09)
provides:
  - Migração que deuniqueifica whatsapp_instances.instance_name (índice de client_id permanece unique)
  - WhatsappInstance#origin enum += :reused_sibling, scope :connected, #siblings, #shared?, self.shareable_targets
  - Evolution::InstanceProvisioner#reuse(existing:) — cópia local sem I/O de rede
  - Admin::WhatsappInstancesController#reuse + rota reuse_admin_client_whatsapp_instance_path
  - Admin::ClientsController#show monta @reusable_targets
  - Toggle Stimulus "Novo número (QR)" vs "Reutilizar conexão existente" no _panel
  - Badge "Conexão compartilhada com N cliente(s)." no branch conectado
  - Whatsapp::SendToGroupJob.limits_concurrency chave por instance_name (D-04)
affects: [31-02-fan-out-webhook-group-synchronizer, 30-acompanhamento-ao-vivo-hardening]

# Actuals (#2632)
actuals:
  tokens: 9975
  tasks: 4
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Enum value add without migration (origin += reused_sibling: 2, integer-backed, code-only)"
    - "Per-physical-connection fan-out via WhatsappInstance.where(instance_name:) instead of find_by, once the unique index was dropped"
    - "Dedicated Stimulus controller per semantic domain instead of reusing a same-shaped toggle whose target names are bound to a different concept"

key-files:
  created:
    - db/migrate/20260831185638_deuniqueify_whatsapp_instance_name.rb
    - app/javascript/controllers/whatsapp_provision_toggle_controller.js
    - test/services/evolution/instance_provisioner_test.rb
  modified:
    - app/models/whatsapp_instance.rb
    - app/services/evolution/instance_provisioner.rb
    - app/controllers/admin/whatsapp_instances_controller.rb
    - app/controllers/admin/clients_controller.rb
    - app/jobs/whatsapp/send_to_group_job.rb
    - config/routes.rb
    - app/views/admin/whatsapp_instances/_panel.html.erb
    - app/views/admin/clients/show.html.erb
    - db/schema.rb
    - test/models/whatsapp_instance_test.rb
    - test/controllers/admin/whatsapp_instances_controller_test.rb
    - test/controllers/admin/clients_controller_test.rb
    - test/jobs/whatsapp/send_to_group_job_test.rb

key-decisions:
  - "D-03 implementado literalmente: Client has_one :whatsapp_instance preservado; #reuse cria uma NOVA linha copiando instance_name/token/connection_state/paired_at/remote_instance_id da irmã, origin: :reused_sibling"
  - "D-04 implementado: limits_concurrency key: troca &.id por &.instance_name — irmãs (linhas distintas, mesma conexão física) agora serializam no MESMO semáforo SolidQueue"
  - "D-06/D-07: toggle Stimulus dedicado (whatsapp-provision-toggle), não reuso de media-type-toggle — nomes de target ficariam enganosos; branch QR (else) do _panel fica byte-idêntico exceto pela linha da badge condicional a shared?"
  - "SEG-01/T-31-01: #reuse resolve a irmã por WhatsappInstance.connected.where.not(client_id:).find_by(instance_name:) — nunca um id cru de params; verificado por git grep (zero ocorrências de WhatsappInstance.find(params)"

patterns-established:
  - "shareable_targets/siblings/shared? ficam no MODEL (não no controller/ERB) — GROUP BY fora da view"
  - "Rescue Evolution::Errors::* copiado verbatim do #adopt para o #reuse, mesmo sendo defensivo (o #reuse não faz I/O de rede) — mantém a taxonomia de erro consistente entre actions do mesmo controller"

requirements-completed: []

coverage:
  - id: D1
    description: "Migração dropa unique de instance_name (mantém client_id unique) + WhatsappInstance ganha origin: reused_sibling, scope :connected, #siblings, #shared?, self.shareable_targets"
    verification:
      - kind: unit
        ref: "test/models/whatsapp_instance_test.rb — 6 casos novos (indice nao-unico, client_id ainda unique, origin_reused_sibling?, siblings, shared?, shareable_targets x2)"
        status: unknown
      - kind: other
        ref: "bin/rails db:migrate + grep em db/schema.rb (instance_name sem unique, client_id unique) — executado nesta sessão, output verificado"
        status: pass
    human_judgment: false
  - id: D2
    description: "Evolution::InstanceProvisioner#reuse(existing:) copia campos da irmã sem I/O de rede, origin: :reused_sibling"
    verification:
      - kind: unit
        ref: "test/services/evolution/instance_provisioner_test.rb — 3 testes (campos copiados, zero I/O via RaisingFakeEvolutionClient, RecordNotUnique no 2o reuse)"
        status: unknown
      - kind: other
        ref: "bin/rails runner script/tmp_reuse_smoke.rb (temporário, removido) — imprimiu REUSE-OK nesta sessão"
        status: pass
    human_judgment: false
  - id: D3
    description: "Admin::WhatsappInstancesController#reuse (rota + resolução escopada SEG-01) e Admin::ClientsController#show monta @reusable_targets"
    verification:
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb — 5 casos (irmã conectada, não-conectada, inexistente, self-target, duplicata) + test/controllers/admin/clients_controller_test.rb — 2 casos de @reusable_targets"
        status: unknown
      - kind: other
        ref: "bin/rails runner 'Rails.application.routes.url_helpers.respond_to?(:reuse_admin_client_whatsapp_instance_path)' -> true; git grep 'WhatsappInstance.find(params' -> vazio"
        status: pass
    human_judgment: false
  - id: D4
    description: "Whatsapp::SendToGroupJob.limits_concurrency chave por instance_name (D-04) — clientes-irmãos serializam no mesmo semáforo"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/send_to_group_job_test.rb — assertion renomeada (instance_name) + caso novo de irmãs com mesma concurrency_key"
        status: unknown
      - kind: other
        ref: "bin/rails runner script/tmp_ckey_smoke.rb (temporário, removido) — imprimiu CKEY-OK nesta sessão; concurrency_limit==1/on_conflict==:block confirmados"
        status: pass
    human_judgment: false
  - id: D5
    description: "Toggle Stimulus 'Novo número (QR)' vs 'Reutilizar conexão existente' no _panel + badge 'compartilhada com N' + fluxo QR (branch else) preservado byte-a-byte exceto pela badge"
    verification:
      - kind: automated_ui
        ref: "test/controllers/admin/clients_controller_test.rb — GET real + assert_select confirmando <option> com 'usado por:' no <select id=source_instance_name>"
        status: unknown
      - kind: other
        ref: "node --check no controller Stimulus; git diff app/javascript/controllers/index.js vazio; renderização real via ActionDispatch::Integration::Session nesta sessão confirmou VIEW-RENDER-OK (empty state) e VIEW-RENDER-OK (shared badge)"
        status: pass
    human_judgment: true
    rationale: "Verificação visual do toggle (pills ativas/inativas, disable do submit até selecionar, turbo_confirm ao clicar) exige clique real no browser — banco de teste indisponível localmente para bin/rails test (31-RESEARCH.md Pitfall 7); coberto por UAT do operador"

# Metrics
duration: ~50min
completed: 2026-08-31
status: complete
---

# Phase 31 Plan 01: Reutilização de Conexão WhatsApp Summary

**Instância de WhatsApp compartilhável entre clientes: índice deuniqueificado, InstanceProvisioner#reuse copia uma irmã já conectada sem I/O, controller/rota `#reuse` com resolução escopada, chave de concorrência do SendToGroupJob por instance_name, e toggle Stimulus "Novo número" vs "Reutilizar" no painel.**

## Performance

- **Duration:** ~50min (estimativa — timestamp de início não capturado no arranque da execução)
- **Tasks:** 4 (Task 1a, Task 1b, Task 2, Task 3)
- **Files modified:** 16 (13 modified, 3 new)

## Accomplishments
- Migração `DeuniqueifyWhatsappInstanceName`: índice de `instance_name` deixa de ser UNIQUE (índice de `client_id` permanece unique) — habilita N linhas `WhatsappInstance` apontando para a mesma conexão física, uma por cliente
- `Evolution::InstanceProvisioner#reuse(existing:)`: cria a linha do cliente novo copiando `instance_name`/`token`/`connection_state`/`paired_at`/`remote_instance_id` da irmã, `origin: :reused_sibling`, ZERO chamadas ao Evolution — provado por `RaisingFakeEvolutionClient` no teste e no smoke script
- `Admin::WhatsappInstancesController#reuse` + rota `post :reuse`: resolve a irmã por `WhatsappInstance.connected.where.not(client_id: @client.id).find_by(instance_name: ...)` — nunca um id cru de params (T-31-01/SEG-01); `nil` → alert genérico, `RecordNotUnique` → alert de duplicata
- `Admin::ClientsController#show` monta `@reusable_targets` (via `WhatsappInstance.shareable_targets`) só quando o cliente ainda não tem instância
- `Whatsapp::SendToGroupJob.limits_concurrency key:` troca `whatsapp_instance&.id` por `&.instance_name` (D-04) — duas instâncias-irmãs (id diferente, mesmo `instance_name`) agora disputam o MESMO slot de concorrência; sentinel de fallback sem-instância inalterado
- Toggle Stimulus `whatsapp-provision-toggle` no branch `nil?` do `_panel.html.erb` (controller JS dedicado, não reuso de `media-type-toggle`) com `<select>` de conexões reutilizáveis, `turbo_confirm` explícito, e aviso pt-BR de que é o MESMO número físico
- Badge "Conexão compartilhada com N cliente(s)." no branch conectado quando `whatsapp_instance.shared?` — única linha adicionada ao fluxo QR existente, que fica byte-idêntico do resto

## Task Commits

Cada task foi commitada atomicamente:

1. **Task 1a: Migração + model + InstanceProvisioner#reuse (D-03)** - `d241939` (feat)
2. **Task 1b: Rota + Admin::WhatsappInstancesController#reuse + @reusable_targets (D-06, SEG-01)** - `dba42d5` (feat)
3. **Task 2: SendToGroupJob concorrência por instance_name (D-04)** - `a3c1edf` (feat)
4. **Task 3: Toggle Stimulus + badge compartilhada (D-06/D-07)** - `1f9a5a4` (feat)

## Files Created/Modified
- `db/migrate/20260831185638_deuniqueify_whatsapp_instance_name.rb` - remove_index + add_index não-único em `instance_name`
- `db/schema.rb` - regenerado (version 2026_08_31_185638)
- `app/models/whatsapp_instance.rb` - enum `origin += reused_sibling: 2`, `scope :connected`, `#siblings`, `#shared?`, `self.shareable_targets`
- `app/services/evolution/instance_provisioner.rb` - método público `#reuse(existing:)`, `#call`/`#adopt`/`#persist_new` inalterados
- `config/routes.rb` - `post :reuse` dentro de `resource :whatsapp_instance`
- `app/controllers/admin/whatsapp_instances_controller.rb` - action `#reuse`
- `app/controllers/admin/clients_controller.rb` - `@reusable_targets` no `#show`
- `app/jobs/whatsapp/send_to_group_job.rb` - `limits_concurrency key:` por `instance_name`
- `app/views/admin/whatsapp_instances/_panel.html.erb` - toggle no branch `nil?` + badge "compartilhada" no branch `else`
- `app/views/admin/clients/show.html.erb` - repassa `@reusable_targets` ao partial
- `app/javascript/controllers/whatsapp_provision_toggle_controller.js` (novo) - toggle Stimulus dedicado
- `test/services/evolution/instance_provisioner_test.rb` (novo) - 3 testes de `#reuse`
- `test/models/whatsapp_instance_test.rb` - 6 testes novos (índice, enum, siblings/shared?/shareable_targets)
- `test/controllers/admin/whatsapp_instances_controller_test.rb` - 5 testes novos de `#reuse`
- `test/controllers/admin/clients_controller_test.rb` - 3 testes novos (`@reusable_targets` x2 + renderização do select)
- `test/jobs/whatsapp/send_to_group_job_test.rb` - assertion renomeada + 1 teste novo de irmãs

## Decisions Made
- D-03/D-04/D-06/D-07 implementados exatamente como travado no CONTEXT/RESEARCH — nenhuma decisão nova tomada nesta execução, só as discretionary calls já resolvidas no RESEARCH ("Open Questions (RESOLVED)"): origin enum em vez de coluna `shared:boolean`; controller Stimulus dedicado; `turbo_confirm` no submit de reutilizar; badge derivada de `siblings.where.not(id:).count`.
- Rescue `Evolution::Errors::*` copiado verbatim do `#adopt` para o `#reuse`, mesmo o `#reuse` não fazendo I/O de rede — defesa em profundidade e consistência de taxonomia de erro entre actions do mesmo controller (não é uma decisão nova, é literalmente o que o PLAN.md pediu).

## Deviations from Plan

None - plan executado exatamente como escrito. As tasks (1a, 1b, 2, 3) mapeiam 1:1 para os 4 commits; nenhum Rule 1-4 disparado.

## Known Stubs

Nenhum. Todo o código entregue é funcional (não há dados mock/placeholder); a UI de reutilização depende de `@reusable_targets` real vindo do model, sem hardcode.

## Issues Encountered
- `bin/rails test` continua indisponível neste ambiente (banco de teste pertence a outro usuário do SO — 31-RESEARCH.md Pitfall 7, MEMORY.md `test_db_permission.md`). Todos os testes desta plan foram escritos para CI e verificados por: (a) `ruby -c` limpo em todos os arquivos de teste; (b) lógica de model/service provada via `bin/rails runner` com scripts smoke temporários (`script/tmp_reuse_smoke.rb` → `REUSE-OK`, `script/tmp_ckey_smoke.rb` → `CKEY-OK`, ambos criados e removidos dentro da task, conforme o PLAN.md); (c) a renderização real do `_panel.html.erb` (empty-state com select + "usado por:", e branch conectado com a badge "Conexão compartilhada com N") foi confirmada via `ActionDispatch::Integration::Session` num script ad-hoc nesta sessão — não apenas inspeção estática do ERB.
- A execução real da suíte Minitest (incluindo os testes de controller/renderização com `assert_select`) permanece como item de UAT do operador, mesmo padrão das fases 25-30.

## User Setup Required

None - nenhuma configuração externa nova. Nenhum pacote instalado (Package Legitimacy Audit: N/A, confirmado no RESEARCH).

## Next Phase Readiness
- Plano 31-02 (fan-out do webhook `connection.update` + `GroupSynchronizer` para instâncias-irmãs) pode prosseguir: a migração de deuniqueificação e os métodos `WhatsappInstance#siblings`/`shareable_targets` que ele consome já existem.
- Operador deve rodar a suíte Minitest real (ambiente com banco de teste próprio) para confirmar os 17 testes novos/alterados desta plan antes do deploy — nenhum bloqueio de código, só de ambiente local.
- Fluxo de reutilização está pronto para uso real assim que houver pelo menos uma instância `connected` de um cliente existente na agência (não requer dado novo além do que já existe).

---
*Phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes*
*Completed: 2026-08-31*

## Self-Check: PASSED

- FOUND: db/migrate/20260831185638_deuniqueify_whatsapp_instance_name.rb
- FOUND: app/javascript/controllers/whatsapp_provision_toggle_controller.js
- FOUND: test/services/evolution/instance_provisioner_test.rb
- FOUND commit: d241939 (Task 1a)
- FOUND commit: dba42d5 (Task 1b)
- FOUND commit: a3c1edf (Task 2)
- FOUND commit: 1f9a5a4 (Task 3)
