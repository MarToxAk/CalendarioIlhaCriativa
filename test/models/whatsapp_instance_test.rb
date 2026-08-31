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

  # --- Fase 31 (D-03): indice de instance_name deuniqueificado -------------
  test "indice nao-unico de instance_name permite 2a linha com o mesmo nome para outro cliente" do
    other = Client.create!(name: "Sibling Client", password: "senha1234", password_confirmation: "senha1234")
    shared_name = "livia_client_shared_smoke"

    @client.create_whatsapp_instance!(instance_name: shared_name, connection_state: :connected)

    assert_nothing_raised do
      other.create_whatsapp_instance!(instance_name: shared_name, connection_state: :connected)
    end
    assert_equal 2, WhatsappInstance.where(instance_name: shared_name).count
  end

  test "indice UNIQUE de client_id ainda levanta RecordNotUnique na 2a instancia do mesmo cliente" do
    @client.create_whatsapp_instance!(instance_name: WhatsappInstance.evolution_name_for(@client))

    assert_raises(ActiveRecord::RecordNotUnique) do
      WhatsappInstance.create!(client: @client, instance_name: "outro-nome")
    end
  end

  test "origin_reused_sibling? responde ao novo valor do enum" do
    wi = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      origin: :reused_sibling
    )
    assert wi.origin_reused_sibling?
    refute wi.origin_created_by_app?
    refute wi.origin_adopted_existing?
  end

  # --- siblings / shared? / shareable_targets (D-03/D-06) -------------------
  test "siblings inclui self e qualquer outra linha com o mesmo instance_name" do
    shared_name = "livia_client_siblings_smoke"
    wi_a = @client.create_whatsapp_instance!(instance_name: shared_name, connection_state: :connected)
    other = Client.create!(name: "Sibling B", password: "senha1234", password_confirmation: "senha1234")
    wi_b = other.create_whatsapp_instance!(instance_name: shared_name, connection_state: :connected)

    assert_equal [ wi_a, wi_b ].sort_by(&:id), wi_a.siblings.sort_by(&:id)
  end

  test "shared? e falso sem irma e verdadeiro com irma do mesmo instance_name" do
    wi = @client.create_whatsapp_instance!(instance_name: WhatsappInstance.evolution_name_for(@client))
    refute wi.shared?

    other = Client.create!(name: "Sibling C", password: "senha1234", password_confirmation: "senha1234")
    other.create_whatsapp_instance!(instance_name: wi.instance_name)

    assert wi.reload.shared?
  end

  # --- shareable_targets (fase 31 D-06 + quick task 260831-nb7: fonte ao vivo) ---

  test "shareable_targets lista entrada Evolution conectada com irma local e exclui o nome do proprio cliente" do
    shared_name = "livia_client_targets_smoke"
    sibling_client = Client.create!(name: "Cliente Irmao", password: "senha1234", password_confirmation: "senha1234")
    sibling_client.create_whatsapp_instance!(instance_name: shared_name, connection_state: :connected)
    own_name = WhatsappInstance.evolution_name_for(@client)

    entries = [
      { "name" => shared_name, "connectionStatus" => "open" },
      { "name" => own_name, "connectionStatus" => "open" }
    ]

    targets = Evolution::Client.stub(:fetch_instances, ->(**) { entries }) do
      WhatsappInstance.shareable_targets(excluding_client_id: @client.id)
    end

    entry = targets.find { |t| t[:instance_name] == shared_name }
    assert entry.present?
    assert_equal [ sibling_client.name ], entry[:client_names]
    refute targets.any? { |t| t[:instance_name] == own_name }
  end

  test "shareable_targets nao lista entrada cujo connectionStatus nao mapeia para :connected" do
    entries = [
      { "name" => "livia_client_connecting_smoke", "connectionStatus" => "connecting" },
      { "name" => "livia_client_close_smoke", "connectionStatus" => "close" }
    ]

    targets = Evolution::Client.stub(:fetch_instances, ->(**) { entries }) do
      WhatsappInstance.shareable_targets(excluding_client_id: @client.id)
    end

    assert_empty targets
  end

  test "shareable_targets lista entrada Evolution conectada SEM nenhuma linha WhatsappInstance local com client_names vazio" do
    entries = [ { "name" => "livia_client_orphan_smoke", "connectionStatus" => "open" } ]

    targets = Evolution::Client.stub(:fetch_instances, ->(**) { entries }) do
      WhatsappInstance.shareable_targets(excluding_client_id: @client.id)
    end

    entry = targets.find { |t| t[:instance_name] == "livia_client_orphan_smoke" }
    assert entry.present?
    assert_equal [], entry[:client_names]
  end

  test "shareable_targets devolve [] em vez de propagar quando fetch_instances levanta Evolution::Errors::Transient" do
    targets = Evolution::Client.stub(:fetch_instances, ->(**) { raise Evolution::Errors::Transient, "timeout" }) do
      WhatsappInstance.shareable_targets(excluding_client_id: @client.id)
    end

    assert_equal [], targets
  end
end
