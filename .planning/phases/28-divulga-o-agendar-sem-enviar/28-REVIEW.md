---
phase: 28-divulga-o-agendar-sem-enviar
reviewed: 2026-08-30T21:30:00-03:00
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
  warning: 0
  info: 4
  total: 4
status: issues_found
---

# Phase 28: Code Review Report (Final Re-Review — Fix Pass 2, iteration 3/3)

**Reviewed:** 2026-08-30T21:30:00-03:00
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found (Info only — no must-fix items remain)

## Summary

This is the third and final review pass in the auto fix/re-review loop. It
verifies fix-pass commit `6756bca` ("WR-01 (residual) re-attach resolved
arte on RecordNotFound rescue"), the sole change since the previous
(`28-REVIEW.iter3.md`) review, and re-audits the full phase-28 file scope
for anything the fix might have introduced.

**WR-01 (residual) — CONFIRMED FIXED, no new gap introduced.**

`app/controllers/admin/divulgacoes_controller.rb:80-83` now threads the
already-resolved `arte` local variable into the rescue's reconstruction of
`@divulgacao`:

```ruby
@divulgacao ||= @client.divulgacoes.new(
  arte:          arte,
  scheduled_for: divulgacao_params[:scheduled_for]
)
```

I traced every path that can reach `rescue ActiveRecord::RecordNotFound` in
`create` and confirmed the specific worry named in the task — "could the
exception have originated from arte resolution itself, leaving `arte` nil or
stale" — is a real but harmless case, not a bug:

- The rescue is a **method-level** rescue (implicit `begin` at `def create`,
  single `end` closes the method after the rescue body) — `arte` is genuinely
  in the same local-variable scope, not a leaked variable from elsewhere.
- Only two lines in the method body can raise `RecordNotFound`: line 46
  (`@client.artes.find(divulgacao_params[:arte_id])`) and line 48
  (`scoped_active_groups.find(gids)`).
  - If line 46 raises, `arte` was never assigned; Ruby's parse-time local
    variable pre-declaration means it's `nil` at that point (not stale,
    not a leftover from a prior request — each request gets a fresh
    controller instance and a fresh call to `create`). Passing `arte: nil`
    into `@client.divulgacoes.new(...)` is a no-op equivalent to omitting
    the keyword — the association is simply unset, and the re-rendered
    `collection_select` correctly shows no `<option selected>` (forces a
    valid re-pick), with no crash (`.save`/`.valid?` is never called on this
    path, so `belongs_to :arte`'s required-by-default validation never
    fires here).
  - If line 48 raises, `arte` already holds a real `Arte` scoped to
    `@client.artes` (line 46 succeeded first) — safe to re-attach, and it
    cannot belong to a different client (SEG-01/SEG-02 invariant preserved).
  - No other line between the method's `arte =` assignment and the rescue
    can raise `RecordNotFound`, so there is no third case to worry about.
- Confirmed empirically: `test/controllers/admin/divulgacoes_controller_test.rb:185-198`
  (new regression test) asserts the `<option value="#{@arte.id}"><selected>`
  survives re-render when only the group id fails; the pre-existing
  `build_client_b` cross-client test (line 82-95) still asserts the foreign
  arte's title never leaks into the response body when arte resolution
  *itself* is what fails — i.e. the `nil` case is also covered and does not
  regress the SEG-01/SEG-02 leak-prevention guarantee.
- Ran the full relevant suite: `82 runs, 410 assertions, 0 failures, 0
  errors, 0 skips` (`divulgacoes_controller_test.rb`, `divulgacao_test.rb`,
  `divulgacao_grupo_test.rb`, `divulgacoes_helper_test.rb`,
  `clients_controller_test.rb`).

No Critical or Warning findings remain. All three prior fixes (CR-01, CR-02/
WR-02, WR-01 including its residual) are confirmed resolved across all three
review iterations, with no regressions introduced by any of them.

Four **Info**-level items remain, all carried over unchanged from the
original review and explicitly out of scope for the fix passes (performance/
robustness nits, not correctness bugs). Since this is the final iteration of
the auto-loop, they are listed below with an explicit ship/defer
recommendation.

## Info

### IN-01: `new.html.erb` queries `@client.whatsapp_instance` a second time instead of reusing the already-loaded `@instance`

**File:** `app/views/admin/divulgacoes/new.html.erb:120`
**Issue:** `submit_disabled = !@instance.connected? || @client.whatsapp_instance.whatsapp_groups.where(active: true).none?` re-fetches the association instead of using the `@instance` ivar the controller already set.
**Fix:** `@instance.whatsapp_groups.where(active: true).none?`
**Recommendation:** Acceptable to defer — redundant query, not a correctness issue.

### IN-02: `divulgacoes#index` and the `clients#show` mirror card N+1 on `divulgacao_grupos.size` per row

**File:** `app/views/admin/divulgacoes/index.html.erb:47`, `app/views/admin/clients/show.html.erb` (Divulgações card), `app/controllers/admin/divulgacoes_controller.rb:7`
**Issue:** `@client.divulgacoes.includes(:arte)` does not include `:divulgacao_grupos`, so each row's `d.divulgacao_grupos.size` issues a separate query.
**Fix:** `@client.divulgacoes.includes(:arte, :divulgacao_grupos).order(scheduled_for: :desc)`
**Recommendation:** Acceptable to defer — explicitly out of v1 review scope (performance).

### IN-03: `_status_badge.html.erb` and `_grupo_row.html.erb` have no `else`/default branch in their `case` statements

**File:** `app/views/admin/divulgacoes/_status_badge.html.erb`, `app/views/admin/divulgacoes/_grupo_row.html.erb`
**Issue:** Both partials `case` over the enum string with one `when` per known value and no `else`. Currently safe (enum restricts the domain) but silently renders nothing if either enum ever gains a value.
**Fix:** Add a defensive `else` branch rendering a neutral "unknown status" pill.
**Recommendation:** Acceptable to defer — no live path to trigger it today; worth doing opportunistically alongside a future enum change, not blocking.

### IN-04: `@divulgacao ||= ...` in the `RecordNotFound` rescue block is a vestigial/misleading `||=` — `@divulgacao` is provably always `nil` at that point, so it always assigns

**File:** `app/controllers/admin/divulgacoes_controller.rb:80`
**Issue:** Within `create`, `@divulgacao` is only ever assigned (a) inside the early-return guard at line 41 (`@instance.nil? || @approved_artes.empty?`), which `return`s before any code that can raise `RecordNotFound`, or (b) at line 50, after both lines that can raise `RecordNotFound` have already succeeded. There is therefore no code path in which the rescue block is entered with `@divulgacao` already set — the `||=` always behaves like a plain `=`. This isn't a bug (the guard is harmless and correct either way), but it reads as defensive code that implies a scenario ("what if `@divulgacao` was already partially built when this fired?") that cannot actually occur in the current method, which could mislead a future reader/editor of this rescue block.
**Fix:** Either leave as-is (truly harmless) or simplify to `@divulgacao = @client.divulgacoes.new(...)` and drop the `||=` to avoid implying a non-existent code path; if kept, a one-line comment noting "always nil here, `||=` is just defensive" would remove the ambiguity for the next editor.
**Recommendation:** Acceptable to defer — purely cosmetic/clarity, zero behavioral risk. Not introduced by the reviewed fix (pre-existing since fix-pass 1); noted here for completeness since this is the final review pass.

---

## Ship/Defer Summary (final iteration — auto-loop stops here)

- **Must-fix-before-ship:** none. All three original Critical/Warning
  findings (CR-01, CR-02/WR-02, WR-01 + its residual) are confirmed resolved,
  verified both by direct code tracing and by running the full test suite
  (0 failures).
- **Acceptable to defer:** IN-01, IN-02, IN-03, IN-04 — all Info-level,
  non-blocking, none affect correctness, security, or data integrity. IN-02
  is explicitly a performance item (out of v1 review scope per the review
  charter). Safe to ship phase 28 as-is and address these opportunistically
  in a later phase or cleanup pass.

---

_Reviewed: 2026-08-30T21:30:00-03:00_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
