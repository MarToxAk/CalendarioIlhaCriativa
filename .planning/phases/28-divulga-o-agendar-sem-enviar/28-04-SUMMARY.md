---
phase: 28-divulga-o-agendar-sem-enviar
plan: 04
subsystem: ui
tags: [rails, erb, divulgacao, pt-br, empty-states, cancel, clients-show]

requires:
  - phase: 28-divulga-o-agendar-sem-enviar
    provides: "divulgacoes/divulgacao_grupos schema, Divulgacao/DivulgacaoGrupo models, Admin::DivulgacoesController#create happy path, criacao-time validations, Admin::DivulgacoesHelper#divulgacao_datetime_label/#divulgacao_duration_estimate, new.html.erb com preview+estimate+picker wiring (plano 03)"
provides:
  - "Admin::DivulgacoesController#new/#create com guardas server-side (sem whatsapp_instance / sem arte aprovada -> re-render :new 422 antes de tocar arte_id/grupos)"
  - "new.html.erb com os tres estados completos (empty sem instancia, empty sem arte aprovada, card+form com banner amber + submit disabled quando nao-connected ou zero grupos ativos)"
  - "index.html.erb completo (empty state, tabela desktop + lista mobile, pagy_nav) substituindo o stub minimo do plano 01"
  - "_status_badge.html.erb (locals: divulgacao:) -- paleta canonica agendada/cancelada/em_andamento/concluida"
  - "Divulgacao#cancelar! -- agendada -> cancelada, sem params, idempotente"
  - "Admin::DivulgacoesController#show/#cancel + set_divulgacao escopado (@client.divulgacoes.find) -- cross-client id 404"
  - "show.html.erb (Detalhes/Grupos(N)/Previa) + _grupo_row.html.erb (locals: dg:) -- nome de grupo congelado + pill de status"
  - "Admin::ClientsController#show @divulgacoes + card 'Divulgacoes' (entry point 'Nova divulgacao' + espelho das 5 mais recentes + 'Ver todas')"
affects: [29-motor-de-envio, 30-acompanhamento-ao-vivo-hardening]

actuals:
  tokens: 10600
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Guarda server-side replicada no controller antes de qualquer resolucao de params (arte_id/grupos) -- a view so tem o estado vazio pra mostrar quando @instance.nil? || @approved_artes.empty?, entao #create sai cedo sem tentar @client.artes.find"
    - "Snapshot de status via case/when em vez de hash de paleta -- 4 partials (_status_badge de divulgacoes.status, _grupo_row inline de divulgacao_grupos.status) repetem a MESMA forma de pill (inline-flex ... rounded-full ... border + glifo bullet) sem componentizar, seguindo o precedente ja estabelecido em whatsapp_groups/show e whatsapp_instances/_connection_badge"
    - "Cross-client 404 via before_action escopado (@client.divulgacoes.find) -- mesmo padrao de @client.artes.find e whatsapp_groups#set_group; Rails :rescuable em test transforma RecordNotFound em response 404 em vez de propagar a excecao pro teste (assert_response :not_found, nao assert_raises)"

key-files:
  created:
    - app/views/admin/divulgacoes/_status_badge.html.erb
    - app/views/admin/divulgacoes/_grupo_row.html.erb
    - app/views/admin/divulgacoes/show.html.erb
  modified:
    - app/controllers/admin/divulgacoes_controller.rb (new/#create guards, set_divulgacao, #show, #cancel)
    - app/models/divulgacao.rb (cancelar!)
    - app/views/admin/divulgacoes/new.html.erb (3 estados + banner + submit disabled)
    - app/views/admin/divulgacoes/index.html.erb (lista completa substituindo o stub)
    - app/controllers/admin/clients_controller.rb (@divulgacoes)
    - app/views/admin/clients/show.html.erb (card Divulgacoes)
    - test/controllers/admin/divulgacoes_controller_test.rb (14 testes novos)
    - test/controllers/admin/clients_controller_test.rb (2 testes novos)
    - test/models/divulgacao_test.rb (2 testes novos)

key-decisions:
  - "_status_badge.html.erb criado na Task 1 (nao na Task 2 como o plano listava) -- a view index.html.erb da propria Task 1 ja renderiza `render \"status_badge\", divulgacao: d` (linha explicita na acao da Task 1 do plano), entao o partial precisava existir pra a Task 1 compilar. Implementado ja com a paleta completa (4 estados) especificada pela Task 2, entao a Task 2 so reutilizou sem retrabalho."
  - "Guardas de teste 'sem <form' reescritas para checar a ausencia de `name=\"divulgacao[arte_id]\"` em vez de `/<form/` -- o layout admin (`layouts/admin.html.erb`) tem seu proprio `<form>` de logout no sidebar, entao um regex `<form` cru sempre da match independente do estado da pagina de divulgacao."
  - "Testes de cross-client 404 e 'sem rota destroy' usam `assert_response :not_found` em vez de `assert_raises(ActiveRecord::RecordNotFound)` -- `config.action_dispatch.show_exceptions = :rescuable` (Rails 8 default em test) converte excecoes rescuaveis (incluindo RecordNotFound e a falta de rota) numa resposta HTTP normal dentro do integration test, nao propaga a excecao pro bloco do teste."
  - "Submit do form desabilitado tambem quando zero grupos ativos (alem de instancia nao-connected) -- `@client.whatsapp_instance.whatsapp_groups.where(active: true).none?`, consistente com o UI-SPEC 'Empty picker' que ja bloqueia a selecao mas nao desabilitava o botao por si."

patterns-established:
  - "Ordem de secoes no show.html.erb (Detalhes -> Grupos(N) -> Previa) como 3 cards `mt-4` empilhados, mesma forma de card+section-heading das outras telas admin -- reusavel por fases futuras (29/30) que vao adicionar dados a essas mesmas secoes (ex.: sent_at/error_code em Grupos)."

requirements-completed: [DIVU-05, DIVU-01, DIVU-09]

coverage:
  - id: D8
    description: "new sem whatsapp_instance -> empty state completo, sem <form de divulgacao"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET new sem whatsapp_instance"
        status: pass
    human_judgment: false
  - id: D9
    description: "new com instancia nao-connected -> banner amber + submit disabled, form ainda renderiza"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET new com instancia disconnected"
        status: pass
    human_judgment: false
  - id: D10
    description: "new sem arte aprovada -> empty state completo, sem form"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET new sem arte aprovada"
        status: pass
    human_judgment: false
  - id: D11
    description: "index vazio/populado -> empty state ou tabela+cards mobile com pagy_nav"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET index vazio / GET index com 2 registros"
        status: pass
    human_judgment: false
  - id: D12
    description: "show renderiza Detalhes/Grupos(N)/Previa com (BRT) explicito e pill Pendente por grupo"
    requirement: DIVU-05
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET show de divulgacao agendada"
        status: pass
    human_judgment: false
  - id: D13
    description: "cancelar! flipa agendada->cancelada, idempotente, preserva registro e divulgacao_grupos"
    requirement: DIVU-09
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#cancelar!"
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#PATCH cancel"
        status: pass
    human_judgment: false
  - id: D14
    description: "cross-client 404 em #show/#cancel, sem vazamento de dados de outro cliente no corpo"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#GET show / PATCH cancel de divulgacao de OUTRO cliente"
        status: pass
    human_judgment: false
  - id: D15
    description: "clients#show ganha entry point 'Nova divulgacao' + espelho das 5 mais recentes + 'Ver todas'"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/clients_controller_test.rb#show com 0/6 divulgacoes"
        status: pass
    human_judgment: false

duration: ~40min
completed: 2026-08-30
status: complete
---

# Phase 28 Plan 04: Estados, Show/Cancel e Entry Point Summary

**Fechamento da superfície de Divulgação: guardas de `#new`/`#create` para os quatro estados bloqueados, `index` completo, `show` com histórico congelado por grupo (BRT explícito), `patch :cancel` sem destroy, e o ponto de entrada em `clients#show`**

## Performance

- **Duration:** ~40min
- **Tasks:** 3
- **Files modified:** 12 (3 criados, 9 modificados)

## Accomplishments
- `#new`/`#create` agora guardam server-side contra os dois estados que bloqueiam totalmente o agendamento (sem `whatsapp_instance`, sem arte aprovada) — a view nunca renderiza o form nesses casos, e `#create` sai antes de tentar resolver `arte_id`/grupos.
- `new.html.erb` cobre os quatro estados do UI-SPEC: dois empty states de página inteira, um banner âmbar de instância desconectada (form ainda visível, submit `disabled`), e o card+form normal — com o submit também desabilitado quando o cliente tem zero grupos ativos.
- `index.html.erb` deixou de ser o stub mínimo do plano 01 e agora tem empty state, tabela desktop + lista de cards mobile (padrão `artes/index` verbatim) e `pagy_nav` centralizado quando há mais de uma página.
- `show.html.erb` renderiza as três seções (Detalhes / Grupos (N) / Prévia) com o nome de grupo **congelado** (nunca uma busca ao vivo no `WhatsappGroup`) e todo datetime carregando o sufixo `(BRT)` explícito via `divulgacao_datetime_label`.
- `Divulgacao#cancelar!` + `Admin::DivulgacoesController#cancel` — `patch :cancel` (rota já existia desde o plano 01) flipa `agendada → cancelada` sem ler nenhum parâmetro, é idempotente num replay, e não existe `destroy` em lugar nenhum (rota, controller, botão).
- `admin/clients#show` ganhou o card "Divulgações": botão pequeno "Nova divulgação" no header + as 5 divulgações mais recentes (título da arte, data/hora BRT, pill de status, "Ver") + link "Ver todas" quando há mais de 5.

## Task Commits

Each task was committed atomically:

1. **Task 1: #new guards + all empty/blocked states + full divulgacoes#index** - `fb684e2` (feat)
2. **Task 2: #show + _grupo_row + _status_badge + #cancel + Divulgacao#cancelar!** - `abbfc75` (feat)
3. **Task 3: entry point + recent-divulgações mirror card on admin/clients#show** - `6c4d97e` (feat)

## Files Created/Modified
- `app/controllers/admin/divulgacoes_controller.rb` - guardas de `#new`/`#create`, `set_divulgacao` escopado, `#show`, `#cancel`
- `app/models/divulgacao.rb` - `cancelar!` (agendada → cancelada, sem params, idempotente)
- `app/views/admin/divulgacoes/new.html.erb` - três estados (empty sem instância / empty sem arte / card+form com banner+disabled)
- `app/views/admin/divulgacoes/index.html.erb` - lista completa (empty state, tabela desktop, cards mobile, pagy_nav)
- `app/views/admin/divulgacoes/_status_badge.html.erb` - **criado** (locals: `divulgacao:`) — paleta agendada/cancelada/em_andamento/concluída
- `app/views/admin/divulgacoes/_grupo_row.html.erb` - **criado** (locals: `dg:`) — nome congelado + pill de status pendente/enviado/falhou/incerto
- `app/views/admin/divulgacoes/show.html.erb` - **criado** — Detalhes/Grupos(N)/Prévia + banner cancelada + botão cancelar condicional
- `app/controllers/admin/clients_controller.rb` - `@divulgacoes = @client.divulgacoes.includes(:arte).order(scheduled_for: :desc)`
- `app/views/admin/clients/show.html.erb` - card "Divulgações" (entry point + espelho das 5 mais recentes + "Ver todas")
- `test/controllers/admin/divulgacoes_controller_test.rb` - 14 testes novos (6 na Task 1, 8 na Task 2)
- `test/controllers/admin/clients_controller_test.rb` - 2 testes novos (Task 3)
- `test/models/divulgacao_test.rb` - 2 testes novos (`cancelar!`)

## Decisions Made
- `_status_badge.html.erb` foi criado já na Task 1 (não na Task 2, como o plano listava nos `files_modified`) porque a própria ação da Task 1 do plano já descreve `render "status_badge", divulgacao: d` dentro de `index.html.erb` — o partial precisava existir para a Task 1 compilar. Implementado desde já com a paleta completa dos 4 estados (a mesma que a Task 2 especifica), então a Task 2 só reutilizou sem retrabalho nem divergência de estilo.
- Testes de "form não renderizado" reescritos para checar `name="divulgacao[arte_id]"` em vez de um regex `/<form/` cru — o layout admin tem seu próprio `<form>` de logout no sidebar (presente em toda página), então `/<form/` sempre dava match independente do estado da divulgação.
- Testes de 404 cross-client e de ausência de rota `destroy` usam `assert_response :not_found` em vez de `assert_raises(ActiveRecord::RecordNotFound)` — o ambiente de teste roda com `config.action_dispatch.show_exceptions = :rescuable` (Rails 8), que converte `RecordNotFound` e falhas de roteamento numa resposta HTTP normal dentro do integration test, sem propagar a exceção pro bloco do teste.
- O submit do form fica `disabled` também quando o cliente tem zero grupos ativos (além do caso "instância não conectada") — consistente com o UI-SPEC, que já bloqueia a seleção no picker mas não amarrava isso ao estado do botão.

## Deviations from Plan

**1. [Rule 2 - dependência de ordem entre arquivos do plano] `_status_badge.html.erb` criado na Task 1, não na Task 2**
- **Found during:** Task 1
- **Issue:** o plano lista `_status_badge.html.erb` nos `files` da Task 2, mas a própria `<action>` da Task 1 já instrui `render "status_badge", divulgacao: d` dentro de `index.html.erb` — sem o partial, `index.html.erb` da Task 1 não compilaria.
- **Fix:** criado o partial já na Task 1, com a paleta completa dos 4 estados especificada na Task 2 (`agendada`/`cancelada`/`em_andamento`/`concluída`), para que a Task 2 só reutilizasse sem retrabalho.
- **Files modified:** `app/views/admin/divulgacoes/_status_badge.html.erb`
- **Commit:** `fb684e2`

Nenhum outro desvio — as três tasks seguiram a ação descrita no plano à risca (guardas server-side, três estados de `new`, `index` completo, `show` com as três seções, `cancelar!` idempotente sem params, card espelho em `clients#show`).

## Issues Encountered

Nenhum bloqueio. Ambiente de teste seguiu o mesmo workaround dos planos anteriores desta fase: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test <files>` (socket Unix — `.env` é bloqueado pelo sandbox pra agentes) e um `.bundle/config` gitignored no worktree apontando `BUNDLE_PATH` pro `vendor/bundle` do checkout principal (`/home/bot/calendario_livia/vendor/bundle`).

Suíte completa rodada ao final (`bin/rails test`, sem filtro de arquivo): **405 runs, 42 errors, 10 failures** — todas em arquivos não tocados por este plano (`rack_attack_test.rb`, `approval_response_test.rb`, `arte_test.rb`, `dashboard_controller_test.rb`, `whatsapp_instances_controller_test.rb`, `webhooks/evolution_controller_test.rb`, `whatsapp/group_synchronizer_test.rb`, `whatsapp/sync_groups_job_test.rb`, `whatsapp_group_test.rb`, `whatsapp_instance_test.rb`, `client/home_controller_test.rb`, `api/v1/ai/clients_controller_test.rb`). A causa raiz é ambiental/pré-existente: `EVOLUTION_WEBHOOK_HMAC_KEY` não configurado no sandbox (`Evolution::Errors::ConfigurationError`), mais alguns testes de N+1/broadcast/rate-limit sensíveis a ordem de execução — nenhum deles relacionado a `divulgacoes` ou `clients`. O escopo de verificação do próprio plano (`divulgacoes_controller_test.rb` + `clients_controller_test.rb` + `divulgacao_test.rb`) roda **65/65 green** isoladamente.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Fase 28 completa: schema, CRUD (`new`/`create`/`index`/`show`), validações de criação, preview, estimativa de duração, e agora todos os estados vazios/bloqueados + `#cancel` + entry points. O motor de envio (fase 29) pode começar a partir daqui.
- Contrato que a fase 29 (ENVIO) precisa respeitar, documentado em código: `patch :cancel` → `Divulgacao#cancelar!` → `status: :cancelada` só a partir de `agendada`; a fase 29 precisa checar esse status antes de disparar cada grupo (DIVU-08, explicitamente fora desta fase).
- `divulgacao_grupos.status` (`pendente/enviado/falhou/incerto`) e `divulgacoes.status` (`agendada/em_andamento/concluida/cancelada`) já têm pills prontas em `_grupo_row.html.erb`/`_status_badge.html.erb` para os três estados que a fase 29/30 vão passar a produzir de fato.
- Follow-up não bloqueante (fora de escopo desta fase): a suíte completa do repositório tem falhas ambientais pré-existentes não relacionadas a este plano (ver "Issues Encountered") — recomenda-se configurar `EVOLUTION_WEBHOOK_HMAC_KEY` no ambiente de CI/sandbox para eliminar o ruído nos runs futuros.

---
*Phase: 28-divulga-o-agendar-sem-enviar*
*Completed: 2026-08-30*

## Self-Check: PASSED

Todos os 13 arquivos citados (criados/modificados) confirmados presentes no worktree via `ls`. Os 3 hashes de commit de task (`fb684e2`, `abbfc75`, `6c4d97e`) confirmados presentes em `git log --oneline --all`.
