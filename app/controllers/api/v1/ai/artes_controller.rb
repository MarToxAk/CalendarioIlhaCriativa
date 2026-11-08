# frozen_string_literal: true

# Contrato do POST /api/v1/ai/artes (fase 33):
# - O arquivo da arte é aceito em multipart/form-data, no campo media_file (D-01).
# - Arquivo + external_url juntos viram 422 pela regra do model (D-02).
# - external_url sozinho continua aceito, mas a arte não é divulgável até um humano
#   subir o arquivo (D-03).
# - A arte nasce pending e o cliente aprova pelo link; não há atalho de aprovação (D-05).
# - Tipo ou tamanho inválidos viram 422 com field "media_file" (D-08).
# - media_file que não é arquivo (texto, Hash, signed id) vira 400 bad_request.

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
    rescue Date::Error
      render_error(code: "bad_request", detail: "Formato de data inválido. Use YYYY-MM-DD.", status: :bad_request)
      return
    end

    if from > to
      render_error(
        code:   "bad_request",
        detail: "O parâmetro 'from' deve ser anterior ou igual a 'to'.",
        status: :bad_request
      )
      return
    end

    scope = scope.where(scheduled_on: from..to)

    @pagy, @artes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Ai::ArteSerializer.serialize_collection(@artes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    return render_media_file_invalid if media_file_param_invalid?

    @arte = Arte.new(arte_params)
    @arte.save!
    render_envelope(data: Api::V1::Ai::ArteSerializer.serialize(@arte), status: :created)
  end

  private

  def arte_params
    params.permit(
      :title, :caption, :scheduled_on, :approval_deadline,
      :external_url, :platform, :media_type, :client_id, :media_file
    )
  end

  # T-33-01: o Active Storage trata uma String atribuída ao anexo como signed blob id.
  # Sem este guard, uma String vira 500 (assinatura inválida) e um signed id válido
  # reaproveitaria o blob de outra arte. Só um upload multipart real é aceito; valor em
  # branco (media_file="") segue como ausente e cai na regra do model.
  def media_file_param_invalid?
    value = params[:media_file]
    value.present? && !value.is_a?(ActionDispatch::Http::UploadedFile)
  end

  def render_media_file_invalid
    render_error(
      code:   "bad_request",
      detail: "media_file deve ser enviado como arquivo em multipart/form-data.",
      status: :bad_request
    )
  end
end
