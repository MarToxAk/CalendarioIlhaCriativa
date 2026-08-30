require "test_helper"

# DI com fake client respondendo a fetch_groups(name, api_key:) — sem rede, sem
# Evolution::Client real. Cobre o caminho feliz (Task 1) + desativação/guard
# (Task 2, GRUPO-05).
class Whatsapp::GroupSynchronizerTest < ActiveSupport::TestCase
  class FakeEvolutionClient
    attr_reader :calls

    def initialize(groups_by_call)
      @groups_by_call = groups_by_call
      @calls = 0
    end

    def fetch_groups(_instance_name, api_key:)
      @calls += 1
      @groups_by_call[@calls - 1] || []
    end
  end

  def setup
    @client = Client.create!(
      name: "Test GroupSync",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
    @instance = WhatsappInstance.create!(
      client: @client,
      instance_name: WhatsappInstance.evolution_name_for(@client),
      token: "test-token",
      connection_state: :connected
    )
  end

  def group(id, subject: "Grupo #{id}", announce: false)
    { "id" => "#{id}@g.us", "subject" => subject, "announce" => announce }
  end

  # --- (a) 1º lote insere N linhas ativas -----------------------------------
  test "first batch inserts active rows" do
    fake = FakeEvolutionClient.new([ [ group(1), group(2), group(3) ] ])
    result = Whatsapp::GroupSynchronizer.new(@instance, client_api: fake).call

    assert result.ok
    assert_equal 3, result.count
    assert_equal 3, @instance.whatsapp_groups.active_groups.count
  end

  # --- (b) re-run com a mesma lista é no-op em active -----------------------
  test "re-run with unchanged list does not deactivate anything" do
    payload = [ group(1), group(2), group(3) ]
    fake = FakeEvolutionClient.new([ payload, payload ])
    synchronizer = Whatsapp::GroupSynchronizer.new(@instance, client_api: fake)

    synchronizer.call
    synchronizer.call

    assert_equal 3, @instance.whatsapp_groups.active_groups.count
    assert_equal 0, @instance.whatsapp_groups.inactive_groups.count
  end

  # --- (c) grupo ausente do 2º lote vira active:false e continua existindo --
  test "group missing from second batch is deactivated but not deleted" do
    fake = FakeEvolutionClient.new([
      [ group(1), group(2), group(3) ],
      [ group(1), group(2) ]
    ])
    synchronizer = Whatsapp::GroupSynchronizer.new(@instance, client_api: fake)

    synchronizer.call
    synchronizer.call

    vanished = @instance.whatsapp_groups.find_by(remote_jid: "3@g.us")
    assert WhatsappGroup.exists?(vanished.id)
    refute vanished.reload.active?
    assert_equal [ "3@g.us" ], @instance.whatsapp_groups.where(active: false).pluck(:remote_jid)
  end

  # --- (d) raw = [] -> todas as linhas ativas viram inativas ---------------
  test "empty batch deactivates everything and stamps groups_synced_at without crashing" do
    fake = FakeEvolutionClient.new([ [ group(1), group(2) ], [] ])
    synchronizer = Whatsapp::GroupSynchronizer.new(@instance, client_api: fake)

    synchronizer.call
    first_synced_at = @instance.reload.groups_synced_at
    result = synchronizer.call

    assert result.ok
    assert_equal 0, @instance.whatsapp_groups.active_groups.count
    assert @instance.reload.groups_synced_at > first_synced_at
  end

  # --- (e) instância disconnected -> guard, sem HTTP ------------------------
  test "disconnected instance aborts before any HTTP call" do
    @instance.update!(connection_state: :disconnected)
    fake = FakeEvolutionClient.new([ [ group(1) ] ])

    result = Whatsapp::GroupSynchronizer.new(@instance, client_api: fake).call

    assert_equal false, result.ok
    assert_equal :not_connected, result.reason
    assert_equal "not_connected", @instance.reload.groups_sync_error
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal 0, fake.calls
  end

  # --- (f) invariante: todo whatsapp_group resolve para um client ----------
  test "every created whatsapp_group resolves to a client via its instance" do
    fake = FakeEvolutionClient.new([ [ group(1) ] ])
    Whatsapp::GroupSynchronizer.new(@instance, client_api: fake).call

    assert_equal WhatsappGroup.count, WhatsappGroup.joins(whatsapp_instance: :client).count
  end

  # --- (g) elemento não-Hash no array não crasha (27-REVIEW.md WR-2) --------
  test "malformed non-Hash element in groups array is skipped instead of raising" do
    fake = FakeEvolutionClient.new([ [ group(1), nil, group(2) ] ])

    result = nil
    assert_nothing_raised do
      result = Whatsapp::GroupSynchronizer.new(@instance, client_api: fake).call
    end

    assert result.ok
    assert_equal 2, result.count
    assert_equal %w[1@g.us 2@g.us], @instance.whatsapp_groups.active_groups.order(:remote_jid).pluck(:remote_jid)
  end
end
