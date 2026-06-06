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
    return unless arte
    errors.add(:arte, "não está em estado aprovável") unless arte.pending? || arte.revised?
  end

  def sync_arte_status
    case decision
    when "approved"         then arte.approved!
    when "change_requested" then arte.change_requested!
    end
  end

  def broadcasts_to_admin
    admin = User.order(:id).first
    return unless admin

    arte_with_client = Arte.eager_load(:client).find(arte_id)
    badge_count      = Arte.change_requested.count

    toast_html    = render_partial_html(
      partial: "admin/shared/approval_toast",
      locals:  { approval_response: self, arte: arte_with_client }
    )
    badge_html    = render_partial_html(
      partial: "admin/shared/sidebar_badge",
      locals:  { badge_count: badge_count }
    )
    dashboard_html = render_partial_html(
      partial: "admin/dashboard/arte_dashboard_row",
      locals:  { arte: arte_with_client }
    )
    approvals_html = render_partial_html(
      partial: "admin/approvals/approval_row",
      locals:  { approval_response: self, arte: arte_with_client }
    )

    content = [
      turbo_stream_tag("append",  "admin-toast-region",          toast_html),
      turbo_stream_tag("replace", "sidebar-badge",               badge_html),
      turbo_stream_tag("replace", ActionView::RecordIdentifier.dom_id(arte_with_client), dashboard_html),
      turbo_stream_tag("prepend", "approvals-tbody",             approvals_html)
    ].join

    AdminNotificationsChannel.broadcast_to(admin, content)
  end

  def render_partial_html(partial:, locals:)
    ApplicationController.render(partial: partial, locals: locals, formats: [ :html ])
  end

  def turbo_stream_tag(action, target, template_html = "")
    %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
  end
end
