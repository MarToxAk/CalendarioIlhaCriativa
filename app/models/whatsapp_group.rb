# frozen_string_literal: true

# Cache local de grupos do WhatsApp de uma instância (fase 27, GRUPO-01).
# Populado exclusivamente por Whatsapp::GroupSynchronizer via upsert_all — este
# model NUNCA fala com o Evolution. display_name é método puro (não
# before_save) porque upsert_all pula todos os callbacks (RESEARCH Pitfall 3).
class WhatsappGroup < ApplicationRecord
  belongs_to :whatsapp_instance
  # SEM dependent: — um grupo que some e desativado (fase 27), nunca apagado; a linha
  # divulgacao_grupos mantem o snapshot group_name/remote_jid independente disso (Pitfall 7 / DIVU-09).
  has_many :divulgacao_grupos

  scope :active_groups,   -> { where(active: true) }
  scope :inactive_groups, -> { where(active: false) }

  # subject nulo (Evolution issue #2124) -> nunca um rótulo em branco.
  # Reticências = U+2026 (um caractere), copy verbatim do 27-UI-SPEC.
  def display_name
    subject.presence || "Grupo sem nome (#{remote_jid.to_s.first(12)}…)"
  end
end
