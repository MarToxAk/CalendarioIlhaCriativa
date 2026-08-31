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

  # ACOMP-03: copy-map pt-BR pros dois sentinel codes gravados pelo job da
  # fase 29 (send_to_group_job.rb:141/148). Qualquer outro error_code cai no
  # fallback "Motivo: <verbatim>" -- SEM truncar, SEM gsub, SEM re-fetch. A
  # sanitizacao (redacao de URL/assinatura + truncamento a 500) ja aconteceu
  # uma unica vez, na escrita, em Whatsapp::SendToGroupJob.sanitize_error_code.
  # Repeti-la aqui na leitura seria redundante e arriscaria mascarar o texto
  # ja seguro com uma segunda passada de regex.
  SENTINEL_ERROR_LABELS = {
    "arte_nao_aprovada"      => "Motivo: a aprovação da arte foi retirada antes do envio.",
    "instancia_desconectada" => "Motivo: o número do cliente estava desconectado no momento do envio.",
  }.freeze

  def divulgacao_grupo_error_label(dg)
    SENTINEL_ERROR_LABELS[dg.error_code] || "Motivo: #{dg.error_code}"
  end

  # Placar compacto por status, lido da associacao JA carregada via
  # includes(:divulgacao_grupos) no controller -- group_by nunca dispara
  # query nova. Contrato de pluralizacao (WR-02, 30-REVIEW): o branch
  # "todas as linhas pendente" usa plural ("N pendentes"), mas o branch misto
  # usa singular fixo ("N pendente") mesmo quando N > 1 -- teste em
  # test/helpers/admin/divulgacoes_helper_test.rb:133-136.
  def divulgacao_placar(divulgacao)
    grupos = divulgacao.divulgacao_grupos.to_a
    total = grupos.size
    return "—" if total.zero?

    by = grupos.group_by(&:status)
    enviado  = by["enviado"].to_a.size
    falhou   = by["falhou"].to_a.size
    incerto  = by["incerto"].to_a.size
    pendente = by["pendente"].to_a.size

    return "#{pendente} pendentes" if pendente == total

    parts = [ "#{enviado} enviados", "#{falhou} falhou" ]
    parts << "#{incerto} incerto"   if incerto.positive?
    parts << "#{pendente} pendente" if pendente.positive?
    parts.join(" · ")
  end
end
