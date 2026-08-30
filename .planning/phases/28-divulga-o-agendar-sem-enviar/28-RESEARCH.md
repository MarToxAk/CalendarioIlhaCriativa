# Phase 28: Divulgação — Agendar sem Enviar - Research

**Researched:** 2026-08-30
**Domain:** Rails 8.1 nested-resource CRUD (`admin/clients/:client_id/divulgacoes`) with a two-table schema (`divulgacoes` + `divulgacao_grupos`), model-level cross-client validation as the security boundary, a `datetime-local` → `Time.zone` round-trip, a no-JS ActiveStorage media preview, and a client-side duration estimate — deliberately stopping before any send.
**Confidence:** HIGH for the schema, the reuse contracts (`_picker.html.erb`, `@client.artes.find` scoping, Arte validation style), the timezone round-trip, and the test harness — all read from source this session. MEDIUM for the `WHATSAPP_MEDIA_MAX_BYTES` value (16 MB is a convergent heuristic + WhatsApp's documented regular-media ceiling, but this specific Evolution gateway has NOT been measured — a phase-29 UAT item). MEDIUM for the phase-29 delay env-var names (no repo precedent — proposed here, phase 29 owns the canonical definition).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

> All 4 grey areas from smart-discuss were accepted as recommended. The CONTEXT.md `## Implementation Decisions` are LOCKED — research supports these, does not offer alternatives.

### Locked Decisions

**Modelo de dados da Divulgação**
- Duas tabelas: `divulgacoes` (`belongs_to :client`, `belongs_to :arte`) + `divulgacao_grupos` (`belongs_to :divulgacao`, `belongs_to :whatsapp_group`) — **uma linha por grupo** (DIVU-09).
- `divulgacao_grupos.status` enum: `pendente / enviado / falhou / incerto` (texto verbatim do DIVU-09). Default `pendente`. Nesta fase toda linha nasce e permanece `pendente` — as outras transições são da fase 29.
- `divulgacoes.status` enum: `agendada / em_andamento / concluida / cancelada`. Default `agendada`. A transição `cancelada` é acionável nesta fase (botão em `#show`); as demais são da fase 29. A coluna/estado precisa existir agora porque o motor da fase 29 lê para decidir se ainda envia.
- Referência ao grupo em `divulgacao_grupos`: FK `whatsapp_group_id` (escopada, para o motor re-resolver e revalidar) **+** snapshot congelado na criação: `group_name` (string, = `whatsapp_group.display_name` no instante da criação) e `remote_jid` (string). Se o grupo for depois desativado/renomeado, o histórico da Divulgação mantém o nome como estava (DIVU-09: "nome do grupo congelado como estava").
- Data/hora do envio: nova coluna `scheduled_for` (`datetime`, tz-aware) em `divulgacoes`. `Arte#scheduled_on` permanece **`date` sem hora, intocada** (DIVU-05). `scheduled_for` é independente de `arte.scheduled_on` — o admin escolhe quando disparar.
- Índices: `divulgacao_grupos [divulgacao_id, whatsapp_group_id]` único (um grupo não entra duas vezes na mesma Divulgação); `divulgacoes [client_id, scheduled_for]`.

**Validações na criação**
- **Só artes aprovadas (DIVU-02):** o picker de arte lista apenas `@client.artes.approved`; o model revalida com `validate :arte_deve_estar_aprovada` no create (defense-in-depth — a arte pode ter mudado de status entre o carregamento do form e o submit).
- **Link externo recusado (DIVU-03):** na criação da Divulgação, recusa se `arte.external_url.present?` ou se `!arte.media_file.attached?`, com mensagem orientando: "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a divulgação." **Não altera nenhuma validação da `Arte`.**
- **Teto de arquivo (DIVU-04):** constante nível-Divulgação `WHATSAPP_MEDIA_MAX_BYTES` (valor exato a confirmar na pesquisa contra o contrato Evolution/WhatsApp 2.3.7 — ordem de grandeza: ~16 MB para vídeo/documento). Validação `validate :arquivo_dentro_do_teto_whatsapp` compara `arte.media_file.blob.byte_size` contra a constante. A validação de 50 MB da `Arte` **permanece intacta**. Mensagem: diz o tamanho atual e o teto, e sugere comprimir/reenviar.
- **Cross-client + id cru (SEG-01/SEG-02):**
  - SEG-02: `validate :arte_e_grupos_do_mesmo_cliente` — `arte.client_id` deve ser igual a `divulgacao.client_id`; qualquer divergência recusa a criação.
  - SEG-01: o form nunca aceita `remote_jid` cru. Todo id submetido em `divulgacao[whatsapp_group_ids][]` é re-resolvido por `client.whatsapp_instance.whatsapp_groups.where(active: true).find(id)` — um id de outro cliente ou de grupo inativo levanta `RecordNotFound` e a criação é recusada. Mesmo padrão de `@client.artes.find`.
  - Reusa o `_picker.html.erb` da fase 27 **verbatim**, agora com `field_name: "divulgacao[whatsapp_group_ids][]"`.

**Preview e estimativa de duração**
- **Preview (DIVU-06):** card acima do botão "Agendar divulgação" mostrando (a) o render da **mídia real** — `image_tag` para imagem, `<video>` com o preview/variant do ActiveStorage para vídeo — e (b) a **legenda exatamente como será enviada**. Sem transformação.
- **Legenda anti-spam (RESOLVIDA):** **v1.7 envia a legenda VERBATIM.** Sem rotação/spinning/variação de legenda neste milestone. O preview mostra a legenda única. (Variação vira `caption_variants` + preview de todas — deferido.)
- **Estimativa de duração (DIVU-07):** `n_grupos_selecionados × média(delay_min, delay_max)`, exibida como faixa humana ("≈ 8–14 min para 20 grupos"). Os valores de delay vêm das env vars da fase 29 (`ENVIO-02` — nomes exatos a confirmar na pesquisa); se ausentes no ambiente, usa defaults documentados e sinaliza que é estimativa. A estimativa atualiza quando o admin muda a seleção de grupos (Stimulus, cálculo client-side a partir de um data-attribute com o range, ou recomputo no submit — o UI-SPEC decide).
- **Layout:** **página única** (`divulgacoes#new`). Topo: seletor de arte + `_picker` de grupos + input de agendamento. Abaixo: card de preview + estimativa. Um submit "Agendar divulgação". Sem wizard multi-step.

**Rotas, navegação e fuso**
- **Rota:** `resources :divulgacoes, only: [:index, :new, :create, :show]` aninhada em `namespace :admin { resources :clients { ... } }`, mesmo padrão de `whatsapp_groups`. `Admin::DivulgacoesController < Admin::BaseController`; `set_client` a partir de `Client.find(params[:client_id])`.
- **Fuso (DIVU-05):** todos os datetimes na tela renderizados com offset explícito — ex. "15/09/2025 14:00 (BRT)" ou "(America/Sao_Paulo)". O input do form é `datetime-local` interpretado em `Time.zone` (já `America/Sao_Paulo` como default do app — INFRA-03). Helper de formatação dedicado (pt-BR).
- **Ponto de entrada:** botão "Nova divulgação" no `admin/clients#show` (perto do painel WhatsApp) + uma seção listando as divulgações daquele cliente (`divulgacoes#index` embutido ou linkado). Sem item no menu lateral global nesta fase.
- **Cancelamento:** `divulgacoes#show` tem botão "Cancelar divulgação" (com `turbo_confirm`) → `PATCH` que seta `status: :cancelada`. Sem `destroy` — o registro e o histórico por grupo são preservados. A honra do cancelamento pelos envios não-realizados é DIVU-08 / fase 29.

### Claude's Discretion (research recommends — see body)
- Nome exato do controller de cancelamento (`cancel` custom vs `update` com state param) e verbo/rota.
- Se `divulgacao_grupos` ganha `sent_at` / `error_code` / `evolution_message_id` agora (colunas nulas prontas p/ fase 29) ou se a fase 29 as adiciona — preferência: adicionar as colunas nulas agora.
- Estrutura exata do preview de vídeo (poster/variant vs `<video controls>` cru).
- Se a estimativa recalcula via Stimulus client-side ou só no re-render — seguir o UI-SPEC.
- Textos pt-BR exatos, classes Tailwind, ícones.
- Se `divulgacoes#index` é página própria ou só uma seção parcial no `clients#show`.
- Nome do helper de formatação de fuso e do arquivo de constantes do teto de mídia.

### Deferred Ideas (OUT OF SCOPE)
- Variação de legenda anti-spam (`caption_variants`) — explicitamente fora do v1.7; a legenda vai verbatim.
- Normalização de links Drive/Dropbox para download direto (PROD-04) — no v1.7 são bloqueados, não normalizados.
- O motor de envio, jobs de disparo, `sendText`/`sendMedia`, idempotência de envio, revalidação de aprovação/conexão no momento do envio — tudo fase 29.
- Progresso ao vivo, reenvio por grupo, histórico consolidado por cliente — fase 30.
- Testes negativos cross-client de ponta a ponta (SEG-04) — fase 30 (o teste de que a arte de A não *alcança* grupos de B precisa do motor). Esta fase tem os testes de validação de criação.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DIVU-01 | Admin cria uma Divulgação escolhendo cliente, arte, grupos e data/hora de envio | Nested `Admin::DivulgacoesController#new/#create` sob `resources :clients` (§Pattern 1); form de página única com seletor de arte (`@client.artes.approved`), `_picker.html.erb` (§Pattern 6), `datetime_field :scheduled_for` (§Pattern 4). Precedente exato: `Admin::ArtesController` + `admin/artes/_form.html.erb`. |
| DIVU-02 | Só artes aprovadas podem ser selecionadas para Divulgação | Picker de arte = `@client.artes.approved` (enum `status` já em `Arte` `[VERIFIED: app/models/arte.rb:28]`). Model revalida: `validate :arte_deve_estar_aprovada` (§Pattern 5, defense-in-depth). |
| DIVU-03 | Artes com link externo (Drive/Dropbox) recusadas na criação, com mensagem orientando o upload | `validate :arte_nao_usa_link_externo` — recusa SO se `arte.external_url.present?` (§Pattern 5). Artes `caption_only` (sem arquivo, sem link) SAO aceitas — fase 29 ENVIO-10 envia via sendText. NAO toca as validacoes de `Arte`. [Open Question 1 RESOLVIDA em 28-CONTEXT.md] |
| DIVU-04 | Arquivos acima do teto do WhatsApp recusados na criação da Divulgação, sem alterar a validação da Arte | `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` (§Pattern 5, §State of the Art, Assumption A1). `validate :arquivo_dentro_do_teto_whatsapp` compara `arte.media_file.blob.byte_size`. `Arte` mantém `size: { less_than: 50.megabytes }` `[VERIFIED: app/models/arte.rb:40]`. |
| DIVU-05 | Data/hora exibidas com fuso explícito; `Arte#scheduled_on` permanece data sem hora | Nova coluna `divulgacoes.scheduled_for :datetime`. `Arte.scheduled_on` fica `t.date … null: false` intocada `[VERIFIED: db/schema.rb:64]`. `datetime-local` → `Time.zone` round-trip via time-zone-aware attributes (§Pattern 4). Helper pt-BR com sufixo "(BRT)". |
| DIVU-06 | Admin vê preview do que será postado — mídia e legenda — antes de confirmar | Preview server-rendered sem JS: `image_tag rails_storage_proxy_path(blob)` / `<video controls playsinline preload="metadata">` — precedente verbatim em `app/views/client/artes/show.html.erb:27-36` `[VERIFIED]`. Legenda = `arte.caption` renderizada `whitespace-pre-wrap`, verbatim (§Pattern 7). |
| DIVU-07 | Admin vê estimativa de duração do disparo ao agendar, dado o nº de grupos e a faixa de delay | `n_grupos × média(min,max)` com faixa humana. Lê `WHATSAPP_SEND_DELAY_MIN_SECONDS` / `_MAX_SECONDS` (proposto §Pattern 8, Assumption A2) com fallback documentado. Stimulus lê `data-*` no container do picker; fallback = recompute no re-render (§Pattern 8). |
| DIVU-09 | Cada grupo com registro próprio, status `pendente/enviado/falhou/incerto`, nome do grupo congelado | Tabela `divulgacao_grupos`, uma linha por grupo, `status` enum (texto verbatim), snapshot `group_name` = `whatsapp_group.display_name` + `remote_jid` no `#create`. Índice único `[divulgacao_id, whatsapp_group_id]` (§Pattern 2, §Pattern 3). |
| SEG-01 | Identificador do grupo nunca vem cru do formulário — só chaves internas resolvidas no escopo do cliente | `_picker.html.erb` emite `check_box_tag "divulgacao[whatsapp_group_ids][]", group.id` (nunca `remote_jid`) `[VERIFIED: app/views/admin/whatsapp_groups/_group_row.html.erb:4-6]`. `#create` re-resolve cada id via `@client.whatsapp_instance.whatsapp_groups.where(active: true).find(ids)` → `RecordNotFound` (§Pattern 3, §Pattern 6). |
| SEG-02 | Sistema recusa Divulgação cuja arte e grupos não pertençam ao mesmo cliente | `arte_id` re-resolvido via `@client.artes.find` no controller + `validate :arte_e_grupos_do_mesmo_cliente` no model (§Pattern 5). Teste canônico A×B (§Test Strategy). Mesmo shape do teste A×B já provado em `test/controllers/admin/whatsapp_groups_controller_test.rb` (fase 27). |
</phase_requirements>

---

## Summary

Phase 28 is a **schema + nested-CRUD + validation-boundary** phase with **zero new gems** and **zero new external calls**. Everything it needs already exists in the repo: the nested-resource controller pattern (`Admin::ArtesController`, `Admin::WhatsappGroupsController`), the association-scoping security pattern (`@client.artes.find` → `RecordNotFound`/404), the reusable scoped group picker (`app/views/admin/whatsapp_groups/_picker.html.erb`, built in phase 27 *specifically* for this phase), the Arte custom-validation style (`validate :method` + `errors.add(:base, "pt-BR message")`), time-zone-aware attributes (`config.time_zone = "Brasilia"`, `default_timezone = :local`, INFRA-03 boot check), the no-JS media preview (`client/artes/show.html.erb`), and `image_processing`/`mini_magick`/`ruby-vips` already in `Gemfile.lock` (not needed for the preview, but available).

The work is: (1) two migrations — `divulgacoes` (`client_id`, `arte_id`, `scheduled_for:datetime`, `status:integer`, index `[client_id, scheduled_for]`) and `divulgacao_grupos` (`divulgacao_id`, `whatsapp_group_id`, `status:integer default 0`, `group_name:string`, `remote_jid:string`, unique index `[divulgacao_id, whatsapp_group_id]`, plus nullable `sent_at`/`error_code`/`evolution_message_id` staged for phase 29); (2) `Divulgacao` + `DivulgacaoGrupo` models with the two enums (`divulgacoes.status` prefixed to avoid the `pendente`/`enviado` collision with `divulgacao_grupos.status`) and four custom `validate` methods; (3) `Admin::DivulgacoesController` (`index`, `new`, `create`, `show`, `cancel`); (4) the single-page `new` view embedding `_picker.html.erb` with `field_name: "divulgacao[whatsapp_group_ids][]"`, the media/caption preview, and the duration estimate; (5) an entry point on `admin/clients/show.html.erb`; (6) a small `divulgacao_estimate_controller.js` Stimulus controller (per UI-SPEC).

Two mechanics carry the risk. **Cross-client isolation** is enforced in three redundant places: `arte_id` re-resolved through `@client.artes.find`, every group id re-resolved through `@client.whatsapp_instance.whatsapp_groups.where(active: true).find(...)`, and the model's `arte_e_grupos_do_mesmo_cliente` validation as backstop. **The `datetime-local` round-trip** works out of the box because Rails 8.1 `load_defaults` enables time-zone-aware attributes — assigning the raw `"2026-09-15T14:00"` string to `divulgacao.scheduled_for` casts it through `Time.zone` (Brasília); the only rule is never call `Time.parse` on the param (use the attribute assignment, or `Time.zone.parse`).

**Primary recommendation:** Follow the locked schema and the code skeletons in §Code Examples verbatim. Build the `divulgacao_grupos` rows as **association records** (`divulgacao.divulgacao_grupos.build(...)` inside the single `divulgacao.save` transaction) — **not** `insert_all` — because N is tens of rows tied to a just-created parent with a frozen snapshot, and `insert_all` would bypass the `belongs_to` presence checks and re-introduce the Rails-8.1 timestamp gotcha for no benefit. Set `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` now, tagged as a conservative heuristic, and add an Assumptions-Log entry so phase-29 UAT measures the real ceiling (5/15/20/30 MB probe already scoped in `evolution-contract.md:56`). Propose `WHATSAPP_SEND_DELAY_MIN_SECONDS` / `WHATSAPP_SEND_DELAY_MAX_SECONDS` env vars with fallback `30`/`90`; phase 29 owns the canonical read, phase 28 only needs a read-only helper.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Persist a Divulgação + one row per selected group | Database / ActiveRecord — `Divulgacao` + `DivulgacaoGrupo` models, single `save` transaction | — | Two tables, FK integrity, unique index `[divulgacao_id, whatsapp_group_id]`. Snapshot columns frozen at create time. |
| Enforce "arte + grupos same client" | API / Backend — controller scoping (`@client.artes.find`, `@client.whatsapp_instance.whatsapp_groups.…find`) | Model (`validate :arte_e_grupos_do_mesmo_cliente` backstop) | Server-side only. Cross-client id → `RecordNotFound`. Same pattern as `client/artes_controller.rb:10` `[VERIFIED]`. |
| Enforce "approved / has file / under ceiling" | Model — `Divulgacao` custom `validate` methods | API / Backend (arte picker pre-filters `.approved`) | Defense-in-depth: arte state can change between form load and submit. Matches `Arte#media_source_present` style. |
| Render the media + caption preview | Frontend Server (ERB) + Browser (`<img>` / `<video>`) | Database / ActiveStorage (`rails_storage_proxy_path` streams the blob) | Server-rendered, no JS. Exact precedent: `client/artes/show.html.erb`. |
| Parse `datetime-local` into the right zone | API / Backend — AR time-zone-aware attribute assignment | — | `config.time_zone = "Brasilia"` + `time_zone_aware_attributes` (default under `load_defaults 8.1`). Never `Time.parse`. |
| Compute + display the duration estimate | Browser — `divulgacao_estimate_controller.js` reading `data-*` | API / Backend (helper computes the range on server re-render as fallback) | Pure arithmetic on `n_groups × avg(min,max)`. No persistence, no API call. |
| Cancel a scheduled Divulgação | API / Backend — `Admin::DivulgacoesController#cancel` (`PATCH`) | Model (`status` enum transition guard) | Sets `status: :cancelada`. No `destroy`. Honoring it against un-sent groups is DIVU-08 / phase 29. |

---

## Standard Stack

### Core — everything already in the repo; no `bundle add` in this phase

| Library | Version (Gemfile.lock) | Purpose here | Why standard |
|---------|------------------------|--------------|--------------|
| `rails` | 8.1.3 `[VERIFIED: Gemfile.lock]` | `enum`, `belongs_to`/`has_many`, custom `validate`, time-zone-aware attributes, nested routes | Framework. Time-zone-aware attributes are on by default under `config.load_defaults 8.1` `[VERIFIED: config/application.rb:14]`. |
| `pagy` | 9.4.0 `[VERIFIED: Gemfile.lock]` | Paginate `divulgacoes#index` (and the picker, already wired) | `Pagy::Backend` included in `Admin::BaseController` `[VERIFIED: app/controllers/admin/base_controller.rb:4]`. |
| `active_storage` (Rails) | 8.1.3 | `arte.media_file.blob.byte_size` for the ceiling check; `rails_storage_proxy_path` for the preview | Already the media store (S3/MinIO, `config/storage.yml`). `client/artes/show.html.erb` is the render precedent. |
| `active_storage_validations` | (in `Gemfile`, no explicit version) `[VERIFIED: Gemfile:36]` | Only used indirectly — `Arte` already uses `content_type:` / `size:` via this gem; **do not** re-validate the blob on `Divulgacao` with it (the ceiling check is a plain `validate` method against a constant) | Already a dependency. |
| `turbo-rails` | 2.0.23 `[VERIFIED: Gemfile.lock]` | `button_to` + `data: { turbo_confirm: … }` for the cancel action; `turbo_submits_with` on the create submit | Established pattern (`_panel.html.erb:79` uses `turbo_submits_with`). |
| `stimulus-rails` | 1.3.4 `[VERIFIED: Gemfile.lock]` | `divulgacao_estimate_controller.js` (recompute the estimate on selection change) | Precedents: `group_sync_controller.js`, `media_type_toggle_controller.js`, `toast_controller.js`. |
| `image_processing` / `mini_magick` / `ruby-vips` | 1.14.0 / 5.3.1 / 2.3.0 `[VERIFIED: Gemfile.lock]` | **Available but not required** — the preview renders the full blob constrained by CSS, no variant | Present since earlier phases. A `resize_to_limit` variant is an optional perf refinement (§Pattern 7). |

### Supporting — artifacts to create (not packages)

| Artifact | Path | Purpose |
|----------|------|---------|
| `Divulgacao` model | `app/models/divulgacao.rb` | `belongs_to :client, :arte`; `has_many :divulgacao_grupos, dependent: :destroy`; enum `status`; 4 custom `validate`; `WHATSAPP_MEDIA_MAX_BYTES` constant; `cancelar!`. |
| `DivulgacaoGrupo` model | `app/models/divulgacao_grupo.rb` | `belongs_to :divulgacao, :whatsapp_group`; enum `status` `{ pendente, enviado, falhou, incerto }`; `validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }`. |
| `Admin::DivulgacoesController` | `app/controllers/admin/divulgacoes_controller.rb` | `< Admin::BaseController`; `set_client`; `index`, `new`, `create`, `show`, `cancel`. |
| Migrations ×2 | `db/migrate/…_create_divulgacoes.rb`, `…_create_divulgacao_grupos.rb` | Schema per CONTEXT + phase-29 nullable columns. |
| Views | `app/views/admin/divulgacoes/{index,new,show}.html.erb` + `_preview.html.erb` | Single-page `new`; `show` with cancel button; `index` list. |
| `Admin::DivulgacoesHelper` | `app/helpers/admin/divulgacoes_helper.rb` | `divulgacao_datetime_label(t)` (pt-BR + "(BRT)"), `divulgacao_duration_estimate(n, min, max)`. |
| `divulgacao_estimate_controller.js` | `app/javascript/controllers/` | Recompute the estimate range on checkbox change (per UI-SPEC). |
| `Divulgacao::SEND_DELAY_*` reader | in `Divulgacao` or `app/models/divulgacao.rb` | `Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN_SECONDS", "30"))` etc. — mirrors `Evolution` constants `[VERIFIED: app/services/evolution.rb:57-59]`. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Build `divulgacao_grupos` as association records in one `save` | `DivulgacaoGrupo.insert_all(rows, unique_by: …)` after `divulgacao.save!` | `insert_all` skips `belongs_to` presence + the uniqueness validation, re-introduces the Rails-8.1 "omit `created_at`/`updated_at` from the row hash" gotcha, and needs a second statement. N is ~tens of rows → association build is simpler and atomic. Use `insert_all` only if a profile shows the build path is slow (it won't be at this N). |
| Dedicated `cancel` member route (`PATCH /…/divulgacoes/:id/cancel`) | `update` with `params[:divulgacao][:status]` | Routes are locked to `only: [:index, :new, :create, :show]`; adding `patch :cancel, on: :member` is one line and keeps the state transition in an explicit action with its own guard. **Recommended.** |
| Model constant `Divulgacao::WHATSAPP_MEDIA_MAX_BYTES` | `config/initializers/whatsapp_limits.rb` | Colocating the constant with the `validate` method that consumes it is more discoverable and testable. **Recommended** (Claude's discretion, resolved). |
| Full blob in the preview `<img>`/`<video>` constrained by CSS | `arte.media_file.variant(resize_to_limit: [800, 800])` for images | Variant needs a processing round-trip + storage; the preview is one admin looking once. Full blob + `max-h-[480px] object-contain` matches `client/artes/show.html.erb`. Variant is a later perf refinement. |
| `rails_storage_proxy_path` (Rails streams the bytes) | `url_for(blob)` / `rails_blob_path` (redirect to a ~5 min presigned URL) | Both work. Proxy = no presign-expiry surprise while the admin edits the form for >5 min; matches the client-show precedent. `_admin_calendar_chip.html.erb` uses `url_for` for a JS tooltip — different context. **Use proxy.** |

**Installation:** none. `git grep` + `Gemfile.lock` read this session confirm no `bundle add`, no importmap pin.

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** Every library it uses is already resolved in `Gemfile.lock` and was verified by direct file read this session.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| — | — | — | No new packages in phase 28 |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

---

## Architecture Patterns

### System Architecture Diagram

```
 admin/clients/:id#show  ──"Nova divulgação" link──▶  GET /admin/clients/:client_id/divulgacoes/new
        │
        ▼
 Admin::DivulgacoesController#new
        │  set_client: @client = Client.find(params[:client_id])
        │  @divulgacao = @client.divulgacoes.new
        │  @approved_artes = @client.artes.approved.order(scheduled_on: :desc)
        ▼
 new.html.erb  (single page)
        │  form_with model: [@client, @divulgacao]
        │  ├─ select :arte_id   ← @approved_artes  (DIVU-02)
        │  ├─ render "admin/whatsapp_groups/picker",
        │  │        client: @client,
        │  │        selected_ids: [],
        │  │        field_name: "divulgacao[whatsapp_group_ids][]"   ← live checkboxes (SEG-01)
        │  ├─ datetime_field :scheduled_for                          ← Time.zone (DIVU-05)
        │  ├─ render "preview"  (media via rails_storage_proxy_path + caption verbatim)  (DIVU-06)
        │  └─ duration estimate  (data-* → divulgacao_estimate_controller.js)            (DIVU-07)
        ▼
 POST /admin/clients/:client_id/divulgacoes
        │
        ▼
 Admin::DivulgacoesController#create
        │  set_client
        │  arte  = @client.artes.find(params[:divulgacao][:arte_id])          ── RecordNotFound ─▶ 404  (SEG-02)
        │  gids  = Array(params[:divulgacao][:whatsapp_group_ids]).map(&:to_i).uniq
        │  groups = @client.whatsapp_instance.whatsapp_groups
        │                   .where(active: true).find(gids)                    ── RecordNotFound ─▶ re-render :new  (SEG-01)
        │  @divulgacao = @client.divulgacoes.new(arte:, scheduled_for: params[…][:scheduled_for])
        │  groups.each { |g| @divulgacao.divulgacao_grupos.build(
        │        whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid) }   (DIVU-09 snapshot)
        │  @divulgacao.save
        │     ├─ validate :arte_deve_estar_aprovada           (DIVU-02)
        │     ├─ validate :arte_nao_usa_link_externo         (DIVU-03: so external_url)
        │     ├─ validate :arquivo_dentro_do_teto_whatsapp    (DIVU-04)
        │     ├─ validate :arte_e_grupos_do_mesmo_cliente     (SEG-02 backstop)
        │     └─ validate :ao_menos_um_grupo
        │  ok  → redirect_to [@client, @divulgacao], notice: …
        │  bad → render :new, status: :unprocessable_entity  (errors[:base] box, same as artes/_form)
        ▼
 GET /admin/clients/:client_id/divulgacoes/:id  (#show)
        │  @divulgacao = @client.divulgacoes.find(params[:id])
        │  renders: arte preview, scheduled_for "(BRT)", per-group rows (status pendente, frozen group_name)
        │  "Cancelar divulgação" button_to  (turbo_confirm) ─▶ PATCH …/:id/cancel ─▶ status: :cancelada
        ▼
 (NO send. NO job. NO Evolution call.  All of that is phase 29.)
```

### Recommended Project Structure

```
app/
├── controllers/admin/divulgacoes_controller.rb     # index, new, create, show, cancel
├── models/divulgacao.rb                             # enum status (prefixed), 4 validates, WHATSAPP_MEDIA_MAX_BYTES, cancelar!
├── models/divulgacao_grupo.rb                       # enum status {pendente,enviado,falhou,incerto}, uniqueness
├── helpers/admin/divulgacoes_helper.rb              # divulgacao_datetime_label, divulgacao_duration_estimate
├── javascript/controllers/divulgacao_estimate_controller.js
└── views/admin/divulgacoes/
    ├── index.html.erb
    ├── new.html.erb
    ├── show.html.erb
    ├── _form.html.erb        # optional — new is single-use, may inline
    └── _preview.html.erb     # media (proxy path) + caption verbatim
db/migrate/
├── XXXX_create_divulgacoes.rb
└── XXXX_create_divulgacao_grupos.rb
config/routes.rb                                     # nested resources :divulgacoes + patch :cancel on member
app/models/client.rb                                 # + has_many :divulgacoes, dependent: :destroy
app/models/arte.rb                                   # + has_many :divulgacoes  (NO dependent: :destroy — see Pitfall 7)
app/views/admin/clients/show.html.erb               # + "Nova divulgação" entry point + divulgações list section
```

### Pattern 1: Nested resource under `resources :clients` — mirror `Admin::ArtesController`

**What:** `Admin::DivulgacoesController < Admin::BaseController` with `before_action :set_client`. Routes nested exactly like `whatsapp_groups`.

```ruby
# config/routes.rb — inside `namespace :admin { resources :clients do ... end }`
resources :divulgacoes, only: [ :index, :new, :create, :show ] do
  member { patch :cancel }
end
# helpers: admin_client_divulgacoes_path(client), new_admin_client_divulgacao_path(client),
#          admin_client_divulgacao_path(client, divulgacao), cancel_admin_client_divulgacao_path(client, divulgacao)
```

**Key facts (read this session):**
- `Admin::BaseController` gives `before_action :require_authentication` + `Pagy::Backend` `[VERIFIED: app/controllers/admin/base_controller.rb:1-5]` — every action is auth-gated, no new auth surface.
- `set_client` pattern: `@client = Client.find(params[:client_id])` (raises `RecordNotFound` → Rails renders 404). `Admin::WhatsappGroupsController#set_client` `[VERIFIED: app/controllers/admin/whatsapp_groups_controller.rb:72]` uses the bare `.find`; `Admin::ArtesController#set_client` `[VERIFIED: app/controllers/admin/artes_controller.rb:79-84]` uses `find_by` + redirect. Either is fine; the bare `.find` is simpler and matches the WhatsApp-groups controller (the closer precedent).
- Error render: `render :new, status: :unprocessable_entity` and show `@divulgacao.errors[:base]` in a red box — verbatim pattern from `admin/artes/_form.html.erb:5-11` `[VERIFIED]` and `Admin::ArtesController#create` `[VERIFIED: app/controllers/admin/artes_controller.rb:23-31]`.

### Pattern 2: The two-table schema

```ruby
# db/migrate/XXXX_create_divulgacoes.rb
class CreateDivulgacoes < ActiveRecord::Migration[8.1]
  def change
    create_table :divulgacoes do |t|
      t.references :client, null: false, foreign_key: true
      t.references :arte,   null: false, foreign_key: true
      t.datetime  :scheduled_for, null: false
      t.integer   :status, null: false, default: 0   # agendada:0 em_andamento:1 concluida:2 cancelada:3
      t.timestamps
    end
    add_index :divulgacoes, [ :client_id, :scheduled_for ]
  end
end
```
```ruby
# db/migrate/XXXX_create_divulgacao_grupos.rb
class CreateDivulgacaoGrupos < ActiveRecord::Migration[8.1]
  def change
    create_table :divulgacao_grupos do |t|
      t.references :divulgacao,     null: false, foreign_key: true
      t.references :whatsapp_group, null: false, foreign_key: true
      t.integer   :status, null: false, default: 0   # pendente:0 enviado:1 falhou:2 incerto:3
      t.string    :group_name, null: false           # snapshot of whatsapp_group.display_name at create
      t.string    :remote_jid, null: false           # snapshot of whatsapp_group.remote_jid at create
      # nullable, staged for phase 29 (Claude's discretion — resolved: add now, no logic)
      t.datetime  :sent_at
      t.string    :error_code
      t.string    :evolution_message_id
      t.timestamps
    end
    add_index :divulgacao_grupos, [ :divulgacao_id, :whatsapp_group_id ], unique: true
  end
end
```

**Notes:**
- Table name `divulgacao_grupos` (no accent, snake_case) → model `DivulgacaoGrupo`. Rails' default inflection pluralizes `Divulgacao` → `divulgacaos`; **`divulgacoes` needs an inflection** OR `self.table_name = "divulgacoes"` on the model. Simplest: add to `config/initializers/inflections.rb` → `inflect.irregular "divulgacao", "divulgacoes"` and `inflect.irregular "divulgacao_grupo", "divulgacao_grupos"`. Verify `config/initializers/inflections.rb` exists (Rails default scaffold) — if not, create it. `[ASSUMED — inflections file not read this session]`
- `status` stored as `integer` (not PG enum) — matches every other enum in the repo (`Arte`, `WhatsappInstance` all use `t.integer` + `enum`). `[VERIFIED: db/schema.rb — artes.status integer, whatsapp_instances.connection_state integer]`
- FK `foreign_key: true` on both → `add_foreign_key` in schema, same as `whatsapp_groups`/`artes` `[VERIFIED: db/schema.rb:262,270]`.

### Pattern 3: `#create` — re-resolve every id through the scoped relation, snapshot at build time

```ruby
def create
  arte   = @client.artes.find(params.dig(:divulgacao, :arte_id))          # SEG-02: cross-client arte -> RecordNotFound
  gids   = Array(params.dig(:divulgacao, :whatsapp_group_ids)).map(&:to_i).uniq.reject(&:zero?)
  groups = scoped_active_groups.find(gids)                                # SEG-01: any foreign/inactive id -> RecordNotFound

  @divulgacao = @client.divulgacoes.new(
    arte:          arte,
    scheduled_for: params.dig(:divulgacao, :scheduled_for)                # DIVU-05: raw "2026-09-15T14:00" string, cast via Time.zone
  )
  groups.each do |g|
    @divulgacao.divulgacao_grupos.build(
      whatsapp_group: g,
      group_name:     g.display_name,     # DIVU-09 frozen snapshot
      remote_jid:     g.remote_jid        # DIVU-09 frozen snapshot
    )
  end

  if @divulgacao.save
    redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                notice: "Divulgação agendada."
  else
    load_form_collections   # @approved_artes etc.
    render :new, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordNotFound
  load_form_collections
  flash.now[:alert] = "Seleção inválida: uma arte ou um grupo escolhido não pertence a este cliente ou foi desativado. Revise e tente de novo."
  @divulgacao ||= @client.divulgacoes.new
  render :new, status: :unprocessable_entity
end

private

def scoped_active_groups
  @client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
end
```

**Key facts:**
- `check_box_tag "divulgacao[whatsapp_group_ids][]", group.id` produces `params[:divulgacao][:whatsapp_group_ids]` = **array of string ids**; `check_box_tag` emits **no** hidden companion field (unlike `f.check_box`), so **zero selection → the key is absent entirely** → `Array(params.dig(...))` = `[]`. `[VERIFIED: app/views/admin/whatsapp_groups/_group_row.html.erb:4-6]`
- Strong params: `params.require(:divulgacao).permit(:arte_id, :scheduled_for, whatsapp_group_ids: [])` — but `arte_id` and `whatsapp_group_ids` are re-resolved through scoped relations anyway, so permitting them is belt-and-suspenders.
- `relation.find([1,2,3])` raises `RecordNotFound` if **any** id is missing from the relation — exactly the SEG-01 semantics the CONTEXT locks ("um id de outro cliente ou de grupo inativo levanta `RecordNotFound`").
- Building associations then `save` runs everything in **one transaction**; a failed `validate` rolls back the parent and all children. `dependent: :destroy` on `has_many :divulgacao_grupos` is still correct for later deletes.

### Pattern 4: `datetime-local` → `Time.zone` round-trip (DIVU-05)

**What:** `f.datetime_field :scheduled_for` renders `<input type="datetime-local">`. The browser submits `"2026-09-15T14:00"` (no zone). Rails casts it correctly with **no special code**.

**Verified mechanics:**
- `config.load_defaults 8.1` `[VERIFIED: config/application.rb:14]` enables `config.active_record.time_zone_aware_attributes = true`. Assigning a String to a `:datetime` attribute routes through `ActiveRecord::AttributeMethods::TimeZoneConversion`, which parses **in `Time.zone`** (`config.time_zone = "Brasilia"` `[VERIFIED: config/application.rb:23]`).
- `config.active_record.default_timezone = :local` `[VERIFIED: config/application.rb:24]` → the value is **written to PG in local (Brasília) wall-clock**, not converted to UTC. Read back, it comes out as an `ActiveSupport::TimeWithZone` in `Time.zone`. Round-trip is lossless as long as the process `TZ` is `America/Sao_Paulo` — which `config/initializers/timezone_check.rb` enforces at boot (INFRA-03) and the test runner sets explicitly (`TZ=America/Sao_Paulo bin/rails test`).
- **Gotcha — never `Time.parse(params[...])`.** Ruby's stdlib `Time.parse` uses the system TZ and treats a zone-less string ambiguously. Either assign the raw string to the attribute (preferred — let AR cast it) or use `Time.zone.parse(...)`. The repo has **no** `Time.parse` misuse today (`Date.strptime` is used for month params `[VERIFIED: app/controllers/admin/calendar_controller.rb:25]`, which is fine — different case).
- **Display:** the stored value is already zone-aware on read. `I18n.l(divulgacao.scheduled_for, format: :long)` → `"terça-feira, 15 de Setembro de 2026, 14:00"` (pt-BR formats `[VERIFIED: config/locales/pt-BR.yml time.formats.long]`). CONTEXT wants an **explicit offset label** — append `" (BRT)"` or `" (America/São_Paulo)"` in `divulgacao_datetime_label`. `scheduled_for.strftime("%Z")` yields `"-03"` under `:local`; hardcoding `"(BRT)"` in the helper is clearer.
- `f.datetime_field` renders the existing value as `strftime("%Y-%m-%dT%H:%M:%S.%L")` — fine for the control; on validation re-render the user's input is preserved.

### Pattern 5: Custom validations — match the `Arte` style

`Arte` uses `validate :method_name` with private methods that call `errors.add(:base, "pt-BR sentence")` `[VERIFIED: app/models/arte.rb:44-45, 95-104]`. Match exactly:

```ruby
class Divulgacao < ApplicationRecord
  WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes   # ~16 MB — teto de mídia regular do WhatsApp (Assumption A1)

  belongs_to :client
  belongs_to :arte
  has_many   :divulgacao_grupos, dependent: :destroy
  accepts_nested_attributes_for :divulgacao_grupos   # optional; the controller builds them directly

  enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status
  #                                                                            ^^^^^^^^^^^^^^^^
  # prefix REQUIRED: divulgacao_grupos.status has :pendente/:enviado — without a prefix the
  # generated bang/predicate methods (agendada?, cancelada!) are fine, but keep prefix for
  # symmetry and to avoid a future collision if Divulgacao ever gets a :pendente-ish state.

  validates :scheduled_for, presence: true
  validate  :arte_deve_estar_aprovada
  validate  :arte_nao_usa_link_externo          # DIVU-03: rejeita SO external_url; caption_only IN escopo
  validate  :arquivo_dentro_do_teto_whatsapp
  validate  :arte_e_grupos_do_mesmo_cliente
  validate  :ao_menos_um_grupo

  def cancelar!
    return false unless status_agendada?
    update(status: :cancelada)
  end

  private

  def arte_deve_estar_aprovada
    return if arte.nil? || arte.approved?
    errors.add(:base, "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação.")
  end

  def arte_nao_usa_link_externo
    # DIVU-03 (CONTEXT resolvido): recusa SO quando ha link externo. NAO recusa por
    # ausencia de media_file — uma arte caption_only (sem arquivo, sem link, com caption)
    # e uma Divulgacao valida (fase 29 ENVIO-10 envia via sendText).
    return if arte.nil? || arte.external_url.blank?
    errors.add(:base, "Esta arte usa um link externo. Faca o upload do arquivo na arte antes de agendar a divulgacao.")
  end

  def arquivo_dentro_do_teto_whatsapp
    return if arte.nil? || !arte.media_file.attached?
    size = arte.media_file.blob.byte_size
    return if size <= WHATSAPP_MEDIA_MAX_BYTES
    errors.add(:base,
      "O arquivo tem #{ActiveSupport::NumberHelper.number_to_human_size(size)}, " \
      "acima do limite de #{ActiveSupport::NumberHelper.number_to_human_size(WHATSAPP_MEDIA_MAX_BYTES)} " \
      "que o WhatsApp aceita para mídia. Comprima ou reenvie um arquivo menor na arte.")
  end

  def arte_e_grupos_do_mesmo_cliente
    return if arte.nil?
    if arte.client_id != client_id
      errors.add(:base, "A arte e os grupos precisam ser do mesmo cliente.")
      return
    end
    foreign = divulgacao_grupos.reject { |dg| dg.whatsapp_group&.whatsapp_instance&.client_id == client_id }
    errors.add(:base, "Um ou mais grupos selecionados não pertencem a este cliente.") if foreign.any?
  end

  def ao_menos_um_grupo
    errors.add(:base, "Selecione ao menos um grupo para a divulgação.") if divulgacao_grupos.empty?
  end
end
```

- `number_to_human_size` gives "16 MB" / "23,4 MB" (pt-BR uses comma decimal under `:pt-BR` locale) — actionable message per CONTEXT "Specific Ideas".
- `arte.approved?` — `Arte` `enum :status` **without** prefix `[VERIFIED: app/models/arte.rb:28]`, so `approved?` is the generated predicate.

### Pattern 6: Reusing `_picker.html.erb` as a live form control (SEG-01)

**Exact locals contract** `[VERIFIED: app/views/admin/whatsapp_groups/_picker.html.erb:1-12]`:

| Local | Required? | Phase 27 (read-only) | Phase 28 (this phase) |
|-------|-----------|----------------------|------------------------|
| `client:` | **yes** | the client | `@client` |
| `selected_ids:` | no (default `[]`) | `[]` | `@divulgacao.divulgacao_grupos.map(&:whatsapp_group_id)` on re-render, else `[]` |
| `field_name:` | no (default `nil`) | `nil` → checkboxes `disabled`, no `name` | `"divulgacao[whatsapp_group_ids][]"` → live checkboxes with `name` |
| `groups:` | no | — | pass only if you need to page the picker (`@pagy` + a scoped page); otherwise the partial re-resolves **all** active groups itself |
| `pagy:` | no | — | pass `@pagy` only if also passing `groups:` |

- The partial **resolves its own option set**: `client.whatsapp_instance&.whatsapp_groups&.where(active: true)` — it never takes a foreign collection, never `WhatsappGroup.where/.find`. `[VERIFIED: _picker.html.erb:10-11]` This is the security invariant proven by phase 27's A×B test.
- Render call in `new.html.erb`:
  ```erb
  <%= render "admin/whatsapp_groups/picker",
        client:       @client,
        selected_ids: (@divulgacao.divulgacao_grupos.map(&:whatsapp_group_id) if @divulgacao.persisted? || @divulgacao.divulgacao_grupos.any?) || [],
        field_name:   "divulgacao[whatsapp_group_ids][]" %>
  ```
- When `field_name` is present the partial also renders a **select-all** checkbox (`data-picker-select-all`) and a **counter** (`data-picker-counter`, `"0 de N grupos selecionados"`) `[VERIFIED: _picker.html.erb:20-31]`. Phase 27 shipped these markers but **no Stimulus controller is wired to them** — phase 28's `divulgacao_estimate_controller.js` (or a `picker_controller.js`) must implement select-all + counter + estimate. Flag for the UI-SPEC.
- **Pagination caveat (known stub from 27-03):** the partial re-resolves ALL active groups when `groups:` is not passed; if a client has >25 groups and you *do* pass a paged `groups:`, checkboxes on other pages lose their state on navigation. For v1.7 the agency's clients are expected to have well under 25 groups — recommend **not paginating the picker in the form** (pass no `groups:`/`pagy:`), render all active groups. If large-group clients appear, the UI-SPEC decides (hidden inputs for off-page selections, or "load all when count is small"). CONTEXT §Deferred/27-03-SUMMARY flags this as a phase-28 decision.

### Pattern 7: The no-JS media + caption preview (DIVU-06)

**Verbatim precedent:** `app/views/client/artes/show.html.erb:26-48` `[VERIFIED]`.

```erb
<%# app/views/admin/divulgacoes/_preview.html.erb — locals: arte %>
<div class="rounded-lg border border-gray-200 bg-gray-50 p-4">
  <p class="text-xs font-medium text-slate-500 mb-2">Prévia — é exatamente isto que vai ao grupo</p>

  <% if arte.media_file.attached? %>
    <% if arte.media_file.image? %>
      <%= image_tag rails_storage_proxy_path(arte.media_file),
            class: "max-w-full max-h-[420px] object-contain mx-auto block rounded", alt: "Prévia da mídia" %>
    <% elsif arte.media_file.video? %>
      <video controls playsinline preload="metadata"
             class="max-w-full max-h-[420px] block mx-auto rounded">
        <source src="<%= rails_storage_proxy_path(arte.media_file) %>" type="<%= arte.media_file.content_type %>">
        Seu navegador não suporta reprodução de vídeo.
      </video>
    <% end %>
  <% elsif arte.caption_only? %>
    <%# see Open Question 1 — caption_only artes may be out of scope for phase 28 %>
  <% end %>

  <% if arte.caption.present? %>
    <div class="mt-3 pt-3 border-t border-gray-200">
      <p class="text-xs font-medium text-slate-500 mb-1">Legenda (enviada sem alteração):</p>
      <p class="text-sm text-slate-800 leading-relaxed whitespace-pre-wrap"><%= arte.caption %></p>
    </div>
  <% end %>
</div>
```

- `arte.media_file.image?` / `.video?` — ActiveStorage blob predicates (work off `content_type`); `Arte` also has `enum :media_type { image, video, caption_only }` `[VERIFIED: app/models/arte.rb:27]` — either works; the blob predicate is what `client/artes/show.html.erb` uses.
- `rails_storage_proxy_path` streams the blob through Rails (no presigned-URL expiry) — safe while the admin has the form open for minutes. The proxy route is always mounted; the client view already uses it `[VERIFIED]`.
- `whitespace-pre-wrap` on the caption preserves newlines exactly — "legenda exatamente como será enviada" (CONTEXT "Specific Ideas": no placeholder, no "[legenda]").
- **Video poster/variant (Claude's discretion, resolved):** use raw `<video controls preload="metadata">` — no poster. A poster frame needs ActiveStorage video `preview`, which requires the `ffmpeg` binary at runtime; not guaranteed present, and unnecessary for an admin preview. `preload="metadata"` shows the first frame in most browsers.

### Pattern 8: Duration estimate (DIVU-07) + the phase-29 delay env vars

**The estimate:** `n_grupos × ((min + max) / 2.0)` seconds, rendered as a human range. CONTEXT's own worked example is "≈ 8–14 min para 20 grupos" → that implies ~24–42 s per group.

**Proposed env var names (no repo precedent — phase 29 / ENVIO-02 owns the canonical read):**

| Env var | Fallback | Rationale |
|---------|----------|-----------|
| `WHATSAPP_SEND_DELAY_MIN_SECONDS` | `"30"` | Explicit `WHATSAPP_` prefix + `_SECONDS` suffix disambiguates from the `sendMedia` `delay` field (which is **milliseconds** and a "typing…" simulation, NOT inter-group pacing — `[CITED: .planning/research/STACK.md:203]`). Mirrors the `Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT", "30"))` idiom `[VERIFIED: app/services/evolution.rb:59]`. |
| `WHATSAPP_SEND_DELAY_MAX_SECONDS` | `"90"` | Anti-ban range "tens of seconds to low minutes per group". Fallback avg 60 s → "≈ 20 min para 20 grupos". |

- Alternative prefix `EVOLUTION_SEND_DELAY_*` (groups with the other `EVOLUTION_*` transport vars) or `DIVULGACAO_DELAY_*` (domain-accurate). Recommend `WHATSAPP_SEND_DELAY_*` — self-documenting, and the concept is "delay between WhatsApp sends", not Evolution HTTP config.
- **If the user wants the estimate copy to match CONTEXT's "8–14 min / 20 groups" example**, the fallbacks must be `25` / `45`. This is a real decision — flag it (Open Question 2). The range is in ENV precisely so it is tunable without a deploy; the fallback only matters when ENV is unset (dev, or a mis-provisioned prod).

**Phase 28's use is read-only:**
```ruby
# app/models/divulgacao.rb  (or a small PORO)
SEND_DELAY_MIN = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN_SECONDS", "30"))
SEND_DELAY_MAX = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MAX_SECONDS", "90"))
```
```ruby
# app/helpers/admin/divulgacoes_helper.rb
def divulgacao_duration_estimate(n_groups, min: Divulgacao::SEND_DELAY_MIN, max: Divulgacao::SEND_DELAY_MAX)
  return "—" if n_groups.to_i.zero?
  lo = (n_groups * min / 60.0).ceil
  hi = (n_groups * max / 60.0).ceil
  lo == hi ? "≈ #{lo} min para #{n_groups} grupos" : "≈ #{lo}–#{hi} min para #{n_groups} grupos"
end
```
- CONTEXT says "se ausentes no ambiente, usa defaults documentados e **sinaliza que é estimativa**" — when the ENV vars are unset, append " (estimativa)" or a tooltip. Simplest: always label it "Estimativa de duração" and the fallback is transparent.
- **Client-side recompute (per UI-SPEC):** put `data-divulgacao-estimate-min-value="30" data-divulgacao-estimate-max-value="90"` on the picker container; the Stimulus controller counts checked `input[type=checkbox]` on `change` and rewrites the estimate text. Server re-render (via `divulgacao_duration_estimate`) is the no-JS fallback and the source of truth on the `show` page.
- **Add `.env.example` entries** for both vars (the repo keeps `.env.example` current — `[VERIFIED: .env.example]` has `EVOLUTION_*_TIMEOUT` with defaults noted).

### Anti-Patterns to Avoid

- **`Arte.find(params[...])` / `WhatsappGroup.find(...)` anywhere in this controller.** Always `@client.artes.find` / `@client.whatsapp_instance.whatsapp_groups.where(active: true).find`. A bare finder is the cross-client leak shape (phase 27 PITFALLS).
- **`Time.parse(params[:divulgacao][:scheduled_for])`.** Assign the raw string to the AR attribute (time-zone-aware cast) or use `Time.zone.parse`.
- **`insert_all` / `upsert_all` for `divulgacao_grupos`.** Build associations. If forced to `insert_all` for scale: run after `divulgacao.save!`, pass `divulgacao_id`, **omit `created_at`/`updated_at` from the row hash** (Rails 8.1 auto-injects; a duplicate assignment → PG `multiple assignments to same column`), `unique_by: %i[divulgacao_id whatsapp_group_id]`, and separately enforce the `belongs_to` presence the bulk path skips.
- **`dependent: :destroy` on `Arte has_many :divulgacoes`.** An arte deleted after a divulgação exists should NOT silently cascade-delete send history. Use plain `has_many :divulgacoes` and let the FK (`null: false`, no `on_delete: :cascade`) block the arte delete, or add `dependent: :restrict_with_error`. `Arte#destroy` is already gated to `pending? && approval_responses.none?` `[VERIFIED: app/controllers/admin/artes_controller.rb:92-96]` so this is mostly theoretical, but be explicit.
- **Rendering the preview media with a variant that needs `ffmpeg`.** Raw `<video>` only.
- **Persisting the delay range in the DB or exposing it in the UI.** ENV only (ENVIO-02, and `.planning/REQUIREMENTS.md:123` Out of Scope: "UI de configuração da faixa de delay").
- **A `destroy` action / route for `Divulgacao`.** Cancel = `status: :cancelada`, record preserved (CONTEXT).
- **Any `Evolution::Client` call, any job enqueue, any `sendText`/`sendMedia`.** All phase 29. If it talks to the WhatsApp host, it does not belong in phase 28.

---

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Per-client authorization on arte/groups | A Pundit policy / manual `if arte.client_id == @client.id` | `@client.artes.find(id)` / `@client.whatsapp_instance.whatsapp_groups.where(active: true).find(ids)` → `RecordNotFound` | The project's established pattern (`client/artes_controller.rb:10`); foreign id = 404 / re-render, zero existence leak, no extra code. Phase 27 proved it with an A×B test. |
| Parse a `datetime-local` param into São Paulo time | `Time.parse` + manual `.in_time_zone` juggling | Assign the raw string to the `:datetime` attribute — AR casts through `Time.zone` | Time-zone-aware attributes are on by default (`load_defaults 8.1`). Manual parsing reintroduces the ambiguity INFRA-03 exists to prevent. |
| Bulk-create N child rows | `insert_all` + timestamp/uniqueness bookkeeping | `parent.children.build(...)` in one `parent.save` transaction | N is tens; atomic rollback on validation failure; `belongs_to` presence + uniqueness validations run; no Rails-8.1 timestamp gotcha. |
| The group picker + scope enforcement | A fresh `<select multiple>` / checkbox list querying `WhatsappGroup` | `render "admin/whatsapp_groups/picker", client:, field_name:, selected_ids:` | Built in phase 27 *for this phase*; resolves its own scoped option set; select-all + counter markup already present. |
| Media/caption preview | A JS lightbox / client-side blob fetch | Server-rendered `image_tag rails_storage_proxy_path` / `<video><source>` | Verbatim precedent in `client/artes/show.html.erb`; no JS, no XSS surface, works with a private bucket. |
| Human file-size string in the error message | `"#{bytes / 1_048_576} MB"` | `ActiveSupport::NumberHelper.number_to_human_size(bytes)` | Locale-aware (pt-BR comma decimals), handles KB/MB/GB boundaries. |
| pt-BR datetime label | `strftime` scattered in ERB | `I18n.l(t, format: :long)` + a helper that appends "(BRT)" | The repo centralises time formatting in `config/locales/pt-BR.yml` and helper methods (`wa_groups_synced_label` precedent). |

**Key insight:** Every hard part of this phase already has a paved path in the repo. The only genuinely new decisions are two constant *values* (`WHATSAPP_MEDIA_MAX_BYTES`, the delay-range fallbacks) and one small Stimulus controller — none of which touch the send path.

---

## Runtime State Inventory

Phase 28 is **greenfield-additive** — two new tables, two new models, a new controller, new views. No rename, no rebrand, no data migration of existing values. The five categories, answered explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `divulgacoes` / `divulgacao_grupos` are created empty. No existing table gains columns. Nothing existing keys on these. `Client` / `Arte` / `WhatsappGroup` gain only `has_many` associations (no schema change). | None. |
| Live service config | None — no job registered, no `config/recurring.yml` touched, no webhook change, no Evolution call. The cancel action is a local `UPDATE`. | None. |
| OS-registered state | None. | None. |
| Secrets / env vars | **New (read-only, optional):** `WHATSAPP_SEND_DELAY_MIN_SECONDS` / `WHATSAPP_SEND_DELAY_MAX_SECONDS` — proposed here, consumed by a helper with documented fallbacks; phase 29 owns the canonical read. Add both to `.env.example`. No secret — plain integers. `WHATSAPP_MEDIA_MAX_BYTES` is a code constant, not an env var. | Add 2 lines to `.env.example`. Provision in prod compose when phase 29 lands (not blocking phase 28). |
| Build artifacts | None — no gem added, no generator output beyond migrations + hand-written files. `db/schema.rb` regenerates on migrate (expected diff: 2 new tables). | Run migrations; commit the `db/schema.rb` diff. |

**Nothing found in "Stored data", "Live service config", "OS-registered state", "Build artifacts" — verified by reading `config/routes.rb`, `config/recurring.yml` (via phase-27 research), `db/schema.rb`, `app/models/{client,arte,whatsapp_group,whatsapp_instance}.rb`, and `.env.example` this session.**

---

## Common Pitfalls

### Pitfall 1: `Divulgacao` pluralization / table name
**What goes wrong:** `Divulgacao.all` → `PG::UndefinedTable: relation "divulgacaos" does not exist`. Rails' default inflector pluralizes `divulgacao` → `divulgacaos`.
**Why it happens:** No English rule for Portuguese `-ção` → `-ções`.
**How to avoid:** Add to `config/initializers/inflections.rb`:
```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "divulgacao", "divulgacoes"
  inflect.irregular "divulgacao_grupo", "divulgacao_grupos"
end
```
OR set `self.table_name = "divulgacoes"` on the model (and name the migration table `divulgacoes` explicitly). The inflection is cleaner because it also fixes route helpers, `dom_id`, and `divulgacao_grupos` association names. **Verify whether `config/initializers/inflections.rb` already exists** (Rails scaffold default; not read this session — `[ASSUMED]`).
**Warning signs:** `UndefinedTable` on first query; `divulgacao_path` helper missing; `form_with model: @divulgacao` posts to the wrong URL.

### Pitfall 2: The two `status` enums collide
**What goes wrong:** `Divulgacao` and `DivulgacaoGrupo` both define `enum :status`. On a model that `has_many` the other, unprefixed predicate/bang methods (`pendente?`, `enviado!`) are ambiguous to a reader and a future `Divulgacao` state named similarly would clash.
**Why it happens:** Both enums are named `status` per the locked CONTEXT vocabulary.
**How to avoid:** `enum :status, {...}, prefix: :status` on `Divulgacao` → `status_agendada?`, `status_cancelada!`. Leave `DivulgacaoGrupo` unprefixed (its `pendente?`/`enviado?` are the DIVU-09 vocabulary the phase-30 UI renders). Confirm the exact strings: `divulgacao_grupos.status` = `pendente / enviado / falhou / incerto` **verbatim** (CONTEXT "Specific Ideas" — phase 30 renders these labels).
**Warning signs:** `ArgumentError: You tried to define an enum named "status" ... already defined` (only if on the same model); confusing test failures where `dg.pendente?` and `d.status` disagree.

### Pitfall 3: Group deactivated between form-load and submit → whole form lost
**What goes wrong:** Admin opens `new`, a `SyncGroupsJob` (phase 27) marks one selected group `active: false`, admin submits → `scoped_active_groups.find(gids)` raises `RecordNotFound` → the entire form is rejected, and a naive handler shows a bare 404.
**Why it happens:** The locked SEG-01 rule is `.where(active: true).find(id)` — strict by design. Group activity is mutable (phase-27 sync).
**How to avoid:** `rescue ActiveRecord::RecordNotFound` in `#create` → re-render `:new` with an actionable flash ("uma arte ou grupo selecionado não pertence a este cliente ou foi desativado — revise a seleção") and `status: :unprocessable_entity`. Do **not** let it 404. (§Pattern 3 skeleton.)
**Warning signs:** Sporadic 404s on divulgação create in a client with active group syncs; UAT.

### Pitfall 4: `check_box_tag` has no hidden companion → zero-selection is silent
**What goes wrong:** Admin submits with no groups checked; `params[:divulgacao][:whatsapp_group_ids]` is **absent** (not `[]`); `params.dig(...)` → `nil`; `nil.map` → `NoMethodError`.
**Why it happens:** `check_box_tag` (used by `_group_row.html.erb`) — unlike `f.check_box` — emits no `<input type="hidden" value="">`. `[VERIFIED: app/views/admin/whatsapp_groups/_group_row.html.erb:4]`
**How to avoid:** `Array(params.dig(:divulgacao, :whatsapp_group_ids))` everywhere; `validate :ao_menos_um_grupo` gives the user a clean "selecione ao menos um grupo".
**Warning signs:** 500 on submit-with-nothing-selected; missing "select a group" validation message.

### Pitfall 5: Timezone display drift
**What goes wrong:** `scheduled_for` shows `13:00` when the admin entered `14:00`, or shows a `+00:00` offset.
**Why it happens:** (a) reading the column with `Time.parse`/`.utc` in a helper; (b) the process `TZ` is not `America/Sao_Paulo` (a dev without `.env`); (c) using `created_at.strftime` habits on a value that's fine but labeling it wrong.
**How to avoid:** Never transform `scheduled_for` on read — it's already `ActiveSupport::TimeWithZone` in `Time.zone`. Format via `I18n.l(scheduled_for, format: :long)` and append a **literal** `"(BRT)"`. Trust `config/initializers/timezone_check.rb` (INFRA-03) to enforce the process TZ; run tests with `TZ=America/Sao_Paulo` (the documented invocation).
**Warning signs:** Off-by-3-hours in the `show` view; `%Z` printing `UTC`; a test that passes locally and fails in CI (different `TZ`).

### Pitfall 6: `arte_id` scoped in the controller but not re-checked in the model
**What goes wrong:** A crafted POST with `divulgacao[arte_id]` of another client's approved arte + this client's groups. If the controller ever loosens `@client.artes.find` to `Arte.find`, SEG-02 breaks with no test catching it.
**Why it happens:** Single-layer enforcement.
**How to avoid:** Keep BOTH: `@client.artes.find` in `#create` AND `validate :arte_e_grupos_do_mesmo_cliente` (`arte.client_id == client_id`) in the model. The model validation is the regression net. Write the A×B test both directions (arte A + groups B via client A's URL; arte B via client A's URL).
**Warning signs:** A refactor that "simplifies" the finder; the A×B test only covering one direction.

### Pitfall 7: `has_many :divulgacoes` cascade on `Arte` / `WhatsappGroup`
**What goes wrong:** Adding `dependent: :destroy` on `Arte has_many :divulgacoes` (or `WhatsappGroup has_many :divulgacao_grupos`) means deleting an arte/group silently erases send history — the exact opposite of DIVU-09's "preserve the frozen name".
**Why it happens:** Reflexive copy of the `Client has_many :artes, dependent: :destroy` pattern.
**How to avoid:** `Arte has_many :divulgacoes` with **no** `dependent:` (or `:restrict_with_error`). `WhatsappGroup has_many :divulgacao_grupos` with no `dependent:` — a group that vanishes is deactivated (phase 27), never deleted, and the `divulgacao_grupos` row keeps the `group_name`/`remote_jid` snapshot regardless. `Client has_many :divulgacoes, dependent: :destroy` is fine (deleting a client is already a heavy, gated action).
**Warning signs:** `dependent: :destroy` on any association pointing at `divulgacoes`/`divulgacao_grupos` from `Arte` or `WhatsappGroup`.

### Pitfall 8: `scheduled_for` in the past
**What goes wrong:** Admin schedules for yesterday; phase 29's engine fires it immediately (or never, depending on the scheduler). No validation catches it in phase 28.
**Why it happens:** CONTEXT locks the datetime input but doesn't mention a future-only constraint.
**How to avoid:** Recommend `validate :scheduled_for_no_futuro` → `errors.add(:base, "A data e hora do envio precisam estar no futuro.") if scheduled_for.present? && scheduled_for <= Time.current`. This is a small guard with clear value; flag it as a discretion call for the planner (Open Question 3) since it's not in the locked list.
**Warning signs:** A divulgação created with `scheduled_for < now`; phase-29 behavior undefined for past schedules.

### Pitfall 9: `insert_all`/`upsert_all` skipping validations (confirm)
**What goes wrong:** If a future refactor switches `divulgacao_grupos` creation to `insert_all`, the `validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }` and `belongs_to` presence are silently skipped.
**Why it happens:** `insert_all`/`upsert_all` run no validations, no callbacks (documented Rails behavior; phase 27 hit this).
**How to avoid:** For phase 28, **build associations** (validations run, single transaction). The unique **index** `[divulgacao_id, whatsapp_group_id]` is the DB-level backstop either way — a duplicate raises `ActiveRecord::RecordNotUnique`. `params[...].uniq` in the controller prevents the common cause (double-submitted checkbox). Confirmed: the per-group rows have no *other* validations that matter at insert time (`status` has a DB default, `group_name`/`remote_jid` are set by the builder).
**Warning signs:** `RecordNotUnique` on create; a switch to `insert_all` without adding the uniqueness guard elsewhere.

---

## Code Examples

### 1. Routes `[VERIFIED: config/routes.rb:9-25]`

```ruby
# config/routes.rb — inside namespace :admin { resources :clients do ... end }
resources :divulgacoes, only: [ :index, :new, :create, :show ] do
  member { patch :cancel }
end
```

### 2. Models

```ruby
# app/models/divulgacao.rb  — see §Pattern 5 for the full validations block
class Divulgacao < ApplicationRecord
  WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes
  SEND_DELAY_MIN = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MIN_SECONDS", "30"))
  SEND_DELAY_MAX = Integer(ENV.fetch("WHATSAPP_SEND_DELAY_MAX_SECONDS", "90"))

  belongs_to :client
  belongs_to :arte
  has_many   :divulgacao_grupos, dependent: :destroy

  enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status

  validates :scheduled_for, presence: true
  validate  :arte_deve_estar_aprovada
  validate  :arte_nao_usa_link_externo          # DIVU-03: rejeita SO external_url; caption_only IN escopo
  validate  :arquivo_dentro_do_teto_whatsapp
  validate  :arte_e_grupos_do_mesmo_cliente
  validate  :ao_menos_um_grupo
  validate  :scheduled_for_no_futuro            # RESOLVIDO: futuro-only (28-CONTEXT.md)

  def cancelar! = status_agendada? && update(status: :cancelada)
  # ... private validate methods (§Pattern 5)
end
```
```ruby
# app/models/divulgacao_grupo.rb
class DivulgacaoGrupo < ApplicationRecord
  belongs_to :divulgacao
  belongs_to :whatsapp_group

  # Vocabulário verbatim do DIVU-09 — a fase 30 renderiza estes rótulos.
  enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }

  validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }
  validates :group_name, :remote_jid, presence: true
end
```
```ruby
# app/models/client.rb — add
has_many :divulgacoes, dependent: :destroy

# app/models/arte.rb — add (NO dependent: — Pitfall 7)
has_many :divulgacoes

# app/models/whatsapp_group.rb — add (NO dependent: — Pitfall 7)
has_many :divulgacao_grupos
```

### 3. Controller `[pattern from app/controllers/admin/artes_controller.rb + admin/whatsapp_groups_controller.rb]`

```ruby
class Admin::DivulgacoesController < Admin::BaseController
  before_action :set_client
  before_action :set_divulgacao, only: [ :show, :cancel ]

  def index
    @pagy, @divulgacoes = pagy(
      @client.divulgacoes.includes(:arte).order(scheduled_for: :desc), limit: 25
    )
  end

  def new
    @divulgacao = @client.divulgacoes.new
    load_form_collections
  end

  def create
    arte   = @client.artes.find(params.dig(:divulgacao, :arte_id))
    gids   = Array(params.dig(:divulgacao, :whatsapp_group_ids)).map(&:to_i).uniq.reject(&:zero?)
    groups = scoped_active_groups.find(gids)

    @divulgacao = @client.divulgacoes.new(
      arte: arte, scheduled_for: params.dig(:divulgacao, :scheduled_for)
    )
    groups.each do |g|
      @divulgacao.divulgacao_grupos.build(
        whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid
      )
    end

    if @divulgacao.save
      redirect_to admin_client_divulgacao_path(@client, @divulgacao), notice: "Divulgação agendada."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    @divulgacao ||= @client.divulgacoes.new
    load_form_collections
    flash.now[:alert] = "Seleção inválida: a arte ou um grupo escolhido não pertence a este cliente ou foi desativado."
    render :new, status: :unprocessable_entity
  end

  def show; end

  def cancel
    if @divulgacao.cancelar!
      redirect_to admin_client_divulgacao_path(@client, @divulgacao), notice: "Divulgação cancelada."
    else
      redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                  alert: "Só é possível cancelar uma divulgação ainda agendada."
    end
  end

  private

  def set_client     = @client = Client.find(params[:client_id])
  def set_divulgacao = @divulgacao = @client.divulgacoes.find(params[:id])

  def scoped_active_groups
    @client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
  end

  def load_form_collections
    @approved_artes = @client.artes.approved.order(scheduled_on: :desc)
  end
end
```

### 4. `new.html.erb` skeleton (single page)

```erb
<% content_for(:page_title) { "Nova divulgação — #{@client.name}" } %>
<%= link_to "← #{@client.name}", admin_client_path(@client), class: "text-sm text-slate-600 hover:text-slate-900" %>

<div class="bg-white rounded-xl border border-gray-200 shadow-card p-8 max-w-2xl mt-4">
  <%= form_with model: [@client, @divulgacao], html: { data: { controller: "divulgacao-estimate" } } do |f| %>
    <% if @divulgacao.errors[:base].any? %>
      <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
        <% @divulgacao.errors[:base].each { |m| %><p><%= m %></p><% } %>
      </div>
    <% end %>

    <div class="mb-4">
      <%= f.label :arte_id, "Arte aprovada", class: "block text-sm font-medium text-slate-900 mb-1.5" %>
      <%= f.collection_select :arte_id, @approved_artes, :id,
            ->(a) { "#{a.title.presence || 'Arte'} — #{l(a.scheduled_on)}" },
            { prompt: "Selecione uma arte aprovada" }, class: "..." %>
    </div>

    <div class="mb-4">
      <span class="block text-sm font-medium text-slate-900 mb-1.5">Grupos</span>
      <%= render "admin/whatsapp_groups/picker",
            client: @client, selected_ids: [], field_name: "divulgacao[whatsapp_group_ids][]" %>
    </div>

    <div class="mb-4">
      <%= f.label :scheduled_for, "Data e hora do envio (America/São_Paulo)", class: "..." %>
      <%= f.datetime_field :scheduled_for, class: "..." %>
    </div>

    <div class="mb-4" data-divulgacao-estimate-target="output"
         data-divulgacao-estimate-min-value="<%= Divulgacao::SEND_DELAY_MIN %>"
         data-divulgacao-estimate-max-value="<%= Divulgacao::SEND_DELAY_MAX %>">
      Estimativa de duração: <span data-divulgacao-estimate-target="text">—</span>
    </div>

    <%= render "preview", arte: @approved_artes.first %> <%# swapped client-side or shown on re-render %>

    <%= f.submit "Agendar divulgação", data: { turbo_submits_with: "Agendando…" }, class: "..." %>
  <% end %>
</div>
```

### 5. Entry point on `admin/clients/show.html.erb` `[VERIFIED: app/views/admin/clients/show.html.erb — "Artes" card pattern]`

```erb
<%# after the WhatsApp panel render, before or after the Artes card %>
<div class="bg-white rounded-xl border border-gray-200 shadow-card p-6 max-w-2xl mt-4">
  <div class="flex items-center justify-between border-b border-gray-100 pb-3 mb-4">
    <h2 class="text-sm font-semibold text-slate-900">Divulgações</h2>
    <%= link_to "Nova divulgação", new_admin_client_divulgacao_path(@client),
          class: "inline-flex items-center h-8 px-3 bg-[#0F7949] hover:bg-green-800 text-white text-xs font-medium rounded-lg transition-colors" %>
  </div>
  <% if @divulgacoes.blank? %>
    <p class="text-sm text-slate-500">Nenhuma divulgação agendada.</p>
  <% else %>
    <%# list: arte title, divulgacao_datetime_label(d.scheduled_for), status badge, "Ver" link %>
  <% end %>
</div>
```
(Requires `@divulgacoes = @client.divulgacoes.includes(:arte).order(scheduled_for: :desc)` in `Admin::ClientsController#show` — verify that controller; not read this session `[ASSUMED]`.)

### 6. Cancel button on `show.html.erb`

```erb
<%= button_to "Cancelar divulgação", cancel_admin_client_divulgacao_path(@client, @divulgacao),
      method: :patch,
      data: { turbo_confirm: "Cancelar esta divulgação? Ela não será enviada. O registro e o histórico por grupo são mantidos." },
      class: "inline-flex items-center h-9 px-3 bg-[#EE3537] hover:bg-red-700 text-white text-sm font-medium rounded-lg transition-colors cursor-pointer" %>
```
(`turbo_confirm` is the established pattern for destructive/dangerous actions — CONTEXT "Established Patterns"; `_panel.html.erb` uses confirm modals, `admin/artes` uses `turbo_confirm` per v1.3+ notes.)

### 7. Duration Stimulus controller

```js
// app/javascript/controllers/divulgacao_estimate_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "text"]
  static values  = { min: Number, max: Number }

  connect() { this.recompute() }

  // wire from the form: data-action="change->divulgacao-estimate#recompute" on the picker container
  recompute() {
    const n = this.element.querySelectorAll('input[type="checkbox"][name="divulgacao[whatsapp_group_ids][]"]:checked').length
    if (!n) { this.textTarget.textContent = "—"; return }
    const lo = Math.ceil(n * this.minValue / 60)
    const hi = Math.ceil(n * this.maxValue / 60)
    this.textTarget.textContent = lo === hi ? `≈ ${lo} min para ${n} grupos` : `≈ ${lo}–${hi} min para ${n} grupos`
  }
}
```

### 8. Migrations — see §Pattern 2 (verbatim).

---

## State of the Art

| Old approach | Current approach | When changed | Impact here |
|--------------|------------------|--------------|-------------|
| `insert_all`/`upsert_all` did not set `created_at`/`updated_at` | Rails auto-manages timestamps for bulk insert (governed by `record_timestamps`) | Rails 7.0 (rails/rails PR #43003), still true in 8.1 | Only relevant if the planner ignores the "build associations" recommendation. Then: omit timestamps from the row hash. `[CITED: rails/rails#43003]` |
| Manual `.in_time_zone` on datetime params | Time-zone-aware attributes cast String → `Time.zone` on assignment | Default since Rails 5 `load_defaults`; explicit here via `load_defaults 8.1` | `divulgacao.scheduled_for = params_string` "just works" in Brasília time. No parsing code. `[VERIFIED: config/application.rb:14,23-24]` |
| WhatsApp regular media ceiling folklore (5 MB image / 16 MB video / 100 MB doc from the Cloud API) | Convergent practical ceiling for regular (non-document) image+video through web/Baileys gateways is **~16 MB**; documents up to 2 GB (not applicable — Arte only accepts jpeg/png/gif + mp4/mov) | ongoing | `WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` as a single conservative ceiling for both image and video. **This gateway not measured** — phase-29 UAT probe (5/15/20/30 MB) codifies the real number. `[CITED: filesize.org/limits/whatsapp; .planning/research/SUMMARY.md:139; evolution-contract.md:56]` |
| `sendMedia` `delay` param assumed to pace sends | `delay` is a pre-send "typing…" simulation in **milliseconds** that blocks the one HTTP request — NOT inter-group pacing | verified at Evolution tag 2.3.7 | The DIVU-07 estimate must use the Rails-side inter-group delay range (`WHATSAPP_SEND_DELAY_*`), never the `sendMedia` `delay`. `[CITED: .planning/research/STACK.md:203; PITFALLS.md:470]` |

**Deprecated / not used:**
- ActiveStorage video `preview` (poster frame) — needs `ffmpeg` at runtime; not used, raw `<video>` instead.
- Image variants for the preview — available (`image_processing` 1.14.0) but unnecessary; full blob + CSS constraint.
- PG native enum types — the repo uses `integer` columns + Rails `enum` everywhere; stay consistent.

---

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes` (16 777 216) is a correct conservative ceiling for image **and** video through this Evolution 2.3.7 + Cloudflare gateway. | DIVU-04, §Pattern 5, §State of the Art | If the real ceiling is lower (e.g. 5 MB for images) some over-limit images pass phase-28 validation and fail at phase-29 `sendMedia`. If higher, some valid files are rejected early (annoying, not dangerous). Repo research says "measure in UAT, don't copy from a blog" (`SUMMARY.md:206`, `evolution-contract.md:56`). **Phase-29 UAT** probes 5/15/20/30 MB and codifies the measured value. Until then, 16 MB is the safe default and the error message tells the admin what to do. |
| A2 | Phase 29 will read the inter-group delay from env vars named `WHATSAPP_SEND_DELAY_MIN_SECONDS` / `WHATSAPP_SEND_DELAY_MAX_SECONDS`, seconds, integer. | DIVU-07, §Pattern 8 | Names are proposed here with **no repo precedent** (`ENVIO-02` is phase 29, not yet planned). If phase 29 picks different names, phase 28's helper + `.env.example` entries + any UI copy need a one-line rename. Mitigation: keep the read in ONE place (`Divulgacao::SEND_DELAY_MIN/MAX`) so the rename is trivial. Recommend the planner note this as a cross-phase contract for phase 29 to honor. |
| A3 | Fallback delay defaults `30` / `90` seconds are acceptable "anti-ban" values for the estimate when ENV is unset. | §Pattern 8 | The fallback only affects the *estimate shown* when ENV is missing (dev, or mis-provisioned prod). CONTEXT's own example ("8–14 min / 20 groups") implies `~25` / `~45`. If the user wants the copy to match that example, use those. This is a user decision (Open Question 2). |
| A4 | `config/initializers/inflections.rb` exists (Rails scaffold default) or can be created to add the `divulgacao`/`divulgacoes` irregular. | Pitfall 1, §Pattern 2 | Not read this session. If absent, create it — trivial. Alternative: `self.table_name = "divulgacoes"` on the model. Either way the planner must include this step or the first query 500s. |
| A5 | `Admin::ClientsController#show` can be extended to load `@divulgacoes` for the entry-point section (or the section links out without preloading). | §Code Examples 5 | `admin/clients_controller.rb` not read this session. Low risk — worst case the entry point is a bare link to `admin_client_divulgacoes_path` and the list lives only on `#index`. |
| A6 | RESOLVIDO — `caption_only` artes SAO aceitas. `arte_nao_usa_link_externo` recusa so `external_url`; `arquivo_dentro_do_teto_whatsapp` ja `return`s quando nao ha arquivo. Arte picker = `@client.artes.approved` (todas, sem carve-out). | DIVU-03, Open Question 1 | Resolvido em 28-CONTEXT.md "Perguntas em aberto da pesquisa — RESOLVIDAS"; fase 29 ENVIO-10 envia caption_only via sendText. |
| A7 | The test DB is reachable via `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test` (unix socket, peer auth, no password), and `bin/rails test` genuinely runs — contradicting the older `MEMORY/test_db_permission.md` note whose root cause was the missing host var (per `27-01-SUMMARY.md`). | §Test Strategy | If the socket path differs on this machine, tests can't run in-session and fall back to inspection + `bin/rails runner` (phases 25/26 precedent). Not a build blocker. |

**Anything not in this table is `[VERIFIED: …]` from a file read this session or `[CITED: …]` from the source referenced inline.**

---

## Open Questions (TODAS RESOLVIDAS em 28-CONTEXT.md § "Perguntas em aberto da pesquisa — RESOLVIDAS")

> As 5 perguntas abaixo foram resolvidas na fase de contexto. Resolucoes: (1) caption_only IN escopo — recusa so external_url; (2) delay fallback 25/45s; (3) scheduled_for futuro-only; (4) index = pagina propria + secao espelho no clients#show; (5) cancelamento = member action `patch :cancel`. Os planos implementam essas resolucoes. O texto original fica abaixo para rastreabilidade.

1. **Are `caption_only` (text-only) artes in scope for a Divulgação in v1.7?**
   - What we know: CONTEXT locks DIVU-03 as "recusa se `!arte.media_file.attached?`" — which rejects every `caption_only` arte (`Arte enum :media_type { …, caption_only }`, no file). ENVIO-10 (phase 29) explicitly handles "arte só de texto vai como mensagem de texto" via `sendText`.
   - What's unclear: whether the CONTEXT rule is deliberately excluding text-only divulgações from v1.7, or whether it's shorthand for "block external links" and text-only should be allowed.
   - Recommendation: **Ask the user.** If text-only is in scope: arte picker = `@client.artes.approved` (all), and `arte_tem_arquivo_anexado` becomes `return if arte.caption_only?` before the file check; the ceiling check already `return`s when no file is attached. If out of scope: arte picker = `@client.artes.approved.where.not(media_type: :caption_only)` and keep the validation strict. Default to the strict reading (matches CONTEXT verbatim) and flag for discuss-phase.

2. **Delay-range fallback defaults: match CONTEXT's "8–14 min / 20 groups" example (`25`/`45`), or use anti-ban-conservative (`30`/`90`)?**
   - What we know: the range lives in ENV (ENVIO-02); the fallback only matters when ENV is unset. CONTEXT's worked example implies ~24–42 s/group.
   - Recommendation: use `25` / `45` so the estimate the user already blessed in CONTEXT stays consistent when ENV is absent; document that production should set the real range. Confirm with the user — it's a one-line change.

3. **Should `scheduled_for` be validated as future-only?**
   - What we know: CONTEXT locks the input but not a future constraint. Phase-29 behavior for a past `scheduled_for` is undefined.
   - Recommendation: add `validate :scheduled_for_no_futuro` (`> Time.current`) with a clear pt-BR message. Cheap, prevents a class of phase-29 surprises. Flag as a planner discretion call.

4. **`divulgacoes#index`: standalone nested page, or only a section on `clients#show`?** (CONTEXT Claude's discretion.)
   - Recommendation: build the standalone nested `index` (route is already in the locked `only: […]` list) AND a compact "Divulgações" section on `clients#show` that links to it — mirrors how the "Artes" card on `clients#show` links to the arte flow. Consistent, low cost.

5. **Cancel: dedicated `cancel` action or `update`?** (CONTEXT Claude's discretion.)
   - Recommendation: `patch :cancel, on: :member` + `Admin::DivulgacoesController#cancel` calling `divulgacao.cancelar!` (guarded to `status_agendada?`). Keeps the transition explicit and testable; `update` isn't in the locked route set.

---

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| PostgreSQL | `divulgacoes` / `divulgacao_grupos` tables, unique index, FK | ✓ | adapter `postgresql` `[VERIFIED: config/database.yml]` | none needed |
| ActiveStorage + a reachable blob store | `arte.media_file.blob.byte_size` (ceiling check), `rails_storage_proxy_path` (preview) | ✓ | S3/MinIO configured (INFRA-01 complete, `config/storage.yml`); `test` uses Disk | test env uses `service: Disk` `[VERIFIED: config/storage.yml]` — preview + byte_size work with a local fixture file |
| `image_processing` / `mini_magick` / `ruby-vips` | **Not required** (no variant in the preview) | ✓ | 1.14.0 / 5.3.1 / 2.3.0 `[VERIFIED: Gemfile.lock]` | n/a |
| `ffmpeg` binary | **Not required** (raw `<video>`, no poster) | unknown | — | n/a — do not use video `preview` |
| Stimulus | `divulgacao_estimate_controller.js` | ✓ | stimulus-rails 1.3.4 `[VERIFIED: Gemfile.lock]` | server re-render of the estimate is the no-JS fallback |
| Test DB (`bin/rails test`) | Running the phase's model + controller + integration tests | ✓ via `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test` (proven in phase 27) | — | inspection + `bin/rails runner` with fixtures built inline (phases 25/26 precedent) if the socket path differs |
| `test/fixtures/files/sample.jpg` | attaching media in tests | ✓ (22 bytes) `[VERIFIED: test/fixtures/files/sample.jpg]` | — | for the >16 MB ceiling test: `blob.update_column(:byte_size, 20.megabytes)` after attach, or test the `validate` method directly |
| Evolution API host / paired instance | **NOT used in phase 28** | n/a | n/a | n/a — any dependency on it means the code belongs in phase 29 |

**Missing dependencies with no fallback:** none. Phase 28 is DB + Rails + view code only.
**Missing dependencies with fallback:** test DB socket path (→ inspection + runner); `ffmpeg` (→ not used).

---

## Test Strategy

> `workflow.nyquist_validation` is **false** for this run — this section is advisory, not a Validation Architecture contract. Framework: Rails built-in **Minitest** + `ActionDispatch::IntegrationTest`. Run: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test`.

### Fixtures / factories
- **No fixtures exist** for `Client`, `Arte`, `WhatsappInstance`, `WhatsappGroup` (`test/fixtures/` has only `clients.yml`, `users.yml`, `sessions.yml` — and `clients.yml` has `one`/`two`/`inactive`). `[VERIFIED: test/fixtures/]`
- Tests build inline, per the phase-27 controller test `[VERIFIED: test/controllers/admin/whatsapp_groups_controller_test.rb]`:
  ```ruby
  @admin = User.find_or_create_by!(email_address: "...") { |u| u.password = u.password_confirmation = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!") }
  sign_in_as(@admin)   # from test/test_helpers/session_test_helper.rb
  @client = Client.create!(name: "...", password: "senha1234", password_confirmation: "senha1234")
  @instance = @client.create_whatsapp_instance!(instance_name: WhatsappInstance.evolution_name_for(@client), connection_state: :connected)
  @group = @instance.whatsapp_groups.create!(remote_jid: "g1@g.us", subject: "Grupo 1", active: true, synced_at: Time.current)
  arte = @client.artes.create!(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, caption: "Legenda")
  arte.media_file.attach(io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")), filename: "sample.jpg", content_type: "image/jpeg")
  ```

### Requirement → test map (illustrative)
| Req | Behavior | Test type | Command |
|-----|----------|-----------|---------|
| DIVU-01 | `#create` with valid arte + groups + datetime → `Divulgacao` + N `DivulgacaoGrupo` rows, redirect | integration | `bin/rails test test/controllers/admin/divulgacoes_controller_test.rb` |
| DIVU-02 | arte not `approved` → `save` false, `errors[:base]` mentions "não está aprovada" | model | `test/models/divulgacao_test.rb` |
| DIVU-03 | arte with `external_url` (no file) → rejected with the upload-orientation message | model | `test/models/divulgacao_test.rb` |
| DIVU-04 | `blob.byte_size` > 16 MB → rejected; message contains the size and the limit | model | `test/models/divulgacao_test.rb` (`blob.update_column(:byte_size, 20.megabytes)`) |
| DIVU-05 | `post … divulgacao: { scheduled_for: "2026-09-15T14:00" }` → `Divulgacao.last.scheduled_for == Time.zone.local(2026,9,15,14,0)`; `Arte#scheduled_on` still a `Date` | integration + model | ditto |
| DIVU-06 | `#new` renders `<img src="/rails/active_storage/…">` or `<video>` and the caption text verbatim | integration | assert `response.body` includes the caption and a media tag |
| DIVU-07 | helper: `divulgacao_duration_estimate(20, min: 25, max: 45)` → `"≈ 9–15 min para 20 grupos"` (or match chosen defaults) | unit | `test/helpers/admin/divulgacoes_helper_test.rb` |
| DIVU-09 | after create, each `DivulgacaoGrupo.status == "pendente"`, `group_name` == the group's `display_name` at create time (rename the group after → snapshot unchanged) | model/integration | ditto |
| SEG-01 | `post … whatsapp_group_ids: ["<id of an INACTIVE or other-client group>"]` → no `Divulgacao` created, re-render `:new` with the "seleção inválida" flash | integration | `assert_no_difference("Divulgacao.count")` |
| SEG-02 (canonical) | client A URL + arte of client B (or groups of client B) → `assert_no_difference(["Divulgacao.count","DivulgacaoGrupo.count"])`, response re-renders/404, body never contains B's arte title / group subject / `remote_jid` | integration | mirrors the phase-27 A×B test verbatim |

### Sampling
- Per task commit: `bin/rails test test/models/divulgacao_test.rb test/models/divulgacao_grupo_test.rb`
- Per phase gate: `POSTGRES_HOST=/var/run/postgresql TZ=America/Sao_Paulo bin/rails test` (full suite). Note 3–4 pre-existing unrelated failures documented across phase-27 summaries (`arte_test.rb:94`, `approval_response_test.rb:158,174`, `dashboard_controller_test.rb:70`) — not introduced here.

---

## Security Domain

`security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high` `[VERIFIED: .planning/config.json]`.

### Applicable ASVS L1 Categories

| ASVS category | Applies | Standard control in this phase |
|---------------|---------|--------------------------------|
| V1 Architecture | yes | All arte/group reads flow through one association path (`@client.artes`, `@client.whatsapp_instance.whatsapp_groups`); no Evolution I/O; the picker resolves its own scoped option set. |
| V2 Authentication | no (inherited) | `Admin::BaseController before_action :require_authentication` `[VERIFIED: app/controllers/admin/base_controller.rb:3]` covers every new action. No new auth surface. |
| V3 Session Management | no | No changes. |
| V4 Access Control | **yes — the core of SEG-01 / SEG-02** | `#create` re-resolves `arte_id` via `@client.artes.find` and every group id via `@client.whatsapp_instance.whatsapp_groups.where(active: true).find(ids)` → `RecordNotFound`. `set_divulgacao` uses `@client.divulgacoes.find`. Model backstop `validate :arte_e_grupos_do_mesmo_cliente`. Cross-client id → 404 / re-render, never a data leak. Canonical A×B negative test REQUIRED (planner MUST include it). |
| V5 Input Validation | yes | No raw `remote_jid`/JID accepted from params — only integer ids, re-resolved through scoped relations. `scheduled_for` cast through the AR datetime type (rejects garbage → validation error, not a crash). `whatsapp_group_ids` coerced `Array(...).map(&:to_i).uniq`. Strong params `permit(:arte_id, :scheduled_for, whatsapp_group_ids: [])`. `arte.caption` in the preview is auto-HTML-escaped by ERB `<%= %>` (no `raw`/`html_safe`). |
| V6 Cryptography | no | No secrets handled. `whatsapp_instance.token` is never touched by this phase. |
| V7 Error Handling & Logging | yes | `RecordNotFound` on cross-client ids is rescued to a generic pt-BR message — no "arte 123 belongs to client 45" disclosure. No group `subject`/`remote_jid` logged. Validation messages state the user's own file size / arte state only. |
| V11 Business Logic | yes | Only `approved` artes schedulable (+ model revalidation — arte state can change between load and submit). Only `active` groups. `cancelar!` guarded to `status_agendada?`. No send path exists to abuse. `scheduled_for` future-only guard recommended (Open Q3). |
| V13 API / Web Service | yes | No JSON endpoint added. `#index`/`#show` scoped by `params[:client_id]` → `Client.find` then `@client.divulgacoes.find`. |

### Known Threat Patterns for {Rails 8.1 nested CRUD + ActiveStorage + no external I/O}

| Pattern | STRIDE | Standard mitigation |
|---------|--------|---------------------|
| Cross-client: arte of A + groups of B via A's nested URL (the "art of A reaches groups of B" precursor) | Elevation of Privilege / Information Disclosure | `@client.artes.find` + `@client.whatsapp_instance.whatsapp_groups.where(active:true).find` + model `arte_e_grupos_do_mesmo_cliente`; A×B negative test both directions |
| Crafted `whatsapp_group_ids[]` with a foreign or inactive id | Tampering / EoP | `.where(active: true).find(ids)` raises on any missing id → whole create rejected; picker never emits a foreign id |
| Raw `remote_jid` injected in params to reach a WhatsApp group directly | Tampering | Form only ever carries integer `group.id`; `remote_jid` is a server-side snapshot written from the resolved record, never read from params |
| Over-limit / external-link media slipping to the (future) send path | Business Logic / Integrity | `arquivo_dentro_do_teto_whatsapp` + `arte_nao_usa_link_externo` at create time (defense-in-depth ahead of phase 29's send-time checks) |
| Stored XSS via `arte.caption` in the preview | XSS (Tampering) | ERB `<%= %>` auto-escapes; `whitespace-pre-wrap` is CSS only; no `raw`/`html_safe`/`sanitize` bypass |
| `RecordNotFound` leaking which client owns an id | Information Disclosure | Rescued to a generic message; 404 (not 403) on cross-client `#show` via `@client.divulgacoes.find` |
| Mass-assignment of `status` / `client_id` | Tampering | Strong params permit only `:arte_id, :scheduled_for, whatsapp_group_ids: []`; `client` comes from the nested route, `status` from the enum default / `cancelar!` |
| Cancel replay / cancel a non-owned divulgação | Access Control | `cancel` goes through `set_divulgacao` (`@client.divulgacoes.find`) + `cancelar!` guard (`status_agendada?`); `PATCH` + CSRF token (Rails default) |

**`security_block_on: high` check:** no HIGH-severity item identified. The security-critical requirements (SEG-01, SEG-02) have concrete, testable controls reusing a pattern already proven by phase 27's A×B test. Planner **MUST** include the canonical cross-client negative test (both directions) as a task.

---

## Sources

### Primary (HIGH confidence) — read this session
- `app/models/arte.rb` — `enum :status { pending, approved, change_requested, revised }` (no prefix, `:28`), `has_one_attached :media_file`, `enum :media_type { image, video, caption_only }` (`:27`), `validates :media_file, content_type:/size: { less_than: 50.megabytes }` (`:37-41`), custom `validate :media_source_present` / `:only_one_media_source` style (`:44-45, 95-104`), `errors.add(:base, "...")` pattern.
- `app/controllers/admin/artes_controller.rb` — nested-under-`clients` controller, `set_client`/`set_arte`, `render :new, status: :unprocessable_entity` on invalid, `check_deletable` gate (`:92-96`), strong params style.
- `app/controllers/client/artes_controller.rb` — `@client.artes.find` + `rescue RecordNotFound` → redirect (`:9-14`).
- `app/controllers/admin/whatsapp_groups_controller.rb` — `set_client = Client.find(params[:client_id])`, scoped `set_group` (`:65-70`), `pagy(... limit: 25)`.
- `app/controllers/admin/base_controller.rb` — `require_authentication` + `Pagy::Backend` (`:1-5`).
- `app/views/admin/whatsapp_groups/_picker.html.erb` — locals `client:` / `selected_ids:` (default `[]`) / `field_name:` (default `nil`) / optional `groups:`, `pagy:`; resolves `client.whatsapp_instance&.whatsapp_groups&.where(active: true)` internally; select-all + counter markup when `field_name` present.
- `app/views/admin/whatsapp_groups/_group_row.html.erb` — `check_box_tag field_name, group.id, selected_ids.include?(group.id), disabled: !field_name` (`:4-6`); `group.announce?` badge.
- `app/views/client/artes/show.html.erb` — media preview: `image_tag rails_storage_proxy_path` / `<video controls playsinline preload="metadata"><source src=rails_storage_proxy_path type=content_type>` (`:26-48`); caption `whitespace-pre-wrap`.
- `app/views/admin/artes/_form.html.erb` — `arte.errors[:base].each` red box (`:5-11`); `f.date_field`; hidden `client_id` when present.
- `app/views/admin/clients/show.html.erb` — "Artes" card pattern (header + "Nova Arte" button `new_admin_arte_path(client_id:)` + list); WhatsApp panel render.
- `app/views/admin/whatsapp_instances/_panel.html.erb` — `button_to` + `data: { turbo_submits_with: … }`, confirm-modal pattern.
- `app/models/{client,whatsapp_instance,whatsapp_group}.rb` — `has_many :artes, dependent: :destroy`, `has_one :whatsapp_instance`, `has_many :whatsapp_groups, through:`; `WhatsappGroup#display_name` (`subject.presence || "Grupo sem nome (…)"`); `WhatsappInstance.evolution_name_for`, `connection_state` enum.
- `db/schema.rb` — `artes.scheduled_on` `t.date … null: false` (`:64`); `artes.status` integer; no `divulgacoes`/`divulgacao_grupos`; FK style (`:262, 270`).
- `config/routes.rb` — `namespace :admin { resources :clients do resources :whatsapp_groups … end }` (`:9-25`).
- `config/application.rb` — `config.load_defaults 8.1` (`:14`), `config.time_zone = "Brasilia"` (`:23`), `config.active_record.default_timezone = :local` (`:24`), `config.i18n.default_locale = :'pt-BR'` (`:25`).
- `config/locales/pt-BR.yml` — `time.formats.long/default`, `date.formats`, `errors.messages`.
- `config/storage.yml` — `test: Disk`, `amazon: S3` (MinIO), private bucket.
- `app/services/evolution.rb` — `Integer(ENV.fetch("EVOLUTION_READ_TIMEOUT", "30"))` idiom (`:57-59`) — the constant-with-ENV-fallback pattern to mirror for the delay vars.
- `.env.example` — `EVOLUTION_*_TIMEOUT` entries with defaults noted (the pattern to follow for `WHATSAPP_SEND_DELAY_*`).
- `test/test_helper.rb` — Minitest, `fixtures :all`, parallelize, deferred-FK workaround.
- `test/fixtures/` — only `clients.yml` (`one`/`two`/`inactive`), `users.yml`, `sessions.yml`; `files/sample.jpg` (22 bytes). No arte/instance/group fixtures.
- `test/controllers/admin/whatsapp_groups_controller_test.rb` — inline setup (`User.find_or_create_by!` + `sign_in_as`, `Client.create!`, `client.create_whatsapp_instance!`, `instance.whatsapp_groups.create!`), the A×B cross-client test shape.
- `.planning/phases/27-…/27-RESEARCH.md`, `27-01/02/03-SUMMARY.md` — `_picker.html.erb` contract, `upsert_all` timestamp gotcha, `check_box_tag` no-hidden-companion, scoped-finder pattern, test-DB-via-socket note.
- `.planning/phases/28-…/28-CONTEXT.md` — all locked decisions.
- `.planning/config.json` — security flags, `nyquist_validation: false`, `human_verify_mode: end-of-phase`.

### Secondary (MEDIUM confidence) — cross-checked
- `.planning/research/SUMMARY.md` (`:92, :139, :162, :206`), `.planning/research/PITFALLS.md` (`:231-232, :470-474, :529`), `.planning/research/STACK.md` (`:198-203, :422-449`) — WhatsApp ~16 MB media ceiling as a convergent heuristic (explicitly "measure in UAT"); `sendMedia` `delay` = pre-send typing simulation in ms, not pacing; media URL fetched server-side by Evolution.
- `.planning/notes/evolution-contract.md` (`:50-59`) — write-path items PENDENTE, media-ceiling probe (5/15/20/30 MB) scoped for **UAT phase 28/29**.
- `.planning/ROADMAP.md` phase 28/29 sections — success criteria, phase-29 owns ENVIO-01..10 + the delay env var.
- [WhatsApp File Size Limits — filesize.org](https://filesize.org/limits/whatsapp/) and [WhatsApp File Size Limit (2026) — usecarly](https://www.usecarly.com/blog/whatsapp-file-size-limit/) — regular media (image/video) caps ~16 MB; documents up to 2 GB (N/A here — Arte accepts only jpeg/png/gif + mp4/mov).
- [rails/rails PR #43003](https://github.com/rails/rails/pull/43003) — `insert_all`/`upsert_all` auto-timestamps + `record_timestamps` (only relevant if bulk insert is used against the recommendation).

### Tertiary (LOW confidence) — flagged
- Exact `WHATSAPP_MEDIA_MAX_BYTES` for image vs video through this specific Evolution 2.3.7 + Cloudflare gateway — not measured; phase-29 UAT (Assumption A1).
- Phase-29 delay env-var names — proposed, no precedent (Assumption A2).
- `config/initializers/inflections.rb` presence (Assumption A4); `Admin::ClientsController#show` extensibility (Assumption A5).

---

## Metadata

**Confidence breakdown:**
- Schema & CRUD & routes: HIGH — locked in CONTEXT; every pattern read from an existing repo controller/view this session.
- Cross-client scoping (SEG-01/02): HIGH — reuses `@client.artes.find` / `@client.whatsapp_instance.whatsapp_groups` verbatim; phase 27's A×B test is the template.
- `datetime-local` → `Time.zone` round-trip: HIGH — `load_defaults 8.1` + `config.time_zone` + `default_timezone = :local` all read from `config/application.rb`; standard Rails behavior.
- `_picker.html.erb` reuse: HIGH — contract read line-by-line; built by phase 27 for this exact use.
- Media preview: HIGH — verbatim precedent in `client/artes/show.html.erb`.
- `WHATSAPP_MEDIA_MAX_BYTES` value: MEDIUM — 16 MB is convergent (repo research + WhatsApp regular-media docs) but this gateway is unmeasured; phase-29 UAT item.
- Delay env-var names/defaults: MEDIUM — proposed, no repo precedent; phase 29 owns the canonical definition.
- Test strategy: HIGH for the harness/fixtures reality; MEDIUM for the >16 MB blob test technique.

**Research date:** 2026-08-30
**Valid until:** ~2026-09-29 for the Rails/timezone/scoping/picker facts (stable). Revisit `WHATSAPP_MEDIA_MAX_BYTES` and the delay env-var names after phase 29 is planned and its UAT measures the real media ceiling.
