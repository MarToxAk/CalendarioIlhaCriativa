# frozen_string_literal: true

class Api::V1::Client::SessionsController < Api::V1::BaseController
  def create
    client = Client.find_by(access_token: params.require(:access_token))

    unless client&.authenticate(params.require(:password))
      return render_error(
        code: "invalid_credentials",
        detail: "Token ou senha inválidos",
        status: :unauthorized
      )
    end

    unless client.active?
      return render_error(
        code: "invalid_credentials",
        detail: "Token ou senha inválidos",
        status: :unauthorized
      )
    end

    token = Api::JwtService.encode({ sub: client.id.to_s, scope: "client" })
    render_envelope(
      data: { token: token, expires_in: Api::JwtService::DEFAULT_EXPIRY.to_i },
      status: :created
    )
  end
end
