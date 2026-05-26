class Client::ArtesController < ClientController
  before_action :set_arte

  def show
  end

  private

  def set_arte
    @arte = @client.artes.includes(:approval_responses).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to client_root_path(token: @client.access_token),
                alert: "Arte não encontrada."
  end
end
