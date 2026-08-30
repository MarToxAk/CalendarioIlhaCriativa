# frozen_string_literal: true

# Formatacao pt-BR para as telas de Divulgacao (28-UI-SPEC). Todo datetime
# renderizado carrega o sufixo explicito "(BRT)" (DIVU-05). O helper de
# estimativa de duracao (`divulgacao_duration_estimate`) chega no plano 03.
module Admin::DivulgacoesHelper
  # "DD/MM/AAAA HH:MM (BRT)" — ex. "15/09/2025 14:00 (BRT)".
  def divulgacao_datetime_label(time)
    return "—" if time.blank?

    "#{time.strftime('%d/%m/%Y %H:%M')} (BRT)"
  end
end
