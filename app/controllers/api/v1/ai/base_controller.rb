# frozen_string_literal: true

class Api::V1::Ai::BaseController < Api::V1::BaseController
  before_action :authenticate_ai_key!

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
end
