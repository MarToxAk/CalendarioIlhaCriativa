require "test_helper"

# Primeiro job do namespace Divulgacoes:: (fase 29-01). Mesmo setup shape de
# test/jobs/whatsapp/sync_groups_job_test.rb (Client.create!,
# WhatsappInstance.create!). Prova só o disparo/agendamento — o corpo real do
# envio é coberto por Whatsapp::SendToGroupJobTest.
class Divulgacoes::DispatchJobTest < ActiveJob::TestCase
  def setup
    @client = Client.create!(name: "DispatchJob Test", password: "senha1234", password_confirmation: "senha1234")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      groups_synced_at: Time.current
    )
    @group = @instance.whatsapp_groups.create!(remote_jid: "g1@g.us", subject: "Grupo Um", active: true, synced_at: Time.current)
    @arte = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte Aprovada"
    )
    @arte.media_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")),
      filename: "sample.jpg", content_type: "image/jpeg"
    )
    @arte.save!
    @divulgacao = @client.divulgacoes.create!(
      arte: @arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ]
    )
    @group_row = @divulgacao.divulgacao_grupos.first
  end

  test "perform enfileira SendToGroupJob para o grupo pendente e marca em_andamento" do
    assert_enqueued_with(job: Whatsapp::SendToGroupJob, args: [ @group_row ]) do
      Divulgacoes::DispatchJob.perform_now(@divulgacao)
    end
    assert_equal "em_andamento", @divulgacao.reload.status
  end

  test "no-op quando a divulgacao ja esta cancelada" do
    @divulgacao.update!(status: :cancelada)

    assert_no_enqueued_jobs do
      Divulgacoes::DispatchJob.perform_now(@divulgacao)
    end
    assert_equal "cancelada", @divulgacao.reload.status
  end

  test "queue_as whatsapp_sends" do
    assert_equal "whatsapp_sends", Divulgacoes::DispatchJob.new.queue_name
  end
end
