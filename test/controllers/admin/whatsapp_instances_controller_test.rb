require "test_helper"

class AdminWhatsappInstancesControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin_wa@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  setup do
    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    sign_in_as(@admin)

    @client = Client.create!(
      name: "WA Controller Test",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
  end

  FAKE_SUCCESS_RESPONSE = {
    "instance" => { "instanceId" => "fake-instance-id" },
    "hash" => "fake-instance-token",
    "qrcode" => { "base64" => "data:image/png;base64,fake" }
  }.freeze

  test "create com sucesso cria a linha e redireciona com notice" do
    assert_difference "WhatsappInstance.count", 1 do
      Evolution::Client.stub(:create_instance, ->(**) { FAKE_SUCCESS_RESPONSE }) do
        post admin_client_whatsapp_instance_path(@client)
      end
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Instância criada. Escaneie o QR Code para parear.", flash[:notice]

    wi = @client.reload.whatsapp_instance
    assert_equal "awaiting_qr", wi.connection_state
    assert_equal "created_by_app", wi.origin
    assert_equal "fake-instance-token", wi.token
  end

  test "create com erro do Evolution (não already-in-use) não cria linha e redireciona com alert" do
    assert_no_difference "WhatsappInstance.count" do
      Evolution::Client.stub(:create_instance, ->(**) { raise Evolution::Errors::Permanent, "401 invalid api key" }) do
        post admin_client_whatsapp_instance_path(@client)
      end
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Não foi possível criar a instância no WhatsApp. Verifique a configuração do Evolution e tente de novo.", flash[:alert]
    assert_nil @client.reload.whatsapp_instance
  end

  # PAIR-02 — create colide com "already in use" -> InstanceProvisioner#call
  # desvia para #adopt internamente (mesmo endpoint #create, sem ação extra do
  # admin). Prova origin: adopted_existing e que set_webhook foi chamado
  # (contador, não só "não levantou" — via stub com efeito colateral no array).
  test "create com 403 already in use adota a instância existente via #adopt interno" do
    fake_instance = { "name" => WhatsappInstance.evolution_name_for(@client), "hash" => "adopted-token-abc", "id" => "remote-1" }
    set_webhook_calls = []

    assert_difference "WhatsappInstance.count", 1 do
      Evolution::Client.stub(:create_instance, ->(**) { raise Evolution::Errors::Permanent, '403 This name "x" is already in use.' }) do
        Evolution::Client.stub(:fetch_instances, ->(**) { [ fake_instance ] }) do
          Evolution::Client.stub(:set_webhook, ->(name, **kwargs) { set_webhook_calls << [ name, kwargs ]; { "webhook" => { "enabled" => true } } }) do
            Evolution::Client.stub(:connection_state, ->(*, **) { "open" }) do
              post admin_client_whatsapp_instance_path(@client)
            end
          end
        end
      end
    end

    assert_equal 1, set_webhook_calls.size
    assert_equal WhatsappInstance.evolution_name_for(@client), set_webhook_calls.first[0]

    # #create sempre usa a notice de criação — a #adopt (rota/botão dedicado,
    # "Adotar instância existente") é que usa a notice de adoção; aqui a
    # adoção acontece internamente dentro do MESMO #create, sem ação extra
    # do admin (CONTEXT.md "buscar connection_state na hora... webhook é
    # reapontado em ambos os casos" — automatismo dentro do request).
    assert_redirected_to admin_client_path(@client)
    assert_equal "Instância criada. Escaneie o QR Code para parear.", flash[:notice]

    wi = @client.reload.whatsapp_instance
    assert_equal "adopted_existing", wi.origin
    assert_equal "connected", wi.connection_state
    assert_equal "adopted-token-abc", wi.token
    assert wi.paired_at.present?
  end

  # WR-04 — só 403 + "already in use" desvia para #adopt. Uma 403 de outra
  # natureza (ex.: API key sem permissão) deve re-propagar como falha dura,
  # nunca virar adoção silenciosa.
  test "create com 403 que NAO e colisao de nome nao adota e redireciona com alert" do
    assert_no_difference "WhatsappInstance.count" do
      Evolution::Client.stub(:create_instance, ->(**) { raise Evolution::Errors::Permanent, "403 API key forbidden for this resource" }) do
        Evolution::Client.stub(:fetch_instances, ->(**) { raise "fetch_instances nao deveria ser chamado" }) do
          post admin_client_whatsapp_instance_path(@client)
        end
      end
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Não foi possível criar a instância no WhatsApp. Verifique a configuração do Evolution e tente de novo.", flash[:alert]
    assert_nil @client.reload.whatsapp_instance
  end

  # --- #verify — verificação manual síncrona (PAIR-05, 26-04) --------------

  test "verify com state open atualiza o banco e redireciona com notice de sucesso" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :awaiting_qr,
      last_qr_base64: "data:image/png;base64,stale"
    )

    Evolution::Client.stub(:connection_state, ->(*) { "open" }) do
      post verify_admin_client_whatsapp_instance_path(@client)
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Estado atualizado: agora Conectada.", flash[:notice]

    wi.reload
    assert_equal "connected", wi.connection_state
    assert wi.last_checked_at.present?
    assert wi.paired_at.present?
    assert_nil wi.last_qr_base64
  end

  test "verify com state close ATUALIZA o banco (nao so a mensagem) e mostra alert de desconectada" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      paired_at: 2.days.ago
    )

    Evolution::Client.stub(:connection_state, ->(*) { "close" }) do
      post verify_admin_client_whatsapp_instance_path(@client)
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "A instância respondeu como desconectada. Use \"Parear novamente\" para reconectar o número.", flash[:alert]

    wi.reload
    assert_equal "disconnected", wi.connection_state
    assert wi.last_checked_at.present?
  end

  test "verify com falha de transporte NAO avanca connection_state nem last_checked_at" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :awaiting_qr
    )
    before_checked_at = wi.last_checked_at

    Evolution::Client.stub(:connection_state, ->(*) { raise Evolution::Errors::Transient, "timeout" }) do
      post verify_admin_client_whatsapp_instance_path(@client)
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Não foi possível falar com o WhatsApp agora. O estado acima pode estar desatualizado. Tente \"Forçar verificação\" de novo em instantes.", flash[:alert]

    wi.reload
    assert_equal "awaiting_qr", wi.connection_state
    assert_equal before_checked_at, wi.last_checked_at
  end

  # WR-01 — rotas verify/reconnect são alcançáveis diretamente mesmo sem
  # instância; não podem estourar NoMethodError (nil.instance_name) -> 500.
  test "verify sem instância redireciona com alert em vez de estourar 500" do
    assert_nil @client.whatsapp_instance
    post verify_admin_client_whatsapp_instance_path(@client)

    assert_redirected_to admin_client_path(@client)
    assert_equal "Este cliente ainda não tem uma instância de WhatsApp.", flash[:alert]
  end

  test "reconnect sem instância redireciona com alert em vez de estourar 500" do
    assert_nil @client.whatsapp_instance
    post reconnect_admin_client_whatsapp_instance_path(@client)

    assert_redirected_to admin_client_path(@client)
    assert_equal "Este cliente ainda não tem uma instância de WhatsApp.", flash[:alert]
  end

  # --- #refresh_qr — throttled, sempre JSON (PAIR-03, 26-04) ---------------

  test "refresh_qr com QR ja em cache responde o JSON sem chamar connect" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :awaiting_qr,
      last_qr_base64: "data:image/png;base64,cached"
    )

    Evolution::Client.stub(:connect, ->(*) { raise "nao deveria chamar" }) do
      post refresh_qr_admin_client_whatsapp_instance_path(@client)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "awaiting_qr", body["state"]
    assert_equal wi.last_qr_base64, body["qr_base64"]
  end

  test "duas chamadas seguidas a refresh_qr dentro de 15s disparam connect no maximo 1 vez" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :awaiting_qr
    )
    Rails.cache.delete("wa_qr_pull_#{wi.id}")
    calls = 0
    fake_connect = ->(*) { calls += 1; { base64: "data:image/png;base64,fresh", code: nil, pairing_code: nil, count: 1 } }

    Evolution::Client.stub(:connect, fake_connect) do
      post refresh_qr_admin_client_whatsapp_instance_path(@client)
      post refresh_qr_admin_client_whatsapp_instance_path(@client)
    end

    assert_equal 1, calls
  ensure
    Rails.cache.delete("wa_qr_pull_#{wi&.id}")
  end

  test "refresh_qr sem instancia responde unpaired sem erro 500" do
    post refresh_qr_admin_client_whatsapp_instance_path(@client)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "unpaired", body["state"]
    assert_nil body["qr_base64"]
  end

  # --- #reconnect — "Parear novamente" (26-04) ------------------------------

  test "reconnect atualiza connection_state para awaiting_qr e grava novo qr_base64" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      last_qr_base64: nil
    )

    fake_connect = ->(*) { { base64: "data:image/png;base64,new-qr", code: nil, pairing_code: nil, count: 1 } }
    Evolution::Client.stub(:connect, fake_connect) do
      post reconnect_admin_client_whatsapp_instance_path(@client)
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Pareamento reiniciado. Escaneie o novo QR Code.", flash[:notice]

    wi.reload
    assert_equal "awaiting_qr", wi.connection_state
    assert_equal "data:image/png;base64,new-qr", wi.last_qr_base64
  end

  test "reconnect com falha do Evolution redireciona com alert e nao muda o estado" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )

    Evolution::Client.stub(:connect, ->(*) { raise Evolution::Errors::Transient, "timeout" }) do
      post reconnect_admin_client_whatsapp_instance_path(@client)
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Não foi possível atualizar o QR Code. Clique em \"Gerar novo QR\" para tentar outra vez.", flash[:alert]
    assert_equal "connected", wi.reload.connection_state
  end
end
