# Phase 27 — UI Review

**Audited:** 2026-08-30
**Baseline:** 27-UI-SPEC.md (approved, 3 non-blocking FLAGs) + inherited 26-UI-SPEC contract
**Screenshots:** not captured — a Rails process on :8080 serves only the default Rails welcome page; the audited surfaces need an authenticated admin session plus a seeded client with a paired instance and synced groups. Code-only audit (ERB/Tailwind/Stimulus inspection).

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Copy is near-verbatim from the contract; panel link never renders the spec-defined `Ver grupos (N)` count variant. |
| 2. Visuals | 3/4 | `truncate` on flex children lacks `min-w-0` in 3 row templates — long group names will not truncate and will shove the badge / overflow the card. |
| 3. Color | 3/4 | `show.html.erb` adds an `Ativo` green pill (`bg-[#F0FDF4] text-[#14A958]`) that the contract's group-state map says active rows must not carry; success green is contract-scoped to the sync-enqueue flash only. |
| 4. Typography | 4/4 | 3 sizes (24/14/12), 3 weights (400/500/600), inactive divider styled `text-xs font-medium text-slate-400 uppercase tracking-wide` verbatim; error/blocked boxes use `leading-relaxed` as required. |
| 5. Spacing | 3/4 | Grid-aligned throughout, but the Phase 28 select-all row is `py-2` (~32px) — below the 44px touch-target floor the spec explicitly guarantees for interactive rows. |
| 6. Experience Design | 2/4 | `group_sync_controller` polls unconditionally on every `connect()`; a normal visit to any groups page fires ~20 background requests and then reveals the "A sincronização está demorando. Atualize a página" note after 60s with no sync in progress. |

**Overall: 18/24**

---

## Top 3 Priority Fixes

1. **BLOCKER — Poller runs when no sync is in progress.** `group_sync_controller.js` `connect()` calls `this.poll()` + `setInterval` unconditionally, and `index.html.erb` attaches `data-controller="group-sync"` whenever `@instance` is present. On a populated list `_advancedPastSince` returns `false` for an unchanged `synced_at` (`new Date(x) > new Date(x)` is false), so the poller runs its full 20 cycles and then un-hides the `timeout` target — showing "A sincronização está demorando. Atualize a página para ver o resultado." to a user who never clicked Sincronizar. On empty-state-2 (`since-value=""`) it also burns 20 cycles then shows the same note. **Fix:** in `connect()`, only start polling when `this.sinceValue` indicates an in-flight sync or a `notice` flash is present (the spec's stated guard: *"On `connect`, if `syncing` is true or a `notice` flash is present: poll"*). Pass a `syncingValue`/flash flag from the view and early-return otherwise.

2. **WARNING — `truncate` cannot engage on the group-name span.** `_group_row.html.erb:8`, `index.html.erb:105` (inactive row), and the pattern generally place `class="… truncate"` on a flex child with no `min-w-0`/`flex-1`. A flex item defaults to `min-width:auto`, so it will not shrink below its content and `truncate` is a no-op; a long `subject` pushes the `shrink-0` `announce` / `Inativo` badge out of the row and overflows the `max-w-2xl` card. **Fix:** `class="min-w-0 flex-1 truncate …"` on the name span in both row templates (the spec's own markup omits this — fix it in the implementation).

3. **WARNING — No visible in-progress indicator for sighted users.** After the sync POST redirects, the button label reverts and the only "Sincronizando grupos… isso pode levar alguns segundos." signal is the `sr-only` `aria-live` span (`index.html.erb:42`). The spec's Typography table lists a *"Sync-in-progress status (aria-live, beside the button)"* row at 12px/500 — i.e. a visible caption, not only screen-reader text. **Fix:** render a visible `text-xs font-medium text-slate-500` status line next to the caption that `group_sync_controller` fills while polling, mirroring the `sr-only` text.

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)
- Strings match the Copywriting Contract closely: `Grupos do WhatsApp`, `Grupos`, `Sincronizar grupos`, `Sincronizando…`, empty-state 1/2/3 headings and bodies, blocked banner, inactive divider (`Grupos inativos`) + helper (`Preservados para o histórico. Não podem ser selecionados.`), inactive caption (`Sumiu do WhatsApp na última sincronização`), `Só admins enviam` + `title=`, timeout note + `Atualizar` link — all verbatim (`index.html.erb:46–120`, `_group_row.html.erb:12–15`).
- Error copy: `wa_groups_sync_error_message` (`whatsapp_groups_helper.rb:28`) returns the two contract strings (`not_connected` dedicated, all others → generic retry). Matches the spec.
- Poller toast/status strings in `group_sync_controller.js:37/43/51` match the contract (`Grupos sincronizados.`, failure toast).
- **Divergence:** `_panel.html.erb:73` renders `Ver grupos` only. The contract defines `Ver grupos (12)` "with count when known" and the count is trivially available (`whatsapp_instance` / `client.whatsapp_groups.where(active: true).count`). Nowhere in the phase is the count surfaced on the link.
- `show.html.erb` back link `← Voltar aos grupos` and `Estado` / `Envio` / `JID` labels are not in the contract (show page is not copy-specified) — acceptable, but unreviewed against a contract.

### Pillar 2: Visuals (3/4)
- Clear focal point per state: centered icon + heading + single CTA for empty states 1/2/3 (`index.html.erb:47–91`); card header `Grupos` + connection badge + sync button for the populated state.
- Decorative glyphs are `aria-hidden="true"` (inactive lock `:102`, badge `●`s). Toast dismiss button carries `aria-label="Fechar notificação"` (`group_sync_controller.js:100`). No unlabeled icon-only controls.
- **`truncate` without `min-w-0`** on the name span in `_group_row.html.erb:8` and `index.html.erb:105` — the long-`subject` overflow state (spec "UI Considerations" long-text row) is not actually handled; badge gets pushed / row overflows. Same latent bug the spec markup carries; implementation should correct it.
- `index.html.erb:19` renders the connection badge (`Aguardando criação`) next to the `Grupos` heading even in empty-state-1, directly above body copy that already says "Nenhuma instância de WhatsApp" — mildly redundant.
- Checker FLAG (Dimension 2, non-blocking) — name the primary visual anchor per screen state — remains unaddressed in code/docs.

### Pillar 3: Color (3/4)
- Accent `#0F7949` stays within the reserved list: primary button fill (`index.html.erb:28/54/78`), focus rings + checked state on checkboxes (`_group_row.html.erb:7`, `_picker.html.erb:24`), navigating text links `Ir para o pareamento` / `Atualizar` / `Ver grupos` at `text-[#0F7949] hover:underline` (`index.html.erb:60/119`, `_panel.html.erb:74`). No accent on badges, status text, or the error box — matches the contract.
- Semantic colors correct: amber `bg-[#FFFBEB]/text-amber-800/border-[#F59E0B]/20` for `announce` badge and blocked banner; error `bg-[#FEF2F2]/text-[#EE3537]/border-[#EE3537]/20` for the failed-sync box; slate `bg-slate-100/text-slate-600/border-slate-200` for the `Inativo` pill and muted inactive rows (`index.html.erb:58–109`).
- **Out-of-contract:** `show.html.erb:16` gives active groups an `Ativo` pill in `bg-[#F0FDF4] text-[#14A958] border-[#14A958]/20`. The contract's canonical group-state → treatment map lists **Badge: none** for `active, postable`, and scopes success green to "the redirect flash after a successful sync enqueue". The hue is inherited from the Phase 26 connection badge, so this is a state-map divergence rather than a rogue color, but it is UI the contract does not sanction.
- Note: `bg-[#F0FDF4]` is `green-50` and `text-[#14A958]` replaces the contract's `text-green-700` for success — hardcoded arbitrary hex where the token was specified.

### Pillar 4: Typography (4/4)
- In-phase font sizes: `text-2xl` (h1), `text-sm`, `text-xs` — exactly the 3 the contract allows (24/14/12). Verified across `index.html.erb`, `_group_row.html.erb`, `_picker.html.erb`, `show.html.erb`, `_panel.html.erb`.
- Weights: `font-semibold` (600), `font-medium` (500), default 400 — the inherited justified 3-weight scale; no `font-bold`/`font-light` etc.
- Contract-specific styling honored: last-synced caption `text-xs font-medium text-slate-500` (`index.html.erb:41`); inactive divider `text-xs font-medium text-slate-400 uppercase tracking-wide` (`:97`); null-`subject` name `text-slate-500 italic` (`_group_row.html.erb:8`); error box + blocked banner `leading-relaxed` (`:58/:64`).
- Selection counter `text-xs font-medium text-slate-500` (`_picker.html.erb:27`) matches the contract row.

### Pillar 5: Spacing (3/4)
- 4px grid respected: `p-6`, `pb-3 mb-4`, `mb-4`/`mb-6`, `py-3 px-4` rows, `gap-3`, `gap-1` badge glyph, `py-16` empty states, `mt-6 pt-4` inactive section, `mt-4` timeout note — all match the inherited scale.
- `_group_row.html.erb:4` row is `flex items-center gap-3 py-3 px-4` → ≈44px, meets the touch-target floor as the spec promises.
- **Below floor:** `_picker.html.erb:20` select-all row is `py-2` (8px) → ~32px tall with an `h-4` checkbox — under the 44px interactive-row floor the spec explicitly calls out. Dead in Phase 27 (`field_name: nil`) but ships as the Phase 28 contract.
- `index.html.erb:8` back link uses `max-w-[280px] sm:max-w-md` — arbitrary px value; sanctioned by the spec's long-name backstop decision, noted for completeness.

### Pillar 6: Experience Design (2/4)
- Strong nominal state coverage: enqueue loading via `turbo_submits_with: "Sincronizando…"` on all three sync buttons; job-completion poller; error box + error toast with two copy variants; empty states 1/2/3; picker-empty line; blocked banner + disabled button; disabled sync buttons when `!connected?`; no destructive action (correct per spec).
- **BLOCKER — unconditional polling.** `group_sync_controller.js:18–22` starts the interval on every `connect()`; the controller is attached whenever `@instance` exists (`index.html.erb:11`). Consequences: (a) populated synced list — `_advancedPastSince` is `false` for an unchanged timestamp, so 20 cycles run and the `timeout` note ("sync is taking long, refresh") is revealed with no sync active; (b) empty-state-2 — `since-value=""`, same 20 wasted cycles then the same spurious note; (c) ~20 needless `sync_status` requests per page view. Contract requires polling only when `syncing` or a `notice` flash is present.
- **WARNING — no visible in-progress feedback.** Post-redirect, the "Sincronizando grupos…" text lives only in an `sr-only` span (`index.html.erb:42`); sighted users see nothing between clicking and the eventual `Turbo.visit` replace (up to ~60s). Spec Typography implies a visible caption beside the button.
- **WARNING — dead Phase 28 markup.** `_picker.html.erb` emits `data-picker-select-all` / `data-picker-counter` with a static `0 de N` counter and no Stimulus controller anywhere in the repo to wire them. Not exercised in Phase 27 (read-only), but the "reusable contract for Phase 28" ships with a non-functional select-all and a counter that will never update.
- Minor: `sync` redirects with `notice: "Sincronização já em andamento."` for both the in-flight-state guard and the cache-guard race — reasonable, matches no specific contract string but is clear pt-BR.

---

## Files Audited
- `app/views/admin/whatsapp_groups/index.html.erb`
- `app/views/admin/whatsapp_groups/_group_row.html.erb`
- `app/views/admin/whatsapp_groups/_picker.html.erb`
- `app/views/admin/whatsapp_groups/show.html.erb`
- `app/views/admin/whatsapp_instances/_panel.html.erb`
- `app/views/admin/whatsapp_instances/_connection_badge.html.erb` (referenced by index header)
- `app/javascript/controllers/group_sync_controller.js`
- `app/helpers/admin/whatsapp_groups_helper.rb`
- `app/controllers/admin/whatsapp_groups_controller.rb` (state-branch inputs to the views)

_Registry safety audit: skipped — no `components.json`, `shadcn_initialized: false`, no component registry in use._
