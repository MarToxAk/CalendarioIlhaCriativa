# frozen_string_literal: true

require "test_helper"

class Api::V1::Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    # Inject a test-only JWT_SECRET so Api::JwtService can encode without
    # credentials.yml.enc being configured (T-21-21; plan 21-05 step 1 adds the real secret).
    @original_jwt_secret = ENV["JWT_SECRET"]
    ENV["JWT_SECRET"] = SecureRandom.hex(32)

    User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password              = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    @user = User.find_by!(email_address: ADMIN_EMAIL)
  end

  teardown do
    ENV["JWT_SECRET"] = @original_jwt_secret
  end

  test "POST /api/v1/admin/session com credenciais válidas retorna 201 e token JWT" do
    post "/api/v1/admin/session",
         params: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 201, response.status
    body = response.parsed_body
    assert body.dig("data", "token").present?,
           "Esperado data.token presente, mas foi: #{body.inspect}"
    assert_equal [], body["errors"],
                 "Esperado errors vazio, mas foi: #{body['errors'].inspect}"
  end

  test "POST /api/v1/admin/session com email inexistente retorna 401 invalid_credentials" do
    post "/api/v1/admin/session",
         params: { email: "nao@existe.com.br", password: ADMIN_PASSWORD }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "invalid_credentials", body.dig("errors", 0, "code"),
                 "Esperado errors[0].code == 'invalid_credentials', mas foi: #{body.inspect}"
  end

  test "POST /api/v1/admin/session com senha errada retorna 401 invalid_credentials" do
    post "/api/v1/admin/session",
         params: { email: ADMIN_EMAIL, password: "senhaerrada" }.to_json,
         headers: { "Content-Type" => "application/json" }

    assert_equal 401, response.status
    body = response.parsed_body
    assert_equal "invalid_credentials", body.dig("errors", 0, "code"),
                 "Esperado errors[0].code == 'invalid_credentials', mas foi: #{body.inspect}"
  end
end
