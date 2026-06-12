# frozen_string_literal: true

class Api::V1::Ai::BaseController < Api::V1::BaseController
  include Pagy::Backend
  before_action :authenticate_ai_key!
  before_action :set_active_storage_current

  rescue_from Pagy::OverflowError, with: :page_overflow

  private

  def authenticate_ai_key!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

    # D-07: ak_ prefix identifies AI API keys — must be present
    return render_unauthorized unless token&.start_with?("ak_")

    # D-08: key stored in credentials/ENV, never in the DB
    expected = Rails.application.credentials.dig(:api, :ai_key) ||
               ENV["AI_API_KEY"]
    return render_unauthorized unless expected

    # T-21-17: constant-time comparison to prevent timing attacks — never use ==
    unless ActiveSupport::SecurityUtils.secure_compare(token, expected)
      render_unauthorized
    end
  end

  def render_unauthorized
    render_error(code: "unauthorized", detail: "API key inválida", status: :unauthorized)
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
    [(params[:per_page] || 25).to_i, 100].min.clamp(1, 100)
  end

  def page_overflow
    render_error(code: "page_out_of_range", detail: "Página fora do intervalo", status: :not_found)
  end
end
