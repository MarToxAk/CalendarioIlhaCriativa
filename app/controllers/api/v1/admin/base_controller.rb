# frozen_string_literal: true

class Api::V1::Admin::BaseController < Api::V1::BaseController
  before_action :authenticate_admin_jwt!

  private

  def authenticate_admin_jwt!
    token = bearer_token
    return render_unauthorized unless token
    return render_unauthorized if token.start_with?("ak_")  # AI API key, not an admin JWT — D-07

    claims = Api::JwtService.decode(token)
    return render_unauthorized unless claims[:scope] == "admin"

    @current_user = User.find_by(id: claims[:sub])
    render_unauthorized unless @current_user
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
