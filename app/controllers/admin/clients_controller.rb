class Admin::ClientsController < Admin::BaseController
  before_action :set_client, only: %i[ show edit update rotate_token ]

  def index
    @clients = Client.order(created_at: :desc)
  end

  def show
    @artes = @client.artes.order(scheduled_on: :desc)
    @artes_with_responses = @client.artes
                                    .joins(:approval_responses)
                                    .includes(:approval_responses)
                                    .distinct
                                    .order(scheduled_on: :desc)
  end

  def new
    @client = Client.new
  end

  def create
    params_with_plain = client_params
    if params_with_plain[:password].present?
      params_with_plain = params_with_plain.merge(password_plain: params_with_plain[:password])
    end
    @client = Client.new(params_with_plain)
    if @client.save
      redirect_to admin_client_path(@client), notice: "Cliente cadastrado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    was_active = @client.active
    filtered = client_params.reject { |k, v| k == "password" && v.blank? }
    if filtered[:password].present?
      filtered = filtered.merge(password_plain: filtered[:password])
    end
    if @client.update(filtered)
      if was_active && !@client.active
        redirect_to admin_client_path(@client), notice: "#{@client.name} foi desativado. O acesso ao portal está bloqueado."
      elsif !was_active && @client.active
        redirect_to admin_client_path(@client), notice: "#{@client.name} foi reativado. O cliente pode acessar o portal novamente."
      else
        redirect_to admin_client_path(@client), notice: "Dados do cliente atualizados."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def rotate_token
    @client.regenerate_access_token
    redirect_to admin_client_path(@client),
      notice: "Token rotacionado. O link anterior não funciona mais. Envie o novo link para o cliente."
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:name, :password, :active)
  end
end
