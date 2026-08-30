require "test_helper"

class DivulgacaoGrupoTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "DivulgacaoGrupo Model Test", password: "senha123", password_confirmation: "senha123")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )
    @group = @instance.whatsapp_groups.create!(remote_jid: "dgm1@g.us", subject: "Grupo DG", active: true, synced_at: Time.current)
    @arte = @client.artes.create!(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte", external_url: "https://drive.google.com/file/exemplo"
    )
    @divulgacao = @client.divulgacoes.create!(
      arte:          @arte,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ]
    )
  end

  test "status default e pendente" do
    assert_equal "pendente", DivulgacaoGrupo.new.status
  end

  test "segundo divulgacao_grupo com o mesmo whatsapp_group_id na mesma divulgacao e invalido" do
    dup = DivulgacaoGrupo.new(divulgacao: @divulgacao, whatsapp_group: @group, group_name: "x", remote_jid: "y")
    assert_not dup.valid?
    assert_includes dup.errors[:whatsapp_group_id], "já está em uso"
  end

  test "group_name em branco e invalido" do
    dg = DivulgacaoGrupo.new(divulgacao: @divulgacao, whatsapp_group: @group, group_name: nil, remote_jid: "y")
    assert_not dg.valid?
    assert_includes dg.errors[:group_name], "não pode ficar em branco"
  end

  test "remote_jid em branco e invalido" do
    dg = DivulgacaoGrupo.new(divulgacao: @divulgacao, whatsapp_group: @group, group_name: "x", remote_jid: nil)
    assert_not dg.valid?
    assert_includes dg.errors[:remote_jid], "não pode ficar em branco"
  end
end
