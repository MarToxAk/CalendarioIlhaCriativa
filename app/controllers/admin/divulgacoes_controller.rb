class Admin::DivulgacoesController < Admin::BaseController
  before_action :set_client

  def index
    @pagy, @divulgacoes = pagy(
      @client.divulgacoes.includes(:arte).order(scheduled_for: :desc),
      limit: 25
    )
  end

  def new
    @divulgacao = @client.divulgacoes.new
    load_form_collections
  end

  def create
    arte   = @client.artes.find(params.dig(:divulgacao, :arte_id))
    gids   = Array(params.dig(:divulgacao, :whatsapp_group_ids)).map(&:to_i).uniq.reject(&:zero?)
    groups = scoped_active_groups.find(gids)

    @divulgacao = @client.divulgacoes.new(
      arte:          arte,
      scheduled_for: params.dig(:divulgacao, :scheduled_for)
    )
    groups.each do |g|
      @divulgacao.divulgacao_grupos.build(
        whatsapp_group: g,
        group_name:     g.display_name,
        remote_jid:     g.remote_jid
      )
    end

    if @divulgacao.save
      redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                  notice: "Divulgação agendada para #{helpers.divulgacao_datetime_label(@divulgacao.scheduled_for)}."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_client = @client = Client.find(params[:client_id])

  # Invariante SEG-01: o option set e SEMPRE re-resolvido pela associacao do
  # cliente — nunca WhatsappGroup.find/.where cru. Cliente sem instancia degrada
  # para WhatsappGroup.none (e qualquer id submetido -> RecordNotFound).
  def scoped_active_groups
    @client.whatsapp_instance&.whatsapp_groups&.where(active: true) || WhatsappGroup.none
  end

  def load_form_collections
    @approved_artes = @client.artes.approved.order(scheduled_on: :desc)
  end
end
