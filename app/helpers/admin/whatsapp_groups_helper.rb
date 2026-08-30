# frozen_string_literal: true

# Formatação pt-BR para a seção de grupos do WhatsApp (27-02). Analog:
# Admin::WhatsappInstancesHelper#wa_last_checked_label -- mas aqui o 27-UI-SPEC
# trava um formato ABSOLUTO (não relativo), pois o admin precisa saber
# exatamente quando o lote rodou (INFRA-03, America/São Paulo).
module Admin::WhatsappGroupsHelper
  # Só o timestamp -- o prefixo "Sincronizado pela última vez em " é
  # responsabilidade da VIEW (27-03), copy verbatim do 27-UI-SPEC.
  def wa_groups_synced_label(instance)
    return "—" if instance&.groups_synced_at.blank?

    instance.groups_synced_at.strftime("%d/%m/%Y às %H:%M")
  end
end
