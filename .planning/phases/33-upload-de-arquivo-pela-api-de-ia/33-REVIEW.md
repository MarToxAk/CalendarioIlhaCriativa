---
phase: 33-upload-de-arquivo-pela-api-de-ia
reviewed: 2026-11-08T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - app/controllers/api/v1/ai/artes_controller.rb
  - test/controllers/api/v1/ai/artes_controller_test.rb
  - docs/api-ia.md
findings:
  critical: 1
  warning: 2
  info: 3
  total: 6
  necessity: 0
status: issues_found
---

# Phase 33: Code Review Report

**Reviewed:** 2026-11-08
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the multipart upload on `POST /api/v1/ai/artes`, its tests and `docs/api-ia.md` against decisions D-01..D-12.
The structure is sound. D-02 is preserved: the controller never clears `external_url`, so file plus link gives 422 from
the model. The error envelope and the `field: "media_file"` mapping are correct. Tests use the block form of
`assert_no_enqueued_jobs`, and multipart tests omit the JSON `Content-Type`. There is no cross-tenant path, because the
key is agency-wide and `client_id` is validated by the model.

The guard for non-UploadedFile `media_file` has a hole. Two blank-but-not-empty-string values bypass it and still
produce a 500, which is the failure mode the guard exists to prevent. The compensating rescue is broader than its
comments claim. Local tests were not run (the test DB is unavailable locally, per project notes); findings come from
reading the code and the installed activestorage 8.1.4.1 source.

## Critical Issues

### CR-01: `media_file` blank-but-not-`""` (`" "`, `false`) bypasses the guard and still returns 500

**File:** `app/controllers/api/v1/ai/artes_controller.rb:89-92`
**Issue:** `media_file_param_invalid?` uses `value.present?`, so any value for which `blank?` is true is treated as
"absent" and let through to `Arte.new(arte_params)`. But the Active Storage setter (`activestorage-8.1.4.1/lib/active_storage/attached/model.rb:118-125`)
only treats `nil` and exactly `""` as "no attachment". Everything else goes to `CreateOne.new`, whose initializer
calls `blob.identify_without_saving` and so runs `find_or_build_blob` immediately:

- `media_file=" "` (or `"\n"`, `"\t"`), form or JSON: `" ".blank?` is true, the guard passes, and the String branch
  calls `Blob.find_signed!(" ")`. That raises `ActiveSupport::MessageVerifier::InvalidSignature`, an unhandled 500 from `Arte.new`
  (this call is outside the `begin/rescue`).
- `{"media_file": false}` (JSON): `false.present?` is false, `permit` accepts the boolean scalar, the setter reaches the
  `else` branch and raises `ArgumentError "Could not find or build blob: expected attachable, got false"`. Also a 500.

The comment on line 88 ("valor em branco segue como ausente") promises exactly the case that fails. No test covers either
value; the 400 tests only use `"abc"`, a Hash and a signed id.

**Fix:** Only `nil` and `""` are safe to pass through; reject everything else that is not an upload.
```ruby
def media_file_param_invalid?
  value = params[:media_file]
  return false if value.nil? || value == ""

  !value.is_a?(ActionDispatch::Http::UploadedFile)
end
```
`{}` and `[]` are dropped by `permit`, so they remain harmless. Add tests for `media_file: " "` (form) and
`media_file: false` (JSON) expecting 400 with `assert_rejected_without_effects`.

## Warnings

### WR-01: Compensating rescue is not narrow; it classifies any post-persist `StandardError` as a storage failure

**File:** `app/controllers/api/v1/ai/artes_controller.rb:59-71`
**Issue:** The condition `@arte.persisted? && @arte.media_file.attached?` is true for any exception raised after
commit, not only a failed upload. `after_commit` callbacks include more than `upload`. `ActiveStorage::Attachment` runs
`after_create_commit :mirror_blob_later, :analyze_blob_later, :transform_variants_later` (attachment.rb:36), all of
which enqueue jobs. A queue outage (for example a failed `perform_later`) during commit would match the rescue, delete
the arte, answer `503 storage_unavailable` ("não foi possível gravar o arquivo") and log a misleading cause. If the
queue is down, the `purge_later` enqueued by `destroy` also fails, so the blob row and possibly the already-uploaded
S3 object are orphaned. The 503 contract the docs promise ("nada foi criado") also rests on this classification being right.
`RecordInvalid` is correctly re-raised first, so validation errors are not masked; the issue is only the width of the
second clause.
**Fix:** Rescue the storage error types explicitly instead of `StandardError`, for example
`rescue IOError, SystemCallError, ActiveStorage::IntegrityError, Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e`,
keeping `raise unless @arte.persisted? && @arte.media_file.attached?`. Alternatively, re-raise anything whose
backtrace does not include `ActiveStorage::Attached::Changes::CreateOne#upload`. Add a test where only job enqueue
raises, to pin the intended behavior.

### WR-02: `discard_orphan_arte` can leave the arte behind while the API claims "nada foi criado"

**File:** `app/controllers/api/v1/ai/artes_controller.rb:96-100`
**Issue:** `@arte.destroy` returns `false` (not an exception) when a `before_destroy` aborts, and it can raise. The `false`
return is neither logged nor handled. A raised error is only logged. In both cases the 503 body and `docs/api-ia.md`
still say "nada foi criado e é seguro tentar de novo", and a retry then creates a duplicate arte, the exact outcome the
design (T-33-05) aims to avoid. The tests force only the success path of the cleanup.
**Fix:** Check the result and make the response honest when cleanup fails:
```ruby
def discard_orphan_arte
  return true if @arte.destroy
  Rails.logger.error("[ai/artes#create] arte órfã ##{@arte.id} não removida")
  false
rescue StandardError => e
  Rails.logger.error("[ai/artes#create] falha ao remover arte órfã ##{@arte.id}: #{e.class} - #{e.message}")
  false
end
```
and, when it returns false, use a `detail` that does not promise "nada foi criado" (for example "...a arte ##{id}
pode ter sido criada; confira antes de repetir"). Optionally cover it with a test using `Arte.test_block_destroy = true`.

## Info

### IN-01: Unverifiable claim about a proxy 413 in the docs

**File:** `docs/api-ia.md` (Limites section, last bullet)
**Issue:** "Uma resposta 413 sem o envelope JSON vem do proxy, não da API" cannot be verified from the repository: no proxy
or body-size configuration (`client_max_body_size`, Traefik buffering and so on) lives in the repo, and Rack/Rails apply no
body limit by default. It may also mislead a client about which limit applies (the API limit is 50 MB, enforced as a
422 only after the upload is received).
**Fix:** Either drop the bullet or word it as an operational note confirmed with the infra owner (state the actual proxy
limit). The `media_url` "link assinado de curta duração" claim is consistent with the private S3 bucket and the
default Active Storage expiry (`storage.yml` has no `public: true`, no `service_urls_expire_in` override), so it is acceptable.

### IN-02: Test names and file handles

**File:** `test/controllers/api/v1/ai/artes_controller_test.rb:299-308, 321-326`
**Issue:** "POST com media_file em campo de texto do formulário" and the `caption_only` test (line 286) are
named multipart but send URL-encoded forms, because rack-test only builds multipart when an UploadedFile is present.
That is fine for what they assert, but the naming is slightly misleading. Line 323 also leaves
`file_fixture("sample.jpg").open` unclosed.
**Fix:** Use `File.open(...) { |io| ... }` or `file_fixture("sample.jpg").binread` with `StringIO`; optionally rename the tests
("form urlencoded").

### IN-03: No test for the `media_type` versus file mismatch or for `media_file` as an array

**File:** `test/controllers/api/v1/ai/artes_controller_test.rb`
**Issue:** `media_file[]=...` (Array of uploads) is rejected with 400 by the guard but untested, and a `media_type:
caption_only` (or `video` with a JPEG) arte with a file attached is accepted silently. The latter is outside D-01..D-12
(model behavior, pre-existing) but the docs say nothing about it.
**Fix:** Add an array case to the 400 tests; consider a one-line docs note that `media_type` is not cross-checked
against the uploaded file.

---

_Reviewed: 2026-11-08_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
