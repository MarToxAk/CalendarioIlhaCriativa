class Admin::DashboardController < Admin::BaseController
  def index
    scope = Arte.includes(:approval_responses)
                .joins(:client)
                .order("clients.name ASC, artes.scheduled_on DESC")

    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    scope = scope.where(status: params[:status]) if params[:status].present? && Arte.statuses.keys.include?(params[:status].to_s)

    @artes_by_client = scope.group_by(&:client)
    @clients = Client.order(:name)
  end
end
