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

  validates :scheduled_on, presence: true
  validates :platform,     presence: true
  validates :media_type,   presence: true
  validates :client,       presence: true

  validate :media_source_present
  validate :only_one_media_source

  private

  def media_source_present
    return if media_file.attached? || external_url.present?
    errors.add(:base, "Precisa de arquivo ou link externo")
  end

  def only_one_media_source
    return unless media_file.attached? && external_url.present?
    errors.add(:base, "Use arquivo OU link externo, não ambos")
  end
end
