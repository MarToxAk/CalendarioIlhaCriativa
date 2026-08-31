require "test_helper"

class AdminClientsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  setup do
    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    sign_in_as(@admin)

    @client = Client.create!(
      name: "Test Client",
      password: "senha1234",
      password_plain: "senha1234"
    )
  end

  # ── create ──────────────────────────────────────────────────────────────────

  test "create com dados válidos redireciona para show com notice" do
    assert_difference "Client.count", 1 do
      post admin_clients_path, params: {
        client: { name: "Loja da Maria", password: "abcd1234" }
      }
    end
    novo_cliente = Client.last
    assert_redirected_to admin_client_path(novo_cliente)
    assert_equal "Cliente cadastrado com sucesso.", flash[:notice]
    assert_equal "abcd1234", novo_cliente.password_plain
  end

  test "create com nome vazio renderiza new com status 422" do
    assert_no_difference "Client.count" do
      post admin_clients_path, params: {
        client: { name: "", password: "abcd1234" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "span[role='alert']"
  end

  # ── update ──────────────────────────────────────────────────────────────────

  test "update com senha em branco mantém senha original (D-10)" do
    senha_original = @client.password_plain
    patch admin_client_path(@client), params: {
      client: { name: "Nome Novo", password: "", password_plain: "" }
    }
    assert_redirected_to admin_client_path(@client)
    @client.reload
    assert_equal senha_original, @client.password_plain
    assert_equal "Nome Novo", @client.name
  end

  test "update com nova senha sincroniza password_plain (CLIE-04)" do
    patch admin_client_path(@client), params: {
      client: { name: @client.name, password: "novasenha99" }
    }
    assert_response :redirect
    @client.reload
    assert_equal "novasenha99", @client.password_plain
  end

  test "update com dados inválidos renderiza edit com status 422" do
    patch admin_client_path(@client), params: {
      client: { name: "" }
    }
    assert_response :unprocessable_entity
  end

  # ── active (CLIE-03) ─────────────────────────────────────────────────────────

  test "update com active: false desativa o cliente (CLIE-03)" do
    patch admin_client_path(@client), params: { client: { active: false } }
    assert_redirected_to admin_client_path(@client)
    @client.reload
    assert_equal false, @client.active?
  end

  test "update com active: true reativa o cliente (CLIE-03)" do
    @client.update!(active: false)
    patch admin_client_path(@client), params: { client: { active: true } }
    assert_redirected_to admin_client_path(@client)
    @client.reload
    assert_equal true, @client.active?
  end

  # ── divulgações (mirror — DIVU-01) ───────────────────────────────────────

  test "show com 0 divulgacoes exibe mensagem vazia e link Nova divulgacao" do
    Evolution::Client.stub(:fetch_instances, ->(**) { [] }) do
      get admin_client_path(@client)
    end

    assert_response :success
    assert_includes response.body, "Nenhuma divulgação agendada."
    assert_includes response.body, new_admin_client_divulgacao_path(@client)
  end

  test "show com 6 divulgacoes lista as 5 mais recentes e um link Ver todas" do
    instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )
    group = instance.whatsapp_groups.create!(remote_jid: "cg1@g.us", subject: "Grupo Cliente Show", active: true, synced_at: Time.current)
    arte = @client.artes.new(scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: "Arte Show")
    arte.media_file.attach(fixture_file_upload("sample.jpg", "image/jpeg"))
    arte.save!

    6.times do |i|
      @client.divulgacoes.create!(
        arte: arte, scheduled_for: (i + 1).days.from_now,
        divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: group, group_name: group.display_name, remote_jid: group.remote_jid) ]
      )
    end

    get admin_client_path(@client)

    assert_response :success
    divulgacao_links = @client.divulgacoes.order(scheduled_for: :desc).first(5).map { |d| admin_client_divulgacao_path(@client, d) }
    divulgacao_links.each { |path| assert_includes response.body, path }
    sixth = @client.divulgacoes.order(scheduled_for: :desc).last
    refute_includes response.body, admin_client_divulgacao_path(@client, sixth)
    assert_includes response.body, "Ver todas"
    assert_includes response.body, admin_client_divulgacoes_path(@client)
    assert_includes response.body, "(BRT)"
  end

  test "show_inclui_historico_de_aprovacoes" do
    arte = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :pending,
      title: "Arte com Resposta",
      caption: "Legenda",
      approval_deadline: Date.current + 5,
      external_url: "https://drive.google.com/file/exemplo"
    )
    arte.approval_responses.create!(decision: :change_requested)

    Evolution::Client.stub(:fetch_instances, ->(**) { [] }) do
      get admin_client_path(@client)
    end
    assert_response :success
    assert_includes response.body, "Arte com Resposta"
    assert_includes response.body, "Histórico de aprovações"
  end

  # ── @reusable_targets (fase 31, D-06) ──────────────────────────────────────

  test "show de cliente sem instancia com irma conectada em outro cliente monta @reusable_targets com 1 entrada" do
    sibling_client = Client.create!(name: "Reusable Sibling", password: "senha1234", password_confirmation: "senha1234")
    sibling = sibling_client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(sibling_client),
      connection_state: :connected
    )

    Evolution::Client.stub(:fetch_instances, ->(**) { [ { "name" => sibling.instance_name, "connectionStatus" => "open" } ] }) do
      get admin_client_path(@client)
    end

    assert_response :success
    # Sem @whatsapp_instance: o painel renderiza o toggle "Novo número (QR)" vs
    # "Reutilizar conexão existente" (branch whatsapp_instance.nil? do _panel).
    assert_select "label", text: "Novo número (QR)"
    # @reusable_targets tem 1 entrada: o <select> aparece com a irmã conectada.
    assert_select "select#source_instance_name" do
      assert_select "option", text: "#{sibling.instance_name} — usado por: #{sibling_client.name}"
    end
  end

  test "show de cliente COM instancia nao monta @reusable_targets" do
    @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )

    get admin_client_path(@client)

    assert_response :success
    # Com @whatsapp_instance presente: o painel renderiza o branch "conectado",
    # nunca o toggle/select de reutilização (@reusable_targets não é montado,
    # fetch_instances nem é chamado).
    assert_select "select#source_instance_name", count: 0
  end

  # ── toggle de reutilizacao no _panel (fase 31, D-06/D-07) ──────────────────

  test "show de cliente sem instancia renderiza o select de reutilizacao com opcao 'usado por:'" do
    sibling_client = Client.create!(name: "Reusable Select Sibling", password: "senha1234", password_confirmation: "senha1234")
    sibling = sibling_client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(sibling_client),
      connection_state: :connected
    )

    Evolution::Client.stub(:fetch_instances, ->(**) { [ { "name" => sibling.instance_name, "connectionStatus" => "open" } ] }) do
      get admin_client_path(@client)
    end

    assert_response :success
    assert_select "select#source_instance_name" do
      assert_select "option", text: /usado por:/
    end
  end

  # ── shareable_targets ao vivo (quick task 260831-nb7) ───────────────────────

  test "show de cliente sem instancia com Evolution reportando instancia SEM linha local mostra opcao com rotulo de fallback" do
    Evolution::Client.stub(:fetch_instances, ->(**) { [ { "name" => "livia_client_orphan_live", "connectionStatus" => "open" } ] }) do
      get admin_client_path(@client)
    end

    assert_response :success
    assert_select "select#source_instance_name" do
      assert_select "option", text: "livia_client_orphan_live — ainda não vinculada a nenhum cliente"
      assert_select "option", text: /usado por:/, count: 0
    end
  end

  test "show de cliente sem instancia com Evolution falhando responde :success e mostra mensagem de lista vazia" do
    Evolution::Client.stub(:fetch_instances, ->(**) { raise Evolution::Errors::Transient, "timeout" }) do
      get admin_client_path(@client)
    end

    assert_response :success
    assert_includes response.body, "Nenhuma conexão conectada disponível para reutilizar."
  end

  # ── linha :unpaired = "sem instância" (quick task 260831-o9t) ─────────────

  test "show de cliente com instancia :unpaired trata como sem instancia (empty-state + select de reutilizacao)" do
    sibling_client = Client.create!(name: "Unpaired Sibling", password: "senha1234", password_confirmation: "senha1234")
    sibling = sibling_client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(sibling_client),
      connection_state: :connected
    )
    @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :unpaired
    )

    Evolution::Client.stub(:fetch_instances, ->(**) { [ { "name" => sibling.instance_name, "connectionStatus" => "open" } ] }) do
      get admin_client_path(@client)
    end

    assert_response :success
    assert_select "label", text: "Novo número (QR)"
    assert_select "select#source_instance_name", count: 1
  end

  test "show de cliente com instancia :unpaired NAO renderiza o ramo conectado" do
    @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :unpaired
    )

    Evolution::Client.stub(:fetch_instances, ->(**) { [] }) do
      get admin_client_path(@client)
    end

    assert_response :success
    assert_select "button", text: "Desvincular WhatsApp", count: 0
    assert_select "#unlink-modal-desc", count: 0
  end

  # ── copy do modal "Desvincular WhatsApp" (quick task 260831-o9t) ──────────

  test "show de cliente com conexao COMPARTILHADA descreve as irmas no modal Desvincular WhatsApp" do
    nome = WhatsappInstance.evolution_name_for(@client)
    @client.create_whatsapp_instance!(instance_name: nome, connection_state: :connected)

    sibling_client = Client.create!(name: "Unlink Sibling", password: "senha1234", password_confirmation: "senha1234")
    sibling_client.create_whatsapp_instance!(instance_name: nome, connection_state: :connected)

    get admin_client_path(@client)

    assert_response :success
    assert_select "#unlink-modal-desc" do |elements|
      body = elements.first.text
      assert_match(/em uso por 1 outro/, body)
      assert_match(/não são afetados/, body)
      assert_match(/Nada é apagado/, body)
    end
  end

  test "show de cliente com conexao NAO compartilhada descreve a conexao ativa no modal Desvincular WhatsApp" do
    @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )

    get admin_client_path(@client)

    assert_response :success
    assert_select "#unlink-modal-desc" do |elements|
      body = elements.first.text
      refute_match(/outro\(s\) cliente/, body)
      refute_match(/compartilham/, body)
      assert_match(/A conexão em si continua ativa/, body)
    end
  end
end
