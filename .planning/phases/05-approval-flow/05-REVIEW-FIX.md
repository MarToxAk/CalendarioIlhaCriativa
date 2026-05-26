---
phase: 05-approval-flow
fixed_at: 2026-05-26T00:00:00Z
review_path: .planning/phases/05-approval-flow/05-REVIEW.md
iteration: 1
findings_in_scope: 10
fixed: 9
skipped: 1
status: partial
---

# Phase 05: Code Review Fix Report

**Fixed at:** 2026-05-26T00:00:00Z
**Source review:** .planning/phases/05-approval-flow/05-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 10 (4 Critical + 6 Warning)
- Fixed: 9
- Skipped: 1 (CR-02 — pre-existing architectural debt, not safe to automate)

## Fixed Issues

### CR-01: Invalid `decision` value raises unhandled `ArgumentError` (500 error)

**Files modified:** `app/controllers/client/responses_controller.rb`
**Commit:** b2381d1
**Applied fix:** Added an early guard at the top of `create` that checks
`ApprovalResponse.decisions.key?(params.dig(:approval_response, :decision))`
before building the record. Invalid values redirect back with `alert: "Resposta inválida."`,
preventing the unhandled `ArgumentError` 500 crash entirely.

---

### CR-03: `:status` permitted in admin `arte_params` — state machine bypass

**Files modified:** `app/controllers/admin/artes_controller.rb`
**Commit:** 43bc483
**Applied fix:** Removed `:status` from the `arte_params` permit list. Status
transitions now only occur through dedicated actions (`mark_revised` and the
`ApprovalResponse#sync_arte_status` after_create callback), preserving the audit trail.

Note: WR-02 fix was included in the same commit (same file).

---

### CR-04: `target: "_blank"` without `rel="noopener noreferrer"` in admin view

**Files modified:** `app/views/admin/artes/show.html.erb`
**Commit:** 19c8237
**Applied fix:** Added `rel: "noopener noreferrer"` to the `link_to` call for
`@arte.external_url`, preventing reverse tabnapping.

---

### WR-01: Race condition on concurrent approval submissions

**Files modified:** `app/controllers/client/responses_controller.rb`
**Commit:** 96460da
**Applied fix:** Wrapped the approval response creation in `Arte.transaction`
with `@client.artes.lock.find(@arte.id)` (SELECT FOR UPDATE). The arte is
reloaded with a pessimistic lock inside the transaction, ensuring concurrent
requests serialize and the `arte_must_be_pending` validation sees a consistent
state. This requires human verification of the logic flow.

**Status:** fixed: requires human verification

---

### WR-02: `check_editable` blocks `revised` artes from admin edit

**Files modified:** `app/controllers/admin/artes_controller.rb`
**Commit:** 43bc483
**Applied fix:** Changed `check_editable` guard from `unless @arte.pending?` to
`unless @arte.pending? || @arte.revised?`. Admins can now edit artes in the
`revised` state (where the client has requested changes) and the alert message
was updated to reflect both permitted states.

**Status:** fixed: requires human verification (design decision — confirm revised artes should indeed be editable)

---

### WR-03: N+1 queries on `approval_responses` in show views

**Files modified:** `app/controllers/client/artes_controller.rb`, `app/controllers/admin/artes_controller.rb`
**Commit:** dacb70b
**Applied fix:** Added `includes(:approval_responses)` to `set_arte` in both
`Client::ArtesController` and `Admin::ArtesController`. Eliminates the 2-3
extra queries per page load from `any?`/`none?` + `each` calls on the association.

---

### WR-04: `responded_at` column never populated

**Files modified:** `app/models/approval_response.rb`
**Commit:** 315b014
**Applied fix:** Added `before_create { self.responded_at ||= Time.current }` to
`ApprovalResponse`. The `responded_at` column is now reliably set to the exact
moment the client submitted their response.

---

### WR-05: `token_version` nil bypass risk in `client.rb`

**Files modified:** `app/models/client.rb`
**Commit:** dd1aa15
**Applied fix:** Replaced the safe-navigation operator (`access_token&.first(8)`)
with an explicit nil guard that raises a descriptive error. When `access_token`
is nil, the comparison `nil == nil` would have silently granted authentication;
the raise ensures this fails loudly instead.

---

### WR-06: `email_address` reflected from params into login form

**Files modified:** `app/views/sessions/new.html.erb`
**Commit:** 9b1a014
**Applied fix:** Removed `value: params[:email_address]` from the email field in
the admin login form. The field is now always blank on GET, eliminating the
phishing pre-fill vector. (Rails auto-escaping prevented direct XSS, but the
reflection pattern itself was a phishing risk.)

---

## Skipped Issues

### CR-02: Plaintext password stored in `clients.password_plain` column

**File:** `db/schema.rb:79`
**Reason:** Pre-existing architectural debt — this is a systemic design issue that
requires a migration to drop the column, changes to `Admin::ClientsController` and
its views, and a new mechanism (magic link / encrypted PIN) for sharing credentials
with clients. Automating this change carries a high risk of breaking the existing
admin client management flow. Documented and deferred to a dedicated security
remediation task.
**Original issue:** `clients` table stores plaintext passwords in `password_plain`
column, actively populated and rendered in admin UI. Any database read (SQL injection,
backup, insider access) exposes all client passwords.

---

_Fixed: 2026-05-26T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
