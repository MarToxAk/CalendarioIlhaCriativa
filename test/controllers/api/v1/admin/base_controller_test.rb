# frozen_string_literal: true

require "test_helper"

# Stub controller to exercise the Admin::BaseController guard without
# requiring a real admin endpoint to exist in the production routing table yet.
class Api::V1::Admin::TestPingController < Api::V1::Admin::BaseController
  def ping
    render_envelope(data: { pong: true })
  end
end

class Api::V1::Admin::BaseControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    # Inject a test-only JWT_SECRET so Api::JwtService can encode/decode
    # without requiring credentials.yml.enc to be configured (T-21-21).
    # This value is random per test run and never stored in the repository.
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password              = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    @user = User.find_by!(email_address: ADMIN_EMAIL)

    # Temporarily add a route that goes through Admin::BaseController so we can
    # test the before_action :authenticate_admin_jwt! guard in isolation.
    Rails.application.routes.draw do
      namespace :api, defaults: { format: :json } do
        namespace :v1 do
          namespace :admin do
            resource :session, only: [ :create ]
            get "ping" => "test_ping#ping"
          end
          namespace :client do
            resource :session, only: [ :create ]
          end
          namespace :ai do
            # Phase 24
          end
        end
      end
      get "up" => "rails/health#show", as: :rails_health_check
    end
  end

  teardown do
    # Restore JWT_SECRET to its original state (may be nil in test env before
    # credentials are provisioned — plan 21-05 step 1).
    ENV["JWT_SECRET"] = @original_jwt_secret

    # Restore the original routes to avoid polluting other tests.
    Rails.application.reload_routes!
  end

  test "request sem Authorization header retorna 401 com code unauthorized" do
    get "/api/v1/admin/ping", headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "unauthorized", body.dig("errors", 0, "code"),
                 "Esperado errors[0].code == 'unauthorized', mas foi: #{body.inspect}"
  end

  test "request com JWT de cliente (scope:client) para endpoint admin retorna 401" do
    # Gerar JWT de cliente diretamente via JwtService para simular token de scope errado.
    # O ENV["JWT_SECRET"] foi injetado no setup, então o encode funciona sem credentials.
    client = Client.find_or_create_by!(access_token: "basetest_client_token_xyz") do |c|
      c.name                  = "BaseTest Client"
      c.password              = "SenhaBase789!"
      c.password_confirmation = "SenhaBase789!"
      c.active                = true
    end

    client_jwt = Api::JwtService.encode({ sub: client.id.to_s, scope: "client" })

    get "/api/v1/admin/ping",
        headers: {
          "Content-Type"  => "application/json",
          "Authorization" => "Bearer #{client_jwt}"
        }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "unauthorized", body.dig("errors", 0, "code"),
                 "JWT de cliente deve ser rejeitado em endpoint admin, mas foi: #{body.inspect}"
  end

  test "request com API key ak_ para endpoint admin retorna 401" do
    get "/api/v1/admin/ping",
        headers: {
          "Content-Type"  => "application/json",
          "Authorization" => "Bearer ak_testekey1234567890abcdef"
        }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "unauthorized", body.dig("errors", 0, "code"),
                 "API key ak_ deve ser rejeitada em endpoint admin, mas foi: #{body.inspect}"
  end
end
