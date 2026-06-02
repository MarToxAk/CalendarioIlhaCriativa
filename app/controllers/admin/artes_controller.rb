class Admin::ArtesController < Admin::BaseController
  before_action :set_client, only: %i[index new create show edit update destroy mark_revised]
  before_action :set_arte, only: %i[show edit update destroy mark_revised]
  before_action :check_editable, only: %i[edit update]
  before_action :check_deletable, only: %i[destroy]

  def index
    @artes = if params[:client_id].present?
      Arte.where(client_id: params[:client_id]).includes(:client).order(scheduled_on: :desc)
    else
      Arte.includes(:client).order(scheduled_on: :desc)
    end
    @clients = Client.all
    @status_options = Arte.statuses.keys
    @platform_options = Arte.platforms.keys
  end

  def show
  end

  def new
    @arte = Arte.new(client: @client)
  end

  def create
    @arte = Arte.new(arte_params)
    if @arte.save
      redirect_to admin_arte_path(@arte), notice: "Arte criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @arte.update(arte_params)
      redirect_to admin_arte_path(@arte), notice: "Arte atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @arte.destroy
      redirect_to admin_artes_path, notice: "Arte excluída com sucesso."
    else
      redirect_to admin_arte_path(@arte), alert: "Não foi possível excluir a arte."
    end
  end

  def mark_revised
    if @arte.change_requested?
      @arte.revised!
      redirect_to admin_arte_path(@arte), notice: "Arte marcada como revisada."
    else
      redirect_to admin_arte_path(@arte), alert: "Ação inválida para o status atual."
    end
  end

  private

  def set_arte
    if @client
      @arte = @client.artes.includes(:approval_responses).find(params[:id])
    else
      @arte = Arte.includes(:approval_responses).find(params[:id])
      @client = @arte.client
    end
  end

  def set_client
    return unless params[:client_id].present?
    @client = Client.find_by(id: params[:client_id])
    unless @client
      redirect_to admin_artes_path, alert: "Cliente não encontrado." and return
    end
  end

  def arte_params
    params.require(:arte).permit(:title, :caption, :scheduled_on, :approval_deadline, :external_url, :platform, :media_type, :client_id, :media_file, :admin_reply)
  end

  def check_editable
    unless @arte.pending? || @arte.revised? || @arte.change_requested?
      redirect_to admin_arte_path(@arte), alert: "Edição bloqueada: só é possível editar artes pendentes, revisadas ou com pedido de alteração."
    end
  end

  def check_deletable
    unless @arte.pending? && @arte.approval_responses.none?
      redirect_to admin_arte_path(@arte), alert: "Exclusão bloqueada: só é possível excluir artes pendentes sem resposta do cliente."
    end
  end
end
