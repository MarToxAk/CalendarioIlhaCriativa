---
phase: quick/260831-nb7-listar-as-inst-ncias-do-whatsapp-direto-
plan: 1
subsystem: whatsapp-provisioning
tags: [rails, evolution-api, whatsapp, faraday]

requires:
  - phase: 31-inst-ncia-whatsapp-compartilhada-entre-clientes
    provides: instância deuniqueificada, InstanceProvisioner#reuse, controller #reuse, toggle "Reutilizar conexão existente"
provides:
  - "WhatsappInstance.shareable_targets lê Evolution::Client.fetch_instances ao vivo (não só linhas locais)"
  - "Evolution::InstanceProvisioner#adopt_named — adoção por nome arbitrário, fora do rescue de #call"
  - "Admin::WhatsappInstancesController#reuse decide entre irmã local (zero I/O) e adoção ao vivo"
affects: [admin/clients#show, admin/whatsapp_instances]

actuals:
  tokens: 5822
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "shareable_targets como fonte-ao-vivo com fallback [] em rescue de Evolution::Errors::* (nunca 500)"
    - "adopt_named como wrapper público fino sobre #adopt privado (reuso de código, zero duplicação)"

key-files:
  created: []
  modified:
    - app/models/whatsapp_instance.rb
    - app/controllers/admin/clients_controller.rb
    - app/services/evolution/instance_provisioner.rb
    - app/controllers/admin/whatsapp_instances_controller.rb
    - app/views/admin/whatsapp_instances/_panel.html.erb
    - test/models/whatsapp_instance_test.rb
    - test/controllers/admin/clients_controller_test.rb
    - test/services/evolution/instance_provisioner_test.rb
    - test/controllers/admin/whatsapp_instances_controller_test.rb

key-decisions:
  - "Smoke check ao vivo (Task 1) confirmou entry[\"name\"] (não instanceName) e entry[\"connectionStatus\"] batem exatamente com o previsto no plano/FEATURES.md — nenhum ajuste de campo necessário"
  - "Label de fallback '#{name} — ainda não vinculada a nenhum cliente' no _panel.html.erb foi implementado no Task 1 (não no Task 3 como o plano previa) porque o teste novo do Task 1 já exercita essa mesma partial renderizada por clients#show — pull-forward necessário para o próprio Task 1 passar sua verificação"

patterns-established:
  - "Pattern: revalidar contra o estado AO VIVO do Evolution antes de qualquer escrita quando o alvo não tem irmã local (nunca confiar cegamente num nome vindo de params)"

requirements-completed: []

coverage:
  - id: D1
    description: "WhatsappInstance.shareable_targets lista TODAS as instâncias que o Evolution reporta como conectadas agora (connectionStatus == open), inclusive sem nenhuma linha local, e degrada para [] em qualquer falha do Evolution"
    verification:
      - kind: unit
        ref: "test/models/whatsapp_instance_test.rb#shareable_targets lista entrada Evolution conectada com irma local e exclui o nome do proprio cliente"
        status: pass
      - kind: unit
        ref: "test/models/whatsapp_instance_test.rb#shareable_targets nao lista entrada cujo connectionStatus nao mapeia para :connected"
        status: pass
      - kind: unit
        ref: "test/models/whatsapp_instance_test.rb#shareable_targets lista entrada Evolution conectada SEM nenhuma linha WhatsappInstance local com client_names vazio"
        status: pass
      - kind: unit
        ref: "test/models/whatsapp_instance_test.rb#shareable_targets devolve [] em vez de propagar quando fetch_instances levanta Evolution::Errors::Transient"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/clients_controller_test.rb#show de cliente sem instancia com Evolution reportando instancia SEM linha local mostra opcao com rotulo de fallback"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/clients_controller_test.rb#show de cliente sem instancia com Evolution falhando responde :success e mostra mensagem de lista vazia"
        status: pass
    human_judgment: false
  - id: D2
    description: "Evolution::InstanceProvisioner#adopt_named expõe o caminho de adoção da fase 26 (set_webhook sempre, connection_state real) para um nome escolhido pelo admin, preservando #reuse zero-I/O"
    verification:
      - kind: unit
        ref: "test/services/evolution/instance_provisioner_test.rb#adopt_named com nome presente no fetch_instances persiste linha nova com origin_adopted_existing? e chama set_webhook 1x"
        status: pass
      - kind: unit
        ref: "test/services/evolution/instance_provisioner_test.rb#adopt_named com nome ausente no fetch_instances levanta Evolution::Errors::Permanent e nao cria linha"
        status: pass
    human_judgment: false
  - id: D3
    description: "Admin::WhatsappInstancesController#reuse escolhe entre copiar de irmã local (zero I/O) ou adotar ao vivo, revalidando o estado no momento do POST, nunca criando linha para um alvo não conectado"
    verification:
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb#reuse com source_instance_name sem nenhuma linha local adota ao vivo via adopt_named"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb#reuse com instance_name inexistente nao cria linha e redireciona com alert generico"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb#reuse com alvo NAO conectado (awaiting_qr) nao cria linha (T-31-01)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb#reuse com instance_name da PROPRIA instancia do cliente (self-target) nao cria linha (T-31-01)"
        status: pass
    human_judgment: false

duration: ~40min
completed: 2026-08-31
status: complete
---

# Quick Task 260831-nb7: Listar instâncias do WhatsApp direto do Evolution Summary

**`<select>` "Reutilizar conexão existente" passa a listar TODAS as conexões que o Evolution reporta como pareadas agora — não só as que algum cliente local já reivindicou — via `Evolution::Client.fetch_instances` + adoção ao vivo (`InstanceProvisioner#adopt_named`) para o caso sem irmã local.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-31T19:20:00Z (aprox.)
- **Completed:** 2026-08-31T20:05:22Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments
- `WhatsappInstance.shareable_targets` trocou de fonte local (`WhatsappInstance` conectadas) para fonte ao vivo (`GET /instance/fetchInstances`), inclusive instâncias "órfãs" que nenhum cliente local usa ainda
- Smoke check ao vivo (task 1, credenciais reais) confirmou os campos exatos que a Evolution API devolve — `name` e `connectionStatus`, batendo com o previsto no plano, sem necessidade de ajuste
- `Evolution::InstanceProvisioner#adopt_named(name)` — wrapper público fino que reaproveita o `#adopt` privado já existente da fase 26, sem duplicar lógica de set_webhook/connection_state/persistência
- `Admin::WhatsappInstancesController#reuse` agora decide entre dois caminhos (irmã local zero-I/O vs. adoção ao vivo) e SEMPRE revalida o estado da conexão no momento do POST antes de criar qualquer linha
- Uma falha de rede do Evolution no carregamento de `admin/clients#show` degrada para "Nenhuma conexão conectada disponível para reutilizar." em vez de 500

## Task Commits

1. **Task 1: `WhatsappInstance.shareable_targets` vira Evolution-backed (fonte ao vivo)** - `c1ae6d8` (feat)
2. **Task 2: `Evolution::InstanceProvisioner#adopt_named` — adoção por nome arbitrário** - `1ac778b` (feat)
3. **Task 3: `Admin::WhatsappInstancesController#reuse` decide irmã local vs. adoção ao vivo** - `19624df` (feat)

_Nenhuma task TDD — todas `type="auto"`, um commit por task._

## Files Created/Modified
- `app/models/whatsapp_instance.rb` - `shareable_targets` reescrito para ler `Evolution::Client.fetch_instances`, com rescue -> `[]`
- `app/controllers/admin/clients_controller.rb` - comentário acima da linha do `@reusable_targets` atualizado (código inalterado)
- `app/services/evolution/instance_provisioner.rb` - novo método público `adopt_named(name)`
- `app/controllers/admin/whatsapp_instances_controller.rb` - `#reuse` decide entre `InstanceProvisioner#reuse` (irmã local) e `#adopt_named` (adoção ao vivo), com revalidação
- `app/views/admin/whatsapp_instances/_panel.html.erb` - label de fallback quando `client_names` vem vazio
- `test/models/whatsapp_instance_test.rb`, `test/controllers/admin/clients_controller_test.rb`, `test/services/evolution/instance_provisioner_test.rb`, `test/controllers/admin/whatsapp_instances_controller_test.rb` - testes novos/atualizados stubando `Evolution::Client`

## Decisions Made
- Smoke check confirmou empiricamente que `entry["name"]` (não `instanceName`) e `entry["connectionStatus"]` são os campos reais devolvidos por `GET /instance/fetchInstances` no host de produção — nenhum ajuste de leitura de campo foi necessário no código, o plano já previa corretamente ambos.
- O label de fallback do `_panel.html.erb` (originalmente previsto para o Task 3) foi implementado já no Task 1, porque o teste novo do Task 1 (`clients_controller_test.rb`) exercita a MESMA partial renderizada por `admin/clients#show`. Sem esse pull-forward, o `<verify>` do próprio Task 1 falharia até o Task 3 rodar — documentado como deviation abaixo.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pull-forward do label de fallback da view para o Task 1**
- **Found during:** Task 1 (ao rodar `bin/rails test test/controllers/admin/clients_controller_test.rb`)
- **Issue:** O plano agenda a mudança de `_panel.html.erb` (label "ainda não vinculada a nenhum cliente" quando `client_names` vem vazio) para o Task 3, mas pede um teste NOVO no Task 1 (`clients_controller_test.rb`) que já exercita essa mesma renderização via `admin/clients#show`. Sem a mudança de view, o `<verify>` do próprio Task 1 falharia.
- **Fix:** Implementada a troca de expressão do rótulo (`_panel.html.erb`) já no Task 1, junto com o resto da mudança de `shareable_targets`. O Task 3 não precisou tocar essa linha de novo — só a lógica do controller `#reuse`.
- **Files modified:** app/views/admin/whatsapp_instances/_panel.html.erb
- **Verification:** `bin/rails test test/models/whatsapp_instance_test.rb test/controllers/admin/clients_controller_test.rb` — 37/37 passam já no Task 1
- **Committed in:** c1ae6d8 (Task 1 commit)

**2. [Rule 1 - Bug] `fake_instance` de teste sem `connectionStatus` causava falso-negativo no teste novo do Task 3**
- **Found during:** Task 3 (primeira rodada de `bin/rails test test/controllers/admin/whatsapp_instances_controller_test.rb`)
- **Issue:** O `fake_instance` do teste novo "reuse com source_instance_name sem nenhuma linha local adota ao vivo" não incluía a chave `"connectionStatus"`, então `map_evolution_state(nil)` mapeava para `:awaiting_qr` (não `:connected`) e o guard de revalidação redirecionava com alert em vez de adotar — `WhatsappInstance.count` não mudava (esperado +1, real +0).
- **Fix:** Adicionada `"connectionStatus" => "open"` ao hash `fake_instance` do teste.
- **Files modified:** test/controllers/admin/whatsapp_instances_controller_test.rb
- **Verification:** `bin/rails test test/controllers/admin/whatsapp_instances_controller_test.rb` — 21/21 passam
- **Committed in:** 19624df (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking - pull-forward de view, 1 bug - stub de teste incompleto)
**Impact on plan:** Ambos os ajustes eram necessários para as próprias verificações do plano passarem; nenhum scope creep — o pull-forward só antecipou 2 linhas de código já planejadas para o Task 3.

## Issues Encountered
- Suite completa (`bin/rails test`, sem filtro) tem 19 falhas pré-existentes em arquivos totalmente fora do escopo desta task (`test/integration/rack_attack_test.rb`, `test/models/arte_test.rb`, `test/models/approval_response_test.rb`, `test/controllers/client/home_controller_test.rb`, `test/controllers/admin/dashboard_controller_test.rb`) — confirmado via `git diff --stat` que nenhum dos 3 commits desta task tocou esses arquivos. Fora de escopo (scope boundary), não corrigido.

## User Setup Required

None - nenhuma configuração externa nova. Credenciais do Evolution já configuradas desde EVO-01 (fase 25).

## Next Phase Readiness

- `<select>` "Reutilizar conexão existente" agora reflete o estado real do Evolution, não apenas o que o app local já sabe — cobre o caso de instâncias pareadas por outra ferramenta da agência.
- Superfície aceita, não corrigida: o Evolution é compartilhado com outras apps da agência; o `<select>` pode listar (e a adoção pode reivindicar) uma instância que não pertence a este app. Decisão explícita do usuário, superfície já admin-only, nenhum segredo exposto.

---
*Quick task: 260831-nb7*
*Completed: 2026-08-31*

## Self-Check: PASSED

All 9 code/test files created/modified verified present on disk. All 3 task commits (c1ae6d8, 1ac778b, 19624df) verified present in git log.
