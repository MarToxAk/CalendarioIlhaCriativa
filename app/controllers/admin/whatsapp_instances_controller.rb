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
    return redirect_to(admin_client_path(@client),
      alert: "Este cliente ainda não tem uma instância de WhatsApp.") if inst.nil?

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
      alert: "A instância respondeu como desconectada. Use \"Desvincular WhatsApp\" e conecte um número novo ou reutilize outra conexão."
  rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e
    Rails.logger.warn("[whatsapp_instances] verify falhou client=#{@client.id}: #{e.class}")
    redirect_to admin_client_path(@client),
      alert: "Não foi possível falar com o WhatsApp agora. O estado acima pode estar desatualizado. Tente \"Forçar verificação\" de novo em instantes."
  end

  # PAIR-03 — única ação JSON do controller (o Stimulus polling do 26-05
  # consome isto). Nunca chama o Evolution mais de 1x a cada 15s por
  # instância (T-26-15) — `pull_fresh_qr` só prossegue quando ainda não há
  # QR salvo e o throttle de cache permite. Sempre responde com o que já
  # está no banco, mesmo quando o Evolution falha (rescue silencioso em
  # `pull_fresh_qr`).
  def refresh_qr
    inst = @client.whatsapp_instance
    pull_fresh_qr(inst) if inst&.awaiting_qr? && inst.last_qr_base64.blank?
    render json: { state: inst&.connection_state || "unpaired", qr_base64: (inst&.awaiting_qr? ? inst.last_qr_base64 : nil) }
  end

  # "Parear novamente" — força um QR novo mesmo numa instância connected/
  # disconnected (encerra a sessão atual do WhatsApp; confirmação modal fica
  # a cargo da view no 26-05).
  def reconnect
    inst = @client.whatsapp_instance
    return redirect_to(admin_client_path(@client),
      alert: "Este cliente ainda não tem uma instância de WhatsApp.") if inst.nil?

    result = Evolution::Client.connect(inst.instance_name)
    inst.update!(connection_state: :awaiting_qr, last_qr_base64: result[:base64], last_checked_at: Time.current)
    redirect_to admin_client_path(@client), notice: "Pareamento reiniciado. Escaneie o novo QR Code."
  rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e
    Rails.logger.warn("[whatsapp_instances] reconnect falhou client=#{@client.id}: #{e.class}")
    redirect_to admin_client_path(@client),
      alert: "Não foi possível atualizar o QR Code. Clique em \"Gerar novo QR\" para tentar outra vez."
  end

  # Quick task 260831-o9t. "Desvincular WhatsApp" — substitui o antigo botão
  # "Parear novamente" do painel (mostrado quando connected?/disconnected?).
  # NÃO toca #reconnect (ainda usado pelo botão "Gerar novo QR" de _qr.html.erb
  # no estado awaiting_qr). ZERO I/O de rede: NUNCA chama Evolution::Client — a
  # sessão física do WhatsApp continua viva (e, se compartilhada, segue em uso
  # pelos clientes-irmãos). "Desvincular" = flipar connection_state para a
  # sentinela :unpaired que JÁ EXISTE (enum valor 0, mesma semântica "sem
  # instância" de _client_row.html.erb) + soft-desativar os whatsapp_groups em
  # cache DESTA linha (update_all(active: false), sem callbacks, escopado pela
  # associação) para não deixar grupo ativo enganoso. NUNCA destroy/destroy_all:
  # divulgacao_grupos.whatsapp_group_id é null: false sem on_delete: :cascade,
  # então destruir levantaria ActiveRecord::InvalidForeignKey.
  def unlink
    inst = @client.whatsapp_instance
    return redirect_to(admin_client_path(@client),
      alert: "Este cliente ainda não tem uma instância de WhatsApp.") if inst.nil?

    ActiveRecord::Base.transaction do
      inst.update!(
        connection_state: :unpaired,
        groups_sync_state: :idle,
        groups_sync_error: nil,
        last_qr_base64: nil,
        paired_at: nil,
        last_checked_at: Time.current
      )
      inst.whatsapp_groups.update_all(active: false)
    end

    redirect_to admin_client_path(@client),
      notice: "WhatsApp desvinculado deste cliente. A conexão em si continua ativa — nada foi apagado. Conecte um número novo ou reutilize outra conexão quando quiser."
  end

  # Fase 31 (D-03/D-06, T-31-01) + quick task 260831-nb7. "Reutilizar conexão
  # existente" — vincula ESTE cliente a uma conexão JÁ CONECTADA reportada
  # pelo <select> ao vivo (WhatsappInstance.shareable_targets). Dois caminhos:
  # (a) existe irmã local conectada -> #reuse (zero I/O, D-07 intocado); (b)
  # sem irmã local (instância só no Evolution ainda) -> #adopt_named (mesmo
  # caminho de adoção da fase 26). SEG-01: o nome nunca é confiado cegamente —
  # ou casa com uma irmã já escopada localmente, ou é revalidado AO VIVO
  # contra o Evolution antes de qualquer escrita.
  def reuse
    name = params.require(:source_instance_name)
    own_name = WhatsappInstance.evolution_name_for(@client)
    return redirect_to(admin_client_path(@client),
      alert: "Conexão indisponível para reutilização. Atualize a página e tente de novo.") if name == own_name

    sibling = WhatsappInstance.connected.where.not(client_id: @client.id).find_by(instance_name: name)

    if sibling
      Evolution::InstanceProvisioner.new(@client).reuse(existing: sibling)
    else
      entry = Evolution::Client.fetch_instances.find { |i| (i["name"] || i["instanceName"]) == name }
      return redirect_to(admin_client_path(@client),
        alert: "Conexão indisponível para reutilização. Atualize a página e tente de novo.") if entry.nil? || WhatsappInstance.map_evolution_state(entry["connectionStatus"]) != :connected

      Evolution::InstanceProvisioner.new(@client).adopt_named(name)
    end

    redirect_to admin_client_path(@client),
      notice: "Conexão reutilizada. Sincronize os grupos deste cliente para popular a lista."
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_client_path(@client), alert: "Este cliente já possui uma instância de WhatsApp."
  rescue Evolution::Errors::ConfigurationError, Evolution::Errors::Permanent, Evolution::Errors::Transient, Evolution::Errors::Unknown => e
    Rails.logger.warn("[whatsapp_instances] reuse falhou client=#{@client.id}: #{e.class}")
    redirect_to admin_client_path(@client),
      alert: "Não foi possível reutilizar a conexão agora. Tente de novo em instantes."
  end

  private

  # Escopo SEMPRE por client_id (resource nested singular) — nunca buscar a
  # instância direto por um id de params solto (isolamento por cliente,
  # groundwork para SEG-* de fases futuras).
  def set_client
    @client = Client.find(params[:client_id])
  end

  # Só prossegue se conseguiu ESCREVER a chave de throttle — `unless_exist:
  # true` faz `Rails.cache.write` retornar false sem sobrescrever se a chave
  # já existe, ou seja, ninguém puxou um QR fresco nos últimos 15s para esta
  # instância (T-26-15). Silencioso em qualquer falha do Evolution — o
  # endpoint sempre responde com o que já está no banco; o polling do
  # Stimulus tenta de novo no próximo ciclo.
  def pull_fresh_qr(inst)
    return unless Rails.cache.write("wa_qr_pull_#{inst.id}", true, unless_exist: true, expires_in: 15.seconds)

    result = Evolution::Client.connect(inst.instance_name)
    inst.update!(last_qr_base64: result[:base64]) if result[:base64].present?
  rescue Evolution::Errors::Transient, Evolution::Errors::Unknown, Evolution::Errors::Permanent, Evolution::Errors::ConfigurationError
    nil
  end
end
