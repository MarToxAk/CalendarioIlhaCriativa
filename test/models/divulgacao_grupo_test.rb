require "test_helper"
require "turbo/broadcastable/test_helper"

class DivulgacaoGrupoTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "DivulgacaoGrupo Model Test", password: "senha123", password_confirmation: "senha123")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )
    @group = @instance.whatsapp_groups.create!(remote_jid: "dgm1@g.us", subject: "Grupo DG", active: true, synced_at: Time.current)
    # Arte aprovada com arquivo anexado (a Divulgacao recusa external_url — DIVU-03).
    @arte = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte"
    )
    @arte.media_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")),
      filename: "sample.jpg", content_type: "image/jpeg"
    )
    @arte.save!
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

  # --- Task 2 (ACOMP-01): broadcast_progresso ao vivo ------------------

  include Turbo::Broadcastable::TestHelper

  test "flip de status dispara 2 replace no stream [client, divulgacao] (ACOMP-01)" do
    dg = @divulgacao.divulgacao_grupos.first

    streams = capture_turbo_stream_broadcasts([ @client, @divulgacao ]) do
      dg.update!(status: :enviado)
    end

    assert_equal 2, streams.length
    assert streams.all? { |s| s["action"] == "replace" }

    targets = streams.map { |s| s["target"] }
    assert_includes targets, ActionView::RecordIdentifier.dom_id(dg)
    assert_includes targets, ActionView::RecordIdentifier.dom_id(@divulgacao, :progresso)

    progresso_stream = streams.find { |s| s["target"] == ActionView::RecordIdentifier.dom_id(@divulgacao, :progresso) }
    texto = progresso_stream.text
    assert_match(/enviados/, texto)
    assert_match(/falhou/, texto)
    assert_match(/pendente/, texto)
    assert_match(/incerto/, texto)
  end

  test "update sem mudar status nao dispara broadcast (ACOMP-01)" do
    dg = @divulgacao.divulgacao_grupos.first

    streams = capture_turbo_stream_broadcasts([ @client, @divulgacao ]) do
      dg.touch
    end

    assert_empty streams
  end
end
