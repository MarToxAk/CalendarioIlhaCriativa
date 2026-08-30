# Runner de verificação do plano 27-03, Task 3 -- não é deliverable da fase, é
# ferramenta de prova: monta os 5 cenários de estado da página de grupos e
# renderiza admin/whatsapp_groups/index via ActionController::Renderer (a API
# oficial do Rails para renderizar uma view/controller fora de um ciclo HTTP
# real -- necessário aqui porque este ambiente sandboxed roda `bin/rails
# runner` em development, e um dispatch Rack completo via
# ActionDispatch::Integration::Session dentro do mesmo processo do runner
# corrompe o ActiveSupport::ExecutionContext do processo externo, ambos
# aninhando ActiveSupport::Executor -- ver Issues Encontrados do SUMMARY).
# O Renderer não passa pelos before_actions do controller, então os ivars são
# montados aqui manualmente com a MESMA lógica de Admin::WhatsappGroupsController#index.

def scenario_html(client)
  instance = client.whatsapp_instance
  active_groups = instance ? instance.whatsapp_groups.where(active: true)
                                      .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid) : nil
  inactive_groups = instance ? instance.whatsapp_groups.where(active: false)
                                        .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid) : nil

  renderer = Admin::WhatsappGroupsController.renderer.new(http_host: "localhost")
  renderer.render(
    template: "admin/whatsapp_groups/index",
    layout: false,
    assigns: {
      client: client,
      instance: instance,
      active_groups: active_groups,
      inactive_groups: inactive_groups,
      pagy: nil
    }
  )
end

def fresh_client(name)
  Client.create!(name: name, password: "senha1234", password_confirmation: "senha1234")
end

# --- Cenario 1: cliente sem whatsapp_instance -----------------------------
client1 = fresh_client("Runner States 1")
body1 = scenario_html(client1)
raise "FAIL cenario 1: esperava 'Nenhuma instância de WhatsApp'" unless body1.include?("Nenhuma instância de WhatsApp")
puts "cenario 1 OK"

# --- Cenario 2: instancia disconnected ------------------------------------
client2 = fresh_client("Runner States 2")
client2.create_whatsapp_instance!(
  instance_name: WhatsappInstance.evolution_name_for(client2),
  connection_state: :disconnected
)
body2 = scenario_html(client2)
raise "FAIL cenario 2: esperava a copy do banner bloqueado" unless body2.include?("A instância está desconectada.")
puts "cenario 2 OK"

# --- Cenario 3: connected + groups_sync_error='transient' + 1 grupo cache --
client3 = fresh_client("Runner States 3")
instance3 = client3.create_whatsapp_instance!(
  instance_name: WhatsappInstance.evolution_name_for(client3),
  connection_state: :connected,
  groups_synced_at: Time.zone.local(2026, 8, 30, 10, 0),
  groups_sync_state: :error,
  groups_sync_error: "transient"
)
instance3.whatsapp_groups.create!(remote_jid: "s3@g.us", subject: "Grupo Cache Cenario 3", active: true, synced_at: Time.current)
body3 = scenario_html(client3)
raise "FAIL cenario 3: esperava copy de erro transiente" unless body3.include?("não foi possível falar com o WhatsApp agora")
raise "FAIL cenario 3: esperava o grupo em cache ainda renderizado" unless body3.include?("Grupo Cache Cenario 3")
puts "cenario 3 OK"

# --- Cenario 4: connected + synced + 0 grupos -----------------------------
client4 = fresh_client("Runner States 4")
client4.create_whatsapp_instance!(
  instance_name: WhatsappInstance.evolution_name_for(client4),
  connection_state: :connected,
  groups_synced_at: Time.zone.local(2026, 8, 30, 11, 0),
  groups_sync_state: :idle
)
body4 = scenario_html(client4)
raise "FAIL cenario 4: esperava 'Nenhum grupo neste número'" unless body4.include?("Nenhum grupo neste número")
puts "cenario 4 OK"

# --- Cenario 5: 1 grupo active + 1 inactive -------------------------------
client5 = fresh_client("Runner States 5")
instance5 = client5.create_whatsapp_instance!(
  instance_name: WhatsappInstance.evolution_name_for(client5),
  connection_state: :connected,
  groups_synced_at: Time.zone.local(2026, 8, 30, 12, 0),
  groups_sync_state: :idle
)
instance5.whatsapp_groups.create!(remote_jid: "s5a@g.us", subject: "Grupo Ativo 5", active: true, synced_at: Time.current)
instance5.whatsapp_groups.create!(remote_jid: "s5i@g.us", subject: "Grupo Sumido 5", active: false, synced_at: 1.day.ago)
body5 = scenario_html(client5)
raise "FAIL cenario 5: esperava o divisor 'Grupos inativos'" unless body5.include?("Grupos inativos")

divider_index = body5.index("Grupos inativos")
after_divider = body5[divider_index..]
raise "FAIL cenario 5: a linha do grupo inativo não deveria ter checkbox" if after_divider.include?('type="checkbox"')
raise "FAIL cenario 5: esperava o grupo ativo ANTES do divisor (com checkbox)" unless body5[0...divider_index].include?('type="checkbox"')
raise "FAIL cenario 5: esperava o grupo inativo listado" unless after_divider.include?("Grupo Sumido 5")
puts "cenario 5 OK"

puts "STATES OK"
