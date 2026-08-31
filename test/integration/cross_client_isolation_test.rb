require "test_helper"

# SEG-04 (fase 30, SC4) — a suite tem que FALHAR se uma arte do cliente A
# alcançar um grupo do cliente B. Cobre os dois caminhos (criação e envio) mais
# um belt de token, e é mutation-sensitive: os dois `assert_raises` diretos
# abaixo quebram sozinhos se `@client.divulgacoes.find` (o idioma #resend /
# set_divulgacao — 30-CONTEXT linha 264) ou a cadeia `scoped_active_groups`
# (`@client.whatsapp_instance.whatsapp_groups.where(active: true).find`, a
# EXATA cadeia que `Admin::DivulgacoesController#create` chama `.find(gids)`
# em) forem trocados por um `.find` cru — mesmo que o backstop de model
# `arte_e_grupos_do_mesmo_cliente` continue rejeitando os casos de
# controller/model abaixo.
#
# Setup shape combina os dois analogs lidos: o par de clientes de
# test/integration/client_isolation_test.rb e o scaffolding de WhatsApp
# (instância + grupo + arte aprovada + Divulgacao) de
# test/jobs/whatsapp/send_to_group_job_test.rb.
class CrossClientIsolationTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin_cross_client_isolation@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  def setup
    ActiveStorage::Current.url_options = { host: "example.com", protocol: "https" }

    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end

    @client_a = build_client_with_whatsapp!(name: "Cliente A", password: "senhaA123", token: "SEGREDO-INSTANCIA-A")
    @client_b = build_client_with_whatsapp!(name: "Cliente B", password: "senhaB123", token: "SEGREDO-INSTANCIA-B")

    @instance_a = @client_a.whatsapp_instance
    @instance_b = @client_b.whatsapp_instance
    @group_a = @instance_a.whatsapp_groups.create!(remote_jid: "grupo-a@g.us", subject: "Grupo do A", active: true, synced_at: Time.current)
    @group_b = @instance_b.whatsapp_groups.create!(remote_jid: "grupo-b@g.us", subject: "Grupo do B", active: true, synced_at: Time.current)

    @arte_a = approved_arte_for!(@client_a, "Arte Aprovada do A")
    @arte_b = approved_arte_for!(@client_b, "Arte Aprovada do B")
  end

  # --- Test 1: criação cross-client recusada (mutation-sensitive) --------

  test "criação de Divulgação do cliente A referenciando grupo do cliente B é recusada em TRES camadas" do
    # client_b.divulgacoes é uma linha real (não um id fabricado) — precisa
    # existir de fato para o assert_raises abaixo provar o .find escopado,
    # não só um id inexistente que também levantaria RecordNotFound.
    divulgacao_b = @client_b.divulgacoes.create!(
      arte: @arte_b, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group_b, group_name: @group_b.display_name, remote_jid: @group_b.remote_jid) ]
    )

    # --- Camada 1 (A MUTATION GUARD): dois finders escopados diretos -----
    # Se `@client.divulgacoes.find` virar `Divulgacao.find`, ESTA linha
    # continua passando (RecordNotFound só não seria levantado) e o teste
    # quebra aqui, ANTES de qualquer coisa de controller/model.
    assert_raises(ActiveRecord::RecordNotFound) do
      @client_a.divulgacoes.find(divulgacao_b.id)
    end

    # Mesma lógica para a EXATA cadeia que Admin::DivulgacoesController#create
    # chama .find(gids) em (scoped_active_groups). Se essa cadeia virar
    # WhatsappGroup.find cru, esta linha para de levantar e o teste quebra
    # aqui — independente do backstop de model abaixo.
    assert_raises(ActiveRecord::RecordNotFound) do
      @client_a.whatsapp_instance.whatsapp_groups.where(active: true).find([ @group_b.id ])
    end

    # --- Camada 2 (SEGUNDA barreira independente): controller ------------
    sign_in_as(@admin)
    assert_no_difference "Divulgacao.count" do
      post admin_client_divulgacoes_path(@client_a), params: {
        divulgacao: {
          arte_id: @arte_a.id,
          whatsapp_group_ids: [ @group_b.id ],
          scheduled_for: 3.days.from_now.strftime("%Y-%m-%dT%H:%M")
        }
      }
    end
    assert_response :unprocessable_entity

    # --- Camada 3 (SEGUNDA barreira independente): model backstop --------
    # Este backstop (arte_e_grupos_do_mesmo_cliente) rejeitaria o caso acima
    # MESMO com um .find cru — por isso NÃO substitui os assert_raises da
    # Camada 1 como prova de mutation sensitivity.
    divulgacao = @client_a.divulgacoes.new(
      arte: @arte_a,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group_b, group_name: @group_b.display_name, remote_jid: @group_b.remote_jid) ]
    )
    assert divulgacao.invalid?
    assert_includes divulgacao.errors[:base], "Um ou mais grupos selecionados não pertencem a este cliente."
  end

  # --- Test 2: envio nunca cruza cliente ----------------------------------

  test "Whatsapp::SendToGroupJob rodado sobre uma linha cross-client forçada nunca chama Evolution com o remote_jid do cliente B" do
    divulgacao_a = @client_a.divulgacoes.create!(
      arte: @arte_a, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group_a, group_name: @group_a.display_name, remote_jid: @group_a.remote_jid) ]
    )
    poisoned = divulgacao_a.divulgacao_grupos.first
    # Força a referência a apontar para o grupo do cliente B (bypassa a
    # validação de model arte_e_grupos_do_mesmo_cliente de propósito —
    # simula uma linha envenenada por acesso direto ao banco/console).
    poisoned.update_columns(whatsapp_group_id: @group_b.id, group_name: @group_b.display_name, remote_jid: @group_b.remote_jid)
    poisoned.reload

    # A instância PRÓPRIA do cliente A (a única que o job resolve via
    # divulgacao.client.whatsapp_instance) fica desconectada — reproduz o
    # guard `instance&.connected?` (send_to_group_job.rb:122-151) que já
    # roda ANTES de qualquer I/O de rede, independente de qual grupo a
    # linha carrega. É o guard existente da fase 29, não uma checagem nova
    # de cross-client — o job em si não tem hoje uma checagem que compare o
    # cliente-dono do grupo com o cliente-dono da divulgação; a barreira real
    # contra esse cenário é a validação de criação provada no Test 1. Este
    # teste prova que, mesmo com uma linha envenenada, os guards de
    # revalidação existentes continuam impedindo qualquer I/O.
    @instance_a.update!(connection_state: :disconnected)

    called_numbers = []
    Evolution::Client.stub(:send_text, ->(*_args, **_kwargs) { raise "não deveria ser chamado (send_text)" }) do
      Evolution::Client.stub(:send_media, ->(*_args, **_kwargs) { raise "não deveria ser chamado (send_media)" }) do
        Whatsapp::SendToGroupJob.perform_now(poisoned)
      end
    end

    assert_empty called_numbers
    refute_includes called_numbers, @group_b.remote_jid

    poisoned.reload
    assert_not_equal "enviado", poisoned.status
    assert_equal "falhou", poisoned.status
    assert_equal "instancia_desconectada", poisoned.error_code
  end

  # --- Test 3: belt de cadeia de token ------------------------------------

  test "tokens de instancia diferem entre clientes e SendToGroupJob resolve a chave via divulgacao.client.whatsapp_instance.token" do
    assert_not_equal @client_a.whatsapp_instance.token, @client_b.whatsapp_instance.token

    divulgacao_a = @client_a.divulgacoes.create!(
      arte: @arte_a, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group_a, group_name: @group_a.display_name, remote_jid: @group_a.remote_jid) ]
    )
    group_row = divulgacao_a.divulgacao_grupos.first

    Evolution::Client.stub(:send_media, ->(name, number:, mediatype:, media:, api_key:, caption:) {
      assert_equal @client_a.whatsapp_instance.token, api_key
      assert_not_equal @client_b.whatsapp_instance.token, api_key
      { "key" => { "id" => "MSG-BELT" } }
    }) do
      Whatsapp::SendToGroupJob.perform_now(group_row)
    end

    group_row.reload
    assert_equal "enviado", group_row.status
    assert_equal "MSG-BELT", group_row.evolution_message_id
  end

  # --- Test 4: isolamento sobrevive a instance_name compartilhado (fase 31) --

  test "isolamento cross-client sobrevive com um par de clientes-irmãos compartilhando instance_name (D-02, SEG-04)" do
    shared_instance_name = "livia_client_sibling_pair_#{SecureRandom.hex(4)}"
    client_c = build_client_with_whatsapp!(
      name: "Cliente C (irmão de A)", password: "senhaC123", token: "SEGREDO-INSTANCIA-C",
      instance_name: shared_instance_name
    )
    client_d = build_client_with_whatsapp!(
      name: "Cliente D (irmão de A)", password: "senhaD123", token: "SEGREDO-INSTANCIA-D",
      instance_name: shared_instance_name
    )
    assert_equal client_c.whatsapp_instance.instance_name, client_d.whatsapp_instance.instance_name
    assert client_c.whatsapp_instance.shared?
    assert client_d.whatsapp_instance.shared?

    group_c = client_c.whatsapp_instance.whatsapp_groups.create!(remote_jid: "grupo-c@g.us", subject: "Grupo do C", active: true, synced_at: Time.current)
    group_d = client_d.whatsapp_instance.whatsapp_groups.create!(remote_jid: "grupo-d@g.us", subject: "Grupo do D", active: true, synced_at: Time.current)
    arte_c = approved_arte_for!(client_c, "Arte Aprovada do C")
    arte_d = approved_arte_for!(client_d, "Arte Aprovada do D")

    divulgacao_d = client_d.divulgacoes.create!(
      arte: arte_d, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: group_d, group_name: group_d.display_name, remote_jid: group_d.remote_jid) ]
    )

    # O isolamento é ancorado no id da LINHA whatsapp_instance (client_c.whatsapp_instance.id
    # != client_d.whatsapp_instance.id), NUNCA no instance_name — mesmo os dois compartilhando
    # a mesma conexão física, o grupo de D pertence à linha de D.
    assert_raises(ActiveRecord::RecordNotFound) do
      client_c.whatsapp_instance.whatsapp_groups.where(active: true).find([ group_d.id ])
    end

    assert_raises(ActiveRecord::RecordNotFound) do
      client_c.divulgacoes.find(divulgacao_d.id)
    end

    # Backstop de model: continua rejeitando arte-de-C + grupo-de-D mesmo com
    # instance_name compartilhado entre as linhas.
    divulgacao = client_c.divulgacoes.new(
      arte: arte_c,
      scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: group_d, group_name: group_d.display_name, remote_jid: group_d.remote_jid) ]
    )
    assert divulgacao.invalid?
    assert_includes divulgacao.errors[:base], "Um ou mais grupos selecionados não pertencem a este cliente."
  end

  private

  def build_client_with_whatsapp!(name:, password:, token:, instance_name: nil)
    client = Client.create!(name: name, password: password, password_confirmation: password)
    client.create_whatsapp_instance!(
      instance_name: instance_name || WhatsappInstance.evolution_name_for(client),
      connection_state: :connected,
      token: token,
      groups_synced_at: Time.current
    )
    client
  end

  def approved_arte_for!(client, title)
    arte = client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :approved, title: title
    )
    arte.media_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")),
      filename: "sample.jpg", content_type: "image/jpeg"
    )
    arte.save!
    arte
  end
end
