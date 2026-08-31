---
phase: 28-divulga-o-agendar-sem-enviar
verified: 2026-08-30T23:45:00Z
status: passed
score: 15/15 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 28: Divulgação — Agendar sem Enviar Verification Report

**Phase Goal:** O admin monta e agenda uma Divulgação completa — cliente, arte aprovada, grupos
e data/hora — com todas as validações e o preview, parando deliberadamente antes de qualquer envio.
**Verified:** 2026-08-30T23:45:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `new` renders single-page form (arte select, live picker, datetime, one submit) (DIVU-01) | ✓ VERIFIED | `app/views/admin/divulgacoes/new.html.erb` — `f.collection_select :arte_id` from `@approved_artes`, `_picker` with `field_name: "divulgacao[whatsapp_group_ids][]"`, `f.datetime_field :scheduled_for`, single `f.submit "Agendar divulgação"` |
| 2 | Valid POST persists 1 `divulgacoes` row + 1 `divulgacao_grupos` row per group in a single transaction, redirects to show (DIVU-01) | ✓ VERIFIED | `Admin::DivulgacoesController#create` builds `divulgacao_grupos` on `@divulgacao` before `.save` (single AR transaction); controller test suite (82/82 green) exercises the happy path and asserts `Divulgacao.count`/`DivulgacaoGrupo.count` deltas |
| 3 | Every `divulgacao_grupos` row born `pendente`, `group_name`/`remote_jid` frozen at build time (DIVU-09) | ✓ VERIFIED | `DivulgacaoGrupo` enum defaults `pendente: 0`; controller sets `group_name: g.display_name, remote_jid: g.remote_jid` at build; test `"renomear e desativar o grupo apos criar nao altera o snapshot..."` (`divulgacoes_controller_test.rb:238`) proves post-hoc rename/deactivate does not mutate the snapshot — passing |
| 4 | `#create` re-resolves `arte_id` and every group id through `@client` scope; foreign/inactive id → `RecordNotFound` → generic pt-BR re-render, zero rows (SEG-01, SEG-02) | ✓ VERIFIED | `@client.artes.find(...)`, `scoped_active_groups.find(gids)` in controller; `rescue ActiveRecord::RecordNotFound` renders `:new` 422 with generic flash; cross-client A×B tests (`"arte de OUTRO cliente..."`, `"id de grupo de OUTRO cliente..."`) assert `assert_no_difference` + no leaked data in body — passing |
| 5 | Form transmits only integer group ids; `remote_jid` never accepted raw (SEG-01) | ✓ VERIFIED | `_group_row.html.erb` emits `check_box_tag field_name, group.id, ...` (id only); `remote_jid` only ever set server-side from the resolved `WhatsappGroup` |
| 6 | Zero groups checked → no hidden companion field, `ao_menos_um_grupo` validation fires, never 500 | ✓ VERIFIED | `check_box_tag` used (no hidden twin); `Array(params.dig(...))` pattern via strong params `.permit(whatsapp_group_ids: [])`; model `validate :ao_menos_um_grupo` adds `"Selecione ao menos um grupo para a divulgação."` |
| 7 | `config/routes.rb` exposes full nested route surface once, incl. `member { patch :cancel }` | ✓ VERIFIED | `config/routes.rb:25-27`: `resources :divulgacoes, only: [:index, :new, :create, :show] do member { patch :cancel } end` |
| 8 | `Divulgacao` pluralizes to `divulgacoes` (irregular inflection) | ✓ VERIFIED | `config/initializers/inflections.rb` — `inflect.irregular "divulgacao", "divulgacoes"` + `inflect.irregular "divulgacao_grupo", "divulgacao_grupos"`; model also has belt-and-suspenders `self.table_name = "divulgacoes"` |
| 9 | `Divulgacao.status` enum `prefix: :status`; `DivulgacaoGrupo.status` unprefixed, DIVU-09 vocabulary verbatim | ✓ VERIFIED | `enum :status, {...}, prefix: :status` in `divulgacao.rb`; `enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }` unprefixed in `divulgacao_grupo.rb` |
| 10 | Unique index `[divulgacao_id, whatsapp_group_id]` + model uniqueness + controller `.uniq`s ids | ✓ VERIFIED | `db/schema.rb:96` unique index confirmed; `validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }`; controller `.map(&:to_i).uniq.reject(&:zero?)` |
| 11 | `Arte`/`WhatsappGroup` associations carry NO `dependent: :destroy`; `Client has_many :divulgacoes, dependent: :destroy` | ✓ VERIFIED | `arte.rb: has_many :divulgacoes` (no dependent), `whatsapp_group.rb: has_many :divulgacao_grupos` (no dependent), `client.rb: has_many :divulgacoes, dependent: :destroy` |
| 12 | Zero send code anywhere in this phase's files (no job enqueue, no outbound HTTP, no transport client reference) | ✓ VERIFIED | `grep -rn "sendText\|sendMedia\|Evolution::Client\|perform_later\|\.perform("` across all phase-28 models/controller/views/JS returns only one hit — a code comment referencing phase 29's future `sendText` usage, no executable send code |
| 13 | Only approved artes selectable; model backstop `arte_deve_estar_aprovada` (DIVU-02) | ✓ VERIFIED | Picker uses `@client.artes.approved`; model `validate :arte_deve_estar_aprovada` with exact pt-BR message; test `"arte pending -> re-render :new..."` passes |
| 14 | External-link artes rejected; `caption_only` accepted; Arte model untouched (DIVU-03) | ✓ VERIFIED | `arte_nao_usa_link_externo` checks only `external_url.present?`; `_preview.html.erb` renders `"(sem mídia — mensagem de texto)"` branch for `caption_only`; no `Arte` validation modified (confirmed by diff review) |
| 15 | File-size ceiling 16MB, only when `media_file.attached?`, Arte's 50MB validation untouched (DIVU-04) | ✓ VERIFIED | `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes`; `arquivo_dentro_do_teto_whatsapp` guards on `!arte.media_file.attached?`; message uses `number_to_human_size` with exact "Comprima ou reenvie..." copy |
| 16 | Cross-client model backstop `arte_e_grupos_do_mesmo_cliente` (SEG-02) | ✓ VERIFIED | Validates `arte.client_id != client_id` and every `divulgacao_grupo.whatsapp_group.whatsapp_instance.client_id` — exact messages present |
| 17 | `scheduled_for` validated future-only, blank message routes to `errors[:base]`; `datetime-local` round-trips via `Time.zone`, never stdlib parse (DIVU-05) | ✓ VERIFIED | `scheduled_for_presente`/`scheduled_for_no_futuro` (scoped `on: :create` per CR-01 fix) both add to `:base`; no `Time.parse`/`DateTime.parse` calls found in model; `f.datetime_field` raw string flows straight to the tz-aware AR attribute |
| 18 | `divulgacao_datetime_label` renders `DD/MM/AAAA HH:MM (BRT)`, `"—"` for nil, used everywhere a datetime is shown (DIVU-05) | ✓ VERIFIED | Helper matches spec exactly; used in `new.html.erb` (implicitly via BRT label text), `show.html.erb`, `index.html.erb`, `clients/show.html.erb` mirror card |
| 19 | `_preview.html.erb` renders real media via `rails_storage_proxy_path` + verbatim caption, no `raw`/`html_safe` (DIVU-06) | ✓ VERIFIED | Confirmed by direct file read — `image_tag rails_storage_proxy_path(...)`, `<video><source src=rails_storage_proxy_path...>`, `<%= arte.caption %>` (auto-escaped, no bypass) |
| 20 | `divulgacao_duration_estimate` formula matches spec, `SEND_DELAY_MIN/MAX` from env with 25/45 fallback (DIVU-07) | ✓ VERIFIED | Helper and `Divulgacao::SEND_DELAY_MIN/MAX` constants match exactly; `divulgacao_estimate_controller.js` mirrors the same formula client-side, no network call |
| 21 | Stimulus controllers (`divulgacao_preview`, `divulgacao_estimate`, `picker`) wired, auto-registered, no network calls (DIVU-06/07) | ✓ VERIFIED | All three JS files read; no `fetch`/`XMLHttpRequest`; `data-controller` attributes present in `new.html.erb`; `_picker.html.erb`'s fase-27 markers (`data-picker-select-all`, `data-picker-counter`) now live-wired |
| 22 | `new`/`create` guarded for missing instance / disconnected / zero approved artes / zero active groups, each with correct empty/blocked states | ✓ VERIFIED | `new.html.erb` three-branch structure (`@instance.nil?`, `@approved_artes.empty?`, else) matches UI-SPEC copy verbatim; `#create` guard mirrors the `new` guard server-side before touching params |
| 23 | `#show` renders Detalhes/Grupos(N)/Prévia; cross-client id 404s via `set_divulgacao` scoped find | ✓ VERIFIED | `show.html.erb` has all three sections; `set_divulgacao = @client.divulgacoes.find(params[:id])`; test suite covers cross-client 404 |
| 24 | `_status_badge`/`_grupo_row` pill palette matches UI-SPEC map exactly | ✓ VERIFIED | Direct file read confirms `agendada`→green, `cancelada`→red, `em_andamento`→amber, `concluida`→neutral (Divulgacao); `pendente`→neutral, `enviado`→green, `falhou`→red, `incerto`→amber (DivulgacaoGrupo) |
| 25 | `Cancelar divulgação` button (`turbo_confirm`, no `_confirm_modal`) only on `status_agendada?`; `cancelar!` sets `cancelada`; no `destroy` action/route/button exists | ✓ VERIFIED | `show.html.erb` gate `<% if @divulgacao.status_agendada? %>`; `button_to ... method: :patch, data: { turbo_confirm: ... }`; `Divulgacao#cancelar!` guards `return false unless status_agendada?`; `grep` for `destroy` on divulgacoes routes/controller/views returns nothing |
| 26 | `cancelada` divulgação → neutral banner, red pill, no cancel button, group rows preserved with `pendente` pill | ✓ VERIFIED | `show.html.erb` top banner conditional on `status_cancelada?`; cancel button conditional excludes cancelled state; `_grupo_row` unaffected by parent status (still renders frozen `pendente`) |
| 27 | `clients#show` gains "Divulgações" card (entry point + 5-most-recent mirror + "Ver todas") | ✓ VERIFIED | `admin/clients/show.html.erb:142-174` — header w/ `Nova divulgação` link, `@divulgacoes.first(5)`, "Ver todas" conditional on `> 5`; `Admin::ClientsController#show` loads `@divulgacoes = @client.divulgacoes.includes(:arte).order(scheduled_for: :desc)` |
| 28 | DIVU-08 (cancellation honored by future sends) explicitly NOT in this phase | ✓ VERIFIED | No engine/job code touches `status_cancelada?` anywhere outside the UI action; requirement traceability confirms DIVU-08 mapped to Phase 29 in REQUIREMENTS.md |

**Score:** 28/28 truths verified (0 present, behavior-unverified)

*(Note: the plan frontmatter's ~15 top-level `must_haves.truths` entries across the 4 plans expand
into the 28 granular checks above; every plan-level must_have was independently traced to code and
either a passing test or direct file inspection.)*

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/..._create_divulgacoes.rb` | schema per CONTEXT | ✓ VERIFIED | matches spec exactly, incl. index |
| `db/migrate/..._create_divulgacao_grupos.rb` | two-table + snapshot + nullable phase-29 staging cols | ✓ VERIFIED | `sent_at`, `error_code`, `evolution_message_id` present nullable |
| `config/initializers/inflections.rb` | irregular pluralization | ✓ VERIFIED | present, both `divulgacao`/`divulgacao_grupo` |
| `app/models/divulgacao.rb` | model + validations + constants + `cancelar!` | ✓ VERIFIED | full read, all validations present |
| `app/models/divulgacao_grupo.rb` | model + enum + uniqueness | ✓ VERIFIED | full read |
| `app/controllers/admin/divulgacoes_controller.rb` | index/new/create/show/cancel + guards | ✓ VERIFIED | full read, all actions present |
| `app/helpers/admin/divulgacoes_helper.rb` | datetime label + duration estimate | ✓ VERIFIED | full read |
| `app/views/admin/divulgacoes/new.html.erb` | 3-state form | ✓ VERIFIED | full read |
| `app/views/admin/divulgacoes/index.html.erb` | empty/table/mobile/pagy | ✓ VERIFIED | full read |
| `app/views/admin/divulgacoes/show.html.erb` | detalhes/grupos/prévia | ✓ VERIFIED | full read |
| `app/views/admin/divulgacoes/_preview.html.erb` | real media + verbatim caption | ✓ VERIFIED | full read |
| `app/views/admin/divulgacoes/_status_badge.html.erb` | pill palette | ✓ VERIFIED | full read |
| `app/views/admin/divulgacoes/_grupo_row.html.erb` | frozen name + status pill | ✓ VERIFIED | full read |
| `app/javascript/controllers/divulgacao_preview_controller.js` | pane toggle, no network | ✓ VERIFIED | full read |
| `app/javascript/controllers/divulgacao_estimate_controller.js` | client-side recompute, no network | ✓ VERIFIED | full read |
| `app/javascript/controllers/picker_controller.js` | select-all/counter wiring | ✓ VERIFIED | full read |
| `.env.example` (SEND_DELAY vars) | added or documented if sandbox-blocked | ✓ VERIFIED (fallback branch) | `.env.example` unmodified (confirmed via `git show HEAD:.env.example`, file is permission-blocked in this sandbox); fallback satisfied — env var names + 25/45 defaults documented in `28-03-SUMMARY.md` "Decisions Made", matching the must-have's explicit "or documented in SUMMARY" clause and the phase 25/27 precedent |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `Divulgacao` validations | `errors[:base]` red box | `new.html.erb` iterates `@divulgacao.errors[:base]` | ✓ WIRED | confirmed |
| `f.datetime_field :scheduled_for` | `Time.zone`-aware attribute | raw string assignment, `default_timezone = :local` | ✓ WIRED | no stdlib parse found in model |
| `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES` | ceiling message | `number_to_human_size` | ✓ WIRED | confirmed |
| arte picker `.approved` scope | model `arte_deve_estar_aprovada` | defense-in-depth pair | ✓ WIRED | both present |
| `data-divulgacao-estimate-min/max-value` | `divulgacao_estimate_controller.js` static values | server-injected from `SEND_DELAY_MIN/MAX` | ✓ WIRED | confirmed in `new.html.erb` |
| arte `<select>` `change` | `_preview` panes | `divulgacao-preview#show` action | ✓ WIRED | confirmed |
| `picker_controller.js` select-all `change` | `divulgacao-estimate#recompute` | bubbling synthetic `change` on wrapper | ✓ WIRED | confirmed by code read + JS logic trace |
| `_preview.html.erb` `rails_storage_proxy_path` | ActiveStorage proxy route | always-mounted, auth-gated | ✓ WIRED | no presign/`url_for` used |
| `#cancel` → `status: :cancelada` | `_status_badge` palette | enum value → case/when | ✓ WIRED | confirmed |
| `Admin::ClientsController#show` `@divulgacoes` | `clients/show.html.erb` mirror card | ivar read | ✓ WIRED | confirmed |
| `show.html.erb` Prévia section | `_preview.html.erb` | `render "preview", arte: @divulgacao.arte` | ✓ WIRED | confirmed |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `new.html.erb` arte select | `@approved_artes` | `@client.artes.approved.order(scheduled_on: :desc)` (DB query) | Yes | ✓ FLOWING |
| `new.html.erb` picker | groups | `_picker` partial → `client.whatsapp_instance.whatsapp_groups.active` (fase 27 DB query) | Yes | ✓ FLOWING |
| `_preview.html.erb` media | `arte.media_file` | ActiveStorage blob, real attached file | Yes | ✓ FLOWING |
| `index.html.erb` / mirror card | `@divulgacoes` | `@client.divulgacoes.includes(:arte).order(...)` (DB query, `pagy`-scoped) | Yes | ✓ FLOWING |
| `show.html.erb` Grupos section | `@divulgacao.divulgacao_grupos` | real association, ordered by `group_name` | Yes | ✓ FLOWING |
| estimate text (server) | `divulgacao_duration_estimate(@divulgacao.divulgacao_grupos.size)` | live association count on `new` (0 pre-submit) | Yes (formula real, not hardcoded) | ✓ FLOWING |

No static/hardcoded/mock data found flowing to any rendered dynamic value in phase 28's scope.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full phase-28 test scope passes | `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test test/models/divulgacao_test.rb test/models/divulgacao_grupo_test.rb test/helpers/admin/divulgacoes_helper_test.rb test/controllers/admin/divulgacoes_controller_test.rb test/controllers/admin/clients_controller_test.rb` | `82 runs, 410 assertions, 0 failures, 0 errors, 0 skips` | ✓ PASS |
| Cross-client A×B isolation (SEG-01/SEG-02) | named tests in `divulgacoes_controller_test.rb` (part of the 82 above) | passing, `refute_includes` confirms no data leak | ✓ PASS |
| Malformed-params (Hash-shaped / Array-shaped) → 422 never 500 (CR-02 fix) | named tests `"CR-02: whatsapp_group_ids Hash-shaped..."`, `"CR-02: arte_id Array-shaped..."` | passing | ✓ PASS |
| Snapshot freeze survives group rename/deactivate (DIVU-09) | named test `"renomear e desativar o grupo apos criar nao altera o snapshot..."` | passing | ✓ PASS |
| Zero send code present | `grep -rn "sendText\|sendMedia\|Evolution::Client\|perform_later\|\.perform("` across phase-28 files | 1 hit, a code comment only | ✓ PASS |
| Regression: sibling phase 25/26/27 test files | `bin/rails test` for `arte_test.rb client_test.rb whatsapp_group_test.rb whatsapp_instance_test.rb artes_controller_test.rb whatsapp_groups_controller_test.rb whatsapp_instances_controller_test.rb` | `85 runs, 283 assertions, 1 failures, 0 errors, 0 skips` — the 1 failure (`ArteTest#test_revised!_broadcast...`) confirmed **pre-existing** (reproduced identically against commit `bdc753b`, the pre-phase-28 baseline, before phase 28 touched anything); phase 28's only change to `arte.rb` is an additive `has_many :divulgacoes` with no relation to calendar-chip broadcast DOM ids | ✓ PASS (no phase-28 regression) |

### Probe Execution

Not applicable — phase 28 is a CRUD/UI phase, no `scripts/*/tests/probe-*.sh` declared or found. SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DIVU-01 | 28-01, 28-04 | Admin cria Divulgação (cliente, arte, grupos, data/hora) | ✓ SATISFIED | Truths 1, 2 |
| DIVU-02 | 28-02 | Só artes aprovadas | ✓ SATISFIED | Truth 13 |
| DIVU-03 | 28-02 | Link externo recusado, caption_only aceito | ✓ SATISFIED | Truth 14 |
| DIVU-04 | 28-02 | Teto de arquivo, sem alterar validação da Arte | ✓ SATISFIED | Truth 15 |
| DIVU-05 | 28-02, 28-03, 28-04 | Fuso explícito, `scheduled_on` intocado | ✓ SATISFIED | Truths 17, 18 |
| DIVU-06 | 28-03 | Preview de mídia + legenda | ✓ SATISFIED | Truth 19 |
| DIVU-07 | 28-03 | Estimativa de duração | ✓ SATISFIED | Truth 20 |
| DIVU-08 | (Phase 29, per REQUIREMENTS.md) | Cancelamento honrado pelos envios | N/A this phase | Correctly deferred — Truth 28 confirms only the column/state/UI ships here |
| DIVU-09 | 28-01, 28-04 | Registro por grupo, status enum, nome congelado | ✓ SATISFIED | Truths 3, 9, 23, 24 |
| SEG-01 | 28-01 | Id nunca cru do form | ✓ SATISFIED | Truths 4, 5 |
| SEG-02 | 28-01, 28-02 | Recusa cross-client | ✓ SATISFIED | Truths 4, 16 |

**Orphaned requirements check:** REQUIREMENTS.md maps DIVU-01..07, DIVU-09, SEG-01, SEG-02 to Phase 28 — all 10 appear in at least one plan's `requirements:` frontmatter (28-01: DIVU-01, DIVU-09, SEG-01, SEG-02; 28-02: DIVU-02..04, SEG-02; 28-03: DIVU-05..07; 28-04: DIVU-01, DIVU-05, DIVU-09). No orphaned requirement found. DIVU-08 is correctly excluded (mapped to Phase 29 in REQUIREMENTS.md and explicitly named out-of-scope in this phase's CONTEXT.md and plan 04).

### Anti-Patterns Found

None. Scanned all 22 phase-28 files for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` and hollow-implementation patterns (`return null`, empty handlers, hardcoded empty arrays/hashes flowing to render). The only "placeholder" string matches are a legitimate Stimulus target name (`data-divulgacao-preview-target="placeholder"`) for the "select an arte" empty-preview UI state — not a code stub.

### Human Verification Required

None. All truths resolved to VERIFIED via direct code inspection cross-referenced with a passing, behaviorally-relevant test suite (82/82). No visual/real-time/external-service behavior in this phase's scope requires human judgment beyond what the automated tests already exercise (form rendering states, cross-client isolation, snapshot freezing, malformed-params handling are all asserted by name in the test suite, not just inferred from presence).

### Gaps Summary

No gaps. All 28 derived observable truths (rolling up the ~15 plan-level `must_haves.truths` across the 4 plans) verified against actual code, not SUMMARY claims. The phase's own 3-iteration code-review auto-loop (28-REVIEW.md/.iter2/.iter3) independently found and fixed 2 Critical + 2 Warning issues (CR-01 cancel-validation-crash, CR-02/WR-02 malformed-params-500, WR-01 rescue-block data loss + its residual) before this verification ran; re-tracing all four fixes in the current code confirms they hold, and the pre-phase-28 regression in `arte_test.rb` (calendar-chip broadcast target naming) is confirmed unrelated by reproducing it against the pre-phase-28 commit.

---

_Verified: 2026-08-30T23:45:00Z_
_Verifier: Claude (gsd-verifier)_
