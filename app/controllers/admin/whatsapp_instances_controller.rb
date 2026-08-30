class Admin::WhatsappInstancesController < Admin::BaseController
  before_action :set_client

  def create
    Evolution::InstanceProvisioner.new(@client).call
    redirect_to admin_client_path(@client), notice: "Instância criada. Escaneie o QR Code para parear."
  rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e
    Rails.logger.warn("[whatsapp_instances] create falhou client=#{@client.id}: #{e.class}")
    redirect_to admin_client_path(@client),
      alert: "Não foi possível criar a instância no WhatsApp. Verifique a configuração do Evolution e tente de novo."
  end

  # PAIR-02 — "Adotar instância existente". O InstanceProvisioner já cobre
  # create-ou-adota internamente (rescue "already in use" -> #adopt), então
  # esta action não precisa de lógica extra: só chama o mesmo #call.
  def adopt
    Evolution::InstanceProvisioner.new(@client).call
    redirect_to admin_client_path(@client),
      notice: "Instância existente adotada e webhook reapontado para este sistema."
  rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e
    Rails.logger.warn("[whatsapp_instances] adopt falhou client=#{@client.id}: #{e.class}")
    redirect_to admin_client_path(@client),
      alert: "Não foi possível criar a instância no WhatsApp. Verifique a configuração do Evolution e tente de novo."
  end

  # PAIR-05 — verificação manual SÍNCRONA (nunca job). A gravação em banco
  # roda SEMPRE que a leitura tem sucesso — mesmo quando o estado lido não é
  # "open" — porque a verificação também serve para descobrir uma
  # desconexão. `assert_open!` roda DEPOIS da gravação: o estado real já foi
  # persistido, e assert_open! só decide qual mensagem mostrar (não é um
  # caminho de falha — connectionState respondeu, só que "não aberto").
  # Numa falha de TRANSPORTE (levantada por connection_state em si, antes de
  # qualquer leitura de estado), a exceção interrompe ANTES do update! —
  # connection_state/last_checked_at permanecem com o último valor conhecido.
  def verify
    inst = @client.whatsapp_instance
    state = Evolution::Client.connection_state(inst.instance_name)
    mapped = WhatsappInstance.map_evolution_state(state)
    old_label = inst.connection_state_label
    inst.update!(
      connection_state: mapped,
      last_checked_at: Time.current,
      paired_at: (inst.paired_at || (state == "open" ? Time.current : nil)),
      last_qr_base64: (state == "open" ? nil : inst.last_qr_base64)
    )
    Evolution::Client.assert_open!(state)
    redirect_to admin_client_path(@client),
      notice: (old_label == inst.connection_state_label ? "Conexão verificada: #{inst.connection_state_label}." : "Estado atualizado: agora #{inst.connection_state_label}.")
  rescue Evolution::Errors::NotConnected
    redirect_to admin_client_path(@client),
      alert: "A instância respondeu como desconectada. Use \"Parear novamente\" para reconectar o número."
  rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e
    Rails.logger.warn("[whatsapp_instances] verify falhou client=#{@client.id}: #{e.class}")
    redirect_to admin_client_path(@client),
      alert: "Não foi possível falar com o WhatsApp agora. O estado acima pode estar desatualizado. Tente \"Forçar verificação\" de novo em instantes."
  end

  private

  # Escopo SEMPRE por client_id (resource nested singular) — nunca buscar a
  # instância direto por um id de params solto (isolamento por cliente,
  # groundwork para SEG-* de fases futuras).
  def set_client
    @client = Client.find(params[:client_id])
  end
end
