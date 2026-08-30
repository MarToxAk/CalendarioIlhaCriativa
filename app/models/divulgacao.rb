class Divulgacao < ApplicationRecord
  # Belt-and-suspenders alem da inflexao irregular em config/initializers/inflections.rb.
  self.table_name = "divulgacoes"

  # Teto de midia regular do WhatsApp (~16 MB). Heuristica conservadora (28-RESEARCH
  # Assumption A1) — a UAT da fase 29 mede o teto real do gateway Evolution e este
  # numero e um update de uma linha se estiver errado. Colocado junto da validacao
  # que o consome (arquivo_dentro_do_teto_whatsapp).
  WHATSAPP_MEDIA_MAX_BYTES = 16.megabytes

  belongs_to :client
  belongs_to :arte
  has_many :divulgacao_grupos, dependent: :destroy

  # prefix REQUIRED: divulgacao_grupos.status tem :pendente/:enviado — o prefixo
  # mantem status_agendada? / status_cancelada! explicitos e evita colisao futura.
  enum :status, { agendada: 0, em_andamento: 1, concluida: 2, cancelada: 3 }, prefix: :status

  # Todas as mensagens de validacao de criacao caem em errors[:base] — a view
  # (new.html.erb) tem uma unica caixa vermelha que itera errors[:base], sem
  # estilizacao por mensagem (28-UI-SPEC "Copywriting Contract").
  validate :scheduled_for_presente
  validate :scheduled_for_no_futuro
  validate :arte_deve_estar_aprovada
  validate :arte_nao_usa_link_externo
  validate :arquivo_dentro_do_teto_whatsapp
  validate :arte_e_grupos_do_mesmo_cliente
  validate :ao_menos_um_grupo

  private

  # DIVU-05 / 28-UI-SPEC: mensagem de branco verbatim, em errors[:base] (nao em
  # errors[:scheduled_for]) para passar pela unica caixa de erro do form.
  def scheduled_for_presente
    errors.add(:base, "Informe a data e hora do envio.") if scheduled_for.blank?
  end

  # RESOLVIDO em 28-CONTEXT: agendamento e futuro-only. Branco ja e tratado por
  # scheduled_for_presente — aqui so o passado.
  def scheduled_for_no_futuro
    return if scheduled_for.blank?
    errors.add(:base, "A data e hora do envio precisam estar no futuro.") if scheduled_for <= Time.current
  end

  # DIVU-02: defense-in-depth atras do picker @client.artes.approved — o status da
  # arte pode mudar entre o load do form e o submit.
  def arte_deve_estar_aprovada
    return if arte.nil? || arte.approved?
    errors.add(:base, "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação.")
  end

  # DIVU-03 (CONTEXT resolvido): recusa SO quando ha link externo. NAO recusa por
  # ausencia de media_file — uma arte caption_only (sem arquivo, sem link, com
  # caption) e uma Divulgacao valida (fase 29 ENVIO-10 envia via sendText). Nenhuma
  # validacao da Arte e tocada — a Arte continua aceitando external_url.
  def arte_nao_usa_link_externo
    return if arte.nil?
    return if arte.external_url.blank?
    errors.add(:base, "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a divulgação.")
  end

  # DIVU-04: teto mais apertado que os 50 MB da Arte, so no create da Divulgacao.
  # So roda quando ha arquivo anexado (caption_only isento). Mensagem diz o tamanho
  # atual, o teto e o que fazer — number_to_human_size da "16 MB" / "20 MB" com
  # virgula decimal sob o locale :pt-BR.
  def arquivo_dentro_do_teto_whatsapp
    return if arte.nil? || !arte.media_file.attached?
    size = arte.media_file.blob.byte_size
    return if size <= WHATSAPP_MEDIA_MAX_BYTES
    errors.add(:base,
      "O arquivo tem #{ActiveSupport::NumberHelper.number_to_human_size(size)}, " \
      "acima do limite de #{ActiveSupport::NumberHelper.number_to_human_size(WHATSAPP_MEDIA_MAX_BYTES)} " \
      "que o WhatsApp aceita para mídia. Comprima ou reenvie um arquivo menor na arte.")
  end

  # SEG-02 backstop: regressao atras do .find escopado do controller. A arte e todos
  # os grupos construidos precisam pertencer ao mesmo cliente da divulgacao.
  def arte_e_grupos_do_mesmo_cliente
    return if arte.nil?
    if arte.client_id != client_id
      errors.add(:base, "A arte e os grupos precisam ser do mesmo cliente.")
      return
    end
    foreign = divulgacao_grupos.reject { |dg| dg.whatsapp_group&.whatsapp_instance&.client_id == client_id }
    errors.add(:base, "Um ou mais grupos selecionados não pertencem a este cliente.") if foreign.any?
  end

  def ao_menos_um_grupo
    errors.add(:base, "Selecione ao menos um grupo para a divulgação.") if divulgacao_grupos.empty?
  end
end
