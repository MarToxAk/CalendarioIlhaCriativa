# Pitfalls Research: Calendário de Aprovação de Artes

**Domain:** Content approval calendar with token-based client access
**Researched:** 2026-05-24
**Overall confidence:** HIGH (all critical items verified against official sources)

---

## Critical Pitfalls

### 1. Token Enumeration via Short or Predictable Tokens

**Risk:** If client tokens are short (under 16 chars), sequential, or derived from IDs, an attacker can enumerate all valid links in a small number of requests, accessing every client's calendar without a password.

**Warning signs:**
- Tokens contain the client's database ID or name
- Tokens are 8 characters or fewer
- No unique index on the token column in the database
- No rate limiting on the public calendar route

**Prevention:**
- Use Rails' built-in `has_secure_token` (generates 24-char base58 token via `SecureRandom::base58`). Collision probability is 1/58^24 — effectively zero.
- Add a unique index on `clients.public_token` in the migration. `has_secure_token` handles regeneration on collision, but the DB constraint is the actual safety net.
- Apply Rack::Attack throttling on the token-based calendar route: max 20 requests per IP per minute. Even with a valid token, a client hitting 300 requests/minute is anomalous.
- Never expose the client's integer ID in any URL visible to clients.

**Phase:** Foundation phase (auth and token generation). Getting this wrong at the start means rotating all client links later, which requires informing every client.

---

### 2. Password Brute Force on Token + Password Auth

**Risk:** The client access model is `token (URL) + simple password`. The token is effectively public (sent by email, shared in messages). This means the password is the only secret. Without rate limiting, an attacker who discovers a client's URL can brute-force the short password in seconds.

**Warning signs:**
- No failed attempt counter per token
- Password login form has no throttle on failed attempts
- Passwords are short numeric strings (e.g., "1234")
- No distinction between "token correct, password wrong" and "token not found" in error responses — but also no timing-constant comparison

**Prevention:**
- Use `BCrypt` (via `has_secure_password` or manual digest) to store client passwords — never plaintext.
- Throttle the password-check route per token with Rack::Attack: max 5 failures per token per 15 minutes, returning 429.
- Return identical error messages for "token not found" and "wrong password" — never reveal which part failed.
- Use `ActiveSupport::SecurityUtils.secure_compare` when comparing any token or password digest to prevent timing attacks.
- Enforce a minimum password length of 8 characters in the admin UI when creating client credentials, even if "simple."

**Phase:** Foundation phase (alongside token generation). These controls are trivial to add at creation and costly to retrofit.

---

### 3. Cross-Client Data Leak via Missing Scope

**Risk:** In a single-database multi-client system, every query that doesn't scope by client can return another client's posts. This is the most common multi-tenant failure mode. It happens once, usually silently — a client sees another agency's content.

**Warning signs:**
- Controller actions use `Post.find(params[:id])` instead of `current_client.posts.find(params[:id])`
- Any query that starts with a model name directly (e.g., `Post.where(...)`) rather than through an association
- `current_client` helper is defined but not consistently used
- Background jobs use unscoped queries ("enqueue job with post_id, find post in job")

**Prevention:**
- Every data-access method in client-facing controllers must go through the client association: `current_client.posts.find(params[:id])`. This raises `ActiveRecord::RecordNotFound` (→ 404) if the post belongs to a different client, never leaking data.
- Consider using the `acts_as_tenant` gem to enforce scoping at the model level as a safety net. It adds a `default_scope` that makes unscoped queries impossible without explicitly disabling the tenant.
- Write an explicit integration test for the leak scenario: log in as client A, try to access a post ID belonging to client B — assert 404, not 200.
- Background jobs must receive `client_id` and reload through the association, not fetch the resource directly.

**Phase:** Foundation phase (data model) and every feature phase thereafter. The test for cross-client access must be part of the test suite from day one.

---

### 4. File Upload Without Size and Type Enforcement

**Risk:** An admin uploads a 2 GB video file directly. Rails buffers it in memory or to disk before any validation fires, potentially crashing the server or filling disk. Separately, a malicious upload with a `.jpg` extension but executable content can bypass naive extension checks.

**Warning signs:**
- No `content_length_limit` set in Active Storage or Nginx config
- File type validated only by extension check in JS/client-side
- No `active_storage_validations` or equivalent gem in Gemfile
- Video previews processed synchronously in the web request
- Upload controller action runs for more than 5 seconds on large files

**Prevention:**
- Add `active_storage_validations` gem and declare explicit size and type limits on the model:
  ```ruby
  validates :file, content_type: ['image/jpeg', 'image/png', 'image/gif', 'video/mp4'],
                   size: { less_than: 100.megabytes }
  ```
- Set Nginx `client_max_body_size` to your limit (e.g., `100m`) to reject oversized uploads at the proxy before they hit Rails.
- Rely on Active Storage's `identify()` which reads magic bytes to determine real MIME type — do not trust the `Content-Type` header supplied by the client.
- For videos, do NOT process (transcode, generate thumbnails) synchronously in the request. Defer to Active Job.
- For local storage in v1: set a per-client storage quota check before accepting uploads; log accumulated disk usage.
- External links (Google Drive, Dropbox) are much safer for large files — no storage cost, no upload attack surface. Make this the recommended path for videos in admin onboarding.

**Phase:** Feature phase covering file upload. Must be done before any file upload goes to production, not retrofitted after.

---

### 5. Timezone Mismatch Causing Posts to Appear on Wrong Day

**Risk:** Dates are stored as `datetime` in UTC. The agency operates in one timezone (e.g., Brasília, UTC-3). When the admin schedules a post for "Monday at 11pm," it stores as Tuesday 02:00 UTC. The calendar displays it on Tuesday. The client sees it on the wrong day. This erodes trust immediately on first use.

**Warning signs:**
- `config.time_zone` is not set in `application.rb` (defaults to UTC)
- Post scheduled dates are stored as `datetime` instead of `date` when time-of-day is irrelevant
- Calendar grouping uses `.to_date` on a UTC datetime without timezone conversion
- `Date.today` used instead of `Date.current` or `Time.zone.today`
- Tests all pass but production users in Brazil see wrong days

**Prevention:**
- Set `config.time_zone = 'Brasilia'` in `application.rb` immediately. For v1 serving a single agency, a single timezone is correct.
- Store post scheduled dates as `date` column type (not `datetime`) if time-of-day is not needed. A `date` column has no timezone ambiguity.
- If `datetime` is needed (for deadlines), always use `Time.zone.now`, `Time.current`, `Time.zone.parse` — never `Time.now` or `Date.today`.
- The calendar grouping query must compare dates in the app timezone: `Post.where(scheduled_date: month_range)` where `month_range` is computed using `Time.zone`.
- Write a test that creates a post at 11pm Brasília time and asserts it appears on the correct calendar day, not the next day.

**Phase:** Foundation phase (data model). Changing datetime columns to dates, or adding timezone conversion, after client data exists is painful. Decide date vs. datetime types correctly upfront.

---

### 6. Approval State Corruption via Direct Attribute Writes

**Risk:** Approval status starts as a simple string column. Without a state machine, controllers freely write `post.update(status: params[:status])`, allowing invalid transitions: a "revisada" (reviewed) post can be set back to "pendente" by replaying a request, or a client can POST any status string including ones not in the spec.

**Warning signs:**
- `status` column is a plain `string` without a database check constraint or enum
- Controller accepts `status` directly from `params` without validation
- No model-level allowed-values check
- Admin can set status to arbitrary strings via the API
- No audit log of who changed status and when

**Prevention:**
- Use Rails `enum` to define states:
  ```ruby
  enum status: { pending: 0, approved: 1, changes_requested: 2, revised: 3 }
  ```
  Rails enums reject invalid values with an `ArgumentError` before hitting the database.
- Define allowed transitions explicitly. For this project's simple binary model (approved / changes_requested), the client can only transition from `pending` to `approved` or `changes_requested`. The admin can only transition from `changes_requested` to `revised`. Enforce this in the model with a custom validation or a lightweight state machine.
- Never pass `status` from `params` directly. Use named action methods: `post.approve!`, `post.request_changes!`.
- Add a database check constraint matching the enum values as a last line of defense.
- For AASM if adopted: use `guard` blocks on transitions and handle `AASM::InvalidTransition` exceptions at the controller level.

**Phase:** Feature phase (approval workflow). Define enums and transition rules before implementing client-facing approval actions.

---

## Moderate Pitfalls

### 7. Client Shares Their Own Link with the Wrong Person

**Risk:** The client forwards their calendar URL (or the admin sends the wrong link to the wrong client). Because it's a token URL with a shared password, there's no audit trail and no way to distinguish sessions. One client can see another's content.

**Warning signs:**
- Links have no expiry or rotation mechanism
- All client sessions share the same password indefinitely
- No per-session logging in the audit trail
- Admin has no way to revoke a link without generating a new token

**Prevention:**
- Build token rotation into the admin panel from the start: "Generate new link" invalidates the old token and issues a new one. This is one button that takes 5 minutes to implement but critical when a client leaks their link.
- Store session origin (IP, user agent, approximate timestamp) in the server session when a client authenticates. Show the admin "last accessed from X" in the client panel.
- Link invalidation is more important than encryption. A token the admin can rotate is safer than one they can't.

**Phase:** Admin panel phase. Token rotation must exist before onboarding real clients.

---

### 8. External Link Rot (Google Drive / Dropbox Links)

**Risk:** Admin pastes a Google Drive link for a post. Three weeks later the file is moved, the folder permissions change, or the Drive link expires. The client opens the calendar to approve a post and sees a broken link or "Access denied." The client assumes the post doesn't exist. They don't approve it. Deadline is missed.

**Warning signs:**
- No validation that the external URL is reachable at time of entry
- No visual distinction between "file uploaded here" vs "external link" in the calendar UI
- No admin alert when a client views a post and the file is inaccessible
- Broken links go undetected until a client complains

**Prevention:**
- At save time, perform a lightweight `HEAD` request to the external URL and warn the admin if it returns non-2xx. This won't catch future breakage but catches immediate mistakes.
- In the UI, show a clear "External link — ensure permissions are set to 'Anyone with link'" notice when an external URL is saved.
- Log when a client views a post but the external resource returns an error (requires client-side fetch with error reporting).
- Consider embedding a preview thumbnail (via Open Graph or Google Drive preview) so the admin can visually confirm the right file before saving.

**Phase:** Feature phase (post creation). The HEAD-request validation at save time is simple and catches 80% of cases.

---

### 9. Approval Ambiguity After Admin Makes Revisions

**Risk:** Client requests changes. Admin revises the file and marks it "revisada." The client never re-approves it. The post goes live with unverified revised content. Alternatively, the admin re-opens the post for approval but the client doesn't realize it's a new version — they think their earlier "changes requested" comment was enough.

**Warning signs:**
- "Revisada" is a terminal state with no path back to client approval
- No visual indicator in the client calendar that a post has been revised since their last interaction
- Clients don't see a revision history or "updated" badge

**Prevention:**
- After the admin marks a post as "revisada," automatically reset it to a "pending_re_approval" state that appears to the client as a new pending item.
- Show a "Revised — please re-approve" badge prominently on the calendar item.
- Keep a simple revision counter on the post (`revision_count: integer`) so both admin and client know it's been revised N times.
- The binary status model (approved / changes_requested) requires a `revised` state that feeds back into the client's pending queue — model this in the state machine from the start, not as an afterthought.

**Phase:** Feature phase (approval workflow state machine). Design the full state cycle (pending → approved/changes_requested → revised → pending) before writing the first controller action.

---

## Minor Pitfalls

### 10. Session Not Invalidated After Token Rotation

**Risk:** Admin rotates a client's token (because the link was leaked). The client who had the old link is already authenticated in a browser session. Their session cookie still grants access, even though their token no longer works for new logins.

**Warning signs:**
- `session[:client_id]` is set on login and never explicitly cleared on token rotation
- Admin rotates token but client's open browser tab still works

**Prevention:**
- Store the token value (or a token version counter) in the session at login time. On every authenticated request, verify `session[:client_token] == current_client.public_token`. If they don't match, destroy the session.
- This is a one-line check in `before_action :authenticate_client!`.

**Phase:** Foundation phase (auth). Add the check when implementing the session authentication filter.

---

### 11. Calendar Month Navigation Loading All Posts

**Risk:** Admin accumulates 12 months of posts. The calendar loads all posts for all time to render the current month view, making the page slow for no reason.

**Warning signs:**
- `current_client.posts` without date scoping in the calendar query
- Calendar page load time increases month after month
- N+1 queries on post associations (platform tags, file attachments)

**Prevention:**
- Always scope calendar queries to the displayed month: `current_client.posts.where(scheduled_date: start_of_month..end_of_month)`.
- Eager load associations: `.includes(:active_storage_attachments)`.
- Add a database index on `(client_id, scheduled_date)` — the two columns always queried together.

**Phase:** Feature phase (calendar view). Add the index and scope in the same migration/PR as the calendar feature.

---

### 12. Admin Panel Has No Confirmation on Destructive Actions

**Risk:** Admin accidentally deletes a client or a post. No confirmation dialog. Data is gone. For a 10-30 client operation, each client represents real relationship risk.

**Warning signs:**
- Delete buttons use standard `method: :delete` links with no `data-confirm`
- No soft delete / audit trail on client or post records

**Prevention:**
- Add `data-confirm: "Delete this post? This cannot be undone."` to all destructive actions.
- Consider `paranoia` gem or a manual `deleted_at` column for soft deletes on clients and posts. Given the scale (10-30 clients), hard deletes are a real risk.

**Phase:** Admin panel phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Auth & token setup | Brute force on password + timing attack on token | Rack::Attack + secure_compare + BCrypt from day one |
| Data model | Timezone bug puts posts on wrong day | Use `date` columns, set `config.time_zone`, write timezone test |
| Data model | Cross-client data leak | All queries through `current_client` association, add integration test |
| File upload | Oversized files crash server | Size limit in model + Nginx config before first upload |
| File upload | MIME spoofing bypasses type check | Trust Active Storage `identify()`, not user-supplied Content-Type |
| Approval workflow | Invalid state transitions | Rails enum + named bang methods, never raw `status=` from params |
| Approval workflow | Revised posts never re-approved | Design full state cycle before implementing actions |
| Admin panel | Leaked client links can't be revoked | Token rotation button required before onboarding clients |
| Calendar view | Month view loads all history | Scope query to displayed month + index on `(client_id, scheduled_date)` |
| Client UX | Clients don't understand what "approved" means | Prominent status badges, clear CTA copy, explicit deadline countdown |

---

## Sources

- [Rails Security Guide — Securing Rails Applications](https://guides.rubyonrails.org/security.html)
- [SECURITY IN RAILS: Preventing enumeration attacks, timing attacks — DEV Community](https://dev.to/rwxpat/security-in-rails-preventing-enumeration-attacks-data-leaks-and-timing-based-attacks-4k6e)
- [has_secure_token — Rails API](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html)
- [Rack::Attack rate limiting production guide — TTB Software](https://ttb.software/2026/03/21/rails-rate-limiting-rack-attack-production-guide/)
- [active_storage_validations gem — GitHub](https://github.com/igorkasyanchuk/active_storage_validations)
- [Securing Rails Active Storage Direct Uploads — DEV Community](https://dev.to/slimgee/securing-rails-active-storage-direct-uploads-55fm)
- [Unrestricted File Upload via MIME Type Spoofing — GitHub Advisory](https://github.com/gitroomhq/postiz-app/security/advisories/GHSA-44wg-r34q-hvfx)
- [Row-Level Multitenancy in Rails — DEV Community](https://dev.to/temitopeajao/row-level-multitenancy-in-rails-building-a-bulletproof-tenant-isolation-layer-from-scratch-25de)
- [Multi-Tenancy in Rails 8 — Omaship Guides](https://omaship.com/guides/multi-tenancy-rails-saas-2026)
- [AASM State Machines for Rails — GitHub](https://github.com/aasm/aasm)
- [Date/Time comparisons incorrect depending on TimeZone — Rails issue #36462](https://github.com/rails/rails/issues/36462)
- [Content Calendar Approval Process — Sugar Punch Marketing](https://sugarpunchmarketing.com/podcast-episodes/content-calendar-approval-process-create-systems-clients-actually-use-no-more-chasing-feedback/)
- [Active Storage & Form Errors: Preventing Lost File Uploads — Daniela Baron](https://danielabaron.me/blog/active_storage_form_errors/)
