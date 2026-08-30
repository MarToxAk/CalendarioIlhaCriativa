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

  test "discard_on Permanent grava groups_sync_error=transient e state=error, sem reenfileirar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::Permanent)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "error", @instance.groups_sync_state
    assert_equal "transient", @instance.groups_sync_error
  end

  test "discard_on NotConnected grava groups_sync_error=not_connected, sem reenfileirar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::NotConnected)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "error", @instance.groups_sync_state
    assert_equal "not_connected", @instance.groups_sync_error
  end

  test "discard_on ConfigurationError grava groups_sync_error=transient, sem reenfileirar" do
    fake = FakeSynchronizer.new(error_class: Evolution::Errors::ConfigurationError)
    Whatsapp::GroupSynchronizer.stub(:new, ->(*) { fake }) do
      assert_no_enqueued_jobs do
        Whatsapp::SyncGroupsJob.perform_now(@instance)
      end
    end
    @instance.reload
    assert_equal "error", @instance.groups_sync_state
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
