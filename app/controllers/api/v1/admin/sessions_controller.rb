# frozen_string_literal: true

class Api::V1::Admin::SessionsController < Api::V1::BaseController
  def create
    user = User.find_by(email_address: params.require(:email).strip.downcase)

    unless user&.authenticate(params.require(:password))
      return render_error(
        code: "invalid_credentials",
        detail: "E-mail ou senha inválidos",
        status: :unauthorized
      )
    end

    token = Api::JwtService.encode({ sub: user.id.to_s, scope: "admin" })
    render_envelope(
      data: { token: token, expires_in: Api::JwtService::DEFAULT_EXPIRY.to_i },
      status: :created
    )
  end
end
