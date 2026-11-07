# frozen_string_literal: true

# API de IA — Divulgacoes (fase 32).
#
# CONTRATO DO POST /api/v1/ai/divulgacoes (D-02):
#
# * O POST AGENDA DE VERDADE: tem o mesmo efeito do botao "Agendar" do admin,
#   incluindo o job real de disparo (Divulgacoes::DispatchJob) enfileirado para
#   o horario de scheduled_for. Nao existe modo "rascunho" nem simulacao.
# * NAO ha campo de confirmacao: quem opera a IA confirma com o humano ANTES de
#   chamar este endpoint.
# * O POST NAO e idempotente: um retry apos timeout cria uma segunda divulgacao
#   e cada grupo recebe duas mensagens. Antes de repetir uma chamada que deu
#   timeout, consulte a listagem do cliente filtrada por status agendada.
# * scheduled_for deve ser ISO 8601 com offset explicito (ex.
#   2026-11-05T14:00:00-03:00; "Z" tambem e normalizado para o fuso da
#   aplicacao). Valor ilegivel, ausente ou no passado cai em 422 com a mensagem
#   do model.
#
# Escopo (D-09): arte e grupos sao SEMPRE resolvidos pela associacao do cliente
# informado. Um id de outro cliente (ou grupo inativo) resulta no 404 generico
# herdado do controller base — nunca revela de quem e o id.
#
# CONTRATO DO GET /api/v1/ai/divulgacoes (D-03, D-11, D-12, D-13):
#
# * client_id e OBRIGATORIO: a listagem e sempre de UM cliente (400 se ausente
#   ou malformado, 404 se inexistente). Nao existe listagem entre clientes.
# * status e opcional e aceita so os 4 valores do enum (agendada, em_andamento,
#   concluida, cancelada); qualquer outro valor e 400, nunca uma lista vazia.
# * from/to sao opcionais, inclusivos, formato YYYY-MM-DD, sobre scheduled_for.
#   Um so extremo e aceito (intervalo aberto); o dia inteiro de "to" entra.
#   400 para data ilegivel ou from depois de to.
# * Ordenacao por scheduled_for crescente (as proximas primeiro), desempate por
#   id. Paginacao por page/per_page (25 por padrao, maximo 100).
class Api::V1::Ai::DivulgacoesController < Api::V1::Ai::BaseController
  # Filtro de listagem invalido vira 400 estruturado (mesmo code do Artes#index).
  class InvalidFilter < StandardError; end

  rescue_from InvalidFilter do |e|
    render_error(code: "bad_request", detail: e.message, status: :bad_request)
  end

  def index
    # permit antes do require: client_id em formato Hash/Array vira ausencia
    # (400), nunca 500. Nao ha ramo sem client_id.
    client = Client.find(params.permit(:client_id).require(:client_id))

    # includes: o serializer le a associacao ja carregada (sem 1 query por linha).
    # Desempate por id deixa a paginacao estavel.
    scope = client.divulgacoes.includes(:divulgacao_grupos).order(scheduled_for: :asc, id: :asc)
    scope = scope.where(status: status_filter) if params[:status].present?
    range = period_range
    scope = scope.where(scheduled_for: range) if range

    @pagy, @divulgacoes = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Ai::DivulgacaoSerializer.serialize_collection(@divulgacoes),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    attrs = create_params

    # require ANTES de qualquer lookup: ausente/malformado -> 400 herdado.
    client_id = attrs.require(:client_id)
    arte_id   = attrs.require(:arte_id)

    # D-05: client_id explicito, nunca inferido da arte.
    client = Client.find(client_id)
    arte   = client.artes.find(arte_id)

    gids   = Array(attrs[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
    groups = scoped_active_groups(client).find(gids)

    # D-07: a string vai direto ao atributo; o cast do Rails normaliza offset/Z.
    divulgacao = client.divulgacoes.new(arte: arte, scheduled_for: attrs[:scheduled_for])
    groups.each do |g|
      divulgacao.divulgacao_grupos.build(
        whatsapp_group: g,
        group_name:     g.display_name,
        remote_jid:     g.remote_jid
      )
    end

    # D-08: as validacoes existentes do model viram RecordInvalid -> 422.
    divulgacao.save!

    # Mesmo job do admin, SO depois de persistir (ENVIO-01).
    Divulgacoes::DispatchJob.set(wait_until: divulgacao.scheduled_for).perform_later(divulgacao)

    render_envelope(data: Api::V1::Ai::DivulgacaoSerializer.serialize(divulgacao), status: :created)
  end

  private

  # Validacao explicita: um where com valor de enum desconhecido viraria
  # "status IS NULL" e devolveria 200 com lista vazia, escondendo o erro do
  # agente. Array/Hash tambem nao sao chave do enum e caem aqui (400).
  def status_filter
    value = params[:status]
    return value if Divulgacao.statuses.key?(value)

    raise InvalidFilter, "Status inválido. Use: #{Divulgacao.statuses.keys.join(', ')}."
  end

  # Intervalo de scheduled_for com limites de DIA no fuso do app. Nao usar um
  # range de Date direto: sobre a coluna datetime ele vira BETWEEN a meia-noite
  # e exclui o ultimo dia inteiro (uma divulgacao as 23:30 de "to" sumiria).
  # nil quando nenhum dos dois extremos veio; um so extremo gera intervalo aberto.
  def period_range
    return nil unless params[:from].present? || params[:to].present?

    from = parse_date(:from)
    to   = parse_date(:to)
    if from && to && from > to
      raise InvalidFilter, "O parâmetro 'from' deve ser anterior ou igual a 'to'."
    end

    from&.in_time_zone&.beginning_of_day..to&.in_time_zone&.end_of_day
  end

  def parse_date(key)
    return nil if params[key].blank?

    Date.iso8601(params[key].to_s)
  rescue Date::Error
    raise InvalidFilter, "Formato de data inválido. Use YYYY-MM-DD."
  end

  # Allowlist: formatos Hash/Array nos escalares sao descartados e o status
  # nunca e permitido — a divulgacao nasce sempre agendada (default do enum).
  def create_params
    params.permit(:client_id, :arte_id, :scheduled_for, whatsapp_group_ids: [])
  end

  # Mesma fonte do admin; cliente sem instancia degrada para none (404 em qualquer id).
  def scoped_active_groups(client)
    client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
  end
end
