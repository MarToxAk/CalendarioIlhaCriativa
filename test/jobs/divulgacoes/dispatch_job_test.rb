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

  # --- 29-03: escalonamento sob N grupos (ENVIO-02, ENVIO-03) -------------

  # Setup dedicado com 4 grupos pendentes -- o setup padrao (1 grupo) acima
  # nao pega bug de escalonamento (offset que nao acumula, ou que bloqueia o
  # worker), que so aparece com multiplos grupos e timing real.
  def setup_multi_group_divulgacao
    groups = 4.times.map do |i|
      @instance.whatsapp_groups.create!(remote_jid: "g#{i + 2}@g.us", subject: "Grupo #{i + 2}", active: true, synced_at: Time.current)
    end
    divulgacao = @client.divulgacoes.create!(
      arte: @arte, scheduled_for: 3.days.from_now,
      divulgacao_grupos: groups.map { |g| DivulgacaoGrupo.new(whatsapp_group: g, group_name: g.display_name, remote_jid: g.remote_jid) }
    )
    divulgacao
  end

  # stub_const nao esta disponivel (minitest 5.x puro, sem gem
  # minitest-stub_const neste projeto) -- atribuicao direta via const_set,
  # restaurada no ensure, com silence_warnings para o
  # "already initialized constant" esperado (nao editar o ENV do processo de
  # teste inteiro).
  def with_send_delay_range(min, max)
    original_min = Divulgacao::SEND_DELAY_MIN
    original_max = Divulgacao::SEND_DELAY_MAX
    silence_warnings { Divulgacao.const_set(:SEND_DELAY_MIN, min); Divulgacao.const_set(:SEND_DELAY_MAX, max) }
    yield
  ensure
    silence_warnings { Divulgacao.const_set(:SEND_DELAY_MIN, original_min); Divulgacao.const_set(:SEND_DELAY_MAX, original_max) }
  end

  test "perform enfileira todos os grupos pendentes com offsets crescentes dentro da faixa ENV, primeiro grupo com offset 0" do
    divulgacao = setup_multi_group_divulgacao
    started_at = Time.current

    with_send_delay_range(10, 20) do
      Divulgacoes::DispatchJob.perform_now(divulgacao)
    end

    enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "Whatsapp::SendToGroupJob" }
    assert_equal 4, enqueued.size

    # `wait: 0.seconds` ainda produz um scheduled_at (nao nil) igual a
    # "agora" -- o primeiro grupo tem offset 0, entao seu scheduled_at cai
    # dentro de uma janela de folga curta a partir do inicio do teste.
    scheduled_times = enqueued.map { |j| Time.iso8601(j["scheduled_at"]) }
    assert_in_delta started_at.to_f, scheduled_times.first.to_f, 2.0,
      "primeiro grupo deve ter offset 0 -- scheduled_at ~= agora"

    assert scheduled_times.each_cons(2).all? { |a, b| b > a },
      "cada offset subsequente deve ser estritamente maior que o anterior (offsets acumulam, nunca resetam)"
  end

  test "perform enfileira N jobs rapidamente sem sleep -- dispatch nao ocupa o worker esperando entre grupos" do
    divulgacao = setup_multi_group_divulgacao

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Divulgacoes::DispatchJob.perform_now(divulgacao)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 1.0,
      "enfileirar 4 registros e uma operacao de milissegundos -- nunca deveria levar segundos (prova indireta de ENVIO-03)"
  end

  test "divulgacoes.status vai para em_andamento assim que o perform roda, ANTES de qualquer SendToGroupJob ter sido executado" do
    divulgacao = setup_multi_group_divulgacao
    Divulgacoes::DispatchJob.perform_now(divulgacao)

    assert_equal "em_andamento", divulgacao.reload.status
    assert divulgacao.divulgacao_grupos.pendente.count.positive?, "nenhum SendToGroupJob deve ter rodado ainda (sem perform_enqueued_jobs)"
  end

  test "grep estatico: nenhum sleep em dispatch_job.rb" do
    assert_not File.read(Rails.root.join("app/jobs/divulgacoes/dispatch_job.rb")).match?(/\bsleep\b/)
  end
end
