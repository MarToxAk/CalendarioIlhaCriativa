require "test_helper"

class Webhooks::EvolutionControllerTest < ActionDispatch::IntegrationTest
  def setup
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
    @client = Client.create!(
      name: "Webhook Test",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
    @name = WhatsappInstance.evolution_name_for(@client)
    @instance = @client.create_whatsapp_instance!(
      instance_name: @name,
      token: "tok",
      connection_state: :awaiting_qr
    )
    @secret = WhatsappInstance.webhook_secret_for(@name)
  end

  # --- PAIR-06 literal: segredo antes do banco ------------------------------

  test "sem header X-Webhook-Secret retorna 401" do
    post "/webhooks/evolution", params: { instance: @name, event: "connection.update", data: { state: "open" } }
    assert_response :unauthorized
  end

  test "segredo errado retorna 401" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "connection.update", data: { state: "open" } },
      headers: { "X-Webhook-Secret" => "segredo-errado" }
    assert_response :unauthorized
  end

  test "segredo errado + instance_name inexistente no banco AINDA retorna 401 (a query não roda antes do check de segredo)" do
    nome_inexistente = "livia_client_#{SecureRandom.hex(8)}"
    assert_no_difference "WhatsappInstance.count" do
      # A prova real é que o find_by NUNCA roda antes do check de segredo — se
      # rodasse antes, um instance_name que não existe no banco teria o mesmo
      # comportamento de "instância desconhecida" (204), não 401. Como o
      # segredo comparado é derivado do instance_name presente no payload
      # (nunca de um segredo persistido), o segredo "certo" para esse nome
      # nunca é usado aqui — é sempre um segredo deliberadamente errado.
      post "/webhooks/evolution",
        params: { instance: nome_inexistente, event: "connection.update", data: { state: "open" } },
        headers: { "X-Webhook-Secret" => "segredo-errado-tambem" }
    end
    assert_response :unauthorized
  end

  # --- 204 silencioso para instância desconhecida (Pitfall 9) --------------

  test "segredo correto + instance_name desconhecido retorna 204 sem corpo" do
    nome_desconhecido = "livia_client_#{SecureRandom.hex(8)}"
    secret_correto = WhatsappInstance.webhook_secret_for(nome_desconhecido)
    post "/webhooks/evolution",
      params: { instance: nome_desconhecido, event: "connection.update", data: { state: "open" } },
      headers: { "X-Webhook-Secret" => secret_correto }
    assert_response :no_content
    assert_empty response.body
  end

  # --- connection.update: dotcase e UPPER_SNAKE convergem (Pitfall 3) ------

  test "connection.update com state open marca connected, grava paired_at e limpa QR" do
    @instance.update!(last_qr_base64: "data:image/png;base64,abc")

    post "/webhooks/evolution",
      params: { instance: @name, event: "connection.update", data: { state: "open" } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_equal "connected", @instance.connection_state
    assert @instance.paired_at.present?
    assert @instance.last_checked_at.present?
    assert_nil @instance.last_qr_base64
  end

  test "CONNECTION_UPDATE (upper-snake) produz o mesmo resultado que connection.update" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "CONNECTION_UPDATE", data: { state: "open" } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_equal "connected", @instance.connection_state
    assert @instance.paired_at.present?
  end

  test "state refused mapeia para disconnected" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "connection.update", data: { state: "refused" } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_equal "disconnected", @instance.connection_state
  end

  # WR-06 — um state que o Evolution não emite hoje (release futura ou
  # payload malformado de um caller assinado) NÃO pode rebaixar uma
  # instância connected para awaiting_qr. No-op silencioso, responde 200.
  test "connection.update com state desconhecido nao rebaixa uma instancia connected" do
    @instance.update!(connection_state: :connected, paired_at: 3.days.ago, last_qr_base64: nil)

    post "/webhooks/evolution",
      params: { instance: @name, event: "connection.update", data: { state: "reconnecting" } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_equal "connected", @instance.connection_state
    assert_nil @instance.last_qr_base64
  end

  # --- paired_at write-once (PAIR-08) ---------------------------------------

  test "paired_at não é sobrescrito numa segunda reconexão state open" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "connection.update", data: { state: "open" } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok
    first_paired_at = @instance.reload.paired_at
    assert first_paired_at.present?

    travel 1.hour do
      post "/webhooks/evolution",
        params: { instance: @name, event: "connection.update", data: { state: "open" } },
        headers: { "X-Webhook-Secret" => @secret }
    end
    assert_response :ok

    assert_equal first_paired_at, @instance.reload.paired_at
  end

  # --- qrcode.updated -------------------------------------------------------

  test "qrcode.updated com base64 grava last_qr_base64 e mantém awaiting_qr" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "qrcode.updated", data: { qrcode: { base64: "data:image/png;base64,xyz" } } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_equal "data:image/png;base64,xyz", @instance.last_qr_base64
    assert_equal "awaiting_qr", @instance.connection_state
  end

  test "qrcode.updated sem data.qrcode.base64 (limite de QR atingido) é um no-op silencioso, não quebra" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "qrcode.updated", data: { qrcode: { base64: nil } } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_nil @instance.last_qr_base64
    assert_equal "awaiting_qr", @instance.connection_state
  end

  # --- eventos não tratados (messages.*, fase 29) ---------------------------

  test "evento não tratado (ex: messages.upsert) é um no-op, responde 200" do
    post "/webhooks/evolution",
      params: { instance: @name, event: "messages.upsert", data: { foo: "bar" } },
      headers: { "X-Webhook-Secret" => @secret }
    assert_response :ok

    @instance.reload
    assert_equal "awaiting_qr", @instance.connection_state
  end
end
