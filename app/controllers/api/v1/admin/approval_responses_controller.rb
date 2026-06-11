# frozen_string_literal: true

class Api::V1::Admin::ApprovalResponsesController < Api::V1::Admin::BaseController
  before_action :set_arte

  def index
    responses = @arte.approval_responses
    render_envelope(
      data: Api::V1::Admin::ApprovalResponseSerializer.serialize_collection(
        responses, arte_status: @arte.status
      ),
      meta: { arte_status: @arte.status }
    )
  end

  private

  def set_arte
    @arte = Arte.find(params[:arte_id])
  end
end
