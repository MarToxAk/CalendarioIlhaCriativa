class ApprovalResponse < ApplicationRecord
  belongs_to :arte

  enum :decision, { approved: 0, change_requested: 1 }

  validates :decision, presence: true
  validate  :arte_must_be_pending, on: :create

  before_create { self.responded_at ||= Time.current }
  after_create  :sync_arte_status

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
end
