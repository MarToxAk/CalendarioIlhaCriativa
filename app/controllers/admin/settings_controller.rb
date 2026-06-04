class Admin::SettingsController < Admin::BaseController
  def show
  end

  def update_password
    unless Current.user.authenticate(params[:password_current])
      return redirect_to admin_settings_path, alert: "Senha atual incorreta."
    end

    if params[:password].blank?
      return redirect_to admin_settings_path, alert: "A nova senha não pode ficar em branco."
    end

    if params[:password] != params[:password_confirmation]
      return redirect_to admin_settings_path, alert: "A nova senha e a confirmação não coincidem."
    end

    if Current.user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      redirect_to admin_settings_path, notice: "Senha alterada com sucesso."
    else
      redirect_to admin_settings_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end

  def update_agency
    if Current.user.update(agency_name: params[:agency_name])
      redirect_to admin_settings_path, notice: "Nome da agência atualizado."
    else
      redirect_to admin_settings_path, alert: Current.user.errors.full_messages.to_sentence
    end
  end
end
