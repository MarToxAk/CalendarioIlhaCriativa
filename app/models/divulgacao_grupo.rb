class DivulgacaoGrupo < ApplicationRecord
  belongs_to :divulgacao
  belongs_to :whatsapp_group

  # Vocabulario verbatim do DIVU-09 — a fase 30 renderiza estes rotulos.
  # Nesta fase toda linha nasce e permanece :pendente.
  enum :status, { pendente: 0, enviado: 1, falhou: 2, incerto: 3 }

  # ACOMP-01 / fase 30: mesmo padrao de arte.rb:27 — after_update_commit guardado por
  # saved_change_to_status?. Replace granular: a propria <li> (dom_id(self)) e a
  # linha-resumo agregada (dom_id(divulgacao, :progresso)), nunca a lista inteira.
  after_update_commit :broadcast_progresso, if: -> { saved_change_to_status? }

  validates :whatsapp_group_id, uniqueness: { scope: :divulgacao_id }
  validates :group_name, :remote_jid, presence: true

  private

  def broadcast_progresso
    broadcast_replace_to [ divulgacao.client, divulgacao ],
      target: ActionView::RecordIdentifier.dom_id(self),
      partial: "admin/divulgacoes/grupo_row", locals: { dg: self }
    broadcast_replace_to [ divulgacao.client, divulgacao ],
      target: ActionView::RecordIdentifier.dom_id(divulgacao, :progresso),
      partial: "admin/divulgacoes/progresso_resumo", locals: { divulgacao: divulgacao }
  end
end
