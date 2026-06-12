---
phase: 23
reviewers: [gemini]
reviewed_at: 2026-06-12T11:00:00-03:00
plans_reviewed:
  - 23-01-PLAN.md
  - 23-02-PLAN.md
  - 23-03-PLAN.md
note: claude skipped (self — running inside Claude Code CLI)
---

# Cross-AI Plan Review — Phase 23

## Gemini Review

This is a high-quality implementation plan that demonstrates a strong understanding of Rails API best practices, concurrency, and security. It avoids common pitfalls like "ID enumeration" and N+1 queries in index actions while maintaining consistency with the established patterns from previous phases.

### 1. Summary

The plan for Phase 23 is robust and logically sequenced. It successfully bridges the gap between the existing web portal logic and a new versioned JSON API. By prioritizing row-level locking (D-07) and strict client scoping (D-09), the plan ensures that the mobile API is as reliable and secure as the web interface. The use of PORO serializers provides a clean separation of concerns, ensuring that internal admin data is never leaked to the client-facing endpoints.

### 2. Strengths

- **Security by Design:** The use of `@current_client.artes.find(id)` across all controllers prevents cross-client data leakage (horizontal privilege escalation) at the database query level.
- **Concurrency Handling:** Implementing `lock.find` within a transaction for approval responses is excellent for preventing race conditions (e.g., two users trying to approve the same arte simultaneously).
- **Defensive Programming:** The "Enum Guard" before the transaction (Task 23-02.2) is a sophisticated touch that prevents `ArgumentError` from bubbling up as a 500 Internal Server Error.
- **Performance Awareness:** Explicitly excluding `includes(:approval_responses)` from the `index` action while keeping it in the `show` action demonstrates a clear intent to optimize payload size and query count.
- **Testing Coverage:** The test plan covers both the happy path and critical failure modes (unauthorized, cross-client access, and invalid state transitions).

### 3. Concerns

- **ActiveStorage URL Configuration (MEDIUM):** Generating absolute URLs in the API requires `ActiveStorage::Current.url_options[:host]` to be set. While `set_active_storage_current` is planned, you must ensure the host is correctly pulled from request headers or environment configs to avoid broken links in the mobile app.
- **Serializer N+1 Risk (LOW):** Plan 23-01 Task 2 mentions that the serializer "always tries to serialize `approval_responses`," but Plan 23-02 Task 1 says "NEVER use `includes` in index." If the serializer unconditionally calls `object.approval_responses`, it will trigger an N+1 query for every arte in the list.
- **Validation Error Format (LOW):** While the plan mentions `render_envelope`, it doesn't explicitly detail how `ActiveRecord::RecordInvalid` (from `response.save!`) will be handled. Consistency in error messaging (e.g., field-level errors for the mobile app) is crucial.

### 4. Suggestions

- **Conditional Serialization:** Update the `ArteSerializer` logic to only include `approval_responses` if the association is loaded (`object.association(:approval_responses).loaded?`) or if a specific flag is passed. This resolves the N+1 conflict between the infrastructure and the controller.
- **Rescue RecordNotFound:** In the `BaseController`, explicitly `rescue_from ActiveRecord::RecordNotFound` to return a standardized JSON error envelope with a 404 status. This ensures the mobile app receives a parseable response instead of a generic HTML error page.
- **Pagination Headers:** In addition to the `meta.pagination` object in the body, consider adding standard Link headers (via Pagy) to make it easier for the mobile app or AI agent to navigate pages.
- **Timezone Consistency:** Ensure the `responded_at` and `scheduled_on` fields are serialized in ISO8601 format (UTC) to avoid confusion on the client side.

### 5. Risk Assessment: LOW

The risk is low because the plan adheres to the patterns already proven in Phase 22. The dependencies are already in place, and the business logic is a direct port of the stable web portal. The primary risks are minor technical details (ActiveStorage hosts) that are easily addressed during the "Act" phase.

**Verdict:** Proceed with implementation. The plan is ready for execution.

---

## Consensus Summary

*Single reviewer (Gemini) — consensus is Gemini's own assessment.*

### Agreed Strengths

- Security by design: scoped `@current_client.artes.find` prevents IDOR at query level
- Row-level lock in transaction is the correct concurrency pattern for double-submit prevention
- Enum guard before transaction prevents ArgumentError → 500
- N+1 avoided: `includes(:approval_responses)` only in `show`, not `index`
- Test plan covers all critical failure modes (401, 404 cross-client, 400 enum, 422 non-approvable, 201 revised re-approval)

### Agreed Concerns

- **(MEDIUM) Serializer N+1 risk in index:** If `ArteSerializer.serialize_collection` unconditionally calls `arte.approval_responses` (even to return `[]`), this triggers N+1. The plan instructs the controller NOT to use `includes` in index, but doesn't guard the serializer itself. Fix: use `arte.association(:approval_responses).loaded? ? arte.approval_responses : []` in the serializer, or pass a flag.
- **(MEDIUM) ActiveStorage host in test environment:** `set_active_storage_current` is patched from request headers at runtime. In integration tests, the request host is `www.example.com` (Rails test default) — this is fine for tests, but the plan should note the production requirement for a configured `DEFAULT_URL_HOST` or similar env var.
- **(LOW) Validation error format:** `RecordInvalid` is caught by the existing `rescue_from` in BaseController from Phase 21/22 — but the plan doesn't confirm the error message format includes field-level details (vs. just the model error string). The mobile app may need structured field errors.

### Divergent Views

*Only one reviewer — no divergent views.*

---

*Generated by /gsd-review --phase 23 --all on 2026-06-12*
*CLIs available: gemini ✓ | claude skipped (self) | codex ✗ | opencode ✗ | qwen ✗ | cursor ✗ | ollama ✗*
