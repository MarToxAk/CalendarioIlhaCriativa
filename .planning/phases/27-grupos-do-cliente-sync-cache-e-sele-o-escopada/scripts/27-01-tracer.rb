# bin/rails runner .planning/phases/27-grupos-do-cliente-sync-cache-e-sele-o-escopada/scripts/27-01-tracer.rb
#
# Task 1 <verify> — caminho feliz ponta a ponta: fake Evolution::Client injetado ->
# Whatsapp::GroupSynchronizer#call -> upsert_all -> #index lê só o cache.
# Sem rede, sem instância real do Evolution.

client = Client.create!(
  name: "Tracer 27-01 #{SecureRandom.hex(4)}",
  password: "senha1234",
  password_confirmation: "senha1234"
)

instance = WhatsappInstance.create!(
  client: client,
  instance_name: WhatsappInstance.evolution_name_for(client),
  token: "fake-token-#{SecureRandom.hex(4)}",
  connection_state: :connected,
  last_checked_at: Time.current
)

fake_groups_payload = [
  { "id" => "120363000000000001@g.us", "subject" => "Grupo A", "announce" => false },
  { "id" => "120363000000000002@g.us", "subject" => nil, "announce" => true },
  { "id" => "55SELF@s.whatsapp.net", "subject" => "eu" }
]

fake_client = Class.new do
  define_singleton_method(:fetch_groups) do |_instance_name, api_key:|
    fake_groups_payload
  end
end

result = Whatsapp::GroupSynchronizer.new(instance, client_api: fake_client).call

failures = []

failures << "result.ok != true (#{result.ok.inspect})" unless result.ok == true

count = WhatsappGroup.where(whatsapp_instance_id: instance.id).count
failures << "whatsapp_groups.count != 2 (got #{count})" unless count == 2

announce_count = WhatsappGroup.where(whatsapp_instance_id: instance.id, announce: true).count
failures << "where(announce:true).count != 1 (got #{announce_count})" unless announce_count == 1

null_subject_group = WhatsappGroup.find_by(whatsapp_instance_id: instance.id, remote_jid: "120363000000000002@g.us")
if null_subject_group.nil?
  failures << "null-subject group row not found"
elsif null_subject_group.display_name != "Grupo sem nome (120363000000…)"
  failures << "display_name mismatch: #{null_subject_group.display_name.inspect}"
end

instance.reload
failures << "groups_synced_at ausente" if instance.groups_synced_at.nil?
failures << "groups_sync_state != idle (got #{instance.groups_sync_state})" unless instance.groups_sync_state == "idle"

if failures.any?
  warn "TRACER FAILED:"
  failures.each { |f| warn "  - #{f}" }
  raise "27-01 tracer failed: #{failures.join('; ')}"
end

puts "TRACER OK"
