class ApprovalResponse < ApplicationRecord
  belongs_to :arte

  enum :decision, { approved: 0, change_requested: 1 }

  validates :decision, presence: true
  validate  :arte_must_be_pending, on: :create

  before_create { self.responded_at ||= Time.current }
  after_create  :sync_arte_status
  after_create_commit :broadcasts_to_admin

  private

  def arte_must_be_pending
    errors.add(:arte, "não está em estado aprovável") unless arte.pending? || arte.revised?
  end

  def sync_arte_status
    case decision
    when "approved"         then arte.approved!
    when "change_requested" then arte.change_requested!
    end
  end

  def broadcasts_to_admin
    admin = User.first
    return unless admin

    arte_with_client = Arte.includes(:client).find(arte_id)
    badge_count      = Arte.change_requested.count

    streams = [
      turbo_stream.append(
        "admin-toast-region",
        partial: "admin/shared/approval_toast",
        locals:  { approval_response: self, arte: arte_with_client }
      ),
      (turbo_stream.replace(
        "sidebar-badge",
        partial: "admin/shared/sidebar_badge",
        locals:  { badge_count: badge_count }
      ) if decision == "change_requested"),
      turbo_stream.replace(
        dom_id(arte_with_client),
        partial: "admin/dashboard/arte_dashboard_row",
        locals:  { arte: arte_with_client }
      ),
      turbo_stream.prepend(
        "approvals-tbody",
        partial: "admin/approvals/approval_row",
        locals:  { approval_response: self }
      )
    ].compact

    AdminNotificationsChannel.broadcast_to(admin, turbo_stream: streams)
  end
end
