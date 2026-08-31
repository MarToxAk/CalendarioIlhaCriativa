---
phase: 28-divulga-o-agendar-sem-enviar
reviewed: 2026-08-31T00:03:03Z
depth: standard
files_reviewed: 26
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
  critical: 2
  warning: 2
  info: 3
  total: 7
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-08-31T00:03:03Z
**Depth:** standard
**Files Reviewed:** 26 (+ 5 test files audited for coverage gaps)
**Status:** issues_found

## Summary

The cross-client isolation boundary (SEG-01/SEG-02) is genuinely solid: every
finder is scoped through `@client`, the DIVU-09 frozen snapshot is proven to
survive a post-create rename/deactivate, the caption preview is properly
ERB-auto-escaped with no `raw`/`html_safe`/`sanitize` anywhere, the DIVU-03
`caption_only` carve-out is correctly scoped to `external_url` only, the media
ceiling check is correctly guarded on `media_file.attached?`, and there is
zero send/dispatch code anywhere in the phase's files (confirmed by grep). The
three Stimulus controllers are network-free and use `textContent` exclusively
— no DOM XSS surface.

However, two reproducible correctness bugs were found by exercising the code
directly (not just reading it), both concrete enough to demonstrate with a
failing test run against the actual app:

1. **`Divulgacao#cancelar!` cannot cancel a divulgação once its `scheduled_for`
   time has passed** — the single most realistic moment an admin would want
   to cancel (at or after the scheduled send time, before phase 29's engine
   has run). `update(status: :cancelada)` re-runs the full validation set,
   including `scheduled_for_no_futuro`, which now rejects the very record
   being cancelled.
2. **Malformed (but authenticated, admin-submitted) `whatsapp_group_ids` /
   `arte_id` param shapes crash `#create` with an unhandled 500** instead of
   the graceful re-render the plan explicitly requires ("never a 500"). The
   `rescue ActiveRecord::RecordNotFound` clause does not catch the
   `NoMethodError` / `ActiveRecord::AssociationTypeMismatch` that a
   Hash-shaped or multi-valued param actually raises.

Both were reproduced against the running app (see Fix sections for the exact
repro). Two further Warnings and three Info items are below.

## Critical Issues

### CR-01: `Divulgacao#cancelar!` fails once `scheduled_for` is in the past — the cancel feature is broken for its most important use case

**File:** `app/models/divulgacao.rb:43-46` (interacts with `app/models/divulgacao.rb:58-61`)
**Issue:**

```ruby
def cancelar!
  return false unless status_agendada?
  update(status: :cancelada)
end
```

`update` re-runs **every** validation on the record, including:

```ruby
def scheduled_for_no_futuro
  return if scheduled_for.blank?
  errors.add(:base, "A data e hora do envio precisam estar no futuro.") if scheduled_for <= Time.current
end
```

Once `scheduled_for` has elapsed — which happens for every single divulgação,
often within minutes of creation, and is *exactly* the window in which an
admin would most want to cancel one before phase 29's send engine picks it up
— `cancelar!` silently returns `false`. The controller then shows the
misleading alert "Só é possível cancelar uma divulgação ainda agendada."
(*"Only possible to cancel a divulgação still scheduled"*) even though the
record's status genuinely is `agendada`; the admin has no way to know the
real cause is a validation collision, and **no way to cancel the record at
all** through the UI from that point forward. This also silently sets up a
landmine for phase 29: any status transition it performs at or after
`scheduled_for` (e.g. `agendada → em_andamento`) will hit the exact same
`update` → re-validate → reject failure mode, since sends by definition
happen at/after the scheduled time.

Reproduced directly (not just read) via a Rails test:
```
d = client.divulgacoes.create!(arte:, scheduled_for: 2.seconds.from_now, divulgacao_grupos: [...])
sleep 3
d.cancelar!            # => false
d.errors.full_messages # => ["A data e hora do envio precisam estar no futuro."]
d.reload.status         # => "agendada"  (never changed)
```
The existing test suite never catches this because every `cancelar!` test
(`test/models/divulgacao_test.rb:204-223`,
`test/controllers/admin/divulgacoes_controller_test.rb:511-535`) uses
`scheduled_for: 3.days.from_now`, so `scheduled_for_no_futuro` never fires
during the `update`.

**Fix:** Skip the creation-time validations on the cancel transition — either
scope `scheduled_for_no_futuro` (and any other validation that should only
gate creation) to `on: :create`, or bypass validation explicitly in
`cancelar!`:

```ruby
# Option A — scope the validation (also protects phase 29's future status updates)
validate :scheduled_for_no_futuro, on: :create

# Option B — bypass validation for this specific, narrowly-guarded transition
def cancelar!
  return false unless status_agendada?
  update_column(:status, self.class.statuses[:cancelada]) && (updated_at_will_change!; touch)
  # simpler: update(status: :cancelada); but skip validation:
  self.status = :cancelada
  save(validate: false)
end
```
Option A is preferable — it also protects phase 29's engine from hitting the
same wall when it transitions `agendada → em_andamento → concluida` at/after
`scheduled_for`. Add a regression test that cancels a divulgação whose
`scheduled_for` has already elapsed.

### CR-02: Malformed `whatsapp_group_ids` / `arte_id` param shapes crash `#create` with an unhandled 500 instead of the required graceful re-render

**File:** `app/controllers/admin/divulgacoes_controller.rb:46-48`
**Issue:**

```ruby
arte   = @client.artes.find(params.dig(:divulgacao, :arte_id))
gids   = Array(params.dig(:divulgacao, :whatsapp_group_ids)).map(&:to_i).uniq.reject(&:zero?)
groups = scoped_active_groups.find(gids)
```

Only `ActiveRecord::RecordNotFound` is rescued (line 69). Two param shapes
that a browser devtools edit, a buggy client, or a hand-crafted request can
trivially produce raise a *different* exception that is **not** rescued,
producing a bare 500:

1. `divulgacao[whatsapp_group_ids][foo]=1` (Hash instead of Array) →
   `Array(hash_like_object)` wraps the single `ActionController::Parameters`
   object in a one-element array, then `.map(&:to_i)` calls `#to_i` on an
   `ActionController::Parameters` instance → `NoMethodError`.
2. `divulgacao[arte_id][]=1&divulgacao[arte_id][]=2` (two valid ids for the
   `arte_id` field, normally a scalar) → `@client.artes.find([1,2])` returns
   an `Array` of two `Arte` records → `@client.divulgacoes.new(arte: [...])`
   → `ActiveRecord::AssociationTypeMismatch`.

Both were reproduced end-to-end with real `post` requests against the app
(HTTP 500 / unhandled exception surfaced to Rails' error page), e.g.:
```
NoMethodError: undefined method `to_i' for an instance of ActionController::Parameters
    app/controllers/admin/divulgacoes_controller.rb:47:in `map'
```
```
ActiveRecord::AssociationTypeMismatch: Arte(#26240) expected, got [...] which is an instance of Array
    app/controllers/admin/divulgacoes_controller.rb:50:in `create'
```
This directly contradicts the phase's own explicit design contract (plan
28-01, must_haves: "...never a 500") and the general principle that no
authenticated-but-malformed request should crash the app rather than
returning a clean 4xx/re-render. It's low-effort to trigger (edit a form
field's `name` attribute in devtools, or replay/tamper a captured request)
and needs no special privilege beyond the existing admin session.

**Fix:** Normalize/guard the param shapes before using them, and widen the
rescue to the exception classes that can legitimately arise from malformed
input:

```ruby
raw_gids = params.dig(:divulgacao, :whatsapp_group_ids)
gids = Array(raw_gids).map { |v| v.to_s.to_i }.uniq.reject(&:zero?) if raw_gids.is_a?(Array) || raw_gids.nil?
gids ||= []  # a Hash-shaped submission is simply treated as "no valid ids"

arte_id = params.dig(:divulgacao, :arte_id)
arte_id = nil unless arte_id.is_a?(String) || arte_id.is_a?(Integer)
arte = @client.artes.find(arte_id)
```
or, more defensively, keep the existing logic but widen the rescue:
```ruby
rescue ActiveRecord::RecordNotFound, ActiveRecord::AssociationTypeMismatch, NoMethodError, TypeError
  ...
```
The explicit param-shape guard is preferable to a broad rescue, since a
broad `rescue NoMethodError` risks silently swallowing unrelated bugs in the
same method. Add controller tests for both param shapes (Hash-shaped
`whatsapp_group_ids`, Array-shaped `arte_id`) asserting a graceful
`:unprocessable_entity` re-render, not a 500.

## Warnings

### WR-01: On the `RecordNotFound` rescue path, the form silently resets — all previously-entered values are lost, unlike the model-validation-failure path

**File:** `app/controllers/admin/divulgacoes_controller.rb:69-77`
**Issue:** When a normal model validation fails (e.g. arte not approved,
file over the ceiling), `@divulgacao` is the object built with the admin's
submitted `arte`/`scheduled_for`/groups, so the re-rendered form retains
those choices. But when `ActiveRecord::RecordNotFound` is raised (foreign or
inactive arte/group id — the case this rescue exists specifically to
handle), `@divulgacao ||= @client.divulgacoes.new` builds a **blank** record:
no arte selected, no datetime, no groups checked. The admin has to redo the
entire form from scratch after what is often just a stale-selection race
(e.g. a group deactivated by a phase-27 sync between form load and submit),
even though the *other* fields they filled in (datetime, still-valid groups)
were perfectly fine.
**Fix:** Preserve what's still resolvable before re-rendering, e.g. assign
the raw `scheduled_for` string back onto the fresh record, and re-select only
the group ids that *did* resolve successfully:
```ruby
rescue ActiveRecord::RecordNotFound
  @divulgacao ||= @client.divulgacoes.new(scheduled_for: params.dig(:divulgacao, :scheduled_for))
  load_form_collections
  flash.now[:alert] = "..."
  render :new, status: :unprocessable_entity
end
```

### WR-02: `arte_id` / `whatsapp_group_ids` are read via ad-hoc `params.dig` calls instead of a strong-params allowlist, deviating from the plan's documented (and safer-by-convention) approach with no test coverage of the deviation

**File:** `app/controllers/admin/divulgacoes_controller.rb:46-53`
**Issue:** The plan explicitly calls for a strong-params helper permitting
only `:arte_id, :scheduled_for, whatsapp_group_ids: []`. The shipped code
instead reads each value individually via `params.dig(:divulgacao, :field)`.
Functionally this avoids classic mass-assignment (attributes are set
explicitly, not via a permitted hash passed to `.new`), so it isn't a
security hole by itself — but it's also the direct root cause of CR-02: a
strong-params `.permit(whatsapp_group_ids: [])` call would have coerced a
Hash-shaped submission into an empty/stripped array (Rails silently drops
non-array values for an array-typed permit) rather than passing the raw
`ActionController::Parameters` straight into `Array()`/`.map(&:to_i)`.
**Fix:** Adopt the documented strong-params pattern:
```ruby
def divulgacao_params
  params.require(:divulgacao).permit(:arte_id, :scheduled_for, whatsapp_group_ids: [])
end
```
and read `divulgacao_params[:whatsapp_group_ids]` — this closes CR-02's Hash
case for free and matches the plan's own threat model (T-28-03).

## Info

### IN-01: `new.html.erb` queries `@client.whatsapp_instance` a second time instead of reusing the already-loaded `@instance`

**File:** `app/views/admin/divulgacoes/new.html.erb:120`
**Issue:** `submit_disabled = !@instance.connected? || @client.whatsapp_instance.whatsapp_groups.where(active: true).none?` re-fetches the association instead of using the `@instance` ivar the controller already set, issuing a redundant query and slightly obscuring that both halves of the condition refer to the same instance.
**Fix:** `@instance.whatsapp_groups.where(active: true).none?`

### IN-02: `divulgacoes#index` and the `clients#show` mirror card N+1 on `divulgacao_grupos.size` per row

**File:** `app/views/admin/divulgacoes/index.html.erb:47`, `app/views/admin/clients/show.html.erb` (Divulgações card)
**Issue:** `@client.divulgacoes.includes(:arte)` does not include `:divulgacao_grupos`, so each row's `d.divulgacao_grupos.size` issues a separate query. Out of this review's stated performance scope, but flagged since it's a one-line fix.
**Fix:** `@client.divulgacoes.includes(:arte, :divulgacao_grupos).order(scheduled_for: :desc)`

### IN-03: `_status_badge.html.erb` and `_grupo_row.html.erb` have no `else`/default branch in their `case` statements

**File:** `app/views/admin/divulgacoes/_status_badge.html.erb`, `app/views/admin/divulgacoes/_grupo_row.html.erb`
**Issue:** Both partials `case` over the enum string with one `when` per known value and no `else`. Currently safe because the enum restricts the domain, but if either enum ever gains a value (or a value is passed in from a differently-typed source) the partial silently renders nothing rather than a fallback pill — a bit fragile for a state that already had one near-miss in this phase (`_status_badge.html.erb` and `DivulgacaoGrupo`'s status vocabulary are separate enums with overlapping-looking names, `pendente`/`concluida` both appear as one enum's "neutral" value and the other's active value).
**Fix:** Add a defensive `else` branch rendering a neutral "unknown status" pill, at least as a canary for a future enum-vocabulary drift.

---

_Reviewed: 2026-08-31T00:03:03Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
