class Admin::ApprovalsController < Admin::BaseController
  def index
    scope = ApprovalResponse.joins(arte: :client)
                            .includes(arte: :client)
                            .order(responded_at: :desc)

    if params[:client_id].present?
      client_id = params[:client_id].to_i
      scope = scope.where(artes: { client_id: client_id }) if client_id > 0
    end

    if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
      scope = scope.where(decision: params[:decision])
    end

    @pagy, @approval_responses = pagy(scope, limit: 25,
      params: { client_id: params[:client_id], decision: params[:decision] }.compact_blank)
    @clients = Client.order(:name)
  end
end
