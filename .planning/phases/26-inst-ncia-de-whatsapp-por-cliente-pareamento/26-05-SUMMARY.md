---
phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
plan: 05
subsystem: ui
tags: [tailwind, stimulus, turbo, whatsapp-pairing, admin-panel]

requires:
  - phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento
    provides: "WhatsappInstance model (connection_state_label, paired_days/recently_paired?, map_evolution_state — 26-01), InstanceProvisioner create+adopt (26-01/26-02), Webhooks::EvolutionController (26-03), Admin::WhatsappInstancesController#verify/#refresh_qr/#reconnect (26-04)"
provides:
  - "Badge de estado de conexão (admin/whatsapp_instances/_connection_badge) — 4 variantes de cor pela tabela canônica do UI-SPEC, reutilizado no show e no index"
  - "Coluna 'Conexão' em admin/clients#index — bolinha por cliente (verde/âmbar/vermelha/oca), sem N+1 (includes(:whatsapp_instance))"
  - "qr_pairing_controller.js — polling real de refresh_qr a cada 20s, MAX_CYCLES=6, disconnect() com clearInterval, nunca re-prefixa o data-URI"
  - "Admin::WhatsappInstancesHelper#wa_last_checked_label / #wa_paired_age_text — copy pt-BR exata do UI-SPEC"
  - "admin/whatsapp_instances/_panel.html.erb — card WhatsApp completo (empty/QR+banner de banimento/cautela de idade/ações), substitui o card mínimo do 26-01 em clients#show"
affects: []

actuals:
  tokens: 4425
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Contexto de estado 'connected' em camadas independentes: linha de identidade (fresh-pair XOR adotada) + parágrafo de cautela de idade sempre anexado quando recently_paired?, nunca mutuamente exclusivos"
    - "qr_pairing_controller.js espelha o teardown de toast_controller.js (disconnect -> clearInterval) — nenhum novo padrão de timer no projeto"

key-files:
  created:
    - app/views/admin/whatsapp_instances/_connection_badge.html.erb
    - app/views/admin/whatsapp_instances/_qr.html.erb
    - app/views/admin/whatsapp_instances/_panel.html.erb
    - app/helpers/admin/whatsapp_instances_helper.rb
    - app/javascript/controllers/qr_pairing_controller.js
  modified:
    - app/controllers/admin/clients_controller.rb
    - app/views/admin/clients/index.html.erb
    - app/views/admin/clients/_client_row.html.erb
    - app/views/admin/clients/show.html.erb

key-decisions:
  - "Sem botão 'Adotar instância existente' — decisão de design registrada no <objective> do plano: a adoção automática do 26-02 já fecha PAIR-02 funcionalmente dentro do mesmo clique em 'Criar instância'; o fluxo de dois passos do UI-SPEC não é construído."
  - "Flash banner (não toast/turbo_stream) para o feedback de 'Forçar verificação' — data-turbo-submits-with nativo do Turbo resolve o estado 'Verificando…' sem infra nova; os controllers de 26-01/26-02/26-04 já usam notice/alert."
  - "Contexto de estado 'connected' desacopla identidade (fresh-pair vs adotada) de recência (cautela <7 dias) — uma instância adotada E recém-pareada mostra AS DUAS linhas, nunca uma suprime a outra, para não perder a garantia PAIR-08 em nenhuma combinação de estado."

patterns-established:
  - "connection_badge.html.erb é a fonte única de cor/rótulo por connection_state — reutilizado em show (dl) e index (potencialmente), evita reimplementação da tabela de cores"

requirements-completed: [PAIR-03, PAIR-04, PAIR-07, PAIR-08]

coverage:
  - id: D1
    description: "admin/clients#index mostra bolinha de conexão por cliente (4 variantes incluindo oca para zero) sem N+1"
    requirement: "PAIR-04"
    verification:
      - kind: unit
        ref: "grep includes(:whatsapp_instance) em admin/clients_controller.rb"
        status: pass
      - kind: unit
        ref: "ruby -e checagem das 4 cores em _connection_badge.html.erb"
        status: pass
      - kind: integration
        ref: "bin/rails runner — GET autenticado real /admin/clients com 1 cliente sem instância + 1 connected -> title=\"Sem instância\" e title=\"Conectada\" presentes"
        status: pass
    human_judgment: false
  - id: D2
    description: "qr_pairing_controller.js: disconnect() limpa o timer, nunca re-prefixa data:image/png;base64, e usa MAX_CYCLES=6"
    requirement: "PAIR-03"
    verification:
      - kind: unit
        ref: "ruby -e inspeção estática do shape do controller Stimulus"
        status: pass
    human_judgment: false
  - id: D3
    description: "Banner de risco de banimento (PAIR-07) sempre visível acima do QR quando awaiting_qr, sem checkbox, com a copy exata do UI-SPEC"
    requirement: "PAIR-07"
    verification:
      - kind: unit
        ref: "grep da copy exata em _qr.html.erb"
        status: pass
      - kind: integration
        ref: "bin/rails runner — GET autenticado real numa instância awaiting_qr: banner presente, img src = data-URI sem re-prefixo, nenhum <input type=\"checkbox\"> na página"
        status: pass
    human_judgment: false
  - id: D4
    description: "Helpers wa_last_checked_label/wa_paired_age_text produzem a copy pt-BR exata do Copywriting Contract (incluindo a cautela <7 dias)"
    requirement: "PAIR-08"
    verification:
      - kind: unit
        ref: "bin/rails runner — FakeView com Admin::WhatsappInstancesHelper: \"há 1 min\" e cautela contendo \"menos de 7 dias\""
        status: pass
    human_judgment: false
  - id: D5
    description: "clients/show.html.erb renderiza o panel completo; GET real numa instância connected recém-pareada mostra badge + cautela de idade + Forçar verificação (turbo_submits_with)"
    requirement: "PAIR-04"
    verification:
      - kind: integration
        ref: "bin/rails runner — GET autenticado real /admin/clients/:id (connected, paired_at 2 dias): body inclui \"Conectada\", \"menos de 7 dias\", \"Forçar verificação\""
        status: pass
      - kind: integration
        ref: "bin/rails runner — GET real nos 4 estados (sem instância, awaiting_qr, connected recém-pareada, disconnected): empty-state, QR+banner, cautela, badge Desconectada + botão Parear novamente todos presentes"
        status: pass
    human_judgment: false
  - id: D6
    description: "Nenhuma regressão na suíte de testes automatizados — mesmo baseline de 19 falhas pré-existentes documentado em 26-01..26-04"
    verification:
      - kind: integration
        ref: "bin/rails test (suíte completa): 287 runs, 19 failures, 0 errors — idêntico ao baseline"
        status: pass
      - kind: integration
        ref: "bin/rails test test/controllers/admin/clients_controller_test.rb test/controllers/admin/whatsapp_instances_controller_test.rb test/models/whatsapp_instance_test.rb: 30 runs, 0 failures"
        status: pass
    human_judgment: false
  - id: D7
    description: "Verificação visual humana (cor do badge, legibilidade do banner âmbar, quebra de layout, responsividade da bolinha no index)"
    human_judgment: true
    rationale: "O <human-check> do plano cobre 4 itens que só um humano pode confirmar visualmente (contraste de cor real, legibilidade do banner em tela, ausência de quebra de layout no card 'Informações' acima, comportamento da bolinha do index em telas estreitas). As checagens automatizadas provaram presença/ausência de texto e estrutura HTML (bin/rails runner com sessão autenticada real), não a aparência renderizada — esta sessão não tem `bin/dev`/browser disponível para captura de tela."

duration: ~15min
completed: 2026-08-30
status: complete
---

# Phase 26 Plan 05: Polimento Visual Completo — Badge, QR Rotativo, Banner de Banimento e Cautela de Idade Summary

**Badge de 4 cores por `connection_state` (index sem N+1 + show), Stimulus `qr_pairing_controller.js` com polling real de 20s e teardown obrigatório, banner âmbar de risco de banimento sempre visível acima do QR e aviso de idade do pareamento com cautela <7 dias — tudo com a copy exata do `26-UI-SPEC.md` aprovado, provado por 4 requests autenticados reais cobrindo os 4 estados de conexão.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-30T13:46:00Z (aprox.)
- **Completed:** 2026-08-30T13:47:00Z (aprox.)
- **Tasks:** 3
- **Files modified:** 9 (5 criados, 4 modificados)

## Accomplishments

- `admin/whatsapp_instances/_connection_badge.html.erb` — pill de 4 cores (verbatim do shape de `_status_badge.html.erb`) cobrindo `connected` (+ sufixo "(adotada)"), `awaiting_qr`, `disconnected` e `unpaired`/sem instância, com os hex/classes exatos da tabela canônica do UI-SPEC.
- `admin/clients_controller#index` passa a usar `Client.includes(:whatsapp_instance)`; nova coluna "Conexão" no `clients#index` com uma bolinha `w-2 h-2` por cliente — oca (`border border-slate-300`) quando não há instância, nunca uma célula em branco.
- `qr_pairing_controller.js` — Stimulus controller novo: `connect()` faz o primeiro poll imediato e arma `setInterval` de 20s; `disconnect() { clearInterval(this.timer) }` obrigatório (Pitfall 10); ao ler `state === "connected"` limpa o timer e recarrega a página via `Turbo.visit`; após `MAX_CYCLES = 6` revela o alvo `regenerate`; nunca reconstrói o prefixo `data:image/png;base64,` (o valor do backend já é o data-URI completo).
- `Admin::WhatsappInstancesHelper` — `wa_last_checked_label` (há pouco / há N min / há N h) e `wa_paired_age_text` (linha neutra ≥7 dias, cautela âmbar <7 dias) com a copy pt-BR verbatim do Copywriting Contract.
- `admin/whatsapp_instances/_qr.html.erb` — banner âmbar de risco de banimento (PAIR-07) SEMPRE visível acima do QR quando `awaiting_qr?`, sem checkbox; texto auxiliar de como escanear; bloco `data-controller="qr-pairing"` com `<img>` (placeholder "Gerando QR Code…" quando ainda não há QR) e botão oculto "Gerar novo QR".
- `admin/whatsapp_instances/_panel.html.erb` — card WhatsApp completo: empty-state (herdado do 26-01), `<dl>` Estado/Última verificação, linha de contexto por estado (fresh-pair / adotada / cautela de idade — as duas últimas nunca se excluem, garantindo PAIR-08 mesmo numa instância adotada e recém-pareada), QR quando `awaiting_qr?`, botão "Forçar verificação" (`data-turbo-submits-with: "Verificando…"`, sempre visível) e botão "Parear novamente" com modal de confirmação `warning` (apenas `connected`/`disconnected`).
- `clients/show.html.erb` — o card WhatsApp mínimo do 26-01 foi substituído por `render "admin/whatsapp_instances/panel"`.
- Verificação real (não mockada): GETs autenticados via `ActionDispatch::Integration::Session` cobrindo os 4 estados de conexão (sem instância, `awaiting_qr` recém-criado, `connected` recém-pareado com adoção neutra, `disconnected` antigo) — todos renderizam com o HTML esperado, sem re-prefixar o base64 e sem `<input type="checkbox">` no banner.

## Task Commits

Each task was committed atomically:

1. **Task 1: Badge de estado + coluna "Conexão" no index (PAIR-04)** - `32987db` (feat)
2. **Task 2: QR pairing — Stimulus polling + banner de banimento + cautela de idade (PAIR-03, PAIR-07, PAIR-08)** - `c23ce30` (feat)
3. **Task 3: Montar _panel.html.erb completo + substituir card mínimo em clients#show** - `3a12494` (feat)

**Plan metadata:** commit pendente (docs, gerado após este SUMMARY)

## Files Created/Modified

- `app/views/admin/whatsapp_instances/_connection_badge.html.erb` — badge de 4 cores por `connection_state`
- `app/views/admin/whatsapp_instances/_qr.html.erb` — banner de banimento + bloco de polling do QR
- `app/views/admin/whatsapp_instances/_panel.html.erb` — card WhatsApp completo
- `app/helpers/admin/whatsapp_instances_helper.rb` — `wa_last_checked_label`, `wa_paired_age_text`
- `app/javascript/controllers/qr_pairing_controller.js` — polling Stimulus do QR
- `app/controllers/admin/clients_controller.rb` — `#index` com `includes(:whatsapp_instance)`
- `app/views/admin/clients/index.html.erb` — `<th>` "Conexão"
- `app/views/admin/clients/_client_row.html.erb` — `<td>` com a bolinha de conexão
- `app/views/admin/clients/show.html.erb` — renderiza `admin/whatsapp_instances/panel`

## Decisions Made

- **Sem botão "Adotar instância existente"** — decisão de design já registrada explicitamente no `<objective>` do plano (rastreabilidade RESEARCH vs UI-SPEC): a adoção automática do 26-02 fecha PAIR-02 dentro do próprio clique em "Criar instância"; o fluxo de dois passos do UI-SPEC não foi construído porque criaria um caminho morto.
- **Flash banner, não toast/turbo_stream, para o feedback do "Forçar verificação"** — `data-turbo-submits-with` nativo resolve o estado "Verificando…" sem exigir infraestrutura de turbo_stream que inverteria a ordem de dependência entre este plano e o 26-04.
- **Contexto de estado "connected" desacopla identidade de recência** — uma instância `connected` E `origin_adopted_existing?` E `recently_paired?` mostra as DUAS linhas (a de identidade "adotada" e a cautela de idade âmbar), nunca uma suprimindo a outra. Essa é uma interpretação deliberada da ambiguidade textual do plano (as três regras de contexto por estado não eram mutuamente exclusivas no enunciado) resolvida a favor de nunca perder a garantia PAIR-08 em nenhuma combinação de origem/recência.

## Deviations from Plan

None - plano executado exatamente como especificado, incluindo a resolução de design já documentada no próprio `<objective>` (sem botão de adoção manual). A única decisão de implementação não 100% literal do texto do plano foi a ordem/independência das linhas de contexto do estado `connected` (ver "Decisions Made" acima) — não é uma mudança de escopo, é uma leitura da especificação que prioriza a garantia mais forte (PAIR-08 nunca suprimida).

## Issues Encountered

None relacionado a este plano. A suíte completa (`bin/rails test`) mantém as mesmas 19 falhas pré-existentes já documentadas em 26-01/26-02/26-03/26-04 (nenhum arquivo tocado por este plano está entre elas) — confirmado rodando a suíte completa antes de commitar a Task 3.

## User Setup Required

None - nenhuma configuração de serviço externo neste plano.

## Known Stubs

None. Todos os estados (empty/loading/error/populated/partial/stale) do `## UI Considerations` do UI-SPEC estão refletidos nas views reais: empty-state (client sem instância), loading (`Gerando QR Code…`), error (mensagens de falha já entregues nos controllers do 26-04, reutilizadas via flash), populado (4 estados de conexão), parcial (adotada não-`open`), stale (`Última verificação` sempre visível com `title=` do timestamp completo + "Forçar verificação" como escape hatch).

## Next Phase Readiness

- PAIR-03, PAIR-04, PAIR-07 e PAIR-08 fechados — última fase pendente da fase 26 (todos os 5 planos têm SUMMARY.md).
- Fase 26 completa: nenhum blocker aberto para a fase 27 (Grupos do Cliente).
- Verificação visual humana (cor real, legibilidade, responsividade) permanece como item de UAT — ver `## Coverage` D7 acima; nenhuma automação neste ambiente tem acesso a `bin/dev`/browser para captura de tela.

---
*Phase: 26-inst-ncia-de-whatsapp-por-cliente-pareamento*
*Completed: 2026-08-30*

## Self-Check: PASSED
