# frozen_string_literal: true

# Contrato do POST /api/v1/ai/artes (fase 33):
# - O arquivo da arte é aceito em multipart/form-data, no campo media_file (D-01).
# - Arquivo + external_url juntos viram 422 pela regra do model (D-02).
# - external_url sozinho continua aceito, mas a arte não é divulgável até um humano
#   subir o arquivo (D-03).
# - A arte nasce pending e o cliente aprova pelo link; não há atalho de aprovação (D-05).
# - Tipo ou tamanho inválidos viram 422 com field "media_file" (D-08).
# - media_file que não é arquivo (texto, Hash, signed id) vira 400 bad_request.
# - Se o arquivo não puder ser gravado, a resposta é 503 storage_unavailable, a arte é
#   removida e um novo POST não duplica.

class Api::V1::Ai::ArtesController < Api::V1::Ai::BaseController
  # Falhas do envio dos bytes ao storage (Disk, S3/MinIO). Resolvidas por nome na hora do
  # rescue: o aws-sdk só é carregado quando o serviço S3 é usado, e sem ele nenhum erro
  # Aws pode ter sido levantado. Outros erros pós-commit (ex.: enfileirar job) não entram.
  STORAGE_FAILURE_CLASSES = %w[
    IOError
    SystemCallError
    ActiveStorage::IntegrityError
    Aws::Errors::ServiceError
    Seahorse::Client::NetworkingError
  ].freeze

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
    begin
      @arte.save!
    rescue ActiveRecord::RecordInvalid
      raise
    rescue StandardError => e
      # O Active Storage envia os bytes em after_commit: se o storage falha, a linha da arte
      # (e do blob) já está gravada. Só uma falha de storage (STORAGE_FAILURE_CLASSES) com
      # arte persistida + anexo vira 503; qualquer outro erro segue como 500.
      raise unless storage_failure?(e) && @arte.persisted? && @arte.media_file.attached?

      Rails.logger.error("[ai/artes#create] falha ao gravar arquivo da arte ##{@arte.id}: #{e.class} - #{e.message}")
      discard_orphan_arte
      return render_error(
        code:   "storage_unavailable",
        detail: "Não foi possível gravar o arquivo da arte; nada foi criado. Tente novamente.",
        status: :service_unavailable
      )
    end

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
  # reaproveitaria o blob de outra arte. Só um upload multipart real é aceito. Apenas
  # ausente (nil) e media_file="" passam: são exatamente os valores que o Active Storage
  # trata como "sem anexo" e que caem na regra do model. Qualquer outro valor que não seja
  # upload (" ", false, número, lista, texto, signed id) vira 400, nunca 500.
  def media_file_param_invalid?
    value = params[:media_file]
    return false if value.nil? || value == ""

    !value.is_a?(ActionDispatch::Http::UploadedFile)
  end

  def storage_failure?(error)
    STORAGE_FAILURE_CLASSES.any? do |name|
      klass = name.safe_constantize
      klass && error.is_a?(klass)
    end
  end

  # Best-effort (precedente cancel_unscheduled da fase 32): uma falha ao apagar não pode
  # mascarar o 503. O dependent: :purge_later do anexo limpa o blob depois.
  def discard_orphan_arte
    @arte.destroy
  rescue StandardError => e
    Rails.logger.error("[ai/artes#create] falha ao remover arte órfã ##{@arte.id}: #{e.class} - #{e.message}")
  end

  def render_media_file_invalid
    render_error(
      code:   "bad_request",
      detail: "media_file deve ser enviado como arquivo em multipart/form-data.",
      status: :bad_request
    )
  end
end
