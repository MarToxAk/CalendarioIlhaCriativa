# Features Research: Calendário de Aprovação de Artes

**Domain:** Social media content approval calendar for agencies
**Researched:** 2026-05-24
**Reference tools studied:** Planable, Gain, Hootsuite, ContentCal, Later, Sked Social, ContentStudio

---

## Table Stakes

Features clients and admins expect. Missing any of these and the tool feels incomplete or untrustworthy compared to just using WhatsApp or email.

### Client-Facing

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Monthly calendar view of scheduled posts | Core mental model — "what is going live when" | Low | Grid by day, posts shown as cards with thumbnail |
| Post preview showing actual content (image/video/caption) | Clients need to see *exactly* what will publish to give meaningful feedback | Medium | Lightbox or inline expand per post card |
| One-click approve or request-changes action per post | The entire job of the client; must be frictionless | Low | Two-button UI, no form to fill out before choosing |
| Comment field when requesting changes | Without this, "request changes" is useless — admin has no direction | Low | Required or optional when status = Request Changes |
| Access via link + password, no account creation | Clients refuse to create yet another account; friction kills adoption | Low | Session-based auth keyed to client token |
| Visual indicator of post status (approved / needs changes / pending) | Clients need to know what they have already handled vs what still needs review | Low | Color badges per post card |
| See which platform each post targets (Instagram / Facebook / LinkedIn) | Context for judgment — what works on IG differs from LinkedIn | Low | Platform icon on card |
| See the approval deadline per post | Clients need external pressure; without a due date, they procrastinate | Low | Shown on card or post detail |
| Ability to navigate between months | Calendar is temporal; clients may review ahead or check past approvals | Low | Prev/Next month navigation |

### Admin-Facing

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Client list management (create, edit, deactivate) | Admin must manage the portfolio without developer help | Low | CRUD on clients with name, link slug, password |
| Add posts to specific calendar days per client | Core content scheduling action | Medium | Date picker + file upload or external URL |
| Upload image or video per post | The primary content artifact | Medium | Direct upload; store file or reference |
| Attach external link (Drive, Dropbox) as post asset | Admin may not want to re-upload files already in cloud storage | Low | URL field alongside upload |
| Write or paste caption per post | Caption is primary copy for all three platforms | Low | Textarea, plain text sufficient for v1 |
| Set approval deadline per post | Drives client behavior; without it there is no urgency | Low | Date picker field |
| Dashboard / list view of all client responses | Admin must triage feedback without opening every calendar individually | Medium | Filterable list: client, status, date |
| Mark a post as "revised" after making requested changes | Closes the loop; tells clients their feedback was acted on | Low | Admin-only status update |
| See all comments left by clients | Cannot action feedback that is buried | Low | Shown in dashboard and on post detail |
| Per-post status visible in admin calendar | Admin needs same calendar awareness as client | Low | Same status badges, admin view |

---

## Differentiators

Features that set a tool apart. Not expected on day one, but they create stickiness and reduce the most common friction points.

| Feature | Value Proposition | Complexity | Build When |
|---------|-------------------|------------|------------|
| Status summary strip at top of calendar ("3 approved, 2 need changes, 5 pending") | Clients immediately see their outstanding work without scanning every card | Low | Phase 2 — one query, render numbers |
| Admin notification digest (daily email summary of unreviewed posts) | Admin currently checks manually; a digest reduces the risk of missed deadlines | Medium | Phase 2 or 3; requires mailer setup |
| Post-level revision thread (admin replies to client comment) | Without this, admin must respond via WhatsApp; conversation lives outside the tool | Medium | Phase 2; threaded comments per post |
| "Revised — please re-review" status that notifies client | Closes the revision cycle explicitly; clients know to re-visit | Medium | Requires some notification mechanism |
| Bulk approve (client approves all pending posts at once) | Reduces friction for clients who trust the content and just need to confirm | Low | Phase 2; checkbox select + batch action |
| Post history / audit log (who approved what and when) | Protects admin if client disputes a published post; also useful for billing transparency | Low | Timestamps on status changes, simple table |
| Password reset or link regeneration by admin | Admin must be able to rotate access without developer help | Low | Admin UI button, regenerates token |
| Caption character count and platform limits indicator | LinkedIn (3000), Instagram (2200), Facebook (63206) — helps admin write correctly | Low | Client-side JS counter |
| Copy post to another day or duplicate for another platform | Admin often repurposes content across platforms | Medium | Phase 3 |
| Preview how post looks in-platform (simulated feed) | Planable and Gain both offer this; reduces "I didn't know it would look like that" complaints | High | Defer — requires per-platform rendering logic |

---

## Anti-Features (Explicitly Avoid in v1)

Things that seem useful but will slow down delivery, add maintenance burden, or solve problems this project does not have at 10-30 clients.

| Anti-Feature | Why Avoid | Warning | What to Do Instead |
|--------------|-----------|---------|-------------------|
| Multi-stage approval workflows (draft → legal → client → final) | This tool has one client and one admin. Multi-stage is for enterprise teams with compliance requirements | Adds state machine complexity; UI branching | Binary status: Approved / Request Changes |
| Role-based permissions within a client (e.g. viewer vs approver) | Single client contact is the model; sub-roles inside a client org are out of scope | Premature architecture for 10-30 clients | One password per client link — done |
| Real-time collaboration (live cursors, concurrent editing) | Neither party edits posts simultaneously; admin writes, client reviews asynchronously | WebSockets complexity for zero perceived benefit | Static page with reload is fine |
| Direct publishing to Instagram / Facebook / LinkedIn via API | Platform APIs (especially Meta) require app review, token management, webhook handling — a project in itself | Can block v1 indefinitely if attempted | Admin publishes manually using approved content as reference |
| Mobile push notifications | Requires a native app or PWA push setup; overkill for a web tool at this scale | Significant infrastructure for marginal gain | Email digest is sufficient for now |
| In-app analytics (reach, engagement, impressions) | Requires platform API access; out of scope and orthogonal to approval workflow | Scope creep; clients can check platform natively | Link to native platform insights if needed |
| Client account creation / OAuth login | Adds password reset flows, email verification, token management | Every extra auth step loses clients who could just use the link | Token-in-URL + simple password is the right call |
| Drag-and-drop calendar rescheduling | Admin rarely reschedules at scale; adds JS complexity and state sync risk | Complex UX for infrequent action | Edit post form with date picker |
| White-labeling / custom domains | Relevant for SaaS resellers; not needed for a single-agency internal tool | Infrastructure and DNS management cost | Admin controls branding via CSS variables if needed |
| Revision round limits (automatic lockout after N rounds) | Gain and others offer this for SaaS billing reasons; irrelevant here | Adds policy logic; creates adversarial client relationship | Admin handles rounds informally; set expectations in person |
| AI caption generation or content suggestions | Trendy but entirely orthogonal to approval workflow | Scope creep with no grounding in the problem | Admin writes captions externally, pastes in |

---

## Feature Dependencies

Which features require other features to work correctly.

```
Client calendar view
  └─ Requires: post exists with date, platform, content asset
  └─ Requires: client auth via link + password

Post approval / request changes action
  └─ Requires: client is authenticated (session active)
  └─ Requires: post is in "pending" state (not already decided)
  └─ Enables: comment field (shown when "Request Changes" chosen)

Admin dashboard (response triage)
  └─ Requires: client approval status stored on post
  └─ Requires: comments stored per post
  └─ Requires: at least one client with posts

Mark post as "revised" (admin)
  └─ Requires: post is in "Request Changes" state
  └─ Requires: admin is authenticated

Approval deadline display
  └─ Requires: admin has set deadline on post
  └─ Informs: urgency cue on client calendar card

Post-level revision thread (differentiator)
  └─ Requires: comments feature (table stakes)
  └─ Requires: admin reply UI + per-comment authorship

Admin notification digest (differentiator)
  └─ Requires: post status tracking (table stakes)
  └─ Requires: mailer configured (ActionMailer + SMTP)

Bulk approve (differentiator)
  └─ Requires: individual approve action (table stakes)
  └─ Requires: checkbox UI + batch route
```

---

## MVP Recommendation

Build exactly the table stakes list above, in this priority order:

**Phase 1 (Core loop):**
1. Admin creates clients, generates link + password
2. Admin adds posts (upload or external URL, caption, platform, deadline, date)
3. Client opens calendar, sees posts, approves or requests changes with comment
4. Admin dashboard shows all responses, comments, pending reviews
5. Admin marks post as revised

**Defer to Phase 2:**
- Status summary strip (low effort, high client UX value)
- Post-level admin reply to client comment
- Password / link regeneration by admin

**Defer to Phase 3+:**
- Email digest notifications
- Bulk approve
- Post history / audit log
- Duplicate / copy post

---

## Sources

- [Planable product page](https://planable.io/product/) — calendar views, approval layers, locking mechanism
- [Gain approvals feature page](https://gainapp.com/features/approving) — no-login magic approver, one-click decisions, private queues
- [Hootsuite social media approval tool](https://www.hootsuite.com/platform/social-media-approval-tool) — role-based access, separate client environments
- [Gain blog: 6 best social media approval tools](https://blog.gainapp.com/social-media-approval-tools/) — table stakes vs differentiator analysis
- [Sked Social: streamline agency approvals](https://skedsocial.com/blog/agency-social-media-content-approvals) — revision round limits, pain points, good vs bad client experience
- [Social media approval workflow top tools 2026](https://wifitalents.com/best/social-media-approval-software/) — approval gates, audit trails, calendar-first differentiators
- [Sugar Punch Marketing: approval process UX](https://sugarpunchmarketing.com/podcast-episodes/content-calendar-approval-process-create-systems-clients-actually-use-no-more-chasing-feedback/) — client adoption pitfalls, complexity vs simplicity tradeoffs
- [TrustyPost: social media approval workflow SOPs](https://trustypost.ai/blog/social-media-approval-workflow-2026-simple-sops/) — deadline management, post status lifecycle, revision history
