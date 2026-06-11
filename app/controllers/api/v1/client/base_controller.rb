# frozen_string_literal: true

class Api::V1::Client::BaseController < Api::V1::BaseController
  before_action :authenticate_client_jwt!

  private

  def authenticate_client_jwt!
    token = bearer_token
    return render_unauthorized unless token

    claims = Api::JwtService.decode(token)
    return render_unauthorized unless claims[:scope] == "client"

    @current_client = Client.find_by(id: claims[:sub])
    return render_unauthorized unless @current_client
    render_unauthorized unless @current_client.active?
  rescue Api::Errors::TokenExpired, Api::Errors::TokenInvalid
    render_unauthorized
  end

  def bearer_token
    request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip.presence
  end

  def render_unauthorized
    render_error(code: "unauthorized", detail: "Autenticação inválida ou expirada", status: :unauthorized)
  end
end
