class Admin::WhatsappGroupsController < Admin::BaseController
  before_action :set_client, :set_instance
  before_action :set_group, only: [ :show ]

  # Lê SOMENTE o cache local (whatsapp_groups) — este arquivo nunca fala com o
  # host WhatsApp externo (GRUPO-02/SC2).
  def index
    return if @instance.nil?

    @pagy, @active_groups = pagy(
      @instance.whatsapp_groups.where(active: true)
               .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid),
      limit: 25
    )
    @inactive_groups = @instance.whatsapp_groups.where(active: false)
                                 .order(Arel.sql("subject ASC NULLS LAST")).order(:remote_jid)
  end

  # Dispara Whatsapp::SyncGroupsJob em background (GRUPO-01). Instância
  # ausente/não conectada NUNCA enfileira -- guard cedo, sem gravar estado.
  # Guard de cache de 15s (Pitfall 8) evita duplo-clique/sync-spam: só
  # prossegue se conseguiu ESCREVER a chave (mesmo precedente de
  # #pull_fresh_qr, T-26-15). Esse TTL é mais curto que a pior duração
  # possível do job (3 tentativas x 30s de retry_on + timeouts HTTP), então
  # o guard sozinho não impede um segundo job concorrente para a mesma
  # instância depois que a chave expira -- o check em groups_sync_syncing?
  # cobre exatamente essa janela, gate no estado real em vez de um TTL fixo
  # (WR-02 do code review da fase 27).
  def sync
    if @instance.nil? || !@instance.connected?
      return redirect_to admin_client_whatsapp_groups_path(@client),
             alert: "A instância está desconectada. Reconecte o número antes de sincronizar os grupos."
    end

    if @instance.groups_sync_syncing?
      return redirect_to admin_client_whatsapp_groups_path(@client), notice: "Sincronização já em andamento."
    end

    return redirect_to(admin_client_whatsapp_groups_path(@client), notice: "Sincronização já em andamento.") \
      unless Rails.cache.write("wa_groups_sync_#{@instance.id}", true, unless_exist: true, expires_in: 15.seconds)

    @instance.update!(groups_sync_state: :syncing, groups_sync_error: nil)
    Whatsapp::SyncGroupsJob.perform_later(@instance)
    redirect_to admin_client_whatsapp_groups_path(@client),
                notice: "Sincronização iniciada. Os grupos aparecem aqui em instantes."
  end

  # Prova canônica do isolamento cross-client da fase (GRUPO-03/SC5): o único
  # dado renderizado vem de @group, resolvido em set_group SEMPRE a partir de
  # @client.whatsapp_instance.whatsapp_groups -- nunca WhatsappGroup.find cru.
  def show
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

  # Toda leitura de grupo único parte de @client.whatsapp_instance.whatsapp_groups
  # -- nunca WhatsappGroup.find/.where (GRUPO-03/SC5: cross-client id ->
  # RecordNotFound -> redirect genérico, sem vazar subject/remote_jid de outro
  # cliente). @instance nil (cliente sem instância) degrada para o MESMO
  # RecordNotFound -- nunca um NoMethodError em `.whatsapp_groups` de uma
  # associação ausente.
  def set_group
    raise ActiveRecord::RecordNotFound if @instance.nil?

    @group = @instance.whatsapp_groups.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_client_whatsapp_groups_path(@client), alert: "Grupo não encontrado."
  end
end
