---
phase: 16-feriados-brasileiros
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - app/helpers/application_helper.rb
  - app/lib/brazilian_holidays.rb
  - app/views/admin/calendar/_calendar_grid.html.erb
  - app/views/client/home/_month_calendar.html.erb
  - test/controllers/admin/calendar_controller_test.rb
  - test/controllers/client/home_controller_test.rb
  - test/lib/brazilian_holidays_test.rb
findings:
  critical: 0
  warning: 4
  info: 2
  total: 6
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-06-04
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

This phase adds a `BrazilianHolidays` static lookup module and wires it into both the admin and client calendar views via a `brazilian_holiday_for` helper. The holiday data is correct for all three years (dates cross-checked algorithmically: Easter-derived dates, Carnaval, Corpus Christi, Black Friday, Dia das Mães, and Dia dos Pais all verify). The integration is simple and safe.

Four warnings were found: a `Date.today` / `Time.zone.today` split between the two controllers that will misfire at midnight in non-UTC deployments, a missing N+1 guard for Active Storage attachments in the admin controller, and two blocks of duplicate tests that inflate the test suite without adding coverage. Two informational items cover a data scope cliff and a mislabeled holiday name.

No critical issues were found.

---

## Warnings

### WR-01: `Date.today` in `Client::HomeController` ignores application timezone

**File:** `app/controllers/client/home_controller.rb:36,39`
**Issue:** `parse_month_param` falls back to `Date.today.beginning_of_month`. `Date.today` always returns the system (OS) date, not the Rails application timezone set in `config/time_zone`. The admin controller correctly uses `Time.zone.today` (lines 24 and 27). In any deployment where the server timezone differs from the configured Rails timezone — or if the app is ever set to a Brazilian timezone (UTC-3) — this divergence will produce wrong month boundaries and a mismatched "today" highlight for clients viewing the calendar around midnight. The same bug exists in the view at `_month_calendar.html.erb:16` where `Date.today` is used to highlight the current day, while the admin grid at `_calendar_grid.html.erb:14` correctly uses `Time.zone.today`.

**Fix:**
```ruby
# app/controllers/client/home_controller.rb, lines 36 and 39
def parse_month_param
  return Time.zone.today.beginning_of_month unless params[:month].present?
  Date.strptime(params[:month], "%Y-%m").beginning_of_month
rescue Date::Error
  Time.zone.today.beginning_of_month
end
```
```erb
<%# app/views/client/home/_month_calendar.html.erb, line 16 %>
<% if date == Time.zone.today %>
```

---

### WR-02: N+1 Active Storage query in admin calendar grid

**File:** `app/controllers/admin/calendar_controller.rb:13-15`
**Issue:** The admin calendar controller eager-loads `:client` but not the `media_file` Active Storage attachment. The partial at `_calendar_grid.html.erb:36-43` calls `arte.media_file.attached?` and `arte.media_file.content_type` for every visible arte chip. With no attachment eager-load, each arte that has a file attached fires two additional SQL queries (`active_storage_attachments` and `active_storage_blobs`). The client controller already handles this correctly with `.includes(media_file_attachment: :blob)`.

**Fix:**
```ruby
# app/controllers/admin/calendar_controller.rb, line 13
@artes = Arte.where(scheduled_on: grid_start..grid_end)
             .includes(:client, media_file_attachment: :blob)
             .order(:id)
```

---

### WR-03: Duplicate authenticated/unauthenticated tests in `Admin::CalendarControllerTest`

**File:** `test/controllers/admin/calendar_controller_test.rb:21-69`
**Issue:** Four test cases added in a comment-noted "plano 14-03" batch are exact semantic duplicates of four tests that already exist at lines 21-40:
- `"GET /admin/calendar retorna 200 quando autenticado"` (line 21) duplicates `"test_returns_200_when_authenticated"` (line 44)
- `"GET /admin/calendar redireciona quando nao autenticado"` (line 26) duplicates `"test_redirects_when_unauthenticated"` (line 49)
- `"GET /admin/calendar com parametro month valido retorna 200"` (line 32) duplicates `"test_navigates_to_specific_month"` (line 61)
- `"GET /admin/calendar com parametro month invalido retorna 200 sem 500"` (line 37) duplicates `"test_invalid_month_param_does_not_crash"` (line 66)

Because Rails generates distinct method names from these different string descriptions, both sets run and pass, but they provide zero additional coverage. This inflates the test run time and creates confusion about which tests are authoritative.

**Fix:** Remove the older four tests (lines 21-40) and keep the semantically equivalent, better-named block from the 14-03 batch, or vice versa. Do not keep both.

---

### WR-04: `BrazilianHolidays` data coverage silently drops after 2027

**File:** `app/lib/brazilian_holidays.rb:62-64`
**Issue:** `BrazilianHolidays.for(year)` returns `{}` for any year outside `{2025, 2026, 2027}`. The views treat a `nil` return (hash miss) as "no holiday" and render nothing, which is the correct silent fallback. However, when the calendar is navigated to January 2028 or beyond, national holidays like Ano Novo, Tiradentes, Independência, etc. will silently disappear from the UI without any error. Given that the system is already in 2026 and users may navigate to 2028 within the product's lifetime, this is a near-term correctness gap for known fixed-date national holidays.

**Fix:** Extract the fixed Brazilian national holidays (those that never change date: Ano Novo, Tiradentes, Dia do Trabalho, Independência, Ap./Crianças, Finados, Proclamação da República, Natal) into a `FIXED_HOLIDAYS` constant and compute them dynamically for any year. Reserve the year-keyed hash only for the moveable feasts. Example sketch:

```ruby
FIXED_HOLIDAYS = {
  [1,  1]  => "Ano Novo",
  [4,  21] => "Tiradentes",
  [5,  1]  => "Dia do Trabalho",
  [9,  7]  => "Independência",
  [10, 12] => "Ap. / Crianças",
  [11, 2]  => "Finados",
  [11, 15] => "Rep. da República",
  [12, 25] => "Natal",
}.freeze

def self.for(year)
  base = FIXED_HOLIDAYS.transform_keys { |m, d| Date.new(year, m, d) }
  base.merge(MOVEABLE.fetch(year, {}))
end
```

---

## Info

### IN-01: "Rep. da República" is an abbreviation of a formal holiday name

**File:** `app/lib/brazilian_holidays.rb:18,36,55`
**Issue:** The November 15th holiday is officially "Proclamação da República". The display string "Rep. da República" is truncated to fit the calendar cell (the `truncate(holiday, length: 15)` call in the views would trim "Proclamação da República" to "Proclamação da …"). The abbreviation works around the display limit but obscures the holiday's identity. The `truncate` helper is already in place, so the full name could be stored in the module and the truncation left to the view, which is already designed for it.

**Fix:** Use the full official name: `"Proclamação da República"`. The view's `truncate(holiday, length: 15)` call will display `"Proclamação da…"` which is already more recognizable than `"Rep. da República"`.

---

### IN-02: `BrazilianHolidaysTest` does not assert the `for` method returns a frozen hash

**File:** `test/lib/brazilian_holidays_test.rb`
**Issue:** The test file checks presence, specific keys, and nil return, but does not verify that the returned hash is frozen. The inner hashes are individually frozen (`.freeze`), and the outer `HOLIDAYS` constant is also frozen. However, `BrazilianHolidays.for(year)` returns the inner hash directly via `HOLIDAYS.fetch(year, {})`, meaning a caller can modify the returned hash in-place (e.g., `BrazilianHolidays.for(2026)[Date.new(2026, 1, 1)] = "mutated"`), which would corrupt the constant for the lifetime of the process.

**Fix:** Either add a test asserting the returned hash is frozen, or protect `for` by returning a dup:
```ruby
def self.for(year)
  HOLIDAYS.fetch(year, {}).dup
end
```
Note that each inner hash is already `.freeze`d, so `fetch` returns the frozen hash — in practice Ruby will raise `FrozenError` if any caller tries to mutate it. The current behavior is therefore safe in practice, but it is worth a test assertion to document the contract explicitly.

---

_Reviewed: 2026-06-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
