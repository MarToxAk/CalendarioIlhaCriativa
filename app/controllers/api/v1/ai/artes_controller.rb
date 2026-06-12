# frozen_string_literal: true

class Api::V1::Ai::ArtesController < Api::V1::Ai::BaseController
  def index
    # D-01/D-02: from e to são obrigatórios — 400 se ausentes
    raise ActionController::ParameterMissing.new("from e to são obrigatórios") unless params[:from].present? && params[:to].present?

    scope = Arte.approved.order(scheduled_on: :asc)

    # D-03: filtro opcional por client_id
    scope = scope.where(client_id: params[:client_id]) if params[:client_id].present?

    # D-04/D-05: parsear datas e filtrar período
    begin
      from = Date.parse(params[:from])
      to   = Date.parse(params[:to])
      scope = scope.where(scheduled_on: from..to)
    rescue Date::Error
      render_error(code: "bad_request", detail: "Formato de data inválido. Use YYYY-MM-DD.", status: :bad_request)
      return
    end

    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Ai::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    # D-06: IA usa apenas external_url — upload direto não é suportado
    if params[:media_file].present?
      render_error(code: "bad_request", detail: "Upload de arquivo não é suportado. Use external_url.", status: :bad_request)
      return
    end

    @arte = Arte.new(arte_params)
    @arte.save!
    render_envelope(data: Api::V1::Ai::ArteSerializer.serialize(@arte), status: :created)
  end

  private

  def arte_params
    params.permit(
      :title, :caption, :scheduled_on, :approval_deadline,
      :external_url, :platform, :media_type, :client_id
    )
  end
end
