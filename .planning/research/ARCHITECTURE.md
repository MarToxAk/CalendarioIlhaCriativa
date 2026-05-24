# Architecture Research: Calendário de Aprovação de Artes

**Domain:** Content approval workflow — social media agency admin + passwordless client portal
**Researched:** 2026-05-24
**Overall confidence:** HIGH (all key patterns grounded in official Rails guides and verified sources)

---

## Components

### Component Map

```
┌─────────────────────────────────────────────────────────────┐
│                        Rails App                            │
│                                                             │
│  ┌──────────────────┐         ┌────────────────────────┐   │
│  │   Admin Panel    │         │  Client-Facing Calendar │   │
│  │  (authenticated) │         │  (token + password)     │   │
│  │                  │         │                         │   │
│  │ - Client CRUD    │         │ - Monthly calendar view │   │
│  │ - Arte CRUD      │         │ - Arte detail / preview │   │
│  │ - File upload    │         │ - Approve / request     │   │
│  │ - Feedback panel │         │   change with comment   │   │
│  └────────┬─────────┘         └───────────┬─────────────┘   │
│           │                               │                 │
│           └──────────┬────────────────────┘                 │
│                      │                                      │
│            ┌─────────▼──────────┐                          │
│            │   Domain Core      │                          │
│            │   (ActiveRecord)   │                          │
│            │                    │                          │
│            │ Client             │                          │
│            │ Arte               │                          │
│            │ ApprovalResponse   │                          │
│            │ Comment            │                          │
│            └─────────┬──────────┘                          │
│                      │                                      │
│            ┌─────────▼──────────┐                          │
│            │   Storage Layer    │                          │
│            │                    │                          │
│            │ Active Storage     │                          │
│            │ (local disk / S3)  │                          │
│            │ External URL field │                          │
│            └────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

### Boundaries and Responsibilities

| Component | Responsibility | Key Rails Mechanism |
|-----------|---------------|---------------------|
| Admin Panel | Full CRUD on clients and artes, file upload, read all feedback | Devise or Rails 8 auth generator for admin session |
| Client Calendar | Read-only view of own monthly artes, submit approval/change | Token + password session, scoped to one Client |
| Domain Core | Business rules, state transitions, associations | ActiveRecord models, enum, validations |
| Storage Layer | Hold uploaded files OR record external URL | Active Storage (`has_one_attached`) + plain `external_url` string column |
| Feedback Panel | Aggregate view of all pending/changed artes | Scoped query in Admin, no new component needed |
| Notification Hooks | Reserved extension points (v2) | ActiveRecord callbacks (`after_create_commit`) ready for Action Mailer or a job |

The admin panel and client calendar share the same Rails process. They are separated by routing namespaces (`/admin/*` vs `/c/:token/*`) and authentication concerns, not by separate applications. At 10-30 clients this is the correct level of separation — no microservices needed.

---

## Data Model

### Key Entities

```
Client
  id
  name                    string, not null
  slug                    string, unique (human-readable, optional)
  access_token            string, not null, unique  ← URL token (has_secure_token)
  password_digest         string, not null           ← has_secure_password
  created_at / updated_at

Arte
  id
  client_id               integer, FK → clients.id
  title                   string
  caption                 text
  scheduled_on            date, not null             ← calendar day
  approval_deadline       date
  platform                integer (enum)             ← instagram | facebook | linkedin
  media_type              integer (enum)             ← image | video | caption_only
  status                  integer (enum)             ← pending | approved | change_requested | revised
  external_url            string, nullable           ← Google Drive / Dropbox link
  created_at / updated_at
  [Active Storage attachment: media_file (optional)]

ApprovalResponse
  id
  arte_id                 integer, FK → artes.id
  decision                integer (enum)             ← approved | change_requested
  comment                 text, nullable
  responded_at            datetime
  created_at / updated_at

  NOTE: One-to-one with Arte for v1 (one active response per arte).
  If revision history is needed later, convert to has_many.
```

### Associations

```ruby
# Client
has_many :artes, dependent: :destroy

# Arte
belongs_to :client
has_one   :approval_response, dependent: :destroy
has_one_attached :media_file  # nil if external_url is used instead

# ApprovalResponse
belongs_to :arte
```

### Enums

```ruby
# Arte
enum :platform,   { instagram: 0, facebook: 1, linkedin: 2 }, prefix: :platform
enum :media_type, { image: 0, video: 1, caption_only: 2 }
enum :status,     { pending: 0, approved: 1, change_requested: 2, revised: 3 }

# ApprovalResponse
enum :decision,   { approved: 0, change_requested: 1 }
```

Use integer-backed enums (not string). Add `null: false, default: 0` at the DB level for every enum column. Never reorder enum keys — always append.

### The External URL + Active Storage Duality

Active Storage handles file uploads only. It has no concept of an external link. The cleanest approach for this project is a dual-column strategy on `artes`:

- `media_file` (Active Storage attachment) — used when admin uploads a file
- `external_url` (string column) — used when admin pastes a Drive/Dropbox link

Add a model validation ensuring at least one is present, and never both:

```ruby
validate :media_source_present
validate :only_one_media_source

def media_source_present
  errors.add(:base, "Precisa de arquivo ou link externo") unless media_file.attached? || external_url.present?
end

def only_one_media_source
  errors.add(:base, "Use arquivo OU link externo, não ambos") if media_file.attached? && external_url.present?
end
```

### Calendar as a Query, Not a Model

There is no `Calendar` model. A monthly calendar view is a scoped query:

```ruby
Arte.where(client: @client, scheduled_on: Date.current.beginning_of_month..Date.current.end_of_month)
    .order(:scheduled_on)
    .includes(:approval_response)
```

Group results by `scheduled_on.day` in the presenter/view layer. Adding a Calendar model adds indirection with no benefit at this scale.

---

## Access Control Architecture

### Two Authentication Contexts, One App

| Context | Who | Mechanism | Session Key |
|---------|-----|-----------|-------------|
| Admin | Agency staff | Rails 8 auth generator (`has_secure_password` on `User` model) | `session[:user_id]` |
| Client | End client | `access_token` in URL + `has_secure_password` on `Client` model | `session[:client_id]` |

These are completely separate session namespaces. There is no shared authentication logic.

### Admin Authentication

Use the Rails 8 built-in authentication generator:

```bash
bin/rails generate authentication
```

This produces a `User` model with `has_secure_password`, a `Session` model with `has_secure_token`, and an `Authentication` concern for `ApplicationController`. Scope all admin routes under `/admin` with a `before_action :require_authentication` (the generated concern).

For v1, a single admin user (created via `rails console` or a seed) is sufficient. No sign-up flow needed.

### Client Token + Password Flow

Clients access via a URL like `/c/abc123xyz` where `abc123xyz` is the `Client#access_token`. The token identifies which client, the password authenticates them.

```ruby
# Client model
class Client < ApplicationRecord
  has_secure_token :access_token   # generates 24-char unique token on create
  has_secure_password              # password_digest column, authenticate(password) method
  has_many :artes, dependent: :destroy
end
```

The flow in four steps:

1. Admin creates a client. Rails auto-generates `access_token`. Admin sets a password. Admin shares the URL `/c/{access_token}` with the client.
2. Client hits `/c/:token` → app finds `Client.find_by!(access_token: params[:token])`. Renders a password form (the token is in the URL, so the form can be a simple POST).
3. Client submits password → `client.authenticate(params[:password])`. On success, write `session[:client_id] = client.id`. Redirect to `/c/:token/calendar`.
4. All subsequent client requests go through a `before_action :require_client_auth` in a base `ClientController`:

```ruby
class ClientController < ApplicationController
  skip_before_action :require_authentication  # skip admin auth
  before_action :load_client_from_token
  before_action :require_client_auth

  private

  def load_client_from_token
    @client = Client.find_by!(access_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "Link inválido", status: :not_found
  end

  def require_client_auth
    unless session[:client_id] == @client.id
      redirect_to client_login_path(@client.access_token)
    end
  end
end
```

### Isolation Guarantee

Client sessions are always verified against the token in the URL. A client cannot access another client's calendar by guessing a session. The check `session[:client_id] == @client.id` prevents session-fixation-style lateral movement. Artes queries are always scoped to `@client`:

```ruby
@artes = @client.artes.where(scheduled_on: month_range)
```

Never query `Arte.find(params[:id])` without the client scope. Use `@client.artes.find(params[:id])` so Rails raises `RecordNotFound` on cross-client access.

### Routing Structure

```ruby
Rails.application.routes.draw do
  # Admin — protected by require_authentication concern
  namespace :admin do
    root to: "dashboard#index"
    resources :clients do
      resources :artes
    end
    resources :feedback, only: [:index]   # read-all feedback panel
  end

  # Client portal — protected by token + password
  scope "/c/:token", module: :client, as: :client do
    get   "login",    to: "sessions#new",    as: :login
    post  "login",    to: "sessions#create"
    delete "logout",  to: "sessions#destroy", as: :logout
    get   "calendar", to: "calendars#show",  as: :calendar
    resources :artes, only: [:show] do
      resource :approval_response, only: [:create, :update]
    end
  end
end
```

---

## Data Flow

### Creation Flow (Admin → Arte)

```
Admin fills arte form
  → POST /admin/clients/:id/artes
  → Admin::ArtesController#create
  → Arte.new(arte_params) scoped to client
  → Active Storage attaches file  OR  external_url stored
  → Arte saved with status: :pending
  → Arte appears on client's monthly calendar
```

### Review Flow (Client → ApprovalResponse)

```
Client opens /c/:token/calendar
  → CalendarsController#show
  → @client.artes.for_month(params[:month]).includes(:approval_response)
  → Render calendar grouped by day
  → Client clicks an arte
  → ArtesController#show renders preview + decision form

Client submits decision
  → POST /c/:token/artes/:id/approval_response
  → ApprovalResponsesController#create (or update if revisiting)
  → ApprovalResponse.create!(arte: @arte, decision:, comment:)
  → Arte status updated via callback or controller call:
       @arte.approved!           if decision == :approved
       @arte.change_requested!   if decision == :change_requested
  → Redirect back to calendar with confirmation message

[Extension point v2: after_create_commit :notify_admin callback fires here]
```

### Revision Flow (Admin → Revised)

```
Admin opens /admin/feedback
  → Feedback::IndexController queries Arte.change_requested.includes(:client, :approval_response)
  → Admin sees all artes with requested changes + client comments

Admin makes changes (re-uploads file or updates caption)
  → PATCH /admin/clients/:id/artes/:id
  → Admin marks arte as revised: @arte.revised!
  → ApprovalResponse is NOT deleted — kept as history
  → Arte status resets... OR admin can reset to :pending if re-approval is needed

[Decision: after admin marks as :revised, the arte status stays :revised until admin
manually resets to :pending if they want another client approval round.
For v1, :revised is a terminal state that means "admin addressed it." Simple.]
```

### State Machine on Arte#status

```
pending → approved          (client approves)
pending → change_requested  (client requests change)
change_requested → revised  (admin marks addressed)
revised → pending           (admin resets for re-approval, optional v2)
```

Do not use a state machine gem (AASM, workflow) for this. The transitions are simple enough that `Arte#approved!`, `Arte#change_requested!`, and `Arte#revised!` (generated by enum) are sufficient. Add validations on `ApprovalResponse` to guard the transition:

```ruby
class ApprovalResponse < ApplicationRecord
  belongs_to :arte
  enum :decision, { approved: 0, change_requested: 1 }

  validates :decision, presence: true
  validate :arte_must_be_pending, on: :create

  after_create :sync_arte_status

  private

  def arte_must_be_pending
    errors.add(:arte, "já foi respondida") unless arte.pending?
  end

  def sync_arte_status
    case decision
    when "approved"         then arte.approved!
    when "change_requested" then arte.change_requested!
    end
  end
end
```

---

## Build Order

Dependencies cascade: you cannot build later phases without earlier ones being solid.

### Phase 1 — Data Foundation

Build first because everything depends on it.

- `Client` model: `access_token` (has_secure_token), `password_digest` (has_secure_password), name
- `Arte` model: all columns including enums, `external_url`, Active Storage attachment
- `ApprovalResponse` model: decision enum, comment, `arte_id`
- Migrations with correct null constraints and defaults
- Model validations and associations
- `media_source_present` / `only_one_media_source` validations on Arte
- Basic seeds (one admin user, one client, a few artes)

### Phase 2 — Admin Authentication + Client CRUD

Build second because admin must exist before any client data is real.

- Rails 8 auth generator for admin `User` + `Session`
- Admin routes namespace + `ApplicationController` concern
- `Admin::ClientsController` — CRUD, display access_token and shareable link
- `Admin::ArtesController` — CRUD, file upload via Active Storage or external_url paste
- Simple admin layout (no styling needed yet, functionality first)

### Phase 3 — Client Calendar + Auth

Build third because it depends on clients and artes existing.

- `Client::SessionsController` — password form, create/destroy
- `ClientController` base class with `load_client_from_token` + `require_client_auth`
- `Client::CalendarsController#show` — monthly query, group by day
- `Client::ArtesController#show` — arte detail with media preview
- Handle both `media_file` (Active Storage URL) and `external_url` in the view

### Phase 4 — Approval Flow

Build fourth because client must be able to see artes before responding.

- `Client::ApprovalResponsesController#create` + `#update`
- `ApprovalResponse` state sync callback
- Arte status enum transitions
- Guard against double-submission (`arte_must_be_pending` validation)
- Confirmation message after decision

### Phase 5 — Admin Feedback Panel

Build fifth because it reads data produced by Phase 4.

- `Admin::FeedbackController#index`
- Query: `Arte.change_requested.includes(:client, :approval_response).order(:approval_deadline)`
- Display client name, arte title, comment, deadline
- "Mark as revised" button → `PATCH /admin/artes/:id` with `{ status: :revised }`
- Filter/sort by client, deadline

### Phase 6 — Polish + Deadline Awareness

- Highlight artes past `approval_deadline` in both admin and client views
- Active Storage direct upload (skip for local disk, add for S3 if needed)
- Turbo Frames for approve/change inline (no full-page reload)
- Mobile-friendly calendar layout

---

## Rails Conventions to Follow

| Concern | Convention | Why |
|---------|-----------|-----|
| Client auth isolation | Two separate concerns (`Authentication` for admin, custom `ClientAuthentication` for client) | Clean separation, no leakage |
| Enum columns | Integer-backed, `null: false, default: 0` | Prevents nil surprises; safe addition later |
| Media storage | `has_one_attached :media_file` + `external_url` string, validated mutually exclusive | Active Storage doesn't handle external URLs natively |
| Calendar rendering | Plain query + view helper, no Calendar model | YAGNI — a model adds indirection with no payoff |
| State transitions | Enum-generated bang methods (`arte.approved!`) | Sufficient for a binary workflow; no gem needed |
| Scoping | Always `@client.artes.find(...)` never `Arte.find(...)` in client controllers | Enforces isolation at the query level |
| Namespacing | `Admin::` and `Client::` controller namespaces | Clear ownership, easy to grep, standard Rails |

---

## Architectural Risks to Watch

| Risk | Probability | Mitigation |
|------|------------|------------|
| Client views another client's arte via URL manipulation | Medium | Always scope queries to `@client`; see isolation note above |
| `external_url` pointing to a Drive link that becomes private | High (operational) | Display URL as-is; admin's responsibility to maintain link validity |
| Arte with no media source (neither upload nor URL) | Medium | Model validation catches it at save time |
| Admin user password lost with no recovery flow | Low | Seed reset via `rails console` is acceptable for single-admin v1 |
| ApprovalResponse submitted twice (double-click) | Medium | `arte_must_be_pending` validation on `ApprovalResponse`; Turbo disables button after submit |

---

## Sources

- [Active Storage Overview — Rails Guides](https://guides.rubyonrails.org/active_storage_overview.html) — polymorphic attachments, `has_one_attached`, direct upload (HIGH confidence)
- [Rails 8 Authentication Generator — BigBinary](https://www.bigbinary.com/blog/rails-8-introduces-a-basic-authentication-generator) — admin auth generator (HIGH confidence)
- [generates_token_for in Rails 7.1 — Mintbit](https://www.mintbit.com/blog/rails-7-dot-1-generate-tokens-for-specific-purposes-with-generates-token-for/) — token expiry and embedded data (HIGH confidence)
- [ActiveRecord::SecureToken — Rails API](https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html) — `has_secure_token` mechanics (HIGH confidence)
- [Enum Best Practices — Honeybadger](https://www.honeybadger.io/blog/how-to-use-enum-attributes-in-ruby-on-rails/) — integer-backed enums, default values (MEDIUM confidence)
- [Hotwire Decisions — Lab Zero](https://labzero.com/blog/hotwire-decisions-when-to-use-turbo-frames-turbo-streams-and-stimulus) — Turbo Frames for inline interactions (MEDIUM confidence)
