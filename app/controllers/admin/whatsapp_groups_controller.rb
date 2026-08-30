class Admin::WhatsappGroupsController < Admin::BaseController
  before_action :set_client, :set_instance

  # Lê SOMENTE o cache local (whatsapp_groups) — nunca Evolution::Client neste
  # arquivo (GRUPO-02/SC2). #sync e #sync_status chegam na 27-02; #show na 27-03.
  def index
    return if @instance.nil?

    @pagy, @active_groups = pagy(
      @instance.whatsapp_groups.where(active: true)
               .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid),
      limit: 25
    )
  end

  private

  def set_client   = @client = Client.find(params[:client_id])
  def set_instance = @instance = @client.whatsapp_instance

  # Qualquer leitura de grupo único (27-03 #show) DEVE partir de
  # @client.whatsapp_instance.whatsapp_groups.find(...) — nunca WhatsappGroup.find
  # (GRUPO-03/SC5: cross-client id -> RecordNotFound -> 404, sem vazar existência).
end
