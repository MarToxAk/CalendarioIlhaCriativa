---
task: 260831-o9t-trocar-o-bot-o-parear-novamente-quando-c
type: quick
status: complete
subsystem: admin/whatsapp-instances
tags: [whatsapp, evolution, instance-provisioner, admin-ui, soft-delete]
dependency-graph:
  requires:
    - Fase 26 (InstanceProvisioner#call/#adopt, painel de WhatsApp)
    - Fase 31 (instância compartilhada — enum :unpaired sentinela, siblings, shared?)
  provides:
    - "Admin::WhatsappInstancesController#unlink (POST unlink)"
    - "linha :unpaired tratada como 'sem instância' em admin/clients#show"
    - "InstanceProvisioner#reuse/#persist_new idempotentes sobre linha :unpaired"
  affects:
    - config/routes.rb
    - app/controllers/admin/whatsapp_instances_controller.rb
    - app/controllers/admin/clients_controller.rb
    - app/services/evolution/instance_provisioner.rb
    - app/views/admin/whatsapp_instances/_panel.html.erb
tech-stack:
  added: []
  patterns:
    - "soft-desativação de grupos via update_all(active: false) escopado pela associação (nunca destroy — mina de FK divulgacao_grupos.whatsapp_group_id null: false sem cascade)"
    - "find_or_initialize_by(client:) + guard `persisted? && !unpaired?` para re-provisão idempotente (mesmo padrão de #adopt)"
key-files:
  created: []
  modified:
    - config/routes.rb
    - app/controllers/admin/whatsapp_instances_controller.rb
    - app/controllers/admin/clients_controller.rb
    - app/services/evolution/instance_provisioner.rb
    - app/views/admin/whatsapp_instances/_panel.html.erb
    - test/controllers/admin/whatsapp_instances_controller_test.rb
    - test/controllers/admin/clients_controller_test.rb
    - test/services/evolution/instance_provisioner_test.rb
decisions:
  - "#unlink é ação NOVA, não uma mudança em #reconnect — #reconnect segue servindo o botão 'Gerar novo QR' de _qr.html.erb (estado awaiting_qr) e continua chamando Evolution::Client.connect; #unlink nunca toca o Evolution"
  - "'Desvincular' = flipar connection_state para a sentinela :unpaired já existente (enum valor 0), sem migração, sem novo valor de enum, sem destroy"
  - "grupos em cache da linha desvinculada ficam active: false (update_all) para não aparecerem como ativos; divulgacao_grupos e whatsapp_groups nunca são apagados"
  - "guard `persisted? && !unpaired?` em #reuse e #persist_new mantém RecordNotUnique para linha viva; só linha :unpaired é sobrescrita"
metrics:
  duration: ~15min
  completed: 2026-08-31
  tasks: 2
  commits: 2
actuals:
  tokens: 9000
  tasks: 2
  commits: 2
---

# Quick Task 260831-o9t: Trocar "Parear novamente" por "Desvincular WhatsApp" Summary

Substituído o botão "Parear novamente" do painel de WhatsApp de `admin/clients#show` (mostrado quando `connected?`/`disconnected?`) por um botão **"Desvincular WhatsApp"** que remove o vínculo LOCAL do cliente com a conexão sem tocar na sessão física do Evolution: flipa `connection_state` para a sentinela `:unpaired` já existente e soft-desativa os `whatsapp_groups` daquela linha, com ZERO chamada à Evolution API e nenhuma linha apagada. Depois de desvincular, o cliente volta ao estado "sem instância" e pode conectar um número novo (QR) ou reutilizar outra conexão — `InstanceProvisioner#persist_new` e `#reuse` viraram idempotentes sobre a linha `:unpaired` remanescente.

## Task 1 (tracer): Ação #unlink ponta a ponta — commit 3914bf1

- **config/routes.rb**: `post :unlink` adicionado no bloco `resource :whatsapp_instance ... do`, ao lado de `reconnect`/`reuse`. `reconnect` intocado.
- **Admin::WhatsappInstancesController#unlink** (nova ação, logo antes de `#reuse`): guard `inst.nil?` → redirect com alert (nunca 500); numa `ActiveRecord::Base.transaction`, `inst.update!(connection_state: :unpaired, groups_sync_state: :idle, groups_sync_error: nil, last_qr_base64: nil, paired_at: nil, last_checked_at: Time.current)` + `inst.whatsapp_groups.update_all(active: false)`; redirect com notice. Sem `rescue`, sem `Evolution::Client`.
- **#verify**: o alert do `rescue Evolution::Errors::NotConnected` deixou de citar "Parear novamente" — agora `'... Use "Desvincular WhatsApp" e conecte um número novo ou reutilize outra conexão.'`
- **_panel.html.erb**: botão renomeado para "Desvincular WhatsApp"; modal `reconnect-modal` → `unlink-modal`, título "Desvincular WhatsApp", `confirm_label: "Desvincular"`, `cancel_label: "Manter vínculo"`, `form_action: unlink_admin_client_whatsapp_instance_path(client)`; corpo reescrito (ramo compartilhado e não compartilhado) com cópia precisa: a conexão continua ativa, nada é apagado, os clientes-irmãos não são afetados. Comentário de cabeçalho e bloco `<%# %>` atualizados. `_qr.html.erb` e "Gerar novo QR" intocados.
- **Testes**: string do alert de `#verify` atualizada; 5 testes novos de `#unlink` (flip para unpaired + notice; grupos `active: false` sem FK error com histórico real de `Divulgacao`/`DivulgacaoGrupo`; conexão compartilhada não afeta a linha irmã; guard sem instância; nunca chama o Evolution). Em `clients_controller_test`, os 2 testes de cópia do modal reescritos para `#unlink-modal-desc` e a nova cópia.

**Tracer verify (end-to-end):** `bin/rails test test/controllers/admin/whatsapp_instances_controller_test.rb test/controllers/admin/clients_controller_test.rb` → 43 runs, 0 failures, 0 errors. Não-regressão: `whatsapp_instance_test` + `whatsapp_groups_controller_test` + `cross_client_isolation_test` → 37 runs, 0 failures.

## Task 2 (auto): Linha :unpaired = "sem instância" + re-provisão idempotente — commit a3a61fe

- **Admin::ClientsController#show**: `@whatsapp_instance = nil if @whatsapp_instance&.unpaired?` logo após `@whatsapp_instance = @client.whatsapp_instance` — espelha `_client_row.html.erb:11`. Com isso `@reusable_targets` é montado e `_panel` cai no ramo `whatsapp_instance.nil?` (empty-state) sem mudança de view. Comentário atualizado.
- **Evolution::InstanceProvisioner#reuse**: `WhatsappInstance.create!` → `find_or_initialize_by(client: @client)` + `raise ActiveRecord::RecordNotUnique, "..." if row.persisted? && !row.unpaired?` + `row.assign_attributes(...)` (mesmo conjunto de campos) + `row.save!`. Retorno inalterado. ZERO I/O preservado (nenhuma chamada de rede adicionada). Doc-comment atualizado.
- **Evolution::InstanceProvisioner#persist_new**: mesmo padrão `find_or_initialize_by` + guard + `assign_attributes` + `save!`. Isto faz "Criar instância" funcionar depois de `#unlink` (antes o `create!` levantava `RecordNotUnique`, que `#create` não resgata → 500).
- **#call / #adopt / #adopt_named** intocados.
- **Testes**: `instance_provisioner_test` — `#reuse` sobre linha `:unpaired` do próprio cliente sobrescreve sem `RecordNotUnique` e sem I/O (RaisingFakeEvolutionClient). `whatsapp_instances_controller_test` — "reuse depois de unlink re-vincula" e "create depois de unlink conecta número novo (sem 500)", ambos `assert_no_difference "WhatsappInstance.count"`. `clients_controller_test` — show com linha `:unpaired` renderiza empty-state + `select#source_instance_name`; e não renderiza o botão/modal "Desvincular WhatsApp".

**Verify:** `bin/rails test test/controllers/admin/clients_controller_test.rb test/services/evolution/instance_provisioner_test.rb test/controllers/admin/whatsapp_instances_controller_test.rb` → 53 runs, 0 failures, 0 errors.

## Full verification (plano §6)

`bin/rails test` sobre `whatsapp_instances_controller_test` + `clients_controller_test` + `instance_provisioner_test` + `whatsapp_instance_test` + `whatsapp_groups_controller_test` + `cross_client_isolation_test` → **90 runs, 423 assertions, 0 failures, 0 errors, 0 skips**. Testes de `#reuse`/`RecordNotUnique` já existentes e a suíte de isolamento cross-client (SEG-01/SEG-04) seguem verdes e inalterados; `#reconnect` e sua rota não foram tocados.

## Deviations from Plan

None - plan executed exactly as written.

## Threat surface

Nenhuma superfície nova além da prevista no `<threat_model>` do plano. `#unlink` herda `Admin::BaseController` (admin-only), é escopada por `params[:client_id]` via `before_action :set_client`, tem proteção CSRF do Rails, não consome dado do usuário além do `client_id` da rota, e não faz nenhuma chamada de rede. `inst.whatsapp_groups.update_all` é escopado pela associação (só a linha deste cliente) — SEG-04 intacto.

## Self-Check: PASSED

- config/routes.rb `post :unlink` — FOUND
- Admin::WhatsappInstancesController#unlink — FOUND
- app/views/admin/whatsapp_instances/_panel.html.erb `unlink-modal` — FOUND
- InstanceProvisioner#reuse/#persist_new `find_or_initialize_by` — FOUND
- Commit 3914bf1 — FOUND
- Commit a3a61fe — FOUND
