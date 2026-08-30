require "test_helper"

class DivulgacaoTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Divulgacao Model Test", password: "senha123", password_confirmation: "senha123")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )
    @group = @instance.whatsapp_groups.create!(remote_jid: "gm1@g.us", subject: "Grupo Modelo", active: true, synced_at: Time.current)
    @arte = @client.artes.create!(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte", external_url: "https://drive.google.com/file/exemplo"
    )
  end

  test "status default e agendada" do
    assert_equal "agendada", Divulgacao.new.status
  end

  test "divulgacao com scheduled_for mas sem grupos e invalida com errors[:base]" do
    d = @client.divulgacoes.new(arte: @arte, scheduled_for: 3.days.from_now)
    assert_not d.valid?
    assert_includes d.errors[:base], "Selecione ao menos um grupo para a divulgação."
  end

  test "divulgacao sem scheduled_for e invalida em :scheduled_for" do
    d = @client.divulgacoes.new(
      arte: @arte,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ]
    )
    assert_not d.valid?
    assert_includes d.errors[:scheduled_for], "não pode ficar em branco"
  end

  test "divulgacao valida com arte, scheduled_for futuro e ao menos um grupo" do
    d = @client.divulgacoes.new(
      arte:          @arte,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ]
    )
    assert d.valid?, d.errors.full_messages.inspect
  end
end
