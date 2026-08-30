---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
plan: 02
subsystem: integrations
tags: [evolution-api, whatsapp, adoption-flow, admin-panel]

requires:
  - phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
    provides: "WhatsappInstance model (encrypts :token, map_evolution_state, evolution_name_for, webhook_secret_for), Evolution::Client#create_instance, InstanceProvisioner#call (caminho de criação), Admin::WhatsappInstancesController#create — tudo do plano 26-01"
provides:
  - "Evolution::Client#connect (QR normalizado, guard contra HTTP 200 + {error:true} — Pitfall 6) + #set_webhook (events sempre explícito)"
  - "Evolution::InstanceProvisioner#call cobre create-ou-adota: rescue Evolution::Errors::Permanent que casa /already in use/i desvia para #adopt; qualquer outro Permanent continua subindo cru"
  - "Evolution::InstanceProvisioner#adopt — busca instância existente por match exato de nome, reaponta webhook SEMPRE antes de ler connection_state (Pitfall 4), persiste origin: adopted_existing com estado real via WhatsappInstance.map_evolution_state, paired_at write-once (PAIR-08)"
  - "Admin::WhatsappInstancesController#adopt — mesmo shape de #create, notice de adoção do UI-SPEC"
affects: [26-03-webhook-receiver-autenticado, 26-04-verificao-manual-qr-refresh, 26-05-polimento-visual]

actuals:
  tokens: 3400
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "InstanceProvisioner#call: rescue Evolution::Errors::Permanent com regex /already in use/i seletivo — qualquer outro Permanent (payload inválido, 401/404) sobe cru para o controller, sem desviar para adoção"
    - "adopt() reaponta o webhook SEMPRE, ANTES de ler connection_state — ordem verificada por índice de string na verificação, não só por presença dos dois métodos"
    - "Evolution::Client#connect normaliza chaves top-level OU aninhadas em qrcode (base64/code/pairingCode/count), guard body[\"error\"] ANTES de qualquer .dig"

key-files:
  created: []
  modified:
    - app/services/evolution/client.rb
    - app/services/evolution/instance_provisioner.rb
    - app/controllers/admin/whatsapp_instances_controller.rb
    - test/services/evolution/client_test.rb
    - test/controllers/admin/whatsapp_instances_controller_test.rb

key-decisions:
  - "InstanceProvisioner#adopt SEMPRE chama set_webhook antes de ler connection_state (Pitfall 4) — sem essa ordem o painel trava para sempre em 'aguardando pareamento' porque o webhook antigo nunca aponta para este app"
  - "Admin::WhatsappInstancesController#create e #adopt compartilham exatamente a mesma chamada a InstanceProvisioner#call — a adoção acontece automaticamente DENTRO de #create quando o Evolution devolve 'already in use'; #adopt (rota/botão dedicado do UI-SPEC) existe para o fluxo explícito, mas ambos convergem no mesmo InstanceProvisioner"
  - "Teste antigo de erro genérico do #create ('403 already in use') foi ajustado para uma mensagem que NÃO colide com a nova regex de adoção (401 invalid api key) — o cenário antigo ('erro cru propaga') deixou de ser verdade para 'already in use' especificamente, então precisava de uma mensagem Permanent diferente para continuar testando o caminho de propagação genuína"

patterns-established:
  - "WhatsappInstance.map_evolution_state (fonte única, definida em 26-01) é reutilizado sem reimplementação em adopt() — nenhum Hash de mapeamento duplicado"

requirements-completed: [PAIR-02]

coverage:
  - id: D1
    description: "Evolution::Client#connect normaliza QR (top-level ou aninhado em qrcode), levanta Transient em HTTP 200 + {error:true} (Pitfall 6) e Unknown em corpo 2xx não-Hash"
    requirement: "PAIR-02"
    verification:
      - kind: unit
        ref: "test/services/evolution/client_test.rb#connect (4 casos: QR válido, QR aninhado, error:true, corpo não-Hash)"
        status: pass
      - kind: integration
        ref: "bin/rails runner — Faraday::Adapter::Test stub GET /instance/connect/x com {error:true} -> Evolution::Errors::Transient"
        status: pass
    human_judgment: false
  - id: D2
    description: "Evolution::Client#set_webhook sempre envia events explícito (nunca array vazio) e retorna o body do 201"
    requirement: "PAIR-02"
    verification:
      - kind: unit
        ref: "test/services/evolution/client_test.rb#set_webhook"
        status: pass
    human_judgment: false
  - id: D3
    description: "InstanceProvisioner#call desvia para #adopt SOMENTE quando o Permanent casa /already in use/i; qualquer outro Permanent continua subindo cru"
    requirement: "PAIR-02"
    verification:
      - kind: unit
        ref: "ruby -e inspeção de código (rescue presente) + test/controllers/admin/whatsapp_instances_controller_test.rb (cenário 'erro não already-in-use' propaga; cenário 'already in use' adota)"
        status: pass
    human_judgment: false
  - id: D4
    description: "adopt() chama set_webhook ANTES de ler connection_state (ordem verificada por índice de string, não só presença) — Pitfall 4"
    requirement: "PAIR-02"
    verification:
      - kind: unit
        ref: "ruby -e comparação de índice de string dentro do corpo de def adopt"
        status: pass
      - kind: integration
        ref: "bin/rails runner — DI seam client_api: simula 403 already in use -> adopt -> set_webhook -> connected, paired_at gravado"
        status: pass
    human_judgment: false
  - id: D5
    description: "paired_at só é gravado quando ainda nil e o estado lido é open (write-once, PAIR-08) — nunca sobrescrito numa adoção onde o estado já é open"
    requirement: "PAIR-02"
    verification:
      - kind: unit
        ref: "ruby -e grep 'paired_at ||=' + bin/rails runner asserção result.instance.paired_at.present?"
        status: pass
    human_judgment: false
  - id: D6
    description: "Admin::WhatsappInstancesController#adopt existe, usa a copy exata do UI-SPEC ('Instância existente adotada e webhook reapontado para este sistema.') e o mesmo rescue genérico de #create"
    requirement: "PAIR-02"
    verification:
      - kind: unit
        ref: "grep -qF copy exata em app/controllers/admin/whatsapp_instances_controller.rb"
        status: pass
    human_judgment: false
  - id: D7
    description: "POST admin_client_whatsapp_instance_path com create_instance stubado para 403 already in use resulta em origin: adopted_existing, connection_state correto, token da instância adotada, paired_at gravado e set_webhook chamado exatamente 1 vez (contador, não só 'não levantou')"
    requirement: "PAIR-02"
    verification:
      - kind: integration
        ref: "test/controllers/admin/whatsapp_instances_controller_test.rb#'create com 403 already in use adota a instância existente via #adopt interno'"
        status: pass
    human_judgment: false

duration: ~12min
completed: 2026-08-30
status: complete
---

# Phase 26 Plan 02: Adoção de Instância Existente (PAIR-02) Summary

**`Evolution::Client#connect`/`#set_webhook` + `InstanceProvisioner#adopt` fecham o segundo caminho de `POST /instance/create`: uma colisão "already in use" agora adota a instância existente, reaponta o webhook incondicionalmente e persiste o estado real — sem erro cru para o admin.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-08-30T13:20:00Z (aprox.)
- **Completed:** 2026-08-30T13:32:00Z (aprox.)
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- `Evolution::Client#connect(instance_name)` — GET `/instance/connect/{name}` com `read_timeout: READ_TIMEOUT_FAST`, normaliza `base64`/`code`/`pairing_code`/`count` (aceita chaves top-level ou aninhadas em `qrcode`), levanta `Evolution::Errors::Transient` quando o corpo 2xx tem `error: true` (Pitfall 6 — HTTP 200 não significa QR válido) e `Evolution::Errors::Unknown` quando o corpo 2xx não é um `Hash`.
- `Evolution::Client#set_webhook(instance_name, url:, headers:)` — POST `/webhook/set/{name}` sempre com `events:` explícito (`%w[QRCODE_UPDATED CONNECTION_UPDATE]`, nunca `[]` — o Evolution trocaria por "todos os eventos"), retorna o body do 201.
- `Evolution::InstanceProvisioner#call` agora envolve a chamada a `create_instance`/`persist_new` com `rescue Evolution::Errors::Permanent => e; raise unless e.message =~ /already in use/i; adopt(name, headers)` — qualquer outro `Permanent` (payload inválido, 401/404) continua subindo cru para o controller.
- `InstanceProvisioner#adopt` — busca a instância existente por match **exato** de nome em `fetch_instances` (T-26-07, nunca por índice/prefixo), chama `set_webhook` **incondicionalmente antes** de ler `connection_state` (Pitfall 4), persiste `origin: :adopted_existing` com `connection_state` via `WhatsappInstance.map_evolution_state` (fonte única do 26-01, não reimplementada), e grava `paired_at` só se ainda `nil` e o estado é `"open"` (write-once, PAIR-08).
- `Admin::WhatsappInstancesController#adopt` — mesmo shape de `#create`, chama o mesmo `InstanceProvisioner#call` (que já cobre create-ou-adota internamente), com a copy exata do UI-SPEC (`"Instância existente adotada e webhook reapontado para este sistema."`) no sucesso.
- Testes: 8 novos casos em `client_test.rb` (`connect` QR válido/aninhado/`error:true`/corpo não-Hash, `set_webhook`), 1 novo caso end-to-end no controller test provando adoção via `#create` (403 "already in use" → `set_webhook` chamado 1x, `origin: adopted_existing`, `connection_state: connected`, `token` da instância adotada, `paired_at` gravado).

## Task Commits

Each task was committed atomically:

1. **Task 1: Evolution::Client#connect + #set_webhook** - `c1cb3a4` (feat)
2. **Task 2: InstanceProvisioner#adopt + Admin::WhatsappInstancesController#adopt (PAIR-02)** - `c621ba3` (feat)

**Plan metadata:** commit pendente (docs, gerado após este SUMMARY)

## Files Created/Modified

- `app/services/evolution/client.rb` — `+connect`, `+set_webhook`
- `app/services/evolution/instance_provisioner.rb` — `+adopt` privado, `#call` com `rescue Evolution::Errors::Permanent`
- `app/controllers/admin/whatsapp_instances_controller.rb` — `+#adopt`
- `test/services/evolution/client_test.rb` — +8 testes (`connect` × 4, `set_webhook` × 1, mais os já existentes de `create_instance` intocados)
- `test/controllers/admin/whatsapp_instances_controller_test.rb` — +1 teste de adoção end-to-end; 1 teste ajustado (mensagem do stub trocada para não colidir com a nova regex `/already in use/i`)

## Decisions Made

- **`#create` e `#adopt` convergem no mesmo `InstanceProvisioner#call`** — a adoção acontece automaticamente dentro de `#create` quando o Evolution devolve "already in use", sem exigir clique extra do admin (CONTEXT.md: "buscar `connection_state` na hora... em ambos os casos o webhook é reapontado"). A rota/botão `#adopt` dedicado do UI-SPEC ("Adotar instância existente") existe para o fluxo explícito mas usa exatamente o mesmo serviço — nenhuma lógica duplicada no controller. A resolução completa entre o automatismo de `#create` e o botão manual de `#adopt` fica documentada para o 26-05 conforme o `<done>` da Task 2 do plano.
- **Teste antigo do `#create` com erro genérico ajustado.** O teste pré-existente `"create com erro do Evolution não cria linha"` usava a mensagem `"403 already in use"` para provar que erros do Evolution propagam como alert genérico — com a nova regra de adoção, essa mensagem específica agora É interceptada e desvia para `#adopt`. Trocada para `"401 invalid api key"` (Permanent que não casa a regex), preservando a intenção original do teste (propagação genuína de erro) sem contradição com o comportamento novo.

## Deviations from Plan

None — plano executado exatamente como especificado. Os dois `<verify>` automatizados de cada task (inspeção de código via `ruby -e` + simulação `bin/rails runner` via DI seam) passaram sem ajuste na primeira tentativa, e os testes automatizados (`bin/rails test`) confirmaram os dois arquivos de teste tocados sem regressão.

## Issues Encountered

- **19 falhas pré-existentes em `bin/rails test` (suíte completa) não relacionadas a este plano** — confirmado rodando a suíte completa (265 runs, 19 failures, 0 errors) e comparando com o baseline documentado no 26-01-SUMMARY.md (mesmo número: 19 falhas em `api/v1/ai/*`, `client/home_controller_test.rb`, `models/arte_test.rb`, nenhum desses arquivos tocado por este plano). Não corrigidas — fora do escopo desta task per regra de escopo do executor.

## User Setup Required

None — nenhuma configuração de serviço externo neste plano.

## Next Phase Readiness

- PAIR-02 fechado: "already in use" nunca aparece como erro cru para o admin.
- PAIR-03 e PAIR-08 permanecem `Pending` — compartilhados com 26-03/26-04/26-05 (QR na UI, badge de estado, aviso de idade do número) e só fecham quando o ÚLTIMO plano que os declara entregar (shared-ID gate).
- `Evolution::Client#connect`/`#set_webhook` prontos para reuso em 26-04 (`#refresh_qr`/`#verify`) sem reimplementação.
- `InstanceProvisioner#call` cobre agora os DOIS caminhos completos de `POST /instance/create` (cria e adota) — nenhum refactor de assinatura pública necessário para 26-03 (webhook receiver, que só lê `connection_state`/`paired_at` já persistidos) nem 26-04.
- Nenhum blocker aberto para 26-03.

---
*Phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento*
*Completed: 2026-08-30*

## Self-Check: PASSED
