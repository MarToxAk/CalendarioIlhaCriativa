require "test_helper"

# Sem analog no repo (primeiro ActiveJob) — modela nos discard_on/retry_on do
# próprio Rails. DI via stub de Whatsapp::GroupSynchronizer.new — sem rede,
# sem Evolution::Client real (Task 1, GRUPO-01).
class Whatsapp::SyncGroupsJobTest < ActiveJob::TestCase
  class FakeSynchronizer
    attr_reader :calls

    def initialize(error_class: nil)
      @error_class = error_class
      @calls = 0
    end

    def call
      @calls += 1
      raise @error_class, "fake" if @error_class

      true
    end
  end

  def setup
    @client = Client.create!(
      name: "SyncJob Test",
      password: "senha1234",
      password_confirmation: "senha1234"
    )
    @instance = WhatsappInstance.create!(
      client: @client,
      instance_name: WhatsappInstance.evolution_name_for(@client),
      token: "SEGREDO",
      connection_state: :connected
    )
  end

  test "queue_as default" do
    assert_equal "default", Whatsapp::SyncGroupsJob.new.queue_name
  end

  test "perform delega ao GroupSynchronizer uma unica vez e nada mais" do
    fake = FakeSynchronizer.new
    Whatsapp::GroupSynchronizer.stub(:new, ->(instance) { assert_equal @instance, instance; fake }) do
      Whatsapp::SyncGroupsJob.new(@instance).perform_now
    end
    assert_equal 1, fake.calls
  end

  test "retry_on Transient reenfileira em vez de descartar (GET idempotente)" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Transient)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_enqueued_with(job: Whatsapp::SyncGroupsJob, args: [ @instance ]) do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    assert_nil @instance.reload.groups_sync_error
  end

  test "retry_on Unknown reenfileira em vez de descartar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Unknown)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_enqueued_with(job: Whatsapp::SyncGroupsJob, args: [ @instance ]) do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    assert_nil @instance.reload.groups_sync_error
  end

  # 27-REVIEW.md WR-03-DUP: codigo distinto de "transient" -- Permanent (400/404/422/401/403)
  # nao e a mesma causa raiz de uma falha de rede, e quem depura via groups_sync_error no
  # Rails console/DB precisa distinguir os dois.
  test "discard_on Permanent grava groups_sync_error=permanent e state=error, sem reenfileirar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Permanent)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal "permanent", @instance.groups_sync_error
  end

  test "discard_on NotConnected grava groups_sync_error=not_connected, sem reenfileirar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::NotConnected)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal "not_connected", @instance.groups_sync_error
  end

  # 27-REVIEW.md WR-03-DUP: codigo distinto de "transient" -- ConfigurationError e um erro de
  # boot/config (base_url ou apikey global ausente), nao uma falha de rede transitoria.
  test "discard_on ConfigurationError grava groups_sync_error=config_error, sem reenfileirar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::ConfigurationError)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal "config_error", @instance.groups_sync_error
  end

  # 27-REVIEW.md WR-A (re-review): garante que o discard_on(StandardError) catch-all --
  # declarado PRIMEIRO na classe -- so pega excecoes que NENHUM handler mais especifico
  # cobre, e ainda assim tira groups_sync_state de :syncing (senao o gate groups_sync_syncing?
  # do WR-02 bloqueia todo re-sync futuro, permanentemente).
  test "discard_on StandardError (catch-all) cobre excecao fora da taxonomia Evolution::Errors e ainda assim limpa groups_sync_state" do
    fake = FakeSynchronizer.new(error_class: Faraday::ParsingError)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal "transient", @instance.groups_sync_error
    refute @instance.groups_sync_syncing?
  end

  # 27-REVIEW.md WR-A (re-review): o catch-all so deve rodar quando NENHUM handler mais
  # especifico responde -- Transient continua reenfileirando normalmente (nao e engolido
  # pelo discard_on(StandardError) so por ele estar declarado antes na classe).
  test "discard_on StandardError (catch-all) nao rouba Transient do retry_on mais especifico" do
    @instance.update!(groups_sync_state: :syncing)
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Transient)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_enqueued_with(job: Whatsapp::SyncGroupsJob, args: [ @instance ]) do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    assert_nil @instance.reload.groups_sync_error
    # retry_on (nao exaurido) nunca toca groups_sync_state -- so mark_error na
    # exaustao/discard faz isso. Continua "syncing" (setado pelo controller antes
    # de enfileirar), provando que o catch-all NAO interceptou este Transient.
    assert @instance.groups_sync_syncing?
  end

  # 27-REVIEW.md WR-B: a 3a/ultima tentativa de retry_on Transient tem que efetivamente
  # chamar mark_error -- os testes acima de "retry_on Transient/Unknown reenfileira" so
  # cobrem a 1a tentativa. exception_executions pode ser setado direto no teste (sem
  # precisar dormir pelos wait: 30.seconds reais).
  test "retry_on Transient chama mark_error na tentativa final (exhaustion), sem reenfileirar de novo" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Transient)
    job = Whatsapp::SyncGroupsJob.new(@instance)
    job.exception_executions = { "[Evolution::Errors::Transient]" => 3 }

    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        job.perform_now
      end
    end
    @instance.reload
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal "transient", @instance.groups_sync_error
    refute @instance.groups_sync_syncing?
  end

  test "retry_on Unknown chama mark_error na tentativa final (exhaustion), sem reenfileirar de novo" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Unknown)
    job = Whatsapp::SyncGroupsJob.new(@instance)
    job.exception_executions = { "[Evolution::Errors::Unknown]" => 3 }

    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        job.perform_now
      end
    end
    @instance.reload
    assert_equal "sync_error", @instance.groups_sync_state
    assert_equal "transient", @instance.groups_sync_error
  end

  test "discard_on ActiveJob::DeserializationError nao tem efeito colateral (instancia deletada mid-flight)" do
    Whatsapp::SyncGroupsJob.perform_later(@instance)
    @instance.destroy!

    assert_nothing_raised do
      perform_enqueued_jobs
    end
  end

  test "perform_later serializa via GlobalID -- o token nunca entra nos argumentos do job" do
    job = Whatsapp::SyncGroupsJob.new(@instance)
    serialized = job.serialize

    refute_includes serialized["arguments"].to_s, "SEGREDO"
  end
end
