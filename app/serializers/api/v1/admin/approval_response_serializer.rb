# frozen_string_literal: true

module Api::V1::Admin::ApprovalResponseSerializer
  def self.serialize(approval_response, arte_status:)
    {
      id:           approval_response.id,
      decision:     approval_response.decision,
      comment:      approval_response.comment,
      responded_at: approval_response.responded_at,
      created_at:   approval_response.created_at,
      arte_status:  arte_status
    }
  end

  def self.serialize_collection(responses, arte_status:)
    responses.map { |r| serialize(r, arte_status: arte_status) }
  end
end
