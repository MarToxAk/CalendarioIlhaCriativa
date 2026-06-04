class Admin::ApprovalsController < Admin::BaseController
  def index
    scope = ApprovalResponse.joins(arte: :client)
                            .includes(arte: :client)
                            .order(responded_at: :desc)

    scope = scope.where(artes: { client_id: params[:client_id] }) if params[:client_id].present?

    if params[:decision].present? && ApprovalResponse.decisions.key?(params[:decision])
      scope = scope.where(decision: params[:decision])
    end

    @pagy, @approval_responses = pagy(scope, limit: 25)
    @clients = Client.order(:name)
  end
end
