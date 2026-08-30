# Deferred Items — Phase 26

Out-of-scope issues discovered during plan execution, not fixed per deviation scope-boundary rule.

## 26-03: Pre-existing flaky test — RackAttackTest#test_60_primeiras_requisições_ao_namespace_AI_não_retornam_429

- **File:** `test/integration/rack_attack_test.rb`
- **Found during:** 26-03 Task 2 (running the full `rack_attack_test.rb` suite after adding the webhook throttle)
- **Issue:** The "60 primeiras requisições" test fires 60 sequential `GET /api/v1/ai/artes` requests from a single simulated IP within one test. `throttle("api/ai_by_ip", limit: 30, period: 60)` (added in phase 24, INFAPI-04) throttles by IP independently of the by-key throttle the test name references, so request #31 legitimately hits 429 — the test's premise (60 by-key requests should all pass) doesn't account for the tighter by-IP ceiling.
- **Confirmed pre-existing:** fails in isolation on a clean checkout (`bin/rails test test/integration/rack_attack_test.rb -n "/60 primeiras/"`), unrelated to any file touched by phase 26. Last touched by commit `c81f429` (phase 24).
- **Not fixed:** out of scope for 26-03 (webhook receiver + webhook throttle) per the executor's scope-boundary rule — no file this plan modifies is involved.
