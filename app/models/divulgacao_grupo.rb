class DivulgacaoGrupo < ApplicationRecord
  belongs_to :divulgacao
  belongs_to :whatsapp_group

  # Vocabulario verbatim do DIVU-09 — a fase 30 renderiza estes rotulos.
  # Nesta fase toda linha nasce e permanece :pendente.
  enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }

  validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }
  validates :group_name, :remote_jid, presence: true
end
