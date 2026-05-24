# Stack Research: Calendário de Aprovação de Artes

**Project:** Rails content-approval calendar for social media agency
**Researched:** 2026-05-24
**Overall confidence:** HIGH (core stack), MEDIUM (calendar UI), HIGH (auth pattern)

---

## Recommended Stack

### Core

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Ruby | 3.3.x | Language runtime | LTS, ships with Rails 8.1's recommended Ruby |
| Rails | 8.1.3 | Web framework | Current stable as of March 2026; Propshaft + importmap default; built-in auth generator eliminates need for Devise for admin |
| PostgreSQL | 16.x | Primary database | Array columns, UUID support, full-text search; overkill for 10-30 clients but correct choice for production — avoid SQLite in multi-user concurrent writes |

**Rails 8.1.3** is the latest stable release (March 24, 2026, RubyGems). Rails 8.0.x is also supported until May 2026, but 8.1 is the recommended target for new projects.

---

### Authentication

This project has two distinct access patterns that must be handled separately:

#### Admin (back-office panel)

**Use Rails 8 built-in authentication generator — not Devise.**

```bash
bin/rails generate authentication
```

This generates:
- `User` model with `has_secure_password` (bcrypt)
- `Session` model with `has_secure_token` (DB-persisted sessions)
- `Authentication` concern with `require_authentication` before_action
- Password reset flow with signed, time-limited tokens

Devise is not needed here. The built-in generator produces readable, ownable code that lives in your project. For a single-admin or small-team back-office with no self-registration, it is the correct choice. Devise's value is in multi-model, multi-strategy setups — that is not this project.

If a second admin needs to be added later, handle it directly in the User model or via a rake task. Do not add Devise to get "user management" — it adds 15+ modules you will not use.

#### Client (public link + simple password)

**Custom `has_secure_token` + password-on-session pattern — no gem needed.**

The client access model is not a user account. It is a shareable resource with a simple password. Implement it as:

```ruby
# Client model
class Client < ApplicationRecord
  has_secure_token :access_token   # unique URL slug
  has_secure_password              # bcrypt password (simple, admin-set)
end
```

The public URL is `GET /c/:access_token` — rendered without any authentication concern. When the client submits the password form, store `client_id` in the Rails session (standard cookie). No gem is needed for this. It is 30 lines of controller code.

Do not use Devise for clients. The token-link pattern is architecturally incompatible with Devise's model-centric session management. Mixing them adds complexity with no benefit.

---

### File Handling

#### Direct uploads (images, videos)

**Use ActiveStorage** with local disk in development and S3-compatible storage (e.g., DigitalOcean Spaces or AWS S3) in production.

```ruby
# Art model
class Art < ApplicationRecord
  has_one_attached :media_file
end
```

ActiveStorage is the correct choice here because:
- Built into Rails — no gem to maintain
- Supports direct browser-to-storage upload (avoids routing large video files through Dyno/server memory)
- Handles image variants via `libvips` (generate thumbnails for calendar preview)
- Video preview frames supported out of the box
- Scale of 10-30 clients with social-media-sized files (images up to ~10MB, videos up to ~100MB) is well within ActiveStorage's reliable range

Shrine is the alternative if you need complex derivative pipelines or multi-step processing. This project does not.

#### External links (Google Drive, Dropbox)

**Store as a plain string column on the `Art` model.** ActiveStorage does not handle external URLs — that is intentional. The correct pattern is:

```ruby
# arts table
add_column :arts, :external_url, :string
```

The `Art` model has a polymorphic source: either `media_file` (ActiveStorage attachment) or `external_url` (string). Render conditionally in views. A model validation should enforce that exactly one is present.

Do not attempt to proxy or re-upload Drive/Dropbox links — they are access-controlled, short-lived, or user-managed. Treat them as opaque display links.

---

### Frontend

**Hotwire (Turbo + Stimulus) — no React, no Vue.**

The default Rails 8 stack ships with `turbo-rails` and `stimulus-rails` via importmap. Use them.

This application's interactivity needs are:
1. Approve / Request Changes buttons on each art card — inline update, no page reload
2. Comment textarea that appears conditionally on "Request Changes"
3. Admin panel list updates after status changes
4. Calendar month navigation

All of these are solved by Turbo Frames and Turbo Streams + one or two Stimulus controllers. A React SPA would add a build pipeline, API layer, state management, and hydration concerns for zero user-visible benefit at this scale.

**Asset pipeline:** Propshaft (Rails 8 default) + importmap for JS + `tailwindcss-rails` gem for CSS (standalone Tailwind binary, no Node required).

```ruby
# Gemfile
gem "tailwindcss-rails"
gem "turbo-rails"
gem "stimulus-rails"
```

---

### Supporting Libraries

| Gem | Version | Purpose | Conditions |
|-----|---------|---------|------------|
| `tailwindcss-rails` | ~> 4.x | Utility-first CSS, no Node build | Default Rails 8 CSS choice for Hotwire apps |
| `simple_calendar` | ~> 3.1 | Monthly calendar rendering helper | Renders calendar grid; handles start_date, wraps any ORM objects |
| `image_processing` | ~> 1.x | ActiveStorage variant processing via libvips | Required for thumbnail generation from uploaded images |
| `pagy` | ~> 9.x | Pagination for admin art/client lists | 100x lighter than Kaminari; use in admin panel |
| `pundit` | ~> 2.x | Authorization policies for admin actions | Not needed for client access (custom token); needed to protect admin-only routes if roles expand |
| `dotenv-rails` | ~> 3.x | Environment variable management | S3 credentials, app secret key in development |
| `good_job` | ~> 4.x | Background job processing | For future email notifications or async file processing; uses PostgreSQL — no Redis needed |

**`simple_calendar` rationale:** Version 3.1.0 released January 2025, requires Rails >= 6.1, Rails 8 compatible. It renders a month grid and maps any collection of objects to calendar days via a `start_time` attribute. The admin and client views both need a monthly calendar — this avoids building a grid from scratch. Customize via partials.

**`good_job` rationale:** Not needed in v1 (no background processing required), but the project will need it the moment email notifications or async thumbnails are added. Including it from the start costs nothing (PostgreSQL-backed, no new infrastructure). The alternative — Sidekiq — requires Redis, which adds operational cost for a 10-30 client app.

---

## What NOT to Use

| Technology | Reason |
|------------|--------|
| **Devise** | Overkill for this project. Admin auth is one user type with standard session-based login — Rails 8 built-in handles it. Client access is a token pattern incompatible with Devise's model. Adding Devise means wrestling with its generators, routes, and views for no benefit. |
| **React / Vue / Inertia** | Full JS frontend is not justified. Turbo Frames + 2-3 Stimulus controllers cover all dynamic UI requirements. React adds build pipeline, SSR considerations, API serialization, and state management — none of which are needed here. |
| **CarrierWave** | Predates ActiveStorage, requires manual cloud configuration, no longer the Rails default. ActiveStorage is bundled and better maintained. |
| **Shrine** | Architecturally superior to ActiveStorage for complex pipelines, but that complexity is not needed here. File sizes and processing requirements (thumbnails + previews) are within ActiveStorage's reliable range. |
| **Kaminari / will_paginate** | Slower and heavier than Pagy. Pagy is the current standard recommendation. |
| **Sprockets** | Rails 8 defaults to Propshaft. Sprockets is legacy — only add it if a gem you depend on explicitly requires it (none in this stack do). |
| **SQLite in production** | Rails 8 now includes Solid Cache/Queue/Cable that enable SQLite in production for single-server deploys. Appropriate for some projects — not this one. Concurrent writes from 10-30 clients approving arts simultaneously will cause lock contention. Use PostgreSQL. |
| **Redis** | Not needed. Good Job uses PostgreSQL for queuing. Action Cable can use the PostgreSQL adapter. Avoid adding Redis infrastructure for this scale. |
| **JWT** | No API clients consume this app. JWT adds complexity (expiry, refresh, key management) for a session-cookie flow that already works. The Rails session cookie is sufficient for admin; the custom token URL is sufficient for clients. |

---

## Confidence Levels

| Area | Confidence | Notes |
|------|------------|-------|
| Rails 8.1.3 as target | HIGH | Verified on RubyGems.org, March 2026 release |
| Rails built-in auth for admin | HIGH | Official Rails feature since 8.0; well documented |
| `has_secure_token` client pattern | HIGH | Core Rails feature; standard pattern for shareable links |
| ActiveStorage for uploads | HIGH | Built-in, official docs confirm all required features |
| External URL as plain string column | HIGH | Confirmed: ActiveStorage does not handle external links; string column is the correct approach |
| Hotwire (Turbo + Stimulus) | HIGH | Ships with Rails 8 by default; Context7 docs verified |
| `simple_calendar` gem | MEDIUM | Latest version 3.1.0 (Jan 2025), Rails 8 compatible per gemspec; no explicit Rails 8 integration test found, but no breaking changes identified |
| `good_job` for background jobs | HIGH | Actively maintained, PostgreSQL-backed, Rails 8 compatible |
| Pundit for authorization | MEDIUM | Not strictly needed in v1; include only if admin roles are added |
| Tailwind CSS via `tailwindcss-rails` | HIGH | Official Rails gem, Propshaft-compatible, no Node required |

---

## Gemfile Skeleton

```ruby
ruby "3.3.5"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"

gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

gem "image_processing", "~> 1.2"   # for ActiveStorage variants
gem "simple_calendar", "~> 3.1"
gem "pagy", "~> 9.3"
gem "good_job", "~> 4.0"
gem "dotenv-rails"

group :development, :test do
  gem "debug", platforms: %i[mri mswin]
  gem "brakeman"              # security audit
  gem "rubocop-rails-omakase"
end

group :development do
  gem "web-console"
  gem "rack-mini-profiler"
end
```

---

## Sources

- Rails 8.1.3 on RubyGems: https://rubygems.org/gems/rails/versions
- Rails 8.1 release announcement: https://rubyonrails.org/2025/10/22/rails-8-1
- Rails 8.0 release notes (auth generator): https://guides.rubyonrails.org/8_0_release_notes.html
- Rails 8 authentication deep dive: https://andriifurmanets.com/blogs/built-in-authentication-in-rails
- Rails built-in auth generator (Saeloun): https://blog.saeloun.com/2025/05/12/rails-8-adds-built-in-authentication-generator/
- ActiveStorage overview (official): https://guides.rubyonrails.org/active_storage_overview.html
- Turbo Rails (Context7): https://context7.com/hotwired/turbo-rails/llms.txt
- simple_calendar gem: https://github.com/excid3/simple_calendar
- Rails authorization patterns 2026: https://blog.saeloun.com/2026/04/28/rails-authorization-patterns-complete-guide/
- Pagy pagination: https://github.com/ddnexus/pagy
- Tailwind with Rails 8 Propshaft: https://radanskoric.com/articles/rails-assets-deep-dive-propshaft
