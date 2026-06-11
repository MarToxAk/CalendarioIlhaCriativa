# frozen_string_literal: true

class Api::V1::Admin::ArtesController < Api::V1::Admin::BaseController
  def index
    scope = Arte.includes(:client).order(scheduled_on: :desc)
    scope = apply_filters(scope)
    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Admin::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    @arte = Arte.new(arte_params)
    @arte.external_url = nil if params[:media_file].present?
    @arte.save!
    render_envelope(
      data: Api::V1::Admin::ArteSerializer.serialize(@arte),
      status: :created
    )
  end

  private

  def apply_filters(scope)
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?
    if params[:status].present?
      raise ActionController::ParameterMissing.new(:status) unless Arte.statuses.key?(params[:status])
      scope = scope.where(status: params[:status])
    end
    if params[:month].present?
      begin
        date = Date.strptime(params[:month], "%Y-%m")
        scope = scope.where(scheduled_on: date.beginning_of_month..date.end_of_month)
      rescue Date::Error
        raise ActionController::ParameterMissing.new(:month)
      end
    end
    scope
  end

  def arte_params
    params.permit(
      :title, :caption, :scheduled_on, :approval_deadline,
      :external_url, :platform, :media_type, :client_id, :media_file
    )
  end
end
