# frozen_string_literal: true

# Formatacao pt-BR para as telas de Divulgacao (28-UI-SPEC). Todo datetime
# renderizado carrega o sufixo explicito "(BRT)" (DIVU-05).
module Admin::DivulgacoesHelper
  # "DD/MM/AAAA HH:MM (BRT)" — ex. "15/09/2025 14:00 (BRT)".
  def divulgacao_datetime_label(time)
    return "—" if time.blank?

    "#{time.strftime('%d/%m/%Y %H:%M')} (BRT)"
  end

  # Estimativa humana da duracao do disparo (DIVU-07). Fonte da verdade / fallback
  # sem-JS: renderiza a MESMA string que o divulgacao_estimate_controller.js
  # escreve client-side. `n_groups == 0` -> travessao (zero-state). `lo == hi`
  # (poucos grupos) -> valor unico, nao uma faixa. "para {n} grupos" NAO e
  # pluralizado (copy travada no 28-UI-SPEC).
  def divulgacao_duration_estimate(n_groups, min: Divulgacao::SEND_DELAY_MIN, max: Divulgacao::SEND_DELAY_MAX)
    return "—" if n_groups.to_i.zero?

    lo = (n_groups * min / 60.0).ceil
    hi = (n_groups * max / 60.0).ceil
    lo == hi ? "≈ #{lo} min para #{n_groups} grupos" : "≈ #{lo}–#{hi} min para #{n_groups} grupos"
  end
end
