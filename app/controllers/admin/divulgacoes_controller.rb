class Admin::DivulgacoesController < Admin::BaseController
  before_action :set_client
  before_action :set_divulgacao, only: [ :show, :cancel ]

  def index
    @pagy, @divulgacoes = pagy(
      @client.divulgacoes.includes(:arte).order(scheduled_for: :desc),
      limit: 25
    )
  end

  def show
  end

  def cancel
    if @divulgacao.cancelar!
      redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                  notice: "Divulgação cancelada. Nenhum envio será feito."
    else
      redirect_to admin_client_divulgacao_path(@client, @divulgacao),
                  alert: "Só é possível cancelar uma divulgação ainda agendada."
    end
  end

  def new
    @instance = @client.whatsapp_instance
    @divulgacao = @client.divulgacoes.new
    load_form_collections
  end

  def create
    @instance = @client.whatsapp_instance
    load_form_collections

    # Guarda server-side (Task 1): sem instancia ou sem arte aprovada, a view
    # so tem o estado vazio pra mostrar — nem tenta resolver arte_id/grupos.
    # Instancia nao-connected fica permissiva aqui de proposito: o submit
    # desabilitado no client e so uma dica, a fase 29 e dona da revalidacao
    # de conexao no momento do envio.
    if @instance.nil? || @approved_artes.empty?
      @divulgacao = @client.divulgacoes.new
      render :new, status: :unprocessable_entity
      return
    end

    arte   = @client.artes.find(divulgacao_params[:arte_id])
    gids   = Array(divulgacao_params[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
    groups = scoped_active_groups.find(gids)

    @divulgacao = @client.divulgacoes.new(
      arte:          arte,
      scheduled_for: divulgacao_params[:scheduled_for]
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
  rescue ActiveRecord::RecordNotFound
    # SEG-01/SEG-02: um id forasteiro/inativo (ou um grupo desativado por um sync
    # da fase 27 entre o load do form e o submit) cai aqui em vez de 404 — re-render
    # com mensagem acionavel e generica (nao revela de quem e o id). Zero linhas gravadas.
    # WR-01: preserva o que ja era resolvivel (arte, scheduled_for bruto + grupos
    # que realmente existem/pertencem ao cliente) em vez de devolver o form em
    # branco — um id forasteiro/desativado nao deveria forcar o admin a
    # redigitar tudo. `arte` (linha 46) ja esta no escopo local do metodo por
    # causa do rescue de nivel de metodo do Ruby; se a excecao veio da propria
    # resolucao da arte (linha 46), `arte` ainda e nil (pre-declaracao de
    # variavel local do Ruby), o que e inofensivo de repassar aqui.
    @divulgacao ||= @client.divulgacoes.new(
      arte:          arte,
      scheduled_for: divulgacao_params[:scheduled_for]
    )
    resolved_gids = Array(divulgacao_params[:whatsapp_group_ids]).map(&:to_i).uniq.reject(&:zero?)
    scoped_active_groups.where(id: resolved_gids).each do |g|
      @divulgacao.divulgacao_grupos.build(
        whatsapp_group: g,
        group_name:     g.display_name,
        remote_jid:     g.remote_jid
      )
    end
    load_form_collections
    flash.now[:alert] = "Seleção inválida: uma arte ou um grupo escolhido não pertence a este cliente ou foi desativado. Revise a seleção e tente de novo."
    render :new, status: :unprocessable_entity
  end

  private

  # WR-02/CR-02: strong-params allowlist (em vez de params.dig ad-hoc). Alem de
  # seguir a convencao do Rails, isso coage/descarta formatos malformados antes
  # que cheguem na logica de resolucao de id: um whatsapp_group_ids Hash-shaped
  # vira nil (permit de array so aceita Array), e um arte_id Array-shaped tambem
  # vira nil (permit escalar so aceita tipos escalares) — ambos batem no
  # `rescue ActiveRecord::RecordNotFound` acima via `.find(nil)`, nunca num 500.
  def divulgacao_params
    params.require(:divulgacao).permit(:arte_id, :scheduled_for, whatsapp_group_ids: [])
  end

  def set_client = @client = Client.find(params[:client_id])

  # T-28-15/T-28-16: escopado pela associacao do cliente — um id de outra
  # divulgacao (de outro cliente) cai em RecordNotFound -> Rails 404, nunca
  # renderiza dado de B na resposta de A.
  def set_divulgacao = @divulgacao = @client.divulgacoes.find(params[:id])

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
