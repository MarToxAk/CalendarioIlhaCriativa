---
phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
plan: 02
subsystem: whatsapp-groups
tags: [rails, activejob, solid_queue, stimulus, rack-attack, evolution-api]

# Dependency graph
requires:
  - phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
    provides: "27-01: tabela whatsapp_groups, Evolution::Client.fetch_groups, Whatsapp::GroupSynchronizer PORO, Admin::WhatsappGroupsController#index (cache local), superfície de rota completa"
provides:
  - "Whatsapp::SyncGroupsJob — primeiro ActiveJob do repo, traduz Evolution::Errors em retry/discard"
  - "Admin::WhatsappGroupsController#sync (guardado, throttled, anti-spam) + #sync_status (JSON de 4 chaves, escopado)"
  - "Throttle Rack::Attack admin/whatsapp_groups_sync_by_ip (6/60s)"
  - "group_sync_controller.js — poller Stimulus de conclusão de sync (3s, teto 20 ciclos)"
  - "Botão 'Sincronizar grupos' + link 'Ver grupos' no painel WhatsApp do cliente"
  - "wa_groups_synced_label — timestamp absoluto pt-BR (America/São Paulo)"
affects: [27-03-picker-escopado-estados-de-tela, 29-motor-de-envio]

# Actuals (#2632)
actuals:
  tokens: 5563
  tasks: 3
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Evolution::Errors -> ActiveJob retry_on/discard_on: GET idempotente retry (Transient/Unknown), erro semântico discard_on com handler gravando um código curto de estado (mark_error) — padrão para o motor de envio da fase 29"
    - "Máquina de 3 colunas (state/error/synced_at) como ÚNICO backing de status assíncrono — zero introspecção do solid_queue, poller Stimulus lê só JSON local"
    - "Poller GET puro sem CSRF para endpoint de leitura sem efeito colateral (diferencia do poller POST do QR, que muta)"

key-files:
  created:
    - app/jobs/whatsapp/sync_groups_job.rb
    - test/jobs/whatsapp/sync_groups_job_test.rb
    - test/controllers/admin/whatsapp_groups_controller_test.rb
    - app/javascript/controllers/group_sync_controller.js
    - app/helpers/admin/whatsapp_groups_helper.rb
    - .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/scripts/27-02-helper.rb
    - .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/deferred-items.md
  modified:
    - app/controllers/admin/whatsapp_groups_controller.rb
    - config/initializers/rack_attack.rb
    - app/views/admin/whatsapp_instances/_panel.html.erb

key-decisions:
  - "Guard anti-spam de cache (Rails.cache.write unless_exist: true, expires_in: 15.seconds) implementado como não-opcional em #sync, seguindo o precedente exato de pull_fresh_qr (T-26-15) — o texto do plano descreve como 'guard opcional' mas fornece o código literal a adicionar; interpretei 'opcional' como discricionariedade de projeto (já decidida no plano), não como algo a omitir."
  - "'Sincronizar grupos' no painel usa a classe de botão SECUNDÁRIA (não a verde primária) — o 27-UI-SPEC reserva o accent #0F7949 como CTA primário só para a página de grupos (empty state 2 / header nunca sincronizado); no painel, ao lado de 'Forçar verificação', o botão segue o mesmo estilo secundário dos demais."
  - "Toast client-side (group_sync_controller.js) construído via DOM direto (createElement + data-controller=\"toast\"), não via Turbo Stream broadcast — os toasts existentes do projeto (_approval_toast.html.erb) são sempre server-driven via ActionCable; este poller não tem canal de push, só um fetch síncrono no browser. Reaproveita a mesma classe/estrutura e o toast_controller.js existente (auto-dismiss, limite de 3) para não duplicar comportamento."
  - "REQUIREMENTS.md: GRUPO-01 marcado completo (só 27-01 e 27-02 o declaram, ambos com SUMMARY). GRUPO-02 permanece em aberto — também declarado por 27-03 (picker escopado), que ainda não tem SUMMARY nesta wave (shared-ID gate, gsd-tools requirements.ready-ids)."

patterns-established:
  - "Job de I/O externo assíncrono: guarda taxonomia de erro do serviço (Evolution::Errors) -> retry_on para classes seguras a repetir (idempotentes) -> discard_on com handler que grava um código curto de estado consultável via endpoint JSON local. Fase 29 (motor de envio) deve seguir a mesma tradução de taxonomia."

requirements-completed: [GRUPO-01]

coverage:
  - id: D1
    description: "Whatsapp::SyncGroupsJob — primeiro ActiveJob do repo, traduz Evolution::Errors em retry_on (Transient/Unknown, wait 30s, attempts 3) e discard_on (Permanent/NotConnected/ConfigurationError -> mark_error; DeserializationError sem efeito colateral)"
    requirement: "GRUPO-01"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/sync_groups_job_test.rb (9 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Segurança de argumento do job (INFRA-04) — instância passada por registro (GlobalID), token nunca entra em job.serialize['arguments']"
    requirement: "GRUPO-01"
    verification:
      - kind: unit
        ref: "test/jobs/whatsapp/sync_groups_job_test.rb#perform_later serializa via GlobalID"
        status: pass
      - kind: other
        ref: "bin/rails runner (Task 1 <verify> #2 do plano) -- 'OK no token in args'"
        status: pass
    human_judgment: false
  - id: D3
    description: "#sync guardado (instância ausente/desconectada nunca enfileira), anti-spam (cache guard 15s + Rack::Attack 6/60s) e feedback de flash (GRUPO-01/SC1)"
    requirement: "GRUPO-01"
    verification:
      - kind: integration
        ref: "test/controllers/admin/whatsapp_groups_controller_test.rb (#sync: sem instância, desconectada, conectada)"
        status: pass
      - kind: other
        ref: "bin/rails runner -- Rack::Attack.throttles.key?('admin/whatsapp_groups_sync_by_ip') => THROTTLE OK"
        status: pass
    human_judgment: false
  - id: D4
    description: "#sync_status devolve exatamente { syncing, synced_at, error, count } lido do estado local (3 colunas), escopado por params[:client_id], sem nomes/JIDs de grupo (GRUPO-02, Security V13)"
    requirement: "GRUPO-02"
    verification:
      - kind: integration
        ref: "test/controllers/admin/whatsapp_groups_controller_test.rb (#sync_status payload shape + cross-client scope)"
        status: pass
    human_judgment: false
  - id: D5
    description: "group_sync_controller.js -- poller GET (sem CSRF), teto ~20 ciclos, clearInterval em disconnect(), nunca console.log de payload de grupo"
    verification:
      - kind: other
        ref: "greps estáticos do plano (CSRF, console., disconnect+clearInterval) -- todos OK"
        status: pass
    human_judgment: true
    rationale: "O comportamento real do poller num navegador (toast aparecendo, Turbo.visit substituindo a página, revelação da caixa de erro/nota de timeout) depende de targets Stimulus que só existem na view do 27-03 (ainda não construída) -- não há wiring data-controller nesta fase para testar em browser real. Verificado só por análise estática do arquivo. Confirmação visual fica para o UAT consolidado de fim de fase."
  - id: D6
    description: "Painel WhatsApp do cliente: botão 'Sincronizar grupos' (desabilitado salvo connected?, turbo_submits_with) + link 'Ver grupos'"
    verification:
      - kind: unit
        ref: "ERB.new(...).src parse check em _panel.html.erb (sem erro de sintaxe) + test/controllers/admin/clients_controller_test.rb (8 tests, sem regressão)"
        status: pass
    human_judgment: true
    rationale: "Layout visual (posição, espaçamento, estado disabled) não foi conferido num navegador real nesta sessão -- só a estrutura ERB e as classes Tailwind foram verificadas por inspeção contra o 27-UI-SPEC. Confirmação visual fica para o UAT consolidado de fim de fase (workflow.human_verify_mode = end-of-phase)."
  - id: D7
    description: "wa_groups_synced_label -- timestamp absoluto pt-BR (DD/MM/AAAA às HH:MM, America/São Paulo) ou '—' quando nunca sincronizado"
    verification:
      - kind: integration
        ref: ".planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/scripts/27-02-helper.rb"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-30
status: complete
---

# Phase 27 Plan 02: Sync trigger, job e poller de grupos do WhatsApp Summary

**`Whatsapp::SyncGroupsJob` (primeiro ActiveJob do repo) traduz a taxonomia `Evolution::Errors` em retry/discard; `#sync`/`#sync_status` fecham o loop "cliquei -> sincronizou" via um poller Stimulus que lê só as 3 colunas de estado local, nunca o Evolution nem o solid_queue.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-30T19:00:00Z (aprox.)
- **Completed:** 2026-08-30T19:09:58Z
- **Tasks:** 3
- **Files modified:** 10 (7 criados, 3 modificados)

## Accomplishments
- `Whatsapp::SyncGroupsJob` — `retry_on` para `Evolution::Errors::Transient`/`Unknown` (wait 30s, attempts 3, GET idempotente), `discard_on` para `Permanent`/`NotConnected`/`ConfigurationError` (grava código curto via `mark_error`) e `discard_on ActiveJob::DeserializationError`. `perform(instance)` só delega a `Whatsapp::GroupSynchronizer#call`. Token da instância nunca entra nos argumentos serializados (GlobalID + INFRA-04).
- `Admin::WhatsappGroupsController#sync` — guarda instância ausente/desconectada (nunca enfileira), guard de cache anti-spam (`Rails.cache.write unless_exist:`, 15s, precedente `pull_fresh_qr`), marca `groups_sync_state: :syncing` e enfileira o job com flash `"Sincronização iniciada. Os grupos aparecem aqui em instantes."`.
- `#sync_status` — responde só `{ syncing, synced_at, error, count }` a partir das 3 colunas locais, escopado por `params[:client_id]` via `set_client`, sem nomes/JIDs de grupo (Security V13).
- Throttle `Rack::Attack` `admin/whatsapp_groups_sync_by_ip` (6/60s por IP) ao lado do throttle de webhooks.
- `group_sync_controller.js` — poller Stimulus (3s, teto ~20 ciclos), GET puro sem `X-CSRF-Token` (endpoint sem efeito colateral), `clearInterval` garantido em `disconnect()`, toast de sucesso/erro + `Turbo.visit` replace na conclusão, nota de timeout no teto de ciclos. Nunca loga payload de grupo (INFRA-04).
- Painel WhatsApp do cliente (`_panel.html.erb`): botão "Sincronizar grupos" (desabilitado salvo `connected?`, `turbo_submits_with: "Sincronizando…"`) + link "Ver grupos".
- `wa_groups_synced_label` — timestamp absoluto pt-BR (`DD/MM/AAAA às HH:MM`), `"—"` quando nunca sincronizado.
- Cobertura de teste: `test/jobs/whatsapp/sync_groups_job_test.rb` (9), `test/controllers/admin/whatsapp_groups_controller_test.rb` (6) — todos verdes; sem regressão em `test/controllers/admin/clients_controller_test.rb` (8).

## Task Commits

Each task was committed atomically:

1. **Task 1: Whatsapp::SyncGroupsJob — TDD RED** - `5f20bcf` (test)
2. **Task 1: Whatsapp::SyncGroupsJob — TDD GREEN** - `e5f4870` (feat)
3. **Task 2: #sync + #sync_status + throttle + testes de controller** - `df1c286` (feat)
4. **Task 3: group_sync_controller.js + painel + helper** - `22446c8` (feat)

**Plan metadata:** (este commit, a seguir)

## Files Created/Modified
- `app/jobs/whatsapp/sync_groups_job.rb` — primeiro ActiveJob do repo
- `test/jobs/whatsapp/sync_groups_job_test.rb` — 9 testes (retry/discard/perform/token safety)
- `app/controllers/admin/whatsapp_groups_controller.rb` — `#sync` + `#sync_status`
- `test/controllers/admin/whatsapp_groups_controller_test.rb` — 6 testes
- `config/initializers/rack_attack.rb` — throttle `admin/whatsapp_groups_sync_by_ip`
- `app/javascript/controllers/group_sync_controller.js` — poller Stimulus
- `app/views/admin/whatsapp_instances/_panel.html.erb` — botão + link
- `app/helpers/admin/whatsapp_groups_helper.rb` — `wa_groups_synced_label`
- `.planning/phases/.../scripts/27-02-helper.rb` — runner de verificação (não deliverable, ferramenta de prova)
- `.planning/phases/.../deferred-items.md` — item fora de escopo registrado (ver Issues Encountered)

## Decisions Made
- Guard anti-spam de cache implementado como parte fixa de `#sync` (não pulado), seguindo o precedente `pull_fresh_qr` — ver frontmatter `key-decisions` para o raciocínio completo.
- Botão "Sincronizar grupos" no painel usa estilo secundário (o CTA primário verde é reservado para a página de grupos, 27-UI-SPEC).
- Toast do poller construído via DOM direto (`createElement`), reaproveitando a classe/estrutura e o `toast_controller.js` existentes — não há canal de Turbo Stream broadcast disponível para um poll síncrono no browser.
- `GRUPO-01` marcado completo em `REQUIREMENTS.md` (só 27-01+27-02 o declaram, ambos concluídos). `GRUPO-02` continua em aberto — também declarado por 27-03, que roda em paralelo nesta wave e ainda não tem SUMMARY (shared-ID gate).

## Deviations from Plan

None - plan executado como escrito. O guard de cache anti-spam, descrito no plano como "opcional", foi implementado porque o próprio texto do plano fornece o código literal a adicionar (ver Decisions Made) — não é uma adição além do que o plano pediu.

## Issues Encountered

- **`test/controllers/admin/dashboard_controller_test.rb:70` falha em isolamento, sem relação com este plano.** Nenhum arquivo tocado por 27-02 tem relação com `Admin::DashboardController`, o sidebar badge, `Arte` ou `ApprovalResponse`. Mesma família das 3 falhas pré-existentes já documentadas em `27-01-SUMMARY.md` (`arte_test.rb:94`, `approval_response_test.rb:158,174` — asserções de turbo-stream/N+1 desalinhadas com o HTML/broadcast atual). Não corrigido aqui (fora de escopo); registrado em `deferred-items.md`.
- **Acesso a banco/segredos neste worktree**: mesmo workaround documentado em `27-01-SUMMARY.md` — `.bundle/config` apontando `BUNDLE_PATH` para o `vendor/bundle` do checkout principal (gems compartilhados, read-only) e `config/master.key` copiado (chave local de decrypt, não um novo segredo). `bin/rails test`/`runner` rodaram com `POSTGRES_HOST=/var/run/postgresql` (socket unix local, sem senha). Ambos os arquivos são gitignored — não aparecem em nenhum commit deste plano.

## Known Stubs

Nenhum stub introduzido por este plano. `group_sync_controller.js` não é wired (nenhuma view usa `data-controller="group-sync"` ainda) — isso é escopo explícito do 27-03 (a view `admin/whatsapp_groups/index.html.erb`, que ainda não existe), não um stub deste plano: o arquivo é criado pronto para uso, com os targets (`error`, `timeout`, `status`) que a view do 27-03 vai referenciar.

## User Setup Required

None - nenhuma configuração de serviço externo necessária neste plano. O worker solid_queue precisa estar rodando (`bin/jobs`) para `perform_later` executar de verdade em dev/prod — item de UAT/operação, não de setup deste plano.

## Next Phase Readiness

- Base pronta para o 27-03 (picker escopado + estados de tela): `group_sync_controller.js` já expõe os targets (`error`, `timeout`, `status`) e values (`statusUrl`, `since`) que a view precisa wire-ar; `wa_groups_synced_label` já formata o timestamp que a view vai prefixar com "Sincronizado pela última vez em "; `#sync_status` já responde o contrato JSON completo.
- **Sem bloqueios.** Nenhum item de `Deviations`/`Issues Encountered` impede o avanço — a falha de `dashboard_controller_test.rb` é pré-existente e não relacionada.
- Disparo real de sync contra uma instância pareada de verdade (worker solid_queue + host Evolution) permanece item de UAT consolidado de fim de fase, herdado da fase 26.

---
*Phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada*
*Completed: 2026-08-30*

## Self-Check: PASSED

- `app/jobs/whatsapp/sync_groups_job.rb`, `test/jobs/whatsapp/sync_groups_job_test.rb`,
  `app/controllers/admin/whatsapp_groups_controller.rb`,
  `test/controllers/admin/whatsapp_groups_controller_test.rb`,
  `config/initializers/rack_attack.rb`, `app/javascript/controllers/group_sync_controller.js`,
  `app/views/admin/whatsapp_instances/_panel.html.erb`,
  `app/helpers/admin/whatsapp_groups_helper.rb`,
  `.planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/scripts/27-02-helper.rb` —
  todos confirmados em disco.
- Commits confirmados em `git log --oneline --all`: `5f20bcf`, `e5f4870`, `df1c286`, `22446c8`.
- `bin/rails test test/jobs/whatsapp/sync_groups_job_test.rb test/controllers/admin/whatsapp_groups_controller_test.rb`:
  15 runs, 62 assertions, 0 failures, 0 errors.
- Runner `27-02-helper.rb`: `HELPER OK`.
- Runner de token: `OK no token in args`.
- Runner de throttle: `THROTTLE OK`.
- Greps de `group_sync_controller.js`: sem CSRF, sem `console.`, com `disconnect`+`clearInterval` — todos OK.
- `bin/rails routes -g whatsapp_groups`: `sync`/`sync_status` com os nomes de helper usados na view.
