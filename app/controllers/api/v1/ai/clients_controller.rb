# frozen_string_literal: true

class Api::V1::Ai::ClientsController < Api::V1::Ai::BaseController
  # page=abc / page=0 / page=-1 levantam Pagy::VariableError (supertipo do
  # OverflowError, que o base trata como 404): viram 400 estruturado em vez de 500.
  # Declarado aqui (e nao no base) porque este handler, por ser mais novo, tambem
  # casaria o OverflowError — por isso delega de volta ao page_overflow.
  rescue_from Pagy::VariableError do |e|
    next page_overflow if e.is_a?(Pagy::OverflowError)

    render_error(code: "bad_request", detail: "Parâmetro de paginação inválido.", status: :bad_request)
  end

  def summary
    # D-11: RecordNotFound automático → 404 via rescue_from herdado (T-24-07)
    client = Client.find(params[:id])

    # `group(:status).count` retorna chaves pelo RÓTULO do enum ("approved"), não
    # pelo inteiro — indexar por Arte.statuses["approved"] (1) devolvia sempre nil.
    counts = Arte.where(client_id: client.id).group(:status).count

    total                  = counts.values.sum
    approved_count         = counts["approved"].to_i
    pending_count          = counts["pending"].to_i
    change_requested_count = counts["change_requested"].to_i
    revised_count          = counts["revised"].to_i

    render_envelope(data: {
      client_id:             client.id,
      total:,
      approved_count:,
      pending_count:,
      change_requested_count:,
      revised_count:
    })
  end

  # Fase 32 (D-06, D-13): descoberta dos ids de grupo para o POST /api/v1/ai/divulgacoes.
  # Le SO o cache local de grupos (nunca fala com o Evolution) e SO os ativos, pela mesma
  # expressao e ordem do admin. A fase 31 deu a cada cliente a SUA linha de instancia (e
  # os SEUS grupos), entao a lista continua isolada por cliente mesmo com conexao fisica
  # compartilhada — nunca consultar pelo nome da conexao. Cliente sem instancia -> 200 com
  # lista vazia (o POST correspondente falharia seguro em 422 "Selecione ao menos um
  # grupo"). Os `id` devolvidos sao os valores de `whatsapp_group_ids` do POST.
  def whatsapp_groups
    client = Client.find(params[:id])

    groups = client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
    groups = groups.order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid)

    @pagy, @groups = pagy(groups, limit: per_page_param)

    render_envelope(
      data: Api::V1::Ai::WhatsappGroupSerializer.serialize_collection(@groups),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end
end
