require "test_helper"

class WhatsappInstanceTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(
      name: "Test WA",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
  end

  # --- evolution_name_for — determinístico, sem I/O ------------------------
  test "evolution_name_for is deterministic per client id" do
    name = WhatsappInstance.evolution_name_for(@client)
    assert_equal "livia_client_#{@client.id}", name
    assert_equal name, WhatsappInstance.evolution_name_for(@client)
  end

  test "evolution_name_for differs across clients" do
    other = Client.create!(name: "Other", password: "senha1234", password_confirmation: "senha1234")
    refute_equal WhatsappInstance.evolution_name_for(@client), WhatsappInstance.evolution_name_for(other)
  end

  # --- webhook_secret_for — HMAC estável para a mesma chave+nome ----------
  test "webhook_secret_for is stable for the same instance_name and key" do
    name = "livia_client_5"
    first = WhatsappInstance.webhook_secret_for(name)
    second = WhatsappInstance.webhook_secret_for(name)
    assert_equal first, second
    assert_match(/\A[0-9a-f]{64}\z/, first)
  end

  test "webhook_secret_for changes when instance_name changes" do
    a = WhatsappInstance.webhook_secret_for("livia_client_5")
    b = WhatsappInstance.webhook_secret_for("livia_client_6")
    refute_equal a, b
  end

  # --- map_evolution_state — fonte única do mapa Evolution -> connection_state
  test "map_evolution_state maps known Evolution states" do
    assert_equal :connected,    WhatsappInstance.map_evolution_state("open")
    assert_equal :awaiting_qr,  WhatsappInstance.map_evolution_state("connecting")
    assert_equal :disconnected, WhatsappInstance.map_evolution_state("close")
    assert_equal :disconnected, WhatsappInstance.map_evolution_state("refused")
  end

  test "map_evolution_state defaults to :awaiting_qr for unknown values without raising" do
    assert_equal :awaiting_qr, WhatsappInstance.map_evolution_state(nil)
    assert_equal :awaiting_qr, WhatsappInstance.map_evolution_state("")
    assert_equal :awaiting_qr, WhatsappInstance.map_evolution_state("evento-futuro-desconhecido")
  end

  # --- paired_days / recently_paired? --------------------------------------
  test "paired_days is nil when paired_at is nil" do
    wi = @client.create_whatsapp_instance!(instance_name: WhatsappInstance.evolution_name_for(@client))
    assert_nil wi.paired_days
    assert_nil wi.recently_paired?
  end

  test "paired_days returns the floor of elapsed days and recently_paired? is true under 7 days" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      paired_at: 3.days.ago
    )
    assert_equal 3, wi.paired_days
    assert wi.recently_paired?
  end

  test "recently_paired? is false when paired 7 or more days ago" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      paired_at: 10.days.ago
    )
    assert_equal 10, wi.paired_days
    refute wi.recently_paired?
  end

  # --- connection_state_label — rótulo pt-BR por estado (26-04, PAIR-05) ---
  test "connection_state_label covers the 4 enum values" do
    wi = @client.build_whatsapp_instance(instance_name: WhatsappInstance.evolution_name_for(@client))

    wi.connection_state = :unpaired
    assert_equal "Aguardando criação", wi.connection_state_label

    wi.connection_state = :awaiting_qr
    assert_equal "Aguardando pareamento", wi.connection_state_label

    wi.connection_state = :connected
    assert_equal "Conectada", wi.connection_state_label

    wi.connection_state = :disconnected
    assert_equal "Desconectada", wi.connection_state_label
  end

  # --- encrypts :token — ciphertext != plaintext em repouso ----------------
  test "token is encrypted at rest (raw column value differs from the assigned plaintext)" do
    plaintext = "plaintext-secret-value"
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      token: plaintext,
      connection_state: :awaiting_qr
    )

    raw = ActiveRecord::Base.connection.select_value("SELECT token FROM whatsapp_instances WHERE id=#{wi.id}")

    refute_equal plaintext, raw
    assert_not_nil raw
    assert_equal plaintext, wi.reload.token
  end
end
