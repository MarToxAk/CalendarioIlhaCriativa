# frozen_string_literal: true

# Formatação pt-BR para a seção WhatsApp de admin/clients#show e para o
# indicador do index (26-05). Copy verbatim do 26-UI-SPEC "Copywriting
# Contract".
module Admin::WhatsappInstancesHelper
  # "Última verificação: {label}" — nunca um timestamp cru na linha principal;
  # o timestamp completo vai em title= (26-UI-SPEC "stale" UI Consideration).
  def wa_last_checked_label(instance)
    return "—" if instance.last_checked_at.blank?

    diff = Time.current - instance.last_checked_at
    if diff < 60
      "há pouco"
    elsif diff < 3600
      "há #{(diff / 60).to_i} min"
    else
      "há #{(diff / 3600).to_i} h"
    end
  end

  # Linha de idade do pareamento (PAIR-08). Neutra a partir de 7 dias;
  # cautela (âmbar) abaixo disso — copy verbatim do UI-SPEC, deixando
  # explícito que a contagem é local a este sistema, não a idade real do
  # número no WhatsApp.
  def wa_paired_age_text(instance)
    return nil unless instance.paired_at

    days = instance.paired_days
    if days && days < 7
      "Pareado há #{days} dia(s) neste sistema. Números pareados há menos de 7 dias têm mais risco de " \
        "bloqueio — evite grandes volumes de disparo agora. A contagem começa no pareamento aqui e não " \
        "reflete a idade real do número no WhatsApp."
    else
      "Pareado há #{days} dias neste sistema."
    end
  end
end
