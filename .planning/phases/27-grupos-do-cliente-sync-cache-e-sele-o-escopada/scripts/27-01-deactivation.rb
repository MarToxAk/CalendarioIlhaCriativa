# bin/rails runner .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/scripts/27-01-deactivation.rb
#
# Task 2 <verify> — passada de desativação (GRUPO-05) + guard de não-conectado,
# com fakes injetados. Sem rede, sem Evolution::Client real.

failures = []

fake_client = Class.new do
  attr_reader :calls

  def initialize(batches)
    @batches = batches
    @calls = 0
  end

  def fetch_groups(_instance_name, api_key:)
    batch = @batches[@calls]
    @calls += 1
    batch || []
  end
end

def group(id, subject: "Grupo #{id}", announce: false)
  { "id" => "#{id}@g.us", "subject" => subject, "announce" => announce }
end

client = Client.create!(
  name: "Deactivation 27-01 #{SecureRandom.hex(4)}",
  password: "senha1234",
  password_confirmation: "senha1234"
)
instance = WhatsappInstance.create!(
  client: client,
  instance_name: WhatsappInstance.evolution_name_for(client),
  token: "fake-token-#{SecureRandom.hex(4)}",
  connection_state: :connected
)

# (b1) lote de 3 -> 3 ativos
fake1 = fake_client.new([ [ group(1), group(2), group(3) ] ])
Whatsapp::GroupSynchronizer.new(instance, client_api: fake1).call
active_count = instance.whatsapp_groups.where(active: true).count
failures << "b1: esperado 3 ativos, veio #{active_count}" unless active_count == 3

# (deac) 2o lote sem o 3o -> só "3@g.us" fica inativo, e continua existindo
fake2 = fake_client.new([ [ group(1), group(2) ] ])
Whatsapp::GroupSynchronizer.new(instance, client_api: fake2).call
deactivated_jids = instance.whatsapp_groups.where(active: false).pluck(:remote_jid)
failures << "deac: esperado ['3@g.us'], veio #{deactivated_jids.inspect}" unless deactivated_jids == [ "3@g.us" ]
third = instance.whatsapp_groups.find_by(remote_jid: "3@g.us")
failures << "deac: grupo 3 não existe mais (deveria continuar existindo)" if third.nil? || !WhatsappGroup.exists?(third.id)

# (empty) lote [] -> desativa tudo + groups_synced_at avança
before_synced_at = instance.reload.groups_synced_at
fake3 = fake_client.new([ [] ])
Whatsapp::GroupSynchronizer.new(instance, client_api: fake3).call
active_after_empty = instance.whatsapp_groups.where(active: true).count
failures << "empty: esperado 0 ativos, veio #{active_after_empty}" unless active_after_empty == 0
failures << "empty: groups_synced_at não avançou" unless instance.reload.groups_synced_at > before_synced_at

# (guard) instância desconectada -> aborta antes de qualquer HTTP
instance.update!(connection_state: :disconnected)
fake4 = fake_client.new([ [ group(99) ] ])
result = Whatsapp::GroupSynchronizer.new(instance, client_api: fake4).call
failures << "guard: result.reason != :not_connected (#{result.reason.inspect})" unless result.reason == :not_connected
failures << "guard: groups_sync_error != 'not_connected' (#{instance.reload.groups_sync_error.inspect})" unless instance.groups_sync_error == "not_connected"
failures << "guard: fake recebeu fetch_groups (calls=#{fake4.calls}, esperado 0)" unless fake4.calls == 0

if failures.any?
  warn "DEACTIVATION+GUARD FAILED:"
  failures.each { |f| warn "  - #{f}" }
  raise "27-01 deactivation/guard verify failed: #{failures.join('; ')}"
end

puts "DEACTIVATION+GUARD OK"
