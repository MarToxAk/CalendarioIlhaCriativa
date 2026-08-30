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

  # Copy verbatim do 27-UI-SPEC "Error state" -- a caixa de erro na página de
  # grupos escolhe o texto pelo código curto gravado em groups_sync_error
  # (Whatsapp::SyncGroupsJob#mark_error). Códigos hoje: "transient", "permanent",
  # "config_error", "not_connected", "unexpected_error" (27-REVIEW.md WR-1 --
  # catch-all de StandardError fora da taxonomia Evolution::Errors). Só
  # "not_connected" tem copy dedicada; os demais caem, DE PROPÓSITO, na mesma
  # mensagem genérica de "tente de novo" -- retry é instrução válida para o
  # usuário em qualquer um desses casos, mesmo que a causa raiz varie (rede vs.
  # payload/rota malformado vs. boot mal configurado vs. bug não previsto). O
  # valor gravado em groups_sync_error continua distinto por classe
  # (27-REVIEW.md WR-03-DUP/WR-1) para quem depura via Rails console/DB direto
  # -- só a copy da UI não distingue.
  def wa_groups_sync_error_message(instance)
    case instance&.groups_sync_error
    when "not_connected"
      "A última sincronização falhou: o número apareceu como desconectado. " \
        'Use "Parear novamente" na seção WhatsApp e sincronize de novo.'
    else
      "A última sincronização falhou: não foi possível falar com o WhatsApp agora. " \
        "Tente sincronizar novamente em instantes."
    end
  end
end
