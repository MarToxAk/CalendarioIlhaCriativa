---
phase: 32-divulga-es-na-api-de-ia
reviewed: 2026-11-07T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - config/routes.rb
  - app/controllers/api/v1/ai/divulgacoes_controller.rb
  - app/controllers/api/v1/ai/clients_controller.rb
  - app/serializers/api/v1/ai/divulgacao_serializer.rb
  - app/serializers/api/v1/ai/whatsapp_group_serializer.rb
  - test/controllers/api/v1/ai/divulgacoes_controller_test.rb
  - test/controllers/api/v1/ai/clients_controller_test.rb
  - test/integration/cross_client_isolation_test.rb
findings:
  critical: 2
  warning: 4
  info: 4
  total: 10
  necessity: 0
status: issues_found
---

# Phase 32: Code Review Report

**Reviewed:** 2026-11-07
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

The production code (controllers, serializers, routes) is sound on the points the review was asked to focus on.

- **Tenant isolation:** `create` resolves `arte` through `client.artes.find` and groups through `client.whatsapp_instance.whatsapp_groups.where(active: true).find`. No raw `Model.find` is used for tenant data, and a foreign or inactive id gives a generic 404. `index` is scoped through `client.divulgacoes`. `show` and `cancel` use a global `Divulgacao.find`, which matches the agency-wide key model and D-01/D-04.
- **Input validation:** `permit` before `require` turns Hash/Array scalars into 400. Enum `status` is validated explicitly. The date range is built from day boundaries in the app time zone.
- **N+1:** `index` uses `includes(:divulgacao_grupos)` and the serializer sorts in Ruby, so there is no query per row.
- **Auth:** inherited from `Api::V1::Ai::BaseController`.

The problems are in the tests and in a few input-contract and robustness gaps:

1. Several index tests build dates with `index_day + N`, which on a `TimeWithZone` adds N seconds, not N days. At least four tests will fail. I verified this with ActiveSupport in the project bundle.
2. A bare `assert_no_enqueued_jobs` runs after a setup that attaches Active Storage files, which likely fails about 13 tests.

I could not run the suite (known DB ownership block), so the test findings come from reading the code and checking the Rails and Pagy source in `vendor/bundle`.

## Critical Issues

### CR-01: Index tests use `index_day + N`, which adds seconds, so four tests fail and the ordering/range contract is not proven

**File:** `test/controllers/api/v1/ai/divulgacoes_controller_test.rb:233, 263, 277`
**Issue:** `index_day` is `(Date.current + 10).in_time_zone`, a `TimeWithZone`. `TimeWithZone#+ 1` adds one second, not one day. Running `((Date.current+10).in_time_zone + 1).change(hour: 8)` in the project bundle prints `2026-11-17 08:00:00 -0300`, the same day as `index_day.change(hour: 8)`. The effect on each test:

- **Line 233 ("ordena por scheduled_for crescente"):** `depois` lands on the same day at 08:00, the same instant as `cedo`. The actual order is `[cedo, depois, tarde]` (tie broken by id), but the test expects `[cedo, tarde, depois]`. It fails.
- **Line 263 ("from e to inclui o dia inteiro de to"):** the record meant to be two days later at 12:00 is on day `dia` at 12:00. `from=to=dia` returns three rows, not the expected `[cedo, noite]`. It fails.
- **Lines 277-286 ("aceita so from ou so to"):** `d3` is on the same day as `d1`. `from: dia+1` returns `[]` instead of `[d3]`, and `to: dia` returns `[d1, d3]` instead of `[d1]`. It fails.

**Fix:** Use day arithmetic on dates or durations.
```ruby
# helper
def index_day(offset_days = 0)
  (Date.current + 10 + offset_days).in_time_zone
end

depois = make_divulgacao(..., at: index_day(1).change(hour: 8))
d3 = make_divulgacao(..., at: index_day(2).change(hour: 12))
# or: (index_day + 1.day).change(hour: 8)
```

### CR-02: Bare `assert_no_enqueued_jobs` after a setup that enqueues Active Storage jobs (likely mass failure)

**File:** `test/controllers/api/v1/ai/divulgacoes_controller_test.rb:60, 472` (used by `assert_rejected_without_effects`, so by every 400/404/422 test, about 13 tests)
**Issue:** `assert_no_enqueued_jobs` without a block asserts that the total enqueued-job count is zero. It counts jobs enqueued during `setup`.

- `setup` calls `build_arte_with_file!` twice, which runs `arte.media_file.attach(...)` and `arte.save!`.
- Active Storage enqueues `ActiveStorage::AnalyzeJob` in the attachment's `after_create_commit`. That callback fires in transactional tests.
- `ImageAnalyzer.analyze_later?` is true by default in activestorage 8.1.3.1.
- `ActiveJob::TestHelper` installs the test adapter before `setup` and does not clear it afterward, so the count is not zero.

Every other `assert_no_enqueued_jobs` in the repo, including `admin/divulgacoes_controller_test.rb`, uses the block form for this reason. The cross-client file also uses the block form.

**Fix:** Clear the queue at the end of `setup` and keep the bare assertions, or switch to block form.
```ruby
# end of setup
clear_enqueued_jobs

# or in assert_rejected_without_effects
assert_no_enqueued_jobs do
  assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] { post_divulgacao(body) }
end
```
Apply the same fix to the 401 test at line 60. Without CR-01 and CR-02 fixed, the new suite is red.

## Warnings

### WR-01: Malformed `whatsapp_group_ids` entries are silently dropped, so a send can go to fewer groups than requested

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:102`
**Issue:** `Array(...).map(&:to_i).uniq.reject(&:zero?)` turns `"abc"` into 0 and discards it, and `"12abc"` into 12. A payload such as `["abc", 5]` returns 201 and schedules only group 5, with no error. The admin form can ignore malformed ids because its ids come from checkboxes. An AI client sends free-form JSON and cannot tell that part of its list was ignored. This is an irreversible mass send, and it contradicts the contract that bad ids give a 4xx. If every entry is dropped, the request ends in a 422 about "ao menos um grupo", which hides the cause.
**Fix:** Validate the raw values before the lookup.
```ruby
raw = Array(attrs[:whatsapp_group_ids])
unless raw.all? { |v| v.to_s.match?(/\A\d+\z/) }
  return render_error(code: "bad_request", detail: "whatsapp_group_ids deve conter apenas ids numéricos.", status: :bad_request)
end
gids = raw.map(&:to_i).uniq
```

### WR-02: `page=abc` or `page=0` on the new list endpoints returns 500

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:67`, `app/controllers/api/v1/ai/clients_controller.rb:40` (root cause in `app/controllers/api/v1/ai/base_controller.rb:8`)
**Issue:** `pagy` raises `Pagy::VariableError` for a non-integer or `< 1` `page` (`pagy/shared_methods.rb:11`). The base controller rescues only `Pagy::OverflowError`, so `GET /api/v1/ai/divulgacoes?client_id=1&page=abc` and `page=0` give an unhandled 500. This breaks the 400/404/422 contract these endpoints advertise. The gap already exists in `artes#index`, but the phase adds two more endpoints that hit it.
**Fix:** Add this to `Api::V1::Ai::BaseController`.
```ruby
rescue_from Pagy::VariableError do |e|
  render_error(code: "bad_request", detail: "Parâmetro de paginação inválido.", status: :bad_request)
end
```

### WR-03: The row lock in `cancel` protects only one direction of the cancel/dispatch race

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:81-86` (counterpart: `app/jobs/divulgacoes/dispatch_job.rb:14-17`)
**Issue:** The comment claims a cancel arriving as the dispatch starts will not overwrite the newer status, and `with_lock` handles that half. `DispatchJob#perform` does `reload`, `return if cancelada?`, then `update!(status: :em_andamento)` with no lock and no conditional update. If cancel commits between the job's `reload` and its `update!`, the job overwrites `cancelada` with `em_andamento`. The API has already returned 200 "cancelada", and `SendToGroupJob` (`send_to_group_job.rb:132`) now sees `em_andamento` and sends. The window is small but real. It affects the guarantee of the new cancel endpoint, and the fix belongs in the job.
**Fix:** Make the job's transition atomic.
```ruby
divulgacao.with_lock do
  return if divulgacao.status_cancelada?
  divulgacao.update!(status: :em_andamento) if divulgacao.status_agendada?
end
```

### WR-04: Divulgacao is persisted and the job is enqueued in two separate steps, with no recovery path

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:116-119`
**Issue:** If `perform_later` raises after `save!` (queue or DB unavailable), the client gets a 500 but the row is `agendada` with no dispatch job and nothing will ever send it. The docs tell the agent to check the listing before retrying a timeout, so a blind retry creates a duplicate. The admin controller has the same sequence. The API makes it more likely to matter because callers retry automatically.
**Fix:** Enqueue inside the same transaction and roll back on failure, or rescue the enqueue error and mark or delete the row.
```ruby
Divulgacao.transaction do
  divulgacao.save!
  Divulgacoes::DispatchJob.set(wait_until: divulgacao.scheduled_for).perform_later(divulgacao)
end
```
If the queue is DB-backed (Solid Queue), this gives atomicity directly.

## Info

### IN-01: `scheduled_for` without an offset is accepted and read in the app time zone

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:106`
**Issue:** The docs say the value "deve ser" ISO 8601 with an explicit offset, but `"2026-11-05T14:00:00"` or `"2026-11-05"` is accepted and interpreted as America/Sao_Paulo. An AI agent in another zone gets a silently shifted send time. D-07's rationale was to avoid this.
**Fix:** Optionally require an offset, for example `/(Z|[+-]\d{2}:?\d{2})\z/`, and return 422 or 400 otherwise.

### IN-02: `Date.iso8601` is more lenient than the documented `YYYY-MM-DD`

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:163`
**Issue:** It also accepts `20261105`, `2026-W45` and `2026-309`. This is harmless but differs from the documented contract.
**Fix:** Pre-check with `/\A\d{4}-\d{2}-\d{2}\z/` or document the leniency.

### IN-03: No cap on the size of `whatsapp_group_ids`

**File:** `app/controllers/api/v1/ai/divulgacoes_controller.rb:102-103`
**Issue:** An arbitrarily large array becomes one `IN (...)` query and the same number of `divulgacao_grupos` rows. The key is trusted and throttled at 60 requests per minute, so this is a robustness matter only.
**Fix:** Reject more than a sane maximum, for example 200, with a 400.

### IN-04: `ai_headers` in the cross-client test mutates `ENV` lazily and shares state with the teardown through an ivar flag

**File:** `test/integration/cross_client_isolation_test.rb:218-220, 304-312`
**Issue:** `@ai_key_saved` makes the teardown correct, but a test that never calls `ai_headers` is left to a separate teardown that no-ops. The pattern is fragile compared with the setup/teardown pair in `divulgacoes_controller_test.rb`. Also, `Rails.application.credentials.dig(:api, :ai_key)` takes precedence over `ENV["AI_API_KEY"]` in `authenticate_ai_key!`, so every API test in the repo assumes the credentials key is unset in test.
**Fix:** Move the ENV save and set into `setup` (the file already defines `def setup`) and restore it in the existing teardown.

---

_Reviewed: 2026-11-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
