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

  private

  # Escopo SEMPRE por client_id (resource nested singular) — nunca buscar a
  # instância direto por um id de params solto (isolamento por cliente,
  # groundwork para SEG-* de fases futuras).
  def set_client
    @client = Client.find(params[:client_id])
  end
end
