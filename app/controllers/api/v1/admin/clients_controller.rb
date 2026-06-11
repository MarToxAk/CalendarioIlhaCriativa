# frozen_string_literal: true

class Api::V1::Admin::ClientsController < Api::V1::Admin::BaseController
  def index
    scope = Client.order(created_at: :desc)
    @pagy, @clients = pagy(scope, limit: per_page_param)
    render_envelope(
      data: Api::V1::Admin::ClientSerializer.serialize_collection(@clients),
      meta: { pagination: pagination_meta(@pagy) }
    )
  end

  def create
    @client = Client.new(client_params)
    @client.password_plain = params[:password] if params[:password].present?
    @client.save!
    portal_host = "#{request.protocol}#{request.host_with_port}"
    render_envelope(
      data: Api::V1::Admin::ClientSerializer.serialize(
        @client,
        include_credentials: true,
        portal_host: portal_host
      ),
      status: :created
    )
  end

  private

  def client_params
    params.permit(:name, :password, :active)
  end
end
