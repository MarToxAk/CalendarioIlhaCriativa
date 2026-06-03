---
phase: 09-calendar-summary-strip
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - app/controllers/client/home_controller.rb
  - app/views/client/home/index.html.erb
  - test/controllers/client/home_controller_test.rb
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-06-03T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Review covers the calendar summary strip feature added in phase 09: the `@summary` hash computation in `Client::HomeController#index`, the inline chip strip in `index.html.erb`, and the new test cases in `home_controller_test.rb`.

The core logic is correct — `@summary` is computed in-memory from the already-scoped `@artes` relation, the month/year filter correctly excludes overflow grid days, and `revised` is grouped with `pending` per spec. The view guard `@summary[:total] > 0` is sound.

One blocker exists: the `parse_month_param` rescue clause does not cover `TypeError`, which is raised when a caller submits `month[]= ` (an array parameter), causing an unhandled 500. Two warnings: a subtle test coverage gap where the cross-month isolation test never exercises the Ruby-level filter, and weak regex assertions in the new test cases that could pass spuriously. One info item: a magic-number `.count` chain that could be collapsed.

---

## Critical Issues

### CR-01: `parse_month_param` does not rescue `TypeError` — array param causes 500

**File:** `app/controllers/client/home_controller.rb:38`

**Issue:** `rescue Date::Error` only catches `Date::Error` (a subclass of `ArgumentError`). When a request supplies `month[]=2026-01` (an array-style query parameter), Rails sets `params[:month]` to an `Array`. `Array#present?` returns `true` for a non-empty array, so the guard at line 36 passes. `Date.strptime` then receives an Array and raises `TypeError: no implicit conversion of Array into String`, which is **not** caught by `rescue Date::Error`. The result is an unhandled exception and a 500 response.

Verified in project Ruby environment:
```
Date.strptime([], '%Y-%m')   # => TypeError (not Date::Error)
['a'].present?               # => true
```

**Fix:** Widen the rescue clause to cover `TypeError` as well, or coerce the param to a String before parsing:

```ruby
def parse_month_param
  return Date.today.beginning_of_month unless params[:month].present?
  Date.strptime(params[:month].to_s, "%Y-%m").beginning_of_month
rescue Date::Error, TypeError
  Date.today.beginning_of_month
end
```

Using `.to_s` is the simpler defence: `Array#to_s` produces something like `'["2026-01"]'` which `strptime` cannot parse, so `Date::Error` is raised and caught cleanly. Alternatively keep the explicit rescue of both exception classes.

The existing test at line 44–48 only covers the `"abc"` string case and does not catch this path — see WR-02.

---

## Warnings

### WR-01: Cross-month isolation test does not exercise the Ruby-level month filter

**File:** `test/controllers/client/home_controller_test.rb:86-98`

**Issue:** The test "summary strip conta apenas artes do mês corrente, excluindo outros meses" creates an arte at `other_month = (Date.today - 2.months).beginning_of_month`. Because that date is approximately 60+ days before `grid_start` (the Monday containing the 1st of the current month), the arte is **never fetched from the database** by the `WHERE scheduled_on BETWEEN grid_start AND grid_end` query. `@artes` simply does not contain it.

The test therefore validates the DB-level `WHERE` range filter, not the `artes_do_mes.select { |a| a.scheduled_on.month == ... }` Ruby filter on line 19–22. If the Ruby filter were accidentally removed or broken, this test would still pass.

The genuine risk is an arte that falls within the grid window (e.g., the last days of the previous month when `beginning_of_month.beginning_of_week` extends back) being incorrectly counted in `@summary`. No test covers that boundary case.

**Fix:** Add a complementary test that places an arte on a grid-overflow day from the previous month (i.e., a day in `grid_start..current_month.beginning_of_month - 1.day`) and asserts it is excluded from `@summary[:total]`:

```ruby
test "summary strip exclui artes de dias de overflow do grid anterior ao mês" do
  # Find a day that falls in the grid but belongs to the prior month
  grid_start = Date.today.beginning_of_month.beginning_of_week
  overflow_day = grid_start  # Monday before the 1st; belongs to previous month
  # Skip test if there is no overflow (month starts on Monday)
  skip "sem overflow neste mês" if overflow_day == Date.today.beginning_of_month

  Arte.create!(client: @client, scheduled_on: overflow_day,
               platform: :instagram, media_type: :caption_only,
               external_url: "https://example.com/overflow")
  sign_in_as_client(@client)
  get client_root_path(token: @client.access_token)
  assert_response :success
  assert_no_match(/role="status"/, response.body)  # No artes in current month
end
```

### WR-02: Test regex assertions can produce false positives for count values

**File:** `test/controllers/client/home_controller_test.rb:83,97,107,120,130`

**Issue:** Several assertions use patterns like `/2.*total/m` and `/1.*total/m` to verify count chips. Because `.*` is greedy and the `/m` flag makes `.` match newlines, these regexes match any HTML containing the digit anywhere before the word "total" — including "12 total", "21 total", "10 total". Specifically:

- `/2.*total/m` would match if there were 12 or 20 artes, not just 2.
- `/1.*total/m` would match if there were 10, 11, 21, or any count containing `1`.

Additionally, the test at line 44–48 ("parâmetro month inválido não causa erro 500") only covers a plain invalid string (`"abc"`). It does not cover the array parameter path that triggers the `TypeError` described in CR-01.

**Fix for count assertions:** Use a more precise pattern that matches the exact digit wrapped in the `<span>` tag the view produces:

```ruby
# Instead of:
assert_match(/2.*total/m, response.body)

# Use:
assert_match(/<span class="font-semibold">2<\/span> total/, response.body)
```

**Fix for array-param test:** Add a test for the missing coverage:

```ruby
test "parâmetro month como array não causa erro 500 (CR-01)" do
  sign_in_as_client(@client)
  get client_root_path(token: @client.access_token, month: ["2026-01"])
  assert_response :success
end
```

---

## Info

### IN-01: Four sequential `.count { |a| ... }` passes over the same array

**File:** `app/controllers/client/home_controller.rb:23-28`

**Issue:** The `@summary` hash is built with four separate iteration passes over `artes_do_mes` (`.count`, `.count { ... }`, `.count { ... }`, `.count { ... }`). This is not a performance blocker (the array is already in memory and at most a few hundred elements), but it is slightly inconsistent with the Ruby idiom for this kind of grouped counting and makes the intent harder to read at a glance.

**Fix (optional):** Replace with a single `each_with_object` pass or use `tally`/`group_by`:

```ruby
counts = artes_do_mes.each_with_object(Hash.new(0)) do |a, h|
  s = a.status.to_s
  h[:approved]         += 1 if s == "approved"
  h[:pending]          += 1 if %w[pending revised].include?(s)
  h[:change_requested] += 1 if s == "change_requested"
end
@summary = {
  total:            artes_do_mes.count,
  approved:         counts[:approved],
  pending:          counts[:pending],
  change_requested: counts[:change_requested]
}
```

This is a readability suggestion only; the current code is correct.

---

_Reviewed: 2026-06-03T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
