class Arte < ApplicationRecord
  belongs_to :client
  has_many :approval_responses, -> { order(created_at: :desc) }, dependent: :destroy
  has_one_attached :media_file

  # Test-only hook — allows integration tests to simulate destroy returning false
  # without Mocha. Set Arte.test_block_destroy = true before the request,
  # reset to false in ensure. Never active in production (Rails.env.test? guard).
  if Rails.env.test?
    class << self
      attr_accessor :test_block_destroy
    end
    self.test_block_destroy = false

    before_destroy :__test_block_destroy_hook__
    def __test_block_destroy_hook__
      throw :abort if self.class.test_block_destroy
    end
  end

  enum :platform,   { instagram: 0, facebook: 1, linkedin: 2 }, prefix: :platform
  enum :media_type, { image: 0, video: 1, caption_only: 2 }
  enum :status,     { pending: 0, approved: 1, change_requested: 2, revised: 3 }

  after_update_commit :broadcasts_revised_to_all, if: -> { saved_change_to_status? && revised? }

  validates :scheduled_on, presence: true
  validates :platform,     presence: true
  validates :media_type,   presence: true
  validates :client,       presence: true

  validate :media_source_present
  validate :only_one_media_source
  validates :external_url, format: { with: /\Ahttps?:\/\/\S+\z/, message: "deve começar com http:// ou https://" }, allow_blank: true

  private

  def broadcasts_revised_to_all
    admin = User.order(:id).first
    return unless admin

    # Contagem global (todos os clientes) — badge admin mostra pendências totais, não por cliente
    badge_count = Arte.change_requested.count

    chip_html  = render_partial_html(
      partial: "client/home/arte_calendar_chip",
      locals:  { arte: self, client: client }
    )
    toast_html = render_partial_html(
      partial: "client/shared/arte_revised_toast",
      locals:  { arte: self, client: client }
    )
    badge_html = render_partial_html(
      partial: "admin/shared/sidebar_badge",
      locals:  { badge_count: badge_count }
    )

    # Envia apenas chip e toast ao cliente; o #calendar-summary não é atualizado
    # em tempo real porque a arte revisada pode pertencer a um mês diferente do
    # mês que o cliente está visualizando — sobrescrever causaria dados incorretos.
    chip_target    = ActionView::RecordIdentifier.dom_id(self, "calendar_chip")
    client_streams = [
      turbo_stream_tag("replace", chip_target,           chip_html),
      turbo_stream_tag("append",  "client-toast-region", toast_html)
    ].join
    admin_stream = turbo_stream_tag("replace", "sidebar-badge", badge_html)

    ClientCalendarChannel.broadcast_to(client, client_streams)
    AdminNotificationsChannel.broadcast_to(admin, admin_stream)
  end

  def render_partial_html(partial:, locals:)
    ApplicationController.render(partial: partial, locals: locals, formats: [ :html ])
  end

  def turbo_stream_tag(action, target, template_html = "")
    %(<turbo-stream action="#{action}" target="#{target}"><template>#{template_html}</template></turbo-stream>)
  end

  def media_source_present
    return if media_file.attached? || external_url.present?
    errors.add(:base, "Precisa de arquivo ou link externo")
  end

  def only_one_media_source
    return unless media_file.attached? && external_url.present?
    errors.add(:base, "Use arquivo OU link externo, não ambos")
  end
end
