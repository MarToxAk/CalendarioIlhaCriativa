require "test_helper"

class Admin::DivulgacoesControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin_divulgacoes@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  setup do
    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    sign_in_as(@admin)

    @client = Client.create!(
      name: "Divulgacoes Controller Test",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      groups_synced_at: Time.current
    )
    @g1 = @instance.whatsapp_groups.create!(remote_jid: "g1@g.us", subject: "Grupo Um",  active: true, synced_at: Time.current)
    @g2 = @instance.whatsapp_groups.create!(remote_jid: "g2@g.us", subject: "Grupo Dois", active: true, synced_at: Time.current)

    @arte = @client.artes.new(
      scheduled_on: Date.current,
      platform:     :instagram,
      media_type:   :image,
      status:       :approved,
      title:        "Arte Aprovada"
    )
    @arte.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    @arte.save!
  end

  # --- happy path (Task 2 / DIVU-01, DIVU-09) ---------------------------

  test "POST create agenda uma divulgacao com uma linha pendente por grupo e redireciona pro show" do
    assert_difference("Divulgacao.count", 1) do
      assert_difference("DivulgacaoGrupo.count", 2) do
        post admin_client_divulgacoes_path(@client), params: {
          divulgacao: {
            arte_id:            @arte.id,
            whatsapp_group_ids: [ @g1.id, @g2.id ],
            scheduled_for:      3.days.from_now.strftime("%Y-%m-%dT%H:%M")
          }
        }
      end
    end

    divulgacao = Divulgacao.last
    assert_redirected_to admin_client_divulgacao_path(@client, divulgacao)
    assert_equal @client.id, divulgacao.client_id
    assert_equal @arte.id,   divulgacao.arte_id
    assert_equal "agendada", divulgacao.status
    assert_equal [ "pendente" ], divulgacao.divulgacao_grupos.pluck(:status).uniq
    assert_equal [ "Grupo Dois", "Grupo Um" ], divulgacao.divulgacao_grupos.pluck(:group_name).sort
    assert_equal [ "g1@g.us", "g2@g.us" ], divulgacao.divulgacao_grupos.pluck(:remote_jid).sort
  end
end
