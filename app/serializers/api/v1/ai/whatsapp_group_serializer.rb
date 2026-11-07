# frozen_string_literal: true

# Serializer de grupo de WhatsApp para a API de IA (fase 32, D-06).
#
# Este modulo e a ALLOWLIST: devolve apenas o identificador interno (o valor que a IA
# envia em `whatsapp_group_ids` ao agendar uma divulgacao), o identificador remoto do
# grupo e o rotulo de exibicao. Nada da conexao do cliente (credencial, estado de
# pareamento, identificadores do gateway) nem metadados de sincronizacao sai por aqui —
# qualquer campo novo precisa ser adicionado de forma explicita neste hash.
module Api::V1::Ai::WhatsappGroupSerializer
  def self.serialize(group)
    {
      id:           group.id,
      remote_jid:   group.remote_jid,
      display_name: group.display_name
    }
  end

  def self.serialize_collection(groups)
    groups.map { |g| serialize(g) }
  end
end
