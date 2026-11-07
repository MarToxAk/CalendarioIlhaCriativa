# frozen_string_literal: true

# Serializer da Divulgacao para a API de IA (D-10). Allowlist explicita de chaves:
# nao expoe o identificador da mensagem no gateway do WhatsApp nem o id interno
# do grupo — so o que a IA precisa para acompanhar o disparo.
module Api::V1::Ai::DivulgacaoSerializer
  def self.serialize(divulgacao)
    {
      id:            divulgacao.id,
      client_id:     divulgacao.client_id,
      arte_id:       divulgacao.arte_id,
      status:        divulgacao.status,
      scheduled_for: divulgacao.scheduled_for,
      created_at:    divulgacao.created_at,
      updated_at:    divulgacao.updated_at,
      # Ordenado em Ruby (nunca .order na associacao): respeita o includes de quem
      # lista varias divulgacoes e nao dispara uma query por divulgacao.
      grupos:        divulgacao.divulgacao_grupos.sort_by(&:id).map { |dg| serialize_grupo(dg) }
    }
  end

  def self.serialize_collection(divulgacoes)
    divulgacoes.map { |d| serialize(d) }
  end

  private_class_method def self.serialize_grupo(divulgacao_grupo)
    {
      group_name: divulgacao_grupo.group_name,
      remote_jid: divulgacao_grupo.remote_jid,
      status:     divulgacao_grupo.status,
      sent_at:    divulgacao_grupo.sent_at,
      error_code: divulgacao_grupo.error_code
    }
  end
end
