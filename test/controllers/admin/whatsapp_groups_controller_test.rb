require "test_helper"

class AdminWhatsappGroupsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin_wa_groups@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  setup do
    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    sign_in_as(@admin)

    @client = Client.create!(
      name: "WA Groups Controller Test",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
  end

  teardown do
    Rails.cache.delete("wa_groups_sync_#{@instance&.id}")
  end

  # --- #sync -----------------------------------------------------------

  test "sync com instancia ausente nao enfileira e redireciona com alert" do
    assert_nil @client.whatsapp_instance

    assert_no_enqueued_jobs do
      post sync_admin_client_whatsapp_groups_path(@client)
    end

    assert_redirected_to admin_client_whatsapp_groups_path(@client)
    assert_equal "A instância está desconectada. Reconecte o número antes de sincronizar os grupos.", flash[:alert]
  end

  test "sync com instancia desconectada nao enfileira e redireciona com alert" do
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :disconnected
    )

    assert_no_enqueued_jobs do
      post sync_admin_client_whatsapp_groups_path(@client)
    end

    assert_redirected_to admin_client_whatsapp_groups_path(@client)
    assert_equal "A instância está desconectada. Reconecte o número antes de sincronizar os grupos.", flash[:alert]
    assert_equal "idle", @instance.reload.groups_sync_state
  end

  test "sync com instancia conectada enfileira o job, marca syncing e mostra notice" do
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )
    Rails.cache.delete("wa_groups_sync_#{@instance.id}")

    assert_enqueued_with(job: Whatsapp::SyncGroupsJob, args: [ @instance ]) do
      post sync_admin_client_whatsapp_groups_path(@client)
    end

    assert_redirected_to admin_client_whatsapp_groups_path(@client)
    assert_equal "Sincronização iniciada. Os grupos aparecem aqui em instantes.", flash[:notice]
    assert @instance.reload.groups_sync_syncing?
  end

  # --- #sync_status ------------------------------------------------------

  test "sync_status devolve exatamente as 4 chaves esperadas, sem nomes/JIDs de grupo" do
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      groups_synced_at: Time.zone.local(2026, 8, 30, 14, 5),
      groups_sync_state: :idle
    )
    @instance.whatsapp_groups.create!(remote_jid: "1@g.us", subject: "Grupo Segredo", active: true, synced_at: Time.current)
    @instance.whatsapp_groups.create!(remote_jid: "2@g.us", subject: "Grupo Inativo", active: false, synced_at: Time.current)

    get sync_status_admin_client_whatsapp_groups_path(@client)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal %w[count error synced_at syncing], body.keys.sort
    assert_equal false, body["syncing"]
    assert_equal @instance.groups_synced_at.iso8601, body["synced_at"]
    assert_nil body["error"]
    assert_equal 1, body["count"]

    refute_includes response.body, "Grupo Segredo"
    refute_includes response.body, "1@g.us"
    refute_includes response.body, "2@g.us"
  end

  test "sync_status sem instancia devolve os defaults sem erro 500" do
    assert_nil @client.whatsapp_instance

    get sync_status_admin_client_whatsapp_groups_path(@client)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal false, body["syncing"]
    assert_nil body["synced_at"]
    assert_nil body["error"]
    assert_equal 0, body["count"]
  end

  # --- escopo cross-client (GRUPO-03 / SC5) -------------------------------

  test "sync_status escopado por client_id -- nunca reflete os grupos de outro cliente" do
    client_a = @client
    instance_a = client_a.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(client_a),
      connection_state: :connected
    )
    instance_a.whatsapp_groups.create!(remote_jid: "a1@g.us", subject: "Grupo A", active: true, synced_at: Time.current)

    client_b = Client.create!(name: "WA Groups Controller Test B", password: "senha1234", password_confirmation: "senha1234")
    instance_b = client_b.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(client_b),
      connection_state: :connected
    )
    instance_b.whatsapp_groups.create!(remote_jid: "b1@g.us", subject: "Grupo B", active: true, synced_at: Time.current)
    instance_b.whatsapp_groups.create!(remote_jid: "b2@g.us", subject: "Grupo B2", active: true, synced_at: Time.current)

    get sync_status_admin_client_whatsapp_groups_path(client_b)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["count"]
  ensure
    Rails.cache.delete("wa_groups_sync_#{instance_a&.id}")
    Rails.cache.delete("wa_groups_sync_#{instance_b&.id}")
  end
end
