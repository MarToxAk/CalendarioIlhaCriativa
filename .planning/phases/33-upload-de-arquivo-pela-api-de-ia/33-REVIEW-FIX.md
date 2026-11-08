---
phase: 33-upload-de-arquivo-pela-api-de-ia
fixed_at: 2026-11-08T00:00:00Z
review_path: .planning/phases/33-upload-de-arquivo-pela-api-de-ia/33-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 33: Code Review Fix Report

**Fixed at:** 2026-11-08
**Source review:** .planning/phases/33-upload-de-arquivo-pela-api-de-ia/33-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (CR-01, WR-01, WR-02, and IN-01 as a docs-only fix; IN-02 and IN-03 were out of scope by instruction)
- Fixed: 4
- Skipped: 0

**Verification environment:** the main checkout (`workflow.use_worktrees=false`, no worktree created), on branch `planning/phase-33-upload-ia`. The local recipe (`tmp/ai_upload_test.sh` plus `tmp/ai_upload_preload.rb`) ran the full `test/controllers/api/v1/ai/artes_controller_test.rb`: 28 runs, 163 assertions, 0 failures, 0 errors. rubocop was clean on both Ruby files. CI is the authority.

## Fixed Issues

### CR-01: `media_file` blank-but-not-`""` bypasses the guard and still returns 500

**Files modified:** `app/controllers/api/v1/ai/artes_controller.rb`, `test/controllers/api/v1/ai/artes_controller_test.rb`
**Commit:** 9c40168
**Applied fix:** `media_file_param_invalid?` now lets through only `nil` and exactly `""`, which are the values Active Storage treats as "no attachment". Everything else that is not an `ActionDispatch::Http::UploadedFile` returns 400 `bad_request`. Added three tests: `" "` in a form, `false` in JSON, and an array. Without the fix, the `false` test errors with `ArgumentError: Could not find or build blob`, and the `" "` test errors as well. With the fix, all three pass. Status: fixed. This is a logic change, so a human should confirm the semantics.

### WR-01: Compensating rescue is not narrow

**Files modified:** `app/controllers/api/v1/ai/artes_controller.rb`, `test/controllers/api/v1/ai/artes_controller_test.rb`
**Commit:** d640123
**Applied fix:** Added `STORAGE_FAILURE_CLASSES` (`IOError`, `SystemCallError`, `ActiveStorage::IntegrityError`, `Aws::Errors::ServiceError`, `Seahorse::Client::NetworkingError`). They are resolved by name with `safe_constantize` at rescue time, because the aws-sdk loads lazily and is absent in test (Disk). The rescue now re-raises unless `storage_failure?(e)` AND the arte is persisted with the attachment; `RecordInvalid` is still re-raised first. The research doc only names `IOError` (used in its stub). The remaining classes come from the reviewer's suggestion and the Disk/S3 services. Added a test where only `ActiveStorage::AnalyzeJob.perform_later` raises a `RuntimeError`: the error propagates (`assert_raises`) and is not mapped to 503. That test fails against the previous broad rescue. Status: fixed: requires human verification (the choice of class list is a judgment call).

### WR-02: `discard_orphan_arte` can leave the arte behind while the API claims "nada foi criado"

**Files modified:** `app/controllers/api/v1/ai/artes_controller.rb`, `test/controllers/api/v1/ai/artes_controller_test.rb`, `docs/api-ia.md`
**Commit:** 9df5785
**Applied fix:** `discard_orphan_arte` returns true only when `destroy` succeeded. A `false` return is logged as an error, and so is a raised exception, and both return false. The 503 `storage_unavailable` keeps its code but its `detail` now depends on the result. If the cleanup worked, it says "nada foi criado". If it failed, it says the arte `##{id}` pode ter ficado criada sem arquivo and tells the caller to check before retrying. `docs/api-ia.md` documents both variants in the error table and the 5.2 error list. The text points to the human, not `GET /artes`, because a pending arte is not listed there. Tests: the existing 503 test now asserts "nada foi criado", and a new test uses `Arte.test_block_destroy = true` to force the cleanup failure. Status: fixed: requires human verification.

### IN-01: Unverifiable claim about a proxy 413 in the docs (docs-honesty only)

**Files modified:** `docs/api-ia.md`
**Commit:** 92af4ad
**Applied fix:** Replaced "Uma resposta 413 sem o envelope JSON vem do proxy, não da API" with a neutral note: "Um limite de tamanho de corpo no caminho até o app pode devolver 413 antes de a API responder. Se a resposta não trouxer o envelope JSON, avise o humano." It no longer asserts the origin.

## Out of Scope (not touched)

- IN-02 (test names and unclosed file handle) and IN-03 (media_type vs. file mismatch note), excluded by instruction. The array case from IN-03 was covered as part of CR-01.

---

_Fixed: 2026-11-08_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
