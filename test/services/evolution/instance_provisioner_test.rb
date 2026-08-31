require "test_helper"

# Fase 31 (D-03/D-07) — Evolution::InstanceProvisioner#reuse. Cobre SOMENTE o
# método novo (#call/#adopt já cobertos por test/controllers/admin/
# whatsapp_instances_controller_test.rb). RaisingFakeEvolutionClient prova
# ZERO I/O de rede — qualquer chamada ao Evolution::Client faria o teste falhar.
class Evolution::InstanceProvisionerTest < ActiveSupport::TestCase
  class RaisingFakeEvolutionClient
    def self.method_missing(*)
      raise "RaisingFakeEvolutionClient: nenhum método do Evolution::Client deveria ser chamado por #reuse"
    end

    def self.respond_to_missing?(*) = true
  end

  def setup
    @client_a = Client.create!(name: "Provisioner Reuse A", password: "senha1234", password_confirmation: "senha1234")
    @client_b = Client.create!(name: "Provisioner Reuse B", password: "senha1234", password_confirmation: "senha1234")
    @instance_a = @client_a.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client_a),
      token: "token-irma-a",
      connection_state: :connected,
      paired_at: 2.days.ago,
      remote_instance_id: "remote-a"
    )
  end

  test "#reuse copia instance_name/token/connection_state/paired_at/remote_instance_id da irma e seta origin: reused_sibling, sem I/O de rede" do
    result = Evolution::InstanceProvisioner.new(@client_b, client_api: RaisingFakeEvolutionClient).reuse(existing: @instance_a)

    row = result.instance
    assert row.persisted?
    assert_equal @client_b, row.client
    assert_equal @instance_a.instance_name, row.instance_name
    assert_equal @instance_a.token, row.token
    assert_equal @instance_a.remote_instance_id, row.remote_instance_id
    assert_equal "connected", row.connection_state
    assert_equal @instance_a.paired_at.to_i, row.paired_at.to_i
    assert row.origin_reused_sibling?
    assert result.adopted
    assert_nil result.qr_base64
  end

  test "#reuse nao chama create_instance/connect/set_webhook (RaisingFakeEvolutionClient levanta em qualquer metodo)" do
    assert_nothing_raised do
      Evolution::InstanceProvisioner.new(@client_b, client_api: RaisingFakeEvolutionClient).reuse(existing: @instance_a)
    end
  end

  test "#reuse sobre uma linha :unpaired do proprio cliente sobrescreve sem RecordNotUnique e sem I/O" do
    @client_b.create_whatsapp_instance!(
      instance_name: "livia_client_stale_old",
      connection_state: :unpaired
    )

    result = nil
    assert_no_difference "WhatsappInstance.count" do
      result = Evolution::InstanceProvisioner.new(@client_b, client_api: RaisingFakeEvolutionClient).reuse(existing: @instance_a)
    end

    row = @client_b.reload.whatsapp_instance
    assert_equal result.instance.id, row.id
    assert_equal @instance_a.instance_name, row.instance_name
    assert_equal @instance_a.token, row.token
    assert row.origin_reused_sibling?
    assert_equal "connected", row.connection_state
  end

  test "#reuse para um cliente que ja tem instancia levanta RecordNotUnique (indice UNIQUE de client_id preservado)" do
    Evolution::InstanceProvisioner.new(@client_b, client_api: RaisingFakeEvolutionClient).reuse(existing: @instance_a)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Evolution::InstanceProvisioner.new(@client_b, client_api: RaisingFakeEvolutionClient).reuse(existing: @instance_a)
    end
  end

  # --- #adopt_named (quick task 260831-nb7) — wrapper publico sobre #adopt ---
  # ao contrario de #reuse, bate em fetch_instances/set_webhook/connection_state
  # do Evolution::Client de verdade -> mesmo padrao de stub do controller test.

  test "#adopt_named com nome presente no fetch_instances persiste linha nova com origin_adopted_existing? e chama set_webhook 1x" do
    name = "livia_client_named_smoke"
    fake_instance = { "name" => name, "hash" => "adopted-named-token", "id" => "remote-named-1" }
    set_webhook_calls = []

    result = nil
    Evolution::Client.stub(:fetch_instances, ->(**) { [ fake_instance ] }) do
      Evolution::Client.stub(:set_webhook, ->(n, **kwargs) { set_webhook_calls << [ n, kwargs ]; { "webhook" => { "enabled" => true } } }) do
        Evolution::Client.stub(:connection_state, ->(*, **) { "open" }) do
          result = Evolution::InstanceProvisioner.new(@client_b).adopt_named(name)
        end
      end
    end

    row = result.instance
    assert row.persisted?
    assert_equal @client_b, row.client
    assert_equal name, row.instance_name
    assert_equal "adopted-named-token", row.token
    assert_equal "remote-named-1", row.remote_instance_id
    assert_equal "connected", row.connection_state
    assert row.origin_adopted_existing?
    assert_equal 1, set_webhook_calls.size
    assert_equal name, set_webhook_calls.first[0]
  end

  test "#adopt_named com nome ausente no fetch_instances levanta Evolution::Errors::Permanent e nao cria linha" do
    name = "livia_client_absent_smoke"

    assert_no_difference "WhatsappInstance.count" do
      Evolution::Client.stub(:fetch_instances, ->(**) { [] }) do
        assert_raises(Evolution::Errors::Permanent) do
          Evolution::InstanceProvisioner.new(@client_b).adopt_named(name)
        end
      end
    end
  end
end
