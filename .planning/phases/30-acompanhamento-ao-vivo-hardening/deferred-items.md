# Phase 30 — Deferred Items (out of scope for 30-01)

## Pre-existing test failure — `test/models/arte_test.rb`

**Test:** `ArteTest#test_revised!_broadcast_admin_inclui_replace_do_admin_calendar_chip`
**File:** `test/models/arte_test.rb:94`
**Symptom:** regex `/target="arte_\d+_admin_calendar_chip"/` does not match the actual target
`admin_calendar_chip_arte_1342` — the assertion's expected dom_id ordering
(`arte_N_admin_calendar_chip`) is reversed relative to what `ActionView::RecordIdentifier.dom_id`
actually produces (`admin_calendar_chip_arte_N` — prefix comes first).
**Confirmed pre-existing:** neither `app/models/arte.rb` nor `test/models/arte_test.rb` appear
in any 30-01 commit (`git log --stat` over the 30-01 commit range shows zero touches to either
file). Out of scope per the executor's scope boundary rule — logged here, not fixed.
**Introduced by:** Phase 20 (commit `01d4b08`, "atualizar testes para 5 streams... e 2 streams
admin (arte)"), predates Phase 30 entirely.

## Pre-existing unrelated failures observed during 30-02 full-suite run

Running the full `bin/rails test` suite (not just the divulgacoes controller test file) during
30-02 verification surfaces additional failures in files this plan never touches:

- `ApprovalResponseTest#test_broadcasts_to_admin_inclui_chip_replace_para_o_admin_calendar_chip`
  (`test/models/approval_response_test.rb`) — SAME root cause as the `arte_test.rb` entry above
  (`target="arte_\d+_admin_calendar_chip"` regex vs actual `admin_calendar_chip_arte_N` dom_id
  ordering).
- `ApprovalResponseTest#test_broadcasts_to_admin_nao_dispara_N+1_para_arte.client` — unrelated
  N+1 assertion, `approval_response.rb` not in any 30-02 commit.
- `Admin::DashboardControllerTest#test_sidebar_badge_absent_when_no_change_requested_artes` —
  fails even run alone (`bin/rails test test/controllers/admin/dashboard_controller_test.rb -n
  test_sidebar_badge_absent_when_no_change_requested_artes`), finds a stray
  `span#sidebar-badge` implying a leftover `change_requested` Arte row already present in the
  shared Postgres test database before the test's own setup runs. Neither
  `dashboard_controller.rb` nor its test file are touched by any 30-02 commit
  (`git log -- test/controllers/admin/dashboard_controller_test.rb
  app/controllers/admin/dashboard_controller.rb` — last touch is `b5a774d`, Phase 17).
- `Client::HomeControllerTest#test_summary_strip_não_aparece_quando_não_há_artes_no_mês_corrente`
  and `RackAttackTest#test_60_primeiras_requisições...` — same class of symptom (stray rows /
  shared rate-limit cache state surviving across `bin/rails test` invocations against the real,
  non-ephemeral Postgres test database noted in the `test_db_permission` memory). Neither file
  touched by any 30-02 commit.

**Confirmed pre-existing, not introduced by 30-02:** none of the five files above appear in any
30-01 or 30-02 commit. Consistent with the `test_db_permission` note (sandbox test DB is a real,
persistent Postgres database rather than a per-run ephemeral one) — leftover rows / cache state
from earlier full-suite runs can leak into deterministic-looking assertions in unrelated test
files. Out of scope per the executor's scope boundary rule — logged here, not fixed. The
divulgacoes controller test file itself is green in isolation (48/48) and in the full run.

## Additional pre-existing unrelated failure observed during 30-03 full-suite run

- `Api::V1::Ai::ClientsControllerTest` — three tests (`GET /summary retorna 200...`, `GET
  /summary não inclui artes de outro cliente`, and a third `/summary` variant) return 401
  instead of 200. `app/controllers/api/v1/ai/clients_controller.rb` and its test file are not
  touched by any 30-01/30-02/30-03 commit (`git log` shows last touch is Phase 24, commit
  `f78a155`). Same class of symptom as the other entries above (shared, non-ephemeral Postgres
  test DB — likely a stale/expired API token or leftover auth state from an earlier full-suite
  run). Out of scope per the executor's scope boundary rule — logged here, not fixed.
