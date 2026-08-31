---
phase: 28-divulga-o-agendar-sem-enviar
reviewed: 2026-08-31T02:00:00Z
depth: standard
files_reviewed: 27
files_reviewed_list:
  - db/migrate/20260830190001_create_divulgacoes.rb
  - db/migrate/20260830190002_create_divulgacao_grupos.rb
  - app/models/divulgacao.rb
  - app/models/divulgacao_grupo.rb
  - app/controllers/admin/divulgacoes_controller.rb
  - app/helpers/admin/divulgacoes_helper.rb
  - app/views/admin/divulgacoes/new.html.erb
  - app/views/admin/divulgacoes/index.html.erb
  - app/views/admin/divulgacoes/show.html.erb
  - app/views/admin/divulgacoes/_preview.html.erb
  - app/views/admin/divulgacoes/_status_badge.html.erb
  - app/views/admin/divulgacoes/_grupo_row.html.erb
  - app/javascript/controllers/divulgacao_preview_controller.js
  - app/javascript/controllers/divulgacao_estimate_controller.js
  - app/javascript/controllers/picker_controller.js
  - config/initializers/inflections.rb
  - config/routes.rb
  - app/models/client.rb
  - app/models/arte.rb
  - app/models/whatsapp_group.rb
  - app/controllers/admin/clients_controller.rb
  - app/views/admin/clients/show.html.erb
  - db/schema.rb
  - test/controllers/admin/divulgacoes_controller_test.rb
  - test/models/divulgacao_test.rb
  - test/models/divulgacao_grupo_test.rb
  - test/helpers/admin/divulgacoes_helper_test.rb
  - test/controllers/admin/clients_controller_test.rb
findings:
  critical: 0
  warning: 1
  info: 3
  total: 4
status: issues_found
---

# Phase 28: Code Review Report (Re-Review After Fix Pass)

**Reviewed:** 2026-08-31T02:00:00Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

This is a re-review of a fix pass applied on top of the original 28-REVIEW.md
(2 Critical, 2 Warning, 3 Info). Three commits (`da02339`, `137e2d9`,
`9aaed39`) were audited by re-reading the current source and by empirically
reproducing/re-testing each fix against the live app (not just reading the
diff). Both original Criticals are confirmed resolved. One Warning
(WR-02, absorbed into the CR-02 fix) is confirmed resolved. The other Warning
(WR-01) is **partially** resolved — the fixer's own new test only asserts
`scheduled_for` and group preservation, and a form-data-loss gap remains for
the `arte` field specifically, reproduced below. The task's two specific
"did the fix open a new gap" questions were both empirically checked and
**came back clean** (no new gap found).

**CR-01 (cancelar! fails once scheduled_for is in the past) — CONFIRMED
FIXED.** `scheduled_for_no_futuro` is now `on: :create`
(`app/models/divulgacao.rb:37`). Ran the full `test/models/divulgacao_test.rb`
suite (23 runs, 0 failures), including the new regression test at lines
228-243 that uses `travel_to` to land squarely past `scheduled_for` and then
asserts `cancelar!` succeeds. Also independently verified: the only routes
for this resource are `index/new/create/show` plus `patch :cancel`
(`config/routes.rb:25-27`) — there is no `edit`/`update` action anywhere, so
there is no path by which an admin could set `scheduled_for` to a past value
post-creation. The task's specific worry ("could scoping to `on: :create`
open a gap on some other update path") does not apply here — confirmed no
such path exists. One adjacent, non-blocking observation: `cancelar!`'s
`update(status: :cancelada)` call still re-runs the five *other* validations
(`arte_deve_estar_aprovada`, `arte_nao_usa_link_externo`,
`arquivo_dentro_do_teto_whatsapp`, `arte_e_grupos_do_mesmo_cliente`,
`ao_menos_um_grupo`), which are all still update-time-validated too. I traced
whether any of these are reachably invalidated between a divulgação's
creation and its cancellation and found no live path today: `Arte#status`
can only regress off `approved` via a client `ApprovalResponse`, which is
itself blocked once `arte.approved?` (`ApprovalResponse#arte_must_be_pending`
only allows `pending`/`revised`); `Admin::ArtesController#check_editable`
blocks editing (and thus swapping `media_file`) once approved; and
`check_deletable` blocks destroying a non-`pending` arte. So this is inert
today, not a live bug — flagged only as a landmine for phase 29 to be aware
of, not a new finding requiring a fix.

**CR-02 / WR-02 (malformed param shapes crash with a 500; ad-hoc `params.dig`
replaced with strong params) — CONFIRMED FIXED, and specifically verified
against the task's "does permit silently let garbage through" worry.**
`divulgacao_params` now uses
`params.require(:divulgacao).permit(:arte_id, :scheduled_for, whatsapp_group_ids: [])`
(`app/controllers/admin/divulgacoes_controller.rb:98-100`). Ran
`test/controllers/admin/divulgacoes_controller_test.rb` (36 runs, 0
failures), including the two new CR-02 regression tests (lines 137-161:
Hash-shaped `whatsapp_group_ids`, Array-shaped `arte_id`), both asserting
`:unprocessable_entity`, never a 500. I additionally probed the specific
edge case named in the task — a nested array-of-hashes for
`whatsapp_group_ids` — directly against `ActionController::Parameters` in a
`rails runner` session (not inferred from documentation):
```
whatsapp_group_ids: [{"a"=>"1"}, {"b"=>"2"}] .permit(whatsapp_group_ids: []) => nil
whatsapp_group_ids: ["1", {"b"=>"2"}, "3"]    .permit(whatsapp_group_ids: []) => nil
arte_id: {"foo"=>"1"}                         .permit(:arte_id)              => nil
```
Rails' `permit` rejects the *entire* array (not a partial per-element filter)
the moment any element isn't a permitted scalar, so no hash/array garbage
reaches the `.map(&:to_i)` id-resolution loop — it becomes `nil` →
`Array(nil) => []` → `scoped_active_groups.find([])`, which I also verified
directly returns `[]` (not an exception) → the record correctly fails
`ao_menos_um_grupo` and re-renders 422. No new gap found for either question
posed in the task.

**WR-01 (RecordNotFound rescue path preserves what's resolvable) — ONLY
PARTIALLY FIXED.** `scheduled_for` and successfully-resolved groups are now
correctly preserved on re-render
(`app/controllers/admin/divulgacoes_controller.rb:76-84`), verified by the
fixer's own new test (lines 165-183) and independently confirmed. However,
the fix never re-attaches the already-resolved `arte` local variable to
`@divulgacao` in the rescue block, so when the *arte* resolves successfully
but only a *group* id fails (the scenario the code's own inline comments
describe as the primary motivating case — "um grupo desativado por um sync
da fase 27 entre o load do form e o submit"), the arte selection is silently
dropped and the admin has to re-pick it. See WR-01 (residual) below for a
concrete repro.

## Warnings

### WR-01 (residual): the arte selection is still lost on re-render when only the group id(s) fail to resolve, even though `scheduled_for` and resolvable groups are now preserved

**File:** `app/controllers/admin/divulgacoes_controller.rb:46-48` (interacts with the rescue at `69-88`)
**Issue:**
```ruby
arte   = @client.artes.find(divulgacao_params[:arte_id])          # line 46
gids   = Array(divulgacao_params[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
groups = scoped_active_groups.find(gids)                          # line 48 — raises here
...
rescue ActiveRecord::RecordNotFound
  @divulgacao ||= @client.divulgacoes.new(scheduled_for: divulgacao_params[:scheduled_for])
  resolved_gids = Array(divulgacao_params[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
  scoped_active_groups.where(id: resolved_gids).each { |g| @divulgacao.divulgacao_grupos.build(...) }
  ...
```
When the exception is raised at line 48 (an invalid/foreign/deactivated
group id), the local variable `arte` (line 46) already holds the
successfully-resolved `Arte` record — Ruby's method-level rescue shares the
method's local variable scope, so `arte` is fully populated at that point.
But the rescue block never passes `arte: arte` into the fresh
`@client.divulgacoes.new(...)` call, so the re-rendered `<select>`
(`app/views/admin/divulgacoes/new.html.erb:65-66`,
`f.collection_select :arte_id, ...`) comes back with nothing selected — the
admin has to re-pick a perfectly valid arte they already correctly chose,
even though the code's own new comment at line 73-75 frames this exact class
of case ("um id forasteiro/inativo... nao deveria forcar o admin a
redigitar tudo") as the thing being fixed.

Reproduced directly against the running app (own client's valid arte + one
non-existent group id):
```ruby
post admin_client_divulgacoes_path(@client), params: {
  divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ 999999 ], scheduled_for: "2026-09-20T15:30" }
}
# => 422, response.body includes @arte.title (it's still listed as an <option>)
# => but no <option ... selected> for @arte.id — the selection itself is gone
```
The fixer's own new regression test for WR-01
(`test/controllers/admin/divulgacoes_controller_test.rb:165-183`) does not
catch this: it asserts `scheduled_for` survives and that `@g1`'s checkbox is
still `checked`, but never asserts anything about the `arte_id` select's
selected state, so this gap shipped silently.

**Fix:** Thread the already-resolved `arte` local variable into the rescue's
reconstruction (guard for the case where `arte` itself never resolved, i.e.
the exception came from line 46 instead of line 48 — in that case `arte` is
`nil` by Ruby's local-variable pre-declaration, which is harmless to pass
through):
```ruby
rescue ActiveRecord::RecordNotFound
  @divulgacao ||= @client.divulgacoes.new(
    arte:          arte,
    scheduled_for: divulgacao_params[:scheduled_for]
  )
  resolved_gids = Array(divulgacao_params[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
  scoped_active_groups.where(id: resolved_gids).each do |g|
    @divulgacao.divulgacao_grupos.build(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid)
  end
  ...
```
Add a regression test asserting the `<select name="divulgacao[arte_id]">`
still has the correct `<option ... selected>` when only the group id(s)
fail to resolve (mirroring the existing `assert_select` pattern already used
for the group checkbox at line 180).

## Info

_Carried over from the original 28-REVIEW.md, left untouched by the fix pass
(expected — the task scoped this re-review to verifying the 3 fixes plus
looking for newly introduced issues, not re-litigating unaddressed Info
items). Re-confirmed still present and unchanged at the cited locations;
no re-analysis performed beyond confirming the lines are unmodified by the
fix commits._

### IN-01: `new.html.erb` queries `@client.whatsapp_instance` a second time instead of reusing the already-loaded `@instance`

**File:** `app/views/admin/divulgacoes/new.html.erb:120`
**Issue:** `submit_disabled = !@instance.connected? || @client.whatsapp_instance.whatsapp_groups.where(active: true).none?` re-fetches the association instead of using the `@instance` ivar the controller already set.
**Fix:** `@instance.whatsapp_groups.where(active: true).none?`

### IN-02: `divulgacoes#index` and the `clients#show` mirror card N+1 on `divulgacao_grupos.size` per row

**File:** `app/views/admin/divulgacoes/index.html.erb:47`, `app/views/admin/clients/show.html.erb` (Divulgações card)
**Issue:** `@client.divulgacoes.includes(:arte)` does not include `:divulgacao_grupos`, so each row's `d.divulgacao_grupos.size` issues a separate query.
**Fix:** `@client.divulgacoes.includes(:arte, :divulgacao_grupos).order(scheduled_for: :desc)`

### IN-03: `_status_badge.html.erb` and `_grupo_row.html.erb` have no `else`/default branch in their `case` statements

**File:** `app/views/admin/divulgacoes/_status_badge.html.erb`, `app/views/admin/divulgacoes/_grupo_row.html.erb`
**Issue:** Both partials `case` over the enum string with one `when` per known value and no `else` — silently renders nothing if the enum ever gains a value.
**Fix:** Add a defensive `else` branch rendering a neutral "unknown status" pill.

---

_Reviewed: 2026-08-31T02:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
