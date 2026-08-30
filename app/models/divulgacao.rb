class Divulgacao < ApplicationRecord
  # Belt-and-suspenders alem da inflexao irregular em config/initializers/inflections.rb.
  self.table_name = "divulgacoes"

  belongs_to :client
  belongs_to :arte
  has_many :divulgacao_grupos, dependent: :destroy

  # prefix REQUIRED: divulgacao_grupos.status tem :pendente/:enviado — o prefixo
  # mantem status_agendada? / status_cancelada! explicitos e evita colisao futura.
  enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status

  validates :scheduled_for, presence: true
  validate :ao_menos_um_grupo

  private

  def ao_menos_um_grupo
    errors.add(:base, "Selecione ao menos um grupo para a divulgação.") if divulgacao_grupos.empty?
  end
end
