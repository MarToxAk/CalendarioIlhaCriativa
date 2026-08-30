# Deferred Items — Phase 27

Out-of-scope findings discovered during plan execution. Not fixed (Scope Boundary rule) — logged
for visibility only.

## 27-02

- **`test/controllers/admin/dashboard_controller_test.rb:70` (`test_sidebar_badge_absent_when_no_change_requested_artes`) fails in isolation, unrelated to this plan.** `bin/rails test test/controllers/admin/dashboard_controller_test.rb` → `Expected exactly 0 elements matching "span#sidebar-badge", found 1.` No file touched by 27-02 (`app/jobs/whatsapp/`, `app/controllers/admin/whatsapp_groups_controller.rb`, `app/javascript/controllers/group_sync_controller.js`, `app/helpers/admin/whatsapp_groups_helper.rb`, `app/views/admin/whatsapp_instances/_panel.html.erb`, `config/initializers/rack_attack.rb`) has any relationship to `Admin::DashboardController`, the sidebar badge, `Arte`, or `ApprovalResponse`. Same family as the 3 pre-existing failures documented in `27-01-SUMMARY.md` (`arte_test.rb:94`, `approval_response_test.rb:158,174` — turbo-stream/N+1 assertions desalinhadas com o HTML/broadcast atual). Not fixed here — out of scope for 27-02.
