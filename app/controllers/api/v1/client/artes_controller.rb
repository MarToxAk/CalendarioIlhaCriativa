# frozen_string_literal: true

class Api::V1::Client::ArtesController < Api::V1::Client::BaseController
  def index
    scope = @current_client.artes.where(status: %w[pending revised]).order(:scheduled_on)
    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Client::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def show
    @arte = @current_client.artes.includes(:approval_responses).find(params[:id])
    render_envelope(data: Api::V1::Client::ArteSerializer.serialize(@arte))
  end
end
