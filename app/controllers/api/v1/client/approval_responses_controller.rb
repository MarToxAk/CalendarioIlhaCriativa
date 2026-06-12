# frozen_string_literal: true

class Api::V1::Client::ApprovalResponsesController < Api::V1::Client::BaseController
  before_action :set_arte

  def create
    # Enum guard antes da transação (D-10, Pitfall 4) — decision inválido → 400
    unless ApprovalResponse.decisions.key?(params[:decision].to_s)
      raise ActionController::ParameterMissing.new(:decision)
    end

    result = Arte.transaction do
      locked_arte = @current_client.artes.lock.find(@arte.id)
      response = locked_arte.approval_responses.build(response_params)
      response.save!
      { response: response, arte: locked_arte }
    end

    render_envelope(
      data: Api::V1::Client::ApprovalResponseSerializer.serialize(
        result[:response],
        arte_status: result[:arte].reload.status
      ),
      status: :created
    )
  end

  private

  def set_arte
    @arte = @current_client.artes.find(params[:arte_id])
  end

  def response_params
    params.permit(:decision, :comment)
  end
end
