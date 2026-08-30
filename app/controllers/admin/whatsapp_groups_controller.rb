class Admin::WhatsappGroupsController < Admin::BaseController
  before_action :set_client, :set_instance

  # Lê SOMENTE o cache local (whatsapp_groups) — este arquivo nunca fala com o
  # host WhatsApp externo (GRUPO-02/SC2). #sync e #sync_status chegam na 27-02;
  # #show na 27-03.
  def index
    return if @instance.nil?

    @pagy, @active_groups = pagy(
      @instance.whatsapp_groups.where(active: true)
               .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid),
      limit: 25
    )
  end

  # Dispara Whatsapp::SyncGroupsJob em background (GRUPO-01). Instância
  # ausente/não conectada NUNCA enfileira -- guard cedo, sem gravar estado.
  # Guard de cache (Pitfall 8) evita sync-spam: só prossegue se conseguiu
  # ESCREVER a chave (mesmo precedente de #pull_fresh_qr, T-26-15).
  def sync
    if @instance.nil? || !@instance.connected?
      return redirect_to admin_client_whatsapp_groups_path(@client),
             alert: "A instância está desconectada. Reconecte o número antes de sincronizar os grupos."
    end

    return redirect_to(admin_client_whatsapp_groups_path(@client), notice: "Sincronização já em andamento.") \
      unless Rails.cache.write("wa_groups_sync_#{@instance.id}", true, unless_exist: true, expires_in: 15.seconds)

    @instance.update!(groups_sync_state: :syncing, groups_sync_error: nil)
    Whatsapp::SyncGroupsJob.perform_later(@instance)
    redirect_to admin_client_whatsapp_groups_path(@client),
                notice: "Sincronização iniciada. Os grupos aparecem aqui em instantes."
  end

  # Único backing de sync_status: as 3 colunas de estado local, nunca o
  # Evolution nem introspecção do solid_queue (Pattern 5). Payload restrito a
  # 4 chaves -- sem nomes de grupo, sem JIDs, sem contagem de inativos
  # (RESEARCH Security V13, T-27-03). Já escopado por params[:client_id] via
  # set_client.
  def sync_status
    render json: {
      syncing: @instance&.groups_sync_syncing? || false,
      synced_at: @instance&.groups_synced_at&.iso8601,
      error: @instance&.groups_sync_error,
      count: @instance ? @instance.whatsapp_groups.where(active: true).count : 0
    }
  end

  private

  def set_client   = @client = Client.find(params[:client_id])
  def set_instance = @instance = @client.whatsapp_instance

  # Qualquer leitura de grupo único (27-03 #show) DEVE partir de
  # @client.whatsapp_instance.whatsapp_groups.find(...) — nunca WhatsappGroup.find
  # (GRUPO-03/SC5: cross-client id -> RecordNotFound -> 404, sem vazar existência).
end
