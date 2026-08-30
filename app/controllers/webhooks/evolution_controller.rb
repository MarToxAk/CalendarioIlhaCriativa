# frozen_string_literal: true

# Receiver de webhook do Evolution (PAIR-06) — único endpoint desta fase que
# aceita tráfego de fora sem sessão/CSRF, então é deliberadamente pequeno.
# `valid_signature?` é a PRIMEIRA coisa que #create faz: o segredo é
# recalculado (HMAC-SHA256 sobre instance_name, mesma fórmula de
# WhatsappInstance.webhook_secret_for) e comparado por secure_compare ANTES de
# qualquer WhatsappInstance.find_by rodar (T-26-10, literal do requisito).
# Nunca loga o corpo cru nem params.inspect (T-26-14, INFRA-04) — os dois
# segredos comparados também nunca são logados.
class Webhooks::EvolutionController < ActionController::API
  def create
    return head(:unauthorized) unless valid_signature?

    instance = WhatsappInstance.find_by(instance_name: params[:instance].to_s)
    return head(:no_content) if instance.nil?

    apply_event(instance)
    head :ok
  end

  private

  # Hashea OS DOIS lados (SHA256) antes de secure_compare — Pitfall 5. Comparar
  # os valores crus pode levantar ArgumentError quando os comprimentos diferem,
  # o que vazaria informação sobre o tamanho do segredo via stack trace/500
  # (T-26-13). Hasheados, o comprimento é sempre 64 hex chars.
  def valid_signature?
    presented = request.headers["X-Webhook-Secret"].to_s
    return false if presented.blank?

    expected = WhatsappInstance.webhook_secret_for(params[:instance].to_s)
    ActiveSupport::SecurityUtils.secure_compare(
      Digest::SHA256.hexdigest(presented),
      Digest::SHA256.hexdigest(expected)
    )
  end

  # Normaliza a grafia do evento — o host real emite dotcase
  # (`connection.update`) mas o RESEARCH também prevê UPPER_SNAKE
  # (`CONNECTION_UPDATE`); ambas convergem aqui (Pitfall 3). `messages.*` (fase
  # 29) e qualquer evento não mapeado caem no `else` — no-op silencioso.
  def apply_event(instance)
    event = params[:event].to_s.tr(".-", "__").upcase

    case event
    when "CONNECTION_UPDATE"
      apply_connection_update(instance)
    when "QRCODE_UPDATED"
      apply_qrcode_updated(instance)
    end
  end

  def apply_connection_update(instance)
    state = params.dig(:data, :state)
    return if state.blank?
    # WR-06 — estado fora do conjunto que o Evolution emite hoje: no-op
    # silencioso. Nunca rebaixar uma instância saudável para awaiting_qr por
    # causa de um payload malformado ou de um state novo de release futura.
    return unless WhatsappInstance.known_evolution_state?(state)

    mapped = WhatsappInstance.map_evolution_state(state)
    instance.connection_state = mapped
    instance.last_checked_at = Time.current
    instance.paired_at ||= Time.current if state == "open"
    instance.last_qr_base64 = nil if state == "open"
    instance.save!
  end

  # Limite de QR atingido (QRCODE_LIMIT) chega aqui sem data.qrcode.base64 —
  # no-op silencioso, nunca um NoMethodError (Pitfall 7).
  def apply_qrcode_updated(instance)
    base64 = params.dig(:data, :qrcode, :base64)
    return if base64.blank?

    instance.update!(last_qr_base64: base64, connection_state: :awaiting_qr)
  end
end
