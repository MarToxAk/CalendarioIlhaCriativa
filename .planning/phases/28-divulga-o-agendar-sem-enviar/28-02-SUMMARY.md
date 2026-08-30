---
phase: 28-divulga-o-agendar-sem-enviar
plan: 02
subsystem: database
tags: [rails, activerecord, validations, activestorage, timezone, divulgacao, pt-br]

requires:
  - phase: 28-divulga-o-agendar-sem-enviar
    provides: "divulgacoes/divulgacao_grupos schema, Divulgacao/DivulgacaoGrupo models, Admin::DivulgacoesController#create happy path, Admin::DivulgacoesHelper#divulgacao_datetime_label, new.html.erb com caixa errors[:base]"
provides:
  - "5 validacoes de criacao no Divulgacao: arte_deve_estar_aprovada (DIVU-02), arte_nao_usa_link_externo (DIVU-03 — so external_url, caption_only aceito), arquivo_dentro_do_teto_whatsapp (DIVU-04 — so quando media_file.attached?), arte_e_grupos_do_mesmo_cliente (SEG-02 backstop), scheduled_for_no_futuro"
  - "Divulgacao::WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes (heuristica conservadora, Assumption A1 — fase 29 UAT mede o teto real)"
  - "scheduled_for blank -> errors[:base] 'Informe a data e hora do envio.' (mensagem verbatim do 28-UI-SPEC, roteada pro :base para a unica caixa vermelha do form)"
  - "datetime-local 'YYYY-MM-DDTHH:MM' -> Time.zone (Brasilia, -03:00) round-trip sem codigo de parsing; Arte#scheduled_on permanece Date"
  - "min: Time.current no f.datetime_field como client hint"
  - "cobertura de teste: 20 model + 3 helper + 9 controller novos, todos os 7 textos de validacao do 28-UI-SPEC assertados verbatim"
affects: [29-motor-de-envio, 30-acompanhamento-ao-vivo-hardening]

actuals:
  tokens: 6000
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Validacoes customizadas do Divulgacao no estilo Arte: `validate :metodo` + guard-clause privada com `errors.add(:base, 'frase pt-BR com o que fazer')`"
    - "Teto de midia da Divulgacao como constante colocada com a validacao que a consome; mensagem via ActiveSupport::NumberHelper.number_to_human_size (virgula decimal pt-BR)"
    - "Mensagem de branco roteada para errors[:base] (nao errors[:atributo]) quando a view tem uma unica caixa de erro consolidada"
    - "datetime-local round-trip via atribuicao crua do parametro ao atributo tz-aware (config.time_zone + default_timezone=:local) — nunca Time.parse/DateTime.parse"

key-files:
  created:
    - test/helpers/admin/divulgacoes_helper_test.rb
  modified:
    - app/models/divulgacao.rb
    - app/views/admin/divulgacoes/new.html.erb
    - test/models/divulgacao_test.rb
    - test/models/divulgacao_grupo_test.rb
    - test/controllers/admin/divulgacoes_controller_test.rb

key-decisions:
  - "Mensagem de scheduled_for em branco vai para errors[:base] via `validate :scheduled_for_presente` (removido o `validates :scheduled_for, presence: true` do plano 01). O plano sugeria `message:` no `presence:`, mas isso deixa o erro em errors[:scheduled_for] e a view (28-UI-SPEC + Task 3 'sem novo markup') so renderiza a caixa errors[:base]. Rotear pro :base e a unica forma de a mensagem 'Informe a data e hora do envio.' aparecer com a marcacao existente."
  - "`divulgacao_datetime_label` ja existia (criado como deviation Rule 3 no plano 01, referenciado pela notice de sucesso do #create). Este plano so adicionou o arquivo de teste do helper — a implementacao ja batia com o `<behavior>` verbatim."
  - "A caixa errors[:base] do new.html.erb ja tinha a forma do admin/artes/_form.html.erb (plano 01). Task 3 nao precisou de mudanca estrutural — so cobertura de integracao."
  - "arte_e_grupos_do_mesmo_cliente usa duas mensagens: 'A arte e os grupos precisam ser do mesmo cliente.' (arte.client_id != client_id) e 'Um ou mais grupos selecionados nao pertencem a este cliente.' (grupo construido de outra instancia) — ambas nomeadas no must_haves.truths do plano."

patterns-established:
  - "Validacao customizada Divulgacao: early `return` no caso nil/ok, depois `errors.add(:base, ...)` — espelha app/models/arte.rb"
  - "Teste de arquivo acima do teto sem fixture grande: attach de sample.jpg + `blob.update_column(:byte_size, 20.megabytes)`"
  - "Teste de arte caption_only: `arte.save!(validate: false)` — a validacao media_source_present da Arte exige arquivo/link; caption_only e escopo da Divulgacao, nao da Arte"

requirements-completed: [DIVU-02, DIVU-03, DIVU-04, DIVU-05, SEG-02]

coverage:
  - id: D1
    description: "arte nao aprovada (pending/change_requested/revised) no submit -> save falso, errors[:base] contem 'A arte selecionada nao esta aprovada. So artes aprovadas podem ser agendadas para divulgacao.' (DIVU-02, defense-in-depth atras do picker .approved)"
    requirement: DIVU-02
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arte pending recusa a divulgacao (DIVU-02)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arte change_requested recusa a divulgacao (DIVU-02)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arte revised recusa a divulgacao (DIVU-02)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#arte pending -> re-render :new com 'A arte selecionada nao esta aprovada.' (DIVU-02)"
        status: pass
    human_judgment: false
  - id: D2
    description: "arte com external_url presente -> recusada com 'Esta arte usa um link externo. Faca o upload do arquivo na arte antes de agendar a divulgacao.'; NENHUMA validacao da Arte tocada (git diff --stat app/models/arte.rb vazio) (DIVU-03)"
    requirement: DIVU-03
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arte com external_url recusa a divulgacao (DIVU-03)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#arte com external_url (sem arquivo) -> 'Esta arte usa um link externo.' (DIVU-03)"
        status: pass
    human_judgment: false
  - id: D3
    description: "arte caption_only (sem media_file, sem external_url, com caption) e uma Divulgacao VALIDA — DIVU-03 recusa so link externo, nunca mera ausencia de arquivo (CONTEXT resolvido)"
    requirement: DIVU-03
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arte caption_only (sem arquivo, sem link) e uma Divulgacao valida (DIVU-03, caption_only IN escopo)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#arte caption_only aprovada + grupo valido + futuro -> cria a divulgacao (DIVU-03, caption_only IN escopo)"
        status: pass
    human_judgment: false
  - id: D4
    description: "arte.media_file.blob.byte_size > WHATSAPP_MEDIA_MAX_BYTES (16.megabytes) -> recusada com mensagem que cita o tamanho atual, o teto e 'Comprima ou reenvie um arquivo menor na arte.'; check so roda quando media_file.attached?; validacao 50 MB da Arte intacta (DIVU-04)"
    requirement: DIVU-04
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arquivo de 20 MB recusa a divulgacao com tamanho, teto e o que fazer (DIVU-04)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#sem media_file anexado o teto e ignorado (DIVU-04, caption_only)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#WHATSAPP_MEDIA_MAX_BYTES e 16 megabytes"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#arquivo acima do teto de 16 MB -> mensagem com tamanho atual e limite (DIVU-04)"
        status: pass
    human_judgment: false
  - id: D5
    description: "validate :arte_e_grupos_do_mesmo_cliente e o backstop de model para SEG-02: arte.client_id == client_id E todo divulgacao_grupo.whatsapp_group.whatsapp_instance.client_id == client_id; mismatch adiciona a mensagem pt-BR correspondente (SEG-02, RESEARCH Pitfall 6)"
    requirement: SEG-02
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#arte de outro cliente recusa a divulgacao (SEG-02)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#grupo de outro cliente recusa a divulgacao (SEG-02)"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#SEG-02 backstop no nivel do model: arte do cliente B + divulgacao do cliente A e invalida"
        status: pass
    human_judgment: false
  - id: D6
    description: "scheduled_for no passado -> errors[:base] 'A data e hora do envio precisam estar no futuro.'; scheduled_for em branco -> 'Informe a data e hora do envio.' (nao a mensagem de futuro)"
    requirement: DIVU-05
    verification:
      - kind: unit
        ref: "test/models/divulgacao_test.rb#divulgacao sem scheduled_for reporta 'Informe a data e hora do envio.' em errors[:base]"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#divulgacao com scheduled_for no passado e invalida com mensagem de futuro"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#scheduled_for no passado -> 'A data e hora do envio precisam estar no futuro.'"
        status: pass
    human_judgment: false
  - id: D7
    description: "POST divulgacao com scheduled_for: '2026-09-15T14:00' -> Divulgacao.last.scheduled_for == Time.zone.local(2026,9,15,14,0) com utc_offset -3*3600; string crua atribuida ao atributo, castada por Time.zone (Brasilia); parametro nunca passa por parser de time do stdlib (DIVU-05)"
    requirement: DIVU-05
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#scheduled_for cru 2026-09-15T14:00 round-trips pra Time.zone.local Brasilia (-03:00)"
        status: pass
      - kind: other
        ref: "grep -n 'Time.parse|DateTime.parse|Time.strptime' app/controllers/admin/divulgacoes_controller.rb app/models/divulgacao.rb -> sem matches"
        status: pass
    human_judgment: false
  - id: D8
    description: "Arte#scheduled_on permanece coluna date sem componente de hora — esta fase adiciona divulgacoes.scheduled_for e nao toca em artes (DIVU-05)"
    requirement: DIVU-05
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#criar a divulgacao nao transforma Arte#scheduled_on num datetime — continua Date sem hora"
        status: pass
    human_judgment: false
  - id: D9
    description: "divulgacao_datetime_label(t) -> '{DD/MM/AAAA} {HH:MM} (BRT)' (ex. '15/09/2025 14:00 (BRT)') e '—' para nil/blank; o f.datetime_field carrega min: Time.current como client hint (DIVU-05)"
    requirement: DIVU-05
    verification:
      - kind: unit
        ref: "test/helpers/admin/divulgacoes_helper_test.rb#divulgacao_datetime_label formata DD/MM/AAAA HH:MM (BRT)"
        status: pass
      - kind: unit
        ref: "test/helpers/admin/divulgacoes_helper_test.rb#divulgacao_datetime_label(nil) retorna o travessao"
        status: pass
      - kind: other
        ref: "grep -n 'min:' app/views/admin/divulgacoes/new.html.erb -> linha do datetime_field"
        status: pass
    human_judgment: false
  - id: D10
    description: "lixo impossivel de parsear no scheduled_for casta pra nil e e pego por presence — nunca levanta 500; :new re-renderizado com 'Informe a data e hora do envio.'"
    requirement: DIVU-05
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#scheduled_for com lixo impossivel de parsear casta pra nil e cai no presence — sem 500"
        status: pass
    human_judgment: false
  - id: D11
    description: "todas as 7 mensagens de validacao DIVU/SEG + as 2 de datetime chegam ao admin pela unica caixa errors[:base] (bg-red-50 border border-red-200 text-red-700) no render :new 422, com o input do usuario preservado"
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb (5 POSTs de validacao assertam a mensagem verbatim em response.body)"
        status: pass
      - kind: other
        ref: "grep -n 'errors\\[:base\\]' app/views/admin/divulgacoes/new.html.erb -> caixa itera @divulgacao.errors[:base]"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-30
status: complete
---

# Phase 28 Plan 02: Validações de criação da Divulgação + round-trip de fuso Summary

**As cinco validações de criação do `Divulgacao` (arte aprovada, sem link externo — `caption_only` aceito, arquivo ≤ 16 MB só quando anexado, arte+grupos do mesmo cliente, agendamento no futuro) com a cópia pt-BR verbatim do 28-UI-SPEC, mais o round-trip `datetime-local` → `Time.zone` (Brasília, −03:00) sem código de parsing e o `Arte#scheduled_on` permanecendo `Date`.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-08-30T22:07:00Z
- **Completed:** 2026-08-30T22:27:39Z
- **Tasks:** 3 (2 TDD, 1 auto)
- **Files modified:** 6 (1 criado, 5 modificados)

## Accomplishments

- **Task 1 — as cinco validações + `WHATSAPP_MEDIA_MAX_BYTES`:** `arte_deve_estar_aprovada` (DIVU-02), `arte_nao_usa_link_externo` (DIVU-03 — recusa **só** `external_url`; `caption_only` é uma Divulgação válida), `arquivo_dentro_do_teto_whatsapp` (DIVU-04 — `return` cedo quando `!media_file.attached?`; mensagem com tamanho atual + teto via `number_to_human_size`), `arte_e_grupos_do_mesmo_cliente` (SEG-02 backstop — duas mensagens: arte de outro cliente / grupo de outra instância), `scheduled_for_no_futuro` (futuro-only) + `scheduled_for_presente` (branco → `errors[:base]`). `WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` colocada com a validação que a consome. `app/models/arte.rb` **intocado** (`git diff --stat` vazio). 20 testes de model.
- **Task 2 — helper + round-trip de fuso:** `test/helpers/admin/divulgacoes_helper_test.rb` novo (`"—"` para nil/branco, `"15/09/2025 14:00 (BRT)"` para um `Time.zone.local` fixo — a implementação já existia do plano 01 e já batia com o `<behavior>`). `min: Time.current` adicionado no `f.datetime_field` (client hint). Testes de integração provando que a string crua `"2026-09-15T14:00"` faz round-trip para `Time.zone.local(2026,9,15,14,0)` com offset `-03:00` sem código de parsing; que `Arte#scheduled_on` continua `Date` sem `#hour`; e que lixo (`"not-a-date"`) casta para `nil` e cai no `presence` sem 500.
- **Task 3 — superfície de validação pela caixa `errors[:base]`:** a caixa do `new.html.erb` já tinha a forma do `admin/artes/_form.html.erb` (plano 01) — nenhuma mudança estrutural. 6 testes de integração novos assertando cada mensagem do "Copywriting Contract" verbatim em `response.body` (DIVU-02 pending, DIVU-03 external_url, DIVU-04 blob forçado a 20 MB, datetime no passado), o `caption_only` aprovado criando a Divulgação (`Divulgacao.count` +1), e a asserção de model-level do backstop SEG-02.

## Task Commits

1. **Task 1: cinco validações + WHATSAPP_MEDIA_MAX_BYTES** — `a0b85f9` (feat)
2. **Task 2: helper coverage + round-trip datetime-local → Time.zone** — `197df5a` (feat)
3. **Task 3: superfície de validação pela caixa errors[:base]** — `671c616` (test)
4. **Fix de regressão: setup do DivulgacaoGrupoTest** — `29fd870` (test)

_Task 1 e Task 2 são `tdd="true"`; testes e implementação foram escritos juntos e o `<verify>` rodou verde antes do commit (RED/GREEN combinados num commit `feat` por tarefa, dado o run não-assistido)._

## Files Created/Modified

- `app/models/divulgacao.rb` — `WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes`; removido `validates :scheduled_for, presence: true`; adicionadas 7 declarações `validate :método` + os corpos privados guard-clause (`scheduled_for_presente`, `scheduled_for_no_futuro`, `arte_deve_estar_aprovada`, `arte_nao_usa_link_externo`, `arquivo_dentro_do_teto_whatsapp`, `arte_e_grupos_do_mesmo_cliente`; `ao_menos_um_grupo` mantido do plano 01).
- `app/views/admin/divulgacoes/new.html.erb` — `min: Time.current` no `f.datetime_field :scheduled_for` (1 linha; help text "(BRT)" já estava do plano 01).
- `test/helpers/admin/divulgacoes_helper_test.rb` — **criado**: `ActionView::TestCase`, 3 casos do `divulgacao_datetime_label`.
- `test/models/divulgacao_test.rb` — reescrito: helpers de construção (`arte_com_arquivo`, `arte_caption_only`, `divulgacao_para`) + 20 testes cobrindo cada caso do `<behavior>` do Task 1 (DIVU-02/03/04, SEG-02, presença/futuro, `caption_only` aceito, teto pulado sem arquivo).
- `test/models/divulgacao_grupo_test.rb` — setup trocado de arte com `external_url` para arte com `media_file` anexado (ver Deviations).
- `test/controllers/admin/divulgacoes_controller_test.rb` — +9 testes: 3 de round-trip/fuso (Task 2) + 6 de superfície de validação e model-backstop SEG-02 (Task 3).

## Decisions Made

Ver `key-decisions` no frontmatter. Destaques:

- **Mensagem de `scheduled_for` em branco → `errors[:base]`** (não `errors[:scheduled_for]`). O plano sugeria `presence: { message: ... }`, mas a view tem uma única caixa de erro consolidada (`@divulgacao.errors[:base]`) e o `must_haves.truths` + a instrução do Task 3 ("sem novo markup") exigem que as 9 mensagens fluam por ela. Removi o `validates :scheduled_for, presence: true` do plano 01 e adicionei `validate :scheduled_for_presente`. Ver Deviations.
- **`divulgacao_datetime_label` já existia** (deviation Rule 3 do plano 01). Este plano só adicionou o teste; a implementação já era verbatim do `<behavior>`.
- **`new.html.erb` já tinha a caixa `errors[:base]` e o help text "(BRT)"** do plano 01. Task 3 foi puramente cobertura de integração.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Mensagem de `scheduled_for` em branco roteada para `errors[:base]` em vez de `errors[:scheduled_for]`**
- **Found during:** Task 1
- **Issue:** O `<action>` do Task 1 sugere `message:` no `validates :scheduled_for, presence:` ou uma chave de locale `:blank`. Ambas deixam o erro em `errors[:scheduled_for]`. A view (`new.html.erb`, plano 01) e o `must_haves.truths` ("todas as sete mensagens DIVU/SEG mais as duas de datetime renderizam na caixa `errors[:base]`") + a instrução do Task 3 ("sem markup novo") só renderizam `@divulgacao.errors[:base]`. Com o `message:` a mensagem "Informe a data e hora do envio." nunca apareceria em `response.body` — quebrando o `<behavior>` do Task 2 (`assert_includes response.body, "Informe a data e hora do envio."`).
- **Fix:** Removido `validates :scheduled_for, presence: true`; adicionado `validate :scheduled_for_presente` → `errors.add(:base, "Informe a data e hora do envio.") if scheduled_for.blank?`.
- **Files modified:** `app/models/divulgacao.rb`, `test/models/divulgacao_test.rb` (o teste do plano 01 "divulgacao sem scheduled_for e invalida em :scheduled_for" que assertava `errors[:scheduled_for]` "não pode ficar em branco" foi substituído pela versão que asserta `errors[:base]` "Informe a data e hora do envio.").
- **Verification:** `test/models/divulgacao_test.rb` + `test/controllers/admin/divulgacoes_controller_test.rb` verdes (38 runs).
- **Committed in:** `a0b85f9` (Task 1) / `671c616` (Task 3, testes de integração).

**2. [Rule 1 - Bug / scope boundary] `DivulgacaoGrupoTest#setup` regredido pela nova validação DIVU-03**
- **Found during:** Task 1 (rodada da suíte de models após implementar as validações)
- **Issue:** `test/models/divulgacao_grupo_test.rb` (plano 01) constrói o `@divulgacao` do setup a partir de uma arte com `external_url`. A nova `arte_nao_usa_link_externo` faz `@client.divulgacoes.create!` levantar `RecordInvalid` — quebrando os 4 testes do arquivo (regressão direta desta tarefa).
- **Fix:** Setup trocado para uma arte aprovada com `media_file` anexado (`sample.jpg`), como já feito no `divulgacao_test.rb`.
- **Files modified:** `test/models/divulgacao_grupo_test.rb`
- **Verification:** `bin/rails test test/models/divulgacao_grupo_test.rb` → `4 runs, 0 failures, 0 errors`.
- **Committed in:** `29fd870`.

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bug/scope-boundary). **Impact:** Ambos necessários para o plano compilar/rodar dentro do contrato do 28-UI-SPEC e da suíte existente. Sem scope creep — a mudança de rota da mensagem é a única forma de a única caixa de erro do form surfacear o branco; o fix do `divulgacao_grupo_test` é a atualização mínima do setup regredido pela nova validação.

## Issues Encountered

- **Falhas pré-existentes não relacionadas em `test/models/`.** `bin/rails test test/models/` → `70 runs, 3 failures, 8 errors`. Todos ambientais e já documentados no plano 01 SUMMARY: `Missing Active Record encryption credential: active_record_encryption.primary_key` (`WhatsappGroupTest`, `WhatsappInstanceTest` — fases 25/26 `verification_deferred_human`) e testes de broadcast flaky (`ArteTest#test_revised!_broadcast_admin...`, `ApprovalResponseTest#test_broadcasts_to_admin...`). **Nenhuma falha nova introduzida por este plano** — os 3 arquivos-alvo (`divulgacao_test.rb`, `divulgacoes_helper_test.rb`, `divulgacoes_controller_test.rb`) + `divulgacao_grupo_test.rb` estão 100% verdes (42 runs, 0 failures, 0 errors).
- **Invocação dos testes:** o repo exige `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test <arquivos>` (workaround de socket unix — `.env` bloqueado para agentes no sandbox). `bin/rails test` puro não conecta. O worktree também precisou de um `.bundle/config` gitignored apontando para `/home/bot/calendario_livia/vendor/bundle` (mesmo passo do plano 01).
- **Arte `caption_only` no teste:** a validação `media_source_present` da `Arte` exige `media_file` OU `external_url`, então uma arte `caption_only` pura (sem nenhum dos dois) não passa na validação da `Arte`. Os testes a constroem com `save!(validate: false)` — `caption_only` é escopo da Divulgação (fase 29 ENVIO-10), não da Arte, e o plano proíbe tocar `app/models/arte.rb`.

## Verification

- `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/models/divulgacao_test.rb test/helpers/admin/divulgacoes_helper_test.rb test/controllers/admin/divulgacoes_controller_test.rb` → **38 runs, 145 assertions, 0 failures, 0 errors**.
- `test/models/divulgacao_grupo_test.rb` → **4 runs, 0 failures, 0 errors** (setup fixado).
- `git diff --stat app/models/arte.rb` → **vazio** (Arte intocada — DIVU-03/DIVU-04 explícitas).
- `grep -rn "Time.parse\|DateTime.parse\|Time.strptime" app/controllers/admin/divulgacoes_controller.rb app/models/divulgacao.rb` → **sem matches**.
- `grep -n "WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes" app/models/divulgacao.rb` → match; `grep -n "number_to_human_size" app/models/divulgacao.rb` → match; `grep -n "media_file.attached?" app/models/divulgacao.rb` → match (check guardado no attachment).
- `grep -n "min:" app/views/admin/divulgacoes/new.html.erb` → linha do `datetime_field`; `grep -n "Interpretada no fuso de Brasília (BRT)." app/views/admin/divulgacoes/new.html.erb` → match.

## Threat Model Compliance

- **T-28-06 (EoP cross-client, high):** `mitigate` — `validate :arte_e_grupos_do_mesmo_cliente` implementado; asserção de model-level em `test/controllers/admin/divulgacoes_controller_test.rb#SEG-02 backstop no nivel do model` + os A×B end-to-end do plano 01.
- **T-28-07 (link externo / arquivo acima do teto, medium):** `mitigate` — `arte_nao_usa_link_externo` + `arquivo_dentro_do_teto_whatsapp` (guardado em `media_file.attached?`); `Arte` intocada.
- **T-28-08 (agendamento no passado, low):** `mitigate` — `scheduled_for_no_futuro` (`<= Time.current`) + `scheduled_for_presente`.
- **T-28-09 (DoS por `scheduled_for` não-parseável, low):** `mitigate` — cast do tipo `:datetime` via `Time.zone` dá `nil` para lixo → pego pelo `presence`; parâmetro nunca passa por parser do stdlib (grep-verificado). Teste `#scheduled_for com lixo impossivel de parsear`.
- **T-28-10 (info disclosure em mensagens de validação, low):** `accept` — as mensagens citam só o status da própria arte / tamanho do arquivo / mismatch arte-vs-grupos; sem identificadores cross-client, sem ids de registro.

## Threat Flags

Nenhuma superfície de segurança nova além da mapeada no `<threat_model>` do plano. Sem novos endpoints, paths de auth, padrões de acesso a arquivo ou mudanças de schema (esta fase adiciona só validações no model + 1 atributo `min:` na view).

## Next Phase Readiness

- **Pronto para o plano 28-03 (preview + estimativa de duração):** todas as validações de criação estão no lugar; `divulgacao_datetime_label` estável; a caixa `errors[:base]` do form é a superfície única de erro. O plano 03 adiciona `_preview.html.erb` e `divulgacao_duration_estimate`.
- **Contrato para a fase 29 confirmado:** `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` (heurística — a UAT da fase 29 mede o teto real do gateway Evolution com o probe 5/15/20/30 MB e este é um update de uma linha se estiver errado — Assumption A1).
- **Blockers:** nenhum. Falhas pré-existentes de `test/models/` são ambientais (encryption credential / broadcast flaky), fora do escopo desta fase.

## Self-Check: PASSED

- Arquivos: `app/models/divulgacao.rb`, `app/views/admin/divulgacoes/new.html.erb`, `test/helpers/admin/divulgacoes_helper_test.rb`, `test/models/divulgacao_test.rb`, `test/models/divulgacao_grupo_test.rb`, `test/controllers/admin/divulgacoes_controller_test.rb` — todos presentes em disco.
- Commits presentes no git log: `a0b85f9` (Task 1), `197df5a` (Task 2), `671c616` (Task 3), `29fd870` (fix de regressão).
- `bin/rails test` dos 3 arquivos-alvo: `38 runs, 145 assertions, 0 failures, 0 errors`.
- `git diff --stat app/models/arte.rb` vazio.
- `grep` de `Time.parse`/`DateTime.parse` no controller + model: sem matches.

---
*Phase: 28-divulga-o-agendar-sem-enviar*
*Completed: 2026-08-30*
