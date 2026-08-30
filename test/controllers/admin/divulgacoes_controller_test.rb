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

  # --- cross-client isolation A×B (Task 3 / SEG-01, SEG-02) -------------

  # Constroi o cliente B com sua propria instancia + grupo + arte aprovada. O
  # segredo de B tem strings distintas para o refute_includes provar que a
  # re-renderizacao do form de A nao vaza nada de B.
  def build_client_b
    client_b = Client.create!(name: "Divulgacoes Cliente B", password: "senha1234", password_confirmation: "senha1234")
    instance_b = client_b.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(client_b),
      connection_state: :connected,
      groups_synced_at: Time.current
    )
    group_b = instance_b.whatsapp_groups.create!(remote_jid: "segredo-b@g.us", subject: "Segredo do B", active: true, synced_at: Time.current)
    arte_b = client_b.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte Secreta do B")
    arte_b.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte_b.save!
    [ client_b, group_b, arte_b ]
  end

  test "arte de OUTRO cliente pela URL de divulgacoes do cliente A -- re-render :new, zero linhas, sem vazar dados de B" do
    _client_b, group_b, arte_b = build_client_b

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_b.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    refute_includes response.body, arte_b.title
    refute_includes response.body, group_b.subject
    refute_includes response.body, group_b.remote_jid
  end

  test "id de grupo de OUTRO cliente no array pela URL de A -- re-render :new, zero linhas, sem vazar dados de B" do
    _client_b, group_b, _arte_b = build_client_b

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id, group_b.id ], scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    refute_includes response.body, group_b.subject
    refute_includes response.body, group_b.remote_jid
  end

  test "id de grupo INATIVO do proprio cliente A -- re-render :new, zero linhas, flash Selecao invalida" do
    inactive = @instance.whatsapp_groups.create!(remote_jid: "inativo-a@g.us", subject: "Grupo Inativo A", active: false, synced_at: Time.current)

    assert_no_difference [ "Divulgacao.count", "DivulgacaoGrupo.count" ] do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id, inactive.id ], scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Seleção inválida", flash[:alert]
  end

  test "nenhum grupo marcado (chave ausente) -- re-render :new, zero linhas, mensagem selecione ao menos um grupo" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Selecione ao menos um grupo"
  end

  # --- Task 2: datetime-local -> Time.zone round-trip (DIVU-05) --------

  test "scheduled_for cru 2026-09-15T14:00 round-trips pra Time.zone.local Brasilia (-03:00)" do
    assert_difference("Divulgacao.count", 1) do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: "2026-09-15T14:00" }
      }
    end

    d = Divulgacao.last
    assert_equal Time.zone.local(2026, 9, 15, 14, 0), d.scheduled_for
    assert_equal(-3 * 3600, d.scheduled_for.utc_offset)
  end

  test "criar a divulgacao nao transforma Arte#scheduled_on num datetime — continua Date sem hora" do
    post admin_client_divulgacoes_path(@client), params: {
      divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: "2026-09-15T14:00" }
    }
    assert_redirected_to admin_client_divulgacao_path(@client, Divulgacao.last)

    @arte.reload
    assert_kind_of Date, @arte.scheduled_on
    assert_not @arte.scheduled_on.respond_to?(:hour)
  end

  test "scheduled_for com lixo impossivel de parsear casta pra nil e cai no presence — sem 500" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: "not-a-date" }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Informe a data e hora do envio."
  end

  # --- DIVU-09 snapshot congelado -------------------------------------

  test "renomear e desativar o grupo apos criar nao altera o snapshot group_name/remote_jid" do
    original_name = @g1.display_name
    divulgacao = @client.divulgacoes.create!(
      arte:          @arte,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @g1, group_name: @g1.display_name, remote_jid: @g1.remote_jid) ]
    )
    dg = divulgacao.divulgacao_grupos.first

    @g1.update!(subject: "Nome totalmente novo do grupo")
    @g1.update!(active: false)
    dg.reload

    assert_equal original_name, dg.group_name
    assert_equal "g1@g.us", dg.remote_jid
  end

  # --- Task 3: cada mensagem de validacao chega pela caixa errors[:base] ---

  def future_param = 3.days.from_now.strftime("%Y-%m-%dT%H:%M")

  test "arte pending -> re-render :new com 'A arte selecionada nao esta aprovada.' (DIVU-02)" do
    arte_pending = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :pending, title: "Arte Pendente"
    )
    arte_pending.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte_pending.save!

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_pending.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação."
  end

  test "arte com external_url (sem arquivo) -> 'Esta arte usa um link externo.' (DIVU-03)" do
    arte_link = @client.artes.create!(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte com Link", external_url: "https://drive.google.com/file/x"
    )

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_link.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a divulgação."
  end

  test "arquivo acima do teto de 16 MB -> mensagem com tamanho atual e limite (DIVU-04)" do
    arte_grande = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte Grande"
    )
    arte_grande.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte_grande.save!
    arte_grande.media_file.blob.update_column(:byte_size, 20.megabytes)

    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_grande.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "20 MB"
    assert_includes response.body, "16 MB"
    assert_includes response.body, "Comprima ou reenvie um arquivo menor na arte."
  end

  test "arte caption_only aprovada + grupo valido + futuro -> cria a divulgacao (DIVU-03, caption_only IN escopo)" do
    arte_texto = @client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :caption_only,
      status: :approved, title: "Arte Só Texto", caption: "Bom dia a todos!"
    )
    arte_texto.save!(validate: false) # media_source_present da Arte exige arquivo/link; caption_only e escopo da Divulgacao

    assert_difference("Divulgacao.count", 1) do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: arte_texto.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: future_param }
      }
    end

    assert_redirected_to admin_client_divulgacao_path(@client, Divulgacao.last)
  end

  test "scheduled_for no passado -> 'A data e hora do envio precisam estar no futuro.'" do
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client), params: {
        divulgacao: { arte_id: @arte.id, whatsapp_group_ids: [ @g1.id ], scheduled_for: 1.hour.ago.strftime("%Y-%m-%dT%H:%M") }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "A data e hora do envio precisam estar no futuro."
  end

  test "SEG-02 backstop no nivel do model: arte do cliente B + divulgacao do cliente A e invalida" do
    _client_b, _group_b, arte_b = build_client_b

    d = @client.divulgacoes.new(
      arte:          arte_b,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @g1, group_name: @g1.display_name, remote_jid: @g1.remote_jid) ]
    )

    assert_not d.valid?
    assert_includes d.errors[:base], "A arte e os grupos precisam ser do mesmo cliente."
  end
end
