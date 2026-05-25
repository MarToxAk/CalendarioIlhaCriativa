class Client::SessionsController < ClientController
  skip_before_action :require_client_auth, only: [ :new, :create ]

  def new
  end

  def create
    unless @client.active?
      flash.now[:alert] = "Acesso bloqueado. Entre em contato com o administrador."
      render :new, status: :unprocessable_entity
      return
    end
    if @client.authenticate(params[:password])
      session[:client_id]            = @client.id
      session[:client_token_version] = @client.token_version
      redirect_to client_root_path(token: @client.access_token)
    else
      flash.now[:alert] = "Senha incorreta. Tente novamente."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:client_id)
    session.delete(:client_token_version)
    redirect_to new_client_session_path(token: @client.access_token), notice: "Saiu com sucesso."
  end
end
