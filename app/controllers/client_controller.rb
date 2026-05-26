class ClientController < ApplicationController
  layout 'client'

  skip_before_action :require_authentication

  before_action :load_client_from_token
  before_action :require_client_auth

  private

  def load_client_from_token
    @client = Client.find_by!(access_token: params[:token])
    unless @client.active?
      render plain: "Acesso bloqueado", status: :forbidden
    end
  rescue ActiveRecord::RecordNotFound
    render plain: "Link inválido", status: :not_found
  end

  def require_client_auth
    unless session[:client_id] == @client.id &&
           session[:client_token_version] == @client.token_version
      session.delete(:client_id)
      session.delete(:client_token_version)
      redirect_to new_client_session_path(token: @client.access_token)
    end
  end
end
