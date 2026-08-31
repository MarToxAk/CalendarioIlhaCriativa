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

    # WR-04 — o Evolution só sinaliza colisão de nome pela CÓPIA humana da
    # mensagem 403; o envelope de erro NÃO carrega código estruturado
    # (verificado no fonte do Evolution na tag 2.3.7 — ver 26-RESEARCH.md).
    # Restrição aceita e documentada: não inventar um campo que o upstream
    # não fornece. Para reduzir mis-roteamento casamos DUAS coisas: o status
    # 403 (prefixo posto por Evolution::Client#raise_for_status! -> "403 …")
    # E a frase abaixo. Assim uma 401/404 cuja cópia por acaso contenha
    # "already in use" NÃO é desviada para #adopt, e uma futura mudança de
    # wording do 403 fica rastreável neste ponto único.
    NAME_IN_USE_MESSAGE = /already in use/i
    private_constant :NAME_IN_USE_MESSAGE

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
      raise unless name_collision?(e)

      adopt(name, headers)
    end

    # Fase 31 (D-03/D-06/D-07): reutiliza uma instância-irmã JÁ CONECTADA para um
    # cliente novo. ZERO I/O de rede — não chama create_instance/connect/set_webhook
    # (a conexão física já está pareada e o webhook já aponta pra este sistema).
    # Público, ao lado de #call — NÃO modifica #call/#adopt/#persist_new (D-07).
    def reuse(existing:)
      row = WhatsappInstance.create!(
        client: @client,
        instance_name: existing.instance_name,      # CÓPIA — aponta pra mesma conexão física
        token: existing.token,                      # CÓPIA — encrypts transparente (whatsapp_instance.rb:12)
        remote_instance_id: existing.remote_instance_id,
        origin: :reused_sibling,
        connection_state: existing.connection_state, # espera-se :connected
        paired_at: existing.paired_at,
        last_checked_at: Time.current
      )
      Result.new(instance: row, adopted: true, qr_base64: nil)
    end

    private

    # 403 + frase de colisão. Qualquer outra Permanent (401 credencial, 404
    # rota, 403 não-colisão como "API key forbidden") re-propaga sem desvio.
    def name_collision?(error)
      msg = error.message.to_s
      msg.start_with?("403 ") && msg.match?(NAME_IN_USE_MESSAGE)
    end

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

      Result.new(instance: row, adopted: true, qr_base64: adopt_qr(name, state))
    end

    # WR-05 — a linha já foi persistida (save! acima). Um erro ao buscar o QR
    # inicial NÃO pode propagar para fora de #call: o controller mostraria
    # "Não foi possível criar a instância" ao lado de um card de instância já
    # viva no painel. Silencioso em qualquer falha do Evolution, exatamente
    # como #pull_fresh_qr — o poller do Stimulus busca o QR no próximo ciclo.
    def adopt_qr(name, state)
      return nil if state == "open"

      @api.connect(name)[:base64]
    rescue Evolution::Errors::Transient, Evolution::Errors::Unknown, Evolution::Errors::Permanent, Evolution::Errors::ConfigurationError
      nil
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
