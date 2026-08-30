---
phase: 28-divulga-o-agendar-sem-enviar
plan: 01
subsystem: database
tags: [rails, activerecord, enum, nested-resource, cross-client-isolation, activestorage, divulgacao]

requires:
  - phase: 27-grupos-do-cliente-sync-cache-e-sele-o-escopada
    provides: "whatsapp_groups cache, WhatsappGroup#display_name, _picker.html.erb scoped partial"
provides:
  - "divulgacoes + divulgacao_grupos schema (two-table, one row per group, frozen group_name/remote_jid snapshot + nullable phase-29 staging columns)"
  - "Divulgacao / DivulgacaoGrupo models with integer-backed status enums (agendada/em_andamento/concluida/cancelada prefix: :status; pendente/enviado/falhou/incerto)"
  - "Admin::DivulgacoesController#index/#new/#create — create happy path end-to-end"
  - "nested route surface resources :divulgacoes only [index,new,create,show] + member patch :cancel"
  - "cross-client isolation boundary (arte + every group id re-resolved through @client scope) proven by A×B test both directions"
  - "Admin::DivulgacoesHelper#divulgacao_datetime_label"
affects: [29-motor-de-envio, 30-acompanhamento-ao-vivo-hardening]

actuals:
  tokens: 6000
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Two-table Divulgacao schema with frozen per-group snapshot columns (DIVU-09)"
    - "Cross-client id re-resolution: @client.artes.find + scoped_active_groups.find(ids) → RecordNotFound → generic re-render (SEG-01/SEG-02)"
    - "Irregular pt-BR inflection (divulgacao/divulgacoes) + belt-and-suspenders self.table_name"
    - "form_with model: [:admin, @client, @divulgacao] for namespaced nested-resource route helper resolution"

key-files:
  created:
    - db/migrate/20260830190001_create_divulgacoes.rb
    - db/migrate/20260830190002_create_divulgacao_grupos.rb
    - app/models/divulgacao.rb
    - app/models/divulgacao_grupo.rb
    - app/controllers/admin/divulgacoes_controller.rb
    - app/helpers/admin/divulgacoes_helper.rb
    - app/views/admin/divulgacoes/new.html.erb
    - app/views/admin/divulgacoes/index.html.erb
    - test/controllers/admin/divulgacoes_controller_test.rb
    - test/models/divulgacao_test.rb
    - test/models/divulgacao_grupo_test.rb
  modified:
    - config/initializers/inflections.rb
    - config/routes.rb
    - app/models/client.rb
    - app/models/arte.rb
    - app/models/whatsapp_group.rb
    - db/schema.rb

key-decisions:
  - "Task 1 (checkpoint:decision) resolved to Option A — the CONTEXT-locked contract: two-table shape, both integer-backed status enum value sets verbatim, frozen group_name/remote_jid snapshot columns PLUS the nullable phase-29 staging columns sent_at/error_code/evolution_message_id added now (no logic), and member { patch :cancel }. User already accepted this exact schema/enum/route shape in smart-discuss Grey Area 1; unattended run takes A."
  - "Divulgacao.status uses prefix: :status (status_agendada?, status_cancelada!); DivulgacaoGrupo.status unprefixed with DIVU-09 vocabulary verbatim (pendente/enviado/falhou/incerto)."
  - "Arte/WhatsappGroup has_many :divulgacoes / :divulgacao_grupos carry NO dependent: — deleting an arte or group never cascade-erases send history (Pitfall 7). Client has_many :divulgacoes, dependent: :destroy is fine."
  - "divulgacao_grupos rows built as association records inside the single divulgacao.save transaction (not insert_all) — atomic rollback, validations run, no Rails-8.1 timestamp gotcha."
  - "#show / #cancel action bodies deferred to plan 04 — route contract exists now because phase 29 depends on it; #create redirects to the (not-yet-implemented) show path and index.html.erb 'Ver' links there."

patterns-established:
  - "Cross-client isolation: never Arte.find / WhatsappGroup.find bare in the controller — always @client.artes.find and @client.whatsapp_instance&.whatsapp_groups&.where(active: true).find(ids); any foreign/inactive id → RecordNotFound → generic pt-BR flash + re-render :new 422, zero rows written."
  - "DIVU-09 frozen snapshot: group_name = whatsapp_group.display_name and remote_jid copied server-side at build time; renaming or deactivating the group afterward never changes the stored snapshot."

requirements-completed: [DIVU-01, DIVU-09, SEG-01, SEG-02]

coverage:
  - id: D1
    description: "GET .../divulgacoes/new renders a single-page schedule form (approved-arte select, reused scoped _picker with live checkboxes, datetime-local, one submit) and POST persists one divulgacoes row + one divulgacao_grupos row per selected group in a single save transaction, then redirects to the show path (DIVU-01)"
    requirement: DIVU-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#POST create agenda uma divulgacao com uma linha pendente por grupo e redireciona pro show"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every divulgacao_grupos row is born pendente and carries group_name = the group's display_name and remote_jid frozen at build time — renaming or deactivating the group afterward never changes the stored snapshot (DIVU-09)"
    requirement: DIVU-09
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#renomear e desativar o grupo apos criar nao altera o snapshot group_name/remote_jid"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_grupo_test.rb#status default e pendente"
        status: pass
    human_judgment: false
  - id: D3
    description: "#create re-resolves arte_id through @client.artes.find and every group id through @client.whatsapp_instance.whatsapp_groups.where(active: true).find(ids); a foreign or inactive id raises RecordNotFound, rescued to a generic pt-BR flash + re-render :new 422, creating no rows; the response body leaks none of the other client's arte title / group subject / remote_jid (SEG-01, SEG-02)"
    requirement: SEG-01
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#arte de OUTRO cliente pela URL de divulgacoes do cliente A"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#id de grupo de OUTRO cliente no array pela URL de A"
        status: pass
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#id de grupo INATIVO do proprio cliente A"
        status: pass
    human_judgment: false
  - id: D4
    description: "Zero groups checked → key absent → Array(params.dig(...)) yields [] and validate :ao_menos_um_grupo adds the pt-BR message, never a 500"
    requirement: SEG-02
    verification:
      - kind: integration
        ref: "test/controllers/admin/divulgacoes_controller_test.rb#nenhum grupo marcado (chave ausente)"
        status: pass
      - kind: unit
        ref: "test/models/divulgacao_test.rb#divulgacao com scheduled_for mas sem grupos e invalida com errors[:base]"
        status: pass
    human_judgment: false
  - id: D5
    description: "Full nested route surface defined once: resources :divulgacoes only [index,new,create,show] with member { patch :cancel }; Divulgacao pluralizes to divulgacoes (irregular inflection) so table name, route helpers, dom_id and form_with all resolve"
    verification:
      - kind: other
        ref: "bin/rails routes -g divulgacoes lists new/create/index/show/cancel"
        status: pass
      - kind: other
        ref: "bin/rails runner 'p Divulgacao.table_name' => \"divulgacoes\""
        status: pass
    human_judgment: false
  - id: D6
    description: "This plan writes zero send code — no job enqueue, no outbound HTTP, no WhatsApp transport reference in app/models/divulgacao*.rb or the controller"
    verification:
      - kind: other
        ref: "grep -rn 'Evolution|sendText|sendMedia|perform_later|perform_now|Divulgacao.*Job' app/models/divulgacao*.rb app/controllers/admin/divulgacoes_controller.rb → no matches"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-08-30
status: complete
---

# Phase 28 Plan 01: Tracer + hardening cross-client da Divulgação Summary

**Schema de duas tabelas (`divulgacoes` + `divulgacao_grupos` com snapshot congelado `group_name`/`remote_jid`), models com enums integer-backed, rota aninhada completa (incl. `patch :cancel`) e o caminho feliz de criação ponta a ponta — com a prova canônica A×B de isolamento cross-client nas duas direções.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-08-30T22:06:41Z
- **Completed:** 2026-08-30T22:16:00Z
- **Tasks:** 3 (1 checkpoint:decision auto-resolvido, 1 tracer, 1 auto)
- **Files modified:** 17 (11 criados, 6 modificados)

## Accomplishments

- **Task 1 (checkpoint:decision) — resolvido para Opção A** sem parar (run não-assistido): contrato travado do CONTEXT — duas tabelas, dois conjuntos de valores de enum `status` integer-backed verbatim, colunas de snapshot congelado `group_name`/`remote_jid` MAIS as colunas nulas de staging da fase 29 (`sent_at`, `error_code`, `evolution_message_id`) adicionadas agora sem lógica, e `member { patch :cancel }`.
- **Task 2 (tracer) — fatia vertical do caminho feliz**: 2 migrations (rodadas contra o dev DB, `db/schema.rb` commitado), inflexão irregular `divulgacao`/`divulgacoes`, models `Divulgacao`/`DivulgacaoGrupo`, associações em `Client`/`Arte`/`WhatsappGroup`, rota aninhada, `Admin::DivulgacoesController#index/#new/#create`, `new.html.erb` (form) + `index.html.erb` (mínimo), helper `divulgacao_datetime_label`, e o teste de controller do caminho feliz (1 `divulgacoes` + 2 `divulgacao_grupos` `pendente`, redirect ao show). **Tracer feedback gate re-executado end-to-end após o commit: verde.**
- **Task 3 (auto) — hardening do isolamento cross-client + prova DIVU-09**: `rescue ActiveRecord::RecordNotFound` no `#create` (id forasteiro/inativo → re-render `:new` 422 com `flash.now[:alert]` genérico, zero linhas), caixa do alert no `new.html.erb`, e os testes A×B nas duas direções + grupo inativo + zero grupos + snapshot DIVU-09 (renomear/desativar o grupo após criar não altera `group_name`/`remote_jid`). Model tests para defaults de enum, `validate :ao_menos_um_grupo`, presence de `scheduled_for`, uniqueness scope e presence de `group_name`/`remote_jid`.

## Task Commits

1. **Task 2: tracer end-to-end** — `58768b3` (feat)
2. **Task 3: hardening cross-client + DIVU-09** — `a9f2e68` (feat)

_Task 1 é um checkpoint:decision — sem commit de código; a decisão está registrada em `key-decisions` acima._

## Files Created/Modified

- `db/migrate/20260830190001_create_divulgacoes.rb` — `client_id`/`arte_id` (FK, null: false), `scheduled_for:datetime null: false`, `status:integer default 0`, índice `[client_id, scheduled_for]`.
- `db/migrate/20260830190002_create_divulgacao_grupos.rb` — `divulgacao_id`/`whatsapp_group_id` (FK, null: false), `status:integer default 0`, `group_name`/`remote_jid` (string, null: false, snapshot), colunas nulas fase-29 `sent_at`/`error_code`/`evolution_message_id`, índice único `[divulgacao_id, whatsapp_group_id]`.
- `db/schema.rb` — as duas tabelas + índices + 4 FKs (`divulgacoes→clients`, `divulgacoes→artes`, `divulgacao_grupos→divulgacoes`, `divulgacao_grupos→whatsapp_groups`).
- `config/initializers/inflections.rb` — bloco `:en` ativo com `inflect.irregular "divulgacao", "divulgacoes"` + `"divulgacao_grupo", "divulgacao_grupos"` (antes era só comentários).
- `app/models/divulgacao.rb` — `self.table_name = "divulgacoes"` (belt-and-suspenders), `belongs_to :client/:arte`, `has_many :divulgacao_grupos, dependent: :destroy`, `enum :status, {...}, prefix: :status`, `validates :scheduled_for, presence: true`, `validate :ao_menos_um_grupo`.
- `app/models/divulgacao_grupo.rb` — `belongs_to :divulgacao/:whatsapp_group`, `enum :status, { pendente:0, enviado:1, falhou:2, incerto:3 }` (verbatim DIVU-09), `uniqueness: { scope: :divulgacao_id }`, presence de `group_name`/`remote_jid`.
- `app/models/client.rb` — `+ has_many :divulgacoes, dependent: :destroy`.
- `app/models/arte.rb` — `+ has_many :divulgacoes` (SEM `dependent:` — Pitfall 7).
- `app/models/whatsapp_group.rb` — `+ has_many :divulgacao_grupos` (SEM `dependent:` — Pitfall 7).
- `config/routes.rb` — `resources :divulgacoes, only: [:index, :new, :create, :show] do member { patch :cancel } end` aninhado sob `resources :clients`.
- `app/controllers/admin/divulgacoes_controller.rb` — `#index`/`#new`/`#create`; `set_client` bare `.find`; `scoped_active_groups` (`|| WhatsappGroup.none`); `#create` re-resolve `arte` + `groups`, `build` das associações numa transação, snapshot no build, `rescue RecordNotFound` → re-render genérico.
- `app/helpers/admin/divulgacoes_helper.rb` — `divulgacao_datetime_label(t)` → `"DD/MM/AAAA HH:MM (BRT)"`.
- `app/views/admin/divulgacoes/new.html.erb` — `content_for(:page_title)`, back-link truncado, card `p-8 max-w-2xl`, `form_with model: [:admin, @client, @divulgacao]`, caixa `errors[:base]` + caixa `flash.now[:alert]`, `collection_select :arte_id`, `_picker` embutido (`field_name: "divulgacao[whatsapp_group_ids][]"`, sem `groups:`/`pagy:`), `datetime_field :scheduled_for`, submit "Agendar divulgação".
- `app/views/admin/divulgacoes/index.html.erb` — mínimo: h1, back-link, botão "Nova divulgação", lista simples ou "Nenhuma divulgação agendada." (tabela/empty-state completos são plano 04).
- `test/controllers/admin/divulgacoes_controller_test.rb` — caminho feliz + A×B (duas direções) + grupo inativo + zero grupos + snapshot DIVU-09.
- `test/models/divulgacao_test.rb` / `test/models/divulgacao_grupo_test.rb` — defaults de enum e validações.

## Decisions Made

Ver `key-decisions` no frontmatter. Destaques:

- **Task 1 → Opção A** (contrato travado do CONTEXT), registrada sem parar conforme instrução de auto-mode.
- **`form_with model: [:admin, @client, @divulgacao]`** em vez de `[@client, @divulgacao]` — ver Deviations (Rule 1).
- **Helper `divulgacao_datetime_label` criado neste plano** (o plano listava-o como artefato do plano 02, mas a `notice` de sucesso do `#create` no Task 2 o referencia por nome) — ver Deviations (Rule 3).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `form_with model: [@client, @divulgacao]` não resolve o helper de rota namespaced**
- **Found during:** Task 3 (ao exercitar o re-render de `:new` pelo caminho `RecordNotFound`)
- **Issue:** O plano (`must_haves.truths` e o skeleton do RESEARCH) especifica `form_with model: [@client, @divulgacao]`. Como `Client`/`Divulgacao` não são models namespaced, o `form_with` gera `client_divulgacoes_path` (inexistente) em vez de `admin_client_divulgacoes_path` — `ActionView::Template::Error: undefined method 'client_divulgacoes_path'`. O caminho feliz do Task 2 não pegou isso porque só renderiza o form no `GET new` (nunca exercitado) — o POST bem-sucedido redireciona.
- **Fix:** `form_with model: [:admin, @client, @divulgacao]` — o prefixo `:admin` resolve `admin_client_divulgacoes_path` e mantém o object name `divulgacao` (portanto `name="divulgacao[...]"`, casando com o `field_name` do picker e o `params.dig(:divulgacao, ...)` do controller).
- **Files modified:** `app/views/admin/divulgacoes/new.html.erb`
- **Verification:** os 4 testes de re-render (`arte de B`, `grupo de B`, `grupo inativo`, `zero grupos`) passam com `assert_response :unprocessable_entity`.
- **Committed in:** `a9f2e68` (Task 3)

**2. [Rule 3 - Blocking] Helper `divulgacao_datetime_label` ausente mas referenciado pela `notice` de sucesso**
- **Found during:** Task 2
- **Issue:** A `<action>` do Task 2 define a `notice` de sucesso como `"Divulgação agendada para #{divulgacao_datetime_label(@divulgacao.scheduled_for)}."` (verbatim do 28-UI-SPEC Copywriting Contract), mas `app/helpers/admin/divulgacoes_helper.rb` está listado como artefato do plano 02 e não estava nos `<files>` do Task 2. Sem ele, o `#create` levanta `NoMethodError`.
- **Fix:** Criado `app/helpers/admin/divulgacoes_helper.rb` com **apenas** `divulgacao_datetime_label(t)` → `"DD/MM/AAAA HH:MM (BRT)"` (28-UI-SPEC §79). O helper de estimativa de duração (`divulgacao_duration_estimate`) continua sendo do plano 03. Chamado no controller via `helpers.divulgacao_datetime_label(...)`.
- **Files modified:** `app/helpers/admin/divulgacoes_helper.rb` (criado), `app/controllers/admin/divulgacoes_controller.rb`
- **Verification:** teste do caminho feliz passa; `bin/rails runner` confirma o formato.
- **Committed in:** `58768b3` (Task 2)

**3. [Rule 3 - Blocking] `BUNDLE_PATH` não resolve dentro do worktree**
- **Found during:** setup (antes do Task 2)
- **Issue:** O worktree não herda `.bundle/config` do checkout principal (é gitignored), então `bin/rails` falha com `Bundler::GemNotFound` — as gems estão em `/home/bot/calendario_livia/vendor/bundle` via `BUNDLE_PATH: "vendor/bundle"` relativo.
- **Fix:** Criado `.bundle/config` no worktree apontando para o caminho absoluto `/home/bot/calendario_livia/vendor/bundle`. Arquivo gitignored — não commitado, não afeta o merge de volta.
- **Files modified:** `.bundle/config` (não versionado)
- **Verification:** `bin/rails runner`, `bin/rails db:migrate`, `bin/rails test` todos rodam.
- **Committed in:** n/a (arquivo gitignored)

**4. [Rule 4 boundary — NÃO aplicado] `#show`/`#cancel` sem corpo**
- O plano explicitamente adia os corpos de `#show`/`#cancel` para os planos 02–04, mantendo só o contrato de rota agora (fase 29 depende dele). Consequência conhecida: o redirect de sucesso do `#create` e o link "Ver" do `index.html.erb` apontam para `admin/divulgacoes#show`, que hoje levanta `AbstractController::ActionNotFound` se seguido. Os testes só asseguram o *location* do redirect, não o seguem. Registrado em `## Known Stubs` e no ledger `.planning/WINDOWS.md` (kind `todo`, fase 28).

---

**Total deviations:** 3 auto-fixed (1 bug Rule 1, 2 blocking Rule 3). **Impact:** Todos necessários para o plano compilar/rodar. Nenhum scope creep — o helper criado tem só o método que o Task 2 referencia; a mudança do `form_with` é a única forma de o helper de rota namespaced resolver.

## Issues Encountered

- **Suite de testes com falhas pré-existentes não relacionadas.** Baseline no commit base `bdc753b`: `336 runs, 10 failures, 42 errors`. Após este plano: `350 runs, 10 failures, 42 errors` (os 14 testes novos de Divulgação passam; contagem de falhas/erros idêntica). As falhas/erros pré-existentes têm causa de ambiente: `EVOLUTION_WEBHOOK_HMAC_KEY não configurado`, `Missing Active Record encryption credential: active_record_encryption.primary_key` (fases 25/26 `verification_deferred_human`), e os testes de broadcast flaky em `arte_test.rb`/`approval_response_test.rb`/`dashboard_controller_test.rb` já documentados nos summaries da fase 27. **Zero novas falhas introduzidas por este plano.**
- **Invocação dos testes:** o repo exige `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test` (workaround de socket unix — `.env` bloqueado para agentes no sandbox). `bin/rails test` puro não conecta.

## Known Stubs

| Arquivo | Linha | Motivo |
|---------|-------|--------|
| `app/controllers/admin/divulgacoes_controller.rb` | rota `show`/`cancel` sem action | Corpos de `#show`/`#cancel` adiados para o plano 04 (contrato de rota existe agora porque a fase 29 depende dele). `#create` redireciona para o show path e `index.html.erb` linka "Ver" para lá — hoje 500 se seguido. Não bloqueia o objetivo deste plano (caminho feliz de criação + prova cross-client). Registrado em `.planning/WINDOWS.md`. |

## Threat Flags

Nenhuma superfície de segurança nova além da já mapeada no `<threat_model>` do plano. Todos os threats de severidade `high` (T-28-01 EoP/InfoDisclosure na resolução de `arte_id`/`whatsapp_group_ids`, T-28-02 tampering de JID cru) estão `mitigate` com controle concreto + teste: re-resolução escopada + índice único + `Array(...).map(&:to_i).uniq.reject(&:zero?)`, e o A×B negativo nas duas direções assegura que o body da resposta não carrega nada do cliente B.

## Next Phase Readiness

- **Pronto para o plano 28-02:** schema, models, rota, controller `#create` e o caminho feliz estão no lugar. O plano 02 adiciona as validações restantes (`arte_deve_estar_aprovada`, `arte_nao_usa_link_externo` — só `external_url`, `caption_only` EM escopo —, `arquivo_dentro_do_teto_whatsapp`, `arte_e_grupos_do_mesmo_cliente`, `scheduled_for_no_futuro`) e o helper de estimativa.
- **Blockers:** nenhum. O `#show`/`#cancel` adiado é esperado (contrato de rota presente; corpos no plano 04).
- **Contrato para a fase 29 confirmado (one-way door, Task 1 = Opção A):** nomes de coluna de `divulgacoes`/`divulgacao_grupos`, os dois conjuntos de enum `status` integer-backed, e a rota `patch :cancel`.

## Self-Check: PASSED

- Todos os 11 arquivos de código + o SUMMARY existem em disco (`ls` confirmado).
- Ambos os commits de tarefa presentes no git log: `58768b3` (Task 2), `a9f2e68` (Task 3).
- `bin/rails test` dos 3 arquivos alvo: `14 runs, 61 assertions, 0 failures, 0 errors`.
- `bin/rails routes -g divulgacoes` lista `new`/`create`/`index`/`show`/`cancel`.
- grep de send-path em `app/models/divulgacao*.rb` + controller: sem matches.

---
*Phase: 28-divulga-o-agendar-sem-enviar*
*Completed: 2026-08-30*
