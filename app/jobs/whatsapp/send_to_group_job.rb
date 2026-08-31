# frozen_string_literal: true

# Whatsapp::SendToGroupJob — corpo completo do `perform` (fase 29-01). Claim
# atômico ANTES de qualquer I/O de rede — a única defesa real contra
# double-send (ENVIO-04; o plano 29-02 prova isso sob concorrência). Revalida
# `arte.approved?`/`instance.connected?` DENTRO do `perform`, nunca confiando
# num check feito uma única vez no DispatchJob (ENVIO-06/07). Token sempre via
# `divulgacao.client.whatsapp_instance.token` (SEG-03) — a MESMA cadeia de
# resolução que o plano 29-02 usa para a chave de concorrência
# (`limits_concurrency`), fixada no checkpoint da Task 1 do 29-01-PLAN.md para
# nunca divergir. `finalize_divulgacao_if_done` é MÉTODO DE CLASSE porque o
# plano 29-02 precisa chamá-lo de dentro de blocos `discard_on`/`retry_on`
# (que rodam fora do `perform`, no mesmo `self` de classe — igual ao
# `self.mark_error` de Whatsapp::SyncGroupsJob).
class Whatsapp::SendToGroupJob < ApplicationJob
  queue_as :whatsapp_sends # config/queue.yml: worker "*" genérico pega até a fila dedicada chegar no 29-03 (INFRA-06)

  # URL de mídia presignada gerada DENTRO do perform (ENVIO-08) — validade
  # curta o suficiente para cobrir só este envio individual, evitando que a
  # URL do último grupo de uma Divulgação grande expire antes do download.
  MEDIA_URL_TTL = 5.minutes

  def perform(group)
    group.reload
    divulgacao = group.divulgacao.reload
    return if divulgacao.status_cancelada? # DIVU-08/DIVU-09: no-op silencioso, item permanece pendente

    claimed = DivulgacaoGrupo.where(id: group.id, status: :pendente)
                              .update_all(status: :enviado, sent_at: Time.current, updated_at: Time.current)
    return if claimed.zero? # ENVIO-04: já processado por outro worker/retry — nunca chega ao HTTP

    arte = divulgacao.arte.reload
    unless arte.approved?
      group.update!(status: :falhou, error_code: "arte_nao_aprovada") # ENVIO-06
      self.class.finalize_divulgacao_if_done(divulgacao)
      return
    end

    instance = divulgacao.client.whatsapp_instance
    unless instance&.connected?
      group.update!(status: :falhou, error_code: "instancia_desconectada") # ENVIO-07
      self.class.finalize_divulgacao_if_done(divulgacao)
      return
    end

    send_via_evolution(group, arte, instance)
    self.class.finalize_divulgacao_if_done(divulgacao)
  end

  def self.finalize_divulgacao_if_done(divulgacao)
    return if divulgacao.divulgacao_grupos.pendente.exists?
    divulgacao.update!(status: :concluida) if divulgacao.status_em_andamento?
  end

  private

  # SEM begin/rescue ainda — o rescue pontual de Evolution::Errors::Transient
  # que desfaz o claim é aditivo do plano 29-02, não muda esta forma.
  def send_via_evolution(group, arte, instance)
    api_key = instance.token # SEG-03 — sempre resolvido via divulgacao.client.whatsapp_instance, nunca um id solto

    resp = if arte.caption_only?
      Evolution::Client.send_text(instance.instance_name, number: group.remote_jid, text: arte.caption, api_key: api_key)
    else
      media_url = arte.media_file.url(expires_in: MEDIA_URL_TTL) # ENVIO-08 — gerada aqui, nunca no DispatchJob
      Evolution::Client.send_media(instance.instance_name, number: group.remote_jid, mediatype: arte.media_type,
                                    media: media_url, api_key: api_key, caption: arte.caption.presence)
    end

    # RESEARCH Assumption A1: shape exato do sucesso PENDENTE de UAT real — ler os dois formatos possíveis.
    group.update!(evolution_message_id: resp["key"]&.dig("id") || resp["id"])
  end
end
