# Copilot Instructions

## Stack

- Ruby 3.3.3 / Rails 8.1, PostgreSQL
- Frontend: Tailwind CSS, Hotwire (Turbo + Stimulus), importmap (no bundler)
- Background jobs: GoodJob (DB-backed)
- Pagination: Pagy
- Calendar views: simple_calendar
- Rate limiting: rack-attack

## Commands

```bash
bin/rails test                        # full test suite
bin/rails test test/models/arte_test.rb                  # single file
bin/rails test test/models/arte_test.rb:12               # single test by line
bin/rails db:test:prepare test        # prepare DB + run tests (matches CI)
bin/rubocop                           # lint (omakase style)
bin/brakeman --no-pager               # security static analysis
bin/importmap audit                   # JS dependency audit
```

## Architecture

### Two distinct user realms

**Admin realm** — `User` model with `has_secure_password` + `Session` model.
- Authentication via `Authentication` concern (included in `ApplicationController`). Session stored in a signed cookie `:session_id` pointing to a `Session` record.
- All admin controllers inherit `Admin::BaseController` which sets `layout 'admin'` and calls `before_action :require_authentication`.

**Client portal** — `Client` model with its own `has_secure_password` + a unique `access_token` (generated via `has_secure_token`).
- Routes are scoped under `/c/:token` with `as: :client`.
- `ClientController` (not namespaced) sets `layout 'client'`, skips the admin auth, and authenticates clients using `session[:client_id]` + `session[:client_token_version]` (the first 8 chars of the token). Revoking a client's token (rotate) immediately invalidates all active client sessions.
- Client controllers live in `app/controllers/client/`.

### Arte approval workflow

`Arte` has four statuses: `pending → approved | change_requested → revised → approved`.

The status is **never set directly in a controller** for client-facing actions. Instead, creating an `ApprovalResponse` record drives the transition via an `after_create` callback (`sync_arte_status`). Admin-side transitions (`mark_revised`, `approved!`) are controller-driven.

`ApprovalResponse#arte_must_be_pending` only allows new responses when the arte is `pending` or `revised`.

Edit/delete guards in `Admin::ArtesController`:
- Edit allowed only when `pending?`, `revised?`, or `change_requested?`
- Delete allowed only when `pending?` **and** `approval_responses.none?`

### Media sources

Each `Arte` must have **exactly one** media source: either a `media_file` (Active Storage attachment) or an `external_url` (e.g. Google Drive link). The model validates this with two custom validators (`media_source_present`, `only_one_media_source`).

Forms include a hidden `media_source` param (`"upload"` or `"link"`). The controller uses this to either purge the attached file or nil-out `external_url` before saving — the model itself doesn't know which source was chosen.

## Key Conventions

### Test setup
Tests use `ActionDispatch::IntegrationTest`. There are no FactoryBot factories; test objects are created inline with `.create!`. `sign_in_as(user)` from `SessionTestHelper` is available in all integration tests.

### Testing destroy failure
`Arte` exposes a test-only class attribute `Arte.test_block_destroy = true` (guarded by `Rails.env.test?`) to simulate a `before_destroy` abort without mocking. Always reset in an `ensure` block.

### Locale
All user-visible strings are in Portuguese (pt-BR). Error messages, flash notices/alerts, and view text are written in Portuguese.

### No fixtures for test data
`fixtures :all` is declared in `TestCase` but tests create their own records inline. Fixture files exist but are not relied upon for controller tests.

### `Current` attributes
`Current.session` holds the active admin `Session` record (thread-local via `ActiveSupport::CurrentAttributes`). It is set by the `Authentication` concern and used to identify the logged-in `User` as `Current.session.user`.
