require "test_helper"

# Corpo real do envio (fase 29-01, ENVIO-04/06/07/08/10, SEG-03). Mesmo setup
# shape de test/jobs/whatsapp/sync_groups_job_test.rb e
# test/controllers/admin/divulgacoes_controller_test.rb (Client.create!,
# create_whatsapp_instance!, whatsapp_groups.create!, arte aprovada com
# media_file anexado). Nenhum I/O de rede real — Evolution::Client stubado.
class Whatsapp::SendToGroupJobTest < ActiveJob::TestCase
  def setup
    # Fora de um request, o Disk service (config/environments/test.rb) exige
    # ActiveStorage::Current.url_options explicito para gerar a URL de mídia
    # (send_via_evolution chama arte.media_file.url). Mesmo padrão já usado
    # pelos before_actions das APIs (app/controllers/api/v1/*/base_controller.rb)
    # -- só necessário aqui porque o Disk service não tem host implícito de
    # request; o serviço real de produção/dev (:amazon/S3) gera URL presignada
    # sem depender de contexto de request (RESEARCH Pitfall 2).
    ActiveStorage::Current.url_options = { host: "example.com", protocol: "https" }
    @client = Client.create!(name: "SendToGroupJob Test", password: "senha1234", password_confirmation: "senha1234")
    @instance = @client.create_whatsapp_instance!(
      instance_name: WhatsappInstance.evolution_name_for(@client),
      connection_state: :connected,
      token: "SEGREDO-INSTANCIA",
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

  test "perform via sendMedia -- marca enviado com sent_at e evolution_message_id, chama send_media com o token da instancia do CLIENTE (SEG-03)" do
    Evolution::Client.stub(:send_media, ->(name, number:, mediatype:, media:, api_key:, caption:) {
      assert_equal @instance.instance_name, name
      assert_equal @instance.token, api_key
      assert_equal @group_row.remote_jid, number
      assert_equal "image", mediatype
      { "key" => { "id" => "MSG1" } }
    }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "enviado", @group_row.status
    assert_not_nil @group_row.sent_at
    assert_equal "MSG1", @group_row.evolution_message_id
  end

  test "WR-05: shape de sucesso com 'key' non-Hash cai no fallback resp['id'] sem virar :falhou" do
    Evolution::Client.stub(:send_media, ->(*) { { "key" => "MSG-FLAT", "id" => "MSGX" } }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "enviado", @group_row.status, "mensagem foi entregue -- parsing do shape nunca deve virar :falhou"
    assert_equal "MSGX", @group_row.evolution_message_id
  end

  test "perform via sendText quando arte.caption_only?" do
    @arte.media_file.purge
    @arte.update_columns(media_type: Arte.media_types[:caption_only], caption: "Bom dia a todos!")

    Evolution::Client.stub(:send_text, ->(name, number:, text:, api_key:) {
      assert_equal @instance.instance_name, name
      assert_equal @instance.token, api_key
      assert_equal @group_row.remote_jid, number
      assert_equal "Bom dia a todos!", text
      { "key" => { "id" => "MSG2" } }
    }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "enviado", @group_row.status
    assert_equal "MSG2", @group_row.evolution_message_id
  end

  test "revalidacao: arte nao aprovada nunca chama Evolution" do
    @arte.update_column(:status, Arte.statuses[:change_requested])

    Evolution::Client.stub(:send_media, ->(*) { raise "nao deveria ser chamado" }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_equal "arte_nao_aprovada", @group_row.error_code
    assert_nil @group_row.sent_at, "CR-01: linha :falhou nunca pode carregar sent_at do claim (Evolution nem foi chamada)"
  end

  test "revalidacao: instancia desconectada nunca chama Evolution" do
    @instance.update!(connection_state: :disconnected)

    Evolution::Client.stub(:send_media, ->(*) { raise "nao deveria ser chamado" }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_equal "instancia_desconectada", @group_row.error_code
    assert_nil @group_row.sent_at, "CR-01: linha :falhou nunca pode carregar sent_at do claim (Evolution nem foi chamada)"
  end

  test "cancelamento: divulgacao cancelada faz perform virar no-op silencioso, item continua pendente" do
    @divulgacao.update!(status: :cancelada)

    Evolution::Client.stub(:send_media, ->(*) { raise "nao deveria ser chamado" }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    assert_equal "pendente", @group_row.reload.status
  end

  test "claim atomico: um grupo ja enviado nao chama Evolution de novo" do
    @group_row.update!(status: :enviado, sent_at: Time.current)

    Evolution::Client.stub(:send_media, ->(*) { raise "nao deveria ser chamado" }) do
      assert_nothing_raised do
        Whatsapp::SendToGroupJob.perform_now(@group_row)
      end
    end
  end

  test "token nunca entra nos argumentos serializados do job" do
    job = Whatsapp::SendToGroupJob.new(@group_row)
    serialized = job.serialize

    refute_includes serialized["arguments"].to_s, "SEGREDO-INSTANCIA"
  end

  test "queue_as whatsapp_sends" do
    assert_equal "whatsapp_sends", Whatsapp::SendToGroupJob.new.queue_name
  end

  # --- 29-02: taxonomia de erro completa ---------------------------------

  test "discard_on Permanent grava falhou e error_code truncado a partir da mensagem do erro" do
    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::Permanent, "x" * 1000 }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_operator @group_row.error_code.length, :<=, 500
    assert_nil @group_row.sent_at, "CR-01: :falhou (Permanent) nunca pode carregar sent_at do claim"
  end

  test "WR-03: error_code redige URLs presignadas ecoadas no texto livre do erro Evolution" do
    leak = 'BadRequest: failed to download resource: https://bucket.s3.amazonaws.com/artes/1.jpg?X-Amz-Signature=deadbeef&X-Amz-Expires=300'
    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::Permanent, leak }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_not_includes @group_row.error_code, "https://"
    assert_not_includes @group_row.error_code, "X-Amz-Signature"
    assert_includes @group_row.error_code, "[url-redigida]"
  end

  test "discard_on Unknown grava incerto (nunca falhou), sem reenfileirar" do
    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::Unknown, "timeout de leitura" }) do
      assert_no_enqueued_jobs do
        Whatsapp::SendToGroupJob.perform_now(@group_row)
      end
    end

    assert_equal "incerto", @group_row.reload.status
    assert_not_nil @group_row.reload.sent_at, "CR-01: :incerto PRESERVA sent_at de proposito -- read-timeout pode ter entregue"
  end

  test "discard_on NotConnected grava falhou com instancia_desconectada" do
    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::NotConnected, "connectionState != open" }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_equal "instancia_desconectada", @group_row.error_code
    assert_nil @group_row.sent_at, "CR-01: :falhou (NotConnected) nunca pode carregar sent_at do claim"
  end

  test "discard_on ConfigurationError grava falhou com a mensagem truncada" do
    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::ConfigurationError, "base_url ausente" }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_equal "base_url ausente", @group_row.error_code
    assert_nil @group_row.sent_at, "CR-01: :falhou (ConfigurationError) nunca pode carregar sent_at do claim"
  end

  test "discard_on StandardError (catch-all) cobre excecao fora da taxonomia Evolution::Errors e ainda assim finaliza a divulgacao se for o ultimo grupo pendente" do
    @divulgacao.update!(status: :em_andamento) # estado real no momento em que o DispatchJob enfileira o SendToGroupJob

    Evolution::Client.stub(:send_media, ->(*) { raise Faraday::ParsingError, "corpo inesperado" }) do
      Whatsapp::SendToGroupJob.perform_now(@group_row)
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_equal "unexpected_error", @group_row.error_code
    assert_nil @group_row.sent_at, "CR-01: :falhou (catch-all StandardError) nunca pode carregar sent_at do claim"
    assert_equal "concluida", @divulgacao.reload.status
  end

  test "discard_on StandardError (catch-all) nao rouba Transient do retry_on mais especifico" do
    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::Transient, "connection refused" }) do
      assert_enqueued_with(job: Whatsapp::SendToGroupJob, args: [ @group_row ]) do
        Whatsapp::SendToGroupJob.perform_now(@group_row)
      end
    end
  end

  test "retry_on Transient desfaz o claim (status volta a pendente) antes de reenfileirar -- a nova tentativa realmente tenta enviar de novo, nao vira no-op" do
    calls = 0
    stub_impl = lambda do |*|
      calls += 1
      raise Evolution::Errors::Transient, "connection refused" if calls == 1
      { "key" => { "id" => "MSG2" } }
    end

    Evolution::Client.stub(:send_media, stub_impl) do
      assert_enqueued_with(job: Whatsapp::SendToGroupJob, args: [ @group_row ]) do
        Whatsapp::SendToGroupJob.perform_now(@group_row)
      end
      assert_equal "pendente", @group_row.reload.status # claim desfeito, nao ficou preso em enviado

      Whatsapp::SendToGroupJob.perform_now(@group_row) # simula o que retry_on faria de fato
    end

    @group_row.reload
    assert_equal 2, calls
    assert_equal "enviado", @group_row.status
    assert_equal "MSG2", @group_row.evolution_message_id
  end

  test "retry_on Transient chama mark_falhou (error_code transient) na tentativa final (exhaustion), sem reenfileirar de novo" do
    job = Whatsapp::SendToGroupJob.new(@group_row)
    job.exception_executions = { "[Evolution::Errors::Transient]" => 5 }

    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::Transient, "connection refused" }) do
      assert_no_enqueued_jobs do
        job.perform_now
      end
    end

    @group_row.reload
    assert_equal "falhou", @group_row.status
    assert_equal "transient", @group_row.error_code
    assert_nil @group_row.sent_at, "CR-01: :falhou (Transient exaustao) nunca pode carregar sent_at do claim"
  end

  test "limits_concurrency configurado para 1 por instancia" do
    assert_equal 1, Whatsapp::SendToGroupJob.concurrency_limit
    assert_equal :block, Whatsapp::SendToGroupJob.concurrency_on_conflict
  end

  test "concurrency_key resolve para o whatsapp_instance_id do grupo (regressao do fix da Task 1 do plano 29-01)" do
    job = Whatsapp::SendToGroupJob.new(@group_row)
    assert_includes job.concurrency_key, @instance.id.to_s
  end

  test "token nunca entra no argumento serializado, mesmo com limits_concurrency declarado" do
    job = Whatsapp::SendToGroupJob.new(@group_row)
    serialized = job.serialize

    refute_includes serialized["arguments"].to_s, "SEGREDO-INSTANCIA"
  end

  # --- 29-02: idempotencia sob execucao concorrente/duplicada (ENVIO-04) --

  test "claim atomico: update_all condicional retorna 0 quando outro processo/tentativa ja tratou o item" do
    @group_row.update!(status: :enviado)
    claimed = DivulgacaoGrupo.where(id: @group_row.id, status: :pendente).update_all(status: :enviado)
    assert_equal 0, claimed
  end

  test "perform_now duas vezes seguidas no mesmo grupo pendente so chama Evolution::Client uma unica vez" do
    calls = 0
    Evolution::Client.stub(:send_media, ->(*) { calls += 1; { "key" => { "id" => "X" } } }) do
      2.times { Whatsapp::SendToGroupJob.perform_now(@group_row) }
    end

    assert_equal 1, calls
  end

  test "dois SendToGroupJob enfileirados para o MESMO grupo -- o segundo a rodar e sempre um no-op" do
    calls = 0
    Evolution::Client.stub(:send_media, ->(*) { calls += 1; { "key" => { "id" => "X" } } }) do
      Whatsapp::SendToGroupJob.perform_later(@group_row)
      Whatsapp::SendToGroupJob.perform_later(@group_row)
      perform_enqueued_jobs
    end

    assert_equal 1, calls
  end

  test "um grupo ja falhou/incerto/enviado nunca e reivindicado de novo pelo claim" do
    %w[falhou incerto enviado].each do |status|
      @group_row.update!(status: status)
      claimed = DivulgacaoGrupo.where(id: @group_row.id, status: :pendente).update_all(status: :enviado)
      assert_equal 0, claimed, "esperava claim=0 para status inicial #{status}"
    end
  end

  # --- 29-03: cancelamento mid-dispatch + fechamento de divulgacoes.status (DIVU-08) --

  # Divulgacao dedicada com N grupos pendentes (remote_jid unico por chamada
  # para nao colidir com o indice unico whatsapp_instance_id+remote_jid).
  def build_divulgacao_with_groups(n)
    groups = n.times.map do |i|
      @instance.whatsapp_groups.create!(
        remote_jid: "mg-#{SecureRandom.hex(4)}-#{i}@g.us", subject: "Grupo Multi #{i}", active: true, synced_at: Time.current
      )
    end
    @client.divulgacoes.create!(
      arte: @arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: groups.map { |g| DivulgacaoGrupo.new(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid) }
    )
  end

  test "cancelamento ANTES do DispatchJob rodar: perform_now direto numa divulgacao cancelada e no-op, item continua pendente, Evolution nunca chamado" do
    divulgacao = build_divulgacao_with_groups(2)
    divulgacao.update!(status: :cancelada)
    group1 = divulgacao.divulgacao_grupos.first

    Evolution::Client.stub(:send_media, ->(*) { raise "nao deveria ser chamado" }) do
      Whatsapp::SendToGroupJob.perform_now(group1)
    end

    assert_equal "pendente", group1.reload.status
  end

  test "cancelamento DEPOIS do DispatchJob ja ter enfileirado -- o SendToGroupJob cujo offset ainda nao decorreu vira no-op quando roda" do
    divulgacao = build_divulgacao_with_groups(2)
    calls = 0

    Evolution::Client.stub(:send_media, ->(*) { calls += 1; { "key" => { "id" => "X" } } }) do
      Divulgacoes::DispatchJob.perform_now(divulgacao) # enfileira N SendToGroupJob
      divulgacao.update!(status: :cancelada) # admin clica cancelar enquanto os jobs esperam o offset
      perform_enqueued_jobs
    end

    assert_equal 0, calls, "Evolution::Client nunca deveria ser chamado apos o cancelamento"
    assert divulgacao.divulgacao_grupos.reload.all? { |g| g.status == "pendente" }, "nenhum divulgacao_grupo deveria ter mudado de pendente"
  end

  test "cancelamento no meio de um lote -- o grupo JA enviado antes do cancel permanece enviado; os que ainda nao rodaram viram no-op" do
    divulgacao = build_divulgacao_with_groups(2)
    group1, group2 = divulgacao.divulgacao_grupos.order(:id).to_a

    Evolution::Client.stub(:send_media, ->(*) { { "key" => { "id" => "OK1" } } }) do
      Whatsapp::SendToGroupJob.perform_now(group1)
    end

    divulgacao.update!(status: :cancelada)

    Evolution::Client.stub(:send_media, ->(*) { raise "nao deveria ser chamado" }) do
      Whatsapp::SendToGroupJob.perform_now(group2)
    end

    assert_equal "enviado", group1.reload.status, "cancelamento nao reverte o que ja foi enviado"
    assert_equal "pendente", group2.reload.status, "grupo posterior ao cancelamento nunca foi tentado"
  end

  test "fechamento de divulgacoes.status: o ULTIMO grupo pendente saindo (por qualquer caminho) marca a divulgacao concluida" do
    divulgacao = build_divulgacao_with_groups(2)
    divulgacao.update!(status: :em_andamento)
    group1, group2 = divulgacao.divulgacao_grupos.order(:id).to_a

    Evolution::Client.stub(:send_media, ->(*) { { "key" => { "id" => "OK1" } } }) do
      Whatsapp::SendToGroupJob.perform_now(group1)
    end
    assert_equal "em_andamento", divulgacao.reload.status, "ainda tem 1 pendente"

    Evolution::Client.stub(:send_media, ->(*) { raise Evolution::Errors::Permanent, "erro simulado" }) do
      Whatsapp::SendToGroupJob.perform_now(group2)
    end
    assert_equal "concluida", divulgacao.reload.status, "zero pendentes, mesmo com uma falha no meio"
  end

  test "uma divulgacao com pendentes restantes NUNCA vira concluida antes da hora" do
    divulgacao = build_divulgacao_with_groups(3)
    divulgacao.update!(status: :em_andamento)
    group1, group2, _group3 = divulgacao.divulgacao_grupos.order(:id).to_a

    Evolution::Client.stub(:send_media, ->(*) { { "key" => { "id" => "OK" } } }) do
      Whatsapp::SendToGroupJob.perform_now(group1)
      Whatsapp::SendToGroupJob.perform_now(group2)
    end

    assert_equal "em_andamento", divulgacao.reload.status, "o terceiro grupo ainda pendente trava a transicao"
  end
end
