# frozen_string_literal: true

class Api::V1::Admin::BaseController < Api::V1::BaseController
  include Pagy::Backend
  before_action :authenticate_admin_jwt!
  before_action :set_active_storage_current

  rescue_from Pagy::OverflowError, with: :page_overflow

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

  def set_active_storage_current
    ActiveStorage::Current.url_options = {
      protocol: request.protocol,
      host:     request.host,
      port:     request.port
    }
  end

  def pagination_meta(pagy)
    {
      page:        pagy.page,
      per_page:    pagy.limit,
      total_count: pagy.count,
      total_pages: pagy.pages
    }
  end

  def per_page_param
    [ (params[:per_page] || 25).to_i, 100 ].min.clamp(1, 100)
  end

  def page_overflow
    render_error(code: "page_out_of_range", detail: "Página fora do intervalo", status: :not_found)
  end
end
