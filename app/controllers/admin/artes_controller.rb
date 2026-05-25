class Admin::ArtesController < Admin::BaseController
  before_action :set_arte, only: %i[show edit update destroy]
  before_action :set_client, only: %i[new create]
  before_action :check_editable, only: %i[edit update]
  before_action :check_deletable, only: %i[destroy]

  def index
    @artes = Arte.includes(:client).order(scheduled_on: :desc)
    @clients = Client.all
    @status_options = Arte.statuses.keys
    @platform_options = Arte.platforms.keys
    # Filtering logic can be added here
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
    @arte.destroy
    redirect_to admin_artes_path, notice: "Arte excluída com sucesso."
  end

  private

  def set_arte
    @arte = Arte.find(params[:id])
  end

  def set_client
    @client = Client.find_by(id: params[:client_id])
  end

  def arte_params
    params.require(:arte).permit(:title, :caption, :scheduled_on, :approval_deadline, :external_url, :platform, :media_type, :status, :client_id, :media_file)
  end

  def check_editable
    unless @arte.pending?
      redirect_to admin_arte_path(@arte), alert: "Edição bloqueada: só é possível editar artes pendentes."
    end
  end

  def check_deletable
    unless @arte.pending? && @arte.approval_response.nil?
      redirect_to admin_arte_path(@arte), alert: "Exclusão bloqueada: só é possível excluir artes pendentes sem resposta do cliente."
    end
  end
end
