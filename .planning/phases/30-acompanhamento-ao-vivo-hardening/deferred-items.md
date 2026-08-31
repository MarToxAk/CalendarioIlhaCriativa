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
