require "test_helper"

class DivulgacaoTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Divulgacao Model Test", password: "senha123", password_confirmation: "senha123")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected
    )
    @group = @instance.whatsapp_groups.create!(remote_jid: "gm1@g.us", subject: "Grupo Modelo", active: true, synced_at: Time.current)
    # Arte aprovada com link externo (o default do setup — vários testes o sobrescrevem).
    @arte = @client.artes.create!(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: :approved, title: "Arte", external_url: "https://drive.google.com/file/exemplo"
    )
  end

  # --- helpers de construção ------------------------------------------------

  def arte_com_arquivo(status: :approved, byte_size: nil, client: @client)
    arte = client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :image,
      status: status, title: "Arte com arquivo"
    )
    arte.media_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample.jpg")),
      filename: "sample.jpg", content_type: "image/jpeg"
    )
    arte.save!
    arte.media_file.blob.update_column(:byte_size, byte_size) if byte_size
    arte
  end

  def arte_caption_only(status: :approved, client: @client)
    arte = client.artes.new(
      scheduled_on: Date.current, platform: :instagram, media_type: :caption_only,
      status: status, title: "Arte só texto", caption: "Bom dia!"
    )
    # A validação media_source_present da Arte exige arquivo OU link; caption_only
    # (sem nenhum dos dois) é uma decisão de escopo da fase 28 para a Divulgação,
    # não para a Arte — o teste constrói o registro sem revalidar a Arte.
    arte.save!(validate: false)
    arte
  end

  def grupo_dg(group = @group)
    DivulgacaoGrupo.new(whatsapp_group: group, group_name: group.display_name, remote_jid: group.remote_jid)
  end

  def divulgacao_para(arte, scheduled_for: 3.days.from_now, grupos: [ nil ], client: @client)
    client.divulgacoes.new(
      arte: arte,
      scheduled_for: scheduled_for,
      divulgacao_grupos: grupos.map { |g| grupo_dg(g || @group) }
    )
  end

  # --- enum default ------------------------------------------------------

  test "status default e agendada" do
    assert_equal "agendada", Divulgacao.new.status
  end

  # --- scheduled_for: presença + futuro (DIVU-05) ----------------------

  test "divulgacao sem scheduled_for reporta 'Informe a data e hora do envio.' em errors[:base]" do
    d = divulgacao_para(arte_com_arquivo, scheduled_for: nil)
    assert_not d.valid?
    assert_includes d.errors[:base], "Informe a data e hora do envio."
    assert_not_includes d.errors[:base], "A data e hora do envio precisam estar no futuro."
  end

  test "divulgacao com scheduled_for no passado e invalida com mensagem de futuro" do
    d = divulgacao_para(arte_com_arquivo, scheduled_for: 1.hour.ago)
    assert_not d.valid?
    assert_includes d.errors[:base], "A data e hora do envio precisam estar no futuro."
  end

  test "divulgacao com scheduled_for no futuro passa na regra de futuro" do
    d = divulgacao_para(arte_com_arquivo, scheduled_for: 1.day.from_now)
    d.valid?
    assert_not_includes d.errors[:base], "A data e hora do envio precisam estar no futuro."
  end

  # --- DIVU-02: só artes aprovadas ------------------------------------

  test "arte pending recusa a divulgacao (DIVU-02)" do
    d = divulgacao_para(arte_com_arquivo(status: :pending))
    assert_not d.valid?
    assert_includes d.errors[:base], "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação."
  end

  test "arte change_requested recusa a divulgacao (DIVU-02)" do
    d = divulgacao_para(arte_com_arquivo(status: :change_requested))
    assert_not d.valid?
    assert_includes d.errors[:base], "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação."
  end

  test "arte revised recusa a divulgacao (DIVU-02)" do
    d = divulgacao_para(arte_com_arquivo(status: :revised))
    assert_not d.valid?
    assert_includes d.errors[:base], "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação."
  end

  test "arte approved nao dispara o erro de aprovacao (DIVU-02)" do
    d = divulgacao_para(arte_com_arquivo(status: :approved))
    d.valid?
    assert_not_includes d.errors[:base], "A arte selecionada não está aprovada. Só artes aprovadas podem ser agendadas para divulgação."
  end

  # --- DIVU-03: link externo recusado, caption_only aceito ------------

  test "arte com external_url recusa a divulgacao (DIVU-03)" do
    d = divulgacao_para(@arte) # @arte tem external_url do setup
    assert_not d.valid?
    assert_includes d.errors[:base], "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a divulgação."
  end

  test "arte com media_file anexado e sem external_url nao dispara o erro de link (DIVU-03)" do
    d = divulgacao_para(arte_com_arquivo)
    d.valid?
    assert_not_includes d.errors[:base], "Esta arte usa um link externo. Faça o upload do arquivo na arte antes de agendar a divulgação."
  end

  test "arte caption_only (sem arquivo, sem link) e uma Divulgacao valida (DIVU-03, caption_only IN escopo)" do
    d = divulgacao_para(arte_caption_only)
    assert d.valid?, d.errors.full_messages.inspect
  end

  # --- DIVU-04: teto de 16 MB, só quando há arquivo ------------------

  test "WHATSAPP_MEDIA_MAX_BYTES e 16 megabytes" do
    assert_equal 16.megabytes, Divulgacao::WHATSAPP_MEDIA_MAX_BYTES
  end

  test "arquivo de 20 MB recusa a divulgacao com tamanho, teto e o que fazer (DIVU-04)" do
    d = divulgacao_para(arte_com_arquivo(byte_size: 20.megabytes))
    assert_not d.valid?
    msg = d.errors[:base].find { |m| m.start_with?("O arquivo tem") }
    assert msg, d.errors[:base].inspect
    assert_includes msg, "20 MB"
    assert_includes msg, "16 MB"
    assert_includes msg, "Comprima ou reenvie um arquivo menor na arte."
  end

  test "arquivo de 1 MB passa no teto (DIVU-04)" do
    d = divulgacao_para(arte_com_arquivo(byte_size: 1.megabyte))
    d.valid?
    assert_empty d.errors[:base].select { |m| m.start_with?("O arquivo tem") }
  end

  test "sem media_file anexado o teto e ignorado (DIVU-04, caption_only)" do
    d = divulgacao_para(arte_caption_only)
    d.valid?
    assert_empty d.errors[:base].select { |m| m.start_with?("O arquivo tem") }
  end

  # --- SEG-02: arte e grupos do mesmo cliente -----------------------

  test "arte de outro cliente recusa a divulgacao (SEG-02)" do
    outro = Client.create!(name: "Outro Cliente", password: "senha123", password_confirmation: "senha123")
    arte_de_outro = arte_com_arquivo(client: outro)
    d = divulgacao_para(arte_de_outro) # client: @client, grupo do @client
    assert_not d.valid?
    assert_includes d.errors[:base], "A arte e os grupos precisam ser do mesmo cliente."
  end

  test "grupo de outro cliente recusa a divulgacao (SEG-02)" do
    outro = Client.create!(name: "Outro Cliente Grupo", password: "senha123", password_confirmation: "senha123")
    inst_outro = outro.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(outro), connection_state: :connected
    )
    grupo_outro = inst_outro.whatsapp_groups.create!(remote_jid: "go1@g.us", subject: "Grupo do Outro", active: true, synced_at: Time.current)

    d = divulgacao_para(arte_com_arquivo, grupos: [ grupo_outro ])
    assert_not d.valid?
    assert_includes d.errors[:base], "Um ou mais grupos selecionados não pertencem a este cliente."
  end

  test "arte e grupos do mesmo cliente nao disparam o erro de cliente (SEG-02)" do
    d = divulgacao_para(arte_com_arquivo)
    d.valid?
    assert_not_includes d.errors[:base], "A arte e os grupos precisam ser do mesmo cliente."
    assert_not_includes d.errors[:base], "Um ou mais grupos selecionados não pertencem a este cliente."
  end

  # --- ao menos um grupo (plano 01, mantido) -----------------------

  test "divulgacao com scheduled_for mas sem grupos e invalida com errors[:base]" do
    d = @client.divulgacoes.new(arte: arte_com_arquivo, scheduled_for: 3.days.from_now)
    assert_not d.valid?
    assert_includes d.errors[:base], "Selecione ao menos um grupo para a divulgação."
  end

  # --- caminho feliz completo -------------------------------------

  test "divulgacao valida: arte aprovada com arquivo, futuro e ao menos um grupo" do
    d = divulgacao_para(arte_com_arquivo)
    assert d.valid?, d.errors.full_messages.inspect
  end

  # --- Task 2: cancelar! ---------------------------------------------------

  test "cancelar! numa divulgacao agendada -- flipa pra cancelada e retorna true" do
    d = @client.divulgacoes.create!(
      arte: arte_com_arquivo, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ]
    )

    assert d.cancelar!
    assert_equal "cancelada", d.reload.status
  end

  test "cancelar! numa divulgacao ja cancelada -- retorna false, permanece cancelada" do
    d = @client.divulgacoes.create!(
      arte: arte_com_arquivo, scheduled_for: 3.days.from_now,
      divulgacao_grupos: [ DivulgacaoGrupo.new(whatsapp_group: @group, group_name: @group.display_name, remote_jid: @group.remote_jid) ]
    )
    d.cancelar!

    assert_not d.cancelar!
    assert_equal "cancelada", d.reload.status
  end
end
