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

  test "create com erro do Evolution não cria linha e redireciona com alert" do
    assert_no_difference "WhatsappInstance.count" do
      Evolution::Client.stub(:create_instance, ->(**) { raise Evolution::Errors::Permanent, "403 already in use" }) do
        post admin_client_whatsapp_instance_path(@client)
      end
    end

    assert_redirected_to admin_client_path(@client)
    assert_equal "Não foi possível criar a instância no WhatsApp. Verifique a configuração do Evolution e tente de novo.", flash[:alert]
    assert_nil @client.reload.whatsapp_instance
  end
end
