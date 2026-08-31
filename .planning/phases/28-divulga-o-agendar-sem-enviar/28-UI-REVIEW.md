# Phase 28 — UI Review

**Audited:** 2026-08-30
**Baseline:** 28-UI-SPEC.md (approved, inherits Phase 26 → 27 contract verbatim + phase-specific additions)
**Screenshots:** not captured — no reachable authenticated dev server (port 8080 served the Rails welcome page with no login session; ports 3000/5173 not listening). Code-only audit against the actual ERB/JS on `main` HEAD (`d752d9f`).

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | Every string in `new`/`index`/`show`/`_preview`/`_grupo_row`/`_status_badge`/clients mirror matches the Copywriting Contract verbatim, including the `(BRT)` suffix rule and the RecordNotFound rescue copy. |
| 2. Visuals | 4/4 | Card hierarchy, section headings, and icon usage (all `aria-hidden`, all paired with text) match the inherited system; no icon-only affordances. |
| 3. Color | 3/4 | Small-primary "Nova divulgação" button in the `clients#show` mirror uses `hover:bg-green-800` instead of the contract's `hover:bg-[#0a5c37]` — a visible hue/darkness drift from the declared token. |
| 4. Typography | 4/4 | Only 12/14/24px sizes introduced by this phase; `text-lg` appears solely inside the reused (not new) empty-state block, consistent with the inherited asset. Weight set stays within 400/500/600. |
| 5. Spacing | 4/4 | All spacing classes trace to the declared scale or the documented exceptions (`mb-1.5`, `max-h-[380px]`, `max-h-64`); no new arbitrary values. |
| 6. Experience Design | 3/4 | State coverage (loading/error/empty/disabled/confirm) is thorough and matches the UI Considerations table, but the "cancelada" banner timestamp reads `@divulgacao.updated_at` rather than a dedicated cancellation timestamp — a latent correctness risk once any other mutation path exists. |

**Overall: 22/24**

---

## Top 3 Priority Fixes

1. **`hover:bg-green-800` instead of `hover:bg-[#0a5c37]` on the mirror-section "Nova divulgação" button** — `app/views/admin/clients/show.html.erb:144` — Color contract violation: Tailwind's `green-800` (`#166534`) is visibly darker/bluer than the declared brand hover `#0a5c37`, breaking hover-state color consistency between the `index` header button (which correctly renders `#0a5c37` via the shared "Primary button" class) and this small variant. Fix: change `hover:bg-green-800` to `hover:bg-[#0a5c37]` to match the "Small primary button" row in the Design System table exactly.

2. **Cancellation timestamp sourced from `updated_at`, not a dedicated field** — `app/views/admin/divulgacoes/show.html.erb:18` (`divulgacao_datetime_label(@divulgacao.updated_at)`) — the cancelada banner claims "Esta divulgação foi cancelada em {timestamp}", but `updated_at` is a generic ActiveRecord touch column with no guarantee it reflects the cancellation moment specifically — any future mutation to the row (e.g. a Phase 29/30 engine write, an admin correction) would silently move this displayed timestamp without the divulgação having been re-cancelled. Fix: add a `cancelled_at` datetime column, set it in `Divulgacao#cancelar!` alongside the status transition, and read it here instead of `updated_at`.

3. **Same `hover:bg-green-800` pattern also exists at `app/views/admin/clients/show.html.erb:181`** (small primary button, adjacent card, likely a Phase 27-or-earlier surface reusing the same broken pattern) — not newly introduced by Phase 28, but it means the drift is now repeated twice in the same view and will visually clash directly against the correctly-styled Phase 28 button just above it once both are on screen. Fix: same swap, and worth a follow-up grep across `app/views/admin/` for any other `hover:bg-green-800`/`hover:bg-green-700` on `bg-[#0F7949]`/`bg-[#14A958]` buttons to close the drift systemically.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)
- All primary/secondary/CTA labels checked against the contract table: "Agendar divulgação" / "Agendando…" (`new.html.erb`), "Nova divulgação" (index header, mirror, empty states), "Cancelar divulgação" / "Cancelando…" + exact `turbo_confirm` string (`show.html.erb:47`), "Ir para o pareamento", "Ver artes do cliente", all present verbatim.
- Datetime formatting: `divulgacao_datetime_label` (`app/helpers/admin/divulgacoes_helper.rb:8`) produces exactly `DD/MM/YYYY HH:MM (BRT)` per DIVU-05.
- Estimate copy: `divulgacao_duration_estimate` and the JS mirror in `divulgacao_estimate_controller.js` both produce `≈ {lo}–{hi} min para {n} grupos` / the `lo == hi` single-value fallback / `—` for zero — matches spec exactly, and client/server strings are kept in lockstep (both hard-coded to the same template).
- RecordNotFound rescue flash text (`divulgacoes_controller.rb:82`) matches the contract's "Seleção inválida: uma arte ou um grupo escolhido não pertence a este cliente ou foi desativado. Revise a seleção e tente de novo." exactly.
- One string not explicitly in the contract table: the `cancel` action's failure-path alert ("Só é possível cancelar uma divulgação ainda agendada.", `divulgacoes_controller.rb:19`) for the unreachable-via-UI double-cancel race. Reasonable defensive copy, not a violation — the contract only speaks to the success path.

### Pillar 2: Visuals (4/4)
- Clear per-page focal point: single card (`new`), list-shell card (`index`), three stacked sections (`show`) — consistent with the inherited card shell.
- All SVG icons carry `aria-hidden="true"` and are always paired with adjacent text (empty-state headings, mobile-card chevron, status pill `●` glyph). No icon-only interactive elements.
- Preview media carries `alt="Prévia da mídia da divulgação"`; video has both a `<track>`-less native fallback string and `preload="none"` for the hidden multi-pane case, matching the spec's fetch-avoidance rule.
- Hierarchy via size/weight is consistent: `<h1>` 24/600, section `<h2>` 14/600, body 14/400 — no ad hoc overrides found in the four new views + five new partials.

### Pillar 3: Color (3/4)
- Accent (`#0F7949`) usage stays inside the four reserved categories (primary submit, focus rings on `<select>`/`datetime-local`/checkboxes, checked-checkbox state via the inherited picker, "Ver"/"Ver arte"/"Ir para o pareamento" text links) — no accent leakage onto status pills, the preview card, or the estimate value, matching the contract's explicit exclusion list.
- Status pill palettes (`_status_badge.html.erb`, `_grupo_row.html.erb`) map 1:1 to the canonical table: `agendada`→success green, `cancelada`→error red, `em_andamento`→warning amber, `concluida`→neutral slate, and the four `divulgacao_grupos.status` pills likewise — all four future-phase pills (`em_andamento`, `concluida`, `enviado`, `falhou`, `incerto`) are pre-wired correctly even though this phase never drives them.
- **Deviation:** `hover:bg-green-800` (Tailwind stock color) on the small primary button instead of the declared `hover:bg-[#0a5c37]` custom hex — see Priority Fix #1/#3 above. This is a literal token substitution, not a stylistic choice; the two greens are perceptibly different (`#166534` vs `#0a5c37`).

### Pillar 4: Typography (4/4)
- Grep of all `text-*` size utilities across the four views + five partials returns only `text-xs` (12px), `text-sm` (14px), `text-2xl` (24px), and `text-lg` (18px) — the last confined to the reused empty-state heading (an inherited asset carried in unchanged from Phase 26, not a new size introduced by this phase, per the spec's own footnote scoping the "3 sizes" rule to in-phase additions).
- Font weights used: `font-medium` (500) and `font-semibold` (600) only, consistently on the elements the contract assigns them to (field labels, section headings, `<th>`/badge text, list primary cells). No stray `font-bold`/`font-light`.

### Pillar 5: Spacing (4/4)
- Card padding (`p-8` form, `p-6` show/list/mirror), field rhythm (`mb-4`/`mb-6`), section-heading `pb-3 mb-4`, and the two scroll-container caps (`max-h-[380px] overflow-y-auto` picker, `max-h-64 overflow-y-auto` caption) all match the declared scale and documented exceptions verbatim — no undeclared arbitrary spacing values found in any of the audited files.

### Pillar 6: Experience Design (3/4)
- Loading: `turbo_submits_with` on both the create submit ("Agendando…") and the cancel `button_to` ("Cancelando…") — correct, disables + swaps label for the request duration.
- Error: `errors[:base]` red box, `flash.now[:alert]` box for the RecordNotFound path, and — notably — the rescue path **preserves already-resolvable form state** (arte, raw `scheduled_for`, and any group ids that do resolve) rather than blanking the form, a stronger-than-spec UX behavior.
- Empty states: all four (no instance, no approved arte, empty picker, empty index) render the correct heading/body/CTA combination; the `clients#show` mirror correctly uses the inline (non-`py-16`) "Nenhuma divulgação agendada." variant instead of duplicating the full-page empty block inside a shared card.
- Disabled state: submit correctly disables on `!@instance.connected?` OR zero active groups — matches the Layout & Interaction Contract's disabled condition precisely.
- Destructive confirm: native `turbo_confirm` with the exact contracted string, no `_confirm_modal` — correct per the locked v1.3+ pattern.
- **Deviation:** the cancelada banner's timestamp is read from `@divulgacao.updated_at` (`show.html.erb:18`) rather than a purpose-built cancellation timestamp. Functionally correct today (no other write path exists post-cancel), but it is not a load-bearing "cancelled at" fact — it silently rides on a generic touch column. See Priority Fix #2.

---

## Files Audited

- `app/views/admin/divulgacoes/new.html.erb`
- `app/views/admin/divulgacoes/index.html.erb`
- `app/views/admin/divulgacoes/show.html.erb`
- `app/views/admin/divulgacoes/_preview.html.erb`
- `app/views/admin/divulgacoes/_status_badge.html.erb`
- `app/views/admin/divulgacoes/_grupo_row.html.erb`
- `app/views/admin/clients/show.html.erb` (mirror section, lines 139–174)
- `app/helpers/admin/divulgacoes_helper.rb`
- `app/javascript/controllers/divulgacao_preview_controller.js`
- `app/javascript/controllers/divulgacao_estimate_controller.js`
- `app/javascript/controllers/picker_controller.js`
- `app/controllers/admin/divulgacoes_controller.rb`
- `config/routes.rb` (route existence check for `admin_arte_path`)
- `.planning/phases/28-divulga-o-agendar-sem-enviar/28-UI-SPEC.md`
- `.planning/phases/28-divulga-o-agendar-sem-enviar/28-CONTEXT.md`
