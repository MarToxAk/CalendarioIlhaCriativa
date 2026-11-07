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
class Api::V1::Ai::DivulgacoesController < Api::V1::Ai::BaseController
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
