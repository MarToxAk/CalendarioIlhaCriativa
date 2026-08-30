require "test_helper"

class WhatsappGroupTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(
      name: "Test WA Groups",
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

  # --- display_name ---------------------------------------------------------
  test "display_name returns subject when present" do
    group = WhatsappGroup.create!(
      whatsapp_instance: @instance, remote_jid: "1@g.us", subject: "Grupo A"
    )
    assert_equal "Grupo A", group.display_name
  end

  test "display_name falls back to remote_jid prefix with ellipsis when subject is nil" do
    group = WhatsappGroup.create!(
      whatsapp_instance: @instance, remote_jid: "120363000000000001@g.us", subject: nil
    )
    assert_equal "Grupo sem nome (120363000000…)", group.display_name
    assert_equal 1, group.display_name.scan("…").size
  end

  test "display_name falls back when subject is blank" do
    group = WhatsappGroup.create!(
      whatsapp_instance: @instance, remote_jid: "120363000000000002@g.us", subject: ""
    )
    assert_match(/\AGrupo sem nome \(/, group.display_name)
  end

  # --- scopes -----------------------------------------------------------
  test "active_groups and inactive_groups partition by active" do
    active = WhatsappGroup.create!(whatsapp_instance: @instance, remote_jid: "a@g.us", active: true)
    inactive = WhatsappGroup.create!(whatsapp_instance: @instance, remote_jid: "b@g.us", active: false)

    assert_includes @instance.whatsapp_groups.active_groups, active
    refute_includes @instance.whatsapp_groups.active_groups, inactive
    assert_includes @instance.whatsapp_groups.inactive_groups, inactive
    refute_includes @instance.whatsapp_groups.inactive_groups, active
  end

  # --- invariante de escopo (assumption_delta_decision) ------------------
  test "every whatsapp_group resolves to exactly one client via its instance" do
    group = WhatsappGroup.create!(whatsapp_instance: @instance, remote_jid: "c@g.us")
    resolved = WhatsappGroup.joins(whatsapp_instance: :client).find(group.id)
    assert_equal @client, resolved.whatsapp_instance.client
  end
end
