# frozen_string_literal: true

module Evolution
  # Orquestra a CRIAÇÃO OU ADOÇÃO de uma instância Evolution para um cliente e
  # persiste a linha correspondente (PAIR-01/PAIR-02). Quando `create_instance`
  # devolve 403 "already in use" (nome já existente no manager compartilhado da
  # agência), o fluxo desvia para `adopt`: reaponta o webhook incondicionalmente
  # (Pitfall 4 — sem isso o painel trava para sempre em "aguardando pareamento")
  # e persiste a linha local com o estado real lido do Evolution.
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
    rescue Evolution::Errors::Permanent => e
      raise unless e.message =~ /already in use/i

      adopt(name, headers)
    end

    private

    # PAIR-02. `existing` é resolvido por match EXATO de nome (nunca por índice
    # nem prefixo parcial — T-26-07, o manager é compartilhado com outras apps
    # da agência). `set_webhook` é chamado SEMPRE, ANTES de ler `connection_state`
    # (Pitfall 4). `paired_at` só é gravado se ainda nil e o estado lido é "open"
    # (write-once, PAIR-08, mesma regra do 26-01).
    def adopt(name, headers)
      existing = @api.fetch_instances.find { |i| (i["name"] || i["instanceName"]) == name }
      raise Evolution::Errors::Permanent, "instância #{name} não encontrada no manager para adoção" unless existing

      @api.set_webhook(name, url: webhook_url, headers: headers)
      state = @api.connection_state(name)

      row = WhatsappInstance.find_or_initialize_by(client: @client)
      row.assign_attributes(
        instance_name: name,
        token: existing["token"] || existing["hash"] || existing.dig("Auth", "token"),
        remote_instance_id: existing["id"] || existing["instanceId"],
        origin: :adopted_existing,
        connection_state: WhatsappInstance.map_evolution_state(state),
        last_checked_at: Time.current
      )
      row.paired_at ||= Time.current if state == "open"
      row.save!

      Result.new(instance: row, adopted: true,
                 qr_base64: state == "open" ? nil : @api.connect(name)[:base64])
    end

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
