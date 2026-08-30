# frozen_string_literal: true

module Evolution
  # Orquestra a CRIAÇÃO de uma instância Evolution para um cliente e persiste a
  # linha correspondente (PAIR-01). O caminho de ADOÇÃO (403 "already in use" ->
  # buscar a instância existente, reapontar o webhook, persistir) chega no plano
  # 26-02 — este plano propaga Evolution::Errors::Permanent sem rescue.
  class InstanceProvisioner
    Result = Struct.new(:instance, :adopted, :qr_base64, keyword_init: true)

    # client_api: seam de DI para teste (stub de Evolution::Client sem rede).
    def initialize(client, client_api: Evolution::Client)
      @client = client
      @api = client_api
    end

    def call
      name = WhatsappInstance.evolution_name_for(@client)
      headers = {
        "X-Webhook-Secret" => WhatsappInstance.webhook_secret_for(name),
        "Content-Type" => "application/json"
      }
      resp = @api.create_instance(instance_name: name, webhook_url: webhook_url, webhook_headers: headers)
      persist_new(name, resp)
    end

    private

    def persist_new(name, resp)
      row = WhatsappInstance.create!(
        client: @client,
        instance_name: name,
        token: resp["hash"].is_a?(Hash) ? resp.dig("hash", "apikey") : resp["hash"],
        remote_instance_id: resp.dig("instance", "instanceId"),
        origin: :created_by_app,
        connection_state: :awaiting_qr,
        last_checked_at: Time.current
      )
      Result.new(instance: row, adopted: false, qr_base64: resp.dig("qrcode", "base64"))
    end

    def webhook_url = File.join(Evolution.webhook_base_url, "webhooks/evolution")
  end
end
